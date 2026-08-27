/// Executable example for the `groups/` module of `tom_flutter_ui`.
///
/// `groups/` is the **collective-visibility** layer: a group controls the
/// authorization of a whole region of related widgets without putting an id on
/// every leaf. The module itself is thin — `TomAuthorizationGroup` and its
/// `AuthGroupMode` are implemented in `tom_core_kernel` and re-exported here,
/// so importing `tom_flutter_ui` is enough to name both; what `groups/` adds
/// is `TomWidgetMixin`, which wires the Tom UI concerns (id, group,
/// authorization, resources) into widgets that extend Flutter widgets.
///
/// This example demonstrates the pure-logic surfaces (no `BuildContext`):
///
/// 1. creating a group, and the default `controlsWidest` mode,
/// 2. registering members (weak-reference tracking),
/// 3. a `TomWidgetMixin` widget resolving its effective auth through the group,
/// 4. the three `AuthGroupMode`s (`controlsAll` / `controlsWidest` /
///    `controlsNarrowest`) via `applyMode`,
/// 5. group introspection (`mostRestrictive`, `isUniform`, `findMember`) and
///    what it answers when nothing in the group is visible,
/// 6. scope-aware path resolution, in both the ambient and the explicit form.
///
/// Because it imports `flutter/material` (→ `dart:ui`) through the package
/// barrel, run it under the Flutter toolchain, e.g.
/// `flutter test example/groups/groups_example.dart`, not bare `dart run`. The
/// same scenarios are covered by `test/groups/groups_example_test.dart`.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// A minimal Tom widget that mixes in [TomWidgetMixin] so it participates in
/// the authorization/group system. The build output is irrelevant here — the
/// example only exercises the (context-free) resolution logic.
class _GroupedField extends StatelessWidget with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final TomAuthorizationGroup? tomGroup;

  /// An optional explicit scope. Overriding it is what lets step 5 below show
  /// the second way a scope reaches a widget: as a value, rather than from the
  /// zone the widget happens to be constructed in.
  @override
  final TomScope? scope;

  const _GroupedField(this.tomId, {this.tomGroup, this.scope});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Test adapter that resolves auth state by exact resource path.
class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void run() {
  TomAuthorization.reset();

  // The group's auth comes from its resolved path; members default to full.
  TomAuthorization.adapter = _PathAuthAdapter({
    'shipping': TomAuthState.read, // ceiling for controlsWidest
    'billing': TomAuthState.disabled, // replacement for controlsAll
    'contact': TomAuthState.read, // floor for controlsNarrowest
    'ghost': TomAuthState.none, // a member the user may not see at all
  });

  // ---------------------------------------------------------------------------
  // 1. Creating a group. A group needs only an id; the mode defaults to
  //    controlsWidest, i.e. the group acts as a ceiling on its members.
  // ---------------------------------------------------------------------------
  final shipping = TomAuthorizationGroup('shipping');
  print('shipping mode: ${shipping.mode}');

  // ---------------------------------------------------------------------------
  // 2. Members + weak-reference tracking.
  // ---------------------------------------------------------------------------
  final street = _GroupedField('street', tomGroup: shipping);
  final city = _GroupedField('city', tomGroup: shipping);
  street.registerWithGroup();
  city.registerWithGroup();
  print('shipping members: ${shipping.memberCount}');
  print('findMember(city): ${shipping.findMember('city')?.tomId}');

  // ---------------------------------------------------------------------------
  // 3. Effective auth: a full member narrowed to the group's read ceiling.
  // ---------------------------------------------------------------------------
  final streetAuth = street.getAuth();
  print('street effective auth (full ⊓ read ceiling): $streetAuth');
  print('street basePath: ${street.basePath}');

  // ---------------------------------------------------------------------------
  // 4. The three AuthGroupMode behaviours via applyMode.
  // ---------------------------------------------------------------------------
  final billing =
      TomAuthorizationGroup('billing', mode: AuthGroupMode.controlsAll);
  final contact =
      TomAuthorizationGroup('contact', mode: AuthGroupMode.controlsNarrowest);

  final widest = shipping.applyMode(TomAuthState.full); // ceiling → read
  final all = billing.applyMode(TomAuthState.full); // replace → disabled
  final narrowest = contact.applyMode(TomAuthState.disabled); // floor → read
  print('controlsWidest:    full   → $widest');
  print('controlsAll:       full   → $all');
  print('controlsNarrowest: disabled → $narrowest');

