# Little Things Module

The server-side base exception and the wire shape it is rendered into. This
module contributes two types — `TomServerException`, which every other
`tom_core_server` exception extends, and `TomLoginException`, the one subclass
declared here rather than beside the module that raises it, with a closed-set
`TomLoginFailure` reason (a kernel type) — plus `tomErrorEnvelope`, which turns
any error into the body a client receives, and `tomErrorResponse`, which answers
that body as the response — or, when the caller asks for one, the same fields as
an RFC 9457 problem document. The
request id the exception constructor recovers from the zone is the kernel's
`TomRequestId` (see [Request Correlation](#request-correlation)).

## Table of Contents

- [Overview](#overview)
- [TomServerException](#tomserverexception)
  - [What a raise site may throw](#what-a-raise-site-may-throw)
  - [The Whole Kernel Parameter List](#the-whole-kernel-parameter-list)
- [Isolate Attribution](#isolate-attribution)
- [Request Correlation](#request-correlation)
- [The clientThrow Flag](#the-clientthrow-flag)
  - [Read it through clientMessage](#read-it-through-clientmessage)
- [TomLoginException and Its Reason](#tomloginexception-and-its-reason)
  - [The five values, and the three that are missing](#the-five-values-and-the-three-that-are-missing)
  - [Consistency is enforced, not reviewed](#consistency-is-enforced-not-reviewed)
- [The Error Envelope](#the-error-envelope)
- [The Problem Document](#the-problem-document)
  - [Which format a response takes](#which-format-a-response-takes)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomServerException` | class | Base class for all server-raised exceptions; extends the kernel's `TomException` |
| `TomLoginException` | class | A failed login, raised by the authentication services; extends `TomServerException` and adds a `TomLoginFailure` reason |
| `tomErrorEnvelope` | function | Renders any error into the package's wire error body — the shape every error response uses |
| `tomErrorResponse` | function | The error response for an error and a status, in the format the request asks for — every framework error response is built here |
| `tomProblemDetails` | function | An error as an RFC 9457 problem document: the envelope plus `type`, `title`, `status` and `instance` |
| `tomWantsProblemJson` | function | Whether a request is answered with a problem document: the context key, or an `Accept` naming `application/problem+json` |
| `tomReasonPhrase` | function | The reason phrase of an HTTP status — a problem document's `title` |
| `tomProblemJsonMediaType` | const String | `application/problem+json` |
| `tomProblemJsonContextKey` | const String | `tom.problemJson` — the request context key that answers an endpoint's errors as problem+json |

The kernel already provides `TomException` (UUID tracking, parameters,
auto-logging, request UUID). `TomServerException` layers two server-specific
concerns on top: it records **which isolate** produced the error and it
**correlates** the error with the active request.

## TomServerException

```dart
class TomPaymentException extends TomServerException {
  TomPaymentException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.clientThrow,
  });
}

throw TomPaymentException(
  'payment.capture.declined',
  'The payment could not be processed',
  parameters: {'processor': processorName},
  clientThrow: false, // the processor's own reason is not the caller's business
);
```

Two things about that shape are the module's rules rather than its taste, and
both are checked.

**Name a subtype, not the base class.** The catch clause below reaches
`TomPaymentException` through its parent, so nothing is lost by declaring one —
and a caller that wants to handle a declined payment differently from a failed
query needs the type to say which it has. Throwing `TomServerException` itself
leaves it with the key string and nothing else. The package raises the base
class directly at exactly seven sites, all `.named(...)` constructors refusing an
unregistered data source, and the exemption is narrow on purpose: they fail at
construction, before any request is served, so no `catch` clause is running to
discriminate and a subtype would add nothing but a declaration.
`test/server_exception_family_test.dart` pins those seven by file and key, so an
eighth has to make the same argument rather than inherit it.

**The key reads `<area>.<operation>.<condition>`**, dotted-lowercase — the shape
`TomException`'s own dartdoc fixes. The first segment names the module, so keys
raised by unrelated code cannot collide, and the middle segment is what lets two
failures of the same subsystem be told apart in a log.

Because every server exception subtypes `TomServerException`, a single catch
clause reaches all of them:

```dart
try {
  await handleRequest();
} on TomServerException catch (e) {
  log.error('${e.isolateName}: ${e.key} (req ${e.requestUuid})');
  if (e.clientThrow) respondWith(e.defaultUserMessage);
  else respondWith('Internal error');
}
```

That "every" is enforced rather than merely asserted.
`test/server_exception_family_test.dart` reads every class declaration under
`lib/src/tomserver/`, walks each `extends` chain, and fails on any class that
reaches the kernel's `TomException` without passing through
`TomServerException`. It is a source scan rather than a runtime check on
purpose: a runtime check can only examine the types someone remembered to list,
which is precisely the property that fails. A new exception class is therefore
covered the moment it is written, and a class that leaves the family names its
own file in the failure.

Leaving the family is worth catching because three things are built on the
claim: the endpoints pipeline classifies a failure by catching
`TomServerException`, so a type outside it reaches the client unclassified;
`tomErrorEnvelope` writes `clientThrow` only for a member, so a non-member
cannot say whether its message may be shown; and the isolate and request
attribution below is added by the base constructor, so a non-member arrives
naming neither the worker that raised it nor the request that caused it.

### What a raise site may throw

The family rule says what a *type* must be. A raise site has the same
obligation for the same three reasons: a `FormatException` thrown from inside a
request is as invisible to `on TomServerException` as a class declared outside
the family. So a server raise site throws a `TomServerException` subtype —
directly, or through a helper whose declared return type is one — with exactly
three exceptions, each a reason a keyed server exception would be the *wrong*
answer:

| Category | When | Examples |
| -------- | ---- | -------- |
| `programmer error` | The caller's code is wrong, and no running system reaches the site: an argument or a lifecycle state checked at a public entry point. A key would tell a caller to branch on a mistake that is fixed by editing code. `ArgumentError` / `StateError`. | a framework table descriptor with no columns; a cache constructed with a negative size; a digest fed after close |
| `parse contract` | A public parse function keeping Dart's own convention — `int.parse`, `DateTime.parse` — and throwing `FormatException`. The obligation moves to the caller: code that parses *data from outside the process* with one converts the `FormatException` into a keyed exception. | `parseSqlDate`, `parseSqlTimeOfDay`, `TomS3BlobStore.parseHttpDate` |
| `kernel protocol` | A kernel type the kernel dispatches on, raised to speak that protocol. | `TomPermanentJobFailure`, the scheduler's "do not retry" |

The parse-contract row is the one with teeth. Every SQL driver reads stored
`DATE`, `TIME` and `DATETIME` text through those parse functions, and a stored
row is data from outside, so the driver converts: an unreadable value raises
`error.result_processing.not_a_date`, `.not_a_time` or `.not_an_instant`, naming
the column and the value, the same way the numeric readers refuse theirs. Before
it did, a `DATE` column holding a timestamp crossed the endpoints pipeline as a
bare `FormatException`, with no key and no column.

An exempt site says so where it stands, on the line above the `throw`:

```dart
// throws-outside-family: programmer error — the deadline is an install-time
// argument.
throw ArgumentError.value(timeout, 'timeout', 'the health deadline must be positive');
```

`test/server_exception_family_test.dart` scans every `throw` of a call under
`lib/src/tomserver/`, resolves a helper (`_asStorageException`,
`TomBlobStore.notFound`) to the return type its declaration states, and fails on
a raise outside the family with no marker, on a marker naming no category, and
on a marker no longer standing above such a raise. `throw e` of a value already
held is propagation, not a raise site, and is not judged. The reasons live at
the marked sites rather than in a list in the test, so an exemption is
read where it is used and cannot outlive the code it excuses.

### The Whole Kernel Parameter List

`TomServerException`'s constructor forwards **every** parameter the kernel's
`TomException` accepts. That matters more than it sounds: every exception type
in the package chains through this one constructor, so a parameter missing here
is missing from every one of them — and three were.

| Parameter | What it makes possible |
| --------- | ---------------------- |
| `uuid` | An exception *reconstructed* from a wire representation keeps the identity its log line was written under. Generated when omitted, so nothing changes for a failure raised here. |
| `requestUuid` | Correlation for an exception built outside the request zone — a worker isolate handed the id as a plain string, a deserialiser holding it as a field. Until it was forwarded, the zone was the only route. |
| `serverCallError` | The kernel's slot for "this came from an HTTP call", in the package most likely to make outbound ones. `TomServerSelfLoginException` fills it, so a refused auth server reports the status and body rather than a sentence. |

`serverCallError` describes the server's own outbound call and is deliberately
**not** in the error envelope: it is nobody else's business, and the envelope
carries the fields a client branches on.

## Isolate Attribution

Server work is spread across an isolate pool, so the bare error message alone
does not tell you which worker failed. `TomServerException` captures
`Isolate.current.debugName` into `isolateName` at construction time (falling
back to `"unnamed isolate"` when the isolate has no debug name), and appends it
to `toString()`. This makes a logged error self-identifying without the call
site having to record the isolate explicitly.

**The field answers "where did this fail", not "where did this surface".** It
names the isolate of origin and is never updated afterwards: an exception raised
inside a pool worker and re-thrown in the main isolate still names the worker.
That is the reading worth having — the workers are identical, so *which one* is
precisely what the message cannot say, while "which isolate is reading this"
has an answer that is never useful. Resolving the name lazily, at `toString()`
time, would give exactly that useless answer and destroy the attribution the
field exists for.

Nothing records a *hop*. A trail of the isolates an exception passed through
would need every rethrow site to cooperate, and rethrow sites are where the
least work is done; a reader who needs where-it-surfaced records it at the
rethrow.

**The name travels however the exception does.** Within one isolate group —
which is what `Isolate.spawn`, `Isolate.run` and the server's own isolate
pooling create — an exception handed over a `SendPort` arrives with the field
intact, so a worker's failure is still attributed to the worker after the
hand-off. That is measured, not assumed: `test/little_things_test.dart` spawns a
named worker, sends one back, and reads the name on the other side.

## Request Correlation

The request id is the kernel's `TomRequestId` (context module), carried in the
zone for the lifetime of one unit of work: `tomRequestContextMiddleware` sets it
for a request — the caller's trace id, or a trusted proxy's request-id header
(see [server.md](server.md#request-ids)) — and `tomDefaultAuthenticationMiddleware`
keeps it in the request's zone values; a scheduled job run gets one from
`TomJobRunCommand` and a socket message read through
`TomWebSocketConnection.serve` one of its own. When a `TomServerException` is
constructed inside that zone, its constructor reads the id via
`getFromCurrentZone<TomRequestId>()` and copies its `value` into the inherited
`requestUuid` field. The error is therefore linked to the work that triggered it
without any code threading the id through the call stack. Outside such a zone
(e.g. during startup) `requestUuid` is simply left unset.

**An explicitly supplied `requestUuid` wins over the ambient one**, and the zone
lookup runs only when the caller said nothing. A caller that names a request is
relaying or reconstructing a failure from elsewhere — a worker isolate handed
the id as a plain string, a deserialiser holding it as a field — and knows
something the surrounding zone does not. Overwriting it would re-label another
request's failure with this one's id, which is worse than no correlation at all.

`toString()` renders the correlation as a trailing `request: <request-id>` segment,
and omits that segment altogether when the exception was raised outside a
request:

```text
<uuid>-<request-id>, TomServerException: K, m, ... main client-throw: true request: <request-id>
<uuid>-null, TomServerException: K, m, ... main client-throw: true
```

The label matters more than it looks. The base `TomException` already carries
the id, but only inside the composite leading token
`<exception-uuid>-<request-id>` — and because a v4 UUID contains hyphens
itself, as a request id may (a socket message's is `<trace id>-<span id>`), that
token cannot be split back into its two ids by eye or by a simple pattern. The labelled copy is what makes the correlation greppable.

## The clientThrow Flag

`clientThrow` (default `true`) marks whether the exception is safe to surface to
the caller. The endpoints pipeline may relay the user message of a
`clientThrow: true` exception, while a `clientThrow: false` exception should be
masked behind a generic error response — use it for internal failures whose
detail must not leak.

`TomLoginException` does not offer the choice at construction: its constructor
forwards the rest of the payload and adds `reason`, but not `clientThrow`, so
every
`TomLoginException` is client-visible. Omitting the parameter is the common
shape — fifteen of the package's twenty-eight subtypes inherit the `true`
default the same way — but the neighbourhood makes it a decision rather than an
omission. Every other exception the authentication subsystem raises is hidden:
`Tom2FAException`, `TomServerSelfLoginException`, `TomSigningKeyException` and
`TomJwtKeyException` hard-wire `clientThrow: false`, and `TomOAuthException`
re-defaults it to `false`. The
login failure is the exception whose message is written for the person who
mistyped a password, so it is the one that may reach them.

### Read it through `clientMessage`

`clientThrow` binds the *value*, not the handler. A response built from
`defaultUserMessage` directly shows the message of an exception marked `false`,
and nothing complains — a leak by **omission** rather than by decision, which is
the kind that survives review.

`TomServerException.clientMessage(maskedFallback)` is the sanctioned read:

```dart
return _error(403, error.key, error.clientMessage('Request refused.'));
```

It returns `defaultUserMessage` when `clientThrow` is true and `maskedFallback`
when it is not. The fallback is required and has no default, because the
framework does not own the text a deployment shows in place of a hidden one:
text belongs to the rendering tier, reached through a resource key, and a
generic English sentence baked into the framework would be putting words in a
client's mouth.

**Only the message is masked.** `key` stays on the wire for every exception —
`tomErrorEnvelope` reports it unconditionally — because it is a stable code a
client resolves against its own resources, not free text an author wrote for a
person. A masked response therefore still has something to render.

The type system cannot enforce this, and the module does not pretend otherwise:
`defaultUserMessage` is a public field on the kernel's `TomException`, used by
`tom_core_kernel` and `tom_core_flutter` alike, and hiding it would be a kernel
change. What is enforced instead is *visibility*.
`test/server_exception_family_test.dart` scans `lib/src/tomserver/` for direct
reads of `defaultUserMessage` and fails on one that is not pinned with a reason.
Two are pinned: `clientMessage`'s own implementation, and a self-login failure
written to the operator's log. A third has to be argued for rather than merely
written.

**The default error handler is safe by construction**, because
`tomErrorEnvelope` carries no message at all — see
[The Error Envelope](#the-error-envelope). A replacement `errorHandler` that
adds one takes on the obligation the envelope avoids.

Both `clientThrow` and `isolateName` are `final`, so what the constructor fixes
is the value and not merely a default. That is deliberate: an exception is a
value describing something that has already happened, and both fields record a
fact about the moment it was raised — which worker produced it, and whether the
party that wrote the message intended it for a client. A catch site that decides
a particular failure must not leave the server masks it in the response it
builds, rather than rewriting the error's account of itself. On this path the
question rarely arises anyway, because `TomAuthenticationServer` catches the
exception and turns its `key` into a failed `TomAuthenticationResult` rather
than letting it reach the pipeline that reads the flag.

## TomLoginException and Its Reason

A login failure carries two audiences with opposite needs. The **server** wants
every distinction it can get, for its logs and its lockout logic; the **client**
must not be told more than it has earned. `TomLoginException` serves both by
carrying two things:

| Field | Audience | Shape |
| ----- | -------- | ----- |
| `key` | the server, and a message catalogue | free-form, as specific as the throw site likes (`login.error.2fa.enrolment-code-invalid`) |
| `reason` | the client | a closed set of five values, switchable without matching strings |

`reason` is a **required** named argument, and required rather than defaulted on
purpose: a default is a classification nobody made, so every new throw site
would silently join it and the value a client branches on would quietly stop
meaning anything. The compiler asking the question at each site is the whole
mechanism.

```dart
throw TomLoginException(
  'login.error.2fa.attempts-exhausted',
  'No two-factor attempts remain',
  reason: TomLoginFailure.rateLimited,
);
```

### The five values, and the three that are missing

| Value | The caller's remedy |
| ----- | ------------------- |
| `accountProblem` | the account cannot authenticate — no such account, wrong credentials, or locked |
| `secondFactorRequired` | a second factor is needed and has not been supplied or enrolled |
| `secondFactorInvalid` | the factor supplied is not usable: wrong code, expired, already answered |
| `rateLimited` | the attempts for this challenge or enrolment are spent, so start the login over — or, for `login.error.2fa.send-limit`, a code was sent to this address too recently, so wait the `retryAfterSeconds` its parameters carry |
| `providerError` | the deployment's side failed — a provider refused, a code could not be delivered, a mechanism has no adaptor |

**There is no `badCredentials`, no `unknownUser` and no `accountLocked`.** All
three are `accountProblem`, because telling a caller which of them it hit is a
**user-enumeration oracle**: "unknown user" and "wrong password" as separate
answers let anyone confirm which accounts exist, and "locked" confirms it a
second way. The server keeps the distinction — it is in the `key` — and the
account's owner learns the detail through a channel that already knows who they
are.

`rateLimited` is separated from `secondFactorInvalid` for the opposite reason:
the remedies differ. Trying the same factor again can succeed after an invalid
code and cannot after the attempts are spent, so a client that cannot tell them
apart shows the wrong instruction in one of the two cases.

**The one wait the framework imposes travels as a parameter.** A refusal under
the send pace for delivered codes carries `retryAfterSeconds` in its
`parameters`; every other `rateLimited` refusal means a spent challenge, whose
remedy is a new login rather than a wait. A field on `TomLoginException` would
be empty at every other site, so the number rides with the one key that has
it.

### Consistency is enforced, not reviewed

Thirty-nine throw sites across six files classify themselves.
`test/server_exception_family_test.dart` scans them from source and holds three
rules: every `TomLoginFailure` value has at least one producer (a value nothing
raises is a client branch that is dead code), a given key maps to one reason
wherever it is raised (one condition, one remedy), and every key belongs to the
`login.error.` vocabulary.

## The Error Envelope

`tomErrorEnvelope(error)` is the single definition of what a Tom error looks
like on the wire. Every error response body the package produces comes from
here — through `tomErrorResponse`, which sends it as is or as the fields of a
problem document (see [The Problem Document](#the-problem-document)):
`TomServer.errorHandler` sends it as the `500` body, and
`TomUserPreferencesErrorHandler` sends the same body under a `404` or a `400`,
so a client decodes one shape rather than one shape per endpoint.

```dart
tomErrorEnvelope(TomServerException('order.not-found', 'No such order.'));
// {
//   errorType:   'TomServerException',
//   errorKey:    'order.not-found',
//   uuid:        '…',
//   autoLog:     false,
//   requestUuid: '…',   // or null outside a request
//   clientThrow: true,
// }
```

A `TomLoginException` adds one more field:

```dart
tomErrorEnvelope(
  TomLoginException(
    'login.error.2fa.attempts-exhausted',
    'No two-factor attempts remain',
    reason: TomLoginFailure.rateLimited,
  ),
);
// {  …, clientThrow: true, loginFailure: 'rateLimited' }
```

The body is built in layers, each reporting only what the error actually
carries. `errorType` is unconditional — every failure has a runtime type, and a
client that recognises nothing else can still log something specific.
`errorKey`, `uuid`, `autoLog` and `requestUuid` are added for a `TomException`,
which is what a client branches on. `clientThrow` is added for a
`TomServerException`, and `loginFailure` for a `TomLoginException` — the field
that makes a login failure actionable without string-matching a key no type
enumerates.

A field is **absent rather than null** when the error does not carry it, so its
presence means something. A body with no `errorKey` came from something that is
not a Tom error at all; a body with no `clientThrow` came from outside this
package — the kernel raises plain `TomException`s, so a validation refusal
relayed from there is distinguishable from a failure raised on the server side;
a body with no `loginFailure` is not a login failure.
Padding the shape out with defaults would make every body look like a server
error and cost a client that distinction.

The function is declared here because `TomServerException` decides the one
conditional field, and this is the module every other one already depends on —
so both error handlers reach the builder without either reaching the other.

## The Problem Document

`tomErrorResponse(error, status: ..., request: ...)` builds every framework
error response: `TomServer.errorHandler`, `TomStatusMappingErrorHandler` and so
`TomDefaultErrorHandler` and `TomUserPreferencesErrorHandler`,
`TomRateLimits.tooManyRequests`, and the OpenAPI document endpoint's `404`. It
answers with the envelope, or with `tomProblemDetails(error, status)` — the
same fields as an RFC 9457 problem document — and always adds
`x-tom-error: true`.

```dart
tomProblemDetails(
  TomServerException('order.not-found', 'No such order.'),
  404,
);
// {
//   type:        'urn:tom:error:order.not-found',
//   title:       'Not Found',
//   status:      404,
//   instance:    'urn:tom:request:…',   // only inside a request
//   errorType:   'TomServerException',
//   errorKey:    'order.not-found',
//   uuid:        '…',
//   autoLog:     false,
//   requestUuid: '…',
//   clientThrow: true,
// }
```

RFC 9457's members come first:

- **`type`** — `urn:tom:error:<errorKey>` for an error with a key, so the key is
  the problem type a client branches on; `about:blank` for an error without one.
- **`title`** — `tomReasonPhrase(status)`, the HTTP reason phrase (`Error` for a
  status with none registered).
- **`status`** — the status the response is answered with.
- **`instance`** — `urn:tom:request:<requestUuid>` when the error names the
  request it was raised in, absent otherwise.

Then every envelope field, as an extension member, so a client reads
`errorKey`, `clientThrow` or `loginFailure` the same way in both formats. There
is no `detail`: the envelope carries no message, and the problem document does
not either, so switching format reveals nothing the other hides.

### Which format a response takes

| Request | Body | `Content-Type` |
| ------- | ---- | -------------- |
| `Accept` lists `application/problem+json` (with a `q` above 0) | `tomProblemDetails` | `application/problem+json` |
| served by an endpoint of a service declared with `problemJson: true` | `tomProblemDetails` | `application/problem+json` |
| anything else | `tomErrorEnvelope` | `application/json` |

`tomWantsProblemJson(request)` decides it. A wildcard (`*/*`,
`application/*`) does not select problem+json: a client that has not named the
format is one written against the envelope. A `null` request — a response built
outside a request — is the envelope. An endpoint of a `@TomService(problemJson:
true)` service (or a `TomApiImplementation` with `problemJson: true`) carries
`tomProblemJsonContextKey: true` on the request every error handler of it
receives, so a deployment's own handler that calls `tomErrorResponse` follows
the service's choice too — see
[endpoints.md](endpoints.md#error-formats-and-problemjson).

## Not Yet Implemented

- **The error envelope carries no message.** `tomErrorEnvelope` reports
  `errorType`, `errorKey`, `uuid`, `autoLog`, `requestUuid` and `clientThrow`,
  and never the exception's `defaultUserMessage` — see
  [The Error Envelope](#the-error-envelope). A problem document has no `detail`
  for the same reason. A client shows text by resolving
  `errorKey` against its own resources, which is what makes the message
  translatable; a client that does not recognise the key has the type and the
  id, and nothing to display.
  <!-- pinned: test/documented_limitations_test.dart › the error envelope carries no message -->
- **Work the framework does not start gets no id.** A request, a scheduled job
  run and a socket message read through `TomWebSocketConnection.serve` each run
  under a request id; anything else — a start-up task, a script, a socket
  handler reading `messages` itself past the upgrade request — raises exceptions
  with the id of whatever zone it runs in, and a null `requestUuid` outside
  every one. Such work establishes its own with `TomRequestId.runRoot`.
  <!-- pinned: test/little_things_test.dart › requestUuid is unset when constructed outside a request zone -->

## Verification

`test/little_things_test.dart` covers all three types the module contributes:
`TomServerException`'s isolate
attribution — including that the name survives an isolate hop and still names
the origin — its `clientThrow` flag and the `clientMessage` read that honours
it, the three kernel parameters it forwards and the explicit-wins-over-ambient
rule for `requestUuid`, the request correlation it picks up from the kernel's
`TomRequestId` in the zone, the
one subclass declared beside it (`TomLoginException`) with its `TomLoginFailure`
reason and the values that set deliberately omits, and `tomErrorEnvelope` — the
wire shape every error response uses, including the `loginFailure` field a login
failure adds and everything else omits.

`test/api_versioning_test.dart` covers `error_response.dart` through a served
endpoint: the envelope for a request that does not ask (no `Accept`,
`application/json`, and both wildcards), a problem document for one that does
(case and quality parameters included) with its members and the envelope fields
it carries and no `detail`, the envelope again for `q=0`, a problem document
whatever the request asks for from a `problemJson` service, and — directly —
`tomProblemDetails` for an error without a key, an unregistered status's `Error`
title, and `tomErrorResponse` keeping the headers it is given.

`test/server_exception_family_test.dart` holds the classification itself. Its
rules read every `throw TomLoginException(` under `lib/src/tomserver/` from
source, which is the only way to cover a site nobody thought to reach: every
`TomLoginFailure` value must have a producer, a key must map to one reason
wherever it is raised, and every key must belong to the `login.error.`
vocabulary.

```bash
dart run example/little_things/little_things_example.dart
```

`example/little_things/little_things_example.dart` walks the same ground in six
steps, ending on the one that is a claim about *the type system* rather than
about a value: a `catch` clause written for `TomServerException` catches a
`TomLoginException`, which is how the pipeline reaches every server exception
with one `on` clause. Every step checks its own result through the package's
throwing `check` helper, so a green run is a verification rather than a
transcript; `test/examples_test.dart` runs it, which is what keeps that true.

## Core Components

- **`TomServerException`** — the base server exception. Adds `isolateName`
  (originating worker), `clientThrow` (client-safe flag) with the
  `clientMessage` read that honours it, and zone-based `requestUuid` population
  to the kernel's `TomException`.
- **`TomLoginException`** — a login that cannot succeed: unknown client or user,
  invalid credentials, no enrolled second factor, an expired challenge. Raised
  by `TomAuthenticationService`, `Tom2FAService` and their helpers, and caught
  by `TomAuthenticationServer`, which turns its `key` and its reason into a
  failed `TomAuthenticationResult`. It adds a required `TomLoginFailure` reason over
  the base — see
  [TomLoginException and Its Reason](#tomloginexception-and-its-reason). See
  `doc/authentication.md` for the login flow it belongs to.
- **`TomLoginFailure`** — the closed set a client switches on, deliberately
  coarser than the server's own knowledge. Declared in `tom_core_kernel`,
  beside `TomAuthenticationResult`, which carries the same value as
  `loginFailureReason` when the server returns a failed result instead of
  throwing.
- **`tomErrorEnvelope`** — renders any error into the wire error body, reporting
  `errorType` always, the `TomException` fields for a Tom error, and
  `clientThrow` for a server one. Used by `TomServer.errorHandler` and
  `TomUserPreferencesErrorHandler`; a handler that translates a status chooses
  the status and not the shape.
- **`tomErrorResponse`** — the error response itself: the envelope declared
  `application/json`, or `tomProblemDetails` declared `application/problem+json`
  when `tomWantsProblemJson` says the request asks for it, always under
  `x-tom-error: true`. `tomReasonPhrase` supplies the document's `title`;
  `tomProblemJsonMediaType` and `tomProblemJsonContextKey` name the media type
  and the context key the rule reads.

`TomLoginException` is declared here, next to the base class, rather than beside
the authentication server that consumes it, so that the 2FA subsystem can throw
it without importing that server. The cost of that placement is this guide: a
reader looking up the module finds a type whose whole meaning lives in another
one.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:convert` | dart | `error_response.dart` | `jsonEncode`, the response body |
| `dart:isolate` | dart | `server_exception.dart` | `Isolate.current` for the worker's debug name |
| `shelf` | package | `error_response.dart` | `Request` and `Response` |
| `tom_core_kernel` | package | `server_exception.dart`, `error_response.dart` | `TomException` (the base class), `getFromCurrentZone`, and `TomRequestId`, the request id the constructor correlates with; `TomHeader` and `TomMimeType` for the response's `Content-Type` |

The module imports no other module of this package, which is the point: it sits
at the bottom of the dependency graph and everything else may depend on it.
