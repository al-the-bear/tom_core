/// JWT Token Example
///
/// This example demonstrates JWT token creation and parsing using the
/// TomBase crypto module. JWT (JSON Web Tokens) are commonly used for
/// authentication and secure data exchange.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: Creating a basic JWT token
// =============================================================================

class BasicJwtCreationExample {
  static String? jwtString;
  static int jwtPartCount = 0;
  static bool hasCorrectStructure = false;

  static void example1BasicJwtCreation() {
    final basicToken = TomServerJwtToken({
      'userId': 'user-123',
      'role': 'admin',
    }, expiresIn: Duration(hours: 24));

    jwtString = basicToken.getJWT('my-auth-server');
    final jwtParts = jwtString!.split('.');
    jwtPartCount = jwtParts.length;
    hasCorrectStructure = jwtPartCount == 3;

    assert(
      hasCorrectStructure,
      'JWT should have 3 parts (header.payload.signature)',
    );
    assert(jwtString!.isNotEmpty, 'JWT string should not be empty');
  }
}

// =============================================================================
// EXAMPLE 2: Parsing a JWT token (client-side)
// =============================================================================

class JwtParsingExample {
  static String? parsedIssuer;
  static String? parsedUserId;
  static String? parsedRole;
  static bool hasValidUntil = false;

  static void example2JwtParsing() {
    // Create a token
    final serverToken = TomServerJwtToken({
      'userId': 'user-123',
      'role': 'admin',
    }, expiresIn: Duration(hours: 24));
    final jwtString = serverToken.getJWT('my-auth-server');

    // Parse the token
    final clientToken = TomClientJwtToken(jwtString, decrypt: false);

    parsedIssuer = clientToken.issuer;
    final parsedPayload = clientToken.payload;
    parsedUserId = parsedPayload?['userId'] as String?;
    parsedRole = parsedPayload?['role'] as String?;
    hasValidUntil = parsedPayload?.containsKey('validUntil') ?? false;

    assert(parsedIssuer == 'my-auth-server', 'Issuer should match');
    assert(parsedUserId == 'user-123', 'User ID should match');
    assert(parsedRole == 'admin', 'Role should match');
    assert(hasValidUntil, 'Should have validUntil field');
  }
}

// =============================================================================
// EXAMPLE 3: Token with encrypted data
// =============================================================================

class EncryptedJwtExample {
  static String? publicUserId;
  static String? sessionKey;
  static List<dynamic>? permissions;
  static bool hasSecretData = false;

  static void example3EncryptedData() {
    final tokenWithSecret = TomServerJwtToken(
      {'userId': 'user-456'},
      encryptedData: {
        'sessionKey': 'secret-key-xyz',
        'permissions': ['read', 'write'],
      },
      expiresIn: Duration(hours: 8),
    );

    final secretJwt = tokenWithSecret.getJWT('secure-server');

    // Parse and decrypt
    final decryptedToken = TomClientJwtToken(secretJwt);
    final secretData = decryptedToken.secretData;

    publicUserId = decryptedToken.payload?['userId'] as String?;
    sessionKey = secretData?['sessionKey'] as String?;
    permissions = secretData?['permissions'] as List<dynamic>?;
    hasSecretData = secretData != null && secretData.isNotEmpty;

    assert(publicUserId == 'user-456', 'Public userId should match');
    assert(sessionKey == 'secret-key-xyz', 'Session key should match');
    assert(permissions != null, 'Permissions should exist');
    assert(permissions!.contains('read'), 'Should have read permission');
    assert(permissions!.contains('write'), 'Should have write permission');
    assert(hasSecretData, 'Should have secret data');
  }
}

// =============================================================================
// EXAMPLE 4: Token configuration
// =============================================================================

class JwtConfigurationExample {
  static bool isDummy = false;
  static bool hasPublicKey = false;
  static bool hasPrivateKey = false;

  static void example4Configuration() {
    final defaultConfig = TomJwtConfiguration.defaultSignConfiguration;

    isDummy = defaultConfig.isDummy;
    hasPublicKey = defaultConfig.rsaPublicKey.modulus != null;
    hasPrivateKey = defaultConfig.rsaPrivateKey.modulus != null;

    assert(isDummy, 'Development config should be dummy');
    assert(hasPublicKey, 'Should have public key');
    assert(hasPrivateKey, 'Should have private key');
  }
}

// =============================================================================
// EXAMPLE 5: Tokens with different expirations
// =============================================================================

class TokenExpirationExample {
  static String? shortValidUntil;
  static String? longValidUntil;
  static bool shortTokenCreated = false;
  static bool longTokenCreated = false;

