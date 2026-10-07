# Little Things Module

Small client-side helpers for `tom_core_flutter`. Currently this module
provides two **exception types** layered on the kernel's exception model.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Why a distinct type](#why-a-distinct-type)
- [Naming the request a failure belongs to](#naming-the-request-a-failure-belongs-to)
- [Resolving the message for display](#resolving-the-message-for-display)
- [Core Components](#core-components)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomClientException` | class | Client-side subtype of the kernel `TomException`. |
| `TomClientUIException` | class | A `TomClientException` whose message is safe to show in the UI. |

Both are thin subtypes — they carry the kernel
[`TomException`](../../tom_core_kernel/doc/little_things/little_things.md)'s
payload unchanged and add only a **semantic type** that client code can branch
on. "Unchanged" is literal: every one of the kernel's arguments is forwarded,
including `uuid`, `requestUuid` and `serverCallError` — see
[Naming the request a failure belongs to](#naming-the-request-a-failure-belongs-to).

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

// Raise a user-facing error:
throw TomClientUIException(
  'login.failed',
  'Could not sign you in. Please try again.',
);

// Wrap an internal failure, surfacing only presentable ones:
try {
  await initialize();
} catch (e) {
  if (e is TomClientUIException) rethrow; // already presentable
  throw TomClientUIException(
    'app.initialization.failed',
    'The application could not start.',
    rootException: e,
  );
}
```

## Why a distinct type

The value of these classes is the **type**, not the message. UI layers catch a
generic `TomException`, then check `e is TomClientUIException` to decide whether
the error can be displayed verbatim or must be wrapped/sanitized first. Throwing
a plain `TomException` would force callers to inspect `key` strings; the subtype
makes the "is this safe to show?" decision a compile-checked `is` test.

## Naming the request a failure belongs to

Three of the kernel's arguments say *which* failure this is rather than what it
was, and both client types forward all three:

| Argument | What it answers | Why a client needs it |
| -------- | --------------- | --------------------- |
| `uuid` | which failure | A failure **reconstructed** from a server's error envelope has to keep the identity the far side logged it under. A generated one can never be matched back to that log line. |
| `requestUuid` | which request it belongs to | The client is the side that *issues* requests, so it is the side holding the correlation id. |
| `serverCallError` | which HTTP call it came from | A client is where outbound calls originate; this is the kernel's typed record of one. |

They are constructor arguments rather than fields assigned afterwards. `uuid`
and `requestUuid` are writable on a kernel exception, so that much was always
*reachable* — but a report edited between the throw and the catch describes a
failure the code in between decided on, and everything these three carry is
known where the exception is raised. `serverCallError` is `final`: for it the
constructor is the only route there has ever been.

`TomUserPreferencesClientException` is the first to fill them, and shows the
shape. Every rejection carries the whole answer as a `TomServerCallError`,
because a caller reaching for it is asking "what did the call do" and "the
gateway answered 502 with HTML" is an answer. When the server replied with the
framework's error envelope — announced by the `x-tom-error` header —
`TomServerCallError` reads the `errorKey`, `uuid` and `requestUuid` out of it,
and the client copies that `requestUuid` onto the exception. Both sides of one
failed call then name the same request, which is the only way the two logs can
be read together.

What the client does **not** do is borrow the server's `uuid`. The exception was
raised here; it is not the server's exception rebuilt. Nor does it read an id out
of a body that is not an envelope: inventing a correlation is worse than having
none, because a wrong one is believed.

## Resolving the message for display

`key` is what a UI resolves against the text resources; `defaultUserMessage` is
the fallback for when no resource exists. **Neither exception type performs that
lookup.** It belongs to the layer that displays the error, and it is four lines:

```dart
String messageFor(TomException failure) =>
    TomTextResourceProvider.getAppResources().getTextOrNull(failure.key) ??
    failure.defaultUserMessage;
```

**`getTextOrNull`, never `getText`.** The latter echoes the key when the bundle
has no entry, so a helper written with it puts `login.failed` in front of a user
and discards the fallback the message exists to be. The two calls differ by four
characters and by everything.

### Why the exception does not do it

An exception is raised in places a resource tree may not exist yet — early
start-up before resources load, a worker isolate, a unit test — and
`getAppResources()` does not degrade quietly there: it **throws**
`resources.text_provider.not_installed`. A type that resolved on construction
would carry that failure into exactly the situations where reporting a failure
matters most, and it would make every `throw TomClientUIException(...)` depend on
a bootstrap step that has nothing to do with the failure being reported.

The module's one design decision is that the value of these classes is the
**type** and that they add nothing else; a resource-layer getter would be the
first thing they added, and it would be the wrong one. The display boundary is
the single place that already knows a resource tree is installed, which is what
makes it the right home.

This is a **contract, not a limitation**. Both branches of the lookup and the
`getText` trap are executed and asserted by
`example/little_things/little_things_example.dart`, and
`test/little_things_test.dart`'s group `resolving the message for display` pins
the other half: with a resource entry present under the exception's own key,
`defaultUserMessage` still answers what the throw site wrote.

## Core Components

### `TomClientException`

A client-originated error. Use it for failures that should be handled in code
but are **not** necessarily safe to present to a user.

Its constructor is the one every client-side exception type chains through, so
an argument missing from it is missing from all of them. It forwards the kernel's
whole list: `key`, `defaultUserMessage`, `uuid`, `requestUuid`, `parameters`,
`stack`, `rootException`, `autoLog`, `serverCallError`.

### `TomClientUIException`

A client error intended for display. Throw it when `defaultUserMessage` is a
finished, user-appropriate message. The common pattern is
`if (e is TomClientUIException) rethrow;` to let presentable errors bubble up.

## Limitations

- **The types add no behaviour.** There is no severity, no retryability, no
  category and no message formatting — `key` and `parameters` are the whole
  structure a handler gets, and the rest is what the kernel `TomException`
  already carried. That is the design (the value is the *type*), but it means a
  consumer wanting richer error classification builds it above these, not by
  subclassing further.
- **Clause order is load-bearing, and getting it wrong fails silently.**
  `TomClientUIException` is a subtype, so a handler with only
  `on TomClientException` catches it too and its presentable message never
  reaches the banner. Nothing warns; the error is merely logged instead of
  shown. The subtype clause must come first — `example/little_things/little_things_example.dart`
  executes both orders.
- **The message is not resolved here.** `defaultUserMessage` is a literal
  string; resolving `key` against the text resources is the display boundary's
  job, and `getAppResources()` **throws** where no bundle is installed. See
  [Resolving the message for display](#resolving-the-message-for-display) for
  the shape and the reasoning.
- **`autoLog` writes at construction, not at throw.** An exception built for a
  test, or built on a branch that then decided not to throw it, is logged all
  the same. The flag is tied to *building* the object, which is also what makes
  it observable at all — there is no hook at the throw.
- **Most of the payload stays writable after construction.** `key`,
  `defaultUserMessage`, `parameters`, `uuid`, `requestUuid`, `stack` and
  `rootException` are public mutable fields on the kernel base, and
  `parameters` is held **by reference** rather than copied — so a caller's map
  can be edited through the exception and vice versa. The constructor is where
  a complete report is assembled; nothing enforces that it stays the report
  that was assembled. Only `autoLog` and `serverCallError` are `final`.
- **A wrap does not share its cause's identity.** `rootException` is the only
  link between a wrapped failure and the one it came from: the wrap gets its own
  `uuid`, and does not inherit the cause's `requestUuid`. Two log lines about
  one incident therefore carry two ids, and joining them means following the
  reference rather than matching on an id.
- **`serverCallError` has one producer in this package.**
  `TomUserPreferencesClient` fills it for every rejection it raises; no other
  client code does. A handler must treat it as present-or-absent rather than
  expecting every HTTP-shaped failure to carry one.

Each of these is executed by `test/little_things_test.dart` — the behavioural
ones in the group `the limitations the module document states`, the clause order
in `discriminating with catch clauses`, and the message resolution in
`resolving the message for display`.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `tom_core_kernel` | package | every file | the base `TomException` (logging, UUID, server-error tracking) that both types extend |
