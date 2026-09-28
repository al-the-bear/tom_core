/// Executable example for the rendered behaviour of the
/// `advanced_container_layout/` module of `tom_flutter_ui`.
///
/// The companion example beside this one,
/// `advanced_container_layout_example.dart`, covers what can be shown without a
/// widget tree: flag composition, the device-context resolvers, the visibility
/// controllers, and a builder chain that produces an [Acl]. This one covers
/// what cannot. A fluent chain reads plausibly on the page whatever it does;
/// the questions a reader actually arrives with — what a variant replaces, what
/// a breakpoint splits, how wide a grid cell comes out, what a withheld
/// component does to the row's geometry, what id a component ends up carrying —
/// are all answered by the container at layout time, and are visible only once
/// something is laid out.
///
/// So every section below **renders** the layout and reads the result back off
/// the render tree: positions, widths, what is on screen and what is not.
///
/// 1. A **responsive variant** — one row above 600 px, three below it.
/// 2. A **row breakpoint** — the same four fields, split after two below 700 px.
/// 3. A **grid flow** — three columns sharing the width, and a `wrap` that
///    decides its own row breaks.
/// 4. **Authorization-aware rendering** — the same layout with one component
///    withheld, first shown inert and then hidden with its width reclaimed.
/// 5. **Composed ids** — the path a component ends up at, read back from the
///    [AclScope] the container published around it.
///
/// The widget-building functions are plain: each returns a `Widget` and can be
/// copied into an application unchanged. `run` is what renders and measures
/// them, so it takes the `WidgetTester` its suite provides.
///
/// Run `flutter test
/// test/advanced_container_layout/advanced_container_layout_rendered_example_test.dart`,
/// which calls this example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// The layouts. Each is ordinary builder code a reader can lift as it stands.
// =============================================================================

/// A form whose three fields share one row on a wide container and take a row
/// each below 600 px.
///
/// `addVariant` replaces the **whole** row set below its width, so the variant
/// describes the narrow layout from scratch rather than patching the wide one.
Widget buildVariantForm() => AclBuilder()
    .append(const Text('Street'))
    .setPSize(120, 20)
    .append(const Text('No.'))
    .setPSize(60, 20)
    .append(const Text('City'))
    .setPSize(120, 20)
    .addVariant(
      'narrow',
      atWidth: 600,
      builder: (b) => b
          .append(const Text('Street'))
          .setPSize(120, 20)
          .newRow()
          .append(const Text('No.'))
          .setPSize(60, 20)
          .newRow()
          .append(const Text('City'))
          .setPSize(120, 20),
    )
    .build();

/// Four fields in one row that breaks into two below 700 px.
///
/// A breakpoint is **positional**: the call sits between the two `append`s it
/// separates, and the split index is wherever the chain has got to. Nothing
/// else about the row changes — the same components, redistributed.
Widget buildBreakpointRow() => AclBuilder()
    .append(const Text('First'))
    .setPSize(80, 20)
    .append(const Text('Last'))
    .setPSize(80, 20)
    .addRowBreakpoint(atWidth: 700)
    .append(const Text('Email'))
    .setPSize(80, 20)
    .append(const Text('Phone'))
    .setPSize(80, 20)
    .build();

/// Six tiles in a three-column grid.
///
/// A flow container is given a flat list and decides the rows itself, so the
/// number of rows is a function of the width rather than of the call chain.
AclFlowContainer buildGrid(List<String> labels) => AclFlowContainer(
  kind: AclFlowKind.grid,
  columns: 3,
  components: [
    for (final label in labels)
      AclComponent(child: SizedBox(height: 20, child: Text(label))),
  ],
);

/// The same tiles, wrapped instead: a row ends when the next tile does not fit.
AclFlowContainer buildWrap(List<String> labels) => AclFlowContainer(
  kind: AclFlowKind.wrap,
  defaultItemWidth: 100,
  components: [
    for (final label in labels)
      AclComponent(
        child: SizedBox(height: 20, child: Text(label)),
        preferredSize: const Size(100, 20),
      ),
  ],
);

