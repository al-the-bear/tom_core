import 'package:flutter/material.dart';

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
class TomReorderHandle extends StatelessWidget {
  const TomReorderHandle({
    super.key,
    required this.index,
    this.icon = Icons.drag_indicator,
    this.size = 18,
    this.color,
    this.tooltip = 'Drag to reorder',
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  });

  /// The row's index inside the host [ReorderableListView]. The handle
  /// reports this index when the drag starts so the list can pick the
  /// correct row up.
  final int index;

  /// Icon shown as the handle. Defaults to [Icons.drag_indicator].
  final IconData icon;

  /// Icon size in logical pixels.
  final double size;

  /// Optional tint. Falls back to the ambient icon theme.
  final Color? color;

  /// Tooltip text. Pass an empty string to disable.
  final String tooltip;

  /// Padding around the icon. Determines the touch target size.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Padding(
      padding: padding,
      child: Icon(icon, size: size, color: color),
    );
    final wrapped = tooltip.isEmpty
        ? iconWidget
        : Tooltip(message: tooltip, child: iconWidget);
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: wrapped,
      ),
    );
  }
}
