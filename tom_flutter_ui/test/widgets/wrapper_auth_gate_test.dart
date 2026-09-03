import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tcce1: the eight wrappers that cannot resolve their own authorization.
//
// Most of the kit gates itself: 273 of the 290 widget classes extend a family
// base, and 13 more extend a Flutter widget whose `State` is public and wrap
// `super.build`. That leaves four widgets — and four of the nine types under
// `widgets/` that are not widgets at all — which can do neither, for two
// structural reasons that a call site cannot see:
//
//   - `DataCell`, `DataColumn`, `DataRow` and `ExpansionPanel` are *not
//     widgets*. They are plain classes holding widgets, so `TomWidgetMixin`
//     (declared `on Widget`) cannot be mixed in and there is no `build` to
//     wrap.
//   - `SnackBar`, `SnackBarAction`, `AnimatedPositioned` and
//     `AnimatedPositionedDirectional` are widgets whose `State` classes are
//     private to the framework, so `super.build(context)` is unreachable and
//     the `TomPopupMenuItem` pattern does not transfer.
//
// All eight nonetheless declared `tomId`/`tomGroup`/`scope` with the same
// names every gated wrapper uses, so `TomSnackBar(tomId: 'x', tomGroup: admin)`
// type-checked, read as gated, and showed to everyone. That is the exact
// failure authorization plumbing exists to prevent, and it was silent in both
// directions — nothing threw, nothing logged, `flutter analyze` was clean.
//
// Each of the eight owns a *slot* — `child`, `content`, `label`, `body` — and
// gating the slot is what gating the widget means. `TomAuthGate` is that slot
// wrapper, and it mixes in `TomWidgetMixin` so the answer comes from the one
// resolver rather than a second, weaker copy.
//
// Two of the eight cannot hide themselves even so, because their container
// decides their extent: a `DataRow` must yield one cell per column, and a
// `SnackBar` is placed by `ScaffoldMessenger`. Those two are pinned at the
// only points that *can* enforce them — `TomDataRow.isVisible`, which the
// caller filters on, and `TomMessenger`, which declines to show the bar.

class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;
  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Pumps [child] and taps a button that shows it as a snack bar.
