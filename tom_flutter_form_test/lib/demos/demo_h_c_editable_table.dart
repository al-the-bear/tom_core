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

/// Exercises `tom_flutter_ui` field widgets embedded in Material `DataTable`
/// cells (plus the `TomAclBuilder` row pattern and `TomFormStyleScope` error
/// placement), with a `TomFormSearchInput` product picker.
///
/// Renders an OrderForm.items list as TWO Material DataTables, both bound
/// to the SAME `_form.items` so editing in one variant immediately updates
/// the other:
///
/// * Variant A — "in-cell errors": the standard renderer, error text and
///   error border appear directly under / around each invalid cell. Also
///   exposes the `TomAclBuilder` row-per-item pattern via a segmented
///   switch (§16, "DataTable / TomAclBuilder side-by-side").
/// * Variant B — "error strip below row": the cells are wrapped in a
///   `TomFormStyleScope` that promotes the error message into a tooltip
///   and disables the error border, so the cell never grows or shifts;
///   below each row a per-row error strip lists every field error.
///
/// Cells are top-aligned so the row heights stay anchored to the same
/// baseline whether or not an error is on screen — answers feedback (g).
///
/// The product field is a `TomFormSearchInput<String>` over the catalog;
/// selecting an entry auto-fills the unit price.
class DemoHCEditableTable extends StatefulWidget {
  const DemoHCEditableTable({super.key});

  @override
  State<DemoHCEditableTable> createState() => _DemoHCEditableTableState();
}

class _DemoHCEditableTableState extends State<DemoHCEditableTable> {
  late final OrderForm _form;
  late final TomFormInspector _inspector;

