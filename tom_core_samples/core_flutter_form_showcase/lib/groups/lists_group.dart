/// Lists group — editing a bound collection with [TomInlineListForm].
///
/// A [TomListForm] wraps a `TomList<OrderItem>`; the inline list renders one
/// row sub-form per item and the [TomListFormToolbar] adds, removes and
/// reorders rows. Structural mutations flow straight back into the bound list.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/form_host.dart';
import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/showcase_entities.dart';
import '../forms/order_item_form.dart';

/// The inline rows plus toolbar for an already-live [listForm], tracking the
/// selected row so the toolbar's remove/move act on it.
///
/// Selection is the only state here: [ListFormHost] owns the list form's
/// creation, binding and disposal, so this widget has one reason to change.
// Why: extends [TomStatefulWidget]/[TomState] (not raw) so the demo payload
// conforms to G-UI-2. No tomId/resources → scope bases, which are non-const
// (construction reads [TomScope.current]).
class _InlineOrderList extends TomStatefulWidget {
  _InlineOrderList({required this.listForm});

  /// The live list form supplied by the enclosing [ListFormHost].
  final TomListForm<OrderItem, OrderItemForm> listForm;

  @override
  TomState<_InlineOrderList> createState() => _InlineOrderListState();
}

class _InlineOrderListState extends TomState<_InlineOrderList> {
  int? _selectedIndex;

  void _select(int? index) => setState(() => _selectedIndex = index);

  @override
  Widget buildContent(BuildContext context) {
    return TomSizedBox(
      height: 460,
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TomInlineListForm shrink-wraps its rows and never scrolls itself,
          // so it renders at its natural height wherever it is placed. In a
          // bounded pane the pane supplies the scrolling — which is also the
          // arrangement an application copies: the list grows with the data,
          // the surrounding region decides how much of it is on screen.
          TomExpanded(
            child: TomSingleChildScrollView(
              child: TomInlineListForm<OrderItem, OrderItemForm>(
                listForm: widget.listForm,
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
          ),
          TomDivider(height: 8),
          TomListFormToolbar<OrderItem, OrderItemForm>(
            listForm: widget.listForm,
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
      // Verbatim `_InlineOrderListState.buildContent`, less the fixed-height
      // TomSizedBox that only the showcase cell needs (declared in the leading
      // comment) and the `widget.` / `_` prefixes the reader supplies. Every
      // layout primitive is the Tom one, because that is the sample's own rule
      // (G-UI-1) — a snippet showing `Row`/`Expanded` here would teach the
      // opposite of what the surrounding code does.
      code: "// The inline list shrink-wraps and never scrolls itself, so the\n"
          "// bounded pane above the toolbar supplies the scrolling.\n"
          "TomColumn(\n"
          "  crossAxisAlignment: CrossAxisAlignment.stretch,\n"
          "  children: [\n"
          "    TomExpanded(\n"
          "      child: TomSingleChildScrollView(\n"
          "        child: TomInlineListForm<OrderItem, OrderItemForm>(\n"
          "          listForm: listForm,\n"
          "          reorderable: true,\n"
          "          rowBuilder: (context, index, rowForm) => TomCard(\n"
          "            key: ValueKey('order-row-\${rowForm.hashCode}'),\n"
          "            margin: const EdgeInsets.symmetric(vertical: 4),\n"
          "            color: index == selectedIndex\n"
          "                ? Theme.of(context).colorScheme.surfaceContainerHighest\n"
          "                : null,\n"
          "            child: TomInkWell(\n"
          "              onTap: () => _select(index),\n"
          "              child: TomPadding(\n"
          "                padding: const EdgeInsets.all(8),\n"
          "                child: TomRow(\n"
          "                  crossAxisAlignment: CrossAxisAlignment.start,\n"
          "                  children: [\n"
          "                    TomReorderHandle(index: index),\n"
          "                    TomSizedBox(width: 8),\n"
          "                    TomExpanded(\n"
          "                        flex: 3, child: rowForm.productName.widget),\n"
          "                    TomSizedBox(width: 8),\n"
          "                    TomExpanded(child: rowForm.quantity.widget),\n"
          "                  ],\n"
          "                ),\n"
          "              ),\n"
          "            ),\n"
          "          ),\n"
          "        ),\n"
          "      ),\n"
          "    ),\n"
          "    TomDivider(height: 8),\n"
          "    TomListFormToolbar<OrderItem, OrderItemForm>(\n"
          "      listForm: listForm,\n"
          "      selectedIndex: selectedIndex,\n"
          "      onSelectionChanged: (i) async => _select(i),\n"
          "    ),\n"
          "  ],\n"
          ")",
      child: ListFormHost<OrderItem, OrderItemForm>(
        scopeId: 'lists_inline',
        create: OrderItemListForm.new,
        items: seededOrderItems,
        builder: (context, listForm) => _InlineOrderList(listForm: listForm),
      ),
    ),
  ],
);
