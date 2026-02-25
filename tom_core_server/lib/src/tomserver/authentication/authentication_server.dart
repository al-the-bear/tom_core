import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

// TODO: add support for 2FA
@tomReflector
class TomAuthenticationAdaptor {
  final bool guestOnly;
  final bool userOnly;

  TomAuthenticationAdaptor({this.guestOnly = false, this.userOnly = false});
}

@tomReflector
class Tom2FAAdaptor {
  final String type;
  const Tom2FAAdaptor(this.type);
}

class LoginException extends TomServerException {
  LoginException(
    super.key,
    super.userMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

@tomReflector
class TomAuthenticationData {
  String organization;
  String application;
  String process;
  String language;
  String country;
  String timezone;
  String client;

  String username;
  Object? key;

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

@tomReflector
abstract class TomAuthenticationService {
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  );
}

// TODO: complete the definition of this. Must support email, SMS, authenticator-type etc.
@tomReflector
abstract class Tom2FAService {
  // required UI to show messages to user (inside the client, not here on the server ;-) ). Need to envision a mechanism for this, especially to keep that flexible
}

class TomAuthenticationInfo {
  TomPrincipal principal;
  TomAccessControlDefinition acd;

  TomAuthenticationInfo(this.principal, this.acd);
}

// this class is the default to provide support for guest login without any further user information
class TomDummyAuthenticationService implements TomAuthenticationService {
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

@tomReflector
class TomAuthenticationServer {

  static TomAuthenticationService globalSettingUserAuthenticationService =
      TomDummyAuthenticationService();
  static TomAuthenticationService globalSettingGuestAuthenticationService =
      TomDummyAuthenticationService();

  static String globalSettingJwtOrganization = "tom";

  Future<TomAuthenticationResult> authenticateGuest(
    TomAuthenticationMessage m,
  ) async {
    return await authenticateUser(m, true);
  }

  Future<TomAuthenticationResult> authenticatePass1(
    TomAuthenticationMessage m,
  ) async {
    return await authenticateUser(m, false);
  }

  Future<TomAuthenticationResult> authenticatePass2(
    TomAuthenticationMessage m,
  ) async {
    throw UnsupportedError("Two factor authentication is not yet implemented");
  }

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
