/// External identity as an implementation of the *existing* authentication
/// contract (C-9).
///
/// [TomOAuthAuthenticationService] **implements [TomAuthenticationService]**.
/// That single fact is the design; everything else in this library follows from
/// it. It receives a [TomOAuthCredential] where a password login receives a
/// password, exchanges it, finds or provisions the local account, and returns an
/// ordinary [TomAuthenticationInfo].
///
/// Then it stops. It issues no token, consults no 2FA policy and makes no
/// session decision, because [TomAuthenticationServer.authenticateExternal]
/// hands its result to the same continuation a password login reaches. An
/// externally authenticated principal is therefore challenged for its second
/// factor, offered enrolment, and issued exactly the claims a password login
/// would have produced — not because this library reproduces those rules, but
/// because it never touches them.
///
/// ## Why a delegate rather than a replacement
///
/// A deployment installs *one*
/// [TomAuthenticationServer.globalSettingUserAuthenticationService]. If enabling
/// external login meant replacing it, enabling external login would mean
/// disabling passwords — so this service takes the deployment's existing service
/// as a [delegate] and passes any credential that is not a
/// [TomOAuthCredential] straight through. Wiring it up is one line, and an
/// account may hold a password *and* several external identities at once.
///
/// ```dart
/// TomAuthenticationServer.globalSettingUserAuthenticationService =
///     TomOAuthAuthenticationService(
///       directory: MyDirectory(),
///       delegate: TomAuthenticationServer.globalSettingUserAuthenticationService,
///     );
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'authentication_server.dart';
import 'external_provider.dart';
import 'oauth_flow.dart';
import 'oauth_identity.dart';
import 'oauth_provider.dart';
import 'oauth_tokens.dart';

/// The credential an external login carries in [TomAuthenticationData.key].
///
/// A typed value rather than a delimited string, because the pair is what the
/// flow needs and a `'code|state'` convention is a parser two files apart from
/// its formatter.
class TomOAuthCredential {
  /// The authorization code the provider issued.
  final String code;

  /// The handle of the pending authorization the code completes.
  final String state;

  /// Creates an external-login credential.
  const TomOAuthCredential({required this.code, required this.state});

  @override
  String toString() => 'TomOAuthCredential(state: $state)';
}

/// What the deployment supplies: how to turn a *local username* into an
/// authenticated principal, and what to do when there is no local account yet.
///
/// The framework deliberately does not know either. It has no user table — the
/// whole point of [TomAuthenticationService] is that a deployment owns that — so
/// an external login can go no further than "this is `alice@example.com` at
/// `https://accounts.google.com`" without asking the application who that is.
///
/// The two methods are separate because the second is a *decision* the first is
/// not: resolving a known account is a lookup, while creating one is a policy
/// choice, and a deployment that never wants the second should not have to
/// implement it as part of the first.
abstract class TomExternalIdentityDirectory {
  /// The principal and access-control definition for [username], which the
  /// external provider has already authenticated.
  ///
  /// Note what this method is *not* passed: a credential. The provider has
  /// verified the user; this is the deployment's account lookup, not a second
  /// authentication. An implementation that demanded a password here would be
  /// asking the user to log in twice.
  ///
  /// Returns `null` when no local account exists under [username] — which is
  /// what sends the login down the provisioning branch.
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  );

  /// Creates a local account from [identity] and returns its principal.
  ///
  /// Only ever called when the provider is configured with
  /// [TomOAuthProvisioning.autoProvision]. The default implementation refuses,
  /// so a deployment that turns auto-provisioning on without implementing this
  /// gets a clear error rather than a silently half-created account.
  ///
  /// `async` although nothing here awaits: the refusal must reach the caller as
  /// a rejected future, the way an override's failure would. This method is
  /// public and overridable, so its callers are not enumerable — one that only
  /// ever awaits would take a synchronous throw straight past its handler.
  Future<TomAuthenticationInfo> provisionFromExternalIdentity(
    TomExternalIdentity identity,
    TomAuthenticationData authData,
  ) async {
    throw TomLoginException(
      'login.error.oauth.provisioning-unsupported',
      'Provider auto-provisioning is configured, but this deployment\'s '
          'TomExternalIdentityDirectory does not implement '
          'provisionFromExternalIdentity.',
      reason: TomLoginFailure.providerError,
    );
  }

  /// The installed [TomExternalIdentityDirectory] bean, or `null`.
  static TomExternalIdentityDirectory? resolve() {
    final installed = TomBean.getBeanByType(TomExternalIdentityDirectory);
    return installed is TomExternalIdentityDirectory ? installed : null;
  }
}

/// A [TomAuthenticationService] that authenticates an OAuth 2.0 / OIDC
/// authorization code.
class TomOAuthAuthenticationService implements TomAuthenticationService {
  /// The deployment's account lookup and provisioning.
  final TomExternalIdentityDirectory directory;

  /// The service that handles every credential this one does not — typically
  /// the deployment's password service. `null` makes external identity the only
  /// way in, which is a legitimate choice and not the default one.
  final TomAuthenticationService? delegate;

