/// Single sign-on against a real identity provider: an OpenID Connect login and
/// two SAML 2.0 logins against Keycloak, each driven the way a browser drives
/// it — the redirect out, the provider's login form, the redirect or form post
/// back — and completed through the framework's own login path.
///
/// The whole file is `@Tags(['sso'])` and skips itself when no Keycloak is
/// listening on `127.0.0.1:8089`. `tool/run_sso_tests.sh` starts one from
/// `docker-compose.sso.yaml`, whose realm (`test/fixtures/keycloak/`) holds the
/// clients and users named here.
@Tags(['sso'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

final String _keycloak =
    Platform.environment['TOM_CORE_SERVER_SSO_URL'] ?? 'http://127.0.0.1:8089';
String get _realm => '$_keycloak/realms/tom';

const _app = 'http://127.0.0.1:18089';
const _redirectUri = '$_app/sso/callback';
const _acsUrl = '$_app/saml/acs';

Future<String?> _skipReason() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(
      Uri.parse('$_realm/.well-known/openid-configuration'),
    );
    final response = await request.close();
    await response.drain<void>();
    client.close(force: true);
    return response.statusCode == 200
        ? null
        : 'Keycloak answered ${response.statusCode}';
  } catch (error) {
    return 'No Keycloak at $_keycloak (start it with tool/run_sso_tests.sh): '
        '$error';
  }
}

