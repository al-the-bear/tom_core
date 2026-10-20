/// Optional cache encryption: AES-256-GCM over plaintext cache files, under a
/// device-local key kept in the platform secret store.
///
/// Behind its own entry point because it links a cipher implementation, and a
/// build that does not seal its cache should not carry one.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart';

import '../storage_cache.dart';

/// [TomCacheCipher] over AES-256-GCM.
///
/// A sealed file is `nonce (12 bytes) ‖ ciphertext ‖ tag (16 bytes)`. The
/// nonce is random per file; GCM's tag is what makes a file sealed under
/// another key, or altered, fail to open rather than open as noise.
class TomAesGcmCacheCipher implements TomCacheCipher {
  /// The default secret-store handle the cache key is kept under. A handle,
  /// not a secret.
  @visibleForTesting
  static const keyHandle = 'tom.cache.key';

  static const _keyBytes = 32;
  static const _nonceBytes = 12;
  static const _tagBits = 128;

  final Uint8List _key;
  final Random _random;

  /// A cipher over [key], which must be 32 bytes.
  TomAesGcmCacheCipher(Uint8List key, {Random? random})
    : _key = Uint8List.fromList(key),
      _random = random ?? Random.secure() {
    if (key.length != _keyBytes) {
      throw ArgumentError.value(
        key.length,
        'key',
        'An AES-256 key is $_keyBytes bytes',
      );
    }
  }

  /// The cipher for this device: over the key [secrets] holds under [handle],
  /// minted first when it holds none.
  ///
  /// A key that is missing — a wiped keychain, a restored machine — is
  /// replaced rather than reported. What was sealed under the old one no
  /// longer opens, which the cache reads as a miss; nothing is lost, because
  /// nothing in a cache is the only copy.
  static Future<TomAesGcmCacheCipher> forDevice(
    TomCacheKeyStore secrets, {
    String handle = keyHandle,
    Random? random,
  }) async {
    final stored = await secrets.read(handle);
    if (stored != null) {
      try {
        final key = base64.decode(stored);
        if (key.length == _keyBytes) {
          return TomAesGcmCacheCipher(key, random: random);
        }
      } on FormatException {
        // Not a key; replaced below.
      }
    }
    final source = random ?? Random.secure();
    final key = Uint8List.fromList([
      for (var i = 0; i < _keyBytes; i++) source.nextInt(256),
    ]);
    await secrets.write(handle, base64.encode(key));
    return TomAesGcmCacheCipher(key, random: random);
  }

  @override
  Future<Uint8List> seal(Uint8List plain) async {
    final nonce = Uint8List.fromList([
      for (var i = 0; i < _nonceBytes; i++) _random.nextInt(256),
    ]);
    final sealed = _cipher(nonce, encrypt: true).process(plain);
    return Uint8List(nonce.length + sealed.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, sealed);
  }

  @override
  Future<Uint8List> open(Uint8List sealed) async {
    if (sealed.length < _nonceBytes + _tagBits ~/ 8) {
      throw const FormatException('Too short to be a sealed cache file');
    }
    final nonce = Uint8List.sublistView(sealed, 0, _nonceBytes);
    final body = Uint8List.sublistView(sealed, _nonceBytes);
    try {
      return _cipher(nonce, encrypt: false).process(body);
    } on InvalidCipherTextException {
      throw const FormatException('Not sealed under this key');
    }
  }

  GCMBlockCipher _cipher(Uint8List nonce, {required bool encrypt}) =>
      GCMBlockCipher(AESEngine())..init(
        encrypt,
        AEADParameters(KeyParameter(_key), _tagBits, nonce, Uint8List(0)),
      );
}
