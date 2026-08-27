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

    testWidgets('a mid-list failure hides the loaded items but keeps them',
        (tester) async {
      // The error slot replaces the whole list, so the retry has to bring the
      // already-loaded items back rather than start from nothing.
      //
      // "Only hidden" used to be asserted by the `loadedCount` check alone,
      // which proves the items survive in state but says nothing about what
      // is on screen. Both halves are checked below, because the unchecked
      // half is the one the documentation got wrong: the dartdoc called this
      // slot an "error tile", which would mean a row appended under items
      // that were still visible.
      final source = _Source(total: 100, failFrom: 1);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('item-'), findsWidgets,
          reason: 'items must be on screen first, or the check below is '
              'vacuous — a first-page failure cannot tell a panel from a tile');

      await _scrollToBottom(tester);
      expect(find.textContaining('Failed to load'), findsOneWidget);

      expect(find.textContaining('item-'), findsNothing,
          reason: 'the error slot took the surface; no row survives beside it');
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
      // Asserted as the whole log rather than `calls.last`, because the
      // duplicate is the point: page 0 is fetched, then fetched again. The
      // `last` form is true of a fetcher called once per page too, so it
      // could not have caught the dartdoc that claimed exactly that.
      expect(source.calls, [(0, 10), (1, 10), (0, 10)],
          reason: 'refresh re-requests a page that was already fetched');
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

    // The fetcher is re-entrant, not merely re-called. Three paths re-issue a
    // page that was already requested — Retry ('Retry re-issues the same
    // page'), refresh ('refresh restarts from page 0'), and the one below,
    // where a refresh lands while a page is still in flight and leaves two
    // calls outstanding at once. The first two are sequential and were
    // already covered; this one is the reason `PageFetcher` needs a
    // generation fence rather than just the `_pending` gate, because
    // `refresh` clears `_pending` in order to start immediately.
    testWidgets('a refresh during an in-flight fetch discards its result',
        (tester) async {
      final source = _Source(total: 100);
      final key = GlobalKey<TomInfiniteScrollState<int>>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        key: key,
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
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
      expect(source.calls, [(0, 10), (1, 10), (0, 10)],
          reason: 'refresh does not wait for the in-flight page — the two '
              'calls overlap, so the fetcher must tolerate re-entry');

      source.gate!.complete();
      await refreshed;
      await tester.pumpAndSettle();

      // Without the fence the abandoned page 1 lands on top of the restarted
      // sequence, giving 20 items whose first row is `item-10`.
      expect(key.currentState!.loadedCount, 10,
          reason: 'the abandoned page must not be appended to the new list');
      expect(find.text('item-0'), findsOneWidget);
      expect(find.text('item-10'), findsNothing);
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
        expect(finder(), findsNothing,
            reason: 'in the $slot state, $name must not be painted too — '
                'each of these slots owns the whole surface');
      });
      expect(markers[slot]!(), findsWidgets,
          reason: 'the $slot slot must be painted');
    }

    testWidgets('the initial-load skeleton is alone on the surface',
        (tester) async {
      final source = _Source(total: 25)..gate = Completer<void>();

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pump();

      expectOnly('skeleton');
      source.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the empty state is alone on the surface', (tester) async {
      final source = _Source(total: 0);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expectOnly('empty');
    });

    testWidgets('the error slot is alone on the surface, items and all',
        (tester) async {
      final source = _Source(total: 100, failFrom: 1);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();
      await _scrollToBottom(tester);

      expectOnly('error');
      expect(find.byType(ListView), findsNothing,
          reason: 'no list is mounted at all, so nothing can be a tile in it');
    });

    testWidgets('the loaded list is alone on the surface', (tester) async {
      final source = _Source(total: 25);

      await tester.pumpWidget(_app(TomInfiniteScroll<int>(
        pageSize: 10,
        fetcher: source.fetch,
        itemBuilder: _tile,
      )));
      await tester.pumpAndSettle();

      expectOnly('items');
    });

  });
}
