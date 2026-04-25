import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../tom_form.dart';
import 'tom_list_form.dart';
import 'tom_reorder_handle.dart';

// ---------------------------------------------------------------------------
// TomInlineListForm — Phase 2a §16
// ---------------------------------------------------------------------------

/// Renders a [TomListForm] as a vertically stacked sequence of inline
/// per-row sub-forms — each row is its row's [TForm] rendered in place
/// (no master-detail split, no expansion/collapse).
///
/// This is the right component when the natural editing UX is "every row
/// is always visible and always editable", e.g. an order-items table with
/// inline cells (H-D's items, H-C's editable rows). Each row sees the
/// same [TForm] instance the [TomListForm] owns — there is no sibling
/// form bound to the same [TomClass], so structural mutations and dirty
/// state propagate cleanly through the standard child-container chain.
///
/// The widget is layout-agnostic: callers supply [rowBuilder] for the row
/// body and may optionally supply [headerBuilder] / [footerBuilder] /
/// [toolbarBuilder] / [rowSeparatorBuilder] / [emptyBuilder] to compose
/// the surrounding chrome. Add / remove buttons are NOT built in — wire
/// them in [toolbarBuilder] (typically using `TomListFormToolbar`).
///
/// Drag-and-drop reordering: pass [reorderable]: true. The widget then
/// renders rows inside a [ReorderableListView] (shrink-wrapped, no inner
/// scrolling) and forwards `onReorder` events to
/// [TomListForm.reorder]. To add a visible drag handle inside the row,
/// place a [TomReorderHandle] anywhere in [rowBuilder]:
///
/// ```dart
/// rowBuilder: (ctx, i, form) => Row(children: [
///   TomReorderHandle(index: i),
///   Expanded(child: form.label.widget),
/// ])
/// ```
///
/// The widget observes [listForm] and rebuilds on any structural change
/// (rows added / removed / reordered) and on per-row field edits, so
/// builder closures may freely read row-form state without each builder
/// needing its own observer wiring.
///
/// Example:
///
/// ```dart
/// TomInlineListForm<OrderItem, OrderItemForm>(
///   listForm: form.items,
///   reorderable: true,
///   headerBuilder: (ctx, list) => const _ItemsTableHeader(),
///   rowBuilder: (ctx, i, row) => Row(children: [
///     TomReorderHandle(index: i),
///     Expanded(child: _ItemRow(index: i, form: row)),
///     IconButton(
///       icon: const Icon(Icons.delete_outline),
///       onPressed: () => form.items.removeAt(i),
///     ),
///   ]),
///   toolbarBuilder: (ctx, list) => TomListFormToolbar(listForm: list),
///   emptyBuilder: (ctx) => const Text('No items yet.'),
/// )
/// ```
class TomInlineListForm<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends StatefulWidget {
  const TomInlineListForm({
    super.key,
    required this.listForm,
    required this.rowBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.toolbarBuilder,
    this.emptyBuilder,
    this.rowSeparatorBuilder,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.reorderable = false,
    this.onReorder,
    this.proxyDecorator,
  });

  /// The list whose rows are rendered inline.
  final TomListForm<TItem, TForm> listForm;

  /// Builds the body for row [index]. The provided [rowForm] is the
  /// list's own sub-form for that index — the same instance reachable via
  /// `listForm[index]`. Bind any per-row controls (delete buttons, drag
  /// handles, dirty chips) to this form.
  final Widget Function(BuildContext context, int index, TForm rowForm)
      rowBuilder;

