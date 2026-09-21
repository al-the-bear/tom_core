import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the shape that makes a mis-paired undo state a **compile** error.
///
/// `TomActionTransaction` used to hold `(TomAction action, dynamic undoState)`
/// pairs and reverse them with `entry.action.undo(entry.undoState)` — an
/// unchecked dynamic dispatch. Recording action A's state against action B
/// therefore compiled, analyzed clean, and threw a `TypeError` from inside the
/// history the first time somebody pressed undo, far from the call that was
/// wrong.
///
/// **The obvious fix does not work, and that is why this file exists.**
/// Declaring `record<TUndo extends TomActionUndo>(TomAction<_, TUndo>, TUndo)`
/// looks like it relates the two and does not: Dart's class type parameters are
/// covariant, so inference is free to widen `TUndo` to `TomActionUndo` and
/// accept any state at all. Measured against the analyzer on 2026-09-21, with
/// an `Act<T>` / `AUndo` / `BUndo` reduction of exactly this API:
///
/// ```dart
/// record(a, wrongState);  // inference-based  — NO error
/// a.pair(wrongState);     // receiver-pinned  — error
/// a.undo(wrongState);     // direct call      — error
/// ```
///
/// Only a receiver-pinned parameter rejects it, which is what
/// `TomAction.recordInto` is: `TUndo` is the *receiver's own* type argument, so
/// there is no inference left to widen.
///
/// These assertions read the source rather than running the analyzer. Asking
/// the analyzer is the direct evidence and was tried first — it passes, and
/// costs 12 min 18 s inside the package (37 s even for an import-free snippet;
/// the cost is analyzer start-up, not package size), which is more than this
/// claim is worth in a suite that already runs for fifty minutes. Reading the
/// declaration catches every way the API could be relaxed back, in
/// milliseconds.
void main() {
  /// The file's declarations, with dartdoc and comments removed.
  ///
  /// The prose explains what the code no longer does, so it names the very
  /// things these assertions require to be absent.
  String codeOf(String path) => File(
    path,
  ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

  final transaction = codeOf('lib/src/actions/tom_action_transaction.dart');
  final action = codeOf('lib/src/actions/tom_action.dart');

  group('the recorded reversal survives type checking', () {
    test('recordInto is on the action, taking the receiver\'s own TUndo', () {
      // The receiver pins TUndo. Moving this onto the transaction, in any form
      // that takes the action as an argument, reopens the hole.
      expect(
        action,
        contains('void recordInto(TomActionTransaction tx, TUndo undoState)'),
        reason:
            'recordInto must stay a member of TomAction with the undo state '
            'typed as the class\'s own TUndo — inference on a transaction '
            'method cannot express this, see the file comment',
      );
    });

    test('the transaction records calls, not an action and a state', () {
      // Taking the calls is what makes the transaction side safe by
      // construction: a closure body is checked against the receiver's real
      // signature, so `() => increment.undo(otherState)` does not compile.
      expect(transaction, contains('required String actionId'));
      expect(transaction, contains('required void Function() undo'));
      expect(transaction, contains('void Function()? redo'));
      expect(
        RegExp(r'void record\(\{').hasMatch(transaction),
        isTrue,
        reason: 'record takes named call parameters, not positional values',
      );
      expect(
        RegExp(r'void record<').hasMatch(transaction),
        isFalse,
        reason:
            'a generic record(action, undoState) is the shape that cannot be '
            'made safe — inference widens the undo type',
      );
    });

    test('no entry field is dynamic and no reversal dispatches dynamically', () {
      expect(
        transaction.contains('dynamic'),
        isFalse,
        reason: 'the undo state was `dynamic`; the closures replaced it',
      );
      expect(
        transaction.contains('entry.action'),
        isFalse,
        reason:
            'rollback / undoAll / redoAll must call the recorded closures, not '
            'dispatch through a stored action',
      );
      // What the entry keeps of the action is its id, for one diagnostic.
      // A whole-word match: `contains` alone passes for `actionId2`.
      expect(
        RegExp(r'final String actionId\b').hasMatch(transaction),
        isTrue,
        reason:
            'the entry keeps the id redoAll names when an entry has no redo',
      );
    });
  });
}
