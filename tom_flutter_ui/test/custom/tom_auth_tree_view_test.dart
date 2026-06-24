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
}
