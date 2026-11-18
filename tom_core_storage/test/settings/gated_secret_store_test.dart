/// The gated secret store's contract as its in-memory double keeps it: a
/// miss reads null without a prompt, a read prompts with its reason, a
/// failure is an exception of its kind (never a miss), and nothing is
/// written where no OS check can gate it.
library;

import 'package:test/test.dart';
import 'package:tom_core_storage/settings.dart';

void main() {
  test('a miss reads null without a prompt; a read prompts with its reason; '
      'delete forgets', () async {
    final store = TomInMemoryGatedSecretStore();
    expect(await store.read('h', reason: 'unlock'), isNull);
    expect(store.prompts, isEmpty);
    await store.write('h', 'demo-bundle', lifetime: TomGatedLifetime.session);
    expect(store.lifetimeOf('h'), TomGatedLifetime.session);
    expect(await store.read('h', reason: 'unlock the vault'), 'demo-bundle');
    expect(store.prompts, ['unlock the vault']);
    await store.delete('h');
    expect(await store.read('h', reason: 'unlock'), isNull);
  });

  test('a cancelled, locked-out or invalidated check is an exception of its '
      'kind, which names no secret', () async {
    final store = TomInMemoryGatedSecretStore();
    await store.write('h', 'demo-bundle');
    for (final kind in [
      TomGatedSecretErrorKind.cancelled,
      TomGatedSecretErrorKind.lockedOut,
      TomGatedSecretErrorKind.invalidated,
    ]) {
      store.nextFailure = kind;
      await expectLater(
        store.read('h', reason: 'unlock'),
        throwsA(
          isA<TomGatedSecretStoreException>()
              .having((e) => e.kind, 'kind', kind)
              .having((e) => '$e', 'text', isNot(contains('demo'))),
        ),
      );
    }
    expect(await store.read('h', reason: 'unlock'), 'demo-bundle');
  });

  test('without an OS check nothing is written or read', () async {
    final store = TomInMemoryGatedSecretStore(
      available: TomGatedAvailability.none,
    );
    expect(await store.availability(), TomGatedAvailability.none);
    await expectLater(
      store.write('h', 'demo-bundle'),
      throwsA(
        isA<TomGatedSecretStoreException>().having(
          (e) => e.kind,
          'kind',
          TomGatedSecretErrorKind.unavailable,
        ),
      ),
    );
  });
}
