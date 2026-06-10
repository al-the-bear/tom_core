// Cancellation family for cross-isolate streaming protocols.
//
// This is the generic, transport-agnostic core of the cancellation
// protocol used by isolate adapters (e.g. the brain-memory isolate
// boundary). It carries no knowledge of any concrete message catalogue:
// the request/response *envelopes* that ferry a token across the
// boundary belong to the adapter that owns the message protocol; this
// module only owns the token, its allocator, the in-isolate registry,
// the per-request handle, and the typed cancellation exception.
//
// Why an `Isolate`-prefixed family (and not the cooperative
// `CancellationToken` in `cancellation.dart`):
//
//   The cooperative `CancellationToken` is a *behavioural* token —
//   consumers `await whenCancelled` and check `isCancelled` to abort
//   in-process work. This family is a *protocol* token: an opaque,
//   sendable integer id that names a cancellable request crossing an
//   isolate boundary. The state lives in an in-isolate
//   `IsolateCancellationRegistry`; the token itself carries no state.
//   The two abstractions co-exist in this package, so the protocol
//   family is named distinctly to keep call sites unambiguous.
//
// Sendability:
//
//   [IsolateCancellationToken] is a single-integer value type, so it
//   crosses isolate boundaries trivially. The registry and handle live
//   only inside the executor's isolate; they never cross.
//
// Lifecycle:
//
//   1. The host allocates a token
//      ([IsolateCancellationTokenAllocator.next]) and includes it in a
//      cancellable request envelope owned by the adapter.
//   2. The in-isolate executor registers the token
//      ([IsolateCancellationRegistry.register]) before invoking the
//      cancellable operation.
//   3. If a cancel envelope arrives, the executor flips the registry's
//      cancelled-flag for that token ([IsolateCancellationRegistry.cancel]).
//   4. The executor checks the flag at well-defined checkpoints
//      (pre-call, between stream chunks, post-call); on cancellation it
//      raises [IsolateCancellationException].
//   5. The executor disposes the handle after the response is sent.
//
// Cancellation can be observed before, during, or after the call — the
// registry honours whichever order it sees (see the late-cancel note on
// [IsolateCancellationRegistry]).

import 'dart:async';

/// Opaque identifier for a cancellable request, sendable across an
/// isolate boundary.
///
/// Allocated by the host ([IsolateCancellationTokenAllocator]) and
/// included in the request envelope. The in-isolate
/// [IsolateCancellationRegistry] keys off the integer value; tokens are
/// unique per host instance and not recycled within a host lifetime.
///
/// The token is `int`-shaped (boxed) rather than a raw `int` so that
/// signatures stay readable (`recall(query, cancellation: token)` vs.
/// `recall(query, cancellation: 42)`) and so the host-side allocator
/// has a typed return value.
final class IsolateCancellationToken {
  /// Monotonic integer assigned by the host.
  final int id;

  const IsolateCancellationToken(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IsolateCancellationToken && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'IsolateCancellationToken($id)';
}

/// Host-side counter that hands out unique [IsolateCancellationToken]s.
///
/// One allocator per isolate host. Not thread-safe in the cross-isolate
/// sense (the allocator lives on the host side; each allocation is on
/// the host's isolate which is single-threaded by definition).
final class IsolateCancellationTokenAllocator {
  int _next = 1;

  /// Returns a fresh [IsolateCancellationToken] and advances the counter.
  IsolateCancellationToken next() => IsolateCancellationToken(_next++);

  /// Visible for tests — returns the next id without advancing.
  int get peekNext => _next;
}

/// In-isolate registry of cancellation state per token.
///
/// One registry per executor. Tokens are registered on envelope arrival,
/// the cancelled-flag is flipped on cancel-envelope arrival, and the
/// token is unregistered when the response is sent. Unknown tokens
/// (`register` not called, or already unregistered) are silently no-op
/// for `cancel(token)` — the protocol allows the cancel to arrive
/// *before* the open envelope or *after* the close, and we treat both as
/// benign (the future request will see the cancel; a past request had
/// nothing to cancel anyway).
///
/// **Late-cancel semantics**: when a `cancel(token)` arrives for a token
/// that has not yet been registered, the registry remembers the
/// cancellation in `_pendingCancellations` so the subsequent
/// `register(token)` sees the flag already raised. This handles the
/// natural race where the host sends a cancel immediately after the open
/// envelope, but the cancel arrives first because the open envelope is
/// still mid-dispatch.
final class IsolateCancellationRegistry {
  final Map<int, _RegistryEntry> _entries = <int, _RegistryEntry>{};
  final Set<int> _pendingCancellations = <int>{};

