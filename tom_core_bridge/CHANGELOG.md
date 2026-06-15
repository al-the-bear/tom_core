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
  extension's bridge command/args at `core_bs`). No source changes.

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
