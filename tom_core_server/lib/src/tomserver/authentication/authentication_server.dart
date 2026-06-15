import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// Marks a class as an authentication adaptor and constrains which login flows
/// it participates in.
///
/// [guestOnly] restricts the adaptor to guest logins; [userOnly] restricts it
/// to authenticated-user logins. Leaving both `false` (the default) makes the
/// adaptor eligible for either flow. The annotation is reflection-discoverable,
/// so a runtime can enumerate the registered adaptors and route a login to the
/// right one.
@tomReflector
class TomAuthenticationAdaptor {
  /// Whether this adaptor handles only guest logins.
  final bool guestOnly;

  /// Whether this adaptor handles only authenticated-user logins.
  final bool userOnly;

  /// Creates an adaptor marker; defaults make it eligible for both flows.
  TomAuthenticationAdaptor({this.guestOnly = false, this.userOnly = false});
}

/// Marks a class as a server-side two-factor (2FA) adaptor for a given [type].
///
/// The [type] names the second-factor mechanism (e.g. `'totp'`, `'sms'`). The
/// annotation is reflection-discoverable so a runtime can dispatch the second
/// authentication pass to the matching adaptor. The 2FA flow itself
/// ([TomAuthenticationServer.authenticatePass2]) is not yet implemented.
@tomReflector
class Tom2FAAdaptor {
  /// The 2FA mechanism this adaptor implements (e.g. `'totp'`, `'sms'`).
  final String type;

  /// Tags the annotated class as a 2FA adaptor for [type].
  const Tom2FAAdaptor(this.type);
}

/// A server-side login failure.
///
/// Thrown by a [TomAuthenticationService] (or its helpers) when a login cannot
/// succeed — unknown client/user, invalid credentials, etc. Carries the kernel
/// [TomServerException] payload (`key`, user message, `parameters`, `stack`,
/// `rootException`, `autoLog`); [TomAuthenticationServer] catches it and turns
/// its `key` into a failed [TomAuthenticationResult] rather than propagating.
class LoginException extends TomServerException {
  /// Creates a login failure with a resource [key] and a default user message.
  LoginException(
    super.key,
    super.userMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// The data carried into a single authentication attempt.
///
/// A [TomAuthenticationServer] builds this from an incoming
/// `TomAuthenticationMessage` and passes it to the configured
/// [TomAuthenticationService]. It identifies *what* is being logged into
/// (organization / application / process / client) and *who* ([username]),
/// plus the credential ([key], e.g. the password) and the client locale
/// (language / country / timezone). The fields are mutable so a service can
/// enrich them while resolving the login.
@tomReflector
class TomAuthenticationData {
  /// The organization being logged into.
  String organization;

  /// The application being logged into.
  String application;

  /// The process (sub-context of the application) being logged into.
  String process;

  /// The client's language code.
  String language;

  /// The client's country code.
  String country;

  /// The client's timezone identifier.
  String timezone;

  /// The client (front-end) identifier the login originates from.
  String client;

  /// The login name of the user (or `"GUEST"` for guest logins).
  String username;

  /// The credential to verify (typically the password); `null` for guests.
  Object? key;

  /// Creates the data for one authentication attempt.
  TomAuthenticationData({
    required this.username,
    this.key,
    required this.organization,
    required this.application,
    required this.process,
    required this.language,
    required this.country,
    required this.timezone,
    required this.client,
  });
}

/// The contract an application implements to authenticate a login.
///
/// Implementations resolve the [TomAuthenticationData] against their user store
/// (database, directory, etc.) and return a [TomAuthenticationInfo] carrying the
/// authenticated principal and its access-control definition. On failure they
/// throw a [LoginException]. The default implementation,
/// [TomDummyAuthenticationService], accepts everything and is for scaffolding
/// only.
@tomReflector
abstract class TomAuthenticationService {
  /// Authenticates [authData], returning the principal and its access rights,
  /// or throwing a [LoginException] when the login is rejected.
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  );
}

/// Contract for a second-factor (2FA) authentication step.
///
/// Placeholder: the second authentication pass is not yet implemented (see
/// [TomAuthenticationServer.authenticatePass2]). The full contract must cover
/// the available mechanisms (email, SMS, authenticator app, …) and a way to
/// drive the second-factor UI on the *client*, kept flexible enough that the
/// server does not hard-code the mechanism set.
@tomReflector
abstract class Tom2FAService {}

/// The successful outcome of a [TomAuthenticationService.authenticateUser] call.
///
/// Pairs the authenticated [principal] (identity, locale, user record) with the
/// [acd] — the access-control definition (groups/roles) that
/// [TomAuthenticationServer] encodes into the issued authorization token.
class TomAuthenticationInfo {
  /// The authenticated principal (identity, locale, and user record).
  TomPrincipal principal;

  /// The principal's access-control definition (groups and roles).
  TomAccessControlDefinition acd;

