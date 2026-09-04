/// Demo R — Phase 6 custom widgets (tree / radio / infinite scroll).
///
/// Three Phase 6 widgets composed on one page:
///
///   * `TomAuthTreeView` — five hierarchical nav nodes, each with its
///     own `tomId`. Resource-driven auth determines per-node visibility,
///     interactivity, and inheritance: when a parent is `disabled`, all
///     children inherit that constraint (cannot be widened). Two of the
///     leaves carry a `none` rule by default so the tree is visibly
///     trimmed at first paint.
///   * `TomRadioGroup` — density picker with **group-level** auth
///     (resource key `demoR.densityRadio`). The right-hand panel flips
///     the auth state across `full / read / disabled / none` and the
///     whole group reacts.
///   * `TomInfiniteScroll` — paginated list over a synthetic 10 000-row
///     source. Exercises the initial-load skeleton (via
///     `TomSkeletonLoader`), the bottom-of-list "loading more"
///     indicator, the empty / error slots, and the page exhaustion
///     branch. Each *row* is wrapped in its own `TomErrorBoundary`
///     (a boundary around the tile builder) — so a
///     synthetic build-time throw inside one row (driven by the
///     `throwOnTile` toggle in the right control pane) is caught at
///     row scope: only the failing row collapses to a compact inline
///     fallback while sibling rows keep rendering normally. An outer
///     `TomErrorBoundary` around the whole scroll remains as a
///     defense-in-depth backstop.
///
/// Implementation note (round-4 feedback `t`): an earlier version
/// only had the outer boundary and the throwing logic lived inside
/// the `itemBuilder` closure itself, so the throw escaped the
/// closure before the inner boundary's subtree existed and the whole
/// list was replaced. The fix is two-part: (a) move the row body
/// into a dedicated `_DemoRRow` widget so the throw happens inside
/// `build()` (i.e. inside the per-row boundary's subtree); (b) wrap
/// every row in its own `TomErrorBoundary` with a compact fallback.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';
import '../state/phase6_state.dart';

class DemoRTreeRadioInfinite extends StatefulWidget {
  const DemoRTreeRadioInfinite({super.key});

  @override
  State<DemoRTreeRadioInfinite> createState() => _DemoRTreeRadioInfiniteState();
}

class _DemoRTreeRadioInfiniteState extends State<DemoRTreeRadioInfinite> {
  final _adapter = DemoPhase6AuthAdapter();
  final _controller = DemoRController();
  final _pageSource = DemoRPageSource();
  final _scrollKey = GlobalKey<TomInfiniteScrollState<String>>();

  // The five default tree-node auth states. Mirrors the rules seeded
  // into `_adapter` in `initState` so the right-hand control panel
  // shows the *current* picture rather than `full` on first paint.
  late final Map<String, TomAuthState> _treeAuth;

