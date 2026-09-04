/// Access control system for the Tom framework.
///
/// This library provides a comprehensive access control system that enables
/// fine-grained authorization for resources, endpoints, and data fields.
/// It supports multiple authorization paradigms including:
///
/// - **Role-based access control (RBAC)**: Grant access based on user roles
/// - **Group-based access control**: Grant access based on group membership
/// - **Entitlement-based access control**: Grant access based on entitlements
/// - **Resource key protection**: Protect individual data fields or resources
/// - **Custom access handlers**: Implement custom authorization logic
///
/// ## Usage Example
///
/// ```dart
/// // Check if a resource is accessible
/// if (!tomProtected('user.email')) {
///   displayEmail(user.email);
/// }
///
/// // Use access control annotations on endpoints
/// @TomRoleAccess(['admin', 'manager'])
/// void deleteUser(int userId) { ... }
///
/// // Use entitlement-based access
/// @TomEntitlementAccess(['feature.premium.*'])
/// void runPremiumFeature() { ... }
/// ```
///
/// See also:
/// - [TomPrincipal] for the authenticated user context
/// - [TomAccessControlInformation] for the user's access rights
library;

// =============================================================================
// IMPORTS
// =============================================================================

import 'package:meta/meta.dart';

import '../little_things/little_things.dart';
import 'server_principal.dart';
import 'tom_authorization.dart';
import 'user_principal_aci.dart';

// =============================================================================
// RESOURCE KEY PROTECTION
// =============================================================================

/// Provides resource-level protection based on resource keys.
///
/// This class implements a protection mechanism that can selectively hide
/// or expose data based on the current user's access rights. It integrates
/// with the zone-based [TomPrincipal] to determine accessibility.
///
/// ## Global Settings
///
/// The protection behavior can be controlled through global settings:
/// - [globalSettingProtectionDefault]: Master switch for protection
/// - [globalSettingUseAutomaticEndpointProtection]: Auto-protect API endpoints
/// - [globalSettingUseAutomaticJsonProtection]: Auto-protect JSON serialization
/// - [globalSettingUseAutomaticDatabaseProtection]: Auto-protect database queries
/// - [globalSettingUseAutomaticFormFieldProtection]: Auto-protect form fields
/// - [globalSettingUseAutomaticActionProtection]: Auto-protect actions
/// - [globalSettingUseAutomaticActionProtectionForDisabling]: Auto-disable action triggers like buttons
///
/// Of the six automatic switches, **only
/// [globalSettingUseAutomaticEndpointProtection] currently does anything** —
/// the server's endpoint pipeline consults it. The other five are declared and
/// documented but read by nothing, so setting one to `true` has no effect. Each
/// says so on its own declaration; do not rely on one until it does.
///
/// ## Example
///
/// ```dart
/// // Enable protection globally
/// TomResourceKeyProtection.globalSettingProtectionDefault = true;
///
/// // Protect a field - returns fallback if user lacks access
/// var email = TomResourceKeyProtection.protect(
///   user.email,
///   '[hidden]',
///   'user.email',
/// );
/// ```
class TomResourceKeyProtection {
  /// Master switch to enable/disable resource protection globally.
  ///
  /// When `false`, all resources are accessible. When `true`, resource
  /// access is evaluated based on the current principal's resource keys.
  static bool globalSettingProtectionDefault = false;

  // TODO: five of the six switches below have no reader anywhere. Decide per
  // switch whether to implement the tier or delete the flag — a `bool` that
  // reads like a control and performs nothing is worse than an absent one.

  /// When enabled, API endpoints are automatically protected based on metadata.
  ///
  /// The one automatic switch that is honoured: `tom_core_server`'s endpoint
  /// pipeline consults it when the ordinary access check has already refused.
  static bool globalSettingUseAutomaticEndpointProtection = false;

