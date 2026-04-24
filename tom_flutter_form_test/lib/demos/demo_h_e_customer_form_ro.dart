import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/customer_hd_panes.dart';
import '../common/demo_scaffold.dart';
import '../forms/customer_hd_form.dart';
import '../state/phase_hd_state.dart';

// ---------------------------------------------------------------------------
// Demo H-E — Customer Form with read-only lists + master-detail edit overlays
// ---------------------------------------------------------------------------
//
// Customer info and billing address are editable in-place (identical to
// Demo H-D). The shipping addresses and orders sections show fully
// read-only summary lists. Each section header has a single "Edit list"
// button that opens a modal overlay containing a TomMasterDetailScaffold
// (master list on the left, full editor on the right) — the same panes
// used by Demo H-D, but presented as a focused editing surface.
//
// Adding and removing items happens inside the overlay. Closing the
// overlay returns the user to the read-only summary which immediately
// reflects all changes (the overlay edits the same TomClass instances).
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
      title: 'Demo H-E — Customer Form (read-only lists + edit overlays)',
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
              'as compact read-only lists; each section header has an '
              '"Edit list" button that opens a modal overlay with the '
              'full master-detail editor (add, remove, edit). Closing '
              'the overlay returns to the read-only summary, which '
              'immediately reflects all changes.',
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
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit list'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      _ShippingEditOverlay(listForm: _form.shippingAddresses),
                ),
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
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit list'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _OrderEditOverlay(parentForm: _form),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _OrderROList(listForm: _form.orders),
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
        child: Text(
            'No shipping addresses yet. Tap "Edit list" to add one.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    return Column(
      children: List.generate(widget.listForm.length, (i) {
        final itemForm = widget.listForm[i];
        final addr = itemForm.currentBinding;
        return TomMultiObservableBuilder(
          observables: addr == null
              ? []
              : [addr.label, addr.line1, addr.city, addr.country],
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
                  child:
                      Text('${i + 1}', style: const TextStyle(fontSize: 11))),
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
  const _OrderROList({required this.listForm});

  final TomListForm<OrderHD, OrderHDForm> listForm;

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
        child: Text('No orders yet. Tap "Edit list" to add one.',
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
                  child:
                      Text('${i + 1}', style: const TextStyle(fontSize: 11))),
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
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipping addresses edit overlay
// ---------------------------------------------------------------------------

class _ShippingEditOverlay extends StatefulWidget {
  const _ShippingEditOverlay({required this.listForm});

  final TomListForm<ShippingAddressHD, ShippingAddressHDForm> listForm;

  @override
  State<_ShippingEditOverlay> createState() => _ShippingEditOverlayState();
}

class _ShippingEditOverlayState extends State<_ShippingEditOverlay> {
  late final ShippingAddressHDForm _detail;

  @override
  void initState() {
    super.initState();
    _detail = TomScope.withScope('demoHE', () => ShippingAddressHDForm());
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text('Edit shipping addresses',
                        style: theme.textTheme.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: TomMasterDetailScaffold<ShippingAddressHD,
                    ShippingAddressHDForm>(
                  listForm: widget.listForm,
                  detailForm: _detail,
                  masterPaneWidth: 220,
                  masterBuilder:
                      (context, listForm, selected, selectIndex) =>
                          AddressMasterPane(
                    listForm: listForm,
                    selectedIndex: selected,
                    selectIndex: selectIndex,
                  ),
                  detailBuilder: (context, form) =>
                      AddressDetailPane(form: form),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orders edit overlay
// ---------------------------------------------------------------------------

class _OrderEditOverlay extends StatefulWidget {
  const _OrderEditOverlay({required this.parentForm});

  final CustomerHDForm parentForm;

  @override
  State<_OrderEditOverlay> createState() => _OrderEditOverlayState();
}

class _OrderEditOverlayState extends State<_OrderEditOverlay> {
  late final OrderHDForm _detail;

  @override
  void initState() {
    super.initState();
    // createOrderDetailForm() pre-wires the shipping address picker so the
    // "Ship to" field lists the customer's current addresses.
    _detail = TomScope.withScope(
        'demoHE', () => widget.parentForm.createOrderDetailForm());
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text('Edit orders',
                        style: theme.textTheme.titleMedium)),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: TomMasterDetailScaffold<OrderHD, OrderHDForm>(
                  listForm: widget.parentForm.orders,
                  detailForm: _detail,
                  masterPaneWidth: 220,
                  masterBuilder:
                      (context, listForm, selected, selectIndex) =>
                          OrderMasterPane(
                    listForm: listForm,
                    selectedIndex: selected,
                    selectIndex: selectIndex,
                  ),
                  detailBuilder: (context, form) =>
                      OrderDetailPane(form: form),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
