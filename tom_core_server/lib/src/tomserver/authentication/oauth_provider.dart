/// External-identity provider configuration (C-9) — **as data, not code**.
///
/// A deployment that wants "Sign in with Google" edits its configuration tree
/// and restarts. It writes no Dart, subclasses nothing and registers no
/// provider-specific class, because everything that distinguishes one OAuth 2.0
/// / OIDC provider from another is a handful of URLs, a client id, a secret and
/// a list of scopes — and a provider that needs a *class* to be added is a
/// provider that cannot be added by an operator.
///
/// ## Where the values come from
///
/// [TomOAuthProviders.fromConfiguration] reads the existing configuration tree
/// ([TomServerConfigResourceProvider]) under `oauth.providers`, one nested map
/// per provider:
///
/// ```yaml
/// oauth:
///   providers:
///     google:
///       issuer: https://accounts.google.com
///       authorizationEndpoint: https://accounts.google.com/o/oauth2/v2/auth
///       tokenEndpoint: https://oauth2.googleapis.com/token
///       clientId: 1234567890-abcdef.apps.googleusercontent.com
///       clientSecret: ${GOOGLE_CLIENT_SECRET}
///       redirectUri: https://app.example.com/oauth/callback
///       scopes: [openid, email, profile]
///       provisioning: refuse
/// ```
///
/// It is the *existing* configuration module and not a new one, which is what
/// makes `${GOOGLE_CLIENT_SECRET}` work without any machinery of this module's
/// own: the YAML resource loader already substitutes `${…}` from the process
/// environment before the tree is handed over, so a client secret never has to
/// be written into a file that is checked in.
///
/// ## Delegated access is two more keys, and both are opt-in
///
/// A deployment that only wants "Sign in with …" writes nothing further: the
/// framework retains no provider credential unless a provider asks it to.
/// One that genuinely needs to call a provider's API *as the user* adds
/// [storeTokens] and whatever the provider demands before it will issue a
/// refresh token at all:
///
/// ```yaml
/// oauth:
///   providers:
///     google:
///       # … the login configuration above, plus:
///       scopes: [openid, email, https://www.googleapis.com/auth/calendar.readonly]
///       storeTokens: true
///       authorizationParameters:
///         access_type: offline     # Google returns no refresh token without it
///         prompt: consent          # … and repeats it only under this
/// ```
///
/// [storeTokens] governs *storage*, not capability: the grant is surfaced on
/// `TomOAuthExchange.tokens` from every exchange regardless, so a caller that
/// wants it for the duration of this request always may. Retention is the part
/// that needs a decision, because a stored provider refresh token is a
/// long-lived credential against a *third party* that outlives the session — see
/// `readme.md` in this folder.
///
/// [authorizationParameters] are applied **before** the flow's own parameters,
/// so a configuration typo cannot replace `state`, `redirect_uri` or the PKCE
/// challenge.
///
/// ## What is deliberately *not* configurable
///
/// The [redirectUri] is configuration; it is **not** a request parameter. A
/// caller that could name where the provider sends the user back could have a
/// live authorization code delivered to a host it owns — the classic open
/// redirect — and no amount of state or PKCE checking downstream repairs that,
/// because the attacker holds the code before any of it runs.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../little_things/server_exception.dart';

/// Raised when external-identity configuration or a provider exchange is
/// unusable.
///
/// A [TomServerException] like every other server-side failure, so it reaches
/// the endpoint error handler and the log through the same path. Defaults to
/// `clientThrow: false`: a misconfigured provider is an operator's problem and
/// its detail (endpoint URLs, client ids) is not a caller's business.
class TomOAuthException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomOAuthException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
    super.clientThrow = false,
  });
}

/// What happens on a successful external login for which no local account
/// exists.
///
/// A **configuration choice** rather than framework policy, because the right
/// answer is a property of the deployment and not of the code: an internal tool
/// behind a corporate identity provider wants every authenticated employee to
/// get an account, while a paid product wants a purchase before a login. A
/// framework that picked one would be wrong for the other half of its users,
/// and a framework that picked "provision" would be wrong in the direction that
/// creates accounts.
enum TomOAuthProvisioning {
  /// Refuse the login. The default: creating an account is a decision, and a
  /// default that silently makes decisions is a default that surprises.
  refuse,

