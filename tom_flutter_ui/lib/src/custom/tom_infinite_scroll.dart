/// List wrapper with pagination, an observable page fetcher, and
/// empty / error / loading-state hooks. The default slot builders render
/// [TomEmptyState] and [TomSkeletonLoader], so an unconfigured list already
/// matches the rest of the kit; the error slot is plain Material widgets.
///
/// The error slot is deliberately not a `TomErrorBoundary`, and the two are
/// not alternatives. A boundary catches a throw raised while a widget
/// *builds*; this slot reports a [TomPageFetcher] future that rejected, which
/// never reaches a boundary because the failure is already caught and held
/// in state. They compose rather than overlap: wrapping each row in its own
/// boundary contains a build-time throw to that row, while the fetch-error
/// slot goes on handling failed pages.
///
/// The widget is parameterised over a single [TomPageFetcher] callback
/// of shape `Future<List<T>> Function(int page, int pageSize)`. The
/// inner [ListView.builder] calls the fetcher whenever the user
/// approaches the end of the loaded list and appends the result. When
/// a page returns fewer items than [TomInfiniteScroll.pageSize], the
/// wrapper considers the source exhausted and stops issuing further
/// requests.
///
/// State transitions exposed through the slot builders. The skeleton and empty
/// slots are returned in place of the `ListView` and take the whole surface;
/// the "loading more" indicator is a tile *within* the list; and the error
/// slot is one or the other depending on whether there is anything to
/// preserve.
///
/// Pages are requested on two triggers: scrolling within
/// [TomInfiniteScroll.prefetchOffset] of the end, and a page landing that
/// leaves the list with nothing to scroll. The second exists because the first
/// cannot fire on a list that does not overflow — and a *full* page that
/// happens to fit leaves the source unexhausted, so without it the list stops
/// after one page with more data available. It applies only when there is no
/// scrollable extent at all; anything scrollable is left to the gesture.
///
/// * `pending && items.isEmpty` — initial-load skeleton via
///   [TomInfiniteScroll.skeletonBuilder].
/// * `pending && items.isNotEmpty` — bottom-of-list "loading more"
///   indicator (a small `CircularProgressIndicator`), appended as the
///   list's last tile.
/// * `error != null && items.isEmpty` — [TomInfiniteScroll.errorBuilder] with
///   [TomInfiniteScrollErrorPlacement.surface], defaulting to a centred
///   Material panel with the message and a Retry action. Nothing is loaded,
///   so the failure is all there is to show.
/// * `error != null && items.isNotEmpty` — the same builder with
///   [TomInfiniteScrollErrorPlacement.tile], defaulting to a compact row with
///   the message and a Retry action, appended as the list's last tile. **The
///   loaded items stay on screen.** A user who has scrolled through ten
///   screens does not lose them because page six failed, and the report is at
///   the boundary they reached rather than in place of everything behind it.
/// * `items.isEmpty && !pending && error == null` —
///   [TomInfiniteScroll.emptyBuilder].
library;

import 'package:flutter/material.dart';

import 'tom_empty_state.dart';
import 'tom_skeleton_loader.dart';

/// Fetches one page of items. `page` is zero-based, `pageSize` is the
/// requested page size. Returning fewer items than `pageSize` signals
/// end-of-source and stops further auto-fetches.
///
/// Must be idempotent: retries and refreshes re-request pages that have
/// already been fetched. See [TomInfiniteScroll.fetcher] for when.
typedef TomPageFetcher<T> = Future<List<T>> Function(int page, int pageSize);

/// Builds a single list tile from an item.
typedef TomInfiniteScrollItemBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

/// Where a page failure is being reported.
///
/// The two are genuinely different situations and want different shapes, which
/// is why the builder is told which one it is in rather than left to guess
/// from a count it does not have.
enum TomInfiniteScrollErrorPlacement {
  /// Nothing is loaded, so the report takes the whole surface. There is
  /// nothing to preserve and the failure is the only thing to say.
  surface,

  /// Items are on screen and stay there; the report is the list's last tile,
  /// at the boundary the user scrolled to. Replacing the surface here would
  /// throw away a screenful of content the user has already reached.
  tile,
}

/// Builds the report for a page that failed.
///
/// [retry] re-issues the page that failed — the cursor does not advance past
/// a failure — and [placement] says whether the result is taking the surface
/// or sitting at the end of the list.
typedef TomInfiniteScrollErrorBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      VoidCallback retry,
      TomInfiniteScrollErrorPlacement placement,
    );

