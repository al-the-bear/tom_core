/// Demonstrates the **external-identity contract** — the part of an OAuth 2.0 /
/// OpenID Connect login that lives in the kernel, and why it is only that part.
///
/// The *flow* is server-side and cannot be shown here: it needs a client secret,
/// a call to the provider's token endpoint, and a linking table. What the kernel
/// owns is the agreement the two halves bind to — which providers exist, how a
/// client asks for an authorization URI, and what the provider's redirect
/// carries back. All of that is inspectable without a server, which is what this
/// sample does.
///
/// The one thing worth arriving at is the last: `/oauth/callback` answers with a
/// [TomAuthenticationResult], the *same* type `/login` answers with — same token
/// pair, same `requires2FA` handshake, same enrolment offer. An external
/// identity resolves a principal; everything after the principal is resolved is
/// the one login path every credential reaches. Signing in with Google does not
/// excuse you from your second factor.
///
/// Key concepts covered:
/// - [TomOAuthProviderDto] as a catalog entry carrying resource *keys*, and
///   [TomOAuthProviderDto.scoped] making the `oauth.<id>.*` convention
///   structural rather than a matter of per-provider discipline
/// - [TomOAuthAuthorizationRequest] carrying login context and no redirect URI
///   — a redirect target the caller may name is an open redirect
/// - [TomOAuthAuthorizationDto.state] as a correlation handle, not a credential
/// - [tomOAuthApi] and the four id constants ([tomOAuthApiId] and the three
///   endpoint ids) as the strings the server restates in its
///   `@TomApiEndpointImplementation` annotations
/// - [TomApiEndpoint.urlParameterMapping] binding the provider's snake_case
///   `error_description` onto the DTO's `errorDescription`, so the provider's
///   spelling never reaches the Dart shape
/// - [TomPublicAccess] on all three endpoints, and why public is not unguarded
/// - [registerTomOAuthApi] as the explicit, idempotent registration both halves
///   call, and [TomOAuthApiService] as the contract's Dart face
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// OAuth / External Identity Contract Example
// =============================================================================

/// Where this imaginary deployment is reachable.
final Uri _baseUri = Uri.parse('https://api.example.com');

