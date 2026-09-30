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

/// A fallback that can be named from a `const` constructor.
Widget _namedFallback(
  BuildContext context,
  FlutterErrorDetails details,
  VoidCallback retry,
) => const Text('fallback');

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
      await tester.pumpWidget(
        _app(const TomErrorBoundary(child: Text('safe'))),
      );

      expect(find.text('safe'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('does not invoke onError', (tester) async {
      var calls = 0;

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(onError: (_) => calls++, child: const Text('safe')),
        ),
      );

      expect(calls, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('TomErrorBoundary catching', () {
    testWidgets('a throwing child is replaced by the default fallback', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TomErrorBoundary(child: _Boom())));
      await _settleError(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.textContaining('boom'),
        findsOneWidget,
        reason: 'the exception text is shown, not swallowed',
      );
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      tester.takeException();
    });

    testWidgets('onError receives the details', (tester) async {
      FlutterErrorDetails? seen;

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            onError: (d) => seen = d,
            child: const _Boom(message: 'kaboom'),
          ),
        ),
      );
      await _settleError(tester);

      expect(seen, isNotNull);
      expect(seen!.exception, isStateError);
      expect(seen!.exceptionAsString(), contains('kaboom'));
      tester.takeException();
    });

    testWidgets('a custom fallback replaces the default card', (tester) async {
      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            fallbackBuilder: (context, details, retry) =>
                Text('custom:${details.exceptionAsString().contains('boom')}'),
            child: const _Boom(),
          ),
        ),
      );
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

    testWidgets('a retry into a still-broken child falls back again', (
      tester,
    ) async {
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
      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            fallbackBuilder: (context, details, retry) =>
                TextButton(onPressed: retry, child: const Text('again')),
            child: _Flaky(fail),
          ),
        ),
      );
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

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            onError: outerErrors.add,
            fallbackBuilder: (_, _, _) => const Text('outer-fallback'),
            child: Column(
              children: [
                const Text('outer-ok'),
                TomErrorBoundary(
                  onError: innerErrors.add,
                  fallbackBuilder: (_, _, _) => const Text('inner-fallback'),
                  child: const _Boom(),
                ),
              ],
            ),
          ),
        ),
      );
      await _settleError(tester);

      expect(innerErrors, hasLength(1));
      expect(outerErrors, isEmpty);
      expect(find.text('inner-fallback'), findsOneWidget);
      expect(find.text('outer-fallback'), findsNothing);
      tester.takeException();
    });

    testWidgets('the surviving siblings keep rendering', (tester) async {
      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            child: Column(
              children: [
                const Text('outer-ok'),
                TomErrorBoundary(
                  fallbackBuilder: (_, _, _) => const Text('inner-fallback'),
                  child: const _Boom(),
                ),
              ],
            ),
          ),
        ),
      );
      await _settleError(tester);

      expect(
        find.text('outer-ok'),
        findsOneWidget,
        reason: 'containment: one broken row does not take the list with it',
      );
      tester.takeException();
    });

    testWidgets('two sibling boundaries are contained independently', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              TomErrorBoundary(
                fallbackBuilder: (_, _, _) => const Text('first-fallback'),
                child: const _Boom(),
              ),
              const TomErrorBoundary(child: Text('second-ok')),
            ],
          ),
        ),
      );
      await _settleError(tester);

      expect(find.text('first-fallback'), findsOneWidget);
      expect(find.text('second-ok'), findsOneWidget);
      tester.takeException();
    });
  });

  // -------------------------------------------------------------------------
  group('an error outside every boundary is not the boundary\'s to eat', () {
    /// Runs [body] with a recognisable builder in the global slot, and puts
    /// the slot back before returning.
    ///
    /// The installed builder stands in for the application's own error widget
    /// — in a real process that is Flutter's red box in debug, or a crash
    /// reporter's hook in release. What matters is that it is *not* ours, and
    /// that a mounted boundary must leave it in charge of everything it does
    /// not guard.
    ///
    /// Restoring cannot wait for `addTearDown`: `flutter_test` asserts the
    /// slot is unchanged when the test *body* ends, which is before teardowns
    /// run. The tree is emptied first so the boundary's own `dispose` puts
    /// back what it found — this builder — and only then is the original put
    /// back over it.
    Future<void> withAppErrorWidget(
      WidgetTester tester,
      Future<void> Function(List<FlutterErrorDetails> seen) body,
    ) async {
      final seen = <FlutterErrorDetails>[];
      final original = ErrorWidget.builder;
      ErrorWidget.builder = (details) {
        seen.add(details);
        return const Text('app-error-widget', textDirection: TextDirection.ltr);
      };
      try {
        await body(seen);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        ErrorWidget.builder = original;
      }
    }

    testWidgets('a throwing sibling of a boundary reaches the app\'s own '
        'error widget', (tester) async {
      // The defect this group exists for: one mounted boundary anywhere turned
      // every unguarded build error in the process into a blank space — no red
      // box in debug, and in release nothing the application installed.
      await withAppErrorWidget(tester, (seen) async {
        await tester.pumpWidget(
          _app(
            const Column(
              children: [
                TomErrorBoundary(child: Text('guarded')),
                _Boom(message: 'unguarded'),
              ],
            ),
          ),
        );
        await _settleError(tester);

        expect(
          find.text('app-error-widget'),
          findsOneWidget,
          reason:
              'the slot the boundary took belongs to the application for every '
              'error the boundary does not guard',
        );
        expect(seen, hasLength(1));
        expect(seen.single.exception.toString(), contains('unguarded'));
        tester.takeException();
      });
    });

    testWidgets('the guarded subtree still reaches its own boundary', (
      tester,
    ) async {
      // The control. Without it the case above is satisfied by a boundary that
      // forwards everything and guards nothing.
      final caught = <FlutterErrorDetails>[];
      await withAppErrorWidget(tester, (seen) async {
        await tester.pumpWidget(
          _app(
            TomErrorBoundary(
              onError: caught.add,
              fallbackBuilder: (_, _, _) => const Text('fallback'),
              child: const _Boom(message: 'guarded'),
            ),
          ),
        );
        await _settleError(tester);

        expect(find.text('fallback'), findsOneWidget);
        expect(caught, hasLength(1));
        expect(
          seen,
          isEmpty,
          reason: 'a guarded error must not also reach the application widget',
        );
        tester.takeException();
      });
    });

    testWidgets('both at once, each to its own handler', (tester) async {
      // The two paths in one tree, which is the arrangement a real application
      // is in: some of it guarded, most of it not.
      final caught = <FlutterErrorDetails>[];
      await withAppErrorWidget(tester, (seen) async {
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                TomErrorBoundary(
                  onError: caught.add,
                  fallbackBuilder: (_, _, _) => const Text('fallback'),
                  child: const _Boom(message: 'guarded'),
                ),
                const _Boom(message: 'unguarded'),
              ],
            ),
          ),
        );
        await _settleError(tester);

        expect(find.text('fallback'), findsOneWidget);
        expect(find.text('app-error-widget'), findsOneWidget);
        expect(caught.single.exception.toString(), contains('guarded'));
        expect(seen.single.exception.toString(), contains('unguarded'));
        while (tester.takeException() != null) {}
      });
    });

    testWidgets('a boundary reports its error once, not once per rebuild', (
      tester,
    ) async {
      // The lookup moved into `build` to answer whose error it is while the
      // slot is being built, which raises the question this case settles:
      // `onError` is documented as firing once per caught error, and `build`
      // is a place that can run more than once.
      //
      // It holds, and deliberately without a guard added to make it hold: an
      // explicit "already reported" flag was written, found to be unkillable
      // by mutation, and removed. This case is what says the property is a
      // fact about the widget rather than about that flag.
      final caught = <FlutterErrorDetails>[];
      final rebuild = ValueNotifier<int>(0);
      addTearDown(rebuild.dispose);

      await withAppErrorWidget(tester, (_) async {
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<int>(
              valueListenable: rebuild,
              builder: (_, _, _) => TomErrorBoundary(
                onError: caught.add,
                fallbackBuilder: (_, _, _) => const Text('fallback'),
                child: const _Boom(),
              ),
            ),
          ),
        );
        rebuild.value = 1;
        await tester.pump();
        await _settleError(tester);

        expect(caught, hasLength(1));
        while (tester.takeException() != null) {}
      });
    });
  });

  group('a boundary keeps guarding after it has captured', () {
    testWidgets('the hook is still installed once a lone boundary has caught', (
      tester,
    ) async {
      // The hook used to belong to a host the boundary rendered only while it
      // had caught nothing, so catching unmounted the host and — for a lone
      // boundary — put the previous builder straight back. Guarding is a
      // property of being in the tree, not of currently looking untroubled.
      final original = ErrorWidget.builder;

      await tester.pumpWidget(
        _app(
          const TomErrorBoundary(
            fallbackBuilder: _namedFallback,
            child: _Boom(),
          ),
        ),
      );
      await _settleError(tester);
      expect(find.text('fallback'), findsOneWidget, reason: 'it did catch');

      expect(
        ErrorWidget.builder,
        isNot(same(original)),
        reason: 'a boundary showing its fallback is still a boundary',
      );

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(
        ErrorWidget.builder,
        same(original),
        reason: 'and it still releases the slot when it leaves',
      );
      tester.takeException();
    });

    testWidgets('a throwing fallbackBuilder is caught by its own boundary', (
      tester,
    ) async {
      // The consequence that bites: `fallbackBuilder` is caller code and can
      // throw, and a boundary that stopped guarding the moment it caught could
      // not catch its own fallback — the error would land outside every
      // boundary and be handed to the application's error widget instead.
      final caught = <FlutterErrorDetails>[];

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            onError: caught.add,
            fallbackBuilder: (context, details, retry) =>
                throw StateError('from-the-fallback'),
            child: const _Boom(message: 'first'),
          ),
        ),
      );
      await _settleError(tester);

      expect(caught, hasLength(2));
      expect(caught.first.exception.toString(), contains('first'));
      expect(
        caught.last.exception.toString(),
        contains('from-the-fallback'),
        reason:
            'the boundary is still the nearest enclosing one for its own '
            'fallback, which is only true while it still owns the hook',
      );
      while (tester.takeException() != null) {}
    });

    testWidgets('a throwing fallbackBuilder falls back to the default card, '
        'with the original error, and settles', (tester) async {
      // The boundary caught its fallback's error and used to render nothing:
      // the swap was deferred to a post-frame callback registered from inside
      // a post-frame callback, and with the tree otherwise idle no frame ever
      // ran it. Scheduling frames would not have fixed it — a fallback that
      // always throws would rebuild forever. The boundary falls back to its
      // own card instead, which cannot throw for a caller's reason, so it
      // settles.
      final caught = <FlutterErrorDetails>[];

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            onError: caught.add,
            fallbackBuilder: (context, details, retry) =>
                throw StateError('from-the-fallback'),
            child: const _Boom(message: 'first'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.textContaining('first'),
        findsOneWidget,
        reason:
            'the card reports the error the user ran into, not the '
            "fallback's",
      );
      expect(caught, hasLength(2), reason: 'once for each failure, no more');
      expect(tester.binding.hasScheduledFrame, isFalse);
      while (tester.takeException() != null) {}
    });

    testWidgets('retry from the default card gives the fallbackBuilder a new '
        'chance, and settles again', (tester) async {
      final caught = <FlutterErrorDetails>[];

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            onError: caught.add,
            fallbackBuilder: (context, details, retry) =>
                throw StateError('from-the-fallback'),
            child: const _Boom(message: 'first'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(caught, hasLength(4));
      while (tester.takeException() != null) {}
    });

    testWidgets('when the default card fails too, the error goes to the '
        'builder installed before any boundary', (tester) async {
      // The last step: nothing is left to fall back to, so the boundary steps
      // aside and the error widget the app would have had without it renders
      // the card's failure. The real card cannot fail for a caller's reason,
      // so the test replaces it with one that does.
      TomErrorBoundary.debugDefaultFallback = (context, details, retry) =>
          throw StateError('from-the-default');
      addTearDown(() => TomErrorBoundary.debugDefaultFallback = null);
      final caught = <FlutterErrorDetails>[];

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            onError: caught.add,
            fallbackBuilder: (context, details, retry) =>
                throw StateError('from-the-fallback'),
            child: const _Boom(message: 'first'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorWidget), findsOneWidget);
      expect(
        caught.map((c) => c.exception.toString()),
        [
          contains('first'),
          contains('from-the-fallback'),
          contains('from-the-default'),
        ],
        reason: 'once per stage, then it stops',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      while (tester.takeException() != null) {}
    });

    testWidgets('the last healthy row failing is still caught', (tester) async {
      // A list of guarded rows: the count fell with every row that failed, so
      // the hook survived only while one row was still healthy. Which error
      // the last one was decided whether it was caught at all.
      final fallbacks = <int>[];

      await tester.pumpWidget(
        _app(
          Column(
            children: [
              for (var i = 0; i < 3; i++)
                TomErrorBoundary(
                  fallbackBuilder: (_, _, _) {
                    fallbacks.add(i);
                    return Text('row-$i-fallback');
                  },
                  child: _Boom(message: 'row-$i'),
                ),
            ],
          ),
        ),
      );
      await _settleError(tester);

      for (var i = 0; i < 3; i++) {
        expect(
          find.text('row-$i-fallback'),
          findsOneWidget,
          reason: 'every row must be contained, including the last to fail',
        );
      }
      while (tester.takeException() != null) {}
    });

    testWidgets('a retry re-guards without reinstalling anything', (
      tester,
    ) async {
      // The other direction across the same seam: recovering must not install
      // a second hook or lose the saved builder, since the count never moved.
      final original = ErrorWidget.builder;
      final fail = ValueNotifier<bool>(true);
      addTearDown(fail.dispose);

      await tester.pumpWidget(
        _app(
          TomErrorBoundary(
            fallbackBuilder: (_, _, retry) =>
                TextButton(onPressed: retry, child: const Text('retry')),
            child: _Flaky(fail),
          ),
        ),
      );
      await _settleError(tester);

      final withFallback = ErrorWidget.builder;
      fail.value = false;
      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();

      expect(find.text('recovered'), findsOneWidget);
      expect(
        ErrorWidget.builder,
        same(withFallback),
        reason: 'recovering is not a remount; the slot does not change hands',
      );

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(ErrorWidget.builder, same(original));
      tester.takeException();
    });
  });

  group('the hook state can be put back', () {
    // The state behind the slot is process-wide, because the slot is. A
    // boundary whose `dispose` never runs — a test that tears down its
    // binding, or one that pumps a boundary and abandons the tree — used to
    // pin the count above zero for the rest of the process, so every test
    // after it inherited an error widget belonging to a widget that was gone.
    // Nothing could reach the two library variables to undo it.

    testWidgets('a leaked boundary no longer pins the slot', (tester) async {
      final original = ErrorWidget.builder;

      // Mount a boundary and leave without unmounting it — the count is
      // incremented and, as far as the library is concerned, still is.
      await tester.pumpWidget(
        _app(const TomErrorBoundary(key: ValueKey('a'), child: Text('a'))),
      );
      expect(ErrorWidget.builder, isNot(same(original)));

      TomErrorBoundary.debugReleaseGlobalHook();
      expect(
        ErrorWidget.builder,
        same(original),
        reason: 'the slot goes back to whoever held it',
      );

      // And the count is forgotten: a *fresh* boundary installs again, saving
      // the builder that is there now rather than believing one is already
      // saved. The key forces a new element — without it the framework reuses
      // the one already mounted, `initState` never runs, and this would test
      // nothing at all.
      await tester.pumpWidget(
        _app(const TomErrorBoundary(key: ValueKey('b'), child: Text('b'))),
      );
      expect(ErrorWidget.builder, isNot(same(original)));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(ErrorWidget.builder, same(original));
    });

    testWidgets('the still-mounted boundary\'s own dispose stays harmless', (
      tester,
    ) async {
      // The case the reset creates: it zeroes a count that mounted boundaries
      // still believe they hold a share of, so their `dispose` arrives with
      // nothing left to release. It must not put back a builder it no longer
      // has, and it must not drive the count negative — which the next
      // boundary would read as "already installed".
      final original = ErrorWidget.builder;

      await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('a'))));
      TomErrorBoundary.debugReleaseGlobalHook();
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(ErrorWidget.builder, same(original));

      await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('b'))));
      expect(
        ErrorWidget.builder,
        isNot(same(original)),
        reason: 'a negative count would have skipped the install',
      );
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(ErrorWidget.builder, same(original));
    });

    test('releasing when nothing is installed changes nothing', () {
      final original = ErrorWidget.builder;
      TomErrorBoundary.debugReleaseGlobalHook();
      TomErrorBoundary.debugReleaseGlobalHook();
      expect(ErrorWidget.builder, same(original));
    });
  });

  group('TomErrorBoundary global hook', () {
    testWidgets('installs on mount and restores on unmount', (tester) async {
      final original = ErrorWidget.builder;

      await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('a'))));
      expect(ErrorWidget.builder, isNot(same(original)));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      expect(
        ErrorWidget.builder,
        same(original),
        reason: 'the last boundary out restores what the first one found',
      );
    });

    testWidgets(
      'the inner boundary mounting does not stomp the saved builder',
      (tester) async {
        // Ref-counting, not last-writer-wins: an inner boundary mounting and
        // unmounting must leave the original builder recoverable.
        final original = ErrorWidget.builder;

        await tester.pumpWidget(
          _app(
            const TomErrorBoundary(
              child: TomErrorBoundary(child: Text('nested')),
            ),
          ),
        );
        await tester.pumpWidget(_app(const TomErrorBoundary(child: Text('a'))));
        expect(ErrorWidget.builder, isNot(same(original)));

        await tester.pumpWidget(_app(const SizedBox.shrink()));
        expect(ErrorWidget.builder, same(original));
      },
    );
  });
}
