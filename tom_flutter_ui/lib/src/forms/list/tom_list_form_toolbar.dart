import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../tom_form.dart';
import 'tom_list_form.dart';

// ---------------------------------------------------------------------------
// TomListFormToolbar
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
/// **Layout.** Buttons are rendered inside a single [Wrap]. The reorder
/// pair (Move up / Move down) is bundled into an inner [Row] so the
/// `Wrap` treats it as one atomic child — the two arrows always stay
/// next to each other, and they only flow onto a new line *as a pair*
/// when the host doesn't have enough horizontal space for them to fit
/// alongside the wide tonal-filled Add/Remove buttons. This avoids the
/// lopsided break (one arrow next to Add/Remove, the other arrow alone
/// on the second line) reported against narrow master panes, while
/// still letting the toolbar lay out inline when there's room.
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
/// [beforeActions] / [afterActions] to inject custom buttons before /
/// after the standard set.
///
/// **Resource resolution.** The toolbar follows the standard Tom
/// resource pattern. Each button's label / tooltip / icon falls back to
/// resources when the matching constructor argument is null:
///
/// | Argument          | Resource key              | Default              |
/// |-------------------|---------------------------|----------------------|
/// | `addLabel`        | `<basePath>.add.label`    | `'Add'`              |
/// | `addIcon`         | `<basePath>.add.icon`     | `Icons.add`          |
/// | `addTooltip`      | `<basePath>.add.tooltip`  | (none)               |
/// | `removeLabel`     | `<basePath>.remove.label` | `'Remove'`           |
/// | `removeIcon`      | `<basePath>.remove.icon`  | `Icons.delete_outline` |
/// | `removeTooltip`   | `<basePath>.remove.tooltip` | (none)             |
/// | `moveUpLabel`     | `<basePath>.moveUp.label` | (icon-only)          |
/// | `moveUpIcon`      | `<basePath>.moveUp.icon`  | `Icons.arrow_upward` |
/// | `moveUpTooltip`   | `<basePath>.moveUp.tooltip` | `'Move up'`        |
/// | `moveDownLabel`   | `<basePath>.moveDown.label` | (icon-only)        |
/// | `moveDownIcon`    | `<basePath>.moveDown.icon` | `Icons.arrow_downward` |
/// | `moveDownTooltip` | `<basePath>.moveDown.tooltip` | `'Move down'`    |
///
/// **Authorization.** The whole toolbar respects the standard
/// [TomPolicyNodeBase] gate at `<basePath>` (none → toolbar disappears,
/// disabled → all buttons greyed out, read → readonly treatment, full →
/// normal). In addition, each button consults its own sub-resource path
/// (`<basePath>.add`, `<basePath>.remove`, `<basePath>.moveUp`,
/// `<basePath>.moveDown`) — when its sub-state is `none` the button is
/// hidden regardless of `showXxx`; when `disabled` or `read` it is
/// rendered without an `onPressed` callback so the user cannot fire it.
///
/// Per-row authorization is not supported by design — the same toolbar
/// auth applies to every row of the list. Authorize individual fields
/// of the row sub-form via the field widgets themselves.
class TomListFormToolbar<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends TomContainerBase {
  TomListFormToolbar({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
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
    String? addLabel,
    String? removeLabel,
    String? moveUpLabel,
    String? moveDownLabel,
    String? addTooltip,
    String? removeTooltip,
    String? moveUpTooltip,
    String? moveDownTooltip,
    IconData? addIcon,
    IconData? removeIcon,
    IconData? moveUpIcon,
    IconData? moveDownIcon,
    this.iconSize = 16,
    this.beforeActions,
    this.afterActions,
    this.beforeAdd,
    this.beforeRemove,
    this.beforeMove,
  }) {
    final addBase = _childKey(basePath, 'add');
    final removeBase = _childKey(basePath, 'remove');
    final moveUpBase = _childKey(basePath, 'moveUp');
    final moveDownBase = _childKey(basePath, 'moveDown');

    _resolvedAddLabel = addLabel ?? TomCtr.textOrNull(addBase, 'label') ?? 'Add';
    _resolvedRemoveLabel =
        removeLabel ?? TomCtr.textOrNull(removeBase, 'label') ?? 'Remove';
    _resolvedMoveUpLabel = moveUpLabel ?? TomCtr.textOrNull(moveUpBase, 'label');
    _resolvedMoveDownLabel =
        moveDownLabel ?? TomCtr.textOrNull(moveDownBase, 'label');

    _resolvedAddTooltip = addTooltip ?? TomCtr.textOrNull(addBase, 'tooltip');
    _resolvedRemoveTooltip =
        removeTooltip ?? TomCtr.textOrNull(removeBase, 'tooltip');
    _resolvedMoveUpTooltip = moveUpTooltip ??
        TomCtr.textOrNull(moveUpBase, 'tooltip') ??
        'Move up';
    _resolvedMoveDownTooltip = moveDownTooltip ??
        TomCtr.textOrNull(moveDownBase, 'tooltip') ??
        'Move down';

    _resolvedAddIcon = addIcon ?? TomCtr.icon(addBase, 'icon') ?? Icons.add;
    _resolvedRemoveIcon = removeIcon ??
        TomCtr.icon(removeBase, 'icon') ??
        Icons.delete_outline;
    _resolvedMoveUpIcon = moveUpIcon ??
        TomCtr.icon(moveUpBase, 'icon') ??
        Icons.arrow_upward;
    _resolvedMoveDownIcon = moveDownIcon ??
        TomCtr.icon(moveDownBase, 'icon') ??
        Icons.arrow_downward;

    _addAuthState = _resolveButtonAuth(addBase);
    _removeAuthState = _resolveButtonAuth(removeBase);
    _moveUpAuthState = _resolveButtonAuth(moveUpBase);
    _moveDownAuthState = _resolveButtonAuth(moveDownBase);
  }

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

