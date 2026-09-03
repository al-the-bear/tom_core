import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'example_list_screen.dart';
import 'forms/example_customer_rich_form.dart';
import 'shared/example_authorization.dart';
import 'shared/example_scaffold.dart';
import 'state/example_state.dart';

// ---------------------------------------------------------------------------
// Example H-B — Expandable rows over a customer's orders
// ---------------------------------------------------------------------------
//
// `TomExpandableListForm` renders one collapsible tile per order in the
// bound customer's orders list. The collapsed summary shows the order id,
// priority, paid flag, item count and running total; expanding the row
// reveals the per-order editor (date / priority / paid switch) plus the
// order's items in an inline editable list.
//
// What this example demonstrates:
//
//   * `TomExpandableListForm` end-to-end: header / summary / body /
//     toolbar builders and the `controller` used to track which row is
//     open. The default policy keeps a single row expanded at a time.
//   * Family-agnostic editing: the row's `ExampleOrderForm` and its
//     items list both use `FormFieldFamily`, so flipping `family` to
//     Cupertino changes every input automatically.
//   * Per-row breakpoints: the order header row built with `AclBuilder`
//     stacks `priority + paid` vertically below 600 px so the editor
//     stays usable on narrow viewports.
//
// Read-only summary outside the expanded body uses
// `TomMultiObservableBuilder` so the title repaints whenever the row's
// fields or its items change.
class ExampleHBExpandableRows extends StatefulWidget {
  const ExampleHBExpandableRows({super.key, required this.family});

  final ExampleFamily family;

  @override
  State<ExampleHBExpandableRows> createState() =>
      _ExampleHBExpandableRowsState();
}

class _ExampleHBExpandableRowsState extends State<ExampleHBExpandableRows> {
  late final FormFieldFamily _family;
  late final ExampleCustomerRichForm _form;
  late final TomExpandableListFormController _controller;

  @override
  void initState() {
    super.initState();
    installExampleAuthorization();
    _family = widget.family == ExampleFamily.cupertino
        ? FormFieldFamily.cupertino
        : FormFieldFamily.material;
    _form = ExampleCustomerRichForm(family: _family);
    _form.bind(exampleCustomerHb);
    _controller = TomExpandableListFormController(
      initialExpanded: _form.orders.isEmpty ? const {} : const {0},
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
        title: 'Example H-B · $familyLabel',
        child: ListenableBuilder(
          listenable: _form.changes,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TomExpandableListForm<ExampleOrder, ExampleOrderForm>(
                  listForm: _form.orders,
                  controller: _controller,
                  reorderable: true,
                  headerBuilder: (context, list) => _Header(form: _form),
                  summaryBuilder: (context, i, rowForm) =>
                      _Summary(index: i, form: rowForm),
                  bodyBuilder: (context, i, rowForm) =>
                      _Body(form: rowForm, family: _family),
                  toolbarBuilder: (context, list) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TomListFormToolbar<ExampleOrder, ExampleOrderForm>(
                      listForm: list,
                      addLabel: 'Add order',
                      removeLabel: 'Remove order',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.form});
  final ExampleCustomerRichForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Text(
            'Orders for ${form.fullName.get()}',
            style: theme.textTheme.titleSmall,
          ),
          const Spacer(),
          if (form.isDirty)
            const Chip(
              label: Text('Dirty'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.index, required this.form});

  final int index;
  final ExampleOrderForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = form.currentBinding;
    if (order == null) return const ListTile(title: Text('(unbound)'));
    return TomMultiObservableBuilder(
      observables: [order.orderId, order.priority, order.paid, order.items],
      builder: (context) {
        var total = 0.0;
        for (var i = 0; i < order.items.length; i++) {
          final item = order.items[i];
          total += item.quantity.get() * item.unitPrice.get();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Row(
            children: [
              TomReorderHandle(index: index),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderId.get().isEmpty
                          ? '(no id)'
                          : order.orderId.get(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.priority.get()} · '
                      '${order.items.length} item(s) · '
                      '${order.paid.get() ? "paid" : "unpaid"}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.form, required this.family});

  final ExampleOrderForm form;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    final header = AclBuilder()
      ..setAclDefaultAppendGap(8)
      ..setAclExpandXDefault(true);

    header.append(form.orderId.widget);
    header.append(form.orderDate.widget);
    header.addRowBreakpoint(atWidth: 600);

    header.newRow();
    header.append(form.priority.widget);
    header.append(form.paid.widget);
    header.addRowBreakpoint(atWidth: 600);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListenableBuilder(
        listenable: form.changes,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header.build(),
            const SizedBox(height: 8),
            const Divider(),
            TomMultiObservableBuilder(
              observables: [form.items],
              builder: (context) => Column(
                children: List.generate(form.items.length, (i) {
                  return _ItemEditor(
                    key: ValueKey('h-b-item-${form.items[i].hashCode}'),
                    form: form.items[i],
                  );
                }),
              ),
            ),
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

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({super.key, required this.form});

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
