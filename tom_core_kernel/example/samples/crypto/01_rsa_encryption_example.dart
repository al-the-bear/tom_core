/// RSA Encryption Example
///
/// This example demonstrates RSA encryption and decryption using the
/// TomBase crypto module. RSA is an asymmetric encryption algorithm
/// where data encrypted with a public key can only be decrypted with
/// the corresponding private key.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// EXAMPLE 1: Basic RSA encryption and decryption
// =============================================================================

class BasicRsaEncryptionExample {
  static String? originalMessage;
  static String? decryptedMessage;
  static bool encryptedIsNotEmpty = false;
  static bool encryptedIsLarger = false;

  static void example1BasicEncryption() {
    // Use the development keys from TomJwtConfiguration
    final publicKey = TomJwtConfiguration.rsaPubKey;
    final privateKey = TomJwtConfiguration.rsaPrivKey;

    originalMessage = 'Hello, RSA encryption!';
    final messageBytes = Uint8List.fromList(utf8.encode(originalMessage!));

    // Encrypt with public key
    final encrypted = rsaEncrypt(publicKey, messageBytes);
    encryptedIsNotEmpty = encrypted.isNotEmpty;
    encryptedIsLarger = encrypted.length > messageBytes.length;

    // Decrypt with private key
    final decrypted = rsaDecrypt(privateKey, encrypted);
    decryptedMessage = utf8.decode(decrypted);

    assert(
      decryptedMessage == originalMessage,
      'Decrypted should match original',
    );
    assert(encryptedIsNotEmpty, 'Encrypted data should not be empty');
    assert(encryptedIsLarger, 'RSA adds padding, so encrypted is larger');
  }
}

// =============================================================================
// EXAMPLE 2: Encrypting sensitive JSON data
// =============================================================================

class JsonEncryptionExample {
  static Map<String, dynamic>? originalData;
  static Map<String, dynamic>? decryptedData;
  static int encryptedLength = 0;

  static void example2JsonEncryption() {
    final publicKey = TomJwtConfiguration.rsaPubKey;
    final privateKey = TomJwtConfiguration.rsaPrivKey;

    originalData = {'userId': '12345', 'secret': 'my-api-key'};
    final jsonString = jsonEncode(originalData);
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

    final encryptedJson = rsaEncrypt(publicKey, jsonBytes);
    encryptedLength = base64Encode(encryptedJson).length;

    // Decrypt and parse
    final decryptedJsonBytes = rsaDecrypt(privateKey, encryptedJson);
    final decryptedJsonString = utf8.decode(decryptedJsonBytes);
    decryptedData = jsonDecode(decryptedJsonString) as Map<String, dynamic>;

    assert(decryptedData!['userId'] == '12345', 'UserId should match');
    assert(decryptedData!['secret'] == 'my-api-key', 'Secret should match');
    assert(encryptedLength > 0, 'Encrypted length should be positive');
  }
}

// =============================================================================
// EXAMPLE 3: Using RsaKeyHelper for encryption
// =============================================================================

class RsaKeyHelperExample {
  static String? helperMessage;
  static String? helperResult;
  static bool roundTripSuccess = false;

  static void example3RsaKeyHelperMethods() {
    final publicKey = TomJwtConfiguration.rsaPubKey;
    final privateKey = TomJwtConfiguration.rsaPrivKey;

    helperMessage = 'Encrypted with RsaKeyHelper';
    final helperBytes = Uint8List.fromList(utf8.encode(helperMessage!));

    final helperEncrypted = RsaKeyHelper.rsaEncrypt(publicKey, helperBytes);
    final helperDecrypted = RsaKeyHelper.rsaDecrypt(
      privateKey,
      helperEncrypted,
    );
    helperResult = utf8.decode(helperDecrypted);

    roundTripSuccess = helperMessage == helperResult;

    assert(roundTripSuccess, 'Round-trip encryption should work');
    assert(
      helperResult == 'Encrypted with RsaKeyHelper',
      'Result should match',
    );
  }
}

// =============================================================================
// EXAMPLE 4: Encryption with base64 encoding for transport
// =============================================================================

class TransportEncodingExample {
  static String? transportMessage;
  static String? transportResult;
  static int base64Length = 0;

