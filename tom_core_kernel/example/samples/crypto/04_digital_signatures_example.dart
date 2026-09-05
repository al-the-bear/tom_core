/// Digital Signatures Example
///
/// This example demonstrates RSA digital signatures for data integrity
/// and authentication. Signatures prove that data was created by the
/// holder of a private key and has not been modified.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// EXAMPLE 1: Basic signing and verification
// =============================================================================

class BasicSigningExample {
  static String? message;
  static int signatureLength = 0;
  static bool isValid = false;

  static void example1BasicSigning() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    message = 'This is an important message';
    final messageBytes = Uint8List.fromList(utf8.encode(message!));

    // Sign with private key
    final signature = rsaSign(privateKey, messageBytes);
    signatureLength = signature.length;

    // Verify with public key
    isValid = rsaVerify(publicKey, messageBytes, signature);

    assert(isValid, 'Signature should be valid');
    assert(signatureLength == 256, '2048-bit key produces 256-byte signature');
  }
}

// =============================================================================
// EXAMPLE 2: Detecting tampered messages
// =============================================================================

class TamperDetectionExample {
  static String? originalMessage;
  static String? tamperedMessage;
  static bool originalValid = false;
  static bool tamperedValid = false;
  static bool tamperingDetected = false;

  static void example2TamperDetection() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    originalMessage = 'Transfer \$1000 to account A';
    final originalBytes = Uint8List.fromList(utf8.encode(originalMessage!));
    final originalSignature = rsaSign(privateKey, originalBytes);

    // Tampered message (attacker changed amount)
    tamperedMessage = 'Transfer \$9999 to account A';
    final tamperedBytes = Uint8List.fromList(utf8.encode(tamperedMessage!));

    // Verify original message with its signature
    originalValid = rsaVerify(publicKey, originalBytes, originalSignature);

    // Try to verify tampered message with original signature
    tamperedValid = rsaVerify(publicKey, tamperedBytes, originalSignature);

    tamperingDetected = !tamperedValid;

    assert(originalValid, 'Original message should be valid');
    assert(!tamperedValid, 'Tampered message should be invalid');
    assert(tamperingDetected, 'Tampering should be detected');
  }
}

// =============================================================================
// EXAMPLE 3: Signing JSON data
// =============================================================================

class JsonSigningExample {
  static Map<String, dynamic>? jsonData;
  static bool jsonValid = false;
  static int signatureBase64Length = 0;

  static void example3JsonSigning() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    jsonData = {
      'transactionId': 'TXN-2024-001',
      'amount': 500.00,
      'currency': 'USD',
      'timestamp': '2024-06-15T12:00:00Z',
    };
    final jsonString = jsonEncode(jsonData);
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

    final jsonSignature = rsaSign(privateKey, jsonBytes);
    signatureBase64Length = base64Encode(jsonSignature).length;
    jsonValid = rsaVerify(publicKey, jsonBytes, jsonSignature);

    assert(jsonValid, 'JSON signature should be valid');
    assert(signatureBase64Length > 0, 'Signature base64 should not be empty');
  }
}

// =============================================================================
// EXAMPLE 4: Using RsaKeyHelper.sign for string signing
// =============================================================================

class RsaKeyHelperSignExample {
  static String? textToSign;
  static String? base64Signature;
  static bool textValid = false;

  static void example4RsaKeyHelperSign() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    textToSign = 'Simple text signing example';
    base64Signature = RsaKeyHelper.sign(textToSign!, privateKey);

    // To verify, we need to decode the base64 signature
    final decodedSig = Uint8List.fromList(base64Decode(base64Signature!));
    final textBytes = Uint8List.fromList(utf8.encode(textToSign!));
    textValid = rsaVerify(publicKey, textBytes, decodedSig);

    assert(textValid, 'Text signature should be valid');
    assert(base64Signature!.isNotEmpty, 'Base64 signature should not be empty');
  }
}

// =============================================================================
// EXAMPLE 5: Detecting modified signatures
// =============================================================================

class ModifiedSignatureExample {
  static String? testMessage;
  static bool validSigResult = false;
  static bool modifiedSigResult = false;
  static bool modificationDetected = false;

  static void example5ModifiedSignature() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    testMessage = 'Test message for signature modification';
    final testBytes = Uint8List.fromList(utf8.encode(testMessage!));
    final validSignature = rsaSign(privateKey, testBytes);

    // Create a modified signature (flip some bits)
    final modifiedSignature = Uint8List.fromList(validSignature);
    modifiedSignature[0] =
        modifiedSignature[0] ^ 0xFF; // Flip bits in first byte

    validSigResult = rsaVerify(publicKey, testBytes, validSignature);
    modifiedSigResult = rsaVerify(publicKey, testBytes, modifiedSignature);
    modificationDetected = !modifiedSigResult;

    assert(validSigResult, 'Valid signature should verify');
    assert(!modifiedSigResult, 'Modified signature should not verify');
    assert(modificationDetected, 'Modification should be detected');
  }
}

// =============================================================================
// EXAMPLE 6: Document signing workflow
// =============================================================================

class DocumentSigningExample {
  static Map<String, dynamic>? document;
  static Map<String, dynamic>? signedDocument;
  static bool documentValid = false;

