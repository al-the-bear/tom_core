/// The auth server's second-factor enrolment store — the persistent one, with a
/// bridge over the accounts that predate it.
///
/// ## Why a bridge is needed at all
///
/// Installing a [Tom2FAEnrolmentStore] changes what pass 1 means by "this user
/// has a factor". Without one the login asks the mechanism's legacy hook (here
/// the `auth_users.two_factor_secret` column) and challenges whoever answers;
/// with one, the *store* is the authority, and a user with no row in it is sent
/// to enrolment — see `TomAuthenticationServer._usableEnrolments`, which
/// deliberately distinguishes "no store installed" from "tracked, none
/// enrolled".
///
/// That is the right rule, and it is exactly what makes first-login enrolment
/// possible. But this sample seeds a demo account (`dave`) whose factor lives in
/// the legacy column and has no row here, and the framework's own verification
/// path already handles that case: `TomTotp2FAService` asks the store first and
/// falls back to the legacy resolver. So the account is perfectly able to answer
/// a challenge — only the pass-1 *decision* would have wrongly concluded it had
/// nothing to answer with.
///
/// [LegacyBridging2FAEnrolmentStore] closes that gap by reporting the legacy
/// flag as one synthetic enrolment when, and only when, the persistent store has
/// nothing for the principal. The result is the framework's documented
/// migrate-one-user-at-a-time path made concrete: seeded accounts keep being
/// challenged, everyone else enrols, and no user has to be converted ahead of
/// time.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A [Tom2FAEnrolmentStore] over `tom_user_two_factor_enrolment` that also
/// recognises the pre-enrolment `auth_users.two_factor_type` flag.
///
/// Reads consult the persistent store first; only when it has nothing does the
/// principal's own legacy flag stand in. Writes and removals go to the
/// persistent store unchanged — the legacy column is read-only here, because a
/// synthetic enrolment describes a factor this store does not own and offering
/// to delete it would promise something it cannot do.
class LegacyBridging2FAEnrolmentStore implements Tom2FAEnrolmentStore {
  /// The prefix of a synthetic enrolment's id, so a log line or an admin screen
  /// can tell a bridged factor from a stored one at a glance.
  static const String legacyIdPrefix = 'legacy:';

  final Tom2FAEnrolmentStore _persistent;

  /// Wraps [persistent] — normally a [TomPersistent2FAEnrolmentStore].
  const LegacyBridging2FAEnrolmentStore(Tom2FAEnrolmentStore persistent)
      : _persistent = persistent;

  @override
  Future<List<Tom2FAEnrolment>> enrolmentsFor(Tom2FAContext context) async {
    final stored = await _persistent.enrolmentsFor(context);
    if (stored.isNotEmpty) return stored;

    // Read off the principal rather than re-queried: the credential check has
    // already projected `auth_users.two_factor_type` onto it (that is what the
    // default `TomPrincipalFlag2FAPolicy` reads), so a second trip to the
    // database on every login would only add a way for the two to disagree.
    final principal = context.principal;
    final type = principal.twoFactorType ?? '';
    if (!principal.requires2FA || type.isEmpty) return const [];

    return [
      Tom2FAEnrolment(
        type: type,
        enrolmentId: '$legacyIdPrefix$type',
        isPrimary: true,
        // Empty on purpose: the secret stays in the legacy column, where the
        // mechanism's own fallback resolver reads it. Copying it into a
        // synthetic value object would put a live credential in memory for no
        // caller that needs it.
      ),
    ];
  }

  @override
  Future<void> store(Tom2FAContext context, Tom2FAEnrolment enrolment) =>
      _persistent.store(context, enrolment);

  @override
  Future<void> remove(Tom2FAContext context, String enrolmentId) =>
      _persistent.remove(context, enrolmentId);
}
