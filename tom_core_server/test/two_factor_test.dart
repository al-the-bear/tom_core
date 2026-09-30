/// Tests for the server-side second-factor subsystem: the adaptor contract, the
/// mechanism registry, the built-in TOTP adaptor, and the two-pass login flow
/// that ties them together.
///
/// The whole flow is connection-free — the interim challenge travels in a JWT
/// signed and RSA-encrypted with the framework's bundled default keys — so a
/// complete `pass1 → challenge → pass2 → session` round trip runs in-process,
/// with no user store, no HTTP and no clock stubbing beyond what TOTP itself
/// needs.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// The RFC 4226 / RFC 6238 reference secret, in the base32 form an
/// authenticator is provisioned with.
///
/// Used here only as *a* working secret for the adaptor's policy tests; that it
/// reproduces the RFC's published codes is the kernel's concern
/// (`TomTotp` in `tom_core_kernel/test/security_test.dart`).
const String _rfcSecretBase32 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

/// Builds the wire message the server consumes. [password] doubles as the
/// primary credential on pass 1 and as the submitted factor on pass 2 — the
/// message's single credential slot, which is exactly why no wire field had to
/// be added for 2FA.
TomAuthenticationMessage _message({
  String userName = 'alice',
  String password = 's3cret',
}) => TomAuthenticationMessage()
  ..client = 'web'
  ..userName = userName
  ..password = password
  ..organization = 'acme'
  ..application = 'console'
  ..process = 'login'
  ..clientLanguage = 'en'
  ..clientCountry = 'US'
  ..clientTimezone = 'UTC';

/// Builds a principal that may or may not still owe a second factor, so a test
/// can drive both branches of pass 1 from the same shape.
TomPrincipal _principal(
  TomAuthenticationData a, {
  bool requires2FA = false,
  String? twoFactorType,
  List<String> roles = const ['admin'],
}) => TomPrincipal(
  authenticated: true,
  context: {},
  requires2FA: requires2FA,
  twoFactorType: twoFactorType,
  clientId: 0,
  organization: a.organization,
  organizationId: 0,
  application: a.application,
  applicationId: 0,
  process: a.process,
  processId: 0,
  language: a.language,
  country: a.country,
  clientCountry: a.country,
  clientLanguage: a.language,
  clientTimezone: a.timezone,
  user: TomUser(
    id: 1,
    username: a.username,
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: roles),
);

/// A principal distinguished only by its user id, for the enrolment store —
/// whose entire job is to keep one user's factors away from another's.
///
/// [organization] varies separately so a test can ask what the tenant does
/// *not* do to the storage key.
TomPrincipal _principalWithId(int userId, {String organization = 'acme'}) =>
    TomPrincipal(
      authenticated: true,
      context: {},
      clientId: 0,
      organization: organization,
      organizationId: 0,
      application: 'console',
      applicationId: 0,
      process: 'login',
      processId: 0,
      language: 'en',
      country: 'US',
      clientCountry: 'US',
      clientLanguage: 'en',
      clientTimezone: 'UTC',
      user: TomUser(
        id: userId,
        username: 'user$userId',
        firstname: 'Test',
        lastname: 'User',
        attributes: {},
        timezone: 'utc',
      ),
      aci: TomAccessControlInformation(roles: const ['user']),
    );

/// An authentication service that answers with a fixed principal shape.
class _StubAuthService implements TomAuthenticationService {
  _StubAuthService({this.requires2FA = false, this.twoFactorType});

  final bool requires2FA;
  final String? twoFactorType;

  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async => TomAuthenticationInfo(
    _principal(a, requires2FA: requires2FA, twoFactorType: twoFactorType),
    TomAccessControlDefinition(),
  );
}

/// A mechanism whose "code" is a constant, so the flow tests can assert
/// challenge/verify/retry semantics without depending on the clock.
///
/// Also records what the framework handed it, which is how the tests check that
/// the opaque blobs really do survive the round trip through the token.
class _FakeAdaptor implements Tom2FAService {
  _FakeAdaptor({this.failIssueWith});

  /// The one submission this mechanism accepts.
  static const String expected = '424242';

  /// The displayable hint it advertises.
  static const String hint = '***-**-4711';

  /// Thrown from [issueChallenge] instead of returning, for the pass-1 error
  /// paths (a user who cannot be challenged, a mechanism whose gateway is down).
  final Object? failIssueWith;

  int issued = 0;
  int verified = 0;
  Tom2FAContext? lastVerifyContext;
  Tom2FASubmission? lastSubmission;

  @override
  Tom2FAMethodDescriptor get descriptor =>
      Tom2FAMethodDescriptor.scoped('fake');

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    issued++;
    if (failIssueWith != null) throw failIssueWith!;
    return const Tom2FAChallengeSpec(
      hint: hint,
      clientData: {'shape': 'digits-6'},
      verificationData: {'nonce': 'n-1'},
      attemptsAllowed: 3,
      validity: Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async {
    verified++;
    lastVerifyContext = context;
    lastSubmission = submission;
    return submission.submitted == expected;
  }
}

/// An adaptor that needs something the deployment may not have installed.
///
/// Stands in for the shipped delivered-code adaptors in the registry's own
/// tests, because what the scan does with an unmet prerequisite has to hold for
/// *any* adaptor that declares one — a deployment's own push-approval mechanism
/// as much as the two that ship here — and a test written against the mail
/// adaptor would only pin the shipped case.
class _GatedAdaptor extends _FakeAdaptor implements Tom2FAPrerequisite {
  _GatedAdaptor({this.unmetPrerequisite});

  @override
  final String? unmetPrerequisite;
}

/// A mechanism that can also be *set up*, so the enrolment passes can be driven
/// without the clock TOTP needs.
///
/// Deliberately a second class rather than a flag on [_FakeAdaptor]: the whole
/// point of [Tom2FAEnrolmentSupport] being a separate interface is that a
/// registry may hold adaptors that answer challenges but cannot enrol, and the
/// tests need both shapes present at once to assert that the offer names only
/// the enrollable ones.
class _EnrollableAdaptor implements Tom2FAService, Tom2FAEnrolmentSupport {
  /// The mechanism key this adaptor is registered under.
  static const String type = 'app';

  /// The confirmation the enrolment accepts, and the code the challenge for an
  /// already-enrolled user accepts.
  static const String confirmation = '111222';

  /// The material the offer hands the client (and keeps server-side).
  static const String secret = 'SEED-42';

  int begun = 0;
  int confirmed = 0;
  int issued = 0;

  @override
  Tom2FAMethodDescriptor get descriptor => Tom2FAMethodDescriptor.scoped(type);

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    issued++;
    return const Tom2FAChallengeSpec(
      hint: 'app on this phone',
      attemptsAllowed: 3,
      validity: Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async => submission.submitted == confirmation;

  @override
  Future<Tom2FAEnrolmentOffer> beginEnrolment(Tom2FAContext context) async {
    begun++;
    return Tom2FAEnrolmentOffer(
      type: type,
      hint: 'app on this phone',
      clientData: const {'setupCode': secret},
      enrolmentData: const {'secret': secret},
      attemptsAllowed: 2,
      validity: const Duration(minutes: 10),
    );
  }

  @override
  Future<Tom2FAEnrolment> confirmEnrolment(
    Tom2FAContext context,
    Tom2FAEnrolmentOffer offer,
    String submitted,
  ) async {
    confirmed++;
    if (submitted != confirmation) {
      throw TomLoginException(
        'login.error.2fa.enrolment-invalid-code',
        'The confirmation code does not match the offered factor',
        reason: TomLoginFailure.secondFactorInvalid,
      );
    }
    return Tom2FAEnrolment(
      type: type,
      enrolmentId: 'enrolment-1',
      hint: offer.hint,
      secretData: offer.enrolmentData,
    );
  }
}

/// A policy that grants grace logins and counts the ones actually spent.
///
/// Grace accounting is optional by design ([Tom2FAGraceAccounting]), so the
/// shipped policies do not implement it — a test policy is the only way to
/// observe that the skip pass charges the grace it was told to charge.
class _GracePolicy implements Tom2FAPolicy, Tom2FAGraceAccounting {
  _GracePolicy({required this.requirement, required this.graceLogins});

  final Tom2FARequirement requirement;
  final int graceLogins;

  int graceSpent = 0;

  @override
  Future<Tom2FADecision> decideFor(Tom2FAContext context) async =>
      Tom2FADecision(
        requirement: requirement,
        allowedMechanisms: const ['app'],
        graceLogins: graceLogins,
      );

  @override
  Future<void> recordGraceLoginConsumed(Tom2FAContext context) async {
    graceSpent++;
  }
}

/// Collects what the framework logged, so a test can assert on a diagnostic
/// that has no other observable effect.
///
/// Every level is kept: [TomLogger] hands the output its own configured level
/// and leaves the filtering to it, so filtering here would silently drop the
/// message whenever the suite ran at a quieter level.
class _CapturingLogOutput implements TomLogOutput {
  final List<String> messages = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => messages.add('$message');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One candidate for the adaptor scan, standing in for a reflected class.
///
/// A hand-built mirror rather than a reflected fixture class, because the scan
/// is automatic: a class annotated `@Tom2FAAdaptor` that cannot be used would
/// be found by every other test in this process the first time it looked a
/// mechanism up. Only [metadata], [newInstance] and the name the failure
/// messages interpolate are needed; [noSuchMethod] makes anything else a loud
/// test bug rather than a silent `null`.
class _CandidateMirror implements ClassMirror<Object> {
  _CandidateMirror(
    this._name, {
    required List<Object> metadata,
    required Object Function() instantiate,
  }) : _metadata = metadata,
       _instantiate = instantiate;

  final String _name;
  final List<Object> _metadata;
  final Object Function() _instantiate;

  @override
  List<Object> get metadata => _metadata;

  @override
  Object newInstance(
    String constructorName,
    List<dynamic> positionalArguments, [
    Map<Symbol, dynamic> namedArguments = const {},
  ]) => _instantiate();

