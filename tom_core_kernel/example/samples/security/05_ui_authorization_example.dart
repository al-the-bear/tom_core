/// Demonstrates the UI authorization primitives in `tom_authorization.dart`:
/// [TomAuthState], [TomAuthorization], [TomAuthorizationGroup],
/// [TomAuthorizer], and [TomUIStateController].
///
/// This example covers:
/// - The four [TomAuthState] outcomes and their `narrow` / `widen` algebra
/// - Predicates: `isVisible`, `isInteractive`, `showsContent`
/// - Installing a [TomAuthorizationAdapter] and resolving via [TomAuthorization]
/// - Group control modes (`controlsAll` / `controlsWidest` / `controlsNarrowest`)
/// - Group introspection: `isUniform` and `mostRestrictive`
/// - [TomAuthorizer] strategies (`fixed`, `fromAction`, narrows-only vs decides)
/// - [TomUIStateController] narrowing build-time state with row data
///
/// Authorization state is ordered from most to least permissive:
/// `none < disabled < read < full`. Most combinators take the more restrictive
/// (narrower) of two states; only `widen` and `controlsNarrowest` raise it.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A test adapter that resolves authorization from a fixed lookup table.
///
/// Unknown paths fall back to [TomAuthState.full] (development default).
class _MapAuthorizationAdapter implements TomAuthorizationAdapter {
  _MapAuthorizationAdapter(this._states);

  final Map<String, TomAuthState> _states;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      _states[resourceKeyPath] ?? TomAuthState.full;
}

/// A minimal [TomAuthorizable] used to populate a group with known states.
class _FixedAuthorizable implements TomAuthorizable {
  _FixedAuthorizable(this.tomId, this._state, {this.tomGroup});

  @override
  final String? tomId;

  @override
  final TomAuthorizationGroup? tomGroup;

  final TomAuthState _state;

  @override
  TomAuthState get effectiveAuthState => _state;
}

