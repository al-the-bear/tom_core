import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// TomWidgetMixin is the render contract every direct-extension Tom widget
// shares — `getAuth()`, `checkHidden()`, and the 4-state `applyAuthState`
// visual treatment.
//
// `getAuth()` composes four layers in a fixed order: resource → group →
// authorizer → uiStateController. The order is load-bearing, because the
// layers are not all narrowing: `TomAuthorizer` in its `authorizerDecides`
// mode and `TomAuthorizationGroup.applyMode` under `controlsAll` /
// `controlsNarrowest` can *widen*, so a layer running later than it should
// silently undoes what an earlier one established. The "layer order" group
// below therefore pins each adjacent boundary with inputs that produce a
// different `TomAuthState` if the two layers are swapped — a test that fixes
// one layer and leaves the rest null cannot tell one order from another.
//
// The group↔controller boundary is pinned separately, for this mixin *and*
// for `TomPolicyNodeBase`, in `test/widget_base/auth_resolution_order_test.dart`;
// it is not repeated here.

/// Minimal concrete widget mixing in [TomWidgetMixin].
class _MixinWidget extends StatelessWidget with TomWidgetMixin {
  _MixinWidget({
    this.tomId,
    this.authorizer,
    this.uiStateController,
    this.tomGroup,
    required this.child,
  });

  @override
  final String? tomId;
  @override
  final TomAuthorizer? authorizer;
  @override
  final TomUIStateController? uiStateController;
  @override
  final TomAuthorizationGroup? tomGroup;

  final Widget child;

  @override
  Widget build(BuildContext context) => applyAuthState(context, child);
}

/// The other half of the same design. [TomNodeBase] is what a Tom widget
/// inherits when it does *not* extend a Flutter original, and it builds the
/// same debug label in its own method. The two have to agree: a label that
/// identifies a widget differently depending on which half of the package it
/// came from is worse than no label, because the reader cannot tell a format
/// difference from a state difference.
class _NodeWidget extends TomNodeBase {
  _NodeWidget({super.tomId, super.tomGroup});

  // Left abstract by TomNodeBase and supplied by TomPolicyNodeBase in the real
  // hierarchy; irrelevant to the label, so it answers a constant here.
  @override
  TomAuthState get effectiveAuthState => TomAuthState.full;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  tearDown(TomAuthorization.reset);

