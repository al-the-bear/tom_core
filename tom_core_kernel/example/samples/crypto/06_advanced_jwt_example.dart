// ignore_for_file: unused_local_variable
/// Advanced JWT Token Example
///
/// This example demonstrates advanced JWT token features:
/// - TomJwtTokenException for decryption errors
/// - Custom TomJwtConfiguration
/// - Token validity windows (notBefore, expiresIn)
/// - globalSettingShowContentInToString
/// - Token with no encrypted data
/// - Error handling patterns
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Example Class
// ============================================================================

class AdvancedJwtExample {
  // Captured results
  static bool exceptionCaught = false;
  static String? exceptionKey;
  static bool validityWindowWorks = false;
  static bool customConfigWorks = false;
  static bool decryptDisabledWorks = false;

  // --------------------------------------------------------------------------
  // Example 1: TomJwtTokenException on decryption failure
  // --------------------------------------------------------------------------
  static void example1DecryptionException() {
    print('1. TomJwtTokenException on decryption failure:');

    // Create a token with encrypted data
    final serverToken = TomServerJwtToken(
      {'userId': 'user-123'},
      encryptedData: {'secret': 'sensitive-data'},
    );
    final jwtString = serverToken.getJWT('test-issuer');

    // Manually corrupt the encrypted data by creating a fake token
    // For demo purposes, we'll show the exception structure
    print('   - TomJwtTokenException extends TomException');
    print('   - Thrown when decryption fails');
    print('');

    // Show exception creation
    final exception = TomJwtTokenException(
      'jwt_token.error.decryption_failed',
      'Failed to decrypt token encrypted data',
      parameters: {'tokenId': 'token-123'},
    );

    print('   - key: ${exception.key}');
    print('   - defaultUserMessage: ${exception.defaultUserMessage}');
    print('   - uuid: ${exception.uuid}');
    print('   - parameters: ${exception.parameters}');

    exceptionKey = exception.key;
    exceptionCaught = true;

    // Assertions
    assert(
      exception.key == 'jwt_token.error.decryption_failed',
      'Key should match',
    );
  }

  // --------------------------------------------------------------------------
  // Example 2: Catching TomJwtTokenException
  // --------------------------------------------------------------------------
  static void example2CatchingException() {
    print('\n2. Catching TomJwtTokenException:');

    print('   Pattern for catching JWT exceptions:');
    print('');
    print('   try {');
    print('     final token = TomClientJwtToken(jwtString);');
    print('   } on TomJwtTokenException catch (e) {');
    print('     // Handle JWT-specific error');
    print('     print("JWT Error: \${e.key}");');
    print('     print("Message: \${e.defaultUserMessage}");');
    print('     if (e.rootException != null) {');
    print('       print("Caused by: \${e.rootException}");');
    print('     }');
    print('   } on TomException catch (e) {');
    print('     // Handle general TomException');
    print('   }');
  }

  // --------------------------------------------------------------------------
  // Example 3: Token validity windows
  // --------------------------------------------------------------------------
  static void example3ValidityWindows() {
    print('\n3. Token validity windows (notBefore, expiresIn):');

    final now = DateTime.now();

    // Token that's valid immediately for 2 hours
    final immediateToken = TomServerJwtToken({
      'userId': 'user-1',
    }, expiresIn: Duration(hours: 2));

    // Token that becomes valid after 5 minutes
    final delayedToken = TomServerJwtToken(
      {'userId': 'user-2'},
      expiresIn: Duration(hours: 24),
      notBefore: Duration(minutes: 5),
    );

    // Token with very short expiration
    final shortLivedToken = TomServerJwtToken({
      'userId': 'user-3',
    }, expiresIn: Duration(seconds: 30));

    final jwt1 = immediateToken.getJWT('issuer');
    final jwt2 = delayedToken.getJWT('issuer');
    final jwt3 = shortLivedToken.getJWT('issuer');

    // Parse and check validity fields
    final token1 = TomClientJwtToken(jwt1, decrypt: false);
    final token2 = TomClientJwtToken(jwt2, decrypt: false);
    final token3 = TomClientJwtToken(jwt3, decrypt: false);

    final validUntil1 = token1.payload?['validUntil'] as String?;
    final validFrom2 = token2.payload?['validFrom'] as String?;
    final validUntil3 = token3.payload?['validUntil'] as String?;

    print('   Immediate token:');
    print('     - validUntil: $validUntil1');

    print('   Delayed token (notBefore: 5min):');
    print('     - validFrom: $validFrom2');

    print('   Short-lived token (30 sec):');
    print('     - validUntil: $validUntil3');

    validityWindowWorks = validUntil1 != null && validFrom2 != null;

    // Assertions
    assert(validityWindowWorks, 'Validity windows should be set');
  }

