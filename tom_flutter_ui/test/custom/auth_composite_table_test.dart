/// The four-outcome table `custom/`'s documents state **once, for three
/// widgets**, held against all three.
///
/// `doc/custom.md` and the completion document both carry it as a shared claim
/// — `none` removes, `disabled` fades and blocks pointers, `read` blocks
/// pointers without fading, `full` is untouched — and add that "pointer-blocked
/// means an `IgnorePointer`, in all three, so a `trailing:` action button, a
/// `Radio`, anything the guarded content contains, is inert and not merely
/// un-styled".
///
/// Nothing held that. Each widget was tested on its own, in its own file, and
/// between them the table had holes exactly where a reader would not look for
/// them: `TomAuthGuard` had no `read` case and its `disabled` case asserted the
/// fade under a name that promised pointer blocking; `TomChoiceGroup` had only
/// `none` and `full`. `TomAuthTreeView` shipped with the fade and no barrier at
/// all, and a button in `trailing:` fired on a node greyed out to mean
/// "unavailable" — which is what a shared claim tested per widget invites.
///
/// So this file is the table, driven as a table: every composite, every state,
/// through one interactive child that is *tapped* rather than inspected. A
/// barrier that is present in the tree but lets a tap through would satisfy any
/// structural finder for `IgnorePointer` and fails here.
///
/// The per-widget differences the second table states — the extent of the
/// block, and the two opt-outs — are asserted below it. The tree's is in
/// `tom_auth_tree_view_test.dart`, where it belongs: "each node's own row only"
/// needs a tree of more than one node to mean anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// The one path every composite here is keyed on, so a case changes the state
/// and nothing else.
const _gate = 'gate';

class _Gate implements TomAuthorizationAdapter {
  _Gate(this.state);
  final TomAuthState state;

  @override
  TomAuthState resolveAuth(String path) =>
      path == _gate ? state : TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The faded wrapper the auth widgets add at `disabled`, and only there.
///
/// Matched on "below 1" rather than on the literal default, because the number
/// is `disabledOpacity` and a caller is expected to change it.
Finder _fadedAncestorOf(Finder child) => find.ancestor(
  of: child,
  matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1.0),
);

/// One auth-gated composite, described by what it takes and what it renders.
typedef _Composite = ({
  String name,

  /// Builds the widget with an interactive child that calls [onAct].
  Widget Function(VoidCallback onAct) build,

  /// Finds the content that must disappear at `none`.
  Finder content,

  /// Drives the interaction that must not fire while blocked.
  Future<void> Function(WidgetTester tester) act,
});

Future<void> _tapAct(WidgetTester tester) async {
  // `warnIfMissed` is off because a blocked target is *expected* to miss its
  // hit test; the counter is the assertion, not the warning.
  await tester.tap(find.text('act'), warnIfMissed: false);
  await tester.pump();
}

Future<void> _tapBeta(WidgetTester tester) async {
  await tester.tap(find.text('Beta'), warnIfMissed: false);
  await tester.pump();
}

const _items = <TomChoiceGroupItem<String>>[
  TomChoiceGroupItem(value: 'a', label: 'Alpha'),
  TomChoiceGroupItem(value: 'b', label: 'Beta'),
];

final _composites = <_Composite>[
  (
    name: 'TomAuthGuard',
    build: (onAct) => TomAuthGuard(
      tomId: _gate,
      child: ElevatedButton(onPressed: onAct, child: const Text('act')),
    ),
    content: find.text('act'),
    act: _tapAct,
  ),
  (
    name: 'TomChoiceGroup',
    build: (onAct) => TomChoiceGroup<String>(
      tomId: _gate,
      items: _items,
      selected: 'a',
      onChanged: (_) => onAct(),
    ),
    content: find.text('Beta'),
    act: _tapBeta,
  ),
  (
    name: 'TomAuthTreeView',
    build: (onAct) => TomAuthTreeView(
      shrinkWrap: true,
      nodes: [
        TomAuthTreeNode(
          tomId: _gate,
          title: const Text('node'),
          trailing: ElevatedButton(onPressed: onAct, child: const Text('act')),
        ),
      ],
    ),
    content: find.text('act'),
    act: _tapAct,
  ),
];

