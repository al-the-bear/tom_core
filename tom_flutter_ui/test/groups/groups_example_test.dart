import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/groups/groups_example.dart' as example;

class _GroupedField extends StatelessWidget with TomWidgetMixin {
  @override
  final String? tomId;
  @override
  final TomAuthorizationGroup? tomGroup;

  const _GroupedField(this.tomId, {this.tomGroup});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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

  group('TomAuthorizationGroup typedef', () {
    test('aliases TomAuthorizationGroup', () {
      // A typedef's type literal evaluates to the aliased type.
      expect(TomAuthorizationGroup, equals(TomAuthorizationGroup));
      expect(TomAuthorizationGroup('g'), isA<TomAuthorizationGroup>());
    });

    test('default mode is controlsWidest', () {
      expect(TomAuthorizationGroup('g').mode, AuthGroupMode.controlsWidest);
    });
  });

  group('AuthGroupMode via applyMode', () {
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
}
