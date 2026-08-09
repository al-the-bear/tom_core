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
Profiles live in the `bridge` section of `tom_vscode_extension.json`. A profile
does **not** hold a command path: it names an entry in the sibling
`bridge.executables` map, which is resolved for the current platform against
`bridge.binaryPath`.

```jsonc
{
  "bridge": {
    "current": "core",                   // active profile key
    "binaryPath": {                      // per-platform binary directory
      "darwin-arm64": "${env:TOM_BINARY_PATH}/darwin-arm64/",
      "linux-x64": "${env:TOM_BINARY_PATH}/linux-x64/"
    },
    "executables": {                     // name → per-platform path
      "core_bs": { "*": "${binaryPath}core_bs" }
    },
    "profiles": {
      "core": {
        "label": "Tom Core Bridge",
        "executable": "core_bs",         // key in `executables` — mandatory
        "args": [],
        "cwd": "${workspaceFolder}",     // optional; defaults to workspace root
        "runPubGet": false               // compiled binary needs no pub get
      }
    }
  }
}
```

`loadBridgeConfig()`
(`tom_vscode_extension/src/handlers/restartBridge-handler.ts`) reads each
profile, requires a string `executable`, and resolves it via
`resolveBridgeExecutable` → `resolveNamedExecutable(profile.executable,
bridge.executables)`. The resolved path plus `args` / `cwd` / `runPubGet` then
drive `DartBridgeClient.startWithAutoRestart`.

Two consequences worth knowing before you edit the file:

- **A profile without `executable` is skipped silently.** `loadBridgeConfig()`
  `continue`s past it, so it never appears in the profile picker. If every
  profile lacks one, the whole config resolves to `undefined` and the only
  message you get is the generic `Bridge configuration missing`.
- **A name that resolves to nothing is skipped the same way.** If
  `executables["core_bs"]` has no entry matching the current platform (exact,
  `<os>-*` wildcard, then `*`), `resolveNamedExecutable` returns `undefined`
  and the profile is dropped.

An `executables` entry is a platform map resolved by exact key
(`darwin-arm64`), then family wildcard (`darwin-*`), then `*`. The value is
expanded for `${binaryPath}`, `${home}`, `${workspaceFolder}`, `${env:VAR}` and
a leading `~`. Use `${binaryPath}core_bs` for a published artifact — a **bare**
name is *not* prefixed with `binaryPath`; it is looked for under the
extension's own `bin/<platform>/` and then on `PATH`. On Windows a value with
no file extension gains `.exe`.

Switch the active profile with the **`tomAi.bridge.switchProfile`** command;
restart applies it (the bridge auto-restarts on error).

## Troubleshoot a failed launch

All bridge activity is logged to the extension's **Dart Bridge output channel**
(`[VS Code Extension] …` lines, plus `Raw from Dart: …` for every stdout line).
Work the list top-down:

| Symptom | Cause / fix |
| --- | --- |
| `Bridge binary not found: <path>` | The handler's `fs.existsSync` check on the resolved path failed. `executables["core_bs"]` points somewhere wrong, `binaryPath` for this platform is wrong, or the binary was never built — run `tom build tom_core_bridge` and confirm `$TOM_BINARY_PATH/<platform-vs>/core_bs` exists. |
| `Bridge configuration missing` / `Working directory not found` | No `bridge` section in `tom_vscode_extension.json`, **or every profile was skipped** (missing `executable`, or an `executable` that resolves to nothing on this platform), or the profile `cwd` does not exist. Add the `executable` key and a matching `executables` entry. |
| Process starts then exits immediately, no `[BSTART]` line | The binary failed to start. A healthy server prints `[BSTART] VS Code Bridge Server started` once stdin is wired. Check the output channel and the process stderr for a stack trace. |
| `dart compile exe` fails (building from scratch) | `core_bs` links `tom_core_d4rt`'s generated bridges, so a failure here is usually a version skew between the two. Run `dart pub get` in this package to realign `tom_d4rt` after upgrading `tom_core_d4rt`, then retry; `dart analyze` in `tom_core_d4rt` localises a genuine codegen defect. |
| Bridge runs but Tom Framework classes are missing in scripts | The extension is running the **base** `tom_bs`, not `core_bs` — most often because the `core` profile was skipped and `loadBridgeConfig()` fell back to the first profile that did resolve. Confirm the active profile's `executable` is `core_bs` and that it was applied (`tomAi.bridge.switchProfile` → restart). |
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
