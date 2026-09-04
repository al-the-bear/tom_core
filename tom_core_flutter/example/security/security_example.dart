/// Executable example for the security module of `tom_core_flutter`.
///
/// Demonstrates the seam an application actually implements — a
/// `Tom2FAFlowController` — by walking one through every stop of a
/// second-factor login: choosing a mechanism, setting it up, being refused,
/// and answering a challenge on the next sign-in. Along the way it shows the
/// registry rule that decides what the chooser may list, `Tom2FATexts`
/// resolution including its deliberately conspicuous failure, and the two ways
/// a mechanism reaches the registry — the `TomClient2FAAdaptor` annotation and
/// an explicit registration.
///
/// The *panels* are not rendered here. `Tom2FAFlowPanel`,
/// `TomTotp2FAClientMechanism` and `TomQrCodeView` are widgets, and a widget
/// needs a `WidgetTester` pump loop that an example has no way to open; they
/// are demonstrated by `test/two_factor_client_test.dart` instead. What that
/// suite cannot show is what this file is for: its controller is a stub whose
/// moves record their argument and never advance the login, because a widget
/// test wants each stop *pinned* rather than *reached*. Reaching them is the
/// controller's whole job, and it is the only part of this module an
/// application has to write itself.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/security_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own.
library;

import 'package:flutter/widgets.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

// A client mechanism tagged with the 2FA key it renders. In an application that
// runs the reflection generator, this annotation is the whole wiring: the
// registry scans the reflected program on first read and installs the class
// under `sms`. This example does not generate reflection, so Example 10
// registers it by hand — which is the same registry, reached the other way.
//
// The panels are stubs. What an SMS mechanism actually renders (a code field,
// and the masked number the challenge hinted at) is `TomTotp2FAClientMechanism`'s
// job to model, and a widget needs a pump loop an example cannot open.
@TomClient2FAAdaptor('sms')
class SmsClientMechanism extends Tom2FAClientMechanism {
  /// Creates the mechanism. Unnamed and argument-free, because that is the
  /// constructor the annotation scan calls.
  const SmsClientMechanism() : super('sms');

  @override
  Widget buildEnrolmentPanel(
    BuildContext context,
    Tom2FAEnrolmentPanelContext data,
  ) => const SizedBox.shrink();

  @override
  Widget buildChallengePanel(
    BuildContext context,
    Tom2FAChallengePanelContext data,
  ) => const SizedBox.shrink();
}

/// The application's one typed backend failure, with a message already written
/// for the user. Its existence is why [DemoFlowController.describeError] is
/// overridden at all.
class DemoBackendException implements Exception {
  /// Creates a failure carrying [message].
  DemoBackendException(this.message);

  /// What the user should be told.
  final String message;

  @override
  String toString() => 'DemoBackendException($message)';
}

/// A controller whose moves genuinely advance the login.
///
/// A real one delegates each move to an auth client and lets the session it
/// wraps hold the state (see `advanced_app_client`); this one keeps the state
/// in three fields so the example is deterministic and offline. What matters
/// is the shape, which is identical either way: five moves that change where
/// the login *is*, and two getters the panel re-reads on every build to find
/// out. The panel never asks "what happened"; it asks "where are we now".
class DemoFlowController extends Tom2FAFlowController {
  /// The mechanism keys the server offered, before the registry filters them.
  static const List<String> offered = ['totp', 'sms'];

  // The server opens the login owing an enrolment with nothing chosen yet:
  // `type` is empty, so `hasOffer` is false and the panel renders the chooser.
  Tom2FAPendingEnrolment? _enrolment = Tom2FAPendingEnrolment(
    offeredTypes: offered,
    skippable: true,
    skipSpendsGrace: true,
  );
  Tom2FAChallenge? _challenge;

  /// Whether the second factor has been satisfied and the login may complete.
  bool settled = false;

  /// How many times the user backed out to the credentials screen.
  int cancelled = 0;

  @override
  Tom2FAPendingEnrolment? get pendingEnrolment => _enrolment;

