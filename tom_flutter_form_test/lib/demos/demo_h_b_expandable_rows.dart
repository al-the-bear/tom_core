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
// total); expanded state reveals the editable sub-form, including the
// type-ahead Product picker that auto-fills the unit price.
//
// Behaviours wired in for spec §16:
//
// * Single-row exclusive expansion: opening one row collapses the
//   currently-open row.
// * Row-switch guard: switching while the open row has validation
//   errors (e.g. `quantity = 0`) is refused — the open row stays
//   expanded and a snackbar surfaces the reason.
// * Save → validate → collapse on success: if the order saves
//   cleanly, the open row collapses to its read-only summary.
// * Validate-on-bind: the form runs `validate()` once after binding
//   so the "Form valid / invalid" badge reflects the actual state of
//   the loaded data (instead of the pristine `false`).
// * Per-row + parent error panels surface every reason the form is
//   invalid, so the badge is never the only signal.
class DemoHBExpandableRows extends StatefulWidget {
  const DemoHBExpandableRows({super.key});

  @override
  State<DemoHBExpandableRows> createState() => _DemoHBExpandableRowsState();
}

class _DemoHBExpandableRowsState extends State<DemoHBExpandableRows> {
  late final OrderForm _form;
  late final TomFormInspector _inspector;

  /// Index of the single currently-expanded row, or `null` when every
  /// row is collapsed. Single-row exclusive expansion is the spec
  /// default for §16 — it avoids the foot-gun where two dirty rows
  /// fight for the user's attention.
  int? _expandedRow;

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
            Text('What this demo covers',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const Text(
                'Tap a row to expand the OrderItemForm inline — only ONE '
                'row is open at a time. The product field is a type-ahead '
                'search over the catalog; selecting an entry auto-fills '
                'the unit price. Quantity = 0 is an error.\n\n'
                'Switching to another row while the open row has '
                'validation errors is refused — the open row stays '
                'expanded and a snackbar tells you why. Saving the order '
                'collapses the open row on success.'),
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
                    onPressed: () async {
                      // Adding a row also "switches" to it — apply the
                      // same row-switch guard so we don't lose edits in
                      // an open invalid row.
                      final ok = await _guardSwitchAwayFromExpanded();
                      if (!ok) return;
                      items.add();
                      setState(() => _expandedRow = items.length - 1);
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
        final isOpen = _expandedRow == index;
        return ExpansionTile(
          // The key embeds `isOpen` so the ExpansionTile is *re-created*
          // (fresh State) whenever we externally change `_expandedRow`.
          // `initiallyExpanded` is only consulted on first build of a
          // given State instance — without rotating the key, programmatic
          // collapses (save-success, row-switch veto, "Discard all")
          // wouldn't visually take effect because the existing State
          // would keep its own `_isExpanded=true` regardless of the
          // updated `initiallyExpanded` prop. See round-5 (b).
          key: ValueKey('row-$index-${isOpen ? 'open' : 'closed'}'),
          initiallyExpanded: isOpen,
          maintainState: true,
          onExpansionChanged: (open) async {
            if (open) {
              await _requestOpenRow(index);
            } else {
              // Round-5 (c): closing the row by tapping its header
              // must also go through the validate-before-switch
              // guard. Otherwise users could "escape" a row with
              // pending errors (e.g. quantity=0) by collapsing it,
              // sidestepping the same gate that protects switching
              // to a sibling row.
              final ok = await _guardSwitchAwayFromExpanded();
              if (!ok) {
                // Re-rotate the key back to the open variant on the
                // next frame so the visual state matches the model.
                if (mounted) setState(() {});
                return;
              }
              setState(() => _expandedRow = null);
            }
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
                  setState(() {
                    if (_expandedRow == index) _expandedRow = null;
                  });
                  _form.items.removeAt(index);
                },
              ),
            ],
          ),
          // Round-6 (c): childrenPadding intentionally zero so the row
          // error strip below can stretch flush with the items card's
          // edges. Each non-strip child applies its own horizontal pad.
          childrenPadding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: form.productName.widget,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: form.quantity.widget),
                const SizedBox(width: 12),
                Expanded(child: form.unitPrice.widget),
              ]),
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
      },
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
                  // (c) collapse the open row on a clean save.
                  setState(() => _expandedRow = null);
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Saved order + items.'
                      : 'Validation failed — see errors below the rows.'),
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
                setState(() => _expandedRow = null);
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

  /// (d) Row-switch guard. Validates the currently-expanded row; if it
  /// has errors, refuses the switch and shows a snackbar. Returns
  /// `true` when the caller may proceed to open another row.
  Future<bool> _guardSwitchAwayFromExpanded() async {
    final cur = _expandedRow;
    if (cur == null) return true;
    if (cur < 0 || cur >= _form.items.length) return true;
    final form = _form.items[cur];
    final errors = await form.validate();
    if (errors.isEmpty) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Row ${cur + 1} has ${errors.length} '
        '${errors.length == 1 ? "error" : "errors"} — fix them or '
        'discard before switching.',
      ),
      duration: const Duration(seconds: 3),
    ));
    setState(() {});
    return false;
  }

  /// Apply the row-switch guard and, on success, expand `index`.
  Future<void> _requestOpenRow(int index) async {
    if (_expandedRow == index) return;
    final ok = await _guardSwitchAwayFromExpanded();
    if (!ok) {
      // ExpansionTile will already have toggled itself open optimistically
      // — force a rebuild that reverts to the prior state by bumping the
      // key set. Setting state with the same _expandedRow is enough since
      // we read `initiallyExpanded` from it on rebuild.
      setState(() {});
      return;
    }
    setState(() => _expandedRow = index);
  }

  double _orderTotal() {
    return _form.items.forms
        .fold<double>(0, (sum, f) => sum + f.computedTotal);
  }
}
