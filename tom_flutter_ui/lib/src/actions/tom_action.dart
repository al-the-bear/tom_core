import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_scope_path.dart';
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
/// - **Authorized** — [effectiveAuthState] governs both whether a widget shows
///   the action and whether [TomActionTrigger] will run it ([isAuthorized])
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
abstract class TomAction<
  TContext extends TomActionContext,
  TUndo extends TomActionUndo
>
    implements TomAuthorizable {
  /// Unique action ID within its controller.
  final String actionId;

  /// The controller that owns this action.
  final TomActionController controller;

  /// Optional explicit scope for resource and authorization lookups.
  ///
  /// When provided, this scope is used instead of the controller's — see
  /// [constructionScope].
  final TomScope? scope;

  /// The authorization group this action belongs to: its own when it was given
  /// one, otherwise the controller's [TomActionController.tomGroup].
  ///
  /// The fallback is what makes a controller-level group mean anything. A group
  /// declared once on the controller covers every action it owns, which is what
  /// "collective action control" has to mean if it is to save the caller the
  /// per-action wiring; an action that names its own group still overrides it.
  ///
  /// Resolved at construction, like [constructionScope] and for the same
  /// reason — the group is *registered with* here, so it has to be known before
  /// the constructor body runs. A controller whose group is assignable
  /// therefore has to carry it by the time its actions are built; for a
  /// `TomForm`, that is while the form prepares itself, before any `late final`
  /// action field is first read.
  @override
  final TomAuthorizationGroup? tomGroup;

  /// The frame this action resolves in: its own [scope] when it was given one,
  /// otherwise the controller's [TomActionController.constructionScope].
  ///
  /// Named once and read everywhere, because every path this action produces
  /// has to come out of the same frame. [canonicalPath] and the group path are
  /// a `<prefix>.<id>` pair; a prefix that differs between them looks up a rule
  /// belonging to some other member. Capturing it at construction — rather than
  /// reading [TomScope.current] per lookup, as the group composition used to —
  /// is what makes the answer independent of where it is read from: an action
  /// is a long-lived object consulted from screens, triggers and group
  /// inspection alike, and only the zone it was built in describes where it
  /// actually lives.
  final TomScope constructionScope;

  TomAction({
    required this.actionId,
    required this.controller,
    this.scope,
    TomAuthorizationGroup? tomGroup,
  }) : tomGroup = tomGroup ?? controller.tomGroup,
       constructionScope = scope ?? controller.constructionScope {
    this.tomGroup?.register(this);
    controller.registerAction(this);
  }

  @override
  String? get tomId => actionId;

  /// The canonical authorization path for this action.
  ///
  /// Format: `<scopePath>.<controllerId>.<actionId>`, dropping the scope
  /// segment at the root — the same rule every other path in the package goes
  /// through ([TomScopePath]).
  ///
  /// The controller id stays in the path even when the action carries a scope
  /// of its own: it is the action's namespace, not its location, and dropping
  /// it would let two controllers in one scope collide on an action id.
  late final String canonicalPath = TomScopePath.join(
    TomScopePath.qualify(controller.controllerId, constructionScope),
    actionId,
  );

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

  /// Whether this action supports redo.
  ///
  /// Declared separately from [isUndoable] because knowing how to reverse a
  /// change does not imply knowing how to re-apply it: `undo` receives the
  /// snapshot it needs, whereas re-applying may need parameters that only the
  /// action itself holds. An action that overrides [redo] must say so here, the
  /// same way [undo] needs [isUndoable].
  ///
  /// This is what makes a Redo button honest. [TomUndoHistory.canRedo] is false
  /// unless every action in the transaction on top of the redo stack declares
  /// it, so a button bound to `TomRedoAction` stays disabled rather than
  /// enabling itself and doing nothing when pressed.
  bool get isRedoable => false;

  /// Re-applies the action using the saved undo state.
  ///
  /// The forward counterpart of [undo], and the reason redo can work at all: a
  /// transaction records `(action, undoState)` pairs, never the `TContext` an
  /// action ran with, so re-running [execute] is not available to it. [redo]
  /// takes the same argument [undo] does, which the transaction *does* hold.
  ///
  /// The undo state generally names the target of the change while the action
  /// holds the parameters — an increment's undo state carries the counter and
  /// its previous value, and the action carries the step — so the pair is
  /// enough to go either way:
  ///
  /// ```dart
  /// @override
  /// bool get isRedoable => true;
  ///
  /// @override
  /// void redo(IncrementUndo undoState) =>
  ///     undoState.counter.value = undoState.previous + step;
  /// ```
  ///
  /// Only called if [isRedoable] is `true` and the transaction was undone.
  void redo(TUndo undoState) {}

  /// Gets the authorization state for this action.
  TomAuthState get authState => TomAuthorization.resolveAuth(canonicalPath);

  @override
  TomAuthState get effectiveAuthState {
    var state = authState;
    // The group is resolved in the frame [canonicalPath] was built from. Read
    // against the ambient scope instead, the ceiling lands on whichever
    // same-named group the *reader* happens to stand in — or, at the root, on
    // no group rule at all.
    if (tomGroup != null) {
      state = tomGroup!.applyMode(state, constructionScope);
    }
    return state;
  }

  /// Whether authorization permits this action to run.
  ///
  /// `effectiveAuthState.isInteractive` — which is `full` and nothing else, the
  /// kernel's own predicate. Read by [TomActionTrigger] before it dispatches
  /// and by `TomCompositeAction` before it runs a step, so the answer that
  /// governs execution is the same one that governs the button: a widget bound
  /// to [authorizer] narrows to the action's state, and a state below `full` is
  /// not interactive there either.
  ///
  /// Not a security boundary — the server enforces. It is the check that stops
  /// a hidden or disabled action from running when it is reached by a path that
  /// never passed through a widget: a keyboard shortcut, a test, a callback
  /// holding the trigger directly.
  bool get isAuthorized => effectiveAuthState.isInteractive;

  /// Creates a [TomAuthorizer] backed by this action's authorization.
  ///
  /// Applies the default pattern: widget full + action none = disabled.
  TomAuthorizer get authorizer =>
      TomAuthorizer.fromAction(actionAuth: () => authState);

  // ===========================================================================
  // Resource resolution
  // ===========================================================================

  /// Resolves the action's display label from resources.
  ///
  /// Looks up `<canonicalPath>.label` in the resource system.
  String get label {
    return TomCtr.textOrNull(canonicalPath, 'label') ?? actionId;
  }

  /// Resolves the action's tooltip from resources.
  String? get tooltip {
    return TomCtr.textOrNull(canonicalPath, 'tooltip');
  }

  /// Resolves the action's icon name from resources.
  String? get iconName {
    return TomCtr.textOrNull(canonicalPath, 'icon');
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
    super.tomGroup,
  });

  /// Executes the simple action (no undo state returned).
  void executeSimple(TContext context, TomActionTransaction tx);

  @override
  TomActionUndo? execute(TContext context, TomActionTransaction tx) {
    executeSimple(context, tx);
    return null;
  }
}
