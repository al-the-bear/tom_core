/// Decides *whether* a login owes a second factor, and *which* mechanisms it may
/// be answered with.
///
/// ## Why this is a policy and not a field
///
/// The identity a [TomAuthenticationService] resolves carries
/// [TomPrincipal.requires2FA] and [TomPrincipal.twoFactorType] — one boolean and
/// one mechanism name, decided by whichever adaptor produced the principal. That
/// pair can express only "this user must use exactly this mechanism" or "this
/// user is exempt". It cannot say *offer a second factor but let the user
/// decline*, cannot say *everyone in role `admin` must use one*, and cannot
/// separate the mechanisms a user **may** use from the one they happen to have.
///
/// So the decision is lifted out of the principal and into a collaborator the
/// deployment chooses. [TomAuthenticationServer] asks the resolved policy once,
/// on pass 1, and branches on its answer.
///
/// ## The contract in one line
///
/// > A [Tom2FADecision] says how strongly a factor is wanted
/// > ([Tom2FADecision.requirement]) and what this principal is permitted to
/// > answer with ([Tom2FADecision.allowedMechanisms]).
///
/// Everything downstream — the mechanism the challenge is issued for, the error
/// a login fails with when no permitted mechanism is installed — is derived from
/// those two.
///
/// ## Which policy runs
///
/// [Tom2FAPolicy.resolve] reads the bean context, so a deployment installs its
/// own by type:
///
/// ```dart
/// TomBean.withType<Tom2FAPolicy>(TomRole2FAPolicy(
///   requirementByRole: {'admin': Tom2FARequirement.required},
/// ));
/// ```
///
/// or by environment, via [TomBean.installByEnvironment]. With nothing
/// installed, [TomPrincipalFlag2FAPolicy] answers — reproducing the principal's
/// own flags exactly, so a deployment that never heard of this file keeps the
/// behaviour it had.
///
/// The two shipped implementations deliberately carry no `@TomComponent`
/// annotation: both need constructor arguments to be useful, and a policy that
/// installed itself by being linked in would take a security decision nobody
/// asked it to take.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'two_factor.dart';

// =============================================================================
// DECISION
// =============================================================================

/// How strongly a deployment wants a second factor from a given principal.
///
/// The declaration order **is** the strictness order, ascending — [strictest]
/// depends on it, and so does any policy that combines rules. A value inserted
/// out of order would silently change which rule wins.
enum Tom2FARequirement {
  /// No second factor. The login completes on the primary credential alone.
  disabled,

  /// A second factor is offered, but the login can complete without one.
  optional,

  /// A second factor must be satisfied before an authorization token is issued.
  required;

  /// The stricter of `this` and [other].
  ///
  /// Used when a principal matches several rules — a user who is `optional` by
  /// one role and `required` by another is `required`, never the reverse.
  Tom2FARequirement strictest(Tom2FARequirement other) =>
      index >= other.index ? this : other;
}

/// What a [Tom2FAPolicy] concluded about one login.
class Tom2FADecision {
  /// How strongly this login wants a second factor.
  final Tom2FARequirement requirement;

  /// The mechanism keys this principal is permitted to answer with, in
  /// preference order — the first is what the login challenges with when the
  /// user has expressed no choice.
  ///
  /// These are *permissions*, not availability: a policy may name a mechanism
  /// that no adaptor implements here. [offerableMechanisms] is the part that can
  /// actually be used.
  final List<String> allowedMechanisms;

  /// How many further logins this principal may complete before an unsatisfied
  /// [required] becomes blocking.
  ///
  /// Zero — the default — means "no grace". A positive count softens a
  /// [Tom2FARequirement.required] login that has nothing enrolled: instead of
  /// insisting, the flow offers enrolment *and* lets the user decline it, and
  /// spends one grace login through [Tom2FAGraceAccounting] when they do.
  /// Grace is charged only when it is actually used — declining an `optional`
  /// offer costs nothing, and neither does merely being shown one.
  final int graceLogins;

  /// Records a policy's conclusion.
  ///
  /// [allowedMechanisms] is copied and made unmodifiable: a decision is a value
  /// handed across a layer boundary, and a caller that could mutate it would be
  /// editing the policy's answer after the fact.
  Tom2FADecision({
    required this.requirement,
    List<String> allowedMechanisms = const [],
    this.graceLogins = 0,
  }) : allowedMechanisms = List.unmodifiable(allowedMechanisms),
       assert(graceLogins >= 0, 'graceLogins cannot be negative');