  /// When enabled, JSON serialization automatically respects resource protection.
  ///
  /// **Not implemented.** Nothing reads this flag; the `json` module does not
  /// reference resource-key protection at all.
  static bool globalSettingUseAutomaticJsonProtection = false;

  /// When enabled, database queries automatically filter protected resources.
  ///
  /// **Not implemented.** Nothing reads this flag; `object_persistence` does
  /// not reference resource-key protection at all.
  static bool globalSettingUseAutomaticDatabaseProtection = false;

  /// When enabled, form fields are automatically protected based on their
  /// resource keys.
  ///
  /// **Not implemented.** Nothing reads this flag. Form fields resolve their
  /// visibility from [TomAuthState] instead — see `tom_flutter_ui`'s forms.
  static bool globalSettingUseAutomaticFormFieldProtection = false;

  /// When enabled, actions are automatically protected based on their resource
  /// keys.
  ///
  /// **Not implemented.** Nothing reads this flag.
  static bool globalSettingUseAutomaticActionProtection = false;

  /// When enabled, a protected action that the principal may not trigger is
  /// automatically disabled rather than hidden.
  ///
  /// **Not implemented.** Nothing reads this flag.
  static bool globalSettingUseAutomaticActionProtectionForDisabling = false;

  /// Protects a value based on [principal]'s resource key access.
  ///
  /// Returns [data] if [principal] holds [resourceKey], otherwise [fallback].
  /// A `null` principal holds no keys, so it gets [fallback].
  ///
  /// This is [protect] stated over an explicit operand, and it is the form to
  /// reach for whenever a principal is already in hand — reading the zone when
  /// the caller named someone answers a different question. It matters most
  /// where the two differ irreconcilably: minting a token for a principal
  /// *being authenticated* means there is no principal on the zone yet, so the
  /// zone-reading form is fail-closed and blanks every protected field.
  ///
  /// **Requires [globalSettingProtectionDefault] to be `true`.** It defaults to
  /// `false`, and while it is off this returns [data] for every key and every
  /// principal — so a call added for protection protects nothing until the
  /// switch is set.
  ///
  /// - [principal]: The principal whose keys decide access, or `null`
  /// - [data]: The actual value to return if access is granted
  /// - [fallback]: The value to return if access is denied
  /// - [resourceKey]: The key identifying the protected resource
  static T protectFor<T>(
    TomPrincipal? principal,
    T data,
    T fallback,
    String resourceKey,
  ) {
    if (isProtectedFor(principal, resourceKey)) return fallback;
    return data;
  }

  /// Protects a value based on the current user's resource key access.
  ///
  /// Returns [data] if the current user — the principal installed on the
  /// ambient zone — has access to [resourceKey], otherwise returns [fallback].
  /// Where a principal is already in hand, call [protectFor] instead.
  ///
  /// **Requires [globalSettingProtectionDefault] to be `true`.** It defaults to
  /// `false`, and while it is off this returns [data] for every key and every
  /// principal — so a call added for protection protects nothing until the
  /// switch is set.
  ///
  /// - [data]: The actual value to return if access is granted
  /// - [fallback]: The value to return if access is denied
  /// - [resourceKey]: The key identifying the protected resource
  static T protect<T>(T data, T fallback, String resourceKey) {
    if (isProtected(resourceKey)) return fallback;
    return data;
  }

  /// Checks if a resource is protected from [principal].
  ///
  /// Returns `true` if the resource is protected (the principal lacks access),
  /// `false` if the resource is accessible. A `null` [principal] is treated as
  /// holding no keys, so a protected resource is out of its reach.
  ///
  /// Gated on [globalSettingProtectionDefault]: while that is `false` — its
  /// default — this answers `false` for every key and every principal, before
  /// any key is consulted.
  ///
  /// This is the rule itself, stated over an explicit operand. [isProtected]
  /// applies it to whoever the ambient zone names; [TomResourceKeyAccess]
  /// applies it to the principal its caller asked about.
  ///
  /// - [principal]: The principal whose keys decide access, or `null`
  /// - [resourceKey]: The key identifying the resource to check
  // TODO: plugin actual check for resource access here...
  static bool isProtectedFor(TomPrincipal? principal, String resourceKey) {
    if (!globalSettingProtectionDefault) return false;
    if (principal == null) return true;
    return !principal.aci.resourceKeys.contains(resourceKey);
  }

