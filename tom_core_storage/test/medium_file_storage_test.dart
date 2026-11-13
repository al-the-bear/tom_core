/// TomMediumFileStorage: single-file containers on a keyed medium, with a
/// compare-and-swap by content (the browser's settings container).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_basics/utilities.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

Uint8List _b(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  late TomMemoryBundleMedium medium;
  late TomMediumFileStorage storage;
  const locator = 'browser:settings.webwork.kdbx';

  setUp(() {
    medium = TomMemoryBundleMedium();
    storage = TomMediumFileStorage(medium: medium, prefix: 'browser:');
  });

  test('1: handles its own prefix only', () {
    expect(storage.handles(locator), isTrue);
    expect(storage.handles('github:o/r/x'), isFalse);
  });

  test('2: an absent container has no head and is not found', () async {
    expect(await storage.headOf(locator), isNull);
    await expectLater(
      storage.readBytes(locator),
      throwsA(isA<TomContainerNotFoundException>()),
    );
  });

  test(
    '3: a commit stores the bytes under the key and answers their hash',
    () async {
      final head = await storage.commit(
        locator,
        TomChangeset.singleFile(_b('one')),
      );
      expect(head, tomSha256Hex(_b('one')));
      expect(await storage.headOf(locator), head);
      expect(await storage.readBytes(locator), _b('one'));
      expect(await medium.readBytes('settings.webwork.kdbx'), _b('one'));
    },
  );

  test('4: a stale expected head is refused and nothing is written', () async {
    final first = await storage.commit(
      locator,
      TomChangeset.singleFile(_b('one')),
    );
    await storage.commit(
      locator,
      TomChangeset.singleFile(_b('two')),
      expectedHead: first,
    );
    await expectLater(
      storage.commit(
        locator,
        TomChangeset.singleFile(_b('three')),
        expectedHead: first,
      ),
      throwsA(isA<TomCasConflictException>()),
    );
    expect(await storage.readBytes(locator), _b('two'));
  });

  test('5: creating over an existing container is refused', () async {
    await storage.commit(locator, TomChangeset.singleFile(_b('one')));
    await expectLater(
      storage.commit(locator, TomChangeset.singleFile(_b('again'))),
      throwsA(isA<TomCasConflictException>()),
    );
  });

  test('6: a bundle changeset and a bundle read are refused', () async {
    await expectLater(
      storage.commit(locator, TomChangeset(writes: {'a.yaml': _b('a')})),
      throwsA(isA<TomStorageException>()),
    );
    await expectLater(
      storage.readBundle(locator),
      throwsA(isA<TomStorageException>()),
    );
  });

  test('7: delete removes the container; list names what is kept', () async {
    await storage.commit(locator, TomChangeset.singleFile(_b('one')));
    await storage.commit(
      'browser:other.kdbx',
      TomChangeset.singleFile(_b('x')),
    );
    expect(
      (await storage.list('browser:')).map((e) => e.path),
      containsAll([locator, 'browser:other.kdbx']),
    );
    await storage.delete(locator);
    expect(await storage.headOf(locator), isNull);
  });
}
