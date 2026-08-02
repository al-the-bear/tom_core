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
    timeZone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: roles),
);

/// A principal distinguished only by its user id, for the enrolment store —
/// whose entire job is to keep one user's factors away from another's.
TomPrincipal _principalWithId(int userId) => TomPrincipal(
      authenticated: true,
      context: {},
      clientId: 0,
      organization: 'acme',
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
        timeZone: 'utc',
      ),
      aci: TomAccessControlInformation(roles: const ['user']),
    );

/// An authentication service that answers with a fixed principal shape.
class _StubAuthService implements TomAuthenticationService {
  _StubAuthService({
    this.requires2FA = false,
    this.twoFactorType,
  });

  final bool requires2FA;
  final String? twoFactorType;

  @override
  Future<TomAuthenticationInfo> authenticateUser(TomAuthenticationData a) async =>
      TomAuthenticationInfo(
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
  ) async =>
      submission.submitted == confirmation;

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
      throw LoginException(
        'login.error.2fa.enrolment-invalid-code',
        'The confirmation code does not match the offered factor',
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
  })  : _metadata = metadata,
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
  ]) =>
      _instantiate();

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

    test('Tom2FAException is a server exception that is not client-throwable',
        () {
      final e = Tom2FAException('authentication.2fa.x', 'boom');
      expect(e, isA<TomServerException>());
      expect(e.clientThrow, isFalse);
    });

    test('reset drops every registration', () {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      Tom2FARegistry.reset();
      expect(Tom2FARegistry.lookup('fake'), isNull);
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

    test('availableMethods reports the TOTP descriptor with resource keys',
        () async {
      initializeReflection();
      Tom2FARegistry.reset();

      final totp = Tom2FARegistry.availableMethods.singleWhere(
        (m) => m.type == TomTotp2FAService.mechanismType,
      );
      expect(totp.displayNameKey, 'two_factor.totp.name');
      expect(totp.descriptionKey, 'two_factor.totp.description');
      expect(totp.iconKey, 'two_factor.totp.icon');
    });

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

    test('the catalog is derived from the registry, so the two cannot drift',
        () {
      Tom2FARegistry.reset();
      Tom2FARegistry.register('fake', _FakeAdaptor());
      expect(
        Tom2FARegistry.availableMethods.map((m) => m.type),
        Tom2FARegistry.registeredTypes,
      );
    });

    // "What can be verified here" and "what can the user be sent off to set up"
    // are different questions. A forced-enrolment step that offered the first
    // would present an option that cannot be acted on.
    test('enrollableMethods is availableMethods minus what cannot be enrolled',
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
    });

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

    Tom2FAContext contextFor(int userId) => Tom2FAContext(
          principal: _principalWithId(userId),
        );

    Tom2FAEnrolment enrolment({
      String type = 'totp',
      String id = 'device-1',
      String hint = 'iPhone',
      bool isPrimary = false,
      Map<String, Object?> secretData = const {'secret': _rfcSecretBase32},
    }) =>
        Tom2FAEnrolment(
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
      expect(loaded.where((e) => e.isPrimary).map((e) => e.enrolmentId),
          ['app']);
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

    test('remove drops one enrolment and tolerates an absent id', () async {
      final context = contextFor(1);
      await store.store(context, enrolment(id: 'a'));
      await store.store(context, enrolment(id: 'b'));

      await store.remove(context, 'a');
      expect((await store.enrolmentsFor(context)).map((e) => e.enrolmentId),
          ['b']);

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
          isA<Tom2FAException>().having((e) => e.key, 'key', key).having(
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
      expect(identical(Tom2FARegistry.lookup('carrier-pigeon'), adaptor), isTrue);
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
          isA<Tom2FAException>()
              .having((e) => e.defaultUserMessage, 'message', contains('"sms"')),
        ),
      );
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

  // The RFC vectors for the derivation itself live with the derivation, in
  // `tom_core_kernel/test/security_test.dart` (group `TomTotp`). What is tested
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

    test('issues a challenge describing the code shape but delivering nothing',
        () async {
      final spec = await TomTotp2FAService().issueChallenge(context());
      expect(spec.hint, isEmpty);
      expect(spec.clientData['digits'], TomTotp2FAService.globalSettingDigits);
      expect(
        spec.clientData['periodSeconds'],
        TomTotp2FAService.globalSettingPeriod.inSeconds,
      );
      // Nothing secret travels: the secret is re-resolved on pass 2.
      expect(spec.verificationData, isEmpty);
    });

    test('fails the login when no authenticator is enrolled', () async {
      TomTotp2FAService.globalSettingSecretResolver = (_) => null;
      await expectLater(
        TomTotp2FAService().issueChallenge(context()),
        throwsA(
          isA<LoginException>().having(
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
    Future<void> installStoreWith(String? secret, {String type = 'totp'}) async {
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
      TomTotp2FAService.globalSettingSecretResolver =
          (_) => 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      await installStoreWith(_rfcSecretBase32);

      expect(
        await TomTotp2FAService()
            .verifySubmission(context(), submission(currentCode())),
        isTrue,
      );
    });

    // Migrating one user at a time: a store that holds nothing for *this* user
    // is not an answer, so the hook still gets asked.
    test('falls back to the resolver when the store holds no TOTP enrolment',
        () async {
      await installStoreWith(_rfcSecretBase32, type: 'sms');
      expect(
        await TomTotp2FAService()
            .verifySubmission(context(), submission(currentCode())),
        isTrue,
      );
    });

    test('with a store but no enrolment and no resolver, the login fails as '
        'not-enrolled', () async {
      TomTotp2FAService.globalSettingSecretResolver = null;
      await installStoreWith(null);
      await expectLater(
        TomTotp2FAService().issueChallenge(context()),
        throwsA(
          isA<LoginException>()
              .having((e) => e.key, 'key', 'login.error.2fa.not-enrolled'),
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
          secretData: const {
            TomTotp2FAService.secretDataKey: _rfcSecretBase32,
          },
        ),
      );
      TomBean.withType(Tom2FAEnrolmentStore, store);

      expect(
        await TomTotp2FAService()
            .verifySubmission(context(), submission(currentCode())),
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

    test('rejects a code of the wrong length without hashing anything',
        () async {
      expect(
        await TomTotp2FAService().verifySubmission(context(), submission('12')),
        isFalse,
      );
    });

    test('tolerates one time step of clock skew either way', () async {
      TomTotp2FAService.globalSettingWindowSteps = 1;
      final adaptor = TomTotp2FAService();
      expect(
        await adaptor.verifySubmission(context(), submission(currentCode(stepsOff: -1))),
        isTrue,
      );
      expect(
        await adaptor.verifySubmission(context(), submission(currentCode(stepsOff: 1))),
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

    Tom2FAContext context() => Tom2FAContext(
          principal: _principalWithId(7),
          application: 'console',
        );

    /// The base32 secret the offer is asking the user to install.
    String offeredSecret(Tom2FAEnrolmentOffer offer) =>
        offer.enrolmentData[TomTotp2FAService.secretDataKey] as String;

    // ------------------------------------------------------------------
    // The round trip
    // ------------------------------------------------------------------

    test('a generated secret round-trips base32 and its code confirms',
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
    });

    // The confirmed secret must be the one the *verifier* will later resolve,
    // not merely one that agrees with itself.
    test('the confirmed enrolment answers a real challenge afterwards',
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
              expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            ),
          ),
        ),
        isTrue,
      );
    });

    test('confirmation tolerates the same clock skew the verifier does',
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
    });

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
          isA<LoginException>().having(
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
          isA<LoginException>().having(
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
    test('confirmation derives the code from enrolmentData, never clientData',
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
        throwsA(isA<LoginException>()),
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
    });

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
      expect(
        TomTotp.decodeBase32(offeredSecret(offer)),
        hasLength(32),
      );
    });

    // ------------------------------------------------------------------
    // The provisioning URI
    // ------------------------------------------------------------------

    test("the otpauth URI parses and carries this verifier's own policy",
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
    });

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
      expect(
        offer.clientData['digits'],
        TomTotp2FAService.globalSettingDigits,
      );
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
    // The default, which must be today's behaviour and nothing else
    // -------------------------------------------------------------------------

    test('the flag policy reads an exempt principal as disabled', () async {
      final decision = await const TomPrincipalFlag2FAPolicy()
          .decideFor(contextFor());

      expect(decision.requirement, Tom2FARequirement.disabled);
      expect(decision.isSatisfiedWithoutFactor, isTrue);
      expect(decision.allowedMechanisms, isEmpty);
    });

    test('the flag policy reproduces requires2FA and twoFactorType', () async {
      final decision = await const TomPrincipalFlag2FAPolicy()
          .decideFor(contextFor(requires2FA: true, twoFactorType: 'totp'));

      expect(decision.requirement, Tom2FARequirement.required);
      expect(decision.allowedMechanisms, ['totp']);
    });

    // The dead end the flags cannot express: required, but naming nothing. The
    // policy must not invent a mechanism — it reports the requirement with no
    // way to satisfy it, and the login is what turns that into a clear refusal.
    test('a principal that requires a factor but names none allows nothing',
        () async {
      final decision = await const TomPrincipalFlag2FAPolicy()
          .decideFor(contextFor(requires2FA: true));

      expect(decision.requirement, Tom2FARequirement.required);
      expect(decision.allowedMechanisms, isEmpty);
    });

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
        (await policy.decideFor(contextFor(roles: ['staff', 'admin'])))
            .requirement,
        Tom2FARequirement.required,
      );
      expect(
        (await policy.decideFor(contextFor(roles: ['admin', 'staff'])))
            .requirement,
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

      final decision =
          await policy.decideFor(contextFor(roles: ['service-account', 'admin']));
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
    test('offerable mechanisms are the permitted ones that are registered',
        () async {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      final policy = TomRole2FAPolicy(
        defaultRequirement: Tom2FARequirement.required,
        mechanisms: ['sms', 'fake', 'push'],
      );

      final decision = await policy.decideFor(contextFor());
      expect(decision.allowedMechanisms, ['sms', 'fake', 'push']);
      expect(decision.offerableMechanisms, ['fake']);
    });

    test('a policy naming only unregistered mechanisms offers nothing',
        () async {
      Tom2FARegistry.register('fake', _FakeAdaptor());
      final policy = TomRole2FAPolicy(
        defaultRequirement: Tom2FARequirement.required,
        mechanisms: ['sms'],
      );

      final decision = await policy.decideFor(contextFor());
      expect(decision.allowedMechanisms, ['sms'], reason: 'still permitted');
      expect(decision.offerableMechanisms, isEmpty, reason: 'but unusable');
    });

    test('a decision cannot be edited after the policy made it', () async {
      final decision = await const TomPrincipalFlag2FAPolicy()
          .decideFor(contextFor(requires2FA: true, twoFactorType: 'totp'));

      expect(() => decision.allowedMechanisms.add('sms'), throwsUnsupportedError);
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
      final public =
          TomClientJwtToken(pass1.authorizationToken, decrypt: false);
      expect(public.payload, isNot(contains(Tom2FAClaims.verificationData)));
    });

    test('pass 2 hands the adaptor the challenge and its own blob back',
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
    });

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

      final principal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(completed);
      expect(principal.authenticated, isTrue);
      expect(principal.requires2FA, isFalse);
    });

    // The todo's actual acceptance criterion: after the second factor, the
    // client holds exactly the token a pass1-only login would have given it.
    test('the completed token is the one a 2FA-free login would have issued',
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
    });

    test('a wrong answer is retryable and spends exactly one attempt', () async {
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
    });

    test('the attempt counter cannot be rewound within one challenge', () async {
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
    });

    test('an exhausted challenge is refused without consulting the adaptor',
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
    });

    test('a lapsed challenge is refused without consulting the adaptor',
        () async {
      final lapsed = Tom2FAChallenge(
        type: 'fake',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: _tokenCarrying(lapsed),
      );

      expect(result.error, 'login.error.2fa.expired');
      expect(result.authorizationToken, isEmpty);
      expect(adaptor.verified, 0);
    });

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

    test('pass 2 outside a request zone and without a token fails cleanly',
        () async {
      final result = await server.authenticatePass2(_message());
      expect(result.error, 'login.error.2fa.no-challenge');
      expect(result.authenticationToken, isEmpty);
    });

    test('a challenge for an unregistered mechanism cannot be answered',
        () async {
      final token = await issuedChallenge();
      Tom2FARegistry.reset();

      final result = await server.authenticatePass2(
        _message(password: '424242'),
        challengeToken: token,
      );
      expect(result.error, 'login.error.2fa.unsupported-mechanism');
    });

    test('pass 1 fails when the account names a mechanism nobody implements',
        () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true, twoFactorType: 'carrier-pigeon');
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
      expect(result.authenticationToken, isEmpty);
    });

    test('pass 1 fails when the account names no mechanism at all', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService(requires2FA: true);
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
    });

    // An adaptor that cannot challenge this user (no enrolled device) must fail
    // the login rather than show a prompt that can never be satisfied.
    test('a LoginException from the adaptor surfaces its own key', () async {
      Tom2FARegistry.reset();
      Tom2FARegistry.register(
        'fake',
        _FakeAdaptor(
          failIssueWith: LoginException(
            'login.error.2fa.not-enrolled',
            'nothing enrolled',
          ),
        ),
      );
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.not-enrolled');
      expect(result.authorizationToken, isEmpty);
    });

    test('an unexpected adaptor fault is masked behind the generic error',
        () async {
      Tom2FARegistry.reset();
      Tom2FARegistry.register(
        'fake',
        _FakeAdaptor(failIssueWith: StateError('gateway down')),
      );
      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.unknown');
    });

    test('a principal that owes no factor logs in on pass 1 alone', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _StubAuthService();
      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isFalse);
      expect(adaptor.issued, 0);
      expect(
        TomClientJwtToken(result.authorizationToken, decrypt: false)
            .payload?[Tom2FAClaims.requires2FA],
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
    test('an installed policy can require a factor the principal does not',
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
    });

    test('an installed policy can exempt a principal whose flag requires one',
        () async {
      // Flags say required (the group default). The policy says nobody is.
      TomBean.withType(Tom2FAPolicy, TomRole2FAPolicy());

      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isFalse);
      expect(adaptor.issued, 0, reason: 'no challenge should be issued');
    });

    // The permitted-but-not-installed case, reached through a policy rather than
    // through a principal naming a mechanism nobody implements. Same refusal,
    // because the login rejects on what is *offerable*, not on where the
    // permission came from.
    test('a policy naming only unregistered mechanisms fails the login',
        () async {
      TomBean.withType(
        Tom2FAPolicy,
        TomRole2FAPolicy(
          defaultRequirement: Tom2FARequirement.required,
          mechanisms: ['sms'],
        ),
      );

      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
      expect(result.authenticationToken, isEmpty);
      expect(adaptor.issued, 0);
    });

    test('the login challenges with the policy\'s first offerable mechanism',
        () async {
      TomBean.withType(
        Tom2FAPolicy,
        TomRole2FAPolicy(
          defaultRequirement: Tom2FARequirement.required,
          // 'sms' is permitted but not installed here, so preference order has
          // to survive the intersection for 'fake' to be the one challenged.
          mechanisms: ['sms', 'fake'],
        ),
      );

      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.twoFactorType, 'fake');
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
    }) =>
        TomBean.withType(
          Tom2FAPolicy,
          TomRole2FAPolicy(
            defaultRequirement: requirement,
            mechanisms: mechanisms,
          ),
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
    }) =>
        store.store(
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

    // The mechanism used to be read off `principal.twoFactorType`, which can
    // name only one factor and is set by whichever adaptor built the principal.
    // The store is the authority now, so a user holding several factors is
    // challenged for the one they nominated.
    test('the challenge follows the primary enrolment, not the policy order',
        () async {
      await alreadyEnrolled(type: 'fake', id: 'old-token', isPrimary: false);
      await alreadyEnrolled(id: 'phone');
      policy(Tom2FARequirement.required, mechanisms: ['fake', 'app']);

      final result = await server.authenticatePass1(_message());

      expect(result.twoFactorType, 'app',
          reason: "'fake' comes first in the policy but is not primary");
      expect(unenrollable.issued, 0);
      expect(enrollable.issued, 1);
    });

    // ------------------------------------------------------------------
    // Shape 2 — enforced, not yet enrolled
    // ------------------------------------------------------------------

    test('an unenrolled user is offered the method list, not locked out',
        () async {
      policy(Tom2FARequirement.required);

      final (result, _) = await login();

      expect(result.error, isEmpty, reason: 'this used to be a hard failure');
      expect(result.requires2FAEnrolment, isTrue);
      expect(result.requires2FA, isFalse,
          reason: 'enrolment is its own state, not an overloaded challenge');
      expect(result.twoFactorEnrolmentSkippable, isFalse);
      expect(result.availableTwoFactorMethods.map((m) => m.type), ['app']);
      // Resource-keyed, so the chooser has something to render in the user's
      // own language rather than a mechanism key.
      final method = result.availableTwoFactorMethods.single;
      expect(method.displayNameKey, 'two_factor.app.name');
      expect(method.descriptionKey, 'two_factor.app.description');
      expect(method.iconKey, 'two_factor.app.icon');
      expect(enrollable.issued, 0, reason: 'nothing to challenge yet');
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

    test('an interim enrolment token grants no session', () async {
      policy(Tom2FARequirement.required);

      final (_, token) = await login();
      final principal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(token);

      expect(principal.username, 'alice');
      expect(principal.authenticated, isFalse);
    });

    test('the whole enrol-on-first-login round trip issues a session',
        () async {
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
      final publicClaims =
          TomClientJwtToken(begun.authorizationToken, decrypt: false).payload;
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
        TomBearerAuthentication.convertTokenPayloadToPrincipal(session)
            .authenticated,
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

    test('an optional policy offers enrolment and lets it be declined',
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
    });

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
    test('grace logins make a required offer declinable, and are spent',
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
    });

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

      expect(graced.graceSpent, 0,
          reason: 'an optional factor was never owed, so nothing was postponed');
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
    test('with no store installed the login keeps the challenge path',
        () async {
      TomBean.resetBeanContext();
      policy(Tom2FARequirement.required);

      final result = await server.authenticatePass1(_message());

      expect(result.error, isEmpty);
      expect(result.requires2FA, isTrue);
      expect(result.requires2FAEnrolment, isFalse);
      expect(enrollable.issued, 1);
    });

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

    test('a wrong confirmation stores nothing and leaves the login incomplete',
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
    });

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

    test('an enrolment pass outside a request zone fails cleanly', () async {
      final result = await server.beginTwoFactorEnrolment(
        _message(password: 'app'),
      );

      expect(result.error, 'login.error.2fa.no-enrolment');
      expect(result.authenticationToken, isEmpty);
    });

    // The offer is only honest if the factor it advertises can be recorded.
    test('a required user with nothing enrollable still fails the login',
        () async {
      policy(Tom2FARequirement.required, mechanisms: ['fake']);

      final result = await server.authenticatePass1(_message());

      expect(result.error, 'login.error.2fa.unsupported-mechanism');
      expect(result.authorizationToken, isEmpty);
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
  final (publicInfo, privateInfo) =
      TomBearerAuthentication.convertPrincipalToTokenPayload(
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
