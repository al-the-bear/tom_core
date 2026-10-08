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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';
// For the icon adapter the chooser resolves `iconKey` through. Not re-exported
// by this package's barrel, and should not be — it belongs to the widget
// library, and an application configures it there.
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Every string the panel currently renders, in tree order.
///
/// Used to compare two renderings of one panel that differ only in a
/// `clientData` key: equality is the assertion that the extra key changed
/// nothing a reader can see. Text rather than widget keys, because a panel that
/// *started* reading a key would most likely surface it as a line rather than
/// as a newly keyed widget.
List<String> _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .toList();

/// The whole seconds the challenge panel's countdown currently shows.
///
/// Read out of the rendered line rather than off the state, so what is asserted
/// is what a user sees — including that the bundle's `{seconds}` placeholder
/// was substituted at all.
int _countdownSeconds(WidgetTester tester) {
  final line = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const Key('tom-2fa-totp-challenge-countdown')),
      matching: find.byType(Text),
    ),
  );
  final text = line.data ?? line.textSpan?.toPlainText() ?? '';
  final match = RegExp(r'Good for another (\d+) s').firstMatch(text);
  expect(
    match,
    isNotNull,
    reason:
        'the countdown line reads "$text", which is not the bundle text '
        'with a number in it',
  );
  return int.parse(match!.group(1)!);
}