  @override
  String toString() => _name;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The candidate mirror was asked for ${invocation.memberName}, which '
    'the adaptor scan does not use. Implement it here if that changes.',
  );
}

/// The JWT registered claims, the validity window and the encrypted blob — all
/// of which differ between two tokens minted a moment apart for reasons that
/// have nothing to do with 2FA.
const _volatileClaims = {
  'iat',
  'exp',
  'nbf',
  'iss',
  'jti',
  'aud',
  'sub',
  'validFrom',
  'validUntil',
  'encrypted',
};

/// The identity claims of [jwt], with the volatile ones stripped — what must be
/// *identical* between a completed pass 2 and a login that never needed one.
Map<String, dynamic> _identityClaims(String jwt) {
  final payload = Map<String, dynamic>.from(
    TomClientJwtToken(jwt, decrypt: false).payload ?? const {},
  );
  payload.removeWhere((key, _) => _volatileClaims.contains(key));
  return payload;
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  group('Tom2FARegistry', () {
    tearDown(Tom2FARegistry.reset);

    // MUST stay ahead of the reflection test below: initializeReflection() is
    // process-global and irreversible, so this is the only window in which the
    // no-reflection state can be observed at all.
    test('tolerates a program with no generated reflection', () {
      // Annotation discovery is a convenience on top of register(), not a
      // precondition of it — a deployment that wires its adaptors by hand must
      // not have its logins fail because there was nothing to scan.
      expect(() => Tom2FARegistry.lookup('anything'), returnsNormally);
      expect(Tom2FARegistry.registeredTypes, isEmpty);
    });

    // Tolerating the missing reflector must not mean saying nothing about it.
    // An empty registry with no diagnostic is the hardest possible shape to
    // debug: every lookup answers null, and null is also what a genuinely
    // unregistered mechanism answers.
    //
    // Logged once per registry lifetime, not once per access: `lookup` runs on
    // every login pass, and a deployment that wires its adaptors by hand is
    // supported rather than broken -- a line per login would be noise it can
    // do nothing about.
    test('says so, once, when there is no reflection to scan', () {
      final log = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      tomLog.logOutput = log;
      addTearDown(() => tomLog.logOutput = previous);

      Tom2FARegistry.registeredTypes;
      Tom2FARegistry.lookup('anything');
      Tom2FARegistry.availableMethods;

      final skipped = log.messages
          .where((m) => m.contains('2FA adaptor scan'))
          .toList();
      expect(skipped, hasLength(1), reason: 'once per lifetime, not per read');
      expect(skipped.single, contains('no generated reflection'));
    });

    test('resolves a hand-registered adaptor', () {
      final adaptor = _FakeAdaptor();
      Tom2FARegistry.register('fake', adaptor);
      expect(identical(Tom2FARegistry.lookup('fake'), adaptor), isTrue);
      expect(Tom2FARegistry.registeredTypes, contains('fake'));
    });

    test('returns null for an unknown mechanism', () {
      expect(Tom2FARegistry.lookup('carrier-pigeon'), isNull);
    });

    test('re-registering the same instance is a no-op', () {
      final adaptor = _FakeAdaptor();
      Tom2FARegistry.register('fake', adaptor);
      expect(() => Tom2FARegistry.register('fake', adaptor), returnsNormally);
    });

    // Two mechanisms answering to one key is a wiring bug; picking one silently
    // would surface it much later and much less clearly.
    test('rejects a second, different adaptor for the same key', () {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      expect(
        () => Tom2FARegistry.register('fake', _FakeAdaptor()),
        throwsA(isA<Tom2FAException>()),
      );
    });

    test(
      'Tom2FAException is a server exception that is not client-throwable',
      () {
        final e = Tom2FAException('authentication.2fa.x', 'boom');
        expect(e, isA<TomServerException>());
        expect(e.clientThrow, isFalse);
      },
    );

    test('reset drops every registration', () {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      Tom2FARegistry.reset();
      expect(Tom2FARegistry.lookup('fake'), isNull);
    });

    // The defect this pins, and the last test that can: it closes the
    // no-reflection window by calling initializeReflection() -- which is
    // exactly where the test below closed it before, so nothing above sees a
    // different world.
    //
    // The scan used to arm its own "already done" flag *before* running, so a
    // scan that could not run was never retried. A process that touched the
    // registry before initializeReflection() -- an eager bean, a settings
    // read, anything -- got an empty registry and kept it, and the reflector
    // that arrived a moment later was never consulted.
    //
    // Deliberately no reset() between the two reads: the whole point is that
    // one registry lifetime spans the reflector's arrival.
    test('picks up a reflector that only becomes available later', () {
      expect(
        Tom2FARegistry.registeredTypes,
        isEmpty,
        reason: 'premise: nothing to scan yet',
      );

      initializeReflection();

      expect(
        Tom2FARegistry.lookup(TomTotp2FAService.mechanismType),
        isA<TomTotp2FAService>(),
        reason: 'the skipped scan must be re-armed, not remembered as done',
      );
    });

    // The dispatch the framework actually relies on: an adaptor is found by its
    // @Tom2FAAdaptor annotation, with nothing naming it anywhere in the server.
    test('discovers annotated adaptors by reflection', () {
      initializeReflection();
      Tom2FARegistry.reset();
      expect(
        Tom2FARegistry.lookup(TomTotp2FAService.mechanismType),
        isA<TomTotp2FAService>(),
      );
      expect(Tom2FARegistry.registeredTypes, contains('totp'));
    });

    // The other way a scan fails: it runs, and throws part-way. A hand-wired
    // adaptor already sitting on a key the scan also claims makes register()
    // reject the scan's instance -- a real wiring bug, and the shape the
    // registry's own dartdoc says must surface at start-up rather than at the
    // login that happens to need the missing mechanism.
    //
    // It used to surface once and then never again, because the flag was
    // already armed: the second read returned a half-built registry, quietly.
    test('a scan that throws part-way keeps throwing', () {
      initializeReflection();
      Tom2FARegistry.reset();
      // Occupy a key the scan will also claim, with a foreign instance.
      Tom2FARegistry.register(TomTotp2FAService.mechanismType, _FakeAdaptor());

      final collision = throwsA(
        isA<Tom2FAException>()
            .having((e) => e.key, 'key', 'authentication.2fa.duplicate_adaptor')
            .having(
              (e) => e.defaultUserMessage,
              'message',
              contains('"${TomTotp2FAService.mechanismType}"'),
            ),
      );

      expect(
        () => Tom2FARegistry.registeredTypes,
        collision,
        reason: 'premise',
      );
      // Same fault, named the same way. Not merely "throws again": a scan that
      // left its own partial work behind would collide with *that* on the
      // retry, and report whichever mechanism it happened to reach first.
      expect(() => Tom2FARegistry.registeredTypes, collision);
    });
  });

  // ===========================================================================
  // THE CATALOG
  // ===========================================================================

  /// What a client is given when it must render "*choose a method*".
  ///
  /// The property under test throughout is that **no literal text escapes**: a
  /// descriptor carrying `'Authenticator app'` would look right in English and
  /// be a translation defect everywhere else, and no test that only checked the
  /// list's *shape* could tell the two apart.
  group('Tom2FAMethodDescriptor and the method catalog', () {
    setUp(Tom2FARegistry.reset);
    tearDown(Tom2FARegistry.reset);

    test('scoped() derives all three keys from the mechanism key', () {
      final descriptor = Tom2FAMethodDescriptor.scoped('sms');
      expect(descriptor.type, 'sms');
      expect(descriptor.displayNameKey, 'two_factor.sms.name');
      expect(descriptor.descriptionKey, 'two_factor.sms.description');
      expect(descriptor.iconKey, 'two_factor.sms.icon');
    });

    test(
      'availableMethods reports the TOTP descriptor with resource keys',
      () async {
        initializeReflection();
        Tom2FARegistry.reset();

        final totp = Tom2FARegistry.availableMethods.singleWhere(
          (m) => m.type == TomTotp2FAService.mechanismType,
        );
        expect(totp.displayNameKey, 'two_factor.totp.name');
        expect(totp.descriptionKey, 'two_factor.totp.description');
        expect(totp.iconKey, 'two_factor.totp.icon');
      },
    );

    test('no descriptor carries anything that reads as user-facing text', () {
      initializeReflection();
      Tom2FARegistry.reset();

      for (final descriptor in Tom2FARegistry.availableMethods) {
        for (final key in [
          descriptor.displayNameKey,
          descriptor.descriptionKey,
          descriptor.iconKey,
        ]) {
          // A resource key is a dotted identifier under the scope. Prose
          // cannot satisfy both: it has no dots in that shape, and it has
          // spaces.
          expect(
            key,
            startsWith('${Tom2FAMethodDescriptor.resourceScope}.'),
            reason: '$key must be a key under the 2FA resource scope',
          );
          expect(
            key,
            isNot(contains(' ')),
            reason: '$key looks like literal text, not a resource key',
          );
        }
      }
    });

    test(
      'the catalog is derived from the registry, so the two cannot drift',
      () {
        Tom2FARegistry.reset();
        Tom2FARegistry.register('fake', _FakeAdaptor());
        expect(
          Tom2FARegistry.availableMethods.map((m) => m.type),
          Tom2FARegistry.registeredTypes,
        );
      },
    );

    // "What can be verified here" and "what can the user be sent off to set up"
    // are different questions. A forced-enrolment step that offered the first
    // would present an option that cannot be acted on.
    test(
      'enrollableMethods is availableMethods minus what cannot be enrolled',
      () {
        initializeReflection();
        Tom2FARegistry.reset();
        Tom2FARegistry.register('fake', _FakeAdaptor());

        expect(
          Tom2FARegistry.availableMethods.map((m) => m.type),
          containsAll(<String>['fake', TomTotp2FAService.mechanismType]),
        );
        expect(
          Tom2FARegistry.enrollableMethods.map((m) => m.type),
          contains(TomTotp2FAService.mechanismType),
        );
        expect(
          Tom2FARegistry.enrollableMethods.map((m) => m.type),
          isNot(contains('fake')),
        );
      },
    );

    test('enrolmentSupportFor resolves the enrollable and nothing else', () {
      initializeReflection();
      Tom2FARegistry.reset();
      Tom2FARegistry.register('fake', _FakeAdaptor());

      expect(
        Tom2FARegistry.enrolmentSupportFor(TomTotp2FAService.mechanismType),
        isA<TomTotp2FAService>(),
      );
      // Registered but not enrollable, and unknown entirely, answer alike: the
      // caller's action is the same, so distinguishing them would only invite a
      // branch with nothing behind it.
      expect(Tom2FARegistry.enrolmentSupportFor('fake'), isNull);
      expect(Tom2FARegistry.enrolmentSupportFor('carrier-pigeon'), isNull);
    });
  });

  // ===========================================================================
  // ENROLMENT STORE
  // ===========================================================================

  /// The per-user half of the same question the catalog answers globally: *what
  /// has **this** user set up?*
  ///
  /// Everything here runs against [TomMemory2FAEnrolmentStore]; the persistent
  /// store's own round trip (and the fact that its `secret_data` column is
  /// unreadable) needs a database and lives in
  /// `two_factor_enrolment_db_test.dart`.
  group('Tom2FAEnrolmentStore (in memory)', () {
    late TomMemory2FAEnrolmentStore store;

    setUp(() {
      TomBean.resetBeanContext();
      store = TomMemory2FAEnrolmentStore();
    });

    tearDown(TomBean.resetBeanContext);

    Tom2FAContext contextFor(int userId, {String organization = 'acme'}) =>
        Tom2FAContext(
          principal: _principalWithId(userId, organization: organization),
          organization: organization,
        );

    Tom2FAEnrolment enrolment({
      String type = 'totp',
      String id = 'device-1',
      String hint = 'iPhone',
      bool isPrimary = false,
      Map<String, Object?> secretData = const {'secret': _rfcSecretBase32},
    }) => Tom2FAEnrolment(
      type: type,
      enrolmentId: id,
      hint: hint,
      isPrimary: isPrimary,
      secretData: secretData,
    );

    test('resolve returns null when no store is installed', () {
      expect(Tom2FAEnrolmentStore.resolve(), isNull);
    });

    test('resolve finds the installed store', () {
      TomBean.withType(Tom2FAEnrolmentStore, store);
      expect(identical(Tom2FAEnrolmentStore.resolve(), store), isTrue);
    });

    test('a stored enrolment round-trips', () async {
      final context = contextFor(1);
      await store.store(context, enrolment());

      final loaded = await store.enrolmentsFor(context);
      expect(loaded, hasLength(1));
      expect(loaded.single.type, 'totp');
      expect(loaded.single.enrolmentId, 'device-1');
      expect(loaded.single.hint, 'iPhone');
      expect(loaded.single.secretData['secret'], _rfcSecretBase32);
    });

    // The whole point of a store over a single resolver hook: a user may own
    // more than one factor.
    test('a user can hold several enrolments', () async {
      final context = contextFor(1);
      await store.store(context, enrolment(id: 'phone', type: 'sms'));
      await store.store(context, enrolment(id: 'app', isPrimary: true));

      final loaded = await store.enrolmentsFor(context);
      expect(loaded.map((e) => e.enrolmentId), containsAll(['phone', 'app']));
      expect(loaded.where((e) => e.isPrimary).map((e) => e.enrolmentId), [
        'app',
      ]);
    });

    test('re-storing the same enrolment id replaces it', () async {
      final context = contextFor(1);
      await store.store(context, enrolment(hint: 'old phone'));
      await store.store(context, enrolment(hint: 'new phone'));

      final loaded = await store.enrolmentsFor(context);
      expect(loaded, hasLength(1));
      expect(loaded.single.hint, 'new phone');
    });

    test('enrolments are scoped to their principal', () async {
      await store.store(contextFor(1), enrolment());
      expect(await store.enrolmentsFor(contextFor(2)), isEmpty);
    });

    // The storage key is the principal id and nothing else, and the shipped
    // table has no tenant column to hold anything else. That is only sound
    // because a principal id names one person across the whole deployment
    // rather than within a tenant -- the premise every framework table that
    // files rows per principal already rests on. These two tests exist so the
    // premise is asserted somewhere rather than merely believed: read the
    // opposite way, they are what fails if someone gives the key a tenant.
    test('the storage key is the principal id, whatever the tenant', () {
      expect(
        Tom2FAEnrolmentStore.principalKeyOf(contextFor(7)),
        Tom2FAEnrolmentStore.principalKeyOf(
          contextFor(7, organization: 'globex'),
        ),
      );
      expect(Tom2FAEnrolmentStore.principalKeyOf(contextFor(7)), '7');
    });

    test('a user reaches their factors from every organization', () async {
      await store.store(contextFor(1), enrolment(hint: 'iPhone'));

      // Same person, second tenant: their authenticator is already enrolled,
      // so the login challenges it instead of demanding a second set-up.
      final elsewhere = await store.enrolmentsFor(
        contextFor(1, organization: 'globex'),
      );
      expect(elsewhere, hasLength(1));
      expect(elsewhere.single.hint, 'iPhone');

      // And it is one factor, not one per tenant: re-enrolling from the second
      // tenant replaces the row rather than adding a parallel one.
      await store.store(
        contextFor(1, organization: 'globex'),
        enrolment(hint: 'new iPhone'),
      );
      final home = await store.enrolmentsFor(contextFor(1));
      expect(home, hasLength(1));
      expect(home.single.hint, 'new iPhone');
    });

    test('remove drops one enrolment and tolerates an absent id', () async {
      final context = contextFor(1);
      await store.store(context, enrolment(id: 'a'));
      await store.store(context, enrolment(id: 'b'));

      await store.remove(context, 'a');
      expect((await store.enrolmentsFor(context)).map((e) => e.enrolmentId), [
        'b',
      ]);

      await expectLater(store.remove(context, 'ghost'), completes);
    });

    // "No store installed" and "installed, and this user has none" must not
    // look alike: the first means *fall back to the legacy hook*, the second
    // means *this user has genuinely enrolled nothing*.
    test('an empty store is distinguishable from no store', () async {
      expect(Tom2FAEnrolmentStore.resolve(), isNull);
      TomBean.withType(Tom2FAEnrolmentStore, store);
      expect(Tom2FAEnrolmentStore.resolve(), isNotNull);
      expect(await store.enrolmentsFor(contextFor(1)), isEmpty);
    });

    test('toString never prints the secret', () {
      final text = enrolment().toString();
      expect(text, contains('device-1'));
      expect(text, isNot(contains(_rfcSecretBase32)));
    });

    test('enrolledAt is normalised to UTC', () {
      final local = DateTime(2026, 3, 4, 5, 6);
      final stored = Tom2FAEnrolment(
        type: 'totp',
        enrolmentId: 'x',
        enrolledAt: local,
      );
      expect(stored.enrolledAt.isUtc, isTrue);
      expect(stored.enrolledAt, local.toUtc());
    });
  });

  // ===========================================================================
  // WHAT THE SCAN REFUSES
  // ===========================================================================

  /// The scan validates each annotated class the moment it finds it, rather
  /// than letting a bad adaptor become a login-time failure. What matters about
  /// each refusal is not that it throws but that it *names the class* — the
  /// scan runs at start-up with nothing else in the frame, so a message that
  /// only said "an adaptor is unusable" would leave an operator grepping.
  group('the adaptor scan', () {
    setUp(Tom2FARegistry.reset);
    tearDown(Tom2FARegistry.reset);

    /// Asserts that scanning [candidate] alone fails with [key] and a message
    /// that names the candidate.
    void expectScanFailure(_CandidateMirror candidate, String key) {
      expect(
        () => Tom2FARegistry.registerAnnotated([candidate]),
        throwsA(
          isA<Tom2FAException>()
              .having((e) => e.key, 'key', key)
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('$candidate'),
              ),
        ),
      );
    }

    test('registers a well-formed candidate', () {
      final adaptor = _FakeAdaptor();
      Tom2FARegistry.registerAnnotated([
        _CandidateMirror(
          'GoodAdaptor',
          metadata: const [Tom2FAAdaptor('carrier-pigeon')],
          instantiate: () => adaptor,
        ),
      ]);
      expect(
        identical(Tom2FARegistry.lookup('carrier-pigeon'), adaptor),
        isTrue,
      );
    });

    test('ignores a class with no @Tom2FAAdaptor annotation', () {
      // The candidate set is the whole reflected program, so most of it is not
      // an adaptor and must be walked past without being constructed — the scan
      // may not instantiate arbitrary classes to find out what they are.
      expect(
        () => Tom2FARegistry.registerAnnotated([
          _CandidateMirror(
            'OrdinaryClass',
            metadata: const [],
            instantiate: () => fail('an unannotated class must not be built'),
          ),
        ]),
        returnsNormally,
      );
    });

    test('refuses an adaptor that cannot be constructed', () {
      expectScanFailure(
        _CandidateMirror(
          'NeedsCollaboratorsAdaptor',
          metadata: const [Tom2FAAdaptor('sms')],
          instantiate: () => throw StateError('no no-argument constructor'),
        ),
        'authentication.2fa.adaptor_instantiation_failed',
      );
    });

    test('refuses an adaptor that does not implement the service', () {
      expectScanFailure(
        _CandidateMirror(
          'NotAnAdaptor',
          metadata: const [Tom2FAAdaptor('sms')],
          instantiate: Object.new,
        ),
        'authentication.2fa.adaptor_does_not_implement_service',
      );
    });

    test('the mechanism the bad adaptor claimed is named too', () {
      // Both halves of the wiring are in the message: which class, and which
      // mechanism it was going to answer for. The second is what tells an
      // operator whether the login that stopped working is this one.
      expect(
        () => Tom2FARegistry.registerAnnotated([
          _CandidateMirror(
            'NotAnAdaptor',
            metadata: const [Tom2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
        ]),
        throwsA(
          isA<Tom2FAException>().having(
            (e) => e.defaultUserMessage,
            'message',
            contains('"sms"'),
          ),
        ),
      );
    });

    // "A half-registered registry is not offered as an alternative" is the
    // registry's own dartdoc, and it has to mean the registry the caller can
    // still see afterwards -- not merely that the scan threw. The good
    // candidate here is registered before the bad one is reached, so without a
    // rollback it would outlive the failure.
    //
    // It matters because a failed scan is now retried: leftovers from the
    // first attempt would collide with the second attempt's fresh instances
    // and report a mechanism that was never the problem.
    test('a scan that fails leaves nothing of itself behind', () {
      expect(
        () => Tom2FARegistry.registerAnnotated([
          _CandidateMirror(
            'GoodAdaptor',
            metadata: const [Tom2FAAdaptor('carrier-pigeon')],
            instantiate: _FakeAdaptor.new,
          ),
          _CandidateMirror(
            'NotAnAdaptor',
            metadata: const [Tom2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
        ]),
        throwsA(isA<Tom2FAException>()),
      );
      expect(
        Tom2FARegistry.lookup('carrier-pigeon'),
        isNull,
        reason: 'the candidate registered before the failure is rolled back',
      );
    });

    // The converse, so the rollback cannot be implemented as "clear
    // everything": registrations that were already there are not the scan's to
    // undo.
    test('a scan that fails leaves earlier registrations alone', () {
      final hand = _FakeAdaptor();
      Tom2FARegistry.register('fake', hand);

      expect(
        () => Tom2FARegistry.registerAnnotated([
          _CandidateMirror(
            'NotAnAdaptor',
            metadata: const [Tom2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
        ]),
        throwsA(isA<Tom2FAException>()),
      );
      expect(identical(Tom2FARegistry.lookup('fake'), hand), isTrue);
    });

    test('the scan stops at the first unusable candidate', () {
      // Carrying on past a broken adaptor is the tempting kindness that must
      // not be offered: it would turn a start-up wiring error into a login-time
      // one for whichever mechanism the operator did not test that day.
      var reached = false;
      expect(
        () => Tom2FARegistry.registerAnnotated([
          _CandidateMirror(
            'NotAnAdaptor',
            metadata: const [Tom2FAAdaptor('sms')],
            instantiate: Object.new,
          ),
          _CandidateMirror(
            'GoodAdaptor',
            metadata: const [Tom2FAAdaptor('carrier-pigeon')],
            instantiate: () {
              reached = true;
              return _FakeAdaptor();
            },
          ),
        ]),
        throwsA(isA<Tom2FAException>()),
      );
      expect(reached, isFalse);
      expect(Tom2FARegistry.lookup('carrier-pigeon'), isNull);
    });
  });

  // ===========================================================================
  // WHAT THE SCAN SKIPS
  // ===========================================================================

  /// Refusing a *malformed* adaptor and skipping an *unusable* one are two
  /// different judgements, and the scan has to make both.
  ///
  /// A class annotated `@Tom2FAAdaptor` that cannot be constructed is wrong
  /// however the deployment is wired, so it stops the scan. An adaptor that is
  /// perfectly well-formed but needs a collaborator this deployment never
  /// installed is not wrong — a server with no mail relay is a legitimate
  /// shape — and the only useful thing to do with it is leave the mechanism out
  /// of the registry, where every offer is derived from.
  group('an adaptor with an unmet prerequisite', () {
    setUp(Tom2FARegistry.reset);
    tearDown(Tom2FARegistry.reset);

    /// A candidate for [type] that declares [unmet] as what it is missing.
    _CandidateMirror gated(String type, {String? unmet}) => _CandidateMirror(
      'GatedAdaptor',
      metadata: [Tom2FAAdaptor(type)],
      instantiate: () => _GatedAdaptor(unmetPrerequisite: unmet),
    );

    test('is left out of the registry rather than registered', () {
      Tom2FARegistry.registerAnnotated([
        gated('carrier-pigeon', unmet: 'no loft is installed'),
      ]);

      expect(Tom2FARegistry.lookup('carrier-pigeon'), isNull);
      expect(Tom2FARegistry.registeredTypes, isNot(contains('carrier-pigeon')));
    });

    test('registers as usual once nothing is missing', () {
      Tom2FARegistry.registerAnnotated([gated('carrier-pigeon')]);

      expect(Tom2FARegistry.lookup('carrier-pigeon'), isA<_GatedAdaptor>());
    });

    // Skipping and refusing must not be the same act. A missing mail relay
    // cannot be allowed to cost the deployment its TOTP, which would turn a
    // supported shape into a total 2FA outage.
    test('does not stop the scan', () {
      Tom2FARegistry.registerAnnotated([
        gated('carrier-pigeon', unmet: 'no loft is installed'),
        _CandidateMirror(
          'GoodAdaptor',
          metadata: const [Tom2FAAdaptor('fake')],
          instantiate: _FakeAdaptor.new,
        ),
      ]);

      expect(Tom2FARegistry.lookup('fake'), isA<_FakeAdaptor>());
    });

    // A mechanism that silently disappears is the hardest kind of absence to
    // debug: every lookup answers null, and null is also what a mechanism
    // nobody ever wrote answers. The line has to name both halves -- which
    // mechanism went, and what to install to get it back.
    test('says which mechanism went and what was missing', () {
      final log = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      tomLog.logOutput = log;
      addTearDown(() => tomLog.logOutput = previous);

      Tom2FARegistry.registerAnnotated([
        gated('carrier-pigeon', unmet: 'no loft is installed'),
      ]);

      final skipped = log.messages
          .where((m) => m.contains('carrier-pigeon'))
          .toList();
      expect(skipped, hasLength(1));
      expect(skipped.single, contains('no loft is installed'));
    });

    // The complaint the prerequisite answers is about *automatic* registration:
    // the shipped adaptors install themselves into deployments that never asked
    // for them. Naming one in a register() call is asking for it, and a
    // deployment that installs its collaborators after its adaptors must keep
    // that escape.
    test('is registered anyway when a deployment asks for it by hand', () {
      final adaptor = _GatedAdaptor(unmetPrerequisite: 'no loft is installed');
      Tom2FARegistry.register('carrier-pigeon', adaptor);

      expect(
        identical(Tom2FARegistry.lookup('carrier-pigeon'), adaptor),
        isTrue,
      );
    });
  });

  // The RFC vectors for the derivation itself live with the derivation, in
  // `tom_core_kernel/test/security_test.dart` (the group named `TomTotp`). What is tested
  // here is only what this adaptor adds on top: policy — the secret source, the
  // accepted skew window, the digit width, and the failure modes those produce.
  group('TomTotp2FAService adaptor', () {
    late TomTotpSecretResolver? savedResolver;
    late int savedWindow;

    setUp(() {
      // No enrolment store installed unless a test installs one — these tests
      // are about the adaptor's own policy, and the store is a separate seam.
      TomBean.resetBeanContext();
      savedResolver = TomTotp2FAService.globalSettingSecretResolver;
      savedWindow = TomTotp2FAService.globalSettingWindowSteps;
      TomTotp2FAService.globalSettingSecretResolver = (_) => _rfcSecretBase32;
    });

    tearDown(() {
      TomBean.resetBeanContext();
      TomTotp2FAService.globalSettingSecretResolver = savedResolver;
      TomTotp2FAService.globalSettingWindowSteps = savedWindow;
    });

    Tom2FAContext context() => Tom2FAContext(
      principal: _principal(
        TomAuthenticationData(
          username: 'alice',
          organization: 'acme',
          application: 'console',
          process: 'login',
          language: 'en',
          country: 'US',
          timezone: 'UTC',
          client: 'web',
        ),
      ),
    );

    Tom2FASubmission submission(String code) => Tom2FASubmission(
      submitted: code,
      challenge: Tom2FAChallenge(
        type: 'totp',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        attempt: 1,
      ),
    );

    /// The code an authenticator would show right now, [stepsOff] time steps
    /// away from the server's current step.
    ///
    /// Derived through the kernel primitive the verifier itself uses, so the
    /// test cannot drift out of agreement with what it is checking.
    String currentCode({int stepsOff = 0}) => TomTotp.generateCode(
      TomTotp.decodeBase32(_rfcSecretBase32),
      TomTotp.counterFor(period: TomTotp2FAService.globalSettingPeriod) +
          stepsOff,
      TomTotp2FAService.globalSettingDigits,
    );

    test(
      'issues a challenge describing the code shape but delivering nothing',
      () async {
        final spec = await TomTotp2FAService().issueChallenge(context());
        expect(spec.hint, isEmpty);
        expect(
          spec.clientData['digits'],
          TomTotp2FAService.globalSettingDigits,
        );
        expect(
          spec.clientData['periodSeconds'],
          TomTotp2FAService.globalSettingPeriod.inSeconds,
        );
        // Nothing secret travels: the secret is re-resolved on pass 2.
        expect(spec.verificationData, isEmpty);
      },
    );

    test('fails the login when no authenticator is enrolled', () async {
      TomTotp2FAService.globalSettingSecretResolver = (_) => null;
      await expectLater(
        TomTotp2FAService().issueChallenge(context()),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.not-enrolled',
          ),
        ),
      );
    });

    test('accepts the current code', () async {
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode()),
        ),
        isTrue,
      );
    });

    // ------------------------------------------------------------------
    // Where the secret comes from
    // ------------------------------------------------------------------

    /// Installs an enrolment store holding [secret] for the test's principal.
    Future<void> installStoreWith(
      String? secret, {
      String type = 'totp',
    }) async {
      final store = TomMemory2FAEnrolmentStore();
      if (secret != null) {
        await store.store(
          context(),
          Tom2FAEnrolment(
            type: type,
            enrolmentId: 'device-1',
            secretData: {TomTotp2FAService.secretDataKey: secret},
          ),
        );
      }
      TomBean.withType(Tom2FAEnrolmentStore, store);
    }

    // The store is the source of truth once installed; a stale resolver left
    // over from before the migration must not keep answering.
    test('prefers the enrolment store over the legacy resolver', () async {
      TomTotp2FAService.globalSettingSecretResolver = (_) =>
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      await installStoreWith(_rfcSecretBase32);

      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode()),
        ),
        isTrue,
      );
    });

