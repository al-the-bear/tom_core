/// Master-detail group — the [TomMasterDetailListForm] scaffold.
///
/// One pane lists the order items; selecting a row opens that row's own
/// sub-form in the detail pane. Selection is scaffold-local while edits and
/// structural changes flow through the shared [TomListForm], and an
/// unsaved-changes guard intercepts switching away from a dirty row.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/order_item_form.dart';

// Why: scope-participating layout wrapper (no tomId/resources) →
// [TomStatelessWidget], non-const; raw layout primitives swapped for Tom ones.
class _MasterPane extends TomStatelessWidget {
  _MasterPane({
    required this.listForm,
    required this.selectedIndex,
    required this.selectIndex,
  });

  final TomListForm<OrderItem, OrderItemForm> listForm;
  final int? selectedIndex;
  final Future<void> Function(int? index) selectIndex;

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TomPadding(
            padding: const EdgeInsets.all(8),
            child: TomText(
                text: 'Items (${listForm.length})',
                style: theme.textTheme.titleSmall),
          ),
          TomDivider(height: 1),
          TomExpanded(
            child: TomListView.builder(
              itemCount: listForm.length,
              itemBuilder: (context, index) {
                final item = listForm[index].currentBinding;
                final selected = index == selectedIndex;
                return TomMultiObservableBuilder(
                  observables: item == null
                      ? const <TomObservable>[]
                      : [item.productName, item.quantity],
                  builder: (context) {
                    final name = item == null || item.productName.get().isEmpty
                        ? '(new item)'
                        : item.productName.get();
                    return TomListTile(
                      dense: true,
                      selected: selected,
                      titleText: name,
                      subtitle: TomText(text: 'Qty ${item?.quantity.get() ?? ''}'),
                      onTap: () => selectIndex(index),
                    );
                  },
                );
              },
            ),
          ),
          TomDivider(height: 1),
          TomPadding(
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

// Why: scope-participating layout wrapper (no tomId/resources) →
// [TomStatelessWidget], non-const; raw layout primitives swapped for Tom ones.
class _DetailPane extends TomStatelessWidget {
  _DetailPane({required this.form});

  final OrderItemForm form;

  @override
  Widget buildContent(BuildContext context) {
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(12),
        child: TomListenableBuilder(
          listenable: form.changes,
          builder: (context, _) => TomSingleChildScrollView(
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TomRow(
                  children: [
                    TomExpanded(
                      child: TomText(
                          text: 'Item detail',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (form.isDirty)
                      TomChip(
                        labelText: 'Dirty',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                TomSizedBox(height: 8),
                form.productName.widget,
                TomSizedBox(height: 8),
                form.quantity.widget,
                TomSizedBox(height: 8),
                form.unitPrice.widget,
                TomSizedBox(height: 8),
                form.notes.widget,
                TomSizedBox(height: 12),
                TomErrorView(form: form, title: 'Item errors'),
                TomSizedBox(height: 12),
                TomWrap(
                  spacing: 8,
                  children: [
                    TomFilledButton(
                      icon: TomIcon(icon: Icons.save, size: 16),
                      label: 'Save',
                      onPressed: () => form.save(),
                    ),
                    TomOutlinedButton(
                      icon: TomIcon(icon: Icons.undo, size: 16),
                      label: 'Discard',
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
      note: 'Select a row to edit it on the right, and drag the splitter to '
          'rebalance the panes. Edit a field then pick another row to see the '
          'Save / Discard / Cancel guard.',
      code: "TomMasterDetailListForm<OrderItem, OrderItemForm>(\n"
          "  listForm: listForm,\n"
          "  masterPaneWidth: 220,\n"
          "  draggableSplitter: true,\n"
          "  initialSelectedIndex: 0,\n"
          "  masterBuilder: (context, listForm, selected, selectIndex) =>\n"
          "      MasterPane(...),\n"
          "  detailBuilder: (context, _, rowForm) =>\n"
          "      DetailPane(form: rowForm),\n"
          ")",
      // The master pane is a fixed 220px; below ~560 the detail pane has no
      // room left for its field column, so the cell stacks rather than split.
      previewMinWidth: 560,
      child: ListFormHost<OrderItem, OrderItemForm>(
        scopeId: 'md_list',
        create: OrderItemListForm.new,
        items: seededOrderItems,
        builder: (context, listForm) => TomSizedBox(
          height: 440,
          child: TomMasterDetailListForm<OrderItem, OrderItemForm>(
            listForm: listForm,
            masterPaneWidth: 220,
            draggableSplitter: true,
            initialSelectedIndex: 0,
            // The scaffold hands its own reference back; it is the same
            // instance the host created, so `_` it and close over `listForm`
            // rather than shadow the name.
            masterBuilder: (context, _, selected, selectIndex) => _MasterPane(
              listForm: listForm,
              selectedIndex: selected,
              selectIndex: selectIndex,
            ),
            detailBuilder: (context, _, rowForm) => _DetailPane(form: rowForm),
          ),
        ),
      ),
    ),
  ],
);
