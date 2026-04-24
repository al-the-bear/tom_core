import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/customer_hd_form.dart';
import '../state/phase_hd_state.dart';

// ---------------------------------------------------------------------------
// Demo H-D — Full Customer Form with master-detail for addresses + orders
// ---------------------------------------------------------------------------
//
// A single CustomerHD record is shown as a scrollable form with four
// sections:
//
//   1. Customer info  — fullName, email, phone (direct fields)
//   2. Billing address — flat address fields on the same form
//   3. Shipping addresses — TomMasterDetailScaffold: list on left, full
//      ShippingAddressHDForm on right
//   4. Orders — TomMasterDetailScaffold: list on left, OrderHDForm on right
//      The order detail pane shows orderId / date / shippingLabel plus an
//      inline items table (add / remove / edit all rows in place).
//
// All four sections share ONE CustomerHDForm, so the form's isDirty
// aggregates across info + billing + all shipping + all orders.
class DemoHDCustomerForm extends StatefulWidget {
  const DemoHDCustomerForm({super.key});

  @override
  State<DemoHDCustomerForm> createState() => _DemoHDCustomerFormState();
}

class _DemoHDCustomerFormState extends State<DemoHDCustomerForm> {
  late final CustomerHDForm _form;

  // Each master-detail scaffold needs its own stand-alone detail form that
  // gets rebound to the selected item. The list forms inside _form track
  // dirty state across all rows; the scaffold's detailForm is what the
  // user actually edits.
  late final ShippingAddressHDForm _shippingDetail;
  late final OrderHDForm _orderDetail;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHD', () => CustomerHDForm());
    _shippingDetail =
        TomScope.withScope('demoHD', () => ShippingAddressHDForm());
    // createOrderDetailForm() pre-wires the shipping address picker so the
    // "Ship to" field lists the customer's current addresses.
    _orderDetail =
        TomScope.withScope('demoHD', () => _form.createOrderDetailForm());
    _form.bind(phaseHdCustomer);
  }

  @override
  void dispose() {
    _form.dispose();
    _shippingDetail.dispose();
    _orderDetail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H-D — Customer Form (master-detail)',
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
            Text('What this demo covers',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
              'A full customer record bound to one CustomerHDForm. '
              'Direct fields (name, email, phone) and billing address '
              'sit at the top. Below them, two TomMasterDetailScaffold '
              'instances handle: (1) the shipping addresses list with a '
              'full address editor on the right, and (2) the orders list '
              'with order metadata + an inline DataTable of line items '
              'on the right. Save / Discard at the bottom covers the '
              'entire form — isDirty aggregates across all four sections.',
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
            Text('Shipping addresses', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 380,
              child: TomMasterDetailScaffold<ShippingAddressHD,
                  ShippingAddressHDForm>(
                listForm: _form.shippingAddresses,
                detailForm: _shippingDetail,
                masterPaneWidth: 200,
                masterBuilder:
                    (context, listForm, selected, selectIndex) =>
                        _AddressMasterPane(
                  listForm: listForm,
                  selectedIndex: selected,
                  selectIndex: selectIndex,
                ),
                detailBuilder: (context, form) =>
                    _AddressDetailPane(form: form),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Orders', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 560,
              child: TomMasterDetailScaffold<OrderHD, OrderHDForm>(
                listForm: _form.orders,
                detailForm: _orderDetail,
                masterPaneWidth: 200,
                masterBuilder:
                    (context, listForm, selected, selectIndex) =>
                        _OrderMasterPane(
                  listForm: listForm,
                  selectedIndex: selected,
                  selectIndex: selectIndex,
                ),
                detailBuilder: (context, form) =>
                    _OrderDetailPane(form: form),
              ),
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
                label: Text('Dirty'),
                visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipping address master pane
// ---------------------------------------------------------------------------

class _AddressMasterPane extends StatefulWidget {
  const _AddressMasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<ShippingAddressHD, ShippingAddressHDForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  State<_AddressMasterPane> createState() => _AddressMasterPaneState();
}

class _AddressMasterPaneState extends State<_AddressMasterPane>
    implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _AddressMasterPane old) {
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                  'Addresses (${widget.listForm.length})',
                  style: theme.textTheme.titleSmall),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.listForm.length,
                itemBuilder: (context, i) {
                  final addr = widget.listForm[i].currentBinding;
                  final sel = i == widget.selectedIndex;
                  return TomMultiObservableBuilder(
                    observables: addr == null
                        ? []
                        : [addr.label, addr.city],
                    builder: (context) => ListTile(
                      dense: true,
                      selected: sel,
                      leading: CircleAvatar(
                          radius: 12,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 10))),
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
                      subtitle: Text(
                          addr?.city.get() ?? '',
                          overflow: TextOverflow.ellipsis),
                      onTap: () => widget.selectIndex(i),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 8),
            Wrap(spacing: 6, children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                onPressed: () async {
                  widget.listForm.add();
                  await widget.selectIndex(widget.listForm.length - 1);
                },
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Remove'),
                onPressed: widget.selectedIndex == null
                    ? null
                    : () async {
                        widget.listForm.removeAt(widget.selectedIndex!);
                        await widget.selectIndex(null);
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipping address detail pane
// ---------------------------------------------------------------------------

class _AddressDetailPane extends StatelessWidget {
  const _AddressDetailPane({required this.form});

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
                                duration:
                                    const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Discard'),
                    onPressed: form.isDirty ? () => form.discard() : null,
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

class _OrderMasterPane extends StatefulWidget {
  const _OrderMasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<OrderHD, OrderHDForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  State<_OrderMasterPane> createState() => _OrderMasterPaneState();
}

class _OrderMasterPaneState extends State<_OrderMasterPane>
    implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _OrderMasterPane old) {
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text('Orders (${widget.listForm.length})',
                  style: theme.textTheme.titleSmall),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.listForm.length,
                itemBuilder: (context, i) {
                  final order = widget.listForm[i].currentBinding;
                  final sel = i == widget.selectedIndex;
                  return TomMultiObservableBuilder(
                    observables: order == null
                        ? []
                        : [order.orderId, order.orderDate],
                    builder: (context) => ListTile(
                      dense: true,
                      selected: sel,
                      leading: CircleAvatar(
                          radius: 12,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 10))),
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
                      subtitle: Text(
                          order?.orderDate.get() ?? '',
                          overflow: TextOverflow.ellipsis),
                      onTap: () => widget.selectIndex(i),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 8),
            Wrap(spacing: 6, children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                onPressed: () async {
                  widget.listForm.add();
                  await widget.selectIndex(widget.listForm.length - 1);
                },
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Remove'),
                onPressed: widget.selectedIndex == null
                    ? null
                    : () async {
                        widget.listForm.removeAt(widget.selectedIndex!);
                        await widget.selectIndex(null);
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order detail pane — metadata fields + inline items table
// ---------------------------------------------------------------------------

class _OrderDetailPane extends StatefulWidget {
  const _OrderDetailPane({required this.form});

  final OrderHDForm form;

  @override
  State<_OrderDetailPane> createState() => _OrderDetailPaneState();
}

class _OrderDetailPaneState extends State<_OrderDetailPane>
    implements TomObserver {
  OrderHDForm get form => widget.form;

  @override
  void initState() {
    super.initState();
    form.items.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _OrderDetailPane old) {
    super.didUpdateWidget(old);
    if (old.form.items != form.items) {
      old.form.items.removeObserver(this);
      form.items.addObserver(this);
    }
  }

  @override
  void dispose() {
    form.items.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable _) {
    if (mounted) setState(() {});
  }

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
                // Order metadata
                Row(children: [
                  Expanded(child: form.orderId.widget),
                  const SizedBox(width: 8),
                  Expanded(child: form.orderDate.widget),
                ]),
                const SizedBox(height: 8),
                form.shippingLabel.widget,
                const SizedBox(height: 12),
                // Inline items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items (${form.items.length})',
                        style: theme.textTheme.labelLarge),
                    Wrap(spacing: 6, children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add item'),
                        onPressed: () => form.items.add(),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                _itemsTable(context),
                const SizedBox(height: 8),
                // Order total readout
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
                                duration:
                                    const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text('Discard'),
                    onPressed: form.isDirty ? () => form.discard() : null,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemsTable(BuildContext context) {
    final theme = Theme.of(context);
    if (form.items.length == 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No items yet. Tap "Add item" to begin.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    // Render items in a compact inline DataTable.
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
        rows: List.generate(form.items.length, (i) {
          final itemForm = form.items[i];
          return DataRow(cells: [
            DataCell(SizedBox(
                width: 180,
                child: _cellStyle(itemForm.productName.widget))),
            DataCell(
                SizedBox(width: 60, child: _cellStyle(itemForm.quantity.widget))),
            DataCell(SizedBox(
                width: 80,
                child: _cellStyle(itemForm.unitPrice.widget))),
            DataCell(
                SizedBox(width: 120, child: _cellStyle(itemForm.notes.widget))),
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
              onPressed: () => form.items.removeAt(i),
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
