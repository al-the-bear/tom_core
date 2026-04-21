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
  late final CustomerListForm _listForm;
  late final CustomerDetailForm _detailForm;
  late final TomFormInspector _inspector;

  @override
  void initState() {
    super.initState();
    _listForm = TomScope.withScope('demoHA', () => CustomerListForm());
    _detailForm =
        TomScope.withScope('demoHA', () => CustomerDetailForm());
    _listForm.bind(phase2aCustomers.customers);
    _inspector = TomFormInspector();
    _listForm.addListener(_inspector);
    _detailForm.addListener(_inspector);
  }

  @override
  void dispose() {
    _listForm.removeListener(_inspector);
    _detailForm.removeListener(_inspector);
    _listForm.dispose();
    _detailForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H-A — Master-Detail Customer Editor',
      child: TomUnsavedChangesGuard(
        form: _detailForm,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _intro(context),
              const SizedBox(height: 12),
              SizedBox(
                height: 460,
                child: TomMasterDetailScaffold<Customer, CustomerDetailForm>(
                  listForm: _listForm,
                  detailForm: _detailForm,
                  masterPaneWidth: 280,
                  masterBuilder: (context, listForm, selected, selectIndex) =>
                      _MasterPane(
                    listForm: listForm,
                    selectedIndex: selected,
                    selectIndex: selectIndex,
                  ),
                  detailBuilder: (context, form) =>
                      _DetailPane(form: form),
                ),
              ),
              const SizedBox(height: 12),
              InfoPanel(
                title: 'Event log (list + detail)',
                children: [
                  EventLogPanel(
                    inspector: _inspector,
                    rebuildOn: _detailForm.changes,
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
                'Click a customer in the master list to edit them on the '
                'right. Make a change and click another row — the master-'
                'detail scaffold runs the unsaved-changes guard and pops '
                'Save / Discard / Cancel before re-binding the detail '
                'form. Add / Remove / Move Up / Move Down emit list '
                'events into the bus that the detail form already shares — '
                'see them interleaved in the event log below.'),
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
                      customer?.fullName.get() ?? '(unbound)',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      customer?.company.get() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text('Detail (formId: ${form.formId})',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
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
            );
          },
        ),
      ),
    );
  }
}
