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
///     branch. Wrapped in `TomErrorBoundary` so a synthetic build-time
///     throw inside an item builder is caught and surfaced via the
///     boundary's fallback UI.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
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
              child: Text('TomAuthTreeView',
                  style: theme.textTheme.titleSmall),
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
                    leading: const Icon(Icons.admin_panel_settings_outlined,
                        size: 18),
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
                  child: Text('TomInfiniteScroll + TomErrorBoundary',
                      style: theme.textTheme.titleSmall),
                ),
                Text(
                  'loaded: ${_scrollKey.currentState?.loadedCount ?? 0}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TomErrorBoundary(
                child: TomInfiniteScroll<String>(
                  key: _scrollKey,
                  pageSize: 25,
                  fetcher: (page, size) =>
                      _pageSource.fetchPage(page, size,
                          failNext: _controller.failNext),
                  itemBuilder: (context, item, index) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.list_alt_outlined),
                    title: Text(item),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                value: TomAuthState.disabled, child: Text('disabled')),
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
          subtitle: const Text(
              'Triggers the error slot on the next prefetch.'),
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
                        value: TomAuthState.full, child: Text('full')),
                    DropdownMenuItem(
                        value: TomAuthState.read, child: Text('read')),
                    DropdownMenuItem(
                        value: TomAuthState.disabled, child: Text('disabled')),
                    DropdownMenuItem(
                        value: TomAuthState.none, child: Text('none')),
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