  static void example6DocumentSigning() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    // Step 1: Create document
    document = {
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
    signedDocument = {'document': document, 'signature': docSignatureBase64};

    // Step 4: Recipient verifies (simulated)
    final receivedDoc = signedDocument!['document'] as Map<String, dynamic>;
    final receivedSig = signedDocument!['signature'] as String;
    final receivedDocBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(receivedDoc)),
    );
    final receivedSigBytes = Uint8List.fromList(base64Decode(receivedSig));

    documentValid = rsaVerify(publicKey, receivedDocBytes, receivedSigBytes);

    assert(documentValid, 'Document signature should be valid');
    assert(signedDocument!.containsKey('signature'), 'Should have signature');
    // The recipient's copy has to be byte-identical, because the signature was
    // taken over those bytes: an envelope that reorders the document verifies
    // as tampering.
    assert(
      jsonEncode(receivedDoc) == docString,
      'The transmitted document should survive the envelope unchanged',
    );
  }
}

// =============================================================================
// EXAMPLE 7: Multiple signatures for same document
// =============================================================================

class MultipleSignaturesExample {
  static String? signature1Base64;
  static String? signature2Base64;
  static bool signaturesAreDifferent = false;
  static bool bothVerify = false;

  static void example7MultipleSignatures() {
    final privateKey = TomJwtConfiguration.rsaPrivKey;
    final publicKey = TomJwtConfiguration.rsaPubKey;

    const message = 'Document to sign multiple times';
    final messageBytes = Uint8List.fromList(utf8.encode(message));

    // Sign the same message twice
    final signature1 = rsaSign(privateKey, messageBytes);
    final signature2 = rsaSign(privateKey, messageBytes);

    signature1Base64 = base64Encode(signature1);
    signature2Base64 = base64Encode(signature2);

    // RSA-PSS uses randomized padding, so signatures may differ
    // But both should verify correctly
    final verify1 = rsaVerify(publicKey, messageBytes, signature1);
    final verify2 = rsaVerify(publicKey, messageBytes, signature2);
    bothVerify = verify1 && verify2;

    // Note: With RSA-PKCS1v1.5, signatures would be the same
    // With RSA-PSS, they may differ due to salt
    signaturesAreDifferent = signature1Base64 != signature2Base64;

    assert(bothVerify, 'Both signatures should verify');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 04: Digital Signatures Example ===\n');

  BasicSigningExample.example1BasicSigning();
  print('1. Sign with the private key, verify with the public key:');
  print('   message          : ${BasicSigningExample.message}');
  print('   signature bytes  : ${BasicSigningExample.signatureLength}');
  print('   signature valid  : ${BasicSigningExample.isValid}');
  print('');

  TamperDetectionExample.example2TamperDetection();
  print('2. A changed message no longer matches its signature:');
  print('   original message : ${TamperDetectionExample.originalMessage}');
  print('   tampered message : ${TamperDetectionExample.tamperedMessage}');
  print('   original verifies: ${TamperDetectionExample.originalValid}');
  print('   tampered verifies: ${TamperDetectionExample.tamperedValid}');
  print('   tampering detected: ${TamperDetectionExample.tamperingDetected}');
  print('');

  JsonSigningExample.example3JsonSigning();
  print('3. Signing a JSON payload:');
  print('   signed fields : ${JsonSigningExample.jsonData?.keys.join(', ')}');
  print(
    '   transaction id: '
    '${JsonSigningExample.jsonData?['transactionId']}',
  );
  print(
    '   base64 signature chars: ${JsonSigningExample.signatureBase64Length}',
  );
  print('   signature valid       : ${JsonSigningExample.jsonValid}');
  print('');

  RsaKeyHelperSignExample.example4RsaKeyHelperSign();
  print('4. Signing a string through RsaKeyHelper.sign:');
  print('   text signed      : ${RsaKeyHelperSignExample.textToSign}');
  print(
    '   base64 signature : '
    '${RsaKeyHelperSignExample.base64Signature!.substring(0, 24)}...',
  );
  print('   signature valid  : ${RsaKeyHelperSignExample.textValid}');
  print('');

  ModifiedSignatureExample.example5ModifiedSignature();
  print('5. Flipping bits in the signature invalidates it:');
  print('   message           : ${ModifiedSignatureExample.testMessage}');
  print(
    '   intact signature verifies  : '
    '${ModifiedSignatureExample.validSigResult}',
  );
  print(
    '   modified signature verifies: '
    '${ModifiedSignatureExample.modifiedSigResult}',
  );
  print(
    '   modification detected      : '
    '${ModifiedSignatureExample.modificationDetected}',
  );
  print('');

  DocumentSigningExample.example6DocumentSigning();
  print('6. A document signing and verification workflow:');
  print('   document title  : ${DocumentSigningExample.document?['title']}');
  print('   parties         : ${DocumentSigningExample.document?['parties']}');
  print(
    '   packaged keys   : '
    '${DocumentSigningExample.signedDocument?.keys.join(', ')}',
  );
  print(
    '   recipient verified document: '
    '${DocumentSigningExample.documentValid}',
  );
  print('');

  MultipleSignaturesExample.example7MultipleSignatures();
  print('7. Signing one message twice:');
  print(
    '   first  signature : '
    '${MultipleSignaturesExample.signature1Base64!.substring(0, 24)}...',
  );
  print(
    '   second signature : '
    '${MultipleSignaturesExample.signature2Base64!.substring(0, 24)}...',
  );
  print(
    '   signatures differ: '
    '${MultipleSignaturesExample.signaturesAreDifferent}',
  );
  print('   both verify      : ${MultipleSignaturesExample.bothVerify}');
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
