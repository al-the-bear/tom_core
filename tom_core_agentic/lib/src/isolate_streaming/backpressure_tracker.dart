// Credit-based backpressure tracker for streaming protocols.
//
// A pure async credit ledger: a producer waits for a positive credit
// balance before emitting each item, and a consumer tops the ledger up
// as it drains. Used by isolate-streaming adapters to keep a fast
// in-isolate producer from overrunning a slower cross-boundary consumer,
// but it has no isolate-specific coupling — it is a plain
// counting-semaphore-with-FIFO-waiters.

import 'dart:async';

/// Per-stream credit ledger held by a stream producer.
///
/// Backpressured producers construct one of these with an initial credit
/// allowance. Unbounded streams skip the tracker entirely — items flow
/// without credit accounting.
///
/// Usage:
///
///   ```dart
///   final tracker = BackpressureTracker(initialCredits: 16);
///   while (more) {
///     await tracker.awaitCredit();
///     pushChunk();
///     tracker.consume(1);
///   }
///   ```
///
/// `awaitCredit()` returns immediately when credits > 0; otherwise it
/// waits until [grant] is called. Multiple callers may be parked; they
/// are released in FIFO order one credit at a time.
final class BackpressureTracker {
  int _credits;
  final List<Completer<void>> _waiters = <Completer<void>>[];
  bool _closed = false;

  BackpressureTracker({required int initialCredits}) : _credits = initialCredits {
    if (initialCredits < 0) {
      throw ArgumentError.value(
        initialCredits,
        'initialCredits',
        'must be non-negative',
      );
    }
  }

  /// Remaining credits. Visible for tests.
  int get credits => _credits;

  /// Number of waiters parked on [awaitCredit]. Visible for tests.
  int get waiterCount => _waiters.length;

  /// Whether [close] has been called. Subsequent [awaitCredit] calls
  /// throw [StateError].
  bool get isClosed => _closed;

  /// Returns once at least one credit is available. Does not decrement —
  /// call [consume] after pushing the chunk.
  Future<void> awaitCredit() {
    if (_closed) {
      return Future<void>.error(
        StateError('BackpressureTracker is closed.'),
      );
    }
    if (_credits > 0) return Future<void>.value();
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Consumes [n] credits (default 1). Permits going to zero; rejects
  /// going negative.
  void consume([int n = 1]) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'must be non-negative');
    }
    if (n > _credits) {
      throw StateError(
        'BackpressureTracker.consume($n) but only $_credits credits available.',
      );
    }
    _credits -= n;
  }

  /// Grants [n] more credits. Wakes up to [n] parked waiters in FIFO
  /// order; remaining credits stay on the ledger.
  void grant(int n) {
    if (_closed) return;
    if (n <= 0) {
      throw ArgumentError.value(n, 'n', 'must be positive');
    }
    _credits += n;
    while (_waiters.isNotEmpty && _credits > 0) {
      final w = _waiters.removeAt(0);
      if (!w.isCompleted) {
        w.complete();
      }
    }
  }

  /// Closes the tracker. Pending waiters fail with [StateError].
  void close() {
    if (_closed) return;
    _closed = true;
    final waiters = List<Completer<void>>.from(_waiters);
    _waiters.clear();
    for (final w in waiters) {
      if (!w.isCompleted) {
        w.completeError(StateError('BackpressureTracker is closed.'));
      }
    }
  }
}
