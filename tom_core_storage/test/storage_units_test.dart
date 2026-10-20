/// The platform-neutral parts of the package, each on its own: the in-memory
/// and read-only media, the commit journal over a medium, Git-LFS pointer
/// refusal, object ceilings, location prefixes, and the cache cipher.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_storage/cipher.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

class _Keys implements TomCacheKeyStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String handle) async => values[handle];
  @override
  Future<void> write(String handle, String value) async =>
      values[handle] = value;
}

void main() {
  group('STORAGE-MEDIUM media', () {
    test(
      'STORAGE-MEDIUM-1: a memory medium round-trips through its ZIP form',
      () async {
        final medium = TomMemoryBundleMedium.fromText({
          'a.yaml': 'a: 1',
          'nested/b.yaml': 'b: 2',
        });
        final back = TomMemoryBundleMedium.fromZip(medium.toZip());
        expect(await back.listFiles(), ['a.yaml', 'nested/b.yaml']);
        expect(await back.readString('nested/b.yaml'), 'b: 2');
      },
    );

    test(
      'STORAGE-MEDIUM-2: a read-only medium reads and refuses writes',
      () async {
        final view = TomReadOnlyBundleMedium(
          TomMemoryBundleMedium.fromText({'a': 'x'}),
        );
        expect(await view.readString('a'), 'x');
        await expectLater(view.writeString('a', 'y'), throwsA(anything));
      },
    );

    test('STORAGE-MEDIUM-3: a recording medium leaves its base untouched and '
        'reports a changeset', () async {
      final base = TomMemoryBundleMedium.fromText({'a': 'x', 'gone': 'z'});
      final recording = TomRecordingBundleMedium(base);
      await recording.writeString('a', 'y');
      await recording.delete('gone');
      expect(await base.readString('a'), 'x');
      expect(await recording.readString('a'), 'y');
      final changeset = recording.changeset;
      expect(changeset.writes.keys, ['a']);
      expect(changeset.deletes, ['gone']);
    });
  });

  group('STORAGE-JOURNAL the commit journal over a medium', () {
    test('STORAGE-JOURNAL-1: an entry outlives the journal object and is gone '
        'once completed', () async {
      final medium = TomMemoryBundleMedium();
      final first = await TomMediumCommitJournal(medium: medium).append(
        locator: 'mem:/doc',
        changeset: TomChangeset.singleFile(_b('v1')),
        baseHead: null,
        version: 1,
      );
      final reopened = TomMediumCommitJournal(medium: medium);
      final pending = await reopened.pending();
      expect(pending.single.locator, 'mem:/doc');
      expect(utf8.decode(pending.single.changeset.containerBytes), 'v1');
      await reopened.complete(first.sequence);
      expect(await reopened.pending(), isEmpty);
      expect(
        await medium.exists(TomMediumCommitJournal.path),
        isFalse,
        reason: 'a drained journal leaves no file behind',
      );
    });
  });

  group('STORAGE-POLICY refusals and limits', () {
    test('STORAGE-POLICY-1: a Git-LFS pointer is refused by name, content '
        'passes', () {
      final pointer = _b(
        'version https://git-lfs.github.com/spec/v1\n'
        'oid sha256:${'a' * 64}\nsize 12345\n',
      );
      expect(TomLfsPointer.tryParse(pointer), isNotNull);
      expect(
        () => tomRefuseLfsPointer('loc', 'x.bin', pointer, remedy: 'Fetch it.'),
        throwsA(isA<TomLfsObjectException>()),
      );
      tomRefuseLfsPointer('loc', 'x.yaml', _b('a: 1'), remedy: 'n/a');
    });

    test('STORAGE-POLICY-2: the tighter of two ceilings applies', () {
      const ceiling = TomObjectCeiling(configured: 100, backend: 50);
      expect(ceiling.admits(50), isTrue);
      expect(ceiling.admits(51), isFalse);
      expect(
        () => ceiling.enforce(60, locator: 'loc', what: 'an image'),
        throwsA(isA<TomObjectTooLargeException>()),
      );
      expect(const TomObjectCeiling().admits(1 << 40), isTrue);
    });

    test('STORAGE-POLICY-3: a location covers a folder on a path boundary, '
        'and the longest one wins', () {
      expect(tomLocationCovers('/a/b', '/a/b/c'), isTrue);
      expect(tomLocationCovers('/a/b', '/a/bc'), isFalse);
      expect(tomLocationCovers('github:o/r:', 'github:o/r:docs'), isTrue);
      expect(tomLongestLocationPrefix({'/a': 1, '/a/b': 2}, '/a/b/c'), 2);
      expect(tomLongestLocationPrefix({'/x': 1}, '/a'), isNull);
    });
  });

  group('STORAGE-CIPHER the cache cipher', () {
    test('STORAGE-CIPHER-1: the device key is minted once and reused; a file '
        'opens only under its own key', () async {
      final keys = _Keys();
      final a = await TomAesGcmCacheCipher.forDevice(keys);
      final again = await TomAesGcmCacheCipher.forDevice(keys);
      expect(keys.values, hasLength(1));
      final sealed = await a.seal(_b('cached'));
      expect(utf8.decode(await again.open(sealed)), 'cached');

      final other = await TomAesGcmCacheCipher.forDevice(_Keys());
      await expectLater(other.open(sealed), throwsFormatException);
    });
  });
}
