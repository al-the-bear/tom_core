# Tom Core D4rt

`tom_core_d4rt` is the **D4rt scripting tool with full Tom Framework bridge
support** — an interactive REPL and headless script runner that exposes the
core Tom packages to sandboxed DartScript code.

It builds on `tom_d4rt` (the interpreter) and `tom_d4rt_dcli` (the base REPL
with shell/dcli bridges), adding generated bridges for a dozen Tom packages so
scripts can call into the kernel, server, build, distributed, and document
toolkits directly.

> **Proprietary / internal.** This package is `publish_to: none` and is not
> distributed on pub.dev. See [`LICENSE`](LICENSE).

## What it does

- **Interactive REPL** — launch `d4rt` for a live DartScript prompt with all Tom
  bridges pre-registered, named sessions, replay, and `info`/`classes`
  introspection commands.
- **Headless script & replay runner** — execute a replay file and exit, for use
  in tests and automation.
- **VS Code integration** — connects to the editor bridge (default port
  `19900`) so scripts can drive the running VS Code instance.
- **Programmatic API** — `TomDartscriptBridges.register(interpreter)` wires every
  bridge into a `D4rt` instance you construct yourself.

## Bridged packages

`TomDartscriptBridges.register(D4rt)` registers the `tom_d4rt_dcli` base bridges
plus the following Tom packages (each is also exposed under its sub-package
barrels for direct imports):

| Package | Domain |
| ------- | ------ |
| `tom_basics` | Core utilities, types, relaxers |
| `tom_reflection` | Runtime reflection support |
| `tom_core_kernel` | Kernel: context, crypto, logging, security, settings |
| `tom_core_server` | Server: datasources, persistence, endpoints |
| `tom_build` | Build system and workspace tooling |
| `tom_dist_ledger` | Distributed ledger primitives |
| `tom_process_monitor` | Process monitoring |
| `tom_doc_scanner` | Markdown document scanning |
| `tom_doc_specs` | Document schema specifications |
| `tom_md2latex` | Markdown → LaTeX conversion |
| `tom_md2pdf` | Markdown → PDF conversion |

## Getting started

This package generates its bridge code with `build_runner` (the `d4rtgen`
builder configured in `buildkit.yaml`). After cloning the workspace and
fetching dependencies, regenerate the bridges:

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
```

See [`doc/build.md`](doc/build.md) for the full build and binary-compilation
workflow.

## Run

Run the REPL directly from source:

```bash
dart run bin/d4rt.dart
```

Or compile and run the `d4rt` binary produced by the build (it is emitted to
`$TOM_BINARY_PATH/<platform>/d4rt`).

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

Inside the REPL, use `info <package>` to inspect a bridged package and `classes`
to list every available class.

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

## Additional information

- [`doc/build.md`](doc/build.md) — build, bridge generation, binary compilation.
- [`doc/testing.md`](doc/testing.md) — replay-based bridge testing.
- [`doc/cli.md`](doc/cli.md) — as-built CLI wiring (thin `bin/d4rt.dart` → `lib/src/cli/`).
- [`doc/d4rt_cli_api_design.md`](doc/d4rt_cli_api_design.md) — forward-looking CLI / API design notes.
