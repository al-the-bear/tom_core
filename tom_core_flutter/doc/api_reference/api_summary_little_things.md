# Tom Core Flutter API Reference: Little Things Module

Client-side exception types that let Flutter code distinguish failures raised in
the client from those surfaced by lower layers.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomClientException](#tomclientexception)
  - [TomClientUIException](#tomclientuiexception)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomclient/little_things/client_exceptions.dart`.

These are thin semantic subtypes of the kernel `TomException`. Neither declares
a field or a method of its own — each adds only a constructor that forwards to
its superclass — so the whole readable surface is inherited. What they add is
the *type*, which lets client code branch — e.g.
`if (e is TomClientUIException)` — to decide whether an error is safe to show in
the UI.

Both constructors forward the kernel's **whole** parameter list, including the
three that identify a failure rather than describe it — `uuid`, `requestUuid`
and `serverCallError`. Every client-side exception type chains through
`TomClientException`, so an argument missing here is missing from all of them,
and each of the three has a case the client cannot otherwise express: a failure
*reconstructed* from a server's error envelope must keep the identity the far
side logged it under; the client is the side that issues requests, so it is the
side that holds the correlation id; and a client is where HTTP calls originate,
which is what `serverCallError` records. The fields are settable too, but a
report edited between the throw and the catch describes a failure the code in
between decided on.

## Class Hierarchy

```
TomBaseException  (tom_basics)
    └── TomException  (kernel)
            └── TomClientException
                    └── TomClientUIException
```

Two levels above the client classes, not one: `key`, `defaultUserMessage`,
`parameters`, `stack`, `rootException`, `uuid`, `requestUuid` and `timeStamp`
are declared on `TomBaseException`, while `autoLog`, `serverCallError` and the
`TomLoggable` implementation are added by `TomException`.

## Classes

### TomClientException

An exception originating on the client side of a Tom application.

- **Extends:** `TomException`

#### Constructors

```dart
TomClientException(
  String key,
  String defaultUserMessage, {
  String? uuid,
  String? requestUuid,
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
  TomServerCallError? serverCallError,
})
```

See `TomException` (kernel) for the meaning of each argument. The parameter
types above are the *kernel constructor's*, reached through Dart
super-parameters — which resolve against the immediate superclass, not against
the field's original declaration. That matters for `stack`: the field on
`TomBaseException` is `Object?`, but `TomException`'s constructor narrows it to
`StackTrace?`, so that is what a caller may pass here. `autoLog` is
non-nullable and defaults to `false`; the default is inherited too, so omitting
it is not the same as passing `null` — passing `null` does not compile.
`serverCallError` is the kernel's typed record of an HTTP answer;
`TomUserPreferencesClientException` fills it for every rejection, and copies the
server's `requestUuid` out of it onto the exception so both sides of one failed
call carry the same id.

### TomClientUIException

A client exception whose `defaultUserMessage` is safe and intended for display
in the UI. The distinct type — not just the message — is the contract.

- **Extends:** `TomClientException`

#### Constructors

```dart
TomClientUIException(
  String key,
  String defaultUserMessage, {
  String? uuid,
  String? requestUuid,
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
  TomServerCallError? serverCallError,
})
```

Identical to `TomClientException`'s, one link further down the same
super-parameter chain.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
