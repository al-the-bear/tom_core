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
/// - resource key not in the map → the principal has no role there → [none];
/// - role not in the registry → an unknown role grants nothing → [none].
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

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
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
