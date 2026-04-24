import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/customer_hd_form.dart';
import '../state/phase_hd_state.dart';

// ---------------------------------------------------------------------------
// Demo H-E — Customer Form with read-only lists + per-row Edit dialogs
// ---------------------------------------------------------------------------
//
// The customer info and billing address are editable in-place (identical to
// Demo H-D). The shipping addresses and orders sections show read-only
// summary rows. Each row has an "Edit" button that opens an AlertDialog
// containing the full editor form for that item.  An "Add" button on each
// section header adds a new item and immediately opens its edit dialog.
//
// Architecture note: The dialog widgets create and own their own form
// instances (ShippingAddressHDForm / OrderHDForm), bound to the same
// underlying TomClass objects as the list forms inside CustomerHDForm.
// Saves propagate back through the shared observable objects; the main
// form's dirty flag reflects mutations committed by the dialogs.
class DemoHECustomerForm extends StatefulWidget {
  const DemoHECustomerForm({super.key});

  @override
  State<DemoHECustomerForm> createState() => _DemoHECustomerFormState();
}

class _DemoHECustomerFormState extends State<DemoHECustomerForm> {
  late final CustomerHDForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHE', () => CustomerHDForm());
    _form.bind(phaseHeCustomer);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H-E — Customer Form (read-only lists + edit dialogs)',
      child: TomUnsavedChangesGuard(
        form: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: _form.changes,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _intro(context),
                const SizedBox(height: 12),
                _customerInfoCard(context),
                const SizedBox(height: 12),
                _billingAddressCard(context),
                const SizedBox(height: 12),
                _shippingAddressesCard(context),
                const SizedBox(height: 12),
                _ordersCard(context),
                const SizedBox(height: 12),
                TomErrorView(form: _form, title: 'Form errors'),
                const SizedBox(height: 12),
                _formActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
              'Same CustomerHDForm as Demo H-D, bound to an independent '
              'state instance. Customer info and billing address are '
              'editable in-place. Shipping addresses and orders are shown '
              'as compact read-only lists — each row has an "Edit" button '
              'that opens a dialog with the full editor for that item. '
              'The "Add" button in each section header adds a new item and '
              'immediately opens its dialog. Dialogs own their own form '
              'instances; saves commit back to the shared TomClass objects.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Customer info', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.fullName.widget,
            const SizedBox(height: 8),
            _form.email.widget,
            const SizedBox(height: 8),
            _form.phone.widget,
          ],
        ),
      ),
    );
  }

  Widget _billingAddressCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Billing address', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _form.billLine1.widget,
            const SizedBox(height: 8),
            _form.billLine2.widget,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _form.billCity.widget),
                const SizedBox(width: 8),
                Expanded(child: _form.billState.widget),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _form.billZip.widget),
              ],
            ),
            const SizedBox(height: 8),
            _form.billCountry.widget,
          ],
        ),
      ),
    );
  }

  Widget _shippingAddressesCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text('Shipping addresses',
                      style: theme.textTheme.titleSmall)),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                onPressed: () async {
                  _form.shippingAddresses.add();
                  final newIndex = _form.shippingAddresses.length - 1;
                  final item = _form.shippingAddresses[newIndex].currentBinding;
                  if (item != null && context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => _ShippingAddressEditDialog(
                        address: item,
                        title: 'New shipping address',
                      ),
                    );
                  }
                },
              ),
            ]),
            const SizedBox(height: 8),
            _ShippingROList(listForm: _form.shippingAddresses),
          ],
        ),
      ),
    );
  }

  Widget _ordersCard(BuildContext context) {
    final theme = Theme.of(context);
    final labelSource = _form.shippingAddressLabelSource;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text('Orders', style: theme.textTheme.titleSmall)),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                onPressed: () async {
                  _form.orders.add();
                  final newIndex = _form.orders.length - 1;
                  final item = _form.orders[newIndex].currentBinding;
                  if (item != null && context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => _OrderEditDialog(
                        order: item,
                        title: 'New order',
                        shippingLabelSource: labelSource,
                      ),
                    );
                  }
                },
              ),
            ]),
            const SizedBox(height: 8),
            _OrderROList(
              listForm: _form.orders,
              shippingLabelSource: labelSource,
            ),
          ],
        ),
      ),
    );
  }

  Widget _formActions(BuildContext context) {
    return ListenableBuilder(
      listenable: _form.changes,
      builder: (context, _) => Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save all'),
            onPressed: _form.isDirty
                ? () async {
                    final ok = await _form.save();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Customer saved.'
                            : 'Validation failed — check errors.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Discard all'),
            onPressed: _form.isDirty ? () => _form.discard() : null,
          ),
          if (_form.isDirty)
            const Chip(
                label: Text('Dirty'), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Read-only shipping address list
// ---------------------------------------------------------------------------

class _ShippingROList extends StatefulWidget {
  const _ShippingROList({required this.listForm});

  final TomListForm<ShippingAddressHD, ShippingAddressHDForm> listForm;

  @override
  State<_ShippingROList> createState() => _ShippingROListState();
}

class _ShippingROListState extends State<_ShippingROList>
    implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _ShippingROList old) {
    super.didUpdateWidget(old);
    if (old.listForm != widget.listForm) {
      old.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listForm.length == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No shipping addresses yet. Tap "Add" to add one.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    return Column(
      children: List.generate(widget.listForm.length, (i) {
        final itemForm = widget.listForm[i];
        final addr = itemForm.currentBinding;
        return TomMultiObservableBuilder(
          observables:
              addr == null ? [] : [addr.label, addr.line1, addr.city, addr.country],
          builder: (context) => Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11))),
              title: Text(
                addr?.label.get().isEmpty ?? true
                    ? '(unnamed)'
                    : addr!.label.get(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (addr?.line1.get().isNotEmpty ?? false) addr!.line1.get(),
                  if (addr?.city.get().isNotEmpty ?? false) addr!.city.get(),
                  if (addr?.country.get().isNotEmpty ?? false)
                    addr!.country.get(),
                ].join(', '),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit'),
                    onPressed: addr == null
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (_) => _ShippingAddressEditDialog(
                                address: addr,
                                title: 'Edit shipping address',
                              ),
                            ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Remove address',
                    onPressed: () => widget.listForm.removeAt(i),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Read-only order list
// ---------------------------------------------------------------------------

class _OrderROList extends StatefulWidget {
  const _OrderROList({
    required this.listForm,
    this.shippingLabelSource,
  });

  final TomListForm<OrderHD, OrderHDForm> listForm;
  final TomSelectableSource<String>? shippingLabelSource;

  @override
  State<_OrderROList> createState() => _OrderROListState();
}

class _OrderROListState extends State<_OrderROList> implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _OrderROList old) {
    super.didUpdateWidget(old);
    if (old.listForm != widget.listForm) {
      old.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listForm.length == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No orders yet. Tap "Add" to add one.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    return Column(
      children: List.generate(widget.listForm.length, (i) {
        final itemForm = widget.listForm[i];
        final order = itemForm.currentBinding;
        return TomMultiObservableBuilder(
          observables: order == null
              ? []
              : [order.orderId, order.orderDate, order.shippingLabel],
          builder: (context) => Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: CircleAvatar(
                  radius: 14,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11))),
              title: Text(
                order?.orderId.get().isEmpty ?? true
                    ? '(new order)'
                    : order!.orderId.get(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (order?.orderDate.get().isNotEmpty ?? false)
                    order!.orderDate.get(),
                  if (order?.shippingLabel.get().isNotEmpty ?? false)
                    'Ship to: ${order!.shippingLabel.get()}',
                  '${order?.items.length ?? 0} item(s)',
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit'),
                    onPressed: order == null
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (_) => _OrderEditDialog(
                                order: order,
                                title: 'Edit order',
                                shippingLabelSource:
                                    widget.shippingLabelSource,
                              ),
                            ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Remove order',
                    onPressed: () => widget.listForm.removeAt(i),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipping address edit dialog
// ---------------------------------------------------------------------------

class _ShippingAddressEditDialog extends StatefulWidget {
  const _ShippingAddressEditDialog({
    required this.address,
    required this.title,
  });

  final ShippingAddressHD address;
  final String title;

  @override
  State<_ShippingAddressEditDialog> createState() =>
      _ShippingAddressEditDialogState();
}

class _ShippingAddressEditDialogState
    extends State<_ShippingAddressEditDialog> {
  late final ShippingAddressHDForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHE', () => ShippingAddressHDForm());
    _form.bind(widget.address);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: ListenableBuilder(
          listenable: _form.changes,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _form.label.widget,
                const SizedBox(height: 8),
                _form.line1.widget,
                const SizedBox(height: 8),
                _form.line2.widget,
                const SizedBox(height: 8),
                _form.city.widget,
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _form.stateRegion.widget),
                  const SizedBox(width: 8),
                  SizedBox(width: 110, child: _form.zipCode.widget),
                ]),
                const SizedBox(height: 8),
                _form.country.widget,
                const SizedBox(height: 8),
                TomErrorView(form: _form, title: 'Address errors'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _form.discard();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await _form.save();
            if (!context.mounted) return;
            if (ok) {
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Validation failed — check errors.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Order edit dialog — metadata + inline items table
// ---------------------------------------------------------------------------

class _OrderEditDialog extends StatefulWidget {
  const _OrderEditDialog({
    required this.order,
    required this.title,
    this.shippingLabelSource,
  });

  final OrderHD order;
  final String title;
  final TomSelectableSource<String>? shippingLabelSource;

  @override
  State<_OrderEditDialog> createState() => _OrderEditDialogState();
}

class _OrderEditDialogState extends State<_OrderEditDialog>
    implements TomObserver {
  late final OrderHDForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope(
      'demoHE',
      () => OrderHDForm(shippingLabelSource: widget.shippingLabelSource),
    );
    _form.bind(widget.order);
    _form.items.addObserver(this);
  }

  @override
  void dispose() {
    _form.items.removeObserver(this);
    _form.dispose();
    super.dispose();
  }

  @override
  void onNotify(TomObservable _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 700,
        child: ListenableBuilder(
          listenable: _form.changes,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Order metadata
                Row(children: [
                  Expanded(child: _form.orderId.widget),
                  const SizedBox(width: 8),
                  Expanded(child: _form.orderDate.widget),
                ]),
                const SizedBox(height: 8),
                _form.shippingLabel.widget,
                const SizedBox(height: 12),
                // Items header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items (${_form.items.length})',
                        style: theme.textTheme.labelLarge),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add item'),
                      onPressed: () => _form.items.add(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _itemsTable(context),
                const SizedBox(height: 8),
                // Order total
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Order total: \$${_form.totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                TomErrorView(form: _form, title: 'Order errors'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _form.discard();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await _form.save();
            if (!context.mounted) return;
            if (ok) {
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Validation failed — check errors.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _itemsTable(BuildContext context) {
    final theme = Theme.of(context);
    if (_form.items.length == 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No items yet. Tap "Add item" to begin.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 72,
        dataRowMaxHeight: 120,
        columnSpacing: 8,
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Notes')),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('')),
        ],
        rows: List.generate(_form.items.length, (i) {
          final itemForm = _form.items[i];
          return DataRow(cells: [
            DataCell(SizedBox(
                width: 180,
                child: _cellStyle(itemForm.productName.widget))),
            DataCell(SizedBox(
                width: 60, child: _cellStyle(itemForm.quantity.widget))),
            DataCell(SizedBox(
                width: 80, child: _cellStyle(itemForm.unitPrice.widget))),
            DataCell(SizedBox(
                width: 120, child: _cellStyle(itemForm.notes.widget))),
            DataCell(
              ListenableBuilder(
                listenable: itemForm.changes,
                builder: (context, _) => Text(
                  '\$${itemForm.computedTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            DataCell(IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove item',
              onPressed: () => _form.items.removeAt(i),
            )),
          ]);
        }),
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
