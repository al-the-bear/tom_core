import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../forms/customer_hd_form.dart';
import '../state/phase_hd_state.dart';

// ---------------------------------------------------------------------------
// Reusable master/detail panes for the CustomerHD demos (H-D, H-E).
//
// These panes are pulled out of demo_h_d_customer_form.dart so the H-E demo
// can drop the same scaffolds into an edit overlay without duplicating any
// of the list/detail wiring.
//
// All four panes are stateless — selection is owned by the hosting
// `TomMasterDetailListForm`, list mutations are routed through the
// reusable `TomListFormToolbar`, and per-row drag handles use
// `TomReorderHandle` so the rows reorder via either the toolbar arrows
// or pointer drag.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Shipping address master pane
// ---------------------------------------------------------------------------

class AddressMasterPane extends StatelessWidget {
  const AddressMasterPane({
    super.key,
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<ShippingAddressHD, ShippingAddressHDForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text('Addresses (${listForm.length})',
                  style: theme.textTheme.titleSmall),
            ),
            const Divider(height: 8),
            Expanded(
              child: TomInlineListForm<ShippingAddressHD,
                  ShippingAddressHDForm>(
                listForm: listForm,
                reorderable: true,
                onReorder: (from, to) =>
                    _trackSelection(from, to, selectedIndex, selectIndex),
                rowBuilder: (context, i, rowForm) {
                  final addr = rowForm.currentBinding;
                  final sel = i == selectedIndex;
                  return TomMultiObservableBuilder(
                    key: ValueKey('h-d-addr-${rowForm.hashCode}'),
                    observables:
                        addr == null ? [] : [addr.label, addr.city],
                    builder: (context) => ListTile(
                      dense: true,
                      selected: sel,
                      leading: TomReorderHandle(index: i),
                      title: Text(
                        addr?.label.get().isEmpty ?? true
                            ? '(unnamed)'
                            : addr!.label.get(),
                        style: TextStyle(
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(addr?.city.get() ?? '',
                          overflow: TextOverflow.ellipsis),
                      onTap: () => selectIndex(i),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 8),
            TomListFormToolbar<ShippingAddressHD, ShippingAddressHDForm>(
              listForm: listForm,
              selectedIndex: selectedIndex,
              onSelectionChanged: selectIndex,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipping address detail pane
// ---------------------------------------------------------------------------

class AddressDetailPane extends StatelessWidget {
  const AddressDetailPane({super.key, required this.form});

  final ShippingAddressHDForm form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: form.changes,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('Address detail',
                          style: Theme.of(context).textTheme.titleSmall)),
                  if (form.isDirty)
                    const Chip(
                        label: Text('Dirty'),
                        visualDensity: VisualDensity.compact),
                ]),
                const SizedBox(height: 8),
                form.label.widget,
                const SizedBox(height: 8),
                form.line1.widget,
                const SizedBox(height: 8),
                form.line2.widget,
                const SizedBox(height: 8),
                form.city.widget,
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: form.stateRegion.widget),
                  const SizedBox(width: 8),
                  SizedBox(width: 110, child: form.zipCode.widget),
                ]),
                const SizedBox(height: 8),
                form.country.widget,
                const SizedBox(height: 12),
                TomErrorView(form: form, title: 'Address errors'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.save, size: 14),
                    label: const Text('Save'),
                    onPressed: form.isDirty
                        ? () async {
                            final ok = await form.save();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Address saved.'
                                    : 'Check errors.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Discard'),
                    onPressed:
                        form.isDirty ? () => form.discard() : null,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order master pane
// ---------------------------------------------------------------------------

class OrderMasterPane extends StatelessWidget {
  const OrderMasterPane({
    super.key,
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<OrderHD, OrderHDForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text('Orders (${listForm.length})',
                  style: theme.textTheme.titleSmall),
            ),
            const Divider(height: 8),
            Expanded(
              child: TomInlineListForm<OrderHD, OrderHDForm>(
                listForm: listForm,
                reorderable: true,
                onReorder: (from, to) =>
                    _trackSelection(from, to, selectedIndex, selectIndex),
                rowBuilder: (context, i, rowForm) {
                  final order = rowForm.currentBinding;
                  final sel = i == selectedIndex;
                  return TomMultiObservableBuilder(
                    key: ValueKey('h-d-order-${rowForm.hashCode}'),
                    observables: order == null
                        ? []
                        : [order.orderId, order.orderDate],
                    builder: (context) => ListTile(
                      dense: true,
                      selected: sel,
                      leading: TomReorderHandle(index: i),
                      title: Text(
                        order?.orderId.get().isEmpty ?? true
                            ? '(new order)'
                            : order!.orderId.get(),
                        style: TextStyle(
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(order?.orderDate.get() ?? '',
                          overflow: TextOverflow.ellipsis),
                      onTap: () => selectIndex(i),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 8),
            TomListFormToolbar<OrderHD, OrderHDForm>(
              listForm: listForm,
              selectedIndex: selectedIndex,
              onSelectionChanged: selectIndex,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order detail pane — metadata fields + inline reorderable items table
// ---------------------------------------------------------------------------

class OrderDetailPane extends StatelessWidget {
  const OrderDetailPane({super.key, required this.form});

  final OrderHDForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: form.changes,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text('Order detail',
                          style: theme.textTheme.titleSmall)),
                  if (form.isDirty)
                    const Chip(
                        label: Text('Dirty'),
                        visualDensity: VisualDensity.compact),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: form.orderId.widget),
                  const SizedBox(width: 8),
                  Expanded(child: form.orderDate.widget),
                ]),
                const SizedBox(height: 8),
                form.shippingLabel.widget,
                const SizedBox(height: 12),
                TomInlineListForm<OrderItemHD, OrderItemHDForm>(
                  listForm: form.items,
                  reorderable: true,
                  headerBuilder: (context, list) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items (${list.length})',
                            style: theme.textTheme.labelLarge),
                        TomListFormToolbar<OrderItemHD, OrderItemHDForm>(
                          listForm: list,
                          // No selection in an inline table — the
                          // toolbar's Add still appends a fresh row;
                          // Move-up / Move-down are disabled (no
                          // selection to act on).
                          showMoveUp: false,
                          showMoveDown: false,
                          showRemove: false,
                          addLabel: 'Add item',
                        ),
                      ],
                    ),
                  ),
                  emptyBuilder: (_) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No items yet. Tap "Add item" to begin.',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                  rowBuilder: (context, i, itemForm) => _ItemRow(
                    key: ValueKey('h-d-item-${itemForm.hashCode}'),
                    index: i,
                    form: itemForm,
                    listForm: form.items,
                    onRemove: () => form.items.removeAt(i),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Order total: \$${form.totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                TomErrorView(form: form, title: 'Order errors'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.save, size: 14),
                    label: const Text('Save order'),
                    onPressed: form.isDirty
                        ? () async {
                            final ok = await form.save();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Order saved.'
                                    : 'Check errors.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Discard'),
                    onPressed:
                        form.isDirty ? () => form.discard() : null,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the order-items inline list. Lives at top level so the
/// hosting [TomInlineListForm] can pass each row's own [OrderItemHDForm]
/// and a remove callback without rebuilding closures from the parent.
///
/// The row mimics a column-aligned table: drag handle on the left,
/// fixed-width cells side by side, each holding the field's own widget,
/// and a delete button on the right. The wrapping [TomFormStyleScope]
/// suppresses the per-field label+description so the column header
/// above each cell can take that role.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.index,
    required this.form,
    required this.listForm,
    required this.onRemove,
  });

  final int index;
  final OrderItemHDForm form;
  final TomListForm<OrderItemHD, OrderItemHDForm> listForm;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TomReorderHandle(index: index),
            // Per-row Move-up / Move-down arrows. The order items list
            // has no master section to host a selection-driven toolbar,
            // so the row itself owns the explicit reorder controls.
            TomListRowMoveButtons<OrderItemHD, OrderItemHDForm>(
              listForm: listForm,
              index: index,
            ),
            const SizedBox(width: 4),
            SizedBox(
                width: 180, child: _cellStyle(form.productName.widget)),
            const SizedBox(width: 8),
            SizedBox(
                width: 60, child: _cellStyle(form.quantity.widget)),
            const SizedBox(width: 8),
            SizedBox(
                width: 80, child: _cellStyle(form.unitPrice.widget)),
            const SizedBox(width: 8),
            SizedBox(
                width: 120, child: _cellStyle(form.notes.widget)),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: ListenableBuilder(
                listenable: form.changes,
                builder: (context, _) => Text(
                  '\$${form.computedTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove item',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  /// Suppresses the field's outer label+description anatomy so cells
  /// stay compact — the column header takes the role of the label.
  Widget _cellStyle(Widget fieldWidget) {
    return TomFormStyleScope(
      tomId: 'orderItems',
      style: TomFormStyle.material3.copyWith(
        defaults: TomFormStyle.material3.defaults.copyWith(
          descriptionPlacement: DescriptionPlacement.tooltip,
        ),
      ),
      child: fieldWidget,
    );
  }
}

// ---------------------------------------------------------------------------
// Selection-tracking helper used by both master panes after a drag-reorder.
// Keeps the user's selected row pinned to whichever index the dragged row
// landed on, and shifts neighbouring selections accordingly.
// ---------------------------------------------------------------------------

void _trackSelection(
  int from,
  int to,
  int? selectedIndex,
  Future<void> Function(int? index) selectIndex,
) {
  final next = reorderedSelectionIndex(from, to, selectedIndex);
  if (next != null) selectIndex(next);
}

/// Pure index arithmetic behind [_trackSelection]: given a drag-reorder that
/// moved a row from [from] to [to], returns the index the currently
/// [selectedIndex] row should track to, or `null` when the reorder leaves the
/// selection where it is (including when nothing is selected).
///
/// The three shifting cases:
/// - the selected row *is* the dragged row (`selectedIndex == from`) → it
///   follows the drag to [to];
/// - a down-move (`from < to`) sliding past the selection
///   (`from < selectedIndex <= to`) shifts it one step up (`selectedIndex - 1`);
/// - an up-move (`from > to`) sliding past the selection
///   (`to <= selectedIndex < from`) shifts it one step down (`selectedIndex + 1`).
///
/// Any other selection is unaffected by the reorder, hence `null`.
@visibleForTesting
int? reorderedSelectionIndex(int from, int to, int? selectedIndex) {
  if (selectedIndex == null) return null;
  if (selectedIndex == from) return to;
  if (from < selectedIndex && selectedIndex <= to) return selectedIndex - 1;
  if (to <= selectedIndex && selectedIndex < from) return selectedIndex + 1;
  return null;
}