  /// Checks if a resource is protected from the current user.
  ///
  /// The "current user" is the principal installed on the ambient zone. Where
  /// a principal is already in hand, call [isProtectedFor] instead — reading
  /// the zone when the caller named someone answers a different question.
  ///
  /// Returns `true` if the resource is protected (user lacks access),
  /// `false` if the resource is accessible.
  ///
  /// Gated on [globalSettingProtectionDefault] exactly as [isProtectedFor] is.
  /// Note the two ways this answers `false`: protection switched off (nothing
  /// is protected) and the principal holding the key. Outside a request zone
  /// there is no principal, so with protection on this answers `true` for
  /// everything — fail-closed.
  ///
  /// - [resourceKey]: The key identifying the resource to check
  static bool isProtected(String resourceKey) =>
      isProtectedFor(getFromCurrentZone<TomPrincipal>(), resourceKey);
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Convenience function to protect a value based on resource key access.
///
/// This is a shorthand for [TomResourceKeyProtection.protect], and inherits its
/// precondition: nothing is protected until
/// [TomResourceKeyProtection.globalSettingProtectionDefault] is `true`.
///
/// ```dart
/// // Once, at start-up — otherwise the call below is a no-op.
/// TomResourceKeyProtection.globalSettingProtectionDefault = true;
///
/// var visibleEmail = tomProtect(user.email, '[hidden]', 'user.email');
/// ```
T tomProtect<T>(T data, T fallback, String resourceKey) {
  return TomResourceKeyProtection.protect<T>(data, fallback, resourceKey);
}

/// Convenience function to check if a resource is protected.
///
/// This is a shorthand for [TomResourceKeyProtection.isProtected], and inherits
/// its precondition: while
/// [TomResourceKeyProtection.globalSettingProtectionDefault] is `false` — its
/// default — this always answers `false` and the guard below always passes.
///
/// ```dart
/// if (!tomProtected('user.email')) {
///   print(user.email);
/// }
/// ```
bool tomProtected(String resourceKey) {
  return TomResourceKeyProtection.isProtected(resourceKey);
}

// =============================================================================
// ACCESS CONTROL BASE CLASS
// =============================================================================

/// Abstract base class for all access control types.
///
/// Extend this class to implement custom access control logic.
/// All access control implementations must override [checkPrincipalAccess]
/// to determine if a [TomPrincipal] should have access.
///
/// ## Built-in Implementations
///
/// - [TomNoAccess]: Denies all access
/// - [TomPublicAccess]: Allows all access
/// - [TomAuthenticatedAccess]: Requires authenticated user
/// - [TomGuestAccess]: Allows guests and authenticated users
/// - [TomRoleAccess]: Requires specific roles
/// - [TomGroupAccess]: Requires group membership
/// - [TomEntitlementAccess]: Requires specific entitlements
/// - [TomResourceKeyAccess]: Checks resource key protection
/// - [TomCustomAccess]: Delegates to custom handler
/// - [TomGradedAccess]: Composes three of the above into all four
///   [TomAuthState] values — the only built-in that can resolve to
///   [TomAuthState.disabled] or [TomAuthState.read]
///
/// ## Two operands: the user and the deployment
///
/// Evaluation has **two** operands, not one. A user's grant is met with the
/// grant of the deployment the code is running in — the *ambient server
/// principal* ([TomServerPrincipal]) — and the effective answer is the more
/// restrictive of the two: `min(user, server)` over the four-state ladder,
/// binary AND for two-state controls. A user's [TomAuthState.full] on a feature
/// this deployment is not entitled to evaluates to [TomAuthState.none]. The
/// deployment's grants cap every user's grants; they never widen them.
///
/// ## What subclasses implement
///
/// The public entry points [checkAccessibility] and [resolveAuthState] compute
/// that meet and are **not overridable** — a cap that any subclass could
/// sidestep by overriding the method everybody already calls would not be a cap
/// at all. Subclasses instead implement the two hooks:
///
/// - [checkPrincipalAccess] / [resolvePrincipalAuthState] — the *user* operand:
///   what this control demands of the calling principal. This is the whole of
///   a subclass's own rule; nothing about the deployment belongs here.
/// - [resolveServerAuthState] — the *deployment* operand: what grade this
///   control's subject is granted to the deployment. It defaults to
///   [TomAuthState.full] (uncapped), because most controls name a *user*
///   requirement (a role, a group, a resource key) and say nothing about
///   deployment features. [TomEntitlementAccess] is the grant carrier that
///   actually answers it.
abstract class TomAccessControl {
  const TomAccessControl();

