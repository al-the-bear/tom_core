## 1.0.13

### Tests

- **Covered the `DocSpecsSkeletonGenerator` bridged surface the replays
  previously only pinned by reachability (RCJ8).** During RCK17 the tom_doc_specs
  IO/scan surfaces were driven live, but `DocSpecsSkeletonGenerator` was left
  reachability-pinned in `test_d4rt_tom_doc_specs.d4rt`. It is now driven live
  over the same self-contained mini-1.0 fixture schema: `generate(schema)`
  returns the skeleton markdown as a `String` (it does not write files itself —
  the caller persists it), so the replay asserts the emitted structure (the
  `<!-- docspec: mini/1.0 -->` comment, the `# [overview-overview] Overview`
  section headline, and the `TODO: Add content for this section.` text-required
  placeholder), then persists it with `TomFs.write` and confirms the written
  file round-trips (`TomFs.exists` + `TomFs.read(...).contains(...)`). No bridged
  behaviour changed.

## 1.0.12

### Tests

- **Covered the kernel/server bridge surfaces the replays previously deferred
  because they need a value fixture or a live database (RCK20).** Three gaps
  from `completion_steps.tom_core.md` are now closed:
  - *Timezone value types (§17 timezoned).* `TomZonedTime` / `TomZonedDate` /
    `TomTimezoned` default their timezone to `TomTimezone.utc`, which wraps the
    `timezone` package's predefined `tz.UTC` constant — so they construct
    without `initializeTimeZones()`. `test_d4rt_tom_core_kernel.d4rt` now drives
    their constructors and getters directly, plus the observable wrappers
    `TomOZonedTime` (box/get/set) and the `TomOTimezoned.noDateTime` sentinel
    (which boxes the Unix epoch, so it is *not* null).
  - *Isolate pooling (§17 isolate_pooling).* `TomWorker.spawn` /
    `TomWorkerPool.withSize` start real OS isolates whose entrypoint would have
    to host the interpreter — impossible from a replay — so the replay covers
    only the connection-free static surface (`readyMessage`, `isMainIsolate`,
    `canSendToCreator`, `workerCount`, `TomExecutor.noResult`) and class
    reachability; the spawn/execute paths stay covered by the native kernel
    isolate tests.
  - *`MariaDbDatasource` (server datasource).* The connection-free surface
    (`parsePort` / `normalizePort` / field setters / `connected` /
    `isOperational` before connect) is asserted in
    `test_d4rt_tom_core_server.d4rt`. The genuinely DB-dependent path lives in a
    new **live-DB replay** `test_d4rt_tom_core_server_db.d4rt`: it opens a real
    connection (setting fields + `connect()`, bypassing the reflection-based
    `initialize`) and drives CREATE/INSERT/rollback-transaction/
    commit-transaction/DROP/close as bare auto-awaited statements, verified via
    the synchronous `connected`/`isOperational` getters and a post-statement
    `verify(true, …)` (a throw would abort before it).
- **Made the live-DB replay cleanly skippable.** A new `tom_core (db)` group in
  `d4rt_replay_test.dart` TCP-probes `127.0.0.1:3309` and `markTestSkipped`s
  when nothing answers, so `testkit :test` stays green on machines without a
  database. Coordinates are pinned to the RCK13 docker fixture
  (`tom_core_server/docker-compose.test.yaml`); the d4rt gate does **not** read
  the `TOM_CORE_SERVER_TEST_DB_*` overrides that the dart-side RCK13 suites
  honor. Verified both paths: 25/25 green with the fixture up (the DB replay
  runs), all-skipped with it down.

## 1.0.11

### Tests

- **Drove the `tom_process_monitor` network/IO classes with a live localhost
  fixture (RCK19).** Unlike `tom_dist_ledger` (RCK18), every
  `tom_process_monitor` network class has a *synchronous* constructor, so it
  yields a real instance rather than a raw `Future` — which makes a genuine
  self-contained fixture possible inside the replay.
  `test/replay/test_d4rt_tom_process_monitor.d4rt` now drives real bind/unbind
  lifecycles (async `start`/`stop` run as bare statements that auto-await,
  verified via the observable `isRunning` toggle) for `AlivenessServer`,
  `AlivenessServerHelper` (with `addRoute`), and `RemoteApiServer` (constructed
  with real `RegistryService` + `ProcessControl` deps), plus real file IO for
  `LogManager` (`initialize`/`info`/`warn`/`error`/`getProcessLogDir`/`close`),
  `RegistryService` (`initialize` creates the dir, `save` writes the registry
  file through its file lock, `load`), and `LocalProcessMonitorClient`
  (`register`/`deregister` write the registry file) — each verified through the
  file appearing on disk. `AlivenessChecker` and `RemoteProcessMonitorClient`
  are constructed and disposed. The return-value-only async methods
  (`isProcessAlive`/`checkAlive`/`fetchPid`, which stay raw `Future`s when
  captured) and the process-spawning entry points (`ProcessMonitor.start`,
  `ProcessControl.startProcess`) are covered by their synchronous construction +
  value surface; the abstract `ProcessMonitorClient` base and `ServerDiscovery`
  stay reachability-pinned. Every server is stopped and every temp tree removed
  before the replay exits, so it terminates cleanly (330 lines executed). No
  bridge or public-behaviour change.

## 1.0.10

### Tests

- **Extended the `tom_dist_ledger` replay to cover every network class'
  synchronous construction + value surface (RCK18).**
  `test/replay/test_d4rt_tom_dist_ledger.d4rt` now exercises the sync surfaces of
  `SpawnedCall` (complete/fail, `result`/`resultOr`/`resultOrNull`, `kill`),
  `CallFrame` (default `FrameState.active`, `isStale`, state setter, `toJson`/
  `fromJson` round-trip), `LocalLedger` (constructed over a temp fixture, getters,
  `heartbeatInterval`, `dispose`), `RemoteLedgerClient` (constructed inert,
  getters, `dispose`), the `Ledger`/`Operation`/`Call` callback carriers
  (`LedgerCallback`, `OperationCallback`(+`onFailure`), `CallCallback`(+`cleanup`)),
  `OperationHelper`'s poll builders (`pollFile`/`pollUntil`/`pollFiles`), and
  `CleanupHandler` (`instance`, `register`/`unregister`/`dispose`). The async-only
  classes (`LedgerServer`, `RemoteOperation`, `LocalOperation`, and the driven
  `Ledger`/`Call` roles) stay reachability-pinned: a driven loopback fixture is
  impossible inside the replay harness because d4rt cannot top-level-`await`, an
  async factory assigned to a variable stays a raw `Future` (never resolves to the
  object), and a `.then()` continuation runs after `testSummary()` and re-triggers
  the interpreter's async state-machine bug. Both hazards were re-confirmed
  empirically before falling back to the documented sync-surface coverage. No
  bridge or public-behaviour change.

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