void run() {
  print('=== 03: UI Authorization Example ===\n');

  // ===========================================================================
  // Example 1: TomAuthState predicates and the narrow/widen algebra
  // ===========================================================================

  print('1. TomAuthState predicates and narrow/widen:');

  const none = TomAuthState.none;
  const disabled = TomAuthState.disabled;
  const read = TomAuthState.read;
  const full = TomAuthState.full;

  final narrowed = full.narrow(read); // more restrictive wins
  final widened = disabled.widen(read); // less restrictive wins

  print('   full.isInteractive: ${full.isInteractive}');
  print('   read.showsContent: ${read.showsContent}');
  print('   disabled.isVisible: ${disabled.isVisible}');
  print('   none.isVisible: ${none.isVisible}');
  print('   full.narrow(read): $narrowed');
  print('   disabled.widen(read): $widened');
  print('');

  // ===========================================================================
  // Example 2: Resolving through TomAuthorization with an adapter
  // ===========================================================================

  print('2. TomAuthorization resolves via an installed adapter:');

  // No adapter → development default is `full`.
  TomAuthorization.reset();
  final beforeAdapter = TomAuthorization.resolveAuth('checkout.email');

  TomAuthorization.adapter = _MapAuthorizationAdapter({
    'checkout.email': TomAuthState.read,
    'checkout.iban': TomAuthState.none,
  });
  final emailAuth = TomAuthorization.resolveAuth('checkout.email');
  final ibanAuth = TomAuthorization.resolveAuth('checkout.iban');
  final unknownAuth = TomAuthorization.resolveAuth('checkout.unknown');

  print('   before adapter (dev default): $beforeAdapter');
  print('   checkout.email: $emailAuth');
  print('   checkout.iban: $ibanAuth');
  print('   checkout.unknown (fallback): $unknownAuth');
  print('');

  // ===========================================================================
  // Example 3: Group control modes
  // ===========================================================================

  print('3. TomAuthorizationGroup.applyMode for each mode:');

  // The group resolves its own auth from the adapter via resolveGroupPath().
  // At the default scope the path is just the groupId, so we register it here.
  TomAuthorization.adapter = _MapAuthorizationAdapter({
    'shipping': TomAuthState.read, // the group's own resolved state
  });

  final controlsAll =
      TomAuthorizationGroup('shipping', mode: AuthGroupMode.controlsAll);
  final controlsWidest =
      TomAuthorizationGroup('shipping', mode: AuthGroupMode.controlsWidest);
  final controlsNarrowest =
      TomAuthorizationGroup('shipping', mode: AuthGroupMode.controlsNarrowest);

  // A member that would otherwise be fully editable.
  final allResult = controlsAll.applyMode(full); // replaced by group `read`
  final widestResult = controlsWidest.applyMode(full); // ceiling → read
  final narrowestResult = controlsNarrowest.applyMode(none); // floor → read

  print('   controlsAll.applyMode(full): $allResult');
  print('   controlsWidest.applyMode(full): $widestResult');
  print('   controlsNarrowest.applyMode(none): $narrowestResult');
  print('');

  // ===========================================================================
  // Example 4: Group introspection — isUniform and mostRestrictive
  // ===========================================================================

  print('4. Group membership introspection:');

  final group = TomAuthorizationGroup('address');
  final street = _FixedAuthorizable('street', TomAuthState.read, tomGroup: group);
  final city = _FixedAuthorizable('city', TomAuthState.read, tomGroup: group);
  final zip = _FixedAuthorizable('zip', TomAuthState.disabled, tomGroup: group);
  group.register(street);
  group.register(city);

  final uniformBefore = group.isUniform; // both read → uniform
  group.register(zip);
  final uniformAfter = group.isUniform; // read + disabled → not uniform
  final mostRestrictive = group.mostRestrictive; // disabled wins
  final found = group.findMember('city');

  print('   memberCount: ${group.memberCount}');
  print('   isUniform (read, read): $uniformBefore');
  print('   isUniform (read, read, disabled): $uniformAfter');
  print('   mostRestrictive: $mostRestrictive');
  print('   findMember("city")?.tomId: ${found?.tomId}');
  print('');

  // ===========================================================================
  // Example 5: TomAuthorizer strategies
  // ===========================================================================

  print('5. TomAuthorizer combines resource auth with a resolver:');

  // fixed: ignores resource auth entirely (authorizerDecides).
  final fixed = TomAuthorizer.fixed(TomAuthState.disabled);
  final fixedResult = fixed.effectiveAuth(full);

  // narrows-only: cannot widen beyond the resource state.
  final narrowsOnly = TomAuthorizer(
    resolve: (_) => TomAuthState.full, // tries to widen…
  );
  final narrowsOnlyResult = narrowsOnly.effectiveAuth(read); // …capped at read

  // fromAction: full widget + no action permission → disabled.
  final fromAction =
      TomAuthorizer.fromAction(actionAuth: () => TomAuthState.none);
  final fromActionResult = fromAction.effectiveAuth(full);

  print('   fixed(disabled).effectiveAuth(full): $fixedResult');
  print('   narrowsOnly tries full on read → $narrowsOnlyResult');
  print('   fromAction(none).effectiveAuth(full): $fromActionResult');
  print('');

  // ===========================================================================
  // Example 6: TomUIStateController narrows at build time
  // ===========================================================================

  print('6. TomUIStateController can only narrow:');

  final controller = TomUIStateController(
    resolve: (currentAuth, data) {
      // Row owned by someone else → read-only.
      if (data case {'ownerId': final int id} when id != 1) {
        return TomAuthState.read;
      }
      return currentAuth;
    },
  );

  final ownRow = controller.apply(full, data: {'ownerId': 1});
  final otherRow = controller.apply(full, data: {'ownerId': 2});
  final cannotWiden = controller.apply(read, data: {'ownerId': 1});

  print('   own row (ownerId 1) from full: $ownRow');
  print('   other row (ownerId 2) from full: $otherRow');
  print('   controller never widens read: $cannotWiden');
  print('');

  // Clean up the global singleton so later examples see the dev default.
  TomAuthorization.reset();

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: predicates and algebra
  assert(full.isInteractive);
  assert(!read.isInteractive);
  assert(read.showsContent);
  assert(!disabled.showsContent);
  assert(disabled.isVisible);
  assert(!none.isVisible);
  assert(narrowed == TomAuthState.read);
  assert(widened == TomAuthState.read);

  // Example 2: adapter resolution
  assert(beforeAdapter == TomAuthState.full);
  assert(emailAuth == TomAuthState.read);
  assert(ibanAuth == TomAuthState.none);
  assert(unknownAuth == TomAuthState.full);

  // Example 3: group modes (group resolves to `read`)
  assert(allResult == TomAuthState.read);
  assert(widestResult == TomAuthState.read);
  assert(narrowestResult == TomAuthState.read);

  // Example 4: introspection
  assert(uniformBefore);
  assert(!uniformAfter);
  assert(mostRestrictive == TomAuthState.disabled);
  assert(found?.tomId == 'city');

  // Example 5: authorizer strategies
  assert(fixedResult == TomAuthState.disabled);
  assert(narrowsOnlyResult == TomAuthState.read);
  assert(fromActionResult == TomAuthState.disabled);

  // Example 6: UI state controller
  assert(ownRow == TomAuthState.full);
  assert(otherRow == TomAuthState.read);
  assert(cannotWiden == TomAuthState.read);
}