Future<void> run() async {
  print('=== 10: The External-Identity Contract ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: the catalog a client renders.
  //   Deliberately thin: an id and two resource keys. Issuer URLs, client ids,
  //   secrets and scopes are the server's business and are not on the wire.
  // ---------------------------------------------------------------------------
  print('1. The provider catalog:');

  final google = TomOAuthProviderDto.scoped('google');
  final acme = TomOAuthProviderDto(
    id: 'acme-sso',
    displayNameKey: 'oauth.acme-sso.name',
    iconKey: 'branding.acme.mark',
  );

  print('   - scoped("google") : $google');
  print('   -   displayNameKey : ${google.displayNameKey}');
  print('   -   iconKey        : ${google.iconKey}');
  print('   - explicit keys    : ${acme.displayNameKey} / ${acme.iconKey}');
  print('   → keys, never text: the tier that renders knows the locale\n');

  // ---------------------------------------------------------------------------
  // Example 2: registering the contract.
  //   Explicit rather than implicit in a top-level initializer, because a
  //   deployment that configures no providers should not carry the API at all.
  // ---------------------------------------------------------------------------
  print('2. Registration is explicit and idempotent:');

  final registeredBefore = tomRemoteApis.apis.containsKey(tomOAuthApiId);

  registerTomOAuthApi();
  final countAfterFirst = tomRemoteApis.apis.length;
  registerTomOAuthApi();
  final countAfterSecond = tomRemoteApis.apis.length;

  final fromRegistry = tomRemoteApis[tomOAuthApiId];

  print('   - present before registering : $registeredBefore');
  print(
    '   - registry size after 1 / 2  : '
    '$countAfterFirst / $countAfterSecond',
  );
  print('   - tomRemoteApis["$tomOAuthApiId"] : ${fromRegistry.name}');
  print('   → both halves call this; the second call is a no-op\n');

  // ---------------------------------------------------------------------------
  // Example 3: the three endpoints, as the server will mount them.
  //   The ids are constants precisely because the server's
  //   @TomApiEndpointImplementation(apiId:, endpointId:) has to name them. A
  //   literal restated over there is the one string that can go wrong while
  //   both sides still compile.
  // ---------------------------------------------------------------------------
  print('3. The endpoints:');

  final providers = tomOAuthApi[tomOAuthProvidersEndpointId];
  final begin = tomOAuthApi[tomOAuthBeginEndpointId];
  final complete = tomOAuthApi[tomOAuthCompleteEndpointId];

  for (final endpoint in [providers, begin, complete]) {
    print(
      '   - ${endpoint.id.padRight(26)} '
      '${endpoint.method.name.toUpperCase().padRight(5)} '
      '${endpoint.resolveUri(_baseUri)}',
    );
  }
  print(
    '   - all public : '
    '${[providers, begin, complete].every((e) => e.access is TomPublicAccess)}',
  );
  print('   → public because this is how a caller who is not yet');
  print('     authenticated becomes authenticated — like /login\n');

  // ---------------------------------------------------------------------------
  // Example 4: starting a flow.
  //   Note what the request does NOT carry: a redirect URI. Where the provider
  //   sends the user back is server configuration, because a redirect target a
  //   caller may choose is an open redirect — an attacker who can name it has
  //   the provider deliver a live authorization code to a host they own.
  // ---------------------------------------------------------------------------
  print('4. Asking for an authorization URI:');

  final service = _DemoOAuthService();

  final catalog = await service.listOAuthProviders();
  final request = TomOAuthAuthorizationRequest(
    providerId: catalog.first.id,
    client: 'reports-web',
    application: 'reports',
    organization: 'acme',
    clientLanguage: 'de',
    clientCountry: 'DE',
    clientTimezone: 'Europe/Berlin',
  );
  final authorization = await service.beginOAuthAuthorization(request);

  print('   - catalog          : ${catalog.map((p) => p.id).join(', ')}');
  print('   - request          : $request');
  print(
    '   - request.organization / language : '
    '${request.organization} / ${request.clientLanguage}',
  );
  print('   - authorizationUri : ${authorization.authorizationUri}');
  print('   - state            : ${authorization.state}');
  print('   → the context is captured now, because the redirect that comes');
  print('     back is a plain browser navigation carrying none of it\n');

  // ---------------------------------------------------------------------------
  // Example 5: the redirect, and the one seam where spelling matters.
  //   The provider redirects a browser, so everything arrives in the query
  //   string. urlParameterMapping declares the provider's snake_case names once,
  //   on the left; the DTO keeps Dart's camelCase on the right.
  // ---------------------------------------------------------------------------
  print('5. The callback binds the provider\'s spelling:');

  final mapping = complete.urlParameterMapping;
  final declinedRedirect = complete.resolveUri(
    _baseUri,
    parameters: {
      'state': authorization.state,
      'error': 'access_denied',
      'errorDescription': 'The user declined',
    },
  );

  print('   - mapping        : $mapping');
  print('   - a refusal URL  : $declinedRedirect');
  print('   → error_description on the wire, errorDescription in Dart,');
  print('     declared in exactly one place\n');

  // ---------------------------------------------------------------------------
  // Example 6: a refusal is not an exception.
  //   The provider said no; the endpoint still answers with the login type,
  //   carrying an error and no tokens.
  // ---------------------------------------------------------------------------
  print('6. The user declined:');

  final declined = await service.completeOAuthAuthorization(
    TomOAuthCallbackRequest(
      state: authorization.state,
      error: 'access_denied',
      errorDescription: 'The user declined',
    ),
  );

  print('   - result.error              : ${declined.error}');
  print('   - result.authenticationToken: "${declined.authenticationToken}"');
  print('   → same type, same field, no special OAuth error shape\n');

  // ---------------------------------------------------------------------------
  // Example 7: the punchline.
  //   The code is exchanged, the principal is resolved — and the login lands in
  //   exactly the state a password login would, second factor and all.
  // ---------------------------------------------------------------------------
  print('7. Success — and the second factor is still owed:');

  final callback = TomOAuthCallbackRequest(
    code: 'provider-code-4711',
    state: authorization.state,
  );
  final result = await service.completeOAuthAuthorization(callback);

  print('   - callback              : $callback');
  print('   - result.error          : "${result.error}"');
  print('   - result.requires2FA    : ${result.requires2FA}');
  print('   - result.twoFactorType  : ${result.twoFactorType}');
  print('   - result.authorizationToken: "${result.authorizationToken}"');
  print('   → from here it is sample 09, unchanged: an external identity');
  print('     resolves a principal, it does not finish a login\n');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: the scoped constructor derives both keys; explicit ones are free
  // to differ, because an in-house provider may live in a branding bundle.
  assert(google.id == 'google');
  assert(google.displayNameKey == 'oauth.google.name');
  assert(google.iconKey == 'oauth.google.icon');
  assert(
    google.displayNameKey.startsWith('${TomOAuthProviderDto.resourceScope}.'),
  );
  assert(acme.iconKey == 'branding.acme.mark');
  // Reflection constructs a wire DTO empty and fills it in (G-DTO-1/2).
  assert(TomOAuthProviderDto().id.isEmpty);

  // Example 2: registration is idempotent and keyed by the id constant.
  assert(tomOAuthApiId == 'tomOAuth');
  assert(countAfterSecond == countAfterFirst);
  assert(identical(fromRegistry, tomOAuthApi));
  assert(identical(TomRemoteApis.getApiById(tomOAuthApiId), tomOAuthApi));

  // Example 3: the ids, URIs, methods and access the server binds to. Asserted
  // as literals on purpose — these are the strings the implementation side
  // restates, so a rename must break here rather than at runtime.
  assert(tomOAuthProvidersEndpointId == 'listOAuthProviders');
  assert(tomOAuthBeginEndpointId == 'beginOAuthAuthorization');
  assert(tomOAuthCompleteEndpointId == 'completeOAuthAuthorization');
  assert(tomOAuthApi.uri == '/oauth');
  assert(tomOAuthApi.endpoints.length == 3);
  assert(providers.method == TomHttpMethod.get);
  assert(begin.method == TomHttpMethod.post);
  assert(complete.method == TomHttpMethod.get);
  assert(
    providers.resolveUri(_baseUri).toString() ==
        'https://api.example.com/oauth/providers',
  );
  assert(
    begin.resolveUri(_baseUri).toString() ==
        'https://api.example.com/oauth/authorize',
  );
  assert(providers.access is TomPublicAccess);
  assert(begin.access is TomPublicAccess);
  assert(complete.access is TomPublicAccess);
  // The provider catalog is a GET with nothing to send.
  assert(providers.requestTypes.isEmpty);

  // Example 4: the request carries context and no redirect target.
  assert(catalog.length == 2);
  assert(request.providerId == 'google');
  assert(request.clientTimezone == 'Europe/Berlin');
  assert(authorization.authorizationUri.startsWith('https://'));
  assert(authorization.state.isNotEmpty);
  // Not a credential: it correlates, it does not authenticate.
  assert(TomOAuthAuthorizationDto().state.isEmpty);

  // Example 5: the mapping is the single place the provider's spelling lives.
  assert(mapping['error_description'] == 'errorDescription');
  assert(mapping['code'] == 'code');
  assert(mapping.length == 4);
  assert(
    declinedRedirect.toString() ==
        'https://api.example.com/oauth/callback'
            '?state=${authorization.state}'
            '&error=access_denied&error_description=The+user+declined',
  );

  // Example 6: a refusal is an ordinary result.
  assert(declined.error.isNotEmpty);
  assert(declined.authenticationToken.isEmpty);
  assert(!declined.requires2FA);

  // Example 7: success answers with the login type, mid-handshake. The
  // declaration says so too — the callback endpoint's response type is the
  // login result, not an OAuth-shaped cousin of it.
  assert(
    complete
        is TomApiEndpoint<TomAuthenticationResult, TomOAuthCallbackRequest>,
  );
  assert(result.error.isEmpty);
  assert(result.authenticationToken.isNotEmpty);
  assert(result.authorizationToken.isEmpty);
  assert(result.requires2FA);
  assert(result.twoFactorType == 'totp');

  print('OAuth contract example complete.\n');
}

/// A server-free stand-in for the deployment's OAuth service.
///
/// Implementing [TomOAuthApiService] at all is the point: the interface and the
/// endpoint declarations are two independent statements of the same three calls,
/// and an implementation is what stops them drifting apart unnoticed.
class _DemoOAuthService implements TomOAuthApiService {
  @override
  Future<List<TomOAuthProviderDto>> listOAuthProviders() async => [
    TomOAuthProviderDto.scoped('google'),
    TomOAuthProviderDto.scoped('github'),
  ];

  @override
  Future<TomOAuthAuthorizationDto> beginOAuthAuthorization(
    TomOAuthAuthorizationRequest request,
  ) async => TomOAuthAuthorizationDto(
    authorizationUri:
        'https://accounts.${request.providerId}.example/authorize'
        '?client_id=srv&redirect_uri=${Uri.encodeQueryComponent('$_baseUri/oauth/callback')}&state=pending-1&code_challenge=…',
    state: 'pending-1',
  );

  @override
  Future<TomAuthenticationResult> completeOAuthAuthorization(
    TomOAuthCallbackRequest request,
  ) async {
    if (request.error.isNotEmpty) {
      return TomAuthenticationResult(
        'oauth.provider.refused: ${request.error}',
      );
    }
    // The principal is resolved; the login is not finished.
    return TomAuthenticationResult()
      ..authenticationToken = '<interim>'
      ..requires2FA = true
      ..twoFactorType = 'totp';
  }
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}
