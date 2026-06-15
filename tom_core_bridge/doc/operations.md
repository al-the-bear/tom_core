# Tom Core Bridge — Operations

Operational runbook for the `core_bs` binary: how to build it, where the
artifact lands, how to point the VS Code extension at it, and how to diagnose a
failed launch. For the package overview and architecture see
[`../README.md`](../README.md).

## Build the binary

`core_bs` is compiled ahead-of-time and published into the workspace binary
tree. The build is driven by [`../buildkit.yaml`](../buildkit.yaml):

1. **`versioner` step** — regenerates `lib/src/version.versioner.dart`
   (`CoreBridgeVersionInfo`: version, build number, git commit, build time)
   from `pubspec.yaml` + git state.
2. **`compiler` step** — per-platform `dart compile exe bin/core_bs.dart`
   pipelines (details below).

```bash
# Via the workspace build tool (runs the versioner, then compiles):
tom build tom_core_bridge

# Or compile the entry point directly for the current platform only:
dart compile exe bin/core_bs.dart -o core_bs
```

### Cross-compilation

The `darwin-arm64` host compiles **for itself and all Linux targets** in one
pass (`targets: [darwin-arm64, linux-x64, linux-arm64, linux-armhf]`). Other
Unix hosts (`darwin-x64`, `linux-*`) compile for themselves only; Windows
(`win32-*`) compiles `core_bs.exe`. A `postcompile` step runs
`chmod -R +x` on the output directory for macOS/Linux.

## Where the artifact lands

Compiled binaries are published under `$TOM_BINARY_PATH/<platform-vs>/`:

| Platform (`platform-vs`) | Artifact path |
| --- | --- |
| `darwin-arm64` | `$TOM_BINARY_PATH/darwin-arm64/core_bs` |
| `darwin-x64` | `$TOM_BINARY_PATH/darwin-x64/core_bs` |
| `linux-x64` | `$TOM_BINARY_PATH/linux-x64/core_bs` |
| `linux-arm64` | `$TOM_BINARY_PATH/linux-arm64/core_bs` |
| `linux-armhf` | `$TOM_BINARY_PATH/linux-armhf/core_bs` |
| `win32-x64` | `$TOM_BINARY_PATH/win32-x64/core_bs.exe` |

`$TOM_BINARY_PATH` is the workspace binary root (the `tom_binaries` layer).

## Point the VS Code extension at it

The extension launches a bridge process from its **active bridge profile**.
Profiles live in the `bridge` section of `tom_vscode_extension.json`:

```jsonc
{
  "bridge": {
    "current": "core",                  // active profile key
    "profiles": {
      "core": {
        "label": "Tom Core Bridge",
        "command": "/abs/path/to/$TOM_BINARY_PATH/<platform-vs>/core_bs",
        "args": [],
        "cwd": "<bridge working dir>",   // optional; defaults to workspace root
        "runPubGet": false               // compiled binary needs no pub get
      }
    }
  }
}
```

The active profile's `command` / `args` / `cwd` / `runPubGet` drive
`DartBridgeClient.startWithAutoRestart`
(`tom_vscode_extension/src/handlers/restartBridge-handler.ts`):

- **Compiled binary** — set `command` to the published `core_bs` executable and
  leave `args` empty; set `runPubGet: false`.
- **From source** — set `command` to `dart` and
  `args: ["run", "<path>/tom_core_bridge/bin/core_bs.dart"]`. When `command` is
  `dart` and `args` are omitted, the extension falls back to
  `dart run bin/tom_bs.dart` (the **base** server) — so for `core_bs` you must
  supply the explicit `args`.

Switch the active profile with the **`tomAi.bridge.switchProfile`** command;
restart applies it (the bridge auto-restarts on error).

## Troubleshoot a failed launch

All bridge activity is logged to the extension's **Dart Bridge output channel**
(`[VS Code Extension] …` lines, plus `Raw from Dart: …` for every stdout line).
Work the list top-down:

| Symptom | Cause / fix |
| --- | --- |
| `Bridge binary not found: <path>` | The handler `fs.existsSync(command)` check failed. The profile `command` path is wrong or the binary was never built — run `tom build tom_core_bridge` and point `command` at the published `$TOM_BINARY_PATH/<platform-vs>/core_bs`. |
| `Bridge configuration missing` / `Working directory not found` | No `bridge` section in `tom_vscode_extension.json`, or the profile `cwd` does not exist. Add/fix the profile. |
| Process starts then exits immediately, no `[BSTART]` line | The binary failed to start. A healthy server prints `[BSTART] VS Code Bridge Server started` once stdin is wired. Check the output channel and the process stderr for a stack trace. |
| `dart compile exe` fails (building from scratch) | Known blocker: `core_bs` links `tom_core_d4rt`'s generated bridges, which currently fail to compile (the B3/B4 `tom_d4rt_generator` emission defects tracked in the `tom_core_d4rt` refactoring plan), and this package additionally needs a `tom_d4rt` version realignment (`dart pub get` after upgrading `tom_core_d4rt`). The entry point itself is trivial; the binary builds once those upstream issues resolve. See [`../CHANGELOG.md`](../CHANGELOG.md) "Known issues". |
| Bridge runs but Tom Framework classes are missing in scripts | The extension is running the **base** `tom_bs` (the `dart`-command fallback), not `core_bs`. Confirm the active profile supplies the explicit `core_bs` command/args and was applied (`tomAi.bridge.switchProfile` → restart). |
| `Running dart pub get …` hangs/fails on a compiled binary | A compiled `core_bs` needs no `pub get`; set `runPubGet: false` on the profile. |

## Verify a healthy launch

After a successful start the output channel shows:

```text
[VS Code Extension] INFO Starting Dart bridge: <command> <args>
[BSTART] VS Code Bridge Server started
```

From that point every D4rt script run through the bridge has the full Tom
Framework bridge set available in addition to the DCli and VS Code APIs.

For a one-command end-to-end check that the binary builds, starts, and answers
a bridge request, see the [smoke test](smoke_test.md)
(`dart run tool/smoke_test.dart`).
