/// A passkey, enrolled and used through this sample's login.
///
/// `erin` is offered a second factor; she chooses a passkey, a software
/// authenticator makes one against the options the server issued, and her next
/// login is challenged for it and completes. Every step runs through the
/// sample's [AuthTokenService] and the framework's `TomAuthenticationServer`
/// underneath, with the deployment's own mechanism list and relying party —
/// only the authenticator is simulated, because a test has no browser.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

UserRecord _erin() => applyPassword(
  UserRecord()
    ..id = 6
    ..username = 'erin'
    ..displayName = 'Erin Example'
    ..email = 'erin@example.com'
    ..status = UserStatus.active.name,
  'erin-pass',
);

AuthTokenService _service() => AuthTokenService(
  AdvancedAuthenticationService(
    InMemoryAuthUserStore(
      users: [_erin()],
      roleKeysByUserId: const {
        6: ['editor', 'two_factor_optional'],
      },
    ),
  ),
  issuer: 'tom',
);

LoginRequest _login() => LoginRequest(
  username: 'erin',
  password: 'erin-pass',
  app: 'todo',
  org: 'acme',
);

void main() {
  late TomMemory2FAEnrolmentStore enrolments;

  setUp(() {
    TomBean.resetBeanContext();
    TomBearerAuthentication.clearTokens();
    // The same relying party and mechanism list the boot installs.
    installPasskeyRelyingParty(environment: const {});
    Tom2FARegistry.reset();
    Tom2FARegistry.register(
      TomTotp2FAService.mechanismType,
      TomTotp2FAService(),
    );
    Tom2FARegistry.register(
      TomWebAuthn2FAService.mechanismType,
      TomWebAuthn2FAService(),
    );
    TomBean.withType<Tom2FAPolicy>(
      TomRole2FAPolicy(
        requirementByRole: const {
          'two_factor_optional': Tom2FARequirement.optional,
        },
        mechanisms: advancedTwoFactorMechanisms,
      ),
    );
    enrolments = TomMemory2FAEnrolmentStore();
    TomBean.withType<Tom2FAEnrolmentStore>(enrolments);
  });

  tearDown(() {
    TomBearerAuthentication.clearTokens();
    TomBean.resetBeanContext();
    TomWebAuthn2FAService.globalSettingRelyingPartyId = '';
    TomWebAuthn2FAService.globalSettingAllowedOrigins = {};
  });

  test('the relying party is localhost, with the default browser origin', () {
    expect(TomWebAuthn2FAService.globalSettingRelyingPartyId, 'localhost');
    expect(TomWebAuthn2FAService.allowedOrigins, {'http://localhost:8090'});

    installPasskeyRelyingParty(
      environment: const {
        'ADVANCED_PASSKEY_ORIGINS':
            'http://localhost:9000, http://localhost:9001',
      },
    );
    expect(TomWebAuthn2FAService.allowedOrigins, {
      'http://localhost:9000',
      'http://localhost:9001',
    });
  });

  test('erin enrols a passkey, then signs in with it', () async {
    final service = _service();
    final authenticator = TomWebAuthnSoftwareAuthenticator(
      origin: advancedPasskeyDefaultOrigin,
    );

    // Pass 1 offers a factor, and the passkey is among the choices.
    final offered = await service.login(_login());
    expect(offered.requires2FAEnrolment, isTrue);
    expect(
      offered.availableTwoFactorMethods.map((m) => m.type),
      containsAll(advancedTwoFactorMechanisms),
    );

    // Choosing it yields creation options bound to this deployment.
    final chosen = await service.beginEnrolment(
      TwoFactorEnrolmentRequest(
        type: TomWebAuthn2FAService.mechanismType,
        enrolmentToken: offered.authzToken,
      ),
    );
    TomBearerAuthentication.setTokens(chosen.authToken, chosen.authzToken);
    final offer = TomBearerAuthentication.pendingTwoFactorEnrolment!;
    expect(offer.type, TomWebAuthn2FAService.mechanismType);
    final creation = TomWebAuthnCreationOptions.fromJson(
      offer.clientData[TomWebAuthn2FAService.optionsKey],
    )!;
    expect(creation.rpId, 'localhost');
    expect(creation.userName, 'erin');

    // The authenticator's answer travels through the same String seam a typed
    // code does, and completes the login.
    final enrolled = await service.confirmEnrolment(
      TwoFactorEnrolmentRequest(
        code: authenticator.create(creation).toSubmission(),
        enrolmentToken: chosen.authzToken,
      ),
    );
    expect(enrolled.requires2FA, isFalse);
    expect(enrolled.user.username, 'erin');
    TomBearerAuthentication.clearTokens();

    // The next login is challenged for the passkey…
    final challenged = await service.login(_login());
    expect(challenged.requires2FA, isTrue);
    expect(challenged.twoFactorType, TomWebAuthn2FAService.mechanismType);
    TomBearerAuthentication.setTokens(
      challenged.authToken,
      challenged.authzToken,
    );
    final request = TomWebAuthnRequestOptions.fromJson(
      TomBearerAuthentication
          .pendingTwoFactorChallenge!
          .clientData[TomWebAuthn2FAService.optionsKey],
    )!;
    expect(request.allowCredentialIds, [authenticator.id]);
    TomBearerAuthentication.clearTokens();

    // …and completes with it.
    final signedIn = await service.submitSecondFactor(
      SecondFactorRequest(
        code: authenticator.get(request).toSubmission(),
        challengeToken: challenged.authzToken,
      ),
    );
    expect(signedIn.requires2FA, isFalse);
    expect(signedIn.user.username, 'erin');
  });

  test('a passkey from another origin does not complete the login', () async {
    final service = _service();
    final authenticator = TomWebAuthnSoftwareAuthenticator(
      origin: advancedPasskeyDefaultOrigin,
    );
    final offered = await service.login(_login());
    final chosen = await service.beginEnrolment(
      TwoFactorEnrolmentRequest(
        type: TomWebAuthn2FAService.mechanismType,
        enrolmentToken: offered.authzToken,
      ),
    );
    TomBearerAuthentication.setTokens(chosen.authToken, chosen.authzToken);
    final creation = TomWebAuthnCreationOptions.fromJson(
      TomBearerAuthentication
          .pendingTwoFactorEnrolment!
          .clientData[TomWebAuthn2FAService.optionsKey],
    )!;
    TomBearerAuthentication.clearTokens();
    await service.confirmEnrolment(
      TwoFactorEnrolmentRequest(
        code: authenticator.create(creation).toSubmission(),
        enrolmentToken: chosen.authzToken,
      ),
    );

    final challenged = await service.login(_login());
    TomBearerAuthentication.setTokens(
      challenged.authToken,
      challenged.authzToken,
    );
    final request = TomWebAuthnRequestOptions.fromJson(
      TomBearerAuthentication
          .pendingTwoFactorChallenge!
          .clientData[TomWebAuthn2FAService.optionsKey],
    )!;
    TomBearerAuthentication.clearTokens();

    authenticator.origin = 'https://advanced-todo.example';
    await expectLater(
      service.submitSecondFactor(
        SecondFactorRequest(
          code: authenticator.get(request).toSubmission(),
          challengeToken: challenged.authzToken,
        ),
      ),
      throwsA(isA<TomLoginException>()),
    );
  });
}
