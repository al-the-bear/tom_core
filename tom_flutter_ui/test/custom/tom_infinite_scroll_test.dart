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
  ///
  /// Mutable so a case can make the source healthy between a failure and the
  /// retry or refresh that is supposed to clear it — otherwise "the error
  /// cleared" and "the error was replaced by the same error" look alike.
  int? failFrom;

  /// One entry per call, as `(page, pageSize)`.
  final List<(int, int)> calls = [];

  /// While non-null, fetches block on this until it is completed.
  Completer<void>? gate;

  int get callCount => calls.length;

  /// Call indices that throw, by position in [calls] rather than by page.
  ///
  /// Two requests for the same page can be parked on one gate — a refresh over
  /// an in-flight page 0 produces exactly that — and telling them apart is the
  /// only way to let the abandoned one fail while the one that replaced it
  /// succeeds.
  final Set<int> failCalls = {};

  Future<List<int>> fetch(int page, int pageSize) async {
    final index = calls.length;
    calls.add((page, pageSize));
    // The gate comes first, so a failing page can also be held open. A
    // failure that throws before the caller has a chance to do anything else
    // is a different case from one that arrives late, and only the late one
    // can test what happens to a result nobody wants any more.
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (failCalls.contains(index) || (failFrom != null && page >= failFrom!)) {
      throw StateError('page $page unavailable');
    }
    final start = page * pageSize;
    if (start >= total) return const [];
    final end = start + pageSize > total ? total : start + pageSize;
    return [for (var i = start; i < end; i++) i];
  }
}

const double _tileHeight = 50;
const double _viewportHeight = 200;

Widget _tile(BuildContext _, int item, int index) =>
    SizedBox(height: _tileHeight, child: Text('item-$item'));

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 300, height: _viewportHeight, child: child),
    ),
  ),
);

/// Scrolls the list to its very bottom, which is what arms `_maybeFetch`.
Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -2000));
  await tester.pumpAndSettle();
}

/// Scrolls to the bottom, then again, so a tile the first scroll *caused* is
/// on screen.
///
/// A failed page appends a report tile below the rows, which only exists once
/// the fetch the first scroll triggered has rejected. One drag leaves it just
/// past the viewport.
Future<void> _scrollToTrailingTile(WidgetTester tester) async {
  await _scrollToBottom(tester);
  await _scrollToBottom(tester);
}

