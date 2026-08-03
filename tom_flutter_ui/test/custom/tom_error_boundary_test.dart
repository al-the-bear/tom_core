/// Behavioural coverage for `TomErrorBoundary`.
///
/// The boundary's substance is not the fallback card — it is the *routing*.
/// `ErrorWidget.builder` is a single global slot, so the naive implementation
/// ("the boundary that installed the hook handles the error") sends every error
/// to whichever boundary mounted last. In a list of rows, each with its own
/// boundary, that is the difference between one broken row and a broken list.
/// The nested tests below are the ones that would catch a regression there.
///
/// The second non-obvious behaviour is the ref-counted hook: the *first*
/// boundary to mount saves the previous `ErrorWidget.builder` and the *last* to
/// unmount restores it. Getting this wrong leaks a test-local error widget into
/// every later test in the process, which is the kind of failure that shows up
/// somewhere else entirely.
///
/// Note on `tester.takeException()`: the framework still reports the original
/// exception even though the boundary renders a fallback — catching it is the
/// boundary's job, *silencing* it is not. Each throwing test therefore drains
/// the recorded exception explicitly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// A widget whose build always throws.
class _Boom extends StatelessWidget {
  const _Boom({this.message = 'boom'});

  final String message;

  @override
  Widget build(BuildContext context) => throw StateError(message);
}

/// A widget that throws while [fail] is true — lets a test flip the underlying
/// condition and then exercise `retry`.
class _Flaky extends StatelessWidget {
  const _Flaky(this.fail);

  final ValueNotifier<bool> fail;

  @override
  Widget build(BuildContext context) {
    if (fail.value) throw StateError('boom');
    return const Text('recovered');
  }
}

