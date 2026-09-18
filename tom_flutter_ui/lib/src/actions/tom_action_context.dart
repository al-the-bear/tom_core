import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Base context available to all actions.
///
/// Actions declare their context requirements via the [TContext] generic
/// parameter. Concrete contexts extend this base with domain-specific data.
///
/// ```dart
/// class OrderActionContext extends TomActionContext {
///   final Order selectedOrder;
///   final OrderRepository orderRepo;
///
///   OrderActionContext({
///     required this.selectedOrder,
///     required this.orderRepo,
///     super.scope,
///   });
/// }
/// ```
class TomActionContext {
  /// The frame this invocation happens in, or null for the ambient one.
  ///
  /// Distinct from [TomAction.scope], which is fixed at construction and says
  /// where the action *lives* — it fixes `canonicalPath` and the group ceiling,
  /// and is deliberately independent of where the action is later consulted
  /// from. This one is per invocation and says where the action is being *run*:
  /// [runInScope] installs it around every consult of the action with this
  /// context, so anything reached from `canExecute` or `execute` that reads
  /// [TomScope.current] — a nested controller, a resource lookup, a widget
  /// built in response — sees this frame.
  ///
  /// Null is the ordinary case and means *the ambient frame*. A context is
  /// built per invocation by a `contextBuilder` called at the moment of the
  /// gesture, so the zone in force then is usually already the right one;
  /// capturing it here would be redundant. The field exists for the case where
  /// it is not — work dispatched from a callback, a timer or an isolate
  /// boundary, where the gesture's frame is no longer installed.
  final TomScope? scope;

  TomActionContext({this.scope});

  /// Runs [body] in [scope], or directly when this context carries none.
  ///
  /// The single place [scope] is read. Every consult of an action with a
  /// context goes through here — `canExecute` from [TomActionTrigger] and from
  /// [TomCompositeAction], `execute` from [TomActionTransaction.run] — so the
  /// gate and the body cannot end up seeing different frames.
  ///
  /// Re-entrant: installing a scope that is already current is a no-op, so
  /// nesting the calls costs nothing.
  T runInScope<T>(T Function() body) =>
      scope == null ? body() : scope!.runInScope(body);
}
