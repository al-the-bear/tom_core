import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../resource_auth/tom_resources.dart';
import 'tom_action_context.dart';
import 'tom_action_controller.dart';
import 'tom_action_transaction.dart';

// =============================================================================
// TomActionUndo — tag interface for undo state
// =============================================================================

/// Tag interface for undo state objects.
///
/// Action implementations that support undo must return an object
/// implementing this interface from [TomAction.execute].
///
/// ```dart
/// class DeleteOrderUndo implements TomActionUndo {
///   final Order deletedOrder;
///   DeleteOrderUndo(this.deletedOrder);
/// }
/// ```
abstract interface class TomActionUndo {}

// =============================================================================
// TomAction — base class for all actions
// =============================================================================

/// Base class for all Tom actions.
///
/// Actions are the behavioral counterpart to widgets:
/// - **Stateless** — no mutable instance state between invocations
/// - **Typed** — context requirements declared via [TContext]
/// - **Authorized** — visibility controlled via the authorization system
/// - **Undoable** — optional undo support via [TUndo]
///
/// ```dart
/// class DeleteOrderAction extends TomAction<OrderContext, DeleteOrderUndo> {
///   DeleteOrderAction(TomActionController controller)
///       : super(actionId: 'delete', controller: controller);
///
///   @override
///   bool canExecute(OrderContext context) => context.selectedOrder != null;
///
///   @override
///   DeleteOrderUndo? execute(OrderContext context, TomActionTransaction tx) {
///     final order = context.selectedOrder!;
///     context.orderRepo.delete(order);
///     return DeleteOrderUndo(order);
///   }
///
///   @override
///   bool get isUndoable => true;
///
///   @override
///   void undo(DeleteOrderUndo undoState) {
///     // Restore the deleted order
///   }
/// }
/// ```
abstract class TomAction<TContext extends TomActionContext,
    TUndo extends TomActionUndo> implements TomAuthorizable {
  /// Unique action ID within its controller.
  final String actionId;

  /// The controller that owns this action.
  final TomActionController controller;

  /// Optional scope for resource resolution.
  final TomScope? scope;

  @override
  final TomAuthorizationGroup? authorizationGroup;

  TomAction({
    required this.actionId,
    required this.controller,
    this.scope,
    this.authorizationGroup,
  }) {
    authorizationGroup?.register(this);
    controller.registerAction(this);
  }

  @override
  String? get tomId => actionId;

  /// The canonical authorization path for this action.
  ///
  /// Format: `ac-<controllerId>.a-<actionId>`
  String get canonicalPath => 'ac-${controller.controllerId}.a-$actionId';

  /// Whether this action can execute given the current [context].
  ///
  /// Override for business-rule gating (e.g., list is empty, form invalid).
  bool canExecute(TContext context) => true;

  /// Executes the action and optionally returns undo state.
  ///
  /// Returns `null` if undo is not supported or not applicable.
  TUndo? execute(TContext context, TomActionTransaction tx);

  /// Whether this action supports undo.
  bool get isUndoable => false;

  /// Reverses the action using the saved undo state.
  ///
  /// Only called if [isUndoable] is `true` and [execute] returned non-null.
  void undo(TUndo undoState) {}

  /// Gets the authorization state for this action.
  TomAuthState get authState => TomAuthorization.resolveAuth(canonicalPath);

  /// Creates a [TomAuthorizer] backed by this action's authorization.
  ///
  /// Applies the default pattern: widget full + action none = disabled.
  TomAuthorizer get authorizer => TomAuthorizer.fromAction(
        actionAuth: () => authState,
      );

  // ===========================================================================
  // Resource resolution
  // ===========================================================================

  /// Resolves the action's display label from resources.
  ///
  /// Looks up `<canonicalPath>.label` in the resource system.
  String get label {
    if (TomUIResources.resourceExists('$canonicalPath', 'label')) {
      return TomUIResources.resolveText('$canonicalPath', 'label');
    }
    return actionId;
  }

  /// Resolves the action's tooltip from resources.
  String? get tooltip {
    if (!TomUIResources.resourceExists('$canonicalPath', 'tooltip')) return null;
    return TomUIResources.resolveText('$canonicalPath', 'tooltip');
  }

  /// Resolves the action's icon name from resources.
  String? get iconName {
    if (!TomUIResources.resourceExists('$canonicalPath', 'icon')) return null;
    return TomUIResources.resolveText('$canonicalPath', 'icon');
  }

  @override
  String toString() => 'TomAction($canonicalPath)';
}

/// A [TomAction] that does not produce undo state.
///
/// Convenience base class for actions that are not undoable.
abstract class TomSimpleAction<TContext extends TomActionContext>
    extends TomAction<TContext, TomActionUndo> {
  TomSimpleAction({
    required super.actionId,
    required super.controller,
    super.scope,
    super.authorizationGroup,
  });

  /// Executes the simple action (no undo state returned).
  void executeSimple(TContext context, TomActionTransaction tx);

  @override
  TomActionUndo? execute(TContext context, TomActionTransaction tx) {
    executeSimple(context, tx);
    return null;
  }
}

