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
/// Widget premiumFeature() { ... }
/// ```
///
/// See also:
/// - [TomPrincipal] for the authenticated user context
/// - [TomAccessControlInformation] for the user's access rights
library;

// =============================================================================
// IMPORTS
// =============================================================================

import '../little_things/little_things.dart';
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

  // TODO: check that these three parts are implemented
  /// When enabled, API endpoints are automatically protected based on metadata.
  static bool globalSettingUseAutomaticEndpointProtection = false;

  /// When enabled, JSON serialization automatically respects resource protection.
  static bool globalSettingUseAutomaticJsonProtection = false;

  /// When enabled, database queries automatically filter protected resources.
  static bool globalSettingUseAutomaticDatabaseProtection = false;

  /// When enabled, form fields are automatically protected based on their
  /// resource keys.
  static bool globalSettingUseAutomaticFormFieldProtection = false;

  /// When enabled, actions are automatically protected based on their resource
  /// keys.
  static bool globalSettingUseAutomaticActionProtection = false;

  /// When enabled, a protected action that the principal may not trigger is
  /// automatically disabled rather than hidden.
  static bool globalSettingUseAutomaticActionProtectionForDisabling = false;

  /// Protects a value based on resource key access.
  ///
  /// Returns [data] if the current user has access to [resourceKey],
  /// otherwise returns [fallback].
  ///
  /// - [data]: The actual value to return if access is granted
  /// - [fallback]: The value to return if access is denied
  /// - [resourceKey]: The key identifying the protected resource
  static T protect<T>(T data, T fallback, String resourceKey) {
    if (isProtected(resourceKey)) return fallback;
    return data;
  }

  /// Checks if a resource is protected from the current user.
  ///
  /// Returns `true` if the resource is protected (user lacks access),
  /// `false` if the resource is accessible.
  ///
  /// - [resourceKey]: The key identifying the resource to check
  // TODO: plugin actual check for resource access here...
  static bool isProtected(String resourceKey) {
    if (!globalSettingProtectionDefault) return false;
    var authentication = getFromCurrentZone<TomPrincipal>();
    if (authentication != null) {
      return !authentication.aci.resourceKeys.contains(resourceKey);
    }
    return true;
  }
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Convenience function to protect a value based on resource key access.
///
/// This is a shorthand for [TomResourceKeyProtection.protect].
///
/// ```dart
/// var visibleEmail = tomProtect(user.email, '[hidden]', 'user.email');
/// ```
T tomProtect<T>(T data, T fallback, String resourceKey) {
  return TomResourceKeyProtection.protect<T>(data, fallback, resourceKey);
}

/// Convenience function to check if a resource is protected.
///
/// This is a shorthand for [TomResourceKeyProtection.isProtected].
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
/// All access control implementations must override [checkAccessibility]
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
abstract class TomAccessControl {
  const TomAccessControl();

  /// Checks if the given [principal] has access.
  ///
  /// Returns `true` if access is granted, `false` otherwise.
  /// A `null` principal typically represents an unauthenticated user.
  bool checkAccessibility(TomPrincipal? principal) => false;

  /// Resolves this access control to a four-state [TomAuthState].
  ///
  /// The default bridges the binary [checkAccessibility] onto two states —
  /// granted → [TomAuthState.full], denied → [TomAuthState.none] — so every
  /// existing binary access control (role/group/entitlement/etc.) keeps its
  /// meaning unchanged while gaining a four-state outcome. Controls that need
  /// to express [TomAuthState.read] (read-only) or [TomAuthState.disabled]
  /// (visible but locked) override this method; see [TomGradedAccess].
  TomAuthState resolveAuthState(TomPrincipal? principal) =>
      checkAccessibility(principal) ? TomAuthState.full : TomAuthState.none;
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
  })  : read = read ?? full,
        disabled = disabled ?? read ?? full;

  @override
  TomAuthState resolveAuthState(TomPrincipal? principal) {
    if (full.checkAccessibility(principal)) return TomAuthState.full;
    if (read.checkAccessibility(principal)) return TomAuthState.read;
    if (disabled.checkAccessibility(principal)) return TomAuthState.disabled;
    return TomAuthState.none;
  }

  @override
  bool checkAccessibility(TomPrincipal? principal) =>
      resolveAuthState(principal).showsContent;
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
  bool checkAccessibility(TomPrincipal? principal) => false;
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
  bool checkAccessibility(TomPrincipal? principal) => true;
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
  bool checkAccessibility(TomPrincipal? principal) =>
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
  bool checkAccessibility(TomPrincipal? principal) =>
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
  bool checkAccessibility(TomPrincipal? principal) =>
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
class TomEntitlementAccess extends TomAccessControl {
  /// List of regex patterns to match against user entitlements.
  final List<String> patterns;

  /// Creates an entitlement-based access control.
  ///
  /// - [patterns]: List of regex patterns; access is granted if any match
  const TomEntitlementAccess(this.patterns);

  @override
  bool checkAccessibility(TomPrincipal? principal) {
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
  bool checkAccessibility(TomPrincipal? principal) {
    if (principal != null) {
      for (var r in roles) {
        if (principal.aci.roles.contains(r)) {
          return true;
        }
      }
    }
    return false;
  }
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
  bool checkAccessibility(TomPrincipal? principal) {
    if (principal != null) {
      for (var g in groups) {
        if (principal.aci.groups.contains(g)) {
          return true;
        }
      }
    }
    return false;
  }
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
/// Widget salaryField() { ... }
/// ```
class TomResourceKeyAccess extends TomAccessControl {
  /// The resource key to check.
  final String key;

  /// Creates a resource key-based access control.
  ///
  /// - [key]: The resource key to check for protection
  const TomResourceKeyAccess(this.key);

  @override
  bool checkAccessibility(TomPrincipal? principal) =>
      !TomResourceKeyProtection.isProtected(key);
}
