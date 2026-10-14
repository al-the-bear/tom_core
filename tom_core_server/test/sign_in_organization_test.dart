/// The sign-in organization: settled against the user's memberships at
/// sign-in, listed, and switched within a session without a credential.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

TomAuthenticationMessage _message({
  String userName = 'alice',
  String organization = 'acme-sales',
}) => TomAuthenticationMessage()
  ..client = 'web'
  ..userName = userName
  ..password = 's3cret'
  ..organization = organization
  ..application = 'console'
  ..process = 'login'
  ..clientLanguage = 'en'
  ..clientCountry = 'US'
  ..clientTimezone = 'UTC';

/// [username] signed in for [organization], holding the role
/// `member-of-<organization>` — so a test can see whose rights a token carries.
TomPrincipal _principal(
  String username,
  String organization, {
  bool authenticated = true,
}) => TomPrincipal(
  authenticated: authenticated,
  organization: organization,
  application: 'console',
  user: TomUser(id: 'u-$username', username: username),
  aci: TomAccessControlInformation(roles: ['member-of-$organization']),
);

/// Resolves a login for the organization it names, counting its calls.
class _Service implements TomAuthenticationService {
  int calls = 0;

  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async {
    calls++;
    return TomAuthenticationInfo(
      _principal(
        a.username,
        a.organization,
        authenticated: a.username != 'GUEST',
      ),
      TomAccessControlDefinition(),
    );
  }
}

/// alice is a member of acme-sales and acme-hq (the default); bob of nothing.
class _Directory implements TomSignInOrganizationDirectory {
  _Directory({
    this.choiceOffered = true,
    this.fallback = TomOrganizationFallback.refuse,
  });

  final bool choiceOffered;
  final TomOrganizationFallback fallback;
  final List<String> signedInFor = [];

  @override
  Future<TomSignInOrganizations> organizationsFor(
    TomPrincipal principal,
  ) async => principal.username == 'alice'
      ? TomSignInOrganizations(
          const [
            TomSignInOrganization('acme-sales', name: 'Sales'),
            TomSignInOrganization('acme-hq', name: 'Headquarters'),
          ],
          defaultOrganization: 'acme-hq',
          choiceOffered: choiceOffered,
          fallback: fallback,
        )
      : TomSignInOrganizations(const []);

  @override
  Future<TomAuthenticationInfo> signInFor(
    TomPrincipal principal,
    String organization,
  ) async {
    signedInFor.add(organization);
    return TomAuthenticationInfo(
      _principal(principal.username, organization),
      TomAccessControlDefinition(),
    );
  }
}

Map<String, dynamic> _claims(String token) =>
    TomClientJwtToken(token, decrypt: false).payload!;

