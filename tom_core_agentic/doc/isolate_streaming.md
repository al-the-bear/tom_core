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
| `IsolateCancellationToken` | class | Opaque, value-equal id naming one cancellable request — the only member of this family that crosses the boundary |
| `IsolateCancellationTokenAllocator` | class | Host-side counter handing out monotonically increasing tokens |
| `IsolateCancellationRegistry` | class | Worker-side registry; cancels in-flight tokens and remembers late cancels |
| `IsolateCancellationHandle` | class | Worker-side view of one token: `isCancelled`, a `cancelled` future, `throwIfCancelled` |
| `IsolateCancellationException` | exception | Thrown by `throwIfCancelled` when the token is cancelled |
| `IsolateStreamCloseSignal` | class | Per-stream close flag + future a producer reacts to without busy-waiting |
| `BackpressureTracker` | class | FIFO credit ledger gating a producer to the consumer's drain rate |
| `IsolateRequestGuard` | class | Host-side per-request completion guard: fails in-flight requests on worker death or deadline |
| `IsolateRequestFailureReason` | enum | `workerDeath` or `timeout` |
| `IsolateRequestFailure` | exception | The failure delivered to a guarded request |
| `IsolateExceptionRegistry` | class | Maps type tags to factories that rebuild typed errors across the boundary |
| `IsolateExceptionFactory` | typedef | `Object Function(String message, Map<String, Object?> details)` |

## Cancellation

Cancellation is split across the boundary, and the split is asymmetric: **only
the token crosses**. The host allocates a token and puts its id in its own
request envelope; the executor inside the worker isolate owns the registry,
registers the token when that envelope lands, and reads the handle at its
checkpoints. Cancelling is a *message*, not a method call — the host sends a
cancel envelope, and the executor turns it into `registry.cancel`.

The registry and the handle stay in the worker isolate because they cannot do
anything else: both hold a `Completer`, so sending one throws
`ArgumentError: ... object is unsendable`. The token is a single-integer value
type and crosses trivially.

```dart
// --- host isolate: allocate, and send the id in your own envelope ---
final allocator = IsolateCancellationTokenAllocator();

final token = allocator.next();
workerPort.send({'op': 'recall', 'cancellation': token.id});

// To abort, later — another message, not a call into the worker's registry:
workerPort.send({'op': 'cancel', 'cancellation': token.id});

// --- worker isolate: the registry lives here and never leaves ---
final registry = IsolateCancellationRegistry();

// When the request envelope arrives: register, then check at checkpoints.
final handle = registry.register(IsolateCancellationToken(tokenId));
handle.throwIfCancelled();          // throws IsolateCancellationException
await handle.cancelled;             // or await the cancellation future
handle.dispose();                   // once the response has been sent

// When the cancel envelope arrives: flip the flag for that token.
registry.cancel(IsolateCancellationToken(tokenId));
```

`register` returns an [`IsolateCancellationHandle`]; its `cancelled` future
completes when the executor applies the host's cancel, and `throwIfCancelled`
raises [`IsolateCancellationException`] for code that prefers a guard call to
awaiting.

**Late-cancel race.** A cancel can arrive before the matching `register` — the
host sends it right after the request envelope, but the request envelope is
still mid-dispatch. The registry remembers such a cancel in a pending set, so
the subsequent `register` for that token returns an already-cancelled handle.

An unknown-token cancel is ambiguous, though, and the registry does *not*
remember them all: an id it has already seen belongs to a request that has
since been disposed, so that cancel is dropped rather than pending forever
(ids are never recycled, so nothing would ever consume it). The two cases are
told apart by a high-water mark over registered ids. `inFlightCount` and
`pendingCancelCount` expose the two sides of the ledger.

**Two `isCancelled`s, two scopes.** The registry's `isCancelled(token)` reports
on what it currently holds — an in-flight entry or a remembered pre-open cancel
— so it answers `false` once the request is disposed, even for one that really
was cancelled. It has to: a durable record would accumulate cancelled-and-closed
ids for the executor's whole life, for the same reason the post-close cancel is
dropped. The handle's `isCancelled` does survive disposal, because the handle
holds the entry directly. Prefer the handle wherever one is in scope; reach for
the registry only when all you have is an id.

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
unbounded buffer. Like the close signal, the ledger is held by the producer
inside the worker isolate; a cross-boundary consumer's drain reaches it as a
message that calls `grant`.

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
  that races ahead of its registration.
- **Allocation and registration sit on opposite sides.** `allocator.next()` runs
  on the host, `registry.register` inside the worker isolate, and the token id
  is what travels between them — it is what keeps one request identifiable on
  both sides. Only that id crosses; the registry, the handle and
  `IsolateStreamCloseSignal` all hold a `Completer` and are unsendable.

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
