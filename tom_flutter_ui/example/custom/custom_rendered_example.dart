/// Runnable example for the `custom/` module of `tom_flutter_ui` — all nine
/// widgets, on screen, in one app.
///
/// The example beside this one covers what can be shown without a widget tree:
/// the `TomAuthState` lattice, the resource-path lookup, the data models. This
/// one covers the rest, which for a kit of composites is most of it. Two of
/// the nine — [TomAuthTreeView] and [TomInfiniteScroll] — were rendered by no
/// example at all, and they are the two with the most wiring.
///
/// Every widget below is built by a plain function that takes no tester and no
/// `BuildContext`, so each can be lifted into an application unchanged.
/// [buildGallery] assembles them; `main` runs it; [run] renders it under a
/// `WidgetTester` and checks that each one did what it says.
///
/// Run it as an app with `flutter run -t
/// example/custom/custom_rendered_example.dart`, or as a check with
/// `flutter test test/custom/custom_rendered_example_test.dart`, which calls
/// [run] and reports the result in its exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// The policy the gallery is rendered under.
// =============================================================================

/// Grants everything except the paths it is given.
///
/// A real application resolves these from its own backend; what matters here
/// is that three of the nine widgets ask, and that they ask about paths the
/// caller chose.
class DemoPolicy implements TomAuthorizationAdapter {
  DemoPolicy(this.withheld);

  final Map<String, TomAuthState> withheld;

  @override
  TomAuthState resolveAuth(String path) => withheld[path] ?? TomAuthState.full;
}

/// The policy the gallery demonstrates: one section read-only, one action
/// withheld outright, one choice group disabled.
DemoPolicy demoPolicy() => DemoPolicy(const {
  'demo.admin': TomAuthState.none,
  'demo.reports': TomAuthState.read,
  'demo.density': TomAuthState.disabled,
});

// =============================================================================
// The nine widgets, one function each.
// =============================================================================

/// [TomAuthGuard] over a button the policy withholds, beside one it grants.
Widget buildGuards() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TomAuthGuard(
      tomId: 'demo.admin',
      // `none` removes the subtree; this is what a reader sees instead.
      hiddenBuilder: (_) => const Text('(admin tools hidden)'),
      child: ElevatedButton(onPressed: () {}, child: const Text('Purge')),
    ),
    TomAuthGuard(
      tomId: 'demo.export',
      child: ElevatedButton(onPressed: () {}, child: const Text('Export')),
    ),
  ],
);

/// [TomAuthTreeView] whose `reports` section is read-only while the entries
/// under it stay live — the arrangement a navigation tree exists for.
Widget buildTree() => SizedBox(
  height: 160,
  child: TomAuthTreeView(
    parentPath: 'demo',
    nodes: [
      TomAuthTreeNode(
        tomId: 'reports',
        title: const Text('Reports'),
        leading: const Icon(Icons.folder_outlined),
        children: [
          TomAuthTreeNode(tomId: 'view', title: const Text('View')),
          TomAuthTreeNode(tomId: 'export', title: const Text('Export')),
        ],
      ),
      TomAuthTreeNode(tomId: 'settings', title: const Text('Settings')),
    ],
  ),
);

/// [TomChoiceGroup] gated as a unit: `demo.density` resolves `disabled`, so the
/// whole group is faded and every radio is disabled.
Widget buildChoiceGroup() => const TomChoiceGroup<String>(
  tomId: 'demo.density',
  title: 'Density',
  selected: 'comfortable',
  items: [
    TomChoiceGroupItem(value: 'compact', label: 'Compact'),
    TomChoiceGroupItem(value: 'comfortable', label: 'Comfortable'),
  ],
);

/// [TomEmptyState] with an action — the designed surface a list shows instead
/// of blank space.
Widget buildEmptyState() => SizedBox(
  // Tall enough for icon + headline + body + action inside the widget's own
  // 24-pixel padding; an empty state is a whole-surface idiom and only looks
  // like a box here because it is one section of a gallery.
  height: 280,
  child: TomEmptyState(
    title: 'No invoices',
    description: 'Nothing has been issued this quarter.',
    actionLabel: 'Create one',
    onActionPressed: () {},
  ),
);

