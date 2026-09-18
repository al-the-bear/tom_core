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
| `clientPlatformUtils` | Getter answering **one** `TomPlatformUtils` per process, built on first read; its concrete type is selected at compile time. Register it process-wide at startup. |
| `resetClientPlatformUtils` | Discards the built instance so the next read constructs again. `@visibleForTesting` — what a constructor does can only be observed by a test that can get back to "nothing built yet". |
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

## One instance per process

The getter caches: the first read builds the variant, every later read answers
the same object. It is a cache rather than a constant because the target is only
known at run time on the web branch and the constructor does real work on the
native one — so nothing is built in a process that never asks.

Caching the object does not freeze what it reports; every predicate reads
`defaultTargetPlatform` / `kIsWeb` at call time.

Two things follow. **Identity means something** — a caller that reads the getter
again instead of going through `TomPlatformUtils.current` holds what the process
registered, not a second equal-looking object. And **the native constructor's
work happens once**: it copies the whole process environment into the kernel's
env-var map, which a getter that constructed per read paid for on every read, on
a call that looks like a property access.

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