void main() async {
  final skipReason = await _skipReason();

  setUpAll(initializeReflection);

  group('OpenID Connect against Keycloak', () {
    late TomOAuthFlow flow;

    setUp(() async {
      flow = TomOAuthFlow(
        providers: await TomOAuthProviders.discover({
          'keycloak': {
            'issuer': _realm,
            'discovery': true,
            'clientId': 'tom-oidc',
            'clientSecret': 'tom-oidc-secret',
            'redirectUri': _redirectUri,
            'usernameClaim': 'email',
            'groupsClaim': 'groups',
            'defaultRoles': ['employee'],
            'roleMapping': {
              'admins': ['tom.admin'],
              'staff': ['tom.user'],
            },
          },
        }),
        stateStore: TomOAuthMemoryStateStore(),
        transport: TomHttpOAuthTokenTransport(),
      );
    });

    test('discovery reads the endpoints Keycloak publishes', () {
      final provider = flow.providers['keycloak'];
      expect(
        provider.authorizationEndpoint,
        '$_realm/protocol/openid-connect/auth',
      );
      expect(provider.tokenEndpoint, '$_realm/protocol/openid-connect/token');
    });

    test(
      'a login provisions the user and maps the groups onto roles',
      () async {
        final directory = _Directory();
        final identities = TomMemoryExternalIdentityStore();
        final service = TomOAuthAuthenticationService(
          directory: directory,
          flow: flow,
          identityStore: identities,
        );

        Future<TomAuthenticationInfo> signIn(
          String user,
          String password,
        ) async {
          final begun = await flow.beginAuthorization(
            TomOAuthAuthorizationRequest(providerId: 'keycloak'),
          );
          final callback = await _Browser().signIn(
            Uri.parse(begun.authorizationUri),
            user,
            password,
          );
          final back = callback.redirect!;
          expect(back.origin + back.path, _redirectUri);
          expect(back.queryParameters['state'], begun.state);
          return service.authenticateUser(
            _authData(
              TomOAuthCredential(
                code: back.queryParameters['code']!,
                state: back.queryParameters['state']!,
              ),
            ),
          );
        }

        final alice = await signIn('alice', 'alice-password');
        expect(alice.principal.user.username, 'alice@example.test');
        expect(alice.principal.aci.roles, [
          'employee',
          'tom.admin',
          'tom.user',
        ]);
        expect(
          directory.provisioned.single.groups,
          unorderedEquals(['admins', 'staff']),
        );

        // The second login finds the link the first one wrote.
        final again = await signIn('alice', 'alice-password');
        expect(again.principal.user.username, 'alice@example.test');
        expect(directory.provisioned, hasLength(1));

        final bob = await signIn('bob', 'bob-password');
        expect(bob.principal.aci.roles, ['employee', 'tom.user']);
      },
    );

    test('a code is spent once', () async {
      final begun = await flow.beginAuthorization(
        TomOAuthAuthorizationRequest(providerId: 'keycloak'),
      );
      final back = (await _Browser().signIn(
        Uri.parse(begun.authorizationUri),
        'bob',
        'bob-password',
      )).redirect!;
      final code = back.queryParameters['code']!;
      await flow.completeAuthorization(code: code, state: begun.state);
      await expectLater(
        flow.completeAuthorization(code: code, state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.unknown_state',
          ),
        ),
      );
    });
  }, skip: skipReason);

  group('SAML 2.0 against Keycloak', () {
    late TomOAuthMemoryStateStore store;
    late TomSamlFlow saml;
    late TomOAuthFlow flow;

    setUp(() async {
      Map<String, Object?> sp(String entity, {bool signRequests = false}) => {
        'metadataUrl': '$_realm/protocol/saml/descriptor',
        'spEntityId': '$_app/saml/$entity',
        'acsUrl': _acsUrl,
        'redirectUri': _redirectUri,
        'usernameAttribute': 'email',
        'displayNameAttribute': 'firstName',
        'nameIdFormat': 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified',
        'groupsClaim': 'groups',
        'roleMapping': {
          'admins': ['tom.admin'],
        },
        if (signRequests) 'spSigningKeyFile': 'test/fixtures/saml/sp_key.pem',
        if (signRequests) 'spCertificateFile': 'test/fixtures/saml/sp_cert.pem',
      };
      store = TomOAuthMemoryStateStore();
      saml = TomSamlFlow(
        providers: await TomSamlProviders.discover({
          // Keycloak requires this service provider's requests to be signed,
          // and signs its responses.
          'response-signed': sp('response-signed', signRequests: true),
          // This one sends unsigned requests and is answered with a signed
          // assertion inside an unsigned response.
          'assertion-signed': {
            ...sp('assertion-signed'),
            'requireSignedAssertion': true,
          },
        }),
        stateStore: store,
      );
      flow = TomOAuthFlow(
        providers: TomOAuthProviders(const {}),
        stateStore: store,
        transport: TomHttpOAuthTokenTransport(),
        saml: saml,
      );
    });

    /// Runs one SAML login through Keycloak and answers the login result.
    Future<TomAuthenticationInfo> signIn(
      String providerId,
      _Directory directory,
    ) async {
      final begun = await flow.beginAuthorization(
        TomOAuthAuthorizationRequest(providerId: providerId),
      );
      final page = await _Browser().signIn(
        Uri.parse(begun.authorizationUri),
        'alice',
        'alice-password',
      );
      final post = page.formPost!;
      expect(post.action.toString(), _acsUrl);
      expect(post.fields['RelayState'], begun.state);

      final back = Uri.parse(
        await saml.acceptResponse(
          samlResponse: post.fields['SAMLResponse']!,
          relayState: post.fields['RelayState']!,
        ),
      );
      expect(back.queryParameters['error'], isNull, reason: '$back');
      return TomOAuthAuthenticationService(
        directory: directory,
        flow: flow,
        identityStore: TomMemoryExternalIdentityStore(),
      ).authenticateUser(
        _authData(
          TomOAuthCredential(
            code: back.queryParameters['code']!,
            state: back.queryParameters['state']!,
          ),
        ),
      );
    }

    test('the metadata supplies Keycloak\'s entity id, address and key', () {
      final provider = saml.providers['response-signed'];
      expect(provider.issuer, _realm);
      expect(provider.ssoUrl, '$_realm/protocol/saml');
      expect(provider.idpSigningKeys, isNotEmpty);
    });

    test(
      'a signed request is answered with a signed response that verifies',
      () async {
        final directory = _Directory();
        final info = await signIn('response-signed', directory);
        expect(info.principal.user.username, 'alice@example.test');
        expect(info.principal.aci.roles, ['tom.admin']);
        final identity = directory.provisioned.single;
        expect(identity.issuer, _realm);
        expect(identity.subject, 'alice');
        expect(identity.displayName, 'Alice');
        expect(identity.groups, unorderedEquals(['admins', 'staff']));
      },
    );

    test('a signed assertion inside an unsigned response verifies', () async {
      final directory = _Directory();
      final info = await signIn('assertion-signed', directory);
      expect(info.principal.user.username, 'alice@example.test');
      expect(directory.provisioned.single.subject, 'alice');
    });

    test('a response altered on its way back is refused', () async {
      final begun = await flow.beginAuthorization(
        TomOAuthAuthorizationRequest(providerId: 'response-signed'),
      );
      final post = (await _Browser().signIn(
        Uri.parse(begun.authorizationUri),
        'alice',
        'alice-password',
      )).formPost!;
      final xml = utf8.decode(base64.decode(post.fields['SAMLResponse']!));
      final forged = base64.encode(
        utf8.encode(xml.replaceFirst('>alice<', '>mallory<')),
      );
      expect(forged, isNot(post.fields['SAMLResponse']));
      final back = Uri.parse(
        await saml.acceptResponse(
          samlResponse: forged,
          relayState: post.fields['RelayState']!,
        ),
      );
      expect(back.queryParameters['error'], 'access_denied');
      expect(
        back.queryParameters['error_description'],
        'saml.signature.digest_mismatch',
      );
    });
  }, skip: skipReason);
}