void main() {
  // -------------------------------------------------------------------------
  group('TomInfiniteScroll initial load', () {
    testWidgets('shows the skeleton while the first page is in flight', (
      tester,
    ) async {
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump(); // let the post-frame fetch start

      expect(find.byType(TomSkeletonLoader), findsWidgets);
      expect(find.textContaining('item-'), findsNothing);

      source.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TomSkeletonLoader), findsNothing);
    });

    testWidgets('a custom skeleton replaces the default', (tester) async {
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
            skeletonBuilder: (_) => const Text('loading…'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('loading…'), findsOneWidget);
      expect(find.byType(TomSkeletonLoader), findsNothing);

      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('requests page 0 at the configured page size', (tester) async {
      final source = _Source();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 7,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(source.calls, [(0, 7)]);
    });

    testWidgets('renders the first page', (tester) async {
      final source = _Source();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('item-0'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll empty source', () {
    testWidgets('falls back to the default empty state', (tester) async {
      final source = _Source(total: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TomEmptyState), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('a custom empty builder replaces it', (tester) async {
      final source = _Source(total: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
            emptyBuilder: (_) => const Text('nothing here'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('nothing here'), findsOneWidget);
      expect(find.byType(TomEmptyState), findsNothing);
    });

    testWidgets('an empty first page also exhausts the source', (tester) async {
      // Zero items is fewer than `pageSize`, so nothing further is requested.
      final source = _Source(total: 0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.isExhausted, isTrue);
      expect(source.callCount, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll pagination', () {
    testWidgets('reaching the bottom asks for the next page', (tester) async {
      final source = _Source(total: 25);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.calls, [(0, 10)]);

      await _scrollToBottom(tester);

      expect(source.calls.first, (0, 10));
      expect(source.calls, contains((1, 10)));
    });

    testWidgets('the second page is appended, not replaced', (tester) async {
      final source = _Source(total: 25);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.loadedCount, 10);

      await _scrollToBottom(tester);

      expect(key.currentState!.loadedCount, 20);
    });

    testWidgets('a fetch in flight suppresses a second request', (
      tester,
    ) async {
      final source = _Source(total: 100);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      source.gate = Completer<void>();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      final duringFirstDrag = source.callCount;
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      expect(
        source.callCount,
        duringFirstDrag,
        reason: 'the pending gate absorbs every further scroll notification',
      );
      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a short page ends the source', (tester) async {
      final source = _Source(total: 15);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(key.currentState!.isExhausted, isTrue);

      final callsAtEnd = source.callCount;
      await _scrollToBottom(tester);

      expect(
        source.callCount,
        callsAtEnd,
        reason: 'an exhausted source is never polled again',
      );
    });

    testWidgets('a full last page still stops at the empty page that follows', (
      tester,
    ) async {
      // 20 items at a page size of 10 means page 1 is *full*, so exhaustion is
      // only discovered by page 2 coming back empty.
      final source = _Source(total: 20);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
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

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      source.gate = Completer<void>();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();

      // The tile is appended the moment the fetch starts, but it sits *below*
      // the last loaded item — which is exactly where the viewport bottom was
      // before it appeared. So it is built and off-stage, and only a further
      // scroll brings it on screen. Both halves are asserted: the tile exists,
      // and scrolling the last stretch reveals it.
      expect(
        find.byType(CircularProgressIndicator, skipOffstage: false),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        source.calls,
        hasLength(2),
        reason: 'the extra drag does not stack a second request',
      );

      source.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.byType(CircularProgressIndicator, skipOffstage: false),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll errors', () {
    testWidgets('a failing first page shows the default error slot', (
      tester,
    ) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
      expect(find.textContaining('page 0 unavailable'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('a custom error builder replaces it', (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
            errorBuilder: (_, error, retry, _) =>
                TextButton(onPressed: retry, child: Text('boom: $error')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('boom:'), findsOneWidget);
      expect(find.textContaining('Failed to load'), findsNothing);
    });

    testWidgets('the error latches until the user retries', (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final callsAfterFailure = source.callCount;

      await tester.pump(const Duration(seconds: 1));

      expect(
        source.callCount,
        callsAfterFailure,
        reason: 'a latched error stops the auto-fetch loop',
      );
    });

    testWidgets('Retry re-issues the same page', (tester) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(source.calls, [
        (0, 10),
        (0, 10),
      ], reason: 'the failed page is retried, not skipped');
    });

    testWidgets('a mid-list failure keeps the loaded items on screen', (
      tester,
    ) async {
      // The two placements of the error slot are the substance of this
      // widget's failure behaviour, and this is the one with something to
      // lose. A user who has scrolled through screens of content does not
      // give them up because the next page failed; the report goes at the
      // boundary they reached.
      //
      // Both halves are checked — what is in state and what is on screen.
      // `loadedCount` alone proves the items survive and says nothing about
      // whether anybody can see them, which is exactly how the surface-taking
      // behaviour went unquestioned.
      final source = _Source(total: 100, failFrom: 1);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('item-'),
        findsWidgets,
        reason:
            'items must be on screen first, or the check below is '
            'vacuous — a first-page failure cannot tell a panel from a tile',
      );

      await _scrollToTrailingTile(tester);
      expect(find.textContaining('Failed to load'), findsOneWidget);

      expect(
        find.textContaining('item-'),
        findsWidgets,
        reason: 'the rows the user already reached stay where they are',
      );
      expect(
        find.byType(ListView),
        findsOneWidget,
        reason: 'the report is a tile in the list, not a replacement for it',
      );
      expect(key.currentState!.loadedCount, 10);
    });

    testWidgets('an initial-load failure still takes the whole surface', (
      tester,
    ) async {
      // The other placement, and the control for the case above: with nothing
      // loaded there is nothing to preserve, and a report squeezed into a tile
      // of an otherwise empty list would read as a broken row.
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'no list is mounted, so nothing can be a tile in it',
      );
    });

    testWidgets('the builder is told which placement it is in', (tester) async {
      // It is called in both, so a builder that assumes it owns the surface
      // would render a full-height panel inside a list tile. The parameter is
      // what lets it answer both, and this is what says it is real.
      final seen = <TomInfiniteScrollErrorPlacement>[];
      final source = _Source(total: 100, failFrom: 1);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
            errorBuilder: (_, error, retry, placement) {
              seen.add(placement);
              return Text('failed at $placement');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToTrailingTile(tester);

      expect(seen, isNotEmpty);
      expect(seen.toSet(), {
        TomInfiniteScrollErrorPlacement.tile,
      }, reason: 'items are loaded, so the report belongs in the list');
    });

    testWidgets('the builder is told when it owns the surface', (tester) async {
      // The other half, in its own test rather than a second pump: without a
      // key the framework reuses the state, so the items and the latched error
      // survive and the placement never changes — which is how this would have
      // passed while testing nothing.
      final seen = <TomInfiniteScrollErrorPlacement>[];

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: _Source(failFrom: 0).fetch,
            itemBuilder: _tile,
            errorBuilder: (_, error, retry, placement) {
              seen.add(placement);
              return Text('failed at $placement');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(seen.toSet(), {TomInfiniteScrollErrorPlacement.surface});
    });
  });

  // -------------------------------------------------------------------------
  group('TomInfiniteScroll state and refresh', () {
    testWidgets('exposes loaded / pending / exhausted', (tester) async {
      final source = _Source(total: 15)..gate = Completer<void>();
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
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

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);
      expect(key.currentState!.loadedCount, 20);

      await key.currentState!.refresh();
      await tester.pumpAndSettle();

      expect(key.currentState!.loadedCount, 10);
      // Asserted as the whole log rather than `calls.last`, because the
      // duplicate is the point: page 0 is fetched, then fetched again. The
      // `last` form is true of a fetcher called once per page too, so it
      // could not have caught the dartdoc that claimed exactly that.
      expect(source.calls, [
        (0, 10),
        (1, 10),
        (0, 10),
      ], reason: 'refresh re-requests a page that was already fetched');
    });

    testWidgets('refresh clears a latched error', (tester) async {
      final source = _Source(failFrom: 0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Failed to load'), findsOneWidget);

      await key.currentState!.refresh();
      await tester.pumpAndSettle();

      expect(
        source.calls,
        hasLength(2),
        reason: 'refresh re-attempts rather than staying latched',
      );
    });

    // The fetcher is re-entrant, not merely re-called. Three paths re-issue a
    // page that was already requested — Retry ('Retry re-issues the same
    // page'), refresh ('refresh restarts from page 0'), and the one below,
    // where a refresh lands while a page is still in flight and leaves two
    // calls outstanding at once. The first two are sequential and were
    // already covered; this one is the reason `TomPageFetcher` needs a
    // generation fence rather than just the `_pending` gate, because
    // `refresh` clears `_pending` in order to start immediately.
    testWidgets('a refresh during an in-flight fetch discards its result', (
      tester,
    ) async {
      final source = _Source(total: 100);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.loadedCount, 10);

      // Hold page 1 open, then refresh underneath it. Both requests are now
      // parked on the same gate; completing it resolves them in order, the
      // stale one first.
      source.gate = Completer<void>();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      expect(source.calls, [(0, 10), (1, 10)]);

      final refreshed = key.currentState!.refresh();
      await tester.pump();
      expect(
        source.calls,
        [(0, 10), (1, 10), (0, 10)],
        reason:
            'refresh does not wait for the in-flight page — the two '
            'calls overlap, so the fetcher must tolerate re-entry',
      );

      source.gate!.complete();
      await refreshed;
      await tester.pumpAndSettle();

      // Without the fence the abandoned page 1 lands on top of the restarted
      // sequence, giving 20 items whose first row is `item-10`.
      expect(
        key.currentState!.loadedCount,
        10,
        reason: 'the abandoned page must not be appended to the new list',
      );
      expect(find.text('item-0'), findsOneWidget);
      expect(find.text('item-10'), findsNothing);
    });

    testWidgets('a refresh during the very first fetch discards its result', (
      tester,
    ) async {
      // The sibling case above refreshes over an in-flight *page 1*, so the
      // stale result is a page the new sequence has not reached. Here both
      // requests are for page 0, which is the arrangement a pull-to-refresh on
      // a slow connection actually produces: the stale result is an exact
      // duplicate of the wanted one, and without the fence the list holds each
      // item twice.
      //
      // It also enters `_fetchNextPage` from a different caller — the
      // post-frame callback in `initState` rather than a scroll — which is the
      // path every first load takes.
      final source = _Source(total: 100)..gate = Completer<void>();
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump();
      expect(source.calls, [(0, 10)], reason: 'the first page is in flight');
      expect(key.currentState!.loadedCount, 0);

      final refreshed = key.currentState!.refresh();
      await tester.pump();
      expect(source.calls, [(0, 10), (0, 10)]);

      source.gate!.complete();
      await refreshed;
      await tester.pumpAndSettle();

      expect(
        key.currentState!.loadedCount,
        10,
        reason: 'one page, not the same page twice',
      );
      expect(find.text('item-0'), findsOneWidget);
    });

    testWidgets('a failure that arrives after a refresh does not latch', (
      tester,
    ) async {
      // The other arm of the fence. `refresh` clears `_error` as well as the
      // items, so a stale *failure* landing afterwards would put the list back
      // into an error state that belongs to a sequence nobody is watching —
      // and the error panel replaces the whole surface, so the user would see
      // a refresh that appeared to fail.
      // Only the FIRST call fails, so the abandoned request throws while the
      // one that replaced it succeeds. Failing by page could not separate
      // them — both are page 0, parked on the same gate.
      final source = _Source(total: 100)
        ..gate = Completer<void>()
        ..failCalls.add(0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump();

      final refreshed = key.currentState!.refresh();
      await tester.pump();
      source.gate!.complete();
      await refreshed;
      await tester.pumpAndSettle();

      expect(
        find.text('item-0'),
        findsOneWidget,
        reason: 'the refreshed page is on screen',
      );
      expect(key.currentState!.loadedCount, 10);
    });

    testWidgets('a page that fits the viewport still asks for the next', (
      tester,
    ) async {
      // Scrolling is the other trigger, and a list that does not overflow
      // cannot be scrolled — so a *full* page that happens to fit left the
      // list showing one page with more data behind it and nothing able to
      // ask. Exhaustion does not cover it: a full page leaves `isExhausted`
      // false by definition.
      //
      // No gesture anywhere in this case. That is the point.
      final source = _Source(total: 1000);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            // Two 50-pixel rows against a 200-pixel viewport: a full page
            // that cannot fill it.
            pageSize: 2,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        source.calls.length,
        greaterThan(1),
        reason: 'page 0 fitted, so the list must ask for page 1 itself',
      );
      expect(
        key.currentState!.isExhausted,
        isFalse,
        reason: 'the source has plenty left — this is not an exhausted list',
      );
      expect(
        key.currentState!.loadedCount * _tileHeight,
        greaterThan(_viewportHeight),
        reason: 'it keeps asking until the viewport is covered, and stops',
      );
    });

    testWidgets('the fill stops when the source runs out', (tester) async {
      // The bound. A source shorter than the viewport can never fill it, so
      // the loop has to end on exhaustion rather than on success.
      final source = _Source(total: 3);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 2,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.loadedCount, 3);
      expect(key.currentState!.isExhausted, isTrue);
      expect(
        source.calls,
        [(0, 2), (1, 2)],
        reason:
            'the short second page ends it — no request is made after the '
            'source has said it is done',
      );
    });

    testWidgets('a page that overflows the viewport is left to the gesture', (
      tester,
    ) async {
      // The control, and the line the fill is drawn at. A list that *can* be
      // scrolled is already reachable by the scroll trigger, so filling it
      // here would turn every load into an immediate second request — which
      // is a different behaviour from the one this fixes.
      final source = _Source(total: 1000);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            // Ten 50-pixel rows against a 200-pixel viewport: scrollable.
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(source.calls, [
        (0, 10),
      ], reason: 'nothing scrolled, and the list did not need to fill itself');
    });

    testWidgets('a refresh fills a short viewport again', (tester) async {
      // The counter is per sequence: a refreshed list starts short, and must
      // fill from nothing exactly as the first load did.
      final source = _Source(total: 1000);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 2,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final afterFirstFill = key.currentState!.loadedCount;

      await key.currentState!.refresh();
      await tester.pumpAndSettle();

      expect(
        key.currentState!.loadedCount,
        afterFirstFill,
        reason: 'the refreshed list fills to the same depth, not to one page',
      );
    });

    testWidgets('the error is observable from outside, and clears', (
      tester,
    ) async {
      // The state class is public so a `GlobalKey` holder can inspect it, and
      // the failure was the one thing it could not see: `loadedCount`,
      // `isPending` and `isExhausted` read identically for a list showing an
      // error panel and one showing an empty state.
      final source = _Source(failFrom: 0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.hasError, isTrue);
      expect(key.currentState!.error, isA<StateError>());
      expect(
        key.currentState!.error.toString(),
        contains('page 0 unavailable'),
        reason: 'the caller gets the failure itself, not a flag about it',
      );
      // The three that were already public cannot tell this apart from an
      // empty source, which is why the fourth is needed.
      expect(key.currentState!.loadedCount, 0);
      expect(key.currentState!.isPending, isFalse);
      expect(key.currentState!.isExhausted, isFalse);

      source.failFrom = null;
      await key.currentState!.refresh();
      await tester.pumpAndSettle();

      expect(key.currentState!.hasError, isFalse);
      expect(key.currentState!.error, isNull);
      expect(key.currentState!.loadedCount, 10);
    });

    testWidgets('a retry clears it as well as a refresh', (tester) async {
      // `refresh` is not the only way out. The error slot's own Retry runs
      // `_resetError`, and a caller watching `hasError` has to see that too.
      final source = _Source(failFrom: 0);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.hasError, isTrue);

      source.failFrom = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(key.currentState!.hasError, isFalse);
      expect(key.currentState!.error, isNull);
    });

    testWidgets('a healthy list reports no error', (tester) async {
      // The control. Without it both cases above are satisfied by a getter
      // that returns null whatever happened.
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            key: key,
            pageSize: 10,
            fetcher: _Source(total: 25).fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.hasError, isFalse);
      expect(key.currentState!.error, isNull);
    });

    testWidgets('a consumer can pumpAndSettle with the skeleton on screen', (
      tester,
    ) async {
      // The default skeleton is six animating `TomSkeletonLoader`s the caller
      // never names, and a repeating animation schedules frames forever — so
      // the first line of every downstream widget test, `await
      // tester.pumpAndSettle()`, used to hang for the full timeout and then
      // fail with a message about nothing in particular.
      //
      // Reduced motion is the way out, and it is the same switch a user who
      // asked for less motion already sets.
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: TomInfiniteScroll<int>(
                  pageSize: 10,
                  fetcher: source.fetch,
                  itemBuilder: _tile,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(TomSkeletonLoader),
        findsWidgets,
        reason: 'the skeleton has to be up, or this settles for no reason',
      );

      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );

      expect(
        find.byType(TomSkeletonLoader),
        findsWidgets,
        reason: 'and it is still up afterwards — nothing settled it away',
      );

      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('padding reaches the inner list', (tester) async {
      final source = _Source(total: 25);
      const padding = EdgeInsets.all(9);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
            padding: padding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<ListView>(find.byType(ListView)).padding, padding);
    });

    testWidgets('a fetch completing after dispose is dropped', (tester) async {
      final source = _Source()..gate = Completer<void>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      source.gate!.complete();

      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'no setState after dispose',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Which slot owns the surface
  // -------------------------------------------------------------------------
  //
  // `build` picks one slot and returns it. Three of the four take the whole
  // surface — skeleton, empty and error are returned *instead of* the
  // `ListView` — and only the "loading more" spinner is a tile inside the
  // list. That asymmetry is invisible from the call site, which is how the
  // dartdoc came to call the error slot a "tile" and go unchallenged: the
  // bullet describing it sits directly under the one describing the trailing
  // spinner, which genuinely is a tile.
  //
  // A prose rule was considered instead and rejected on measurement. Banning
  // list-membership nouns near slot prose would have to sort through the 360
  // dartdoc lines in `lib/` that already say "tile" or "row", nearly all of
  // them correctly. Comparing a documented noun against the root widget of
  // the matching `_default*` helper would evaluate three sites, all in this
  // one file. Neither is a rule; both are this bug spelled backwards. What
  // generalises is the property the wrong noun denied, so that is what is
  // asserted here.
  //
  // The counterexample that keeps this group from being vacuous already
  // exists: 'a trailing spinner marks the load-more state' in the pagination
  // group asserts the spinner is appended *below the last loaded item*, so
  // items and indicator are on screen together — the exact co-existence
  // forbidden below for the other three. If surface ownership were an
  // artifact of how these tests pump rather than a real property, that test
  // could not pass.
  group('TomInfiniteScroll slot exclusivity', () {
    /// Fails unless [slot] is the *only* one of the four markers on screen.
    ///
    /// Written as "every other marker is absent" rather than "the expected one
    /// is present" on purpose: a check that only looks for what it expects
    /// cannot see a second slot painted beside it, and a second slot painted
    /// beside it is precisely what "tile" claimed.
    void expectOnly(String slot) {
      final markers = <String, Finder Function()>{
        'skeleton': () => find.byType(TomSkeletonLoader),
        'empty': () => find.byType(TomEmptyState),
        'error': () => find.textContaining('Failed to load'),
        'items': () => find.textContaining('item-'),
      };
      expect(markers.keys, contains(slot), reason: 'unknown slot name');
      markers.forEach((name, finder) {
        if (name == slot) return;
        expect(
          finder(),
          findsNothing,
          reason:
              'in the $slot state, $name must not be painted too — '
              'each of these slots owns the whole surface',
        );
      });
      expect(
        markers[slot]!(),
        findsWidgets,
        reason: 'the $slot slot must be painted',
      );
    }

    testWidgets('the initial-load skeleton is alone on the surface', (
      tester,
    ) async {
      final source = _Source(total: 25)..gate = Completer<void>();

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pump();

      expectOnly('skeleton');
      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the empty state is alone on the surface', (tester) async {
      final source = _Source(total: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectOnly('empty');
    });

    testWidgets('the error slot is alone on the surface when nothing loaded', (
      tester,
    ) async {
      final source = _Source(failFrom: 0);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectOnly('error');
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'no list is mounted at all, so nothing can be a tile in it',
      );
    });

    testWidgets('a failure under loaded items shares the surface with them', (
      tester,
    ) async {
      // The exception to the exclusivity rule, and the only one: every other
      // slot replaces the list, and this one joins it.
      final source = _Source(total: 100, failFrom: 1);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToTrailingTile(tester);

      expect(find.textContaining('Failed to load'), findsOneWidget);
      expect(find.textContaining('item-'), findsWidgets);
      expect(find.byType(TomEmptyState), findsNothing);
      expect(find.byType(TomSkeletonLoader), findsNothing);
    });

    testWidgets('the loaded list is alone on the surface', (tester) async {
      final source = _Source(total: 25);

      await tester.pumpWidget(
        _app(
          TomInfiniteScroll<int>(
            pageSize: 10,
            fetcher: source.fetch,
            itemBuilder: _tile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectOnly('items');
    });
  });
}
