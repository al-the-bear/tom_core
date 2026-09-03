import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/customer_hd_panes.dart';
import '../common/demo_scaffold.dart';
import '../forms/customer_hd_form.dart';
import '../state/phase_hd_state.dart';

// ---------------------------------------------------------------------------
// Demo H-D — Full Customer Form with master-detail for addresses + orders
// ---------------------------------------------------------------------------

/// Exercises a deep `tom_flutter_ui` form: flat fields plus two nested
/// `TomMasterDetailListForm`s (with `TomReorderHandle` / `TomListFormToolbar`)
/// whose dirty state aggregates into one parent `CustomerHDForm`.
///
/// A single CustomerHD record is shown as a scrollable form with four
/// sections:
///
///   1. Customer info  — fullName, email, phone (direct fields)
///   2. Billing address — flat address fields on the same form
///   3. Shipping addresses — TomMasterDetailListForm: list on left, the
///      row's own ShippingAddressHDForm on right (no sibling form)
///   4. Orders — TomMasterDetailListForm: list on left, the row's own
///      OrderHDForm on right. Each order detail shows orderId / date /
///      shippingLabel plus an inline reorderable items table.
///
/// All four sections share ONE CustomerHDForm, so the form's isDirty
/// aggregates across info + billing + all shipping + all orders.
///
/// Both master panes use TomReorderHandle for drag reordering and the
/// reusable TomListFormToolbar for add / remove / move-up / move-down.
///
/// The reusable list/detail panes live in common/customer_hd_panes.dart so
/// Demo H-E can drop the same scaffolds into an edit overlay.
class DemoHDCustomerForm extends StatefulWidget {
  const DemoHDCustomerForm({super.key});

  @override
  State<DemoHDCustomerForm> createState() => _DemoHDCustomerFormState();
}

class _DemoHDCustomerFormState extends State<DemoHDCustomerForm> {
  late final CustomerHDForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHD', () => CustomerHDForm());
    _form.bind(phaseHdCustomer);
  }

  @override
  void dispose() {
    _form.dispose();
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
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
              'A full customer record bound to one CustomerHDForm. '
              'Direct fields (name, email, phone) and billing address '
              'sit at the top. Below them, two TomMasterDetailListForm '
              'instances handle: (1) the shipping addresses list with '
              'the row\'s own ShippingAddressHDForm rendered on the '
              'right, and (2) the orders list with the row\'s own '
              'OrderHDForm — including an inline reorderable items '
              'table — on the right. Each master pane uses '
              'TomListFormToolbar (Add / Remove / Move up / Move down) '
              'and TomReorderHandle for drag-and-drop reordering. Save '
              '/ Discard at the bottom covers the entire form — isDirty '
              'aggregates across all four sections.',
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
              child:
                  TomMasterDetailListForm<
                    ShippingAddressHD,
                    ShippingAddressHDForm
                  >(
                    listForm: _form.shippingAddresses,
                    masterPaneWidth: 200,
                    draggableSplitter: true,
                    minMasterPaneWidth: 140,
                    maxMasterPaneWidth: 600,
                    masterBuilder: (context, listForm, selected, selectIndex) =>
                        AddressMasterPane(
                          listForm: listForm,
                          selectedIndex: selected,
                          selectIndex: selectIndex,
                        ),
                    detailBuilder: (context, _, rowForm) =>
                        AddressDetailPane(form: rowForm),
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
              child: TomMasterDetailListForm<OrderHD, OrderHDForm>(
                listForm: _form.orders,
                masterPaneWidth: 200,
                draggableSplitter: true,
                minMasterPaneWidth: 140,
                maxMasterPaneWidth: 600,
                masterBuilder: (context, listForm, selected, selectIndex) =>
                    OrderMasterPane(
                      listForm: listForm,
                      selectedIndex: selected,
                      selectIndex: selectIndex,
                    ),
                detailBuilder: (context, _, rowForm) =>
                    OrderDetailPane(form: rowForm),
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
                        content: Text(
                          ok
                              ? 'Customer saved.'
                              : 'Validation failed — check errors.',
                        ),
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
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
