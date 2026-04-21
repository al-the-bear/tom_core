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
// Demo H-C — Editable Order-Items Table  [Phase 2a §16]
// ---------------------------------------------------------------------------
//
// Renders an OrderForm.items list as a Material DataTable with each row
// containing the actual editable field widgets (productName / quantity /
// unitPrice). A computed-total column observes per-row values; a form-
// level total observes the whole list.
//
// Add / remove / reorder map to TomListForm.add / .removeAt / .move. Drag
// handles act as the reorder affordance — tapping ▲/▼ on the trailing
// column moves the row.
//
// A TomErrorView is mounted to the right of the table; if the list is
// empty, the parent OrderItemsListForm.validateList returns
// `error.items.minRequired` and the panel surfaces it.
class DemoHCEditableTable extends StatefulWidget {
  const DemoHCEditableTable({super.key});

  @override
  State<DemoHCEditableTable> createState() => _DemoHCEditableTableState();
}

class _DemoHCEditableTableState extends State<DemoHCEditableTable> {
  late final OrderForm _form;
  late final TomFormInspector _inspector;

  /// Which renderer is shown in the items card. The DataTable variant is
  /// the default; the ACL variant exercises the spec's `TomAclBuilder`
  /// row-per-item pattern (§16, "DataTable / TomAclBuilder side-by-side").
  _ItemsRenderer _renderer = _ItemsRenderer.dataTable;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHC', () => OrderForm());
    _form.bind(phase2aTableOrder);
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
      title: 'Demo H-C — Editable Order-Items Table',
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
                builder: (context, _) => _tableAndErrorRow(context),
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
                'Each line item is a row in a DataTable; cells host the '
                'live TomFormStringInput widgets directly so edits flow '
                'straight back into the bound Order. The "Total" column '
                'and the order-level total observe the list — adding, '
                'removing, or editing a row updates both.\n\n'
                'Remove all rows to see "items.minRequired" appear in the '
                'TomErrorView on the right (cross-field validation '
                'surfaced through the parent OrderForm).'),
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
            Row(children: [
              Expanded(child: _form.orderNumber.widget),
              const SizedBox(width: 12),
              Expanded(child: _form.customer.widget),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tableAndErrorRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side-by-side on wide layouts; stacked when narrow.
        final wide = constraints.maxWidth >= 900;
        final table = _itemsCard(context);
        final errors = _errorPanel(context);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: table),
              const SizedBox(width: 12),
              SizedBox(width: 280, child: errors),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            table,
            const SizedBox(height: 12),
            errors,
          ],
        );
      },
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: SegmentedButton<_ItemsRenderer>(
                segments: const [
                  ButtonSegment(
                    value: _ItemsRenderer.dataTable,
                    label: Text('DataTable'),
                    icon: Icon(Icons.table_rows_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: _ItemsRenderer.acl,
                    label: Text('TomAclBuilder'),
                    icon: Icon(Icons.view_agenda_outlined, size: 16),
                  ),
                ],
                selected: {_renderer},
                showSelectedIcon: false,
                onSelectionChanged: (sel) =>
                    setState(() => _renderer = sel.first),
              ),
            ),
            const Divider(height: 8),
            if (items.length == 0)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No items — add one below.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else if (_renderer == _ItemsRenderer.dataTable)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  headingRowHeight: 36,
                  dataRowMinHeight: 80,
                  dataRowMaxHeight: 120,
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Qty'), numeric: true),
                    DataColumn(label: Text('Unit price'), numeric: true),
                    DataColumn(label: Text('Total'), numeric: true),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (var i = 0; i < items.length; i++)
                      _buildRow(context, i, items[i]),
                  ],
                ),
              )
            else
              _aclList(context),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add row'),
                    onPressed: () => setState(() => items.add()),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Remove all'),
                    onPressed: items.length == 0
                        ? null
                        : () {
                            setState(() {
                              while (items.length > 0) {
                                items.removeAt(items.length - 1);
                              }
                            });
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

  DataRow _buildRow(BuildContext context, int index, OrderItemForm form) {
    final theme = Theme.of(context);
    return DataRow(
      key: ValueKey('row-$index'),
      cells: [
        DataCell(SizedBox(width: 220, child: form.productName.widget)),
        DataCell(SizedBox(width: 70, child: form.quantity.widget)),
        DataCell(SizedBox(width: 100, child: form.unitPrice.widget)),
        DataCell(
          SizedBox(
            width: 80,
            child: ListenableBuilder(
              listenable: form.changes,
              builder: (context, _) => Text(
                '\$${form.computedTotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: index == 0
                    ? null
                    : () => setState(() => _form.items.move(index, index - 1)),
              ),
              IconButton(
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: index == _form.items.length - 1
                    ? null
                    : () => setState(() => _form.items.move(index, index + 1)),
              ),
              IconButton(
                tooltip: 'Remove row',
                icon: const Icon(Icons.delete_outline, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _form.items.removeAt(index)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cross-field validation',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            const Text(
              'Press "Validate" or remove every row to see the list-level '
              'rule trip and surface here.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TomErrorView(
              form: _form,
              title: 'Order errors',
              emptyState: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No errors — order is well-formed.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
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
                final headerOk = await _form.save();
                final listOk = await _form.items.save();
                if (!context.mounted) return;
                final ok = headerOk && listOk;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Saved order + items.'
                      : 'Validation failed — see error panel.'),
                ));
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Validate'),
              onPressed: () async {
                await _form.validate();
                await _form.items.validate();
                if (!context.mounted) return;
                setState(() {});
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

  /// Renders the list with the spec's `TomAclBuilder` row-per-item
  /// pattern. Each row is its own ACL composed against the
  /// `OrderItemForm` (which implements `TomScreenElementsProvider` via
  /// `TomForm`), so the same field widgets feed two completely different
  /// layout engines from the same bound list.
  Widget _aclList(BuildContext context) {
    final theme = Theme.of(context);
    final items = _form.items;
    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      onReorder: (from, to) {
        // ReorderableListView reports `to` as the index *after* removal
        // when moving downward — normalise to TomListForm.reorder semantics.
        final adjusted = to > from ? to - 1 : to;
        setState(() => _form.items.reorder(from, adjusted));
      },
      itemBuilder: (context, index) {
        final form = items[index];
        return Padding(
          key: ValueKey('acl-row-$index'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_indicator, size: 18),
                ),
              ),
              Expanded(
                child: TomAclBuilder<OrderItemForm>(
                  id: 'orderItemRow',
                  elementProvider: form,
                )
                    .append((f) => SizedBox(width: 220, child: f.productName.widget))
                    .append((f) => SizedBox(width: 70, child: f.quantity.widget))
                    .append((f) => SizedBox(width: 100, child: f.unitPrice.widget))
                    .append(
                      (f) => SizedBox(
                        width: 80,
                        child: ListenableBuilder(
                          listenable: f.changes,
                          builder: (context, _) => Text(
                            '\$${f.computedTotal.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    )
                    .build(context),
              ),
              IconButton(
                tooltip: 'Remove row',
                icon: const Icon(Icons.delete_outline, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => items.removeAt(index)),
              ),
            ],
          ),
        );
      },
    );
  }

  double _orderTotal() {
    return _form.items.forms
        .fold<double>(0, (sum, f) => sum + f.computedTotal);
  }
}

/// Renderer choice for the H-C items card — DataTable (default) or the
/// `TomAclBuilder` side-by-side variant called out in the spec for §H-C.
enum _ItemsRenderer { dataTable, acl }