  @override
  void initState() {
    super.initState();
    TomAuthorization.adapter = _adapter;

    // Seed default per-node rules. Two of the children start at `none`
    // so the tree visibly trims itself on first paint.
    _treeAuth = {
      'demoR.tree.dashboard': TomAuthState.full,
      'demoR.tree.users': TomAuthState.full,
      'demoR.tree.users.list': TomAuthState.full,
      'demoR.tree.users.invite': TomAuthState.read,
      'demoR.tree.billing': TomAuthState.disabled,
      'demoR.tree.billing.plans': TomAuthState.full,
      'demoR.tree.billing.invoices': TomAuthState.full,
      'demoR.tree.admin': TomAuthState.none,
      'demoR.tree.admin.audit': TomAuthState.full,
    };
    _treeAuth.forEach(_adapter.set);

    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _setTreeAuth(String path, TomAuthState state) {
    setState(() {
      _treeAuth[path] = state;
      _adapter.set(path, state);
    });
  }

  // -------------------------------------------------------------------
  // Build.
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo R — Tree / Radio / Infinite scroll (Phase 6)',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final treePane = _treePane(context);
          final radioPane = _radioPane(context);
          final infinitePane = _infinitePane(context);
          final controlPane = _controlPane(context);
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 280, child: treePane),
                  const SizedBox(width: 12),
                  SizedBox(width: 280, child: radioPane),
                  const SizedBox(width: 12),
                  Expanded(child: infinitePane),
                  const SizedBox(width: 12),
                  SizedBox(width: 280, child: controlPane),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 260, child: treePane),
                const SizedBox(height: 12),
                radioPane,
                const SizedBox(height: 12),
                SizedBox(height: 320, child: infinitePane),
                const SizedBox(height: 12),
                controlPane,
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Tree pane.
  // -------------------------------------------------------------------

  Widget _treePane(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('TomAuthTreeView', style: theme.textTheme.titleSmall),
            ),
            const Divider(height: 1),
            Expanded(
              child: TomAuthTreeView(
                shrinkWrap: false,
                padding: const EdgeInsets.symmetric(vertical: 4),
                nodes: [
                  TomAuthTreeNode(
                    tomId: 'demoR.tree.dashboard',
                    title: const Text('Dashboard'),
                    leading: const Icon(Icons.dashboard_outlined, size: 18),
                  ),
                  TomAuthTreeNode(
                    tomId: 'demoR.tree.users',
                    title: const Text('Users'),
                    leading: const Icon(Icons.group_outlined, size: 18),
                    children: [
                      TomAuthTreeNode(
                        tomId: 'demoR.tree.users.list',
                        title: const Text('List'),
                      ),
                      TomAuthTreeNode(
                        tomId: 'demoR.tree.users.invite',
                        title: const Text('Invite'),
                      ),
                    ],
                  ),
                  TomAuthTreeNode(
                    tomId: 'demoR.tree.billing',
                    title: const Text('Billing'),
                    leading: const Icon(Icons.receipt_long_outlined, size: 18),
                    children: [
                      TomAuthTreeNode(
                        tomId: 'demoR.tree.billing.plans',
                        title: const Text('Plans'),
                      ),
                      TomAuthTreeNode(
                        tomId: 'demoR.tree.billing.invoices',
                        title: const Text('Invoices'),
                      ),
                    ],
                  ),
                  TomAuthTreeNode(
                    tomId: 'demoR.tree.admin',
                    title: const Text('Admin'),
                    leading: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    children: [
                      TomAuthTreeNode(
                        tomId: 'demoR.tree.admin.audit',
                        title: const Text('Audit log'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Radio pane.
  // -------------------------------------------------------------------

  Widget _radioPane(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TomRadioGroup', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TomRadioGroup<String>(
              tomId: 'demoR.densityRadio',
              title: 'Row density',
              selected: _controller.radioValue,
              onChanged: _controller.selectRadio,
              items: const [
                TomRadioGroupItem(
                  value: 'compact',
                  label: 'Compact',
                  description: 'Tightest spacing, max info density.',
                ),
                TomRadioGroupItem(
                  value: 'comfortable',
                  label: 'Comfortable',
                  description: 'Default — balances density and breathing room.',
                ),
                TomRadioGroupItem(
                  value: 'spacious',
                  label: 'Spacious',
                  description: 'Extra padding, easiest on the eye.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Selected: ${_controller.radioValue}  ·  '
              'auth: ${_controller.radioAuth.name}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Infinite-scroll pane.
  // -------------------------------------------------------------------

  Widget _infinitePane(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TomInfiniteScroll + TomErrorBoundary',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  'loaded: ${_scrollKey.currentState?.loadedCount ?? 0}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              // Outer boundary kept as defense-in-depth. The
              // *meaningful* containment in this demo is per-row:
              // see `_buildRow` below, which wraps every tile in its
              // own `TomErrorBoundary`. Without the per-row layer
              // the synthetic throw would escape past the
              // ListView.builder and trip *this* outer boundary,
              // collapsing the whole list (the original feedback-`t`
              // bug).
              child: TomErrorBoundary(
                child: TomInfiniteScroll<String>(
                  key: _scrollKey,
                  pageSize: 25,
                  fetcher: (page, size) => _pageSource.fetchPage(
                    page,
                    size,
                    failNext: _controller.failNext,
                  ),
                  itemBuilder: _buildRow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a single list row, wrapped in its own per-row
  /// `TomErrorBoundary`. The throwing logic lives inside `_DemoRRow`
  /// (a real widget) rather than in this closure — that's what makes
  /// the boundary effective: the throw fires from inside the
  /// boundary's subtree's `build()`, not from the closure that
  /// returns the subtree, so `ErrorWidget.builder` routes it to the
  /// inner boundary instead of escaping to whichever boundary
  /// happens to be active when the closure runs.
  Widget _buildRow(BuildContext context, String item, int index) {
    return TomErrorBoundary(
      // ValueKey by index: a fresh boundary per row position so
      // capture state doesn't bleed across rows when the toggle
      // flips and the list rebuilds.
      key: ValueKey<int>(index),
      fallbackBuilder: (context, details, retry) =>
          _DemoRRowErrorTile(index: index, details: details, onRetry: retry),
      child: _DemoRRow(
        item: item,
        index: index,
        throwOnTile: _controller.throwOnTile,
      ),
    );
  }

  // -------------------------------------------------------------------
  // Right control pane.
  // -------------------------------------------------------------------

  Widget _controlPane(BuildContext context) {
    return InfoPanel(
      title: 'Phase 6 controls',
      children: [
        const InfoPanelHeading('Radio group auth'),
        DropdownButton<TomAuthState>(
          isExpanded: true,
          value: _controller.radioAuth,
          items: const [
            DropdownMenuItem(value: TomAuthState.full, child: Text('full')),
            DropdownMenuItem(value: TomAuthState.read, child: Text('read')),
            DropdownMenuItem(
              value: TomAuthState.disabled,
              child: Text('disabled'),
            ),
            DropdownMenuItem(value: TomAuthState.none, child: Text('none')),
          ],
          onChanged: (v) {
            if (v != null) _controller.setRadioAuth(v, _adapter);
          },
        ),
        const InfoPanelHeading('Infinite scroll'),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Fail next page fetch'),
          subtitle: const Text('Triggers the error slot on the next prefetch.'),
          value: _controller.failNext,
          onChanged: (_) => _controller.toggleFailNext(),
        ),
        FilledButton.icon(
          onPressed: () {
            // Note: leave failNext alone — the toggle is independent so
            // the user can deliberately retry into a failure to exercise
            // TomInfiniteScroll's error slot.
            _scrollKey.currentState?.refresh();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Throw in row tile'),
          subtitle: Text(
            'Row #${DemoRController.throwRowIndex.toString().padLeft(5, '0')} '
            'throws — exercises the per-tile TomErrorBoundary.',
          ),
          value: _controller.throwOnTile,
          onChanged: (_) => _controller.toggleThrowOnTile(),
        ),
        const InfoPanelHeading('Tree-node auth'),
        for (final entry in _treeAuth.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key.replaceFirst('demoR.tree.', ''),
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownButton<TomAuthState>(
                  value: entry.value,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: TomAuthState.full,
                      child: Text('full'),
                    ),
                    DropdownMenuItem(
                      value: TomAuthState.read,
                      child: Text('read'),
                    ),
                    DropdownMenuItem(
                      value: TomAuthState.disabled,
                      child: Text('disabled'),
                    ),
                    DropdownMenuItem(
                      value: TomAuthState.none,
                      child: Text('none'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) _setTreeAuth(entry.key, v);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Per-row helpers — extracted so the throw happens inside the per-row
// TomErrorBoundary's subtree (see `_buildRow` above).
// ---------------------------------------------------------------------

/// One list row. Throws synthetically from inside `build()` when
/// [throwOnTile] is set and [index] matches
/// [DemoRController.throwRowIndex]. Being a real widget is the key
/// detail: placing the throw inside `build()` (rather than inside the
/// itemBuilder closure) means the error fires from *inside* the
/// surrounding `TomErrorBoundary`, so the boundary's
/// `ErrorWidget.builder` hook routes the failure to that row only.
class _DemoRRow extends StatelessWidget {
  final String item;
  final int index;
  final bool throwOnTile;

  const _DemoRRow({
    required this.item,
    required this.index,
    required this.throwOnTile,
  });

  @override
  Widget build(BuildContext context) {
    if (throwOnTile && index == DemoRController.throwRowIndex) {
      throw StateError('Synthetic tile-build error at row $index.');
    }
    return ListTile(
      dense: true,
      leading: const Icon(Icons.list_alt_outlined),
      title: Text(item),
    );
  }
}

/// Compact fallback tile for a single failed row. Deliberately row-
/// shaped (icon + one-line message + retry) so the list structure
/// stays visually intact and neighbouring rows keep rendering.
class _DemoRRowErrorTile extends StatelessWidget {
  final int index;
  final FlutterErrorDetails details;
  final VoidCallback onRetry;

  const _DemoRRowErrorTile({
    required this.index,
    required this.details,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.error_outline,
        color: theme.colorScheme.error,
        size: 20,
      ),
      title: Text(
        'Row #$index failed to render',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      subtitle: Text(
        details.exceptionAsString(),
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}
