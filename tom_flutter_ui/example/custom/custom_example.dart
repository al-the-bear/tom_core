/// Executable example for the `custom/` module of `tom_flutter_ui`.
///
/// `custom/` is the **non-form composite kit** — eight ready-made widgets that
/// sit on top of the same authorization, resource, and state systems the form
/// fields use, but solve recurring screen-level problems instead of editing a
/// value:
///
/// - [TomAuthGuard] — hide / disable a subtree by a resolved [TomAuthState].
/// - [TomAuthTreeView] / [TomAuthTreeNode] — a tree with per-node auth, where a
///   parent's effective auth narrows (never widens) its children.
/// - [TomRadioGroup] / [TomRadioGroupItem] — a radio group with one resource
///   key controlling the whole group.
/// - [TomEmptyState], [TomLoadingOverlay], [TomSkeletonLoader],
///   [TomErrorBoundary], [TomInfiniteScroll] — empty / loading / error idioms.
///
/// Unlike the field widgets, these are render-oriented, so most of their value
/// only shows up in a widget tree (covered by the `testWidgets` cases in
/// `test/custom/custom_example_test.dart`). What *is* pure and demonstrated
/// here is the shared machinery they delegate to: the `TomAuthState` lattice
/// (`narrow` — the exact rule [TomAuthTreeView] applies to inherit a parent's
/// auth into its children), the resource-path auth lookup every guard performs,
/// and the plain data models ([TomRadioGroupItem], [TomAuthTreeNode]).
///
/// Because it imports `flutter/material` (→ `dart:ui`) through the package
/// barrel, run it under the Flutter toolchain, e.g.
/// `flutter test example/custom/custom_example.dart`, not bare `dart run`.
/// The same scenarios are covered by `test/custom/custom_example_test.dart`.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Resolves auth state by exact resource path; unknown paths default to full.
class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void run() {
  // Several custom widgets resolve display strings / colours from Tom resources
  // at construction time, so install an (empty) provider and a colours adapter
  // — exactly as the widget tests do.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = AllColorsAdapter();
  TomAuthorization.reset();

  // ---------------------------------------------------------------------------
  // 1. The auth lookup every guard performs. TomAuthGuard / TomRadioGroup /
  //    TomAuthTreeView all qualify a tomId against the active scope and call
  //    TomAuthorization.resolveAuth — the same call exercised directly here.
  // ---------------------------------------------------------------------------
  TomAuthorization.adapter = _PathAuthAdapter({
    'reports.export': TomAuthState.none,
    'reports.edit': TomAuthState.disabled,
    'reports.view': TomAuthState.read,
    // 'reports.open' has no rule → full
  });
  print('export → ${TomAuthorization.resolveAuth('reports.export')}'); // none
  print('edit   → ${TomAuthorization.resolveAuth('reports.edit')}'); // disabled
  print('view   → ${TomAuthorization.resolveAuth('reports.view')}'); // read
  print('open   → ${TomAuthorization.resolveAuth('reports.open')}'); // full

  // ---------------------------------------------------------------------------
  // 2. The TomAuthState lattice — `narrow` is the exact rule TomAuthTreeView
  //    uses to fold a parent's effective auth into each child (a child can be
  //    tightened by its parent but never widened beyond it).
  // ---------------------------------------------------------------------------
  // A `read` parent caps a `full` child at `read`.
  final cappedChild = TomAuthState.full.narrow(TomAuthState.read);
  // A `full` parent leaves a `read` child at `read`.
  final freeParent = TomAuthState.read.narrow(TomAuthState.full);
  // A `none` parent hides the whole subtree.
  final hiddenSubtree = TomAuthState.full.narrow(TomAuthState.none);
  print('full ⊓ read = $cappedChild'); // read
  print('read ⊓ full = $freeParent'); // read
  print('full ⊓ none = $hiddenSubtree'); // none

  // ---------------------------------------------------------------------------
  // 3. The plain data models the composites consume.
  // ---------------------------------------------------------------------------
  const items = <TomRadioGroupItem<String>>[
    TomRadioGroupItem(value: 'eur', label: 'Euro', description: '€'),
    TomRadioGroupItem(value: 'usd', label: 'US Dollar'),
  ];
  print('radio items: ${items.map((i) => i.value).toList()}');

  final tree = TomAuthTreeNode(
    tomId: 'root',
    title: const Text('Root'),
    children: [
      TomAuthTreeNode(tomId: 'child', title: const Text('Child')),
    ],
  );
  print('tree root "${(tree.title as Text).data}" has '
      '${tree.children.length} child(ren)');

  // ---------------------------------------------------------------------------
  // 4. The widgets instantiate (context-free) with their wiring — rendering is
  //    covered by the testWidgets cases.
  // ---------------------------------------------------------------------------
  const guard = TomAuthGuard(tomId: 'reports.export', child: SizedBox());
  const overlay =
      TomLoadingOverlay(isLoading: true, message: 'Saving…', child: SizedBox());
  const empty = TomEmptyState(title: 'No items', description: 'Nothing yet.');
  const skeleton = TomSkeletonLoader(width: 120, height: 16, enabled: false);
  const group = TomRadioGroup<String>(
    tomId: 'reports.currency',
    items: items,
    selected: 'eur',
  );
  print('guard.tomId=${guard.tomId}, overlay.isLoading=${overlay.isLoading}, '
      'empty.title=${empty.title}, skeleton.enabled=${skeleton.enabled}, '
      'group.selected=${group.selected}');

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(TomAuthorization.resolveAuth('reports.export') == TomAuthState.none);
  assert(
      TomAuthorization.resolveAuth('reports.edit') == TomAuthState.disabled);
  assert(TomAuthorization.resolveAuth('reports.view') == TomAuthState.read);
  assert(TomAuthorization.resolveAuth('reports.open') == TomAuthState.full);

  assert(cappedChild == TomAuthState.read);
  assert(freeParent == TomAuthState.read);
  assert(hiddenSubtree == TomAuthState.none);

  assert(items.first.value == 'eur');
  assert(items.first.description == '€');
  assert(items[1].description == null);
  assert(tree.children.length == 1);
  assert(tree.children.first.tomId == 'child');

  assert(guard.tomId == 'reports.export');
  assert(overlay.isLoading);
  assert(empty.title == 'No items');
  assert(!skeleton.enabled);
  assert(group.selected == 'eur');

  TomAuthorization.reset();
}

void main() => run();
