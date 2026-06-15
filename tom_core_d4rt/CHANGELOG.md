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
