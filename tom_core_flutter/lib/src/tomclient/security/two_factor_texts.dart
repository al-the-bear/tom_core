/// The resource keys the framework-owned second-factor UI resolves its text
/// from, and the one helper that resolves them.
///
/// Every string the flow and the shipped panels display is a key looked up in
/// the installed [TomTextResourceProvider] (G-RES-1/5) — there is no literal
/// user-facing text anywhere in this feature. Collected here rather than
/// scattered as string literals at each use site for two reasons: a deployment
/// writing its bundle needs one list of what to translate, and a key that only
/// exists at its use site is a key nobody discovers is missing until a user
/// hits that screen.
///
/// ## The naming convention
///
/// Everything lives under `two_factor.`, matching
/// [Tom2FAMethodDescriptor.resourceScope], so a bundle can be searched by
/// prefix for "all the second-factor text". Mechanism-specific keys nest one
/// level further under the mechanism key (`two_factor.totp.…`), which is the
/// same shape [Tom2FAMethodDescriptor.scoped] derives — so a mechanism's
/// catalog entry and its panel's text sit together in the bundle.
///
/// ## Missing keys
///
/// [TomTextResourceProvider.getText] answers an unknown key with the key
/// itself. That is the right failure for this screen: an untranslated build
/// shows `two_factor.totp.enrol.submit` on the button, which is ugly and
/// unmistakable, rather than a blank control that looks like a layout bug.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The resource keys the second-factor flow and its shipped panels resolve.
class Tom2FATexts {
  Tom2FATexts._();

  /// The scope every key below lives under.
  static const String scope = Tom2FAMethodDescriptor.resourceScope;

  // --- The generic flow frame -------------------------------------------

  /// Screen title while the user is choosing a mechanism.
  static const String chooseTitle = '$scope.choose.title';

  /// Explanation shown above the mechanism list.
  static const String chooseIntro = '$scope.choose.intro';

  /// Screen title while a mechanism's enrolment is being confirmed.
  static const String enrolTitle = '$scope.enrol.title';

  /// Screen title while a challenge is outstanding.
  static const String challengeTitle = '$scope.challenge.title';

  /// Label of the affordance that declines enrolment. Shown only when the
  /// server said declining is permitted.
  static const String skip = '$scope.skip.label';

  /// Warning shown beside [skip] when declining spends a grace login.
  static const String skipSpendsGrace = '$scope.skip.spendsGrace';

  /// Label of the affordance that abandons the flow and returns to sign-in.
  static const String cancel = '$scope.cancel.label';

  /// Attempt budget line; `{count}` is substituted with the remaining count.
  static const String attemptsRemaining = '$scope.attemptsRemaining';

  /// Shown when the server offered only mechanisms this build cannot render.
  ///
  /// About *enrolment*: the chooser has nothing to list. The challenge stop has
  /// its own key, because the two situations differ in what the user can do
  /// about them — see [unrenderableChallenge].
  static const String noRenderableMethods = '$scope.error.noRenderableMethods';

  /// Shown when the outstanding challenge is for a mechanism this build has no
  /// panel for.
  ///
  /// Separate from [noRenderableMethods] because that one is written about
  /// enrolment — "this app cannot set any of these up" — and a user being
  /// *challenged* is not setting anything up. Here there is exactly one
  /// outstanding challenge, of one type, with nothing to switch to: the honest
  /// message names the version gap rather than the catalogue.
  static const String unrenderableChallenge =
      '$scope.error.unrenderableChallenge';

  // --- The TOTP panels ---------------------------------------------------

  /// Step-by-step instruction shown above the QR code.
  static const String totpEnrolIntro = '$scope.totp.enrol.intro';

  /// What a screen reader announces in place of the QR code.
  static const String totpEnrolQrLabel = '$scope.totp.enrol.qrLabel';

  /// Caption introducing the typed-by-hand fallback secret.
  static const String totpEnrolManualEntry = '$scope.totp.enrol.manualEntry';

  /// Label of the field that confirms the authenticator was set up.
  static const String totpEnrolCodeLabel = '$scope.totp.enrol.codeLabel';

  /// Label of the enrolment panel's submit button.
  static const String totpEnrolSubmit = '$scope.totp.enrol.submit';

  /// Label of the field that answers a TOTP challenge.
  static const String totpChallengeCodeLabel =
      '$scope.totp.challenge.codeLabel';

  /// Label of the challenge panel's submit button.
  static const String totpChallengeSubmit = '$scope.totp.challenge.submit';

  /// How long the code on the user's authenticator is still current;
  /// `{seconds}` is substituted with the whole seconds left in the time step.
  static const String totpChallengeExpiresIn =
      '$scope.totp.challenge.expiresIn';

  /// Shown once a typed code has been overtaken by a rollover, so a refusal
  /// reads as "too late" rather than as "wrong".
  static const String totpChallengeCodeChanged =
      '$scope.totp.challenge.codeChanged';

  /// Resolves [key] against the installed provider.
  ///
  /// The single lookup point for this feature, so a deployment that swaps the
  /// provider mid-session (as the advanced sample does when it installs the
  /// authenticated bundle over the login one) changes what every panel shows
  /// without any panel caching a stale string.
  static String text(String key) =>
      TomTextResourceProvider.getAppResources().getText(key);

  /// Resolves [key] and substitutes `{`[placeholder]`}` with [value].
  ///
  /// Substituting here rather than in each panel keeps the *wording* in the
  /// bundle and the *value* in the code — including where in the sentence the
  /// number falls, which differs by language.
  static String textWith(String key, String placeholder, Object value) =>
      text(key).replaceAll('{$placeholder}', '$value');
}