    // Migrating one user at a time: a store that holds nothing for *this* user
    // is not an answer, so the hook still gets asked.
    test(
      'falls back to the resolver when the store holds no TOTP enrolment',
      () async {
        await installStoreWith(_rfcSecretBase32, type: 'sms');
        expect(
          await TomTotp2FAService().verifySubmission(
            context(),
            submission(currentCode()),
          ),
          isTrue,
        );
      },
    );

    test('with a store but no enrolment and no resolver, the login fails as '
        'not-enrolled', () async {
      TomTotp2FAService.globalSettingSecretResolver = null;
      await installStoreWith(null);
      await expectLater(
        TomTotp2FAService().issueChallenge(context()),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.not-enrolled',
          ),
        ),
      );
    });

    // One malformed row must not lock out a user who also holds a good one.
    test('skips a malformed enrolment and uses the next usable one', () async {
      TomTotp2FAService.globalSettingSecretResolver = null;
      final store = TomMemory2FAEnrolmentStore();
      await store.store(
        context(),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'broken',
          secretData: const {TomTotp2FAService.secretDataKey: ''},
        ),
      );
      await store.store(
        context(),
        Tom2FAEnrolment(
          type: 'totp',
          enrolmentId: 'good',
          secretData: const {TomTotp2FAService.secretDataKey: _rfcSecretBase32},
        ),
      );
      TomBean.withType(Tom2FAEnrolmentStore, store);

      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode()),
        ),
        isTrue,
      );
    });

    test('describes itself with resource keys under two_factor.totp', () {
      final descriptor = TomTotp2FAService().descriptor;
      expect(descriptor.type, 'totp');
      expect(descriptor.displayNameKey, 'two_factor.totp.name');
      expect(descriptor.descriptionKey, 'two_factor.totp.description');
      expect(descriptor.iconKey, 'two_factor.totp.icon');
    });

    test('rejects a wrong code', () async {
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission('000000'),
        ),
        isFalse,
      );
    });

    test(
      'rejects a code of the wrong length without hashing anything',
      () async {
        expect(
          await TomTotp2FAService().verifySubmission(
            context(),
            submission('12'),
          ),
          isFalse,
        );
      },
    );

    test('tolerates one time step of clock skew either way', () async {
      TomTotp2FAService.globalSettingWindowSteps = 1;
      final adaptor = TomTotp2FAService();
      expect(
        await adaptor.verifySubmission(
          context(),
          submission(currentCode(stepsOff: -1)),
        ),
        isTrue,
      );
      expect(
        await adaptor.verifySubmission(
          context(),
          submission(currentCode(stepsOff: 1)),
        ),
        isTrue,
      );
    });

    test('rejects a code from outside the accepted window', () async {
      TomTotp2FAService.globalSettingWindowSteps = 1;
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode(stepsOff: 5)),
        ),
        isFalse,
      );
    });

    test('rejects everything when the deployment wired no resolver', () async {
      TomTotp2FAService.globalSettingSecretResolver = null;
      expect(
        await TomTotp2FAService().verifySubmission(
          context(),
          submission(currentCode()),
        ),
        isFalse,
      );
    });
  });

  // ===========================================================================
  // ENROLMENT
  // ===========================================================================

  /// Setting an authenticator up, as opposed to answering one.
  ///
  /// The property these tests exist for is the one that cannot be recovered
  /// afterwards: **no unconfirmed secret is ever handed back for storage**. A
  /// QR scan that silently failed, followed by a stored secret, is an account
  /// its owner can no longer reach — so `confirmEnrolment` returning at all has
  /// to mean the user demonstrably holds the secret.
  group('TomTotp2FAService enrolment', () {
    late String savedIssuer;
    late int savedSecretBytes;
    late int savedWindow;

    setUp(() {
      TomBean.resetBeanContext();
      savedIssuer = TomTotp2FAService.globalSettingIssuer;
      savedSecretBytes = TomTotp2FAService.globalSettingSecretBytes;
      savedWindow = TomTotp2FAService.globalSettingWindowSteps;
    });

    tearDown(() {
      TomBean.resetBeanContext();
      TomTotp2FAService.globalSettingIssuer = savedIssuer;
      TomTotp2FAService.globalSettingSecretBytes = savedSecretBytes;
      TomTotp2FAService.globalSettingWindowSteps = savedWindow;
    });

    Tom2FAContext context() =>
        Tom2FAContext(principal: _principalWithId(7), application: 'console');

    /// The base32 secret the offer is asking the user to install.
    String offeredSecret(Tom2FAEnrolmentOffer offer) =>
        offer.enrolmentData[TomTotp2FAService.secretDataKey] as String;

    // ------------------------------------------------------------------
    // The round trip
    // ------------------------------------------------------------------

    test(
      'a generated secret round-trips base32 and its code confirms',
      () async {
        final adaptor = TomTotp2FAService();
        final offer = await adaptor.beginEnrolment(context());
        final secret = offeredSecret(offer);

        // Decodable, and back to exactly the bytes the policy asked for — a
        // secret the authenticator cannot decode is a lockout the server would
        // only discover at the next login.
        final key = TomTotp.decodeBase32(secret);
        expect(key, hasLength(TomTotp2FAService.globalSettingSecretBytes));
        expect(TomTotp.encodeBase32(key), secret);

        final enrolment = await adaptor.confirmEnrolment(
          context(),
          offer,
          TomTotp2FAService.expectedCode(secret),
        );

        expect(enrolment.type, TomTotp2FAService.mechanismType);
        expect(enrolment.secretData[TomTotp2FAService.secretDataKey], secret);
        expect(enrolment.enrolmentId, isNotEmpty);
      },
    );

    // The confirmed secret must be the one the *verifier* will later resolve,
    // not merely one that agrees with itself.
    test(
      'the confirmed enrolment answers a real challenge afterwards',
      () async {
        final adaptor = TomTotp2FAService();
        final offer = await adaptor.beginEnrolment(context());
        final secret = offeredSecret(offer);

        final enrolment = await adaptor.confirmEnrolment(
          context(),
          offer,
          TomTotp2FAService.expectedCode(secret),
        );

        final store = TomMemory2FAEnrolmentStore();
        await store.store(context(), enrolment);
        TomBean.withType(Tom2FAEnrolmentStore, store);

        expect(
          await adaptor.verifySubmission(
            context(),
            Tom2FASubmission(
              submitted: TomTotp2FAService.expectedCode(secret),
              challenge: Tom2FAChallenge(
                type: TomTotp2FAService.mechanismType,
                expiresAt: DateTime.now().toUtc().add(
                  const Duration(minutes: 5),
                ),
              ),
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'confirmation tolerates the same clock skew the verifier does',
      () async {
        TomTotp2FAService.globalSettingWindowSteps = 1;
        final adaptor = TomTotp2FAService();
        final offer = await adaptor.beginEnrolment(context());
        final secret = offeredSecret(offer);

        // The code the user's slightly-behind phone is still showing.
        final onePeriodAgo = DateTime.now().subtract(
          TomTotp2FAService.globalSettingPeriod,
        );
        await expectLater(
          adaptor.confirmEnrolment(
            context(),
            offer,
            TomTotp2FAService.expectedCode(secret, at: onePeriodAgo),
          ),
          completes,
        );
      },
    );

    // ------------------------------------------------------------------
    // Nothing unconfirmed is ever stored
    // ------------------------------------------------------------------

    test('a wrong code is refused and leaves nothing stored', () async {
      final store = TomMemory2FAEnrolmentStore();
      TomBean.withType(Tom2FAEnrolmentStore, store);

      final adaptor = TomTotp2FAService();
      final offer = await adaptor.beginEnrolment(context());

      await expectLater(
        adaptor.confirmEnrolment(context(), offer, '000000'),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.enrolment-code-invalid',
          ),
        ),
      );

      // Not merely "not stored by the failure" — nothing at all reached the
      // store, because beginEnrolment writes nothing either.
      expect(await store.enrolmentsFor(context()), isEmpty);
    });

    test('an offer with no server-side secret cannot be confirmed', () async {
      await expectLater(
        TomTotp2FAService().confirmEnrolment(
          context(),
          const Tom2FAEnrolmentOffer(type: TomTotp2FAService.mechanismType),
          '000000',
        ),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.enrolment-offer-invalid',
          ),
        ),
      );
    });

    // The security invariant of the two-map split: clientData travels in public
    // claims, so a confirmation that derived its expected code from there could
    // be told which secret to accept.
    test(
      'confirmation derives the code from enrolmentData, never clientData',
      () async {
        final adaptor = TomTotp2FAService();
        final genuine = await adaptor.beginEnrolment(context());
        const attackerSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

        final tampered = Tom2FAEnrolmentOffer(
          type: genuine.type,
          clientData: {
            ...genuine.clientData,
            TomTotp2FAService.secretDataKey: attackerSecret,
          },
          enrolmentData: genuine.enrolmentData,
        );

        await expectLater(
          adaptor.confirmEnrolment(
            context(),
            tampered,
            TomTotp2FAService.expectedCode(attackerSecret),
          ),
          throwsA(isA<TomLoginException>()),
        );

        final enrolment = await adaptor.confirmEnrolment(
          context(),
          tampered,
          TomTotp2FAService.expectedCode(offeredSecret(genuine)),
        );
        expect(
          enrolment.secretData[TomTotp2FAService.secretDataKey],
          offeredSecret(genuine),
        );
      },
    );

    // ------------------------------------------------------------------
    // The secret itself
    // ------------------------------------------------------------------

    test('two enrolments never offer the same secret', () async {
      final adaptor = TomTotp2FAService();
      final secrets = <String>{};
      // More than two: a generator seeded once per process would agree with
      // itself on the first pair and only diverge later, which a two-sample
      // test would call a pass.
      for (var i = 0; i < 8; i++) {
        secrets.add(offeredSecret(await adaptor.beginEnrolment(context())));
      }
      expect(secrets, hasLength(8));
    });

    test('the secret width follows the setting', () async {
      TomTotp2FAService.globalSettingSecretBytes = 32;
      final offer = await TomTotp2FAService().beginEnrolment(context());
      expect(TomTotp.decodeBase32(offeredSecret(offer)), hasLength(32));
    });

    // ------------------------------------------------------------------
    // The provisioning URI
    // ------------------------------------------------------------------

    test(
      "the otpauth URI parses and carries this verifier's own policy",
      () async {
        TomTotp2FAService.globalSettingIssuer = 'Acme Corp';
        final offer = await TomTotp2FAService().beginEnrolment(context());
        final uri = Uri.parse(
          offer.clientData[TomTotp2FAService.clientDataUriKey] as String,
        );

        expect(uri.scheme, 'otpauth');
        expect(uri.host, 'totp');
        // The label is `issuer:account`, both percent-decoded by Uri.
        expect(uri.pathSegments.single, 'Acme Corp:user7');

        expect(uri.queryParameters['secret'], offeredSecret(offer));
        expect(uri.queryParameters['issuer'], 'Acme Corp');
        // Stated, not left to the app's default: the derivation is HMAC-SHA1.
        expect(uri.queryParameters['algorithm'], 'SHA1');
        expect(
          uri.queryParameters['digits'],
          '${TomTotp2FAService.globalSettingDigits}',
        );
        expect(
          uri.queryParameters['period'],
          '${TomTotp2FAService.globalSettingPeriod.inSeconds}',
        );
      },
    );

    // A hardcoded issuer would put one word in every deployment's
    // authenticator; the deployment already has a name for itself.
    test('the issuer defaults to the application being logged into', () async {
      TomTotp2FAService.globalSettingIssuer = '';
      final offer = await TomTotp2FAService().beginEnrolment(context());
      final uri = Uri.parse(
        offer.clientData[TomTotp2FAService.clientDataUriKey] as String,
      );
      expect(uri.queryParameters['issuer'], 'console');
      expect(uri.pathSegments.single, 'console:user7');
    });

    test('the client data carries the code shape a UI must render', () async {
      final offer = await TomTotp2FAService().beginEnrolment(context());
      expect(offer.clientData['digits'], TomTotp2FAService.globalSettingDigits);
      expect(
        offer.clientData['periodSeconds'],
        TomTotp2FAService.globalSettingPeriod.inSeconds,
      );
      expect(offer.attemptsAllowed, greaterThan(0));
      expect(offer.validity, greaterThan(Duration.zero));
    });

    // ------------------------------------------------------------------
    // Carrying the offer between the two calls
    // ------------------------------------------------------------------

    test('an offer survives the claim round trip and still confirms', () async {
      final adaptor = TomTotp2FAService();
      final offer = await adaptor.beginEnrolment(context());

      // Exactly what the interim token does to it: a JSON-safe map out, a
      // decoded map back — possibly on another instance.
      final carried = Tom2FAEnrolmentOffer.fromClaim(
        jsonDecode(jsonEncode(offer.toClaim())),
      );

      expect(carried, isNotNull);
      expect(carried!.type, offer.type);
      expect(carried.attemptsAllowed, offer.attemptsAllowed);
      expect(carried.validity, offer.validity);

      final enrolment = await adaptor.confirmEnrolment(
        context(),
        carried,
        TomTotp2FAService.expectedCode(offeredSecret(offer)),
      );
      expect(
        enrolment.secretData[TomTotp2FAService.secretDataKey],
        offeredSecret(offer),
      );
    });

    test('a malformed claim yields no offer rather than a broken one', () {
      expect(Tom2FAEnrolmentOffer.fromClaim(null), isNull);
      expect(Tom2FAEnrolmentOffer.fromClaim('nonsense'), isNull);
      expect(Tom2FAEnrolmentOffer.fromClaim(const {}), isNull);
      expect(Tom2FAEnrolmentOffer.fromClaim(const {'type': ''}), isNull);
    });

    // This value reaches log lines; a helpful toString would put a live
    // credential in the log the first time anyone debugged an enrolment.
    test('the offer never prints the secret it carries', () async {
      final offer = await TomTotp2FAService().beginEnrolment(context());
      expect(offer.toString(), isNot(contains(offeredSecret(offer))));
    });
  });

  // ===========================================================================
  // POLICY
  // ===========================================================================

  /// Whether a login owes a second factor is a [Tom2FAPolicy] decision, taken
  /// before any mechanism is consulted. What these tests pin is that the
  /// decision is *the* input to the branch — the shipped default reproduces the
  /// principal's own flags exactly (so introducing the policy changed nothing),
  /// and an installed policy overrides them (so the flags are no longer what
  /// decides).
  group('Tom2FAPolicy', () {
    tearDown(() {
      Tom2FARegistry.reset();
      // The bean context is process-global; a policy left installed here would
      // decide the next test's logins.
      TomBean.resetBeanContext();
    });

    /// The context a policy is handed, for a principal with these flags/roles.
    Tom2FAContext contextFor({
      bool requires2FA = false,
      String? twoFactorType,
      List<String> roles = const [],
    }) => Tom2FAContext(
      principal: _principal(
        TomAuthenticationData(
          username: 'alice',
          organization: 'acme',
          application: 'console',
          process: 'login',
          language: 'en',
          country: 'US',
          timezone: 'UTC',
          client: 'web',
        ),
        requires2FA: requires2FA,
        twoFactorType: twoFactorType,
        roles: roles,
      ),
    );

    // -------------------------------------------------------------------------
    // Grace is a budget, and something has to count it
    // -------------------------------------------------------------------------

    group('grace logins are counted, not re-granted', () {
      // `graceLogins: 3` read as "three more, always": the policy re-read its
      // configured allowance on every login and nothing held a running total,
      // so a countdown never counted down and the user was never enrolled. The
      // failure was silent and permissive, which is the worst pair.
      setUp(TomMemory2FAGraceStore.shared.clear);
      tearDown(TomMemory2FAGraceStore.shared.clear);

      Tom2FAContext contextForId(int userId) =>
          Tom2FAContext(principal: _principalWithId(userId));

      test('the default policy grants none, twice running', () async {
        // The behaviour the todo asks to see asserted: two consecutive logins
        // through the shipped default. It grants no grace at all, so there is
        // nothing to count and nothing that could drift.
        const policy = TomPrincipalFlag2FAPolicy();

        final first = await policy.decideFor(
          contextFor(requires2FA: true, twoFactorType: 'totp'),
        );
        final second = await policy.decideFor(
          contextFor(requires2FA: true, twoFactorType: 'totp'),
        );

        expect(first.graceLogins, isZero);
        expect(second.graceLogins, isZero);
        expect(policy, isNot(isA<Tom2FAGraceAccounting>()));
      });

      test('the role policy counts its budget down', () async {
        final policy = TomRole2FAPolicy(
          requirementByRole: const {'admin': Tom2FARequirement.required},
          mechanisms: const ['totp'],
          graceLogins: 3,
        );
        final context = contextForId(42);

        expect((await policy.decideFor(context)).graceLogins, 3);
        await policy.recordGraceLoginConsumed(context);
        expect((await policy.decideFor(context)).graceLogins, 2);
        await policy.recordGraceLoginConsumed(context);
        expect((await policy.decideFor(context)).graceLogins, 1);
        await policy.recordGraceLoginConsumed(context);
        expect(
          (await policy.decideFor(context)).graceLogins,
          isZero,
          reason:
              'the fourth login is the one the budget was for — the offer '
              'stops being declinable here or the number meant nothing',
        );
      });

      test('a spent budget does not go negative', () async {
        final policy = TomRole2FAPolicy(graceLogins: 1);
        final context = contextForId(42);

        await policy.recordGraceLoginConsumed(context);
        await policy.recordGraceLoginConsumed(context);

        expect((await policy.decideFor(context)).graceLogins, isZero);
      });

      test('one principal spending does not charge another', () async {
        final policy = TomRole2FAPolicy(graceLogins: 2);

        await policy.recordGraceLoginConsumed(contextForId(1));

        expect((await policy.decideFor(contextForId(1))).graceLogins, 1);
        expect((await policy.decideFor(contextForId(2))).graceLogins, 2);
      });

      test('the server can find the accounting on the role policy', () async {
        // The login path asks `is Tom2FAGraceAccounting` before spending, so a
        // policy that counts but does not declare it is a policy nothing tells.
        expect(TomRole2FAPolicy(graceLogins: 1), isA<Tom2FAGraceAccounting>());
      });

      test('a policy granting no grace never reads the store', () async {
        // Zero is always zero, and a store read per login to learn it is a
        // round trip a deployment that configured no grace did not ask for.
        final counting = _CountingGraceStore();
        TomBean.withType(Tom2FAGraceStore, counting);

        await TomRole2FAPolicy().decideFor(contextForId(42));

        expect(counting.reads, isZero);
      });

      test('an installed store replaces the process-wide default', () async {
        final store = _CountingGraceStore(consumed: 1);
        TomBean.withType(Tom2FAGraceStore, store);

        final decision = await TomRole2FAPolicy(
          graceLogins: 3,
        ).decideFor(contextForId(42));

        expect(decision.graceLogins, 2);
        expect(store.reads, 1);
      });

      test('the memory store keys on the principal', () async {
        final store = TomMemory2FAGraceStore();

        await store.recordConsumed(contextForId(7));
        await store.recordConsumed(contextForId(7));

        expect(await store.consumedBy(contextForId(7)), 2);
        expect(await store.consumedBy(contextForId(8)), isZero);
        expect(store.size, 1);
      });
    });

    // -------------------------------------------------------------------------
    // The default, which must be today's behaviour and nothing else
    // -------------------------------------------------------------------------

    test('the flag policy reads an exempt principal as disabled', () async {
      final decision = await const TomPrincipalFlag2FAPolicy().decideFor(
        contextFor(),
      );

      expect(decision.requirement, Tom2FARequirement.disabled);
      expect(decision.isSatisfiedWithoutFactor, isTrue);
      expect(decision.allowedMechanisms, isEmpty);
    });

    test('the flag policy reproduces requires2FA and twoFactorType', () async {
      final decision = await const TomPrincipalFlag2FAPolicy().decideFor(
        contextFor(requires2FA: true, twoFactorType: 'totp'),
      );

      expect(decision.requirement, Tom2FARequirement.required);
      expect(decision.allowedMechanisms, ['totp']);
    });

    // The dead end the flags cannot express: required, but naming nothing. The
    // policy must not invent a mechanism — it reports the requirement with no
    // way to satisfy it, and the login is what turns that into a clear refusal.
    test(
      'a principal that requires a factor but names none allows nothing',
      () async {
        final decision = await const TomPrincipalFlag2FAPolicy().decideFor(
          contextFor(requires2FA: true),
        );

        expect(decision.requirement, Tom2FARequirement.required);
        expect(decision.allowedMechanisms, isEmpty);
      },
    );

    test('resolve falls back to the flag policy when no bean is installed', () {
      expect(Tom2FAPolicy.resolve(), isA<TomPrincipalFlag2FAPolicy>());
    });

    test('resolve returns the installed bean', () {
      final installed = TomRole2FAPolicy();
      TomBean.withType(Tom2FAPolicy, installed);

      expect(identical(Tom2FAPolicy.resolve(), installed), isTrue);
    });

    // -------------------------------------------------------------------------
    // Roles
    // -------------------------------------------------------------------------

    test('the role policy applies the default when no role matches', () async {
      final policy = TomRole2FAPolicy(
        requirementByRole: {'admin': Tom2FARequirement.required},
        defaultRequirement: Tom2FARequirement.optional,
        mechanisms: ['fake'],
      );

      final decision = await policy.decideFor(contextFor(roles: ['viewer']));
      expect(decision.requirement, Tom2FARequirement.optional);
    });

    // The whole reason the requirement is an ordered enum: a principal holding
    // two roles with different answers gets the stricter one, never the laxer.
    test('two roles with different requirements yield the stricter', () async {
      final policy = TomRole2FAPolicy(
        requirementByRole: {
          'staff': Tom2FARequirement.optional,
          'admin': Tom2FARequirement.required,
        },
        mechanisms: ['fake'],
      );

      // Both orders, because "strictest" must not depend on which role the ACI
      // happens to list first.
      expect(
        (await policy.decideFor(
          contextFor(roles: ['staff', 'admin']),
        )).requirement,
        Tom2FARequirement.required,
      );
      expect(
        (await policy.decideFor(
          contextFor(roles: ['admin', 'staff']),
        )).requirement,
        Tom2FARequirement.required,
      );
    });

    test('a role that disables loses to a role that requires', () async {
      final policy = TomRole2FAPolicy(
        requirementByRole: {
          'service-account': Tom2FARequirement.disabled,
          'admin': Tom2FARequirement.required,
        },
        mechanisms: ['fake'],
      );

      final decision = await policy.decideFor(
        contextFor(roles: ['service-account', 'admin']),
      );
      expect(decision.requirement, Tom2FARequirement.required);
    });

    test('a null mechanism list means every registered mechanism', () async {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      final policy = TomRole2FAPolicy(
        defaultRequirement: Tom2FARequirement.required,
      );

      final decision = await policy.decideFor(contextFor());
      expect(decision.allowedMechanisms, contains('fake'));
    });

    test('the grace count is carried onto every decision', () async {
      final policy = TomRole2FAPolicy(
        defaultRequirement: Tom2FARequirement.required,
        mechanisms: ['fake'],
        graceLogins: 3,
      );

      expect((await policy.decideFor(contextFor())).graceLogins, 3);
    });

    // -------------------------------------------------------------------------
    // Permitted vs. installed
    // -------------------------------------------------------------------------

    /// A policy names *permissions*. Whether a permitted mechanism can actually
    /// be used is a separate question, and answering it at the decision rather
    /// than at the adaptor lookup is what makes the failure legible: an empty
    /// [Tom2FADecision.offerableMechanisms] beside a non-empty
    /// `allowedMechanisms` says "this deployment installed none of them", which
    /// a null lookup ten frames later cannot say.
    /// The "permitted but not installed" mechanisms below are `push` and
    /// `carrier-pigeon`, deliberately — **not** `totp`.
    ///
    /// The registry's automatic scan walks the whole reflected program, and this
    /// suite reflects the server barrel, which ships `@Tom2FAAdaptor`-annotated
    /// adaptors for `totp`, `sms` and `email`. TOTP needs nothing but itself, so
    /// it is genuinely installed here and naming it as the uninstallable
    /// mechanism would assert the opposite of what the framework does. `sms` and
    /// `email` are absent for a different reason — see the delivery-service test
    /// below — and are no better as stand-ins, because they would then be
    /// testing the prerequisite rather than the intersection.
    test(
      'offerable mechanisms are the permitted ones that are registered',
      () async {
        Tom2FARegistry.register('fake', _FakeAdaptor());
        final policy = TomRole2FAPolicy(
          defaultRequirement: Tom2FARequirement.required,
          mechanisms: ['carrier-pigeon', 'fake', 'push'],
        );

        final decision = await policy.decideFor(contextFor());
        expect(decision.allowedMechanisms, ['carrier-pigeon', 'fake', 'push']);
        expect(decision.offerableMechanisms, ['fake']);
      },
    );

    test(
      'a policy naming only unregistered mechanisms offers nothing',
      () async {
        Tom2FARegistry.register('fake', _FakeAdaptor());
        final policy = TomRole2FAPolicy(
          defaultRequirement: Tom2FARequirement.required,
          mechanisms: ['push'],
        );

        final decision = await policy.decideFor(contextFor());
        expect(decision.allowedMechanisms, ['push'], reason: 'still permitted');
        expect(decision.offerableMechanisms, isEmpty, reason: 'but unusable');
      },
    );

    // "Installed" is more than "registered". The mail adaptor ships annotated,
    // so the scan finds it in every reflected program -- including one that
    // never installed a TomEmailService, where it can be looked up and cannot
    // send anything.
    //
    // Offered anyway, that is the exact failure the intersection exists to
    // prevent, only later: the login accepts the mechanism, issues the
    // challenge, and the adaptor then raises a Tom2FAException, which is not
    // client-throwable -- so the user is shown an opaque failure halfway
    // through signing in rather than a list that never held the impossible
    // option.
    test(
      'a mechanism whose delivery service is absent is not offered',
      () async {
        initializeReflection();
        // The premise: no TomEmailService bean, which is what the shipped mail
        // adaptor resolves at every send.
        TomBean.resetBeanContext();
        Tom2FARegistry.reset();
        Tom2FARegistry.register('fake', _FakeAdaptor());

        final policy = TomRole2FAPolicy(
          defaultRequirement: Tom2FARequirement.required,
          mechanisms: [TomEmailCode2FAService.mechanismType, 'fake'],
        );
        final decision = await policy.decideFor(contextFor());

        expect(
          decision.allowedMechanisms,
          [TomEmailCode2FAService.mechanismType, 'fake'],
          reason:
              'the policy permits it either way -- permission is not ability',
        );
        expect(decision.offerableMechanisms, ['fake']);
      },
    );

    // The same premise reached the other way round: `mechanisms: null` means
    // "everything registered", which is the wording that put the impossible
    // option in front of a user without anybody naming it.
    test('and a policy that names nothing does not pick it up', () async {
      initializeReflection();
      TomBean.resetBeanContext();
      Tom2FARegistry.reset();

      final decision = await TomRole2FAPolicy(
        defaultRequirement: Tom2FARequirement.required,
      ).decideFor(contextFor());

      expect(
        decision.allowedMechanisms,
        contains(TomTotp2FAService.mechanismType),
        reason: 'a mechanism that needs nothing is still picked up',
      );
      expect(
        decision.allowedMechanisms,
        isNot(contains(TomEmailCode2FAService.mechanismType)),
      );
      expect(
        decision.allowedMechanisms,
        isNot(contains(TomSmsCode2FAService.mechanismType)),
      );
    });

    test('a decision cannot be edited after the policy made it', () async {
      final decision = await const TomPrincipalFlag2FAPolicy().decideFor(
        contextFor(requires2FA: true, twoFactorType: 'totp'),
      );

      expect(
        () => decision.allowedMechanisms.add('sms'),
        throwsUnsupportedError,
      );
    });
  });

  // The two-pass flow end to end. These tests mutate global service settings, so
  // setUp/tearDown snapshot and restore them to keep the suite order-independent.
  group('TomAuthenticationServer two-pass flow', () {
    late TomAuthenticationService savedUserService;
    late bool savedProtectionDefault;
    late _FakeAdaptor adaptor;
    final server = TomAuthenticationServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      // Deterministic token payloads: no resource-key redaction of public claims.
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      adaptor = _FakeAdaptor();
      Tom2FARegistry.reset();
      Tom2FARegistry.register('fake', adaptor);
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true, twoFactorType: 'fake');
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
      Tom2FARegistry.reset();
      // A policy installed by one test must not decide the next one's logins.
      TomBean.resetBeanContext();
    });

    /// Runs pass 1 and returns the interim token the client would present back.
    Future<TomClientJwtToken> issuedChallenge() async {
      final pass1 = await server.authenticatePass1(_message());
      expect(pass1.error, isEmpty, reason: 'pass 1 should not fail');
      return TomClientJwtToken(pass1.authorizationToken);
    }

    test('pass 1 answers with a challenge instead of a session', () async {
      final pass1 = await server.authenticatePass1(_message());

      expect(pass1.error, isEmpty);
      expect(pass1.requires2FA, isTrue);
      expect(pass1.twoFactorType, 'fake');
      expect(adaptor.issued, 1);

      final token = TomClientJwtToken(pass1.authorizationToken);
      final challenge = Tom2FAChallenge.fromClaims(token.payload);
      expect(challenge, isNotNull);
      expect(challenge!.type, 'fake');
      expect(challenge.hint, '***-**-4711');
      expect(challenge.attempt, 0);
      expect(challenge.attemptsAllowed, 3);
      expect(challenge.clientData['shape'], 'digits-6');
      expect(challenge.isExpired(), isFalse);
    });

    // The interim token carries the real access-control payload, so what stops
    // it from being a usable session is the derived principal — asserted here
    // because every access check in the framework goes through this one flag.
    test('the interim token does not authenticate its bearer', () {
      // Guard the whole assertion in one place: authenticated must be false
      // even though the username is a real one and the roles are present.
      return issuedChallenge().then((token) {
        final principal =
            TomBearerAuthentication.convertTokenPayloadToPrincipal(token);
        expect(principal.username, 'alice');
        expect(principal.aci.roles, contains('admin'));
        expect(principal.requires2FA, isTrue);
        expect(principal.twoFactorType, 'fake');
        expect(principal.authenticated, isFalse);
      });
    });

    test('the verification blob is server-only', () async {
      final pass1 = await server.authenticatePass1(_message());

      // Present in the encrypted section...
      final decrypted = TomClientJwtToken(pass1.authorizationToken);
      expect(
        decrypted.secretData?[Tom2FAClaims.verificationData],
        containsPair('nonce', 'n-1'),
      );
      // ...and nowhere in the claims a client can read without the private key.
      final public = TomClientJwtToken(
        pass1.authorizationToken,
        decrypt: false,
      );
      expect(public.payload, isNot(contains(Tom2FAClaims.verificationData)));
    });

    test(
      'pass 2 hands the adaptor the challenge and its own blob back',
      () async {
        final token = await issuedChallenge();
        await server.authenticatePass2(
          _message(password: '424242'),
          challengeToken: token,
        );

        expect(adaptor.verified, 1);
        expect(adaptor.lastSubmission!.submitted, '424242');
        // Already counted, so an adaptor sees the state its answer produces.
        expect(adaptor.lastSubmission!.challenge.attempt, 1);
        expect(
          adaptor.lastSubmission!.verificationData,
          containsPair('nonce', 'n-1'),
        );
        expect(adaptor.lastVerifyContext!.principal.username, 'alice');
        expect(adaptor.lastVerifyContext!.organization, 'acme');
      },
    );

    test('a correct answer completes the login', () async {
      final token = await issuedChallenge();
      final pass2 = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );

      expect(pass2.error, isEmpty);
      expect(pass2.requires2FA, isFalse);
      expect(pass2.authenticationToken, isNotEmpty);

      final completed = TomClientJwtToken(pass2.authorizationToken);
      expect(completed.payload?[Tom2FAClaims.requires2FA], 'false');
      expect(completed.payload?[Tom2FAClaims.type], isNull);
      expect(Tom2FAChallenge.fromClaims(completed.payload), isNull);
      // The completed token carries no verification payload at all, so a
      // mechanism secret cannot outlive the challenge it was minted for.
      expect(
        completed.secretData,
        isNot(contains(Tom2FAClaims.verificationData)),
      );
      // The access-control payload survives both passes.
      expect(completed.secretData!['roles'], contains('admin'));

      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        completed,
      );
      expect(principal.authenticated, isTrue);
      expect(principal.requires2FA, isFalse);
    });

    // The todo's actual acceptance criterion: after the second factor, the
    // client holds exactly the token a pass1-only login would have given it.
    test(
      'the completed token is the one a 2FA-free login would have issued',
      () async {
        final token = await issuedChallenge();
        final pass2 = await server.authenticatePass2(
          _message(password: '424242'),
          challengeToken: token,
        );

        TomAuthenticationServer.globalSettingUserAuthenticationService =
            _StubAuthService();
        final control = await server.authenticatePass1(_message());

        expect(
          _identityClaims(pass2.authorizationToken),
          _identityClaims(control.authorizationToken),
        );
      },
    );

    test(
      'a wrong answer is retryable and spends exactly one attempt',
      () async {
        final token = await issuedChallenge();
        final retry = await server.authenticatePass2(
          _message(password: 'wrong'),
          challengeToken: token,
        );

        expect(retry.error, 'login.error.2fa.invalid-code');
        expect(retry.requires2FA, isTrue);
        expect(retry.authorizationToken, isNotEmpty);

        final reissued = TomClientJwtToken(retry.authorizationToken);
        final challenge = Tom2FAChallenge.fromClaims(reissued.payload);
        expect(challenge!.attempt, 1);
        expect(challenge.attemptsRemaining, 2);
        // Re-issued with its blob intact, so the next attempt is answerable.
        expect(
          reissued.secretData?[Tom2FAClaims.verificationData],
          containsPair('nonce', 'n-1'),
        );

        // And the retry token completes the login normally.
        final pass2 = await server.authenticatePass2(
          _message(password: '424242'),
          challengeToken: reissued,
        );
        expect(pass2.error, isEmpty);
      },
    );

    test(
      'the attempt counter cannot be rewound within one challenge',
      () async {
        var token = await issuedChallenge();
        for (var attempt = 1; attempt <= 2; attempt++) {
          final retry = await server.authenticatePass2(
            _message(password: 'wrong'),
            challengeToken: token,
          );
          expect(retry.error, 'login.error.2fa.invalid-code');
          token = TomClientJwtToken(retry.authorizationToken);
          expect(Tom2FAChallenge.fromClaims(token.payload)!.attempt, attempt);
        }

        // Third and last allowed attempt: wrong again burns the challenge.
        final burned = await server.authenticatePass2(
          _message(password: 'wrong'),
          challengeToken: token,
        );
        expect(burned.error, 'login.error.2fa.attempts-exhausted');
        expect(burned.authorizationToken, isEmpty);
        expect(adaptor.verified, 3);
      },
    );

    test(
      'an exhausted challenge is refused without consulting the adaptor',
      () async {
        final exhausted = Tom2FAChallenge(
          type: 'fake',
          attempt: 3,
          attemptsAllowed: 3,
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
        final result = await server.authenticatePass2(
          _message(password: '424242'),
          challengeToken: _tokenCarrying(exhausted),
        );

        expect(result.error, 'login.error.2fa.attempts-exhausted');
        expect(adaptor.verified, 0);
      },
    );

    test(
      'a lapsed challenge is refused without consulting the adaptor',
      () async {
        final lapsed = Tom2FAChallenge(
          type: 'fake',
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 1),
          ),
        );
        final result = await server.authenticatePass2(
          _message(password: '424242'),
          challengeToken: _tokenCarrying(lapsed),
        );

        expect(result.error, 'login.error.2fa.expired');
        expect(result.authorizationToken, isEmpty);
        expect(adaptor.verified, 0);
      },
    );

    test('a token carrying no challenge cannot complete a login', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
      final plain = await server.authenticatePass1(_message());

      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: TomClientJwtToken(plain.authorizationToken),
      );
      expect(result.error, 'login.error.2fa.no-challenge');
    });

    test(
      'pass 2 outside a request zone and without a token fails cleanly',
      () async {
        final result = await server.authenticatePass2(_message());
        expect(result.error, 'login.error.2fa.no-challenge');
        expect(result.authenticationToken, isEmpty);
      },
    );

    test(
      'a challenge for an unregistered mechanism cannot be answered',
      () async {
        final token = await issuedChallenge();
        Tom2FARegistry.reset();

        final result = await server.authenticatePass2(
          _message(password: '424242'),
          challengeToken: token,
        );
        expect(result.error, 'login.error.2fa.unsupported-mechanism');
      },
    );

    test(
      'pass 1 fails when the account names a mechanism nobody implements',
      () async {
        TomAuthenticationServer.globalSettingUserAuthenticationService =
            _StubAuthService(
              requires2FA: true,
              twoFactorType: 'carrier-pigeon',
            );
        final result = await server.authenticatePass1(_message());

        expect(result.error, 'login.error.2fa.unsupported-mechanism');
        expect(result.authenticationToken, isEmpty);
      },
    );

    test('pass 1 fails when the account names no mechanism at all', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true);
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
    });

    // An adaptor that cannot challenge this user (no enrolled device) must fail
    // the login rather than show a prompt that can never be satisfied.
    test('a TomLoginException from the adaptor surfaces its own key', () async {
      Tom2FARegistry.reset();
      Tom2FARegistry.register(
        'fake',
        _FakeAdaptor(
          failIssueWith: TomLoginException(
            'login.error.2fa.not-enrolled',
            'nothing enrolled',
            reason: TomLoginFailure.secondFactorRequired,
          ),
        ),
      );
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.not-enrolled');
      expect(result.authorizationToken, isEmpty);
    });

    test(
      'an unexpected adaptor fault is masked behind the generic error',
      () async {
        Tom2FARegistry.reset();
        Tom2FARegistry.register(
          'fake',
          _FakeAdaptor(failIssueWith: StateError('gateway down')),
        );
        final result = await server.authenticatePass1(_message());

        expect(result.error, 'login.error.unknown');
      },
    );

    test('a principal that owes no factor logs in on pass 1 alone', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isFalse);
      expect(adaptor.issued, 0);
      expect(
        TomClientJwtToken(
          result.authorizationToken,
          decrypt: false,
        ).payload?[Tom2FAClaims.requires2FA],
        'false',
      );
    });

    // -------------------------------------------------------------------------
    // The policy, not the principal's flags, decides
    // -------------------------------------------------------------------------

    /// The four tests above all drive the branch through the principal's own
    /// flags, which is what the default policy reports — so they would pass
    /// whether or not the decision had been lifted out of the field read. These
    /// two put the policy and the flags in *disagreement*, which is the only
    /// arrangement in which the difference is observable at all.
    test(
      'an installed policy can require a factor the principal does not',
      () async {
        // Flags say exempt. The deployment's policy says every `admin` owes one.
        TomAuthenticationServer.globalSettingUserAuthenticationService =
            _StubAuthService();
        TomBean.withType(
          Tom2FAPolicy,
          TomRole2FAPolicy(
            requirementByRole: {'admin': Tom2FARequirement.required},
            mechanisms: ['fake'],
          ),
        );

        final result = await server.authenticatePass1(_message());

        expect(result.error, isEmpty);
        expect(result.requires2FA, isTrue);
        expect(result.twoFactorType, 'fake');
        expect(adaptor.issued, 1);
      },
    );

    test(
      'an installed policy can exempt a principal whose flag requires one',
      () async {
        // Flags say required (the group default). The policy says nobody is.
        TomBean.withType(Tom2FAPolicy, TomRole2FAPolicy());

        final result = await server.authenticatePass1(_message());

        expect(result.error, isEmpty);
        expect(result.requires2FA, isFalse);
        expect(adaptor.issued, 0, reason: 'no challenge should be issued');
      },
    );

    // The permitted-but-not-installed case, reached through a policy rather than
    // through a principal naming a mechanism nobody implements. Same refusal,
    // because the login rejects on what is *offerable*, not on where the
    // permission came from.
    test(
      'a policy naming only unregistered mechanisms fails the login',
      () async {
        TomBean.withType(
          Tom2FAPolicy,
          TomRole2FAPolicy(
            defaultRequirement: Tom2FARequirement.required,
            // 'push' rather than 'sms': the framework ships an sms adaptor, and
            // the registry's scan finds it, so 'sms' names an *installed*
            // mechanism in any program that reflects the server barrel.
            mechanisms: ['push'],
          ),
        );

        final result = await server.authenticatePass1(_message());

        expect(result.error, 'login.error.2fa.unsupported-mechanism');
        expect(result.authenticationToken, isEmpty);
        expect(adaptor.issued, 0);
      },
    );

    test(
      'the login challenges with the policy\'s first offerable mechanism',
      () async {
        TomBean.withType(
          Tom2FAPolicy,
          TomRole2FAPolicy(
            defaultRequirement: Tom2FARequirement.required,
            // 'push' is permitted but not installed here, so preference order has
            // to survive the intersection for 'fake' to be the one challenged.
            mechanisms: ['push', 'fake'],
          ),
        );

        final result = await server.authenticatePass1(_message());

        expect(result.error, isEmpty);
        expect(result.twoFactorType, 'fake');
      },
    );
  });

  // ===========================================================================
  // THE SERVER'S HALF OF THE ENROLMENT CLAIM CONTRACT
  // ===========================================================================

  /// [Tom2FAEnrolmentState.fromClaims] is the server-side twin of the kernel's
  /// [Tom2FAPendingEnrolment.fromClaims]: the two read the *same claims out of
  /// the same token*, one to drive the UI and one to authorise the enrolment
  /// passes. They must therefore agree on what each claim means, which is why
  /// both read booleans through [Tom2FAClaims.isTrue].
  group('an interim token can be answered once', () {
    // The brute-force hole the attempt counter alone does not close. The count
    // travels inside the token, so a stateless server cannot tell a replay of
    // an earlier token in the chain from that token's first presentation — and
    // the earlier token is still inside its validity and still carries its
    // lower count. Replaying pass 1's token therefore bought a fresh allowance
    // every time, bounded only by how many requests fit in the challenge's
    // validity window. Six digits and five minutes is not a bound.
    late TomAuthenticationService savedUserService;
    late bool savedProtectionDefault;
    late _FakeAdaptor adaptor;
    final server = TomAuthenticationServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      adaptor = _FakeAdaptor();
      Tom2FARegistry.reset();
      Tom2FARegistry.register('fake', adaptor);
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true, twoFactorType: 'fake');
      // The default store is process-wide, so one test's spent tokens would
      // otherwise be the next one's.
      Tom2FAMemoryAttemptStore.shared.clear();
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
      Tom2FARegistry.reset();
      TomBean.resetBeanContext();
      Tom2FAMemoryAttemptStore.shared.clear();
    });

    Future<TomClientJwtToken> issuedChallenge() async {
      final pass1 = await server.authenticatePass1(_message());
      expect(pass1.error, isEmpty, reason: 'pass 1 should not fail');
      return TomClientJwtToken(pass1.authorizationToken);
    }

    test('a second answer to the same token is refused', () async {
      final token = await issuedChallenge();

      final first = await server.authenticatePass2(
        _message(password: 'wrong'),
        challengeToken: token,
      );
      expect(first.error, 'login.error.2fa.invalid-code');

      final replay = await server.authenticatePass2(
        _message(password: 'wrong'),
        challengeToken: token,
      );

      expect(replay.error, 'login.error.2fa.challenge-already-answered');
      expect(replay.authorizationToken, isEmpty);
      expect(
        adaptor.verified,
        1,
        reason:
            'the replay must be refused before the mechanism is asked, or the '
            'guess still costs the attacker nothing but a request',
      );
    });

    test('replaying the first token does not mint a fresh allowance', () async {
      // The attack, end to end. Three guesses is the whole budget, and it
      // stays three however the attacker orders the chain.
      final first = await issuedChallenge();

      var token = first;
      for (var attempt = 1; attempt <= 3; attempt++) {
        final result = await server.authenticatePass2(
          _message(password: 'wrong'),
          challengeToken: token,
        );
        if (attempt < 3) {
          expect(result.error, 'login.error.2fa.invalid-code');
          token = TomClientJwtToken(result.authorizationToken);
        } else {
          expect(result.error, 'login.error.2fa.attempts-exhausted');
        }
      }

      final rewound = await server.authenticatePass2(
        _message(password: 'wrong'),
        challengeToken: first,
      );

      expect(rewound.error, 'login.error.2fa.challenge-already-answered');
      expect(
        adaptor.verified,
        3,
        reason:
            'the mechanism saw exactly the allowance, and the replay of the '
            'lowest-counted token in the chain added nothing to it',
      );
    });

    test('a correct answer spends its token too', () async {
      // Otherwise one interim token mints sessions for as long as it lives.
      final token = await issuedChallenge();

      final accepted = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );
      expect(accepted.error, isEmpty);

      final again = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );
      expect(again.error, 'login.error.2fa.challenge-already-answered');
      expect(again.authorizationToken, isEmpty);
    });

    test('each token in the chain is answerable exactly once', () async {
      final first = await issuedChallenge();
      final retry = await server.authenticatePass2(
        _message(password: 'wrong'),
        challengeToken: first,
      );
      final second = TomClientJwtToken(retry.authorizationToken);

      // The re-issued token is a different token, so it has its own answer.
      final accepted = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: second,
      );
      expect(accepted.error, isEmpty);
    });

    test('an installed store replaces the process-wide default', () async {
      final recording = _RecordingAttemptStore();
      TomBean.withType(Tom2FAAttemptStore, recording);

      final token = await issuedChallenge();
      await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );

      expect(recording.spent, hasLength(1));
      expect(recording.spent.single.username, 'alice');
      expect(recording.spent.single.challengeType, 'fake');
      expect(recording.spent.single.fingerprint, isNotEmpty);
      expect(
        recording.spent.single.fingerprint,
        isNot(contains(token.tokenString)),
        reason:
            'the store holds a fingerprint, never the bearer credential '
            'itself — an attempt log is not a place to keep usable tokens',
      );
    });

    test(
      'a store that never refuses restores stateless verification',
      () async {
        // The escape hatch for a deployment that wants the old behaviour: the
        // seam takes it, so nobody has to fork the pass to get it.
        TomBean.withType(Tom2FAAttemptStore, _AlwaysFreshAttemptStore());

        final token = await issuedChallenge();
        await server.authenticatePass2(
          _message(password: 'wrong'),
          challengeToken: token,
        );
        final replay = await server.authenticatePass2(
          _message(password: 'wrong'),
          challengeToken: token,
        );

        expect(replay.error, 'login.error.2fa.invalid-code');
      },
    );
  });

  group('Tom2FAMemoryAttemptStore', () {
    setUp(Tom2FAMemoryAttemptStore.shared.clear);

    test('the first spend is fresh and every later one is not', () async {
      final store = Tom2FAMemoryAttemptStore();
      final attempt = Tom2FAAttempt(
        fingerprint: 'abc',
        username: 'alice',
        challengeType: 'fake',
        notAfter: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

      expect(await store.spend(attempt), isTrue);
      expect(await store.spend(attempt), isFalse);
      expect(await store.spend(attempt), isFalse);
    });

    test('two fingerprints do not collide', () async {
      final store = Tom2FAMemoryAttemptStore();
      final notAfter = DateTime.now().toUtc().add(const Duration(minutes: 5));

      expect(
        await store.spend(
          Tom2FAAttempt(
            fingerprint: 'a',
            username: 'alice',
            challengeType: 'fake',
            notAfter: notAfter,
          ),
        ),
        isTrue,
      );
      expect(
        await store.spend(
          Tom2FAAttempt(
            fingerprint: 'b',
            username: 'alice',
            challengeType: 'fake',
            notAfter: notAfter,
          ),
        ),
        isTrue,
      );
    });

    test(
      'an entry is dropped once its challenge could no longer be answered',
      () async {
        // The record only has to outlive the challenge: after that every token in
        // the chain is refused for being lapsed, so keeping the fingerprint would
        // grow the map for nothing.
        final store = Tom2FAMemoryAttemptStore();
        final lapsed = Tom2FAAttempt(
          fingerprint: 'old',
          username: 'alice',
          challengeType: 'fake',
          notAfter: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
        );

        expect(await store.spend(lapsed), isTrue);
        expect(
          store.size,
          isZero,
          reason:
              'an already-lapsed attempt is recorded and immediately pruned, so '
              'a burst of stale tokens cannot grow the map',
        );
      },
    );

    test('pruning does not drop a record that is still load-bearing', () async {
      final store = Tom2FAMemoryAttemptStore();
      final live = Tom2FAAttempt(
        fingerprint: 'live',
        username: 'alice',
        challengeType: 'fake',
        notAfter: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );
      await store.spend(live);

      await store.spend(
        Tom2FAAttempt(
          fingerprint: 'other',
          username: 'bob',
          challengeType: 'fake',
          notAfter: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
        ),
      );

      expect(await store.spend(live), isFalse);
    });
  });

  group('Tom2FAEnrolmentState claim decoding', () {
    Map<String, dynamic> claims() => <String, dynamic>{
      Tom2FAEnrolmentClaims.pendingEnrolment: 'true',
      Tom2FAEnrolmentClaims.offeredTypes: ['totp'],
      Tom2FAEnrolmentClaims.skippable: true,
      Tom2FAEnrolmentClaims.skipSpendsGrace: true,
    };

    test('the pendingEnrolment gate is read in either wire encoding', () {
      expect(Tom2FAEnrolmentState.fromClaims(claims()), isNotNull);
      expect(
        Tom2FAEnrolmentState.fromClaims(
          claims()..[Tom2FAEnrolmentClaims.pendingEnrolment] = true,
        ),
        isNotNull,
        reason:
            'refusing the JSON boolean would reject a token that really does '
            'carry an enrolment, stranding the login',
      );
    });

    test('the two flags are read in either wire encoding', () {
      // The server used to accept only the JSON boolean here while the kernel
      // accepted both, so one tier rendered a skip button the other refused.
      final asStrings = claims()
        ..[Tom2FAEnrolmentClaims.skippable] = 'true'
        ..[Tom2FAEnrolmentClaims.skipSpendsGrace] = 'true';

      final state = Tom2FAEnrolmentState.fromClaims(asStrings);
      expect(state!.skippable, isTrue);
      expect(state.skipSpendsGrace, isTrue);
    });

    test('the four values that mean yes or no are read as yes or no', () {
      for (final raw in <Object?>[false, 'false', null]) {
        expect(
          Tom2FAEnrolmentState.fromClaims(
            claims()..[Tom2FAEnrolmentClaims.pendingEnrolment] = raw,
          ),
          isNull,
          reason: '$raw (${raw.runtimeType}) says no enrolment is owed',
        );
      }
    });

    test('anything else is refused rather than read as no', () {
      // The claim decides whether a login is finished, so a value this reader
      // cannot interpret must not be assumed to mean "nothing owed": an issuer
      // that meant *this login is not finished* and spelled it `True` or `1`
      // would otherwise authenticate in full. The refusal is a throw because
      // the tokens are signed — an unreadable value can only come from an
      // issuer the deployment already trusts, which is the external-identity
      // case, and there a third party's reasonable encoding choice has to
      // become an error rather than a bypass.
      for (final raw in <Object?>['True', 1, 'yes']) {
        expect(
          () => Tom2FAEnrolmentState.fromClaims(
            claims()..[Tom2FAEnrolmentClaims.pendingEnrolment] = raw,
          ),
          throwsA(
            isA<TomException>().having(
              (e) => e.key,
              'key',
              'security.two_factor.unreadable_claim',
            ),
          ),
          reason: '$raw (${raw.runtimeType}) is neither yes nor no',
        );
      }

      // The same reader gates the two flags, so they refuse on the same terms
      // rather than quietly reading as `false`.
      expect(
        () => Tom2FAEnrolmentState.fromClaims(
          claims()..[Tom2FAEnrolmentClaims.skippable] = 'yes',
        ),
        throwsA(
          isA<TomException>().having(
            (e) => e.key,
            'key',
            'security.two_factor.unreadable_claim',
          ),
        ),
      );
    });

    test('the server and the kernel decode one payload the same way', () {
      // The claims a real offered-shape token carries, projected by the
      // server and read back by both tiers.
      final projected = Tom2FAEnrolmentState(
        offeredTypes: const ['totp'],
        skippable: true,
        skipSpendsGrace: true,
      ).toClaims().cast<String, dynamic>();

      final serverSide = Tom2FAEnrolmentState.fromClaims(projected);
      final clientSide = Tom2FAPendingEnrolment.fromClaims(projected);

      expect(serverSide, isNotNull);
      expect(clientSide, isNotNull);
      expect(clientSide!.skippable, equals(serverSide!.skippable));
      expect(clientSide.skipSpendsGrace, equals(serverSide.skipSpendsGrace));
      expect(clientSide.offeredTypes, equals(serverSide.offeredTypes));
    });
  });

  // ===========================================================================
  // THE DEADLINE IS THE ONLY THING BOUNDING A BEGUN ENROLMENT
  // ===========================================================================

  /// A begun enrolment is a generated secret sitting in a token, confirmable by
  /// whoever holds it. Two things stop that being permanent: the attempt
  /// counter and [Tom2FAEnrolmentClaims.expiresAt]. The offer itself travels in
  /// the token's *encrypted* half, so a client cannot touch it — but the expiry
  /// travels in the public payload, which nothing on the bearer path verifies
  /// ([TomClientJwtToken] decodes rather than verifies). Reading an unreadable
  /// deadline as "no deadline" would therefore hand a client an unbounded
  /// confirmation window for the asking.
  group('Tom2FAEnrolmentState expiry decoding', () {
    /// The public payload and encrypted section of a genuinely begun
    /// enrolment, as the authentication server's token issue would write them.
    (Map<String, dynamic>, Map<String, dynamic>) begun({DateTime? now}) {
      final state =
          Tom2FAEnrolmentState(
            offeredTypes: const ['totp'],
            skippable: true,
          ).withOffer(
            const Tom2FAEnrolmentOffer(
              type: 'totp',
              hint: 'authenticator',
              enrolmentData: {'secret': 'S3CR3T'},
              validity: Duration(minutes: 10),
            ),
            now: now ?? DateTime.utc(2026, 1, 1, 12),
          );
      return (
        state.toClaims().cast<String, dynamic>(),
        state.secretClaims!.cast<String, dynamic>(),
      );
    }

    test('an honest begun state round-trips with its deadline intact', () {
      final (payload, secret) = begun();

      final state = Tom2FAEnrolmentState.fromClaims(payload, secret);

      expect(state!.hasOffer, isTrue);
      expect(state.expiresAt, equals(DateTime.utc(2026, 1, 1, 12, 10)));
      expect(state.isExpired(DateTime.utc(2026, 1, 1, 12, 9)), isFalse);
      expect(state.isExpired(DateTime.utc(2026, 1, 1, 12, 11)), isTrue);
    });

    test('a begun state whose expiry claim was dropped is refused', () {
      final (payload, secret) = begun();
      payload.remove(Tom2FAEnrolmentClaims.expiresAt);

      expect(
        () => Tom2FAEnrolmentState.fromClaims(payload, secret),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.2fa.enrolment-offer-invalid',
          ),
        ),
        reason:
            'the offer is authentic (encrypted) but its bound is not, so a '
            'missing deadline is a client having removed the one claim that '
            'closes the window',
      );
    });

    test('a begun state whose expiry claim is malformed is refused', () {
      for (final raw in <Object?>['', 'soon', 'null', 0, false, <String>[]]) {
        final (payload, secret) = begun();
        payload[Tom2FAEnrolmentClaims.expiresAt] = raw;

        expect(
          () => Tom2FAEnrolmentState.fromClaims(payload, secret),
          throwsA(isA<TomLoginException>()),
          reason: '$raw (${raw.runtimeType}) is not a readable instant',
        );
      }
    });

    test('the offered shape still decodes without any deadline', () {
      // The rule is about a *begun* enrolment. A user still choosing has no
      // window to close, and demanding one would break the choosing stop.
      final payload = Tom2FAEnrolmentState(
        offeredTypes: const ['totp'],
        skippable: true,
      ).toClaims().cast<String, dynamic>();

      final state = Tom2FAEnrolmentState.fromClaims(payload);

      expect(state!.hasOffer, isFalse);
      expect(state.expiresAt, isNull);
      expect(state.isExpired(), isFalse);
    });

    test('a begun state with no deadline reports itself expired', () {
      // Defence in depth for the paths that construct a state directly rather
      // than decoding one. A null deadline may only ever mean "still
      // choosing"; on a begun state it must fail closed, not open.
      final state = Tom2FAEnrolmentState(
        offeredTypes: const ['totp'],
        offer: const Tom2FAEnrolmentOffer(type: 'totp'),
      );

      expect(state.expiresAt, isNull);
      expect(state.isExpired(), isTrue);
      expect(
        state.isExpired(DateTime.utc(1970)),
        isTrue,
        reason: 'no instant is inside a window that was never opened',
      );
    });
  });

  // ===========================================================================
  // THE FOUR SHAPES A DEPLOYMENT CAN BE IN
  // ===========================================================================

  /// The login flow used to serve exactly one of these: *enforced, and the user
  /// already has a factor*. The other three each ended somewhere wrong — a hard
  /// failure with no path forward for a user who owes a factor they have never
  /// set up, and no way at all to express "offered, declinable". These tests run
  /// all four to a conclusion through the real server.
  group('TomAuthenticationServer enrolment flow', () {
    late TomAuthenticationService savedUserService;
    late bool savedProtectionDefault;
    late _EnrollableAdaptor enrollable;
    late _FakeAdaptor unenrollable;
    late TomMemory2FAEnrolmentStore store;
    final server = TomAuthenticationServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      TomResourceKeyProtection.globalSettingProtectionDefault = false;

      TomBean.resetBeanContext();
      Tom2FARegistry.reset();
      enrollable = _EnrollableAdaptor();
      unenrollable = _FakeAdaptor();
      Tom2FARegistry.register('app', enrollable);
      Tom2FARegistry.register('fake', unenrollable);

      store = TomMemory2FAEnrolmentStore();
      TomBean.withType(Tom2FAEnrolmentStore, store);

      // The principal's own flags say nothing here — every test in this group
      // installs the policy that decides.
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
      Tom2FARegistry.reset();
      TomBean.resetBeanContext();
    });

    /// Installs a policy permitting [mechanisms] at [requirement].
    void policy(
      Tom2FARequirement requirement, {
      List<String> mechanisms = const ['app'],
    }) => TomBean.withType(
      Tom2FAPolicy,
      TomRole2FAPolicy(defaultRequirement: requirement, mechanisms: mechanisms),
    );

    /// The context the server builds for the logging-in user, so a test can
    /// seed and read the store under the same key the flow uses.
    Tom2FAContext contextOfAlice() => Tom2FAContext(
      principal: _principal(
        TomAuthenticationData(
          username: 'alice',
          organization: 'acme',
          application: 'console',
          process: 'login',
          language: 'en',
          country: 'US',
          timezone: 'UTC',
          client: 'web',
        ),
      ),
    );

    /// Records [type] as an already-set-up factor for the logging-in user.
    Future<void> alreadyEnrolled({
      String type = 'app',
      String id = 'existing',
      bool isPrimary = true,
    }) => store.store(
      contextOfAlice(),
      Tom2FAEnrolment(
        type: type,
        enrolmentId: id,
        hint: 'set up earlier',
        isPrimary: isPrimary,
        secretData: const {'secret': _EnrollableAdaptor.secret},
      ),
    );

    /// Runs pass 1 and hands back the interim token plus the result.
    Future<(TomAuthenticationResult, TomClientJwtToken)> login() async {
      final result = await server.authenticatePass1(_message());
      expect(result.error, isEmpty, reason: 'pass 1 should not fail');
      return (result, TomClientJwtToken(result.authorizationToken));
    }

    // ------------------------------------------------------------------
    // Shape 1 — enforced, already enrolled
    // ------------------------------------------------------------------

    test('an enrolled user is challenged, not asked to enrol again', () async {
      await alreadyEnrolled();
      policy(Tom2FARequirement.required);

      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isTrue);
      expect(result.requires2FAEnrolment, isFalse);
      expect(result.twoFactorType, 'app');
      expect(result.availableTwoFactorMethods, isEmpty);
      expect(enrollable.issued, 1);
      expect(enrollable.begun, 0);
    });

    // `principal.twoFactorType` is the field that looks like the answer and is
    // not: it names only one factor, and it is set by whichever adaptor built
    // the principal. The store is the authority, so a user holding several
    // factors is challenged for the one they nominated.
    test(
      'the challenge follows the primary enrolment, not the policy order',
      () async {
        await alreadyEnrolled(type: 'fake', id: 'old-token', isPrimary: false);
        await alreadyEnrolled(id: 'phone');
        policy(Tom2FARequirement.required, mechanisms: ['fake', 'app']);

        final result = await server.authenticatePass1(_message());

        expect(
          result.twoFactorType,
          'app',
          reason: "'fake' comes first in the policy but is not primary",
        );
        expect(unenrollable.issued, 0);
        expect(enrollable.issued, 1);
      },
    );

    // ------------------------------------------------------------------
    // Shape 2 — enforced, not yet enrolled
    // ------------------------------------------------------------------

    test(
      'an unenrolled user is offered the method list, not locked out',
      () async {
        policy(Tom2FARequirement.required);

        final (result, _) = await login();

        expect(
          result.error,
          isEmpty,
          reason: 'an unenrolled user under a required policy is not an error',
        );
        expect(result.requires2FAEnrolment, isTrue);
        expect(
          result.requires2FA,
          isFalse,
          reason: 'enrolment is its own state, not an overloaded challenge',
        );
        expect(result.twoFactorEnrolmentSkippable, isFalse);
        expect(result.availableTwoFactorMethods.map((m) => m.type), ['app']);
        // Resource-keyed, so the chooser has something to render in the user's
        // own language rather than a mechanism key.
        final method = result.availableTwoFactorMethods.single;
        expect(method.displayNameKey, 'two_factor.app.name');
        expect(method.descriptionKey, 'two_factor.app.description');
        expect(method.iconKey, 'two_factor.app.icon');
        expect(enrollable.issued, 0, reason: 'nothing to challenge yet');
      },
    );

    // The counterpart to the test above, and the reason the login path keeps
    // three outcomes rather than two: with no store installed there is nothing
    // that *could* have recorded an enrolment, so the user is challenged on the
    // policy's first choice. Reading that as "none enrolled" would push every
    // deployment that never opted into the store through enrolment instead.
    test('no store installed is a challenge, not an offer to enrol', () async {
      // Drop the store this group installs; the policy has to be re-installed
      // because resetting the context clears both.
      TomBean.resetBeanContext();
      policy(Tom2FARequirement.required);
      expect(Tom2FAEnrolmentStore.resolve(), isNull, reason: 'premise');

      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isTrue);
      expect(result.requires2FAEnrolment, isFalse);
      expect(result.twoFactorType, 'app');
      expect(enrollable.issued, 1);
      expect(enrollable.begun, 0);
    });

    // A mechanism the policy permits but which cannot be set up here is not an
    // offer — advertising it would produce a chooser entry that fails the
    // moment it is picked.
    test('the offer names only the mechanisms that can be enrolled', () async {
      policy(Tom2FARequirement.required, mechanisms: ['fake', 'app']);

      final (result, _) = await login();

      expect(result.requires2FAEnrolment, isTrue);
      expect(result.availableTwoFactorMethods.map((m) => m.type), ['app']);
    });

    test('an offer token can be confirmed only once', () async {
      // The same hole as pass two's, in the sibling pass. It matters for the
      // mechanisms whose confirmation is a code sent out of band: an
      // authenticator app hands the secret to whoever holds the token, so
      // guessing its code proves nothing, but an emailed code is exactly as
      // brute-forceable here as a challenge code is there.
      Tom2FAMemoryAttemptStore.shared.clear();
      addTearDown(Tom2FAMemoryAttemptStore.shared.clear);
      policy(Tom2FARequirement.required);
      final (_, offered) = await login();

      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: offered,
      );
      final offerToken = TomClientJwtToken(begun.authorizationToken);

      final wrong = await server.completeTwoFactorEnrolment(
        _message(password: 'not-the-code'),
        enrolmentToken: offerToken,
      );
      expect(wrong.error, 'login.error.2fa.enrolment-invalid-code');

      final replay = await server.completeTwoFactorEnrolment(
        _message(password: 'not-the-code'),
        enrolmentToken: offerToken,
      );

      expect(replay.error, 'login.error.2fa.enrolment-already-answered');
      expect(replay.authorizationToken, isEmpty);
      expect(
        enrollable.confirmed,
        1,
        reason:
            'the adaptor saw the first answer and not the replay — a replay '
            'refused after the mechanism had been asked would still be a free '
            'guess',
      );
    });

    test('an interim enrolment token grants no session', () async {
      policy(Tom2FARequirement.required);

      final (_, token) = await login();
      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        token,
      );

      expect(principal.username, 'alice');
      expect(principal.authenticated, isFalse);
    });

    test('the whole enrol-on-first-login round trip issues a session', () async {
      policy(Tom2FARequirement.required);
      final (_, offered) = await login();

      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: offered,
      );
      expect(begun.error, isEmpty);
      expect(begun.requires2FAEnrolment, isTrue);
      expect(enrollable.begun, 1);

      // What the user needs to install rides in the public claims...
      final begunToken = TomClientJwtToken(begun.authorizationToken);
      final publicClaims = TomClientJwtToken(
        begun.authorizationToken,
        decrypt: false,
      ).payload;
      expect(
        publicClaims?[Tom2FAEnrolmentClaims.clientData],
        containsPair('setupCode', _EnrollableAdaptor.secret),
      );
      // ...and the copy the server confirms against is encrypted, so a client
      // cannot swap the material it is about to be tested on.
      expect(publicClaims, isNot(contains(Tom2FAEnrolmentClaims.offerData)));
      expect(begunToken.secretData, contains(Tom2FAEnrolmentClaims.offerData));

      final done = await server.completeTwoFactorEnrolment(
        _message(password: _EnrollableAdaptor.confirmation),
        enrolmentToken: begunToken,
      );

      expect(done.error, isEmpty);
      expect(done.requires2FAEnrolment, isFalse);
      // No second hoop: proving possession once is proving it.
      expect(done.requires2FA, isFalse);
      expect(enrollable.issued, 0);

      final session = TomClientJwtToken(done.authorizationToken);
      expect(
        TomBearerAuthentication.convertTokenPayloadToPrincipal(
          session,
        ).authenticated,
        isTrue,
      );

      // And it was recorded — the first factor becoming the primary one, so the
      // next login has something to challenge without anyone nominating it.
      final stored = await store.enrolmentsFor(contextOfAlice());
      expect(stored, hasLength(1));
      expect(stored.single.type, 'app');
      expect(stored.single.isPrimary, isTrue);
    });

    test('the next login after enrolling is challenged normally', () async {
      policy(Tom2FARequirement.required);
      final (_, offered) = await login();
      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: offered,
      );
      await server.completeTwoFactorEnrolment(
        _message(password: _EnrollableAdaptor.confirmation),
        enrolmentToken: TomClientJwtToken(begun.authorizationToken),
      );

      final second = await server.authenticatePass1(_message());

      expect(second.requires2FAEnrolment, isFalse);
      expect(second.requires2FA, isTrue);
      expect(second.twoFactorType, 'app');
      expect(enrollable.issued, 1);
    });

    // ------------------------------------------------------------------
    // Shape 3 — optional
    // ------------------------------------------------------------------

    test(
      'an optional policy offers enrolment and lets it be declined',
      () async {
        policy(Tom2FARequirement.optional);

        final (offer, token) = await login();
        expect(offer.requires2FAEnrolment, isTrue);
        expect(offer.twoFactorEnrolmentSkippable, isTrue);

        final skipped = await server.skipTwoFactorEnrolment(
          _message(),
          enrolmentToken: token,
        );

        expect(skipped.error, isEmpty);
        expect(skipped.requires2FA, isFalse);
        expect(skipped.requires2FAEnrolment, isFalse);
        expect(
          TomBearerAuthentication.convertTokenPayloadToPrincipal(
            TomClientJwtToken(skipped.authorizationToken),
          ).authenticated,
          isTrue,
        );
        expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
      },
    );

    test('an optional offer can also be accepted', () async {
      policy(Tom2FARequirement.optional);
      final (_, token) = await login();

      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: token,
      );
      final done = await server.completeTwoFactorEnrolment(
        _message(password: _EnrollableAdaptor.confirmation),
        enrolmentToken: TomClientJwtToken(begun.authorizationToken),
      );

      expect(done.error, isEmpty);
      expect(await store.enrolmentsFor(contextOfAlice()), hasLength(1));
    });

    test('a required offer cannot be declined', () async {
      policy(Tom2FARequirement.required);
      final (_, token) = await login();

      final result = await server.skipTwoFactorEnrolment(
        _message(),
        enrolmentToken: token,
      );

      expect(result.error, 'login.error.2fa.enrolment-required');
      expect(result.authorizationToken, isEmpty);
    });

    // Grace is the one case in which a *required* factor may be postponed, and
    // the postponement has to be charged to somebody — the policy that granted
    // it, which is the only party that knows how many are left.
    test(
      'grace logins make a required offer declinable, and are spent',
      () async {
        final graced = _GracePolicy(
          requirement: Tom2FARequirement.required,
          graceLogins: 2,
        );
        TomBean.withType(Tom2FAPolicy, graced);

        final (offer, token) = await login();
        expect(offer.requires2FAEnrolment, isTrue);
        expect(offer.twoFactorEnrolmentSkippable, isTrue);

        final skipped = await server.skipTwoFactorEnrolment(
          _message(),
          enrolmentToken: token,
        );

        expect(skipped.error, isEmpty);
        expect(graced.graceSpent, 1);
      },
    );

    // Opening the chooser is not using a grace login. Only declining is.
    test('enrolling under grace spends none of it', () async {
      final graced = _GracePolicy(
        requirement: Tom2FARequirement.required,
        graceLogins: 2,
      );
      TomBean.withType(Tom2FAPolicy, graced);

      final (_, token) = await login();
      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: token,
      );
      await server.completeTwoFactorEnrolment(
        _message(password: _EnrollableAdaptor.confirmation),
        enrolmentToken: TomClientJwtToken(begun.authorizationToken),
      );

      expect(graced.graceSpent, 0);
    });

    test('an optional skip charges no grace', () async {
      final graced = _GracePolicy(
        requirement: Tom2FARequirement.optional,
        graceLogins: 2,
      );
      TomBean.withType(Tom2FAPolicy, graced);

      final (_, token) = await login();
      await server.skipTwoFactorEnrolment(_message(), enrolmentToken: token);

      expect(
        graced.graceSpent,
        0,
        reason: 'an optional factor was never owed, so nothing was postponed',
      );
    });

    // ------------------------------------------------------------------
    // Shape 4 — not offered at all
    // ------------------------------------------------------------------

    test('a disabled policy never mentions 2FA', () async {
      policy(Tom2FARequirement.disabled);

      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isFalse);
      expect(result.requires2FAEnrolment, isFalse);
      expect(result.availableTwoFactorMethods, isEmpty);
      expect(result.twoFactorEnrolmentSkippable, isFalse);
      expect(enrollable.begun, 0);
      expect(enrollable.issued, 0);
      expect(
        TomBearerAuthentication.convertTokenPayloadToPrincipal(
          TomClientJwtToken(result.authorizationToken),
        ).authenticated,
        isTrue,
      );
    });

    // A deployment that installed no store keeps exactly the behaviour it had:
    // the adaptor stays the only authority on whether the user has a factor,
    // because there would be nowhere to save an enrolment offered here.
    test(
      'with no store installed the login keeps the challenge path',
      () async {
        TomBean.resetBeanContext();
        policy(Tom2FARequirement.required);

        final result = await server.authenticatePass1(_message());

        expect(result.error, isEmpty);
        expect(result.requires2FA, isTrue);
        expect(result.requires2FAEnrolment, isFalse);
        expect(enrollable.issued, 1);
      },
    );

    // ------------------------------------------------------------------
    // What the enrolment passes refuse
    // ------------------------------------------------------------------

    test('a mechanism that was not offered cannot be enrolled', () async {
      policy(Tom2FARequirement.required);
      final (_, token) = await login();

      final result = await server.beginTwoFactorEnrolment(
        _message(password: 'sms'),
        enrolmentToken: token,
      );

      expect(result.error, 'login.error.2fa.enrolment-not-offered');
      expect(result.authorizationToken, isEmpty);
      expect(enrollable.begun, 0);
    });

    test(
      'a wrong confirmation stores nothing and leaves the login incomplete',
      () async {
        policy(Tom2FARequirement.required);
        final (_, token) = await login();
        final begun = await server.beginTwoFactorEnrolment(
          _message(password: 'app'),
          enrolmentToken: token,
        );

        final retry = await server.completeTwoFactorEnrolment(
          _message(password: 'nope'),
          enrolmentToken: TomClientJwtToken(begun.authorizationToken),
        );

        expect(retry.error, 'login.error.2fa.enrolment-invalid-code');
        expect(retry.requires2FAEnrolment, isTrue);
        expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
        expect(
          TomBearerAuthentication.convertTokenPayloadToPrincipal(
            TomClientJwtToken(retry.authorizationToken),
          ).authenticated,
          isFalse,
        );

        // The re-issued token still confirms, with one attempt spent — the same
        // retry shape a wrong challenge answer gets.
        final done = await server.completeTwoFactorEnrolment(
          _message(password: _EnrollableAdaptor.confirmation),
          enrolmentToken: TomClientJwtToken(retry.authorizationToken),
        );
        expect(done.error, isEmpty);
        expect(await store.enrolmentsFor(contextOfAlice()), hasLength(1));
      },
    );

    test('confirmation attempts cannot be rewound and do run out', () async {
      policy(Tom2FARequirement.required);
      final (_, token) = await login();
      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: token,
      );

      final first = await server.completeTwoFactorEnrolment(
        _message(password: 'nope'),
        enrolmentToken: TomClientJwtToken(begun.authorizationToken),
      );
      expect(first.error, 'login.error.2fa.enrolment-invalid-code');

      // The offer allows two attempts, so the second wrong one burns it.
      final burned = await server.completeTwoFactorEnrolment(
        _message(password: 'nope'),
        enrolmentToken: TomClientJwtToken(first.authorizationToken),
      );
      expect(burned.error, 'login.error.2fa.enrolment-attempts-exhausted');
      expect(burned.authorizationToken, isEmpty);
      expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
    });

    // Without this, the enrolment passes would be an unauthenticated way to
    // attach a factor to somebody else's finished session.
    test('a completed token cannot drive any enrolment pass', () async {
      policy(Tom2FARequirement.disabled);
      final completed = await server.authenticatePass1(_message());
      final token = TomClientJwtToken(completed.authorizationToken);

      for (final pass in <Future<TomAuthenticationResult> Function()>[
        () => server.beginTwoFactorEnrolment(
          _message(password: 'app'),
          enrolmentToken: token,
        ),
        () => server.completeTwoFactorEnrolment(
          _message(password: _EnrollableAdaptor.confirmation),
          enrolmentToken: token,
        ),
        () => server.skipTwoFactorEnrolment(_message(), enrolmentToken: token),
      ]) {
        final result = await pass();
        expect(result.error, 'login.error.2fa.no-enrolment');
        expect(result.authorizationToken, isEmpty);
      }
      expect(enrollable.begun, 0);
      expect(enrollable.confirmed, 0);
      expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
    });

    test('a challenge token is not an enrolment token', () async {
      await alreadyEnrolled();
      policy(Tom2FARequirement.required);
      final (_, challengeToken) = await login();

      final result = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: challengeToken,
      );

      expect(result.error, 'login.error.2fa.no-enrolment');
    });

    test('confirming before beginning is refused', () async {
      policy(Tom2FARequirement.required);
      final (_, offered) = await login();

      final result = await server.completeTwoFactorEnrolment(
        _message(password: _EnrollableAdaptor.confirmation),
        enrolmentToken: offered,
      );

      expect(result.error, 'login.error.2fa.enrolment-offer-invalid');
      expect(enrollable.confirmed, 0);
    });

    /// The confirmation window, exercised at the boundary it exists to draw.
    ///
    /// The expiry claim is a public claim, so a client holding the interim
    /// token can rewrite it in the string it sends. The enrolment passes take
    /// an already-decoded token, so these three tests hand them one whose
    /// claim was rewritten on the wire: a deadline in the past, no deadline at
    /// all, and a deadline that is not an instant. All three must refuse,
    /// because the alternative to refusing is a generated secret that stays
    /// confirmable for as long as somebody keeps the token.
    group('the confirmation window is not the client\'s to move', () {
      /// A begun enrolment whose public expiry claim has been rewritten to
      /// [value], as a client holding the interim token could rewrite it.
      ///
      /// The rewrite is done to the token *string* -- the payload segment
      /// decoded, edited, re-encoded, the signature left as it was -- because
      /// that is the edit a client can make. A decoded token's `payload` is
      /// read-only, so there is no editing the object in hand.
      Future<TomClientJwtToken> tamperedOffer(Object? value) async {
        policy(Tom2FARequirement.required);
        final (_, token) = await login();
        final begun = await server.beginTwoFactorEnrolment(
          _message(password: 'app'),
          enrolmentToken: token,
        );

        final [header, body, signature] = begun.authorizationToken.split('.');
        final claims =
            jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(body))))
                as Map<String, dynamic>;
        if (value == null) {
          claims.remove(Tom2FAEnrolmentClaims.expiresAt);
        } else {
          claims[Tom2FAEnrolmentClaims.expiresAt] = value;
        }
        final rewritten = base64Url
            .encode(utf8.encode(jsonEncode(claims)))
            .replaceAll('=', '');
        return TomClientJwtToken('$header.$rewritten.$signature');
      }

      test('a lapsed offer cannot be confirmed', () async {
        final lapsed = await tamperedOffer(
          DateTime.now()
              .toUtc()
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        );

        final result = await server.completeTwoFactorEnrolment(
          _message(password: _EnrollableAdaptor.confirmation),
          enrolmentToken: lapsed,
        );

        expect(result.error, 'login.error.2fa.enrolment-expired');
        expect(result.authorizationToken, isEmpty);
        expect(
          enrollable.confirmed,
          0,
          reason: 'the window closes before the adaptor is consulted',
        );
        expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
      });

      test('an offer with its deadline removed cannot be confirmed', () async {
        final unbounded = await tamperedOffer(null);

        final result = await server.completeTwoFactorEnrolment(
          _message(password: _EnrollableAdaptor.confirmation),
          enrolmentToken: unbounded,
        );

        expect(result.error, 'login.error.2fa.enrolment-offer-invalid');
        expect(result.authorizationToken, isEmpty);
        expect(enrollable.confirmed, 0);
        expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
      });

      test(
        'an offer with an unreadable deadline cannot be confirmed',
        () async {
          final unreadable = await tamperedOffer('whenever');

          final result = await server.completeTwoFactorEnrolment(
            _message(password: _EnrollableAdaptor.confirmation),
            enrolmentToken: unreadable,
          );

          expect(result.error, 'login.error.2fa.enrolment-offer-invalid');
          expect(enrollable.confirmed, 0);
          expect(await store.enrolmentsFor(contextOfAlice()), isEmpty);
        },
      );

      // Skipping and re-choosing read the same claims through the same
      // decoder, so an unbounded offer must be refused there too rather than
      // being a quieter way past the same check.
      test('every enrolment pass refuses an unbounded offer', () async {
        final unbounded = await tamperedOffer(null);

        for (final pass in <Future<TomAuthenticationResult> Function()>[
          () => server.beginTwoFactorEnrolment(
            _message(password: 'app'),
            enrolmentToken: unbounded,
          ),
          () => server.skipTwoFactorEnrolment(
            _message(),
            enrolmentToken: unbounded,
          ),
        ]) {
          final result = await pass();
          expect(result.error, 'login.error.2fa.enrolment-offer-invalid');
        }
      });
    });

    test('an enrolment pass outside a request zone fails cleanly', () async {
      final result = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
      );

      expect(result.error, 'login.error.2fa.no-enrolment');
      expect(result.authenticationToken, isEmpty);
    });

    // The offer is only honest if the factor it advertises can be recorded.
    test(
      'a required user with nothing enrollable still fails the login',
      () async {
        policy(Tom2FARequirement.required, mechanisms: ['fake']);

        final result = await server.authenticatePass1(_message());

        expect(result.error, 'login.error.2fa.unsupported-mechanism');
        expect(result.authorizationToken, isEmpty);
      },
    );

    // The store going away *between* the offer and the confirmation is the only
    // way to reach this refusal, and that is worth stating rather than working
    // around: with no store installed `_usableEnrolments` answers null and no
    // enrolment is ever offered, so a deployment that never had one cannot get
    // here. What can is a restart or a bean context rebuilt mid-flow — and the
    // confirmation must then refuse, because the alternative is confirming a
    // factor that is written nowhere and handing out a full token pair for it.
    // The user would be enrolled in their own belief and in nothing else, and
    // their next login would ask them to enrol again.
    test('an enrolment whose store disappears mid-flow is refused', () async {
      policy(Tom2FARequirement.required);
      final (_, token) = await login();
      final begun = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
        enrolmentToken: token,
      );
      expect(begun.error, isEmpty, reason: 'the offer must be made first');

      // The store goes; the registry is static and survives, so the pass still
      // reaches the store check rather than failing earlier on the mechanism.
      TomBean.resetBeanContext();

      final result = await server.completeTwoFactorEnrolment(
        _message(password: _EnrollableAdaptor.confirmation),
        enrolmentToken: TomClientJwtToken(begun.authorizationToken),
      );

      expect(result.error, 'login.error.2fa.enrolment-unavailable');
      expect(result.authorizationToken, isEmpty);
      expect(
        enrollable.confirmed,
        0,
        reason: 'nothing is confirmed that cannot be recorded',
      );
    });
  });
}

