/// JWT Token Example
///
/// This example demonstrates JWT token creation and parsing using the
/// TomBase crypto module. JWT (JSON Web Tokens) are commonly used for
/// authentication and secure data exchange.
///
/// Topics covered:
/// - Creating server-side JWT tokens
/// - Parsing client-side JWT tokens
/// - Working with encrypted payload sections
/// - Token configuration
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 05: JWT Token Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Creating a basic JWT token
  // -------------------------------------------------------------------------
  print('1. Creating a basic JWT token:');

  final basicToken = TomServerJwtToken(
    {'userId': 'user-123', 'role': 'admin'},
    expiresIn: Duration(hours: 24),
  );

  final jwtString = basicToken.getJWT('my-auth-server');
  final jwtParts = jwtString.split('.');
  final jwtPartCount = jwtParts.length;

  print('   Public data: {userId: user-123, role: admin}');
  print('   Issuer: my-auth-server');
  print('   Expires in: 24 hours');
  print('   JWT parts: $jwtPartCount (header.payload.signature)');
  print('   JWT (first 80 chars): ${jwtString.substring(0, 80)}...\n');

  // -------------------------------------------------------------------------
  // Example 2: Parsing a JWT token (client-side)
  // -------------------------------------------------------------------------
  print('2. Parsing a JWT token:');

  final clientToken = TomClientJwtToken(jwtString, decrypt: false);

  final parsedIssuer = clientToken.issuer;
  final parsedPayload = clientToken.payload;
  final parsedUserId = parsedPayload?['userId'];
  final parsedRole = parsedPayload?['role'];

  print('   Issuer: $parsedIssuer');
  print('   User ID: $parsedUserId');
  print('   Role: $parsedRole');
  print('   Has validUntil: ${parsedPayload?.containsKey("validUntil")}\n');

  // -------------------------------------------------------------------------
  // Example 3: Token with encrypted data
  // -------------------------------------------------------------------------
  print('3. Token with encrypted data:');

  final tokenWithSecret = TomServerJwtToken(
    {'userId': 'user-456'},
    encryptedData: {'sessionKey': 'secret-key-xyz', 'permissions': ['read', 'write']},
    expiresIn: Duration(hours: 8),
  );

  final secretJwt = tokenWithSecret.getJWT('secure-server');

  // Parse and decrypt
  final decryptedToken = TomClientJwtToken(secretJwt);
  final secretData = decryptedToken.secretData;
  final sessionKey = secretData?['sessionKey'];
  final permissions = secretData?['permissions'] as List<dynamic>?;

  print('   Public payload userId: ${decryptedToken.payload?["userId"]}');
  print('   Encrypted data decrypted successfully');
  print('   Session key: $sessionKey');
  print('   Permissions: $permissions\n');

  // -------------------------------------------------------------------------
  // Example 4: Token configuration
  // -------------------------------------------------------------------------
  print('4. Token configuration details:');

  final defaultConfig = TomJwtConfiguration.defaultSignConfiguration;

  final isDummy = defaultConfig.isDummy;
  final hasPublicKey = defaultConfig.rsaPublicKey.modulus != null;
  final hasPrivateKey = defaultConfig.rsaPrivateKey.modulus != null;

  print('   Is dummy configuration: $isDummy');
  print('   Has public key: $hasPublicKey');
  print('   Has private key: $hasPrivateKey');
  print('   Note: Production should use non-dummy configuration!\n');

  // -------------------------------------------------------------------------
  // Example 5: Token with custom expiration
  // -------------------------------------------------------------------------
  print('5. Tokens with different expirations:');

  final shortLivedToken = TomServerJwtToken(
    {'type': 'short-lived'},
    expiresIn: Duration(minutes: 15),
  );

  final longLivedToken = TomServerJwtToken(
    {'type': 'long-lived'},
    expiresIn: Duration(days: 30),
  );

  final shortJwt = shortLivedToken.getJWT('issuer');
  final longJwt = longLivedToken.getJWT('issuer');

  final shortParsed = TomClientJwtToken(shortJwt, decrypt: false);
  final longParsed = TomClientJwtToken(longJwt, decrypt: false);

  final shortValidUntil = shortParsed.payload?['validUntil'] as String;
  final longValidUntil = longParsed.payload?['validUntil'] as String;

  print('   Short-lived token (15 min) validUntil: $shortValidUntil');
  print('   Long-lived token (30 days) validUntil: $longValidUntil\n');

  // -------------------------------------------------------------------------
  // Example 6: Token with notBefore delay
  // -------------------------------------------------------------------------
  print('6. Token with delayed validity:');

  final delayedToken = TomServerJwtToken(
    {'type': 'delayed'},
    expiresIn: Duration(hours: 2),
    notBefore: Duration(minutes: 5),
  );

  final delayedJwt = delayedToken.getJWT('issuer');
  final delayedParsed = TomClientJwtToken(delayedJwt, decrypt: false);

  final validFrom = delayedParsed.payload?['validFrom'] as String;
  final validUntil = delayedParsed.payload?['validUntil'] as String;

  print('   Token valid from: $validFrom');
  print('   Token valid until: $validUntil');
  print('   Note: Token not valid for first 5 minutes\n');

  // -------------------------------------------------------------------------
  // Example 7: Accessing all token properties
  // -------------------------------------------------------------------------
  print('7. All token properties:');

  final fullToken = TomServerJwtToken(
    {'userId': 'user-789', 'email': 'user@example.com'},
    encryptedData: {'apiKey': 'key-abc123'},
    expiresIn: Duration(hours: 4),
  );

  final fullJwt = fullToken.getJWT('full-issuer');
  final fullParsed = TomClientJwtToken(fullJwt);

  final fullPayload = fullParsed.payload;
  final fullSecretData = fullParsed.secretData;
  final fullIssuer = fullParsed.issuer;

  print('   Issuer: $fullIssuer');
  print('   Public payload keys: ${fullPayload?.keys.toList()}');
  print('   Secret data keys: ${fullSecretData?.keys.toList()}');
  print('   API Key from secret: ${fullSecretData?["apiKey"]}\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Basic token creation
  assert(jwtPartCount == 3); // header.payload.signature
  assert(jwtString.isNotEmpty);

  // Example 2: Token parsing
  assert(parsedIssuer == 'my-auth-server');
  assert(parsedUserId == 'user-123');
  assert(parsedRole == 'admin');
  assert(parsedPayload?.containsKey('validUntil') == true);

  // Example 3: Encrypted data
  assert(sessionKey == 'secret-key-xyz');
  assert(permissions != null);
  assert(permissions!.contains('read'));
  assert(permissions!.contains('write'));
  assert(decryptedToken.payload?['userId'] == 'user-456');

  // Example 4: Configuration
  assert(isDummy == true); // Development configuration
  assert(hasPublicKey == true);
  assert(hasPrivateKey == true);

  // Example 5: Different expirations
  assert(shortValidUntil.isNotEmpty);
  assert(longValidUntil.isNotEmpty);

  // Example 6: Delayed validity
  assert(validFrom.isNotEmpty);
  assert(validUntil.isNotEmpty);

  // Example 7: Full token properties
  assert(fullIssuer == 'full-issuer');
  assert(fullPayload?['userId'] == 'user-789');
  assert(fullPayload?['email'] == 'user@example.com');
  assert(fullSecretData?['apiKey'] == 'key-abc123');
}
