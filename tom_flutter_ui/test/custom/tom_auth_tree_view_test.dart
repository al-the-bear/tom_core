/// Behavioural coverage for `TomAuthTreeView`'s per-node authorization.
///
/// This is the only widget in `custom/` that resolves a *different* auth state
/// for every node it renders, and both risks below follow from that: one tree
/// has to produce a different shape per user, so what a node passes down and
/// how much of it is blocked are decisions taken once per row rather than once
/// per widget.
///
///   * **Only a `disabled` node caps its subtree.** A `read` or `full` node
///     passes `full` down and leaves every descendant to resolve on its own
///     key. Narrowing children by the parent's state instead is the plausible
///     implementation and the wrong one: a navigation tree exists precisely to
///     put entries a user may open under a section header they may not
///     activate, so the over-narrow version hides half the app from the people
///     it was built for. The first group pins both halves.
///
///   * **The block covers the whole row, not just the row's own tap.**
///     `leading:` and `trailing:` take arbitrary widgets, and a per-row action
///     button is the usual reason to reach for them, so suppressing only
///     `InkWell.onTap` would leave the one widget most likely to *do*
///     something fully live on a node the user has no permission to act on.
///     The second group taps real buttons for that reason.
///
/// The two groups therefore measure at different layers, which is itself
/// load-bearing. The first reads `InkWell.onTap` back off the row; the second
/// taps and counts. A barrier that wrapped each node's whole subtree instead
/// of its own row would satisfy every assertion in the first group and still
/// cap the children — so the case that taps a `full` child's button under a
/// `read` parent is the only one that can see it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The package barrel, not `src/custom/tom_auth_tree.dart`, and not only for
// consistency with the five sibling suites: importing the library directly
// would keep this file green even if `tom_custom_widgets.dart` stopped
// exporting the tree — which is the entire failure mode of a barrel
// regression, and the one a test reaching past the public surface cannot see.
//
// It also covers the kernel's auth types, which is why no `tom_core_kernel`
// import stands beside it: `resource_auth.dart` re-exports `TomAuthState`,
// `TomAuthorization` and `TomAuthorizationAdapter`, so a consumer of this
// package reaches them exactly the way this file does.
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Map-backed adapter: each node path resolves to a predetermined state.
class _MapAuthAdapter implements TomAuthorizationAdapter {
  _MapAuthAdapter(this.states);
  final Map<String, TomAuthState> states;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      states[resourceKeyPath] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

/// Reads the [InkWell.onTap] of the row whose title is [text]; `null` ⇒ the
/// node is non-interactive (taps suppressed).
VoidCallback? _onTapOf(WidgetTester tester, String text) {
  final ink = tester.widget<InkWell>(find.widgetWithText(InkWell, text));
  return ink.onTap;
}

/// Taps the button labelled [label] and reports whether it fired.
///
/// Suppressing `warnIfMissed` is the point of the helper rather than a
/// convenience: a blocked button is *expected* to miss its hit test, and the
/// counter — not the warning — is the assertion.
Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ElevatedButton, label),
      warnIfMissed: false);
  await tester.pump();
}