  static void example4Base64Transport() {
    final publicKey = TomJwtConfiguration.rsaPubKey;
    final privateKey = TomJwtConfiguration.rsaPrivKey;

    transportMessage = 'Data for network transmission';
    final transportBytes = Uint8List.fromList(utf8.encode(transportMessage!));

    // Encrypt and encode for transport
    final transportEncrypted = rsaEncrypt(publicKey, transportBytes);
    final transportBase64 = base64Encode(transportEncrypted);
    base64Length = transportBase64.length;

    // Simulate receiving and decoding
    final receivedBytes = base64Decode(transportBase64);
    final transportDecrypted = rsaDecrypt(
      privateKey,
      Uint8List.fromList(receivedBytes),
    );
    transportResult = utf8.decode(transportDecrypted);

    assert(transportResult == transportMessage, 'Transport should work');
    assert(base64Length > 0, 'Base64 length should be positive');
  }
}

// =============================================================================
// EXAMPLE 5: Multiple encryptions produce different ciphertext
// =============================================================================

class EncryptionRandomnessExample {
  static String? encrypted1Base64;
  static String? encrypted2Base64;
  static bool ciphertextsAreDifferent = false;
  static bool bothDecryptCorrectly = false;

  static void example5EncryptionRandomness() {
    final publicKey = TomJwtConfiguration.rsaPubKey;
    final privateKey = TomJwtConfiguration.rsaPrivKey;

    const message = 'Same message encrypted twice';
    final messageBytes = Uint8List.fromList(utf8.encode(message));

    // Encrypt the same message twice
    final encrypted1 = rsaEncrypt(publicKey, messageBytes);
    final encrypted2 = rsaEncrypt(publicKey, messageBytes);

    encrypted1Base64 = base64Encode(encrypted1);
    encrypted2Base64 = base64Encode(encrypted2);

    // Due to OAEP padding randomness, ciphertexts should differ
    ciphertextsAreDifferent = encrypted1Base64 != encrypted2Base64;

    // But both should decrypt to the same value
    final decrypted1 = utf8.decode(rsaDecrypt(privateKey, encrypted1));
    final decrypted2 = utf8.decode(rsaDecrypt(privateKey, encrypted2));
    bothDecryptCorrectly = decrypted1 == message && decrypted2 == message;

    assert(ciphertextsAreDifferent, 'RSA OAEP produces different ciphertexts');
    assert(bothDecryptCorrectly, 'Both should decrypt correctly');
  }
}

// =============================================================================
// EXAMPLE 6: Encrypting credentials for secure storage
// =============================================================================

class SecureStorageExample {
  static Map<String, String> storedCredentials = {};
  static String? retrievedUsername;
  static String? retrievedPassword;

  static void example6SecureStorage() {
    final publicKey = TomJwtConfiguration.rsaPubKey;
    final privateKey = TomJwtConfiguration.rsaPrivKey;

    // Encrypt credentials
    const username = 'admin@example.com';
    const password = 'super-secret-password-123';

    final encryptedUsername = base64Encode(
      rsaEncrypt(publicKey, Uint8List.fromList(utf8.encode(username))),
    );
    final encryptedPassword = base64Encode(
      rsaEncrypt(publicKey, Uint8List.fromList(utf8.encode(password))),
    );

    // Store encrypted credentials
    storedCredentials = {
      'username': encryptedUsername,
      'password': encryptedPassword,
    };

    // Retrieve and decrypt
    retrievedUsername = utf8.decode(
      rsaDecrypt(
        privateKey,
        Uint8List.fromList(base64Decode(storedCredentials['username']!)),
      ),
    );
    retrievedPassword = utf8.decode(
      rsaDecrypt(
        privateKey,
        Uint8List.fromList(base64Decode(storedCredentials['password']!)),
      ),
    );

    assert(retrievedUsername == username, 'Username should match');
    assert(retrievedPassword == password, 'Password should match');
    assert(storedCredentials.length == 2, 'Should have 2 stored credentials');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  BasicRsaEncryptionExample.example1BasicEncryption();
  JsonEncryptionExample.example2JsonEncryption();
  RsaKeyHelperExample.example3RsaKeyHelperMethods();
  TransportEncodingExample.example4Base64Transport();
  EncryptionRandomnessExample.example5EncryptionRandomness();
  SecureStorageExample.example6SecureStorage();
}

void main() {
  requireAsserts();
  run();
}
