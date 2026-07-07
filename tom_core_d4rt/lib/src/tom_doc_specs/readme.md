# tom_doc_specs

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_doc_specs`](../../../../../ai_build/tom_doc_specs/)**.
Registering `tom_core_d4rt` exposes the document-schema specification toolkit to
sandboxed DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_doc_specs/tom_doc_specs.dart'` and validate documents
directly. The bridge forwards the API unchanged.

## What it bridges

The `TomDocSpecsBridge` container registers the public surface of
`tom_doc_specs`, including `DocSpecs`, `DocSpecsFactory`, `DocSpecsValidator`,
`DocSpecSchema`, `SchemaLoader`, `SchemaResolver`, `SpecDoc`, `SpecSection`,
`InsertMarkerProcessor` and the form/section definition types, plus the
`SchemaSource` and `ValidationErrorCategory` enums. For the authoritative API,
read the upstream package (no published README yet — see its source under
`lib/`); this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_doc_specs/tom_doc_specs.dart';

// Schema, validator and spec-document types are now in scope.
```

Inside the REPL, `info tom_doc_specs` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_doc_specs`](../../../../../ai_build/tom_doc_specs/)** · see
[`doc/tom_doc_specs.md`](../../../doc/tom_doc_specs.md) for generation notes.
Part of [`tom_core_d4rt`](../../../README.md) — see the package README for the
REPL, the full bridge list, and build instructions.
