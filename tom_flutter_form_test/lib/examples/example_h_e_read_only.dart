import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'example_list_screen.dart';
import 'forms/example_customer_rich_form.dart';
import 'shared/example_authorization.dart';
import 'shared/example_scaffold.dart';
import 'state/example_state.dart';

// ---------------------------------------------------------------------------
// Example H-E — Read-only Customer with Edit Dialogs
// ---------------------------------------------------------------------------
//
// Same data graph as H-D (the rich `ExampleCustomerRich`) but rendered
// as compact read-only rows. Editing happens out-of-band: a per-row
// "Edit" button opens a modal dialog that hosts an editable
// sub-form bound to the same business object. Saving the dialog's form
// commits straight back into the master state; cancelling rolls back.
//
// Why this pattern matters for examples:
//
//   * Demonstrates the standard "view + edit overlay" idiom: read-only
//     rows for skim-friendliness, modal forms for focused editing.
//   * Shows how a single business object can host two TomForm instances
//     during the dialog's lifetime — the screen-level read-only form
//     and the dialog's editable form — without conflicting state.
//   * Works identically for nested lists: the addresses and orders
//     sections re-use the same `_RowDialog` plumbing.
//
// Like every other example, the only difference between Material and
// Cupertino is the `family` value passed in.
class ExampleHEReadOnly extends StatefulWidget {
  const ExampleHEReadOnly({super.key, required this.family});

  final ExampleFamily family;

  @override
  State<ExampleHEReadOnly> createState() => _ExampleHEReadOnlyState();
}

class _ExampleHEReadOnlyState extends State<ExampleHEReadOnly> {
  late final FormFieldFamily _family;

  /// The customer is bound directly — there is no top-level form, only
  /// the dialogs hold transient forms over short edits. We listen to the
  /// observable graph so the read-only rows refresh after every save.
  late final ExampleCustomerRich _customer;

  @override
  void initState() {
    super.initState();
    installExampleAuthorization();
    _family = widget.family == ExampleFamily.cupertino
        ? FormFieldFamily.cupertino
        : FormFieldFamily.material;
    _customer = exampleCustomerHe;
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
        title: 'Example H-E · $familyLabel',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CustomerCard(customer: _customer, family: _family),
            const SizedBox(height: 12),
            _AddressesCard(customer: _customer, family: _family),
            const SizedBox(height: 12),
            _OrdersCard(customer: _customer, family: _family),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer card — read-only rows + a single "Edit" button that opens an
// editable form bound to the same customer.
// ---------------------------------------------------------------------------
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.family});

  final ExampleCustomerRich customer;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TomMultiObservableBuilder(
          observables: [
            customer.fullName,
            customer.email,
            customer.phone,
            customer.company,
            customer.tier,
            customer.vip,
            customer.loyaltyPoints,
            customer.creditLimit,
            customer.memberSince,
          ],
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Customer', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    onPressed: () => _editCustomer(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ReadOnlyGrid(rows: [
                ('Full name', customer.fullName.get()),
                ('Email', customer.email.get()),
                ('Phone', customer.phone.get()),
                ('Company', customer.company.get()),
                ('Tier', customer.tier.get()),
                ('VIP', customer.vip.get() ? 'yes' : 'no'),
                ('Loyalty', customer.loyaltyPoints.get().toString()),
                (
                  'Credit limit',
                  '\$${customer.creditLimit.get().toStringAsFixed(2)}'
                ),
                ('Member since', _shortDate(customer.memberSince.get())),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editCustomer(BuildContext context) async {
    // Build a fresh form for the dialog only. The form binds straight
    // back to `customer`, so saving inside the dialog updates the
    // underlying observable and the read-only rows redraw.
    final form = ExampleCustomerRichForm(family: family)..bind(customer);
    await _RowDialog.show(
      context: context,
      title: 'Edit customer',
      form: form,
      builder: (ctx) {
        final acl = AclBuilder()
          ..setAclDefaultAppendGap(8)
          ..setAclDefaultRowHeight(56)
          ..setAclExpandXDefault(true);

        acl.append(form.fullName.widget);

        acl.newRow();
        acl.append(form.email.widget);
        acl.append(form.phone.widget);
        acl.addRowBreakpoint(atWidth: 600);

        acl.newRow();
        acl.append(form.company.widget);
        acl.append(form.tier.widget);
        acl.addRowBreakpoint(atWidth: 600);

        acl.newRow();
        acl.append(form.loyaltyPoints.widget);
        acl.append(form.creditLimit.widget);
        acl.append(form.memberSince.widget);
        acl.addRowBreakpoint(atWidth: 600);

        acl.newRow();
        acl.append(form.vip.widget);

        return acl.build();
      },
    );
    form.dispose();
  }
}

// ---------------------------------------------------------------------------
// Addresses card — read-only rows + per-row Edit button.  Add/Remove
// actions go directly through the observable list so a list-form is
// only created when the user opens an Edit dialog.
// ---------------------------------------------------------------------------
class _AddressesCard extends StatelessWidget {
  const _AddressesCard({required this.customer, required this.family});

