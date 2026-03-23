import 'package:flutter/widgets.dart';

import '../../groups/tom_widget_mixin.dart';

/// Tom widget that EXTENDS [Expanded] with authorization.
///
/// This widget IS an [Expanded] (and IS a [Flexible]) — it passes `is Expanded`
/// and `is Flexible` checks for use in [Row], [Column], and [Flex].
///
/// **ParentDataWidget pattern:**
/// - ParentDataWidgets have no `build()` method — they apply parent data
/// - The mixin adds `tomId` for identification
/// - Visibility is controlled by the **parent container** filtering its children
///
/// ```dart
/// TomRow(
///   tomId: 'mainRow',
///   children: [
///     TomExpanded(tomId: 'content', child: ContentWidget()),
///     TomExpanded(tomId: 'sidebar', child: SidebarWidget()),
///   ],
/// )
/// ```
///
/// The parent [TomRow] filters out hidden children before layout.
class TomExpanded extends Expanded with TomWidgetMixin {
  /// Creates a Tom Expanded widget.
  const TomExpanded({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.flex,
    required super.child,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  // No build override needed — parent handles visibility filtering
}

/// Tom widget that EXTENDS [Flexible] with authorization.
///
/// This widget IS a [Flexible] — it passes `is Flexible` checks.
///
/// ```dart
/// TomRow(
///   tomId: 'flexRow',
///   children: [
///     TomFlexible(tomId: 'flex1', flex: 2, child: Widget1()),
///     TomFlexible(tomId: 'flex2', flex: 1, child: Widget2()),
///   ],
/// )
/// ```
class TomFlexible extends Flexible with TomWidgetMixin {
  /// Creates a Tom Flexible widget.
  const TomFlexible({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.flex,
    super.fit,
    required super.child,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  // No build override needed — parent handles visibility filtering
}

/// Tom widget that EXTENDS [Positioned] with authorization.
///
/// This widget IS a [Positioned] — it passes `is Positioned` checks for use
/// in [Stack].
///
/// ```dart
/// TomStack(
///   tomId: 'overlayStack',
///   children: [
///     TomPositioned(tomId: 'badge', top: 0, right: 0, child: Badge()),
///   ],
/// )
/// ```
class TomPositioned extends Positioned with TomWidgetMixin {
  /// Creates a Tom Positioned widget.
  const TomPositioned({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.left,
    super.top,
    super.right,
    super.bottom,
    super.width,
    super.height,
    required super.child,
  });

  /// Creates a Tom Positioned widget that fills the Stack.
  const TomPositioned.fill({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.left = 0.0,
    super.top = 0.0,
    super.right = 0.0,
    super.bottom = 0.0,
    required super.child,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  // No build override needed — parent handles visibility filtering
}

/// Tom widget that EXTENDS [Spacer] with authorization.
///
/// This widget IS a [Spacer] — it passes `is Spacer` checks.
/// Spacer creates empty space in a Flex layout.
///
/// Named `TomSpacerExtended` to avoid conflict with the composition-based
/// `TomSpacer` in tom_containers.dart.
///
/// ```dart
/// Row(children: [
///   Text('Left'),
///   TomSpacerExtended(tomId: 'spacer1'),
///   Text('Right'),
/// ])
/// ```
class TomSpacerExtended extends Spacer with TomWidgetMixin {
  /// Creates a Tom Spacer widget.
  const TomSpacerExtended({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.flex,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  @override
  Widget build(BuildContext context) {
    final hidden = checkHidden(context);
    if (hidden != null) return hidden;
    return super.build(context);
  }
}