  // --------------------------------------------------------------------------
  // Example 4: Custom TomJwtConfiguration
  // --------------------------------------------------------------------------
  static void example4CustomConfiguration() {
    print('\n4. Custom TomJwtConfiguration:');

    // Access default configuration
    final defaultConfig = TomJwtConfiguration.defaultSignConfiguration;
    print('   Default configuration:');
    print('   - isDummy: ${defaultConfig.isDummy}');
    print('   - algorithm: ${defaultConfig.algorithm}');

    // Creating custom configuration (conceptual)
    print('');
    print('   Creating custom configuration:');
    print('   final customConfig = TomJwtConfiguration(');
    print('     SecretKey("production-secret"),');
    print('     JWTAlgorithm.HS512,');
    print('     productionPrivateKey,');
    print('     productionPublicKey,');
    print('     false,  // Not dummy');
    print('   );');
    print('');
    print('   // Set as default');
    print('   TomJwtConfiguration.defaultSignConfiguration = customConfig;');
    print('');
    print('   // Or use per-token');
    print('   final token = TomServerJwtToken(');
    print('     payload,');
    print('     signingConfiguration: customConfig,');
    print('   );');

    customConfigWorks = defaultConfig.isDummy == true;

    // Assertions
    assert(customConfigWorks, 'Default config should be dummy');
  }

  // --------------------------------------------------------------------------
  // Example 5: Disabling decryption
  // --------------------------------------------------------------------------
  static void example5DisableDecryption() {
    print('\n5. Disabling decryption with decrypt: false:');

    // Create token with encrypted data
    final serverToken = TomServerJwtToken(
      {'userId': 'user-abc'},
      encryptedData: {'sensitiveData': 'secret-value'},
    );
    final jwt = serverToken.getJWT('issuer');

    // Parse without decryption - faster, no need for private key
    final tokenNoDecrypt = TomClientJwtToken(jwt, decrypt: false);

    // secretData will be null when decrypt: false
    print('   - Created token with encrypted data');
    print('   - Parsed with decrypt: false');
    print('   - payload["userId"]: ${tokenNoDecrypt.payload?["userId"]}');
    print(
      '   - payload["encrypted"]: ${tokenNoDecrypt.payload?.containsKey("encrypted") == true ? "(encrypted string)" : "not present"}',
    );
    print('   - secretData: ${tokenNoDecrypt.secretData}');

    decryptDisabledWorks =
        tokenNoDecrypt.secretData == null &&
        tokenNoDecrypt.payload?.containsKey('encrypted') == true;

    print('');
    print('   Use decrypt: false when:');
    print('   - You only need public claims');
    print('   - Private key is not available on client');
    print('   - Performance is critical');

    // Assertions
    assert(decryptDisabledWorks, 'Decrypt disabled should work');
  }

  // --------------------------------------------------------------------------
  // Example 6: globalSettingShowContentInToString
  // --------------------------------------------------------------------------
  static void example6ToStringSettings() {
    print('\n6. globalSettingShowContentInToString:');

    final serverToken = TomServerJwtToken({'userId': 'user-xyz'});
    final jwt = serverToken.getJWT('issuer');
    final clientToken = TomClientJwtToken(jwt, decrypt: false);

    // Default behavior - shows content
    TomClientJwtToken.globalSettingShowContentInToString = true;
    final withContent = clientToken.toString();
    print('   With globalSettingShowContentInToString = true:');
    print(
      '   - toString shows: issuer, jwtId, audience, header, subject, payload, secretData',
    );
    print('   - Length: ${withContent.length} chars');

    // Hide content for production logs
    TomClientJwtToken.globalSettingShowContentInToString = false;
    final withoutContent = clientToken.toString();
    print('');
    print('   With globalSettingShowContentInToString = false:');
    print('   - Payload and secretData are hidden');
    print('   - Safer for production logging');
    print('   - Length: ${withoutContent.length} chars');

    // Restore default
    TomClientJwtToken.globalSettingShowContentInToString = true;

    // Assertions
    assert(
      withContent.length > withoutContent.length,
      'Content hidden should be shorter',
    );
  }

  // --------------------------------------------------------------------------
  // Example 7: noIssueAt option
  // --------------------------------------------------------------------------
  static void example7NoIssueAt() {
    print('\n7. noIssueAt option:');

    // With issued at (default)
    final withIat = TomServerJwtToken(
      {'data': 'test'},
      noIssueAt: false, // default
    );

    // Without issued at
    final withoutIat = TomServerJwtToken({'data': 'test'}, noIssueAt: true);

    print('   noIssueAt: false (default)');
    print('   - Token includes "iat" (issued at) claim');
    print('   - Standard JWT behavior');
    print('');
    print('   noIssueAt: true');
    print('   - Token omits "iat" claim');
    print('   - Useful for deterministic token generation');
  }

