# tom_core_kernel

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_core_kernel`](../../../../tom_core_kernel/README.md)**.
Registering `tom_core_d4rt` exposes the kernel to sandboxed DartScript, so REPL
sessions and `.d4rt` scripts can
`import 'package:tom_core_kernel/tom_core_kernel.dart'` and use the observable,
context, security and reflection types directly. The bridge forwards the API
unchanged.

## What it bridges

The `TomCoreKernelBridge` container registers the public surface of
`tom_core_kernel` — the largest bridge in the package — including the observable
family (`TomObject`, `TomString`, `TomInt`, `TomBool`, `TomObservable`,
`TomObserver`), context/scope (`TomExecutionContext`, `TomScope`), DI
(`TomBean`, `TomComponent`), security (`TomAuthorization`, `TomAuthorizer`,
`TomBearerAuthentication`), logging (`TomLogger`, `TomLogOutput`), reflection
(`TomReflector`, the `*Mirror` types) and the crypto helpers, plus the
`TomAuthState`, `TomAuthorizerStrategy` and `AuthGroupMode` enums. For the
authoritative API, read the upstream package README; this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Observable, context, security and reflection types are now in scope.
```

Inside the REPL, `info tom_core_kernel` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_core_kernel`](../../../../tom_core_kernel/README.md)** · see
[`doc/tom_core_kernel.md`](../../../doc/tom_core_kernel.md) for generation notes.
Part of [`tom_core_d4rt`](../../../README.md) — see the package README for the
REPL, the full bridge list, and build instructions.
