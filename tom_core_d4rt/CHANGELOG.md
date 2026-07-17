## 1.0.9

### Tests

- **Completed the `tom_doc_specs` replay to full member-level coverage by
  exercising the IO/scan surfaces over a live self-contained fixture (RCK17).**
  `test/replay/test_d4rt_tom_doc_specs.d4rt` now drives `SchemaLoader.loadSync`,
  `SchemaResolver.resolveSync`/`resolveByDocumentFilenameSync`,
  `SchemaDiscovery.listSchemasInSync`/`listSchemasSync`, and the `DocSpecs`
  facade (`loadSchemaSync`, `scanDocumentSync`, `scanDocumentsSync`,
  `scanTreeSync`, `validate`, `listSchemas*Sync`) against a temp directory tree
  written (and removed) inside the replay — two schema-folder layouts (a schema
  file directly under `.tom/docspecs-schema/` for ID resolution, and one in a
  `*.<type>/` subfolder for the `<title>.<type>.ds.md` convention) plus a
  minimal `.ds.md` document. The sync variants are covered because d4rt cannot
  top-level-`await` and they traverse identical IO code paths to their async
  twins. Only `AiValidator` (an abstract LLM-injection interface with no
  standalone behaviour) stays reachability-pinned. No bridge or public-behaviour
  change.

## 1.0.8

### Tests

- **Completed the `tom_build` replay to 60/60 by covering the five IO drivers
  over a live self-contained fixture (RCK16).**
  `test/replay/test_d4rt_tom_build.d4rt` now exercises `TomFs` (25 methods),
  `TomGlob` (8), `TomShell` (7), `WorkspaceAnalyzer`, and
  `ReflectionGeneratorRunner` against a temp directory tree created (and
  removed) inside the replay — the d4rt binary runs with full IO access, so the
  fixture is self-contained. Two d4rt execution quirks shaped the approach:
  top-level `await` triggers an interpreter state-machine bug and is avoided,
  and async methods (`analyze`/`generate`/`build`) are driven as bare
  statements (which auto-await) and verified via observable side effects rather
  than return values. `TomShell.pipe` is covered via its stdout code path; its
  `input` argument is silently ignored (does not wire stdin) — filed as RCJ1,
  not fixed here (no bridged public-behaviour change).

## 1.0.7

### Tests

- **Tightened the `tom_basics` replay's TomLogger push/pop assertion to the
  RCE6 LIFO restore value (RCK15).** `tom_basics` 1.0.1 — which ships the RCE6
  `TomLogger` push/pop LIFO fix — is now published to pub.dev, and
  `tom_core_d4rt` pins `tom_basics: ">=1.0.1"` so the replay resolves the fixed
  package rather than the pre-RCE6 1.0.0. The previously coverage-only post-pop
  assertion in `test/replay/test_d4rt_tom_basics.d4rt` (a bare `verifyNotNull`)
  is now `verifyEquals(logger.logLevel.levelPattern, 8, ...)`, asserting that
  `popLogLevel()` restores the pre-push level (`info`=8) — the real LIFO scope
  contract. No bridge or public-behaviour change.

## 1.0.6

### Tests

- **Drove the `tom_md2latex` replay to exhaustive connection-free per-bridge
  coverage (RCK14).** `test/replay/test_d4rt_tom_md2latex.d4rt` now references
  every class the `tom_md2latex_bridges.b.dart` container registers — a
  registered name→reference cross-check (excluding comment lines) confirms zero
  gaps across all 23 bridges. The two previously name-uncovered classes are now
  covered: `MarkdownElement` (the empty `sealed` base — pinned for reachability
  and exercised via `is MarkdownElement` subtype checks on every concrete
  element) and `ParsedMarkdown` (constructed directly to assert all six getters
  — `title`/`author`/`date`/`generateToc`/`tocDepth`/`elements` — plus a
  defaults case the `# Hello` parse cannot reach). Remaining connection-free
  gaps were filled at the same time: `CodeBlockElement.code`, `LinkElement.text`,
  `TableElement.rows`/`alignments`, `MarkdownParserOptions.asciiDiagramPatterns`,
  `MarkdownParser.content`/`options`, `MdLatexConverter.convert` (the pure,
  filesystem-free entry point) plus its getters, `MdLatexConverterOptions`
  defaults, `MdLatexConverterResult.converted`, `ConversionError` construction +
  `toString`, and a representative set of `LatexMacros` pure static string
  transforms (`bold`/`italic`/`heading`/`paragraph`/`inlineCode`/
  `horizontalRule`/`beginDocument`/`endDocument`/`makeTitle`/`unorderedList`/
  `orderedList`/`blockQuote`/`link`/`textToSlug`/`escapeText`/`image`/
  `codeBlock`). The only members not exercised are the IO/async surfaces that
  require a live filesystem — `MdLatexConverter.findMarkdownFiles`/`convertAll`/
  `convertFile` and the `Md2Latex.convertFile*`/`convertDirectory` helpers —
  documented as integration-only in the replay header. Bridged public behaviour
  is unchanged.