/// [TomErrorBoundary] around a widget that throws while building.
Widget buildErrorBoundary() => TomErrorBoundary(
  fallbackBuilder: (context, details, retry) => Row(
    children: [
      const Expanded(child: Text('This panel failed')),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  ),
  child: const _AlwaysThrows(),
);

/// [TomInfiniteScroll] over a paged source.
Widget buildInfiniteScroll() => SizedBox(
  height: 200,
  child: TomInfiniteScroll<int>(
    pageSize: 20,
    fetcher: demoFetcher,
    itemBuilder: (context, item, index) =>
        ListTile(dense: true, title: Text('Row $item')),
  ),
);

/// A page source with more rows than any viewport: two frames of delay, so the
/// skeleton is visible on a real device.
Future<List<int>> demoFetcher(int page, int pageSize) async {
  await Future<void>.delayed(const Duration(milliseconds: 16));
  final start = page * pageSize;
  return [for (var i = start; i < start + pageSize; i++) i];
}

/// [TomLoadingOverlay] over content the user may see but not touch yet.
Widget buildLoadingOverlay() => const SizedBox(
  height: 160,
  child: TomLoadingOverlay(
    isLoading: true,
    message: 'Saving…',
    child: Center(child: Text('Invoice #4711')),
  ),
);

/// [TomSkeletonLoader] in both its forms: the rectangle it draws itself, and a
/// silhouette it masks.
Widget buildSkeletons() => Row(
  children: [
    const TomSkeletonLoader(width: 120, height: 16),
    const SizedBox(width: 12),
    TomSkeletonLoader(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 32, height: 32, color: Colors.black),
          const SizedBox(width: 8),
          Container(width: 80, height: 12, color: Colors.black),
        ],
      ),
    ),
  ],
);

/// The people and groups [buildPrincipalPicker] searches.
const _directory = [
  TomPrincipalCandidate(id: 'u1', displayName: 'Alice Archer'),
  TomPrincipalCandidate(id: 'u2', displayName: 'Albert Ames'),
  TomPrincipalCandidate(
    id: 'g1',
    displayName: 'Alpine Sales',
    kind: TomPrincipalKind.group,
  ),
];

/// [TomPrincipalPicker] over a local list, with one user and one group
/// already picked. An application passes its own search — a server's subject
/// search — and keeps the selection in its state.
Widget buildPrincipalPicker() => TomPrincipalPicker(
  search: (query) async => [
    for (final candidate in _directory)
      if (candidate.displayName.toLowerCase().startsWith(query.toLowerCase()))
        candidate,
  ],
  selected: [_directory[0], _directory[2]],
  onChanged: (_) {},
);

/// Throws while building, so the boundary beside it has something to catch.
class _AlwaysThrows extends StatelessWidget {
  const _AlwaysThrows();

  @override
  Widget build(BuildContext context) => throw StateError('demo failure');
}

// =============================================================================
// The app.
// =============================================================================

/// Every section, in one scrollable column.
Widget buildGallery() => ListView(
  padding: const EdgeInsets.all(16),
  children: [
    const Text('TomAuthGuard'),
    buildGuards(),
    const Divider(),
    const Text('TomAuthTreeView'),
    buildTree(),
    const Divider(),
    const Text('TomChoiceGroup'),
    buildChoiceGroup(),
    const Divider(),
    const Text('TomErrorBoundary'),
    buildErrorBoundary(),
    const Divider(),
    const Text('TomLoadingOverlay'),
    buildLoadingOverlay(),
    const Divider(),
    const Text('TomSkeletonLoader'),
    buildSkeletons(),
    const Divider(),
    const Text('TomInfiniteScroll'),
    buildInfiniteScroll(),
    const Divider(),
    const Text('TomEmptyState'),
    buildEmptyState(),
    const Divider(),
    const Text('TomPrincipalPicker'),
    buildPrincipalPicker(),
  ],
);

void main() {
  TomAuthorization.adapter = demoPolicy();
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('tom_flutter_ui — custom')),
        body: buildGallery(),
      ),
    ),
  );
}

// =============================================================================
// The check.
// =============================================================================