  /// Create a local account from the external claims, via
  /// `TomExternalIdentityDirectory.provisionFromExternalIdentity`.
  autoProvision;

  /// Parses a configured value (`refuse`, `autoProvision`, `auto_provision`).
  ///
  /// Case- and separator-insensitive because this is read from hand-written
  /// YAML, where `auto_provision` and `autoProvision` are both the natural
  /// spelling depending on which style the rest of the file uses. An
  /// unrecognised value throws rather than defaulting: a typo in a security
  /// setting must not resolve to *any* behaviour silently, and the operator who
  /// wrote `autoprovison` meant something.
  static TomOAuthProvisioning parse(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[_\-\s]'), '').toLowerCase();
    for (final value in TomOAuthProvisioning.values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    throw TomOAuthException(
      'oauth.config.unknown_provisioning',
      "Unknown OAuth provisioning mode '$raw'; expected one of "
          "${TomOAuthProvisioning.values.map((v) => v.name).join(', ')}.",
    );
  }
}

/// One configured external-identity provider.
///
/// Immutable: it is read from configuration at startup and consulted on every
/// login, so a mutable instance would be shared state that a request could
/// alter for every later request.
class TomOAuthProviderConfig {
  /// The provider key — the map key under `oauth.providers`, and what a client
  /// posts back as [TomOAuthAuthorizationRequest.providerId].
  final String id;

  /// The identity provider's issuer identifier (the OIDC `iss` claim).
  ///
  /// Also the first half of the linking table's key: an external subject is
  /// only unique *within* an issuer, so `(issuer, subject)` is the identity and
  /// `subject` alone is not. Two providers that shared an issuer string would
  /// therefore share accounts, which is why this is configured per provider and
  /// not derived from [id].
  final String issuer;

  /// Where the user is sent to approve the request.
  final String authorizationEndpoint;

  /// Where the authorization code is exchanged for tokens (back-channel).
  final String tokenEndpoint;

  /// Where the user's claims are fetched with the access token, or `null` when
  /// the provider is a full OIDC one whose token response carries an `id_token`.
  ///
  /// Optional because the two provider families answer the same question
  /// differently: an OIDC provider returns the claims *inside* the token
  /// response, while a plain OAuth 2.0 provider (GitHub, and most pre-OIDC
  /// APIs) returns only an access token and expects a second call. Supporting
  /// both is what makes "a configurable provider set" true rather than "a
  /// configurable set of OIDC providers".
  final String? userInfoEndpoint;

  /// Where a grant is revoked (RFC 7009), or `null` when the provider
  /// configures none.
  ///
  /// Optional, and absent is the majority case — a great many providers
  /// publish no revocation endpoint at all, and a deployment that holds no
  /// tokens has nothing to revoke. What it is *not* is a value to default:
  /// guessing an address for a security-relevant call would mean posting a
  /// live credential at a URL nobody configured.
  ///
  /// Where it is set, [TomExternalIdentityStore.unlink] uses it, so pressing
  /// disconnect ends the credential rather than merely forgetting it. See
  /// [TomOAuthFlow.revokeGrant].
  final String? revocationEndpoint;

  /// The client id registered with the provider.
  final String clientId;

  /// The client secret, or `null` for a public client using PKCE only.
  final String? clientSecret;

  /// Where the provider redirects the user back to — **server configuration**,
  /// never a request parameter (see the library documentation).
  final String redirectUri;

  /// The scopes requested. `openid email profile` for an OIDC provider.
  final List<String> scopes;

  /// Whether to use PKCE (RFC 7636). On by default, and there is no good reason
  /// to turn it off other than a provider that rejects the parameters.
  final bool usePkce;

  /// The claim carrying the provider's stable user identifier. `sub` for OIDC;
  /// `id` for providers that predate it.
  ///
  /// Stable is the operative word: this value is written into the linking table
  /// and is how the account is found on every later login, so a provider whose
  /// `sub` changes would orphan every account. Never an email address for that
  /// reason — people change theirs.
  final String subjectClaim;

