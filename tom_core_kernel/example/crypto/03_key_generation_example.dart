/// Key Generation Example
///
/// This example demonstrates RSA key pair generation using the
/// TomBase crypto module. Key generation is essential for creating
/// new cryptographic identities for encryption and signing.
///
/// Topics covered:
/// - Generating RSA key pairs
/// - Creating secure random number generators
/// - Encoding keys to PEM format
/// - Parsing keys from PEM format
/// - Key properties and inspection
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asymmetric/api.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 03: Key Generation Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Creating a secure random number generator
  // -------------------------------------------------------------------------
  print('1. Creating secure random generator:');

  final secureRandom = RsaKeyHelper.getSecureRandom();

  print('   Secure random generator created');
  print('   Type: FortunaRandom (CSPRNG)');
  print('   Seed: 32 bytes from Random.secure()\n');

  // -------------------------------------------------------------------------
  // Example 2: Generating an RSA key pair
  // -------------------------------------------------------------------------
  print('2. Generating RSA key pair:');

  final keyPair = getRsaKeyPair(secureRandom);
  final publicKey = keyPair.publicKey as RSAPublicKey;
  final privateKey = keyPair.privateKey as RSAPrivateKey;

  final modulusBitLength = publicKey.modulus!.bitLength;
  final exponent = publicKey.exponent;

  print('   Key pair generated successfully');
  print('   Modulus bit length: $modulusBitLength bits');
  print('   Public exponent: $exponent');
  print('   Has private key components: ${privateKey.p != null && privateKey.q != null}\n');

  // -------------------------------------------------------------------------
  // Example 3: Encoding keys to PEM format
  // -------------------------------------------------------------------------
  print('3. Encoding keys to PEM format:');

  final publicPem = RsaKeyHelper.encodePublicKeyToPemPKCS1(publicKey);
  final privatePem = RsaKeyHelper.encodePrivateKeyToPemPKCS1(privateKey);

  final publicPemHasHeader = publicPem.contains('-----BEGIN PUBLIC KEY-----');
  final privatePemHasHeader = privatePem.contains('-----BEGIN PRIVATE KEY-----');

  print('   Public key PEM (first 60 chars):');
  print('   ${publicPem.substring(0, 60)}...');
  print('   Private key PEM (first 60 chars):');
  print('   ${privatePem.substring(0, 60)}...');
  print('   Public PEM has correct header: $publicPemHasHeader');
  print('   Private PEM has correct header: $privatePemHasHeader\n');

  // -------------------------------------------------------------------------
  // Example 4: Parsing keys from PEM format
  // -------------------------------------------------------------------------
  print('4. Parsing keys from PEM format:');

  final parsedPublic = RsaKeyHelper.parsePublicKeyFromPem(publicPem);
  final parsedPrivate = RsaKeyHelper.parsePrivateKeyFromPem(privatePem);

  final publicModulusMatch = parsedPublic.modulus == publicKey.modulus;
  final privateModulusMatch = parsedPrivate.modulus == privateKey.modulus;

  print('   Parsed public key successfully');
  print('   Parsed private key successfully');
  print('   Public key modulus matches: $publicModulusMatch');
  print('   Private key modulus matches: $privateModulusMatch\n');

  // -------------------------------------------------------------------------
  // Example 5: Verifying key pair works for encryption
  // -------------------------------------------------------------------------
  print('5. Verifying generated key pair with encryption:');

  final testMessage = 'Testing newly generated keys!';
  final testBytes = Uint8List.fromList(utf8.encode(testMessage));

  final encrypted = rsaEncrypt(publicKey, testBytes);
  final decrypted = rsaDecrypt(privateKey, encrypted);
  final decryptedMessage = utf8.decode(decrypted);

  print('   Original message: $testMessage');
  print('   Encrypted successfully: ${encrypted.isNotEmpty}');
  print('   Decrypted message: $decryptedMessage');
  print('   Round-trip successful: ${testMessage == decryptedMessage}\n');

  // -------------------------------------------------------------------------
  // Example 6: Using development keys
  // -------------------------------------------------------------------------
  print('6. Using development keys from TomJwtConfiguration:');

  final devPublic = TomJwtConfiguration.rsaPubKey;
  final devPrivate = TomJwtConfiguration.rsaPrivKey;

  final devModulusBits = devPublic.modulus!.bitLength;
  final devExponent = devPublic.exponent;
  final devPrivateExists = devPrivate.privateExponent != null;

  print('   Development public key loaded');
  print('   Modulus bit length: $devModulusBits bits');
  print('   Public exponent: $devExponent');
  print('   Has private exponent: $devPrivateExists');
  print('   Note: Development keys should NOT be used in production!\n');

  // -------------------------------------------------------------------------
  // Example 7: Key pair comparison
  // -------------------------------------------------------------------------
  print('7. Comparing keys:');

  // Same key pair should have matching modulus
  final keyModulusMatch = publicKey.modulus == privateKey.modulus;

  // Different key pairs should have different modulus
  final differentKeyPair = publicKey.modulus != devPublic.modulus;

  print('   Public/Private modulus match (same pair): $keyModulusMatch');
  print('   Generated vs dev keys differ: $differentKeyPair\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Secure random - verify it can generate values
  assert(secureRandom.nextUint32() >= 0);

  // Example 2: Key generation
  assert(modulusBitLength == 2048); // Standard RSA key size
  assert(exponent == BigInt.from(65537)); // Standard public exponent
  assert(privateKey.p != null);
  assert(privateKey.q != null);

  // Example 3: PEM encoding
  assert(publicPemHasHeader == true);
  assert(privatePemHasHeader == true);
  assert(publicPem.contains('-----END PUBLIC KEY-----'));
  assert(privatePem.contains('-----END PRIVATE KEY-----'));

  // Example 4: PEM parsing
  assert(publicModulusMatch == true);
  assert(privateModulusMatch == true);
  assert(parsedPublic.exponent == publicKey.exponent);
  assert(parsedPrivate.privateExponent == privateKey.privateExponent);

  // Example 5: Encryption verification
  assert(testMessage == decryptedMessage);
  assert(encrypted.isNotEmpty);

  // Example 6: Development keys
  assert(devModulusBits == 2048);
  assert(devExponent == BigInt.from(65537));
  assert(devPrivateExists == true);

  // Example 7: Key comparison
  assert(keyModulusMatch == true);
  assert(differentKeyPair == true);
}
