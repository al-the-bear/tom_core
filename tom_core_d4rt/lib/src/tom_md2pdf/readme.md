# tom_md2pdf

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_md2pdf`](../../../../../devops/tom_md2pdf/)**.
Registering `tom_core_d4rt` exposes the Markdown→PDF converter to sandboxed
DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_md2pdf/tom_md2pdf.dart'` and render documents directly. The
bridge forwards the API unchanged.

## What it bridges

The `TomMd2pdfBridge` container registers the public surface of `tom_md2pdf`,
including `Md2Pdf`, `MdPdfConverter`, `MdPdfConverterOptions`,
`MdPdfConverterResult`, `PdfConvertedFile`, `PageMargins` and
`PdfConverterOptionsWrapper`, plus the `PageFormat` enum. For the authoritative
API, read the upstream package (no published README yet — see its source under
`lib/`); this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_md2pdf/tom_md2pdf.dart';

// Converter, options and page-format types are now in scope.
```

Inside the REPL, `info tom_md2pdf` lists every bridged class and `classes` lists
them across all packages.

---

Bridges **[`tom_md2pdf`](../../../../../devops/tom_md2pdf/)** · see
[`doc/tom_md2pdf.md`](../../../doc/tom_md2pdf.md) for generation notes. Part of
[`tom_core_d4rt`](../../../README.md) — see the package README for the REPL, the
full bridge list, and build instructions.
