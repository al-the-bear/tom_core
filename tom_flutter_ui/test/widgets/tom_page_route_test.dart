import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// TomPageRoute exists because Flutter builds a route's child inside the
// Navigator's own build, NOT at the call site of push(). A raw
// MaterialPageRoute therefore constructs the pushed screen under whichever
// scope is current when the Navigator builds — in an app, the root zone — so
// the screen's widgets resolve their basePath, and with it their resources and
// their authorization, against the wrong scope.
//
// TomPageRoute captures TomScope.current at construction (push) time and runs
// the builder inside it via InScopeBuilder.wrap1.
//
// Test mechanics matter here: a zone propagates across `await`, so driving the
// pump from inside `TomScope.withScope` would keep the scope current during the
// Navigator's build and hide the very effect under test. So the route is
// CONSTRUCTED inside the scope and everything else runs outside it — which is
// exactly the app-side split between push time and build time.

/// Pushes an already-constructed [route] and settles, from outside any scope.
Future<void> _pushAndSettle(WidgetTester tester, Route<void> route) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(route),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

/// A route builder that records the `basePath` a Tom widget resolves to when
/// the route's child is built.
WidgetBuilder _reportingBuilder(void Function(String) report) => (_) {
  report(TomText(tomId: 'title', text: 'Title').basePath!);
  return const Scaffold(body: Text('pushed'));
};

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomUIColors.adapter = AllColorsAdapter();
    TomAuthorization.reset();
  });

  testWidgets('carries the push-time scope into the pushed screen', (
    tester,
  ) async {
    String? captured;

    // Constructed inside 'checkout' — TomPageRoute captures the scope here.
    final route = TomScope.withScope(
      'checkout',
      () => TomPageRoute<void>(builder: _reportingBuilder((p) => captured = p)),
    );

    // Built later, outside the scope, exactly as the Navigator does in an app.
    await _pushAndSettle(tester, route);

    expect(find.text('pushed'), findsOneWidget);
    expect(captured, 'checkout.title');
  });

  testWidgets(
    'a raw MaterialPageRoute loses the scope (why TomPageRoute exists)',
    (tester) async {
      String? captured;

      final route = TomScope.withScope(
        'checkout',
        () => MaterialPageRoute<void>(
          builder: _reportingBuilder((p) => captured = p),
        ),
      );

      await _pushAndSettle(tester, route);

      // The builder ran under the default scope, so the prefix is gone.
      expect(captured, 'title');
    },
  );

  testWidgets('an explicit scope overrides the ambient one', (tester) async {
    String? captured;
    final explicit = TomScopeBase(scopeId: 'admin', parentScope: null);

    final route = TomScope.withScope(
      'checkout',
      () => TomPageRoute<void>(
        scope: explicit,
        builder: _reportingBuilder((p) => captured = p),
      ),
    );

    await _pushAndSettle(tester, route);

    expect(captured, 'admin.title');
  });

  testWidgets('forwards the MaterialPageRoute settings it declares', (
    tester,
  ) async {
    final route = TomPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
      settings: const RouteSettings(name: '/detail'),
      maintainState: false,
      fullscreenDialog: true,
    );

    expect(route.settings.name, '/detail');
    expect(route.maintainState, isFalse);
    expect(route.fullscreenDialog, isTrue);
  });
}