TomAuthenticationData _authData(TomOAuthCredential credential) =>
    TomAuthenticationData(
      username: TomUser.guestUsername,
      key: credential,
      organization: '',
      application: '',
      process: '',
      language: 'en',
      country: 'XX',
      timezone: 'utc',
      client: '',
    );

/// A deployment directory that provisions every identity it is offered.
class _Directory extends TomExternalIdentityDirectory {
  final Map<String, TomExternalIdentity> accounts = {};
  final List<TomExternalIdentity> provisioned = [];

  TomAuthenticationInfo _info(String username) => TomAuthenticationInfo(
    TomPrincipal(
      authenticated: true,
      context: {},
      requires2FA: false,
      twoFactorType: null,
      clientId: 0,
      organization: '',
      organizationId: 0,
      application: '',
      applicationId: 0,
      process: '',
      processId: 0,
      language: 'en',
      country: 'XX',
      clientCountry: 'XX',
      clientLanguage: 'en',
      clientTimezone: 'utc',
      user: TomUser(
        id: accounts.length,
        username: username,
        firstname: '',
        lastname: '',
        attributes: {},
        timezone: 'utc',
      ),
    ),
    TomAccessControlDefinition(),
  );

  @override
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  ) async => accounts.containsKey(username) ? _info(username) : null;

  @override
  Future<TomAuthenticationInfo> provisionFromExternalIdentity(
    TomExternalIdentity identity,
    TomAuthenticationData authData,
  ) async {
    provisioned.add(identity);
    accounts[identity.username] = identity;
    return _info(identity.username);
  }
}

/// Where a sign-in at Keycloak ended: a redirect back to the application, or a
/// page that auto-posts a form to it.
class _Outcome {
  _Outcome({this.redirect, this.formPost});

  final Uri? redirect;
  final _FormPost? formPost;
}

class _FormPost {
  _FormPost(this.action, this.fields);

  final Uri action;
  final Map<String, String> fields;
}

/// Just enough browser to sign in at Keycloak: cookies, redirects within
/// Keycloak, and the login form.
class _Browser {
  final HttpClient _client = HttpClient();
  final Map<String, Cookie> _cookies = {};

