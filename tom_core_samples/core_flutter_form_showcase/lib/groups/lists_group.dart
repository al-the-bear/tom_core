/// Lists group — editing a bound collection with [TomInlineListForm].
///
/// A [TomListForm] wraps a `TomList<OrderItem>`; the inline list renders one
/// row sub-form per item and the [TomListFormToolbar] adds, removes and
/// reorders rows. Structural mutations flow straight back into the bound list.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/order_item_form.dart';

/// A self-contained editable order-items list: inline rows plus a toolbar,
/// tracking the selected row so the toolbar's remove/move act on it.
class _InlineOrderList extends StatefulWidget {
  const _InlineOrderList();

  @override
  State<_InlineOrderList> createState() => _InlineOrderListState();
}

class _InlineOrderListState extends State<_InlineOrderList> {
  late final OrderItemListForm _listForm;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _listForm = TomScope.withScope('lists_inline', OrderItemListForm.new);
    _listForm.bind(seededOrderItems());
  }

  @override
  void dispose() {
    _listForm.dispose();
    super.dispose();
  }

  void _select(int? index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TomInlineListForm<OrderItem, OrderItemForm>(
              listForm: _listForm,
              reorderable: true,
              rowBuilder: (context, index, rowForm) => Card(
                key: ValueKey('order-row-${rowForm.hashCode}'),
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: index == _selectedIndex
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                child: InkWell(
                  onTap: () => _select(index),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomReorderHandle(index: index),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: rowForm.productName.widget),
                        const SizedBox(width: 8),
                        Expanded(child: rowForm.quantity.widget),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 8),
          TomListFormToolbar<OrderItem, OrderItemForm>(
            listForm: _listForm,
            selectedIndex: _selectedIndex,
            onSelectionChanged: (i) async => _select(i),
          ),
        ],
      ),
    );
  }
}

/// The Lists component group.
final ShowcaseGroup listsGroup = ShowcaseGroup(
  id: 'lists',
  title: 'Editable lists',
  summary: 'A TomListForm bound to a TomList<OrderItem>: inline row sub-forms, '
      'drag-to-reorder handles and the standard add/remove/move toolbar.',
  icon: Icons.list_alt_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'TomInlineListForm + toolbar',
      note: 'Tap a row to select it, then use the toolbar to remove or move '
          'it; drag the handle to reorder. Add appends a fresh OrderItem.',
      code: "TomInlineListForm<OrderItem, OrderItemForm>(\n"
          "  listForm: listForm,\n"
          "  reorderable: true,\n"
          "  rowBuilder: (context, index, rowForm) => Row(children: [\n"
          "    TomReorderHandle(index: index),\n"
          "    Expanded(flex: 3, child: rowForm.productName.widget),\n"
          "    Expanded(child: rowForm.quantity.widget),\n"
          "  ]),\n"
          ")\n"
          "// …\n"
          "TomListFormToolbar<OrderItem, OrderItemForm>(\n"
          "  listForm: listForm,\n"
          "  selectedIndex: selectedIndex,\n"
          "  onSelectionChanged: select,\n"
          ")",
      child: const _InlineOrderList(),
    ),
  ],
);