  /// The handshake. Defaults to [TomOAuthFlow.fromBeans] at first use, so the
  /// ordinary deployment configures providers and wires nothing.
  final TomOAuthFlow? flow;

  /// Where `(issuer, subject)` → account links are kept. Defaults to the
  /// installed [TomExternalIdentityStore] bean.
  final TomExternalIdentityStore? identityStore;

  /// Where the provider's own tokens are kept for the providers that ask for it
  /// ([TomOAuthProviderConfig.storeTokens]). Defaults to the installed
  /// [TomOAuthTokenStore] bean, of which there usually is none — see the
  /// `oauth_tokens.dart` library documentation for why keeping nothing is the
  /// default.
  final TomOAuthTokenStore? tokenStore;

  /// Creates the service.
  const TomOAuthAuthenticationService({
    required this.directory,
    this.delegate,
    this.flow,
    this.identityStore,
    this.tokenStore,
  });

  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) async {
    final credential = authData.key;
    if (credential is! TomOAuthCredential) {
      return _passThrough(authData);
    }

    final exchange = await (flow ?? TomOAuthFlow.fromBeans())
        .completeAuthorization(code: credential.code, state: credential.state);
    final identity = exchange.identity;

    // The login context the *flow* recorded wins over whatever the message
    // carried: the callback is a browser navigation with no client, locale or
    // organization of its own, so trusting the message here would issue the
    // session in whatever the endpoint defaulted to rather than in the context
    // the user actually started the login from.
    _applyPendingContext(authData, exchange.pending);

    // The tenant and organization the provider's token names, read before
    // anything is linked or provisioned: a token for another tenant must not
    // create or reach an account here. The organization the provider names is
    // the sign-in organization — see TomExternalTenancyMapping.
    final mapping = exchange.provider.tenancyMapping;
    final claimedTenant = mapping.tenantIn(identity.claims);
    final current = TomTenantContext.currentId;
    if (claimedTenant != null && current != null && claimedTenant != current) {
      throw TomLoginException(
        'login.error.tenant-mismatch',
        "The identity provider's token is for another tenant than the one "
            'signed in to.',
        reason: TomLoginFailure.accountProblem,
      );
    }
    final claimedOrganization = mapping.organizationIn(identity.claims);
    if (claimedOrganization != null) {
      authData.organization = claimedOrganization;
    }
    TomAuthenticationInfo mapped(TomAuthenticationInfo info) {
      if (claimedTenant != null) info.principal.tenant = claimedTenant;
      if (claimedOrganization != null) {
        info.principal.organization = claimedOrganization;
      }
      return _withMappedRoles(info, identity);
    }

    final store = identityStore ?? TomExternalIdentityStore.resolve();
    if (store == null) {
      throw TomLoginException(
        'login.error.oauth.no-identity-store',
        'External identity login requires a TomExternalIdentityStore, but none '
            'is installed. Register one (for example '
            'TomPersistentExternalIdentityStore over '
            'TomExternalIdentityLinkRepository) before enabling a provider.',
        reason: TomLoginFailure.providerError,
      );
    }

    final linkedUsername = await store.localUsernameFor(identity);
    if (linkedUsername != null) {
      authData.username = linkedUsername;
      final info = await directory.authenticatedPrincipalFor(
        linkedUsername,
        authData,
      );
      if (info == null) {
        // The link outlived the account it pointed at. Refusing is the only
        // safe answer: provisioning here would recreate a deleted account from
        // a stale row, which is precisely the state an administrator was trying
        // to reach when they deleted it.
        throw TomLoginException(
          'login.error.oauth.linked-account-missing',
          "The external identity $identity is linked to the local account "
              "'$linkedUsername', which no longer exists.",
          reason: TomLoginFailure.accountProblem,
        );
      }
      await store.recordLogin(identity);
      await _retainTokens(exchange);
      return mapped(info);
    }

    return mapped(await _firstLogin(authData, store, exchange));
  }

  /// [info] with the roles the provider's mapping grants [identity] applied
  /// to its principal — see [TomExternalRoleMapping] for why on every login.
  TomAuthenticationInfo _withMappedRoles(
    TomAuthenticationInfo info,
    TomExternalIdentity identity,
  ) {
    applyExternalRoles(info.principal, identity.roles);
    return info;
  }

  /// Hands the provider's grant to the token store, when this provider asks for
  /// it to be kept.
  ///
  /// Called only on the success paths, and only *after* a link exists. A refused
  /// login must leave nothing behind: storing at exchange time would file a live
  /// third-party credential under an identity the deployment just declined to
  /// admit, and nothing would ever come back for it.
  Future<void> _retainTokens(TomOAuthExchange exchange) async {
    final grant = exchange.tokens;
    if (grant == null) return;
    final provider = exchange.provider;
    if (provider is! TomOAuthProviderConfig || !provider.storeTokens) return;
    final store = tokenStore ?? TomOAuthTokenStore.resolve();
    if (store == null) {
      // Configuration asked for tokens and the wiring cannot honour it. Loud,
      // because the failure is otherwise invisible: every login succeeds and the
      // first delegated call, days later, finds nothing.
      tomLog.error(
        "OAuth provider '${provider.id}' is configured with storeTokens, but no "
        'TomOAuthTokenStore is installed; the provider grant was discarded.',
      );
      return;
    }
    await store.store(
      exchange.identity.issuer,
      exchange.identity.subject,
      grant,
    );
  }

  /// A successful external login for which no link exists yet.
  ///
  /// Everything this decides comes off [exchange] rather than being passed
  /// alongside it: the identity, and the provider whose policy governs the
  /// decision. A second parameter for either would be a second thing that could
  /// disagree with the first, which is the failure this method is arranged to
  /// make impossible — two registrations may share an issuer, so a provider
  /// re-derived from the identity could be one the user never authorized
  /// against while [_retainTokens] took its own from the one they did.
  Future<TomAuthenticationInfo> _firstLogin(
    TomAuthenticationData authData,
    TomExternalIdentityStore store,
    TomOAuthExchange exchange,
  ) async {
    final identity = exchange.identity;
    final provider = exchange.provider;

    // An existing local account under the asserted username is linked rather
    // than duplicated — this is how a user who signed up with a password later
    // adds "Sign in with …", and how a pre-provisioned account meets its owner.
    // It is gated on the provider being configured to link (`linkExisting` or
    // `autoProvision`), because on a provider configured to refuse, an unlinked
    // account is exactly the case being refused: an attacker who can make *any*
    // provider assert an address must not thereby acquire the local account
    // that already uses it.
    if (identity.username.isNotEmpty &&
        provider.provisioning != TomOAuthProvisioning.refuse) {
      authData.username = identity.username;
      final existing = await directory.authenticatedPrincipalFor(
        identity.username,
        authData,
      );
      if (existing != null && _assertsUnverifiedEmail(identity)) {
        // The provider says outright that it has not verified the address it
        // asserts. Linking on it would hand the existing account to whoever
        // typed that address into the provider's sign-up form.
        throw TomLoginException(
          'login.error.oauth.unverified-email',
          'The external identity $identity asserts the username '
              "'${identity.username}' of an existing account, but the provider "
              'reports the address as unverified, so the account is not linked.',
          reason: TomLoginFailure.accountProblem,
        );
      }
      if (existing != null) {
        await store.link(identity, identity.username);
        await store.recordLogin(identity);
        await _retainTokens(exchange);
        return existing;
      }
    }

    if (provider.provisioning != TomOAuthProvisioning.autoProvision) {
      throw TomLoginException(
        'login.error.oauth.no-local-account',
        'The external identity $identity authenticated successfully, but no '
            'local account is linked to it and provider '
            "'${provider.id}' is configured not to provision one "
            '(${provider.provisioning.name}).',
        reason: TomLoginFailure.accountProblem,
      );
    }

    final provisioned = await directory.provisionFromExternalIdentity(
      identity,
      authData,
    );
    // Link to the username the *directory* settled on, not the claim: a
    // deployment may normalise, prefix or de-duplicate it, and linking to the
    // claim would leave the row pointing at an account that does not exist.
    final username = provisioned.principal.user.username;
    authData.username = username;
    await store.link(identity, username);
    await store.recordLogin(identity);
    await _retainTokens(exchange);
    return provisioned;
  }

  /// Whether [identity]'s provider states that it has not verified the email
  /// address it asserts (the OIDC `email_verified` claim, false).
  ///
  /// Absent is not false: most SAML identity providers and Entra ID send no
  /// such claim, and their directories are the organisation's own.
  static bool _assertsUnverifiedEmail(TomExternalIdentity identity) {
    final verified = identity.claims['email_verified'];
    return verified == false || '$verified' == 'false';
  }

  /// Replays the login context captured when the flow started.
  void _applyPendingContext(
    TomAuthenticationData authData,
    TomOAuthAuthorizationState pending,
  ) {
    if (pending.client.isNotEmpty) authData.client = pending.client;
    if (pending.application.isNotEmpty) {
      authData.application = pending.application;
    }
    if (pending.process.isNotEmpty) authData.process = pending.process;
    if (pending.organization.isNotEmpty) {
      authData.organization = pending.organization;
    }
    if (pending.clientLanguage.isNotEmpty) {
      authData.language = pending.clientLanguage;
    }
    if (pending.clientCountry.isNotEmpty) {
      authData.country = pending.clientCountry;
    }
    if (pending.clientTimezone.isNotEmpty) {
      authData.timezone = pending.clientTimezone;
    }
  }

  /// Hands a non-OAuth credential to [delegate].
  ///
  /// `async` so the "no delegate" refusal is a rejected future rather than a
  /// synchronous throw, which its declared return type already promises.
  Future<TomAuthenticationInfo> _passThrough(
    TomAuthenticationData authData,
  ) async {
    final next = delegate;
    if (next == null) {
      throw TomLoginException(
        'login.error.oauth.credential-not-supported',
        'This deployment authenticates only through an external identity '
            'provider, and the login carried a '
            '${authData.key.runtimeType} rather than an OAuth credential.',
        reason: TomLoginFailure.providerError,
      );
    }
    return next.authenticateUser(authData);
  }
}
