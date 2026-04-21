/// Demo Q — Phase 6 custom widgets (auth / empty / overlay).
///
/// Showcases three of the Phase 6 non-form custom widgets bound to a
/// shared [DemoQController]:
///
///   * `TomAuthGuard` — wraps a "profile" panel; the right-hand
///     control swaps the `demoQ.profile` resource auth state between
///     full / read / disabled / none and the panel reacts live.
///   * `TomEmptyState` — rendered in the items pane when the items
///     list is empty (drives via the controller's clear / seed actions).
///   * `TomLoadingOverlay` — overlays the items pane during a fake
///     async "save" (600 ms `Future.delayed`).
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';
import '../state/phase6_state.dart';

class DemoQAuthEmptyOverlay extends StatefulWidget {
  const DemoQAuthEmptyOverlay({super.key});

  @override
  State<DemoQAuthEmptyOverlay> createState() => _DemoQAuthEmptyOverlayState();
}

class _DemoQAuthEmptyOverlayState extends State<DemoQAuthEmptyOverlay> {
  final _adapter = DemoPhase6AuthAdapter();
  final _controller = DemoQController();

  @override
  void initState() {
    super.initState();
    TomAuthorization.adapter = _adapter;
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

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo Q — Auth / Empty / Overlay (Phase 6)',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          final stagePane = _stagePane(context);
          final controlPane = _controlPane(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: stagePane),
                      const SizedBox(width: 16),
                      SizedBox(width: 320, child: controlPane),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      stagePane,
                      const SizedBox(height: 16),
                      controlPane,
                    ],
                  ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Left — stage with auth-guarded profile + items + overlay.
  // -------------------------------------------------------------------

  Widget _stagePane(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profileCard(context),
        const SizedBox(height: 12),
        _itemsCard(context),
      ],
    );
  }

  Widget _profileCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TomAuthGuard — profile panel',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TomAuthGuard(
              tomId: 'demoQ.profile',
              hiddenBuilder: (_) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Profile hidden — auth = none',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const CircleAvatar(
                          radius: 14, child: Icon(Icons.person, size: 16)),
                      const SizedBox(width: 8),
                      Text('Ada Lovelace',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          )),
                    ]),
                    const SizedBox(height: 6),
                    Text('ada@example.com',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        )),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Edit profile'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(BuildContext context) {
    final theme = Theme.of(context);
    final items = _controller.items;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('TomEmptyState + TomLoadingOverlay',
                      style: theme.textTheme.titleMedium),
                ),
                Text('${items.length} items',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            // The overlay wraps the items list, not the whole card, so
            // the title row stays visible while a save is in flight.
            TomLoadingOverlay(
              isLoading: _controller.isLoading,
              message: 'Saving items…',
              child: SizedBox(
                height: 220,
                child: items.isEmpty
                    ? const TomEmptyState(
                        title: 'No items',
                        description:
                            'Use Seed to insert sample rows, or +1 to '
                            'append a single row.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.label_outline),
                          title: Text(items[i]),
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
  // Right — controls.
  // -------------------------------------------------------------------

  Widget _controlPane(BuildContext context) {
    return InfoPanel(
      title: 'Phase 6 controls',
      children: [
        const InfoPanelHeading('Profile auth (TomAuthGuard)'),
        DropdownButton<TomAuthState>(
          isExpanded: true,
          value: _controller.auth,
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
            if (v != null) _controller.setAuth(v, _adapter);
          },
        ),
        const InfoPanelHeading('Items list (TomEmptyState)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
            OutlinedButton(
              onPressed: _controller.seed,
              child: const Text('Seed'),
            ),
            OutlinedButton(
              onPressed: _controller.addOne,
              child: const Text('+1 row'),
            ),
          ],
        ),
        const InfoPanelHeading('Loading overlay (TomLoadingOverlay)'),
        FilledButton.icon(
          onPressed:
              _controller.isLoading ? null : _controller.simulateSave,
          icon: const Icon(Icons.save_outlined),
          label: Text(
              _controller.isLoading ? 'Saving…' : 'Simulate 600 ms save'),
        ),
      ],
    );
  }
}
