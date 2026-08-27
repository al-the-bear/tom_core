import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/custom/tom_auth_tree.dart';

// bug §33 + tests §23: TomAuthTreeView per-node authorization. The class
// dartdoc deliberately distinguishes a `disabled` parent (children inherit the
// cap, cannot be widened by their own keys) from a `read` parent (children
// remain individually evaluated). The pre-fix resolver narrowed *every* child
// by the parent's effective state, so a `full` child under a `read` parent was
// wrongly downgraded to `read` and lost interactivity. These pin both halves of
// the documented contract end-to-end through a real render.

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

  group('TomAuthTreeView per-node auth propagation (bug §33)', () {
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

  // tcinc731: suppressing the row's own `InkWell.onTap` is not the same as
  // making the row non-interactive. `leading:` and `trailing:` take arbitrary
  // widgets, and a per-row action button is the whole reason a caller reaches
  // for those slots — so a tree that only nulls its own callback leaves the
  // one widget most likely to *do* something fully live at `read` and
  // `disabled`, while the module docs promise "pointer-blocked" at both.
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
      // the whole Column would re-introduce the bug the first group pins —
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