  @override
  Tom2FAChallenge? get pendingChallenge => _challenge;

  @override
  String get accountLabel => 'ada@example.com';

  // Descriptors normally arrive from the server with the interim result. These
  // are derived from the keys instead, which is what `.scoped` is for: a
  // mechanism keeping to the `two_factor.<type>.*` convention is labelled
  // correctly whether or not its server bothered to describe it.
  @override
  List<Tom2FAMethodDescriptor> get availableMethods =>
      offered.map(Tom2FAMethodDescriptor.scoped).toList();

  @override
  Future<void> chooseMethod(String type) async {
    // The server answers a choice with the half-built factor. `clientData` is
    // opaque to everything between the server adaptor and the mechanism's
    // panel — the framework passes it through and never reads a key of it.
    _enrolment = Tom2FAPendingEnrolment(
      type: type,
      attemptsAllowed: 3,
      clientData: const {
        'secret': 'JBSWY3DPEHPK3PXP',
        'otpauthUri':
            'otpauth://totp/Demo:ada@example.com?secret=JBSWY3DPEHPK3PXP',
        'digits': 6,
        'periodSeconds': 30,
      },
    );
  }

  @override
  Future<void> confirmEnrolment(String code) async {
    final offer = _enrolment!;
    if (code != '123456') {
      // Rebuilt rather than mutated, and rebuilt from a *server* answer: the
      // attempt budget is the server's to spend, and a refused confirmation
      // comes back as a re-issued interim result with the counter already
      // advanced. That is why `Tom2FAPendingEnrolment` offers no
      // `withConsumedAttempt` — the only callers of that method anywhere are
      // server-side. Constructing the successor here stands in for the round
      // trip; a real controller assigns whatever the call returned.
      _enrolment = Tom2FAPendingEnrolment(
        type: offer.type,
        attempt: offer.attempt + 1,
        attemptsAllowed: offer.attemptsAllowed,
        clientData: offer.clientData,
      );
      // Throwing is the contract: the panel catches whatever comes back and
      // renders it through `describeError`, so a controller reports a refusal
      // by failing rather than by setting an error field the panel would then
      // have to know to read.
      throw DemoBackendException('That code did not match. Try again.');
    }
    // Confirming an enrolment *is* proof the factor is held, so this login is
    // finished — no challenge follows. A challenge belongs to the next sign-in.
    _enrolment = null;
    settled = true;
  }

  @override
  Future<void> skipEnrolment() async {
    _enrolment = null;
    settled = true;
  }

  @override
  Future<void> submitSecondFactor(String code) async {
    if (code != '123456') {
      _challenge = _challenge!.withConsumedAttempt();
      throw DemoBackendException('That code did not match. Try again.');
    }
    _challenge = null;
    settled = true;
  }

  @override
  void cancel() => cancelled++;

  // The one piece of judgement in the whole class: the app's typed failure
  // already carries a message written for the user, so it is shown as-is
  // rather than as its `toString`.
  @override
  String describeError(Object error) => error is DemoBackendException
      ? error.message
      : super.describeError(error);

  /// Starts a *later* sign-in by the same principal, who now holds the factor.
  ///
  /// Not part of [Tom2FAFlowController] — the interface covers the moves the
  /// panel makes, and beginning a login is not one of them. A real controller
  /// reaches this state the same way: its session is handed a challenge by the
  /// credentials call, before the panel is ever built.
  void beginReturningLogin() {
    settled = false;
    _challenge = Tom2FAChallenge(
      type: 'totp',
      attemptsAllowed: 3,
      hint: 'Authenticator app',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      clientData: const {'digits': 6, 'periodSeconds': 30},
    );
  }
}