  // ---------------------------------------------------------------------------
  // Hooks — implemented by subclasses, never called directly by consumers.
  // ---------------------------------------------------------------------------

  /// The **user** operand: whether [principal] satisfies this control.
  ///
  /// Returns `true` if the principal's own grants suffice, `false` otherwise.
  /// A `null` principal typically represents an unauthenticated user.
  ///
  /// This answer is deliberately *un*capped — it is one half of the meet the
  /// public [checkAccessibility] computes. Consumers want that public method;
  /// this one exists for subclasses to implement and for composite controls
  /// (like [TomGradedAccess]) to interrogate their children without the cap
  /// being applied once per nesting level.
  bool checkPrincipalAccess(TomPrincipal? principal) => false;

  /// The **user** operand resolved to a four-state [TomAuthState].
  ///
  /// The default bridges the binary [checkPrincipalAccess] onto two states —
  /// granted → [TomAuthState.full], denied → [TomAuthState.none] — so every
  /// binary access control (role/group/entitlement/etc.) keeps its meaning
  /// while gaining a four-state outcome. Controls that need to express
  /// [TomAuthState.read] (read-only) or [TomAuthState.disabled] (visible but
  /// locked) override this; see [TomGradedAccess].
  TomAuthState resolvePrincipalAuthState(TomPrincipal? principal) =>
      checkPrincipalAccess(principal) ? TomAuthState.full : TomAuthState.none;

  /// The **deployment** operand: the highest grade this control's subject is
  /// granted to the deployment identified by [serverPrincipal].
  ///
  /// Defaults to [TomAuthState.full] — *uncapped*. That default is the correct
  /// one rather than a lenient shortcut: a control that names a user role, a
  /// group or a resource key expresses nothing about which **features** a
  /// deployment licenses, so it has no opinion to contribute to the meet, and a
  /// participant with no opinion must return the identity element. Returning
  /// anything lower would make an unrelated deployment grant silently veto a
  /// role check.
  ///
  /// [TomEntitlementAccess] overrides this — entitlement patterns *are* the
  /// grant carrier — and [TomGradedAccess] composes its children's answers into
  /// the ladder.
  TomAuthState resolveServerAuthState(TomPrincipal serverPrincipal) =>
      TomAuthState.full;

  // ---------------------------------------------------------------------------
  // Public evaluation — the meet. Not overridable.
  // ---------------------------------------------------------------------------

  /// Resolves the **effective** four-state authorization for [principal]: the
  /// user's grade met with the deployment's.
  ///
  /// When no server principal is installed the deployment has no identity to
  /// cap with, and the result is the user's grade alone — byte-for-byte the
  /// behaviour of every deployment built before server-as-principal existed.
  /// This is why the guard tests [TomServerPrincipal.current] for `null` rather
  /// than evaluating against an empty principal: an empty entitlement set means
  /// "entitled to nothing" and would deny everything.
  @nonVirtual
  TomAuthState resolveAuthState(TomPrincipal? principal) {
    final userState = resolvePrincipalAuthState(principal);
    final server = TomServerPrincipal.current;
    if (server == null) return userState;
    return userState.narrow(resolveServerAuthState(server));
  }

