/// Tom Action System — behavioral counterpart to widgets.
///
/// Actions execute business logic with typed context, authorization,
/// undo support, and clean integration into the widget layer.
///
/// Every type this library exports, grouped by what it is for:
///
/// Writing an action:
/// - [TomAction] — the base class for all actions
/// - [TomSimpleAction] — the base for an action that returns no undo state
/// - [TomActionContext] — the base context an action reads; domain contexts
///   extend it
/// - [TomActionUndo] — the marker an undo-state object implements
///
/// Owning and dispatching one:
/// - [TomActionController] — owns and names a group of actions, and supplies
///   the first segment of their canonical paths
/// - [TomActionTrigger] — the one thing that *runs* an action, binding it to a
///   widget callback
///
/// Undo and redo:
/// - [TomActionTransaction] — one gesture's worth of undo entries, committed
///   as an atomic unit
/// - [TomUndoHistory] — the bounded undo/redo stack of committed transactions
/// - [TomUndoAction] / [TomRedoAction] — coordinator actions that drive a
///   history, so undo and redo dispatch like anything else
/// - [TomUndoRedoContext] — the context those two take: a scope and nothing
///   else
///
/// Composing several:
/// - [TomCompositeAction] — runs a list of steps in order as one action
/// - [TomCompositeStep] — one step of a composite: its action, its context
///   builder and an optional guard
library;

export 'tom_action.dart';
export 'tom_action_controller.dart';
export 'tom_action_context.dart';
export 'tom_action_transaction.dart';
export 'tom_action_trigger.dart';
export 'tom_undo_history.dart';
export 'tom_composite_action.dart';
