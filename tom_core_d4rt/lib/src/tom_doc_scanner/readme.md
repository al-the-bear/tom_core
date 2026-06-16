# tom_doc_scanner

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_doc_scanner`](../../../../../ai_build/tom_doc_scanner/README.md)**.
Registering `tom_core_d4rt` exposes the markdown document scanner to sandboxed
DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_doc_scanner/tom_doc_scanner.dart'` and parse documents
directly. The bridge forwards the API unchanged.

## What it bridges

The `TomDocScannerBridge` container registers the public surface of
`tom_doc_scanner`, including `DocScanner`, `DocScannerFactory`, `Document`,
`DocumentFolder`, `MarkdownParser`, `ParsedHeadline` and `Section`. For the
authoritative API, read the upstream package README; this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_doc_scanner/tom_doc_scanner.dart';

// Document, scanner and parser types are now in scope.
```

Inside the REPL, `info tom_doc_scanner` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_doc_scanner`](../../../../../ai_build/tom_doc_scanner/README.md)**
· see [`doc/tom_doc_scanner.md`](../../../doc/tom_doc_scanner.md) for generation
notes. Part of [`tom_core_d4rt`](../../../README.md) — see the package README for
the REPL, the full bridge list, and build instructions.
