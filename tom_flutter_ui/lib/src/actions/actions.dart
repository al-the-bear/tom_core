/// Tom Action System — behavioral counterpart to widgets.
///
/// Actions execute business logic with typed context, authorization,
/// undo support, and clean integration into the widget layer.
///
/// Core classes:
/// - [TomAction] — base class for all actions
/// - [TomActionController] — container for related actions
/// - [TomActionContext] — base context available to all actions
/// - [TomActionTransaction] — atomic multi-action grouping
/// - [TomActionTrigger] — connects widgets to actions
///
/// Undo/redo:
/// - [TomActionUndo] — tag interface for undo state
/// - [TomUndoHistory] — application-level undo/redo stack
/// - [TomUndoAction] / [TomRedoAction] — coordinator actions
///
/// Multi-action adapters:
/// - [TomCompositeAction] — executes multiple actions sequentially
library;

export 'tom_action.dart';
export 'tom_action_controller.dart';
export 'tom_action_context.dart';
export 'tom_action_transaction.dart';
export 'tom_action_trigger.dart';
export 'tom_undo_history.dart';
export 'tom_composite_action.dart';