/// Drains the frames a caught error needs before the fallback is on screen.
///
/// The path is deliberately deferred twice — the reporter waits a frame before
/// looking up its boundary, and the boundary waits another before calling
/// `setState` — so a fixed `pump()` count is brittle. Settling is the honest
/// way to say "once everything the error scheduled has run".
Future<void> _settleError(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  // -------------------------------------------------------------------------
  group('TomErrorBoundary happy path', () {
    testWidgets('renders the child untouched', (tester) async {
      await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('safe'))));

      expect(find.text('safe'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('does not invoke onError', (tester) async {
      var calls = 0;

      await tester.pumpWidget(_app(TomErrorBoundary(
        onError: (_) => calls++,
        child: const Text('safe'),
      )));

      expect(calls, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('TomErrorBoundary catching', () {
    testWidgets('a throwing child is replaced by the default fallback',
        (tester) async {
      await tester.pumpWidget(_app(const TomErrorBoundary(child: _Boom())));
      await _settleError(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget,
          reason: 'the exception text is shown, not swallowed');
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      tester.takeException();
    });

    testWidgets('onError receives the details', (tester) async {
      FlutterErrorDetails? seen;

      await tester.pumpWidget(_app(TomErrorBoundary(
        onError: (d) => seen = d,
        child: const _Boom(message: 'kaboom'),
      )));
      await _settleError(tester);

      expect(seen, isNotNull);
      expect(seen!.exception, isStateError);
      expect(seen!.exceptionAsString(), contains('kaboom'));
      tester.takeException();
    });

    testWidgets('a custom fallback replaces the default card', (tester) async {
      await tester.pumpWidget(_app(TomErrorBoundary(
        fallbackBuilder: (context, details, retry) => Text(
          'custom:${details.exceptionAsString().contains('boom')}',
        ),
        child: const _Boom(),
      )));
      await _settleError(tester);

      expect(find.text('custom:true'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
      tester.takeException();
    });
  });

  // -------------------------------------------------------------------------
  group('TomErrorBoundary retry', () {
    testWidgets('re-attempts the build and recovers', (tester) async {
      final fail = ValueNotifier(true);
      await tester.pumpWidget(_app(TomErrorBoundary(child: _Flaky(fail))));
      await _settleError(tester);
      expect(find.text('Something went wrong'), findsOneWidget);
      tester.takeException();

      fail.value = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('recovered'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
      fail.dispose();
    });

    testWidgets('a retry into a still-broken child falls back again',
        (tester) async {
      final fail = ValueNotifier(true);
      await tester.pumpWidget(_app(TomErrorBoundary(child: _Flaky(fail))));
      await _settleError(tester);
      tester.takeException();

      await tester.tap(find.text('Retry'));
      await _settleError(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      while (tester.takeException() != null) {}
      fail.dispose();
    });

    testWidgets('the custom fallback gets a working retry', (tester) async {
      final fail = ValueNotifier(true);
      await tester.pumpWidget(_app(TomErrorBoundary(
        fallbackBuilder: (context, details, retry) =>
            TextButton(onPressed: retry, child: const Text('again')),
        child: _Flaky(fail),
      )));
      await _settleError(tester);
      tester.takeException();

      fail.value = false;
      await tester.tap(find.text('again'));
      await tester.pumpAndSettle();

      expect(find.text('recovered'), findsOneWidget);
      fail.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('TomErrorBoundary nesting', () {
    testWidgets('the error reaches the innermost boundary', (tester) async {
      // The whole reason the reporter walks the element tree instead of
      // relying on "whoever owns the global hook".
      final outerErrors = <FlutterErrorDetails>[];
      final innerErrors = <FlutterErrorDetails>[];

      await tester.pumpWidget(_app(TomErrorBoundary(
        onError: outerErrors.add,
        fallbackBuilder: (_, _, _) => const Text('outer-fallback'),
        child: Column(children: [
          const Text('outer-ok'),
          TomErrorBoundary(
            onError: innerErrors.add,
            fallbackBuilder: (_, _, _) => const Text('inner-fallback'),
            child: const _Boom(),
          ),
        ]),
      )));
      await _settleError(tester);

      expect(innerErrors, hasLength(1));
      expect(outerErrors, isEmpty);
      expect(find.text('inner-fallback'), findsOneWidget);
      expect(find.text('outer-fallback'), findsNothing);
      tester.takeException();
    });

    testWidgets('the surviving siblings keep rendering', (tester) async {
      await tester.pumpWidget(_app(TomErrorBoundary(
        child: Column(children: [
          const Text('outer-ok'),
          TomErrorBoundary(
            fallbackBuilder: (_, _, _) => const Text('inner-fallback'),
            child: const _Boom(),
          ),
        ]),
      )));
      await _settleError(tester);

      expect(find.text('outer-ok'), findsOneWidget,
          reason: 'containment: one broken row does not take the list with it');
      tester.takeException();
    });

    testWidgets('two sibling boundaries are contained independently',
        (tester) async {
      await tester.pumpWidget(_app(Column(children: [
        TomErrorBoundary(
          fallbackBuilder: (_, _, _) => const Text('first-fallback'),
          child: const _Boom(),
        ),
        const TomErrorBoundary(child: Text('second-ok')),
      ])));
      await _settleError(tester);

      expect(find.text('first-fallback'), findsOneWidget);
      expect(find.text('second-ok'), findsOneWidget);
      tester.takeException();
    });
  });

  // -------------------------------------------------------------------------
  group('TomErrorBoundary global hook', () {
    testWidgets('installs on mount and restores on unmount', (tester) async {
      final original = ErrorWidget.builder;

      await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('a'))));
      expect(ErrorWidget.builder, isNot(same(original)));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(ErrorWidget.builder, same(original),
          reason: 'the last boundary out restores what the first one found');
    });

    testWidgets('the inner boundary mounting does not stomp the saved builder',
        (tester) async {
      // Ref-counting, not last-writer-wins: an inner boundary mounting and
      // unmounting must leave the original builder recoverable.
      final original = ErrorWidget.builder;

      await tester.pumpWidget(_app(const TomErrorBoundary(
        child: TomErrorBoundary(child: Text('nested')),
      )));
      await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('a'))));
      expect(ErrorWidget.builder, isNot(same(original)));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(ErrorWidget.builder, same(original));
    });
  });
}
