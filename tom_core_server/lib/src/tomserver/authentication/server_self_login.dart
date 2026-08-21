/// **Server self-login** — the deployment authenticates *as itself* against the
/// auth server and installs the resulting principal as
/// [TomServerPrincipal.current].
///
/// A deployed server is a principal like any other client: it presents a service
/// credential, receives a token pair, and the token reconstructs a
/// [TomPrincipal] whose entitlements are **the feature grants of this
/// deployment**. Those grants then cap every user's grants — the
/// `min(user, server)` meet in `TomAccessControl` (kernel,
/// `access_controls.dart`).
///
/// ## Unconfigured is the default, and it is silent
///
/// Every server built before server-as-principal existed has no service
/// credential configured, and must keep working byte-for-byte as it did. So
/// [TomServerSelfLogin.loginAndInstall] returns `false` and installs nothing
/// when the configuration is incomplete — it does not throw, does not log an
/// error, and leaves [TomServerPrincipal] empty so access evaluation degrades to
/// the user's grant alone. Only a *configured* deployment that then *fails* to
/// log in is an error, and that one is loud.
///
/// ## Why a transport seam
///
/// The login is one JSON POST. Putting it behind [TomServiceLoginTransport]
/// keeps the credential handling, the response parsing and the principal
/// reconstruction testable without a live auth server, and lets a deployment
/// whose auth server speaks a different dialect swap the one HTTP call rather
/// than reimplement the flow.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../little_things/server_exception.dart';

// =============================================================================
// CREDENTIAL
// =============================================================================

/// The deployment's own login credential and where to present it.
///
/// Built from the CE-CF server configuration by [fromConfiguration]. The
/// [credential] is secret-bearing: it is supplied out-of-band (OS environment,
/// `.env`, command line) and must never be written into a spec or a checked-in
/// configuration tree — see `codespecs_mapping.md` §5.16.
class TomServiceCredential {
  /// Absolute URI of the auth server's login endpoint, e.g.
  /// `http://auth:8081/auth/login`.
  final Uri loginUri;

  /// The service account's login name.
  final String username;

  /// The service account's secret. Never logged, never serialised anywhere but
  /// into the login request body.
  final String credential;

  /// Multi-tenant context presented with the login; empty when the deployment
  /// is single-tenant.
  final String organization;

  /// The application the deployment logs into.
  final String application;

  /// The process (sub-context of [application]) the deployment logs into.
  final String process;

  /// The client identifier the login originates from.
  final String client;

  /// Creates a service credential.
  const TomServiceCredential({
    required this.loginUri,
    required this.username,
    required this.credential,
    this.organization = '',
    this.application = '',
    this.process = '',
    this.client = '',
  });