  /// Variant-A row layout — DataTable (default) or `TomAclBuilder`.
  /// Variant B is always rendered as a DataTable.
  _ItemsRenderer _variantA = _ItemsRenderer.dataTable;

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
                builder: (context, _) => _variantACard(context),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _form.changes,
                builder: (context, _) => _variantBCard(context),
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
                'Two side-by-side renderers over the SAME OrderForm.items '
                'list. Variant A shows the standard in-cell error visuals; '
                'Variant B promotes the error text into a tooltip and shows '
                'a per-row error strip beneath the row instead, so the '
                'fields never shift their alignment when an error appears. '
                'Both tables are kept in sync via the shared list — typing '
                'in either one updates the other.\n\n'
                'The product cell is a type-ahead search over the catalog; '
                'selecting an entry auto-fills the unit price. Quantity = 0 '
                'and a non-numeric price both trip inline validation '
                '(autoValidate is on for those two fields).'),
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

  // ------------------------------------------------------------------
  // Variant A — in-cell error visuals + DataTable / ACL switch.
  // ------------------------------------------------------------------

  Widget _variantACard(BuildContext context) {
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
                Text('Variant A — in-cell errors  '
                    '(Items: ${items.length})',
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
                selected: {_variantA},
                showSelectedIcon: false,
                onSelectionChanged: (sel) =>
                    setState(() => _variantA = sel.first),
              ),
            ),
            const Divider(height: 8),
            if (items.length == 0)
              _emptyState(context)
            else if (_variantA == _ItemsRenderer.dataTable)
              _variantADataTable(context)
            else
              _aclList(context),
            const Divider(height: 16),
            _addRemoveBar(context),
            const SizedBox(height: 8),
            // Cross-field validation surfaces here (e.g. minRequired).
            _crossFieldErrorView(context),
          ],
        ),
      ),
    );
  }

  Widget _variantADataTable(BuildContext context) {
    final theme = Theme.of(context);
    final items = _form.items;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowHeight: 36,
        // Cells must grow when an error message appears below the input.
        // Bumping the max-height lets that growth happen without the row
        // clipping; pairing with top-aligned cell wrappers (see
        // _topCell) keeps every input anchored to the same baseline.
        dataRowMinHeight: 64,
        dataRowMaxHeight: 140,
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Unit price'), numeric: true),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (var i = 0; i < items.length; i++)
            _buildVariantARow(context, i, items[i], theme),
        ],
      ),
    );
  }

  DataRow _buildVariantARow(
      BuildContext context, int index, OrderItemForm form, ThemeData theme) {
    return DataRow(
      key: ValueKey('vA-row-$index'),
      cells: [
        // Product cell is a touch wider than the previous demo so the
        // long catalog labels don't overflow. Round-5 (e): bumped from
        // 220 → 330 (~50% wider) so 28-char names like "Drafting paper
        // (A1, 50 sht)" no longer ellipsise inside the input.
        DataCell(_topCell(330, form.productName.widget)),
        DataCell(_topCell(70, form.quantity.widget)),
        DataCell(_topCell(110, form.unitPrice.widget)),
        DataCell(_topCell(
          80,
          ListenableBuilder(
            listenable: form.changes,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '\$${form.computedTotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        )),
        DataCell(_rowActions(index)),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Variant B — DataTable with errors suppressed in the cells; per-row
  // error strip rendered beneath each row.
  // ------------------------------------------------------------------

  Widget _variantBCard(BuildContext context) {
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
                Text('Variant B — error strip below row  '
                    '(Items: ${items.length})',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  'Same data — edits propagate to Variant A above.',
                  style: theme.textTheme.bodySmall,
                ),
              ]),
            ),
            const Divider(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                // Fixed width keeps the inner Row's children bounded —
                // if we used ConstrainedBox(minWidth:..) the Row would
                // still see an infinite max width via the horizontal
                // scroll viewport, blowing up Spacer/Expanded layouts.
                // Bumped 760 → 870 in round-5 (e) to absorb the
                // wider product cell. +26 in this round to make room
                // for the drag-handle column on the left.
                width: 896,
                child: TomInlineListForm<OrderItem, OrderItemForm>(
                  listForm: items,
                  reorderable: true,
                  onReorder: (_, _) => setState(() {}),
                  headerBuilder: (_, _) => _variantBHeaderRow(theme),
                  emptyBuilder: (context) => _emptyState(context),
                  rowBuilder: (context, i, rowForm) =>
                      _variantBRow(context, i, rowForm, theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantBHeaderRow(ThemeData theme) {
    final style = theme.textTheme.labelMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          // Spacer for drag-handle column to keep title alignment.
          const SizedBox(width: 22),
          SizedBox(width: 330, child: Text('Product', style: style)),
          const SizedBox(width: 12),
          SizedBox(
              width: 70,
              child: Text('Qty', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 12),
          SizedBox(
              width: 110,
              child: Text('Unit price',
                  style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text('Total',
                  style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 12),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _variantBRow(
      BuildContext context, int index, OrderItemForm form, ThemeData theme) {
    return ListenableBuilder(
      key: ValueKey('vB-row-$index'),
      listenable: form.changes,
      builder: (context, _) {
        final errors = form.fieldsWithErrors;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle for the inline-list reorder.
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TomReorderHandle(index: index),
                  ),
                  const SizedBox(width: 4),
                  _quietCell(330, form.productName.widget),
                  const SizedBox(width: 12),
                  _quietCell(70, form.quantity.widget),
                  const SizedBox(width: 12),
                  _quietCell(110, form.unitPrice.widget),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '\$${form.computedTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _rowActions(index),
                ],
              ),
              if (errors.isNotEmpty) _rowErrorStrip(theme, errors),
            ],
          ),
        );
      },
    );
  }

  Widget _rowErrorStrip(ThemeData theme, List<TomField> errors) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                for (final f in errors)
                  '${f.tomId}: ${resolveFieldValidationMessage(
                        validationState: f.validationState,
                        basePath: f.basePath,
                        scope: f.scope,
                      ) ?? (f.validationState as ValidationError).errorKey}'
              ].join('  •  '),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Field cell wrapped in a style scope that suppresses inline error
  /// visuals (no error text, no error border) so the cell stays the
  /// same height whether the field is in error or not. The error info
  /// shows up in the per-row strip directly below.
  Widget _quietCell(double width, Widget fieldWidget) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: TomFormStyleScope(
          style: const TomFormStyle(
            defaults: TomFieldStyle(
              errorPlacement: ErrorPlacement.tooltip,
              errorBorderEnabled: false,
            ),
          ),
          child: fieldWidget,
        ),
      ),
    );
  }

  /// Anchors a cell's content at the top so error growth in OTHER cells
  /// doesn't visually nudge this one's input down. Without this DataTable
  /// vertically centers cell contents in the row, and the moment one
  /// cell expands every other input on the row jumps. Answers (g).
  Widget _topCell(double width, Widget child) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    );
  }

  // ------------------------------------------------------------------
  // Shared bits
  // ------------------------------------------------------------------

  Widget _rowActions(int index) {
    return Row(
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
    );
  }

  Widget _addRemoveBar(BuildContext context) {
    final items = _form.items;
    // Reusable Add (the per-row Remove buttons in `_rowActions` cover
    // single-row removal). Keep the bulk "Remove all" alongside it.
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          TomListFormToolbar<OrderItem, OrderItemForm>(
            listForm: items,
            showRemove: false,
            showMoveUp: false,
            showMoveDown: false,
            addLabel: 'Add row',
            onSelectionChanged: (_) async => setState(() {}),
          ),
          const SizedBox(width: 8),
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
    );
  }

  Widget _emptyState(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'No items — add one below.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _crossFieldErrorView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TomErrorView(
        form: _form,
        title: 'Form errors',
        emptyState: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'No errors — order is well-formed.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
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
                final ok = await _form.save();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Saved order + items.'
                      : 'Validation failed — see error panels.'),
                ));
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Validate'),
              onPressed: () async {
                await _form.validate();
                if (!context.mounted) return;
                setState(() {});
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Discard all'),
              onPressed: () {
                _form.discard();
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
      onReorderItem: (from, to) {
        // onReorderItem already adjusts `to` for the removed item, so it maps
        // directly onto TomListForm.reorder semantics with no manual fixup.
        setState(() => _form.items.reorder(from, to));
      },
      itemBuilder: (context, index) {
        final form = items[index];
        return Padding(
          key: ValueKey('acl-row-$index'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Icon(Icons.drag_indicator, size: 18),
                ),
              ),
              Expanded(
                child: TomAclBuilder<OrderItemForm>(
                  id: 'orderItemRow',
                  elementProvider: form,
                )
                    // Round-6 (e): the previous round wrapped each cell
                    // in `SizedBox(width: …)` but the ACL layout engine
                    // ignores the inner widget's intrinsic width — every
                    // cell rendered at an equal share of the row, so the
                    // product field stayed cramped no matter what
                    // SizedBox value we passed. The fix is to size the
                    // ACL component itself via `setPSize`. Product is
                    // doubled relative to the previous demo width so
                    // long catalog names finally have breathing room.
                    .append((f) => f.productName.widget).setPSize(720)
                    .append((f) => f.quantity.widget).setPSize(70)
                    .append((f) => f.unitPrice.widget).setPSize(110)
                    .append(
                      (f) => SizedBox(
                        width: 80,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ListenableBuilder(
                            listenable: f.changes,
                            builder: (context, _) => Text(
                              '\$${f.computedTotal.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.right,
                            ),
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
