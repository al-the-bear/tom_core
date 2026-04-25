import 'package:flutter/material.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';

// ---------------------------------------------------------------------------
// TomReorderHandle — Phase 2a §16
// ---------------------------------------------------------------------------

/// A standard drag handle for reordering rows in a [ReorderableListView].
///
/// Wraps a [ReorderableDragStartListener] around a small icon (default:
/// [Icons.drag_indicator]) so demos and concrete row builders don't
/// repeat the same boilerplate every time they want a draggable row.
///
/// Place this anywhere inside the row body — typically on the leading or
/// trailing edge:
///
/// ```dart
/// rowBuilder: (ctx, i, form) => Row(children: [
///   TomReorderHandle(index: i),
///   const SizedBox(width: 8),
///   Expanded(child: form.label.widget),
/// ])
/// ```
///
/// The widget itself does NOT trigger reorders — that's the host
/// [ReorderableListView.onReorder] callback's responsibility. This widget
/// only wires the touch / mouse drag-start signal that lets the host
/// pick the row up.
///
/// **Resource resolution.** The handle participates in the standard
/// Tom resource pipeline. When [tomId] is set, the following keys are
/// consulted (each falls back to the constructor argument or the
/// hard-coded default if no resource exists):
///
/// | Key                     | Type        | Default                  |
/// |-------------------------|-------------|--------------------------|
/// | `<basePath>.icon`       | icon name   | `Icons.drag_indicator`   |
/// | `<basePath>.tooltip`    | string      | `'Drag to reorder'`      |
/// | `<basePath>.color`      | color       | ambient `IconTheme`      |
/// | `<basePath>.size`       | double      | `18`                     |
/// | `<basePath>.padding`    | EdgeInsets  | `H4 / V6`                |
///
/// **Authorization.** The handle goes through the standard
/// [TomPolicyNodeBase] gate — `none` hides the handle, `disabled` /
/// `read` greys it out and absorbs the drag gesture so the row stays
/// in place. Authorization is per-handle (i.e. per *kind* of handle in
/// a list, not per row) — pass the same [tomId] to every row's handle.
class TomReorderHandle extends TomImageBase {
  TomReorderHandle({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.index,
    IconData? icon,
    double? size,
    Color? color,
    String? tooltip,
    EdgeInsetsGeometry? padding,
  })  : _icon = icon,
        _size = size,
        _color = color,
        _tooltip = tooltip,
        _padding = padding {
    _resolvedIcon = _icon ?? TomCtr.icon(basePath, 'icon') ?? Icons.drag_indicator;
    _resolvedSize = _size ?? TomCtr.doubleVal(basePath, 'size') ?? 18.0;
    _resolvedColor = _color ?? TomCtr.color(basePath, 'color');
    _resolvedTooltip = _tooltip ??
        TomCtr.textOrNull(basePath, 'tooltip') ??
        'Drag to reorder';
    _resolvedPadding = _padding ??
        TomCtr.edgeInsets(basePath, 'padding') ??
        const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
  }

  /// The row's index inside the host [ReorderableListView]. The handle
  /// reports this index when the drag starts so the list can pick the
  /// correct row up.
  final int index;

  // Constructor inputs (kept for diagnostics; reads should go through
  // the `_resolved*` fields below).
  final IconData? _icon;
  final double? _size;
  final Color? _color;
  final String? _tooltip;
  final EdgeInsetsGeometry? _padding;

  late final IconData _resolvedIcon;
  late final double _resolvedSize;
  late final Color? _resolvedColor;
  late final String _resolvedTooltip;
  late final EdgeInsetsGeometry _resolvedPadding;

  @override
  Widget buildContent(BuildContext context) {
    final iconWidget = Padding(
      padding: _resolvedPadding,
      child: Icon(_resolvedIcon, size: _resolvedSize, color: _resolvedColor),
    );
    final wrapped = _resolvedTooltip.isEmpty
        ? iconWidget
        : Tooltip(message: _resolvedTooltip, child: iconWidget);
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: wrapped,
      ),
    );
  }
}
