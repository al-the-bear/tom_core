/// Base context available to all actions.
///
/// Actions declare their context requirements via the [TContext] generic
/// parameter. Concrete contexts extend this base with domain-specific data.
///
/// A context carries the data one invocation needs and nothing else. It holds
/// no scope: the frame an action resolves its path, group and resources in is
/// [TomAction.scope], fixed at construction, and an action consulted with a
/// context runs in whatever frame is current at that moment.
///
/// ```dart
/// class OrderActionContext extends TomActionContext {
///   final Order selectedOrder;
///   final OrderRepository orderRepo;
///
///   const OrderActionContext({
///     required this.selectedOrder,
///     required this.orderRepo,
///   });
/// }
/// ```
class TomActionContext {
  const TomActionContext();
}
