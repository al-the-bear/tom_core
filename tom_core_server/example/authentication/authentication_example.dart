/// Executable example for the authentication module of `tom_core_server`.
///
/// Demonstrates the [TomAuthenticationService] contract end to end without a
/// running HTTP server or database: building [TomAuthenticationData], resolving
/// it through a service into a [TomAuthenticationInfo], rejecting a login with a
/// [LoginException], reading the adaptor-annotation configuration, choosing the
/// pending-authorization store through [TomOAuthStateStoreSettings], setting
/// how much clock skew an ID token's expiry is read against, listing an
/// account's external identities as detached snapshots, and watching a grant
/// that can never again mint a token be deleted rather than kept.
///
/// Run with `dart run example/authentication/authentication_example.dart`.
/// The same behaviour is covered by `test/authentication_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// Builds the data for one login attempt with sensible example defaults.
TomAuthenticationData _login(String username, {Object? password}) =>
    TomAuthenticationData(
      username: username,
      key: password,
      organization: 'acme',
      application: 'console',
      process: 'login',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    );

/// The endpoints and credentials every provider needs, so the examples below
/// can vary only the part they are about.
const Map<String, Object> _providerConfig = {
  'issuer': 'https://accounts.example.com',
  'authorizationEndpoint': 'https://accounts.example.com/authorize',
  'tokenEndpoint': 'https://accounts.example.com/token',
  'clientId': 'example-client',
  'clientSecret': 'example-secret',
  'redirectUri': 'https://app.example.com/oauth/callback',
};

/// A minimal service: one known user, everything else rejected.
class DemoAuthService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) async {
    if (authData.username != 'alice' || authData.key != 's3cret') {
      throw LoginException(
        'error.invalid-user-or-password',
        'Invalid user or password',
        parameters: {'username': authData.username},
      );
    }
    // Reuse the dummy service to assemble a principal for the accepted user.
    final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
    return dummy.authenticateUser(authData);
  }
}

