import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../list/tom_list_form.dart';
import '../tom_form.dart';
import 'tom_unsaved_changes_guard.dart';

/// Two-pane master-detail scaffold (§15).
///
/// Owns the selection observable, listens to the bound [TomListForm] for
/// add / remove / reorder, and rebinds [detailForm] whenever the
/// selection changes. Selection changes are routed through
/// [guardUnsavedChanges] so a dirty detail form prompts Save / Discard /
/// Cancel before switching items.
///
/// The widget itself is layout-agnostic: callers supply [masterBuilder]
/// for the left pane (list rendering, add/remove/reorder buttons) and
/// [detailBuilder] for the right pane (the editor for the currently
/// selected item). The provided [TomListForm] handles all the actual
/// data plumbing — this scaffold just wires the cross-pane glue.
class TomMasterDetailScaffold<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends StatefulWidget {
  const TomMasterDetailScaffold({
    super.key,
    required this.listForm,
    required this.detailForm,
    required this.masterBuilder,
    required this.detailBuilder,
    this.emptyDetailBuilder,
    this.masterPaneWidth = 280,
    this.gap = 16,
    this.guardUnsavedSelectionChange = true,
  });

  /// The list of items shown in the master pane.
  final TomListForm<TItem, TForm> listForm;

  /// The single detail form re-bound to whichever item is currently
  /// selected. Identity stays stable — only the binding changes.
  final TForm detailForm;

  /// Builds the master pane. The provided callback re-binds the detail
  /// form, runs the unsaved-changes guard, and rebuilds the scaffold.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
    int? selectedIndex,
    Future<void> Function(int? index) selectIndex,
  ) masterBuilder;

  /// Builds the detail pane around [detailForm].
  final Widget Function(BuildContext context, TForm detailForm) detailBuilder;

  /// Optional builder shown when nothing is selected. Defaults to a
  /// centered hint.
  final WidgetBuilder? emptyDetailBuilder;

  final double masterPaneWidth;
  final double gap;

  /// When `true` (default), selection changes prompt Save/Discard/Cancel
  /// if the detail form is dirty. Set to `false` to switch silently.
  final bool guardUnsavedSelectionChange;

  @override
  State<TomMasterDetailScaffold<TItem, TForm>> createState() =>
      _TomMasterDetailScaffoldState<TItem, TForm>();
}

class _TomMasterDetailScaffoldState<TItem extends TomClass,
        TForm extends TomForm<TItem>>
    extends State<TomMasterDetailScaffold<TItem, TForm>>
    implements TomObserver {
  final TomNInt _selectedIndex = TomNInt(null);

  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
    _selectedIndex.addObserver(this);
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    _selectedIndex.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable observable) {
    if (mounted) setState(() {});
  }

  Future<void> _selectIndex(int? index) async {
    final current = ~_selectedIndex;
    if (current == index) return;

    Future<void> apply() async {
      _selectedIndex | index;
      if (index != null && index >= 0 && index < widget.listForm.length) {
        final rowBinding = widget.listForm[index].currentBinding;
        if (rowBinding != null) {
          widget.detailForm.bind(rowBinding);
        }
      } else {
        widget.detailForm.unbind();
      }
    }

    if (widget.guardUnsavedSelectionChange) {
      await guardUnsavedChanges(
        context: context,
        form: widget.detailForm,
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
      detail = widget.detailBuilder(context, widget.detailForm);
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