  /// Reads the credential out of [config], or returns `null` when the
  /// deployment did not configure server self-login.
  ///
  /// "Did not configure" means any of the three required values
  /// ([TomBaseServerConfiguration.authServerLoginUri],
  /// [TomBaseServerConfiguration.serviceAccountName],
  /// [TomBaseServerConfiguration.serviceAccountCredential]) is absent or blank,
  /// or the URI does not parse. `null` is the supported, silent default — see
  /// the library doc. A *partially* configured deployment is treated the same
  /// way deliberately: half a credential cannot authenticate, and failing loudly
  /// at startup for a value the operator may be mid-way through rolling out is
  /// worse than running uncapped. [TomServerSelfLogin.loginAndInstall] logs the
  /// skip at info level so the state is visible.
  ///
  /// "Blank" includes whitespace for all three, the credential included: an
  /// unsubstituted `${SERVICE_CREDENTIAL}` leaves whitespace behind in some
  /// templating setups, and a whitespace credential read literally would pass
  /// this test and buy a login that cannot succeed -- reported as a *rejected*
  /// credential rather than a missing one, which is the harder of the two to
  /// diagnose because the redaction policy hides the value that would have
  /// explained it.
  ///
  /// The trim decides *whether one was configured* and nothing else: the value
  /// is carried through as written. A secret is opaque, so if the auth server
  /// expects a trailing space then that space has to reach it, and reshaping it
  /// here would turn a correct deployment into the same undiagnosable rejected
  /// login, inverted. `TomSmtpSettings.fromConfiguration` splits the analogous
  /// `smtpPassword` the same way.
  static TomServiceCredential? fromConfiguration(
    TomBaseServerConfiguration config,
  ) {
    final uriText = config.authServerLoginUri?.trim() ?? '';
    final username = config.serviceAccountName?.trim() ?? '';
    final credential = config.serviceAccountCredential ?? '';
    if (uriText.isEmpty || username.isEmpty || credential.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(uriText);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    return TomServiceCredential(
      loginUri: uri,
      username: username,
      credential: credential,
      organization: config.serviceAccountOrganization ?? '',
      application: config.serviceAccountApplication ?? '',
      process: config.serviceAccountProcess ?? '',
      client: config.serviceAccountClient ?? '',
    );
  }

  /// The login request body, shaped as the kernel's [TomAuthenticationMessage].
  ///
  /// Written by hand rather than through reflection so the credential never
  /// passes through a general-purpose serialiser that might log or cache it.
  ///
  /// The identity fields come from this credential; the three locale fields do
  /// not, because **a deployment has no locale to assert**. It is a process,
  /// not a device: there is no browser to read a language from, no operator
  /// present to have a country, and its own clock is UTC. So it sends
  /// [TomAuthenticationMessage]'s defaults — which is what "no locale" is
  /// already spelled as in this framework, `XX` being the ISO 3166-1
  /// user-assigned code the kernel uses for "none".
  ///
  /// They are **read from the message type rather than restated** here. Writing
  /// the body by hand buys the credential its isolation and costs exactly one
  /// thing: nothing otherwise keeps it agreeing with the type it claims to be
  /// shaped as. Three literals would have been a second copy of the kernel's
  /// defaults, correct on the day they were written and silently stale the day
  /// the kernel moved one.
  String toRequestBody() {
    final locale = TomAuthenticationMessage();
    return jsonEncode(<String, Object?>{
      'userName': username,
      'password': credential,
      'organization': organization,
      'application': application,
      'process': process,
      'client': client,
      'clientLanguage': locale.clientLanguage,
      'clientCountry': locale.clientCountry,
      'clientTimezone': locale.clientTimezone,
    });
  }

  /// Redacted representation — the credential is never included.
  @override
  String toString() =>
      'TomServiceCredential($username @ $loginUri, credential: <redacted>)';
}

// =============================================================================
// TRANSPORT SEAM
// =============================================================================

/// One JSON POST, so the login flow can be tested without a live auth server.
abstract class TomServiceLoginTransport {
  /// Creates a transport.
  const TomServiceLoginTransport();

  /// POSTs [body] as `application/json` to [uri] and returns the raw response.
  Future<TomServiceLoginResponse> postJson(Uri uri, String body);
}

/// The raw result of a [TomServiceLoginTransport.postJson] call.
class TomServiceLoginResponse {
  /// The HTTP status code.
  final int statusCode;

  /// The response body, decoded as text.
  final String body;

  /// Creates a response.
  const TomServiceLoginResponse(this.statusCode, this.body);

  /// Whether the status is in the 2xx range.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// The live transport, over the kernel's [TomServerChannel].
class TomHttpServiceLoginTransport extends TomServiceLoginTransport {
  /// Creates the live transport.
  const TomHttpServiceLoginTransport();

  @override
  Future<TomServiceLoginResponse> postJson(Uri uri, String body) async {
    final channel = TomServerChannel(uri.host, _portOf(uri));
    try {
      final call = channel.prepareCall(
        TomServerCallSpecs(
          'POST',
          uri,
          headers: const {'Content-Type': 'application/json'},
          // The server has no bearer of its own *yet* — that is precisely what
          // this call obtains. Attaching the ambient one would present whatever
          // token happens to be stored, which is never right here.
          includeBearerAuthentication: false,
        ),
      );
      call.send(
        TomServerCallLoad(
          stringBody: body,
          contentType: 'application/json',
          encoding: utf8,
        ),
      );
      final status = await call.getResponseStatusCode();
      final text = await call.readAsString(utf8);
      return TomServiceLoginResponse(status, text);
    } finally {
      channel.close();
    }
  }

  /// The port to dial: the URI's own, else the scheme default.
  static int _portOf(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
}

// =============================================================================
// THE FLOW
// =============================================================================

/// Raised when a *configured* deployment fails to log itself in.
///
/// Never raised for an unconfigured deployment — that path returns `false`
/// instead (see [TomServerSelfLogin.loginAndInstall]).
class TomServerSelfLoginException extends TomServerException {
  /// Creates the exception.
  TomServerSelfLoginException(super.key, super.defaultUserMessage)
    : super(clientThrow: false);
}

/// Logs the deployment in as itself and installs the resulting principal.
class TomServerSelfLogin {
  TomServerSelfLogin._();

