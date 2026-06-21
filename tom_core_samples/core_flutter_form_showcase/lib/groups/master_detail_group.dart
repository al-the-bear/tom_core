/// Master-detail group — the [TomMasterDetailListForm] scaffold.
///
/// One pane lists the order items; selecting a row opens that row's own
/// sub-form in the detail pane. Selection is scaffold-local while edits and
/// structural changes flow through the shared [TomListForm], and an
/// unsaved-changes guard intercepts switching away from a dirty row.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/order_item_form.dart';

/// A self-contained master-detail editor over a seeded order-items list.
class _MasterDetailDemo extends StatefulWidget {
  const _MasterDetailDemo();

  @override
  State<_MasterDetailDemo> createState() => _MasterDetailDemoState();
}

class _MasterDetailDemoState extends State<_MasterDetailDemo> {
  late final OrderItemListForm _listForm;

  @override
  void initState() {
    super.initState();
    _listForm = TomScope.withScope('md_list', OrderItemListForm.new);
    _listForm.bind(seededOrderItems());
  }

  @override
  void dispose() {
    _listForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 440,
      child: TomMasterDetailListForm<OrderItem, OrderItemForm>(
        listForm: _listForm,
        masterPaneWidth: 220,
        draggableSplitter: true,
        initialSelectedIndex: 0,
        masterBuilder: (context, listForm, selected, selectIndex) =>
            _MasterPane(
          listForm: listForm,
          selectedIndex: selected,
          selectIndex: selectIndex,
        ),
        detailBuilder: (context, _, rowForm) => _DetailPane(form: rowForm),
      ),
    );
  }
}

class _MasterPane extends StatelessWidget {
  const _MasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<OrderItem, OrderItemForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Items (${listForm.length})',
                style: theme.textTheme.titleSmall),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: listForm.length,
              itemBuilder: (context, index) {
                final item = listForm[index].currentBinding;
                final selected = index == selectedIndex;
                return TomMultiObservableBuilder(
                  observables: item == null
                      ? const <TomObservable>[]
                      : [item.productName, item.quantity],
                  builder: (context) => ListTile(
                    dense: true,
                    selected: selected,
                    title: Text(
                      item == null || item.productName.get().isEmpty
                          ? '(new item)'
                          : item.productName.get(),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Qty ${item?.quantity.get() ?? ''}'),
                    onTap: () => selectIndex(index),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(4),
            child: TomListFormToolbar<OrderItem, OrderItemForm>(
              listForm: listForm,
              selectedIndex: selectedIndex,
              onSelectionChanged: selectIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.form});

  final OrderItemForm form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: form.changes,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Item detail',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (form.isDirty)
                      const Chip(
                        label: Text('Dirty'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                form.productName.widget,
                const SizedBox(height: 8),
                form.quantity.widget,
                const SizedBox(height: 8),
                form.unitPrice.widget,
                const SizedBox(height: 8),
                form.notes.widget,
                const SizedBox(height: 12),
                TomErrorView(form: form, title: 'Item errors'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save'),
                      onPressed: () => form.save(),
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
          ),
        ),
      ),
    );
  }
}

/// The Master-detail component group.
final ShowcaseGroup masterDetailGroup = ShowcaseGroup(
  id: 'master_detail',
  title: 'Master-detail',
  summary: 'A TomMasterDetailListForm: pick an item on the left to edit its '
      'own sub-form on the right, with an unsaved-changes guard on switch.',
  icon: Icons.vertical_split_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomMasterDetailListForm',
      note: 'Select a row to edit it on the right. Edit a field then pick '
          'another row to see the Save / Discard / Cancel guard.',
      code: "TomMasterDetailListForm<OrderItem, OrderItemForm>(\n"
          "  listForm: listForm,\n"
          "  masterPaneWidth: 220,\n"
          "  initialSelectedIndex: 0,\n"
          "  masterBuilder: (context, listForm, selected, selectIndex) =>\n"
          "      MasterPane(...),\n"
          "  detailBuilder: (context, _, rowForm) =>\n"
          "      DetailPane(form: rowForm),\n"
          ")",
      child: const _MasterDetailDemo(),
    ),
  ],
);
