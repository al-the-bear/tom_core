# Tom Core D4rt API Reference: Index

This is the type index for the **public API of the `tom_core_d4rt` package
itself** — the thin registration, CLI, and bridge-container layer it adds on
top of the Tom Framework packages it bridges.

> **Scope.** `tom_core_d4rt` is a *bridge* package: it exposes the API of eleven
> upstream Tom packages to `d4rt` scripts unchanged. The bridged domain types
> (e.g. `TomLogger`, `TomServer`, `TomRepository`) are **not** owned here — their
> authoritative API reference lives in their own package READMEs and in the
> per-package generation guides under [`doc/`](../). This reference documents
> only the classes and functions that `tom_core_d4rt` *declares*: the combined
> registration entry point, the interactive REPL, the build-time version
> constants, and the shared contract of the generated `Tom*Bridge` containers.

## Modules

| Module | Summary | Key types |
| ------ | ------- | --------- |
| Registration | [`api_summary_registration.md`](api_summary_registration.md) | `TomDartscriptBridges` |
| CLI & REPL | [`api_summary_cli.md`](api_summary_cli.md) | `D4rtRepl`, `d4rtMain`, `TomVersionInfo` |
| Bridge containers | [`api_summary_bridges.md`](api_summary_bridges.md) | `TomCoreKernelBridge`, `TomCoreServerBridge`, … (11 generated containers) |

## Type index

| Type | Kind | Module |
| ---- | ---- | ------ |
| `TomDartscriptBridges` | Class (static) | Registration |
| `D4rtRepl` | Class | CLI & REPL |
| `TomVersionInfo` | Class (static) | CLI & REPL |
| `TomBasicsBridge` | Class (generated) | Bridge containers |
| `TomReflectionBridge` | Class (generated) | Bridge containers |
| `TomProcessMonitorBridge` | Class (generated) | Bridge containers |
| `TomCoreKernelBridge` | Class (generated) | Bridge containers |
| `TomBuildBridge` | Class (generated) | Bridge containers |
| `TomCoreServerBridge` | Class (generated) | Bridge containers |
| `TomDistLedgerBridge` | Class (generated) | Bridge containers |
| `TomDocScannerBridge` | Class (generated) | Bridge containers |
| `TomDocSpecsBridge` | Class (generated) | Bridge containers |
| `TomMd2latexBridge` | Class (generated) | Bridge containers |
| `TomMd2pdfBridge` | Class (generated) | Bridge containers |

## Global functions

| Function | Module |
| -------- | ------ |
| `d4rtMain(List<String> arguments)` | CLI & REPL |
| `registerRelaxers()` | Bridge containers |
| `registerGenericConstructors()` | Bridge containers |

## Authoritative API of the bridged packages

For the types each bridge exposes to scripts, follow the package's own
documentation:

| Bridge container | Bridged package | Generation guide |
| ---------------- | --------------- | ---------------- |
| `TomBasicsBridge` | `tom_basics` | [`doc/tom_basics.md`](../tom_basics.md) |
| `TomReflectionBridge` | `tom_reflection` | [`doc/tom_reflection.md`](../tom_reflection.md) |
| `TomProcessMonitorBridge` | `tom_process_monitor` | [`doc/tom_process_monitor.md`](../tom_process_monitor.md) |
| `TomCoreKernelBridge` | `tom_core_kernel` | [`doc/tom_core_kernel.md`](../tom_core_kernel.md) |
| `TomBuildBridge` | `tom_build` | [`doc/tom_build.md`](../tom_build.md) |
| `TomCoreServerBridge` | `tom_core_server` | [`doc/tom_core_server.md`](../tom_core_server.md) |
| `TomDistLedgerBridge` | `tom_dist_ledger` | [`doc/tom_dist_ledger.md`](../tom_dist_ledger.md) |
| `TomDocScannerBridge` | `tom_doc_scanner` | [`doc/tom_doc_scanner.md`](../tom_doc_scanner.md) |
| `TomDocSpecsBridge` | `tom_doc_specs` | [`doc/tom_doc_specs.md`](../tom_doc_specs.md) |
| `TomMd2latexBridge` | `tom_md2latex` | [`doc/tom_md2latex.md`](../tom_md2latex.md) |
| `TomMd2pdfBridge` | `tom_md2pdf` | [`doc/tom_md2pdf.md`](../tom_md2pdf.md) |
