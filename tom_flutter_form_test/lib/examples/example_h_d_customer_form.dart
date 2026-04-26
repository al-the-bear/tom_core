import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'example_list_screen.dart';
import 'forms/example_customer_rich_form.dart';
import 'shared/example_authorization.dart';
import 'shared/example_scaffold.dart';
import 'state/example_state.dart';

// ---------------------------------------------------------------------------
// Example H-D — Full Customer Form (Material + Cupertino in one file)
// ---------------------------------------------------------------------------
//
// One root form bound to the rich `ExampleCustomerRich` graph that exercises
// every concrete field family the form layer ships:
//
//   string  → fullName, email, phone, company
//   search  → tier
//   bool    → vip
//   int     → loyaltyPoints
//   double  → creditLimit
//   date    → memberSince
//   list    → addresses, orders (each with their own sub-form)
//
// The screen is laid out as three vertical sections:
//
//   1. Customer info — flat fields rendered through `AclBuilder`. The
//      builder owns the breakpoint logic: long rows of int / double /
//      date controls collapse to one column when the viewport drops
//      below 700 px.
//   2. Addresses — master-detail list, the row's own ExampleAddressForm
//      on the right.
//   3. Orders — master-detail list. Each order is itself an editable form
//      with its own items list.
//
// Every interactive control is built through `FormFieldFamily`, so the
// only difference between the Material and Cupertino entries is the
// `family` value passed at construction time. Static auth (read-only
// email, disabled tier) is installed in `initState`.
class ExampleHDCustomerForm extends StatefulWidget {
  const ExampleHDCustomerForm({super.key, required this.family});

  final ExampleFamily family;

  @override
  State<ExampleHDCustomerForm> createState() => _ExampleHDCustomerFormState();
}

class _ExampleHDCustomerFormState extends State<ExampleHDCustomerForm> {
  late final FormFieldFamily _family;
  late final ExampleCustomerRichForm _form;

