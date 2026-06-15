# Isolate Streaming Module

A domain-free, `dart:io`-free toolkit for running cancellable, streaming work on
a worker isolate. The module owns five independent primitives — a cancellation
family, a per-stream close signal, a credit-based backpressure ledger, a
per-request guard (worker-death + deadline), and a typed exception registry that
survives the isolate boundary. Nothing here spawns an isolate or assumes a
transport; each primitive is a building block a host/worker pair assembles.

## Table of Contents

- [Overview](#overview)
- [Cancellation](#cancellation)
- [Stream Close Signal](#stream-close-signal)
- [Backpressure](#backpressure)
- [Request Guard](#request-guard)
- [Exception Registry](#exception-registry)
- [Concurrency and Lifecycle](#concurrency-and-lifecycle)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `IsolateCancellationToken` | class | Opaque, value-equal handle identifying one cancellable request |
| `IsolateCancellationTokenAllocator` | class | Hands out monotonically increasing tokens |
| `IsolateCancellationRegistry` | class | Host-side registry; cancels in-flight tokens and remembers late cancels |
| `IsolateCancellationHandle` | class | Worker-side view of one token: `isCancelled`, a `cancelled` future, `throwIfCancelled` |
| `IsolateCancellationException` | exception | Thrown by `throwIfCancelled` when the token is cancelled |
| `IsolateStreamCloseSignal` | class | Per-stream close flag + future a producer reacts to without busy-waiting |
| `BackpressureTracker` | class | FIFO credit ledger gating a producer to the consumer's drain rate |
| `IsolateRequestGuard` | class | Per-request completion guard: fails in-flight requests on worker death or deadline |
| `IsolateRequestFailureReason` | enum | `workerDeath` or `timeout` |
| `IsolateRequestFailure` | exception | The failure delivered to a guarded request |
| `IsolateExceptionRegistry` | class | Maps type tags to factories that rebuild typed errors across the boundary |
| `IsolateExceptionFactory` | typedef | `Object Function(String message, Map<String, Object?> details)` |

## Cancellation

Cancellation is split across the boundary. The **host** allocates a token, runs
the request, and may cancel it; the **worker** sees only a read-only handle.

```dart
final allocator = IsolateCancellationTokenAllocator();
final registry = IsolateCancellationRegistry();

// Host: allocate and register before dispatching to the worker.
final token = allocator.next();
final handle = registry.register(token);

// Worker side (handle shipped across): cooperative checks.
handle.throwIfCancelled();          // throws IsolateCancellationException once cancelled
await handle.cancelled;             // or await the cancellation future

// Host: cancel an in-flight request.
registry.cancel(token);
```

`register` returns an [`IsolateCancellationHandle`]; its `cancelled` future
completes when the host cancels, and `throwIfCancelled` raises
[`IsolateCancellationException`] for code that prefers a guard call to awaiting.

**Late-cancel race.** A cancel can arrive before the matching `register` (the
host cancels a request whose registration message is still in flight). The
registry remembers such cancels in a pending set, so a subsequent `register`
for that token returns an already-cancelled handle. `inFlightCount` and
`pendingCancelCount` expose the two sides of the ledger.

## Stream Close Signal

A streaming worker holds one [`IsolateStreamCloseSignal`] per open stream. A
host close request calls `requestClose`, which both raises the `closeRequested`
flag and fires the `closeSignal` future — so a backpressured producer can poll
the flag at its yield checkpoints while an unbounded producer awaits the future
alongside its source. `requestClose` is idempotent.

```dart
final signal = IsolateStreamCloseSignal();
// Unbounded producer: stop when source completes OR close is requested.
await Future.any([sourceDone, signal.closeSignal.future]);
// Backpressured producer: check between items.
if (signal.closeRequested) return;
```

## Backpressure

[`BackpressureTracker`] is a FIFO credit ledger. The consumer `grant`s credits
as it drains; the producer `awaitCredit`/`consume`s before emitting. Waiters are
released in arrival order, so a slow consumer paces a fast producer without an
unbounded buffer.

```dart
final bp = BackpressureTracker(initialCredits: 0);
bp.grant(2);                 // consumer signals room for 2 items
await bp.awaitCredit();      // producer blocks until a credit is free
bp.consume();                // spend one credit, then emit
bp.close();                  // fails parked waiters so producers unwind
```

`awaitCredit` does **not** decrement — it returns once `credits > 0`; the
producer calls `consume` after pushing the item. `grant(n)` must be positive and
wakes up to `n` FIFO waiters; `consume` rejects going negative. `credits`,
`waiterCount`, and `isClosed` expose the ledger state. After `close`, parked and
subsequent `awaitCredit` calls fail with `StateError` so producers can unwind.

## Request Guard

[`IsolateRequestGuard`] wraps each request future so that a request can never
hang past the worker's lifetime or a deadline. Each `guard` call fails with an
[`IsolateRequestFailure`] when the worker is marked dead or the per-request
timeout elapses, whichever comes first.

```dart
final guard = IsolateRequestGuard(defaultTimeout: Duration(seconds: 30));
final result = await guard.guard(
  workerReply.future,
  operation: 'embed',
);
// Elsewhere, on worker-exit detection:
guard.markWorkerDead('isolate exited with code 70');
// → every in-flight guarded request completes with
//   IsolateRequestFailure(reason: workerDeath, ...)
```

`isWorkerDead` and `inFlightCount` expose guard state; the failure's `reason`
distinguishes `workerDeath` from `timeout`, and its `message` carries the detail.

## Exception Registry

Errors thrown on a worker isolate arrive at the host as plain data. The
[`IsolateExceptionRegistry`] maps a string type-tag to an
[`IsolateExceptionFactory`] that rebuilds the typed error, so callers see the
real exception type rather than a generic envelope.

```dart
final registry = IsolateExceptionRegistry()
  ..register('NotFound', (msg, details) => NotFoundError(msg, id: details['id']));

final restored = registry.reconstruct('NotFound', 'missing', {'id': 'x-7'});
// restored is a NotFoundError, or null if 'NotFound' was never registered.
```

`reconstruct` returns `null` for an unregistered tag (the caller falls back to a
generic error); `isRegistered` and `registeredTypes` expose the taxonomy.

## Concurrency and Lifecycle

- **No isolate is spawned here.** Every primitive is a host- or worker-side
  helper; the caller owns the `Isolate.spawn` / `SendPort` wiring. The tests
  drive the host/worker handshake with hand-held `Completer`s rather than a real
  isolate, which is why the module is unit-testable without isolate plumbing.
- **Idempotent close/cancel.** `IsolateStreamCloseSignal.requestClose`,
  `BackpressureTracker.close`, and registry cancellation are all safe to call
  more than once.
- **Late signals are remembered.** The cancellation registry tolerates a cancel
  that races ahead of its registration; pair allocation (`allocator.next()`)
  with `registry.register` to keep token identity stable across the boundary.

## Core Components

- **Cancellation** — `IsolateCancellationToken`,
  `IsolateCancellationTokenAllocator`, `IsolateCancellationRegistry`,
  `IsolateCancellationHandle`, `IsolateCancellationException`.
- **`IsolateStreamCloseSignal`** — per-stream close flag + future.
- **`BackpressureTracker`** — FIFO credit ledger.
- **`IsolateRequestGuard`** — worker-death + deadline guard, with
  `IsolateRequestFailure` / `IsolateRequestFailureReason`.
- **`IsolateExceptionRegistry`** — type-tag → factory reconstruction, with the
  `IsolateExceptionFactory` typedef.

## Dependencies

- `dart:async` only. The module is `dart:io`-free and depends on no other
  `tom_core_agentic` module, so it is safe to reuse from any tier (including
  `dart:io`-forbidding consumers).