  final ExampleCustomerRich customer;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TomMultiObservableBuilder(
          observables: [customer.addresses],
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Addresses (${customer.addresses.length})',
                      style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _addAddress(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...List.generate(customer.addresses.length,
                  (i) => _addressRow(context, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressRow(BuildContext context, int index) {
    final addr = customer.addresses[index];
    return TomMultiObservableBuilder(
      observables: [addr.label, addr.line1, addr.city, addr.country],
      builder: (context) => ListTile(
        dense: true,
        title: Text(addr.label.get().isEmpty ? '(unnamed)' : addr.label.get()),
        subtitle: Text(
          [addr.line1.get(), addr.city.get(), addr.country.get()]
              .where((p) => p.isNotEmpty)
              .join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Edit',
              onPressed: () => _editAddress(context, addr),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove',
              onPressed: () => customer.addresses.removeAt(index),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAddress(BuildContext context) async {
    final addr = ExampleAddress();
    addr.label | 'New location';
    addr.line1 | '';
    addr.city | '';
    addr.country | '';
    customer.addresses.add(addr);
    await _editAddress(context, addr);
  }

  Future<void> _editAddress(
      BuildContext context, ExampleAddress addr) async {
    final form = ExampleAddressForm(family: family)..bind(addr);
    await _RowDialog.show(
      context: context,
      title: 'Edit address',
      form: form,
      builder: (ctx) {
        final acl = AclBuilder()
          ..setAclDefaultAppendGap(8)
          ..setAclDefaultRowHeight(56)
          ..setAclExpandXDefault(true);

        acl.append(form.label.widget);
        acl.newRow();
        acl.append(form.line1.widget);
        acl.newRow();
        acl.append(form.city.widget);
        acl.append(form.country.widget);
        acl.addRowBreakpoint(atWidth: 480);

        return acl.build();
      },
    );
    form.dispose();
  }
}

// ---------------------------------------------------------------------------
// Orders card — read-only rows + per-row Edit button.  Same pattern as
// addresses; the dialog form opens an editable order with its own
// inline items list.
// ---------------------------------------------------------------------------
class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.customer, required this.family});

  final ExampleCustomerRich customer;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TomMultiObservableBuilder(
          observables: [customer.orders],
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Orders (${customer.orders.length})',
                      style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _addOrder(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...List.generate(customer.orders.length,
                  (i) => _orderRow(context, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderRow(BuildContext context, int index) {
    final order = customer.orders[index];
    return TomMultiObservableBuilder(
      observables: [
        order.orderId,
        order.orderDate,
        order.priority,
        order.paid,
        order.items,
      ],
      builder: (context) {
        var total = 0.0;
        for (var i = 0; i < order.items.length; i++) {
          final item = order.items[i];
          total += item.quantity.get() * item.unitPrice.get();
        }
        return ListTile(
          dense: true,
          title: Text(order.orderId.get().isEmpty
              ? '(no id)'
              : order.orderId.get()),
          subtitle: Text(
            '${_shortDate(order.orderDate.get())} · '
            '${order.priority.get()} · '
            '${order.items.length} item(s) · '
            '\$${total.toStringAsFixed(2)} · '
            '${order.paid.get() ? "paid" : "unpaid"}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit',
                onPressed: () => _editOrder(context, order),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Remove',
                onPressed: () => customer.orders.removeAt(index),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addOrder(BuildContext context) async {
    final order = ExampleOrder();
    final now = DateTime.now();
    order.orderId | 'ORD-${now.millisecondsSinceEpoch % 10000}';
    order.orderDate | now;
    order.priority | 'standard';
    order.paid | false;
    customer.orders.add(order);
    await _editOrder(context, order);
  }

  Future<void> _editOrder(BuildContext context, ExampleOrder order) async {
    final form = ExampleOrderForm(family: family)..bind(order);
    await _RowDialog.show(
      context: context,
      title: 'Edit order',
      form: form,
      builder: (ctx) {
        final acl = AclBuilder()
          ..setAclDefaultAppendGap(8)
          ..setAclDefaultRowHeight(56)
          ..setAclExpandXDefault(true);

        acl.append(form.orderId.widget);
        acl.append(form.orderDate.widget);
        acl.addRowBreakpoint(atWidth: 480);

        acl.newRow();
        acl.append(form.priority.widget);
        acl.append(form.paid.widget);
        acl.addRowBreakpoint(atWidth: 480);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            acl.build(),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(ctx).textTheme.titleSmall),
            const Divider(),
            SizedBox(
              height: 240,
              child: TomInlineListForm<ExampleOrderItem,
                  ExampleOrderItemForm>(
                listForm: form.items,
                rowBuilder: (context, i, itemForm) =>
                    _ItemRow(form: itemForm),
              ),
            ),
            TomListFormToolbar<ExampleOrderItem, ExampleOrderItemForm>(
              listForm: form.items,
            ),
          ],
        );
      },
    );
    form.dispose();
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.form});

  final ExampleOrderItemForm form;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: form.changes,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
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
// Read-only key/value grid used inside the customer card.
// ---------------------------------------------------------------------------
class _ReadOnlyGrid extends StatelessWidget {
  const _ReadOnlyGrid({required this.rows});

  final List<(String label, String value)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      // Two columns when wide, one when narrow — the same kind of
      // breakpoint reflow that AclBuilder provides for editable rows.
      final twoColumn = constraints.maxWidth >= 540;
      if (!twoColumn) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.map((r) => _row(theme, r.$1, r.$2)).toList(),
        );
      }
      final left = <Widget>[];
      final right = <Widget>[];
      for (var i = 0; i < rows.length; i++) {
        final row = _row(theme, rows[i].$1, rows[i].$2);
        if (i.isEven) {
          left.add(row);
        } else {
          right.add(row);
        }
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: 16),
          Expanded(child: Column(children: right)),
        ],
      );
    });
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ),
            Expanded(
              child: Text(value.isEmpty ? '—' : value,
                  style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Dialog host — runs `form.save()` on confirm, `form.discard()` on cancel.
// ---------------------------------------------------------------------------
class _RowDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required TomForm form,
    required WidgetBuilder builder,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: builder(ctx))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        form.discard();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        await form.save();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _shortDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
