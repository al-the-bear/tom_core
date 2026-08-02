/// Widget tests for the framework-owned second-factor UI.
///
/// The three things worth pinning down here are the three the framework
/// promises and an application must not have to re-decide:
///
/// * the **chooser** lists exactly the offered mechanisms this build can
///   render — no more (a key with no panel would strand the user) and no fewer;
/// * the **skip affordance** appears if and only if the *server* said declining
///   is permitted; and
/// * the **TOTP panels** show the secret both ways (scannable and typable) and
///   hand back what the user typed without interpreting it.
///
/// Every assertion goes through a widget key rather than through displayed
/// text, because the text is resource-resolved and a deployment is free to
/// change all of it. The one place text is asserted is the chooser's labels,
/// where the *point* is that they came from the bundle (G-RES-5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  // A bundle covering every key the flow and the TOTP panels resolve, with
  // values distinct enough that a test asserting one cannot accidentally match
  // another.
  TomTextResourceProvider bundle() => TomTextResourceProvider.from({
        Tom2FATexts.chooseTitle: 'Choose a method',
        Tom2FATexts.chooseIntro: 'Pick how you want to confirm it is you.',
        Tom2FATexts.enrolTitle: 'Set it up',
        Tom2FATexts.challengeTitle: 'Confirm it is you',
        Tom2FATexts.skip: 'Not now',
        Tom2FATexts.skipSpendsGrace: 'You can only skip a few more times.',
        Tom2FATexts.cancel: 'Back to sign-in',
        Tom2FATexts.attemptsRemaining: '{count} tries left',
        Tom2FATexts.noRenderableMethods: 'This app cannot set any of these up.',
        Tom2FATexts.totpEnrolIntro: 'Scan this with your authenticator app.',
        Tom2FATexts.totpEnrolQrLabel: 'Enrolment QR code',
        Tom2FATexts.totpEnrolManualEntry: 'Or type this key:',
        Tom2FATexts.totpEnrolCodeLabel: 'Code from the app',
        Tom2FATexts.totpEnrolSubmit: 'Finish set-up',
        Tom2FATexts.totpChallengeCodeLabel: 'Authenticator code',
        Tom2FATexts.totpChallengeSubmit: 'Sign in',
        // Descriptors the chooser falls back to when the server sent none.
        'two_factor.totp.name': 'Authenticator app',
        'two_factor.totp.description': 'A code from an app on your phone.',
        'two_factor.sms.name': 'Text message',
        'two_factor.sms.description': 'A code sent to your phone.',
      });

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(bundle());
    // Start from a bare registry so a test asserting "this build cannot render
    // that mechanism" is not silently rescued by a leftover registration.
    Tom2FAClientRegistry.reset();
  });

  tearDown(Tom2FAClientRegistry.reset);

  Future<void> pump(WidgetTester tester, Tom2FAFlowController controller) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Tom2FAFlowPanel(controller: controller),
            ),
          ),
        ),
      );

  group('the chooser', () {
    testWidgets('lists every offered mechanism this build can render',
        (tester) async {
      Tom2FAClientRegistry.register(const _SmsMechanism());
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            offeredTypes: const ['totp', 'sms'],
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-chooser')), findsOneWidget);
      // TOTP is registered by the panel itself; SMS by this test.
      expect(find.byKey(const Key('tom-2fa-method-totp')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-method-sms')), findsOneWidget);
      // Labelled from the bundle, not from a literal in the framework.
      expect(find.text('Authenticator app'), findsOneWidget);
      expect(find.text('A code sent to your phone.'), findsOneWidget);
    });

    testWidgets('omits a mechanism no panel is registered for', (tester) async {
      // A server upgraded ahead of its clients offers a key we have no panel
      // for. Listing it would take the user to a blank step.
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            offeredTypes: const ['totp', 'webauthn'],
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-method-totp')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-method-webauthn')), findsNothing);
      expect(find.byKey(const Key('tom-2fa-no-methods')), findsNothing);
    });

    testWidgets('says so when it can render none of them', (tester) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['webauthn']),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-no-methods')), findsOneWidget);
      expect(find.text('This app cannot set any of these up.'), findsOneWidget);
    });

    testWidgets('tapping a mechanism asks the controller to begin it',
        (tester) async {
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
      );
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();

      expect(controller.chosen, ['totp']);
    });

    testWidgets('prefers the descriptor the server sent over the convention',
        (tester) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
          // Not const: a descriptor is a wire DTO with mutable fields (G-DTO-2).
          methods: [
            Tom2FAMethodDescriptor(
              type: 'totp',
              displayNameKey: 'vendor.totp.name',
              descriptionKey: 'vendor.totp.description',
            ),
          ],
        ),
      );

      // Unknown keys resolve to themselves, which is exactly how a missing
      // translation should look — and proves the server's keys were used.
      expect(find.text('vendor.totp.name'), findsOneWidget);
      expect(find.text('Authenticator app'), findsNothing);
    });
  });

  group('the skip affordance', () {
    testWidgets('is absent when the server did not permit declining',
        (tester) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-skip')), findsNothing);
    });

    testWidgets('is present, and silent about cost, when skipping is free',
        (tester) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            offeredTypes: const ['totp'],
            skippable: true,
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-skip')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-skip-cost')), findsNothing);
    });

    testWidgets('warns when declining spends a grace login', (tester) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            offeredTypes: const ['totp'],
            skippable: true,
            skipSpendsGrace: true,
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-skip-cost')), findsOneWidget);
      expect(
        find.text('You can only skip a few more times.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping it declines through the controller', (tester) async {
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(
          offeredTypes: const ['totp'],
          skippable: true,
        ),
      );
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-skip')));
      await tester.pumpAndSettle();

      expect(controller.skipped, 1);
    });
  });

  group('the TOTP enrolment panel', () {
    Tom2FAPendingEnrolment offer({int? digits}) => Tom2FAPendingEnrolment(
          type: 'totp',
          offeredTypes: const ['totp'],
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          attemptsAllowed: 3,
          clientData: {
            'otpauthUri': 'otpauth://totp/Tom:alice?secret=JBSWY3DPEHPK3PXP',
            'secret': 'JBSWY3DPEHPK3PXP',
            if (digits != null) 'digits': digits,
          },
        );

    testWidgets('shows the secret both scannable and typable', (tester) async {
      await pump(tester, _FakeController(enrolment: offer()));

      expect(find.byKey(const Key('tom-2fa-totp-enrolment')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-totp-qr')), findsOneWidget);
      // Grouped in fours: the typed-by-hand fallback is where enrolment
      // actually fails, and an ungrouped 16-character string is where users
      // give up.
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
    });

    testWidgets('hands the typed code to the controller unmodified',
        (tester) async {
      final controller = _FakeController(enrolment: offer());
      await pump(tester, controller);

      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('tom-2fa-totp-enrolment-submit')));
      await tester.pumpAndSettle();

      expect(controller.confirmed, ['123456']);
    });

    testWidgets('sizes the field to the width the server declared',
        (tester) async {
      await pump(tester, _FakeController(enrolment: offer(digits: 8)));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-enrolment-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, 8);
    });

    testWidgets('falls back to six digits when the server declared none',
        (tester) async {
      await pump(tester, _FakeController(enrolment: offer()));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-enrolment-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, TomTotp.defaultDigits);
    });

    testWidgets('renders nothing to scan when the URI is missing',
        (tester) async {
      // A server-side omission must degrade to a blank code beside a usable
      // manual-entry string, not to a crashed login screen.
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            type: 'totp',
            offeredTypes: const ['totp'],
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            clientData: const {'secret': 'JBSWY3DP'},
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-totp-qr')), findsOneWidget);
      expect(find.text('JBSW Y3DP'), findsOneWidget);
    });
  });

  group('the TOTP challenge panel', () {
    testWidgets('answers the challenge through the controller', (tester) async {
      final controller = _FakeController(
        challenge: Tom2FAChallenge(
          type: 'totp',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          attemptsAllowed: 3,
          attempt: 1,
        ),
      );
      await pump(tester, controller);

      expect(find.byKey(const Key('tom-2fa-totp-challenge')), findsOneWidget);
      // The attempt budget belongs to the frame, not to the mechanism.
      expect(find.text('2 tries left'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-challenge-code')),
        '654321',
      );
      await tester.tap(find.byKey(const Key('tom-2fa-totp-challenge-submit')));
      await tester.pumpAndSettle();

      expect(controller.answered, ['654321']);
    });

    testWidgets('outranks an enrolment owed at the same time', (tester) async {
      // Holding a factor and owing a new one means proving the held one first;
      // otherwise enrolment is a way around the factor it strengthens.
      await pump(
        tester,
        _FakeController(
          challenge: Tom2FAChallenge(
            type: 'totp',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
          enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-challenge')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-chooser')), findsNothing);
    });
  });

  group('the shared frame', () {
    testWidgets('renders nothing when no second factor is owed',
        (tester) async {
      await pump(tester, _FakeController());

      expect(find.byKey(const Key('tom-2fa-title')), findsNothing);
      expect(find.byKey(const Key('tom-2fa-cancel')), findsNothing);
    });

    testWidgets('shows a failed move through the controller\'s own wording',
        (tester) async {
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
        failure: StateError('nope'),
      );
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tom-2fa-error')), findsOneWidget);
      expect(find.text('described: Bad state: nope'), findsOneWidget);
    });

    testWidgets('cancelling abandons the flow', (tester) async {
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
      );
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-cancel')));
      await tester.pumpAndSettle();

      expect(controller.cancelled, 1);
    });
  });

  group('the registry', () {
    test('an application registration replaces the shipped mechanism', () {
      Tom2FAClientRegistry.register(const _SmsMechanism(type: 'totp'));
      Tom2FAFlowPanel.registerBuiltInMechanisms();

      expect(Tom2FAClientRegistry.find('totp'), isA<_SmsMechanism>());
    });

    test('the shipped TOTP mechanism installs itself', () {
      Tom2FAFlowPanel.registerBuiltInMechanisms();

      expect(Tom2FAClientRegistry.has('totp'), isTrue);
      expect(Tom2FAClientRegistry.types, contains('totp'));
    });

    test('a mechanism describes itself by the scoped convention', () {
      const mechanism = TomTotp2FAClientMechanism();

      expect(mechanism.descriptor.displayNameKey, 'two_factor.totp.name');
      expect(mechanism.descriptor.type, 'totp');
    });
  });

  group('TOTP client helpers', () {
    test('groupSecret splits into fours and leaves a short tail alone', () {
      expect(TomTotp2FAClientMechanism.groupSecret('ABCDEFGHIJ'),
          'ABCD EFGH IJ');
      expect(TomTotp2FAClientMechanism.groupSecret('AB'), 'AB');
      expect(TomTotp2FAClientMechanism.groupSecret(''), '');
    });

    test('digitsOf reads an int, a numeric string, or the RFC default', () {
      expect(TomTotp2FAClientMechanism.digitsOf({'digits': 8}), 8);
      // Servers that JSON-encode numbers as strings are a real thing.
      expect(TomTotp2FAClientMechanism.digitsOf({'digits': '7'}), 7);
      expect(TomTotp2FAClientMechanism.digitsOf({}), TomTotp.defaultDigits);
      expect(TomTotp2FAClientMechanism.digitsOf({'digits': 0}),
          TomTotp.defaultDigits);
      expect(TomTotp2FAClientMechanism.digitsOf({'digits': 'six'}),
          TomTotp.defaultDigits);
    });
  });
}