/// List wrapper with pagination, observable page fetcher, and
/// empty / error / loading-state hooks.
class TomInfiniteScroll<T> extends StatefulWidget {
  /// Fetches a page of items.
  ///
  /// **The same `(page, pageSize)` can be requested more than once, so this
  /// callback must be idempotent.** A failed fetch does not advance the
  /// cursor, so a retry re-issues the page that just failed, and
  /// [TomInfiniteScrollState.refresh] restarts from page 0 — re-requesting
  /// every page as the user scrolls back through them.
  ///
  /// It can also be re-entered: a `refresh()` during an in-flight fetch
  /// starts the new request immediately, leaving two calls outstanding.
  /// The older one's result is discarded, not cancelled — [TomPageFetcher]
  /// has no cancellation channel — so anything the callback does besides
  /// returning items has to be safe to do twice, and safe to do for
  /// nothing.
  final TomPageFetcher<T> fetcher;

  /// Builds a tile for one item.
  final TomInfiniteScrollItemBuilder<T> itemBuilder;

  /// Items per page. Defaults to 20.
  final int pageSize;

  /// Pixels-from-bottom threshold for triggering the next page fetch.
  /// Defaults to 200.
  final double prefetchOffset;

  /// Optional builder for the initial-load skeleton. Defaults to a
  /// stack of [TomSkeletonLoader] tiles.
  ///
  /// Those shimmer, and a repeating animation schedules frames forever — so
  /// `WidgetTester.pumpAndSettle` cannot return while the default skeleton is
  /// on screen, which is the first line of most tests that pump a screen
  /// containing one of these over a real data source. Reduced motion or an
  /// enclosing `TickerMode(enabled: false)` stops the shimmer and lets it
  /// settle; see [TomSkeletonLoader.enabled].
  final WidgetBuilder? skeletonBuilder;

  /// Optional builder for the empty-state slot. Defaults to a
  /// [TomEmptyState] with a generic message.
  final WidgetBuilder? emptyBuilder;

  /// Optional builder for the error slot. Receives the error object, a
  /// `retry` closure, and where it is being rendered.
  ///
  /// It is called in both placements, so a builder that assumes it owns the
  /// surface will produce a full-height panel inside a list tile. Read
  /// [TomInfiniteScrollErrorPlacement] and answer both.
  final TomInfiniteScrollErrorBuilder? errorBuilder;

  /// Optional padding around the inner [ListView].
  final EdgeInsetsGeometry? padding;

  const TomInfiniteScroll({
    super.key,
    required this.fetcher,
    required this.itemBuilder,
    this.pageSize = 20,
    this.prefetchOffset = 200,
    this.skeletonBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.padding,
  });

  @override
  State<TomInfiniteScroll<T>> createState() => TomInfiniteScrollState<T>();
}

/// Public state for [TomInfiniteScroll]. The class is non-private so
/// tests / demos can grab it via `GlobalKey<TomInfiniteScrollState<T>>`
/// to inspect counts and force a refresh.
class TomInfiniteScrollState<T> extends State<TomInfiniteScroll<T>> {
  final List<T> _items = [];
  int _page = 0;
  bool _pending = false;
  bool _exhausted = false;
  Object? _error;
  late final ScrollController _controller;

  /// Bumped whenever the loaded set is thrown away, so a fetch that was
  /// already in flight can tell that its result no longer belongs to
  /// anything and drop it.
  ///
  /// `_pending` cannot do this job. [refresh] clears it in order to start
  /// a new fetch immediately, which leaves the old request running with
  /// nothing marking it stale — it would then append a page from the
  /// discarded sequence on top of the new page 0.
  int _generation = 0;

  /// Number of items currently loaded.
  int get loadedCount => _items.length;

  /// Whether a page fetch is currently in flight.
  bool get isPending => _pending;

  /// Whether the source has been exhausted (last page returned fewer
  /// than [TomInfiniteScroll.pageSize] items).
  bool get isExhausted => _exhausted;

  /// The failure the list is currently reporting, or `null` when there is
  /// none.
  ///
  /// The other three observables cannot distinguish a list showing an error
  /// from one showing an empty state: both have nothing loaded, nothing in
  /// flight and an unexhausted source. Without this, a caller driving the list
  /// through a `GlobalKey` could see that it had stopped and not why, and had
  /// no way to report the failure anywhere — [TomInfiniteScroll.errorBuilder]
  /// receives it, but only inside this widget's own build.
  ///
  /// Cleared by [refresh] and by a successful retry. It is the error of the
  /// *current* sequence: a failure from a request abandoned by [refresh] never
  /// reaches it.
  Object? get error => _error;

