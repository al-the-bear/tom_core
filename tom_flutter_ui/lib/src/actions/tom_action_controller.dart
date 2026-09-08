import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_scope_path.dart';
import 'tom_action.dart';

/// Container for a group of related actions.
///
/// Each controller has a unique [controllerId] and maintains a registry of
/// its actions. The controller provides the first segment of action
/// canonical paths: `<scopePath>.<controllerId>.<actionId>`.
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

  /// Optional explicit scope for resource and authorization lookups.
  ///
  /// When provided, this scope is used instead of whatever [TomScope.current]
  /// carried at construction — see [constructionScope].
  final TomScope? scope;

  /// Optional authorization group for collective action control.
  ///
  /// Named `tomGroup` like every other authorization-group parameter in this
  /// package, including the ones on `TomNodeBase` widgets, so the concept has
  /// one spelling wherever it is reached for.
  final TomAuthorizationGroup? tomGroup;

  /// The frame this controller and, by default, its actions resolve in: the
  /// explicit [scope] when it was given one, otherwise whatever the zone
  /// carried when the controller was constructed.
  ///
  /// Captured once rather than read per lookup, so a controller answers the
  /// same question the same way wherever the answer is asked for. The same
  /// rule, and the same reason, as `TomNodeBase.constructionScope`.
  final TomScope constructionScope;

  /// Registered actions in this controller.
  final List<TomAction> _actions = [];

  TomActionController({required this.controllerId, this.scope, this.tomGroup})
    : constructionScope = scope ?? TomScope.current;

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

  /// The canonical path prefix for actions in this controller:
  /// `<scopePath>.<controllerId>`, or the bare id at the root.
  ///
  /// Resolved in [constructionScope], which is the same frame the actions
  /// build their own paths and their group ceilings from — a prefix that
  /// differed between them would address a rule belonging to someone else.
  late final String canonicalPrefix = TomScopePath.qualify(
    controllerId,
    constructionScope,
  );

  /// Gets the authorization state for this controller as a whole.
  TomAuthState get authState => TomAuthorization.resolveAuth(canonicalPrefix);

  @override
  String toString() => 'TomActionController($controllerId)';
}