  /// The permitted mechanisms that an adaptor is actually registered for, in
  /// the same preference order.
  ///
  /// The intersection happens here, once, rather than at the lookup site: a
  /// policy naming `'sms'` in a deployment that installed no SMS adaptor is a
  /// wiring fault, and it must surface as *this principal has no usable
  /// mechanism* at the branch that decides the login — not as a null adaptor
  /// ten frames later, indistinguishable from a principal who named nothing.
  List<String> get offerableMechanisms {
    final registered = Tom2FARegistry.registeredTypes;
    return List.unmodifiable(allowedMechanisms.where(registered.contains));
  }

  /// Whether this login can proceed without a second factor.
  bool get isSatisfiedWithoutFactor =>
      requirement == Tom2FARequirement.disabled;

  @override
  String toString() =>
      '2FA $requirement via $allowedMechanisms'
      '${graceLogins > 0 ? ' (grace $graceLogins)' : ''}';
}

// =============================================================================
// CONTRACT
// =============================================================================

/// Decides a login's second-factor obligation.
///
/// One question, and only one: *given this identity, is a second factor wanted,
/// and which mechanisms may answer it?* Issuing the challenge, counting
/// attempts and verifying the submission belong to [Tom2FAService] and
/// [TomAuthenticationServer]; a policy performs no I/O on the login's critical
/// path beyond what its own rule source needs.
abstract class Tom2FAPolicy {
  /// The obligation this login carries.
  ///
  /// [context] is the same value the adaptors receive — the principal plus the
  /// tenant and locale coordinates of the attempt. Throwing [TomLoginException]
  /// fails the login with that exception's own key; any other error is masked
  /// behind the generic login failure, as everywhere else in this flow.
  Future<Tom2FADecision> decideFor(Tom2FAContext context);

  /// The policy this deployment installed, or [TomPrincipalFlag2FAPolicy].
  ///
  /// Resolved on every call rather than cached, so a deployment (or a test) that
  /// swaps the bean is obeyed from the next login onwards; the lookup is a map
  /// read.
  ///
  /// Uses [TomBean.getBeanByType] rather than `TomBean<Tom2FAPolicy>().get()`
  /// because *not installed* is the ordinary case, not a wiring fault: the
  /// resolving handle throws when nothing is registered, and no deployment
  /// should have to register a bean merely to keep the behaviour it already had.
  static Tom2FAPolicy resolve() {
    final installed = TomBean.getBeanByType(Tom2FAPolicy);
    return installed is Tom2FAPolicy ? installed : _fallback;
  }

  /// The policy used when the bean context holds none. Stateless, so one
  /// instance serves every login.
  static const Tom2FAPolicy _fallback = TomPrincipalFlag2FAPolicy();
}

/// What a [Tom2FAPolicy] implements when it grants **grace logins** and must
/// therefore remember how many are left.
///
/// [Tom2FADecision.graceLogins] says how many logins a principal may still
/// complete *without* setting up the factor they owe. Something has to spend
/// them, and the only party that can is the one that counts them — a server
/// that decremented a number it does not own would be keeping a second, silently
/// divergent tally.
///
/// A separate interface rather than a method on [Tom2FAPolicy], for the reason
/// `Tom2FAEnrolmentSupport` is separate from [Tom2FAService]: the shipped
/// policies are stateless and grant no grace, so the only honest body they could
/// give this method is an empty one — and a base contract whose implementations
/// mostly ignore it teaches callers to ignore it too. `is` makes "does this
/// policy do grace?" a question with a real answer.
abstract class Tom2FAGraceAccounting {
  /// Records that [context]'s principal has just spent one grace login by
  /// declining an enrolment offer.
  ///
  /// Called at the moment the grace is *used*, not when it is offered: a user
  /// who goes on to enrol has consumed nothing, and charging them for opening
  /// the dialog would run the account down without cause.
  Future<void> recordGraceLoginConsumed(Tom2FAContext context);
}

