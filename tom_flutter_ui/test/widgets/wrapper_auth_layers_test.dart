// Every Tom widget resolves authorization through the same four layers, in the
// same order: the resource rule, the group's mode, a per-widget authorizer,
// and a build-time UI-state controller. Widgets built on a family base get all
// four from `TomPolicyNodeBase`; widgets that extend a Flutter type get them
// from `TomWidgetMixin`.
//
// The wrappers that cannot resolve their own authorization reach those layers
// through a `TomAuthGate` placed in the slot they own. This file pins the two
// halves of that arrangement which a `none`-only test cannot see:
//
//   * that `disabled` gets the *disabled* treatment and not the `full` one.
//     `TomAuthState.disabled.isVisible` is true, so any gate written as
//     "hide if not visible, else dim if read, else pass through" lets a
//     disabled cell render fully interactive — which is exactly how the
//     private helper this gate replaced behaved.
//   * that a per-widget `authorizer` and a `uiStateController` reach the
//     decision at all. A wrapper that accepts neither implements one layer of
//     four while presenting the surface of a widget that implements all of
//     them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Resolves whatever the map says, and `full` for anything unlisted.
class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.rules);

  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _table({List<DataColumn>? columns, List<DataRow>? rows}) => DataTable(
  columns: columns ?? const [DataColumn(label: Text('c'))],
  rows:
      rows ??
      const [
        DataRow(cells: [DataCell(Text('v'))]),
      ],
);

/// The disabled treatment is an [AbsorbPointer] plus an [Opacity] below 1.0.
/// Asserted structurally rather than by exact opacity so a theme that tunes
/// the value does not fail the test — what matters is that the content is
/// dimmed and cannot be touched.
void _expectDisabledTreatment(WidgetTester tester, Finder content) {
  expect(content, findsOneWidget);
  expect(
    find.ancestor(of: content, matching: find.byType(AbsorbPointer)),
    findsWidgets,
    reason: 'disabled content must not receive pointer events',
  );
  final opacities = tester
      .widgetList<Opacity>(
        find.ancestor(of: content, matching: find.byType(Opacity)),
      )
      .where((o) => o.opacity < 1.0);
  expect(opacities, isNotEmpty, reason: 'disabled content must be dimmed');
}

