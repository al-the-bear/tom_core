/// A directory medium's writes are atomic.
///
/// The commit journal exists to survive a process death, and it rewrites its
/// whole file on every mutation — so a medium whose write was a direct
/// overwrite would make the moment the journal is most likely to be asked to
/// do its job exactly the moment its own write could be interrupted.
///
/// A truncated YAML file does not degrade to "one entry short". It does not
/// parse, and an unparseable journal is **indistinguishable from an empty
/// one**, so the failure is silent: the queue is gone and nothing says so.
///
/// The fix is in the contract rather than in an opt-in primitive
/// (`writeBytesAtomic`), because no caller of a `TomBundleMedium` wants a torn
/// file and an opt-in safety primitive is one the next caller forgets. The
/// journal is the sharpest case, not the only one — a bundle's manifest maps
/// its parts to files, so a torn manifest is the whole document.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

import 'support/scratch.dart';

void main() {
  late Directory dir;
  late TomDirectoryBundleMedium medium;

  setUp(() {
    dir = scratchDirectory('atomic').createTempSync('medium-');
    medium = TomDirectoryBundleMedium(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Every file actually on disk, temps included — what `listFiles` hides.
  List<String> onDisk() =>
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.substring(dir.path.length + 1))
          .toList()
        ..sort();

  // ───────────────────────────────────────────────────────────────────────
  group('A1 the write never leaves the target torn', () {
    test(
      'STORAGE-MEDIUM-A1: no temp file survives a completed write [0923]',
      () async {
        await medium.writeString(
          '.webwork/commit-journal.yaml',
          'entries: []\n',
        );
        await medium.writeString(
          '.webwork/commit-journal.yaml',
          'entries: [a]\n',
        );

        expect(
          await medium.readString('.webwork/commit-journal.yaml'),
          'entries: [a]\n',
        );
        expect(
          onDisk(),
          ['.webwork/commit-journal.yaml'],
          reason: 'the temp is renamed over the target, not left beside it',
        );
      },
    );

    test(
      'STORAGE-MEDIUM-A2: the target is replaced, never appended to [0923]',
      () async {
        // The shape of the bug this closes: a shorter second write over a longer
        // first one must not leave the first one\'s tail behind.
        await medium.writeString('notes.webwork.yaml', 'a' * 4096);
        await medium.writeString('notes.webwork.yaml', 'short');
        expect(await medium.readString('notes.webwork.yaml'), 'short');
      },
    );

    test('STORAGE-MEDIUM-A3: a write into a directory that does not exist yet '
        'still works [0923]', () async {
      await medium.writeString('.history/7f3c/2026.webwork.yaml', 'id: 7f3c\n');
      expect(
        await medium.readString('.history/7f3c/2026.webwork.yaml'),
        'id: 7f3c\n',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('A2 an interrupted write leaves nothing that can be mistaken for a '
      'bundle file', () {
    test(
      'STORAGE-MEDIUM-A4: a stale temp is invisible to listFiles [0923]',
      () async {
        // What a crash mid-write leaves behind. It must not appear as a section
        // file: a stray entry in the file list is exactly the failure an
        // interrupted write would otherwise cause *after* the interruption.
        await medium.writeString('notes.webwork.yaml', 'id: notes\n');
        File(
          '${dir.path}/notes.webwork.yaml.99.0'
          '${TomDirectoryBundleMedium.tempSuffix}',
        ).writeAsStringSync('half a fi');

        expect(onDisk(), hasLength(2), reason: 'the temp really is there');
        expect(await medium.listFiles(), ['notes.webwork.yaml']);
      },
    );

    test(
      'STORAGE-MEDIUM-A5: and the last complete state still reads [0923]',
      () async {
        // The DONE-WHEN, at the journal level: a fresh journal over the same
        // medium reads what the last *completed* write left.
        final journal = TomMediumCommitJournal(medium: medium);
        await journal.append(
          locator: 'a.webwork',
          changeset: TomChangeset.singleFile(
            Uint8List.fromList(utf8.encode('doc')),
          ),
          baseHead: 'head-1',
          version: 1,
        );

        // Interrupted: a temp beside the journal, from a write that died.
        final journalPath = '${dir.path}/${TomMediumCommitJournal.path}';
        File(
          '$journalPath.99.0${TomDirectoryBundleMedium.tempSuffix}',
        ).writeAsStringSync('entries:\n  - locator: a.web');

        final reopened = TomMediumCommitJournal(medium: medium);
        final pending = await reopened.pending();
        expect(pending, hasLength(1));
        expect(pending.single.locator, 'a.webwork');
        expect(pending.single.baseHead, 'head-1');
      },
    );

    test(
      'STORAGE-MEDIUM-A6: the next write to the same path sweeps it [0923]',
      () async {
        // Left to accumulate, a crash-left temp lives for ever — "invisible but
        // growing" is a leak whether or not anything reads it. Swept *before*
        // this write creates its own, so any temp for this target is provably
        // from a write that has already finished or died.
        await medium.writeString('notes.webwork.yaml', 'first');
        final stale = File(
          '${dir.path}/notes.webwork.yaml.99.0'
          '${TomDirectoryBundleMedium.tempSuffix}',
        )..writeAsStringSync('half');
        final other = File(
          '${dir.path}/other.webwork.yaml.99.0'
          '${TomDirectoryBundleMedium.tempSuffix}',
        )..writeAsStringSync('half');

        await medium.writeString('notes.webwork.yaml', 'second');

        expect(stale.existsSync(), isFalse);
        expect(
          other.existsSync(),
          isTrue,
          reason:
              'only temps for the path being written are swept — another '
              'target\'s temp may belong to a write still in flight',
        );
        expect(await medium.readString('notes.webwork.yaml'), 'second');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  group('A3 moving is a rename, not a copy', () {
    test('STORAGE-MEDIUM-A9: the file lands whole and leaves nothing behind '
        '[0923]', () async {
      // The base class's default is a copy and a delete, which is neither
      // atomic nor free: retiring a asset into `.history/.assets/`
      // would pull the whole asset through memory to move a file a few inches.
      final bytes = Uint8List.fromList(List.generate(8192, (i) => i % 256));
      await medium.writeBytes('assets/abc.png', bytes);

      await medium.move('assets/abc.png', '.history/.assets/abc.png');

      expect(await medium.exists('assets/abc.png'), isFalse);
      expect(
        await medium.readBytes('.history/.assets/abc.png'),
        bytes,
        reason: 'byte-for-byte — a snapshot of an asset is the asset',
      );
      expect(onDisk(), ['.history/.assets/abc.png']);
    });

    test(
      'STORAGE-MEDIUM-A10: it creates the directory it moves into [0923]',
      () async {
        await medium.writeString('notes.webwork.yaml', 'id: notes\n');
        await medium.move(
          'notes.webwork.yaml',
          '.history/notes/2026.webwork.yaml',
        );
        expect(
          await medium.readString('.history/notes/2026.webwork.yaml'),
          'id: notes\n',
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  group('A4 the journal itself', () {
    test(
      'STORAGE-MEDIUM-A7: every mutation goes through the atomic write [0923]',
      () async {
        // `append`, `complete`, `completeAll` and `clear` all rewrite the whole
        // file, so each is a moment the old contract could tear. Asserted by the
        // absence of debris rather than by counting calls: a medium that fell
        // back to a direct write would leave the same file, but a medium that
        // wrote a temp and failed to rename would leave two.
        final journal = TomMediumCommitJournal(medium: medium);
        final changeset = TomChangeset.singleFile(
          Uint8List.fromList(utf8.encode('doc')),
        );

        final first = await journal.append(
          locator: 'a.webwork',
          changeset: changeset,
          baseHead: 'h1',
          version: 1,
        );
        await journal.append(
          locator: 'b.webwork',
          changeset: changeset,
          baseHead: 'h2',
          version: 1,
        );
        await journal.complete(first.sequence);
        expect(((await journal.pending())).single.locator, 'b.webwork');

        await journal.completeAll('b.webwork');
        expect(await journal.pending(), isEmpty);

        expect(
          onDisk().where(
            (f) => f.endsWith(TomDirectoryBundleMedium.tempSuffix),
          ),
          isEmpty,
        );
      },
    );

    test('STORAGE-MEDIUM-A8: a journal that drained leaves no file to misread '
        '[0923]', () async {
      final journal = TomMediumCommitJournal(medium: medium);
      await journal.append(
        locator: 'a.webwork',
        changeset: TomChangeset.singleFile(
          Uint8List.fromList(utf8.encode('doc')),
        ),
        baseHead: 'h1',
        version: 1,
      );
      await journal.clear();

      expect(await medium.listFiles(), isEmpty);
      expect(await TomMediumCommitJournal(medium: medium).pending(), isEmpty);
    });
  });
}
