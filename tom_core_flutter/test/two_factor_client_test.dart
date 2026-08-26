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
// For the icon adapter the chooser resolves `iconKey` through. Not re-exported
// by this package's barrel, and should not be — it belongs to the widget
// library, and an application configures it there.
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Every string the panel currently renders, in tree order.
///
/// Used to compare two renderings of one panel that differ only in a
/// `clientData` key. Text is what a key the panel *started* reading would
/// surface — a countdown adds no widget key of its own — so equality here is
/// the assertion that the extra key changed nothing.
List<String> _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
    .toList();

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
    TomUIIcons.adapter = AllIconsAdapter();
  });

  tearDown(() {
    Tom2FAClientRegistry.reset();
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

    // The descriptor carries three resource keys and the chooser renders all
    // three. `iconKey` resolves in two steps — the bundle maps the key to an
    // icon *name*, the adapter maps the name to an `IconData` — and every step
    // is allowed to come up empty, because a bundle that never mentions icons
    // is a legitimate deployment rather than a misconfiguration.

    Finder iconIn(String type) => find.descendant(
          of: find.byKey(Key('tom-2fa-method-$type')),
          matching: find.byType(Icon),
        );

    testWidgets('shows the descriptor icon beside a mechanism that has one',
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

      expect(iconIn('totp'), findsOneWidget);
      expect(
        tester.widget<Icon>(iconIn('totp')).icon,
        AllIconsAdapter().resolveIcon('mSecurity'),
        reason: 'the icon named by two_factor.totp.icon, not an arbitrary one',
      );

      // SMS has a label and a description in the bundle but no icon entry, so
      // its row is simply icon-less. An unknown key resolves to the key itself,
      // which is not an icon name — the row must not sprout a broken glyph.
      expect(iconIn('sms'), findsNothing);
    });

    testWidgets('renders no icon when the build configured no icon adapter',
        (tester) async {
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

    testWidgets('renders nothing to scan when the URI will not fit a code',
        (tester) async {
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
            clientData: {
              'otpauthUri': _oversizedUri(),
              'secret': 'JBSWY3DP',
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('tom-2fa-totp-qr')), findsOneWidget);
      expect(find.text('JBSW Y3DP'), findsOneWidget);
    });

    testWidgets('ignores the periodSeconds the server sends', (tester) async {
      // The server writes four keys and this panel reads three. Rendering the
      // real four-key payload beside the three-key one pins the fourth as
      // inert, so teaching the panel about the period has to fail here and
      // take the documented key list with it.
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

    testWidgets('sizes from digits and ignores periodSeconds', (tester) async {
      // The challenge payload the server actually sends is exactly these two
      // keys. The panel reads the first; the second is what a countdown would
      // be driven from, and there is no countdown.
      Tom2FAChallenge challenge({required bool withPeriod}) => Tom2FAChallenge(
            type: 'totp',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            clientData: {
              'digits': 8,
              if (withPeriod) 'periodSeconds': 30,
            },
          );

      await pump(tester, _FakeController(challenge: challenge(
        withPeriod: false,
      )));
      final withoutPeriod = _renderedText(tester);

      await pump(tester, _FakeController(challenge: challenge(
        withPeriod: true,
      )));

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tom-2fa-totp-challenge-code')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, 8);
      expect(_renderedText(tester), withoutPeriod);
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

  group('the QR view', () {
    // Driven directly rather than through the enrolment panel: the widget is
    // exported, so its behaviour on an unencodable payload is a promise to
    // every caller and not only to the one panel that happens to use it today.
    Future<void> pumpCode(
      WidgetTester tester,
      String data, {
      Color? foreground,
    }) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: TomQrCodeView(
                data: data,
                size: 120,
                foreground: foreground,
              ),
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
      expect(tester.getSize(find.byType(TomQrCodeView)), const Size.square(120));
    });

    testWidgets('holds its size and paints nothing when there is no payload',
        (tester) async {
      await pumpCode(tester, '');

      expect(painter(), findsNothing);
      expect(tester.getSize(find.byType(TomQrCodeView)), const Size.square(120));
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
      expect(identical(encodedImageOf(tester), first), isTrue,
          reason: 'an unchanged payload must reuse the encoded code');

      await pumpCode(tester, '$uri&issuer=Tom');
      expect(identical(encodedImageOf(tester), first), isFalse,
          reason: 'a changed payload must be re-encoded');
    });

    testWidgets('does not repaint when nothing that shows has changed',
        (tester) async {
      await pumpCode(tester, uri);
      final first = painterOf(tester);

      await pumpCode(tester, uri);

      // A fresh painter instance every build is expected; what must not happen
      // is that instance claiming a repaint is due when the pixels are settled.
      expect(painterOf(tester).shouldRepaint(first), isFalse);
    });

    testWidgets('repaints when the payload or the styling changes',
        (tester) async {
      await pumpCode(tester, uri);
      final first = painterOf(tester);

      await pumpCode(tester, '$uri&issuer=Tom');
      expect(painterOf(tester).shouldRepaint(first), isTrue);

      // The style clauses were unreachable while the first comparison was
      // always true, so this pins that they now decide something.
      await pumpCode(tester, '$uri&issuer=Tom');
      final settled = painterOf(tester);
      await pumpCode(tester, '$uri&issuer=Tom',
          foreground: const Color(0xFF00FF00));
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
