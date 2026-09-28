/// `TomAuthGuard`'s own parameters.
///
/// The four-state contract it shares with `TomChoiceGroup` and
/// `TomAuthTreeView` is in `auth_composite_table_test.dart`, driven as a table
/// across all three — repeating it here would be a second copy of a claim that
/// is stated once on purpose. What is left is what only this widget has:
/// `hiddenBuilder`, `disabledOpacity`, an explicit `scope`, and the pure
/// `resolveAuthState`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class _Rules implements TomAuthorizationAdapter {
  _Rules(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The opacity the guard applied above [child], or null when it applied none.
double? _fadeOn(WidgetTester tester, Finder child) {
  final faded = tester
      .widgetList<Opacity>(
        find.ancestor(of: child, matching: find.byType(Opacity)),
      )
      .where((o) => o.opacity < 1.0);
  return faded.isEmpty ? null : faded.first.opacity;
}

void main() {
  tearDown(TomAuthorization.reset);

  group('resolveAuthState', () {
    test('reports what the adapter says for the qualified path', () {
      // Public and `@visibleForTesting` so the decision can be asserted
      // without a widget tree — which is the only way to see it separately
      // from what the guard then does with it.
      TomAuthorization.adapter = _Rules({
        'reports.hidden': TomAuthState.none,
        'reports.locked': TomAuthState.disabled,
        'reports.readonly': TomAuthState.read,
      });
      const child = SizedBox.shrink();

      expect(
        const TomAuthGuard(
          tomId: 'reports.hidden',
          child: child,
        ).resolveAuthState(),
        TomAuthState.none,
      );
      expect(
        const TomAuthGuard(
          tomId: 'reports.locked',
          child: child,
        ).resolveAuthState(),
        TomAuthState.disabled,
      );
      expect(
        const TomAuthGuard(
          tomId: 'reports.readonly',
          child: child,
        ).resolveAuthState(),
        TomAuthState.read,
      );
      expect(
        const TomAuthGuard(
          tomId: 'reports.open',
          child: child,
        ).resolveAuthState(),
        TomAuthState.full,
        reason: 'an unlisted path is granted — the adapter decides, not this',
      );
    });
  });

  group('hiddenBuilder', () {
    testWidgets('replaces the shrink at none', (tester) async {
      // `none` removing the subtree is the contract; what stands in its place
      // is this widget's own parameter, and a caller who wants "you do not
      // have access" instead of a hole has no other way to say so.
      TomAuthorization.adapter = _Rules({'secret': TomAuthState.none});

      await tester.pumpWidget(
        _host(
          TomAuthGuard(
            tomId: 'secret',
            hiddenBuilder: (_) => const Text('not available to you'),
            child: const Text('secret content'),
          ),
        ),
      );

      expect(find.text('secret content'), findsNothing);
      expect(find.text('not available to you'), findsOneWidget);
    });

    testWidgets('is not consulted in any other state', (tester) async {
      // The control. A builder called at `read` would replace content the
      // user is entitled to see.
      TomAuthorization.adapter = _Rules({'locked': TomAuthState.read});

      await tester.pumpWidget(
        _host(
          TomAuthGuard(
            tomId: 'locked',
            hiddenBuilder: (_) => const Text('not available to you'),
            child: const Text('readable content'),
          ),
        ),
      );

      expect(find.text('readable content'), findsOneWidget);
      expect(find.text('not available to you'), findsNothing);
    });
  });

  group('disabledOpacity', () {
    testWidgets('is the fade applied at disabled', (tester) async {
      TomAuthorization.adapter = _Rules({'locked': TomAuthState.disabled});

      await tester.pumpWidget(
        _host(
          const TomAuthGuard(
            tomId: 'locked',
            disabledOpacity: 0.17,
            child: Text('content'),
          ),
        ),
      );

      expect(_fadeOn(tester, find.text('content')), 0.17);
    });

    testWidgets('read is not faded, whatever it is set to', (tester) async {
      // The two withheld states are told apart by exactly this: `read` keeps
      // the value readable, which is the whole difference between them.
      TomAuthorization.adapter = _Rules({'locked': TomAuthState.read});

      await tester.pumpWidget(
        _host(
          const TomAuthGuard(
            tomId: 'locked',
            disabledOpacity: 0.17,
            child: Text('content'),
          ),
        ),
      );

      expect(_fadeOn(tester, find.text('content')), isNull);
    });
  });

  group('scope', () {
    testWidgets('an explicit scope qualifies the key instead of the ambient '
        'one', (tester) async {
      // The parameter exists so a guard can address a path outside wherever it
      // happens to be built. Without a case, "it takes a scope" and "it
      // ignores the scope" render identically.
      final scope = TomScopeBase(scopeId: 'admin');
      TomAuthorization.adapter = _Rules({'admin.purge': TomAuthState.none});

      await tester.pumpWidget(
        _host(
          TomAuthGuard(
            tomId: 'purge',
            scope: scope,
            child: const Text('scoped content'),
          ),
        ),
      );
      expect(
        find.text('scoped content'),
        findsNothing,
        reason: 'the scope put the key at admin.purge, which is withheld',
      );

      await tester.pumpWidget(
        _host(
          const TomAuthGuard(tomId: 'purge', child: Text('scoped content')),
        ),
      );
      expect(
        find.text('scoped content'),
        findsOneWidget,
        reason: 'without it the bare key is unlisted, and unlisted is granted',
      );
    });
  });
}
