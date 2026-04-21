import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/order_form.dart';
import '../forms/order_item_form.dart';
import '../panels/event_log_panel.dart';
import '../panels/info_panel.dart';
import '../state/phase2a_state.dart';

// ---------------------------------------------------------------------------
// Demo H-B — Expandable Rows (Order Items)  [Phase 2a §16]
// ---------------------------------------------------------------------------
//
// Renders a TomListForm<OrderItem, OrderItemForm> as one ExpansionTile per
// row. Collapsed state shows the read-only summary (product name / qty /
// total); expanded state reveals the editable sub-form.
//
// The parent OrderForm's isDirty / isValid aggregate correctly across all
// expanded and collapsed children — see the status badges at the top.
class DemoHBExpandableRows extends StatefulWidget {
  const DemoHBExpandableRows({super.key});

  @override
  State<DemoHBExpandableRows> createState() => _DemoHBExpandableRowsState();
}

class _DemoHBExpandableRowsState extends State<DemoHBExpandableRows> {
  late final OrderForm _form;
  late final TomFormInspector _inspector;
  final Set<int> _expandedRows = {};

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHB', () => OrderForm());
    _form.bind(phase2aExpandableOrder);
    _inspector = TomFormInspector();
    _form.addListener(_inspector);
  }

  @override
  void dispose() {
    _form.removeListener(_inspector);
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H-B — Expandable Rows (Order Items)',
      child: TomUnsavedChangesGuard(
        form: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _intro(context),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _form.changes,
                builder: (context, _) => _header(context),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _form.changes,
                builder: (context, _) => _itemsCard(context),
              ),
              const SizedBox(height: 12),
              _actionBar(context),
              const SizedBox(height: 12),
              InfoPanel(
                title: 'Event log',
                children: [
                  EventLogPanel(
                    inspector: _inspector,
                    rebuildOn: _form.changes,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                'Tap a row to expand the OrderItemForm inline. Edits in '
                'expanded rows roll up into the parent OrderForm — the '
                '"Form dirty" / "Form valid" badges at the top reflect '
                'isDirty / isValid across every row, regardless of '
                'whether each row is expanded or collapsed. Add / remove '
                'rows with the buttons at the bottom of the items card.'),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text('Order header', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (_form.isDirty)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text('Form dirty'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Chip(
                label: Text(_form.isValid ? 'Form valid' : 'Form invalid'),
                visualDensity: VisualDensity.compact,
                backgroundColor: _form.isValid
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
              ),
            ]),
            const SizedBox(height: 12),
            _form.orderNumber.widget,
            const SizedBox(height: 8),
            _form.customer.widget,
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(BuildContext context) {
    final theme = Theme.of(context);
    final items = _form.items;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(children: [
                Text('Items (${items.length})',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  'Order total: \$${_orderTotal().toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall,
                ),
              ]),
            ),
            const Divider(height: 8),
            for (var i = 0; i < items.length; i++)
              _expandableRow(context, i, items[i]),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add item'),
                    onPressed: () {
                      items.add();
                      setState(() => _expandedRows.add(items.length - 1));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandableRow(BuildContext context, int index, OrderItemForm form) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: form.changes,
      builder: (context, _) {
        final qty = int.tryParse(form.quantity.get()) ?? 0;
        final price = double.tryParse(form.unitPrice.get()) ?? 0.0;
        final total = qty * price;
        return ExpansionTile(
          key: ValueKey('row-$index'),
          initiallyExpanded: _expandedRows.contains(index),
          onExpansionChanged: (open) {
            setState(() {
              if (open) {
                _expandedRows.add(index);
              } else {
                _expandedRows.remove(index);
              }
            });
          },
          title: Text(
            form.productName.get().isEmpty
                ? '(no product)'
                : form.productName.get(),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text('Qty ${form.quantity.get()} '
              '× \$${form.unitPrice.get()}'),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('\$${total.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Remove row',
                onPressed: () {
                  setState(() => _expandedRows.remove(index));
                  _form.items.removeAt(index);
                },
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            form.productName.widget,
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: form.quantity.widget),
              const SizedBox(width: 12),
              Expanded(child: form.unitPrice.widget),
            ]),
            const SizedBox(height: 8),
            form.notes.widget,
          ],
        );
      },
    );
  }

  Widget _actionBar(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save order'),
              onPressed: () async {
                final ok = await _form.save();
                if (ok) {
                  final listOk = await _form.items.save();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(listOk
                        ? 'Saved order + items.'
                        : 'Header saved, items invalid.'),
                  ));
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Header validation failed.'),
                  ));
                }
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Discard all'),
              onPressed: () {
                _form.discard();
                _form.items.discard();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  double _orderTotal() {
    return _form.items.forms
        .fold<double>(0, (sum, f) => sum + f.computedTotal);
  }
}
