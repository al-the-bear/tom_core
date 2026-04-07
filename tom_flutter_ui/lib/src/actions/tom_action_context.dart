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
  /// The scope in which this action is executing.
  final TomScope? scope;

  TomActionContext({this.scope});
}