/// Where the grace a principal has already spent is remembered.
///
/// [Tom2FAGraceAccounting] says *when* a grace login is used; something has to
/// hold the running total, and this is it. Without one, a policy re-reads its
/// configured allowance on every login and hands the same number back — a
/// countdown that never counts down, and a `graceLogins: 3` that means "three
/// more, always".
///
/// ## Why the in-memory default is honest here and is not for enrolments
///
/// [Tom2FAEnrolmentStore.resolve] returns `null` rather than falling back,
/// because an enrolment that vanished on restart would lose a user their
/// factor. This one falls back to [TomMemory2FAGraceStore], because losing the
/// count degrades to *exactly the behaviour that existed before it was
/// counted*: the user is offered enrolment again and gets another few logins.
/// A restart can therefore make the budget longer and can never make it
/// shorter, so a per-process default cannot cost anyone access — and a store
/// that has to be installed before the counter counts is a counter most
/// deployments would not have.
///
/// A deployment that wants the budget to survive a restart, or to be one budget
/// across a cluster, implements this against its own user data — where the
/// principal already lives. The framework ships no table for it: the count is a
/// fact about a user, and this package has no user table.
abstract class Tom2FAGraceStore {
  /// How many grace logins [context]'s principal has already spent.
  Future<int> consumedBy(Tom2FAContext context);

  /// Records that one more has just been spent.
  Future<void> recordConsumed(Tom2FAContext context);

  /// The installed store, or the process-wide [TomMemory2FAGraceStore].
  static Tom2FAGraceStore resolve() {
    final installed = TomBean.getBeanByType(Tom2FAGraceStore);
    return installed is Tom2FAGraceStore
        ? installed
        : TomMemory2FAGraceStore.shared;
  }

  /// What a store files a principal's count under.
  ///
  /// The principal, and deliberately not the principal *and mechanism*: grace
  /// is spent by declining to enrol at all, which is a decision about the
  /// obligation rather than about any one way of meeting it. Keying by
  /// mechanism would hand a user a fresh allowance for every mechanism the
  /// deployment offers.
  static String principalKeyOf(Tom2FAContext context) =>
      context.principal.id.toString();
}

/// The default [Tom2FAGraceStore]: a map in this process.
///
/// **Per process**, and says so. A restart or a second node starts the count
/// again, which lengthens the budget and never shortens it — see
/// [Tom2FAGraceStore] for why that is an acceptable default here.
class TomMemory2FAGraceStore implements Tom2FAGraceStore {
  /// The process-wide instance [Tom2FAGraceStore.resolve] falls back to.
  static final TomMemory2FAGraceStore shared = TomMemory2FAGraceStore();

  final Map<String, int> _spent = {};

  /// How many principals have spent anything. Test-support.
  int get size => _spent.length;

  @override
  Future<int> consumedBy(Tom2FAContext context) async =>
      _spent[Tom2FAGraceStore.principalKeyOf(context)] ?? 0;

  @override
  Future<void> recordConsumed(Tom2FAContext context) async {
    final key = Tom2FAGraceStore.principalKeyOf(context);
    _spent[key] = (_spent[key] ?? 0) + 1;
  }

  /// Discards every count. Test-support only.
  void clear() => _spent.clear();
}

// =============================================================================
// SHIPPED IMPLEMENTATIONS
// =============================================================================

/// Reads the obligation straight off the principal.
///
/// [TomPrincipal.requires2FA] becomes [Tom2FARequirement.required] or
/// [Tom2FARequirement.disabled], and [TomPrincipal.twoFactorType] becomes the
/// sole allowed mechanism. That is exactly what the login did before policies
/// existed, which is the point: this is the default, so introducing the
/// abstraction changes no deployment's behaviour.
///
/// A principal that requires a factor but names no mechanism yields a `required`
/// decision with **no** allowed mechanism. The login rejects that clearly rather
/// than challenging with a mechanism key of `''`.
///
/// **Grants no grace at all**, and therefore counts none: every decision it
/// makes carries `graceLogins: 0`, so a `required` login with nothing enrolled
/// is offered enrolment it cannot decline. There is nowhere for a number to
/// come from — the principal's flags say *whether* a factor is owed and not how
/// long the user may put it off — and inventing one would be this policy
/// deciding something it was not told. A deployment that wants a grace period
/// uses [TomRole2FAPolicy], which is configured with one and counts it.
class TomPrincipalFlag2FAPolicy implements Tom2FAPolicy {
  /// Creates the flag-reading default policy.
  const TomPrincipalFlag2FAPolicy();

