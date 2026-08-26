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

Both constructors forward six arguments (`key`, `defaultUserMessage`,
`parameters`, `stack`, `rootException`, `autoLog`). The kernel `TomException`
takes three more — `requestUuid`, `uuid` and `serverCallError` — which the
client constructors do not surface; those fields are settable, so assign them
after construction if you need them.

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
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
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

### TomClientUIException

A client exception whose `defaultUserMessage` is safe and intended for display
in the UI. The distinct type — not just the message — is the contract.

- **Extends:** `TomClientException`

#### Constructors

```dart
TomClientUIException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

Identical to `TomClientException`'s, one link further down the same
super-parameter chain.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
