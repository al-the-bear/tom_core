/// `TomStorageFileSystem`: the files of a storage container as a
/// `TomFileSystem`, the shape an editor takes its storage in.
///
/// Every case runs over two tiers: the in-memory remote and the GitHub
/// backend against the GitHub test double, so the adapter is measured against
/// a backend that lists through trees and reads blobs lazily, not only
/// against a map.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/file_system.dart';
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/testing.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_github_api/testing.dart';
import 'package:tom_github_api/tom_github_api.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// A tier: a fresh backend and the locator of a container in it.
class _Tier {
  _Tier(this.name, this.open);

  final String name;
  final (TomStorage, String) Function() open;
}

final _tiers = [
  _Tier('memory', () => (TomMemoryStorage(TomMemoryRemote()), 'mem:docs')),
  _Tier('GitHub', () {
    final server = FakeGitHubServer()..repo('al-the-bear/docs');
    final storage = TomGitHubStorage.withClient(
      GitHubApiClient(
        token: 'test-token',
        httpClient: server.client,
        baseUrl: FakeGitHubServer.baseUrl,
        minMutativeInterval: Duration.zero,
      ),
    );
    return (storage, 'github:al-the-bear/docs/office');
  }),
];

void main() {
  for (final tier in _tiers) {
    group('STORAGE-FS over the ${tier.name} tier', () {
      late TomStorage storage;
      late String locator;
      late TomStorageFileSystem fs;

      setUp(() async {
        (storage, locator) = tier.open();
        fs = TomStorageFileSystem(storage, locator);
        // Two files, committed the way any writer of the container would.
        await storage.commit(
          locator,
          TomChangeset(
            writes: {
              'report.docx': _bytes('version 1'),
              'notes/todo.txt': _bytes('a\nb\nc\n'),
            },
          ),
          expectedHead: null,
        );
      });

      tearDown(() async {
        await fs.dispose();
        storage.close();
      });

      test('STORAGE-FS-01: an editor reads a file, saves it against the '
          'revision it read, and a save against a moved revision is refused '
          'with TomFileConflict', () async {
        final uri = fs.uriOf('report.docx');

        // Open.
        final opened = await fs.read(uri);
        expect(utf8.decode(opened.bytes), 'version 1');

        // Save, checked against what was read.
        final saved = await fs.write(
          uri,
          _bytes('version 2'),
          expected: opened.revision,
        );
        expect(saved, TomFileRevision.of(_bytes('version 2'), DateTime(0)));
        expect(utf8.decode((await fs.read(uri)).bytes), 'version 2');

        // Somebody else saves the file through the storage itself.
        await storage.commit(
          locator,
          TomChangeset(writes: {'report.docx': _bytes('their version')}),
          expectedHead: await storage.headOf(locator),
        );

        // The editor's next save still names the revision it wrote.
        await expectLater(
          fs.write(uri, _bytes('version 3'), expected: saved),
          throwsA(
            isA<TomFileConflict>().having(
              (c) => c.current,
              'current',
              TomFileRevision.of(_bytes('their version'), DateTime(0)),
            ),
          ),
        );
        expect(
          utf8.decode((await fs.read(uri)).bytes),
          'their version',
          reason: 'a refused save writes nothing',
        );
      });

      test('STORAGE-FS-02: a change to another file of the container is no '
          'conflict: the save is retried against the new head', () async {
        final uri = fs.uriOf('report.docx');
        final opened = await fs.read(uri);

        await storage.commit(
          locator,
          TomChangeset(writes: {'notes/todo.txt': _bytes('changed')}),
          expectedHead: await storage.headOf(locator),
        );

        await fs.write(uri, _bytes('mine'), expected: opened.revision);
        expect(utf8.decode((await fs.read(uri)).bytes), 'mine');
        expect(await fs.readText(fs.uriOf('notes/todo.txt')), 'changed');
      });

      test('STORAGE-FS-03: a file deleted since it was read is a conflict '
          'with no current revision', () async {
        final uri = fs.uriOf('report.docx');
        final opened = await fs.read(uri);
        await storage.commit(
          locator,
          TomChangeset(deletes: {'report.docx'}),
          expectedHead: await storage.headOf(locator),
        );
        await expectLater(
          fs.write(uri, _bytes('x'), expected: opened.revision),
          throwsA(
            isA<TomFileConflict>().having((c) => c.current, 'current', isNull),
          ),
        );
      });

      test('STORAGE-FS-04: listing shows the files and the folders their '
          'paths imply, one level at a time', () async {
        final top = await fs.list(fs.root);
        expect(
          {for (final e in top) e.name: e.kind},
          {
            'report.docx': TomFileEntryKind.file,
            'notes': TomFileEntryKind.directory,
          },
        );
        final notes = await fs.list(fs.uriOf('notes/'));
        expect(notes.single.path, 'notes/todo.txt');
        expect((await fs.stat(fs.uriOf('notes')))!.isDirectory, isTrue);
        expect(await fs.stat(fs.uriOf('missing.txt')), isNull);
        expect(await fs.exists(fs.uriOf('report.docx')), isTrue);
      });

      test('STORAGE-FS-05: a new file is written, created, renamed and '
          'deleted, each as one commit', () async {
        await fs.writeText(fs.uriOf('drafts/new.txt'), 'draft');
        expect(await fs.readText(fs.uriOf('drafts/new.txt')), 'draft');

        await fs.create(fs.uriOf('empty.txt'));
        expect((await fs.read(fs.uriOf('empty.txt'))).bytes, isEmpty);
        await expectLater(
          fs.create(fs.uriOf('empty.txt')),
          throwsA(isA<TomFileSystemException>()),
        );

        await fs.rename(fs.uriOf('drafts'), fs.uriOf('final'));
        expect(await fs.exists(fs.uriOf('drafts/new.txt')), isFalse);
        expect(await fs.readText(fs.uriOf('final/new.txt')), 'draft');

        await fs.delete(fs.uriOf('final'));
        expect(await fs.exists(fs.uriOf('final/new.txt')), isFalse);
        expect(await fs.exists(fs.uriOf('report.docx')), isTrue);
      });

      test('STORAGE-FS-06: watch and trash are not supported', () async {
        expect(fs.watch(), isNull);
        expect(await fs.trash(fs.uriOf('report.docx')), isFalse);
        expect(await fs.exists(fs.uriOf('report.docx')), isTrue);
      });

      test('STORAGE-FS-07: a tail slice of a file, cut at a line', () async {
        expect(
          await fs.readSlice(
            fs.uriOf('notes/todo.txt'),
            maxBytes: 3,
            fromEnd: true,
          ),
          'c\n',
        );
      });
    });
  }

  group('STORAGE-FS-09 a commit that loses the race', () {
    /// A memory device on which another writer's change lands between the
    /// head the adapter reads and the commit it makes.
    late TomMemoryRemote remote;
    late _RacingStorage storage;
    late TomStorageFileSystem fs;

    setUp(() async {
      remote = TomMemoryRemote();
      storage = _RacingStorage(remote);
      remote.apply(
        'mem:docs',
        TomChangeset(
          writes: {'report.docx': _bytes('v1'), 'other.txt': _bytes('o')},
        ),
        null,
      );
      fs = TomStorageFileSystem(storage, 'mem:docs');
    });

    test('to a change of another file is retried and lands', () async {
      final opened = await fs.read(fs.uriOf('report.docx'));
      storage.raceWith = {'other.txt': _bytes('theirs')};
      await fs.write(
        fs.uriOf('report.docx'),
        _bytes('mine'),
        expected: opened.revision,
      );
      expect(storage.conflicts, 1, reason: 'the first commit lost the race');
      expect(remote.textSnapshot('mem:docs'), {
        'report.docx': 'mine',
        'other.txt': 'theirs',
      });
    });

    test('to a change of the same file is a TomFileConflict', () async {
      final opened = await fs.read(fs.uriOf('report.docx'));
      storage.raceWith = {'report.docx': _bytes('theirs')};
      await expectLater(
        fs.write(
          fs.uriOf('report.docx'),
          _bytes('mine'),
          expected: opened.revision,
        ),
        throwsA(isA<TomFileConflict>()),
      );
      expect(remote.textSnapshot('mem:docs')['report.docx'], 'theirs');
    });
  });

  test('STORAGE-FS-08: a container that does not exist yet is an empty '
      'folder, and the first write creates it', () async {
    final storage = TomMemoryStorage(TomMemoryRemote());
    final fs = TomStorageFileSystem(storage, 'mem:new');
    expect(await fs.list(fs.root), isEmpty);
    await fs.writeText(fs.uriOf('a.txt'), 'a');
    expect(await storage.headOf('mem:new'), isNotNull);
    expect(await fs.readText(fs.uriOf('a.txt')), 'a');
  });
}

/// [TomMemoryStorage] that, once armed with [raceWith], commits those writes
/// as another writer right after answering the next head.
class _RacingStorage extends TomMemoryStorage {
  _RacingStorage(super.remote);

  Map<String, Uint8List>? raceWith;
  int conflicts = 0;

  @override
  Future<String?> headOf(String locator) async {
    final head = await super.headOf(locator);
    final race = raceWith;
    if (race != null) {
      raceWith = null;
      remote.apply(locator, TomChangeset(writes: race), 'another writer');
    }
    return head;
  }

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async {
    try {
      return await super.commit(
        locator,
        changeset,
        expectedHead: expectedHead,
        message: message,
        onProgress: onProgress,
      );
    } on TomCasConflictException {
      conflicts++;
      rethrow;
    }
  }
}