  @override
  void initState() {
    super.initState();
    installExampleAuthorization();
    _family = widget.family == ExampleFamily.cupertino
        ? FormFieldFamily.cupertino
        : FormFieldFamily.material;
    _form = ExampleCustomerRichForm(family: _family);
    _form.bind(exampleCustomerHd);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyLabel = widget.family == ExampleFamily.cupertino
        ? 'Cupertino'
        : 'Material';

    return TomFormStyleScope(
      style: widget.family == ExampleFamily.cupertino
          ? TomCupertinoFormStyle.cupertino
          : null,
      child: ExampleScaffold(
        title: 'Example H-D · $familyLabel',
        child: ListenableBuilder(
          listenable: _form.changes,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CustomerInfoCard(form: _form),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: _AddressesCard(form: _form, family: _family),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 540,
                  child: _OrdersCard(form: _form, family: _family),
                ),
                const SizedBox(height: 12),
                TomErrorView(form: _form, title: 'Form errors'),
                const SizedBox(height: 12),
                _FormActions(form: _form),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 1 — Customer info, AclBuilder with a breakpoint-stacking row.
// ---------------------------------------------------------------------------
class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({required this.form});

  final ExampleCustomerRichForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // AclBuilder owns the layout: defaults set the row height and the
    // gap between siblings; per-row breakpoints stack sibling fields
    // vertically when the viewport is narrow.
    final acl = AclBuilder()
      ..setAclDefaultAppendGap(8)
      ..setAclExpandXDefault(true);

    acl.append(form.fullName.widget);

    acl.newRow();
    acl.append(form.email.widget);
    acl.append(form.phone.widget);
    acl.addRowBreakpoint(atWidth: 700);

    acl.newRow();
    acl.append(form.company.widget);
    acl.append(form.tier.widget);
    acl.addRowBreakpoint(atWidth: 700);

    // The numeric / date row collapses at the same breakpoint — three
    // controls is a wider row than two strings.
    acl.newRow();
    acl.append(form.loyaltyPoints.widget);
    acl.append(form.creditLimit.widget);
    acl.append(form.memberSince.widget);
    acl.addRowBreakpoint(atWidth: 700);

    acl.newRow();
    acl.append(form.vip.widget);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Customer', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            acl.build(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 2 — Addresses, master-detail.
// ---------------------------------------------------------------------------
class _AddressesCard extends StatelessWidget {
  const _AddressesCard({required this.form, required this.family});

  final ExampleCustomerRichForm form;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TomMasterDetailListForm<ExampleAddress, ExampleAddressForm>(
          listForm: form.addresses,
          masterPaneWidth: 220,
          draggableSplitter: true,
          minMasterPaneWidth: 160,
          maxMasterPaneWidth: 480,
          initialSelectedIndex: form.addresses.isEmpty ? null : 0,
          masterBuilder: (context, listForm, selected, selectIndex) =>
              _AddressMaster(
            listForm: listForm,
            selectedIndex: selected,
            selectIndex: selectIndex,
          ),
          detailBuilder: (context, _, rowForm) =>
              _AddressDetail(form: rowForm),
        ),
      ),
    );
  }
}

class _AddressMaster extends StatelessWidget {
  const _AddressMaster({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<ExampleAddress, ExampleAddressForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text('Addresses (${listForm.length})',
              style: theme.textTheme.titleSmall),
        ),
        const Divider(height: 8),
        Expanded(
          child: TomInlineListForm<ExampleAddress, ExampleAddressForm>(
            listForm: listForm,
            reorderable: true,
            rowBuilder: (context, i, rowForm) {
              final addr = rowForm.currentBinding;
              if (addr == null) return const ListTile(title: Text('(unbound)'));
              final sel = i == selectedIndex;
              return TomMultiObservableBuilder(
                key: ValueKey('example-h-d-addr-${rowForm.hashCode}'),
                observables: [addr.label, addr.city],
                builder: (context) => ListTile(
                  dense: true,
                  selected: sel,
                  leading: TomReorderHandle(index: i),
                  title: Text(
                    addr.label.get().isEmpty
                        ? '(unnamed)'
                        : addr.label.get(),
                    style: TextStyle(
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(addr.city.get(),
                      overflow: TextOverflow.ellipsis),
                  onTap: () => selectIndex(i),
                ),
              );
            },
          ),
        ),
        const Divider(height: 8),
        TomListFormToolbar<ExampleAddress, ExampleAddressForm>(
          listForm: listForm,
          selectedIndex: selectedIndex,
          onSelectionChanged: selectIndex,
        ),
      ],
    );
  }
}

class _AddressDetail extends StatelessWidget {
  const _AddressDetail({required this.form});

  final ExampleAddressForm form;

  @override
  Widget build(BuildContext context) {
    final acl = AclBuilder()
      ..setAclDefaultAppendGap(8)
      ..setAclExpandXDefault(true);

    acl.append(form.label.widget);

    acl.newRow();
    acl.append(form.line1.widget);

    acl.newRow();
    acl.append(form.city.widget);
    acl.append(form.country.widget);
    acl.addRowBreakpoint(atWidth: 480);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListenableBuilder(
        listenable: form.changes,
        builder: (context, _) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              acl.build(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                    onPressed: () => form.save(),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Discard'),
                    onPressed: () => form.discard(),
                  ),
                  if (form.isDirty)
                    const Chip(
                      label: Text('Dirty'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 3 — Orders, master-detail.  Detail pane is itself a form
// that owns an inline items list.
// ---------------------------------------------------------------------------
class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.form, required this.family});

  final ExampleCustomerRichForm form;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TomMasterDetailListForm<ExampleOrder, ExampleOrderForm>(
          listForm: form.orders,
          masterPaneWidth: 240,
          draggableSplitter: true,
          minMasterPaneWidth: 180,
          maxMasterPaneWidth: 520,
          initialSelectedIndex: form.orders.isEmpty ? null : 0,
          masterBuilder: (context, listForm, selected, selectIndex) =>
              _OrderMaster(
            listForm: listForm,
            selectedIndex: selected,
            selectIndex: selectIndex,
          ),
          detailBuilder: (context, _, rowForm) =>
              _OrderDetail(form: rowForm),
        ),
      ),
    );
  }
}