## 1.0.5

### Tests

- **Drove the `tom_doc_specs` replay to exhaustive connection-free per-bridge
  coverage (RCI5).** `test/replay/test_d4rt_tom_doc_specs.d4rt` now references
  every *connection-free* class the `tom_doc_specs_bridges.b.dart` container
  registers — a registered name→reference cross-check (excluding comment lines)
  confirms zero gaps across all 31 bridges; the only members not exercised are
  the IO/scan surfaces that require a live filesystem (`SchemaResolver.resolve*`,
  `SchemaDiscovery.listSchemas*`, and the top-level document-scanning helpers).
  The five previously-uncovered classes are now covered: `SchemaExpander` (pure
  `expand` — nested-field placeholders, list generators with separators,
  `.length`, the `uppercase` transform, literal pass-through of unresolvable
  patterns); `PromptExpander` (pure `expand` — `${id}`/`${type}`/`${text}`/
  `${index}`/`${lineNumber}` placeholders, unknown-key literal pass-through);
  `SchemaResolver` (default constructor, the `schemaExtensions` getter, and the
  pure statics `extractDocumentType`/`isDocSpecDocument`); `SchemaDiscovery`
  (default constructor — its `listSchemas*` methods are IO); and `AiValidator`
  (abstract-interface reachability). Empirically confirmed during this pass: the
  `${...}` placeholder syntax must be escaped as `\${...}` in `.d4rt` files
  (d4rt would otherwise interpolate it) — in **both** the argument and the
  description strings.

## 1.0.4

### Tests

- **Drove the `tom_build` replay to exhaustive connection-free per-bridge
  coverage (RCH5).** `test/replay/test_d4rt_tom_build.d4rt` now references every
  *connection-free* class the `tom_build_bridges.b.dart` container registers — a
  registered name→reference cross-check (excluding comment lines) confirms the
  only remaining gaps are the five IO-driver classes that require a live
  filesystem/process (`WorkspaceAnalyzer`, `ReflectionGeneratorRunner`,
  `TomShell`, `TomFs`, `TomGlob`). The 17 previously-uncovered value/config and
  static-utility classes are now exercised: the value carriers
  `ReflectionGeneratorRunnerResult`, `TomShellException`, `MetadataModes`,
  `WorkspaceModes`, `ModeTypeConfig`, `ModeEntry`, `ActionModeConfiguration`,
  `ActionModeEntry`, `ActionConfig`, `GroupDef`, `ProjectTypeDef` (constructed
  and their getters asserted); and the static utilities `TomEnv`
  (`resolveWith`/`has`/`isMacOS`), `TomMaps` (`merge`/`flatten`/`get`/`has`),
  `ScriptYaml.parse`, `TomZoned` (`current`/`root`/`has`), and the
  `ToolContext.isInitialized` / `TomWs.isLoaded`/`osName` context probes. This
  brings tom_build to 55/60 connection-free classes covered, with only the five
  IO drivers deferred (see the RCI residual). Empirically confirmed during this
  pass: `TomMaps.get` performs a **literal** single-level key lookup (not
  dotted-path traversal), so the assertion uses a flat-key get.

## 1.0.3

### Tests

