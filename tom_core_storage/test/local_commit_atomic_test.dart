/// A local `commit` is atomic for a multi-file changeset.
///
/// Every write is staged as a temp, one intent file records the renames and
/// deletes (the commit point), and only then are they applied. A crash before
/// the intent leaves the container untouched; a crash after it is finished by
/// the next access, reads included. `headOf` never counts a temp, and the next
/// commit sweeps the temps a crashed one left behind.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

import 'support/scratch.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

class _Crash implements Exception {
  final TomLocalCommitStep step;
  _Crash(this.step);
}

/// A probe that throws at the [nth] occurrence of [step].
TomLocalCommitProbe _crashAt(TomLocalCommitStep step, {int nth = 1}) {
  var seen = 0;
  return (at) {
    if (at == step && ++seen == nth) throw _Crash(at);
  };
}

void main() {
  late Directory scratch;
  late String locator;

  setUp(() {
    final root = scratchDirectory('woneqr36');
    scratch = root.createTempSync('local-commit-');
    locator = p.join(scratch.path, 'doc.webwork');
  });
  tearDown(() {
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  /// A container holding `a`, `b` and `old`, at revision 1.
  Future<String> seed(TomLocalFileSystemStorage storage) => storage.commit(
    locator,
    TomChangeset(
      writes: {
        'webwork.yaml': _b('manifest 1'),
        'a.yaml': _b('a 1'),
        'nested/b.yaml': _b('b 1'),
        'old.yaml': _b('old'),
      },
    ),
  );

  TomChangeset revision2() => TomChangeset(
    writes: {
      'webwork.yaml': _b('manifest 2'),
      'a.yaml': _b('a 2'),
      'nested/b.yaml': _b('b 2'),
    },
    deletes: {'old.yaml'},
  );

  Map<String, String> contents() => {
    for (final f in Directory(
      locator,
    ).listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: locator).replaceAll(r'\', '/'): f
          .readAsStringSync(),
  };

  const before = {
    'webwork.yaml': 'manifest 1',
    'a.yaml': 'a 1',
    'nested/b.yaml': 'b 1',
    'old.yaml': 'old',
  };
  const after = {
    'webwork.yaml': 'manifest 2',
    'a.yaml': 'a 2',
    'nested/b.yaml': 'b 2',
  };

  test(
    'STORAGE-LOCAL-B1: a failure between staging and the commit point leaves '
    'the container and its head untouched, and no temp behind [1002]',
    () async {
      const plain = TomLocalFileSystemStorage();
      final head = await seed(plain);

      final crashing = TomLocalFileSystemStorage(
        probe: _crashAt(TomLocalCommitStep.staged),
      );
      await expectLater(
        crashing.commit(locator, revision2(), expectedHead: head),
        throwsA(isA<_Crash>()),
      );

      expect(contents(), before);
      expect(await plain.headOf(locator), head);
    },
  );

  test(
    'STORAGE-LOCAL-B2: a crash midway through the renames is finished by the '
    'next read — a reader sees the whole new container, never a mixture '
    '[1002]',
    () async {
      const plain = TomLocalFileSystemStorage();
      final head = await seed(plain);

      // Dies after the first of three renames, with the intent recorded.
      final crashing = TomLocalFileSystemStorage(
        probe: _crashAt(TomLocalCommitStep.renamed),
      );
      await expectLater(
        crashing.commit(locator, revision2(), expectedHead: head),
        throwsA(isA<_Crash>()),
      );
      // On disk right now: one target renamed, two still staged, the delete
      // not applied — the state a crash leaves.
      expect(
        File(
          p.join(locator, TomLocalFileSystemStorage.intentName),
        ).existsSync(),
        isTrue,
      );

      // A fresh process reads it.
      final bundle = await plain.readBundle(locator);
      expect(await bundle.listFiles(), after.keys.toList()..sort());
      for (final entry in after.entries) {
        expect(await bundle.readString(entry.key), entry.value);
      }
      expect(contents(), after, reason: 'no temp and no intent remain');
    },
  );

  test(
    'STORAGE-LOCAL-B3: a crash right at the commit point is rolled forward by '
    'headOf, and the next commit lands on the recovered head [1002]',
    () async {
      const plain = TomLocalFileSystemStorage();
      final head = await seed(plain);
      final crashing = TomLocalFileSystemStorage(
        probe: _crashAt(TomLocalCommitStep.recorded),
      );
      await expectLater(
        crashing.commit(locator, revision2(), expectedHead: head),
        throwsA(isA<_Crash>()),
      );
      final recovered = await plain.headOf(locator);
      expect(recovered, isNot(head));
      expect(contents(), after);

      final next = await plain.commit(
        locator,
        TomChangeset(writes: {'a.yaml': _b('a 3')}),
        expectedHead: recovered,
      );
      expect(next, isNot(recovered));
      expect(File(p.join(locator, 'a.yaml')).readAsStringSync(), 'a 3');
    },
  );

  test(
    'STORAGE-LOCAL-B4: headOf and list ignore a stray temp, and the next commit '
    'sweeps it [1002]',
    () async {
      const plain = TomLocalFileSystemStorage();
      final head = await seed(plain);

      // What a process killed during staging leaves: temps, no intent.
      final stray = File(
        p.join(locator, 'a.yaml${TomLocalFileSystemStorage.tempSuffix}'),
      )..writeAsStringSync('half a write');
      File(
        p.join(
          locator,
          'nested/new.yaml${TomLocalFileSystemStorage.tempSuffix}',
        ),
      ).writeAsStringSync('never committed');

      expect(
        await plain.headOf(locator),
        head,
        reason: 'a temp is not part of the container',
      );
      final listed = (await plain.list(locator)).map((e) => e.path).toList();
      expect(listed.where((path) => path.endsWith('.tom-tmp')), isEmpty);
      expect(
        await (await plain.readBundle(locator)).listFiles(),
        before.keys.toList()..sort(),
      );

      await plain.commit(
        locator,
        TomChangeset(writes: {'webwork.yaml': _b('manifest 2')}),
        expectedHead: head,
      );
      expect(stray.existsSync(), isFalse);
      expect(
        Directory(
          locator,
        ).listSync(recursive: true).where((e) => e.path.endsWith('.tom-tmp')),
        isEmpty,
      );
    },
  );

  test('STORAGE-LOCAL-B5: a single-file commit is one rename, and a stray temp '
      'beside the file is swept [1002]', () async {
    const plain = TomLocalFileSystemStorage();
    final file = p.join(scratch.path, 'notes.webwork.yaml');
    final head = await plain.commit(file, TomChangeset.singleFile(_b('one')));
    final stray = File('$file${TomLocalFileSystemStorage.tempSuffix}')
      ..writeAsStringSync('torn');
    expect(await plain.headOf(file), head);

    await plain.commit(
      file,
      TomChangeset.singleFile(_b('two')),
      expectedHead: head,
    );
    expect(File(file).readAsStringSync(), 'two');
    expect(stray.existsSync(), isFalse);
  });
}
