/// The app's seam into the framework-owned second-factor flow: a
/// [Tom2FAFlowController] over [AppSession].
///
/// This is the whole of what the application writes to get enrolment and
/// challenge screens. The panel ([Tom2FAFlowPanel]) owns the chooser, the
/// mechanism panels, the attempt counter, the error line and the skip
/// affordance; the token choreography is owned by `advanced_client_core`'s
/// `AuthClient` and the framework's `tomRunWithAuthRetry`. What is left — which
/// session to drive, and what a failure of *this* app's backend says — is what
/// lives here.
///
/// Note what is *not* here: no digit count, no QR code, no `otpauth://`, no
/// mechanism key beyond passing the user's choice through. That is the point of
/// the seam. A deployment that adds an SMS or WebAuthn mechanism registers its
/// client counterpart with [Tom2FAClientRegistry] and this file does not change.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../backend/backend.dart';
import 'app_session.dart';

/// Drives [Tom2FAFlowPanel] from an [AppSession].
class SessionTwoFactorController extends Tom2FAFlowController {
  /// Creates the controller over [session]; every move delegates to it.
  SessionTwoFactorController(this.session);

  /// The session that holds the half-finished login.
  final AppSession session;

  @override
  Tom2FAPendingEnrolment? get pendingEnrolment => session.pendingEnrolment;

  @override
  Tom2FAChallenge? get pendingChallenge => session.pendingChallenge;

  @override
  List<Tom2FAMethodDescriptor> get availableMethods =>
      session.availableTwoFactorMethods;

  /// The account the factor is being set up for, shown beside the QR code so a
  /// user with several accounts in one authenticator can tell them apart.
  ///
  /// Reads [AppSession.pendingAccount], not [AppSession.user]: a half-finished
  /// login has no user yet — assigning one would flip `isLoggedIn` before the
  /// factor settles — so the name travels separately until the login completes.
  @override
  String get accountLabel => session.pendingAccount;

  @override
  Future<void> chooseMethod(String type) =>
      session.chooseTwoFactorMethod(type);

  @override
  Future<void> confirmEnrolment(String code) => session.confirmEnrolment(code);

  @override
  Future<void> skipEnrolment() => session.skipEnrolment();

  @override
  Future<void> submitSecondFactor(String code) =>
      session.submitSecondFactor(code);

  @override
  void cancel() => session.cancelSecondFactor();

  /// The app's single typed backend failure already carries a message written
  /// for the user (server-supplied where the server had one), so the panel shows
  /// that rather than an exception's `toString`.
  @override
  String describeError(Object error) => error is AppBackendException
      ? error.message
      : super.describeError(error);
}