void main() {
  tearDown(TomAuthorization.reset);

  /// Pumps [composite] at [state], drives its interaction once, and reports
  /// how many times that interaction fired.
  ///
  /// The `none` case does not use this: its content is gone, and `tap()` on a
  /// finder matching nothing throws before any assertion could report it.
  Future<int> pumpAndAct(
    WidgetTester tester,
    _Composite composite,
    TomAuthState state,
  ) async {
    TomAuthorization.adapter = _Gate(state);
    var acted = 0;
    await tester.pumpWidget(_host(composite.build(() => acted++)));
    await composite.act(tester);
    return acted;
  }

  group('the shared four-outcome table', () {
    for (final composite in _composites) {
      testWidgets('${composite.name}: none removes the content', (
        tester,
      ) async {
        TomAuthorization.adapter = _Gate(TomAuthState.none);
        await tester.pumpWidget(_host(composite.build(() {})));
        expect(composite.content, findsNothing);
      });

      testWidgets('${composite.name}: disabled renders, fades and blocks', (
        tester,
      ) async {
        final acted = await pumpAndAct(
          tester,
          composite,
          TomAuthState.disabled,
        );
        expect(composite.content, findsOneWidget, reason: 'still rendered');
        expect(
          _fadedAncestorOf(composite.content),
          findsOneWidget,
          reason: 'disabled is the one state that fades',
        );
        expect(
          acted,
          0,
          reason:
              'a faded control that still fires is worse than an unstyled one: '
              'the user is told it is unavailable and it acts anyway',
        );
      });

      testWidgets('${composite.name}: read renders and blocks without fading', (
        tester,
      ) async {
        final acted = await pumpAndAct(tester, composite, TomAuthState.read);
        expect(composite.content, findsOneWidget);
        expect(
          _fadedAncestorOf(composite.content),
          findsNothing,
          reason: 'read keeps the value readable — that is the difference',
        );
        expect(acted, 0);
      });

      testWidgets('${composite.name}: full renders untouched and acts', (
        tester,
      ) async {
        // The control for the whole table. Without it every case above is
        // satisfied by a composite that renders nothing interactive at all.
        final acted = await pumpAndAct(tester, composite, TomAuthState.full);
        expect(composite.content, findsOneWidget);
        expect(_fadedAncestorOf(composite.content), findsNothing);
        expect(acted, 1);
      });
    }

    test('the table covers every state, and every composite', () {
      // Guards the loop: a composite dropped from the list takes its whole row
      // of the table with it and nothing else notices.
      expect(_composites.map((c) => c.name).toSet(), {
        'TomAuthGuard',
        'TomChoiceGroup',
        'TomAuthTreeView',
      });
      expect(TomAuthState.values.toSet(), {
        TomAuthState.none,
        TomAuthState.disabled,
        TomAuthState.read,
        TomAuthState.full,
      });
    });
  });

  group('the block is an IgnorePointer, as the documents say', () {
    // The tap cases above prove the content is inert. They do not prove *how*,
    // and for `TomChoiceGroup` nothing can: the group offers no caller-supplied
    // widget slot, its own row handler is already null when withheld, and its
    // `Radio`s are already `enabled: false` — so removing the barrier changes
    // nothing a pointer can reach. Measured, not assumed: that mutation
    // survives the whole table above.
    //
    // The documents nevertheless state the mechanism ("pointer-blocked means
    // an `IgnorePointer`, in all three"), and a reader relies on it the moment
    // they put something interactive inside. So it is asserted here, as a
    // count against the same widget at `full` rather than as a bare finder:
    // the app shell contributes barriers of its own, and a finder that matched
    // those would pass on a composite that added none.
    Future<int> barriersAt(
      WidgetTester tester,
      _Composite composite,
      TomAuthState state,
    ) async {
      TomAuthorization.adapter = _Gate(state);
      await tester.pumpWidget(_host(composite.build(() {})));
      return find
          .ancestor(of: composite.content, matching: find.byType(IgnorePointer))
          .evaluate()
          .length;
    }

    for (final composite in _composites) {
      for (final state in [TomAuthState.disabled, TomAuthState.read]) {
        testWidgets('${composite.name} adds one at $state', (tester) async {
          final baseline = await barriersAt(
            tester,
            composite,
            TomAuthState.full,
          );
          final withheld = await barriersAt(tester, composite, state);
          expect(
            withheld,
            greaterThan(baseline),
            reason:
                'the widget must contribute a barrier of its own; $baseline '
                'above the content at full, still $withheld at $state',
          );
        });
      }
    }
  });

  group('the opt-outs and extras the second table records', () {
    testWidgets('TomAuthGuard.blockPointerOnRead: false leaves read live', (
      tester,
    ) async {
      TomAuthorization.adapter = _Gate(TomAuthState.read);
      var acted = 0;
      await tester.pumpWidget(
        _host(
          TomAuthGuard(
            tomId: _gate,
            blockPointerOnRead: false,
            child: ElevatedButton(
              onPressed: () => acted++,
              child: const Text('act'),
            ),
          ),
        ),
      );
      await _tapAct(tester);
      expect(
        acted,
        1,
        reason: 'the documented opt-out is the only way back in',
      );
    });

    for (final state in [TomAuthState.disabled, TomAuthState.read]) {
      testWidgets('TomChoiceGroup disables every Radio at $state', (
        tester,
      ) async {
        // The second mechanism the table names. `IgnorePointer` stops the
        // pointer and not the keyboard, and the group sits under a
        // `RadioGroup` that brings arrow-key navigation with it — so removing
        // this half leaves a way in that no tap can detect.
        TomAuthorization.adapter = _Gate(state);
        await tester.pumpWidget(
          _host(
            const TomChoiceGroup<String>(
              tomId: _gate,
              items: _items,
              selected: 'a',
            ),
          ),
        );
        final radios = tester.widgetList<Radio<String>>(
          find.byType(Radio<String>),
        );
        expect(radios, hasLength(_items.length));
        // `== false`, not `!enabled`: the property is nullable, and `null`
        // means "inherit from the RadioGroup", which is a third answer and not
        // the one the table promises.
        expect(radios.every((r) => r.enabled == false), isTrue);
      });
    }

    testWidgets('TomChoiceGroup leaves every Radio enabled at full', (
      tester,
    ) async {
      TomAuthorization.adapter = _Gate(TomAuthState.full);
      await tester.pumpWidget(
        _host(
          const TomChoiceGroup<String>(
            tomId: _gate,
            items: _items,
            selected: 'a',
          ),
        ),
      );
      expect(
        tester
            .widgetList<Radio<String>>(find.byType(Radio<String>))
            .every((r) => r.enabled == true),
        isTrue,
      );
    });
  });
}
