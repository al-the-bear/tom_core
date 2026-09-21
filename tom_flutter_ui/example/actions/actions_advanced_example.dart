/// Executable advanced example for the `actions/` module of `tom_flutter_ui`.
///
/// Picks up where `actions_example.dart` leaves off, and reuses the counter
/// domain declared there. Covers the surfaces an application reaches once the
/// basics work: the undo/redo **coordinator actions**, the **authorization**
/// surface an action exposes to a widget, **resource** resolution for a label,
/// tooltip and icon, the **scope frames** a path and an invocation are resolved
/// in, controller-level **authorization groups**, the direct
/// `TomActionTransaction` API including `rollback`, and the refusal of a
/// duplicate action id.
///
/// Because it imports `package:tom_flutter_ui/tom_flutter_ui.dart` (which pulls
/// in `flutter/material` → `dart:ui`), bare `dart run` cannot execute it. Run
/// `flutter test test/actions/actions_advanced_example_test.dart`, which calls
/// this example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'actions_example.dart';

// ---------------------------------------------------------------------------
// Fixtures this example adds to the shared counter domain.
// ---------------------------------------------------------------------------

/// Reports the scope in force each time it is consulted.
///
/// A context's `scope` affects only the *ambient* frame, so no return value can
/// show it; this reports `TomScope.current` instead, which is what a nested
/// controller or a resource lookup inside the action would have read.
class FrameProbeContext extends TomActionContext {
  final List<String> frames;
  FrameProbeContext({required this.frames, super.scope});
}

class FrameProbeAction extends TomSimpleAction<FrameProbeContext> {
  FrameProbeAction({required super.controller}) : super(actionId: 'frameProbe');

  @override
  bool canExecute(FrameProbeContext context) {
    context.frames.add(TomScope.current.id);
    return true;
  }

  @override
  void executeSimple(FrameProbeContext context, TomActionTransaction tx) {
    context.frames.add(TomScope.current.id);
  }
}

/// A row store, and an action whose undo **appends** rather than assigns.
///
/// [IncrementAction]'s undo writes `counter.value = previous`, so running it
/// twice lands on the same number — which makes it useless for showing that
/// something happened once rather than twice. Restoring a deleted row is the
/// realistic shape (the module's own dartdoc uses `DeleteOrderAction`), and it
/// is what lets section 5 demonstrate that a second `rollback` really is a
/// no-op instead of merely claiming so.
class RowContext extends TomActionContext {
  final List<String> rows;
  RowContext(this.rows);
}

class RestoreRowUndo implements TomActionUndo {
  final List<String> rows;
  final String removed;
  RestoreRowUndo(this.rows, this.removed);
}

class DeleteRowAction extends TomAction<RowContext, RestoreRowUndo> {
  DeleteRowAction({required super.controller}) : super(actionId: 'deleteRow');

  @override
  RestoreRowUndo execute(RowContext context, TomActionTransaction tx) =>
      RestoreRowUndo(context.rows, context.rows.removeLast());

  @override
  bool get isUndoable => true;

  @override
  void undo(RestoreRowUndo undoState) => undoState.rows.add(undoState.removed);

  @override
  bool get isRedoable => true;

  @override
  void redo(RestoreRowUndo undoState) =>
      undoState.rows.remove(undoState.removed);
}