Future<void> run() async {
  // Example 1: the scaffolding service authenticates any non-GUEST user.
  final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
  final guest = await dummy.authenticateUser(_login('GUEST'));
  final user = await dummy.authenticateUser(_login('bob'));
  print('dummy GUEST authenticated: ${guest.principal.authenticated}');
  print('dummy bob authenticated:   ${user.principal.authenticated}');

  // Example 2: a real service accepts the correct credential.
  final service = DemoAuthService();
  final ok = await service.authenticateUser(
    _login('alice', password: 's3cret'),
  );
  print('alice authenticated as:    ${ok.principal.user.username}');

  // Example 3: a wrong credential is rejected with a LoginException.
  try {
    await service.authenticateUser(_login('alice', password: 'wrong'));
  } on LoginException catch (e) {
    print('rejected with key:         ${e.key}');
  }

  // Example 4: adaptor annotations carry their routing configuration.
  final guestAdaptor = TomAuthenticationAdaptor(guestOnly: true);
  const totp = Tom2FAAdaptor('totp');
  print('guest-only adaptor:        ${guestAdaptor.guestOnly}');
  print('2FA adaptor type:          ${totp.type}');

  // Example 5: where pending OAuth authorizations live is configuration.
  // A single node keeps the in-memory store and configures nothing; a cluster
  // names a data source, because the provider's redirect lands on whichever
  // node the load balancer picks, not the one that began the flow.
  final singleNode = TomOAuthStateStoreSettings.fromConfiguration(
    TomServerConfigResourceProvider.from({
      'oauth': {'providers': <String, Object>{}},
    }),
  );
  final clustered = TomOAuthStateStoreSettings.fromConfiguration(
    TomServerConfigResourceProvider.from({
      'oauth': {
        'stateStore': {'type': 'sql', 'datasource': 'main'},
      },
    }),
  );
  print('default state store:       ${singleNode.type.name}');
  print(
    'clustered state store:     ${clustered.type.name} '
    'on "${clustered.datasourceName}"/${clustered.table}',
  );

  // Example 6: holding a provider's tokens is opt-in, per provider. "Sign in
  // with X" needs nothing; an application that calls X's API on the user's
  // behalf says so — and usually has to say so to the provider too, which is
  // what `authorizationParameters` carries.
  //
  // Note what these two registrations are: **one IdP, registered twice**. They
  // share an issuer, differing only in scope and in whether the grant is kept,
  // which is the ordinary way to offer sign-in and delegated access side by
  // side. A provider is keyed by its own id precisely so that this is
  // expressible, and every decision a login takes from configuration follows
  // the registration the flow began with — carried on `TomOAuthExchange`.
  final providers = TomOAuthProviders.fromConfiguration(
    TomServerConfigResourceProvider.from({
      'oauth': {
        'providers': {
          'login_only': _providerConfig,
          'calendar': {
            ..._providerConfig,
            'storeTokens': true,
            'authorizationParameters': {
              'access_type': 'offline',
              'prompt': 'consent',
            },
          },
        },
      },
    }),
  );
  print('login_only keeps tokens:   ${providers['login_only'].storeTokens}');
  print(
    'calendar keeps tokens:     ${providers['calendar'].storeTokens} '
    '${providers['calendar'].authorizationParameters}',
  );

  // Example 7: how stale an ID token may be is configuration too. The flow does
  // not verify the token's signature -- it came down the server's own TLS back
  // channel, so nobody could have substituted it -- but that argument is about
  // authenticity and says nothing about freshness, so `exp` is checked anyway.
  // The tolerance is per provider, because the drift being forgiven belongs to
  // one specific IdP.
  final clocks = TomOAuthProviders.fromConfiguration(
    TomServerConfigResourceProvider.from({
      'oauth': {
        'providers': {
          'well_synced': _providerConfig,
          'slow_clock': {..._providerConfig, 'clockSkewSeconds': 300},
        },
      },
    }),
  );
  print('default skew:              ${clocks['well_synced'].clockSkew}');
  print('widened skew:              ${clocks['slow_clock'].clockSkew}');

  // Example 8: a grant is held against the external identity that consented to
  // it, and it never outlives the link. `unlink` deletes both — the user
  // pressed "disconnect", so the deployment must not still hold a live
  // credential for their mailbox.
  final tokens = TomMemoryOAuthTokenStore();
  final identities = TomMemoryExternalIdentityStore(tokenStore: tokens);
  const identity = TomExternalIdentity(
    issuer: 'https://accounts.example.com',
    subject: 'user-42',
  );
  await identities.link(identity, 'alice');
  await tokens.store(
    identity.issuer,
    identity.subject,
    TomOAuthTokenGrant(
      accessToken: 'at-live',
      refreshToken: 'rt-long-lived',
      scope: 'calendar.readonly',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 55)),
    ),
  );
  final held = await tokens.read(identity.issuer, identity.subject);
  // Neither token is printed: `toString` names the grant instead, because this
  // value reaches log lines and both fields are credentials.
  print('held grant:                $held');
  print(
    'needs refresh in an hour:  '
    '${held!.expiresWithin(const Duration(hours: 1))}',
  );

  // What an account-settings page lists is a *snapshot*: the list is
  // unmodifiable and every link in it is detached, so a page that normalises a
  // display name for display is not thereby editing the store. Writing a change
  // back is `link` or `recordLogin`, never mutation of a returned row.
  final linked = await identities.identitiesOf('alice');
  linked.single.localUsername = 'someone-else';
  final stillLinkedTo = await identities.localUsernameFor(identity);
  print('links listed:              ${linked.length}');
  print('store after editing one:   $stillLinkedTo');

  await identities.unlink(identity.issuer, identity.subject);
  print(
    'grant after unlink:        '
    '${await tokens.read(identity.issuer, identity.subject)}',
  );

  // Example 9: a grant that expired with no refresh token is deleted when
  // `accessTokenFor` finds it, not merely reported as null. It can never mint
  // another token, so it is a fact about the past rather than a credential --
  // and a store that keeps it grows rows an operator cannot tell apart from
  // live but idle ones. (A *rejected* refresh is kept and thrown on instead: a
  // provider erroring during an outage is not proof the grant is dead.)
  final flow = TomOAuthFlow(
    providers: providers,
    stateStore: TomOAuthMemoryStateStore(),
    // Never reached below: the dead-grant path answers before any HTTP.
    transport: const TomHttpOAuthTokenTransport(),
  );
  await tokens.store(
    providers['calendar'].issuer,
    'user-99',
    TomOAuthTokenGrant(
      accessToken: 'at-stale',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
    ),
  );
  final dead = await flow.accessTokenFor(
    providerId: 'calendar',
    subject: 'user-99',
    store: tokens,
  );
  print('dead grant answered:       $dead');
  print(
    'dead grant still stored:   '
    '${await tokens.read(providers['calendar'].issuer, 'user-99') != null}',
  );

  // Assertions
  assert(guest.principal.authenticated == false);
  assert(user.principal.authenticated == true);
  assert(ok.principal.user.username == 'alice');
  assert(guestAdaptor.guestOnly && !guestAdaptor.userOnly);
  assert(totp.type == 'totp');
  assert(singleNode.type == TomOAuthStateStoreType.memory);
  assert(clustered.type == TomOAuthStateStoreType.sql);
  assert(clustered.table == defaultOAuthStateTable);
  assert(providers['login_only'].storeTokens == false);
  assert(providers['calendar'].storeTokens == true);
  assert(providers['calendar'].authorizationParameters.length == 2);
  // One IdP, two registrations: the issuer does not tell them apart.
  assert(providers['login_only'].issuer == providers['calendar'].issuer);
  assert(clocks['well_synced'].clockSkew == const Duration(seconds: 60));
  assert(clocks['slow_clock'].clockSkew == const Duration(minutes: 5));
  assert(held.hasRefreshToken);
  assert(!held.isExpired());
  assert(!'$held'.contains('rt-long-lived'));
  assert(linked.length == 1);
  assert(stillLinkedTo == 'alice');
  assert(await tokens.read(identity.issuer, identity.subject) == null);
  assert(await identities.localUsernameFor(identity) == null);
  assert(dead == null);
  assert(await tokens.read(providers['calendar'].issuer, 'user-99') == null);
}

void main() => run();