- **Drove the `tom_basics` replay to exhaustive per-bridge coverage (RCG5).**
  `test/replay/test_d4rt_tom_basics.d4rt` now references *every* class the
  `tom_basics_bridges.b.dart` container registers — a registered name→reference
  cross-check confirms zero gaps (11/11). The one previously-uncovered class,
  `TomLogger`, was exercised at the class level (it had only been reached
  indirectly via the `tomLog` global): direct construction, the static
  fixed-width label constants (`INFO`/`ERROR`/`SEVERE`/`TRAFFIC`), the static
  `globalSettingInfoEnabled` enable-flag round-trip and `fallback` instance, the
  level stack (`setLogLevel`, `setLogLevelByName`, `pushLogLevel`/`popLogLevel`),
  the per-name overrides (`addNameLevel`/`getNameLevel`/`removeNameLevel`,
  `setLogLevelExceptions`), every level method
  (`info`/`debug`/`warn`/`error`/`trace`/`traffic`/`severe`/`fatal`/`status`),
  `output`, the `logOutput` getter/setter, and `toString`. Note: the package
  resolves the *published* `tom_basics 1.0.0`, which predates the RCE6 LIFO fix,
  so the post-pop assertion is coverage-only (that `popLogLevel` executes and
  leaves a valid level); tightening it to the RCE6 restore value awaits
  republishing `tom_basics` and bumping the constraint here. Replay green
  (Result: PASSED); full 24-group harness green; `dart analyze` clean. No source
  or bridge change — bridged public behaviour is unchanged.

## 1.0.2

### Tests

- **Extended the `tom_reflection` replay to exhaustive per-bridge coverage
  (RCF5).** `test/replay/test_d4rt_tom_reflection.d4rt` now references *every*
  class the `tom_reflection_bridges.b.dart` container registers — no bridged
  type is left unexercised. Added the previously-uncovered constructable markers
  and value objects (`InvokingMetaCapability(Type)` with its `metadataType`
  getter; `Comment(text, trimmedText, isDocComment)` with all three getters
  round-tripping), the remaining capability class tokens
  (`MetadataCapability`, `TypeRelationsCapability`,
  `LibraryDependenciesCapability`, `UriCapability`,
  `TypeAnnotationQuantifyCapability`, `ReflecteeQuantifyCapability`,
  `GlobalQuantifyCapability`, `GlobalQuantifyMetaCapability`,
  `ImportAttachedCapability`), and the remaining mirror interfaces plus
  `SourceLocation` (`ClosureMirror`, `FunctionTypeMirror`, `TypeVariableMirror`,
  `TypedefMirror`, `LibraryDependencyMirror`, `CombinatorMirror`). A registered
  name→reference cross-check confirms zero gaps. Replay green (Result: PASSED,
  206 lines executed); full 24-group harness green. No source or bridge change —
  bridged public behaviour is unchanged.

## 1.0.1

### Documentation

- **Added a per-module API reference under `doc/api_reference/`.** Because
  `tom_core_d4rt` is a bridge package, the reference documents the package's own
  thin public surface — not the upstream types it forwards. Four files plus an
  index: `api_summary_registration.md` (`TomDartscriptBridges`),
  `api_summary_cli.md` (`D4rtRepl`, `d4rtMain`, `TomVersionInfo`),
  `api_summary_bridges.md` (the shared static contract of the eleven generated
  `Tom*Bridge` containers, a class→package map, and the relaxer factory
  functions), and `api_summary_index.md` (type index). Each bridge container
  entry links to the bridged package's authoritative guide under `doc/`, which
  remains the source of truth for the bridged types. Reconciled the `pubspec`
  version (`1.0.0` → `1.0.1`) with this already-open CHANGELOG section and linked
  the reference from the README. No source or bridge change.

### Examples

- **Added runnable DartScript examples for the key bridge modules.** New
  `example/` folder with one `.d4rt` script per module — `01_crypto_example.d4rt`
  (Argon2 hash + verify round-trip, salt generation, JWT/RSA types),
  `02_logging_example.d4rt` (`TomLogger` construction, level by enum/name, log
  lines per severity), and `03_security_example.d4rt` (principal model, ACL
  access checks, bearer auth, resource-role authorization). Each prints real
  runtime results in normal mode and self-asserts with `verify*` in `-test`
  mode; `example/run_examples.sh` runs all three (3/3 green). Added an
  `example/README.md` and an Examples section to the package README. No source
  or bridge change.

### Testing

- **Wired every bridge-module replay test into the Dart harness.** The
  `test_d4rt_tom_doc_scanner`, `test_d4rt_tom_doc_specs`, `test_d4rt_tom_md2latex`,
  and `test_d4rt_tom_md2pdf` replay files existed under `test/replay/` but were
  not referenced by `test/d4rt_replay_test.dart`, so `dart test` / `testkit`
  never ran them. Added a group per module; the harness now covers all 11
  bridged Tom packages (`d4rt test` is 24/24 green). No source or bridge change.

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
