# tom_core_d4rt

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The **D4rt scripting tool with full Tom Framework bridge support** — an
interactive REPL and headless script runner that exposes the core Tom packages
to sandboxed DartScript code.

## Overview

`tom_core_d4rt` builds on [`tom_d4rt`](https://pub.dev/packages/tom_d4rt) (the
interpreter) and `tom_d4rt_dcli` (the base REPL with shell/dcli bridges), adding
**generated bridges** for a dozen Tom packages so scripts can call into the
kernel, server, build, distributed, and document toolkits directly.

It ships two faces of the same bridge set:

- the **`d4rt` binary** (`bin/d4rt.dart`) — a standalone REPL / script runner,
  and
- a library entry point (`TomDartscriptBridges.register`) that the sibling
  [`tom_core_bridge`](../tom_core_bridge/README.md) package links into its
  **`core_bs`** VS Code bridge server (see
  [Binaries](#binaries-d4rt-and-core_bs) below).

## Installation

```yaml
dependencies:
  tom_core_d4rt:
    path: ../tom_core_d4rt
```

This package generates its bridge code with `build_runner` (the `d4rtgen`
builder configured in `buildkit.yaml`). After fetching dependencies, regenerate
the bridges:

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
```

See [`doc/build.md`](doc/build.md) for the full build and binary-compilation
workflow.

## Features

| Capability | What it gives you |
| ---------- | ----------------- |
| Interactive REPL | A live DartScript prompt with every Tom bridge pre-registered, named sessions, replay, and `info`/`classes` introspection. |
| Headless runner | Execute a replay file and exit — the pattern the bridge test suite uses. |
| VS Code integration | Scripts can drive the running editor over the bridge (default port `19900`). |
| Programmatic API | `TomDartscriptBridges.register(interpreter)` wires every bridge into a `D4rt` instance you construct yourself. |

### Bridged packages (the 12 `lib/src/` groups)

`TomDartscriptBridges.register(D4rt)` registers the `tom_d4rt_dcli` base bridges
plus the following Tom packages. Each group lives under `lib/src/<group>/`, owns
a generated `*_bridges.b.dart`, and is documented in its own `readme.md`; the
bridges forward each package's API unchanged, so the per-package READMEs remain
the authoritative API reference.

| Group | Bridge class | Bridges | Domain |
| ----- | ------------ | ------- | ------ |
| `cli` | — *(not a bridge)* | — | REPL wiring (`D4rtRepl`) + build-stamped `TomVersionInfo` behind `bin/d4rt.dart`. |
| `tom_basics` | `TomBasicsBridge` | [`tom_basics`](../../basics/tom_basics/README.md) | Core utilities, types, relaxers |
| `tom_reflection` | `TomReflectionBridge` | [`tom_reflection`](../../reflection/tom_reflection/README.md) | Runtime reflection support |
| `tom_core_kernel` | `TomCoreKernelBridge` | [`tom_core_kernel`](../tom_core_kernel/README.md) | Context, crypto, logging, security, settings |
| `tom_core_server` | `TomCoreServerBridge` | [`tom_core_server`](../tom_core_server/README.md) | Datasources, persistence, endpoints |
| `tom_build` | `TomBuildBridge` | [`tom_build`](../../devops/tom_build/README.md) | Build system and workspace tooling |
| `tom_dist_ledger` | `TomDistLedgerBridge` | [`tom_dist_ledger`](../../distributed/tom_dist_ledger/README.md) | Distributed ledger primitives |
| `tom_process_monitor` | `TomProcessMonitorBridge` | [`tom_process_monitor`](../../distributed/tom_process_monitor/README.md) | Process monitoring |
| `tom_doc_scanner` | `TomDocScannerBridge` | [`tom_doc_scanner`](../../ai_build/tom_doc_scanner/README.md) | Markdown document scanning |
| `tom_doc_specs` | `TomDocSpecsBridge` | `tom_doc_specs` | Document schema specifications |
| `tom_md2latex` | `TomMd2latexBridge` | `tom_md2latex` | Markdown → LaTeX conversion |
| `tom_md2pdf` | `TomMd2pdfBridge` | `tom_md2pdf` | Markdown → PDF conversion |

> The `cli` group is the one non-bridge member: it holds the REPL
> (`D4rtRepl`) and the generated `TomVersionInfo`, not a package bridge.
> Twelve folders, eleven bridges.

## Quick start

Launch the REPL directly from source:

```bash
dart run bin/d4rt.dart
```

Inside the REPL, every Tom bridge is live. Introspect the kernel bridge and call
into it:

```
d4rt> info tom_core_kernel        // lists the bridged kernel classes
d4rt> classes                     // lists every available class
d4rt> var s = TomString('hi');
d4rt> print(s.value);             // prints: hi
```

## Examples

Runnable DartScript examples live in [`example/`](example/) — one per key bridge
module, written from a script author's point of view. Each prints its real
runtime results in normal mode and self-asserts in `-test` mode:

```bash
dart run bin/d4rt.dart -run-replay example/01_crypto_example.d4rt          # prints results
dart run bin/d4rt.dart -run-replay example/01_crypto_example.d4rt -test    # asserts, exit 0 on pass
example/run_examples.sh                                                    # run all three
```

| File | Bridge module | Shows |
| ---- | ------------- | ----- |
| `01_crypto_example.d4rt` | crypto | Argon2 hash + verify round-trip, salt generation, JWT/RSA types |
| `02_logging_example.d4rt` | logging | `TomLogger` construction, level by enum/name, log lines per severity |
| `03_security_example.d4rt` | security | Principal model, ACL access checks, bearer auth, resource-role authorization |

See [`example/README.md`](example/README.md) for details.

## Binaries: `d4rt` and `core_bs`

This package and its sibling [`tom_core_bridge`](../tom_core_bridge/README.md)
emit the two binaries that carry the Tom bridge set:

| Binary | Owned by | What it is |
| ------ | -------- | ---------- |
| `d4rt` | `tom_core_d4rt` (`bin/d4rt.dart`) | Standalone REPL / script runner. Emitted to `$TOM_BINARY_PATH/<platform-vs>/d4rt`. |
| `core_bs` | `tom_core_bridge` (`bin/core_bs.dart`) | The VS Code bridge server (`tom_bs`) **plus** everything `tom_core_d4rt` registers. Emitted to `$TOM_BINARY_PATH/<platform-vs>/core_bs`. |

`core_bs` is just the base `tom_vscode_bridge` server with
`TomDartscriptBridges.register` passed as an additional bridge registrar — so
the Tom Framework bridge set defined here is reachable both from the
command-line `d4rt` REPL and from inside a running VS Code instance via
`core_bs`. Because `core_bs` links the generated bridge set, the two binaries
share the same generation/compilation pipeline. See
[`tom_core_bridge/README.md`](../tom_core_bridge/README.md).

## Run

Compile and run the `d4rt` binary produced by the build (emitted to
`$TOM_BINARY_PATH/<platform>/d4rt`), or run from source as above.

### CLI options

```
Options
  -h, --help                Show this help message
  -v, --version             Show version information
  -session <id>             Resume or start a named session
  -replace-session <id>     Delete existing session and start fresh
  -replay <file>            Replay a file before starting REPL
  -run-replay <file>        Execute replay file and exit
  -list-sessions            List available sessions
  -init-source <file>       Use custom init source file
  -no-init-source           Don't load custom init source
  --dump-configuration      Dump registered bridges and configuration
  --debug                   Print init source and debug information
  -integration-server-port <port>  Override VS Code port (default: 19900)
```

### Headless / test mode

Execute a replay script and exit (no interactive prompt) — the pattern used by
the bridge test suite:

```bash
dart run bin/d4rt.dart -run-replay my_test.d4rt
```

See [`doc/testing.md`](doc/testing.md) for the replay-based testing strategy.

## Library usage

To embed the bridges in your own interpreter setup:

```dart
import 'package:tom_core_d4rt/tom_dartscript_bridges.dart';

void main() {
  final interpreter = D4rt();
  TomDartscriptBridges.register(interpreter);
  // All Tom bridges are now available to scripts run on this interpreter.
}
```

## Architecture

```
bin/d4rt.dart                 thin entry point
        │
   lib/src/cli/               D4rtRepl + VSCodeIntegrationMixin + TomVersionInfo
        │
TomDartscriptBridges.register(D4rt)
        │
        ├── tom_d4rt_dcli base bridges (shell / dcli / VS Code API)
        └── 11 generated package bridges (lib/src/<group>/*_bridges.b.dart)
               tom_basics · tom_reflection · tom_core_kernel · tom_core_server
               tom_build · tom_dist_ledger · tom_process_monitor
               tom_doc_scanner · tom_doc_specs · tom_md2latex · tom_md2pdf
```

| Type | Responsibility |
| ---- | -------------- |
| `TomDartscriptBridges` | Registration class — wires the base + all package bridges into a `D4rt`. |
| `D4rtRepl` | The interactive REPL (`lib/src/cli/`), extends `D4rtReplBase` with VS Code integration and `.d4rt`/`.dcli` replay. |
| `TomVersionInfo` | Build-stamped version constants surfaced by `-v` (generated by the `versioner` step). |
| `Tom*Bridge` | One generated bridge container per upstream package (e.g. `TomCoreKernelBridge`). |

## Ecosystem

```
tom_d4rt (interpreter) · tom_d4rt_dcli (base REPL + bridges)
                 │
          tom_core_d4rt          ← you are here
   (generated Tom Framework bridge set: TomDartscriptBridges)
                 │
        ┌────────┴────────┐
   d4rt binary       tom_core_bridge → core_bs (VS Code bridge server)
```

`tom_core_d4rt` is the bridge layer of the Tom Framework: it makes the kernel,
server, build, distributed, and document packages callable from sandboxed
DartScript. See the [repository map](../README.md) for the full picture.

## Further documentation

- [`doc/build.md`](doc/build.md) — build, bridge generation, binary compilation.
- [`doc/testing.md`](doc/testing.md) — replay-based bridge testing.
- [`doc/cli.md`](doc/cli.md) — as-built CLI wiring (thin `bin/d4rt.dart` → `lib/src/cli/`).
- [`doc/d4rt_cli_api_design.md`](doc/d4rt_cli_api_design.md) — forward-looking CLI / API design notes.
- Per-module API reference under [`doc/api_reference/`](doc/api_reference/) —
  the package's own public surface (registration, CLI/REPL, version info, and the
  shared `Tom*Bridge` container contract). Start at
  [`doc/api_reference/api_summary_index.md`](doc/api_reference/api_summary_index.md).
- Per-bridge generation notes under [`doc/`](doc/) — one markdown file per group
  (`doc/tom_core_kernel.md`, `doc/tom_core_server.md`, …); these remain the
  authoritative reference for the *bridged* types each container forwards.
- [`tom_core_bridge`](../tom_core_bridge/README.md) — the `core_bs` VS Code
  bridge server that links this bridge set.

## Status

- **Version:** 1.0.4
- **Tests:** 33 test cases across 3 suites (replay + dcli-compat; run with
  `dart test` or the `bin/d4rtrun.b.dart` replay runner). The `tom_reflection`
  (RCF5) and `tom_basics` (RCG5) replays each exercise every bridged class
  their containers register (zero-gap cross-check); the `tom_build` replay
  (RCH5) covers every connection-free bridged class (55/60), with only the five
  IO-driver classes (`WorkspaceAnalyzer`, `ReflectionGeneratorRunner`,
  `TomShell`, `TomFs`, `TomGlob`) deferred as they need a live
  filesystem/process.
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
