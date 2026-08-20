// ignore_for_file: unused_local_variable
/// Bearer Authentication Example
///
/// This example demonstrates the TomBearerAuthentication system for
/// JWT-based authentication and principal management.
///
/// Key concepts:
/// - TomBearerAuthentication singleton for token management
/// - Token structure (authentication vs authorization tokens)
/// - Converting principals to token payloads
/// - Accessing the current principal
/// - Updating principal permissions
///
/// Note: Full JWT creation requires RSA key setup. This example
/// focuses on the structural patterns and API usage.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// ============================================================================
// Example Class
// ============================================================================

class BearerAuthenticationExample {
  // Captured results
  static late Map<String, Object?> publicPayload;
  static late Map<String, Object?> privatePayload;
  static bool payloadConversionWorks = false;
  static bool staticAccessorsWork = false;

  // --------------------------------------------------------------------------
  // Example 1: Understanding bearer authentication structure
  // --------------------------------------------------------------------------
  static void example1AuthenticationStructure() {
    print('1. Bearer authentication structure:');

    // The TomBearerAuthentication is a singleton
    final auth = TomBearerAuthentication.bearerAuthentication;

    print('   - TomBearerAuthentication is a singleton');
    print('   - Manages two types of tokens:');
    print('     * Authentication token: proves user identity');
    print('     * Authorization token: contains access rights (ACI)');
    print('   - Provides access to TomPrincipal from tokens');

    // Static accessors for current token state
    print(
      '   - Current auth token: ${TomBearerAuthentication.token ?? 'null'}',
    );
    print(
      '   - Current authz token: ${TomBearerAuthentication.authorizationToken ?? 'null'}',
    );

    staticAccessorsWork = true;
  }

  // --------------------------------------------------------------------------
  // Example 2: Converting principal to token payload
  // --------------------------------------------------------------------------
  static void example2ConvertPrincipalToPayload() {
    print('\n2. Converting principal to token payload:');

    // Create a test principal
    final principal = TomPrincipal(
      authenticated: true,
      user: TomUser(
        id: 123,
        username: 'john.doe',
        firstname: 'John',
        lastname: 'Doe',
        email: 'john.doe@example.com',
        phone: '+1-555-0123',
        timeZone: 'America/New_York',
      ),
      organization: 'Acme Corp',
      application: 'main-app',
      language: 'en',
      country: 'US',
      timezone: 'America/New_York',
      requires2FA: false,
      aci: TomAccessControlInformation(
        roles: ['user', 'premium'],
        groups: ['engineering', 'all-employees'],
        entitlements: ['feature.dashboard.edit', 'feature.reports.view'],
        resourceKeys: ['user.email', 'user.phone'],
      ),
      cli: TomClientLimitsInformation(
        enabledModules: ['module.reports', 'module.analytics'],
        quotas: {'api.calls': 10000, 'storage.mb': 500},
      ),
    );

    // Convert to token payloads
    final result = TomBearerAuthentication.convertPrincipalToTokenPayload(
      principal,
      null, // No ACI definition for this example
      'US', // Client country
      'en', // Client language
    );
    publicPayload = result.$1;
    privatePayload = result.$2;

    print('   - Public payload keys: ${publicPayload.keys.toList()}');
    print('   - Private payload keys: ${privatePayload.keys.toList()}');
    print('');
    print('   Public payload samples:');
    print('     username: ${publicPayload['username']}');
    print('     userId: ${publicPayload['userId']}');
    print('     email: ${publicPayload['email']}');
    print('     organization: ${publicPayload['organization']}');
    print('');
    print('   Private payload samples:');
    print('     roles: ${privatePayload['roles']}');
    print('     groups: ${privatePayload['groups']}');
    print('     entitlements: ${privatePayload['entitlements']}');

    payloadConversionWorks =
        publicPayload['username'] == 'john.doe' &&
        privatePayload['roles'] != null;

    // Assertions
    assert(publicPayload['username'] == 'john.doe', 'Username should match');
    assert(publicPayload['userId'] == 123, 'User ID should match');
    assert(privatePayload['roles'] is List, 'Roles should be a list');
    assert(
      (privatePayload['roles'] as List).contains('premium'),
      'Should have premium role',
    );
  }

