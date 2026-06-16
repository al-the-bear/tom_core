# tom_md2latex

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_md2latex`](../../../../../devops/tom_md2latex/)**.
Registering `tom_core_d4rt` exposes the Markdown→LaTeX converter to sandboxed
DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_md2latex/tom_md2latex.dart'` and convert documents
directly. The bridge forwards the API unchanged.

## What it bridges

The `TomMd2latexBridge` container registers the public surface of
`tom_md2latex`, including `Md2Latex`, `MdLatexConverter`,
`MdLatexConverterOptions`, `MdLatexConverterResult`, `MarkdownParser`,
`MarkdownParserOptions`, `ParsedMarkdown`, `ConvertedFile` and the
`MarkdownElement` node hierarchy (`HeadingElement`, `ParagraphElement`,
`TableElement`, …). For the authoritative API, read the upstream package (no
published README yet — see its source under `lib/`); this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_md2latex/tom_md2latex.dart';

// Converter, options and markdown-element types are now in scope.
```

Inside the REPL, `info tom_md2latex` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_md2latex`](../../../../../devops/tom_md2latex/)** · see
[`doc/tom_md2latex.md`](../../../doc/tom_md2latex.md) for generation notes. Part
of [`tom_core_d4rt`](../../../README.md) — see the package README for the REPL,
the full bridge list, and build instructions.
