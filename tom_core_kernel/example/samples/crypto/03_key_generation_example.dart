/// Key Generation Example
///
/// This example demonstrates RSA key pair generation using the
/// TomBase crypto module. Key generation is essential for creating
/// new cryptographic identities for encryption and signing.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asymmetric/api.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// EXAMPLE 1: Creating a secure random number generator
// =============================================================================

class SecureRandomExample {
  static String algorithmName = '';
  static int randomValue1 = 0;
  static int randomValue2 = 0;
  static bool valuesAreDifferent = false;

  static void example1SecureRandom() {
    final secureRandom = RsaKeyHelper.getSecureRandom();
    algorithmName = secureRandom.algorithmName;

    randomValue1 = secureRandom.nextUint32();
    randomValue2 = secureRandom.nextUint32();
    valuesAreDifferent = randomValue1 != randomValue2;

    // Which generator came back is the whole point of the call: a `Random`
    // seeded from the clock would also hand out differing uint32s.
    assert(algorithmName == 'Fortuna', 'Should be seeded Fortuna, not a PRNG');
    assert(randomValue1 < 0x100000000, 'nextUint32 should stay in 32 bits');
    assert(valuesAreDifferent, 'Random values should generally differ');
  }
}

// =============================================================================
// EXAMPLE 2: Generating an RSA key pair
// =============================================================================

class KeyPairGenerationExample {
  static int modulusBitLength = 0;
  static BigInt? exponent;
  static bool hasPrivateKeyComponents = false;

  static void example2GenerateKeyPair() {
    final secureRandom = RsaKeyHelper.getSecureRandom();
    final keyPair = getRsaKeyPair(secureRandom);

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    modulusBitLength = publicKey.modulus!.bitLength;
    exponent = publicKey.exponent;
    hasPrivateKeyComponents = privateKey.p != null && privateKey.q != null;

    assert(
      modulusBitLength == 2048,
      'Standard RSA key size should be 2048 bits',
    );
    assert(
      exponent == BigInt.from(65537),
      'Standard public exponent should be 65537',
    );
    assert(
      hasPrivateKeyComponents,
      'Should have private key components p and q',
    );
  }
}

// =============================================================================
// EXAMPLE 3: Encoding keys to PEM format
// =============================================================================

class PemEncodingExample {
  static bool publicPemHasHeader = false;
  static bool publicPemHasFooter = false;
  static bool privatePemHasHeader = false;
  static bool privatePemHasFooter = false;
  static int publicPemLength = 0;
  static int privatePemLength = 0;

  static void example3PemEncoding() {
    final secureRandom = RsaKeyHelper.getSecureRandom();
    final keyPair = getRsaKeyPair(secureRandom);

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    final publicPem = RsaKeyHelper.encodePublicKeyToPemPKCS1(publicKey);
    final privatePem = RsaKeyHelper.encodePrivateKeyToPemPKCS1(privateKey);

    publicPemHasHeader = publicPem.contains('-----BEGIN PUBLIC KEY-----');
    publicPemHasFooter = publicPem.contains('-----END PUBLIC KEY-----');
    privatePemHasHeader = privatePem.contains('-----BEGIN PRIVATE KEY-----');
    privatePemHasFooter = privatePem.contains('-----END PRIVATE KEY-----');
    publicPemLength = publicPem.length;
    privatePemLength = privatePem.length;

    assert(publicPemHasHeader, 'Public PEM should have header');
    assert(publicPemHasFooter, 'Public PEM should have footer');
    assert(privatePemHasHeader, 'Private PEM should have header');
    assert(privatePemHasFooter, 'Private PEM should have footer');
    assert(publicPemLength > 0, 'Public PEM should not be empty');
    assert(privatePemLength > publicPemLength, 'Private PEM should be larger');
  }
}

// =============================================================================
// EXAMPLE 4: Parsing keys from PEM format
// =============================================================================

class PemParsingExample {
  static bool publicModulusMatch = false;
  static bool privateModulusMatch = false;
  static bool publicExponentMatch = false;
  static bool privateExponentMatch = false;

  static void example4PemParsing() {
    final secureRandom = RsaKeyHelper.getSecureRandom();
    final keyPair = getRsaKeyPair(secureRandom);

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    // Encode to PEM
    final publicPem = RsaKeyHelper.encodePublicKeyToPemPKCS1(publicKey);
    final privatePem = RsaKeyHelper.encodePrivateKeyToPemPKCS1(privateKey);

    // Parse back from PEM
    final parsedPublic = RsaKeyHelper.parsePublicKeyFromPem(publicPem);
    final parsedPrivate = RsaKeyHelper.parsePrivateKeyFromPem(privatePem);

    publicModulusMatch = parsedPublic.modulus == publicKey.modulus;
    privateModulusMatch = parsedPrivate.modulus == privateKey.modulus;
    publicExponentMatch = parsedPublic.exponent == publicKey.exponent;
    privateExponentMatch =
        parsedPrivate.privateExponent == privateKey.privateExponent;

    assert(publicModulusMatch, 'Public key modulus should match');
    assert(privateModulusMatch, 'Private key modulus should match');
    assert(publicExponentMatch, 'Public exponent should match');
    assert(privateExponentMatch, 'Private exponent should match');
  }
}

// =============================================================================
// EXAMPLE 5: Verifying generated key pair works for encryption
// =============================================================================

class EncryptionVerificationExample {
  static String? testMessage;
  static String? decryptedMessage;
  static bool encryptedIsNotEmpty = false;
  static bool roundTripSuccess = false;

