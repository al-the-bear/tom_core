/// The key port: material, the in-memory registry and the in-memory store.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_settings/tom_core_settings.dart';

void main() {
  group('SETTINGS-KEYS material', () {
    test('SETTINGS-KEYS-1: a passphrase or key-file bytes resolve; a key-file '
        'pointer alone does not, and is not empty either', () {
      expect(const TomKeyMaterial(passphrase: 'p').isResolvable, isTrue);
      expect(
        TomKeyMaterial(keyFileBytes: Uint8List.fromList([1])).isResolvable,
        isTrue,
      );
      const pointer = TomKeyMaterial(keyFileLocator: '/keys/a.key');
      expect(pointer.isResolvable, isFalse);
      expect(pointer.isEmpty, isFalse);
      expect(const TomKeyMaterial().isEmpty, isTrue);
      expect(const TomKeyMaterial(passphrase: '').isEmpty, isTrue);
    });

    test('SETTINGS-KEYS-2: unresolvable material is refused in one sentence '
        'per case', () {
      expect(
        () => const TomKeyMaterial().requireResolvable(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'A key needs a passphrase and/or a key file.',
          ),
        ),
      );
      expect(
        () => const TomKeyMaterial(
          keyFileLocator: '/keys/a.key',
        ).requireResolvable(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('/keys/a.key'),
          ),
        ),
      );
    });

    test('SETTINGS-KEYS-3: copyWith keeps what it is not given', () {
      const material = TomKeyMaterial(passphrase: 'p', keyFileLocator: '/k');
      final copy = material.copyWith(passphrase: 'q');
      expect(copy.passphrase, 'q');
      expect(copy.keyFileLocator, '/k');
    });
  });

  group('SETTINGS-KEYS registry', () {
    test('SETTINGS-KEYS-4: default and per-file keys register and clear', () {
      final registry = TomMemoryKeyRegistry();
      expect(registry.hasDefault, isFalse);
      registry.registerDefault(const TomKeyMaterial(passphrase: 'd'));
      expect(registry.hasDefault, isTrue);
      registry.registerKeyFor('a', const TomKeyMaterial(passphrase: 'a'));
      expect(registry.hasOverrideFor('a'), isTrue);
      expect(registry.overriddenLocators, ['a']);
      registry.removeKeyFor('a');
      expect(registry.hasOverrideFor('a'), isFalse);
      registry.registerDefault(null);
      expect(registry.hasDefault, isFalse);
    });

    test('SETTINGS-KEYS-5: a second scope is empty and of the same binding, '
        'and unresolvable material is refused', () {
      final registry = TomMemoryKeyRegistry()
        ..registerKeyFor('a', const TomKeyMaterial(passphrase: 'a'));
      final scope = registry.newScope();
      expect(scope, isA<TomMemoryKeyRegistry>());
      expect(scope.overriddenLocators, isEmpty);
      expect(
        () => scope.registerKeyFor('b', const TomKeyMaterial()),
        throwsStateError,
      );
      expect(
        () => scope.registerDefault(const TomKeyMaterial()),
        throwsStateError,
      );
    });
  });

  test('SETTINGS-KEYS-6: the in-memory store keeps both defaults and the '
      'overrides apart', () async {
    final store = TomInMemoryKeyStore();
    await store.saveDefaultKey(const TomKeyMaterial(passphrase: 'doc'));
    await store.saveCollaborationDefaultKey(
      const TomKeyMaterial(passphrase: 'collab'),
    );
    await store.saveOverride('a', const TomKeyMaterial(passphrase: 'a'));
    expect((await store.loadDefaultKey())!.passphrase, 'doc');
    expect((await store.loadCollaborationDefaultKey())!.passphrase, 'collab');
    final overrides = await store.loadOverrides();
    expect(overrides.keys, ['a']);
    overrides.clear();
    expect((await store.loadOverrides()).keys, [
      'a',
    ], reason: 'a caller gets a copy');
    await store.removeOverride('a');
    expect(await store.loadOverrides(), isEmpty);
  });

  test('SETTINGS-KEYS-7: the in-memory location registry keys by locator and '
      'says it persisted nothing', () async {
    final registry = TomInMemoryLocationRegistry();
    expect(
      await registry.register(
        const TomStorageLocation(displayName: 'notes', locator: 'a'),
      ),
      isFalse,
    );
    await registry.register(
      const TomStorageLocation(displayName: 'notes', locator: 'b'),
    );
    await registry.register(
      const TomStorageLocation(displayName: 'renamed', locator: 'a'),
    );
    expect(registry.locations.map((l) => '${l.displayName}@${l.locator}'), [
      'renamed@a',
      'notes@b',
    ]);
    expect(await registry.forget('a'), isFalse);
    expect(registry.locations.single.locator, 'b');
  });

  test('SETTINGS-KEYS-8: identity: the unknown sentinel attributes nothing, '
      'and equality is by both fields', () {
    expect(TomIdentity.unknown.isUnknown, isTrue);
    expect(TomIdentity.attributionOf(TomIdentity.unknownAuthorId), isNull);
    expect(TomIdentity.attributionOf('alice'), 'alice');
    const alice = TomIdentity(displayName: 'Alice', authorId: 'alice');
    expect(alice.copyWith(displayName: 'Al').authorId, 'alice');
    expect(alice, const TomIdentity(displayName: 'Alice', authorId: 'alice'));
    expect(alice, isNot(alice.copyWith(displayName: 'Al')));
  });
}