  /// Whether [principal] may see this control's content, deployment cap
  /// included.
  ///
  /// Defined as [TomAuthState.showsContent] over [resolveAuthState], so the
  /// binary and graded views can never disagree. For a two-state control this
  /// is exactly the plain AND of the user's grant and the deployment's, which
  /// is what the meet degenerates to when neither operand can express the
  /// middle states.
  @nonVirtual
  bool checkAccessibility(TomPrincipal? principal) =>
      resolveAuthState(principal).showsContent;
}

// =============================================================================
// GRADED ACCESS CONTROL — composes binary controls into all four states
// =============================================================================

/// Access control that resolves to **all four** [TomAuthState] values by
/// composing three binary controls — one each named after the state it grants:
/// [full], [read], and [disabled].
///
/// Resolution, from most to least privileged:
///
/// - [full] grants → [TomAuthState.full] (interactive/editable)
/// - else [read] grants → [TomAuthState.read] (value visible, not editable)
/// - else [disabled] grants → [TomAuthState.disabled] (rendered but locked)
/// - else → [TomAuthState.none] (hidden)
///
/// When [read] is omitted it defaults to [full]; when [disabled] is omitted it
/// defaults to [read]. This preserves the natural monotonicity that anyone who
/// can edit can also read and see, so the common case only needs a single
/// control.
///
/// For binary consumers, [checkAccessibility] collapses to "can see content"
/// ([TomAuthState.showsContent]): a [TomAuthState.read] or [TomAuthState.full]
/// outcome is accessible; [TomAuthState.disabled] and [TomAuthState.none] are
/// not.
///
/// ```dart
/// final salary = TomGradedAccess(
///   full: const TomRoleAccess(['payroll.admin']),
///   read: const TomRoleAccess(['manager']),
///   disabled: const TomAuthenticatedAccess(),
/// );
/// final state = salary.resolveAuthState(currentPrincipal);
/// // payroll.admin → full, manager → read, other staff → disabled,
/// // anonymous → none.
/// ```
class TomGradedAccess extends TomAccessControl {
  /// Grants full access → resolves to [TomAuthState.full].
  final TomAccessControl full;

  /// Grants read access → resolves to [TomAuthState.read]. Defaults to [full].
  final TomAccessControl read;

  /// Grants visibility → resolves to [TomAuthState.disabled]. Defaults to
  /// [read].
  final TomAccessControl disabled;

  /// Creates a graded access control.
  ///
  /// Only [full] is required; [read] defaults to [full] and [disabled]
  /// defaults to [read].
  TomGradedAccess({
    required this.full,
    TomAccessControl? read,
    TomAccessControl? disabled,
  }) : read = read ?? full,
       disabled = disabled ?? read ?? full;

  @override
  TomAuthState resolvePrincipalAuthState(TomPrincipal? principal) {
    // The children are asked for their *uncapped* verdict. Applying the
    // deployment cap here as well as at the top would apply it once per nesting
    // level, and a cap that composes with itself down a tree stops being
    // `min(user, server)` — it becomes an arbitrary function of the tree shape.
    if (full.checkPrincipalAccess(principal)) return TomAuthState.full;
    if (read.checkPrincipalAccess(principal)) return TomAuthState.read;
    if (disabled.checkPrincipalAccess(principal)) return TomAuthState.disabled;
    return TomAuthState.none;
  }

