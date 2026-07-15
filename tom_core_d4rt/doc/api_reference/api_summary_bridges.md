# Tom Core D4rt API Reference: Bridge Containers Module

The eleven generated `Tom*Bridge` container classes — one per bridged Tom
package — plus the relaxer factory functions. Every container is produced by the
same `d4rtgen` generator and therefore exposes the **same static contract**;
this reference documents that contract once and then lists the concrete
containers.

## Table of contents

- [Overview](#overview)
- [The shared `Tom*Bridge` contract](#the-shared-tombridge-contract)
- [Bridge containers](#bridge-containers)
- [Relaxer factory functions](#relaxer-factory-functions)
- [Enums](#enums)
- [Global functions and constants](#global-functions-and-constants)

## Overview

Each container gathers the bridge definitions for one Tom package and registers
them against a `D4rt` interpreter under that package's import URI. They are all
re-exported from `lib/d4rt_bridges.b.dart`. Consumers rarely call a container
directly — [`TomDartscriptBridges.register`](api_summary_registration.md) calls
them all — but the contract is public and stable, so it is documented here.

- Source: `lib/src/<package>/<package>_bridges.b.dart` (one file per container).
- Barrel: `lib/d4rt_bridges.b.dart` re-exports all eleven.

> **The bridged types are not owned here.** A container forwards its package's
> API unchanged; the authoritative reference for the classes, enums, and
> functions each one exposes to scripts is the package's own README and its
> generation guide under [`doc/`](../) (see the table below).

## The shared `Tom*Bridge` contract

Every `Tom*Bridge` is a static-only class (never instantiated) exposing this
identical surface. `TomCoreKernelBridge` is used below as the representative;
the signatures are the same for all eleven.

**Constructors**

```dart
// None — every Tom*Bridge exposes only static members.
```

**Static methods**

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerBridges` | `static void registerBridges(D4rt interpreter, String importPath)` | Registers every bridged class, enum, extension, global variable, and global function of the package with `interpreter` under `importPath`, and installs the flattened native supertype table. |
| `bridgeClasses` | `static List<BridgedClass> bridgeClasses()` | All bridged class definitions for the package. |
| `bridgedEnums` | `static List<BridgedEnumDefinition> bridgedEnums()` | All bridged enum definitions. |
| `bridgedExtensions` | `static List<BridgedExtensionDefinition> bridgedExtensions()` | All bridged extension definitions. |
| `globalFunctions` | `static Map<String, NativeFunctionImpl> globalFunctions()` | Top-level functions exposed to scripts, by name. |
| `registerGlobalVariables` | `static void registerGlobalVariables(D4rt interpreter, String importPath)` | Registers the package's top-level variables/constants. |
| `classSourceUris` | `static Map<String, String> classSourceUris()` | Source library URI per bridged class name (for de-duplication). |
| `enumSourceUris` | `static Map<String, String> enumSourceUris()` | Source library URI per bridged enum name. |
| `extensionSourceUris` | `static Map<String, String> extensionSourceUris()` | Source library URI per bridged extension. |
| `globalFunctionSourceUris` | `static Map<String, String> globalFunctionSourceUris()` | Source library URI per global function. |
| `globalFunctionSignatures` | `static Map<String, String> globalFunctionSignatures()` | Declared signature text per global function. |
| `classSupertypes` | `static Map<String, List<String>> classSupertypes()` | Flattened native supertype list per bridged class (for subtype checks). |
| `classAliases` | `static Map<String, String> classAliases()` | Alternate names mapped to canonical class names. |
| `functionTypedefs` | `static List<String> functionTypedefs()` | Function-typedef declarations the package needs. |
| `bridgeReExports` | `static List<({String source, String target, Set<String>? show, Set<String>? hide})> bridgeReExports()` | Re-export edges (`source`→`target`, with optional `show`/`hide`) followed during registration. |
| `sourceLibraries` | `static List<String> sourceLibraries()` | Source library URIs the bridges were generated from. |
| `subPackageBarrels` | `static List<String> subPackageBarrels()` | Additional barrel URIs (from re-exports) under which the bridges should also be registered so direct sub-package imports resolve. |
| `getImportBlock` | `static String getImportBlock()` | The `import` lines a script needs to use this package's bridged types. |

**Static properties**

| Property | Signature | Description |
| -------- | --------- | ----------- |
| `enumNames` | `static List<String> get enumNames` | Names of the bridged enums in the package. |

## Bridge containers

All eleven classes implement the contract above. Follow the guide link for the
authoritative list of types each one bridges.

| Container class | Bridged package | Source file | Authoritative API |
| --------------- | --------------- | ----------- | ----------------- |
| `TomBasicsBridge` | `tom_basics` | `lib/src/tom_basics/tom_basics_bridges.b.dart` | [`doc/tom_basics.md`](../tom_basics.md) |
| `TomReflectionBridge` | `tom_reflection` | `lib/src/tom_reflection/tom_reflection_bridges.b.dart` | [`doc/tom_reflection.md`](../tom_reflection.md) |
| `TomProcessMonitorBridge` | `tom_process_monitor` | `lib/src/tom_process_monitor/tom_process_monitor_bridges.b.dart` | [`doc/tom_process_monitor.md`](../tom_process_monitor.md) |
| `TomCoreKernelBridge` | `tom_core_kernel` | `lib/src/tom_core_kernel/tom_core_kernel_bridges.b.dart` | [`doc/tom_core_kernel.md`](../tom_core_kernel.md) |
| `TomBuildBridge` | `tom_build` | `lib/src/tom_build/tom_build_bridges.b.dart` | [`doc/tom_build.md`](../tom_build.md) |
| `TomCoreServerBridge` | `tom_core_server` | `lib/src/tom_core_server/tom_core_server_bridges.b.dart` | [`doc/tom_core_server.md`](../tom_core_server.md) |
| `TomDistLedgerBridge` | `tom_dist_ledger` | `lib/src/tom_dist_ledger/tom_dist_ledger_bridges.b.dart` | [`doc/tom_dist_ledger.md`](../tom_dist_ledger.md) |
| `TomDocScannerBridge` | `tom_doc_scanner` | `lib/src/tom_doc_scanner/tom_doc_scanner_bridges.b.dart` | [`doc/tom_doc_scanner.md`](../tom_doc_scanner.md) |
| `TomDocSpecsBridge` | `tom_doc_specs` | `lib/src/tom_doc_specs/tom_doc_specs_bridges.b.dart` | [`doc/tom_doc_specs.md`](../tom_doc_specs.md) |
| `TomMd2latexBridge` | `tom_md2latex` | `lib/src/tom_md2latex/tom_md2latex_bridges.b.dart` | [`doc/tom_md2latex.md`](../tom_md2latex.md) |
| `TomMd2pdfBridge` | `tom_md2pdf` | `lib/src/tom_md2pdf/tom_md2pdf_bridges.b.dart` | [`doc/tom_md2pdf.md`](../tom_md2pdf.md) |

> **Upstream base bridges.** `TomDartscriptBridges.register` also registers
> `TomD4rtDcliBridge` from `tom_d4rt_dcli` (the `dcli`/stdlib base bridge set)
> before the eleven above. It is declared in `tom_d4rt_dcli`, not this package.

## Relaxer factory functions

Top-level functions in `lib/src/tom_basics/relaxers.b.dart`, called by
`TomDartscriptBridges.register` to install generic-type support. For
`tom_core_d4rt` both are generated as **no-ops** (this bridge set needs no
GEN-079 relaxer wrappers or RC-2 generic-constructor factories); they exist so
the registration call site is uniform across bridge sets.

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `registerRelaxers` | `void registerRelaxers()` | Registers GEN-079 relaxer wrapper factories (no-op here). |
| `registerGenericConstructors` | `void registerGenericConstructors()` | Registers RC-2 generic-constructor factories (no-op here). |

## Enums

None — this module defines no enums. (The bridged *packages* define enums; those
are listed by each container's `enumNames` and documented in the package guides.)

## Global functions and constants

The relaxer factory functions above are the module's only top-level functions.
This module exposes no top-level constants.