  /// Whether the list is currently reporting a failure.
  ///
  /// `error != null`, named to read beside [isPending] and [isExhausted] —
  /// which is how a caller asks these questions, one after another.
  bool get hasError => _error != null;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_maybeFetch);
    // Fire the first page lookup after the first frame so the skeleton
    // gets a chance to paint.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNextPage());
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeFetch);
    _controller.dispose();
    super.dispose();
  }

  void _maybeFetch() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels + widget.prefetchOffset >= position.maxScrollExtent) {
      _fetchNextPage();
    }
  }

  /// Asks for another page when the loaded content leaves the list
  /// unscrollable.
  ///
  /// Scrolling is the only other trigger, and a list that does not overflow
  /// cannot be scrolled — so a full page that happens to fit (a small
  /// [TomInfiniteScroll.pageSize], a tall viewport, short tiles) left the list
  /// showing one page with more data available and nothing able to ask for it.
  /// Exhaustion did not cover it: a *full* page leaves `_exhausted` false by
  /// definition.
  ///
  /// **Deliberately stricter than [_maybeFetch]'s rule.** That one fetches
  /// within [TomInfiniteScroll.prefetchOffset] of the end, which at rest is
  /// true of any list barely taller than its viewport; using it here would
  /// turn every load into an immediate second request. This covers only what
  /// scrolling cannot reach — a list with no scrollable extent at all — and
  /// leaves everything scrollable to the gesture that was always going to
  /// trigger it.
  ///
  /// **What bounds the loop is the source, not a counter here.** Each round
  /// either makes the list scrollable — and this returns on the next one — or
  /// brings a short page, which exhausts the source. A counter of rounds was
  /// written and removed: it could only stop a round that added no items, and
  /// a page that adds none has already set `_exhausted`.
  ///
  /// The case it does not bound is rows that measure zero. No number of pages
  /// makes those scrollable, so the list keeps asking; that is an
  /// `itemBuilder` returning nothing, and no guard here can make such a list
  /// work.
  void _autoFillViewport() {
    if (!mounted || !_controller.hasClients) return;
    // Anything scrollable is already reachable by the scroll trigger.
    if (_controller.position.maxScrollExtent > 0) return;
    _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    if (_pending || _exhausted || _error != null) return;
    final generation = _generation;
    setState(() => _pending = true);
    try {
      final batch = await widget.fetcher(_page, widget.pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(batch);
        _page += 1;
        _exhausted = batch.length < widget.pageSize;
        _pending = false;
      });
      // Once the page is laid out, check whether it filled the viewport. It
      // has to wait for the frame: the extent this reads does not exist until
      // the rows it measures are on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoFillViewport());
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _pending = false;
      });
    }
  }

  /// Resets the loaded set and re-issues the first page fetch.
  ///
  /// Safe to call while a fetch is in flight: the outstanding request is
  /// abandoned rather than awaited, so its page cannot land in the
  /// restarted list. The call itself is not cancelled — [TomPageFetcher] has
  /// no cancellation channel — it simply stops mattering.
  Future<void> refresh() async {
    setState(() {
      _generation += 1;
      _items.clear();
      _page = 0;
      _pending = false;
      _exhausted = false;
      _error = null;
    });
    await _fetchNextPage();
  }

  Widget _defaultSkeleton(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      itemCount: 6,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: TomSkeletonLoader(width: double.infinity, height: 24),
      ),
    );
  }

  Widget _defaultEmpty(BuildContext context) {
    return TomEmptyState(
      title: 'No items',
      description: 'Nothing has been loaded yet.',
    );
  }

  Widget _defaultError(
    BuildContext context,
    Object error,
    VoidCallback retry,
    TomInfiniteScrollErrorPlacement placement,
  ) {
    if (placement == TomInfiniteScrollErrorPlacement.tile) {
      return _defaultErrorTile(context, error, retry);
    }
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 8),
            Text(
              'Failed to load: $error',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  /// The compact form, for a failure reported under rows that are still there.
  ///
  /// A row rather than a centred column: it sits in the list's trailing slot
  /// beside content, and the full-surface panel's proportions read as a broken
  /// tile there.
  Widget _defaultErrorTile(
    BuildContext context,
    Object error,
    VoidCallback retry,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Failed to load: $error',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _resetError() {
    setState(() => _error = null);
    _fetchNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final errorBuilder = widget.errorBuilder ?? _defaultError;
    final error = _error;

    if (_items.isEmpty) {
      // Nothing loaded: every slot takes the surface, because there is
      // nothing behind it to preserve.
      if (error != null) {
        return errorBuilder(
          context,
          error,
          _resetError,
          TomInfiniteScrollErrorPlacement.surface,
        );
      }
      if (_pending) {
        return widget.skeletonBuilder?.call(context) ??
            _defaultSkeleton(context);
      }
      return widget.emptyBuilder?.call(context) ?? _defaultEmpty(context);
    }

    // One trailing tile at most: a fetch that failed is no longer pending, so
    // the spinner and the failure cannot both want the slot.
    final hasTrailing = _pending || error != null;
    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      itemCount: _items.length + (hasTrailing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          if (error != null) {
            return errorBuilder(
              context,
              error,
              _resetError,
              TomInfiniteScrollErrorPlacement.tile,
            );
          }
          // Trailing "loading more" tile.
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return widget.itemBuilder(context, _items[index], index);
      },
    );
  }
}
