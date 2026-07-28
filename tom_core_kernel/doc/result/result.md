# Result Module

The Result module defines the one envelope every Tom operation returns. It
exists to draw a single line — **transport failure is not the same thing as
application outcome** — and to make that line visible in the type system, so
neither side of a call has to guess which one it is looking at.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomResult](#tomresult)
  - [TomErrorResult](#tomerrorresult)
  - [TomFieldError](#tomfielderror)
  - [TomErrorSeverity](#tomerrorseverity)
- [The Wire Form](#the-wire-form)
- [Error Codes as the Join Key](#error-codes-as-the-join-key)
- [Usage Examples](#usage-examples)
  - [Returning a Validation Failure](#returning-a-validation-failure)
  - [Consuming a Result on the Client](#consuming-a-result-on-the-client)
  - [Deserializing a Typed Payload](#deserializing-a-typed-payload)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

The server contract makes four commitments, of which this module implements the
last two:

1. All operations are POST; the operation name carries the intent.
2. **Only 5xx responses are transport errors** — infrastructure failed.
3. **Every application-level outcome travels in a normal 2xx body** as one
   canonical envelope. A validation rejection, a "not found", a business-rule
   refusal: none of these are HTTP errors. They are *results*.
4. Error text is keyed by a stable machine code, so client copy and server logic
   share one source instead of duplicating message strings.

Point 3 is the one worth restating, because it is the one most often violated by
habit. Returning `404` for "no user with that id" collapses two different facts
— *the service could not be reached* and *the service answered, and the answer
was no* — into a single signal. A client then cannot tell a deployment problem
from a normal, expected outcome, and ends up parsing status codes to recover a
distinction the server already knew. `TomResult` keeps them apart: the transport
says the call arrived and was answered; the envelope says what the answer was.

A result is in exactly one of two arms, never both and never neither:

| Arm | Carries | Constructed with |
| --- | ------- | ---------------- |
| success | a `value` of type `T` — which may itself be `null` for an operation with no meaningful payload, such as a delete | `TomResult.success(…)` |
| error | a `TomErrorResult` with a machine code, an optional default message, per-field details, a retryable flag and a severity | `TomResult.failure(…)` |

The module is deliberately **general** rather than server-only: it lives in
`tom_core_kernel`, which both client and server depend on, so the producer and
the consumer read the same discriminator from the same type.

| Type | Role |
| ---- | ---- |
| `TomResult<T>` | The success-or-error envelope |
| `TomErrorResult` | The error arm: code, message, field details, retryable, severity |
| `TomFieldError` | One field-level detail inside a `TomErrorResult` |
| `TomErrorSeverity` | How serious the error is — a presentation hint |

All four implement `TomJsonSerializable` and depend on nothing else.

## Quick Start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Server: produce a result.
TomResult<UserView> loadUser(String id) {
  final user = repo.find(id);
  if (user == null) {
    return TomResult.failure(
      const TomErrorResult('USER_NOT_FOUND', message: 'No such user'),
    );
  }
  return TomResult.success(user.toView());
}

// Client: branch on the discriminator.
final result = await api.loadUser(id);
if (result.isSuccess) {
  render(result.value!);
} else {
  showError(result.error!.code); // copy resolved by code, not by message
}
```

## Core Components

### TomResult

`TomResult<T>` is the envelope. Its two named constructors are the only way to
build one, which is what makes "exactly one arm" a property of the type rather
than a convention:

```dart
const TomResult.success([T? value])
const TomResult.failure(TomErrorResult error)
```

`isSuccess` is defined as `error == null` and `isError` as its negation, so the
two can never disagree.

Note the optional parameter on `success`. An operation that genuinely returns
nothing — a delete, an acknowledgement — writes `TomResult.success()` rather
than inventing a placeholder payload. A `null` `value` on the success arm
therefore means "succeeded, nothing to hand back", and is not an error.

`toJson` emits the discriminator plus whichever arm is populated. The success
payload is encoded through a small internal step: a `TomJsonSerializable` is
expanded via its own `toJson`, and anything else is passed through untouched so
the outer encoder — the server pipeline, or `dart:convert`'s default
`toEncodable` — handles reflected `TomClass` values.

### TomErrorResult

The error arm. It is worth being precise about what it is *not*: it is not an
exception, and it is not a transport error. It is an ordinary value returned in
an ordinary 2xx body.

| Property | Type | Meaning |
| -------- | ---- | ------- |
| `code` | `String` | The machine-readable code. Stable across releases; this is what clients branch on. |
| `message` | `String?` | An optional default/developer message. **Not** the user-facing text. |
| `fieldErrors` | `List<TomFieldError>` | Per-field details when the failure is attributable to specific input. Empty for whole-operation errors. |
| `retryable` | `bool` | Whether retrying the *same* operation *unchanged* could reasonably produce a different outcome. |
| `severity` | `TomErrorSeverity` | A presentation hint. |

`retryable` deserves a moment's thought at each call site. It answers a narrow
question — would doing exactly this again plausibly work? — so transient lock
contention is retryable and a rejected password is not. It is not a general
"was this bad" flag, and a client that retries on it should be able to trust
that a retry is not simply going to fail identically.

### TomFieldError

A single field-level detail, used when a failure attaches to specific input
rather than to the operation as a whole:

| Property | Type | Meaning |
| -------- | ---- | ------- |
| `field` | `String` | The field or dotted field path, e.g. `email` or `address.postalCode` |
| `code` | `String` | The machine code for this field, keyed to copy exactly like the top-level code |
| `message` | `String?` | Optional default/developer message |

The dotted path matters for nested forms: a client rendering
`address.postalCode` can locate the offending input without the server needing
to know anything about the form's layout.

### TomErrorSeverity

A hint the client uses to choose a presentation — a toast, a blocking dialog, a
field annotation:

| Value | Meaning |
| ----- | ------- |
| `info` | Informational; the operation may have partially succeeded or produced a non-blocking notice |
| `warning` | The user should see it, but it does not block the outcome |
| `error` | A normal application error — the operation did not succeed |
| `fatal` | Severe or unexpected; the user generally cannot proceed |

The wire token is the lowercase enum name (`wireName`). `fromWire` parses it
back and **falls back to `error` for `null` or an unrecognized value**, so a
severity introduced by a newer server does not break an older client — it
degrades to the safe, ordinary reading rather than throwing.

## The Wire Form

The envelope carries an explicit `success` boolean:

```json
{ "success": true,  "value": { ... } }
{ "success": false, "error": { "code": "…", "severity": "error", … } }
```

The discriminator is explicit on purpose. Branching on *which key is present*
works until an operation legitimately succeeds with a `null` payload, at which
point "no `value` key" and "failed" become indistinguishable. A generated client
in any language can read one boolean instead.

`TomResult.fromJson` is written to survive a payload that is not quite right:

- a missing `success` key is read as success when there is no `error`;
- an `error` arm that is not a map yields the code `UNKNOWN_ERROR`;
- a missing `code` reads as the empty string rather than throwing.

The point is that a malformed response still produces a well-formed result. A
parser that throws here would turn a server's bad day into a client crash.

`fromJson` deliberately leaves the success `value` as the **raw decoded
payload** — a map, a list, or a primitive. Converting it to a typed `T` is a
call-site concern, and keeping it out of the envelope is what keeps this module
free of any reflection dependency, so it can be used unchanged in places where
reflection is not available.

## Error Codes as the Join Key

`TomErrorResult.code` is the single point where server logic and user-facing
copy meet. The server raises a code; the client resolves copy *from* that code.

This is why `message` is explicitly not the user-facing text. If user copy came
from the server's message field, then every locale, every wording change and
every product-copy review would have to travel through server code. Keying on
the code instead means the server owns *what happened* and the client owns *how
to say it*, and neither has to duplicate the other's job.

Two practical consequences:

- **Codes are API.** Changing `USER_NOT_FOUND` to `NO_SUCH_USER` breaks every
  client that keyed copy to the old value, as surely as renaming a field would.
- **`message` is for developers.** Put in it whatever helps whoever is reading a
  log or a debugger — it is not the string the user will see.

## Usage Examples

### Returning a Validation Failure

```dart
TomResult<void> register(RegistrationForm form) {
  final problems = <TomFieldError>[
    if (!form.email.contains('@'))
      const TomFieldError('email', 'EMAIL_MALFORMED'),
    if (form.password.length < 12)
      const TomFieldError('password', 'PASSWORD_TOO_SHORT'),
  ];

  if (problems.isNotEmpty) {
    return TomResult.failure(
      TomErrorResult(
        'REGISTRATION_INVALID',
        fieldErrors: problems,
        severity: TomErrorSeverity.warning,
      ),
    );
  }

  repo.create(form);
  return const TomResult.success(); // nothing meaningful to return
}
```

### Consuming a Result on the Client

```dart
void handle(TomResult<UserView> result) {
  if (result.isSuccess) {
    render(result.value!);
    return;
  }

  final error = result.error!;

  // Field errors annotate the form; everything else is a message.
  if (error.fieldErrors.isNotEmpty) {
    for (final fieldError in error.fieldErrors) {
      form.annotate(fieldError.field, copyFor(fieldError.code));
    }
    return;
  }

  switch (error.severity) {
    case TomErrorSeverity.info:
    case TomErrorSeverity.warning:
      showToast(copyFor(error.code));
    case TomErrorSeverity.error:
    case TomErrorSeverity.fatal:
      showDialog(copyFor(error.code), canRetry: error.retryable);
  }
}
```

### Deserializing a Typed Payload

`fromJson` hands back the raw payload, so the typed conversion happens at the
call site — where the type is actually known:

```dart
final envelope = TomResult<Map<String, Object?>>.fromJson(decodedBody);

if (envelope.isError) {
  return TomResult<UserView>.failure(envelope.error!);
}

return TomResult<UserView>.success(
  UserView.fromJson(envelope.value!),
);
```

## Best Practices

1. **Do not raise HTTP status codes for application outcomes.** "Not found",
   "not allowed by a business rule", "the form was wrong" are all 2xx responses
   carrying a failure result. Reserve 5xx for infrastructure that broke.
2. **Treat codes as a stable, published vocabulary.** Choose them as carefully
   as you would choose field names, and keep them in one place rather than
   spelling literals inline across handlers.
3. **Do not put user-facing text in `message`.** Copy resolves from `code`. A
   message that leaks to the UI is a message that will need translating, and
   translating it means shipping server code.
4. **Use `fieldErrors` when — and only when — the failure attaches to input.**
   A whole-operation refusal with a made-up field path is harder to render than
   one with no field errors at all.
5. **Set `retryable` deliberately.** Answer the narrow question: would the same
   call, unchanged, plausibly succeed? Leaving it at its `false` default is the
   right choice more often than not.
6. **Return `TomResult.success()` for empty outcomes** rather than inventing a
   placeholder payload or reaching for the error arm.

## Dependencies

This module depends on:

- **JSON Module**: `TomJsonSerializable`, the interface all four types
  implement.

It depends on nothing else — deliberately. Keeping the envelope free of a
reflection dependency is what allows it to be used on both sides of a call and
in environments where reflection is unavailable.