  /// Pairs an authenticated [principal] with its access-control definition.
  TomAuthenticationInfo(this.principal, this.acd);
}

/// A no-op [TomAuthenticationService] that authenticates any non-`"GUEST"` user.
///
/// Provided as the default so a freshly scaffolded server can issue tokens
/// without a user store wired up. It logs an error on every call (unless
/// [showErrorMessage] is cleared) because relying on it outside scaffolding is a
/// mistake — replace it with a real [TomAuthenticationService] via
/// [TomAuthenticationServer.globalSettingUserAuthenticationService] /
/// [TomAuthenticationServer.globalSettingGuestAuthenticationService].
class TomDummyAuthenticationService implements TomAuthenticationService {
  /// Whether to log the "you are using the dummy service" error on each call.
  bool showErrorMessage = true;

  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) {
    TomPrincipal result = TomPrincipal(
      authenticated: authData.username != "GUEST",
      context: {},
      requires2FA: false,
      twoFactorType: null,
      clientId: 0,
      organization: authData.organization,
      organizationId: 0,
      application: authData.application,
      applicationId: 0,
      process: authData.process,
      processId: 0,
      language: authData.language,
      country: authData.country,
      clientCountry: authData.language,
      clientLanguage: authData.language,
      clientTimezone: authData.timezone,
      user: TomUser(
        id: 0,
        username: authData.username,
        firstname: "guest",
        lastname: "guest",
        attributes: {},
        timeZone: "utc",
      ),
      aci: TomAccessControlInformation(),
    );
    if (showErrorMessage) {
      tomLog.error(
        "You are using TomDummyAuthenticationService. This is only acceptable while scaffolding the project. In any productive or product test situation this is an error.",
      );
    }
    return Future.syncValue(
      TomAuthenticationInfo(result, TomAccessControlDefinition()),
    );
  }
}

/// Orchestrates the server-side login flow and issues JWT tokens.
///
/// A server endpoint subclasses this and exposes [authenticateGuest] /
/// [authenticatePass1] / [authenticatePass2] as HTTP endpoints. Each takes a
/// `TomAuthenticationMessage` (the wire request), delegates credential checking
/// to the configured [TomAuthenticationService], and — on success — encodes the
/// resulting principal into two JWTs in the returned [TomAuthenticationResult]:
/// an authentication token (public claims) and an authorization token (public
/// claims plus the encrypted access-control payload).
///
/// Which service is used is selected per flow via the static
/// [globalSettingGuestAuthenticationService] /
/// [globalSettingUserAuthenticationService]; the JWT issuer is
/// [globalSettingJwtOrganization].
@tomReflector
class TomAuthenticationServer {
  /// The service used for authenticated-user logins (pass 1).
  static TomAuthenticationService globalSettingUserAuthenticationService =
      TomDummyAuthenticationService();

  /// The service used for guest logins.
  static TomAuthenticationService globalSettingGuestAuthenticationService =
      TomDummyAuthenticationService();

  /// The `iss` (issuer) organization stamped onto issued JWTs.
  static String globalSettingJwtOrganization = "tom";

  /// Authenticates a guest login via [globalSettingGuestAuthenticationService].
  Future<TomAuthenticationResult> authenticateGuest(
    TomAuthenticationMessage m,
  ) async {
    return await authenticateUser(m, true);
  }

  /// First authentication pass: validates user credentials via
  /// [globalSettingUserAuthenticationService] and issues tokens on success.
  Future<TomAuthenticationResult> authenticatePass1(
    TomAuthenticationMessage m,
  ) async {
    return await authenticateUser(m, false);
  }

  /// Second authentication pass (2FA). Not yet implemented — always throws
  /// [UnsupportedError].
  Future<TomAuthenticationResult> authenticatePass2(
    TomAuthenticationMessage m,
  ) async {
    throw UnsupportedError("Two factor authentication is not yet implemented");
  }

  /// Runs a login: builds [TomAuthenticationData] from the message, delegates to
  /// the guest or user service per [guestLogin], and encodes the principal into
  /// the authentication/authorization JWTs of the returned result. A
  /// [LoginException] yields a failed result carrying its `key`; any other error
  /// yields a `"login.error.unknown"` result.
  Future<TomAuthenticationResult> authenticateUser(
    TomAuthenticationMessage m,
    bool guestLogin,
  ) async {
    var authData = TomAuthenticationData(
      client: m.client,
      username: m.userName,
      organization: m.organization,
      application: m.application,
      process: m.process,
      language: m.clientLanguage,
      country: m.clientCountry,
      key: m.password,
      // TODO: get timezone from somewhere. Maybe best from user preferences in app?
      timezone: m.clientTimezone,
    );
    try {
      // TODO: is this where we get the principals cli from? Or is this obtained from the environment?
      var authInfo =
          await (guestLogin
                  ? globalSettingGuestAuthenticationService
                  : globalSettingUserAuthenticationService)
              .authenticateUser(authData);

      var (
        publicInfo,
        privateInfo,
      ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
        authInfo.principal,
        authInfo.acd,
        m.clientCountry,
        m.clientLanguage,
      );

      var result = TomAuthenticationResult();
      TomServerJwtToken authenticationJwt = TomServerJwtToken(publicInfo);
      result.authenticationToken = authenticationJwt.getJWT(globalSettingJwtOrganization);
      TomServerJwtToken authorizationJwt = TomServerJwtToken(
        publicInfo,
        encryptedData: privateInfo,
      );
      result.authorizationToken = authorizationJwt.getJWT(globalSettingJwtOrganization);
      return result;
    } catch (ex, s) {
      if (ex is LoginException) {
        var result = TomAuthenticationResult(ex.key);
        tomLog.info("Login failed ${ex.key} ${ex.parameters}");
        return result;
      } else {
        var result = TomAuthenticationResult("login.error.unknown");
        tomLog.error("Login failed with unexpected error $ex");
        tomPrintStackTrace(s);
        return result;
      }
    }
  }
}
