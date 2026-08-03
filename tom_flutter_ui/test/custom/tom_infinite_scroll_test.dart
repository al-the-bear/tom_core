/// Behavioural coverage for `TomInfiniteScroll`.
///
/// Almost everything interesting here is about *when the fetcher is called*,
/// not about what is painted. Three rules carry the risk:
///
///   * **Exhaustion is inferred, not declared.** A page shorter than
///     `pageSize` is the end of the source. If that inference broke, a list
///     scrolled to the bottom would re-request the same empty page on every
///     scroll notification — a silent request loop against the backend, with
///     nothing visibly wrong on screen.
///
///   * **A fetch in flight suppresses the next one.** The scroll listener
///     fires many times per drag; without the `_pending` gate each drag would
///     issue a burst of duplicate page requests.
///
///   * **An error latches.** Once a page fails, auto-fetching stops until the
///     user retries — otherwise the failing request repeats on every scroll.
///
/// The fetcher below therefore records every `(page, pageSize)` it is handed,
/// and the assertions are mostly about that call log.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// A paged source that records its calls and can be held open or made to fail.
class _Source {
  _Source({this.total = 25, this.failFrom});

  /// Items available in total; pages beyond it come back short or empty.
  final int total;

  /// First page index that throws, or `null` for a source that never fails.
  final int? failFrom;

  /// One entry per call, as `(page, pageSize)`.
  final List<(int, int)> calls = [];

  /// While non-null, fetches block on this until it is completed.
  Completer<void>? gate;

  int get callCount => calls.length;

  Future<List<int>> fetch(int page, int pageSize) async {
    calls.add((page, pageSize));
    if (failFrom != null && page >= failFrom!) {
      throw StateError('page $page unavailable');
    }
    final gate = this.gate;
    if (gate != null) await gate.future;
    final start = page * pageSize;
    if (start >= total) return const [];
    final end = start + pageSize > total ? total : start + pageSize;
    return [for (var i = start; i < end; i++) i];
  }
}

const double _tileHeight = 50;
const double _viewportHeight = 200;

Widget _tile(BuildContext _, int item, int index) => SizedBox(
      height: _tileHeight,
      child: Text('item-$item'),
    );

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: _viewportHeight,
            child: child,
          ),
        ),
      ),
    );

