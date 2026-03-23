import 'package:flutter/material.dart';

import '../../groups/tom_widget_mixin.dart';

/// Tom widget that EXTENDS [PopupMenuItem] with authorization and resources.
///
/// This widget IS a [PopupMenuItem] — it passes `is PopupMenuItem` checks
/// and `is PopupMenuEntry` checks for use in [showMenu] and [PopupMenuButton].
///
/// **StatefulWidget pattern:**
/// - Widget has the mixin and `tomId`
/// - State overrides `build()` and accesses mixin methods through `widget`
/// - Registration happens in `initState()`, unregistration in `dispose()`
///
/// ```dart
/// PopupMenuButton<String>(
///   itemBuilder: (context) => [
///     TomPopupMenuItem<String>(tomId: 'edit', value: 'edit', child: Text('Edit')),
///     TomPopupMenuItem<String>(tomId: 'delete', value: 'delete', child: Text('Delete')),
///   ],
/// )
/// ```
class TomPopupMenuItem<T> extends PopupMenuItem<T> with TomWidgetMixin {
  /// Creates a Tom PopupMenuItem.
  const TomPopupMenuItem({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.value,
    super.onTap,
    super.enabled,
    super.height,
    super.padding,
    super.textStyle,
    super.labelTextStyle,
    super.mouseCursor,
    required super.child,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  @override
  PopupMenuItemState<T, TomPopupMenuItem<T>> createState() =>
      _TomPopupMenuItemState<T>();
}

class _TomPopupMenuItemState<T>
    extends PopupMenuItemState<T, TomPopupMenuItem<T>> {
  @override
  void initState() {
    super.initState();
    widget.registerWithGroup();
  }

  @override
  void dispose() {
    widget.unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access mixin methods via widget reference
    final hidden = widget.checkHidden(context);
    if (hidden != null) return hidden;

    return widget.applyReadonly(context, super.build(context));
  }
}

/// Tom widget that EXTENDS [PopupMenuDivider] with authorization.
///
/// This widget IS a [PopupMenuDivider] — it passes `is PopupMenuEntry` checks.
///
/// Typically hidden via group authorization rather than individual ID.
class TomPopupMenuDivider extends PopupMenuDivider with TomWidgetMixin {
  /// Creates a Tom PopupMenuDivider.
  const TomPopupMenuDivider({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.height,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  @override
  State<PopupMenuDivider> createState() => _TomPopupMenuDividerState();
}

class _TomPopupMenuDividerState extends State<TomPopupMenuDivider> {
  @override
  void initState() {
    super.initState();
    (widget as TomWidgetMixin).registerWithGroup();
  }

  @override
  void dispose() {
    (widget as TomWidgetMixin).unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widgetMixin = widget as TomWidgetMixin;
    final hidden = widgetMixin.checkHidden(context);
    if (hidden != null) return hidden;

    // Divider doesn't need build override — just use the default
    return const Divider(height: 1.0, thickness: 0.0);
  }
}

/// Tom widget that EXTENDS [CheckedPopupMenuItem] with authorization and resources.
///
/// ```dart
/// PopupMenuButton<String>(
///   itemBuilder: (context) => [
///     TomCheckedPopupMenuItem<String>(tomId: 'option1', value: 'opt1', child: Text('Option 1')),
///   ],
/// )
/// ```
class TomCheckedPopupMenuItem<T> extends CheckedPopupMenuItem<T>
    with TomWidgetMixin {
  /// Creates a Tom CheckedPopupMenuItem.
  const TomCheckedPopupMenuItem({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.value,
    super.checked,
    super.enabled,
    super.padding,
    super.height,
    super.labelTextStyle,
    super.mouseCursor,
    super.child,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  @override
  PopupMenuItemState<T, CheckedPopupMenuItem<T>> createState() =>
      _TomCheckedPopupMenuItemState<T>();
}

class _TomCheckedPopupMenuItemState<T>
    extends PopupMenuItemState<T, CheckedPopupMenuItem<T>> {
  @override
  void initState() {
    super.initState();
    (widget as TomWidgetMixin).registerWithGroup();
  }

  @override
  void dispose() {
    (widget as TomWidgetMixin).unregisterFromGroup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widgetMixin = widget as TomWidgetMixin;
    final hidden = widgetMixin.checkHidden(context);
    if (hidden != null) return hidden;

    return widgetMixin.applyReadonly(context, super.build(context));
  }
}
