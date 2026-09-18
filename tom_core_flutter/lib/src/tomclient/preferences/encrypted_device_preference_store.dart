import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preference_store.dart';
import 'device_preferences.dart';

/// Turns a preference value into stored text and back.
///
/// The seam an encrypting store defers to, and deliberately the whole of it:
/// two methods over `String`, with no key, no algorithm and no lifecycle. The
/// framework does not choose a cipher here and does not hold a key, for two
/// reasons that point the same way.
///
/// Key material belongs to a **platform keystore** — the Keychain, the Android
/// keystore, a browser's subtle-crypto key kept outside `localStorage` — and
/// reaching one is exactly the platform dependency this module is built to keep
/// out of the call site. And `tom_crypto` ships no symmetric cipher, so a
/// framework that encrypted here would either take a new dependency on every
/// application's behalf or hand-roll one. Both are worse than naming the seam.
///
/// [FutureOr] rather than `String`, because a keystore-backed implementation is
/// usually asynchronous and a synchronous one loses nothing by being allowed.
///
/// ```dart
/// class _KeychainCipher implements TomDevicePreferenceCipher {
///   @override
///   Future<String> encrypt(String plaintext) => platform.seal(plaintext);
///
///   @override
///   Future<String> decrypt(String ciphertext) => platform.unseal(ciphertext);
/// }
/// ```
abstract class TomDevicePreferenceCipher {
  /// Allows `const` implementations.
  const TomDevicePreferenceCipher();

  /// Converts [plaintext] to the text that will be stored.
  FutureOr<String> encrypt(String plaintext);

  /// Recovers the plaintext from [ciphertext].
  ///
  /// May throw. A key that no longer decrypts what it once wrote is a real
  /// state — a rotated key, a document from another install — and
  /// [TomEncryptedDevicePreferenceStore] reports it as
  /// `device_preferences.store.undecryptable` rather than letting a raw cipher
  /// error escape as store corruption.
  FutureOr<String> decrypt(String ciphertext);
}

/// A [TomDevicePreferenceStore] that encrypts preference **values** through a
/// [TomDevicePreferenceCipher] and delegates storage to another store.
///
/// A decorator rather than a fourth backend, because the backend contract is
/// two methods and encryption is orthogonal to all three of them: this wraps the
/// file store on desktop, the `localStorage` store in the browser and the memory
/// store in a test, and none of them changes.
///
/// ```dart
/// TomStoredDevicePreferences(
///   TomEncryptedDevicePreferenceStore(
///     TomPlatformDevicePreferenceStore(location, owner: accountId),
///     cipher,
///   ),
/// );
/// ```
///
/// ## What it protects, and what it does not
///
/// **Values only.** A preference's `key`, its `valueType` and its `updatedAt`
/// are stored as they were: someone reading the file learns that
/// `device.authToken` exists, that it holds a `String`, and when it last
/// changed — but not what it is.
///
/// That is a deliberate line rather than an oversight. Encrypting the keys as
/// well would have to be deterministic for a per-key read to work at all, which
/// leaks equality while looking like it does not, and it would make a document
/// unreadable to every tool that inspects one. The honest statement is the one
/// worth having: this hides the secret, not the fact that a secret is kept.
///
/// **It is not a substitute for a credential store.** A refresh token or a
/// password belongs in the platform's own credential storage, whose guarantees
/// (hardware backing, biometric gating, wipe on device reset) no wrapper around
/// a JSON file can offer. What this is for is the preference that is merely
/// sensitive — the last-used account, a device nickname, a flag whose value
/// implies something about the user — where the alternative today is plaintext.
class TomEncryptedDevicePreferenceStore extends TomDevicePreferenceStore {
  /// Wraps [inner], encrypting values through [cipher].
  const TomEncryptedDevicePreferenceStore(this.inner, this.cipher);

  /// The store the encrypted document is persisted in.
  final TomDevicePreferenceStore inner;

  /// The cipher values pass through.
  final TomDevicePreferenceCipher cipher;

  @override
  Future<List<TomUserPreferenceDto>> read() async {
    final stored = await inner.read();
    return [
      for (final dto in stored)
        TomUserPreferenceDto(
          key: dto.key,
          valueType: dto.valueType,
          value: await _decrypt(dto),
          updatedAt: dto.updatedAt,
        ),
    ];
  }

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    await inner.write([
      for (final dto in values)
        TomUserPreferenceDto(
          key: dto.key,
          valueType: dto.valueType,
          value: await cipher.encrypt(dto.value),
          updatedAt: dto.updatedAt,
        ),
    ]);
  }

  /// [dto]'s value in the clear, or a failure naming the preference.
  ///
  /// The key is in the message because a store that cannot be read is usually
  /// readable in part — one preference written under a rotated key among many
  /// that decrypt — and "which one" is the first thing anyone asks.
  Future<String> _decrypt(TomUserPreferenceDto dto) async {
    try {
      return await cipher.decrypt(dto.value);
    } catch (error, stack) {
      throw TomDevicePreferenceException(
        'device_preferences.store.undecryptable',
        "The device preference '${dto.key}' could not be decrypted. Its cipher "
            'refused the stored value — a rotated key, or a document from '
            'another install.',
        parameters: {'key': dto.key},
        rootException: error,
        stack: stack,
      );
    }
  }
}