  /// Registers [token] as in-flight. The returned [IsolateCancellationHandle]
  /// is the handle the executor uses to read [IsolateCancellationHandle.isCancelled]
  /// and to complete the registration.
  ///
  /// If the token has a pending cancel (a cancel arrived before
  /// `register`), the returned handle is already cancelled.
  IsolateCancellationHandle register(IsolateCancellationToken token) {
    final wasPending = _pendingCancellations.remove(token.id);
    final entry = _RegistryEntry(cancelled: wasPending);
    _entries[token.id] = entry;
    return IsolateCancellationHandle._(token, entry, this);
  }

  /// Flips the cancelled-flag for [token].
  ///
  /// If the token is not yet registered, the cancellation is remembered
  /// so the eventual `register(token)` returns an already-cancelled
  /// handle.
  void cancel(IsolateCancellationToken token) {
    final entry = _entries[token.id];
    if (entry != null) {
      entry.markCancelled();
    } else {
      _pendingCancellations.add(token.id);
    }
  }

  /// Whether [token] has been cancelled — independent of whether it is
  /// currently registered.
  bool isCancelled(IsolateCancellationToken token) {
    final entry = _entries[token.id];
    if (entry != null) return entry._cancelled;
    return _pendingCancellations.contains(token.id);
  }

  /// Number of currently registered (in-flight) tokens. Visible for
  /// tests.
  int get inFlightCount => _entries.length;

  /// Number of remembered pending cancellations. Visible for tests.
  int get pendingCancelCount => _pendingCancellations.length;

  void _unregister(int id) {
    _entries.remove(id);
  }
}

class _RegistryEntry {
  bool _cancelled;

  /// Completes the first time the entry is cancelled. Lets a producer
  /// `await` cancellation instead of polling the flag.
  final Completer<void> _cancelSignal = Completer<void>();

  _RegistryEntry({required bool cancelled}) : _cancelled = cancelled {
    if (cancelled) _cancelSignal.complete();
  }

  /// Idempotently raises the cancelled-flag and fires [_cancelSignal].
  void markCancelled() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
  }
}

/// Per-request cancellation handle returned by
/// [IsolateCancellationRegistry.register].
///
/// The executor reads [isCancelled] at the well-defined checkpoints
/// (before the call, between chunks for streams, after the call).
/// Calling [dispose] removes the registration; idempotent.
final class IsolateCancellationHandle {
  final IsolateCancellationToken token;
  final _RegistryEntry _entry;
  final IsolateCancellationRegistry _owner;
  bool _disposed = false;

  IsolateCancellationHandle._(this.token, this._entry, this._owner);

  /// Whether the request has been cancelled (either pre- or post-call).
  bool get isCancelled => _entry._cancelled;

  /// Completes the first time the request is cancelled. Lets a stream
  /// producer `await` cancellation alongside its source completion and
  /// close signal instead of polling the flag on a timer. Never
  /// completes if the request is not cancelled.
  Future<void> get cancelled => _entry._cancelSignal.future;

  /// Throws [IsolateCancellationException] when cancelled. Convenience
  /// for pre-call and post-call checkpoints.
  void throwIfCancelled() {
    if (_entry._cancelled) {
      throw IsolateCancellationException(token);
    }
  }

  /// Unregister this handle. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _owner._unregister(token.id);
  }
}

/// Thrown by the executor when a cancellable request is cancelled at (or
/// after) a checkpoint. An isolate host typically re-raises this across
/// the boundary as a generic boundary exception whose `exceptionType` is
/// `'IsolateCancellationException'`, which the client translates back to
/// this typed class for the caller.
final class IsolateCancellationException implements Exception {
  /// The token that was cancelled.
  final IsolateCancellationToken token;

  IsolateCancellationException(this.token);

  @override
  String toString() => 'IsolateCancellationException(token=${token.id})';
}