class _OrderMaster extends StatelessWidget {
  const _OrderMaster({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<ExampleOrder, ExampleOrderForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text('Orders (${listForm.length})',
              style: theme.textTheme.titleSmall),
        ),
        const Divider(height: 8),
        Expanded(
          child: TomInlineListForm<ExampleOrder, ExampleOrderForm>(
            listForm: listForm,
            reorderable: true,
            rowBuilder: (context, i, rowForm) {
              final o = rowForm.currentBinding;
              if (o == null) return const ListTile(title: Text('(unbound)'));
              final sel = i == selectedIndex;
              return LayoutBuilder(builder: (context, constraints) {
                // Wider master → richer master rows.
                final showSubtitle = constraints.maxWidth >= 240;
                return TomMultiObservableBuilder(
                  key: ValueKey('example-h-d-order-${rowForm.hashCode}'),
                  observables: [o.orderId, o.priority, o.paid],
                  builder: (context) => ListTile(
                    dense: true,
                    selected: sel,
                    leading: TomReorderHandle(index: i),
                    title: Text(
                      o.orderId.get().isEmpty ? '(no id)' : o.orderId.get(),
                      style: TextStyle(
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: showSubtitle
                        ? Text(
                            '${o.priority.get()} · '
                            '${o.paid.get() ? "paid" : "unpaid"}',
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: o.paid.get()
                        ? const Icon(Icons.check_circle, size: 18)
                        : null,
                    onTap: () => selectIndex(i),
                  ),
                );
              });
            },
          ),
        ),
        const Divider(height: 8),
        TomListFormToolbar<ExampleOrder, ExampleOrderForm>(
          listForm: listForm,
          selectedIndex: selectedIndex,
          onSelectionChanged: selectIndex,
        ),
      ],
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.form});

  final ExampleOrderForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = AclBuilder()
      ..setAclDefaultAppendGap(8)
      ..setAclExpandXDefault(true);

    header.append(form.orderId.widget);
    header.append(form.orderDate.widget);
    header.addRowBreakpoint(atWidth: 480);

    header.newRow();
    header.append(form.priority.widget);
    header.append(form.paid.widget);
    header.addRowBreakpoint(atWidth: 480);

    return ListenableBuilder(
      listenable: form.changes,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header.build(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Items', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text('Total: \$${form.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const Divider(height: 12),
            TomInlineListForm<ExampleOrderItem, ExampleOrderItemForm>(
              listForm: form.items,
              reorderable: true,
              rowBuilder: (context, i, itemForm) =>
                  _OrderItemRow(index: i, form: itemForm),
            ),
            TomListFormToolbar<ExampleOrderItem, ExampleOrderItemForm>(
              listForm: form.items,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                  onPressed: () => form.save(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Discard'),
                  onPressed: () => form.discard(),
                ),
                if (form.isDirty)
                  const Chip(
                    label: Text('Dirty'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.index, required this.form});

  final int index;
  final ExampleOrderItemForm form;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: form.changes,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TomReorderHandle(index: index),
            ),
            const SizedBox(width: 4),
            Expanded(flex: 4, child: form.productName.widget),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: form.quantity.widget),
            const SizedBox(width: 8),
            SizedBox(width: 110, child: form.unitPrice.widget),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form actions — Save / Discard for the entire root form.
// ---------------------------------------------------------------------------
class _FormActions extends StatelessWidget {
  const _FormActions({required this.form});

  final ExampleCustomerRichForm form;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Save'),
          onPressed: () => form.save(),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Discard'),
          onPressed: () => form.discard(),
        ),
        if (form.isDirty)
          const Chip(
            label: Text('Dirty'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