  /// The deployment's grade for this graded control: the same ladder, walked
  /// against the *server's* grants instead of the user's.
  ///
  /// A tier counts as granted to the deployment when its child reports itself
  /// fully granted. So a deployment entitled to a feature's view tier but not
  /// its edit tier yields [TomAuthState.read], which caps even an editing user
  /// down to read — the worked example in `codespecs_mapping.md` §5.26,
  /// falling straight out of the structure rather than out of a special case.
  ///
  /// Note the asymmetry with [resolvePrincipalAuthState]: children that express
  /// no deployment opinion answer [TomAuthState.full] (the identity element),
  /// so a graded tree of pure role checks resolves to `full` here and caps
  /// nothing.
  @override
  TomAuthState resolveServerAuthState(TomPrincipal serverPrincipal) {
    if (full.resolveServerAuthState(serverPrincipal) == TomAuthState.full) {
      return TomAuthState.full;
    }
    if (read.resolveServerAuthState(serverPrincipal) == TomAuthState.full) {
      return TomAuthState.read;
    }
    if (disabled.resolveServerAuthState(serverPrincipal) == TomAuthState.full) {
      return TomAuthState.disabled;
    }
    return TomAuthState.none;
  }
}

// =============================================================================
// BASIC ACCESS CONTROL IMPLEMENTATIONS
// =============================================================================

/// Denies access to all users.
///
/// Use this to temporarily disable a feature or endpoint without
/// removing the code. Useful for maintenance or staged rollouts.
///
/// ```dart
/// @TomNoAccess()
/// void deprecatedEndpoint() { ... }
/// ```
class TomNoAccess extends TomAccessControl {
  const TomNoAccess();

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) => false;
}

/// Allows access to all users, including unauthenticated ones.
///
/// Use this for public endpoints that don't require any authentication.
///
/// ```dart
/// @TomPublicAccess()
/// String getPublicInfo() => 'Hello, World!';
/// ```
class TomPublicAccess extends TomAccessControl {
  const TomPublicAccess();

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) => true;
}

/// Requires a fully authenticated user (not a guest).
///
/// Use this for endpoints that require a logged-in user with
/// verified credentials. Guest users are explicitly denied.
///
/// ```dart
/// @TomAuthenticatedAccess()
/// UserProfile getMyProfile() => currentUser.profile;
/// ```
class TomAuthenticatedAccess extends TomAccessControl {
  const TomAuthenticatedAccess();

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) =>
      principal != null &&
      principal.authenticated &&
      principal.username != TomUser.guestUsername;
}

/// Allows authenticated users and guest users.
///
/// Use this for endpoints that should be accessible to anyone
/// who has at least a guest session (e.g., shopping cart functionality
/// before checkout).
///
/// ```dart
/// @TomGuestAccess()
/// void addToCart(Item item) { ... }
/// ```
class TomGuestAccess extends TomAccessControl {
  const TomGuestAccess();

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) =>
      principal != null &&
      (principal.authenticated || principal.username == TomUser.guestUsername);
}

// =============================================================================
// CUSTOM ACCESS CONTROL
// =============================================================================

/// Function signature for custom access control handlers.
///
/// - [principal]: The current user's principal (may be null)
/// - [id]: A resource identifier for context-specific checks
///
/// Returns `true` if access is granted, `false` otherwise.
typedef TomAccessControlHandler =
    bool Function(TomPrincipal? principal, String id);

/// Delegates access control to a registered custom handler.
///
/// This allows implementing complex authorization logic that doesn't
/// fit into the standard role/group/entitlement model.
///
/// ## Registering a Handler
///
/// ```dart
/// TomCustomAccess.registerHandler('canEditDocument', (principal, docId) {
///   if (principal == null) return false;
///   return DocumentService.isOwner(principal.id, int.parse(docId));
/// });
/// ```
///
/// ## Using the Handler
///
/// ```dart
/// @TomCustomAccess(handler: 'canEditDocument', resourceId: '123')
/// void updateDocument(Document doc) { ... }
/// ```
class TomCustomAccess extends TomAccessControl {
  static final Map<String, TomAccessControlHandler> _registeredHandlers = {};

