import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'example_list_screen.dart';
import 'forms/example_customer_rich_form.dart';
import 'shared/example_authorization.dart';
import 'shared/example_scaffold.dart';
import 'state/example_state.dart';

// ---------------------------------------------------------------------------
// Example H-C — Editable items table for one order
// ---------------------------------------------------------------------------
//
// Renders the items of a single `ExampleOrder` as an editable table.
//
//   * Wide layout (>= 720 px): four columns side-by-side — product, qty,
//     unit price, notes — plus a derived line total.
//   * Narrow layout (< 720 px): each row collapses into a stacked
//     "card" layout with the product on top, then qty + price, then
//     notes, then total. The exact same row data, just reflowed.
//
// The row's editable widgets come from `ExampleOrderItemForm` so flipping
// the family parameter swaps every input between Material and Cupertino
// without changing this file.
class ExampleHCEditableTable extends StatefulWidget {
  const ExampleHCEditableTable({super.key, required this.family});

  final ExampleFamily family;

  @override
  State<ExampleHCEditableTable> createState() =>
      _ExampleHCEditableTableState();
}

class _ExampleHCEditableTableState extends State<ExampleHCEditableTable> {
  late final FormFieldFamily _family;
  late final ExampleOrderForm _form;

  @override
  void initState() {
    super.initState();
    installExampleAuthorization();
    _family = widget.family == ExampleFamily.cupertino
        ? FormFieldFamily.cupertino
        : FormFieldFamily.material;
    _form = ExampleOrderForm(family: _family);
    // Bind to the first order of the H-C seed customer so this example
    // does not depend on the H-D / H-E mutable seeds.
    _form.bind(exampleCustomerHc.orders.first);
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
        title: 'Example H-C · $familyLabel',
        child: ListenableBuilder(
          listenable: _form.changes,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrderHeaderCard(form: _form),
                const SizedBox(height: 12),
                _ItemsCard(form: _form),
                const SizedBox(height: 12),
                _Actions(form: _form),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderHeaderCard extends StatelessWidget {
  const _OrderHeaderCard({required this.form});

  final ExampleOrderForm form;

  @override
  Widget build(BuildContext context) {
    final acl = AclBuilder()
      ..setAclDefaultAppendGap(8)
      ..setAclDefaultRowHeight(56)
      ..setAclExpandXDefault(true);

    acl.append(form.orderId.widget);
    acl.append(form.orderDate.widget);
    acl.addRowBreakpoint(atWidth: 600);

    acl.newRow();
    acl.append(form.priority.widget);
    acl.append(form.paid.widget);
    acl.addRowBreakpoint(atWidth: 600);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: acl.build(),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.form});

  final ExampleOrderForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Items', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text('Total: \$${form.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const Divider(height: 16),
            // Flip between table-style and stacked-card-style at one
            // breakpoint. Both layouts re-use the same row form so no
            // state is recreated when the layout flips.
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                return TomMultiObservableBuilder(
                  observables: [form.items],
                  builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide) const _TableHeader(),
                      ...List.generate(
                        form.items.length,
                        (i) => wide
                            ? _TableRow(
                                key: ValueKey(
                                    'h-c-row-${form.items[i].hashCode}'),
                                index: i,
                                form: form.items[i],
                                onRemove: () => form.items.removeAt(i),
                              )
                            : _StackedRow(
                                key: ValueKey(
                                    'h-c-stacked-${form.items[i].hashCode}'),
                                index: i,
                                form: form.items[i],
                                onRemove: () => form.items.removeAt(i),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TomListFormToolbar<ExampleOrderItem, ExampleOrderItemForm>(
              listForm: form.items,
              addLabel: 'Add item',
              removeLabel: 'Remove item',
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(flex: 4, child: Text('Product', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text('Qty', style: style)),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text('Unit price', style: style)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text('Notes', style: style)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text('Total',
                style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    super.key,
    required this.index,
    required this.form,
    required this.onRemove,
  });

  final int index;
  final ExampleOrderItemForm form;
  final VoidCallback onRemove;

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
              padding: const EdgeInsets.only(top: 14),
              child: SizedBox(
                  width: 32, child: TomReorderHandle(index: index)),
            ),
            Expanded(flex: 4, child: form.productName.widget),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: form.quantity.widget),
            const SizedBox(width: 8),
            SizedBox(width: 110, child: form.unitPrice.widget),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: form.notes.widget),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  '\$${form.lineTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _StackedRow extends StatelessWidget {
  const _StackedRow({
    super.key,
    required this.index,
    required this.form,
    required this.onRemove,
  });

  final int index;
  final ExampleOrderItemForm form;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListenableBuilder(
          listenable: form.changes,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TomReorderHandle(index: index),
                  const SizedBox(width: 4),
                  Expanded(child: form.productName.widget),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Remove',
                    onPressed: onRemove,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: form.quantity.widget),
                  const SizedBox(width: 8),
                  Expanded(child: form.unitPrice.widget),
                ],
              ),
              const SizedBox(height: 4),
              form.notes.widget,
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: \$${form.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.form});

  final ExampleOrderForm form;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Save order'),
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