/// Three identified buttons in an identified container, so every component has
/// a policy path the authorization adapter can answer for.
///
/// [hideUnauthorized] decides what a withheld component looks like: shown and
/// inert, or gone with its width reclaimed by the row.
Widget buildSecuredRow({required bool hideUnauthorized}) => AclBuilder()
    .setAclId('order')
    .setAclDefaultHideUnauthorized(hideUnauthorized)
    .setRowId('actions')
    .append(const _Labelled('Save'))
    .setId('save')
    .setPSize(80, 20)
    .append(const _Labelled('Print'))
    .setId('print')
    .setPSize(80, 20)
    .append(const _Labelled('Delete'))
    .setId('delete')
    .setPSize(80, 20)
    .build();

/// A component that reports the [AclScope] path the container published around
/// it, which is the key every policy and resource lookup for it uses.
///
/// [rowIdScope] decides whether the row's id is a segment of that path. A row
/// id always names the *row's own* gate; it enters its components' paths only
/// when the row is declared an identity scope.
Widget buildScopeReporter(
  void Function(String? path) report, {
  required bool rowIdScope,
}) => AclBuilder()
    .setAclId('order')
    .setAclIdScope(true)
    .setRowId('actions')
    .setRowIdScope(rowIdScope)
    .append(_PathReporter(report))
    .setId('save')
    .setPSize(120, 20)
    .build();

/// Renders its label and declares itself withholdable, so `hideUnauthorized`
/// has something it can act on.
class _Labelled extends StatelessWidget implements TomAuthorizable {
  const _Labelled(this.label);

  final String label;

  @override
  String? get tomId => label.toLowerCase();

  @override
  TomAuthState get effectiveAuthState =>
      TomAuthorization.resolveAuth('order.actions.$tomId');

  @override
  TomAuthorizationGroup? get tomGroup => null;

  @override
  Widget build(BuildContext context) => Text(label);
}

/// Reads the published scope and hands its path to the example.
class _PathReporter extends StatelessWidget {
  const _PathReporter(this.report);

  final void Function(String? path) report;

  @override
  Widget build(BuildContext context) {
    report(AclScope.of(context)?.fullIdPath);
    return const Text('Save');
  }
}

/// Grants everything except the paths it is told to withhold.
class _DemoAdapter implements TomAuthorizationAdapter {
  _DemoAdapter(this.withheld);

  final Map<String, TomAuthState> withheld;

  @override
  TomAuthState resolveAuth(String path) => withheld[path] ?? TomAuthState.full;
}

// =============================================================================
// The demonstration. Renders each layout and reads the result back.
// =============================================================================