  /// Optional header rendered above every row (and above the empty
  /// state). Use for column-title strips, dirty chips, totals.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
  )? headerBuilder;

  /// Optional footer rendered below every row (and below the empty
  /// state). Use for grand totals, summary banners, cross-row error
  /// strips.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
  )? footerBuilder;

  /// Optional toolbar rendered after [footerBuilder]. Conventionally
  /// hosts the Add / Remove all / bulk-action buttons.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
  )? toolbarBuilder;

  /// Optional widget shown in place of any rows when the list is empty.
  /// Header / footer / toolbar still render around it.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Optional separator inserted between consecutive rows. The [index]
  /// is the row that PRECEDES the separator (i.e. the separator above
  /// row N has index N-1; never built before row 0 or after the last).
  ///
  /// **Ignored when [reorderable] is true** — [ReorderableListView]
  /// renders one widget per row with no slots for between-row content,
  /// so any separator must live inside the row itself.
  final Widget Function(BuildContext context, int index)? rowSeparatorBuilder;

  /// Outer padding applied to the entire stack.
  final EdgeInsetsGeometry? padding;

  /// Cross-axis alignment of the inner [Column]. Defaults to
  /// [CrossAxisAlignment.stretch] so rows fill the available width.
  final CrossAxisAlignment crossAxisAlignment;

  /// When `true`, rows are rendered inside a [ReorderableListView] and
  /// can be reordered via long-press or by dragging a [TomReorderHandle]
  /// embedded in the row body. Reorder events are forwarded to
  /// [TomListForm.reorder] (and [onReorder] if supplied).
  final bool reorderable;

  /// Optional reorder hook. When set, called *after* the underlying
  /// [TomListForm.reorder] runs so callers can update selection or fire
  /// follow-up effects. The arguments are normalised to the
  /// [TomListForm] convention — `to` is the destination index AFTER the
  /// reorder, regardless of move direction (NOT
  /// [ReorderableListView]'s pre-removal convention).
  final void Function(int from, int to)? onReorder;

  /// Custom proxy decorator forwarded to the underlying
  /// [ReorderableListView] when [reorderable] is true. Use to style the
  /// floating row that follows the user's finger / pointer during a
  /// drag.
  final Widget Function(Widget child, int index, Animation<double> animation)?
      proxyDecorator;

  @override
  State<TomInlineListForm<TItem, TForm>> createState() =>
      _TomInlineListFormState<TItem, TForm>();
}

class _TomInlineListFormState<TItem extends TomClass,
        TForm extends TomForm<TItem>>
    extends State<TomInlineListForm<TItem, TForm>> implements TomObserver {
  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant TomInlineListForm<TItem, TForm> old) {
    super.didUpdateWidget(old);
    if (!identical(old.listForm, widget.listForm)) {
      old.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable _) {
    if (mounted) setState(() {});
  }

  Widget _buildRows(BuildContext context, TomListForm<TItem, TForm> list) {
    if (widget.reorderable) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        proxyDecorator: widget.proxyDecorator,
        onReorder: (from, to) {
          // ReorderableListView reports `to` as the index *after*
          // removal when moving downward — normalise to TomListForm
          // semantics so callers see a single, consistent convention.
          final adjusted = to > from ? to - 1 : to;
          if (adjusted == from) return;
          list.reorder(from, adjusted);
          widget.onReorder?.call(from, adjusted);
        },
        itemBuilder: (context, i) {
          // Each ReorderableListView child must carry a stable key.
          // We embed both the row's index and its form identity so that
          // reordered rows keep their per-row state intact across the
          // structural mutation.
          return KeyedSubtree(
            key: ValueKey('tom-inline-row-${list[i].hashCode}-$i'),
            child: widget.rowBuilder(context, i, list[i]),
          );
        },
      );
    }

    final rowChildren = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      if (i > 0 && widget.rowSeparatorBuilder != null) {
        rowChildren.add(widget.rowSeparatorBuilder!(context, i - 1));
      }
      rowChildren.add(widget.rowBuilder(context, i, list[i]));
    }
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: rowChildren,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.listForm;
    final children = <Widget>[];

    final header = widget.headerBuilder?.call(context, list);
    if (header != null) children.add(header);

    if (list.isEmpty) {
      final empty = widget.emptyBuilder?.call(context);
      if (empty != null) children.add(empty);
    } else {
      children.add(_buildRows(context, list));
    }

    final footer = widget.footerBuilder?.call(context, list);
    if (footer != null) children.add(footer);

    final toolbar = widget.toolbarBuilder?.call(context, list);
    if (toolbar != null) children.add(toolbar);

    final column = Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    return widget.padding != null
        ? Padding(padding: widget.padding!, child: column)
        : column;
  }
}