Future<void> run(WidgetTester tester) async {
  TomAuthorization.reset();
  TomAuthorization.adapter = demoPolicy();
  addTearDown(TomAuthorization.reset);

  // A tall viewport, so the whole gallery is laid out in one pass and each
  // section can be asserted without scrolling to it.
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // `TickerMode(enabled: false)`, because two of the nine animate
        // forever — the skeleton's shimmer and the overlay's progress
        // indicator — and a repeating animation never lets `pumpAndSettle`
        // return. Muting the tickers covers both; reduced motion would stop
        // only the skeleton, since Flutter's own indicator does not consult
        // it. The app above leaves them running, which is the point of them.
        body: TickerMode(enabled: false, child: buildGallery()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The boundary's child throws by design, and the framework records that
  // whether or not the boundary handled it. Draining here rather than at the
  // end keeps the assertion sharp: anything still recorded afterwards is a
  // failure this example did not arrange.
  var drained = 0;
  for (var error = tester.takeException(); error != null;) {
    assert(
      error is StateError && '$error'.contains('demo failure'),
      'an exception this example did not arrange: $error',
    );
    drained++;
    error = tester.takeException();
  }
  assert(drained > 0, 'the boundary demo is supposed to throw');

  // ---------------------------------------------------------------------------
  // 1. TomAuthGuard — `none` removes, and the grant beside it survives.
  // ---------------------------------------------------------------------------
  print('=== TomAuthGuard ===');
  final purgeVisible = find.text('Purge').evaluate().isNotEmpty;
  final exportVisible = find.text('Export').evaluate().isNotEmpty;
  print('withheld action rendered: $purgeVisible');
  print('granted action rendered:  $exportVisible');
  assert(!purgeVisible, 'demo.admin resolves none, so the subtree goes');
  assert(exportVisible, 'and the guard beside it is untouched');
  assert(
    find.text('(admin tools hidden)').evaluate().length == 1,
    'hiddenBuilder is what replaces it',
  );

  // ---------------------------------------------------------------------------
  // 2. TomAuthTreeView — a read-only section with live entries under it.
  // ---------------------------------------------------------------------------
  print('\n=== TomAuthTreeView ===');
  final reportsRow = tester.widget<InkWell>(
    find.widgetWithText(InkWell, 'Reports'),
  );
  final viewRow = tester.widget<InkWell>(find.widgetWithText(InkWell, 'View'));
  print('section interactive: ${reportsRow.onTap != null}');
  print('entry interactive:   ${viewRow.onTap != null}');
  assert(reportsRow.onTap == null, 'demo.reports is read-only');
  assert(viewRow.onTap != null, 'its entries resolve on their own keys');

  // ---------------------------------------------------------------------------
  // 3. TomChoiceGroup — one key gates the whole group.
  // ---------------------------------------------------------------------------
  print('\n=== TomChoiceGroup ===');
  final radios = tester.widgetList<Radio<String>>(find.byType(Radio<String>));
  print(
    'radios: ${radios.length}, all disabled: '
    '${radios.every((r) => r.enabled == false)}',
  );
  assert(radios.length == 2);
  assert(
    radios.every((r) => r.enabled == false),
    'disabled blocks the keyboard as well as the pointer',
  );

  // ---------------------------------------------------------------------------
  // 4. TomErrorBoundary — the throw became a panel, not a crash.
  // ---------------------------------------------------------------------------
  print('\n=== TomErrorBoundary ===');
  final caught = find.text('This panel failed').evaluate().length;
  print('fallback rendered: $caught');
  assert(caught == 1, 'the boundary caught its child and rendered instead');

  // ---------------------------------------------------------------------------
  // 5. TomLoadingOverlay — content visible, scrim over it.
  // ---------------------------------------------------------------------------
  print('\n=== TomLoadingOverlay ===');
  final overlaid = find.text('Invoice #4711').evaluate().length;
  final saving = find.text('Saving…').evaluate().length;
  print('content still painted: $overlaid, message: $saving');
  assert(overlaid == 1, 'the overlay veils the content rather than hiding it');
  assert(saving == 1);

  // ---------------------------------------------------------------------------
  // 6. TomSkeletonLoader — both forms present and settled.
  // ---------------------------------------------------------------------------
  print('\n=== TomSkeletonLoader ===');
  final skeletons = find.byType(TomSkeletonLoader).evaluate().length;
  print('skeletons: \$skeletons (settled, because the tickers are muted)');
  assert(skeletons >= 2, 'the childless form and the masked one');

  // ---------------------------------------------------------------------------
  // 7. TomInfiniteScroll — a page arrived without anyone scrolling.
  // ---------------------------------------------------------------------------
  print('\n=== TomInfiniteScroll ===');
  final firstRow = find.text('Row 0').evaluate().length;
  print('first row rendered: $firstRow');
  assert(firstRow == 1, 'the first page fetched and rendered on its own');

  // ---------------------------------------------------------------------------
  // 8. TomEmptyState — headline, body and action.
  // ---------------------------------------------------------------------------
  print('\n=== TomEmptyState ===');
  final headline = find.text('No invoices').evaluate().length;
  final action = find.text('Create one').evaluate().length;
  print('headline: $headline, action: $action');
  assert(headline == 1);
  assert(
    action == 1,
    'the action appears because both label and handler are '
    'given',
  );

  // ---------------------------------------------------------------------------
  // 9. TomPrincipalPicker — the picked user and group as chips, and the field.
  // ---------------------------------------------------------------------------
  print('\n=== TomPrincipalPicker ===');
  final chips = find.byType(InputChip).evaluate().length;
  final field = find.text('Share with').evaluate().length;
  print('chips: $chips, search field: $field');
  assert(chips == 2, 'one user and one group are picked');
  assert(field == 1, 'the field is offered, since nothing withholds it');
}