  /// Opens [start], submits the login form as [user], and answers where
  /// Keycloak sent the browser.
  Future<_Outcome> signIn(Uri start, String user, String password) async {
    try {
      var page = await _request('GET', start);
      if (page.redirect != null) {
        return _Outcome(redirect: page.redirect);
      }
      final form = _formIn(page.body, start, id: 'kc-form-login');
      if (form == null) {
        fail('Keycloak showed no login form:\n${page.body}');
      }
      page = await _request(
        'POST',
        form.action,
        form: {...form.fields, 'username': user, 'password': password},
      );
      if (page.redirect != null) return _Outcome(redirect: page.redirect);
      final post = _formIn(page.body, form.action);
      if (post == null || !post.fields.containsKey('SAMLResponse')) {
        fail(
          'Keycloak answered neither a redirect nor a SAML post:\n'
          '${page.body}',
        );
      }
      return _Outcome(formPost: post);
    } finally {
      _client.close(force: true);
    }
  }

  /// One request, following redirects that stay at Keycloak. A redirect to
  /// anywhere else is where the browser leaves, and is answered as such.
  Future<({String body, Uri? redirect})> _request(
    String method,
    Uri uri, {
    Map<String, String>? form,
  }) async {
    var current = uri;
    var currentMethod = method;
    var body = form;
    for (var hops = 0; hops < 10; hops++) {
      final request = await _client.openUrl(currentMethod, current)
        ..followRedirects = false;
      if (_cookies.isNotEmpty) request.cookies.addAll(_cookies.values);
      if (body != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
        request.write(
          body.entries
              .map(
                (e) =>
                    '${Uri.encodeQueryComponent(e.key)}='
                    '${Uri.encodeQueryComponent(e.value)}',
              )
              .join('&'),
        );
      }
      final response = await request.close();
      for (final cookie in response.cookies) {
        _cookies[cookie.name] = Cookie(cookie.name, cookie.value);
      }
      final text = await response.transform(utf8.decoder).join();
      if (const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final next = current.resolve(response.headers.value('location')!);
        if (!next.toString().startsWith(_keycloak)) {
          return (body: text, redirect: next);
        }
        current = next;
        currentMethod = 'GET';
        body = null;
        continue;
      }
      if (response.statusCode >= 400) {
        fail('Keycloak answered ${response.statusCode} for $current:\n$text');
      }
      return (body: text, redirect: null);
    }
    fail('Too many redirects from $uri');
  }

  /// The first form in [html] (with [id], when given): its absolute action and
  /// its named inputs.
  static _FormPost? _formIn(String html, Uri base, {String? id}) {
    final formMatch = RegExp(
      '<form[^>]*${id == null ? '' : 'id="$id"'}[^>]*>([\\s\\S]*?)</form>',
      caseSensitive: false,
    ).firstMatch(html);
    if (formMatch == null) return null;
    final tag = RegExp(
      '<form[^>]*>',
      caseSensitive: false,
    ).firstMatch(formMatch.group(0)!)!.group(0)!;
    final action = _unescape(
      RegExp('action="([^"]*)"').firstMatch(tag)?.group(1) ?? '',
    );
    final fields = <String, String>{};
    for (final input in RegExp(
      '<input[^>]*>',
      caseSensitive: false,
    ).allMatches(formMatch.group(1)!)) {
      final name = RegExp('name="([^"]*)"').firstMatch(input.group(0)!);
      if (name == null) continue;
      final value = RegExp('value="([^"]*)"').firstMatch(input.group(0)!);
      fields[name.group(1)!] = _unescape(value?.group(1) ?? '');
    }
    return _FormPost(base.resolve(action), fields);
  }

  static String _unescape(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x3d;', '=')
      .replaceAll('&#x2f;', '/')
      .replaceAll('&#x2b;', '+')
      .replaceAll('&#61;', '=')
      .replaceAll('&#43;', '+')
      .replaceAll('&#47;', '/')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
