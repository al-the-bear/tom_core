import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../tom_form.dart';
import 'tom_list_form.dart';

// ---------------------------------------------------------------------------
// TomListRowMoveButtons — Phase 2a §16
// ---------------------------------------------------------------------------

/// A pair of *Move up* / *Move down* buttons bound to row [index] of a
/// [TomListForm].
///
/// This is the row-level counterpart to the toolbar move buttons in
/// [TomListFormToolbar] — drop it inside a row builder when the host
/// has no master selection (or no master pane at all) and so the
/// toolbar's selection-driven move buttons aren't a fit.
///
/// Each button is enabled only when the row can actually move:
///   * Move up disabled when [index] is 0.
///   * Move down disabled when [index] is the last row.
///
/// Example (inside an inline list row builder):
///
/// ```dart
/// rowBuilder: (ctx, i, form) => Row(children: [
///   TomListRowMoveButtons(listForm: form.items, index: i),
///   const SizedBox(width: 8),
///   Expanded(child: form.label.widget),
/// ])
/// ```
///
/// The widget calls [TomListForm.move] directly — the same code path the
/// toolbar uses — so reorder events fire through the standard
/// child-container chain and the parent form's `isDirty` follows along.
///
/// **Resource resolution.** When [tomId] is set, the following keys are
/// consulted (each falls back to the constructor argument or a hard-
/// coded default if no resource exists):
///
/// | Key                          | Type      | Default                  |
/// |------------------------------|-----------|--------------------------|
/// | `<basePath>.moveUp.icon`     | icon      | `Icons.arrow_upward`     |
/// | `<basePath>.moveUp.tooltip`  | string    | `'Move up'`              |
/// | `<basePath>.moveDown.icon`   | icon      | `Icons.arrow_downward`   |
/// | `<basePath>.moveDown.tooltip`| string    | `'Move down'`            |
/// | `<basePath>.size`            | double    | `18`                     |
/// | `<basePath>.spacing`         | double    | `0`                      |
///
/// **Authorization.** The widget passes through the standard
/// [TomPolicyNodeBase] gate at `<basePath>` — `none` hides the entire
/// pair, `disabled` greys both out and absorbs taps, `read` applies the
/// readonly visual treatment. Per-button auth is resolved at
/// `<basePath>.moveUp` and `<basePath>.moveDown` using the same rules
/// as [TomListFormToolbar].
class TomListRowMoveButtons<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends TomContainerBase {
  TomListRowMoveButtons({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.listForm,
    required this.index,
    this.onReorder,
    this.beforeMove,
    this.dense = true,
    this.axis = Axis.horizontal,
    IconData? moveUpIcon,
    IconData? moveDownIcon,
    String? moveUpTooltip,
    String? moveDownTooltip,
    double? iconSize,
    double? spacing,
  }) {
    final moveUpBase = _childKey(basePath, 'moveUp');
    final moveDownBase = _childKey(basePath, 'moveDown');

    _resolvedMoveUpIcon = moveUpIcon ??
        TomCtr.icon(moveUpBase, 'icon') ??
        Icons.arrow_upward;
    _resolvedMoveDownIcon = moveDownIcon ??
        TomCtr.icon(moveDownBase, 'icon') ??
        Icons.arrow_downward;
    _resolvedMoveUpTooltip = moveUpTooltip ??
        TomCtr.textOrNull(moveUpBase, 'tooltip') ??
        'Move up';
    _resolvedMoveDownTooltip = moveDownTooltip ??
        TomCtr.textOrNull(moveDownBase, 'tooltip') ??
        'Move down';
    _resolvedIconSize =
        iconSize ?? TomCtr.doubleVal(basePath, 'size') ?? 18.0;
    _resolvedSpacing =
        spacing ?? TomCtr.doubleVal(basePath, 'spacing') ?? 0.0;

    _moveUpAuthState = _resolveButtonAuth(moveUpBase);
    _moveDownAuthState = _resolveButtonAuth(moveDownBase);
  }

  /// The list whose rows are reordered.
  final TomListForm<TItem, TForm> listForm;

  /// The row this button pair belongs to. The button pair operates on
  /// `index` — clicking *Move up* runs `listForm.move(index, index - 1)`,
  /// *Move down* runs `listForm.move(index, index + 1)`.
  final int index;

  /// Optional reorder hook invoked after the underlying [TomListForm.move]
  /// runs. Receives the original index and the new (post-move) index.
  final void Function(int from, int to)? onReorder;

  /// Optional veto fired before a move. Receives `(from, to)`. Return
  /// `false` to cancel.
  final Future<bool> Function(int from, int to)? beforeMove;

  /// When `true` (default), uses small icon buttons with compact visual
  /// density. When `false`, the buttons are full-size.
  final bool dense;

  /// Layout axis for the two buttons. Defaults to [Axis.horizontal] (one
  /// row). [Axis.vertical] stacks the up arrow above the down arrow,
  /// which is the typical layout for narrow trailing chrome.
  final Axis axis;

  late final IconData _resolvedMoveUpIcon;
  late final IconData _resolvedMoveDownIcon;
  late final String _resolvedMoveUpTooltip;
  late final String _resolvedMoveDownTooltip;
  late final double _resolvedIconSize;
  late final double _resolvedSpacing;

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

  Future<void> _move(int from, int to) async {
    if (beforeMove != null && !await beforeMove!(from, to)) return;
    listForm.move(from, to);
    onReorder?.call(from, to);
  }

  bool _visible(TomAuthState state) => state != TomAuthState.none;

  VoidCallback? _gatedCallback(
    TomAuthState state,
    bool meaningful,
    Future<void> Function() action,
  ) {
    if (!meaningful) return null;
    if (state != TomAuthState.full) return null;
    return action;
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: _resolvedIconSize),
      onPressed: onPressed,
      visualDensity:
          dense ? VisualDensity.compact : VisualDensity.standard,
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final canMoveUp = index > 0;
    final canMoveDown = index < listForm.length - 1;

    final children = <Widget>[
      if (_visible(_moveUpAuthState))
        _iconButton(
          icon: _resolvedMoveUpIcon,
          tooltip: _resolvedMoveUpTooltip,
          onPressed: _gatedCallback(
            _moveUpAuthState,
            canMoveUp,
            () => _move(index, index - 1),
          ),
        ),
      if (_resolvedSpacing > 0 && _visible(_moveUpAuthState) &&
          _visible(_moveDownAuthState))
        SizedBox(
          width: axis == Axis.horizontal ? _resolvedSpacing : 0,
          height: axis == Axis.vertical ? _resolvedSpacing : 0,
        ),
      if (_visible(_moveDownAuthState))
        _iconButton(
          icon: _resolvedMoveDownIcon,
          tooltip: _resolvedMoveDownTooltip,
          onPressed: _gatedCallback(
            _moveDownAuthState,
            canMoveDown,
            () => _move(index, index + 1),
          ),
        ),
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    return axis == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}