  @override
  Future<Tom2FADecision> decideFor(Tom2FAContext context) async {
    final principal = context.principal;
    if (!principal.requires2FA) {
      return Tom2FADecision(requirement: Tom2FARequirement.disabled);
    }
    final type = principal.twoFactorType;
    return Tom2FADecision(
      requirement: Tom2FARequirement.required,
      allowedMechanisms: (type == null || type.isEmpty) ? const [] : [type],
    );
  }
}

/// Decides by the principal's roles.
///
/// Each role the principal holds is looked up in [requirementByRole]; the
/// **strictest** match wins, so a user who is `admin` (required) and `viewer`
/// (optional) owes a factor. A principal matching no rule gets
/// [defaultRequirement].
///
/// Roles are read from the access-control information the principal already
/// carries ([TomPrincipal.aci]) — the same list authorization decisions use, so
/// a role that grants a privilege and a role that demands a second factor cannot
/// drift apart.
///
/// ```dart
/// TomBean.withType<Tom2FAPolicy>(TomRole2FAPolicy(
///   requirementByRole: {
///     'admin': Tom2FARequirement.required,
///     'staff': Tom2FARequirement.optional,
///   },
///   mechanisms: ['totp'],
/// ));
/// ```
class TomRole2FAPolicy implements Tom2FAPolicy, Tom2FAGraceAccounting {
  /// The requirement each role imposes. Roles absent from the map impose
  /// nothing — they neither raise nor lower the outcome.
  final Map<String, Tom2FARequirement> requirementByRole;

  /// The requirement for a principal holding no role named in
  /// [requirementByRole].
  final Tom2FARequirement defaultRequirement;

  /// The mechanisms a matched principal may use, in preference order, or `null`
  /// for *every registered mechanism*.
  ///
  /// `null` and `[]` are deliberately different: `null` is "this policy does not
  /// restrict the choice", `[]` is "no mechanism is permitted" — which makes a
  /// `required` decision unsatisfiable and fails the login. An empty list is
  /// never what an unset option should mean.
  final List<String>? mechanisms;

  /// How many logins a principal may complete while still owing a factor.
  ///
  /// A **budget**, not a per-login allowance: this policy implements
  /// [Tom2FAGraceAccounting], so each grace login actually spent is recorded in
  /// the [Tom2FAGraceStore] and the decision reports what is left. `3` means
  /// three logins in total, after which the enrolment offer stops being
  /// declinable.
  final int graceLogins;

  /// Creates a role-driven policy.
  TomRole2FAPolicy({
    Map<String, Tom2FARequirement> requirementByRole = const {},
    this.defaultRequirement = Tom2FARequirement.disabled,
    List<String>? mechanisms,
    this.graceLogins = 0,
  }) : requirementByRole = Map.unmodifiable(requirementByRole),
       mechanisms = mechanisms == null ? null : List.unmodifiable(mechanisms);

  @override
  Future<Tom2FADecision> decideFor(Tom2FAContext context) async {
    final roles = context.principal.aci.roles;

    Tom2FARequirement? matched;
    for (final role in roles) {
      final rule = requirementByRole[role];
      if (rule == null) continue;
      matched = matched == null ? rule : matched.strictest(rule);
    }
    final requirement = matched ?? defaultRequirement;
    final remaining = await _remainingGraceFor(context);

    if (requirement == Tom2FARequirement.disabled) {
      return Tom2FADecision(requirement: requirement, graceLogins: remaining);
    }
    return Tom2FADecision(
      requirement: requirement,
      allowedMechanisms: mechanisms ?? Tom2FARegistry.registeredTypes.toList(),
      graceLogins: remaining,
    );
  }

  @override
  Future<void> recordGraceLoginConsumed(Tom2FAContext context) =>
      Tom2FAGraceStore.resolve().recordConsumed(context);

  /// What is left of [graceLogins] for this principal.
  ///
  /// Never negative, and the store is not consulted at all when the policy
  /// grants no grace: a deployment that configured none should not pay a store
  /// read per login for an answer that is always zero.
  Future<int> _remainingGraceFor(Tom2FAContext context) async {
    if (graceLogins <= 0) return 0;
    final spent = await Tom2FAGraceStore.resolve().consumedBy(context);
    final left = graceLogins - spent;
    return left < 0 ? 0 : left;
  }
}
