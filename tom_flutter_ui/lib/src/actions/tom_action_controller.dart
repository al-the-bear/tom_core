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

  /// The authorization group every action this controller owns joins by
  /// default.
  ///
  /// This is the collective half of the group machinery: declare the group once
  /// here and each action built against this controller registers with it and
  /// takes its ceiling, without the per-action wiring. An action that names its
  /// own `tomGroup` overrides it — see [TomAction.tomGroup], which is where the
  /// fallback is resolved.
  ///
  /// Read when an action is *constructed*, so a controller that assigns its
  /// group rather than taking it in the constructor must do so before its
  /// actions are built.
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
  /// Called automatically by the [TomAction] constructor. Throws [StateError]
  /// on a duplicate [TomAction.actionId] — see [addUniquely].
  void registerAction(TomAction action) {
    addUniquely(_actions, action);
  }

  /// Appends [action] to [registered], refusing an id already present.
  ///
  /// The single definition of the rule. Called from [registerAction] here and
  /// from `TomForm`'s, which *implements* this interface rather than extending
  /// it and so keeps its own list; one definition is what stops the two from
  /// disagreeing about whether a duplicate is allowed.
  ///
  /// A duplicate id is never intentional, and it does more than shadow a
  /// lookup. [TomAction.canonicalPath] is `<controllerId>.<actionId>`, so two
  /// actions sharing an id resolve **one** authorization decision and **one**
  /// set of label, tooltip and icon keys — two different behaviours wearing one
  /// caption and one permission, with the second unreachable through
  /// [findAction] for the controller's lifetime.
  ///
  /// Registration happens in the [TomAction] constructor, so the throw lands at
  /// the definition site. For the canonical `late final` action field that is
  /// the first *read* of the field rather than the controller's construction —
  /// later than one might expect, and still the earliest point at which the
  /// duplicate exists.
  static void addUniquely(List<TomAction> registered, TomAction action) {
    if (registered.any((each) => each.actionId == action.actionId)) {
      throw StateError(
        'Duplicate action id "${action.actionId}" on controller '
        '"${action.controller.controllerId}". Both actions would resolve the '
        'authorization and resource keys of "${action.canonicalPath}", and '
        'findAction would only ever return the first. Give one of them a '
        'different actionId.',
      );
    }
    registered.add(action);
  }

  /// All registered actions.
  List<TomAction> get actions => List.unmodifiable(_actions);

  /// Finds an action by its [actionId], or null when this controller has none.
  ///
  /// At most one can match: [registerAction] refuses a duplicate id.
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
