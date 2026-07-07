# Tom Core Bridge

Extended VS Code bridge server with the full Tom Framework D4rt bridge set.

## Overview

This project provides an alternative bridge server binary (`core_bs`) for the
VS Code extension. The base `tom_bs` (from `tom_vscode_bridge`) ships only the
DCli and VS Code API bridges; `core_bs` is the same bridge server **plus** the
complete Tom Framework bridge set registered by `tom_core_d4rt`
(`TomDartscriptBridges.register`):

- **tom_basics** — basic utilities, logging, platform detection
- **tom_reflection** — reflection support
- **tom_core_kernel** — core framework types
- **tom_core_server** — server-side components
- **tom_build** — build-system APIs
- **tom_dist_ledger** — distributed ledger
- **tom_process_monitor** — process monitoring
- **tom_doc_scanner** — markdown document scanning
- **tom_doc_specs** — document-spec validation
- **tom_md2latex** — markdown → LaTeX conversion
- **tom_md2pdf** — markdown → PDF conversion

The bridged surfaces are documented per module in
[`tom_core_d4rt/doc/`](../tom_core_d4rt/doc/).

## Architecture

The binary is a thin entry point: it starts the `tom_vscode_bridge` server and
passes `TomDartscriptBridges.register` as an additional bridge registrar.

```text
tom_core_bridge (bin/core_bs.dart)
├── tom_vscode_bridge            — base bridge server + VS Code API bridges
│   ├── tom_d4rt_dcli            — DCli bridges
│   └── tom_vscode_scripting_api — VS Code API wrappers
└── tom_core_d4rt               — Tom Framework bridges (TomDartscriptBridges)
    ├── tom_basics              ├── tom_dist_ledger     ├── tom_doc_specs
    ├── tom_reflection          ├── tom_process_monitor ├── tom_md2latex
    ├── tom_core_kernel         ├── tom_doc_scanner     └── tom_md2pdf
    ├── tom_core_server
    └── tom_build
```

```dart
// bin/core_bs.dart — the whole entry point
void main() {
  VSCodeBridgeServer(
    additionalBridgeRegistrars: [TomDartscriptBridges.register],
  ).start();
}
```

It is launched by the VS Code extension and communicates over stdin/stdout
using a JSON-RPC-like protocol.

## Build

The binary is compiled ahead-of-time and published into the workspace binary
tree (`$TOM_BINARY_PATH/<platform-vs>/core_bs`). The build is driven by
[`buildkit.yaml`](buildkit.yaml) (a `versioner` step that regenerates
`lib/src/version.versioner.dart`, then per-platform `dart compile exe` pipelines
that also cross-compile the Linux targets from macOS ARM64).

```bash
# Via the workspace build tool (regenerates the versioner, then compiles):
tom build tom_core_bridge

# Or compile the entry point directly for the current platform:
dart compile exe bin/core_bs.dart -o core_bs
```

> **Note:** `core_bs` links the generated `tom_core_d4rt` bridge set. The
> earlier codegen blockers (the `tom_d4rt_generator` defects in the
> `tom_core_server` / `tom_dist_ledger` bridges and the `tom_d4rt` version
> skew) are resolved: `tom_d4rt` resolves to 1.8.24, `dart analyze` is clean
> across those generated bridges, and the binary now **builds**. Running
> `dart run tool/smoke_test.dart` reports `[SMOKE] PASS`. See
> `tom_core_d4rt/CHANGELOG.md` for the history.

## VS Code registration

The extension launches a bridge process whose command and arguments come from
its bridge-profile configuration (`DartBridgeClient`). When no explicit command
is configured it falls back to `dart run bin/tom_bs.dart`. To run the extended
server instead, point the bridge command/args at `core_bs`:

- **Compiled binary** — set the bridge command to the published
  `core_bs` executable (`$TOM_BINARY_PATH/<platform-vs>/core_bs`), no args.
- **From source** — set the command to `dart` with args
  `['run', '<path>/tom_core_bridge/bin/core_bs.dart']`.

Once registered, every D4rt script run through the VS Code bridge has the full
Tom Framework bridge set available in addition to the DCli and VS Code APIs.

## Operations

For the full operational runbook — build pipeline and artifact locations, the
bridge-profile configuration shape, switching profiles, and a troubleshooting
table for failed launches — see [`doc/operations.md`](doc/operations.md).

## License

BSD 3-Clause licensed — see [`LICENSE`](LICENSE).
