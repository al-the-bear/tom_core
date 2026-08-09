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
- **demo_persistence** — `tom_core_d4rt`'s own reflected demo entities, the
  worked example the persistence and endpoint surfaces are exercised against

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
    ├── tom_core_kernel         ├── tom_doc_scanner     ├── tom_md2pdf
    ├── tom_core_server                                 └── demo_persistence
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

> **Note:** `core_bs` links the generated `tom_core_d4rt` bridge set, so the
> build depends on those generated bridges analyzing clean. Verify the whole
> chain — compile, launch, answer a request — with
> `dart run tool/smoke_test.dart`, which reports `[SMOKE] PASS`. See
> [`doc/smoke_test.md`](doc/smoke_test.md).

## VS Code registration

The extension launches a bridge process from its **active bridge profile** in
`tom_vscode_extension.json`. A profile does not carry a command path — it names
an entry in the sibling `bridge.executables` map, which is resolved per
platform against `bridge.binaryPath`. To run the extended server, register
`core_bs` as an executable and point a profile at it:

```jsonc
{
  "bridge": {
    "current": "core",
    "binaryPath": {
      "darwin-arm64": "${env:TOM_BINARY_PATH}/darwin-arm64/",
      "linux-x64": "${env:TOM_BINARY_PATH}/linux-x64/"
    },
    "executables": {
      "core_bs": { "*": "${binaryPath}core_bs" }
    },
    "profiles": {
      "core": {
        "label": "Tom Core Bridge",
        "executable": "core_bs",
        "args": [],
        "cwd": "${workspaceFolder}",
        "runPubGet": false
      }
    }
  }
}
```

`executable` is mandatory: the extension's `loadBridgeConfig()` **skips** any
profile without one, so a profile written with a `command` key is silently not
offered.

Once registered, every D4rt script run through the VS Code bridge has the full
Tom Framework bridge set available in addition to the DCli and VS Code APIs.

## Operations

For the full operational runbook — build pipeline and artifact locations, the
bridge-profile configuration shape, switching profiles, and a troubleshooting
table for failed launches — see [`doc/operations.md`](doc/operations.md).

## License

BSD 3-Clause licensed — see [`LICENSE`](LICENSE).