/// Scrolls the list to its very bottom, which is what arms `_maybeFetch`.
Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -2000));
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  group('TomInfiniteScroll initial load', () {
    testWidgets('shows the skeleton while the first page is in flight',
        (tester) async {
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pump(); // let the post-frame fetch start

      expect(find.byType(TomSkeletonLoader), findsWidgets);
      expect(find.textContaining('item-'), findsNothing);

      source.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TomSkeletonLoader), findsNothing);
    });

    testWidgets('a custom skeleton replaces the default', (tester) async {
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
        skeletonBuilder: (_) => const Text('loading…'),
      )));
      await tester.pump();

      expect(find.text('loading…'), findsOneWidget);
      expect(find.byType(TomSkeletonLoader), findsNothing);

      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('requests page 0 at the configured page size', (tester) async {
      final source = _Source();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 7,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expect(source.calls, [(0, 7)]);
    });

    testWidgets('renders the first page', (tester) async {
      final source = _Source();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expect(find.text('item-0'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll empty source', () {
    testWidgets('falls back to the default empty state', (tester) async {
      final source = _Source(total: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(TomEmptyState), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('a custom empty builder replaces it', (tester) async {
      final source = _Source(total: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
        emptyBuilder: (_) => const Text('nothing here'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('nothing here'), findsOneWidget);
      expect(find.byType(TomEmptyState), findsNothing);
    });

    testWidgets('an empty first page also exhausts the source', (tester) async {
      // Zero items is fewer than `pageSize`, so nothing further is requested.
      final source = _Source(total: 0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expect(key.currentState!.isExhausted, isTrue);
      expect(source.callCount, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll pagination', () {
    testWidgets('reaching the bottom asks for the next page', (tester) async {
      final source = _Source(total: 25);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      expect(source.calls, [(0, 10)]);

      await _scrollToBottom(tester);

      expect(source.calls.first, (0, 10));
      expect(source.calls, contains((1, 10)));
    });

    testWidgets('the second page is appended, not replaced', (tester) async {
      final source = _Source(total: 25);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      expect(key.currentState!.loadedCount, 10);

      await _scrollToBottom(tester);

      expect(key.currentState!.loadedCount, 20);
    });

    testWidgets('a fetch in flight suppresses a second request',
        (tester) async {
      final source = _Source(total: 100);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      source.gate = Completer<void>();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      final duringFirstDrag = source.callCount;
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      expect(source.callCount, duringFirstDrag,
          reason: 'the pending gate absorbs every further scroll notification');
      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a short page ends the source', (tester) async {
      final source = _Source(total: 15);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(key.currentState!.isExhausted, isTrue);

      final callsAtEnd = source.callCount;
      await _scrollToBottom(tester);

      expect(source.callCount, callsAtEnd,
          reason: 'an exhausted source is never polled again');
    });

    testWidgets('a full last page still stops at the empty page that follows',
        (tester) async {
      // 20 items at a page size of 10 means page 1 is *full*, so exhaustion is
      // only discovered by page 2 coming back empty.
      final source = _Source(total: 20);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(key.currentState!.isExhausted, isFalse);

      await _scrollToBottom(tester);

      expect(source.calls, contains((2, 10)));
      expect(key.currentState!.isExhausted, isTrue);
      expect(key.currentState!.loadedCount, 20);
    });

    testWidgets('a trailing spinner marks the load-more state', (tester) async {
      final source = _Source(total: 100);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      source.gate = Completer<void>();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      // The tile is appended the moment the fetch starts, but it sits *below*
      // the last loaded item — which is exactly where the viewport bottom was
      // before it appeared. So it is built and off-stage, and only a further
      // scroll brings it on screen. Both halves are asserted: the tile exists,
      // and scrolling the last stretch reveals it.
      expect(find.byType(CircularProgressIndicator, skipOffstage: false),
          findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(source.calls, hasLength(2),
          reason: 'the extra drag does not stack a second request');

      source.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator, skipOffstage: false),
          findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll errors', () {
    testWidgets('a failing first page shows the default error slot',
        (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
      expect(find.textContaining('page 0 unavailable'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('a custom error builder replaces it', (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
        errorBuilder: (_, error, retry) => TextButton(
          onPressed: retry,
          child: Text('boom: $error'),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('boom:'), findsOneWidget);
      expect(find.textContaining('Failed to load'), findsNothing);
    });

    testWidgets('the error latches until the user retries', (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      final callsAfterFailure = source.callCount;

      await tester.pump(const Duration(seconds: 1));

      expect(source.callCount, callsAfterFailure,
          reason: 'a latched error stops the auto-fetch loop');
    });

    testWidgets('Retry re-issues the same page', (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(source.calls, [(0, 10), (0, 10)],
          reason: 'the failed page is retried, not skipped');
    });

    testWidgets('a mid-list failure keeps the loaded items reachable',
        (tester) async {
      // The error slot replaces the whole list, so the retry has to bring the
      // already-loaded items back rather than start from nothing.
      final source = _Source(total: 100, failFrom: 1);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(find.textContaining('Failed to load'), findsOneWidget);

      expect(key.currentState!.loadedCount, 10,
          reason: 'the first page is still held, only hidden');
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll state and refresh', () {
    testWidgets('exposes loaded / pending / exhausted', (tester) async {
      final source = _Source(total: 15)..gate = Completer<void>();
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pump();
      expect(key.currentState!.isPending, isTrue);
      expect(key.currentState!.loadedCount, 0);

      source.gate!.complete();
      await tester.pumpAndSettle();

      expect(key.currentState!.isPending, isFalse);
      expect(key.currentState!.loadedCount, 10);
      expect(key.currentState!.isExhausted, isFalse);
    });

    testWidgets('refresh restarts from page 0', (tester) async {
      final source = _Source(total: 25);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(key.currentState!.loadedCount, 20);

      await key.currentState!.refresh();
      await tester.pumpAndSettle();

      expect(key.currentState!.loadedCount, 10);
      expect(source.calls.last, (0, 10));
    });

    testWidgets('refresh clears a latched error', (tester) async {
      final source = _Source(failFrom: 0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Failed to load'), findsOneWidget);

      await key.currentState!.refresh();
      await tester.pumpAndSettle();

      expect(source.calls, hasLength(2),
          reason: 'refresh re-attempts rather than staying latched');
    });

    testWidgets('padding reaches the inner list', (tester) async {
      final source = _Source(total: 25);
      const padding = EdgeInsets.all(9);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
        padding: padding,
      )));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        padding,
      );
    });

    testWidgets('a fetch completing after dispose is dropped', (tester) async {
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pump();

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      source.gate!.complete();

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'no setState after dispose');
    });
  });
}