  /// Registers a custom access control handler.
  ///
  /// - [name]: Unique identifier for the handler
  /// - [handler]: The function that evaluates access
  ///
  /// Throws [Exception] if a handler with [name] already exists.
  static void registerHandler(String name, TomAccessControlHandler handler) {
    if (_registeredHandlers[name] != null) {
      throw Exception(
        "AccessControlHandler with name $name already registered.",
      );
    }
    _registeredHandlers[name] = handler;
  }

  /// Retrieves a registered handler by name.
  ///
  /// Throws [Exception] if no handler with [name] exists.
  static TomAccessControlHandler getHandler(String name) {
    if (_registeredHandlers[name] == null) {
      throw Exception("AccessControlHandler with name $name doesn't exist");
    }
    return _registeredHandlers[name]!;
  }

  /// Checks if a handler with the given [name] exists.
  static bool handlerExists(String name) => _registeredHandlers[name] != null;

  /// The name of the registered handler to use.
  final String handler;

  /// An identifier passed to the handler for resource-specific checks.
  final String resourceId;

  /// Creates a custom access control that delegates to a named handler.
  ///
  /// - [handler]: Name of the registered handler
  /// - [resourceId]: Resource identifier passed to the handler
  const TomCustomAccess({required this.handler, required this.resourceId});

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) =>
      getHandler(handler)(principal, resourceId);

  /// Verifies that the handler for this access control exists.
  ///
  /// Returns `true` if the handler is registered, `false` otherwise.
  /// Use this at startup to validate configuration.
  bool verifyHandler() => handlerExists(handler);
}

// =============================================================================
// ENTITLEMENT-BASED ACCESS CONTROL
// =============================================================================

/// Grants access based on entitlement patterns.
///
/// Entitlements are fine-grained permissions that can be assigned to
/// users, groups, or roles. This access control checks if the user
/// has any entitlement matching the specified patterns.
///
/// Patterns are evaluated as regular expressions, allowing for
/// flexible matching:
///
/// ```dart
/// // Match exact entitlement
/// @TomEntitlementAccess(['feature.reports.view'])
///
/// // Match any reports entitlement
/// @TomEntitlementAccess([r'feature\.reports\..*'])
///
/// // Match multiple patterns (OR logic)
/// @TomEntitlementAccess(['admin.*', 'feature.reports.edit'])
/// ```
///
/// ## Also the deployment's grant carrier
///
/// Entitlements are the one requirement kind that means the same thing on both
/// sides of the meet. Asked about a *user* they answer "may this person use the
/// feature"; asked about the *ambient server principal* they answer "is this
/// deployment licensed for the feature at all". That is why
/// `codespecs_mapping.md` §5.26 needs no new class for server-level grants —
/// the same pattern set, matched against the other principal. A deployment
/// whose entitlements do not match caps the feature to [TomAuthState.none] no
/// matter what the user holds.
class TomEntitlementAccess extends TomAccessControl {
  /// List of regex patterns to match against user entitlements.
  final List<String> patterns;

  /// Creates an entitlement-based access control.
  ///
  /// - [patterns]: List of regex patterns; access is granted if any match
  const TomEntitlementAccess(this.patterns);

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) {
    if (principal != null && principal.aci.entitlements.isNotEmpty) {
      for (var p in patterns) {
        String entitlement = principal.aci.entitlements.firstWhere(
          (e) => RegExp(p).hasMatch(e),
          orElse: () => "",
        );
        if (entitlement.isNotEmpty) return true;
      }
    }
    return false;
  }

  /// The deployment operand: the very same pattern match, run against the
  /// server's entitlement set.
  ///
  /// This is the whole of the "grant carrier" in `codespecs_mapping.md` §5.26
  /// — a feature is granted to this deployment iff the server principal's
  /// entitlements match the feature's pattern.
  @override
  TomAuthState resolveServerAuthState(TomPrincipal serverPrincipal) =>
      checkPrincipalAccess(serverPrincipal)
      ? TomAuthState.full
      : TomAuthState.none;
}

// =============================================================================
// SHARED MATCHING HELPER
// =============================================================================

