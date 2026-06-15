## 1.0.0

- Initial release of the D4rt scripting tool with full Tom Framework bridge
  support: an interactive REPL and headless replay runner.
- `TomDartscriptBridges.register` wires the `tom_d4rt_dcli` base bridges plus
  generated bridges for `tom_basics`, `tom_reflection`, `tom_core_kernel`,
  `tom_core_server`, `tom_build`, `tom_dist_ledger`, `tom_process_monitor`,
  `tom_doc_scanner`, `tom_doc_specs`, `tom_md2latex`, and `tom_md2pdf`.
- VS Code editor integration (default port `19900`) and named-session,
  replay, and introspection (`info` / `classes`) REPL commands.

### Documentation

- Authored the package `README.md`: overview, bridged-packages table, build /
  bridge-generation workflow, full CLI options reference, headless test mode,
  and the `TomDartscriptBridges.register` library-usage example. No source
  changes.
- Authored a per-module bridge reference under `doc/` — one document per bridged
  package (`tom_basics`, `tom_reflection`, `tom_core_kernel`, `tom_core_server`,
  `tom_build`, `tom_dist_ledger`, `tom_process_monitor`, `tom_doc_scanner`,
  `tom_doc_specs`, `tom_md2latex`, `tom_md2pdf`) plus `build.md`, `cli.md`, and
  `testing.md` — each listing the classes/enums/extensions the module owns and
  the surfaces it re-exports.
- Final review: cross-checked every module doc against the names actually
  registered in the generated `*_bridges.b.dart` files. Named the previously
  implicit module-owned types so the docs match the registration exactly — the
  kernel's nullable boxed timezone values (`TomNOTimezoned`, `TomNOZonedDate`,
  `TomNOZonedTime`, `TomNOZonedDateTime`), the server's MariaDB / annotation-
  analyzer exceptions (`MariadbDatasourceException`,
  `MariadbPreparedStatementException`, `TomAnnotationAnalyzerException`,
  `TomAnnotationAnalyzerSyntaxException`), and the re-exported `RetryableResponse`
  HTTP extension in the dist-ledger and process-monitor docs. All cross-module
  re-exports remain documented by reference in each module's "Re-exported
  surfaces" section. No source changes.

### Known issues

- The full `d4rt` binary does not yet compile because of generator-emission
  defects in three generated bridge files (owned by `tom_d4rt_generator`):
  `tom_core_server` bridges a non-existent top-level `main()` and emits a
  `withConnection` callback with `FutureOr<Object?>` vs the native
  `FutureOr<Object>`; the `tom_dist_ledger` bridge imports a `part of` file
  (`call_callback.dart`), which the CFE rejects. The analyzer is clean and every
  bridge's behaviour is verified at the d4rt level in isolation; the
  full-binary replay suite (`test/d4rt_replay_test.dart`) is blocked until these
  are fixed upstream.
