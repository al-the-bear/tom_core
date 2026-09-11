import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/order_form.dart';
import '../forms/order_item_form.dart';
import '../panels/event_log_panel.dart';
import '../panels/info_panel.dart';
import '../state/phase2a_state.dart';

// ---------------------------------------------------------------------------
// Demo H-B — Expandable Rows (Order Items)
// ---------------------------------------------------------------------------

/// Exercises `tom_flutter_ui`'s `TomListForm` rendered as one `ExpansionTile`
/// per row, with a type-ahead `TomFormSearchInput` product picker.
///
/// Renders a `TomListForm<OrderItem, OrderItemForm>` as one ExpansionTile per
/// row. Collapsed state shows the read-only summary (product name / qty /
/// total); expanded state reveals the editable sub-form, including the
/// type-ahead Product picker that auto-fills the unit price.
///
/// Behaviours wired in:
///
/// * Single-row exclusive expansion: opening one row collapses the
///   currently-open row.
/// * Row-switch guard: switching while the open row has validation
///   errors (e.g. `quantity = 0`) is refused — the open row stays
///   expanded and a snackbar surfaces the reason.
/// * Save → validate → collapse on success: if the order saves
///   cleanly, the open row collapses to its read-only summary.
/// * Validate-on-bind: the form runs `validate()` once after binding
///   so the "Form valid / invalid" badge reflects the actual state of
///   the loaded data (instead of the pristine `false`).
/// * Per-row + parent error panels surface every reason the form is
///   invalid, so the badge is never the only signal.
class DemoHBExpandableRows extends StatefulWidget {
  const DemoHBExpandableRows({super.key});

  @override
  State<DemoHBExpandableRows> createState() => _DemoHBExpandableRowsState();
}

class _DemoHBExpandableRowsState extends State<DemoHBExpandableRows> {
  late final OrderForm _form;
  late final TomFormInspector _inspector;

  /// Drives [TomExpandableListForm]. We hold the controller so the demo
  /// can programmatically collapse every row after a successful save and
  /// after Discard, and so the "Add item" path can grow + expand the new
  /// row in one shot. Single-row exclusive expansion comes from the
  /// default [TomExpansionPolicy.singleOpen].
  late final TomExpandableListFormController _expandController;

