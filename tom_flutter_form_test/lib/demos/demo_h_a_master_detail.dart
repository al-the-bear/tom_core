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

/// Exercises `tom_flutter_ui`'s `TomMasterDetailListForm` / `TomListForm`
/// master-detail pattern, with `TomListFormToolbar` and `TomReorderHandle`.
///
/// Left pane:  Reorderable list of customers driven by the shared
///             CustomerListForm. The standard TomListFormToolbar handles
///             add / remove / move up / move down. Each row exposes a
///             TomReorderHandle so it can be dragged to a new position.
/// Right pane: The selected customer's own row sub-form
///             (`listForm[selectedIndex]`) — there is NO sibling form
///             bound to the same Customer.
/// Bottom:     EventLogPanel showing the interleaved stream of list events
///             (added / removed / reordered) and per-row form events
///             (value / validation) coming through the shared event bus.
///
/// Two TomMasterDetailListForm instances share one TomListForm so the demo
/// shows that selection state is per-scaffold while structural mutations
/// and field edits flow through both panes immediately.
class DemoHAMasterDetail extends StatefulWidget {
  const DemoHAMasterDetail({super.key});

  @override
  State<DemoHAMasterDetail> createState() => _DemoHAMasterDetailState();
}

class _DemoHAMasterDetailState extends State<DemoHAMasterDetail> {
  late final CustomerListForm _listForm;
  late final TomFormInspector _inspector;

  /// Bridges the [TomListForm]'s event bus into a [ChangeNotifier] so the
  /// [EventLogPanel] (which expects a [Listenable]) can rebuild whenever
  /// list / row events fire. The inspector swallows the events itself;
  /// this notifier just relays "something happened".
  final ChangeNotifier _eventTick = ChangeNotifier();
  late final TomFormEventListener _eventTickListener;

  @override
  void initState() {
    super.initState();
    _listForm = TomScope.withScope('demoHA', () => CustomerListForm());
    _listForm.bind(phase2aCustomers.customers);
    _inspector = TomFormInspector();
    _listForm.addListener(_inspector);
    _eventTickListener = _RelayListener(() {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      _eventTick.notifyListeners();
    });
    _listForm.addListener(_eventTickListener);
  }

  @override
  void dispose() {
    _listForm.removeListener(_eventTickListener);
    _listForm.removeListener(_inspector);
    _listForm.dispose();
    _eventTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H-A — Master-Detail Customer Editor',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _intro(context),
            const SizedBox(height: 12),
            // Round-7: bumped to fit detail header + 5 fields + error
            // view + Save / Discard row at common viewport sizes.
            SizedBox(
              height: 660,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ScaffoldFrame(
                      label: 'Scaffold A — no preselection',
                      child:
                          TomMasterDetailListForm<Customer, CustomerDetailForm>(
                            listForm: _listForm,
                            masterPaneWidth: 240,
                            draggableSplitter: true,
                            minMasterPaneWidth: 160,
                            maxMasterPaneWidth: 600,
                            masterBuilder:
                                (context, listForm, selected, selectIndex) =>
                                    _CustomerMasterPane(
                                      listForm: listForm,
                                      selectedIndex: selected,
                                      selectIndex: selectIndex,
                                    ),
                            detailBuilder: (context, _, rowForm) =>
                                _DetailPane(form: rowForm),
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ScaffoldFrame(
                      label: 'Scaffold B — preselects row 0',
                      child:
                          TomMasterDetailListForm<Customer, CustomerDetailForm>(
                            listForm: _listForm,
                            masterPaneWidth: 240,
                            draggableSplitter: true,
                            minMasterPaneWidth: 160,
                            maxMasterPaneWidth: 600,
                            initialSelectedIndex: 0,
                            masterBuilder:
                                (context, listForm, selected, selectIndex) =>
                                    _CustomerMasterPane(
                                      listForm: listForm,
                                      selectedIndex: selected,
                                      selectIndex: selectIndex,
                                    ),
                            detailBuilder: (context, _, rowForm) =>
                                _DetailPane(form: rowForm),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InfoPanel(
              title: 'Event log (shared list-form bus)',
              children: [
                EventLogPanel(inspector: _inspector, rebuildOn: _eventTick),
              ],
            ),
          ],
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
              'Two TomMasterDetailListForm instances bound to the SAME '
              'TomListForm. Scaffold B preselects row 0 via its '
              'initialSelectedIndex parameter, while Scaffold A starts '
              'with no selection. Each detail pane edits the row\'s own '
              'sub-form (`listForm[selectedIndex]`) — no sibling form, '
              'no rebinding. Click a customer to edit them on the '
              'right; make a change and click another row to see the '
              'unsaved-changes guard pop Save / Discard / Cancel before '
              'switching. The toolbar (Add / Remove / Move up / Move '
              'down) and the per-row drag handles both drive the same '
              'TomListForm so events appear interleaved in the log '
              'below.',
            ),
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
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
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
    : super(listId: 'customerDetail', formFactory: (_) => CustomerDetailForm());

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
// Master pane — reorderable list of customer summaries + standard toolbar.
// ---------------------------------------------------------------------------
class _CustomerMasterPane extends StatelessWidget {
  const _CustomerMasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<Customer, CustomerDetailForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

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
              child: Text(
                'Customers (${listForm.length})',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: TomInlineListForm<Customer, CustomerDetailForm>(
                listForm: listForm,
                reorderable: true,
                onReorder: (from, to) {
                  // Keep the user's selection on the row they just dragged.
                  if (selectedIndex == from) {
                    selectIndex(to);
                  } else if (selectedIndex != null) {
                    final cur = selectedIndex!;
                    if (from < cur && cur <= to) {
                      selectIndex(cur - 1);
                    } else if (to <= cur && cur < from) {
                      selectIndex(cur + 1);
                    }
                  }
                },
                rowBuilder: (context, i, rowForm) => _CustomerListTile(
                  key: ValueKey('h-a-cust-${rowForm.hashCode}'),
                  customer: rowForm.currentBinding,
                  index: i,
                  isSelected: i == selectedIndex,
                  onTap: () => selectIndex(i),
                ),
              ),
            ),
            const Divider(height: 8),
            TomListFormToolbar<Customer, CustomerDetailForm>(
              listForm: listForm,
              selectedIndex: selectedIndex,
              onSelectionChanged: selectIndex,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail pane — renders the row's own sub-form directly.
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
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detail (formId: ${form.formId})',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (form.isDirty)
                        const Chip(
                          label: Text('Dirty'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
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
                              content: Text(
                                ok
                                    ? 'Saved customer.'
                                    : 'Validation failed — check errors.',
                              ),
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
// `TomMultiObservableBuilder`, so any mutation (detail edit in either
// scaffold, programmatic update, anything) reflects immediately in
// both lists.
// ---------------------------------------------------------------------------
class _CustomerListTile extends StatelessWidget {
  const _CustomerListTile({
    super.key,
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
      builder: (context) =>
          _tile(context, title: c.fullName.get(), subtitle: c.company.get()),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      selected: isSelected,
      dense: true,
      leading: TomReorderHandle(index: index),
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

// ---------------------------------------------------------------------------
// Tiny adapter — relays every TomFormEventListener event to a single
// callback. Used to bridge the TomListForm event bus into a Flutter
// Listenable for the EventLogPanel.
// ---------------------------------------------------------------------------
class _RelayListener with TomFormEventListener {
  _RelayListener(this._onAny);
  final VoidCallback _onAny;

  @override
  void handleEvent(TomFormEvent event) {
    super.handleEvent(event);
    _onAny();
  }
}
