## Unreleased — 2026-07-07

### Changed

- **Relicensed to BSD 3-Clause.** The whole `tom_core` package set — this
  package and its `tom_core_*` / `tom_flutter_*` siblings — now ships under the
  BSD 3-Clause license, replacing the previous proprietary license. This
  supersedes the 2026-06-24 note below, which had switched this package from its
  originally scaffolded BSD 3-Clause license to the proprietary one.

## Unreleased — 2026-06-24

### Fixed

- **Build/smoke-test blockers resolved.** The `core_bs` binary now **builds**
  and the smoke test **passes** (`dart run tool/smoke_test.dart` →
  `[SMOKE] PASS`). The upstream `tom_core_d4rt` codegen defects that previously
  blocked compilation are fixed: the `tom_core_server` bridge no longer
  registers a spurious top-level `main` global and its MariaDB
  `withConnection`/`transactional` callbacks use a consistent
  `FutureOr<Object?>`; the `tom_dist_ledger` bridge imports its owning libraries
  instead of a `part of` file. `tom_d4rt` resolves to 1.8.24 (≥ the required
  1.8.19) and `dart analyze` is clean across the generated bridges. The
  "Known issues" block under 1.0.0 below is retained as history.

## 1.0.0

- Initial release of `core_bs`, the extended VS Code bridge server: the
  `tom_vscode_bridge` server started with `TomDartscriptBridges.register` as an
  additional bridge registrar, exposing the full Tom Framework D4rt bridge set
  (from `tom_core_d4rt`) alongside the base DCli and VS Code API bridges.
- Bridged packages: `tom_basics`, `tom_reflection`, `tom_core_kernel`,
  `tom_core_server`, `tom_build`, `tom_dist_ledger`, `tom_process_monitor`,
  `tom_doc_scanner`, `tom_doc_specs`, `tom_md2latex`, and `tom_md2pdf`.
- `buildkit.yaml` build pipeline: a `versioner` step
  (`lib/src/version.versioner.dart`, `CoreBridgeVersionInfo`) plus per-platform
  `dart compile exe` pipelines that publish `core_bs` into
  `$TOM_BINARY_PATH/<platform>/` and cross-compile the Linux targets from
  macOS ARM64.

### Documentation

- Authored `README.md`: purpose (extended bridge server vs. base `tom_bs`), the
  current 11-package bridged set, the architecture (thin entry point delegating
  to `VSCodeBridgeServer` + `TomDartscriptBridges.register`), the build workflow
  (`tom build` / `dart compile exe`), and VS Code registration (point the
  extension's bridge command/args at `core_bs`).
- Documented `bin/core_bs.dart` in place: `// Why:` comments for the
  `additionalBridgeRegistrars` layering seam (the `BridgeRegistrar` callback
  shape) and for the JSON-RPC-like stdin/stdout protocol that
  `VSCodeBridgeServer.start()` wires; refreshed the library doc-comment.
- Authored `doc/operations.md` — operational runbook: build pipeline and
  per-platform artifact locations (`$TOM_BINARY_PATH/<platform-vs>/core_bs`),
  the bridge-profile configuration shape in `tom_vscode_extension.json`,
  profile switching, and a troubleshooting table keyed on the actual launch log
  strings. Cross-linked from `README.md` (Operations section).

### Tooling and cleanup

- Added `tool/smoke_test.dart` and `doc/smoke_test.md` — a build-aware smoke
  test (and the equivalent manual procedure) that builds `core_bs`, launches
  it, and verifies it answers the minimal `echo` bridge request. While the
  binary cannot compile (see Known issues) the runner SKIPs cleanly rather than
  failing; it becomes a live gate once that blocker clears.
- Removed a dead analyzer-suppression block from `analysis_options.yaml` (a
  `**/*.b.dart` exclude and `errors:`/lint overrides copied from the
  bridge-generating sibling `tom_core_d4rt`) — this package has no own generated
  bridges, so the suppressions masked nothing; removing them tightens the gate.
  `dart analyze` is clean.
- Added a `.gitignore` (standard Dart ignores plus the smoke-test temp guard).
- Corrected `LICENSE` to the workspace proprietary license (matching the README
  and the sibling `tom_core_*` packages); it had been scaffolded as BSD 3-Clause
  with a divergent copyright holder.

### Known issues

- The `core_bs` binary does not yet compile in the current workspace state. It
  links the generated `tom_core_d4rt` bridge set, so it shares that package's
  blockers: the `tom_d4rt_generator` codegen defects in the `tom_core_server`
  bridge (a bridged non-existent `main()` and a `withConnection` callback typed
  `FutureOr<Object?>` vs the native `FutureOr<Object>`) and the `tom_dist_ledger`
  bridge (importing a `part of` file). Compilation here additionally requires a
  `tom_d4rt` version aligned with the generated bridges (`dart pub get` after
  upgrading `tom_core_d4rt`). These are upstream concerns tracked in the
  `tom_core_d4rt` refactoring plan; the entry point itself is trivial and the
  binary builds once they are resolved.