/// Resolves a few paths to fixed states, and everything else to full.
///
/// A real application's adapter asks a policy service; the shape is the same.
class _DemoAuthAdapter implements TomAuthorizationAdapter {
  const _DemoAuthAdapter(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void run() {
  // -------------------------------------------------------------------------
  // 1. The coordinator actions — undo and redo as first-class actions.
  // -------------------------------------------------------------------------
  // `TomUndoHistory.undo()` can be called directly, but a toolbar wants an
  // *action*: something with a canonical path, an authorization state and a
  // `canExecute` that disables the button. That is what the coordinator pair
  // is for, and `TomUndoRedoContext` is the context they take — a scope and
  // nothing else, because undoing needs no domain input.
  final counter = Counter();
  final controller = CounterController();
  final history = TomUndoHistory();

  final toolbar = TomActionController(controllerId: 'toolbar');
  final undoAction = TomUndoAction(controller: toolbar, history: history);
  final redoAction = TomRedoAction(controller: toolbar, history: history);

  TomActionTrigger<TomUndoRedoContext, TomActionUndo> button(
    TomAction<TomUndoRedoContext, TomActionUndo> action,
    void Function() onRefused,
  ) => TomActionTrigger<TomUndoRedoContext, TomActionUndo>(
    action: action,
    contextBuilder: TomUndoRedoContext.new,
    onCannotExecute: onRefused,
  );

  var refusedPresses = 0;
  final undoButton = button(undoAction, () => refusedPresses++);
  final redoButton = button(redoAction, () => refusedPresses++);

  // Nothing has happened yet, so both coordinators refuse: this is what keeps
  // a toolbar button disabled rather than inert.
  final undoEnabledAtStart = undoAction.canExecute(TomUndoRedoContext());
  undoButton.trigger();

  // Do something worth undoing, through an ordinary trigger.
  TomActionTrigger<CounterContext, IncrementUndo>(
    action: controller.increment,
    contextBuilder: () => CounterContext(counter),
    undoHistory: history,
  ).trigger();

  undoButton.trigger(); // counter back to 0
  final afterUndoButton = counter.value;
  redoButton.trigger(); // and forward again
  final afterRedoButton = counter.value;

  print(
    'coordinators: paths ${undoAction.canonicalPath} / '
    '${redoAction.canonicalPath}, undo=$afterUndoButton redo=$afterRedoButton, '
    'refused presses $refusedPresses',
  );

  // -------------------------------------------------------------------------
  // 2. The authorization surface an action exposes.
  // -------------------------------------------------------------------------
  // Three readings, each answering a different question:
  //   authState           what the policy says about this action's path
  //   effectiveAuthState  that, narrowed by the action's group
  //   authorizer          the two combined into the value a widget takes
  TomAuthorization.adapter = const _DemoAuthAdapter({
    'admin.purge': TomAuthState.full,
    'admin.archive': TomAuthState.full,
    'retention': TomAuthState.disabled, // the group's ceiling
    'secured.delete': TomAuthState.none, // hidden outright
  });

  final retention = TomAuthorizationGroup(
    'retention',
    mode: AuthGroupMode.controlsWidest,
  );
  final admin = TomActionController(controllerId: 'admin');
  final purge = IncrementAction(controller: admin, id: 'purge');
  final archive = IncrementAction(
    controller: admin,
    id: 'archive',
    tomGroup: retention,
  );

  // `purge` names no group, so its own rule is the whole answer.
  final purgeRaw = purge.authState; // full
  final purgeEffective = purge.effectiveAuthState; // full
  // `archive` is under a group the policy has disabled, and `controlsWidest`
  // narrows a member to the group's ceiling — so a rule saying `full` does not
  // survive it.
  final archiveRaw = archive.authState; // full
  final archiveEffective = archive.effectiveAuthState; // disabled

  // `authorizer` is what a widget is handed. It carries the framework's
  // default rule — a widget that would be fully available, holding an action
  // the user may not perform, renders *disabled* rather than vanishing, so the
  // control the user expects is still there and visibly unavailable.
  final secured = TomActionController(controllerId: 'secured');
  final hidden = IncrementAction(controller: secured, id: 'delete');
  final widgetSeesForHidden = hidden.authorizer.effectiveAuth(
    TomAuthState.full,
  );
  final widgetSeesForPurge = purge.authorizer.effectiveAuth(TomAuthState.full);

  print(
    'authorization: purge ${purgeRaw.name}/${purgeEffective.name}, '
    'archive ${archiveRaw.name}/${archiveEffective.name}, '
    'widget-for-hidden ${widgetSeesForHidden.name}, '
    'widget-for-purge ${widgetSeesForPurge.name}',
  );

  // -------------------------------------------------------------------------
  // 3. A hidden action is refused rather than run.
  // -------------------------------------------------------------------------
  // A button bound to `authorizer` above is already disabled, so nothing
  // reaches here. This is the path that does not go through one — a keyboard
  // shortcut, a test, a callback holding `trigger` directly.
  final securedCounter = Counter();
  var contextsBuilt = 0;
  var refusals = 0;
  TomActionTrigger<CounterContext, IncrementUndo>(
    action: hidden,
    contextBuilder: () {
      contextsBuilt++;
      return CounterContext(securedCounter);
    },
    onCannotExecute: () => refusals++,
  ).trigger();
  final refusedByAuth = !hidden.isAuthorized;
  print(
    'hidden action: ${hidden.effectiveAuthState.name}, '
    'ran ${securedCounter.value == 1}, refused $refusals, '
    'contexts built $contextsBuilt',
  );

  // -------------------------------------------------------------------------
  // 4. Captions come from resources, keyed by the canonical path.
  // -------------------------------------------------------------------------
  // `label`, `tooltip` and `iconName` each resolve `<canonicalPath>.<suffix>`,
  // so an action is captioned by *where it is* rather than by a string in the
  // call site — which is what lets one bundle translate a whole application.
  // `label` falls back to the action id, so a missing caption degrades to
  // something readable instead of an empty button.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {
      'admin': {
        'purge': {
          'label': 'Purge now',
          'tooltip': 'Delete records past their retention window',
          'icon': 'mDeleteSweep',
        },
      },
    }),
  );

  final label = purge.label; // from the bundle
  final tooltip = purge.tooltip; // from the bundle
  final icon = purge.iconName; // a name; the widget maps it to an IconData
  final uncaptionedLabel = archive.label; // no entry → the action id
  final uncaptionedTooltip = archive.tooltip; // no entry → null

  print(
    'resources: label "$label", tooltip "$tooltip", icon "$icon"; '
    'uncaptioned label "$uncaptionedLabel", tooltip $uncaptionedTooltip',
  );

  // Put the empty bundle back: a provider is process-wide, and an example that
  // left its own installed would caption everything that runs after it.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomAuthorization.reset();

  // -------------------------------------------------------------------------
  // 5. The transaction API directly, including rollback.
  // -------------------------------------------------------------------------
  // `run` is the usual entry point. Underneath it are `record` — for an undo
  // state you already hold — and the three ways a transaction's effects move:
  // `rollback` for a gesture that failed part-way, and `undoAll` / `redoAll`,
  // which the history calls.
  final rows = ['a', 'b', 'c', 'd'];
  final rowCtx = RowContext(rows);
  final deleteRow = DeleteRowAction(
    controller: TomActionController(controllerId: 'rows'),
  );

  final manual = TomActionTransaction(label: 'three deletions');
  manual.run(deleteRow, rowCtx);
  manual.run(deleteRow, rowCtx);

  // A third step, recorded by hand: `execute` returns the undo state and
  // `record` files it, which is what `run` does in one call. `TomAction`
  // declares `TUndo?` because an action may have nothing to reverse;
  // `DeleteRowAction` narrows that to a non-nullable `RestoreRowUndo`, so
  // there is nothing to check here.
  final undoState = deleteRow.execute(rowCtx, manual);
  manual.record(deleteRow, undoState);
  final afterThreeSteps = List.of(rows); // ['a']

  // Something later in the gesture failed, so abandon the whole thing. Rollback
  // reverses every recorded entry in reverse order and is a silent no-op if it
  // is reached twice — it runs from error handling, which may itself be entered
  // more than once. This undo *appends*, so a second rollback would be visible
  // as duplicated rows rather than hiding behind an assignment.
  manual.rollback();
  manual.rollback();
  final afterRollback = List.of(rows); // ['a', 'd', 'c', 'b'] — restored once

  // undoAll / redoAll on a committed transaction, which is what the history
  // drives. Each refuses when the transaction is already the way it would
  // leave it.
  final committed = TomActionTransaction(label: 'one deletion');
  committed.run(deleteRow, rowCtx);
  committed.commit();
  final afterCommitted = rows.length; // 3
  committed.undoAll();
  final afterUndoAll = rows.length; // 4
  committed.redoAll();
  final afterRedoAll = rows.length; // 3

  var secondUndoAllRefused = false;
  committed.undoAll();
  try {
    committed.undoAll();
  } on StateError {
    secondUndoAllRefused = true;
  }

  print(
    'transaction: three=$afterThreeSteps rollback=$afterRollback '
    'commit=$afterCommitted undoAll=$afterUndoAll redoAll=$afterRedoAll, '
    'second undoAll refused: $secondUndoAllRefused',
  );

  // -------------------------------------------------------------------------
  // 6. The frame an action's path is built in.
  // -------------------------------------------------------------------------
  // The scope is captured once, when the controller and its actions are
  // constructed, so the path is the same wherever it is later read from — and
  // an action's authorization group is resolved in that same frame.
  final scoped = TomScope.withScope('checkout', CounterController.new);
  final scopedPath = scoped.increment.canonicalPath;

  // The same, with the scope handed over as a value instead of installed on a
  // zone — the shape a builder callback produces.
  final detached = CounterController(scope: TomScopeBase(scopeId: 'checkout'));
  print(
    'scoped path: $scopedPath, detached prefix: ${detached.canonicalPrefix}',
  );

  // -------------------------------------------------------------------------
  // 7. The frame an *invocation* happens in — a different scope.
  // -------------------------------------------------------------------------
  // A context's `scope` is installed around both the gate and the body, so
  // anything they reach that reads `TomScope.current` sees where this
  // invocation is happening — while the action's canonical path, fixed at
  // construction, does not move.
  final frames = <String>[];
  final probe = FrameProbeAction(
    controller: TomActionController(controllerId: 'probe'),
  );
  TomScope.withScope('ambient', () {
    TomActionTrigger<FrameProbeContext, TomActionUndo>(
      action: probe,
      contextBuilder: () => FrameProbeContext(
        frames: frames,
        scope: TomScopeBase(scopeId: 'invocation'),
      ),
    ).trigger();
  });
  print('invocation frames: $frames (path still ${probe.canonicalPath})');

  // -------------------------------------------------------------------------
  // 8. A group declared once on the controller reaches every action it owns.
  // -------------------------------------------------------------------------
  // Membership and ceiling both, without being repeated per action. An action
  // that names its own group overrides it.
  final billing = TomAuthorizationGroup('billing');
  final reporting = TomAuthorizationGroup('reporting');
  final grouped = TomActionController(controllerId: 'gsec', tomGroup: billing);
  final inheritsGroup = IncrementAction(controller: grouped, id: 'edit');
  final ownGroup = IncrementAction(
    controller: grouped,
    id: 'report',
    tomGroup: reporting,
  );
  print(
    'groups: inherited ${inheritsGroup.tomGroup?.groupId}, '
    'own ${ownGroup.tomGroup?.groupId}, '
    'billing members ${billing.members.length}',
  );

  // -------------------------------------------------------------------------
  // 9. An action id is unique within its controller.
  // -------------------------------------------------------------------------
  // A duplicate would share one authorization decision and one set of
  // label/tooltip/icon keys with the action already registered — the very keys
  // section 4 resolved — so it is refused at construction.
  var duplicateRefused = false;
  try {
    IncrementAction(controller: admin, id: 'purge');
  } on StateError {
    duplicateRefused = true;
  }
  // The same id under a different controller is a different canonical path, so
  // there is nothing to collide.
  final elsewhere = IncrementAction(
    controller: TomActionController(controllerId: 'elsewhere'),
    id: 'purge',
  );
  print(
    'duplicate refused: $duplicateRefused, '
    'same id elsewhere: ${elsewhere.canonicalPath}',
  );

  // -------------------------------------------------------------------------
  // Assertions
  // -------------------------------------------------------------------------
  // 1. The coordinators are ordinary actions: canonical paths under their own
  // controller, and a `canExecute` that is false while there is nothing to do.
  assert(undoAction.canonicalPath == 'toolbar.undo');
  assert(redoAction.canonicalPath == 'toolbar.redo');
  assert(!undoEnabledAtStart);
  assert(refusedPresses == 1, 'the first press had nothing to undo');
  assert(afterUndoButton == 0);
  assert(afterRedoButton == 1);

  // 2. The three authorization readings differ exactly where the group bites.
  assert(purgeRaw == TomAuthState.full);
  assert(purgeEffective == TomAuthState.full);
  assert(archiveRaw == TomAuthState.full, 'its own rule says full');
  assert(archiveEffective == TomAuthState.disabled, 'the group narrows it');
  // A widget that would be fully available renders disabled for a hidden
  // action, and stays full for a permitted one.
  assert(widgetSeesForHidden == TomAuthState.disabled);
  assert(widgetSeesForPurge == TomAuthState.full);

  // 3. The hidden action did not run, the refusal was reported once, and the
  // context builder — application code — was never called.
  assert(securedCounter.value == 0);
  assert(refusals == 1);
  assert(contextsBuilt == 0);
  assert(refusedByAuth);

  // 4. Captions resolve by path, and a missing one degrades readably.
  assert(label == 'Purge now');
  assert(tooltip == 'Delete records past their retention window');
  assert(icon == 'mDeleteSweep');
  assert(uncaptionedLabel == 'archive', 'falls back to the action id');
  assert(uncaptionedTooltip == null, 'no fallback — there is nothing to show');

  // 5. Three deletions applied, one rollback reversed them, and a second
  // rollback did nothing — which only an appending undo can show: had rollback
  // run twice, `rows` would carry each restored row twice.
  assert(afterThreeSteps.length == 1, 'three of four rows deleted');
  assert(afterRollback.length == 4, 'every row back, exactly once');
  assert(afterRollback.toSet().length == 4, 'and none of them duplicated');
  assert(manual.entryCount == 3);
  // undoAll / redoAll move a committed transaction both ways, and each refuses
  // to repeat itself.
  assert(afterCommitted == 3);
  assert(afterUndoAll == 4);
  assert(afterRedoAll == 3);
  assert(secondUndoAllRefused);

  // 6. A scope reaches the controller prefix and every action path under it —
  // read here, outside the scope, and still 'checkout.counter.increment'.
  assert(scopedPath == 'checkout.counter.increment');
  assert(scoped.canonicalPrefix == 'checkout.counter');
  assert(detached.canonicalPrefix == 'checkout.counter');

  // 7. The gate and the body both ran in the context's frame, not the ambient
  // one — and the action's own path is unaffected by where it was invoked.
  assert(frames.length == 2);
  assert(frames.every((frame) => frame == 'invocation'));
  assert(probe.canonicalPath == 'probe.frameProbe');

  // 8. The controller's group covers the action that named none, and only that
  // one — the overriding action never joins it.
  assert(identical(inheritsGroup.tomGroup, billing));
  assert(identical(ownGroup.tomGroup, reporting));
  assert(billing.members.length == 1);
  assert(billing.members.contains(inheritsGroup));

  // 9. The duplicate never registered; the same id elsewhere is a distinct path.
  assert(duplicateRefused);
  assert(admin.actions.length == 2, 'purge and archive, not three');
  assert(elsewhere.canonicalPath == 'elsewhere.purge');
}

void main() => run();