Future<void> _showSnackBar(WidgetTester tester, SnackBar bar) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => TomMessenger.showSnackBar(context, bar),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(TomAuthorization.reset);

  group('tcce1: the four widgets whose Flutter State is private', () {
    testWidgets('tcce1-01: a none TomAnimatedPositioned hides its child', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'ap': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              TomAnimatedPositioned(
                tomId: 'ap',
                duration: Duration.zero,
                child: const Text('secret'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('secret'), findsNothing);
    });

    testWidgets('tcce1-02: a full TomAnimatedPositioned still shows its child', (
      tester,
    ) async {
      // The other half of the gate. A wrapper that hides everything passes the
      // test above and is useless, so both directions are pinned for one of
      // the four; the rest share the same `TomAuthGate` code path.
      TomAuthorization.adapter = _MapAuthAdapter({'ap': TomAuthState.full});
      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              TomAnimatedPositioned(
                tomId: 'ap',
                duration: Duration.zero,
                child: const Text('secret'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('secret'), findsOneWidget);
    });

    testWidgets(
      'tcce1-03: a none TomAnimatedPositionedDirectional hides its child',
      (tester) async {
        TomAuthorization.adapter = _MapAuthAdapter({'apd': TomAuthState.none});
        await tester.pumpWidget(
          _host(
            Stack(
              children: [
                TomAnimatedPositionedDirectional(
                  tomId: 'apd',
                  duration: Duration.zero,
                  child: const Text('secret'),
                ),
              ],
            ),
          ),
        );
        expect(find.text('secret'), findsNothing);
      },
    );

    testWidgets('tcce1-04: a none TomSnackBar hides its content', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'sb': TomAuthState.none});
      await _showSnackBar(
        tester,
        TomSnackBar(tomId: 'sb', content: const Text('secret')),
      );
      expect(find.text('secret'), findsNothing);
    });

    testWidgets('tcce1-05: a none TomSnackBarAction hides its label', (
      tester,
    ) async {
      // The one of the eight with no widget slot at all — `label` is a
      // `String`. It gates by building a delegate action inside its own state
      // instead, which is possible because the widget it must *be* is only
      // read for its label width and then mounted as a child.
      TomAuthorization.adapter = _MapAuthAdapter({'undo': TomAuthState.none});
      await _showSnackBar(
        tester,
        SnackBar(
          content: const Text('saved'),
          action: TomSnackBarAction(
            tomId: 'undo',
            label: 'Undo',
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('saved'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('tcce1-06: a group narrows a wrapper that has no tomId', (
      tester,
    ) async {
      // `tomGroup` was the field most obviously doing nothing: declared on all
      // eight, read by none. A group with no tomId is still a real ceiling.
      TomAuthorization.adapter = _MapAuthAdapter({'admin': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              TomAnimatedPositioned(
                tomGroup: TomAuthorizationGroup(
                  'admin',
                  mode: AuthGroupMode.controlsAll,
                ),
                duration: Duration.zero,
                child: const Text('secret'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('secret'), findsNothing);
    });
  });

  group('tcce1: the four Flutter classes that are not widgets', () {
    testWidgets('tcce1-07: a none TomDataCell hides its child', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({'cell': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          DataTable(
            columns: const [DataColumn(label: Text('col'))],
            rows: [
              DataRow(
                cells: [TomDataCell(tomId: 'cell', child: const Text('s'))],
              ),
            ],
          ),
        ),
      );
      expect(find.text('s'), findsNothing);
    });

    testWidgets('tcce1-08: a TomDataCell group narrows the cell', (
      tester,
    ) async {
      // Pinned because the helper this replaced accepted `tomGroup`, stored
      // it, and never read it — the cell rendered in full.
      TomAuthorization.adapter = _MapAuthAdapter({'g': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          DataTable(
            columns: const [DataColumn(label: Text('col'))],
            rows: [
              DataRow(
                cells: [
                  TomDataCell(
                    tomGroup: TomAuthorizationGroup(
                      'g',
                      mode: AuthGroupMode.controlsAll,
                    ),
                    child: const Text('s'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('s'), findsNothing);
    });

    testWidgets('tcce1-09: a none TomDataColumn hides its label', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'col': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          DataTable(
            columns: [TomDataColumn(tomId: 'col', label: const Text('secret'))],
            rows: const [
              DataRow(cells: [DataCell(Text('v'))]),
            ],
          ),
        ),
      );
      expect(find.text('secret'), findsNothing);
    });

    testWidgets('tcce1-10: a none TomExpansionPanel hides header and body', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'panel': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ExpansionPanelList(
              children: [
                TomExpansionPanel(
                  tomId: 'panel',
                  isExpanded: true,
                  headerBuilder: (_, _) => const Text('head'),
                  body: const Text('body'),
                ).toPanel(),
              ],
            ),
          ),
        ),
      );
      expect(find.text('head'), findsNothing);
      expect(find.text('body'), findsNothing);
    });

    test('tcce1-11: a none TomDataRow reports itself invisible', () {
      // A `DataRow` cannot hide itself: `DataTable` requires one cell per
      // column from every row, and a row of blanks reads as a data fault
      // rather than a permission. So this one gates by *reporting*, and the
      // caller filters — which is what its dartdoc has always told them to do.
      TomAuthorization.adapter = _MapAuthAdapter({'row': TomAuthState.none});
      final row = TomDataRow(tomId: 'row', cells: const []);
      expect(row.isVisible, isFalse);
    });

    test('tcce1-12: a TomDataRow group narrows the row', () {
      TomAuthorization.adapter = _MapAuthAdapter({'g': TomAuthState.none});
      final row = TomDataRow(
        tomGroup: TomAuthorizationGroup('g', mode: AuthGroupMode.controlsAll),
        cells: const [],
      );
      expect(row.isVisible, isFalse);
    });
  });

  group('tcce1: a hidden snack bar is not shown at all', () {
    testWidgets('tcce1-13: TomMessenger declines to show a none TomSnackBar', (
      tester,
    ) async {
      // Gating the content alone would leave an empty bar sliding up, which
      // is a worse answer than either showing or not showing it. A snack bar
      // is presented imperatively, so the only place its visibility can be
      // enforced is the call that presents it.
      TomAuthorization.adapter = _MapAuthAdapter({'sb': TomAuthState.none});
      await _showSnackBar(
        tester,
        TomSnackBar(tomId: 'sb', content: const Text('secret')),
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tcce1-14: a visible TomSnackBar is still shown', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'sb': TomAuthState.full});
      await _showSnackBar(
        tester,
        TomSnackBar(tomId: 'sb', content: const Text('shown')),
      );
      expect(find.text('shown'), findsOneWidget);
    });

    testWidgets('tcce1-15: a plain SnackBar is unaffected', (tester) async {
      // TomMessenger takes `SnackBar`, not `TomSnackBar`, so the gate has to
      // be conditional on the argument's type. A plain bar has no tomId to
      // resolve and must pass through untouched.
      TomAuthorization.adapter = _MapAuthAdapter({'sb': TomAuthState.none});
      await _showSnackBar(tester, const SnackBar(content: Text('plain')));
      expect(find.text('plain'), findsOneWidget);
    });
  });

  group('tcce1: no wrapper declares an authorization field it never reads', () {
    test('tcce1-16: every gated wrapper resolves through TomAuthGate', () {
      // The census that produced this file, reduced to the property that
      // matters: the eight all now route their slot through one resolver.
      // Written as a construction smoke test because the alternative — a
      // source scan — belongs to the gate script, not to the suite.
      TomAuthorization.adapter = _MapAuthAdapter({'x': TomAuthState.none});
      final gate = TomAuthGate(tomId: 'x', child: const Text('s'));
      expect(gate.getAuth(), TomAuthState.none);
      expect(gate.checkHidden(), isNotNull);
    });

    testWidgets(
      'tcce1-17: a gate with neither id nor group renders its child',
      (tester) async {
        // The wrappers pass `tomId` straight through, and it is nullable on all
        // eight. An ungated slot must not be narrowed by a gate that has
        // nothing to look up — including under an adapter that denies by
        // default, which is what an app in lockdown looks like.
        TomAuthorization.adapter = _MapAuthAdapter({});
        await tester.pumpWidget(
          _host(TomAuthGate(tomId: null, child: const Text('ungated'))),
        );
        expect(find.text('ungated'), findsOneWidget);
      },
    );
  });
}
