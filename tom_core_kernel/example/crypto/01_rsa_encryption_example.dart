/// RSA Encryption Example
///
/// This example demonstrates RSA encryption and decryption using the
/// TomBase crypto module. RSA is an asymmetric encryption algorithm
/// where data encrypted with a public key can only be decrypted with
/// the corresponding private key.
///
/// Topics covered:
/// - Encrypting data with RSA public key
/// - Decrypting data with RSA private key
/// - Block processing for larger messages
/// - PEM key parsing
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 01: RSA Encryption Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Basic RSA encryption and decryption
  // -------------------------------------------------------------------------
  print('1. Basic RSA encryption and decryption:');

  // Use the development keys from TomJwtConfiguration
  final publicKey = TomJwtConfiguration.rsaPubKey;
  final privateKey = TomJwtConfiguration.rsaPrivKey;

  final originalMessage = 'Hello, RSA encryption!';
  final messageBytes = Uint8List.fromList(utf8.encode(originalMessage));

  // Encrypt with public key
  final encrypted = rsaEncrypt(publicKey, messageBytes);
  final encryptedBase64 = base64Encode(encrypted);

  // Decrypt with private key
  final decrypted = rsaDecrypt(privateKey, encrypted);
  final decryptedMessage = utf8.decode(decrypted);

  print('   Original message: $originalMessage');
  print('   Encrypted (base64, first 50 chars): ${encryptedBase64.substring(0, 50)}...');
  print('   Decrypted message: $decryptedMessage\n');

  // -------------------------------------------------------------------------
  // Example 2: Encrypting sensitive data
  // -------------------------------------------------------------------------
  print('2. Encrypting sensitive data (JSON):');

  final sensitiveData = {'userId': '12345', 'secret': 'my-api-key'};
  final jsonString = jsonEncode(sensitiveData);
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

  final encryptedJson = rsaEncrypt(publicKey, jsonBytes);
  final encryptedJsonBase64 = base64Encode(encryptedJson);

  // Decrypt and parse
  final decryptedJsonBytes = rsaDecrypt(privateKey, encryptedJson);
  final decryptedJsonString = utf8.decode(decryptedJsonBytes);
  final decryptedData = jsonDecode(decryptedJsonString) as Map<String, dynamic>;

  print('   Original data: $sensitiveData');
  print('   Encrypted length: ${encryptedJsonBase64.length} chars');
  print('   Decrypted data: $decryptedData\n');

  // -------------------------------------------------------------------------
  // Example 3: Using RsaKeyHelper for encryption
  // -------------------------------------------------------------------------
  print('3. Using RsaKeyHelper methods:');

  final helperMessage = 'Encrypted with RsaKeyHelper';
  final helperBytes = Uint8List.fromList(utf8.encode(helperMessage));

  final helperEncrypted = RsaKeyHelper.rsaEncrypt(publicKey, helperBytes);
  final helperDecrypted = RsaKeyHelper.rsaDecrypt(privateKey, helperEncrypted);
  final helperResult = utf8.decode(helperDecrypted);

  print('   Original: $helperMessage');
  print('   Round-trip result: $helperResult');
  print('   Matches original: ${helperMessage == helperResult}\n');

  // -------------------------------------------------------------------------
  // Example 4: Encryption with base64 encoding for transport
  // -------------------------------------------------------------------------
  print('4. Preparing encrypted data for transport:');

  final transportMessage = 'Data for network transmission';
  final transportBytes = Uint8List.fromList(utf8.encode(transportMessage));

  // Encrypt and encode for transport
  final transportEncrypted = rsaEncrypt(publicKey, transportBytes);
  final transportBase64 = base64Encode(transportEncrypted);

  // Simulate receiving and decoding
  final receivedBytes = base64Decode(transportBase64);
  final transportDecrypted = rsaDecrypt(privateKey, Uint8List.fromList(receivedBytes));
  final transportResult = utf8.decode(transportDecrypted);

  print('   Original message: $transportMessage');
  print('   Base64 for transport (length): ${transportBase64.length} chars');
  print('   Received and decrypted: $transportResult\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Basic encryption/decryption
  assert(decryptedMessage == originalMessage);
  assert(encrypted.isNotEmpty);
  assert(encrypted.length > messageBytes.length); // RSA adds padding

  // Example 2: JSON encryption
  assert(decryptedData['userId'] == '12345');
  assert(decryptedData['secret'] == 'my-api-key');
  assert(decryptedJsonString == jsonString);

  // Example 3: RsaKeyHelper methods
  assert(helperResult == helperMessage);

  // Example 4: Transport encoding
  assert(transportResult == transportMessage);
  assert(transportBase64.isNotEmpty);
}
