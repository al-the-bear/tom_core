/// Per-principal-per-resource role authorization (C-5).
///
/// The kernel's global [TomAccessControlInformation.roles] answer "*what is this
/// principal, everywhere?*". This library answers the finer question "*what is
/// this principal **on this resource**?*": a principal carries a
/// `resourceKey → roleName` map ([TomAccessControlInformation.resourceRoles]) so
/// the same principal can be `owner` of one resource and `viewer` of another at
/// the same time.
///
/// Two pieces make that resolvable to a [TomAuthState]:
///
/// - [TomResourceRoleRegistry] — the process-wide `roleName → TomAuthState`
///   table. Roles are opaque strings in the grant data; the registry is where an
///   application declares what each role *means* as a resource-level state
///   (e.g. `owner → full`, `viewer → read`).
/// - [TomResourceRoleAdapter] — a [TomAuthorizationAdapter] that resolves a
///   resource key by looking up the principal's role for it and mapping that
///   role through the registry.
///
/// **No fallback (C-5 done-bar).** A resource the principal has no role on
/// resolves to [TomAuthState.none] — it does not degrade to the global roles or
/// to `full`. Likewise a role with no registry entry resolves to
/// [TomAuthState.none]: an unknown role grants nothing rather than silently
/// granting access.
library;

import 'item_permissions.dart';
import 'tom_authorization.dart';

// =============================================================================
// TomResourceRoleRegistry — role name → resource-level TomAuthState
// =============================================================================

/// Process-wide registry mapping a role name to the resource-level
/// [TomAuthState] a principal holding that role has on a resource.
///
/// Populated once at application startup (client and server both declare the
/// same mapping so enforcement and presentation agree):
///
/// ```dart
/// TomResourceRoleRegistry.registerAll({
///   'owner': TomAuthState.full,
///   'editor': TomAuthState.full,
///   'commenter': TomAuthState.read,
///   'viewer': TomAuthState.read,
/// });
/// ```
class TomResourceRoleRegistry {
  TomResourceRoleRegistry._();

  static final Map<String, TomAuthState> _states = {};

  /// Declares that a principal holding [role] has resource-level [state].
  static void register(String role, TomAuthState state) =>
      _states[role] = state;

  /// Declares several `role → state` mappings at once.
  static void registerAll(Map<String, TomAuthState> mapping) =>
      _states.addAll(mapping);

  /// The resource-level state for [role], or `null` when the role is unknown.
  ///
  /// A `null` result is a *denial*: [TomResourceRoleAdapter] treats an unknown
  /// role as [TomAuthState.none] rather than granting access by default.
  static TomAuthState? stateFor(String role) => _states[role];

  /// The resource-level state of [role] held on [resourceKey], or `null` when
  /// it grants nothing there.
  ///
  /// On the key or pattern of a declared item type ([TomItemTypeRegistry]) the
  /// role is a level of that type and its grade is the type's; on any other key
  /// it is [stateFor].
  static TomAuthState? stateOn(String resourceKey, String role) {
    final type = TomItemTypeRegistry.typeOfKey(resourceKey);
    return type == null ? stateFor(role) : type.gradeOf(role);
  }

  /// The stronger of two roles held on the same [resourceKey]: by the declared
  /// order of an item type's levels on its keys, by the wider registered state
  /// elsewhere ([fallback] when given). Folding two levels by their grades
  /// would lose the difference between `view` and `comment`, both `read`.
  static String strongerOn(
    String resourceKey,
    String a,
    String b, [
    String Function(String a, String b)? fallback,
  ]) {
    final type = TomItemTypeRegistry.typeOfKey(resourceKey);
    if (type != null) return type.stronger(a, b);
    if (fallback != null) return fallback(a, b);
    final sa = stateFor(a) ?? TomAuthState.none;
    final sb = stateFor(b) ?? TomAuthState.none;
    return sa.index >= sb.index ? a : b;
  }

  /// Unmodifiable snapshot of the current `role → state` mapping.
  static Map<String, TomAuthState> get mapping => Map.unmodifiable(_states);

  /// Clears every registered mapping. Intended for testing.
  static void reset() => _states.clear();
}

// =============================================================================
// TomResourceRoleAdapter — resolve a resource key via the principal's role
// =============================================================================

/// A [TomAuthorizationAdapter] backed by a principal's per-resource roles.
///
/// Constructed from the current principal's
/// [TomAccessControlInformation.resourceRoles] map; [resolveAuth] resolves a
/// resource key by finding the principal's role for it and mapping that role
/// through the [TomResourceRoleRegistry].
///
/// The resolution is deliberately closed (C-5):
/// - resource key not in the map → the principal has no role there →
///   [TomAuthState.none];
/// - role not in the registry → an unknown role grants nothing →
///   [TomAuthState.none].
///
/// ```dart
/// // At login (from the authorization token's resourceRoles claim):
/// TomAuthorization.adapter = TomResourceRoleAdapter(principal.aci.resourceRoles);
///
/// // Anywhere in the UI or server pipeline:
/// final state = TomAuthorization.resolveAuth('project.42');
/// if (state.isInteractive) { /* editable */ }
/// ```
class TomResourceRoleAdapter implements TomAuthorizationAdapter {
  /// The principal's `resourceKey → roleName` map (a snapshot from the ACI).
  final Map<String, String> resourceRoles;

  /// Builds an adapter over [resourceRoles] (typically
  /// `principal.aci.resourceRoles`).
  const TomResourceRoleAdapter(this.resourceRoles);

  /// Resolves [resourceKeyPath] to the principal's state there. The key of an
  /// item of a declared type resolves through [TomItemPermissions.gradeOn], so
  /// a level held on a pattern covering the item counts and the type's grades
  /// apply; any other key through the principal's exact role and the registry.
  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    final type = TomItemTypeRegistry.typeOfKey(resourceKeyPath);
    if (type != null) {
      return TomItemPermissions.gradeOn(
        resourceRoles,
        type,
        resourceKeyPath.substring(type.name.length + 1),
      );
    }
    final role = resourceRoles[resourceKeyPath];
    if (role == null) return TomAuthState.none;
    return TomResourceRoleRegistry.stateFor(role) ?? TomAuthState.none;
  }

  /// Resolves the effective [TomAuthState] the principal holds on
  /// [resourceKey] — the same computation [resolveAuth] performs, exposed as a
  /// named method for **server-side enforcement** call sites that gate an
  /// operation on a resource without going through the [TomAuthorization]
  /// singleton.
  TomAuthState stateOf(String resourceKey) => resolveAuth(resourceKey);
}