  // --------------------------------------------------------------------------
  // Example 3: Token payload structure
  // --------------------------------------------------------------------------
  static void example3PayloadStructure() {
    print('\n3. Token payload structure:');

    print('   PUBLIC PAYLOAD (visible in JWT):');
    print('   ├── User Info');
    print('   │   ├── username, userId, firstname, lastname');
    print('   │   ├── email, phone, mobile (may be protected)');
    print('   │   └── address fields, timezone');
    print('   ├── Context');
    print('   │   ├── organization, application, process');
    print('   │   └── organizationId, applicationId, processId');
    print('   ├── Localization');
    print('   │   ├── language, country, timezone');
    print('   │   └── clientLanguage, clientCountry, clientTimezone');
    print('   ├── 2FA');
    print('   │   ├── requires2FA');
    print('   │   └── twoFactorType');
    print('   └── Subscription');
    print('       ├── enabledModules');
    print('       └── quotas');
    print('');
    print('   PRIVATE PAYLOAD (encrypted in JWT):');
    print('   ├── context (session context map)');
    print('   ├── roles');
    print('   ├── groups');
    print('   ├── entitlements');
    print('   └── resourceKeys');
  }

  // --------------------------------------------------------------------------
  // Example 4: Resource protection in payloads
  // --------------------------------------------------------------------------
  static void example4ResourceProtection() {
    print('\n4. Resource protection in payloads:');

    // When resource protection is enabled, sensitive fields
    // in the payload are masked using tomProtect
    print('   - Payload generation uses tomProtect() for sensitive fields');
    print('   - Protected fields include:');
    print('     * firstname, lastname');
    print('     * email, phone, mobile');
    print('     * address fields');
    print('     * user attributes');
    print('');
    print('   Example protection keys used:');
    print('     * tom.user.email');
    print('     * tom.user.phone');
    print('     * tom.user.firstname');
    print('     * tom.user.attributes');
  }

  // --------------------------------------------------------------------------
  // Example 5: Client limits in principal
  // --------------------------------------------------------------------------
  static void example5ClientLimits() {
    print('\n5. Client limits information (CLI):');

    final cli = TomClientLimitsInformation(
      enabledModules: [
        'module.reports',
        'module.dashboard',
        'module.analytics',
      ],
      quotas: {'api.calls.daily': 10000, 'storage.mb': 500, 'users.max': 25},
    );

    print('   - Enabled modules: ${cli.enabledModules}');
    print('   - Quotas:');
    cli.quotas.forEach((key, value) {
      print('     * $key: $value');
    });

    // These are included in the public payload
    print('');
    print('   CLI is included in public JWT payload:');
    print('     subscription_enabledModules: ${cli.enabledModules}');
    print('     subscription_quotas: ${cli.quotas}');
  }