void main() {
  tearDown(TomAuthorization.reset);

  group('TomAuthTreeView per-node auth propagation', () {
    testWidgets('read parent does NOT cap a full child — child stays interactive',
        (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.read,
        'root.child': TomAuthState.full,
      });

      await tester.pumpWidget(_host(TomAuthTreeView(
        parentPath: 'root',
        nodes: [
          TomAuthTreeNode(
            tomId: 'parent',
            title: const Text('parent'),
            children: [
              TomAuthTreeNode(tomId: 'child', title: const Text('child')),
            ],
          ),
        ],
      )));

      // Parent is `read`: rendered but non-interactive.
      expect(find.text('parent'), findsOneWidget);
      expect(_onTapOf(tester, 'parent'), isNull);

      // Child resolves `full` on its own key and must remain interactive.
      expect(find.text('child'), findsOneWidget);
      expect(_onTapOf(tester, 'child'), isNotNull);
    });

    testWidgets('disabled parent DOES cap a full child — child non-interactive',
        (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.disabled,
        'root.child': TomAuthState.full,
      });

      await tester.pumpWidget(_host(TomAuthTreeView(
        parentPath: 'root',
        nodes: [
          TomAuthTreeNode(
            tomId: 'parent',
            title: const Text('parent'),
            children: [
              TomAuthTreeNode(tomId: 'child', title: const Text('child')),
            ],
          ),
        ],
      )));

      // Disabled parent caps its subtree: the child inherits `disabled`.
      expect(find.text('child'), findsOneWidget);
      expect(_onTapOf(tester, 'child'), isNull);
    });

    testWidgets('none child is hidden along with its subtree', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.full,
        'root.child': TomAuthState.none,
      });

      await tester.pumpWidget(_host(TomAuthTreeView(
        parentPath: 'root',
        nodes: [
          TomAuthTreeNode(
            tomId: 'parent',
            title: const Text('parent'),
            children: [
              TomAuthTreeNode(tomId: 'child', title: const Text('child')),
            ],
          ),
        ],
      )));

      expect(find.text('parent'), findsOneWidget);
      expect(find.text('child'), findsNothing);
    });

    testWidgets('full parent leaves a full child interactive', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.full,
        'root.child': TomAuthState.full,
      });

      await tester.pumpWidget(_host(TomAuthTreeView(
        parentPath: 'root',
        nodes: [
          TomAuthTreeNode(
            tomId: 'parent',
            title: const Text('parent'),
            children: [
              TomAuthTreeNode(tomId: 'child', title: const Text('child')),
            ],
          ),
        ],
      )));

      expect(_onTapOf(tester, 'parent'), isNotNull);
      expect(_onTapOf(tester, 'child'), isNotNull);
    });
  });

  // `doc/custom.md` states one "pointer-blocked" treatment at `read` and
  // `disabled` across all three auth-gated composites; these are the cases
  // that hold the tree to it.
  group('TomAuthTreeView blocks the whole row, not just its own tap', () {
    /// A tree of one node carrying a counting button in [slot].
    Widget treeWithButton(String slot, VoidCallback onPressed) {
      final button = ElevatedButton(
        onPressed: onPressed,
        child: const Text('act'),
      );
      return _host(TomAuthTreeView(
        parentPath: 'root',
        nodes: [
          TomAuthTreeNode(
            tomId: 'node',
            title: const Text('node'),
            leading: slot == 'leading' ? button : null,
            trailing: slot == 'trailing' ? button : null,
          ),
        ],
      ));
    }

    for (final slot in ['leading', 'trailing']) {
      testWidgets('a $slot button is inert on a disabled node', (tester) async {
        TomAuthorization.adapter =
            _MapAuthAdapter({'root.node': TomAuthState.disabled});
        var taps = 0;
        await tester.pumpWidget(treeWithButton(slot, () => taps++));

        expect(find.text('act'), findsOneWidget, reason: 'still rendered');
        await _tapButton(tester, 'act');
        expect(taps, 0);
      });

      testWidgets('a $slot button is inert on a read node', (tester) async {
        TomAuthorization.adapter =
            _MapAuthAdapter({'root.node': TomAuthState.read});
        var taps = 0;
        await tester.pumpWidget(treeWithButton(slot, () => taps++));

        expect(find.text('act'), findsOneWidget, reason: 'still rendered');
        await _tapButton(tester, 'act');
        expect(taps, 0);
      });

      testWidgets('a $slot button is live on a full node', (tester) async {
        // The control. Without it the two cases above would also pass against
        // a tree that rendered no button at all.
        TomAuthorization.adapter =
            _MapAuthAdapter({'root.node': TomAuthState.full});
        var taps = 0;
        await tester.pumpWidget(treeWithButton(slot, () => taps++));

        await _tapButton(tester, 'act');
        expect(taps, 1);
      });
    }

    testWidgets('blocking is per row — a full child under a read parent keeps '
        'its button live', (tester) async {
      // The counterpart to the propagation rule above: `read` caps nothing, so
      // the block must wrap each node's own row and not the subtree. Wrapping
      // the whole Column would impose the cap that the first group forbids —
      // through the pointer layer instead of the auth layer, and so invisible
      // to every assertion in it.
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.read,
        'root.child': TomAuthState.full,
      });
      var parentTaps = 0;
      var childTaps = 0;

      await tester.pumpWidget(_host(TomAuthTreeView(
        parentPath: 'root',
        nodes: [
          TomAuthTreeNode(
            tomId: 'parent',
            title: const Text('parent'),
            trailing: ElevatedButton(
              onPressed: () => parentTaps++,
              child: const Text('parent-act'),
            ),
            children: [
              TomAuthTreeNode(
                tomId: 'child',
                title: const Text('child'),
                trailing: ElevatedButton(
                  onPressed: () => childTaps++,
                  child: const Text('child-act'),
                ),
              ),
            ],
          ),
        ],
      )));

      await _tapButton(tester, 'parent-act');
      await _tapButton(tester, 'child-act');
      expect(parentTaps, 0, reason: 'parent resolves read → blocked');
      expect(childTaps, 1, reason: 'child resolves full on its own key');
    });
  });
}