void main() {
  late _Service service;
  late TomAuthenticationService savedUser;
  late TomAuthenticationService savedGuest;
  late bool savedProtection;

  setUp(() {
    savedUser = TomAuthenticationServer.globalSettingUserAuthenticationService;
    savedGuest =
        TomAuthenticationServer.globalSettingGuestAuthenticationService;
    savedProtection = TomResourceKeyProtection.globalSettingProtectionDefault;
    TomResourceKeyProtection.globalSettingProtectionDefault = false;
    service = _Service();
    TomAuthenticationServer.globalSettingUserAuthenticationService = service;
    TomAuthenticationServer.globalSettingGuestAuthenticationService = service;
    TomBean.resetBeanContext();
  });

  tearDown(() {
    TomAuthenticationServer.globalSettingUserAuthenticationService = savedUser;
    TomAuthenticationServer.globalSettingGuestAuthenticationService =
        savedGuest;
    TomResourceKeyProtection.globalSettingProtectionDefault = savedProtection;
    TomJwtSigning.reset();
    TomAuditTrail.uninstall();
    TomBean.resetBeanContext();
  });

  _Directory install(_Directory directory) {
    TomBean.withType<TomSignInOrganizationDirectory>(directory);
    return directory;
  }

  group('at sign-in', () {
    test('a member organization the login names stands', () async {
      final directory = install(_Directory());
      final result = await TomAuthenticationServer().authenticatePass1(
        _message(),
      );
      expect(result.error, isEmpty);
      expect(_claims(result.authenticationToken)['organization'], 'acme-sales');
      expect(directory.signedInFor, isEmpty);
    });

    test('a login naming none is signed in for the default', () async {
      final directory = install(_Directory());
      final result = await TomAuthenticationServer().authenticatePass1(
        _message(organization: ''),
      );
      expect(_claims(result.authenticationToken)['organization'], 'acme-hq');
      expect(directory.signedInFor, ['acme-hq']);
      final rights = TomClientJwtToken(result.authorizationToken).secretData!;
      expect(rights['roles'], ['member-of-acme-hq']);
    });

    test('an organization the user is not a member of is refused', () async {
      install(_Directory());
      final result = await TomAuthenticationServer().authenticatePass1(
        _message(organization: 'globex'),
      );
      expect(result.error, 'login.error.organization.not-member');
      expect(result.authenticationToken, isEmpty);
    });

    test('... or signed in for the default, where the list says so', () async {
      install(_Directory(fallback: TomOrganizationFallback.useDefault));
      final result = await TomAuthenticationServer().authenticatePass1(
        _message(organization: 'globex'),
      );
      expect(_claims(result.authenticationToken)['organization'], 'acme-hq');
    });

    test('an account of no organization is refused', () async {
      install(_Directory());
      final result = await TomAuthenticationServer().authenticatePass1(
        _message(userName: 'bob', organization: ''),
      );
      expect(result.error, 'login.error.organization.none');
    });

    test('without a directory the organization is the service\'s', () async {
      final result = await TomAuthenticationServer().authenticatePass1(
        _message(organization: 'globex'),
      );
      expect(_claims(result.authenticationToken)['organization'], 'globex');
    });

    test('a guest is not settled', () async {
      final directory = install(_Directory());
      final result = await TomAuthenticationServer().authenticateGuest(
        _message(userName: 'GUEST', organization: 'anything'),
      );
      expect(result.error, isEmpty);
      expect(directory.signedInFor, isEmpty);
    });
  });

  group('the list', () {
    test('names the organizations, the default and the choice', () async {
      install(_Directory());
      final list = await TomAuthenticationServer().signInOrganizations(
        principal: _principal('alice', 'acme-sales'),
      );
      expect(list.toJson(), {
        'organizations': [
          {'id': 'acme-sales', 'name': 'Sales'},
          {'id': 'acme-hq', 'name': 'Headquarters'},
        ],
        'defaultOrganization': 'acme-hq',
        'choiceOffered': true,
      });
    });

    test('a default that is not in the list is refused', () {
      expect(
        () => TomSignInOrganizations(const [
          TomSignInOrganization('a'),
        ], defaultOrganization: 'b'),
        throwsArgumentError,
      );
    });
  });

  group('a switch', () {
    test('issues tokens for the other organization without a credential, '
        'and is audited', () async {
      final directory = install(_Directory());
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      final session = _principal('alice', 'acme-sales');

      final result = await TomAuthenticationServer().switchOrganization(
        _message(organization: 'acme-hq'),
        principal: session,
      );

      expect(result.error, isEmpty);
      final claims = _claims(result.authenticationToken);
      expect(claims['organization'], 'acme-hq');
      expect(claims[Tom2FAClaims.requires2FA], isNot('true'));
      expect(
        TomClientJwtToken(result.authorizationToken).secretData!['roles'],
        ['member-of-acme-hq'],
      );
      expect(service.calls, 0, reason: 'no credential is checked');
      expect(directory.signedInFor, ['acme-hq']);
      final record = sink.records.single;
      expect(record.target, TomAuthenticationServer.switchAuditTarget);
      expect(record.targetKey, 'acme-hq');
      expect(record.detail, 'from acme-sales to acme-hq');
    });

    Future<String> refusal(
      _Directory directory,
      String organization, {
      TomPrincipal? principal,
    }) async {
      install(directory);
      final result = await TomAuthenticationServer().switchOrganization(
        _message(organization: organization),
        principal: principal ?? _principal('alice', 'acme-sales'),
      );
      expect(result.authenticationToken, isEmpty);
      return result.error;
    }

    test('to an organization the user is not a member of is refused', () async {
      expect(
        await refusal(_Directory(), 'globex'),
        'login.error.organization.not-member',
      );
    });

    test('is refused where the list offers no choice', () async {
      expect(
        await refusal(_Directory(choiceOffered: false), 'acme-hq'),
        'login.error.organization.choice-not-offered',
      );
    });

    test('needs a fully signed-in session', () async {
      expect(
        await refusal(
          _Directory(),
          'acme-hq',
          principal: _principal('alice', 'acme-sales', authenticated: false),
        ),
        'login.error.not-authenticated',
      );
    });

    test('needs a directory', () async {
      final result = await TomAuthenticationServer().switchOrganization(
        _message(organization: 'acme-hq'),
        principal: _principal('alice', 'acme-sales'),
      );
      expect(result.error, 'login.error.organization.no-directory');
    });
  });
}
