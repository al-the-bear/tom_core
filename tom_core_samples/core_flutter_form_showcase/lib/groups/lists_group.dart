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
// Why: extends [TomStatefulWidget]/[TomState] (not raw) so the demo payload
// conforms to G-UI-2. No tomId/resources → scope bases, which are non-const
// (construction reads [TomScope.current]).
class _InlineOrderList extends TomStatefulWidget {
  _InlineOrderList();

  @override
  TomState<_InlineOrderList> createState() => _InlineOrderListState();
}

class _InlineOrderListState extends TomState<_InlineOrderList> {
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
  Widget buildContent(BuildContext context) {
    return TomSizedBox(
      height: 460,
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TomExpanded(
            child: TomInlineListForm<OrderItem, OrderItemForm>(
              listForm: _listForm,
              reorderable: true,
              rowBuilder: (context, index, rowForm) => TomCard(
                key: ValueKey('order-row-${rowForm.hashCode}'),
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: index == _selectedIndex
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                child: TomInkWell(
                  onTap: () => _select(index),
                  child: TomPadding(
                    padding: const EdgeInsets.all(8),
                    child: TomRow(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TomReorderHandle(index: index),
                        TomSizedBox(width: 8),
                        TomExpanded(
                            flex: 3, child: rowForm.productName.widget),
                        TomSizedBox(width: 8),
                        TomExpanded(child: rowForm.quantity.widget),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          TomDivider(height: 8),
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
      child: _InlineOrderList(),
    ),
  ],
);