  // ---------------------------------------------------------------------------
  // 5. Group introspection.
  // ---------------------------------------------------------------------------
  print('shipping mostRestrictive: ${shipping.mostRestrictive}');
  print('shipping isUniform: ${shipping.isUniform}');

  // Everything above reports on *visible* membership: a member resolving to
  // `none` is not there as far as inspection is concerned. So a group whose
  // members are all hidden looks exactly like an empty one — and both must be
  // distinguishable from a group that is fully open, which is what
  // `mostRestrictive == none` buys you. (`full` is where the narrowing fold
  // starts, not an answer; returning it here would call a hidden group
  // editable.) `isUniform` keeps the opposite, vacuous-truth convention.
  // No rule for 'audit', so the *group* resolves to full — and its one member
  // is still invisible. That is the pair the old `full` answer conflated.
  final audit = TomAuthorizationGroup('audit');
  final ghost = _GroupedField('ghost', tomGroup: audit)..registerWithGroup();
  print('audit group authState: ${audit.authState}');
  print('audit member auth: ${ghost.getAuth()}');
  print('audit memberCount: ${audit.memberCount}');
  print('audit mostRestrictive: ${audit.mostRestrictive}');
  print('audit isUniform: ${audit.isUniform}');

  // ---------------------------------------------------------------------------
  // 6. Scope-aware paths: inside a scope the group/member paths are prefixed.
  // ---------------------------------------------------------------------------
  TomScope.withScope('checkout', () {
    final scopedField = _GroupedField('street', tomGroup: shipping);
    print('scoped basePath: ${scopedField.basePath}');
    print('scoped group path: ${shipping.resolveGroupPath()}');
  });

  // The same scope handed over as a value instead of installed on a zone —
  // what `InScopeBuilder` does for callbacks Flutter invokes from its own zone.
  // Both paths must come out prefixed, or the group would be looked up
  // somewhere the member never was.
  final checkout = TomScopeBase(scopeId: 'checkout');
  final detached = _GroupedField('street', tomGroup: shipping, scope: checkout);
  print('explicit basePath: ${detached.basePath}');
  print('explicit group path: ${shipping.resolveGroupPath(checkout)}');

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(shipping.mode == AuthGroupMode.controlsWidest);

  assert(shipping.memberCount == 2);
  assert(shipping.findMember('city') == city);
  assert(shipping.findMember('nope') == null);

  // full ⊓ read = read
  assert(streetAuth == TomAuthState.read);
  assert(street.basePath == 'street');
  assert(street.effectiveAuthState == TomAuthState.read);

  assert(widest == TomAuthState.read); // ceiling narrows full → read
  assert(all == TomAuthState.disabled); // controlsAll replaces
  assert(narrowest == TomAuthState.read); // floor lifts disabled → read

  // Both members resolve to read, so the group is uniform at read.
  assert(shipping.mostRestrictive == TomAuthState.read);
  assert(shipping.isUniform == true);

  // The group is wide open and shows nothing: its only member is hidden, so
  // inspection reports an empty group. `mostRestrictive` has to say `none`
  // here — anything else would describe a group with nothing in it using the
  // vocabulary of a group the user can edit.
  assert(audit.authState == TomAuthState.full);
  assert(ghost.getAuth() == TomAuthState.none);
  assert(audit.memberCount == 0);
  assert(audit.isEmpty == true);
  assert(audit.mostRestrictive == TomAuthState.none);
  assert(audit.mostRestrictive != shipping.mostRestrictive);
  // isUniform keeps the vacuous-truth convention, so it cannot tell the two
  // apart on its own — that is what isEmpty and mostRestrictive are for.
  assert(audit.isUniform == true);

  // An empty group answers exactly as the fully hidden one does.
  assert(TomAuthorizationGroup('empty').mostRestrictive == TomAuthState.none);

  // Unregister prunes membership.
  street.unregisterFromGroup();
  assert(shipping.memberCount == 1);

  // Inside the 'checkout' scope, paths are prefixed.
  TomScope.withScope('checkout', () {
    final scoped = _GroupedField('street', tomGroup: shipping);
    assert(scoped.basePath == 'checkout.street');
    assert(shipping.resolveGroupPath() == 'checkout.shipping');
  });

  // An explicit scope prefixes both paths exactly as the ambient one does.
  assert(detached.basePath == 'checkout.street');
  assert(shipping.resolveGroupPath(checkout) == 'checkout.shipping');

  TomAuthorization.reset();
}

void main() => run();
