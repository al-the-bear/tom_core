import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/custom/custom_example.dart' as example;

/// Resolves auth state by exact resource path; unknown paths default to full.
class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Matches the faded `Opacity(0.4)` wrapper that the auth widgets add (and
/// only they add) in the `disabled` state — robust against the app shell's
/// own `IgnorePointer`s.
Finder _fadedAncestorOf(Finder child) => find.ancestor(
  of: child,
  matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
);

void main() {
  setUp(() {
    // TomEmptyState resolves strings in its constructor, so a provider has to
    // be installed before any case builds one. No colours adapter: nothing in
    // `custom/` resolves a colour through TomUIColors — these widgets take
    // their appearance from the ambient ThemeData.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomAuthorization.reset();
  });
  tearDown(TomAuthorization.reset);

  group('custom example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('TomAuthGuard.resolveAuthState (pure)', () {
    test('maps each resource rule to its TomAuthState', () {
      TomAuthorization.adapter = _PathAuthAdapter({
        'reports.export': TomAuthState.none,
        'reports.edit': TomAuthState.disabled,
        'reports.view': TomAuthState.read,
      });
      Widget c() => const SizedBox();
      expect(
        const TomAuthGuard(
          tomId: 'reports.export',
          child: SizedBox(),
        ).resolveAuthState(),
        TomAuthState.none,
      );
      expect(
        TomAuthGuard(tomId: 'reports.edit', child: c()).resolveAuthState(),
        TomAuthState.disabled,
      );
      expect(
        TomAuthGuard(tomId: 'reports.view', child: c()).resolveAuthState(),
        TomAuthState.read,
      );
      expect(
        TomAuthGuard(tomId: 'reports.open', child: c()).resolveAuthState(),
        TomAuthState.full,
      );
    });
  });

  group('TomAuthGuard rendering', () {
    testWidgets('none collapses the child to SizedBox.shrink', (tester) async {
      TomAuthorization.adapter = _PathAuthAdapter({
        'secret': TomAuthState.none,
      });
      await tester.pumpWidget(
        _host(const TomAuthGuard(tomId: 'secret', child: Text('hidden'))),
      );
      expect(find.text('hidden'), findsNothing);
    });

    testWidgets('disabled keeps the child but blocks pointers', (tester) async {
      TomAuthorization.adapter = _PathAuthAdapter({
        'locked': TomAuthState.disabled,
      });
      await tester.pumpWidget(
        _host(const TomAuthGuard(tomId: 'locked', child: Text('shown'))),
      );
      expect(find.text('shown'), findsOneWidget);
      // The disabled treatment fades the child to opacity 0.4.
      expect(_fadedAncestorOf(find.text('shown')), findsOneWidget);
    });

    testWidgets('full renders the child untouched', (tester) async {
      await tester.pumpWidget(
        _host(const TomAuthGuard(tomId: 'open', child: Text('content'))),
      );
      expect(find.text('content'), findsOneWidget);
      expect(_fadedAncestorOf(find.text('content')), findsNothing);
    });
  });

  group('TomRadioGroup rendering', () {
    const items = <TomRadioGroupItem<String>>[
      TomRadioGroupItem(value: 'a', label: 'Alpha'),
      TomRadioGroupItem(value: 'b', label: 'Beta'),
    ];

    testWidgets('none hides the entire group', (tester) async {
      TomAuthorization.adapter = _PathAuthAdapter({
        'choice': TomAuthState.none,
      });
      await tester.pumpWidget(
        _host(
          const TomRadioGroup<String>(
            tomId: 'choice',
            items: items,
            selected: 'a',
          ),
        ),
      );
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('full renders every item interactively', (tester) async {
      await tester.pumpWidget(
        _host(const TomRadioGroup<String>(items: items, selected: 'a')),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      // The group is not faded at `full`.
      expect(_fadedAncestorOf(find.text('Alpha')), findsNothing);
    });
  });

  group('TomEmptyState / TomLoadingOverlay / TomSkeletonLoader rendering', () {
    testWidgets('empty state shows title and description', (tester) async {
      await tester.pumpWidget(
        _host(TomEmptyState(title: 'Nothing here', description: 'Add one.')),
      );
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Add one.'), findsOneWidget);
    });

    testWidgets('a tomId reads the headline from the installed bundle', (
      tester,
    ) async {
      // The module's only resource lookup, and so the only reason the example
      // and this suite install a provider at all.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(const {
          'reports': {
            'empty': {'title': 'No reports', 'description': 'Nothing yet.'},
          },
        }),
      );
      await tester.pumpWidget(
        _host(TomEmptyState(tomId: 'reports.empty', title: 'ignored')),
      );
      // Resources win over the explicit parameter, which is the fallback.
      expect(find.text('No reports'), findsOneWidget);
      expect(find.text('ignored'), findsNothing);
      expect(find.text('Nothing yet.'), findsOneWidget);
    });

    testWidgets('loading overlay shows scrim + spinner only when loading', (
      tester,
    ) async {
      // The overlay is a Stack that sizes to its child, so give the child a
      // real size — the widget is meant to wrap a full-sized subtree.
      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(
            isLoading: false,
            child: SizedBox(width: 300, height: 300, child: Text('body')),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(
        _host(
          const TomLoadingOverlay(
            isLoading: true,
            message: 'Working…',
            child: SizedBox(width: 300, height: 300, child: Text('body')),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Working…'), findsOneWidget);
    });

    testWidgets('a disabled childless skeleton drops the shimmer mask', (
      tester,
    ) async {
      // Scoped to the childless form on purpose. "Disabled renders a static
      // placeholder" holds only here: with a `child`, disabling returns the
      // caller's widget in its own colours and paints no placeholder at all.
      // A ShaderMask check cannot tell those two apart — neither has a mask —
      // so the real distinction is pinned by pixels in
      // `tom_skeleton_loader_test.dart`.
      await tester.pumpWidget(
        _host(const TomSkeletonLoader(width: 80, height: 12, enabled: false)),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('TomErrorBoundary rendering', () {
    testWidgets('renders its child when no error is thrown', (tester) async {
      await tester.pumpWidget(
        _host(const TomErrorBoundary(child: Text('safe'))),
      );
      expect(find.text('safe'), findsOneWidget);
    });
  });

  group('data models', () {
    test('TomRadioGroupItem keeps value / label / description', () {
      const item = TomRadioGroupItem(
        value: 7,
        label: 'Seven',
        description: 'prime',
      );
      expect(item.value, 7);
      expect(item.label, 'Seven');
      expect(item.description, 'prime');
    });

    test('TomAuthTreeNode nests children and defaults', () {
      final node = TomAuthTreeNode(
        tomId: 'root',
        title: const Text('Root'),
        children: [TomAuthTreeNode(tomId: 'leaf', title: const Text('Leaf'))],
      );
      expect(node.children, hasLength(1));
      expect(node.children.first.tomId, 'leaf');
      expect(node.children.first.children, isEmpty);
      expect(node.initiallyExpanded, isNull);
    });
  });
}
