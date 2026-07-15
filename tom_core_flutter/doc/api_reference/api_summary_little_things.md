# Tom Core Flutter API Reference: Little Things Module

Client-side exception types that let Flutter code distinguish failures raised in
the client from those surfaced by lower layers.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomClientException](#tomclientexception)
  - [TomClientUIException](#tomclientuiexception)

## Overview

Source: `lib/src/tomclient/little_things/client_exceptions.dart`.

These are thin semantic subtypes of the kernel `TomException`. They carry the
same payload (`key`, `defaultUserMessage`, `parameters`, `stack`,
`rootException`, `autoLog`) but let client code branch on the type — e.g.
`if (e is TomClientUIException)` — to decide whether an error is safe to show in
the UI.

## Class Hierarchy

```
TomException  (kernel)
    └── TomClientException
            └── TomClientUIException
```

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
  bool? autoLog,
})
```

See `TomException` (kernel) for the meaning of each argument.

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
  bool? autoLog,
})
```

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
