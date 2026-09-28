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

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

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
  await tester.tap(
    find.widgetWithText(ElevatedButton, label),
    warnIfMissed: false,
  );
  await tester.pump();
}

/// Records every path it is asked about, and answers from [states].
///
/// The recording is the point: "this node is hidden" can be produced by a
/// composed path resolving `none` *or* by a flat path missing the map and
/// falling through to a default, and only the set of paths asked for tells
/// the two apart.
class _RecordingAdapter implements TomAuthorizationAdapter {
  _RecordingAdapter(this.states);
  final Map<String, TomAuthState> states;
  final List<String> asked = <String>[];

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    asked.add(resourceKeyPath);
    return states[resourceKeyPath] ?? TomAuthState.full;
  }
}

/// Two branches carrying the same child id, which is the case a flat namespace
/// cannot express.
List<TomAuthTreeNode> _twoBranches() => [
  TomAuthTreeNode(
    tomId: 'reports',
    title: const Text('reports'),
    children: [
      TomAuthTreeNode(tomId: 'view', title: const Text('reports view')),
    ],
  ),
  TomAuthTreeNode(
    tomId: 'invoices',
    title: const Text('invoices'),
    children: [
      TomAuthTreeNode(tomId: 'view', title: const Text('invoices view')),
    ],
  ),
];