/// A controller that records the moves the panel made, and optionally fails.
class _FakeController extends Tom2FAFlowController {
  _FakeController({
    this.enrolment,
    this.challenge,
    this.methods = const [],
    this.failure,
  });

  final Tom2FAPendingEnrolment? enrolment;
  final Tom2FAChallenge? challenge;
  final List<Tom2FAMethodDescriptor> methods;
  final Object? failure;

  final List<String> chosen = [];
  final List<String> confirmed = [];
  final List<String> answered = [];
  int skipped = 0;
  int cancelled = 0;

  @override
  Tom2FAPendingEnrolment? get pendingEnrolment => enrolment;

  @override
  Tom2FAChallenge? get pendingChallenge => challenge;

  @override
  List<Tom2FAMethodDescriptor> get availableMethods => methods;

  @override
  Future<void> chooseMethod(String type) async {
    chosen.add(type);
    if (failure != null) throw failure!;
  }

  @override
  Future<void> confirmEnrolment(String code) async {
    confirmed.add(code);
    if (failure != null) throw failure!;
  }

  @override
  Future<void> skipEnrolment() async {
    skipped++;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> submitSecondFactor(String code) async {
    answered.add(code);
    if (failure != null) throw failure!;
  }

  @override
  void cancel() => cancelled++;

  @override
  String describeError(Object error) => 'described: $error';
}

/// A second mechanism, so the chooser is exercised with more than one entry and
/// the "an application may replace a built-in" rule has something to replace
/// TOTP with.
class _SmsMechanism extends Tom2FAClientMechanism {
  const _SmsMechanism({String type = 'sms'}) : super(type);

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) =>
      const SizedBox(key: Key('sms-enrolment'));

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) =>
      const SizedBox(key: Key('sms-challenge'));
}
