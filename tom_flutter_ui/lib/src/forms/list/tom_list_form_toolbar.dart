import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../tom_form.dart';
import 'tom_list_form.dart';

// ---------------------------------------------------------------------------
// TomListFormToolbar — Phase 2a §16
// ---------------------------------------------------------------------------

/// Compact action bar with the standard list-form mutations:
/// **Add**, **Remove**, **Move up**, **Move down**.
///
/// Drop into any list-rendering widget (master pane, inline list footer,
/// expandable header) so each demo / app doesn't reinvent the same row of
/// buttons. Each action is enabled only when it is meaningful for the
/// current selection (e.g. *Move up* disabled at index 0; *Remove*
/// disabled when nothing is selected).
///
/// Example:
///
/// ```dart
/// TomListFormToolbar(
///   listForm: form.shippingAddresses,
///   selectedIndex: selected,
///   onSelectionChanged: selectIndex,
/// )
/// ```
///
/// Selection wiring:
///   * After **Add**, selection moves to the newly appended row.
///   * After **Remove**, selection clears.
///   * After **Move up / down**, selection follows the moved row.
///
/// Supplying [onSelectionChanged] is optional — if omitted, selection
/// changes are still applied to the list but not reported back. That mode
/// is useful when the host already observes [TomListForm] and derives
/// selection some other way.
///
/// Pass `showXxx: false` to hide individual buttons, or override
/// [actions] to inject custom buttons before / after / replacing the
/// standard set.
class TomListFormToolbar<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends StatelessWidget {
  const TomListFormToolbar({
    super.key,
    required this.listForm,
    this.selectedIndex,
    this.onSelectionChanged,
    this.showAdd = true,
    this.showRemove = true,
    this.showMoveUp = true,
    this.showMoveDown = true,
    this.spacing = 6,
    this.runSpacing = 4,
    this.dense = true,
    this.alignment = WrapAlignment.start,
    this.addLabel = 'Add',
    this.removeLabel = 'Remove',
    this.moveUpTooltip = 'Move up',
    this.moveDownTooltip = 'Move down',
    this.addIcon = Icons.add,
    this.removeIcon = Icons.delete_outline,
    this.moveUpIcon = Icons.arrow_upward,
    this.moveDownIcon = Icons.arrow_downward,
    this.iconSize = 16,
    this.beforeActions,
    this.afterActions,
    this.beforeAdd,
    this.beforeRemove,
    this.beforeMove,
  });

  /// The list whose membership / order is mutated by the buttons.
  final TomListForm<TItem, TForm> listForm;

  /// Currently selected row index. Drives Remove / Move-up / Move-down
  /// enable state. Pass `null` when no row is selected.
  final int? selectedIndex;

  /// Optional callback invoked whenever this toolbar changes selection
  /// (after Add, Remove, or Move). Not called when the host wires
  /// selection elsewhere.
  final Future<void> Function(int? index)? onSelectionChanged;

  final bool showAdd;
  final bool showRemove;
  final bool showMoveUp;
  final bool showMoveDown;

  /// Spacing between buttons (horizontal). Forwarded to [Wrap.spacing].
  final double spacing;

  /// Spacing between wrapped rows (vertical). Forwarded to
  /// [Wrap.runSpacing].
  final double runSpacing;

  /// When `true` (default), uses small icons + tonal buttons. When
  /// `false`, the buttons are larger and use the surface's default
  /// styling.
  final bool dense;

  /// Horizontal alignment of the [Wrap]'s rows.
  final WrapAlignment alignment;

  final String addLabel;
  final String removeLabel;
  final String moveUpTooltip;
  final String moveDownTooltip;
  final IconData addIcon;
  final IconData removeIcon;
  final IconData moveUpIcon;
  final IconData moveDownIcon;
  final double iconSize;

  /// Optional extra buttons inserted before the standard action set.
  final List<Widget>? beforeActions;

  /// Optional extra buttons appended after the standard action set.
  final List<Widget>? afterActions;

  /// Optional veto fired before an Add. Return `false` to cancel the
  /// add (e.g. the currently-open expandable row has unresolved
  /// validation errors and must be fixed before a new row is appended).
  final Future<bool> Function()? beforeAdd;

  /// Optional veto fired before a Remove. Receives the index that
  /// would be removed. Return `false` to cancel.
  final Future<bool> Function(int index)? beforeRemove;

  /// Optional veto fired before a Move. Receives the source and
  /// destination indices (in [TomListForm] semantics — `to` is the
  /// post-move position). Return `false` to cancel.
  final Future<bool> Function(int from, int to)? beforeMove;

  Future<void> _add() async {
    if (beforeAdd != null && !await beforeAdd!()) return;
    listForm.add();
    await onSelectionChanged?.call(listForm.length - 1);
  }

  Future<void> _remove() async {
    final i = selectedIndex;
    if (i == null) return;
    if (beforeRemove != null && !await beforeRemove!(i)) return;
    listForm.removeAt(i);
    await onSelectionChanged?.call(null);
  }

  Future<void> _moveUp() async {
    final i = selectedIndex;
    if (i == null || i <= 0) return;
    if (beforeMove != null && !await beforeMove!(i, i - 1)) return;
    listForm.move(i, i - 1);
    await onSelectionChanged?.call(i - 1);
  }

  Future<void> _moveDown() async {
    final i = selectedIndex;
    if (i == null || i >= listForm.length - 1) return;
    if (beforeMove != null && !await beforeMove!(i, i + 1)) return;
    listForm.move(i, i + 1);
    await onSelectionChanged?.call(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedIndex != null;
    final canMoveUp = hasSelection && selectedIndex! > 0;
    final canMoveDown =
        hasSelection && selectedIndex! < listForm.length - 1;

    final children = <Widget>[
      ...?beforeActions,
      if (showAdd)
        dense
            ? FilledButton.tonalIcon(
                icon: Icon(addIcon, size: iconSize),
                label: Text(addLabel),
                onPressed: _add,
              )
            : FilledButton.icon(
                icon: Icon(addIcon),
                label: Text(addLabel),
                onPressed: _add,
              ),
      if (showRemove)
        dense
            ? FilledButton.tonalIcon(
                icon: Icon(removeIcon, size: iconSize),
                label: Text(removeLabel),
                onPressed: hasSelection ? _remove : null,
              )
            : FilledButton.icon(
                icon: Icon(removeIcon),
                label: Text(removeLabel),
                onPressed: hasSelection ? _remove : null,
              ),
      if (showMoveUp)
        IconButton(
          tooltip: moveUpTooltip,
          icon: Icon(moveUpIcon, size: iconSize + 2),
          onPressed: canMoveUp ? _moveUp : null,
          visualDensity:
              dense ? VisualDensity.compact : VisualDensity.standard,
        ),
      if (showMoveDown)
        IconButton(
          tooltip: moveDownTooltip,
          icon: Icon(moveDownIcon, size: iconSize + 2),
          onPressed: canMoveDown ? _moveDown : null,
          visualDensity:
              dense ? VisualDensity.compact : VisualDensity.standard,
        ),
      ...?afterActions,
    ];

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: alignment,
      children: children,
    );
  }
}