  /// Round-6 (c): demo control for the row error strip's text alignment
  /// (start = left, center = centered). Lives in the demo because real
  /// apps will pick one and stick with it; the demo just shows both.
  CrossAxisAlignment _rowErrorAlignment = CrossAxisAlignment.start;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoHB', () => OrderForm());
    _form.bind(phase2aExpandableOrder);
    _inspector = TomFormInspector();
    _form.addListener(_inspector);
    _expandController = TomExpandableListFormController();
    // Validate after first frame so the "Form valid / invalid" chip
    // reflects the loaded data instead of the pristine `false`. We
    // defer to post-frame so the field widgets have had a chance to
    // attach their validation listeners and rebuild on the result.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _form.validate();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
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
              ListenableBuilder(
                listenable: _form.changes,
                builder: (context, _) => _formErrorsCard(context),
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
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
              'Tap a row to expand the OrderItemForm inline — only ONE '
              'row is open at a time. The product field is a type-ahead '
              'search over the catalog; selecting an entry auto-fills '
              'the unit price. Quantity = 0 is an error.\n\n'
              'Switching to another row while the open row has '
              'validation errors is refused — the open row stays '
              'expanded and a snackbar tells you why. Saving the order '
              'collapses the open row on success.\n\n'
              'Each row also carries a drag handle (left edge of the '
              'summary) that lets you reorder rows; the open row stays '
              'open at its new position after the drop. The toolbar '
              'below the rows is the reusable TomListFormToolbar — '
              'Add / Remove / Move up / Move down all operate on the '
              'currently-open row.',
            ),
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
            Row(
              children: [
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
              ],
            ),
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
        child: TomExpandableListForm<OrderItem, OrderItemForm>(
          listForm: items,
          controller: _expandController,
          onBeforeChange: _onBeforeRowExpansionChange,
          reorderable: true,
          headerBuilder: (context, list) => Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                Text(
                  'Items (${list.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  'Order total: \$${_orderTotal().toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          summaryBuilder: (context, index, rowForm) =>
              _summary(context, index, rowForm),
          bodyBuilder: (context, index, rowForm) => _rowBody(context, rowForm),
          footerBuilder: (context, list) => const Divider(height: 16),
          toolbarBuilder: (context, list) => Padding(
            padding: const EdgeInsets.all(8),
            child: TomListFormToolbar<OrderItem, OrderItemForm>(
              listForm: list,
              // Single-row exclusive expansion means the open row IS the
              // selection from the toolbar's perspective. Wire the
              // controller's expanded set into the toolbar so Move-up /
              // Move-down / Remove operate on the open row.
              selectedIndex: _expandController.expanded.isEmpty
                  ? null
                  : _expandController.expanded.first,
              addLabel: 'Add item',
              removeLabel: 'Remove item',
              // Adding a row also "switches" away from the open row —
              // run the validate-before-switch gate before append.
              beforeAdd: _guardSwitchAwayFromExpanded,
              // After Add: expand the newly appended row.
              // After Remove / Move: the controller already remaps
              // (Remove drops the open row; Move keeps it open at the
              // new index courtesy of the widget's reorder remap).
              onSelectionChanged: (i) async {
                if (i != null && i == list.length - 1) {
                  _expandController.expand(i);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, int index, OrderItemForm form) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: form.changes,
      builder: (context, _) {
        final qty = int.tryParse(form.quantity.get()) ?? 0;
        final price = double.tryParse(form.unitPrice.get()) ?? 0.0;
        final total = qty * price;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Row(
            children: [
              // Drag handle — TomReorderHandle wraps a
              // ReorderableDragStartListener so the long-press starts a
              // drag instead of toggling the row's expansion state.
              TomReorderHandle(index: index),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.productName.get().isEmpty
                          ? '(no product)'
                          : form.productName.get(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qty ${form.quantity.get()} '
                      '× \$${form.unitPrice.get()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Remove row',
                onPressed: () => _form.items.removeAt(index),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rowBody(BuildContext context, OrderItemForm form) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: form.productName.widget,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: form.quantity.widget),
              const SizedBox(width: 12),
              Expanded(child: form.unitPrice.widget),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: form.notes.widget,
        ),
        const SizedBox(height: 8),
        // Strip itself fills the full row width — no horizontal pad.
        TomRowErrorStrip(
          key: const ValueKey('h-b-row-error-strip'),
          form: form,
          crossAxisAlignment: _rowErrorAlignment,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Form-level error card that surfaces every problem in the order —
  /// answers the "form invalid but no error visible" feedback.
  ///
  /// Round-6 (c): the panel headline falls back to the
  /// `demoHB.errors.title` resource when no constructor-supplied title
  /// exists, so installations can re-skin the headline without editing
  /// demo code.
  Widget _formErrorsCard(BuildContext context) {
    final theme = Theme.of(context);
    final headline =
        TomCtr.textOrNull('', 'demoHB.errors.title') ?? 'Form errors';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TomErrorView(
              form: _form,
              title: 'Order errors',
              emptyState: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
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
                final ok = await _form.save();
                if (!context.mounted) return;
                if (ok) {
                  // (c) collapse the open row on a clean save —
                  // controller.collapseAll() is programmatic and
                  // bypasses the row-switch veto by design.
                  _expandController.collapseAll();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Saved order + items.'
                          : 'Validation failed — see errors below the rows.',
                    ),
                  ),
                );
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
                _expandController.collapseAll();
              },
            ),
            // Round-6 (c): segmented toggle so the demo can flip the row
            // error strip's alignment between left and centred.
            const SizedBox(width: 12),
            SegmentedButton<CrossAxisAlignment>(
              segments: const [
                ButtonSegment(
                  value: CrossAxisAlignment.start,
                  label: Text('Errors left'),
                  icon: Icon(Icons.format_align_left, size: 16),
                ),
                ButtonSegment(
                  value: CrossAxisAlignment.center,
                  label: Text('Errors centered'),
                  icon: Icon(Icons.format_align_center, size: 16),
                ),
              ],
              selected: {_rowErrorAlignment},
              onSelectionChanged: (sel) =>
                  setState(() => _rowErrorAlignment = sel.first),
            ),
          ],
        ),
      ),
    );
  }

  /// onBeforeChange callback for [TomExpandableListForm].
  ///
  /// Fires for every row whose open/closed state is about to flip
  /// (including, in [TomExpansionPolicy.singleOpen], the
  /// previously-open row when a sibling is being opened). When the row
  /// is about to *close* we run validation and refuse the close if
  /// errors exist — the "validate-before-switch" gate. Opens are
  /// always allowed.
  Future<bool> _onBeforeRowExpansionChange(
    int index,
    OrderItemForm form,
    bool willOpen,
  ) async {
    if (willOpen) return true;
    final errors = await form.validate();
    if (errors.isEmpty) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Row ${index + 1} has ${errors.length} '
          '${errors.length == 1 ? "error" : "errors"} — fix them or '
          'discard before switching.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    return false;
  }

  /// Imperative version of the same guard, used by "Add item" — the
  /// add path bypasses [TomExpandableListForm]'s own toggle flow so we
  /// have to run the gate by hand before calling
  /// `controller.expand(...)` (which is programmatic and bypasses the
  /// veto).
  Future<bool> _guardSwitchAwayFromExpanded() async {
    final open = _expandController.expanded;
    if (open.isEmpty) return true;
    final cur = open.first;
    if (cur < 0 || cur >= _form.items.length) return true;
    return _onBeforeRowExpansionChange(cur, _form.items[cur], false);
  }

  double _orderTotal() {
    return _form.items.forms.fold<double>(0, (sum, f) => sum + f.computedTotal);
  }
}
