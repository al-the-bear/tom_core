import 'package:flutter/material.dart';

import '../../groups/tom_widget_mixin.dart';

/// Tom widget that EXTENDS [Tab] with authorization and resources.
///
/// This widget IS a [Tab] — it passes `is Tab` checks and fits in `List<Tab>`.
///
/// **StatelessWidget pattern:**
/// - Override `build()`, check visibility, apply readonly, delegate to super
///
/// ```dart
/// TabBar(
///   tabs: [
///     TomTab(tomId: 'home', text: 'Home'),
///     TomTab(tomId: 'settings', text: 'Settings'),
///   ],
/// )
/// ```
class TomTab extends Tab with TomWidgetMixin {
  /// Creates a Tom Tab.
  ///
  /// Requires [tomId] for authorization and resource resolution.
  /// At least one of [text], [icon], or [child] must be non-null.
  const TomTab({
    required this.tomId,
    this.tomGroup,
    super.key,
    super.text,
    super.icon,
    super.iconMargin,
    super.height,
    super.child,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  @override
  Widget build(BuildContext context) {
    // Check authorization — return immediately if hidden
    final hidden = checkHidden(context);
    if (hidden != null) return hidden;

    // Apply readonly styling, delegate to original build
    return applyReadonly(context, super.build(context));
  }
}

/// Tom widget that EXTENDS [NavigationDestination] with authorization and resources.
///
/// This widget IS a [NavigationDestination] — it passes `is NavigationDestination`
/// checks and fits in `List<Widget>` for NavigationBar.
///
/// ```dart
/// NavigationBar(
///   destinations: [
///     TomNavigationDestination(tomId: 'home', icon: Icon(Icons.home), label: 'Home'),
///     TomNavigationDestination(tomId: 'settings', icon: Icon(Icons.settings), label: 'Settings'),
///   ],
/// )
/// ```
class TomNavigationDestination extends NavigationDestination
    with TomWidgetMixin {
  /// Creates a Tom NavigationDestination.
  const TomNavigationDestination({
    required this.tomId,
    this.tomGroup,
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
    super.tooltip,
    super.enabled,
  });

  @override
  final String tomId;

  @override
  final String? tomGroup;

  @override
  Widget build(BuildContext context) {
    final hidden = checkHidden(context);
    if (hidden != null) return hidden;
    return applyReadonly(context, super.build(context));
  }
}