void main() {
  tearDown(TomAuthorization.reset);

  group('a node is keyed by its whole branch', () {
    testWidgets('the tree resolves the composed paths and nothing else', (
      tester,
    ) async {
      final adapter = _RecordingAdapter(const {});
      TomAuthorization.adapter = adapter;

      await tester.pumpWidget(
        _host(TomAuthTreeView(parentPath: 'app', nodes: _twoBranches())),
      );

      expect(
        adapter.asked.toSet(),
        {
          'app.reports',
          'app.reports.view',
          'app.invoices',
          'app.invoices.view',
        },
        reason:
            'a flat namespace asks for app.view twice and can never grant the '
            'two branches apart',
      );
    });

    testWidgets('same-named children in different branches are separate '
        'grants', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'app.reports.view': TomAuthState.full,
        'app.invoices.view': TomAuthState.none,
      });

      await tester.pumpWidget(
        _host(TomAuthTreeView(parentPath: 'app', nodes: _twoBranches())),
      );

      expect(find.text('reports view'), findsOneWidget);
      expect(
        find.text('invoices view'),
        findsNothing,
        reason: 'granting one `view` must not grant the other',
      );
    });

    testWidgets('composition continues past the second level', (tester) async {
      // Two levels could be produced by a parent that prefixes its children
      // and stops; three cannot.
      final adapter = _RecordingAdapter(const {});
      TomAuthorization.adapter = adapter;

      await tester.pumpWidget(
        _host(
          TomAuthTreeView(
            parentPath: 'app',
            nodes: [
              TomAuthTreeNode(
                tomId: 'a',
                title: const Text('a'),
                children: [
                  TomAuthTreeNode(
                    tomId: 'b',
                    title: const Text('b'),
                    children: [
                      TomAuthTreeNode(tomId: 'c', title: const Text('c')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(adapter.asked, contains('app.a.b.c'));
    });

    testWidgets('with no parentPath the branch composes under the bare ids', (
      tester,
    ) async {
      // The ambient-scope arm. At the root scope the qualifier contributes
      // nothing, so what is left is the branch itself — which is the half of
      // the rule the `parentPath` cases cannot show.
      final adapter = _RecordingAdapter(const {});
      TomAuthorization.adapter = adapter;

      await tester.pumpWidget(_host(TomAuthTreeView(nodes: _twoBranches())));

      expect(adapter.asked.toSet(), {
        'reports',
        'reports.view',
        'invoices',
        'invoices.view',
      });
    });
  });

  group('TomAuthTreeView per-node auth propagation', () {
    testWidgets(
      'read parent does NOT cap a full child — child stays interactive',
      (tester) async {
        TomAuthorization.adapter = _MapAuthAdapter({
          'root.parent': TomAuthState.read,
          'root.parent.child': TomAuthState.full,
        });

        await tester.pumpWidget(
          _host(
            TomAuthTreeView(
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
            ),
          ),
        );

        // Parent is `read`: rendered but non-interactive.
        expect(find.text('parent'), findsOneWidget);
        expect(_onTapOf(tester, 'parent'), isNull);

        // Child resolves `full` on its own key and must remain interactive.
        expect(find.text('child'), findsOneWidget);
        expect(_onTapOf(tester, 'child'), isNotNull);
      },
    );

    testWidgets(
      'disabled parent DOES cap a full child — child non-interactive',
      (tester) async {
        TomAuthorization.adapter = _MapAuthAdapter({
          'root.parent': TomAuthState.disabled,
          'root.parent.child': TomAuthState.full,
        });

        await tester.pumpWidget(
          _host(
            TomAuthTreeView(
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
            ),
          ),
        );

        // Disabled parent caps its subtree: the child inherits `disabled`.
        expect(find.text('child'), findsOneWidget);
        expect(_onTapOf(tester, 'child'), isNull);
      },
    );

    testWidgets('none child is hidden along with its subtree', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.full,
        'root.parent.child': TomAuthState.none,
      });

      await tester.pumpWidget(
        _host(
          TomAuthTreeView(
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
          ),
        ),
      );

      expect(find.text('parent'), findsOneWidget);
      expect(find.text('child'), findsNothing);
    });

    testWidgets('full parent leaves a full child interactive', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.full,
        'root.parent.child': TomAuthState.full,
      });

      await tester.pumpWidget(
        _host(
          TomAuthTreeView(
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
          ),
        ),
      );

      expect(_onTapOf(tester, 'parent'), isNotNull);
      expect(_onTapOf(tester, 'child'), isNotNull);
    });
  });

  // `doc/custom.md` states one "pointer-blocked" treatment at `read` and
  // `disabled` across all three auth-gated composites; these are the cases
  // that hold the tree to it.
  group('expanding is independent of the node\'s auth state', () {
    /// A parent with one child, and a counter for the parent's `onTap`.
    Widget parentWithChild(VoidCallback onParentTap) => _host(
      TomAuthTreeView(
        parentPath: 'root',
        initiallyExpanded: true,
        nodes: [
          TomAuthTreeNode(
            tomId: 'parent',
            title: const Text('parent'),
            onTap: onParentTap,
            children: [
              TomAuthTreeNode(tomId: 'child', title: const Text('child')),
            ],
          ),
        ],
      ),
    );

    /// Taps the expander — the chevron, not the row.
    Future<void> tapExpander(WidgetTester tester) async {
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.expand_more || w.icon == Icons.chevron_right),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    for (final state in [TomAuthState.read, TomAuthState.disabled]) {
      testWidgets('a $state node can still be collapsed and re-expanded', (
        tester,
      ) async {
        // The interaction a read-only tree cannot do without: a section the
        // user may see but not activate still has to fold away, and the header
        // is exactly the row most likely to be withheld.
        TomAuthorization.adapter = _MapAuthAdapter({
          'root.parent': state,
          'root.parent.child': TomAuthState.full,
        });
        var parentTaps = 0;
        await tester.pumpWidget(parentWithChild(() => parentTaps++));

        expect(find.text('child'), findsOneWidget, reason: 'starts expanded');
        await tapExpander(tester);
        expect(find.text('child'), findsNothing, reason: 'collapsed');
        await tapExpander(tester);
        expect(find.text('child'), findsOneWidget, reason: 're-expanded');

        expect(
          parentTaps,
          0,
          reason:
              'the expander toggles and nothing else — activation stays '
              'suppressed, which is what the state means',
        );
      });

      testWidgets('a $state node still suppresses its own row tap', (
        tester,
      ) async {
        // The other half. Without it the fix above is satisfied by a node that
        // simply became interactive again.
        TomAuthorization.adapter = _MapAuthAdapter({'root.parent': state});
        var parentTaps = 0;
        await tester.pumpWidget(parentWithChild(() => parentTaps++));

        await tester.tap(find.text('parent'), warnIfMissed: false);
        await tester.pump();
        expect(parentTaps, 0);
      });
    }

    testWidgets('a full node toggles from the row as well as the chevron', (
      tester,
    ) async {
      // The control, and the behaviour that existed before: at `full` the
      // whole row is the target and it both toggles and activates.
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.full,
      });
      var parentTaps = 0;
      await tester.pumpWidget(parentWithChild(() => parentTaps++));

      await tester.tap(find.text('parent'));
      await tester.pumpAndSettle();
      expect(find.text('child'), findsNothing, reason: 'the row toggles too');
      expect(parentTaps, 1, reason: 'and activates');
    });

    testWidgets('the expander is not faded on a disabled node', (tester) async {
      // Dimming says "unavailable" and this control is available. A faded
      // chevron that still works says the opposite of what it does, which is
      // the same defect as a live-looking control that does nothing.
      TomAuthorization.adapter = _MapAuthAdapter({
        'root.parent': TomAuthState.disabled,
      });
      await tester.pumpWidget(parentWithChild(() {}));

      final chevron = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.expand_more,
      );
      expect(chevron, findsOneWidget);
      expect(
        find.ancestor(
          of: chevron,
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity < 1.0,
          ),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('parent'),
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity < 1.0,
          ),
        ),
        findsOneWidget,
        reason: 'the row beside it *is* faded — otherwise this proves nothing',
      );
    });

    testWidgets('a leaf node shows no expander', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter(const {});
      await tester.pumpWidget(
        _host(
          TomAuthTreeView(
            nodes: [TomAuthTreeNode(tomId: 'leaf', title: const Text('leaf'))],
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.expand_more || w.icon == Icons.chevron_right),
        ),
        findsNothing,
      );
    });
  });

  group('the tree\'s own presentation parameters', () {
    List<TomAuthTreeNode> nested() => [
      TomAuthTreeNode(
        tomId: 'parent',
        title: const Text('parent'),
        children: [TomAuthTreeNode(tomId: 'child', title: const Text('child'))],
      ),
    ];

    testWidgets('initiallyExpanded false hides the subtree until asked', (
      tester,
    ) async {
      TomAuthorization.adapter = _MapAuthAdapter(const {});
      await tester.pumpWidget(
        _host(TomAuthTreeView(initiallyExpanded: false, nodes: nested())),
      );

      expect(find.text('parent'), findsOneWidget);
      expect(find.text('child'), findsNothing);
    });

    testWidgets('a node overrides the tree default', (tester) async {
      // The control, and the reason the per-node flag exists: a tree that
      // starts collapsed usually wants one branch open.
      TomAuthorization.adapter = _MapAuthAdapter(const {});
      await tester.pumpWidget(
        _host(
          TomAuthTreeView(
            initiallyExpanded: false,
            nodes: [
              TomAuthTreeNode(
                tomId: 'parent',
                title: const Text('parent'),
                initiallyExpanded: true,
                children: [
                  TomAuthTreeNode(tomId: 'child', title: const Text('child')),
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('indentation is the step per level', (tester) async {
      TomAuthorization.adapter = _MapAuthAdapter(const {});
      await tester.pumpWidget(
        _host(TomAuthTreeView(indentation: 40, nodes: nested())),
      );

      final parentX = tester.getTopLeft(find.text('parent')).dx;
      final childX = tester.getTopLeft(find.text('child')).dx;
      expect(
        childX - parentX,
        40,
        reason: 'one level down is one indentation across',
      );
    });
  });

  group('TomAuthTreeView blocks the whole row, not just its own tap', () {
    /// A tree of one node carrying a counting button in [slot].
    Widget treeWithButton(String slot, VoidCallback onPressed) {
      final button = ElevatedButton(
        onPressed: onPressed,
        child: const Text('act'),
      );
      return _host(
        TomAuthTreeView(
          parentPath: 'root',
          nodes: [
            TomAuthTreeNode(
              tomId: 'node',
              title: const Text('node'),
              leading: slot == 'leading' ? button : null,
              trailing: slot == 'trailing' ? button : null,
            ),
          ],
        ),
      );
    }

    for (final slot in ['leading', 'trailing']) {
      testWidgets('a $slot button is inert on a disabled node', (tester) async {
        TomAuthorization.adapter = _MapAuthAdapter({
          'root.node': TomAuthState.disabled,
        });
        var taps = 0;
        await tester.pumpWidget(treeWithButton(slot, () => taps++));

        expect(find.text('act'), findsOneWidget, reason: 'still rendered');
        await _tapButton(tester, 'act');
        expect(taps, 0);
      });

      testWidgets('a $slot button is inert on a read node', (tester) async {
        TomAuthorization.adapter = _MapAuthAdapter({
          'root.node': TomAuthState.read,
        });
        var taps = 0;
        await tester.pumpWidget(treeWithButton(slot, () => taps++));

        expect(find.text('act'), findsOneWidget, reason: 'still rendered');
        await _tapButton(tester, 'act');
        expect(taps, 0);
      });

      testWidgets('a $slot button is live on a full node', (tester) async {
        // The control. Without it the two cases above would also pass against
        // a tree that rendered no button at all.
        TomAuthorization.adapter = _MapAuthAdapter({
          'root.node': TomAuthState.full,
        });
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
        'root.parent.child': TomAuthState.full,
      });
      var parentTaps = 0;
      var childTaps = 0;

      await tester.pumpWidget(
        _host(
          TomAuthTreeView(
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
          ),
        ),
      );

      await _tapButton(tester, 'parent-act');
      await _tapButton(tester, 'child-act');
      expect(parentTaps, 0, reason: 'parent resolves read → blocked');
      expect(childTaps, 1, reason: 'child resolves full on its own key');
    });
  });
}
