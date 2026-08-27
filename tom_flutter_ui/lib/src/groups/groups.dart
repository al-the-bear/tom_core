/// Tom UI Groups — collective visibility control for related widgets.
///
/// Groups provide semantic control over entire UI regions without requiring
/// individual IDs on every leaf widget.
///
/// Groups are created manually and passed directly to widgets:
///
/// ```dart
/// final shippingGroup = TomAuthorizationGroup('shipping');
///
/// TomTextField(tomId: 'street', tomGroup: shippingGroup, ...),
/// TomTextField(tomId: 'city', tomGroup: shippingGroup, ...),
/// ```
///
/// Core classes:
/// - `TomAuthorizationGroup` — a single group with weak-reference member
///   tracking. It is defined in `tom_core_kernel` and reaches consumers through
///   `kernel_types.dart`, so importing `tom_flutter_ui` is enough to name it
///   and its `AuthGroupMode`.
/// - [TomWidgetMixin] — mixin for widgets that extend Flutter widgets
/// - [TomAuthGate] — wraps a slot belonging to a wrapper that cannot resolve
///   its own authorization, because the Flutter original is not a widget or
///   keeps its `State` private
library;

export 'tom_auth_gate.dart';
export 'tom_widget_mixin.dart';