  static void example5VerifyEncryption() {
    final secureRandom = RsaKeyHelper.getSecureRandom();
    final keyPair = getRsaKeyPair(secureRandom);

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    testMessage = 'Testing newly generated keys!';
    final testBytes = Uint8List.fromList(utf8.encode(testMessage!));

    final encrypted = rsaEncrypt(publicKey, testBytes);
    encryptedIsNotEmpty = encrypted.isNotEmpty;

    final decrypted = rsaDecrypt(privateKey, encrypted);
    decryptedMessage = utf8.decode(decrypted);
    roundTripSuccess = testMessage == decryptedMessage;

    assert(encryptedIsNotEmpty, 'Encrypted data should not be empty');
    assert(roundTripSuccess, 'Round-trip encryption should work');
  }
}

// =============================================================================
// EXAMPLE 6: Using development keys
// =============================================================================

class DevelopmentKeysExample {
  static int devModulusBits = 0;
  static BigInt? devExponent;
  static bool devPrivateExists = false;
  static bool isDevelopmentKey = false;

  static void example6DevelopmentKeys() {
    final devPublic = TomJwtConfiguration.rsaPubKey;
    final devPrivate = TomJwtConfiguration.rsaPrivKey;

    devModulusBits = devPublic.modulus!.bitLength;
    devExponent = devPublic.exponent;
    devPrivateExists = devPrivate.privateExponent != null;

    // Development keys should have standard properties
    isDevelopmentKey =
        devModulusBits == 2048 && devExponent == BigInt.from(65537);

    assert(devModulusBits == 2048, 'Development key should be 2048 bits');
    assert(
      devExponent == BigInt.from(65537),
      'Development key should use 65537',
    );
    assert(devPrivateExists, 'Should have private exponent');
    assert(isDevelopmentKey, 'Should be a valid development key');
  }
}

// =============================================================================
// EXAMPLE 7: Key pair comparison
// =============================================================================

class KeyComparisonExample {
  static bool publicPrivateModulusMatch = false;
  static bool generatedDifferentFromDev = false;

  static void example7KeyComparison() {
    final secureRandom = RsaKeyHelper.getSecureRandom();
    final keyPair = getRsaKeyPair(secureRandom);

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final devPublic = TomJwtConfiguration.rsaPubKey;

    // Same key pair should have matching modulus
    publicPrivateModulusMatch = publicKey.modulus == privateKey.modulus;

    // Different key pairs should have different modulus
    generatedDifferentFromDev = publicKey.modulus != devPublic.modulus;

    assert(publicPrivateModulusMatch, 'Public/Private modulus should match');
    assert(
      generatedDifferentFromDev,
      'Generated keys should differ from dev keys',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 03: Key Generation Example ===\n');

  SecureRandomExample.example1SecureRandom();
  print('1. A seeded secure random number generator:');
  print('   algorithm     : ${SecureRandomExample.algorithmName}');
  print('   first  uint32 : ${SecureRandomExample.randomValue1}');
  print('   second uint32 : ${SecureRandomExample.randomValue2}');
  print('   values differ : ${SecureRandomExample.valuesAreDifferent}');
  print('');

  KeyPairGenerationExample.example2GenerateKeyPair();
  print('2. Generating a fresh RSA key pair:');
  print('   modulus bits    : ${KeyPairGenerationExample.modulusBitLength}');
  print('   public exponent : ${KeyPairGenerationExample.exponent}');
  print(
    '   private key has p and q: '
    '${KeyPairGenerationExample.hasPrivateKeyComponents}',
  );
  print('');

  PemEncodingExample.example3PemEncoding();
  print('3. Encoding both keys to PEM:');
  print('   public PEM chars  : ${PemEncodingExample.publicPemLength}');
  print('   private PEM chars : ${PemEncodingExample.privatePemLength}');
  print('   public PEM header : ${PemEncodingExample.publicPemHasHeader}');
  print('   public PEM footer : ${PemEncodingExample.publicPemHasFooter}');
  print('   private PEM header: ${PemEncodingExample.privatePemHasHeader}');
  print('   private PEM footer: ${PemEncodingExample.privatePemHasFooter}');
  print('');

  PemParsingExample.example4PemParsing();
  print('4. Parsing the PEM text back into keys:');
  print(
    '   public modulus matches   : ${PemParsingExample.publicModulusMatch}',
  );
  print(
    '   private modulus matches  : ${PemParsingExample.privateModulusMatch}',
  );
  print(
    '   public exponent matches  : ${PemParsingExample.publicExponentMatch}',
  );
  print(
    '   private exponent matches : ${PemParsingExample.privateExponentMatch}',
  );
  print('');

  EncryptionVerificationExample.example5VerifyEncryption();
  print('5. The generated pair really encrypts and decrypts:');
  print('   plaintext        : ${EncryptionVerificationExample.testMessage}');
  print(
    '   after round-trip : '
    '${EncryptionVerificationExample.decryptedMessage}',
  );
  print(
    '   round-trip succeeded: '
    '${EncryptionVerificationExample.roundTripSuccess}',
  );
  print('');

  DevelopmentKeysExample.example6DevelopmentKeys();
  print('6. The built-in development key pair:');
  print('   modulus bits         : ${DevelopmentKeysExample.devModulusBits}');
  print('   public exponent      : ${DevelopmentKeysExample.devExponent}');
  print('   private exponent set : ${DevelopmentKeysExample.devPrivateExists}');
  print('   standard properties  : ${DevelopmentKeysExample.isDevelopmentKey}');
  print('');

  KeyComparisonExample.example7KeyComparison();
  print('7. Comparing the moduli of two key pairs:');
  print(
    '   public and private share a modulus: '
    '${KeyComparisonExample.publicPrivateModulusMatch}',
  );
  print(
    '   generated pair differs from the dev pair: '
    '${KeyComparisonExample.generatedDifferentFromDev}',
  );
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
