import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../object_persistence/data_scope.dart';
import 'principal_delegation.dart';

/// The grant-driven row scope: an entity carrying a resource-key column is
/// filtered by the resource keys the current principal holds a grant on.
///
/// This is the piece that turns the C-5 ownership grants and the C-6
/// delegations into a `WHERE resource_key IN (…)` — the two models already
/// answer "which resources may this principal touch, and how strongly"; the
/// row scope simply asks them, per query, and binds the answer.
///
/// **The grades are the whole design.** Every grant
/// names a role; [TomResourceRoleRegistry] grades that role as a
/// [TomAuthState]. A row is admitted to a *query* at grade
/// [TomAuthState.read] or wider, and to a *write* only at
/// [TomAuthState.full] — so a viewer's shared project is listed and opened but
/// every attempt to modify it is rejected with a
/// `TomDataScopeAuthorizationException`, which is exactly the difference
/// between "shared with me" and "mine". An unregistered role grades as nothing
/// and grants nothing: a typo in a grant row closes a door rather than opening
/// one.
///
/// **Resolution is live, not from the token.** The keys are read from the grant
/// and delegation tables on every request, deliberately: a revoked share must
/// stop granting access at revocation, not at token expiry. The cost of that
/// choice is a read per resolution, which the delegation resolver keeps for the
/// request (`TomRequestCache`), so one request reads the tables once.
///
/// Delegations are folded in *through* [TomDelegationResolver] rather than
/// around it, so every rule the delegation model already enforces — validity
/// window, revocation, mode semantics, non-transitivity — governs the row scope
/// for free.
///
/// Install it once, at server start-up, from the same delegation resolver the
/// rest of the authorization layer uses:
///
/// ```dart
/// TomResourceDataScope.install(delegationResolver);
/// ```
///
/// While nothing is installed the scope denies every row. That is the point: an
/// unwired scope must be a closed door.
class TomResourceDataScope implements TomResourceScopeSource {
  /// Resolves the principal's effective per-resource roles — direct grants
  /// folded with the delegations active at [now].
  final TomDelegationResolver delegationResolver;

  /// The clock delegation validity is evaluated against (injectable for tests).
  final DateTime Function() now;

  /// Maps the request's principal to the id the grant rows are keyed by.
  ///
  /// Defaults to the principal's tenant-qualified id
  /// ([TomPrincipal.qualifiedId]), which is what
  /// `TomPrincipalResourceGrant.principalId` and the delegation table's
  /// delegator and delegate hold: a principal id is unique within its tenant
  /// only, and under `shared` isolation every tenant's grants sit in one table.
  /// A deployment keying grants by username (or by an external subject claim)
  /// overrides it.
  final String Function(TomPrincipal) principalId;

  /// Creates the scope source over [delegationResolver].
  TomResourceDataScope(
    this.delegationResolver, {
    DateTime Function()? now,
    String Function(TomPrincipal)? principalId,
  }) : now = now ?? DateTime.now,
       principalId = principalId ?? _defaultPrincipalId;

  static String _defaultPrincipalId(TomPrincipal principal) =>
      principal.qualifiedId;

  /// Installs the grant-driven `resource` scope over [delegationResolver].
  ///
  /// Returns the installed source, so a caller that wants to install it
  /// somewhere else too (or assert on it) need not rebuild it.
  static TomResourceDataScope install(
    TomDelegationResolver delegationResolver, {
    DateTime Function()? now,
    String Function(TomPrincipal)? principalId,
  }) {
    final source = TomResourceDataScope(
      delegationResolver,
      now: now,
      principalId: principalId,
    );
    TomDataScopeRegistry.resourceScopeSource = source;
    return source;
  }

  /// Removes the installed source, returning the `resource` scope to deny-all.
  static void uninstall() {
    TomDataScopeRegistry.resourceScopeSource = null;
  }

  /// Whether a source is installed (and the `resource` scope therefore admits
  /// anything at all).
  static bool get isInstalled =>
      TomDataScopeRegistry.resourceScopeSource != null;

  @override
  Future<List<Object?>> readableResourceKeys(TomPrincipal? principal) =>
      _keysAtLeast(principal, TomAuthState.read);

  @override
  Future<List<Object?>> writableResourceKeys(TomPrincipal? principal) =>
      _keysAtLeast(principal, TomAuthState.full);

  /// The resource keys [principal] holds a grant on graded [minimum] or wider.
  ///
  /// A `null` principal (an unauthenticated request) resolves to no keys, so an
  /// unauthenticated query sees nothing — deny by default, as with the built-in
  /// `owner` and `group` scopes.
  Future<List<Object?>> _keysAtLeast(
    TomPrincipal? principal,
    TomAuthState minimum,
  ) async {
    if (principal == null) return const [];
    final roles = await _effectiveRoles(principal);
    return [
      for (final entry in roles.entries)
        if (_grades(entry.key, entry.value, minimum)) entry.key,
    ];
  }

  /// Whether [role] held on [key] grades at [minimum] or wider — through the
  /// item type's levels on an item key ([TomResourceRoleRegistry.stateOn]). An
  /// unknown role grades as nothing.
  static bool _grades(String key, String role, TomAuthState minimum) {
    final state = TomResourceRoleRegistry.stateOn(key, role);
    return state != null && state.index >= minimum.index;
  }

  /// The principal's `resourceKey → role` map — read once per request, since
  /// the delegation resolver's reads are kept for the request
  /// (`TomRequestCache`).
  ///
  /// The resolution reads the grant and delegation tables through the ordinary
  /// repositories, which are themselves row-scoped; running it inside
  /// [TomDataScope.runUnscoped] is what stops the scope from recursing into
  /// itself while computing its own input.
  Future<Map<String, String>> _effectiveRoles(TomPrincipal principal) =>
      TomDataScope.runUnscoped(
        () => delegationResolver.resolveEffectiveRoles(
          principalId(principal),
          now(),
        ),
      );
}
