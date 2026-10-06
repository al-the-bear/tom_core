// Cooperative cancellation primitive.
//
// A [CancellationTokenSource] owns the writable side; it hands a
// read-only [CancellationToken] to downstream work and calls
// [CancellationTokenSource.cancel] when that work should stop. The
// downstream side checks the token at every await point — polling
// [CancellationToken.isCancelled] for a synchronous fast-check, or
// awaiting [CancellationToken.whenCancelled] to race cancellation
// against another operation.
//
// This is deliberately the smallest useful surface: a future for the
// async-wait path and a bool for the fast-check path. It is NOT a
// timer — a wall-clock budget is a separate concern; compose a
// [CancellationTokenSource] with a `Timer` at the call site if
// timeout-driven cancellation is wanted.

import 'dart:async';

/// Read-only side of a cancellation channel.
///
/// Consumers receive a token and either await [whenCancelled] (for
/// async paths that want to race cancellation against another
/// operation) or poll [isCancelled] (for synchronous fast-checks at
/// the start of a critical section).
///
/// A token never "un-cancels": once signalled it stays signalled and
/// [whenCancelled] resolves exactly once.
abstract class CancellationToken {
  /// `true` once the source has been cancelled.
  ///
  /// Cheap to call repeatedly — long-running work checks it before
  /// issuing the next chunk.
  bool get isCancelled;

  /// Completes (with `void`) the first time the source is cancelled.
  ///
  /// Never throws. Awaiting an already-cancelled token returns
  /// immediately. Awaiting a never-cancelled token blocks until the
  /// source either cancels or is garbage-collected (callers are
  /// responsible for not holding onto a token whose source has been
  /// abandoned).
  Future<void> get whenCancelled;

  /// A token that is permanently uncancelled. Useful as a default
  /// when a caller does not need cancellation.
  static const CancellationToken none = _NeverCancelled();
}

/// Writable side of a cancellation channel.
///
/// Owners of a [CancellationTokenSource] hand the [token] to a
/// downstream call and call [cancel] when they want the downstream
/// work to stop. Calling [cancel] a second time is a no-op.
final class CancellationTokenSource {
  final Completer<void> _completer = Completer<void>();
  late final _Token _token = _Token(_completer);

  /// The read-only token that observers hold.
  CancellationToken get token => _token;

  /// `true` once [cancel] has been called.
  bool get isCancelled => _completer.isCompleted;

  /// Signals cancellation. Idempotent.
  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }
}

class _Token implements CancellationToken {
  final Completer<void> _completer;
  const _Token(this._completer);

  @override
  bool get isCancelled => _completer.isCompleted;

  @override
  Future<void> get whenCancelled => _completer.future;
}

/// Thrown by an operation that was racing a [CancellationToken] when
/// the token signalled before the operation completed.
///
/// The underlying work (e.g. an in-flight HTTP POST) may still be
/// running — `package:http`'s standard `Client` has no per-request
/// abort handle — but its result is abandoned: the caller observes
/// this exception instead. Lets a batch that hit cancellation on one
/// input stop issuing / awaiting work on the others cleanly rather
/// than running every remaining call to completion and discarding the
/// results.
final class OperationCancelled implements Exception {
  /// Optional human-readable label of the cancelled operation.
  final String? operation;

  const OperationCancelled([this.operation]);

  @override
  String toString() => operation == null
      ? 'OperationCancelled'
      : 'OperationCancelled($operation)';
}

class _NeverCancelled implements CancellationToken {
  const _NeverCancelled();

  @override
  bool get isCancelled => false;

  @override
  Future<void> get whenCancelled => _neverFuture;
}

// A future that never completes. Cached so `CancellationToken.none`
// does not allocate per call.
final Future<void> _neverFuture = Completer<void>().future;
