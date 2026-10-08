/// Demo Q — Phase 6 custom widgets (auth / empty / overlay).
///
/// Showcases three of the Phase 6 non-form custom widgets bound to a
/// real [OrderForm] + [ValidationForm] pair:
///
///   * `TomAuthGuard` — wraps a "profile" panel; the right-hand
///     control swaps the `demoQ.profile` resource auth state between
///     full / read / disabled / none and the panel reacts live.
///   * `TomEmptyState` — what the items pane's `TomInlineListForm`
///     builds through `emptyBuilder` when the bound `OrderItemsListForm`
///     has no rows; the list renderer decides, not the page. Clear / Seed
///     / +1 row map to `items.removeAt` / `items.add` on the list form.
///   * `TomLoadingOverlay` — overlays the items pane while the
///     [ValidationForm.save] awaits its async `TomSlowValidator` (800 ms
///     synthetic latency on the `username` field).
library;

import 'package:flutter/material.dart';
// import 'package:tom_core_kernel/tom_core_kernel.dart';
// Not imported: tom_flutter_ui re-exports every kernel type this file uses
// through its kernel bridge (tom_flutter_ui/lib/src/kernel_types.dart).
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/order_form.dart';
import '../forms/order_item_form.dart';
import '../forms/validation_form.dart';
import '../panels/info_panel.dart';
import '../state/phase2a_state.dart';
import '../state/phase6_state.dart';

class DemoQAuthEmptyOverlay extends StatefulWidget {
  const DemoQAuthEmptyOverlay({super.key});

  @override
  State<DemoQAuthEmptyOverlay> createState() => _DemoQAuthEmptyOverlayState();
}

class _DemoQAuthEmptyOverlayState extends State<DemoQAuthEmptyOverlay> {
  final _adapter = DemoPhase6AuthAdapter();
  final _controller = DemoQController();

  /// Header form + line-items list bound to a fresh [Order]. The items
  /// pane iterates `_orderForm.items` and shows the Phase 6
  /// `TomEmptyState` slot whenever the list is empty.
  late final OrderForm _orderForm;
  late final Order _order;

  /// Side form that carries an async `TomSlowValidator` on `username`.
  /// Driving `TomLoadingOverlay` off the real `form.save()` future is how
  /// an overlay is meant to be paired with async validation: the overlay's
  /// lifetime is the save's, not a timer's.
  late final ValidationForm _validationForm;

  @override
  void initState() {
    super.initState();
    TomAuthorization.adapter = _adapter;

    _order = _seedOrder();
    _orderForm = TomScope.withScope('demoQ', () => OrderForm());
    _orderForm.bind(_order);
    _orderForm.changes.addListener(_onFormChanged);

    _validationForm = TomScope.withScope('demoQ', () => ValidationForm());
    _validationForm.bind(TomClass());
    // Prime non-visible fields so the TomSlowValidator path (which we care
    // about) runs without unrelated required-field errors surfacing.
    _validationForm.username.setValue('guest');
    _validationForm.email.setValue('guest@example.com');
    _validationForm.password.setValue('strongpass1');
    _validationForm.confirmPassword.setValue('strongpass1');
    _validationForm.website.setValue('https://example.com');

    _controller.addListener(_onControllerChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _orderForm.changes.removeListener(_onFormChanged);
    _orderForm.dispose();
    _validationForm.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Order seeding / mutation helpers.
  // -------------------------------------------------------------------

  Order _seedOrder() {
    final o = Order();
    o.orderNumber | 'ORD-Q';
    o.customer | 'Phase 6 demo';
    o.items.add(_newItem('Alpha'));
    o.items.add(_newItem('Beta'));
    o.items.add(_newItem('Gamma'));
    return o;
  }

  OrderItem _newItem(String productName) {
    final i = OrderItem();
    i.productName | productName;
    i.quantity | '1';
    i.unitPrice | '0.00';
    return i;
  }

  void _clearItems() {
    final items = _orderForm.items;
    while (items.length > 0) {
      items.removeAt(items.length - 1);
    }
    setState(() {});
  }

  void _seedItems() {
    final items = _orderForm.items;
    while (items.length > 0) {
      items.removeAt(items.length - 1);
    }
    // Re-bind the underlying Order so the list picks up the fresh rows.
    _order.items.clear();
    _order.items.add(_newItem('Alpha'));
    _order.items.add(_newItem('Beta'));
    _order.items.add(_newItem('Gamma'));
    _orderForm.items.bind(_order.items);
    setState(() {});
  }

  void _addOne() {
    _orderForm.items.add();
    setState(() {});
  }

  Future<void> _runSlowSave() async {
    _controller.beginSave();
    try {
      await _validationForm.save();
    } finally {
      _controller.endSave();
    }
  }

  // -------------------------------------------------------------------
  // Layout.
  // -------------------------------------------------------------------

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
                      SizedBox(width: 340, child: controlPane),
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
            Text(
              'TomAuthGuard — profile panel',
              style: theme.textTheme.titleMedium,
            ),
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
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.person, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ada Lovelace',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ada@example.com',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
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
    final items = _orderForm.items;
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
                    'TomEmptyState + TomLoadingOverlay',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('${items.length} items', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            // Overlay wraps only the list area so the title row stays
            // readable while the TomSlowValidator-backed save runs.
            TomLoadingOverlay(
              isLoading: _controller.isSaving,
              message: 'Saving — TomSlowValidator pending…',
              child: SizedBox(
                height: 260,
                // The list renderer decides when "no rows" shows:
                // TomEmptyState has no bindings of its own and is simply
                // what the list form's emptyBuilder returns.
                child: SingleChildScrollView(
                  child: TomInlineListForm<OrderItem, OrderItemForm>(
                    listForm: _orderForm.items,
                    rowSeparatorBuilder: (_, _) => const Divider(height: 1),
                    emptyBuilder: (_) => TomEmptyState(
                      title: 'No items',
                      description:
                          'Use Seed to insert sample rows, or +1 to '
                          'append a single row.',
                    ),
                    rowBuilder: (_, i, row) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.label_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(flex: 3, child: row.productName.widget),
                          const SizedBox(width: 8),
                          SizedBox(width: 72, child: row.quantity.widget),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _orderForm.items.removeAt(i),
                          ),
                        ],
                      ),
                    ),
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
    final theme = Theme.of(context);
    return InfoPanel(
      title: 'Phase 6 controls',
      children: [
        const InfoPanelHeading('Profile auth (TomAuthGuard)'),
        DropdownButton<TomAuthState>(
          isExpanded: true,
          value: _controller.auth,
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
            if (v != null) _controller.setAuth(v, _adapter);
          },
        ),
        const InfoPanelHeading('Items list (TomEmptyState)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: _clearItems, child: const Text('Clear')),
            OutlinedButton(onPressed: _seedItems, child: const Text('Seed')),
            OutlinedButton(onPressed: _addOne, child: const Text('+1 row')),
          ],
        ),
        const InfoPanelHeading('Loading overlay (TomLoadingOverlay)'),
        Text(
          'Press Save to run ValidationForm.save(). The username field '
          'carries an 800 ms TomSlowValidator — the items pane is overlaid '
          'until that Future resolves.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _validationForm.username.widget,
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _controller.isSaving ? null : _runSlowSave,
          icon: const Icon(Icons.save_outlined),
          label: Text(
            _controller.isSaving ? 'Saving…' : 'Save (awaits TomSlowValidator)',
          ),
        ),
      ],
    );
  }
}
