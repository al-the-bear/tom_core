# Tom Core Flutter API Reference: Security Module

Client-side security annotations for the Flutter tier.

## Table of Contents

- [Overview](#overview)
- [Classes](#classes)
  - [TomClient2FAAdaptor](#tomclient2faadaptor)

## Overview

Source: `lib/src/tomclient/security/authentication.dart`.

The module exposes a single reflection-discoverable annotation,
`TomClient2FAAdaptor`, applied to client authentication adaptors to declare the
two-factor mechanism they implement so a runtime can enumerate and dispatch by
mechanism type.

## Classes

### TomClient2FAAdaptor

Annotation marking a class as a client-side two-factor (2FA) adaptor. It is
`@tomReflector`-registered, so a runtime can enumerate the available client 2FA
adaptors and dispatch by `type`.

```dart
@TomClient2FAAdaptor('totp')
class TotpAdaptor { /* ... */ }
```

#### Constructors

```dart
const TomClient2FAAdaptor(String type)
```

Tags the annotated class as a 2FA adaptor for `type`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The 2FA mechanism this adaptor implements (e.g. `'totp'`, `'sms'`). |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.