  /// The claim to derive a local username from when provisioning.
  final String usernameClaim;

  /// The claim carrying a human-readable display name, when the provider sends
  /// one.
  final String displayNameClaim;

  /// What a first external login does when no local account exists.
  final TomOAuthProvisioning provisioning;

  /// Resource key of the provider's label, as a client renders it.
  final String displayNameKey;

  /// Resource key of the provider's icon.
  final String iconKey;

  /// Whether the provider's own tokens are retained after the login.
  ///
  /// **Off by default, and that is the framework's position rather than a
  /// conservative guess** — see the `oauth_tokens.dart` library documentation.
  /// Authentication needs no provider token once the claims are read, so a
  /// deployment that only wants "Sign in with …" acquires no third-party
  /// credential at all. Turning it on is a statement that this application acts
  /// *as* the user against this provider's API, and it is per provider because
  /// that is the granularity the statement is true at: an app may hold a
  /// calendar grant from one provider and nothing but a login from another.
  ///
  /// When on, [TomOAuthAuthenticationService] hands the grant to the installed
  /// [TomOAuthTokenStore] once the login has produced an identity link — never
  /// before, so a refused login leaves no orphaned credential.
  final bool storeTokens;

  /// Extra query parameters added to the authorization redirect.
  ///
  /// The escape hatch every real provider needs and no two need identically:
  /// Google returns a refresh token only under `access_type=offline` and
  /// re-issues one only under `prompt=consent`, Microsoft wants a `tenant`,
  /// others want `audience` or `resource`. Modelling each as a named field would
  /// mean a framework release per provider quirk; a map means an operator adds
  /// one line of YAML.
  ///
  /// The flow's own parameters (`response_type`, `client_id`, `redirect_uri`,
  /// `scope`, `state`, the PKCE pair) are applied *after* these and therefore
  /// win: they are the ones the handshake's security rests on, and a
  /// configuration typo must not be able to replace the `state` handle or point
  /// the redirect somewhere else.
  final Map<String, String> authorizationParameters;

  /// How far this provider's clock may run ahead of or behind ours before an
  /// `id_token`'s `exp` and `nbf` are believed. One minute by default.
  ///
  /// Freshness is checked against a wall clock neither party controls, so a
  /// token minted a moment ago can look expired here purely because the two
  /// machines disagree. A tolerance is the difference between "the token is
  /// stale" and "the clocks are", and a minute is the customary answer — wide
  /// enough for ordinary NTP drift, far narrower than any token's lifetime.
  ///
  /// Per provider rather than global because the drift being tolerated is one
  /// specific provider's: a deployment must be able to widen the tolerance for
  /// the one badly-synchronised IdP without loosening every other. `Duration.zero`
  /// is a legitimate setting for a deployment confident in its own clocks.
  final Duration clockSkew;

  /// Creates a provider configuration.
  const TomOAuthProviderConfig({
    required this.id,
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.redirectUri,
    this.userInfoEndpoint,
    this.revocationEndpoint,
    this.clientSecret,
    this.scopes = const ['openid', 'email', 'profile'],
    this.usePkce = true,
    this.subjectClaim = 'sub',
    this.usernameClaim = 'email',
    this.displayNameClaim = 'name',
    this.provisioning = TomOAuthProvisioning.refuse,
    this.displayNameKey = '',
    this.iconKey = '',
    this.storeTokens = false,
    this.authorizationParameters = const {},
    this.clockSkew = defaultClockSkew,
  });

  /// The tolerance applied when a provider configures none.
  static const Duration defaultClockSkew = Duration(seconds: 60);