Future<void> run() async {
  // Install a bundle so the resource keys resolve to something readable. A
  // deployment ships this; every user-facing string in the module is a key.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({
      Tom2FATexts.chooseTitle: 'Choose a method',
      Tom2FATexts.chooseIntro: 'Pick how you want to confirm it is you.',
      Tom2FATexts.enrolTitle: 'Set it up',
      Tom2FATexts.challengeTitle: 'Confirm it is you',
      Tom2FATexts.skip: 'Not now',
      Tom2FATexts.attemptsRemaining: '{count} tries left',
      'two_factor.totp.name': 'Authenticator app',
      'two_factor.totp.description': 'A code from an app on your phone.',
      // `two_factor.sms.*` is deliberately absent — see Example 6.
    }),
  );

  // TOTP registers itself when the flow first builds, so an application gets
  // it without wiring. Calling it here is what an example needs instead of a
  // build; nothing else registers, so `sms` has no panel in this process.
  Tom2FAFlowPanel.registerBuiltInMechanisms();

  final controller = DemoFlowController();

  // Example 1: the chooser stop. An enrolment is owed and no mechanism has
  // been picked, which is exactly what `hasOffer == false` means.
  final opening = controller.pendingEnrolment!;
  print(
    'stop 1: hasOffer=${opening.hasOffer} '
    'skippable=${opening.skippable} offered=${opening.offeredTypes}',
  );

  // The chooser lists only what this build can render. That is not a rule the
  // example is restating — `Tom2FAClientRegistry.has` is the same predicate
  // the panel filters with, so `sms` is dropped here for the same reason it
  // would be dropped on screen: a server upgraded ahead of its clients offers
  // keys we have no panel for, and listing one would strand the user.
  final renderable = opening.offeredTypes
      .where(Tom2FAClientRegistry.has)
      .toList();
  print('renderable of ${opening.offeredTypes}: $renderable');

  assert(opening.hasOffer == false);
  // `==` on two lists is identity in Dart, so the contents are compared.
  assert(renderable.length == 1 && renderable.single == 'totp');
  assert(Tom2FAClientRegistry.has('sms') == false);

  // Example 2: the labels come from the bundle, via keys the descriptor
  // derives from the mechanism key alone.
  final totp = controller.availableMethods.firstWhere((d) => d.type == 'totp');
  print(
    'totp label: ${Tom2FATexts.text(totp.displayNameKey)} '
    '— ${Tom2FATexts.text(totp.descriptionKey)}',
  );

  assert(totp.displayNameKey == 'two_factor.totp.name');
  assert(Tom2FATexts.text(totp.displayNameKey) == 'Authenticator app');

  // Example 3: choosing moves the login to the enrolment stop. The same
  // `pendingEnrolment` getter now reports a chosen type and the payload the
  // mechanism's panel will render.
  await controller.chooseMethod('totp');
  final offer = controller.pendingEnrolment!;
  print(
    'stop 2: hasOffer=${offer.hasOffer} type=${offer.type} '
    'clientData keys=${offer.clientData.keys.toList()}',
  );

  assert(offer.hasOffer == true);
  assert(offer.type == 'totp');
  assert(offer.clientData['secret'] == 'JBSWY3DPEHPK3PXP');

  // Example 4: a refusal. The controller reports it by throwing, and
  // `describeError` is what turns it into the line the panel shows — which is
  // why an app with a typed failure overrides that one method and nothing else.
  try {
    await controller.confirmEnrolment('000000');
    throw StateError('a wrong code must not confirm the enrolment');
  } on DemoBackendException catch (error) {
    print('refused: ${controller.describeError(error)}');
    // The message, not the `toString` the default would have produced.
    assert(
      controller.describeError(error) ==
          'That code did not match. '
              'Try again.',
    );
    assert(controller.describeError(error) != '$error');
  }

  // A spent attempt is visible on the same object the panel reads, so the
  // attempt line does not need its own counter.
  print(
    'after one refusal: ${Tom2FATexts.textWith(Tom2FATexts.attemptsRemaining, 'count', controller.pendingEnrolment!.attemptsRemaining)}',
  );
  assert(controller.pendingEnrolment!.attemptsRemaining == 2);

  // Example 5: the right code settles this login. Both getters go null, which
  // is the state the panel renders as nothing at all — the flow is over and
  // the application shows whatever comes after signing in.
  await controller.confirmEnrolment('123456');
  print(
    'stop 2 cleared: enrolment=${controller.pendingEnrolment} '
    'challenge=${controller.pendingChallenge} settled=${controller.settled}',
  );

  assert(controller.pendingEnrolment == null);
  assert(controller.pendingChallenge == null);
  assert(controller.settled);

  // Example 6: a key the bundle does not carry. `TomTextResourceProvider`
  // answers with the key itself, so an untranslated build shows
  // `two_factor.sms.name` where a label belongs — ugly and unmistakable,
  // rather than a blank control that reads as a layout bug.
  final sms = Tom2FAMethodDescriptor.scoped('sms');
  print('untranslated: ${Tom2FATexts.text(sms.displayNameKey)}');
  assert(Tom2FATexts.text(sms.displayNameKey) == 'two_factor.sms.name');

  // Example 7: the next sign-in. The factor is held now, so the server sends a
  // challenge instead of an enrolment — the third stop, and the one a
  // returning user meets every time.
  controller.beginReturningLogin();
  final challenge = controller.pendingChallenge!;
  print(
    'stop 3: type=${challenge.type} hint=${challenge.hint} '
    'attemptsRemaining=${challenge.attemptsRemaining} '
    'expired=${challenge.isExpired()}',
  );

  assert(challenge.attemptsRemaining == 3);
  assert(challenge.isExpired() == false);

  // Example 8: the attempt budget is spent by the controller, not by the
  // panel. Two refusals leave one try, and `isExhausted` says when the
  // challenge is burned.
  for (final wrong in ['111111', '222222']) {
    try {
      await controller.submitSecondFactor(wrong);
    } on DemoBackendException {
      final now = controller.pendingChallenge!;
      print(
        'wrong code $wrong: remaining=${now.attemptsRemaining} '
        'exhausted=${now.isExhausted}',
      );
    }
  }
  assert(controller.pendingChallenge!.attemptsRemaining == 1);
  assert(controller.pendingChallenge!.isExhausted == false);

  // Example 9: the right code clears the challenge and the login completes.
  await controller.submitSecondFactor('123456');
  print(
    'stop 3 cleared: challenge=${controller.pendingChallenge} '
    'settled=${controller.settled}',
  );

  assert(controller.pendingChallenge == null);
  assert(controller.settled);

  // Example 10: the mechanism that was not renderable at Example 1 becomes
  // renderable, and the chooser's answer changes with it. `SmsClientMechanism`
  // above is annotated `@TomClient2FAAdaptor('sms')`; in an application that
  // runs the reflection generator that annotation is the whole wiring, and this
  // line would not exist. This example generates no reflection — nothing to
  // scan — so it reaches the same registry directly, which is also what an
  // application does for a mechanism its constructor needs arguments for.
  Tom2FAClientRegistry.register(const SmsClientMechanism());
  final nowRenderable = [
    'totp',
    'sms',
  ].where(Tom2FAClientRegistry.has).toList();
  print('renderable after registering sms: $nowRenderable');

  assert(Tom2FAClientRegistry.has('sms'));
  assert(nowRenderable.length == 2);

  // The annotation itself is an ordinary const value object: it carries the key
  // it was given and canonicalizes like any other constant. That key has to
  // match the mechanism's own `type` — the scan refuses a class where the two
  // disagree, which is what keeps writing it twice safe.
  const smsMarker = TomClient2FAAdaptor('sms');
  const smsAgain = TomClient2FAAdaptor('sms');
  print(
    'annotation type: ${smsMarker.type}; '
    'mechanism type: ${const SmsClientMechanism().type}; '
    'canonicalized: ${identical(smsMarker, smsAgain)}',
  );

  assert(smsMarker.type == 'sms');
  assert(smsMarker.type == const SmsClientMechanism().type);
  assert(identical(smsMarker, smsAgain));
}

Future<void> main() => run();