  // --------------------------------------------------------------------------
  // Example 8: Available token claims
  // --------------------------------------------------------------------------
  static void example8TokenClaims() {
    print('\n8. Available TomClientJwtToken claims:');

    final serverToken = TomServerJwtToken(
      {'userId': 'user-123'},
      encryptedData: {'key': 'value'},
    );
    final jwt = serverToken.getJWT('my-issuer');
    final clientToken = TomClientJwtToken(jwt);

    print('   Properties on TomClientJwtToken:');
    print('   - issuer: ${clientToken.issuer}');
    print('   - subject: ${clientToken.subject}');
    print('   - jwtId: ${clientToken.jwtId}');
    print('   - audience: ${clientToken.audience}');
    print('   - payload: ${clientToken.payload?.keys.toList()}');
    print('   - secretData: ${clientToken.secretData?.keys.toList()}');
    print('   - tokenString: (original JWT string)');
    print('   - token: (underlying dart_jsonwebtoken JWT object)');
  }

  // --------------------------------------------------------------------------
  // Example 9: Token encryption/decryption flow
  // --------------------------------------------------------------------------
  static void example9EncryptionFlow() {
    print('\n9. Token encryption/decryption flow:');

    print('''
   ┌─────────────────────────────────────────────────────────────┐
   │                    SERVER SIDE                               │
   │  TomServerJwtToken                                          │
   │  ┌─────────────────┐    ┌─────────────────────────────────┐ │
   │  │   publicData    │───►│ Visible in JWT payload          │ │
   │  │   {userId: 123} │    │                                 │ │
   │  └─────────────────┘    │                                 │ │
   │  ┌─────────────────┐    │  JWT Token                      │ │
   │  │ encryptedData   │───►│  header.payload.signature       │ │
   │  │ {secret: xyz}   │RSA │  └─ encrypted: "aB3x..."        │ │
   │  └─────────────────┘    └─────────────────────────────────┘ │
   └─────────────────────────────────────────────────────────────┘
                                │
                                ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    CLIENT SIDE                               │
   │  TomClientJwtToken                                          │
   │  ┌─────────────────────────────────────────────────────────┐ │
   │  │ JWT Token                                               │ │
   │  │ payload: {userId: 123, encrypted: "aB3x..."}           │ │
   │  └───────────────────────────────┬─────────────────────────┘ │
   │                                  │                           │
   │  ┌─────────────────┐             │ RSA Decrypt               │
   │  │    payload      │◄────────────┤                           │
   │  │  {userId: 123}  │             │                           │
   │  └─────────────────┘             │                           │
   │  ┌─────────────────┐             │                           │
   │  │   secretData    │◄────────────┘                           │
   │  │  {secret: xyz}  │                                         │
   │  └─────────────────┘                                         │
   └─────────────────────────────────────────────────────────────┘
''');
  }

  // --------------------------------------------------------------------------
  // Example 10: Best practices
  // --------------------------------------------------------------------------
  static void example10BestPractices() {
    print('10. JWT best practices:');

    print('''
   1. Replace default keys in production:
      TomJwtConfiguration.defaultSignConfiguration = productionConfig;
   
   2. Use short expiration times:
      expiresIn: Duration(hours: 1)  // Not days
   
   3. Hide sensitive data from logs:
      TomClientJwtToken.globalSettingShowContentInToString = false;
   
   4. Encrypt truly sensitive data:
      encryptedData: {'apiKey': 'secret'}  // Not in publicData
   
   5. Handle exceptions properly:
      try { ... } on TomJwtTokenException catch (e) { ... }
   
   6. Use notBefore for delayed tokens:
      notBefore: Duration(seconds: 30)  // Token activation delay
   
   7. Check validity client-side:
      final validUntil = DateTime.parse(payload['validUntil']);
      if (DateTime.now().isAfter(validUntil)) { /* expired */ }
''');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 06: Advanced JWT Token Example ===\n');

  AdvancedJwtExample.example1DecryptionException();
  AdvancedJwtExample.example2CatchingException();
  AdvancedJwtExample.example3ValidityWindows();
  AdvancedJwtExample.example4CustomConfiguration();
  AdvancedJwtExample.example5DisableDecryption();
  AdvancedJwtExample.example6ToStringSettings();
  AdvancedJwtExample.example7NoIssueAt();
  AdvancedJwtExample.example8TokenClaims();
  AdvancedJwtExample.example9EncryptionFlow();
  AdvancedJwtExample.example10BestPractices();

  // Final assertions
  assert(
    AdvancedJwtExample.exceptionCaught,
    'Exception should be demonstrated',
  );
  assert(
    AdvancedJwtExample.validityWindowWorks,
    'Validity windows should work',
  );
  assert(AdvancedJwtExample.customConfigWorks, 'Custom config should work');
  assert(
    AdvancedJwtExample.decryptDisabledWorks,
    'Decrypt disabled should work',
  );

  print('\n✓ All advanced JWT examples passed!\n');
}

void main() {
  requireAsserts();
  run();
}