  // Pre-resolved resource values
  late final String _resolvedAddLabel;
  late final String _resolvedRemoveLabel;
  late final String? _resolvedMoveUpLabel;
  late final String? _resolvedMoveDownLabel;
  late final String? _resolvedAddTooltip;
  late final String? _resolvedRemoveTooltip;
  late final String _resolvedMoveUpTooltip;
  late final String _resolvedMoveDownTooltip;
  late final IconData _resolvedAddIcon;
  late final IconData _resolvedRemoveIcon;
  late final IconData _resolvedMoveUpIcon;
  late final IconData _resolvedMoveDownIcon;

  // Per-button authorization snapshot (resolved at construction time so
  // the build pass is purely declarative).
  late final TomAuthState _addAuthState;
  late final TomAuthState _removeAuthState;
  late final TomAuthState _moveUpAuthState;
  late final TomAuthState _moveDownAuthState;

  static String? _childKey(String? base, String suffix) {
    if (base == null) return null;
    return '$base.$suffix';
  }

  static TomAuthState _resolveButtonAuth(String? path) {
    if (path == null) return TomAuthState.full;
    return TomAuthorization.resolveAuth(path);
  }

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

  /// Whether [state] permits the host's `showXxx` flag to actually
  /// produce a button. `none` is a hard hide (auth wins over `show`);
  /// any other state falls through to the host's flag.
  bool _visible(TomAuthState state, bool show) =>
      show && state != TomAuthState.none;

  /// Whether [state] permits a button to be interactive given the
  /// host's "is this action meaningful right now" flag. Read-only or
  /// disabled auth states force a null `onPressed`.
  VoidCallback? _gatedCallback(
    TomAuthState state,
    bool meaningful,
    Future<void> Function() action,
  ) {
    if (!meaningful) return null;
    if (state != TomAuthState.full) return null;
    return action;
  }

  Widget _filledButton(IconData icon, String label, VoidCallback? onPressed,
      {String? tooltip}) {
    final button = dense
        ? FilledButton.tonalIcon(
            icon: Icon(icon, size: iconSize),
            label: Text(label),
            onPressed: onPressed,
          )
        : FilledButton.icon(
            icon: Icon(icon),
            label: Text(label),
            onPressed: onPressed,
          );
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _moveButton({
    required IconData icon,
    required String tooltip,
    required String? label,
    required VoidCallback? onPressed,
  }) {
    if (label != null && label.isNotEmpty) {
      return _filledButton(icon, label, onPressed, tooltip: tooltip);
    }
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize + 2),
      onPressed: onPressed,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final hasSelection = selectedIndex != null;
    final canMoveUp = hasSelection && selectedIndex! > 0;
    final canMoveDown =
        hasSelection && selectedIndex! < listForm.length - 1;

    // Build the individual reorder buttons first; we'll bundle them into
    // an inner Row so the outer Wrap sees them as a single atomic child
    // and they always stay next to each other (only wrapping together
    // when there's not enough room).
    final moveButtons = <Widget>[
      if (_visible(_moveUpAuthState, showMoveUp))
        _moveButton(
          icon: _resolvedMoveUpIcon,
          tooltip: _resolvedMoveUpTooltip,
          label: _resolvedMoveUpLabel,
          onPressed: _gatedCallback(_moveUpAuthState, canMoveUp, _moveUp),
        ),
      if (_visible(_moveDownAuthState, showMoveDown))
        _moveButton(
          icon: _resolvedMoveDownIcon,
          tooltip: _resolvedMoveDownTooltip,
          label: _resolvedMoveDownLabel,
          onPressed: _gatedCallback(_moveDownAuthState, canMoveDown, _moveDown),
        ),
    ];

    final children = <Widget>[
      ...?beforeActions,
      if (_visible(_addAuthState, showAdd))
        _filledButton(
          _resolvedAddIcon,
          _resolvedAddLabel,
          _gatedCallback(_addAuthState, true, _add),
          tooltip: _resolvedAddTooltip,
        ),
      if (_visible(_removeAuthState, showRemove))
        _filledButton(
          _resolvedRemoveIcon,
          _resolvedRemoveLabel,
          _gatedCallback(_removeAuthState, hasSelection, _remove),
          tooltip: _resolvedRemoveTooltip,
        ),
      if (moveButtons.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: moveButtons.length == 1
              ? moveButtons
              : [
                  moveButtons[0],
                  SizedBox(width: spacing),
                  moveButtons[1],
                ],
        ),
      ...?afterActions,
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: alignment,
      children: children,
    );
  }
}
