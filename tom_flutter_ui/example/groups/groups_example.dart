/// Executable example for the `groups/` module of `tom_flutter_ui`.
///
/// `groups/` is the **collective-visibility** layer: a group controls the
/// authorization of a whole region of related widgets without putting an id on
/// every leaf. The module itself is thin — `TomUIGroup` is a backward-compatible
/// typedef for `TomAuthorizationGroup` (the real implementation lives in
/// `tom_core_kernel`), and `TomWidgetMixin` wires the Tom UI concerns (id,
/// group, authorization, resources) into widgets that extend Flutter widgets.
///
/// This example demonstrates the pure-logic surfaces (no `BuildContext`):
///
/// 1. building a group and registering members (weak-reference tracking),
/// 2. the three `AuthGroupMode`s (`controlsAll` / `controlsWidest` /
///    `controlsNarrowest`) via `applyMode`,
/// 3. a `TomWidgetMixin` widget resolving its effective auth through the group,
/// 4. group introspection (`mostRestrictive`, `isUniform`, `findMember`),
/// 5. scope-aware path resolution.
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

  const _GroupedField(this.tomId, {this.tomGroup});

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
  });

  // ---------------------------------------------------------------------------
  // 1. TomUIGroup is a typedef for TomAuthorizationGroup.
  // ---------------------------------------------------------------------------
  final shipping =
      TomUIGroup('shipping'); // default mode: controlsWidest
  print('TomUIGroup is TomAuthorizationGroup: '
      '${identical(TomUIGroup, TomAuthorizationGroup)}');
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
      TomUIGroup('billing', mode: AuthGroupMode.controlsAll);
  final contact =
      TomUIGroup('contact', mode: AuthGroupMode.controlsNarrowest);

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

  // ---------------------------------------------------------------------------
  // 6. Scope-aware paths: inside a scope the group/member paths are prefixed.
  // ---------------------------------------------------------------------------
  TomScope.withScope('checkout', () {
    final scopedField = _GroupedField('street', tomGroup: shipping);
    print('scoped basePath: ${scopedField.basePath}');
    print('scoped group path: ${shipping.resolveGroupPath()}');
  });

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(identical(TomUIGroup, TomAuthorizationGroup));
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

  // Unregister prunes membership.
  street.unregisterFromGroup();
  assert(shipping.memberCount == 1);

  // Inside the 'checkout' scope, paths are prefixed.
  TomScope.withScope('checkout', () {
    final scoped = _GroupedField('street', tomGroup: shipping);
    assert(scoped.basePath == 'checkout.street');
    assert(shipping.resolveGroupPath() == 'checkout.shipping');
  });

  TomAuthorization.reset();
}

void main() => run();