  group('TomWidgetMixin.getAuth: each layer on its own', () {
    test('defaults to full with no tomId and no adapter', () {
      expect(_MixinWidget(child: const Text('x')).getAuth(), TomAuthState.full);
    });

    test('resolves resource auth at basePath', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.read});
      expect(
        _MixinWidget(tomId: 'w', child: const Text('x')).getAuth(),
        TomAuthState.read,
      );
    });

    test('authorizer replaces resource auth', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.full});
      final widget = _MixinWidget(
        tomId: 'w',
        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
        child: const Text('x'),
      );
      // `TomAuthorizer.fixed` is `authorizerDecides`, not the narrowsOnly
      // constructor default — it returns its state outright rather than
      // narrowing `full` with it. Both happen to answer disabled here; see
      // the layer-order group for a case where the difference shows.
      expect(widget.getAuth(), TomAuthState.disabled);
    });

    test('uiStateController narrows resource auth', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.full});
      final widget = _MixinWidget(
        tomId: 'w',
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.read,
        ),
        child: const Text('x'),
      );
      expect(widget.getAuth(), TomAuthState.read);
    });

    test('group applyMode (controlsAll) replaces the state', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.read,
      });
      final widget = _MixinWidget(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
        child: const Text('x'),
      );
      expect(widget.getAuth(), TomAuthState.read);
    });
  });

  group('TomWidgetMixin.getAuth: layer order', () {
    test('the group applies before the authorizer', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.read,
      });
      final widget = _MixinWidget(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
        authorizer: TomAuthorizer.fixed(TomAuthState.disabled),
        child: const Text('x'),
      );
      // full → group replaces with read → authorizer decides disabled.
      // Swap the two and `controlsAll` discards the authorizer's verdict
      // wholesale, answering read: a per-widget authorizer would become
      // unable to restrict a member of a controlsAll group.
      expect(widget.getAuth(), TomAuthState.disabled);
    });

    test('the authorizer applies before the controller', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.read});
      final widget = _MixinWidget(
        tomId: 'w',
        authorizer: TomAuthorizer.fixed(TomAuthState.full),
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.disabled,
        ),
        child: const Text('x'),
      );
      // read → authorizer decides full (widening) → controller narrows to
      // disabled. Swap the two and the authorizer widens away what the
      // controller just narrowed, answering full — breaking the documented
      // promise that the controller can only narrow.
      expect(widget.getAuth(), TomAuthState.disabled);
    });

    test('all four layers compose in one fixed order', () {
      TomAuthorization.adapter = _MapAuthAdapter({
        'w': TomAuthState.full,
        'grp': TomAuthState.disabled,
      });
      final widget = _MixinWidget(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp', mode: AuthGroupMode.controlsAll),
        authorizer: TomAuthorizer.fixed(TomAuthState.full),
        uiStateController: TomUIStateController(
          resolve: (_, _) => TomAuthState.read,
        ),
        child: const Text('x'),
      );
      // full → group replaces with disabled → authorizer decides full →
      // controller narrows to read. Each adjacent transposition answers a
      // different state: group↔authorizer gives disabled, authorizer↔
      // controller gives full. One expectation, both boundaries.
      expect(widget.getAuth(), TomAuthState.read);
    });
  });

  group('TomWidgetMixin.checkHidden', () {
    test('returns SizedBox.shrink when none, null otherwise', () {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.none});
      expect(
        _MixinWidget(tomId: 'w', child: const Text('x')).checkHidden(),
        isA<SizedBox>(),
      );
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.full});
      expect(
        _MixinWidget(tomId: 'w', child: const Text('x')).checkHidden(),
        isNull,
      );
    });
  });

  group('TomWidgetMixin.applyAuthState visual treatment', () {
    testWidgets('full → bare child', (tester) async {
      await tester.pumpWidget(_host(_MixinWidget(child: const Text('x'))));
      expect(find.text('x'), findsOneWidget);
      expect(find.byType(AbsorbPointer), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('none → SizedBox.shrink, child removed', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.none});
      await tester.pumpWidget(
        _host(_MixinWidget(tomId: 'w', child: const Text('x'))),
      );
      expect(find.text('x'), findsNothing);
    });

    testWidgets('disabled → AbsorbPointer + 0.38 opacity', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.disabled});
      await tester.pumpWidget(
        _host(_MixinWidget(tomId: 'w', child: const Text('x'))),
      );
      expect(find.byType(AbsorbPointer), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(0.38, 0.001),
      );
    });

    testWidgets('read → default readonly AbsorbPointer + 0.6 opacity', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.read});
      await tester.pumpWidget(
        _host(_MixinWidget(tomId: 'w', child: const Text('x'))),
      );
      expect(find.byType(AbsorbPointer), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(0.6, 0.001),
      );
    });

    // The counterpart of the same test in
    // `test/widget_base/tom_policy_node_auth_gate_test.dart`, deliberately
    // using the same 0.2: these are Tom's two enforcement points, and this
    // pins that one theme reaches both. They used to switch over the four
    // states independently, with the disabled opacity written out as a literal
    // in each — restyling it moved neither.
    testWidgets('the disabled treatment follows the scoped theme', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'w': TomAuthState.disabled});
      await tester.pumpWidget(
        _host(
          TomThemeScope(
            theme: const TomTheme(disabledStyle: TomStateStyle(opacity: 0.2)),
            child: _MixinWidget(tomId: 'w', child: const Text('x')),
          ),
        ),
      );
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(0.2, 0.001),
      );
    });
  });

  group('TomWidgetMixin.debugLabel', () {
    test('names the runtime type and the id', () {
      expect(
        _MixinWidget(tomId: 'w', child: const Text('x')).debugLabel,
        '_MixinWidget(id: w)',
      );
    });

    test('appends the group id when the widget is a member', () {
      final widget = _MixinWidget(
        tomId: 'w',
        tomGroup: TomAuthorizationGroup('grp'),
        child: const Text('x'),
      );
      expect(widget.debugLabel, '_MixinWidget(id: w, group: grp)');
    });

    test('omits the id entirely when there is none', () {
      // `tomId` is nullable on this mixin, so an anonymous widget is a
      // reachable case, not a defensive one — the layout widgets that take
      // part in grouping without owning a resource path are exactly it.
      // Interpolating the absent id yields the literal text "null", which
      // reads as a widget whose id *is* the string null rather than as a
      // widget that has none.
      expect(_MixinWidget(child: const Text('x')).debugLabel, '_MixinWidget()');
    });

    test('omits the id but keeps the group for an anonymous member', () {
      final widget = _MixinWidget(
        tomGroup: TomAuthorizationGroup('grp'),
        child: const Text('x'),
      );
      expect(widget.debugLabel, '_MixinWidget(group: grp)');
    });

    test('agrees with TomNodeBase in every combination', () {
      // The two implementations are independent, so nothing but a test keeps
      // them in step. Compared on the parenthesised part only: the leading
      // runtime type necessarily differs.
      String args(String label) =>
          label.substring(label.indexOf('(') + 1, label.length - 1);
      final grp = TomAuthorizationGroup('grp');

      expect(
        args(_MixinWidget(tomId: 'w', child: const Text('x')).debugLabel),
        args(_NodeWidget(tomId: 'w').debugLabel),
      );
      expect(
        args(_MixinWidget(child: const Text('x')).debugLabel),
        args(_NodeWidget().debugLabel),
      );
      expect(
        args(
          _MixinWidget(
            tomId: 'w',
            tomGroup: grp,
            child: const Text('x'),
          ).debugLabel,
        ),
        args(_NodeWidget(tomId: 'w', tomGroup: grp).debugLabel),
      );
      expect(
        args(_MixinWidget(tomGroup: grp, child: const Text('x')).debugLabel),
        args(_NodeWidget(tomGroup: grp).debugLabel),
      );
    });
  });
}
