/// Bearer Authentication Example
///
/// [TomBearerAuthentication] is the client-side store of an authenticated
/// session: the token pair, the principal derived from it, and the static
/// accessors everything else reads through.
///
/// This example runs a whole session in process, because every step of it can
/// be: a principal is converted to token payloads, real JWTs are minted from
/// them, the pair is installed, the principal is read back, its rights are
/// replaced, and the session is cleared.
///
/// - the empty state, and that reading a principal from it is an error
/// - `convertPrincipalToTokenPayload` and the public/private split
/// - which identity fields redaction removes, and whose keys decide it
/// - `setTokens` / `getPrincipal` / `clearTokens`
/// - `updatePrincipal`, and the fact that it *replaces* an ACI
///
/// `03_advanced_access_control_example.dart` owns [TomResourceKeyProtection]
/// in general — `protect()` against the ambient zone. What example 4 below
/// adds is the part specific to minting a token: the operand is the subject
/// the token is *for*, not whoever the zone names.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/04_bearer_authentication_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class BearerAuthenticationExample {
  // Captured results
  static late Map<String, Object?> publicPayload;
  static late Map<String, Object?> privatePayload;
  static bool emptyStateRefusesPrincipal = false;
  static bool payloadConversionWorks = false;
  static bool payloadGroupsPresent = false;
  static bool redactionFollowsSubject = false;
  static bool clientLimitsTravel = false;
  static bool updateReplacesAci = false;
  static bool sessionLifecycleWorks = false;

  /// The subject every example below mints a token for.
  ///
  /// [resourceKeys] is a parameter because example 4 turns redaction on and
  /// needs two subjects that differ in nothing else.
  static TomPrincipal _subject({
    List<String> resourceKeys = const ['user.email', 'user.phone'],
    Map<String, String> resourceRoles = const {'project.apollo': 'owner'},
  }) => TomPrincipal(
    authenticated: true,
    user: TomUser(
      id: 123,
      username: 'john.doe',
      firstname: 'John',
      lastname: 'Doe',
      email: 'john.doe@example.com',
      phone: '+1-555-0123',
      timezone: 'America/New_York',
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
      resourceKeys: resourceKeys,
      resourceRoles: resourceRoles,
    ),
    cli: TomClientLimitsInformation(
      enabledModules: ['module.reports', 'module.analytics'],
      quotas: {'api.calls': 10000, 'storage.mb': 500},
    ),
  );

  /// A signed token pair for [principal], as an auth server would issue it.
  ///
  /// The authentication token carries identity only; the authorization token
  /// carries the same identity plus the ACI, encrypted. `setTokens` derives
  /// the principal from the authorization token, so that is the one that has
  /// to be complete.
  static (String authentication, String authorization) _issueTokens(
    TomPrincipal principal,
  ) {
    final (
      public,
      private,
    ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
      principal,
      null, // no ACI definition for this example
      'US',
      'en',
    );
    return (
      TomServerJwtToken(public).getJWT('auth.example.com'),
      TomServerJwtToken(
        public,
        encryptedData: private,
      ).getJWT('auth.example.com'),
    );
  }

  // --------------------------------------------------------------------------
  // Example 1: The singleton, and the state before a login
  // --------------------------------------------------------------------------
  static void example1AuthenticationStructure() {
    print('1. Bearer authentication before a login:');

    // Every static accessor on the class reads through this one field, so it
    // *is* the client-side session. Clearing first makes this example
    // independent of whatever ran before it in `run_all_samples.dart`.
    final auth = TomBearerAuthentication.bearerAuthentication;
    TomBearerAuthentication.clearTokens();

    print(
      '   - the statics read through one instance : '
      '${identical(auth, TomBearerAuthentication.bearerAuthentication)}',
    );
    print('   - authentication token : ${TomBearerAuthentication.token}');
    print(
      '   - authorization token  : '
      '${TomBearerAuthentication.authorizationToken}',
    );
    print(
      '   - parsed auth token    : '
      '${TomBearerAuthentication.clientJwtToken}',
    );

    // With no token there is no identity, and the class says so rather than
    // handing back an empty principal that would read as an anonymous user.
    Object? refusal;
    try {
      TomBearerAuthentication.getPrincipal();
    } on StateError catch (e) {
      refusal = e;
    }
    print('   - getPrincipal()       : throws ${refusal.runtimeType}');

    emptyStateRefusesPrincipal = refusal is StateError;

    // Assertions
    assert(
      identical(auth, TomBearerAuthentication.bearerAuthentication),
      'The static accessors and the instance are the same session',
    );
    assert(TomBearerAuthentication.token == null, 'No token before a login');
    assert(
      TomBearerAuthentication.clientJwtToken == null,
      'Nothing is parsed before a login',
    );
    assert(
      emptyStateRefusesPrincipal,
      'An absent identity must be an error, not an empty principal',
    );
  }

  // --------------------------------------------------------------------------
  // Example 2: Converting a principal to token payloads
  // --------------------------------------------------------------------------
  static void example2ConvertPrincipalToPayload() {
    print('\n2. Converting principal to token payload:');

    final result = TomBearerAuthentication.convertPrincipalToTokenPayload(
      _subject(),
      null,
      'US',
      'en',
    );
    publicPayload = result.$1;
    privatePayload = result.$2;

    print('   - public payload keys  : ${publicPayload.length}');
    print('   - private payload keys : ${privatePayload.keys.toList()}');
    print('   Public samples:');
    print('     username     : ${publicPayload['username']}');
    print('     userId       : ${publicPayload['userId']}');
    print('     organization : ${publicPayload['organization']}');
    print('   Private samples:');
    print('     roles         : ${privatePayload['roles']}');
    print('     entitlements  : ${privatePayload['entitlements']}');
    print('     resourceRoles : ${privatePayload['resourceRoles']}');

    payloadConversionWorks =
        publicPayload['username'] == 'john.doe' &&
        privatePayload['roles'] != null;

    // Assertions
    assert(publicPayload['username'] == 'john.doe', 'Username should match');
    assert(publicPayload['userId'] == 123, 'User ID should match');
    assert(
      (privatePayload['roles'] as List).contains('premium'),
      'Should have premium role',
    );
    // The split is the point: rights are never in the public half.
    assert(
      !publicPayload.containsKey('roles') &&
          !publicPayload.containsKey('entitlements'),
      'Access rights belong to the encrypted half only',
    );
    assert(payloadConversionWorks, 'Payload conversion should work');
  }

  // --------------------------------------------------------------------------
  // Example 3: What each half of the payload carries
  // --------------------------------------------------------------------------
  static void example3PayloadStructure() {
    print('\n3. Token payload structure:');

    print('   PUBLIC PAYLOAD (visible in the JWT):');
    print('   ├── User Info    — username, userId, firstname, lastname,');
    print('   │                  email, phone, mobile, address, userTimezone');
    print('   ├── Context      — organization, application, process (+ ids)');
    print('   ├── Localization — language, country, timezone, client*');
    print('   ├── 2FA          — requires2FA, twoFactorType');
    print('   └── Subscription — subscription_enabledModules,');
    print('                      subscription_quotas');
    print('');
    print('   PRIVATE PAYLOAD (encrypted in the JWT):');
    print('   └── context, groups, roles, entitlements, resourceKeys,');
    print('       resourceRoles');

    // The tree above is a claim about the payload example 2 built, so it is
    // checked against it rather than left to drift.
    const publicGroups = [
      'username',
      'userId',
      'firstname',
      'lastname',
      'email',
      'phone',
      'mobile',
      'addressLine1',
      'userTimezone',
      'organization',
      'application',
      'process',
      'organizationId',
      'applicationId',
      'processId',
      'language',
      'country',
      'timezone',
      'clientLanguage',
      'clientCountry',
      'clientTimezone',
      'requires2FA',
      'twoFactorType',
      'subscription_enabledModules',
      'subscription_quotas',
    ];
    const privateGroups = [
      'context',
      'groups',
      'roles',
      'entitlements',
      'resourceKeys',
      'resourceRoles',
    ];

    final missingPublic = publicGroups
        .where((k) => !publicPayload.containsKey(k))
        .toList();
    final missingPrivate = privateGroups
        .where((k) => !privatePayload.containsKey(k))
        .toList();

    print('');
    print('   - documented public claims absent  : $missingPublic');
    print('   - documented private claims absent : $missingPrivate');

    payloadGroupsPresent = missingPublic.isEmpty && missingPrivate.isEmpty;

    // Assertions
    assert(missingPublic.isEmpty, 'Every documented public claim should exist');
    assert(
      missingPrivate.isEmpty,
      'Every documented private claim should exist',
    );
    // The private half is exactly these six; a new one should update the tree.
    assert(
      privatePayload.keys.toSet().difference(privateGroups.toSet()).isEmpty,
      'The private payload carries nothing the tree above omits',
    );
    assert(payloadGroupsPresent, 'The documented structure should hold');
  }

  // --------------------------------------------------------------------------
  // Example 4: Whose resource keys decide redaction
  // --------------------------------------------------------------------------
  static void example4ResourceProtection() {
    print('\n4. Redaction in a minted payload:');

    // Protection is off by default, so turn it on for this example only.
    // `03_advanced_access_control_example.dart` uses the same switch and
    // restores it the same way.
    final wasProtecting =
        TomResourceKeyProtection.globalSettingProtectionDefault;
    TomResourceKeyProtection.globalSettingProtectionDefault = true;

    // Two subjects differing only in the keys they hold. Redaction is decided
    // by the subject the token is *for* — not by the ambient zone, which on
    // the login path holds nobody yet, and reading it would blank every
    // protected field of every minted token.
    final (
      holdsEmail,
      _,
    ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
      _subject(resourceKeys: ['tom.user.email']),
      null,
      'US',
      'en',
    );
    final (
      holdsNothing,
      _,
    ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
      _subject(resourceKeys: const []),
      null,
      'US',
      'en',
    );

    TomResourceKeyProtection.globalSettingProtectionDefault = wasProtecting;

    print('   Subject holding tom.user.email:');
    print('     email     : ${holdsEmail['email']}');
    print('     phone     : ${holdsEmail['phone']}   (key not held)');
    print('     firstname : ${holdsEmail['firstname']}   (key not held)');
    print(
      '     attributes: ${holdsEmail['attributes']}     (falls back to {})',
    );
    print('   Subject holding no keys at all:');
    print('     email     : ${holdsNothing['email']}');
    print('   Never filtered, for either subject:');
    print('     username  : ${holdsNothing['username']}');
    print('     userId    : ${holdsNothing['userId']}');

    redactionFollowsSubject =
        holdsEmail['email'] == 'john.doe@example.com' &&
        holdsEmail['phone'] == null &&
        holdsNothing['email'] == null;

    // Assertions
    assert(
      holdsEmail['email'] == 'john.doe@example.com',
      'A field survives when the subject holds its key',
    );
    assert(
      holdsEmail['phone'] == null && holdsEmail['firstname'] == null,
      'A field it does not hold falls back to null',
    );
    assert(
      holdsEmail['attributes'] is Map &&
          (holdsEmail['attributes'] as Map).isEmpty,
      'attributes falls back to an empty map rather than null',
    );
    assert(holdsNothing['email'] == null, 'Redaction follows the subject');
    assert(
      holdsNothing['username'] == 'john.doe' && holdsNothing['userId'] == 123,
      'username and userId always travel in the clear',
    );
    assert(
      TomResourceKeyProtection.globalSettingProtectionDefault == wasProtecting,
      'The global switch is left as it was found',
    );
    assert(redactionFollowsSubject, 'Subject-keyed redaction should work');
  }

  // --------------------------------------------------------------------------
  // Example 5: Client limits reach the client through the public payload
  // --------------------------------------------------------------------------
  static void example5ClientLimits() {
    print('\n5. Client limits information (CLI):');

    final cli = _subject().cli;

    print('   - enabled modules : ${cli.enabledModules}');
    print('   - quotas          :');
    cli.quotas.forEach((key, value) => print('     * $key: $value'));

    // The CLI is not a separate token section: it is flattened into the public
    // payload under `subscription_` names, which is how a client reads it back.
    final modules = publicPayload['subscription_enabledModules'];
    final quotas = publicPayload['subscription_quotas'];

    print('   In the public payload:');
    print('     subscription_enabledModules : $modules');
    print('     subscription_quotas         : $quotas');

    clientLimitsTravel =
        modules is List &&
        modules.contains('module.reports') &&
        quotas is Map &&
        quotas['api.calls'] == 10000;

    // Assertions
    assert(
      (modules as List).length == cli.enabledModules.length,
      'Every enabled module travels',
    );
    assert(
      (quotas as Map)['storage.mb'] == 500,
      'Quotas travel by value, not by name only',
    );
    assert(clientLimitsTravel, 'Client limits should reach the public payload');
  }

  // --------------------------------------------------------------------------
  // Example 6: Where the token pair comes from
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
    print('   1. Client posts credentials to the auth server');
    print('      ${loginEndpoint.specs.method} ${loginEndpoint.specs.url}');
    print('   2. Server validates them and builds a TomPrincipal');
    print('   3. Server calls convertPrincipalToTokenPayload()   — example 2');
    print('   4. Server signs the two payloads with TomServerJwtToken');
    print('   5. Client calls setTokens()                        — example 7');
    print('   6. Every later request reads TomBearerAuthentication.token');
  }

  // --------------------------------------------------------------------------
  // Example 7: A session, and what updatePrincipal does to it
  // --------------------------------------------------------------------------
  static void example7UpdatePrincipal() {
    print('\n7. Installing a session and updating its rights:');

    final (authentication, authorization) = _issueTokens(_subject());
    TomBearerAuthentication.setTokens(authentication, authorization);

    // `getPrincipal` hands back the live session object, not a copy of it, so
    // anything worth comparing across the update has to be copied out first.
    final session = TomBearerAuthentication.getPrincipal();
    final rolesBefore = List<String>.of(session.aci.roles);
    final groupsBefore = List<String>.of(session.aci.groups);
    final resourceRolesBefore = Map<String, String>.of(
      session.aci.resourceRoles,
    );

    print('   After setTokens():');
    print('     username      : ${session.username}');
    print('     roles         : $rolesBefore');
    print('     groups        : $groupsBefore');
    print('     resourceRoles : $resourceRolesBefore');

    // Four positional collections and one optional named one. Note what is
    // *not* passed: resourceRoles.
    TomBearerAuthentication.updatePrincipal(
      ['contractors'],
      ['admin'],
      ['feature.billing.view'],
      ['user.phone'],
    );

    final after = TomBearerAuthentication.getPrincipal();
    print('   After updatePrincipal() — resourceRoles omitted:');
    print('     roles         : ${after.aci.roles}');
    print('     groups        : ${after.aci.groups}');
    print('     entitlements  : ${after.aci.entitlements}');
    print('     resourceKeys  : ${after.aci.resourceKeys}');
    print('     resourceRoles : ${after.aci.resourceRoles}   <- cleared');
    print('   The update swapped the ACI on the cached principal, so the');
    print('   reference taken before it now reports the new rights:');
    print('     same object   : ${identical(session, after)}');
    print('     session.roles : ${session.aci.roles}');

    updateReplacesAci =
        after.aci.roles.length == 1 &&
        after.aci.roles.first == 'admin' &&
        after.aci.resourceRoles.isEmpty;

    // Assertions. The call REPLACES the ACI, it does not merge into it.
    assert(rolesBefore.contains('premium'), 'The session started with it');
    assert(
      !after.aci.roles.contains('premium') && after.aci.roles.contains('admin'),
      'updatePrincipal replaces the role list rather than adding to it',
    );
    assert(
      !after.aci.groups.contains('engineering'),
      'The same replacement applies to every collection',
    );
    // The update swaps the ACI on the principal that is already cached, so a
    // caller holding an earlier `getPrincipal()` result observes the new
    // rights through it. That is the session, not a snapshot of it — code that
    // needs the old values has to copy them, as this example does above.
    assert(
      identical(session, after),
      'getPrincipal returns the one live session object',
    );
    assert(
      !session.aci.roles.contains('premium'),
      'An earlier reference reports the updated rights',
    );
    // This is the trap worth knowing: resourceRoles is the one optional
    // parameter, so omitting it compiles and silently drops every
    // per-resource grant the principal held.
    assert(
      resourceRolesBefore.isNotEmpty && after.aci.resourceRoles.isEmpty,
      'Omitting resourceRoles clears the grants it would have carried',
    );
    assert(updateReplacesAci, 'updatePrincipal should replace the ACI');
  }

  // --------------------------------------------------------------------------
  // Example 8: The static accessors, over a session's lifetime
  // --------------------------------------------------------------------------
  static void example8StaticAccessors() {
    print('\n8. Static accessors over a session lifetime:');

    // Example 7 left a session installed.
    print('   While signed in:');
    print(
      '     token                : '
      '${TomBearerAuthentication.token?.length} chars',
    );
    print(
      '     authorizationToken   : '
      '${TomBearerAuthentication.authorizationToken?.length} chars',
    );
    print(
      '     clientJwtToken       : '
      '${TomBearerAuthentication.clientJwtToken?.issuer}',
    );
    print(
      '     getPrincipal()       : '
      '${TomBearerAuthentication.getPrincipal().username}',
    );

    final signedIn =
        TomBearerAuthentication.token != null &&
        TomBearerAuthentication.clientJwtToken != null &&
        TomBearerAuthentication.getPrincipal().username == 'john.doe';

    // The two tokens are distinct: only the authorization one carries the
    // encrypted ACI, which is why setTokens derives the principal from it.
    final authCarriesRights =
        TomBearerAuthentication.clientJwtToken?.secretData != null;
    final authzCarriesRights =
        TomBearerAuthentication.clientAuthorizationJwtToken?.secretData != null;
    print('     auth token carries rights  : $authCarriesRights');
    print('     authz token carries rights : $authzCarriesRights');

    TomBearerAuthentication.clearTokens();

    Object? refusal;
    try {
      TomBearerAuthentication.getPrincipal();
    } on StateError catch (e) {
      refusal = e;
    }
    print('   After clearTokens():');
    print('     token          : ${TomBearerAuthentication.token}');
    print('     getPrincipal() : throws ${refusal.runtimeType}');

    sessionLifecycleWorks =
        signedIn &&
        TomBearerAuthentication.token == null &&
        refusal is StateError;

    // Assertions
    assert(signedIn, 'The accessors report the installed session');
    assert(
      !authCarriesRights && authzCarriesRights,
      'Rights ride the authorization token only',
    );
    assert(
      TomBearerAuthentication.token == null &&
          TomBearerAuthentication.clientJwtToken == null,
      'clearTokens leaves a freshly constructed state',
    );
    assert(
      refusal is StateError,
      'A cleared session refuses a principal rather than returning a stale one',
    );
    assert(sessionLifecycleWorks, 'The session lifecycle should work');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('=== 04: Bearer Authentication Example ===\n');

  BearerAuthenticationExample.example1AuthenticationStructure();
  BearerAuthenticationExample.example2ConvertPrincipalToPayload();
  BearerAuthenticationExample.example3PayloadStructure();
  BearerAuthenticationExample.example4ResourceProtection();
  BearerAuthenticationExample.example5ClientLimits();
  BearerAuthenticationExample.example6TokenFlowPattern();
  BearerAuthenticationExample.example7UpdatePrincipal();
  BearerAuthenticationExample.example8StaticAccessors();

  // Final assertions
  assert(
    BearerAuthenticationExample.emptyStateRefusesPrincipal,
    'An empty session should refuse a principal',
  );
  assert(
    BearerAuthenticationExample.payloadConversionWorks,
    'Payload conversion should work',
  );
  assert(
    BearerAuthenticationExample.payloadGroupsPresent,
    'The documented payload structure should hold',
  );
  assert(
    BearerAuthenticationExample.redactionFollowsSubject,
    'Redaction should follow the subject the token is for',
  );
  assert(
    BearerAuthenticationExample.clientLimitsTravel,
    'Client limits should reach the public payload',
  );
  assert(
    BearerAuthenticationExample.updateReplacesAci,
    'updatePrincipal should replace the ACI',
  );
  assert(
    BearerAuthenticationExample.sessionLifecycleWorks,
    'The session lifecycle should work',
  );

  // Leave no session behind for the samples that follow.
  assert(
    TomBearerAuthentication.token == null,
    'This example must not leak a session into its siblings',
  );

  print('\n✓ All bearer authentication examples passed!\n');
}

void main() {
  prepareSampleProcess();
  run();
}
