import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/customer_detail_form.dart';
import '../panels/event_log_panel.dart';
import '../panels/info_panel.dart';
import '../state/phase2a_state.dart';

// ---------------------------------------------------------------------------
// Demo H-A — Master-Detail Customer Editor (Phase 2a).
// ---------------------------------------------------------------------------
//
// Left pane:  TomListForm<Customer, CustomerDetailForm> with add / remove /
//             reorder buttons.
// Right pane: A single CustomerDetailForm re-bound on selection.
// Bottom:     EventLogPanel showing the interleaved stream of list events
//             (added / removed / reordered) and detail-form value /
//             validation events — proving they share one event bus.
//
// Selection is guarded by TomMasterDetailScaffold's built-in
// guardUnsavedChanges call; switching items while the detail is dirty
// pops a Save / Discard / Cancel dialog.
class DemoHAMasterDetail extends StatefulWidget {
  const DemoHAMasterDetail({super.key});

  @override
  State<DemoHAMasterDetail> createState() => _DemoHAMasterDetailState();
}

class _DemoHAMasterDetailState extends State<DemoHAMasterDetail> {
  // The two scaffolds share the same list form so mutations on either side
  // (add / remove / reorder / value edits) flow through to the other pane
  // immediately — both scaffolds observe the same TomListForm.
  late final CustomerListForm _listForm;
  // Each scaffold needs its own detail form because the scaffold rebinds
  // it on selection changes, and the two scaffolds maintain independent
  // selection state.
  late final CustomerDetailForm _detailFormA;
  late final CustomerDetailForm _detailFormB;
  late final TomFormInspector _inspector;

  @override
  void initState() {
    super.initState();
    _listForm = TomScope.withScope('demoHA', () => CustomerListForm());
    _detailFormA =
        TomScope.withScope('demoHA', () => CustomerDetailForm());
    _detailFormB =
        TomScope.withScope('demoHA', () => CustomerDetailForm());
    _listForm.bind(phase2aCustomers.customers);
    _inspector = TomFormInspector();
    _listForm.addListener(_inspector);
    _detailFormA.addListener(_inspector);
    _detailFormB.addListener(_inspector);
  }