/// Returns `true` when [principal] is non-null and any entry in [candidates]
/// is present in the ACI string collection chosen by [selectCollection].
///
/// [TomRoleAccess] and [TomGroupAccess] share an identical accessibility rule —
/// "granted if the principal's ACI lists any of the requested names" —
/// differing only in which ACI collection they consult. This helper *is* that
/// rule; each class supplies the collection selector. Entitlement access is
/// deliberately not routed through here: it matches by regular expression
/// rather than exact containment, a genuinely different rule.
bool _principalAciContainsAny(
  TomPrincipal? principal,
  List<String> candidates,
  List<String> Function(TomAccessControlInformation aci) selectCollection,
) {
  if (principal == null) return false;
  final collection = selectCollection(principal.aci);
  for (final candidate in candidates) {
    if (collection.contains(candidate)) return true;
  }
  return false;
}

// =============================================================================
// ROLE-BASED ACCESS CONTROL
// =============================================================================

/// Grants access based on user roles.
///
/// Roles represent job functions or responsibilities (e.g., 'admin',
/// 'manager', 'user'). This is the most common access control pattern.
///
/// ```dart
/// // Require admin role
/// @TomRoleAccess(['admin'])
/// void deleteAllUsers() { ... }
///
/// // Allow admin OR manager (OR logic)
/// @TomRoleAccess(['admin', 'manager'])
/// void viewReports() { ... }
/// ```
class TomRoleAccess extends TomAccessControl {
  /// List of roles that grant access.
  final List<String> roles;

  /// Creates a role-based access control.
  ///
  /// - [roles]: List of role names; access is granted if user has any
  const TomRoleAccess(this.roles);

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) =>
      _principalAciContainsAny(principal, roles, (aci) => aci.roles);
}

// =============================================================================
// GROUP-BASED ACCESS CONTROL
// =============================================================================

/// Grants access based on group membership.
///
/// Groups represent organizational units or teams. Users can be members
/// of multiple groups, and groups can be nested (membership is resolved
/// transitively).
///
/// ```dart
/// // Require membership in finance team
/// @TomGroupAccess(['finance'])
/// void viewFinancialReports() { ... }
///
/// // Allow either department (OR logic)
/// @TomGroupAccess(['hr', 'management'])
/// void viewEmployeeDetails() { ... }
/// ```
class TomGroupAccess extends TomAccessControl {
  /// List of groups that grant access.
  final List<String> groups;

  /// Creates a group-based access control.
  ///
  /// - [groups]: List of group names; access is granted if user is in any
  const TomGroupAccess(this.groups);

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) =>
      _principalAciContainsAny(principal, groups, (aci) => aci.groups);
}

// =============================================================================
// RESOURCE KEY ACCESS CONTROL
// =============================================================================

/// Grants access based on resource key protection.
///
/// This integrates with [TomResourceKeyProtection] to provide
/// field-level or resource-level access control.
///
/// ```dart
/// @TomResourceKeyAccess('user.salary')
/// int readSalary(User user) { ... }
/// ```
///
/// Unlike its siblings, this control has a second operand: while
/// [TomResourceKeyProtection.globalSettingProtectionDefault] is `false`,
/// resource keys are not enforced at all and every principal is granted. Once
/// it is on, the rule is the ordinary one — the principal's own
/// `aci.resourceKeys` must contain [key].
///
/// It is deliberately *not* routed through the shared ACI helper the role and
/// group controls use: that master switch is a genuinely different rule, in
/// the same way entitlement matching is.
class TomResourceKeyAccess extends TomAccessControl {
  /// The resource key to check.
  final String key;

  /// Creates a resource key-based access control.
  ///
  /// - [key]: The resource key to check for protection
  const TomResourceKeyAccess(this.key);

  @override
  bool checkPrincipalAccess(TomPrincipal? principal) =>
      !TomResourceKeyProtection.isProtectedFor(principal, key);
}