/// An `otpauth://` URI larger than any QR code can hold.
///
/// Shaped like the real thing rather than like arbitrary padding, because the
/// realistic way to exceed the ceiling is not a hostile server but an ordinary
/// one whose issuer and account label are long — and the label is exactly the
/// part a deployment fills in and can get wrong. The widest code at the
/// correction level the panel uses holds 2331 bytes; this is roughly triple.
String _oversizedUri() {
  final label = 'a' * 3000;
  return 'otpauth://totp/$label?secret=JBSWY3DPEHPK3PXP&issuer=$label';
}

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
    Tom2FATexts.enrolmentExpired: 'This set-up has expired. Start again.',
    Tom2FATexts.challengeExpired: 'This sign-in has expired. Start again.',
    Tom2FATexts.unrenderableChallenge:
        'This sign-in method needs a newer version of the app.',
    Tom2FATexts.totpEnrolIntro: 'Scan this with your authenticator app.',
    Tom2FATexts.totpEnrolQrLabel: 'Enrolment QR code',
    Tom2FATexts.totpEnrolManualEntry: 'Or type this key:',
    Tom2FATexts.totpEnrolCodeLabel: 'Code from the app',
    Tom2FATexts.totpEnrolSubmit: 'Finish set-up',
    Tom2FATexts.totpChallengeCodeLabel: 'Authenticator code',
    Tom2FATexts.totpChallengeSubmit: 'Sign in',
    Tom2FATexts.totpChallengeExpiresIn: 'Good for another {seconds} s',
    Tom2FATexts.totpChallengeCodeChanged: 'Your app shows a new code now.',
    Tom2FATexts.webauthnEnrolIntro: 'Create a passkey on this device.',
    Tom2FATexts.webauthnEnrolSubmit: 'Create passkey',
    Tom2FATexts.webauthnChallengeIntro: 'Use your passkey to continue.',
    Tom2FATexts.webauthnChallengeSubmit: 'Use passkey',
    Tom2FATexts.webauthnFailed: 'The passkey prompt did not complete.',
    // Descriptors the chooser falls back to when the server sent none.
    'two_factor.totp.name': 'Authenticator app',
    'two_factor.totp.description': 'A code from an app on your phone.',
    // An icon *name* for the adapter to resolve, not an asset path — the
    // two-step convention `tom_flutter_ui` uses everywhere else. SMS
    // deliberately has no icon entry, so one bundle covers both the
    // configured and the unconfigured mechanism.
    'two_factor.totp.icon': 'mSecurity',
    'two_factor.sms.name': 'Text message',
    'two_factor.sms.description': 'A code sent to your phone.',
  });

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(bundle());
    // Start from a bare registry so a test asserting "this build cannot render
    // that mechanism" is not silently rescued by a leftover registration.
    Tom2FAClientRegistry.reset();
    TomUIIcons.adapter = TomAllIconsAdapter();
    // The VM has no authenticator; a test that wants one installs a fake.
    TomWebAuthnPlatform.instance = const TomUnavailableWebAuthnPlatform();
  });

  tearDown(() {
    Tom2FAClientRegistry.reset();
    TomWebAuthnPlatform.instance = const TomUnavailableWebAuthnPlatform();
    // The adapter is process-wide, so a test that sets one must put it back —
    // otherwise "no adapter configured" can never be asserted again.
    TomUIIcons.reset();
  });

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
    testWidgets('lists every offered mechanism this build can render', (
      tester,
    ) async {
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

    // The descriptor carries three resource keys and the chooser renders all
    // three. `iconKey` resolves in two steps — the bundle maps the key to an
    // icon *name*, the adapter maps the name to an `IconData` — and every step
    // is allowed to come up empty, because a bundle that never mentions icons
    // is a legitimate deployment rather than a misconfiguration.

    Finder iconIn(String type) => find.descendant(
      of: find.byKey(Key('tom-2fa-method-$type')),
      matching: find.byType(Icon),
    );

    testWidgets('shows the descriptor icon beside a mechanism that has one', (
      tester,
    ) async {
      Tom2FAClientRegistry.register(const _SmsMechanism());
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            offeredTypes: const ['totp', 'sms'],
          ),
        ),
      );

      expect(iconIn('totp'), findsOneWidget);
      expect(
        tester.widget<Icon>(iconIn('totp')).icon,
        TomAllIconsAdapter().resolveIcon('mSecurity'),
        reason: 'the icon named by two_factor.totp.icon, not an arbitrary one',
      );

      // SMS has a label and a description in the bundle but no icon entry, so
      // its row is simply icon-less. An unknown key resolves to the key itself,
      // which is not an icon name — the row must not sprout a broken glyph.
      expect(iconIn('sms'), findsNothing);
    });

    testWidgets('renders no icon when the build configured no icon adapter', (
      tester,
    ) async {
      // An application that never calls `TomUIIcons.adapter =` still gets a
      // working chooser; the icon is an enhancement, never a requirement.
      TomUIIcons.reset();
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-method-totp')), findsOneWidget);
      expect(iconIn('totp'), findsNothing);
      // The row is still fully labelled — losing the icon loses nothing else.
      expect(find.text('Authenticator app'), findsOneWidget);
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

    testWidgets('tapping a mechanism asks the controller to begin it', (
      tester,
    ) async {
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
      );
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-method-totp')));
      await tester.pumpAndSettle();

      expect(controller.chosen, ['totp']);
    });

    testWidgets('prefers the descriptor the server sent over the convention', (
      tester,
    ) async {
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
    testWidgets('is absent when the server did not permit declining', (
      tester,
    ) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(offeredTypes: const ['totp']),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-skip')), findsNothing);
    });

    testWidgets('is present, and silent about cost, when skipping is free', (
      tester,
    ) async {
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
      expect(find.text('You can only skip a few more times.'), findsOneWidget);
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
    Tom2FAPendingEnrolment offer({int? digits, int? periodSeconds}) =>
        Tom2FAPendingEnrolment(
          type: 'totp',
          offeredTypes: const ['totp'],
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          attemptsAllowed: 3,
          clientData: {
            'otpauthUri': 'otpauth://totp/Tom:alice?secret=JBSWY3DPEHPK3PXP',
            'secret': 'JBSWY3DPEHPK3PXP',
            if (digits != null) 'digits': digits,
            if (periodSeconds != null) 'periodSeconds': periodSeconds,
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

    // Which account a QR code belongs to is invisible in the code itself, so
    // the caption beside it is the only thing distinguishing three work
    // accounts in one authenticator. The pair below pins both halves: it
    // appears when the application named the account, and it is *omitted*
    // rather than blank when it did not — the caption travels from the
    // controller through the flow into the mechanism's context, and a break
    // anywhere on that path shows up as a missing widget here.

    testWidgets('captions the code with the account the application named', (
      tester,
    ) async {
      await pump(
        tester,
        _FakeController(enrolment: offer(), label: 'ada@example.com'),
      );

      expect(find.byKey(const Key('tom-2fa-totp-account')), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
    });

    testWidgets('omits the caption entirely when no account was named', (
      tester,
    ) async {
      // Not "renders an empty caption": an empty one is a gap in the layout
      // that reads as a missing value rather than as an absent one.
      await pump(tester, _FakeController(enrolment: offer()));

      expect(find.byKey(const Key('tom-2fa-totp-account')), findsNothing);
      // The rest of the panel is untouched by the absence.
      expect(find.byKey(const Key('tom-2fa-totp-qr')), findsOneWidget);
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
    });

    testWidgets('hands the typed code to the controller unmodified', (
      tester,
    ) async {
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

    testWidgets('sizes the field to the width the server declared', (
      tester,
    ) async {
      await pump(tester, _FakeController(enrolment: offer(digits: 8)));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-enrolment-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, 8);
    });

    testWidgets('falls back to six digits when the server declared none', (
      tester,
    ) async {
      await pump(tester, _FakeController(enrolment: offer()));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-enrolment-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, TomTotp.defaultDigits);
    });

    testWidgets('renders nothing to scan when the URI is missing', (
      tester,
    ) async {
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

    testWidgets('renders nothing to scan when the URI will not fit a code', (
      tester,
    ) async {
      // A QR code has a hard capacity ceiling and a server can cross it
      // without doing anything wrong — a long issuer or account label is
      // enough. Arriving over the wire, that has to degrade the way a missing
      // URI already does rather than throw out of build: the manual-entry
      // string beside the code is a complete enrolment path on its own, so
      // there is a usable panel to fall back to and no reason to lose it.
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            type: 'totp',
            offeredTypes: const ['totp'],
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            clientData: {'otpauthUri': _oversizedUri(), 'secret': 'JBSWY3DP'},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('tom-2fa-totp-qr')), findsOneWidget);
      expect(find.text('JBSW Y3DP'), findsOneWidget);
    });

    testWidgets('ignores the periodSeconds the server sends', (tester) async {
      // The server writes four keys and the *enrolment* panel reads three: the
      // period drives the challenge panel's countdown and has nothing to say
      // here, where no code is outstanding. Rendering the real four-key payload
      // beside the three-key one pins that, so a countdown wandering onto this
      // panel has to fail here.
      await pump(tester, _FakeController(enrolment: offer(digits: 6)));
      final withoutPeriod = _renderedText(tester);

      await pump(
        tester,
        _FakeController(enrolment: offer(digits: 6, periodSeconds: 30)),
      );

      expect(_renderedText(tester), withoutPeriod);
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

    testWidgets('sizes from digits and counts down from periodSeconds', (
      tester,
    ) async {
      // The challenge payload the server actually sends is exactly these two
      // keys, and the panel now reads both: the first sizes the field, the
      // second drives the countdown.
      Tom2FAChallenge challenge({required int period}) => Tom2FAChallenge(
        type: 'totp',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        clientData: {'digits': 8, 'periodSeconds': period},
      );

      await pump(tester, _FakeController(challenge: challenge(period: 90)));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-challenge-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, 8);

      // The seconds shown are the ones left in the *current* step, so the
      // assertion is on the range rather than on a literal — the step this
      // test happens to start in is whichever one the clock is in.
      expect(_countdownSeconds(tester), inInclusiveRange(1, 90));
    });

    testWidgets('the countdown ticks, and wraps at the rollover', (
      tester,
    ) async {
      await pump(
        tester,
        _FakeController(
          challenge: Tom2FAChallenge(
            type: 'totp',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            clientData: {'periodSeconds': 3},
          ),
        ),
      );
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final first = _countdownSeconds(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(
        _countdownSeconds(tester),
        first == 1 ? 3 : first - 1,
        reason: 'a second passed and the countdown did not move',
      );

      // Two more seconds completes one whole period from where the panel
      // opened, and the number is back where it started: the authenticator has
      // rolled over and the next code has its full life ahead of it.
      await tester.pump(const Duration(seconds: 2));
      expect(_countdownSeconds(tester), first);
    });

    testWidgets('a rollover after typing says so, and only then', (
      tester,
    ) async {
      final controller = _FakeController(
        challenge: Tom2FAChallenge(
          type: 'totp',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          attemptsAllowed: 3,
          attempt: 1,
          clientData: {'periodSeconds': 3},
        ),
      );
      await pump(tester, controller);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      final changed = find.byKey(
        const Key('tom-2fa-totp-challenge-code-changed'),
      );

      // Not while the field is empty, however many rollovers pass. A panel
      // that announced every one of them would say something alarming every
      // thirty seconds to a user who is still reading their screen.
      await tester.pump(const Duration(seconds: 4));
      expect(changed, findsNothing);

      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-challenge-code')),
        '654321',
      );
      await tester.pump();
      expect(
        changed,
        findsNothing,
        reason: 'the code was typed in this step; nothing has overtaken it',
      );

      // Now the rollover, with something typed. This is the case the line
      // exists for.
      await tester.pump(const Duration(seconds: 4));
      expect(changed, findsOneWidget);

      // It does not clear the field — the user may still want to send it, and
      // wiping what they typed would be a second surprise on top of the first.
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-challenge-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '654321');

      // Retyping withdraws the warning: the code in the field belongs to this
      // step again.
      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-challenge-code')),
        '112233',
      );
      await tester.pump();
      expect(changed, findsNothing);
    });

    testWidgets('a stale code is still submitted, because the server takes it', (
      tester,
    ) async {
      // The line warns; it must not block. `TomTotp2FAService` accepts one step
      // either side of its own, so a code typed just before a rollover is still
      // good — a panel that refused to send it would enforce a policy stricter
      // than the one that judges it, and would cost the user the very attempt
      // it was trying to save.
      final controller = _FakeController(
        challenge: Tom2FAChallenge(
          type: 'totp',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          attemptsAllowed: 3,
          attempt: 1,
          clientData: {'periodSeconds': 3},
        ),
      );
      await pump(tester, controller);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-challenge-code')),
        '654321',
      );
      await tester.pump(const Duration(seconds: 4));
      expect(
        find.byKey(const Key('tom-2fa-totp-challenge-code-changed')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('tom-2fa-totp-challenge-submit')));
      await tester.pump();

      expect(controller.answered, ['654321']);
    });

    testWidgets('a mechanism this build cannot render says which problem it is', (
      tester,
    ) async {
      // A client behind its server: the principal enrolled through a newer
      // build and is now signing in from an older one. The chooser can filter a
      // mechanism it cannot render and offer the rest; a challenge has nothing
      // to filter — one outstanding challenge, one type, no alternative.
      //
      // So the message is its own, not the chooser's. "This app cannot set any
      // of these up" is about enrolment, and a user being *challenged* is not
      // setting anything up.
      await pump(
        tester,
        _FakeController(
          challenge: Tom2FAChallenge(
            type: 'webauthn',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            attemptsAllowed: 3,
            attempt: 1,
          ),
        ),
      );

      expect(
        find.byKey(const Key('tom-2fa-unrenderable-challenge')),
        findsOneWidget,
      );
      expect(
        find.text('This sign-in method needs a newer version of the app.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tom-2fa-no-methods')),
        findsNothing,
        reason:
            'the challenge stop is showing the chooser\'s enrolment message',
      );
    });

    testWidgets('and counts down no attempts, because none can be spent', (
      tester,
    ) async {
      // The budget was printed under the message either way, counting down
      // something the user has no way to use. It belongs beside a panel that
      // can spend one.
      await pump(
        tester,
        _FakeController(
          challenge: Tom2FAChallenge(
            type: 'webauthn',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            attemptsAllowed: 3,
            attempt: 1,
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-attempts')), findsNothing);
    });

    testWidgets('leaves cancel as the only exit, and no skip', (tester) async {
      // The shape of the dead end, pinned rather than described. The state is
      // not recoverable on this side, and the framework does not pretend
      // otherwise: there is one control, and it is the one that abandons the
      // sign-in. Skip is enrolment-only by construction — a challenge is owed,
      // not offered — so its absence here is the frame working, and asserting
      // it is what would catch a skip leaking onto a stop that must not have
      // one.
      final controller = _FakeController(
        challenge: Tom2FAChallenge(
          type: 'webauthn',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );
      await pump(tester, controller);

      expect(find.byKey(const Key('tom-2fa-skip')), findsNothing);
      expect(find.byKey(const Key('tom-2fa-cancel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tom-2fa-cancel')));
      await tester.pumpAndSettle();

      expect(controller.cancelled, 1);
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

  group('the passkey panels', () {
    Tom2FAPendingEnrolment passkeyOffer() => Tom2FAPendingEnrolment(
      type: 'webauthn',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      offeredTypes: const ['webauthn'],
      clientData: {
        'publicKey': const TomWebAuthnCreationOptions(
          rpId: 'example.com',
          rpName: 'Acme',
          userId: 'dXNlcg',
          userName: 'alice',
          userDisplayName: 'Alice',
          challenge: 'Y2hhbGxlbmdl',
        ).toJson(),
      },
    );

    Tom2FAChallenge passkeyChallenge() => Tom2FAChallenge(
      type: 'webauthn',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      clientData: {
        'publicKey': const TomWebAuthnRequestOptions(
          challenge: 'Y2hhbGxlbmdl',
          rpId: 'example.com',
          allowCredentialIds: ['Y3JlZA'],
        ).toJson(),
      },
    );

    testWidgets('enrolment hands the options over and submits the response', (
      tester,
    ) async {
      final passkeys = _FakePasskeys();
      TomWebAuthnPlatform.instance = passkeys;
      final controller = _FakeController(enrolment: passkeyOffer());
      await pump(tester, controller);

      expect(
        find.byKey(const Key('tom-2fa-webauthn-enrolment')),
        findsOneWidget,
      );
      expect(find.text('Create a passkey on this device.'), findsOneWidget);
      expect(passkeys.created, isEmpty, reason: 'only a tap may start it');

      await tester.tap(find.byKey(const Key('tom-2fa-webauthn-submit')));
      await tester.pumpAndSettle();

      expect(passkeys.created.single.rpId, 'example.com');
      expect(passkeys.created.single.challenge, 'Y2hhbGxlbmdl');
      final submitted = TomWebAuthnRegistrationResponse.fromSubmission(
        controller.confirmed.single,
      );
      expect(submitted?.id, 'bmV3LWNyZWQ');
    });

    testWidgets('a challenge signs and submits through the same seam', (
      tester,
    ) async {
      final passkeys = _FakePasskeys();
      TomWebAuthnPlatform.instance = passkeys;
      final controller = _FakeController(challenge: passkeyChallenge());
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-webauthn-submit')));
      await tester.pumpAndSettle();

      expect(passkeys.requested.single.allowCredentialIds, ['Y3JlZA']);
      final submitted = TomWebAuthnAuthenticationResponse.fromSubmission(
        controller.answered.single,
      );
      expect(submitted?.signature, 'c2ln');
    });

    testWidgets('a cancelled prompt says so and can be tried again', (
      tester,
    ) async {
      final passkeys = _FakePasskeys()..failNext = true;
      TomWebAuthnPlatform.instance = passkeys;
      final controller = _FakeController(challenge: passkeyChallenge());
      await pump(tester, controller);

      await tester.tap(find.byKey(const Key('tom-2fa-webauthn-submit')));
      await tester.pumpAndSettle();

      expect(controller.answered, isEmpty, reason: 'nothing to submit');
      expect(find.byKey(const Key('tom-2fa-webauthn-failed')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tom-2fa-webauthn-submit')));
      await tester.pumpAndSettle();

      expect(controller.answered, hasLength(1));
      expect(find.byKey(const Key('tom-2fa-webauthn-failed')), findsNothing);
    });

    testWidgets(
      'without an authenticator a passkey challenge is unrenderable',
      (tester) async {
        // The path the flow's find-returns-null handling was written for: the
        // server asks for a passkey, this target has no way to make one.
        await pump(tester, _FakeController(challenge: passkeyChallenge()));

        expect(
          find.byKey(const Key('tom-2fa-webauthn-challenge')),
          findsNothing,
        );
        expect(
          find.text('This sign-in method needs a newer version of the app.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('and is left out of the chooser', (tester) async {
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
    });
  });

  group('the challenge hint', () {
    // No shipped mechanism renders the hint — TOTP has nothing to hint, since
    // the user reads the code off the device in their hand. Delivering it is
    // still the flow's promise, and an undelivered field would only be noticed
    // by the first mechanism that needed it, long after the break. These two
    // hold the flow to the promise using a mechanism that does read it.

    Tom2FAChallenge smsChallenge({String hint = ''}) => Tom2FAChallenge(
      type: 'sms',
      hint: hint,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    String hintShown(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('sms-challenge-hint'))).data ??
        '';

    testWidgets('reaches the mechanism that renders it', (tester) async {
      Tom2FAClientRegistry.register(const _SmsMechanism());
      await pump(
        tester,
        _FakeController(challenge: smsChallenge(hint: '•••• •••• 4417')),
      );

      expect(find.byKey(const Key('sms-challenge')), findsOneWidget);
      expect(hintShown(tester), '•••• •••• 4417');
    });

    testWidgets('arrives empty, not null, when the server sent none', (
      tester,
    ) async {
      // The mechanism gets a `String` either way, so a panel can render it
      // unconditionally without a null check of its own — which is the reason
      // the field is non-nullable with an empty default rather than `String?`.
      Tom2FAClientRegistry.register(const _SmsMechanism());
      await pump(tester, _FakeController(challenge: smsChallenge()));

      expect(hintShown(tester), '');
    });
  });

  group('the shared frame', () {
    testWidgets('renders nothing when no second factor is owed', (
      tester,
    ) async {
      await pump(tester, _FakeController());

      expect(find.byKey(const Key('tom-2fa-title')), findsNothing);
      expect(find.byKey(const Key('tom-2fa-cancel')), findsNothing);
    });

    testWidgets('shows a failed move through the controller\'s own wording', (
      tester,
    ) async {
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

  group('a lapsed deadline is said out loud, not enforced', () {
    // Both wire types carry `isExpired` and the flow read neither, so a user who
    // left the screen open scanned a QR code that would not be accepted, typed a
    // code, and got a refusal from the server — correct behaviour arriving as
    // late as it possibly can.
    //
    // The flow says so now. What it does *not* do is refuse: `expiresAt` is an
    // absolute instant the server issued, the comparison is only as good as this
    // device's clock, and there is no skew window anywhere on the path. A flow
    // that hid the panel on its own verdict would lock a fast-clocked user out
    // of a login the server was still willing to complete.

    DateTime ago() =>
        DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    DateTime ahead() => DateTime.now().toUtc().add(const Duration(minutes: 5));

    testWidgets('a lapsed offer says so, and the panel stays', (tester) async {
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(type: 'totp', expiresAt: ago()),
      );
      await pump(tester, controller);

      expect(
        find.byKey(const Key('tom-2fa-enrolment-expired')),
        findsOneWidget,
      );
      expect(
        find.text('This set-up has expired. Start again.'),
        findsOneWidget,
      );

      // The panel is still there and still submits. The server is the authority
      // on a deadline it issued; this side only reports what it believes.
      expect(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('tom-2fa-totp-enrolment-submit')));
      await tester.pumpAndSettle();

      expect(controller.confirmed, ['123456']);
    });

    testWidgets('a live offer says nothing', (tester) async {
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(type: 'totp', expiresAt: ahead()),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-enrolment-expired')), findsNothing);
    });

    testWidgets('a lapsed challenge says so, and the panel stays', (
      tester,
    ) async {
      final controller = _FakeController(
        challenge: Tom2FAChallenge(type: 'totp', expiresAt: ago()),
      );
      await pump(tester, controller);

      expect(
        find.byKey(const Key('tom-2fa-challenge-expired')),
        findsOneWidget,
      );
      expect(
        find.text('This sign-in has expired. Start again.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-challenge-code')),
        '654321',
      );
      await tester.tap(find.byKey(const Key('tom-2fa-totp-challenge-submit')));
      await tester.pumpAndSettle();

      expect(controller.answered, ['654321']);
    });

    testWidgets('a live challenge says nothing', (tester) async {
      await pump(
        tester,
        _FakeController(
          challenge: Tom2FAChallenge(type: 'totp', expiresAt: ahead()),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-challenge-expired')), findsNothing);
    });

    testWidgets('the chooser never reports a lapse', (tester) async {
      // `Tom2FAPendingEnrolment.isExpired` answers false while the user is still
      // choosing, and the kernel says why: there is no generated material to go
      // stale, so a chooser left open is a UX question rather than a security
      // one. Asserted here because the flow calls `isExpired` on the same type
      // at two stops, and only one of them may ever report true.
      await pump(
        tester,
        _FakeController(
          enrolment: Tom2FAPendingEnrolment(
            offeredTypes: const ['totp'],
            expiresAt: ago(),
          ),
        ),
      );

      expect(find.byKey(const Key('tom-2fa-chooser')), findsOneWidget);
      expect(find.byKey(const Key('tom-2fa-enrolment-expired')), findsNothing);
    });

    testWidgets('a begun offer with no deadline reads as lapsed', (
      tester,
    ) async {
      // The kernel's backstop: a begun offer carrying no `expiresAt` answers
      // true, because it answers as the server would and a panel showing a live
      // confirmation form for a state the server refuses is worse than one
      // saying the offer lapsed. The flow inherits that reading rather than
      // second-guessing it, and this is where that inheritance is visible.
      await pump(
        tester,
        _FakeController(enrolment: Tom2FAPendingEnrolment(type: 'totp')),
      );

      expect(
        find.byKey(const Key('tom-2fa-enrolment-expired')),
        findsOneWidget,
      );
    });
  });

  group('the panel contexts grow one named field at a time', () {
    // What a mechanism can see is a decision, and the decision is that the
    // contexts are *values with named fields* — extended one field at a time,
    // each self-describing — rather than a map an application fills with
    // whatever it likes. `accountLabel` is the only application-supplied field
    // so far, and it was added because a user with three work accounts in one
    // authenticator cannot tell which QR code they are scanning.
    //
    // Two shapes were declined and are pinned here by their absence, because
    // either could be added in one line and neither would break a test that
    // only exercised behaviour:
    //
    //  * an untyped `applicationData` bag. There is already one opaque map on
    //    this path — the server's `clientData` — and a second with different
    //    provenance is how the two come to be confused.
    //  * `accountLabel` on the challenge context. Not forbidden, and probably
    //    right when a challenge screen wants to name the account it is for;
    //    just not yet asked for, and the discipline is that each field arrives
    //    with the case that needs it.

    /// The `final` fields [className] declares, read out of the module source.
    Set<String> fieldsOf(String className) {
      final source = File(
        'lib/src/tomclient/security/two_factor_client.dart',
      ).readAsStringSync();
      final start = source.indexOf('class $className {');
      expect(start, isNot(-1), reason: '$className is no longer declared');
      final body = source.substring(start, source.indexOf('\n}', start));
      return RegExp(
        r'^  final [\w<>?, ]+ (\w+);',
        multiLine: true,
      ).allMatches(body).map((match) => match.group(1)!).toSet();
    }

    test('the enrolment context carries exactly these fields', () {
      expect(
        fieldsOf('Tom2FAEnrolmentPanelContext'),
        unorderedEquals(<String>[
          // From the server's offer.
          'type', 'clientData',
          // From the application, through the controller.
          'accountLabel',
          // The flow's own.
          'onSubmit', 'busy',
        ]),
        reason:
            'the enrolment context gained or lost a field; the module '
            'documents what a mechanism may see, and an untyped application '
            'bag in particular was declined',
      );
    });

    test('the challenge context carries exactly these fields', () {
      expect(
        fieldsOf('Tom2FAChallengePanelContext'),
        unorderedEquals(<String>[
          'type', 'clientData',
          // The mechanism's own, from the server.
          'hint', 'attemptsRemaining',
          'onSubmit', 'busy',
        ]),
        reason:
            'the challenge context gained or lost a field. It deliberately '
            'carries nothing the application supplied — not because a '
            'challenge screen may not, but because none has needed it, and '
            'adding one is a decision to take rather than to drift into',
      );
    });

    test('no context carries a second opaque map', () {
      // The specific shape that was declined, asserted with its own reason so
      // a failure says which decision is being reversed rather than only that
      // a field appeared.
      for (final className in [
        'Tom2FAEnrolmentPanelContext',
        'Tom2FAChallengePanelContext',
      ]) {
        final source = File(
          'lib/src/tomclient/security/two_factor_client.dart',
        ).readAsStringSync();
        final start = source.indexOf('class $className {');
        final body = source.substring(start, source.indexOf('\n}', start));
        final maps = RegExp(
          r'^  final Map<[^>]*> (\w+);',
          multiLine: true,
        ).allMatches(body).map((match) => match.group(1)!).toList();
        expect(
          maps,
          ['clientData'],
          reason:
              '$className declares a map beside the server\'s `clientData`. '
              'One opaque map on this path is the server\'s payload; a second '
              'with different provenance is how the two get confused',
        );
      }
    });

    testWidgets('the one application field reaches the panel from the '
        'controller, and only the enrolment one', (tester) async {
      // The provenance the field table above describes, exercised: the label
      // travels controller → flow → context → panel. The challenge stop is
      // shown with the same controller and the same label, and the caption is
      // nowhere — which is the asymmetry stated as behaviour rather than as a
      // missing field.
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(type: 'totp'),
        label: 'ada@example.com',
      );
      await pump(tester, controller);
      expect(find.text('ada@example.com'), findsOneWidget);

      await pump(
        tester,
        _FakeController(
          challenge: Tom2FAChallenge(
            type: 'totp',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
          label: 'ada@example.com',
        ),
      );
      expect(find.text('ada@example.com'), findsNothing);
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

    test('and is the only one where no authenticator exists', () {
      // `contains` above would go on passing beside a second built-in. On a
      // target with no platform authenticator the framework installs TOTP and
      // nothing else, so a passkey offer is left out of the chooser rather
      // than shown as a button that can only fail.
      Tom2FAFlowPanel.registerBuiltInMechanisms();

      expect(
        Tom2FAClientRegistry.types,
        ['totp'],
        reason:
            'a target without a platform authenticator now gets a second '
            'built-in mechanism; the documents say passkeys are registered '
            'only where one exists',
      );
    });

    test('and passkeys join it where an authenticator exists', () {
      TomWebAuthnPlatform.instance = _FakePasskeys();
      Tom2FAFlowPanel.registerBuiltInMechanisms();

      expect(Tom2FAClientRegistry.types, ['totp', 'webauthn']);
      expect(
        Tom2FAClientRegistry.find('webauthn'),
        isA<TomWebAuthn2FAClientMechanism>(),
      );
    });

    test('and lib/ implements exactly those two', () {
      // The registry is one way to ship a mechanism; declaring a class is the
      // other, and a mechanism declared but left unregistered would still be
      // part of the package's surface and still make the documented set
      // false. Read from the sources, because there is nothing at run time
      // that enumerates a type nobody instantiated.
      final declared = <String>[];
      for (final file
          in Directory('lib/src/tomclient/security')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        declared.addAll(
          RegExp(
            r'^class (\w+) extends Tom2FAClientMechanism',
            multiLine: true,
          ).allMatches(file.readAsStringSync()).map((match) => match.group(1)!),
        );
      }

      expect(
        declared..sort(),
        ['TomTotp2FAClientMechanism', 'TomWebAuthn2FAClientMechanism'],
        reason:
            'lib/ declares a mechanism beside TOTP and passkeys; the '
            'documented set — TOTP everywhere, passkeys where an '
            'authenticator exists — has to be revisited with it',
      );
    });

    testWidgets('a registration mid-flow takes the screen over', (
      tester,
    ) async {
      // The flow resolves the mechanism on every build rather than caching it
      // at the first, so a registration lands on the next frame — including
      // one made while a user is part-way through enrolling. The registry
      // documents replacement as a feature; what this pins is *when* it takes
      // effect, because the documented start-up window is a convention and not
      // something the code enforces.
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(type: 'totp'),
      );
      await pump(tester, controller);
      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')),
        '123456',
      );
      await tester.pump();

      Tom2FAClientRegistry.register(const _SmsMechanism(type: 'totp'));
      await pump(tester, controller);

      expect(find.byKey(const Key('sms-enrolment')), findsOneWidget);
      expect(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')),
        findsNothing,
      );

      // And the typing is gone with the panel that held it: the field's
      // controller lived in that panel's State, which Flutter disposed when the
      // widget type under the same slot changed. Swapping back proves the loss
      // rather than only the absence.
      Tom2FAClientRegistry.register(const TomTotp2FAClientMechanism());
      await pump(tester, controller);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-enrolment-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('a replacement that renders the same panel keeps the typing', (
      tester,
    ) async {
      // The other half, and the reason the warning is conditional rather than
      // flat. What costs the user their input is not the registration: it is
      // the *widget type* changing under the same slot, which is what makes
      // Flutter drop the State and with it the TextEditingController. An
      // application that wraps or subclasses the shipped panel replaces the
      // mechanism object and keeps the shape, so nothing is lost — and that is
      // the likelier replacement.
      final controller = _FakeController(
        enrolment: Tom2FAPendingEnrolment(type: 'totp'),
      );
      await pump(tester, controller);
      await tester.enterText(
        find.byKey(const Key('tom-2fa-totp-enrolment-code')),
        '123456',
      );
      await tester.pump();

      Tom2FAClientRegistry.register(const _WrappingTotpMechanism());
      await pump(tester, controller);

      expect(Tom2FAClientRegistry.find('totp'), isA<_WrappingTotpMechanism>());
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-enrolment-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '123456');
    });

    test('register is the only way a mechanism enters the catalog', () {
      // The module had a second door: a `TomClient2FAAdaptor` annotation,
      // exported from the barrel, documented as a route a runtime could
      // enumerate, and read by nothing. It was removed rather than documented
      // as decorative, because a reader who finds an annotation in a barrel
      // reasonably concludes that annotating a class does something, ships a
      // mechanism annotated and unregistered, and discovers at the chooser that
      // it is absent.
      //
      // The module readme now says "`Tom2FAClientRegistry.register` is the only
      // route into the registry". These three assertions are that sentence:
      // nothing else inserts, nothing here reflects, and the build generates no
      // mirrors for this module — which is what a scan would need.
      final source = File(
        'lib/src/tomclient/security/two_factor_client.dart',
      ).readAsStringSync();

      // One insertion site. `reset` clears and the readers read; an `[…] =`
      // anywhere else would be a second way in.
      expect(
        RegExp(r'_mechanisms\[[^\]]*\]\s*=').allMatches(source).length,
        1,
        reason:
            'something other than `register` writes into the catalog; the '
            'module documents one route in',
      );
    });

    test('and nothing in the module reflects or is generated for', () {
      // The other half of "there is no annotation and no scan". An annotation
      // route needs both a marker to read and generated mirrors to read it
      // with, so either alone returning is enough to fail here — and the build
      // configuration is the half a reader would never think to check.
      for (final file
          in Directory('lib/src/tomclient/security')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final marker in [
          '@tomReflector',
          'tomReflector.',
          'reflectType',
        ]) {
          expect(
            source,
            isNot(contains(marker)),
            reason:
                '${file.path} uses reflection; the module dispatches through '
                'the registry alone, and an annotation route was removed for '
                'promising a dispatch that did not exist',
          );
        }
      }

      expect(
        File('build.yaml').readAsStringSync(),
        isNot(contains('security')),
        reason:
            'the reflection generator now produces mirrors for a security '
            'file; nothing in the module needs them, and needing them is what '
            'a scan would look like',
      );
    });

    test('a mechanism describes itself by the scoped convention', () {
      const mechanism = TomTotp2FAClientMechanism();

      expect(mechanism.descriptor.displayNameKey, 'two_factor.totp.name');
      expect(mechanism.descriptor.type, 'totp');
    });
  });

  group('TOTP client helpers', () {
    test('groupSecret splits into fours and leaves a short tail alone', () {
      expect(
        TomTotp2FAClientMechanism.groupSecret('ABCDEFGHIJ'),
        'ABCD EFGH IJ',
      );
      expect(TomTotp2FAClientMechanism.groupSecret('AB'), 'AB');
      expect(TomTotp2FAClientMechanism.groupSecret(''), '');
    });

    test('digitsOf reads an int, a numeric string, or the RFC default', () {
      expect(TomTotp2FAClientMechanism.digitsOf({'digits': 8}), 8);
      // Servers that JSON-encode numbers as strings are a real thing.
      expect(TomTotp2FAClientMechanism.digitsOf({'digits': '7'}), 7);
      expect(TomTotp2FAClientMechanism.digitsOf({}), TomTotp.defaultDigits);
      expect(
        TomTotp2FAClientMechanism.digitsOf({'digits': 0}),
        TomTotp.defaultDigits,
      );
      expect(
        TomTotp2FAClientMechanism.digitsOf({'digits': 'six'}),
        TomTotp.defaultDigits,
      );
    });

    test('periodOf reads an int, a numeric string, or the RFC default', () {
      // The same defence `digitsOf` applies, to the key beside it. The panel
      // renders a countdown off this, so a server that omitted it or sent it
      // as text must not leave the field counting down from nothing.
      expect(
        TomTotp2FAClientMechanism.periodOf({'periodSeconds': 60}),
        const Duration(seconds: 60),
      );
      expect(
        TomTotp2FAClientMechanism.periodOf({'periodSeconds': '45'}),
        const Duration(seconds: 45),
      );
      expect(TomTotp2FAClientMechanism.periodOf({}), TomTotp.defaultPeriod);
      expect(
        TomTotp2FAClientMechanism.periodOf({'periodSeconds': 0}),
        TomTotp.defaultPeriod,
      );
      expect(
        TomTotp2FAClientMechanism.periodOf({'periodSeconds': 'thirty'}),
        TomTotp.defaultPeriod,
      );
    });

    test('secondsRemainingIn counts down to the epoch-aligned boundary', () {
      // TOTP steps are aligned to the Unix epoch, not to when a challenge was
      // issued, so the boundary is computable without a server timestamp — and
      // it is the same division `TomTotp.counterFor` does, which is what makes
      // the number the panel shows agree with the code the authenticator will
      // roll over to.
      const period = Duration(seconds: 30);
      DateTime at(int epochSeconds) =>
          DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000, isUtc: true);

      // On a boundary the whole step is ahead, not zero: the line reads "good
      // for another N seconds", and a step that has just begun has all of them.
      expect(
        TomTotp2FAClientMechanism.secondsRemainingIn(period, at: at(1800)),
        30,
      );
      expect(
        TomTotp2FAClientMechanism.secondsRemainingIn(period, at: at(1801)),
        29,
      );
      expect(
        TomTotp2FAClientMechanism.secondsRemainingIn(period, at: at(1829)),
        1,
      );
      // And it agrees with the counter: the second the remainder hits its
      // period again is the second the step number changes.
      expect(
        TomTotp.counterFor(period: period, at: at(1829)),
        isNot(TomTotp.counterFor(period: period, at: at(1830))),
      );

      // A local time is converted rather than read as UTC, which is the
      // mistake that would put the countdown hours out in one direction.
      expect(
        TomTotp2FAClientMechanism.secondsRemainingIn(
          period,
          at: at(1801).toLocal(),
        ),
        29,
      );

      // A period that cannot divide answers zero rather than throwing: it is
      // reached only from `periodOf`, which never produces one, and a panel
      // that crashed on a malformed payload would take the login screen down.
      expect(TomTotp2FAClientMechanism.secondsRemainingIn(Duration.zero), 0);
    });
  });

  group('the QR view', () {
    // Driven directly rather than through the enrolment panel: the widget is
    // exported, so its behaviour on an unencodable payload is a promise to
    // every caller and not only to the one panel that happens to use it today.
    Future<void> pumpCode(
      WidgetTester tester,
      String data, {
      Color? foreground,
    }) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TomQrCodeView(data: data, size: 120, foreground: foreground),
        ),
      ),
    );

    // The painter is the difference between the two outcomes: present means a
    // code was encoded, absent means the space was reserved and left blank.
    Finder painter() => find.descendant(
      of: find.byType(TomQrCodeView),
      matching: find.byType(CustomPaint),
    );

    testWidgets('paints a code for a payload that fits', (tester) async {
      await pumpCode(tester, 'otpauth://totp/Tom:alice?secret=JBSWY3DPEHPK3');

      expect(tester.takeException(), isNull);
      expect(painter(), findsOneWidget);
    });

    testWidgets('holds its size and paints nothing when the payload will not '
        'fit', (tester) async {
      await pumpCode(tester, _oversizedUri());

      expect(tester.takeException(), isNull);
      expect(painter(), findsNothing);
      // Same box either way, so a payload that grew past the ceiling between
      // two enrolments does not also shift the layout around it.
      expect(
        tester.getSize(find.byType(TomQrCodeView)),
        const Size.square(120),
      );
    });

    testWidgets('holds its size and paints nothing when there is no payload', (
      tester,
    ) async {
      await pumpCode(tester, '');

      expect(painter(), findsNothing);
      expect(
        tester.getSize(find.byType(TomQrCodeView)),
        const Size.square(120),
      );
    });

    // Encoding a QR code is the expensive part of this widget by a wide margin
    // — milliseconds, a double-digit percentage of a frame — and it depends on
    // nothing but the payload. These three pin the two halves of not paying it
    // twice: the encode is not repeated, and the paint is not repeated either.

    CustomPainter painterOf(WidgetTester tester) =>
        tester.widget<CustomPaint>(painter()).painter!;

    // Reaches a public field on a private class, which needs `dynamic`. The
    // alternative is to leave the cache untested and let a future edit quietly
    // move the encode back into `build`, where nothing would notice.
    Object? encodedImageOf(WidgetTester tester) =>
        (painterOf(tester) as dynamic).image as Object?;

    const uri = 'otpauth://totp/Tom:alice?secret=JBSWY3DPEHPK3';

    testWidgets('re-encodes only when the payload changes', (tester) async {
      await pumpCode(tester, uri);
      final first = encodedImageOf(tester);

      await pumpCode(tester, uri);
      expect(
        identical(encodedImageOf(tester), first),
        isTrue,
        reason: 'an unchanged payload must reuse the encoded code',
      );

      await pumpCode(tester, '$uri&issuer=Tom');
      expect(
        identical(encodedImageOf(tester), first),
        isFalse,
        reason: 'a changed payload must be re-encoded',
      );
    });

    testWidgets('does not repaint when nothing that shows has changed', (
      tester,
    ) async {
      await pumpCode(tester, uri);
      final first = painterOf(tester);

      await pumpCode(tester, uri);

      // A fresh painter instance every build is expected; what must not happen
      // is that instance claiming a repaint is due when the pixels are settled.
      expect(painterOf(tester).shouldRepaint(first), isFalse);
    });

    testWidgets('repaints when the payload or the styling changes', (
      tester,
    ) async {
      await pumpCode(tester, uri);
      final first = painterOf(tester);

      await pumpCode(tester, '$uri&issuer=Tom');
      expect(painterOf(tester).shouldRepaint(first), isTrue);

      // The style clauses were unreachable while the first comparison was
      // always true, so this pins that they now decide something.
      await pumpCode(tester, '$uri&issuer=Tom');
      final settled = painterOf(tester);
      await pumpCode(
        tester,
        '$uri&issuer=Tom',
        foreground: const Color(0xFF00FF00),
      );
      expect(painterOf(tester).shouldRepaint(settled), isTrue);
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
    this.label = '',
  });

  final Tom2FAPendingEnrolment? enrolment;
  final Tom2FAChallenge? challenge;
  final List<Tom2FAMethodDescriptor> methods;
  final Object? failure;

  /// The account name the application would supply. Defaults to the empty
  /// string the base class defaults to, so every test that does not care about
  /// the caption keeps exercising the no-label path.
  final String label;

  @override
  String get accountLabel => label;

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
///
/// Its challenge panel renders [Tom2FAChallengePanelContext.hint], which the
/// shipped TOTP panel has no use for — a code the user reads off their own
/// phone needs no hint about where it came from. That makes this the only place
/// the hint's delivery is observable, and delivery is the half of the contract
/// the framework owns: the flow promises to hand a mechanism whatever the
/// server said, whether or not any mechanism shipped today reads it.
class _SmsMechanism extends Tom2FAClientMechanism {
  const _SmsMechanism({String type = 'sms'}) : super(type);

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => const SizedBox(key: Key('sms-enrolment'));

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => Column(
    key: const Key('sms-challenge'),
    mainAxisSize: MainAxisSize.min,
    children: [Text(data.hint, key: const Key('sms-challenge-hint'))],
  );
}

/// A mechanism that renders the shipped TOTP panels from a different object.
class _WrappingTotpMechanism extends Tom2FAClientMechanism {
  const _WrappingTotpMechanism() : super('totp');

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => const TomTotp2FAClientMechanism().buildEnrolmentPanel(context, data);

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => const TomTotp2FAClientMechanism().buildChallengePanel(context, data);
}

/// A platform authenticator that answers with canned responses.
class _FakePasskeys extends TomWebAuthnPlatform {
  final List<TomWebAuthnCreationOptions> created = [];
  final List<TomWebAuthnRequestOptions> requested = [];
  bool failNext = false;

  @override
  bool get isAvailable => true;

  @override
  Future<TomWebAuthnRegistrationResponse> create(
    TomWebAuthnCreationOptions options,
  ) async {
    created.add(options);
    if (failNext) {
      failNext = false;
      throw const TomWebAuthnPlatformException('NotAllowedError');
    }
    return const TomWebAuthnRegistrationResponse(
      id: 'bmV3LWNyZWQ',
      clientDataJson: 'e30',
      attestationObject: 'oA',
    );
  }

  @override
  Future<TomWebAuthnAuthenticationResponse> get(
    TomWebAuthnRequestOptions options,
  ) async {
    requested.add(options);
    if (failNext) {
      failNext = false;
      throw const TomWebAuthnPlatformException('NotAllowedError');
    }
    return const TomWebAuthnAuthenticationResponse(
      id: 'Y3JlZA',
      clientDataJson: 'e30',
      authenticatorData: 'YXV0aA',
      signature: 'c2ln',
    );
  }
}
