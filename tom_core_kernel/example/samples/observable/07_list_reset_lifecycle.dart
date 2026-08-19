/// Example: TomList reset & lifecycle listeners
///
/// This example demonstrates the structural batch-replacement API on
/// [TomList]:
/// - [TomList.resetWith] — atomically replaces all contents with a single
///   observer notification
/// - [TomListLifecycleListener] — `onBeforeClear` / `onAfterReset` hooks that
///   fire around the replacement so dependent state can be torn down and
///   rebuilt
///
/// `resetWith` is the mechanism `TomListForm` (in `tom_flutter_ui`) uses to
/// keep its sub-form instances in sync when an outer form discards its changes
/// and restores the bind-time snapshot.
///
/// NOTE: Run `dart run build_runner build` before executing this example.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Records the lifecycle callbacks and the list sizes observed at each hook.
///
/// Capturing the size in `onBeforeClear` (old contents still present) and in
/// `onAfterReset` (new contents installed) proves the hooks fire on either
/// side of the swap.
class _RecordingLifecycleListener extends TomListLifecycleListener {
  final List<String> events = [];
  int sizeBeforeClear = -1;
  int sizeAfterReset = -1;

  @override
  void onBeforeClear(TomList list) {
    events.add('beforeClear');
    sizeBeforeClear = list.length;
  }

  @override
  void onAfterReset(TomList list) {
    events.add('afterReset');
    sizeAfterReset = list.length;
  }
}

void run() {
  print('=== TomList Reset & Lifecycle Example ===\n');

  // ===========================================================================
  // Example 1: resetWith replaces all contents atomically
  // ===========================================================================

  print('1. resetWith replaces every element:');

  final items = TomList<TomString>();
  items.append(TomString('alpha')).append(TomString('beta'));

  final before = items.map((e) => ~e).join(', ');
  items.resetWith([TomString('gamma'), TomString('delta'), TomString('epsilon')]);
  final after = items.map((e) => ~e).join(', ');

  print('   before: [$before]');
  print('   after:  [$after]');
  print('   length after reset: ${items.length}');
  print('');

  // ===========================================================================
  // Example 2: resetWith notifies observers exactly once
  // ===========================================================================

  print('2. A single notification fires for the whole batch:');

  final batch = TomList<TomInt>();
  batch.add(TomInt(1));
  int notifyCount = 0;
  // Retain the returned observer. TomObservable holds its observers by
  // WeakReference, so the wrapper `>>` hands back is the only strong reference
  // keeping the callback alive; discard it and notifications stop at the next
  // garbage collection, silently and nondeterministically.
  final batchObserver = batch >> (obs) => notifyCount++;

  batch.resetWith([TomInt(10), TomInt(20), TomInt(30)]);

  print('   elements: [${batch.map((e) => ~e).join(', ')}]');
  print('   observer notifications for the reset: $notifyCount');
  print('');

  batch.removeObserver(batchObserver);

  // ===========================================================================
  // Example 3: lifecycle hooks fire around the swap
  // ===========================================================================

  print('3. TomListLifecycleListener brackets the replacement:');

  final tracked = TomList<TomString>();
  tracked.append(TomString('one')).append(TomString('two'));

  final listener = _RecordingLifecycleListener();
  tracked.addLifecycleListener(listener);

  tracked.resetWith([TomString('x'), TomString('y'), TomString('z')]);

  print('   events: ${listener.events}');
  print('   size seen in onBeforeClear: ${listener.sizeBeforeClear} (old contents)');
  print('   size seen in onAfterReset: ${listener.sizeAfterReset} (new contents)');
  print('');

  // ===========================================================================
  // Example 4: removed listeners no longer fire
  // ===========================================================================

  print('4. removeLifecycleListener stops further callbacks:');

  tracked.removeLifecycleListener(listener);
  final eventCountBefore = listener.events.length;
  tracked.resetWith([TomString('done')]);
  final eventCountAfter = listener.events.length;

  print('   event count before second reset: $eventCountBefore');
  print('   event count after second reset:  $eventCountAfter (unchanged)');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: contents fully replaced
  assert(before == 'alpha, beta');
  assert(after == 'gamma, delta, epsilon');
  assert(items.length == 3);

  // Example 2: exactly one notification for the batch
  assert(notifyCount == 1);
  assert(batch.length == 3);

  // Example 3: hooks fire in order, with correct sizes on each side
  assert(listener.events.length == 2);
  assert(listener.events[0] == 'beforeClear');
  assert(listener.events[1] == 'afterReset');
  assert(listener.sizeBeforeClear == 2); // old contents still present
  assert(listener.sizeAfterReset == 3); // new contents installed

  // Example 4: detached listener is silent
  assert(eventCountBefore == 2);
  assert(eventCountAfter == 2);
}

/// Standalone entry point.
void main() => run();
