/// Tom UI Groups — collective visibility control for related widgets.
///
/// Groups provide semantic control over entire UI regions without requiring
/// individual IDs on every leaf widget.
///
/// Groups are created manually and passed directly to widgets:
///
/// ```dart
/// final shippingGroup = TomUIGroup('shipping');
///
/// TomTextField(tomId: 'street', tomGroup: shippingGroup, ...),
/// TomTextField(tomId: 'city', tomGroup: shippingGroup, ...),
/// ```
///
/// Core classes:
/// - [TomUIGroup] — a single group with weak-reference member tracking
/// - [TomWidgetMixin] — mixin for widgets that extend Flutter widgets
library;

export 'tom_ui_group.dart';
export 'tom_widget_mixin.dart';