  @override
  void dispose() {
    _listForm.removeListener(_inspector);
    _detailFormA.removeListener(_inspector);
    _detailFormB.removeListener(_inspector);
    _listForm.dispose();
    _detailFormA.dispose();
    _detailFormB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H-A — Master-Detail Customer Editor',
      // The outer guard covers detail form A; detail form B's own
      // selection-change guard inside its scaffold still protects against
      // losing edits when switching rows. (Top-level navigation away from
      // the demo is rare in this gallery, so a single outer guard is
      // enough for the worst case.)
      child: TomUnsavedChangesGuard(
        form: _detailFormA,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _intro(context),
              const SizedBox(height: 12),
              SizedBox(
                height: 520,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ScaffoldFrame(
                        label: 'Scaffold A — no preselection',
                        child:
                            TomMasterDetailScaffold<Customer, CustomerDetailForm>(
                          listForm: _listForm,
                          detailForm: _detailFormA,
                          masterPaneWidth: 240,
                          masterBuilder:
                              (context, listForm, selected, selectIndex) =>
                                  _MasterPane(
                            listForm: listForm,
                            selectedIndex: selected,
                            selectIndex: selectIndex,
                          ),
                          detailBuilder: (context, form) =>
                              _DetailPane(form: form),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ScaffoldFrame(
                        label: 'Scaffold B — preselects row 0',
                        child:
                            TomMasterDetailScaffold<Customer, CustomerDetailForm>(
                          listForm: _listForm,
                          detailForm: _detailFormB,
                          masterPaneWidth: 240,
                          initialSelectedIndex: 0,
                          masterBuilder:
                              (context, listForm, selected, selectIndex) =>
                                  _MasterPane(
                            listForm: listForm,
                            selectedIndex: selected,
                            selectIndex: selectIndex,
                          ),
                          detailBuilder: (context, form) =>
                              _DetailPane(form: form),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoPanel(
                title: 'Event log (shared list + both detail forms)',
                children: [
                  EventLogPanel(
                    inspector: _inspector,
                    rebuildOn: _detailFormA.changes,
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
                'Two master-detail scaffolds, both bound to the SAME '
                'TomListForm. Scaffold B preselects row 0 via its '
                'initialSelectedIndex parameter, while Scaffold A starts '
                'with no selection. Click a customer in either list to '
                'edit them on the right. Make a change and click another '
                'row — the scaffold runs the unsaved-changes guard and '
                'pops Save / Discard / Cancel before re-binding the '
                'detail form. Add / Remove / Move Up / Move Down on '
                'either side emit list events into the shared bus, so '
                'both lists refresh together — see the events '
                'interleaved in the log below.'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thin labeled frame around each scaffold so the demo clearly shows two
// independent master-detail instances sharing the same list.
// ---------------------------------------------------------------------------
class _ScaffoldFrame extends StatelessWidget {
  const _ScaffoldFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
              child: Text(label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  )),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subclass so add() can produce a fresh Customer for the bound list.
// ---------------------------------------------------------------------------
class CustomerListForm extends TomListForm<Customer, CustomerDetailForm> {
  CustomerListForm()
      : super(
          listId: 'customerDetail',
          formFactory: (_) => CustomerDetailForm(),
        );

  @override
  Customer createItem() {
    final c = Customer();
    c.fullName | 'New customer';
    c.email | '';
    c.phone | '';
    c.company | '';
    c.tier | 'standard';
    return c;
  }
}

// ---------------------------------------------------------------------------
// Master pane — list + add / remove / reorder buttons.
// ---------------------------------------------------------------------------
class _MasterPane extends StatefulWidget {
  const _MasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<Customer, CustomerDetailForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  State<_MasterPane> createState() => _MasterPaneState();
}

class _MasterPaneState extends State<_MasterPane>
    implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _MasterPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listForm != widget.listForm) {
      oldWidget.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable observable) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text('Customers (${widget.listForm.length})',
                  style: theme.textTheme.titleSmall),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.listForm.length,
                itemBuilder: (context, index) {
                  final form = widget.listForm[index];
                  final customer = form.currentBinding;
                  final isSelected = index == widget.selectedIndex;
                  // Subscribe each row to the bound customer's
                  // displayed fields. Without this the row only
                  // rebuilds on list-structural changes (add /
                  // remove / reorder) and stale values linger until
                  // the next structural mutation.
                  //
                  // Round-5 feedback (a): the master list (and the
                  // sibling list in scaffold B) used to show stale
                  // names / companies after a detail-form save —
                  // because `_MasterPaneState.onNotify` only fires
                  // on `TomListForm` notifications, not on per-item
                  // field changes. Observing the fields here makes
                  // the row reactive to *any* mutation of those
                  // values, regardless of which scaffold's detail
                  // form (or external code path) caused it.
                  return _CustomerListTile(
                    customer: customer,
                    index: index,
                    isSelected: isSelected,
                    onTap: () => widget.selectIndex(index),
                  );
                },
              ),
            ),
            const Divider(height: 8),
            Wrap(
              spacing: 6,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () async {
                    widget.listForm.add();
                    await widget.selectIndex(widget.listForm.length - 1);
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove'),
                  onPressed: widget.selectedIndex == null
                      ? null
                      : () async {
                          final idx = widget.selectedIndex!;
                          widget.listForm.removeAt(idx);
                          await widget.selectIndex(null);
                        },
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: (widget.selectedIndex == null ||
                          widget.selectedIndex! == 0)
                      ? null
                      : () {
                          final i = widget.selectedIndex!;
                          widget.listForm.move(i, i - 1);
                          widget.selectIndex(i - 1);
                        },
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: (widget.selectedIndex == null ||
                          widget.selectedIndex! >=
                              widget.listForm.length - 1)
                      ? null
                      : () {
                          final i = widget.selectedIndex!;
                          widget.listForm.move(i, i + 1);
                          widget.selectIndex(i + 1);
                        },
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail pane — the same CustomerDetailForm re-bound on selection.
// ---------------------------------------------------------------------------
class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.form});

  final CustomerDetailForm form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: form.changes,
          builder: (context, _) {
            // The detail content (5 form fields + error view + button row)
            // can exceed the available height — especially when the demo
            // packs two scaffolds side-by-side. Wrap in a scroll view so
            // it adapts gracefully to smaller heights.
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('Detail (formId: ${form.formId})',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (form.isDirty)
                      const Chip(
                        label: Text('Dirty'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ]),
                  const SizedBox(height: 8),
                  form.fullName.widget,
                  const SizedBox(height: 8),
                  form.email.widget,
                  const SizedBox(height: 8),
                  form.phone.widget,
                  const SizedBox(height: 8),
                  form.company.widget,
                  const SizedBox(height: 8),
                  form.tier.widget,
                  const SizedBox(height: 12),
                  TomErrorView(form: form, title: 'Detail form errors'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save'),
                        onPressed: () async {
                          final ok = await form.save();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Saved customer.'
                                  : 'Validation failed — check errors.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Discard'),
                        onPressed: () => form.discard(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One row in the master pane. Subscribed to the bound customer's
// `fullName` and `company` TomString observables via
// `TomMultiObservableBuilder`, so any mutation (detail-form save in
// either scaffold, programmatic update, anything) reflects immediately
// in both lists. See round-5 feedback (a).
// ---------------------------------------------------------------------------
class _CustomerListTile extends StatelessWidget {
  const _CustomerListTile({
    required this.customer,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final Customer? customer;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    if (c == null) {
      return _tile(context, title: '(unbound)', subtitle: '');
    }
    return TomMultiObservableBuilder(
      observables: [c.fullName, c.company],
      builder: (context) => _tile(
        context,
        title: c.fullName.get(),
        subtitle: c.company.get(),
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required String title, required String subtitle}) {
    return ListTile(
      selected: isSelected,
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        child: Text(
          '${index + 1}',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      title: Text(
        title.isEmpty ? '(unnamed)' : title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
