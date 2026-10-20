/// How a device comes to hold the key of its encrypted settings container.
library;

import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'device_settings.dart';
import 'secret_store.dart';

/// The settings key a device holds: the [secret] and the [handle] the
/// platform secret store keeps it under.
typedef TomSettingsKey = ({String handle, String secret});

/// Ensures this device has a key for its encrypted settings container.
///
/// A chicken-and-egg problem with exactly one escape. The settings container
/// holds the tokens and document keys, so it must be encrypted — but its own
/// key cannot live inside it, and device settings must hold no secret. So
/// **one** secret is held per device, outside both: in the platform secret
/// store, with only its *handle* recorded in device settings.
///
/// Two consequences make the arrangement safe rather than merely workable:
///
/// - **The key is minted, not chosen.** There is no passphrase prompt at first
///   launch. A password invented for a file the user did not know existed is a
///   weak one, and the device already has somewhere better to keep a strong
///   one.
/// - **Losing it loses only the settings.** Documents have their own keys,
///   which is why a wiped keychain is survivable at all — and why the honest
///   response to one is a container that refuses to open rather than a fresh
///   empty one written over the user's settings.
///
/// Opening the container with the key is the container binding's business;
/// this class knows no container format.
class TomSettingsKeyBootstrap {
  /// How many random bytes a minted key is made of: 32, the same order as the
  /// container master key it protects.
  static const _secretBytes = 32;

  final TomDeviceSettings device;
  final TomSecretStore secrets;

  TomSettingsKeyBootstrap({required this.device, required this.secrets});

  /// The device's settings key, minted and recorded when it has none.
  ///
  /// Idempotent: a second run finds the handle and the secret and writes
  /// nothing. Device settings are committed **only when the handle changed**,
  /// which keeps an ordinary launch free of a pointless commit — and makes a
  /// wiped keychain re-mint only the *secret*. Re-minting the handle too would
  /// orphan a secret a restored keychain might bring back.
  ///
  /// **A secret store that fails raises [TomSecretStoreException]**, for
  /// either call, in place of what the store threw. A miss is an answer the
  /// store gives (null) and is handled by minting; a store that could not be
  /// asked at all — a locked or denied keychain, a missing entitlement, a
  /// channel that errored — is a different situation, and the host needs to
  /// know which call failed and what the platform said, without this package
  /// naming any platform's exception type.
  Future<TomSettingsKey> ensure({String? message}) async {
    if (!device.isLoaded) await device.load();

    final storedHandle = device.settingsKeyHandle;
    final handle = storedHandle ?? const Uuid().v4();

    var secret = await _ask(
      TomSecretStoreStep.read,
      () => secrets.read(handle),
    );
    if (secret == null || secret.isEmpty) {
      final minted = _mintSecret();
      await _ask(TomSecretStoreStep.write, () => secrets.write(handle, minted));
      secret = minted;
    }

    if (storedHandle == null) {
      device.settingsKeyHandle = handle;
      await device.save(message: message ?? 'Record the settings key handle');
    }
    return (handle: handle, secret: secret);
  }

  /// Runs one secret-store call, wrapping whatever it throws as a
  /// [TomSecretStoreException] that names [step].
  ///
  /// `Object` is caught on purpose: the store is a port whose implementations
  /// throw their platform's exceptions, which this package cannot name. The
  /// cause travels with the wrapper, so nothing is lost — only typed.
  static Future<T> _ask<T>(
    TomSecretStoreStep step,
    Future<T> Function() call,
  ) async {
    try {
      return await call();
    } on TomSecretStoreException {
      rethrow;
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(TomSecretStoreException(step, error), stack);
    }
  }

  /// A fresh device key: [_secretBytes] cryptographically random bytes,
  /// base64url so it survives being stored as text by a platform store.
  static String _mintSecret() {
    final random = Random.secure();
    return base64Url.encode(
      List<int>.generate(_secretBytes, (_) => random.nextInt(256)),
    );
  }
}