Future<void> run(WidgetTester tester) async {
  /// Lays [layout] out at [width] and settles, so every measurement below is
  /// taken after the container's convergence loop has finished.
  Future<void> pump(Widget layout, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: layout),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double topOf(String label) =>
      tester.getTopLeft(find.text(label, skipOffstage: false)).dy;
  double leftOf(String label) =>
      tester.getTopLeft(find.text(label, skipOffstage: false)).dx;

  /// How many distinct vertical positions the given labels occupy — the row
  /// count as the screen shows it, rather than as the builder recorded it.
  int rowsOccupiedBy(List<String> labels) => labels.map(topOf).toSet().length;

  // ---------------------------------------------------------------------------
  // 1. A responsive variant replaces the row set below its width.
  // ---------------------------------------------------------------------------
  print('=== 1. Responsive variant ===');
  const addressFields = ['Street', 'No.', 'City'];

  await pump(buildVariantForm(), 900);
  final wideRows = rowsOccupiedBy(addressFields);
  print(
    'at 900 px: $wideRows row(s) — ${addressFields.join(", ")} side by side',
  );

  await pump(buildVariantForm(), 400);
  final narrowRows = rowsOccupiedBy(addressFields);
  print('at 400 px: $narrowRows row(s) — one field each');

  assert(wideRows == 1, 'the base layout is one row');
  assert(narrowRows == 3, 'the narrow variant is three rows');

  // ---------------------------------------------------------------------------
  // 2. A row breakpoint splits one row without replacing anything.
  // ---------------------------------------------------------------------------
  print('\n=== 2. Row breakpoint ===');
  const contactFields = ['First', 'Last', 'Email', 'Phone'];

  await pump(buildBreakpointRow(), 900);
  final unsplit = rowsOccupiedBy(contactFields);
  print('at 900 px: $unsplit row(s) — all four across');

  await pump(buildBreakpointRow(), 500);
  final split = rowsOccupiedBy(contactFields);
  final firstRowTop = topOf('First');
  final emailTop = topOf('Email');
  print(
    'at 500 px: $split row(s) — First/Last at y=$firstRowTop, '
    'Email/Phone at y=$emailTop',
  );
  print('  the break falls where addRowBreakpoint sits in the chain');

  assert(unsplit == 1, 'above the breakpoint the row is intact');
  assert(split == 2, 'below it the row is two');
  assert(topOf('First') == topOf('Last'), 'the first two stay together');
  assert(topOf('Email') == topOf('Phone'), 'and so do the last two');
  assert(emailTop > firstRowTop, 'the second half is below the first');

  // ---------------------------------------------------------------------------
  // 3. A flow container decides its own rows.
  // ---------------------------------------------------------------------------
  print('\n=== 3. Flow: grid and wrap ===');
  const tiles = ['A', 'B', 'C', 'D', 'E', 'F'];

  final grid = buildGrid(tiles);
  // buildRows is public and pure: the row plan without rendering anything.
  final gridPlan = grid.buildRows(600);
  print('grid at 600 px: ${gridPlan.length} rows of ${grid.columns} columns');

  await pump(grid, 600);
  final gridRows = rowsOccupiedBy(tiles);
  final cellSpan = leftOf('B') - leftOf('A');
  print(
    'rendered: $gridRows rows, column pitch ${cellSpan.toStringAsFixed(1)} px',
  );

  final wrap = buildWrap(tiles);
  await pump(wrap, 340);
  final wrapNarrow = rowsOccupiedBy(tiles);
  await pump(wrap, 700);
  final wrapWide = rowsOccupiedBy(tiles);
  print(
    'wrap of six 100 px tiles: $wrapNarrow rows at 340 px, '
    '$wrapWide at 700 px',
  );

  assert(gridPlan.length == 2, 'six tiles in three columns is two rows');
  assert(gridRows == 2, 'and that is what renders');
  assert(cellSpan > 0, 'columns advance to the right');
  assert(wrapNarrow > wrapWide, 'a narrower wrap needs more rows');

  // ---------------------------------------------------------------------------
  // 4. Authorization decides what is rendered, and what the row does about it.
  // ---------------------------------------------------------------------------
  print('\n=== 4. Authorization-aware rendering ===');
  TomAuthorization.reset();
  TomAuthorization.adapter = _DemoAdapter({
    'order.actions.print': TomAuthState.none,
  });

  await pump(buildSecuredRow(hideUnauthorized: false), 600);
  final inertPresent = find
      .text('Print', skipOffstage: false)
      .evaluate()
      .length;
  final deleteWhenInert = leftOf('Delete');
  print(
    'hideUnauthorized false: Print rendered ($inertPresent found), '
    'Delete at x=$deleteWhenInert',
  );

  await pump(buildSecuredRow(hideUnauthorized: true), 600);
  final hiddenPresent = find
      .text('Print', skipOffstage: false)
      .evaluate()
      .length;
  final deleteWhenHidden = leftOf('Delete');
  print(
    'hideUnauthorized true:  Print gone ($hiddenPresent found), '
    'Delete at x=$deleteWhenHidden',
  );
  print('  the row reclaims the withheld component\'s width');

  assert(inertPresent == 1, 'a withheld component is shown unless told not to');
  assert(hiddenPresent == 0, 'hideUnauthorized removes it from the tree');
  assert(
    deleteWhenHidden < deleteWhenInert,
    'hiding it moves what follows leftwards — the width is reclaimed, not '
    'left as a hole',
  );

  TomAuthorization.reset();

  // ---------------------------------------------------------------------------
  // 5. The composed id a component ends up carrying.
  // ---------------------------------------------------------------------------
  print('\n=== 5. Composed ids ===');
  String? flat;
  await pump(buildScopeReporter((path) => flat = path, rowIdScope: false), 600);
  print('container "order" (an id scope) + component "save" → $flat');

  String? scoped;
  await pump(
    buildScopeReporter((path) => scoped = path, rowIdScope: true),
    600,
  );
  print('  ... and with the row declared an id scope as well  → $scoped');
  print('  a row id always names the row\'s own gate; it joins its');
  print('  components\' paths only when the row is an identity scope');
  print('  this is the key both the policy and the resource lookups use');

  assert(
    flat == 'order.save',
    'a plain row id does not extend its components\' paths; got $flat',
  );
  assert(scoped == 'order.actions.save', 'an id-scoped row does; got $scoped');
}