/// Mints an interim token carrying [challenge] for a fixed principal.
///
/// Lets a test present a challenge in a state pass 1 will not naturally produce
/// (already exhausted, already lapsed) without stubbing the clock.
TomClientJwtToken _tokenCarrying(Tom2FAChallenge challenge) {
  final principal = _principal(
    TomAuthenticationData(
      username: 'alice',
      organization: 'acme',
      application: 'console',
      process: 'login',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    ),
    requires2FA: true,
    twoFactorType: challenge.type,
  );
  final (
    publicInfo,
    privateInfo,
  ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
    principal,
    null,
    'US',
    'en',
    challenge: challenge,
    twoFactorVerification: const {'nonce': 'n-1'},
  );
  return TomClientJwtToken(
    TomServerJwtToken(publicInfo, encryptedData: privateInfo).getJWT('tom'),
  );
}

/// A store that records what it was asked and never refuses.
class _RecordingAttemptStore implements Tom2FAAttemptStore {
  final List<Tom2FAAttempt> spent = [];

  @override
  Future<bool> spend(Tom2FAAttempt attempt) async {
    spent.add(attempt);
    return true;
  }
}

/// The escape hatch a deployment wanting stateless verification installs.
class _AlwaysFreshAttemptStore implements Tom2FAAttemptStore {
  @override
  Future<bool> spend(Tom2FAAttempt attempt) async => true;
}

/// A grace store that counts how often it was asked.
class _CountingGraceStore implements Tom2FAGraceStore {
  _CountingGraceStore({this.consumed = 0});

  final int consumed;
  int reads = 0;

  @override
  Future<int> consumedBy(Tom2FAContext context) async {
    reads++;
    return consumed;
  }

  @override
  Future<void> recordConsumed(Tom2FAContext context) async {}
}
