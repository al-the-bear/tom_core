import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/groups/groups_example.dart' as example;

class _GroupedField extends StatelessWidget with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final TomAuthorizationGroup? tomGroup;
  @override
  final TomScope? scope;

  const _GroupedField(this.tomId, {this.tomGroup, this.scope});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A probe on the other half of the same mechanism: `TomPolicyNodeBase` is the
/// class every Tom widget inherits, and it composes group auth in its own
/// method rather than through [TomWidgetMixin].
class _PolicyProbe extends TomPolicyNodeBase {
  _PolicyProbe({super.tomId, super.tomGroup, super.scope});

  @override
  Widget buildContent(BuildContext context) => const SizedBox.shrink();
}

class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void main() {
  // The authorization adapter is a process-wide singleton; reset around every
  // test so ordering can never leak state.
  setUp(TomAuthorization.reset);
  tearDown(TomAuthorization.reset);

  group('groups example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('AuthGroupMode', () {
    test('default mode is controlsWidest', () {
      expect(TomAuthorizationGroup('g').mode, AuthGroupMode.controlsWidest);
    });

    test('controlsWidest narrows a member to the group ceiling', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'g': TomAuthState.read});
      final g = TomAuthorizationGroup('g'); // controlsWidest
      expect(g.applyMode(TomAuthState.full), TomAuthState.read);
      // A member already narrower than the ceiling is unaffected.
      expect(g.applyMode(TomAuthState.disabled), TomAuthState.disabled);
    });

    test('controlsAll replaces the member state', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'g': TomAuthState.disabled});
      final g = TomAuthorizationGroup('g', mode: AuthGroupMode.controlsAll);
      expect(g.applyMode(TomAuthState.full), TomAuthState.disabled);
      expect(g.applyMode(TomAuthState.none), TomAuthState.disabled);
    });

    test('controlsNarrowest lifts a restrictive member to the group floor', () {
      TomAuthorization.adapter =
          _PathAuthAdapter({'g': TomAuthState.read});
      final g = TomAuthorizationGroup('g', mode: AuthGroupMode.controlsNarrowest);
      expect(g.applyMode(TomAuthState.disabled), TomAuthState.read);
      // A member already wider than the floor is unaffected.
      expect(g.applyMode(TomAuthState.full), TomAuthState.full);
    });
  });

  group('TomWidgetMixin', () {
    test('resolves effective auth through its group', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'shipping': TomAuthState.read, // group ceiling
        'street': TomAuthState.full, // member resource auth
      });
      final shipping = TomAuthorizationGroup('shipping');
      final street = _GroupedField('street', tomGroup: shipping);
      expect(street.getAuth(), TomAuthState.read);
      expect(street.effectiveAuthState, TomAuthState.read);
      expect(street.basePath, 'street');
    });

    test('register/unregister updates member tracking and findMember', () {
      final g = TomAuthorizationGroup('g');
      final a = _GroupedField('a', tomGroup: g);
      final b = _GroupedField('b', tomGroup: g);
      a.registerWithGroup();
      b.registerWithGroup();
      expect(g.memberCount, 2);
      expect(g.findMember('b'), b);
      a.unregisterFromGroup();
      expect(g.memberCount, 1);
      expect(g.findMember('a'), isNull);
    });

    test('basePath is scope-prefixed inside a TomScope', () {
      final g = TomAuthorizationGroup('shipping');
      TomScope.withScope('checkout', () {
        final field = _GroupedField('street', tomGroup: g);
        expect(field.basePath, 'checkout.street');
        expect(g.resolveGroupPath(), 'checkout.shipping');
      });
    });
  });

  // -------------------------------------------------------------------------
  // A scope reaches the member and the group, or it reaches neither
  // -------------------------------------------------------------------------

  group('a group is resolved in the same scope as its member', () {
    // Three rules, and the third is the point. `shipping: full` is what an
    // out-of-frame group lookup lands on, so a scope that fails to reach the
    // group produces a *wider* answer rather than the same one by luck — the
    // ceiling disappears instead of merely moving.
    void installRules() {
      TomAuthorization.adapter = _PathAuthAdapter({
        'checkout.street': TomAuthState.full,
        'checkout.shipping': TomAuthState.read, // the ceiling that must apply
        'shipping': TomAuthState.full, // the unscoped decoy
      });
    }

    /// A scope handed over as a value, never installed on a zone — the shape
    /// `InScopeBuilder` and the screen-element providers produce.
    TomScope detachedCheckout() => TomScopeBase(scopeId: 'checkout');

    test('resolveGroupPath honours the scope it is given', () {
      final g = TomAuthorizationGroup('shipping');

      expect(g.resolveGroupPath(detachedCheckout()), 'checkout.shipping');
    });

    test('resolveGroupPath still falls back to the ambient scope', () {
      // The parameter is an override, not a replacement: every existing caller
      // passes nothing and must keep resolving exactly as before.
      final g = TomAuthorizationGroup('shipping');

      expect(g.resolveGroupPath(), 'shipping');
      TomScope.withScope('checkout', () {
        expect(g.resolveGroupPath(), 'checkout.shipping');
      });
    });

    test('an ambient scope applies the group ceiling', () {
      installRules();
      final g = TomAuthorizationGroup('shipping');

      TomScope.withScope('checkout', () {
        final field = _GroupedField('street', tomGroup: g);
        expect(field.basePath, 'checkout.street');
        expect(field.getAuth(), TomAuthState.read);
      });
    });

    test('an explicit scope applies it too — it is not silently skipped', () {
      // `basePath` has always honoured an explicit scope. Until the group did
      // as well, the same widget with the same group and the same rules kept
      // `full` here and got `read` above: an authorization ceiling that
      // depended on how the scope was supplied.
      installRules();
      final g = TomAuthorizationGroup('shipping');

      final field = _GroupedField('street', tomGroup: g,
          scope: detachedCheckout());

      expect(field.basePath, 'checkout.street');
      expect(field.getAuth(), TomAuthState.read);
    });

    test('the two forms of supplying a scope agree', () {
      installRules();
      final g = TomAuthorizationGroup('shipping');

      final explicit =
          _GroupedField('street', tomGroup: g, scope: detachedCheckout())
              .getAuth();
      final ambient = TomScope.withScope(
        'checkout',
        () => _GroupedField('street', tomGroup: g).getAuth(),
      );

      expect(explicit, ambient);
    });

    test('TomPolicyNodeBase resolves its group in its construction scope', () {
      // The mixin is one of two places that compose a member with its group;
      // this is the other, and the one every Tom widget inherits.
      installRules();
      final g = TomAuthorizationGroup('shipping');

      final node =
          _PolicyProbe(tomId: 'street', tomGroup: g, scope: detachedCheckout());

      expect(node.basePath, 'checkout.street');
      expect(node.resolveEffectiveAuth(), TomAuthState.read);
    });

    test('a scoped member is inspected at the same state it renders at', () {
      // `members` reads `effectiveAuthState` from wherever the caller happens
      // to stand — outside any zone. `TomPolicyNodeBase.build` re-enters the
      // construction scope, so the render path was always right; every
      // inspection path (`members`, `isUniform`, `mostRestrictive`) was not.
      TomAuthorization.adapter = _PathAuthAdapter({
        'checkout.street': TomAuthState.full,
        'checkout.shipping': TomAuthState.none, // hides the member
        'shipping': TomAuthState.full,
      });
      final g = TomAuthorizationGroup('shipping');

      final node =
          _PolicyProbe(tomId: 'street', tomGroup: g, scope: detachedCheckout());
      g.register(node);

      expect(g.members, isEmpty);
      expect(g.isEmpty, isTrue);
    });
  });
}
