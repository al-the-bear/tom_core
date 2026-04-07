import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'tom_action.dart';

/// Container for a group of related actions.
///
/// Each controller has a unique [controllerId] and maintains a registry of
/// its actions. The controller provides the first segment of action
/// canonical paths: `ac-<controllerId>.a-<actionId>`.
///
/// ```dart
/// class OrderController extends TomActionController {
///   OrderController() : super(controllerId: 'orderMgmt');
///
///   late final create = CreateOrderAction(this);
///   late final update = UpdateOrderAction(this);
///   late final delete = DeleteOrderAction(this);
/// }
/// ```
class TomActionController {
  /// Unique controller ID. Used as prefix in canonical paths.
  final String controllerId;

  /// Optional scope for resource resolution.
  final TomScope? scope;

  /// Optional authorization group for collective action control.
  final TomAuthorizationGroup? authorizationGroup;

  /// Registered actions in this controller.
  final List<TomAction> _actions = [];

  TomActionController({
    required this.controllerId,
    this.scope,
    this.authorizationGroup,
  });

  /// Registers an action with this controller.
  ///
  /// Called automatically by [TomAction] constructor.
  void registerAction(TomAction action) {
    _actions.add(action);
  }

  /// All registered actions.
  List<TomAction> get actions => List.unmodifiable(_actions);

  /// Finds an action by its [actionId].
  TomAction? findAction(String actionId) {
    for (final action in _actions) {
      if (action.actionId == actionId) return action;
    }
    return null;
  }

  /// The canonical path prefix for actions in this controller.
  String get canonicalPrefix => 'ac-$controllerId';

  /// Gets the authorization state for this controller as a whole.
  TomAuthState get authState => TomAuthorization.resolveAuth(canonicalPrefix);

  @override
  String toString() => 'TomActionController($controllerId)';
}