void main() {
  setUp(() => TomAuthorization.adapter = _MapAuthAdapter({}));
  tearDown(TomAuthorization.reset);

  group('tcce2: disabled is a treatment, not a synonym for full', () {
    testWidgets('tcce2-01: a disabled TomDataCell is dimmed and untouchable', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'cell': TomAuthState.disabled,
      });
      await tester.pumpWidget(
        _host(
          _table(
            rows: [
              DataRow(
                cells: [
                  TomDataCell(tomId: 'cell', child: const Text('amount')),
                ],
              ),
            ],
          ),
        ),
      );
      _expectDisabledTreatment(tester, find.text('amount'));
    });

    testWidgets('tcce2-02: a disabled TomDataColumn header is dimmed', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'col': TomAuthState.disabled,
      });
      await tester.pumpWidget(
        _host(
          _table(
            columns: [TomDataColumn(tomId: 'col', label: const Text('salary'))],
          ),
        ),
      );
      _expectDisabledTreatment(tester, find.text('salary'));
    });

    testWidgets('tcce2-03: a full TomDataCell gets no treatment at all', (
      tester,
    ) async {
      // The guard for the other direction: if the gate dimmed everything,
      // "a disabled TomDataCell is dimmed and untouchable" would pass for the
      // wrong reason.
      await tester.pumpWidget(
        _host(
          _table(
            rows: [
              DataRow(
                cells: [
                  TomDataCell(tomId: 'cell', child: const Text('amount')),
                ],
              ),
            ],
          ),
        ),
      );
      final dimmed = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.text('amount'),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity < 1.0);
      expect(dimmed, isEmpty);
    });

    testWidgets('tcce2-04: a disabled TomExpansionPanel body is dimmed', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'panel': TomAuthState.disabled,
      });
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
      _expectDisabledTreatment(tester, find.text('body'));
    });
  });

  group('tcce2: the authorizer layer reaches the gated wrappers', () {
    final denyAll = TomAuthorizer(resolve: (_) => TomAuthState.none);
    final disableAll = TomAuthorizer(resolve: (_) => TomAuthState.disabled);

    testWidgets('tcce2-05: an authorizer hides a TomDataCell', (tester) async {
      await tester.pumpWidget(
        _host(
          _table(
            rows: [
              DataRow(
                cells: [
                  TomDataCell(
                    tomId: 'cell',
                    authorizer: denyAll,
                    child: const Text('amount'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('amount'), findsNothing);
    });

    testWidgets('tcce2-06: an authorizer hides a TomDataColumn label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          _table(
            columns: [
              TomDataColumn(
                tomId: 'col',
                authorizer: denyAll,
                label: const Text('salary'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('salary'), findsNothing);
    });

    test('tcce2-07: an authorizer narrows what TomDataRow reports', () {
      final row = TomDataRow(
        tomId: 'row',
        authorizer: denyAll,
        cells: const [],
      );
      expect(row.isVisible, isFalse);
    });

    testWidgets('tcce2-08: an authorizer disables a TomSnackBar content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => TomMessenger.showSnackBar(
                  context,
                  TomSnackBar(
                    tomId: 'bar',
                    authorizer: disableAll,
                    content: const Text('saved'),
                  ),
                ),
                child: const Text('go'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      _expectDisabledTreatment(tester, find.text('saved'));
    });

    testWidgets('tcce2-09: an authorizer hides a TomAnimatedPositioned child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              TomAnimatedPositioned(
                tomId: 'box',
                authorizer: denyAll,
                duration: const Duration(milliseconds: 1),
                child: const Text('inner'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('inner'), findsNothing);
    });

    testWidgets('tcce2-10: an authorizer that only narrows cannot widen', (
      tester,
    ) async {
      // The default strategy is authorizerNarrowsOnly, so an authorizer that
      // answers `full` under a `none` resource rule must not open the cell.
      TomAuthorization.adapter = _MapAuthAdapter({'cell': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          _table(
            rows: [
              DataRow(
                cells: [
                  TomDataCell(
                    tomId: 'cell',
                    authorizer: TomAuthorizer(
                      resolve: (_) => TomAuthState.full,
                    ),
                    child: const Text('amount'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('amount'), findsNothing);
    });
  });

  group('tcce2: the UI-state-controller layer reaches the gated wrappers', () {
    final hide = TomUIStateController(resolve: (_, _) => TomAuthState.none);

    testWidgets('tcce2-11: a controller hides a TomDataCell', (tester) async {
      await tester.pumpWidget(
        _host(
          _table(
            rows: [
              DataRow(
                cells: [
                  TomDataCell(
                    tomId: 'cell',
                    uiStateController: hide,
                    child: const Text('amount'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('amount'), findsNothing);
    });

    testWidgets('tcce2-12: a controller hides a TomExpansionPanel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ExpansionPanelList(
              children: [
                TomExpansionPanel(
                  tomId: 'panel',
                  uiStateController: hide,
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

    test('tcce2-13: a controller narrows what TomDataRow reports', () {
      final row = TomDataRow(
        tomId: 'row',
        uiStateController: hide,
        cells: const [],
      );
      expect(row.isVisible, isFalse);
    });

    testWidgets('tcce2-14: a controller can only narrow, never widen', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter({'cell': TomAuthState.none});
      await tester.pumpWidget(
        _host(
          _table(
            rows: [
              DataRow(
                cells: [
                  TomDataCell(
                    tomId: 'cell',
                    uiStateController: TomUIStateController(
                      resolve: (_, _) => TomAuthState.full,
                    ),
                    child: const Text('amount'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(find.text('amount'), findsNothing);
    });
  });

  group('tcce2: TomDataCell.empty resolves like every other cell', () {
    testWidgets('tcce2-15: an empty cell still registers with its group', (
      tester,
    ) async {
      // `TomDataCell.empty` renders nothing either way, so authorization has
      // no visible effect on it — but it accepts the same three fields as the
      // full constructor, so it must answer the same question with them
      // rather than leaving `basePath` as the only thing they feed.
      final group = TomAuthorizationGroup('grp');
      TomAuthorization.adapter = _MapAuthAdapter({'grp': TomAuthState.none});
      final cell = TomDataCell.empty(tomId: 'cell', tomGroup: group);
      expect(cell.authState, TomAuthState.none);
      await tester.pump();
    });

    test('tcce2-16: a full empty cell reports full', () {
      expect(TomDataCell.empty(tomId: 'cell').authState, TomAuthState.full);
    });
  });
}