  /// Logs in with [credential] and returns the deployment's [TomPrincipal].
  ///
  /// [decryptTokens] controls whether the authorization token's encrypted
  /// section is unwrapped locally; it must be `true` for a deployment whose
  /// entitlements travel in the encrypted claims, which is the normal case for a
  /// server that holds the RSA private key.
  ///
  /// Throws [TomServerSelfLoginException] when the auth server refuses, when the
  /// response is not the expected shape, or when the token carries no payload.
  static Future<TomPrincipal> logIn(
    TomServiceCredential credential, {
    TomServiceLoginTransport transport = const TomHttpServiceLoginTransport(),
    bool decryptTokens = true,
  }) async {
    final TomServiceLoginResponse response;
    try {
      response = await transport.postJson(
        credential.loginUri,
        credential.toRequestBody(),
      );
    } catch (e) {
      throw TomServerSelfLoginException(
        'server.selflogin.unreachable',
        'Auth server ${credential.loginUri} could not be reached: $e',
      );
    }

    if (!response.isSuccess) {
      // The body may echo the credential back in an error message, so only the
      // status is reported.
      throw TomServerSelfLoginException(
        'server.selflogin.rejected',
        'Auth server rejected the service credential for '
            '${credential.username} (HTTP ${response.statusCode}).',
      );
    }

    final tokens = _readTokens(response.body, credential);
    final authToken = TomClientJwtToken(tokens.$1, decrypt: decryptTokens);
    final authzToken = TomClientJwtToken(tokens.$2, decrypt: decryptTokens);
    try {
      return TomBearerAuthentication.convertTokenPayloadToPrincipal(
        authToken,
        authzToken,
      );
    } on StateError catch (e) {
      throw TomServerSelfLoginException(
        'server.selflogin.bad_token',
        'The service token could not be turned into a principal: ${e.message}',
      );
    }
  }

  /// Logs the deployment in from [config] and installs the principal into
  /// [TomServerPrincipal]; returns whether a principal was installed.
  ///
  /// Returns `false` — silently, having changed nothing — when the deployment
  /// did not configure self-login. That is the GUARD this whole feature stands
  /// on: an unconfigured deployment behaves exactly as it did before
  /// server-as-principal existed. A *configured* deployment that cannot log in
  /// throws [TomServerSelfLoginException]; that is a misconfiguration the
  /// operator must see, not a state to degrade into, because degrading would
  /// silently *widen* access.
  ///
  /// Call this during application startup, before `TomServer.start()`.
  static Future<bool> loginAndInstall(
    TomBaseServerConfiguration config, {
    TomServiceLoginTransport transport = const TomHttpServiceLoginTransport(),
    bool decryptTokens = true,
  }) async {
    final credential = TomServiceCredential.fromConfiguration(config);
    if (credential == null) {
      tomLog.info(
        'Server self-login not configured — the deployment runs without a '
        'server principal and user grants are not capped.',
      );
      return false;
    }
    final principal = await logIn(
      credential,
      transport: transport,
      decryptTokens: decryptTokens,
    );
    TomServerPrincipal.install(principal);
    tomLog.info(
      'Server self-login succeeded for ${credential.username}; deployment '
      'grants now cap user grants.',
    );
    return true;
  }

  /// Extracts the `(authentication, authorization)` token pair from a login
  /// response body.
  ///
  /// Two spellings are accepted because two are in the field: the kernel's
  /// [TomAuthenticationResult] serialises `authenticationToken` /
  /// `authorizationToken`, while application login DTOs commonly shorten these
  /// to `authToken` / `authzToken`. Accepting both here is cheaper than forcing
  /// every auth server to re-shape a response it already publishes to its
  /// clients — and the two names are unambiguous, so nothing is guessed.
  ///
  /// When only one token is present it is used for both roles, matching
  /// [TomBearerAuthentication.convertTokenPayloadToPrincipal]'s own fallback.
  static (String, String) _readTokens(
    String body,
    TomServiceCredential credential,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw TomServerSelfLoginException(
        'server.selflogin.bad_response',
        'Auth server ${credential.loginUri} returned a non-JSON login response.',
      );
    }
    if (decoded is! Map) {
      throw TomServerSelfLoginException(
        'server.selflogin.bad_response',
        'Auth server ${credential.loginUri} returned a JSON login response that '
            'was not an object.',
      );
    }

    final fields = decoded;
    String? read(String a, String b) {
      for (final key in [a, b]) {
        final value = fields[key];
        if (value is String && value.isNotEmpty) return value;
      }
      return null;
    }

    final auth = read('authenticationToken', 'authToken');
    final authz = read('authorizationToken', 'authzToken');
    if (auth == null && authz == null) {
      throw TomServerSelfLoginException(
        'server.selflogin.no_token',
        'The login response from ${credential.loginUri} carried no token.',
      );
    }
    return (auth ?? authz!, authz ?? auth!);
  }
}