  static void example5TokenExpiration() {
    final shortLivedToken = TomServerJwtToken({
      'type': 'short-lived',
    }, expiresIn: Duration(minutes: 15));

    final longLivedToken = TomServerJwtToken({
      'type': 'long-lived',
    }, expiresIn: Duration(days: 30));

    final shortJwt = shortLivedToken.getJWT('issuer');
    final longJwt = longLivedToken.getJWT('issuer');

    final shortParsed = TomClientJwtToken(shortJwt, decrypt: false);
    final longParsed = TomClientJwtToken(longJwt, decrypt: false);

    shortValidUntil = shortParsed.payload?['validUntil'] as String?;
    longValidUntil = longParsed.payload?['validUntil'] as String?;

    shortTokenCreated = shortValidUntil != null && shortValidUntil!.isNotEmpty;
    longTokenCreated = longValidUntil != null && longValidUntil!.isNotEmpty;

    assert(shortTokenCreated, 'Short-lived token should have validUntil');
    assert(longTokenCreated, 'Long-lived token should have validUntil');
  }
}

// =============================================================================
// EXAMPLE 6: Token with delayed validity (notBefore)
// =============================================================================

class DelayedValidityExample {
  static String? validFrom;
  static String? validUntil;
  static bool hasValidFrom = false;
  static bool hasValidUntil = false;

  static void example6DelayedValidity() {
    final delayedToken = TomServerJwtToken(
      {'type': 'delayed'},
      expiresIn: Duration(hours: 2),
      notBefore: Duration(minutes: 5),
    );

    final delayedJwt = delayedToken.getJWT('issuer');
    final delayedParsed = TomClientJwtToken(delayedJwt, decrypt: false);

    validFrom = delayedParsed.payload?['validFrom'] as String?;
    validUntil = delayedParsed.payload?['validUntil'] as String?;

    hasValidFrom = validFrom != null && validFrom!.isNotEmpty;
    hasValidUntil = validUntil != null && validUntil!.isNotEmpty;

    assert(hasValidFrom, 'Should have validFrom field');
    assert(hasValidUntil, 'Should have validUntil field');
  }
}

// =============================================================================
// EXAMPLE 7: Accessing all token properties
// =============================================================================

class FullTokenPropertiesExample {
  static String? fullIssuer;
  static List<String> payloadKeys = [];
  static List<String> secretDataKeys = [];
  static String? apiKey;

  static void example7FullTokenProperties() {
    final fullToken = TomServerJwtToken(
      {'userId': 'user-789', 'email': 'user@example.com'},
      encryptedData: {'apiKey': 'key-abc123'},
      expiresIn: Duration(hours: 4),
    );

    final fullJwt = fullToken.getJWT('full-issuer');
    final fullParsed = TomClientJwtToken(fullJwt);

    final fullPayload = fullParsed.payload;
    final fullSecretData = fullParsed.secretData;

    fullIssuer = fullParsed.issuer;
    payloadKeys = fullPayload?.keys.toList() ?? [];
    secretDataKeys = fullSecretData?.keys.toList() ?? [];
    apiKey = fullSecretData?['apiKey'] as String?;

    assert(fullIssuer == 'full-issuer', 'Issuer should match');
    assert(payloadKeys.contains('userId'), 'Payload should have userId');
    assert(payloadKeys.contains('email'), 'Payload should have email');
    assert(secretDataKeys.contains('apiKey'), 'Secret should have apiKey');
    assert(apiKey == 'key-abc123', 'API key should match');
  }
}

// =============================================================================
// EXAMPLE 8: Token round-trip (create, serialize, parse)
// =============================================================================

class TokenRoundTripExample {
  static String? originalUserId;
  static String? parsedUserId;
  static bool roundTripSuccess = false;
  static bool issuerPreserved = false;

  static void example8TokenRoundTrip() {
    originalUserId = 'round-trip-user';
    const originalIssuer = 'round-trip-issuer';

    // Create token
    final token = TomServerJwtToken({
      'userId': originalUserId,
    }, expiresIn: Duration(hours: 1));

    // Serialize
    final jwt = token.getJWT(originalIssuer);

    // Parse
    final parsed = TomClientJwtToken(jwt, decrypt: false);

    parsedUserId = parsed.payload?['userId'] as String?;
    issuerPreserved = parsed.issuer == originalIssuer;
    roundTripSuccess = originalUserId == parsedUserId;

    assert(roundTripSuccess, 'User ID should survive round-trip');
    assert(issuerPreserved, 'Issuer should be preserved');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  BasicJwtCreationExample.example1BasicJwtCreation();
  JwtParsingExample.example2JwtParsing();
  EncryptedJwtExample.example3EncryptedData();
  JwtConfigurationExample.example4Configuration();
  TokenExpirationExample.example5TokenExpiration();
  DelayedValidityExample.example6DelayedValidity();
  FullTokenPropertiesExample.example7FullTokenProperties();
  TokenRoundTripExample.example8TokenRoundTrip();
}

void main() => run();
