/// Digital Signatures Example
///
/// This example demonstrates RSA digital signatures for data integrity
/// and authentication. Signatures prove that data was created by the
/// holder of a private key and has not been modified.
///
/// Topics covered:
/// - Creating RSA signatures
/// - Verifying signatures
/// - Detecting tampered data
/// - Signing different data types
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 04: Digital Signatures Example ===\n');

  // Use development keys
  final privateKey = TomJwtConfiguration.rsaPrivKey;
  final publicKey = TomJwtConfiguration.rsaPubKey;

  // -------------------------------------------------------------------------
  // Example 1: Basic signing and verification
  // -------------------------------------------------------------------------
  print('1. Basic signing and verification:');

  final message = 'This is an important message';
  final messageBytes = Uint8List.fromList(utf8.encode(message));

  // Sign with private key
  final signature = rsaSign(privateKey, messageBytes);

  // Verify with public key
  final isValid = rsaVerify(publicKey, messageBytes, signature);

  print('   Message: $message');
  print('   Signature length: ${signature.length} bytes');
  print('   Signature (base64, first 40 chars): ${base64Encode(signature).substring(0, 40)}...');
  print('   Signature valid: $isValid\n');

  // -------------------------------------------------------------------------
  // Example 2: Detecting tampered messages
  // -------------------------------------------------------------------------
  print('2. Detecting tampered messages:');

  final originalMessage = 'Transfer \$1000 to account A';
  final originalBytes = Uint8List.fromList(utf8.encode(originalMessage));
  final originalSignature = rsaSign(privateKey, originalBytes);

  // Tampered message (attacker changed amount)
  final tamperedMessage = 'Transfer \$9999 to account A';
  final tamperedBytes = Uint8List.fromList(utf8.encode(tamperedMessage));

  // Verify original message with its signature
  final originalValid = rsaVerify(publicKey, originalBytes, originalSignature);

  // Try to verify tampered message with original signature
  final tamperedValid = rsaVerify(publicKey, tamperedBytes, originalSignature);

  print('   Original message: $originalMessage');
  print('   Tampered message: $tamperedMessage');
  print('   Original message valid: $originalValid');
  print('   Tampered message valid: $tamperedValid');
  print('   Tampering detected: ${!tamperedValid}\n');

  // -------------------------------------------------------------------------
  // Example 3: Signing JSON data
  // -------------------------------------------------------------------------
  print('3. Signing JSON data:');

  final jsonData = {
    'transactionId': 'TXN-2024-001',
    'amount': 500.00,
    'currency': 'USD',
    'timestamp': '2024-06-15T12:00:00Z',
  };
  final jsonString = jsonEncode(jsonData);
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

  final jsonSignature = rsaSign(privateKey, jsonBytes);
  final jsonValid = rsaVerify(publicKey, jsonBytes, jsonSignature);

  print('   JSON data: $jsonData');
  print('   Signature created and verified: $jsonValid\n');

  // -------------------------------------------------------------------------
  // Example 4: Using RsaKeyHelper.sign for string signing
  // -------------------------------------------------------------------------
  print('4. Using RsaKeyHelper.sign for strings:');

  final textToSign = 'Simple text signing example';
  final base64Signature = RsaKeyHelper.sign(textToSign, privateKey);

  // To verify, we need to decode the base64 signature
  final decodedSig = Uint8List.fromList(base64Decode(base64Signature));
  final textBytes = Uint8List.fromList(utf8.encode(textToSign));
  final textValid = rsaVerify(publicKey, textBytes, decodedSig);

  print('   Text: $textToSign');
  print('   Base64 signature (first 40 chars): ${base64Signature.substring(0, 40)}...');
  print('   Signature valid: $textValid\n');

  // -------------------------------------------------------------------------
  // Example 5: Signature with modified signature bytes
  // -------------------------------------------------------------------------
  print('5. Detecting modified signatures:');

  final testMessage = 'Test message for signature modification';
  final testBytes = Uint8List.fromList(utf8.encode(testMessage));
  final validSignature = rsaSign(privateKey, testBytes);

  // Create a modified signature (flip some bits)
  final modifiedSignature = Uint8List.fromList(validSignature);
  modifiedSignature[0] = modifiedSignature[0] ^ 0xFF; // Flip bits in first byte

  final validSigResult = rsaVerify(publicKey, testBytes, validSignature);
  final modifiedSigResult = rsaVerify(publicKey, testBytes, modifiedSignature);

  print('   Message: $testMessage');
  print('   Original signature valid: $validSigResult');
  print('   Modified signature valid: $modifiedSigResult');
  print('   Modification detected: ${!modifiedSigResult}\n');

  // -------------------------------------------------------------------------
  // Example 6: Document signing workflow
  // -------------------------------------------------------------------------
  print('6. Document signing workflow:');

  // Step 1: Create document
  final document = {
    'title': 'Contract Agreement',
    'parties': ['Alice', 'Bob'],
    'date': '2024-06-15',
    'terms': 'Standard terms and conditions apply.',
  };
  final docString = jsonEncode(document);
  final docBytes = Uint8List.fromList(utf8.encode(docString));

  // Step 2: Sign document
  final docSignature = rsaSign(privateKey, docBytes);
  final docSignatureBase64 = base64Encode(docSignature);

  // Step 3: Package for transmission
  final signedDocument = {
    'document': document,
    'signature': docSignatureBase64,
  };

  print('   [Step 1] Document created');
  print('   [Step 2] Document signed');
  print('   [Step 3] Packaged for transmission');

  // Step 4: Recipient verifies (simulated)
  final receivedDoc = signedDocument['document'] as Map<String, dynamic>;
  final receivedSig = signedDocument['signature'] as String;
  final receivedDocBytes = Uint8List.fromList(utf8.encode(jsonEncode(receivedDoc)));
  final receivedSigBytes = Uint8List.fromList(base64Decode(receivedSig));

  final documentValid = rsaVerify(publicKey, receivedDocBytes, receivedSigBytes);

  print('   [Step 4] Recipient verification: ${documentValid ? "VALID" : "INVALID"}\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Basic signing
  assert(isValid == true);
  assert(signature.length == 256); // 2048-bit key produces 256-byte signature

  // Example 2: Tamper detection
  assert(originalValid == true);
  assert(tamperedValid == false);

  // Example 3: JSON signing
  assert(jsonValid == true);

  // Example 4: RsaKeyHelper.sign
  assert(textValid == true);
  assert(base64Signature.isNotEmpty);

  // Example 5: Modified signature detection
  assert(validSigResult == true);
  assert(modifiedSigResult == false);

  // Example 6: Document workflow
  assert(documentValid == true);
}