  // --------------------------------------------------------------------------
  // Example 6: Token flow pattern
  // --------------------------------------------------------------------------
  static void example6TokenFlowPattern() {
    print('\n6. Token flow pattern:');

    // Step 1 of the flow, made concrete. The security module declares the
    // authentication DTOs and no transport of its own — the exchange runs over
    // `TomServerEndpoint` from the `http_connection` module. A login addresses
    // the *authentication* server rather than the API base URI, and sends no
    // bearer token, because establishing one is the point of the call.
    //
    // Building an endpoint opens no connection; the channel creates its HTTP
    // client on the first call. So this example can assert the shape without a
    // server — only `send` reaches the network, and it answers a
    // `(result, error)` pair rather than throwing.
    final loginEndpoint =
        TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>(
          TomServerChannel('auth.example.com', 443),
          TomServerCallSpecs(
            'POST',
            Uri.parse('https://auth.example.com/authenticate'),
            includeBearerAuthentication: false,
          ),
        );

    assert(loginEndpoint.specs.method == 'POST', 'Credentials are posted');
    assert(
      !loginEndpoint.specs.includeBearerAuthentication,
      'A login carries no bearer token — it is what produces one',
    );

    print('   LOGIN FLOW:');
    print('   1. Client sends credentials to auth server');
    print('      ${loginEndpoint.specs.method} ${loginEndpoint.specs.url}');
    print('   2. Server validates credentials');
    print('   3. Server creates TomPrincipal for user');
    print('   4. Server calls convertPrincipalToTokenPayload()');
    print('   5. Server creates JWT tokens with TomServerJwtToken');
    print('   6. Server returns tokens to client');
    print('');
    print('   CLIENT STORAGE:');
    print('   1. Client receives tokens');
    print('   2. Client calls TomBearerAuthentication.setTokens()');
    print('   3. Tokens are parsed and principal is cached');
    print('');
    print('   API CALLS:');
    print('   1. Client reads token via TomBearerAuthentication.token');
    print('   2. Token included in Authorization: Bearer <token> header');
    print('   3. Server validates token and extracts principal');
  }

  // --------------------------------------------------------------------------
  // Example 7: Updating principal permissions
  // --------------------------------------------------------------------------
  static void example7UpdatePrincipal() {
    print('\n7. Updating principal permissions:');

    print('   - TomBearerAuthentication.updatePrincipal() allows');
    print('     refreshing permissions without re-authentication');
    print('');
    print('   Use cases:');
    print('   * User\'s role changes during session');
    print('   * New entitlements granted');
    print('   * Group membership updated');
    print('   * Resource keys modified');
    print('');
    print('   Example call:');
    print('   TomBearerAuthentication.updatePrincipal(');
    print('     [\'group1\', \'group2\'],  // Updated groups');
    print('     [\'admin\', \'user\'],     // Updated roles');
    print('     [\'feature.*\'],         // Updated entitlements');
    print('     [\'user.email\'],        // Updated resource keys');
    print('     resourceRoles: {\'project.apollo\': \'owner\'},');
    print('   );');
    print('');
    print('   The call REPLACES the ACI, it does not merge into it.');
    print('   Pass all five collections every time: resourceRoles is the');
    print('   only optional one, so omitting it compiles and silently');
    print('   clears every per-resource grant the principal held.');
  }

  // --------------------------------------------------------------------------
  // Example 8: Static token accessors
  // --------------------------------------------------------------------------
  static void example8StaticAccessors() {
    print('\n8. Static token accessors:');

    print('   Available static accessors on TomBearerAuthentication:');
    print('   * token - Raw authentication token string');
    print('   * authorizationToken - Raw authorization token string');
    print('   * clientJwtToken - Parsed TomClientJwtToken for auth');
    print(
      '   * clientAuthorizationJwtToken - Parsed TomClientJwtToken for authz',
    );
    print('   * getPrincipal() - Get the current TomPrincipal');
    print('');
    print('   Current state:');
    print('   * token: ${TomBearerAuthentication.token ?? 'null'}');
    print(
      '   * authorizationToken: ${TomBearerAuthentication.authorizationToken ?? 'null'}',
    );
    print(
      '   * clientJwtToken: ${TomBearerAuthentication.clientJwtToken ?? 'null'}',
    );
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('BEARER AUTHENTICATION EXAMPLE');
  print(
    '═══════════════════════════════════════════════════════════════════\n',
  );

  BearerAuthenticationExample.example1AuthenticationStructure();
  BearerAuthenticationExample.example2ConvertPrincipalToPayload();
  BearerAuthenticationExample.example3PayloadStructure();
  BearerAuthenticationExample.example4ResourceProtection();
  BearerAuthenticationExample.example5ClientLimits();
  BearerAuthenticationExample.example6TokenFlowPattern();
  BearerAuthenticationExample.example7UpdatePrincipal();
  BearerAuthenticationExample.example8StaticAccessors();

  print('\n✓ All bearer authentication examples passed!\n');
}

void main() {
  requireAsserts();
  run();
}
