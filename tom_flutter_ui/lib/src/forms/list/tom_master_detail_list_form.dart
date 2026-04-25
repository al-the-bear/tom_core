import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../tom_form.dart';
import '../widgets/tom_unsaved_changes_guard.dart';
import 'tom_list_form.dart';

// ---------------------------------------------------------------------------
// TomMasterDetailListForm — Phase 2a §16
// ---------------------------------------------------------------------------

/// Two-pane master-detail layout that consumes a [TomListForm] directly —
/// no separate "detail form" instance is needed.
///
/// This is the no-sibling-form architecture of [TomInlineListForm] and
/// [TomExpandableListForm] applied to the master-detail UX: when the
/// user picks row N in the master pane, the detail builder is handed
/// `listForm[N]` (the [TForm] the list itself owns). Because there is
/// no second form bound to the same [TomClass], dirty state and value
/// changes propagate cleanly through the standard child-container
/// chain — the detail's `isDirty` rolls into the master list-form's
/// `isDirty`, which rolls into the parent form's `isDirty`, and so on.
///
/// The widget is layout-agnostic: callers supply [masterBuilder] for
/// the left pane and [detailBuilder] for the right pane. The master
/// builder receives the current selection + a `selectIndex` callback
/// that runs the unsaved-changes guard (when [guardUnsavedSelectionChange]
/// is true) before rebuilding.
///
/// Example:
///
/// ```dart
/// TomMasterDetailListForm<ShippingAddress, ShippingAddressForm>(
///   listForm: form.shippingAddresses,
///   masterPaneWidth: 220,
///   masterBuilder: (ctx, list, selected, selectIndex) => AddressMasterPane(
///     listForm: list, selectedIndex: selected, selectIndex: selectIndex,
///   ),
///   detailBuilder: (ctx, index, rowForm) => AddressDetailPane(form: rowForm),
/// )
/// ```
///
/// Multiple [TomMasterDetailListForm] instances may share the same
/// [TomListForm] — each maintains its own selection observable, so
/// scaffold A may be looking at row 0 while scaffold B is looking at
/// row 2. (See Demo H-A for the canonical two-scaffold-one-list demo.)
class TomMasterDetailListForm<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends StatefulWidget {
  const TomMasterDetailListForm({
    super.key,
    required this.listForm,
    required this.masterBuilder,
    required this.detailBuilder,
    this.emptyDetailBuilder,
    this.masterPaneWidth = 280,
    this.gap = 16,
    this.guardUnsavedSelectionChange = true,
    this.initialSelectedIndex,
  });

  /// The list whose rows feed both panes.
  final TomListForm<TItem, TForm> listForm;

  /// Optional initial selection. When non-null, the widget runs
  /// `selectIndex(initialSelectedIndex)` on the first frame so the detail
  /// pane comes up already showing that row.
  ///
  /// The value is consulted only on the very first build; subsequent
  /// changes are ignored (selection becomes user-driven from then on).
  final int? initialSelectedIndex;

  /// Builds the master pane (typically a list of summaries plus an
  /// add/remove/reorder toolbar). The provided callback re-runs the
  /// unsaved-changes guard, applies the selection, and rebuilds the
  /// scaffold.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
    int? selectedIndex,
    Future<void> Function(int? index) selectIndex,
  ) masterBuilder;

  /// Builds the detail pane. The provided [rowForm] is the row's own
  /// sub-form (`listForm[selectedIndex]`) — bind any field widgets,
  /// Save/Discard buttons, error views directly to it.
  ///
  /// When nothing is selected (or the index is out of range) this
  /// builder is NOT called — [emptyDetailBuilder] runs instead.
  final Widget Function(
    BuildContext context,
    int selectedIndex,
    TForm rowForm,
  ) detailBuilder;

  /// Optional widget shown when nothing is selected. Defaults to a
  /// centred italic hint.
  final WidgetBuilder? emptyDetailBuilder;

  final double masterPaneWidth;
  final double gap;

  /// When `true` (default), selection changes prompt Save/Discard/Cancel
  /// if the currently-selected row's sub-form is dirty. Set to `false`
  /// to switch silently.
  final bool guardUnsavedSelectionChange;

  @override
  State<TomMasterDetailListForm<TItem, TForm>> createState() =>
      _TomMasterDetailListFormState<TItem, TForm>();
}

class _TomMasterDetailListFormState<TItem extends TomClass,
        TForm extends TomForm<TItem>>
    extends State<TomMasterDetailListForm<TItem, TForm>>
    implements TomObserver {
  final TomNInt _selectedIndex = TomNInt(null);

  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
    _selectedIndex.addObserver(this);
    final initial = widget.initialSelectedIndex;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectIndex(initial);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TomMasterDetailListForm<TItem, TForm> old) {
    super.didUpdateWidget(old);
    if (!identical(old.listForm, widget.listForm)) {
      old.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
      // The previous selection may not point to a meaningful row in
      // the new list — clear it to avoid the detail pane flashing
      // stale content.
      _selectedIndex | null;
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    _selectedIndex.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable observable) {
    if (!mounted) return;
    // Defensive: if the list shrinks past the current selection (e.g. a
    // remove from outside this widget), clear the selection so the
    // detail pane falls back to the empty builder instead of trying to
    // render an out-of-range row.
    final cur = ~_selectedIndex;
    if (cur != null && cur >= widget.listForm.length) {
      _selectedIndex | null;
    }
    setState(() {});
  }

  Future<void> _selectIndex(int? index) async {
    final current = ~_selectedIndex;
    if (current == index) return;

    Future<void> apply() async {
      _selectedIndex | index;
    }

    if (widget.guardUnsavedSelectionChange &&
        current != null &&
        current >= 0 &&
        current < widget.listForm.length) {
      final rowForm = widget.listForm[current];
      await guardUnsavedChanges(
        context: context,
        form: rowForm,
        action: apply,
      );
    } else {
      await apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ~_selectedIndex;
    final master = widget.masterBuilder(
      context,
      widget.listForm,
      selected,
      _selectIndex,
    );

    Widget detail;
    if (selected == null ||
        selected < 0 ||
        selected >= widget.listForm.length) {
      detail = widget.emptyDetailBuilder?.call(context) ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Select an item from the list to edit it.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          );
    } else {
      detail = widget.detailBuilder(
        context,
        selected,
        widget.listForm[selected],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: widget.masterPaneWidth, child: master),
        SizedBox(width: widget.gap),
        Expanded(child: detail),
      ],
    );
  }
}