  /// Reads one provider from its configuration map.
  ///
  /// Every *required* value is demanded rather than defaulted, because a
  /// provider missing its token endpoint is not a provider with a sensible
  /// default — it is a configuration error, and one that would otherwise
  /// surface as a failed login weeks later instead of a failed startup now.
  factory TomOAuthProviderConfig.fromMap(String id, Map<Object?, Object?> map) {
    String required(String key) {
      final value = map[key];
      if (value == null || '$value'.isEmpty) {
        throw TomOAuthException(
          'oauth.config.missing_value',
          "OAuth provider '$id' is missing the required setting '$key'.",
        );
      }
      return '$value';
    }

    String? optional(String key) {
      final value = map[key];
      if (value == null || '$value'.isEmpty) return null;
      return '$value';
    }

    final rawScopes = map['scopes'];
    return TomOAuthProviderConfig(
      id: id,
      issuer: required('issuer'),
      authorizationEndpoint: required('authorizationEndpoint'),
      tokenEndpoint: required('tokenEndpoint'),
      userInfoEndpoint: optional('userInfoEndpoint'),
      revocationEndpoint: optional('revocationEndpoint'),
      clientId: required('clientId'),
      clientSecret: optional('clientSecret'),
      redirectUri: required('redirectUri'),
      scopes: rawScopes == null
          ? const ['openid', 'email', 'profile']
          : _scopesOf(rawScopes),
      usePkce: map['usePkce'] == null ? true : '${map['usePkce']}' == 'true',
      subjectClaim: optional('subjectClaim') ?? 'sub',
      usernameClaim: optional('usernameClaim') ?? 'email',
      displayNameClaim: optional('displayNameClaim') ?? 'name',
      provisioning: map['provisioning'] == null
          ? TomOAuthProvisioning.refuse
          : TomOAuthProvisioning.parse('${map['provisioning']}'),
      displayNameKey:
          optional('displayNameKey') ??
          '${TomOAuthProviderDto.resourceScope}.$id.name',
      iconKey:
          optional('iconKey') ??
          '${TomOAuthProviderDto.resourceScope}.$id.icon',
      storeTokens: '${map['storeTokens']}' == 'true',
      authorizationParameters: _parametersOf(
        id,
        map['authorizationParameters'],
      ),
      clockSkew: _clockSkewOf(id, map['clockSkewSeconds']),
    );
  }

  /// Reads `clockSkewSeconds`, which must be a whole number of seconds and not
  /// negative.
  ///
  /// Absent is distinguished from `0`: nought is an operator saying "my clocks
  /// are synchronised, refuse anything stale", which is a different instruction
  /// from having said nothing. Negative would tighten expiry *past* the token's
  /// own claim and is never what anyone meant to type.
  static Duration _clockSkewOf(String id, Object? raw) {
    if (raw == null) return defaultClockSkew;
    final seconds = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (seconds == null || seconds < 0) {
      throw TomOAuthException(
        'oauth.config.invalid_clock_skew',
        "OAuth provider '$id' must declare 'clockSkewSeconds' as a whole "
            "number of seconds that is not negative, but it was '$raw'.",
      );
    }
    return Duration(seconds: seconds);
  }

  /// Reads the extra authorization parameters, which must be a map of scalars.
  ///
  /// A nested map or list throws rather than being stringified: `tenant: {a: b}`
  /// is a mistake, and silently sending `{a: b}` as a query parameter value
  /// would produce a provider error whose text says nothing about the YAML that
  /// caused it.
  static Map<String, String> _parametersOf(String id, Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map) {
      throw TomOAuthException(
        'oauth.config.parameters_not_a_map',
        "OAuth provider '$id' must declare 'authorizationParameters' as a map "
            'of name to value, but it was a ${raw.runtimeType}.',
      );
    }
    final parsed = <String, String>{};
    raw.forEach((key, value) {
      if (value is Map || value is List) {
        throw TomOAuthException(
          'oauth.config.parameter_not_a_scalar',
          "OAuth provider '$id' declares the authorization parameter '$key' as "
              'a ${value.runtimeType}; a query parameter can only carry a '
              'scalar value.',
        );
      }
      parsed['$key'] = '$value';
    });
    return Map.unmodifiable(parsed);
  }

  /// Accepts scopes as a YAML list *or* as a single space-separated string,
  /// which is how they are written in every provider's own documentation.
  static List<String> _scopesOf(Object raw) {
    if (raw is List) {
      return List.unmodifiable(raw.map((s) => '$s').where((s) => s.isNotEmpty));
    }
    return List.unmodifiable(
      '$raw'.split(RegExp(r'\s+')).where((s) => s.isNotEmpty),
    );
  }

