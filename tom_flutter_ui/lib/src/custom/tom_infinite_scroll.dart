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
/// State transitions exposed through the slot builders. Only the
/// "loading more" indicator is a tile *within* the list. The skeleton,
/// empty and error slots are returned in place of the `ListView` and take
/// the whole surface, so while any of them is showing, no loaded item is
/// painted.
///
/// * `pending && items.isEmpty` — initial-load skeleton via
///   [TomInfiniteScroll.skeletonBuilder].
/// * `pending && items.isNotEmpty` — bottom-of-list "loading more"
///   indicator (a small `CircularProgressIndicator`), appended as the
///   list's last tile.
/// * `error != null` — [TomInfiniteScroll.errorBuilder] (defaults to a
///   centred Material panel carrying the message and a Retry action).
///   This one replaces the entire list rather than reporting the failure
///   beneath the rows already loaded: those items stay in state and are
///   painted again on retry, but nothing shows above the panel while the
///   error is latched.
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
  final WidgetBuilder? skeletonBuilder;

  /// Optional builder for the empty-state slot. Defaults to a
  /// [TomEmptyState] with a generic message.
  final WidgetBuilder? emptyBuilder;

  /// Optional builder for the error-state slot. Receives the error
  /// object plus a `retry` closure.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
  errorBuilder;

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

  Widget _defaultError(BuildContext context, Object error, VoidCallback retry) {
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

  void _resetError() {
    setState(() => _error = null);
    _fetchNextPage();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final builder = widget.errorBuilder ?? _defaultError;
      return builder(context, _error!, _resetError);
    }
    if (_items.isEmpty) {
      if (_pending) {
        return widget.skeletonBuilder?.call(context) ??
            _defaultSkeleton(context);
      }
      return widget.emptyBuilder?.call(context) ?? _defaultEmpty(context);
    }
    final tileCount = _items.length + (_pending ? 1 : 0);
    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      itemCount: tileCount,
      itemBuilder: (context, index) {
        if (index >= _items.length) {
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
