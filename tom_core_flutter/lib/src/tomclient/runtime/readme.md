# runtime

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Compile-time platform detection for the Flutter client. A single conditional
import picks the right `TomPlatformUtils` implementation — native IO on
desktop/mobile, web in the browser, or a neutral fallback — exposed through the
`clientPlatformUtils` getter.

## Key types

| Type / member | Responsibility |
| ------------- | -------------- |
| `clientPlatformUtils` | Getter returning a fresh `TomPlatformUtils` whose concrete type is selected at compile time. Register it process-wide at startup. |
| `TomFlutterPlatformUtils` | The concrete `TomPlatformUtils` subtype; three variants live in `platform_detection_flutter_io.dart` (`dart:io`), `platform_detection_web.dart` (`dart:js`), and `platform_detection_neutral.dart` (fallback). |
| `TomBadCertificatePolicy` | The hosts whose **unverified** TLS certificate the native client accepts — both loopback families by default. Exported, replaceable through `allowOnly`, and a replacement is logged. |

The conditional import in `platform_detection_client.dart` is the seam:

```dart
import 'platform_detection_neutral.dart'
    if (dart.library.io) 'platform_detection_flutter_io.dart'
    if (dart.library.js) 'platform_detection_web.dart';
```

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  // Register the compile-time-selected platform as the process-wide platform.
  TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);

  // Now platform predicates answer for the current target:
  print(TomPlatformUtils.current.isWeb()); // true in the browser
}
```

## The certificate policy

A client handed a certificate it cannot verify normally refuses the connection.
Development against a local server with a self-signed certificate is the case
where refusing helps nobody, so the native variant's `badCertificateCallback`
consults `TomBadCertificatePolicy` — a loopback address is not reachable from
another machine, so a certificate presented on one came from this machine
whatever it claims.

The shipped list is `0.0.0.0`, `localhost`, `127.0.0.1`, `::1` and `[::1]`, and
nothing else. **Both loopback families are there deliberately:** which one
`localhost` resolves to is the resolver's choice and differs between machines,
so naming one and not the other makes the same code, certificate and URL succeed
on one desktop and fail on the next — as a TLS error, which points the reader at
the certificate. `::1` is the spelling that arrives, because `Uri` strips the
brackets an IPv6 literal carries in a URL.

`allowOnly` replaces the list — widening it, or narrowing it to nothing for a
hardened build — and logs at warn level, because the policy in force is no
longer the policy in the source. Matching is exact; there are no wildcards.
It is read per handshake, so a change reaches clients that already exist, and it
is consulted only on native targets.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