  /// This provider as the client-facing DTO — id and resource keys, nothing
  /// else. Endpoints, client ids and secrets stay on the server.
  TomOAuthProviderDto toDto() => TomOAuthProviderDto(
    id: id,
    displayNameKey: displayNameKey,
    iconKey: iconKey,
  );

  @override
  String toString() => 'TomOAuthProviderConfig($id -> $issuer)';
}

/// The configured provider set.
///
/// Installed as a bean so a deployment can substitute its own source — a
/// database table, a discovery document fetched at startup — without any
/// consumer changing:
///
/// ```dart
/// TomBean.withType<TomOAuthProviders>(TomOAuthProviders.fromConfiguration());
/// ```
class TomOAuthProviders {
  /// The configuration path the provider set is read from.
  static const String configurationKey = 'oauth.providers';

  /// The configured providers, keyed by [TomOAuthProviderConfig.id].
  final Map<String, TomOAuthProviderConfig> providers;

  /// Creates a provider set over an explicit map — the constructor tests and
  /// hand-wired deployments use.
  TomOAuthProviders(Map<String, TomOAuthProviderConfig> providers)
    : providers = Map.unmodifiable(providers);

  /// The installed [TomOAuthProviders] bean, or `null` when none is registered.
  ///
  /// `null` rather than a throw, because "this deployment offers no external
  /// login" is an ordinary state — the great majority of deployments — and the
  /// endpoints answer an empty provider list for it rather than failing.
  static TomOAuthProviders? resolve() {
    final installed = TomBean.getBeanByType(TomOAuthProviders);
    return installed is TomOAuthProviders ? installed : null;
  }

  /// Reads the provider set from the configuration tree under
  /// [configurationKey].
  ///
  /// Answers an empty set when the key is absent, so calling this
  /// unconditionally at startup is safe: a deployment with no `oauth:` block
  /// gets a set that offers nothing rather than an exception. A *malformed*
  /// block still throws — absent and wrong are different states.
  factory TomOAuthProviders.fromConfiguration([
    TomServerConfigResourceProvider? config,
  ]) {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    if (!provider.exists(configurationKey)) return TomOAuthProviders(const {});
    final raw = provider.get(configurationKey);
    if (raw is! Map) {
      throw TomOAuthException(
        'oauth.config.not_a_map',
        "Configuration '$configurationKey' must be a map of provider id to "
            'provider settings, but was a ${raw.runtimeType}.',
      );
    }
    final parsed = <String, TomOAuthProviderConfig>{};
    raw.forEach((key, value) {
      final id = '$key';
      if (value is! Map) {
        throw TomOAuthException(
          'oauth.config.provider_not_a_map',
          "OAuth provider '$id' must be a map of settings, but was a "
              '${value.runtimeType}.',
        );
      }
      parsed[id] = TomOAuthProviderConfig.fromMap(id, value);
    });
    return TomOAuthProviders(parsed);
  }

  /// Whether any provider is configured.
  bool get isEmpty => providers.isEmpty;

  /// The providers as client-facing DTOs, in configuration order.
  List<TomOAuthProviderDto> get descriptors =>
      List.unmodifiable(providers.values.map((p) => p.toDto()));

  /// The provider configured under [id], or `null`.
  TomOAuthProviderConfig? lookup(String id) => providers[id];

  /// The provider configured under [id].
  ///
  /// Throws for an unknown id, because every caller of this reached it from a
  /// request that named a provider, and "the provider you asked for does not
  /// exist" must not resolve to some other provider or to a silent `null` that
  /// the flow then treats as a refusal.
  TomOAuthProviderConfig operator [](String id) {
    final provider = providers[id];
    if (provider == null) {
      throw TomOAuthException(
        'oauth.config.unknown_provider',
        "No OAuth provider is configured under the id '$id'.",
        clientThrow: true,
      );
    }
    return provider;
  }

  @override
  String toString() => 'TomOAuthProviders(${providers.keys.join(', ')})';
}
