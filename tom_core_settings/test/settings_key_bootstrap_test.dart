/// The one-secret bootstrap: a device's settings key is minted once, kept in
/// the secret store, and found again by the handle device settings record.
library;

import 'package:test/test.dart';
import 'package:tom_core_storage/testing.dart';
import 'package:tom_core_settings/tom_core_settings.dart';

const _deviceLocator = 'mem:/support/device.yaml';

/// A keychain the process cannot reach: a write always throws the platform's
/// own error, and a read does unless [readFails] is false.
class _DeniedSecretStore implements TomSecretStore {
  _DeniedSecretStore({this.readFails = true});

  final bool readFails;
  final written = <String, String>{};

  @override
  Future<String?> read(String handle) async {
    if (readFails) throw StateError('keychain denied: read');
    return written[handle];
  }

  @override
  Future<void> write(String handle, String secret) async {
    throw StateError('keychain denied: write');
  }

  @override
  Future<void> delete(String handle) async => written.remove(handle);
}

class _Typed implements TomSecretStore {
  @override
  Future<String?> read(String handle) async =>
      throw const TomSecretStoreException(TomSecretStoreStep.read, 'original');

  @override
  Future<void> write(String handle, String secret) async {}

  @override
  Future<void> delete(String handle) async {}
}

void main() {
  late TomMemoryStorage storage;

  setUp(() => storage = TomMemoryStorage(TomMemoryRemote()));

  TomDeviceSettings device() =>
      TomDeviceSettings(locator: _deviceLocator, storage: storage);

  TomSettingsKeyBootstrap bootstrapWith(TomSecretStore secrets) =>
      TomSettingsKeyBootstrap(device: device(), secrets: secrets);

  test('SETTINGS-BOOT-1: a first run mints a secret, stores it under a new '
      'handle and records the handle', () async {
    final secrets = TomInMemorySecretStore();
    final key = await bootstrapWith(secrets).ensure();
    expect(key.secret, isNotEmpty);
    expect(await secrets.read(key.handle), key.secret);

    final reread = device();
    await reread.load();
    expect(reread.settingsKeyHandle, key.handle);
  });

  test('SETTINGS-BOOT-2: a second run finds the same key and commits '
      'nothing', () async {
    final secrets = TomInMemorySecretStore();
    final first = await bootstrapWith(secrets).ensure();
    final commits = storage.remote.commits.length;
    final second = await bootstrapWith(secrets).ensure();
    expect(second, first);
    expect(storage.remote.commits.length, commits);
  });

  test('SETTINGS-BOOT-3: a wiped keychain re-mints the secret under the same '
      'handle', () async {
    final secrets = TomInMemorySecretStore();
    final first = await bootstrapWith(secrets).ensure();
    await secrets.clear();
    final second = await bootstrapWith(secrets).ensure();
    expect(second.handle, first.handle);
    expect(second.secret, isNot(first.secret));
  });

  test(
    'SETTINGS-BOOT-4: a read that throws is raised as a secret-store '
    'failure naming the read, with the cause, and nothing is minted',
    () async {
      final secrets = _DeniedSecretStore();
      await expectLater(
        bootstrapWith(secrets).ensure(),
        throwsA(
          isA<TomSecretStoreException>()
              .having((e) => e.step, 'step', TomSecretStoreStep.read)
              .having((e) => e.cause, 'cause', isA<StateError>()),
        ),
      );
      expect(
        secrets.written,
        isEmpty,
        reason: 'a read that failed is not a miss; nothing is minted over it',
      );
    },
  );

  test(
    'SETTINGS-BOOT-5: a write that throws is raised naming the write, and '
    'the device file records no handle for a secret that did not land',
    () async {
      final secrets = _DeniedSecretStore(readFails: false);
      await expectLater(
        bootstrapWith(secrets).ensure(),
        throwsA(
          isA<TomSecretStoreException>().having(
            (e) => e.step,
            'step',
            TomSecretStoreStep.write,
          ),
        ),
      );
      final reread = device();
      await reread.load();
      expect(
        reread.settingsKeyHandle,
        isNull,
        reason:
            'the handle is committed after the secret, so a secret the '
            'store refused leaves no handle pointing at nothing',
      );
    },
  );

  test('SETTINGS-BOOT-6: a store that already throws the typed failure is '
      'passed through, not wrapped twice', () async {
    await expectLater(
      bootstrapWith(_Typed()).ensure(),
      throwsA(
        isA<TomSecretStoreException>().having(
          (e) => e.cause,
          'cause',
          'original',
        ),
      ),
    );
  });

  test('SETTINGS-BOOT-7: the failure names its step and the cause\'s type, '
      'never the cause\'s text', () {
    const failure = TomSecretStoreException(
      TomSecretStoreStep.read,
      'secret-looking text',
    );
    expect(failure.toString(), 'TomSecretStoreException(read: String)');
  });
}
