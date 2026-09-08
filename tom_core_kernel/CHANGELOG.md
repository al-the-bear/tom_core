## 1.1.16

The largest release since 1.0: three new modules (`scheduling/`,
`preferences/`, and the file-transfer half of `http_connection/`), the second
authentication pass, the deployment's own principal, and a set of deliberate
API narrowings. Read the **Changed** section before upgrading — several public
members became read-only or non-overridable, which is a compile break for
anyone who was writing them.

### Added

- **`TomReflectionInfo.unknownFields` — the strict-mode question, asked in
  advance (tcincb119).** `strictUnknownFields` answers it as the walk goes and
  stops at the first offender, in this module's own words. That is the wrong
  shape for a caller binding a *document* it owns — a configuration block, a
  settings map — which wants to name every mistake at once, in its own
  vocabulary, and to say which file the keys came from. `unknownFields(o,
  values)` returns the keys naming no writable declaration on `o`, in the order
  the map lists them.

  It applies the same rule as the field walk, so the two cannot drift, and the
  suite pins that agreement directly: every key it names is one a strict
  `setValues` rejects, and every key it passes over is one a strict `setValues`
  accepts. A member that exists but cannot be written is not reported — it is
  not unknown. A class that takes the map over entirely (a `TomClass`, a
  `fromJson` constructor, a `jsonDecode` hook) answers empty, because what
  counts as a known key is then theirs to define.

  `tom_core_server` is the first consumer: its data-source registry rejects a
  settings key that binds no field of the configured driver.

### Fixed

- **Every remote log record said it came from `"RDEF"` (tcincb110).**
  `TomRemoteLogMessage.globalSettingSenderId` was documented as the identifier
  saying which client sent a record, and defaulted to that placeholder. A
  workspace grep found no application assigning it — not `tom_core_server`, not
  `tom_uam_server`, not any of the four sample servers — so every record from
  every application carried the same sender.

  Not cosmetic: `TomRemoteLogServer` names its per-client streams
  `"<sender>_<isolate>"`, so a deployment aggregating several servers into one
  collector wrote them all into one file set distinguished only by isolate
  name — which distinguishes nothing when the servers are alike, and a
  deployment of several servers is the case a collector exists for.

  The sender is now resolved rather than copied.
  `globalSettingSenderIdResolver` is a `String Function()` asked once per
  record; `globalSettingSenderId` remains, as an accessor pair over it, so the
  value form still reads and assigning it installs a resolver answering that
  constant forever. That is the right form for a client whose name *is* a
  constant and the wrong one for a name settled later — a `tom_core_server`
  deployment names itself in its configuration subclass constructor, which runs
  after the base constructor that installs, so a copy taken at installation
  would be the empty string. Expressing the value over the resolver rather than
  beside it means there is one place the answer comes from and the two
  spellings cannot disagree.

  The default answers **the empty string**, not a placeholder. An unset sender
  now looks unset: `TomRemoteLogServer` files such a record under the isolate
  name alone rather than under `_<isolate>`, because `_worker-1` and
  `client-001_worker-1` sort apart while looking like the same shape, and a
  reader of the directory cannot tell an empty sender from a field that never
  arrived.

  A consumer of `tom_core_server` installs nothing: its configuration installs
  `() => tomAppId` when it registers itself as the isolate's active
  configuration.

### Fixed

- **The lint that stops a library importing its own barrel was reported and not
  enforced (tcincb109).** Six `http_connection` files once imported
  `package:tom_core_kernel/tom_core_kernel.dart`, the barrel that exports them.
  Those imports were repaired earlier, and the repair leaned on
  `prefer_relative_imports`, enabled in `tom_ai/core/analysis_options.yaml`, to
  stop the shape returning.

  It would not have. The rule's default severity is `info`, and `dart analyze`
  prints an info and exits **zero** — measured by planting a barrel import and
  reading the exit code, not inferred from the configuration. The workspace's
  quality gate is that command, so a library importing itself would have been
  printed among the output of a passing run.

  The rule is now raised to `warning`, which makes the same violation exit 2.
  Nothing else moved: every Dart and Flutter package in `tom_ai/core` analyzes
  exactly as it did before, the raise having no violations to find.

  `test/import_convention_test.dart` gains three tests. Two are the shape
  itself — no `lib/` library imports the barrel, and the severity in the shared
  options is still `warning` or `error`, because a lint is load-bearing only
  while the gate can fail on it and a severity is one line for a later edit to
  lower. The third is the counterpart: every module directory under
  `lib/src/tombase` is exported by the barrel, since `lib/src` files stop
  reaching for the barrel only while the barrel still reaches them.

  The barrel-import scan matches a directive rather than any line, unlike the
  neighbouring `src/` rule. A dartdoc that shows a consumer
  `import 'package:tom_core_kernel/tom_core_kernel.dart';` is showing the right
  thing, and a guard that refused it would argue against the documentation it
  exists to protect.

### Changed

- **The timezone lookups hand out views, not the index (tcincb87).**
  `TomTimezone.timezones` returned `_timezonesMap` and `allWithOffset` returned
  `_timezoneByOffset[offset]` — the internal collections themselves — so
  corrupting the database from outside the class took one line, and both of
  these were run against the build and took effect:

  ```dart
  TomTimezone.allWithOffset(0)!.add(TomTimezone.utc); // bucket 0 gains a duplicate
  TomTimezone.timezones['ZZZ'] = TomTimezone.utc;     // fromName('ZZZ') resolves
  ```

  The index is built once at first access and never rebuilt, so neither
  mutation was ever repaired: both lasted the life of the process. What made it
  worth fixing in code rather than in a sentence is that neither mistake reads
  as one — sorting a returned list, or filtering it with `removeWhere`, is
  ordinary work on what looks like a local result, and the consequence appears
  somewhere else entirely as a later `firstWithOffset` naming a different zone.

  Both getters return `UnmodifiableMapView` / `UnmodifiableListView`, both O(1)
  and neither copying, so a write throws `UnsupportedError` at the call. Copy
  to work with a modifiable one: `Map.of(TomTimezone.timezones)`,
  `[...?TomTimezone.allWithOffset(0)]`. A defensive copy per call was the
  alternative and was rejected: it never throws, so a caller who mutates it
  expecting the change to stick gets silence, which is today's failure with an
  extra allocation.


- **Six module readmes presented incomplete Key-types tables as inventories;
  all sixteen now cover their module's full exported surface (tcincb26).**
  `security` was missing 23 of 47 names, `observable` 14 of 33,
  `http_connection` 10 of 35, `preferences` 2 of 8, and `resources` and
  `scope_ids` one apiece. A reader takes that table for the module's reference
  surface, so an omission is not a thin document but a wrong one.

  All six were **completed** rather than relabelled. The alternative — saying
  the table is a selection — was the honest branch only if the rows were
  unreadable in bulk, and they were not: the absences fall into families that
  compress. `security` gained eleven rows plus a *Second factor* and an
  *External identity* section; `observable`'s five nullable cells, six
  timezone-aware cells and three ranges became four rows.

  `observable` also had the subtler form of the same defect. Its table read
  `TomNString / TomNInt / TomND…`, which names two of five and leaves a reader
  unable to tell whether the cell they want exists — an ellipsis satisfies a
  reader and no check. The families are spelled out.

- **`test/module_readme_surface_test.dart`**, which holds every module readme to
  the surface its module exports. The class has now been swept by hand three
  times, and `dart analyze` reports none of it. The surface is read from the
  **package barrel** rather than the module directory — a file that exists but
  is not exported is not public, and demanding a readme document it would be
  wrong. A name counts only as a whole word inside an inline code span, because
  a substring search passes vacuously and an ellipsis is what hid part of this
  drift.

  `scheduling` is the one module the barrel exports with no readme at all — 35
  types across 6 files. It is listed in `_withoutReadme` with its reason, and
  the test fails if it gains a readme without being removed from that list, so
  the exemption cannot outlive the gap. Tracked as tcfinal1.

- **`printStackTrace`'s runtime type guard is gone; the field it defended
  against is now `StackTrace?` (tcincb25).** `TomException.printStackTrace`
  narrowed with `raw is StackTrace ? raw : StackTrace.empty` for one reason: the
  inherited `TomBaseException.stack` was `Object?` and publicly mutable, so a
  value no formatter could use still reached it even though every constructor
  in the framework already refused one. `tom_basics 2.0.0` declares the field
  `StackTrace?` (and drops the unchecked `s as StackTrace?` in its own
  `_getStackTrace`), so the guard has nothing left to catch and the kernel now
  requires `tom_basics >=2.0.0`.

  **The substitution stayed, and that distinction is the point.** Only the type
  narrowing was dead. `stack` is still nullable and still publicly mutable, and
  passing `null` straight through would fall through to `StackTrace.current`
  inside the formatter and report the call path of the *report* — a
  plausible-looking trace naming none of the failing code. So the line is now
  `stack ?? StackTrace.empty`, and a mutation dropping the `??` fails the test
  that covers exactly that.

  Two of the three tests that covered the guard went with their subject: one
  assigned a `String`, one an `int`, and neither compiles now. The third — that
  an unusable stack must not be replaced by the reporting site — is still
  reachable through `null` and was re-pointed there rather than deleted, since
  the property it protects outlived the type that motivated it.

- **An auto-captured exception trace now leads with the code that created the
  exception, not with the constructors it passed through (tcincb24).** The
  capture in `TomException`'s initializer is taken at the last moment the
  creating code is still on the stack — and therefore also while every
  constructor in the exception's own chain is. `new TomException` led every
  trace in the system, a subclass added one more frame per level, and the
  practical cost was that a useful `depth` started at 2 rather than 1 across
  ~30 subclasses.

  The run is bounded by **the exception's own leaf constructor**, `new
  $runtimeType`, which is what makes the rule safe rather than merely short.
  Dropping a leading run of `new …` frames unconditionally would swallow an
  application constructor that happens to raise: the trace of `MyThing()`
  throwing in its own body opens with `new TomException`, `new MyThing`, and
  only the first is noise. Stopping at the leaf keeps `new MyThing`, because
  for a directly constructed `TomException` the leaf *is* the first frame.
  Measured, not assumed — all three shapes were read off real traces before the
  rule was written.

  Both representations are rewritten together. `TomBaseException` derives its
  `stackTrace` string from `stack`, so trimming one and not the other would
  have the raw trace and the string an `autoLog` writes disagree about which
  frame comes first. A caller-supplied `stack` is left alone: nothing above it
  belongs to this class. A trace whose leaf frame is absent is left alone too,
  rather than guessing how much to drop while an exception is being built.

  One existing test asserted the old ordering and said so in its comment; it
  now asserts the new one at `depth: 1`. Three cases were added beside it — the
  subclass chain, the application constructor that must survive, and the
  caller-supplied trace — and each was verified to fail the corresponding
  wrong implementation.

- **`tomExecutionContext` is `final`, and a test keeps it that way
  (tcincb22).** The pre-configured ambient context was declared `var` and
  exported, so any importer anywhere in the workspace could assign to it and
  every other importer would immediately see the replacement. Nothing said it
  was meant to be swapped: its dartdoc documents only reading it, and a sweep
  of the workspace found **no assignment at all** — every use reads
  `.contextMap` or calls `runInContext`, and the two downstream re-exports
  already publish it read-only (`tom_build_cli`'s `D4rtGlobals` as a getter,
  the d4rt bridge as `TomExecutionContext get tomExecutionContext`).

  It was the last reassignable top-level in the package, and the class has now
  been swept by hand twice — once across `json`, once here. So the third sweep
  is `test/no_mutable_globals_test.dart`, which scans `lib/` for a top-level
  binding that is neither `final` nor `const`. `dart analyze` does not report
  one: a mutable global is legal Dart and none of the enabled lints covers it.
  The test plants a `var` beside a `final`, a `const`, a `typedef`, a getter
  and a function, and requires the scanner to catch exactly the first — a scan
  that matched nothing would satisfy an is-empty assertion while proving
  nothing.

  The rule is about *reassignment*, not mutation: a `final` holding a growable
  collection is still mutable content, and several here are. What the test
  refuses is the slot being swapped.

### Documentation

- **`doc/analyzer_analysis.json` and its builder configuration are removed
  (tcincb86).** An 18.5 MB analyzer dump sat under `doc/`, which is
  hand-authored by workspace rule, and `build.yaml` plus `tom_analyzer.yaml`
  configured a `tom_analyzer:tom_analyzer` builder to regenerate it. No such
  package is a dependency and none exists here, so a full `build_runner build`
  ran the reflection generator and left the dump untouched: the configuration
  was inert and the file was frozen at whatever the sources said when it was
  last produced somewhere else.

  The search for a consumer is what settled it. The dump had exactly one
  reader — a `tom_reflector` test — and that test asserted every element the
  analyzer finds is present in the dump, which is a check that *the dump is
  current* and says nothing about the analyzer. So the file existed to be
  verified by the only thing that read it. The test now analyzes the package,
  carries the result through `JsonSerializer` / `JsonDeserializer` in-process
  and compares that, which asks the question worth asking; it is
  mutation-verified by dropping a class from the encoder.

  Three guards carried an exemption for the file — `comments_read_as_is_test`,
  `serialized_form_is_not_rebuilt_test` and
  `tool/check_comments_read_as_is.py` — each justified by "generated, fixed by
  regenerating, never by editing", which was only honest while regenerating was
  possible. All three exemptions go with the file, and
  `tool/check_doc_artifacts.py` drops from one baselined fault to zero.


- **Every module document's Dependencies section is now one table, held to the
  module's imports (tcincb85).** Across the five packages these 57 sections came
  in four different table layouts and 51 were written as prose, which is why
  exactly one of them had ever been checked: a checker tolerant of five formats
  can verify only what each format happens to state, and `| Dependency | Used
  for |` names no importing file at all.

  They are now `| Dependency | Kind | Imported by | For |`, ordered dart,
  package, module and alphabetical within each. The sweep did not only reshape
  them: measured against the imports, the old sections named 208 of the 323
  dependencies these modules actually have, so 115 rows are dependencies no
  document had ever mentioned. `tool/check_module_dependencies.py` holds all of
  it — both directions, the `Imported by` column per dependency, the kind, the
  ordering, and a `For` cell that says something — and self-tests ten
  perturbations, one per fault it can report.

  `For` is prose and is held only to being non-empty. Requiring every name in it
  to resolve was tried and rejected: these cells routinely name a type the
  dependency does not declare, which is the sentence worth writing.


- **Conversion stays on the subclasses, and the documents now give the true
  reason (tcincb84).** Four places said a shared `convertToTz*` declaration is
  impossible because each subclass narrows its return type. Dart permits
  return-type covariance in an override, so it is not: a base
  `TomTimezoned convertToTzSameInstant(TomTimezone)` overridden by
  `TomZonedDate convertToTzSameInstant(TomTimezone)` compiles. The
  documentation was defending the design with a constraint that does not exist.

  What does rule it out is that the three types offer different conversion
  sets. A date has `convertToTzSameInstant` and `convertToTzSameDate`, a time
  has `convertToTzSameInstant` and `convertToTzSameTime`, and a datetime has
  only `convertToTzSameInstant` — it already names an instant, so a re-anchoring
  counterpart would have nothing to move. The one method common to all three is
  therefore the instant-preserving one, which is exactly the wrong default for a
  date and for a time: it is what gives a date a time of day and takes a time
  off 1970-01-01. Hoisting it onto a base class whose values have no declared
  kind would apply that default wherever the kind had not been established, and
  it would compile, so nothing would say so.

  The `TomTimezoned` dartdoc, `doc/timezoned/timezoned.md`, the API mirror and
  the module readme now state that, show the one-line rebuild a base value
  needs, and say what the base type *is* for — the supertype every zoned value
  shares, which is what `TomOTimezoned` binds to.
  `timezoned_shared_members_test.dart` holds all of it: the per-type sets, that
  the base declares none of them, and that the document's table says what the
  code does.

- **`doc/json/json.md`'s Core Components now covers the whole module, not two
  thirds of it (tcincb23).** The section had a subsection per file for
  `map_merge_and_process.dart` and `pretty_json.dart` and none for
  `json_serializable.dart`, so a reader who went there for the module's
  reference surface found two of its three files and no signpost that the third
  was described elsewhere. It also documented `prettyJson` and `prettyJsonLine`
  but not `indentEncoder`, which the module exports.

  `json_serializable.dart` gets a subsection that **points at** the Overview
  rather than repeating it. `TomJsonSerializable` is a contract whose
  interesting part is when *not* to implement it — reflection is the default
  path, an all-`final` DTO is un-deserializable by construction, and hand-rolling
  a codec to keep one trades a diagnosable refusal for something the guidelines
  discourage. That argument has to stay in step with the reflection module, and
  a second copy of it would not.

  `indentEncoder` gets its own entry saying why it is exported at all: both
  formatters take a **`String`** and decode it first, so a caller already
  holding a decoded object would otherwise encode it only to have it parsed
  straight back. It is `final`, so the two-space width is fixed and nothing
  reads it as a setting.

  All 13 public symbols across the three files are now named in the section,
  checked by intersecting it with the barrel's exports rather than by reading.

- **`substituteEnvVars` now says why its one limit stands, not just that it
  exists (tcincb19).** The dartdoc and `doc/json/json.md` already stated that a
  caller passing `Platform.environment` cannot express "this variable is
  deliberately empty". Neither said whether that was a wart awaiting a fix, so
  the question came back as a todo.

  It is not. The limit is the shell's: a script written with `${VAR:-default}`
  cannot be handed an empty value either. The shell's escape is a second form,
  `${VAR-default}`, and adding a counterpart here would not reach the operator
  the limit is about — either form lives in the config file, not in the
  environment they set, so the choice would stay the config author's exactly as
  it is now. A `-` separator is also not available: variable names may contain
  one today, since the placeholder pattern reads everything up to `:` or `}`.

  And the author already has the choice. The gap bites in one combination only
  — the placeholder is `${VAR}` with no default *and* the operator wants empty
  — and writing no default is how an author says the value is mandatory, so the
  surviving placeholder there is the loud failure it is meant to be. Where
  empty is legitimate the author writes `${VAR:}`, and `VAR=` and an unset
  `VAR` then both resolve to empty. All three arms are already pinned by tests.

  No behaviour changed, and the `.env` layer's reasoning stays true:
  `TomEnvFile.resolveEnvironment` drops an empty-valued key *because* the two
  resolve identically here, which a change to the folding rule would have
  quietly falsified.

### Added

- **`TomWorkerPool.isClosed`, so a caller can ask the pool the question it can
  already ask a worker (tcincb17).** `TomWorker` publishes `isClosed`;
  `TomWorkerPool` kept the identical `_closed` field, used it to refuse
  `execute` in two places, and published nothing. A caller holding a pool could
  only learn that dispatch would be refused by calling `execute` and catching
  `isolate.pool_closed.execute_after_close` — by performing the operation they
  were trying to decide whether to perform.

  `workerCount` was not a substitute and is not one now. It reads zero after
  `close`, but it also reads zero for a supervised pool whose workers have all
  died and whose replacements have not yet spawned, so it cannot separate "shut
  down" from "momentarily empty". The two getters answer different questions
  and the dartdoc on each now says which.

  Purely additive. Two cases in `TomWorkerPool > close` cover it — the reading
  before and after `close` plus its idempotence, and the pairing with
  `workerCount` — and both fail if the getter stops tracking `_closed`.

- **`TomScheduler.drain()` — the missing way to wait for what a pass started
  (tcinc584).** A `tick()` claims the runs that are due and *starts* them:
  `_dispatchDue` deliberately leaves each `_runOne` unawaited, so that one slow
  job cannot hold up the next window of a fast one and so `start()` does not
  block a process's startup on the first batch. Both properties are worth
  keeping. What was missing was the other half — any way to ask "and is that
  work done?". Callers had only `pumpEventQueue()`, which is a guess about how
  many microtasks a delivery takes rather than a wait, and the kernel's own
  suite reached for it 31 times. Downstream it was worse than untidy:
  `TomMessageOutbox.tick()` was a one-line forward to `scheduler.tick()` while
  documenting itself as a completed pass, so `messaging_example.dart` asserted a
  delivered count of 1 and observed 0, and every messaging test papered over the
  gap with a pump. `drain()` completes once every run in flight has finished and
  written its outcome to the store — succeeded, scheduled for retry, or failed
  for good — and re-checks after each wave, since a finishing run can leave
  another claimable. `tick()` then `drain()` is a completed pass; `stop()` then
  `drain()` quiesces the scheduler, which is also the graceful-shutdown
  affordance `close()` cannot offer, being synchronous. Implementing it retyped
  `_inFlight` from a run-id-to-job-name map to one carrying a per-dispatch
  completer's future: `_runOne` removes its own entry on the way out, so reading
  a future back out of the map to await it would race the removal that ends it,
  whereas a completer is written once at dispatch and completed once after the
  entry is gone. `tick()`, `stop()` and `close()` now say which of the two they
  are, and `doc/scheduling/scheduling.md` states the pair rather than leaving
  "awaitable" to be read as "awaits the work".

- **`tomSetupTimezones` and `tomSetupTimezonesSync` are exported from the
  barrel (tcinc323).** They never were. `timezones.dart` pulled the
  platform-conditional implementation in with an `import`, which brings names
  into the importing library without passing them on, so neither function
  crossed `package:tom_core_kernel/tom_core_kernel.dart` and neither could be
  called by an application. On native nothing showed: the database is bundled
  and `TomTimezone` loads it synchronously on first access, so the call is
  optional there and its absence went unnoticed. On web it is the only way to
  load the database — there is no synchronous path, and every access before it
  completes throws — so the module was unusable as shipped, on the one platform
  where four documents said the call was required. The conditional
  configuration is now re-exported beside the import that already selected it,
  which keeps the platform choice stated once. Both functions gained the
  dartdoc that public API needs, and `doc/timezoned/timezoned.md` gained an
  **Initialization** section, the startup requirement having previously been a
  comment inside a Quick Start snippet.

- **`TomGetSettingsResult.timezone` — the missing half of the timezone pair
  (tcinc300).** The result's localization block is built in server/client pairs
  so a consumer can tell an override from an echo: the server states what it
  decided, the client what it asked for, and comparing the two answers "was I
  overridden?". Two of the three concepts had both halves —
  `country`/`clientCountry`, `language`/`clientLanguage` — while timezone had
  only `clientTimezone`. A server that pinned a session's zone had nowhere to
  say so, and a client reading `clientTimezone` could not tell whether it was
  looking at its own preference echoed back or a server decision. The new field
  is declared beside `country` and `language`, follows the same `null`-means-no-
  opinion convention, and completes the 3+3 set `TomPrincipal` already carried.
  Purely additive: every existing constructor call and every field read is
  unchanged.

- **`08_server_principal_meet_example.dart`.** The meet — every authorization
  decision's second operand — was the one central security concept with no
  runnable sample, and the prose's worked example for it was illustrative only.
  The sample holds the user fixed and varies nothing but the installed
  `TomServerPrincipal`, so each outcome is attributable: an uncapped resolution,
  the same grant refused by an unlicensed deployment, the same grant restored by
  a licensed one, a generous deployment failing to widen a user who never held
  the grant, `null` versus a principal entitled to nothing (opposites, not
  synonyms), and a `TomRoleAccess` abstaining with `full` because it has no
  opinion about which features a deployment licenses.

- **`TomScopeException`.** The scope module's own `TomException` subclass,
  keyed `scope_ids.<operation>.<condition>` — `init_scope.empty_id`,
  `init_scope.separator_in_id`, `use_scope.no_identity` — with `parameters`
  carrying the offending id or type.
- **Background scheduling (`scheduling/`, csex7 / csex8 / CSEXB6 / CSEXC1 /
  csexc2).** A complete job-scheduling substrate, previously absent from the
  kernel entirely. `TomScheduler` is the runtime, and the whole loop — window
  planning, catch-up, claiming, dispatch, timeout, retry and alerting — lives in
  one awaitable `tick()` driven by an injectable clock, so a year of scheduling
  is exercised in milliseconds rather than by waiting on a timer.
  `TomSchedule` covers five kinds (`TomCronSchedule`, `TomCalendarSchedule`,
  `TomIntervalSchedule`, `TomOnceSchedule`, `TomEventSchedule`);
  `TomJobDefinition` carries the policies (`TomRetryPolicy`,
  `TomMissedWindowPolicy`, overlap, timeout) and raises `TomJobAlert`s through a
  `TomJobAlertSink` — including when a schedule can never fire again. Runs are
  persisted through `TomJobStore` (`TomMemoryJobStore`, `TomFileJobStore`) and
  executed through a `TomJobDispatcher` (`TomWorkerPoolJobDispatcher` onto the
  existing isolate pool, or `TomInlineJobDispatcher`). The runtime never
  executes anything itself.
- **Cluster coordination for the scheduler (`TomLeaseLock`, csex8).** Two
  schedulers over one store both claim the same due run unless something
  arbitrates. Supplying a `TomLeaseLock` (`TomMemoryLeaseLock`,
  `TomFileLeaseLock`) gates every run on a lease that is renewed while the work
  runs and lapses when a node dies, with **fencing tokens** (`TomLease.token`,
  strictly increasing per resource) so a paused-then-resumed holder cannot write
  behind its successor's back. The lock is optional and `null` by default: left
  unset, the scheduler behaves exactly as the single-node runtime. The execution
  guarantee is **at-least-once** — job bodies must be idempotent.
- **Declarative jobs (`@TomScheduledJob`, CSEXC1).** A job class annotated with
  `@TomScheduledJob(cron: '0 3 * * *')` *is* its own registration; extend
  `TomJobBase` and start-up collapses to `TomScheduledJobs.registerAll(scheduler)`.
  This removes the failure mode where the class and a hand-written
  `TomJobDefinition` are joined only by a string typed twice, so a rename
  silently unpairs them.
- **Second-factor authentication, end to end (`security/two_factor.dart`).**
  Login became a two-pass flow: pass 1 verifies the primary credential and, when
  the principal still owes a second factor, answers with a token that is a
  *challenge carrier* rather than a session; pass 2 takes that token plus the
  submitted factor and returns exactly the token pair a 2FA-free login would
  have produced. The challenge travels in the token's claims (`Tom2FAClaims`),
  not in a server-side pending-login record, so pass 2 stays stateless and any
  instance can complete a login started by any other. `Tom2FAChallenge` is the
  client-visible half (mechanism, hint, attempts remaining, expiry, an opaque
  `clientData` map); whatever the server needs to verify travels encrypted under
  `Tom2FAClaims.verificationData`. `Tom2FAPendingEnrolment` and
  `Tom2FAMethodDescriptor` let a login *enrol* the factor it demands rather than
  dead-ending a user who has none, and `TomTotp` supplies the RFC 4226 / 6238
  primitives. Neither the framework nor the wire types name a mechanism: adding
  SMS or WebAuthn needs no change here.
- **The ambient server principal (`TomServerPrincipal`, csex4).** A deployed
  server is itself a principal — it authenticates with a service credential and
  its entitlements are *this deployment's* feature grants. Access evaluation now
  has two operands and returns the meet: `min(user, server)` over the four-state
  ladder. A user's `TomAuthState.full` on a feature the deployment is not
  entitled to evaluates to `none`; deployment grants cap user grants and never
  widen them. A deployment that never logs itself in leaves the holder empty and
  evaluation degrades to the user's grant alone — the designed default, not a
  failure mode (`TomServerPrincipal.isConfigured` says which regime a process is
  in). It is a process-wide static rather than a zone value because the zone slot
  for `TomPrincipal` is already taken by the *user* inside a request.
- **Streaming file transfer (`file_transfer.dart` / `http_file_transfer.dart`,
  csfs2).** The client half of the framework's file storage. `TomServerCall`
  accumulates a whole response into a `BytesBuilder` — right for JSON, wrong for
  a 400 MB video — so this library reuses the same connection machinery
  (`TomServerChannel`, the bearer token, the client factory) without ever
  materialising the payload. `TomFileSource` to send, `TomFileMetadata` to
  describe what was stored, `TomFileTransferClient` (`TomHttpFileTransferClient`,
  `TomMemoryFileTransferClient`) to move the bytes, with `TomTransferProgress`
  and `TomTransferCancellation`. A transfer addresses an application-owned
  **slot** (`invoices/4711/scan`), never a storage key: keys are generated
  server-side and returned in `TomFileMetadata.key`, because a client that could
  name its own key would turn any upload endpoint into an open write surface on
  the blob store.
- **Server-stored user preferences (`preferences/`, TCCA10 / C-13, TCCB5).** The
  wire contract (`TomUserPreferenceDto`, `TomUserPreferenceWriteRequest`,
  `TomUserPreferenceKeyRequest`, `TomUserPreferencesApiService`, the
  `tomUserPreferencesApi` endpoint set), a typed `TomUserPreferenceCodec` for
  the stored values, and `TomUserPreferenceKeys` for the framework's own keys.
  `TomApiEndpoint.resolveUri` was added so a client can build the call URL from
  the DTO it already holds — path captures and query parameters both resolve
  through `urlParameterMapping`, and a missing capture is a named
  `TomEndpointException` rather than a malformed URL.
- **External identity as another authentication service
  (`security/oauth_contract.dart`).** `TomOAuthProviderDto`,
  `TomOAuthAuthorizationRequest`, `TomOAuthAuthorizationDto`,
  `TomOAuthCallbackRequest`, `TomOAuthApiService` and the `tomOAuthApi` endpoint
  set (list providers, begin authorization, complete authorization). OAuth 2.0 /
  OIDC is modelled as one more authentication service rather than a parallel
  login path.
- **`TomObservableEnum<E>` (tcca9 / C-8).** An observable enum cell whose
  *display text* comes from the text-resource bundle
  (`<scope>.<enumname>.<value>`, lower case) instead of a Dart-side label table.
  It notifies when *either* the value or the installed bundle changes, which is
  what makes a locale switch re-render a bound field without the caller
  rebuilding anything. `TomTextResourceProvider` gained the revision cell
  (`appResourcesRevision` / `notifyAppResourcesChanged`) that second trigger
  needs, and a `TomTextResourceProvider.from` constructor; assigning `resources`
  announces a change only on the *installed* provider, so populating a
  not-yet-installed one stays silent.
- `TomHeader.location` — the `Location` header name, which is what makes a 3xx a
  redirect rather than an empty body with an odd status.
- **`TomReflectionInfo(strictUnknownFields: true)` (tcinc196).** `setValues`
  silently dropped any key naming no declaration on the target, which is the
  right default on the wire but hides a typo in a config file. The new
  converter option raises `reflection.set.unknown_field` instead. It is a
  property of the converter, not of the call, so nested objects inherit it —
  the walk recurses through `createInstanceFromJson` on the same instance. The
  shared `tomReflectionInfo` stays lenient.

### Changed

- **A transition out of a claim is fenced on the claim, not merely on the state
  (tcincb2_ahtl).** `release`, `markStarted`, `renewClaim`, `complete` and `fail`
  were no-ops unless the store still held the run as `running` — a guard about
  *existence and state*, which cannot see the one case the lease timeout exists
  for. A node claims run R, is partitioned, and its lease lapses;
  `recoverAbandoned` re-queues R and a peer claims it. R is `running` again,
  owned by the peer. The original node returns and calls `complete(R)`: the row
  exists, its state is `running`, the guard passes, and the peer's in-flight
  attempt is silently overwritten. The peer then heartbeats a run the store
  already calls `succeeded`, and its own `complete` no-ops.

  `claimDue` therefore returns `List<TomJobClaim>` rather than `List<TomJobRun>`,
  and all five transitions take the **ticket**. This is the arrangement
  `TomLeaseLock` has always used — `acquire` returns a `TomLease`, `renew` and
  `release` take it back — and it is here for the same reason: recording an
  outcome for work you never claimed should not be something the API lets you
  say. Arity is unchanged, so most call sites read identically.

  The fence is the new **`TomJobRun.claimToken`**: a per-run counter that rises
  on every claim and never repeats, so two claims of one run are orderable. It is
  exactly `TomLease.token`, and that the queue lacked one while the lock had one
  is precisely why the two could disagree about who held a run. The owner alone
  will not serve, because a node can re-claim a run it previously lost and its
  first attempt's outcome would then be accepted as its second's. `claimedAt`
  will not serve either, and that is the sharp edge: it is the *heartbeat*, and
  `renewClaim` moves it — a ticket fenced on it would be invalidated by the first
  heartbeat of the very attempt it certifies, quietly costing the claimant the
  right to report its own outcome. The identity has to be the thing that does not
  move, which is why the lock separates `token` from `expiresAt`.

  `TomMemoryJobStore` copies the owner and token into the ticket at claim time
  rather than reading them back off the run: it hands out the *same object* it
  holds, so a later recovery and re-claim mutate the very run the first claimant
  is still carrying, and a fence read from that object would always agree with
  whoever wrote it last. The five transitions now share one `_held(claim)`
  predicate instead of five copies of the guard. `TomJobRun.toJson` writes
  `claimToken`; `fromJson` reads a missing one as `0`, so a queue file written
  before the fence still loads. `TomSqlJobStore` carries the same change as a
  `claim_token BIGINT` column — see the server's changelog.

- **`Tom2FAPendingEnrolment.isExhausted` is false at the choosing stop
  (tcincb1).** It read `attemptsRemaining <= 0`, with no `hasOffer` guard, while
  the server's `Tom2FAEnrolmentState.isExhausted` — the state this type is the
  client-side view of — has always read `hasOffer && attemptsRemaining <= 0`.
  The two tiers disagreed about the *choosing* stop, and the disagreement was
  not a corner case: the attempt budget belongs to the mechanism's offer, so a
  chooser carries no `attemptsAllowed` claim at all, and an absent claim falls
  back to `0` (deliberately, so an unreadable budget on a begun offer arrives
  already spent). Every chooser therefore reported itself exhausted — attempts
  burned against a mechanism that was never generated. This is the same reading
  the type already gives the *deadline*, whose nullability is documented as
  "the deadline belongs to the mechanism's offer, not to the choice"; the
  budget is the same kind of thing and now gets the same treatment. The
  fail-closed fallback is untouched, because it only bites where `hasOffer` is
  true and the guard is transparent. `TomBearerAuthentication`
  `.pendingTwoFactorEnrolment` had been working around the defect since
  tcinc273 with `if (enrolment.hasOffer && enrolment.isExhausted)`; that
  workaround is gone, and the getter now reads exhaustion as plainly as it
  reads the deadline. **Behaviour change for direct readers**: a chooser that
  answered `true` now answers `false`. One existing test asserted the defective
  reading (`'the choosing stop survives the freshness filter'`) and its premise
  was rewritten — the assertion it was really making, that the getter does not
  delete the chooser, is unchanged and now pins `attemptsRemaining` as the raw
  count instead.

- **A minted token is redacted against its own subject, not against the ambient
  zone (tcincb1).** `convertPrincipalToTokenPayload` takes the principal the
  token is for and then decided which of *that principal's* fields to include by
  calling `tomProtect`, which reads `getFromCurrentZone<TomPrincipal>()` — never
  the argument. Eleven identity fields went through it (`tom.user.firstname`,
  `.lastname`, `.email`, `.phone`, `.mobile`, the four address fields,
  `.stateRegion`, `.attributes`). The caller that matters is the login path:
  `TomAuthenticationServer._issueTokens` mints for a principal being
  authenticated *right now*, so nothing is installed on the zone yet — a login
  request carries no token for the pipeline to derive one from. Because
  `isProtectedFor` treats a `null` principal as holding no keys, every protected
  field of every minted token came back `null` the moment
  `globalSettingProtectionDefault` was switched on: the feature was unusable in
  exactly the configuration that turns it on. The eleven call sites now redact
  through the new `TomResourceKeyProtection.protectFor(principal, …)`, so a
  field survives when the subject's own ACI holds its key, in a request zone or
  out of one. `username`, `userId` and `userTimezone` remain unfiltered as
  before. This is the same shape as tcinc270 — a function holding a principal
  that asked the zone instead — and lands on the same answer: where the caller
  has named someone, answer about them. The defect was latent because the master
  switch defaults to `false`, which is what every test and sample used, so the
  suite was green either way; the five new tests are the first in the file to
  switch protection on.

- **`TomResourceKeyProtection.protectFor` completes the `For` pair.**
  `isProtected`/`isProtectedFor` had had both forms since tcinc270 — the rule
  stated over the ambient zone and over an explicit operand — but the
  value-returning `protect` had no sibling, so a caller with a principal in hand
  could ask *whether* a key was protected but not *apply* the protection without
  going back through the zone. `protectFor(principal, data, fallback, key)` is
  `protect` over a named operand and is now the form to reach for whenever the
  subject is already an argument, which is what serializers and token minters
  always are.

- **One outbound and one inbound entry point now honour all four serialization
  hooks (tcinc1117).** Four hook names are part of the reflection contract —
  `toJson`, `jsonEncode`, `fromJson`, `jsonDecode` — and no single code path
  honoured them all. They were dispatched from three places, each honouring a
  different subset: `getValues` knew `TomClass` and `jsonEncode` but neither a
  plain `toJson()` nor `TomJsonSerializable`, so a DTO carrying a perfectly good
  `toJson` serialized to its raw field map — or, unannotated, threw
  `reflector.reflect.not_reflectable` — and the server's endpoint pipeline
  compensated with a five-way chain of its own. Inbound was split the other way:
  `createInstanceFromJson` tried `fromJson`, `setValues` tried `jsonDecode`, so
  which hook applied depended on which function the caller happened to reach
  for. There are now **two** entry points, one per direction, each honouring
  every hook of its direction in a documented order. Outbound: `TomClass`, then
  `TomJsonSerializable`, then a `toJson()` method, then the `jsonEncode` getter,
  then the field walk. The two `is` tests run *before* any mirror is taken, so a
  self-rendering DTO no longer needs `@tomReflector` to be serialized — which is
  what `TomJsonSerializable` was introduced to buy. The three `toJson` spellings
  are ranked together, ahead of `jsonEncode`, because they are one hook under
  two nominal names and one structural one; were `jsonEncode` ranked between
  them, adding `implements TomJsonSerializable` to a class carrying both would
  silently change its wire format — a declaration of intent becoming a
  behavioural change. Inbound: `TomClass`, then the `fromJson` constructor, then
  the `jsonDecode` method, then the field walk, applied identically by
  `setValues` and `createInstanceFromJson`. `fromJson` outranks `jsonDecode`
  because a constructor owns the object from nothing where the method only
  overwrites what is there. **One behaviour change to note:** a constructor
  builds rather than fills, so `setValues` on a class declaring `fromJson` now
  returns *that* instance and leaves its argument untouched — write
  `o = converter.setValues(o, map)`. All four hooks keep the existing failure
  contract (looked up before they are called, `reflection.hook.failed` /
  `reflection.hook.invalid_return`); the two nominal forms need none of it,
  since an `is` test cannot mistake absence for failure.

- **`convertToJsonString` renders the JSON containers, so a transport does not
  have to (tcinc1118).** One outbound entry point is only *the* outbound entry
  point if everything a handler returns can go through it, and a `List` or a
  `Map` could not: `getValues` refuses both — correctly, since neither is a
  reflected type with fields to read — and `convertToJsonString` was defined as
  `jsonEncode(getValues(o))`. So a handler returning `List<Task>`, which is
  ordinary, had no way onto the wire except for its transport to encode it
  itself. That is precisely why the server's endpoint pipeline carried a
  five-way chain of its own, and why the two sides came to honour different
  hook sets. `convertToJsonString` now encodes a `List` or a `Map` as itself,
  rendering complex elements through `getValues` and passing scalars through,
  to any depth; `getValues` is unchanged and still refuses both, because only
  the *string* form has an answer for a container. Two things are deliberate.
  The container is walked explicitly rather than handed to `jsonEncode` with a
  `toEncodable` callback: `dart:convert` catches whatever that callback raises
  and rethrows `JsonUnsupportedObjectError`, so the annotation guard's
  message — which names the offending type — would have reached callers as
  "converting object to an encodable object failed"; walking it here lets the
  guard's own exception out unwrapped. And nothing in the walk reproduces the
  field walk's date/zoned-time conversions, which belong to `getValues`; a
  second copy of that table is how the two would drift, so a bare `DateTime`
  sitting directly in a map is refused (it threw before too, less
  informatively). A bare scalar stays refused: it is not a container, so it
  takes the object path and meets the guard exactly as before.

- **An all-`final` class is refused outbound rather than serialized as `{}`
  (tcinc1119).** The reflective field walk skips `final` members, and that stays:
  a `final` field cannot be assigned after construction, so no reflective
  deserializer can restore one, and emitting it would buy a payload that renders
  and never round-trips — data lost in the direction nobody checks. The defect
  was the *silence*. A class whose members are all `final` reached the wire as
  `{}` and reported success: the same valid-looking payload with everything
  dropped that `reflector.type.not_annotated` was added to prevent, arrived at by
  a second route. `getValues` now throws `TomReflectorException`
  (`reflector.type.all_final`), naming the type and every member it skipped, and
  listing the remedies. Throwing rather than debug-logging is the point — a
  framework log line is invisible to the caller and would have reproduced the
  very silence the change exists to remove, and the neighbouring `{}`-as-success
  case already throws. The condition is deliberately narrow: **nothing
  contributed *and* something dropped**. A class contributing even one field
  serializes as before, and a class with no wire members at all still renders
  `{}`, which is true of it. Nor is this a ban on immutable DTOs — all four
  rendering hooks are consulted ahead of the walk, so an all-`final` class that
  declares `toJson()`, a `jsonEncode` getter, `TomJsonSerializable` or extends
  `TomClass` never reaches the guard. The exception asks how the type means to
  render itself; it does not answer for it. Only the outbound half changed:
  inbound was never quiet, a payload key naming a `final` member having always
  raised `reflection.set.unexpected_condition_final_static_private`.

- **`TomAuthorizationGroup.mostRestrictive` answers `none` for a group with
  nothing visible, not `full` (tcinc752).** The getter folds its visible members
  with `narrow`, starting from `TomAuthState.full` — and when there are no
  visible members the fold's starting value fell straight out as the answer. So
  the one aggregate a caller reaches for to ask "does this group have anything
  to show?" reported the *most permissive* state possible for precisely the two
  cases where it shows nothing: an empty group, and one whose members are all
  hidden. A container gating on `mostRestrictive == full` treated a fully hidden
  group as fully editable; one gating on `mostRestrictive != none` rendered an
  empty section header. `full` is the identity element of the fold, not a state
  any member reported, and letting it escape as one made those two groups
  indistinguishable from a fully open one.

  It now returns `TomAuthState.none` when nothing is visible, which is what
  "nothing to show" is already called throughout this API and matches what
  `isEmpty`, `memberCount` and `findMember` had said about the same group all
  along. `isUniform` deliberately keeps the opposite convention — vacuously
  `true`, as `Iterable.every` is — because "all visible members share one state"
  is a claim about members, not a state. `doc/security/security.md` and the
  API summary state both rules and why they differ. **Behavioural change:** two
  tests asserted the old `full`; a caller who used `mostRestrictive` as a
  membership test should use `isEmpty`, which answers that question directly.

- **`TomZonedDate.isDate` asks when the day began instead of assuming midnight
  (tcinc338).** A date is anchored to the first instant of its local day, and on
  a handful of zone-days that is not midnight: Chile, Cuba, Lebanon, Egypt,
  Paraguay and the Azores each spring forward *at* 00:00 once a year — seven
  zone-days in 2024, five in 2025 — so the day starts at 01:00 because midnight
  never happens. Both constructors already handled this correctly, by asking the
  timezone database rather than forcing the components to zero. The predicate
  did not, so it answered `false` for values its own type's constructor had just
  produced, and three documents claimed the opposite in as many words ("every
  well-formed `TomZonedDate` passes, wherever it is anchored").

  `isDate` now compares against the first instant of the local day, which is the
  round trip of construction. It also recognises a bare `TZDateTime`, not only a
  `TomTimezoned`: both know their zone, and `toDateTime()` hands back the
  former, so treating them differently made `isDate(value)` and
  `isDate(value.toDateTime())` disagree on exactly the days this fixes. Widening
  is confined to values that are the start of a day — a `TomZonedDateTime` at
  02:00 on a skipped-midnight day is still rejected. Plain `DateTime` arguments
  carry no zone and are judged on all-zero components, unchanged.

- **The timezoned initializer's default arm is the embedded database, and
  `init_tz.dart` is gone (tcinc330).** The default arm of a conditional import
  is taken wherever no condition holds, which makes it the one position that
  can rely on nothing — and the file sitting there imported
  `package:timezone/standalone.dart`, which reads the database off disk through
  `dart:io`. It could not have compiled anywhere it was selected. Nothing ever
  selected it: the VM took the `dart.library.io` arm and the browser took
  `dart.library.js`, so a file that could not work was also never reached, and
  the two faults hid each other. Its own two functions had already drifted
  apart in the same silence — the async one read from the filesystem while the
  sync one used the embedded copy, two data sources in one twenty-line file.

  `init_tz_flutter.dart` is renamed `init_tz_embedded.dart` and promoted to the
  default arm, and the `dart.library.io` arm is dropped as the redundancy it
  became. The selection now reads `import 'init_tz_embedded.dart' if
  (dart.library.js) 'init_tz_web.dart';` — embedded everywhere, fetched in the
  browser. The new name describes the data source rather than a platform,
  because the old one named the single platform it was *least* specific to: it
  served the server, the CLI and the test runner just as much as Flutter, and
  the documentation had already been misled by exactly that.

  Two behavioural consequences, both improvements. A target with neither
  `dart:io` nor `dart:js` — dart2wasm, where `dart.library.js` does not hold —
  previously selected a file that could not compile and now gets a working
  embedded database. And the module no longer has any path to
  `package:timezone/standalone.dart`, so nothing in the kernel loads timezone
  data off the filesystem.

- **`TomZonedDate.fromDateTime` and `TomZonedTime.fromDateTime` enforce their
  type's anchoring (tcinc324).** Both copied every component of the incoming
  `DateTime` straight through, so neither type's defining invariant survived
  the call: a `TomZonedDate` built this way carried a time of day, and a
  `TomZonedTime` carried a calendar date — a `@T@` string reading `2026-08-11`.
  Both malformed values still matched their `isTom…String` predicate, so they
  round-tripped through storage undetected, and the shipped example built one
  on every run. The anchoring was stated as a property of the type in five
  places; it is now a property of the value. Each factory reads the instant in
  the target timezone and then delegates to its own primary constructor, so
  "midnight, there" and "1970-01-01, there" have one definition and DST
  normalization behaves identically whichever way the value was built. Reading
  in the *target* zone is the part that carries meaning: 22:30 UTC is already
  the next day in Berlin, and a date-only value asks which day it is there.
  `TomZonedDateTime.fromDateTime` is unchanged — that type anchors nothing, so
  keeping every component is correct, and a test now says so deliberately.
  Callers that were relying on the components surviving were relying on a value
  of the wrong type; use `TomZonedDateTime` for those.

- **`TomZonedDate.isDate` and `TomZonedTime.isTime` judge a zoned value in its
  own timezone (tcinc325).** Both read the components inherited from
  `DateTime`, which by the module's storage rule are the UTC ones, while the
  anchoring they test for — midnight for a date, the epoch for a time — is
  defined in the zone the value carries. Off UTC the two frames disagree, so
  each predicate rejected the very type it is named after:
  `TomZonedDate(year: 2024, month: 6, day: 15, timezone: tokyo)` stores
  15:00 the previous afternoon and failed `isDate`; `TomZonedTime(hour: 0,
  minute: 30, timezone: tokyo)` stores 1969-12-31 and failed `isTime`. A
  `TomTimezoned` is now read through `toDateTime()` first, which is the frame
  its anchoring was stated in; any other `DateTime` carries one frame and is
  read as it stands, so the plain-`DateTime` behaviour is untouched. The
  predicates keep their `DateTime` parameter and stay usable as a shape test
  on unclassified values — they simply no longer contradict themselves on
  values the library itself produces.

- **The serialized timezoned form requires its trailing `Z`, and the offset it
  carries is not read back (tcinc326).** The `Z` was optional in all eight
  patterns and the offset group was captured by every `parseFromString` and used
  by none, so a string whose instant lacked the `Z` was read as a naive local
  reading and converted with `.toUtc()` against whatever zone the host machine
  was in — while the one field that could have disambiguated it was discarded.
  `@X@2024-06-15T05:30:00.000_+09:00_Asia/Tokyo` yielded UTC hour 3 on a host at
  +02:00 and hour 5 on a UTC host, silently. Requiring the `Z` was preferred to
  reading the offset because the offset is *derived* from the zone rather than
  independent of it: honouring both would make a contradictory string ambiguous,
  where rejecting the Z-less one is the same answer on every machine. The offset
  is still deliberately not validated against the zone — the IANA database
  revises historical offsets, so a disagreement is evidence about the database,
  not the value, and re-serializing restates the offset from the zone. Nothing
  the library produces is affected: every value it writes carries the `Z`. The
  exposure was hand-written, hand-edited and legacy stored data, which now fails
  loudly at the boundary. The eight copies of the format became one builder with
  four cached patterns, which makes "accepted by the predicate but rejected by
  the parser" impossible by construction, and the fractional-second group widened
  from three digits to six — `toIso8601String` emits six as soon as the
  microsecond component is non-zero, so a value carrying microseconds previously
  failed its own predicate.

- **`TomShutdownCleanup.addSignal` is idempotent per signal (tcinc319).** It
  appended a watcher unconditionally, so naming a signal twice installed two
  subscriptions on the same broadcast stream and one arrival drove the handler
  twice. The cleanup itself stayed correct — it runs once — but the operator saw
  the signal reported twice and was told, on its very first arrival, that
  shutdown "has already been performed". The trap was easy to walk into: the
  constructor registers SIGHUP and SIGINT, so `addSignal(ProcessSignal.sigint)`
  was enough to produce it. The retained subscriptions are now keyed by signal
  rather than held in a list, which makes "at most one watcher per signal" a
  property of the structure instead of a check to remember.

- **One spelling of "timezone" across the kernel, and one spelling in the token
  (tcinc301).** The concept was written three ways in code that hands it from
  one type to the next: `TomUser.timeZone`, `TomPrincipal.timezone` /
  `.clientTimezone`, and `TomGetSettingsResult.clientTimeZone`. `TomPrincipal`
  sits between the other two — it is populated from the user and populates the
  settings result — so every hop had to switch spelling, and the source carried
  a hand-written note at the seam (`// Note: user.timeZone is the stored
  preference`) whose only job was to bridge two spellings of one word. The
  neighbouring concepts had no such split: `language` and `country` are spelled
  identically everywhere.

  Everything now reads `timezone` / `clientTimezone`, one word — the spelling
  the IANA database uses, the spelling the `timezone` package this kernel
  depends on names itself, and already the majority here
  (`TomPrincipal.timezone`, `TomPrincipal.clientTimezone`,
  `TomUserPreferenceKeys.timezone`, and the new
  `TomGetSettingsResult.timezone`). The bridging comment is deleted because
  there is nothing left to bridge.

  **The JWT claim names were split the same way, and are unified too.**
  `convertPrincipalToTokenPayload` wrote `"timeZone"` and `"clientTimezone"`
  two lines apart in one map literal, plus `"userTimeZone"` for the user's
  stored preference — so the wire format itself spelled the concept both ways.
  The claims are now `"timezone"`, `"clientTimezone"` and `"userTimezone"`.

  **Breaking, on two surfaces.** `TomUser.timeZone` (getter and constructor
  parameter) and `TomGetSettingsResult.clientTimeZone` (field and constructor
  parameter) are renamed, which the compiler catches; and because both classes
  are reflected, the identifier is the JSON key, so the settings wire contract
  and the token claim names change with them. Reflected serialization data must
  be regenerated — a stale `.reflection.dart` still compiles, because its
  accessor closures take `dynamic instance`, and fails only when the accessor
  is invoked.

- **`settings_client_authorization.dart` and `authentication_authorization.dart`
  now import `@tomReflector` from the reflection module directly.** Both
  previously reached it through `observable/tom_observable_objects.dart`, which
  re-exports the reflection module wholesale. Neither file uses anything of
  observable's own — the annotation was the entire reason for the import — so the
  import line asserted a coupling that does not exist, and it is what the two
  documents' Dependencies sections were reading when they credited observable for
  the DTO annotations. Eleven other files in the package, including the sibling
  `oauth_contract.dart` and `two_factor.dart`, already imported reflection
  directly; these two were the outliers. No symbol resolves differently and no
  executable line moved.

- **Every boolean 2FA claim is now read the same way, `Tom2FAClaims.isTrue`,
  including at the gates.** The module already stated the rule — a claim can
  cross the wire as the JSON boolean `true` or the string `"true"`, because the
  two claim families encode it differently and a deployment mixing framework
  versions can present either — but applied it to exactly two flags, `skippable`
  and `skipSpendsGrace`, which decide whether a skip button renders and how it
  is worded. The reads that actually gate something all used exact string
  equality: `requires2FA` in `convertTokenPayloadToPrincipal`, `requires2FA` in
  `Tom2FAChallenge.fromClaims`, and `pendingEnrolment` in
  `Tom2FAPendingEnrolment.fromClaims`.

  At the first of those the strict reading fails **open**. `authenticated` is
  derived as "username is not the guest **and** no second factor is owed", so a
  token carrying the boolean encoding of "I still owe a factor" was read as
  owing none and authenticated — an interim token becoming a session. At the
  other two it fails closed but strands the user: the client holds a token that
  says a factor or an enrolment is pending and gets `null` when it asks what to
  render, which is precisely the failure the rule's own rationale describes.

  Leniency is the fail-safe direction at all three, so all three now use it.
  `_claimIsTrue` was private to `Tom2FAPendingEnrolment`; it is now
  `Tom2FAClaims.isTrue`, public and documented as the rule for both claim
  families on both tiers, so `tom_core_server` reads the same claims the same
  way. It stays deliberately narrow — `"True"`, `1` and `"yes"` are still false,
  because widening past what a Tom tier writes would be guessing at other
  issuers' conventions rather than reconciling our own.

  **One test changed its premise rather than its assertions.** "the requires2FA
  claim is a string protocol, tested exactly" pinned the old behaviour, and its
  comment named the consequence outright — "a foreign issuer's JSON boolean
  reads as 'no factor owed' and authenticates". That is the defect, not a
  contract, so the test now asserts the lenient reading and the near-misses that
  remain false.

- **`TomUser` copies the `attributes` map instead of aliasing it.** The getter
  returned `Map.unmodifiable(_attributes)` and the dartdoc promised "an
  unmodifiable view", but the constructor kept the caller's own map
  (`_attributes = attributes ?? _attributes`) rather than copying into its own.
  The view therefore guarded only the getter: whoever passed the map still held
  a live handle and could edit an identity's attributes — or inject new ones —
  at any point after construction. `TomAccessControlInformation` and
  `TomClientLimitsInformation` both copy; `TomUser` was the one part of a
  principal that did not, which is also why the read-only contract could not be
  stated for the principal as a whole until now. Found while documenting
  `TomUser`, and fixed the same way its two siblings were: a `final` field that
  the constructor `addAll`s into. Two tests pin it — that a caller's later edit
  is not visible, and that the default-constructed instance is not a special
  case.

- **`TomTotp.counterFor` says what it actually requires of `period`.** The
  `ArgumentError` read `must be a positive duration`, but the guard is
  `period.inSeconds <= 0` and `inSeconds` truncates — so a 500 ms period *is* a
  positive duration and is still rejected. The message now says `must be at
  least one second`, the dartdoc explains why truncation makes the two
  different, and the test pins the sub-second and negative cases alongside the
  zero one it already covered, plus the inclusive one-second boundary.

- **`bearerAuthentication` is documented as the injection seam it is.** Source
  and mirror both called it a "global singleton instance" and stopped there.
  It is not `final`: every static accessor on `TomBearerAuthentication` reads
  through it, so assigning a fresh instance swaps the whole cached client-side
  auth state at once — which is exactly what a dozen test files do in
  `setUp`/`tearDown` to keep one test's login out of the next. A reader who
  took "singleton" to mean read-only would not have found it.

- **Mirror rows state the defaults a reader cannot guess.** The six remaining
  `globalSetting*` switches (`false`), `clientLanguage`/`clientCountry`/
  `clientTimezone` (`"en"`/`"XX"`/`"utc"` — the last two being values nobody
  would infer), and the four `TomPrincipal` database ids, whose unset value is
  `-1` while their string counterparts are nullable. Defaults that *are*
  guessable — an empty string on a DTO field, a `false` on a boolean flag —
  are deliberately left unstated; spelling them out on thirty rows would bury
  the handful that carry information.

- **The mirror documents `Tom2FAChallenge.toString()` and
  `Tom2FAPendingEnrolment.toString()`**, which it does for nearly every other
  class, noting in both cases that the rendering carries no secret.

- **The mirror's `TomResourceKeyProtection` section states the master switch and
  gains the missing `isProtectedFor` row.** The `isProtected` row described only
  the key lookup — "whether the resource is protected from the current
  principal" — omitting both branches that come first: the whole method
  short-circuits to "accessible" while `globalSettingProtectionDefault` is
  `false` (its default), and with protection on it is fail-closed for a caller
  with no principal. A reader taking the row at face value would expect a
  freshly added protection call to protect something, and would misread the
  outside-a-request-zone case as "allowed". The `globalSettingProtectionDefault`
  property row now names the `false` default, and the `protect`, `tomProtect`
  and `tomProtected` rows state that they inherit the precondition. Separately,
  the section listed two static methods where the class has three:
  `isProtectedFor` — the rule over an explicit principal, added when the method
  was split out — had never been mirrored. It is now present, and the
  `TomResourceKeyAccess` entry says it delegates there, so the explicit-operand
  and ambient-zone forms are told apart in the document as they are in the code.
  A test pins `isProtectedFor` reading its argument rather than the zone; until
  now that was asserted only about its one-line delegate.

- **The mirror's `convertTokenPayloadToPrincipal` row states the real
  `requires2FA` test and its `StateError`.** It said a token "carrying a
  `requires2FA` claim" yields an unauthenticated principal, which is close to
  backwards: the reader tests exact string equality against `"true"`, so a token
  carrying the claim as `"false"` — what Tom's own issuer writes on every
  completed login — authenticates, and so does one carrying the JSON boolean
  `true`. The row now says the claim is a string protocol, names the values that
  read as "no factor owed", records that `authenticated` is *derived* here (from
  the non-guest username **and** the factor test) rather than read from the
  token, and documents the `StateError` on a payload-less token that the
  adjacent `getPrincipal()` row already documented. A test pins the string
  protocol across six encodings. The asymmetry the row now makes visible — every
  unrecognised encoding authenticates — is itself under review as a separate
  question.

- **The mirror's `convertPrincipalToTokenPayload` row no longer misstates both
  of its two-factor claims.** It said `requires2FA` is cleared when
  `twoFactorSatisfied` is `true`, and that `twoFactorVerification` goes into the
  private payload full stop. Neither holds: a supplied `challenge` projects
  `requires2FA: "true"` unconditionally and `twoFactorSatisfied` is read only on
  the branch that has no challenge, while `twoFactorVerification` is written
  *only* alongside a challenge and is otherwise dropped. Both readings were
  dangerous in the same direction — a reader trusting the row would expect
  `(challenge: c, twoFactorSatisfied: true)` to mint a completed session and
  would ship the mechanism's server-only blob expecting it to be persisted. The
  row now states both conditions and the reasons behind them (fail-safe claim; a
  secret must not outlive its challenge). The source dartdoc was already
  correct. A test pins the case the row got wrong — a challenge outranks
  `twoFactorSatisfied` — which was the one combination the suite never exercised.

- **The security API mirror lists all six two-factor classes.** Its table of
  contents, class hierarchy and `two_factor.dart` overview each named three —
  `Tom2FAClaims`, `Tom2FAChallenge`, `TomTotp` — while the reference body
  documented six. `Tom2FAEnrolmentClaims`, `Tom2FAPendingEnrolment` and
  `Tom2FAMethodDescriptor` were therefore unreachable by anyone navigating from
  the top, which is the whole enrolment half of the two-pass login: a reader
  finding only the challenge pair concludes the framework cannot enrol a user
  who has no factor yet. All three lists now agree, and the omission was
  confirmed to be exactly these three by diffing every public type declared in
  `lib/src/tombase/security/` against the mirror.

- **The meet's worked example now declares the identifiers it turns on.** The
  security guide's central explanation of why a control the user satisfies can
  still resolve to `none` used `user` and `server` without binding either, and
  obtained the server principal on one line only to discard it and pass an
  undeclared `server` on the next. Both are now bound —
  `TomBearerAuthentication.getPrincipal()` and `TomServerPrincipal.current!` —
  and the per-resource-role adapter snippet nearby, which had the same defect on
  `principal`, is bound too. The values the blocks assert were already correct
  and are now verified by the new `08_server_principal_meet_example.dart`.

- **No documented `updatePrincipal` call silently wipes the principal's
  per-resource grants any more.** The method replaces the ACI rather than
  merging into it, and `resourceRoles` is its only optional parameter — so a
  four-argument call compiles and clears every per-resource grant the principal
  held. Best Practice 7 showed exactly that inside a `refreshPermissions()`
  running on a timer, which drops the grants on every tick; because
  `TomResourceRoleAdapter` resolves an ungranted resource to `none`, the symptom
  is UI disappearing a few seconds after login with nothing in the logs. Best
  Practice 7 now passes `resourceRoles` and explains the replace-not-merge
  semantics, the `updatePrincipal` dartdoc leads with them, and the printed
  "Example call" in `04_bearer_authentication_example.dart` — a fourth copy of
  the same four-argument shape — shows the fifth argument and the warning.
  `security_test.dart` now pins the contract: the existing "replaces the ACI"
  test asserts `resourceRoles` round-trips, and a new test asserts that omitting
  it clears a grant the principal was holding. Documentation and test coverage
  only; the behaviour is unchanged.

- **The resource-key protection docs no longer show a snippet that protects
  nothing.** `TomResourceKeyProtection.globalSettingProtectionDefault` defaults
  to `false`, and `isProtectedFor` returns `false` before consulting any key
  while it is off — so `tomProtect` serves the real value for every key and
  every principal. Best Practice 5 ("Protect Sensitive Fields") and the Quick
  Start both showed `tomProtect` calls with no mention of the switch, five
  hundred lines from the one place it appeared; copied as written they were
  no-ops on exactly the PII they claimed to guard. Both snippets now set the
  switch and link to the canonical subsection, which itself now states that the
  default is fail-*open*. Best Practice 5 additionally documents the
  fail-*closed* consequence of turning it on: `tomProtect` reads the principal
  from the ambient zone, so outside a request — start-up, a background isolate,
  a test — every protected field serves its fallback, and a serializer shared
  between a request and a job will behave differently in each. The same
  precondition is now stated on `protect`, `isProtectedFor`, `isProtected`,
  `tomProtect` and `tomProtected`, so it reaches IDE hover and not just the
  prose. Documentation only — the behaviour was already correct and covered by
  tests.

- **`TomGradedAccess` now appears in the security prose, including in the
  built-in access-control table it was missing from.** The table listed nine
  controls; `access_controls.dart` ships ten. The omitted one is the only
  control that overrides `resolvePrincipalAuthState` rather than the boolean
  `checkPrincipalAccess`, which makes it the only one able to resolve to
  `disabled` or `read` — every other row is two-valued and collapses to `full`
  or `none`. The doc therefore introduced a four-state model and then offered
  nine controls that between them could produce two of the states. Added: a
  tenth table row marking it as the composer, a `Graded Access (all four
  states)` subsection covering the ladder, the `read`→`full`/`disabled`→`read`
  defaulting, the `showsContent` collapse for binary consumers and the
  deployment-side grading, and a paragraph under `TomAuthState` naming all
  three sources of the middle states (graded access, per-resource roles, the
  meet). The previously undefined mention in the meet section and the
  `resolvePrincipalAuthState` row of the operand table now link to it, and
  Best Practice 5 contrasts it with all-or-nothing resource keys. The existing
  sample `06_graded_access_example.dart` is now linked from the prose.

- **The security documentation now covers per-resource roles, which it had
  never mentioned.** `resource_role_authorization.dart` is exported from the
  barrel, tested, and used throughout `tom_core_server` and the advanced
  samples — but `doc/security/security.md` introduced "these main files" and
  listed eight of the module's nine, omitting exactly that one. So
  `TomResourceRoleRegistry`, `TomResourceRoleAdapter` and the fifth ACI
  collection `resourceRoles` were absent from the module's prose, and with them
  an entire authorization paradigm: a role scoped to a *single* resource, so one
  principal can be `owner` of one project and `viewer` of another at the same
  time. The gap was compounded by the doc claiming, of the
  `TomAuthorizationAdapter` contract, that "a kernel-backed adapter maps
  resource-key protection to states" — a description of nothing that exists.
  `TomResourceRoleAdapter` is the only implementation the kernel ships, and it
  is what makes `TomAuthorization.resolveAuth` return anything other than
  `full`. The file table now lists all nine files, the ACI table and its
  constructor sample carry `resourceRoles`, Key Concepts defines the term,
  "Choose One Authorization Paradigm" lists it as the fifth (and warns that it
  deliberately ignores the global roles), and a new section documents the
  registry/adapter pair together with the no-fallback guarantee that governs
  both: an ungranted resource resolves to `none` rather than degrading to the
  global roles, and an unregistered role resolves to `none` rather than
  granting by default. The module readme and the package README key-type tables
  gained the pair as well. Also documented, because it is the trap this API
  makes easiest to fall into: `TomBearerAuthentication.updatePrincipal`
  *replaces* the ACI, so omitting its optional `resourceRoles` argument silently
  drops every per-resource grant the principal held — the Token Management
  sample now passes it.
- **`TomAuthorizationGroup`'s documentation stopped naming a parameter that
  does not exist.** The class dartdoc pointed at `[authorizationGroup]` — a
  member `TomAuthorizable` has never had, so the reference was dead — and both
  the dartdoc and `doc/security/security.md` carried a worked example reading
  `TomTextField(tomId: 'street', authorizationGroup: shipping, ...)`, which
  would not compile: Tom Flutter UI's input widgets take `tomGroup`. The
  prose doc contradicted itself fourteen lines apart, its own
  `TomAuthorizable` table having listed `tomGroup` correctly all along. Both
  samples now lead with the kernel-level `register(element)` form, which is
  what this package actually offers and what its compiled example asserts, and
  the widget snippet is marked as belonging to the UI package. The two live
  references are qualified (`[TomAuthorizable.tomId]` /
  `[TomAuthorizable.tomGroup]`) so they resolve from the group's scope rather
  than silently rendering as plain text.

  Worth knowing for anyone writing against either layer: Tom Flutter UI really
  does use both spellings — `tomGroup` on inputs and other `TomNodeBase`
  widgets, `authorizationGroup` on `TomForm`, `TomActionController` and
  `TomExpansionPanel`. That split is what made the error easy to write, and
  both doc sites now say so instead of leaving the next reader to rediscover
  it.

- **`TomAuthorizationGroup`'s inspection helpers now agree with each other
  about who is in the group.** `isUniform` and `mostRestrictive` skipped
  members whose `effectiveAuthState` is `none`; `members`, `memberCount`,
  `isEmpty` / `isNotEmpty` and `findMember` counted them. A group could
  therefore report members that `mostRestrictive` refused to see, and
  `findMember` would hand back an element the user is not allowed to know
  exists. `members` is now the single place the visibility filter is applied
  and every other helper is defined in terms of it, so the disagreement cannot
  reappear one helper at a time. Consequences worth knowing: a group whose
  members are *all* hidden now reports `isEmpty`, and `memberCount` /
  `findMember` resolve `effectiveAuthState` where they previously did not.
  `register` / `unregister` deliberately keep working on the raw
  registrations — a hidden member is still tracked, and still removable by
  whoever added it.

- **`Tom2FAChallenge.expiresAt` and `Tom2FAPendingEnrolment.expiresAt` are now
  actually normalised to UTC, as both types said they were.** The constructors
  assigned the parameter straight through, so a caller that passed a local
  instant got it back with its own zone attached while the dartdoc promised
  UTC. Nothing misbehaved internally — `isExpired` and `toClaims` each called
  `toUtc()` again on the way past — but that re-normalisation is exactly what
  hid the omission, and it did nothing for the one reader that mattered: an
  application rendering a countdown from the public field, or comparing the
  `toString()` of one challenge across two machines in different zones. The
  constructors now normalise (`null` stays `null` on the enrolment, whose
  choosing stop has no deadline to normalise) and the downstream `toUtc()`
  calls are gone, so the invariant is stated once, where it is established.
  `isExpired` likewise dropped its normalisation of `now`: `isBefore` compares
  instants, not wall clocks, so a caller may pass either zone. This brings the
  two kernel types in line with their server counterparts
  `Tom2FAEnrolmentState` and `TomOAuthTokenGrant`, which already normalised in
  the constructor and relied on it downstream — `Tom2FAEnrolmentState` carries
  the very sentence the kernel challenge had copied without the code.
- **`pendingTwoFactorChallenge` / `pendingTwoFactorEnrolment` are now `null` for
  a challenge or offer that has lapsed or burned its last attempt.** The
  security guide stated this as a kernel guarantee, but the getters delegated
  straight to `fromClaims`, which checks only that the claims are *decodable* —
  so a lapsed interim token round-tripped to a live-looking challenge. A client
  that slept, or sat in a background tab, prompted for a code the server was
  always going to refuse; on the enrolment side the documented `while
  (enrolment != null)` loop had nothing to terminate it. The freshness check
  sits on the getters rather than in `fromClaims`, which stays a clock-free
  decoder of the wire format: the server has its own authoritative clock and
  already runs the same checks in `authenticatePass2`, and a test needs to be
  able to build a lapsed challenge to assert against. One asymmetry on the
  enrolment getter — exhaustion disqualifies an offer only once `hasOffer` is
  true, because the choosing stop carries no attempt budget and so reads back
  as exhausted; a chooser owes no attempts because nothing has been generated
  to attempt yet. (The server's own `Tom2FAEnrolmentState.isExhausted` already
  encodes that rule as `hasOffer && attemptsRemaining <= 0`.)
- **Breaking: `TomClientLimitsInformation` is read-only, like its sibling.**
  `enabledModules` and `quotas` were plain reassignable public fields with
  `const []` / `const {}` defaults — which made the class mutable in the one way
  that skips the constructor and immutable in the one way a caller reaches for
  first. `TomClientLimitsInformation().enabledModules.add('reporting')` threw an
  `UnsupportedError` at runtime with no compile-time signal, because the default
  was a `const` literal, while the very same call on a *populated* instance
  succeeded and silently also mutated the list the caller had passed in. The
  class now follows `TomAccessControlInformation` exactly: private backing
  collections, copied in the constructor, exposed through `List.unmodifiable` /
  `Map.unmodifiable`. The two ACI-side classes finally read the same way, and
  neither can be edited behind the issuer's back — a subscription is decided by
  whatever minted it, not by the code reading it. Callers that assigned to
  either field must construct a new instance instead; nothing in the kernel did,
  and `bearer_authentication.dart` only ever read them.

- **Breaking: a scope id that is empty or contains `.` is now refused.** Ids
  are joined with `.` to build the scope path, and nothing looked at the string,
  so an id carrying the separator forged a segment boundary: `TomScopeBase(
  scopeId: 'a.b')` rendered as exactly the same path as the unrelated chain
  `'a'` → `'b'`, and an empty id rendered as `''`, the string consumers are told
  to read as *no scope at all*. The path is not cosmetic — it is the prefix that
  resource and authorization lookups are keyed on — so two structurally
  different trees producing byte-identical paths meant a scope could name
  another scope's resources. `initScope` now rejects both with a
  `TomScopeException`, which covers `TomScope.withScope` and the `TomScopeBase`
  constructor too, since both route through it; the check therefore runs once
  per scope rather than on every path build, and runs before any field is
  written, so a refused call leaves the instance still initialisable. Nothing
  else about the id is policed — spaces, slashes and non-ASCII are unambiguous
  and stay legal. Ids written as literals in source cannot trip this at all;
  the exposure it closes is the case the module exists for, one scope per detail
  row named from the row. What was Best Practice 3 in
  `doc/scope_ids/scope_ids.md` ("avoid embedding `.` in an id") is now a
  guarantee rather than advice.
- **Breaking: the scope guards now throw `TomScopeException` instead of
  `StateError`.** Adding id validation would otherwise have given a 300-line
  module two unrelated error families for the same kind of failure — "this
  scope is not usable". The kernel's own precedent is decisive (roughly 130
  `Tom*Exception` subclasses against five `StateError`s in all of
  `lib/src/tombase/`), so the existing identity guards were converted rather
  than a second family introduced. Keys are
  `scope_ids.<operation>.<condition>` and `parameters` carries the offending
  value, which makes the failures greppable and translatable like every other
  kernel error. Callers catching `StateError` around scope construction or
  installation must catch `TomScopeException`.
- **Breaking: a `TomScopeMixin` instance whose `initScope` never ran is now
  refused at the point of use, not at the point of consequence.** Because
  `initScope` may be called after construction — a documented pattern, for a
  scope whose parent is only known later — there is a window in which an
  instance exists and is not yet a scope. `runInScope` read neither `id` nor
  `parent`, so it installed the half-built object onto the zone without
  complaint: the body ran, every line of it saw `TomScope.current` return the
  broken instance, and the failure surfaced at whichever later call first asked
  for a path — a resource lookup, an authorization check — as a
  `LateInitializationError` naming a mangled private field and mentioning
  neither the class nor the missing call. Installation now throws a
  `TomScopeException` naming both, and so do `id`, `parent` and `getScopePath()`, which
  previously threw the same unhelpful `LateError`. `initScope` additionally
  refuses a `parentScope` that has no identity of its own, which closes the
  variant where a perfectly good child installs cleanly and the chain walk hits
  the broken parent later. Checking the parent there rather than during the
  path walk is what keeps both checks O(1): an initialised scope has a fully
  initialised chain by induction, since the identity is write-once and a parent
  cannot lose one afterwards. Together they buy one invariant — whatever
  `TomScope.current` returns is usable. Calling `initScope` twice is still
  rejected, unchanged. `InScopeBuilder` still captures an uninitialised scope
  without complaint and refuses at invocation; capture is not use, and a widget
  may legally be constructed with a scope identified before the first build.
- **Breaking: `convertMinutesToUtcOffset` rejects offsets outside ±14:00.** The
  hour field is two digits wide and the padding never truncates, so an
  unbounded offset rendered as `+100:00` — a string the function accepted
  happily and every ISO 8601 parser downstream rejected. Values outside ±840
  minutes now throw the new `TomFormattingException`
  (`formatting.utc_offset.out_of_range`), carrying the offending value in the
  message and in `parameters['totalMinutes']`. The bound is the reachable range
  of the packaged IANA data, measured across every location's transition table
  (−720 Pacific/Kanton through +840 Asia/Anadyr, nothing outside), so it never
  refuses a value the timezone API can produce; it is inclusive because
  Asia/Anadyr sits exactly on it. Offsets obtained from a `TomTimezone` are
  always in range, so `getUtcOffsetStringOn`, `toStringOn` and `toString`
  cannot throw — only the static `TomTimezone.convertMinutesToUtcOffset`, which
  takes an arbitrary `int`, can. This is the one function in `little_things`
  that raises: the trace formatters stay silent because they run while
  reporting some other failure, which formatting an offset does not.
- **Breaking: `TomAccessControl` subclasses must move their rule.**
  `checkAccessibility` and `resolveAuthState` are now `@nonVirtual` — they
  compute the user/deployment meet described above, and a cap any subclass could
  sidestep by overriding the method everybody already calls would not be a cap.
  Override `checkPrincipalAccess` / `resolvePrincipalAuthState` instead (the
  *user* operand; the rule is unchanged, only the method it belongs in), and
  `resolveServerAuthState` for the *deployment* operand. That last one defaults
  to `TomAuthState.full` — uncapped — because a control naming a role, a group
  or a resource key has no opinion about which features a deployment licenses,
  and a participant with no opinion must return the identity element.
  `TomEntitlementAccess` overrides it, since entitlement patterns are the grant
  carrier.
- **Breaking: several public members are no longer writable (TCCA16).** Each was
  a process-wide switch that a single caller could flip for everybody:
  `TomClientRemoteContext.current` is now a getter (use `setCurrent` once at
  startup, or the new zone-carried `runWithContext` for a scoped override, plus
  `resetCurrent` for tests); `TomWorker.workerCount` is a getter (writing it
  handed two live workers the same name) with `resetWorkerCount` for tests;
  `TomHttpMethod.methods` is an unmodifiable map; `TomScope.defaultScope` is
  `final`; `TomContentDisposition.attachment` is `const`.
- **Breaking: `TomWorker.executors` and `TomWorker.isMainIsolate` are no longer
  writable either (tcinc56).** The two statics TCCA16 left standing beside
  `workerCount`. `executors` now reads back an unmodifiable — but live — view;
  register through `addExecutor` / `removeExecutor` / `clearExecutors`. Every
  message handler dispatches off the one backing list, so a caller who replaced
  it wholesale silently detached dispatch from every later registration.
  `isMainIsolate` is a getter, and the one that mattered: it is load-bearing,
  since `sendToCreator`, `executeInCreator` and the server's authorization and
  cache layers all branch on it, so a caller who assigned it could make the main
  isolate act as a worker. The worker-side transition is internal; tests reach
  the other side through `simulateWorkerIsolate` / `resetIsMainIsolate`.
- **Breaking: three members were removed.** `TomNullInterface` is now private —
  it only ever existed to give the internal null-component marker a type, and no
  consumer could meaningfully implement it. `TomException.newField` was a
  never-used "reserved for future use" field. `TomScopeMixin`'s `id` and
  `parent` setters are gone; `initScope` is the single write-once entry point.
- **Ambiguous bean bindings now throw instead of warning (TCCA18).** When two
  implementations qualify equally within one selection tier, the locator raises
  `beanlocator.initialization.ambiguous_implementation` naming both candidates
  and pointing at `@TomEnvironment` / `@TomPlatform` to distinguish them.
  Previously the first candidate won and the second was logged as a warning —
  which binds a deployment to an arbitrary implementation, the failure mode
  where the code runs, the tests pass and production misbehaves.
- **Reflection widens `int` onto `double` fields (tcca20).** JSON and
  command-line `key=value` arguments have no int/double distinction, so
  `{"rate": 2}` decodes to an `int` and a whole-number `double` was previously
  unrepresentable. The converse is deliberately absent: narrowing would need a
  rounding policy, and truncating `2.5` silently loses data.
- **Breaking: `makeCleanJsonMap` keeps null values and returns
  `Map<String, Object?>` (tcdocc1).** The sanitiser's helper used `null` to mean
  both "this *is* JSON's null" and "this has no JSON form", so a deliberate null
  was dropped alongside a `DateTime` — losing the distinction between an absent
  field and one that is present and null, which is exactly the distinction a
  PATCH-style update, a "explicitly cleared" setting, or a nullable-by-schema DTO
  is built on. It bit hardest through `TomJsonSerializable`, whose `toJson`
  returns `Map<String, Object?>` and is documented to carry nulls: converting a
  value object routes its map through the sanitiser automatically, so the
  interface promised the type could describe its own state and the sanitiser then
  edited the description. The two answers are now separated by a private
  sentinel; `null` passes through in maps and in lists (where dropping it also
  shifted every later index), and only genuinely unencodable values are filtered.
  Callers that stored the result in a `Map<String, Object>` need the wider type.
- **Registering the UTC singleton is no longer reported as an ERROR (tccc3).**
  The IANA database ships `Etc/UTC` and has no location keyed exactly `UTC`, so
  `TomTimezone` registers its documented `utc` singleton on every start of every
  process — an ERROR line that is always present is how a team learns to filter
  out ERROR. It is now DEBUG. A genuine ERROR was added for the case that
  actually is broken: the database loaded no locations at all, so only UTC is
  available and every other lookup will miss.
  `TomTimezone.populateFromLocations` is `@visibleForTesting` so that branch can
  be driven, since on a native platform the embedded database always loads.
- `TomTimezone.convertMinutesToUtcOffset` now delegates to the top-level
  `convertMinutesToUtcOffset` in `little_things/formatting.dart` so the two entry
  points cannot drift apart.
- **The `Authorization` header is omitted rather than sent as `Bearer null`**
  when nobody has signed in. An absent credential is a clean 401; a malformed one
  is the same rejection dressed up as a parse failure.
- **Stack-frame truncation kept the wrong frames (RCL1).** `_processStackFrames`
  iterated oldest-first, so a depth limit discarded the frames nearest the throw
  site — the useful ones — and kept the outermost `main`-side frames. It now
  iterates newest-first, as its own documentation already claimed.
- `TomAuthenticationResult` gained `requires2FAEnrolment`,
  `availableTwoFactorMethods` and `twoFactorEnrolmentSkippable`, so pass 1 can
  tell a client that the user must *enrol* a factor rather than merely present
  one.
- **Dependency floors were raised, and two dependencies added.** `tom_basics`
  `>=1.0.3` (`setCurrentEnvironment` now applies its fallback unconditionally;
  1.0.2 added `TomRuntime.reset()`); `tom_crypto` `>=1.1.0` (earlier versions
  drew secure random bytes with an exclusive bound of 255, so no byte could be
  `0xFF` — a bias inherited by every RSA key pair and every password salt this
  package re-exports); new `crypto ^3.0.0` for the `TomTotp` HMAC-SHA1
  primitives; new `meta ^1.9.0` for the `@nonVirtual` annotations that make the
  deployment cap load-bearing. Dev: `tom_reflection_generator` `>=1.3.1`
  (type-literal annotation arguments are now emitted import-prefixed).
- **Breaking: `TomResourceKeyAccess` now answers about the principal it is
  given.** `checkPrincipalAccess` dropped its argument and consulted the
  ambient zone instead, making it the one control in the family that did not
  answer the question the family's contract states — "whether *[principal]*
  satisfies this control". Outside a request zone the divergence was silent and
  fail-closed: `TomResourceKeyAccess('x').checkAccessibility(p)` returned
  `false` for a principal `p` whose `aci.resourceKeys` contained `'x'`, because
  the zone was empty. The rule is now stated once over an explicit operand,
  `TomResourceKeyProtection.isProtectedFor(principal, key)`, and reached two
  ways: the control passes the principal it was asked about, while
  `isProtected`, `tomProtect` and `tomProtected` keep their zone-reading
  behaviour unchanged and now delegate to it. The master switch
  `globalSettingProtectionDefault` is unaffected and still gates the whole rule
  — with it `false`, every principal is granted. Callers who relied on the zone
  being consulted *through an access control* must pass the principal instead,
  which is what every call site already looks like since `checkAccessibility`
  takes one. The suite's `should integrate with TomResourceKeyProtection` case
  asserted the old behaviour and was replaced.
- **Breaking: reading a `TomServerCall` before `send()` raises one key, not
  seven (tcincb11).** `TomServerCall` has eight members that read something off
  the response, and each raised its own key for the single condition "nothing
  has been sent" — `read()` under
  `server.send.illegal_state_read_must_be_after_send`, and the six `getResponse*`
  accessors each naming themselves,
  `…illegal_state_read_headers_only_after_sending` and five more. The shared
  guard existed but took the key from its caller, so the count grew with the API:
  code handling "this call has not been sent" had to match seven keys, and a
  ninth reader would have brought an eighth. That contradicts the convention
  `TomException` states for keys — `<area>.<operation>.<condition>`, whose last
  segment names the *condition* — and an accessor is not a condition. The guard
  now owns the key: all eight readers raise
  `server.send.illegal_state_read_must_be_after_send`, and `_requireSent(what)` /
  `_requireSentResponse(what)` take only a prose description, so a new reader has
  no key to choose and the convention holds without anyone deciding again. The
  detail is not lost, it is demoted: the message names the value that was wanted
  and the `read` parameter carries it, which is where a detail belongs and where
  it does not fragment the contract. `read()` keeps its own non-awaiting guard so
  its timeout still covers the headers as well as the body. The six retired keys
  were referenced nowhere outside their own declarations. Two suite cases,
  exhaustive over a map of every reader, pin the key and the surviving detail.

### Tests

- **`bearer_auth_barrel_export_test.dart` pins that a consumer can *name*
  `TomClientJwtToken`, not merely call the members that return it
  (tcincb13).** `TomBearerAuthentication` puts the type in three public
  positions — `clientJwtToken`, `clientAuthorizationJwtToken` and both
  parameters of `convertTokenPayloadToPrincipal` — but it is declared in
  `tom_crypto`, and it reaches consumers only because the barrel re-exports
  that package unfiltered. Nothing said so and nothing checked it, so
  narrowing that one `export` line to a `show` list would have dropped the
  type from the public surface with every file under `lib/` still compiling:
  they all import `tom_crypto` directly, and the break is visible only from
  outside the package.

  The guard is compile-time, following `timezones_barrel_export_test.dart`:
  it imports nothing but the barrel and writes the type in each position the
  API uses it, so losing the re-export stops the file compiling rather than
  failing an assertion. Its first test reads its own source and holds the
  import list to the barrel alone — adding a direct `tom_crypto` import would
  otherwise leave it green while proving nothing. `tom_core_flutter` carries
  the matching guard for the barrel it re-exports this one through, which is
  the import a Flutter application actually writes; using the API is not the
  same as naming its types, and that package's existing coverage called
  `setTokens` through its barrel without ever writing `TomClientJwtToken`.

  `doc/security/security.md` now states the contract next to the `tom_crypto`
  dependency row: a dependency's type in this module's own signatures has to
  be nameable, and it is, through the barrel and with no second import.

- **`timezone_throw_contract_test.dart` now guards which type a refusal
  surfaces as, not only why it happens (tcinc339).** A second table lists the
  module's three refusal shapes — `fromName` returning `null`, `findTimezone`
  throwing `TomTimezoneException`, `parseFromString` throwing `FormatException`
  — each with the call that provokes it, so an attribution is only ever judged
  against a behaviour that runs. The rule over the readme is that every
  exception type a passage names must belong to something that passage
  mentions, which is exactly what the defective row failed: it named
  `TomTimezoneException` beside "parse failures" and never mentioned
  `findTimezone`. A denial — "throws `FormatException` and never
  `TomTimezoneException`" — is struck out before judging, because the sentence
  naming the type it is *not* is the one most worth writing here.

  Two existing mechanisms were corrected in passing. The file's own dartdoc
  claimed `findTimezone` was "the only thing in the module that throws", which
  is the misconception under repair; it is the only source of
  `TomTimezoneException`, and saying so is the point. And the passage scanner
  read any line carrying a throw word on its own — right for a trailing code
  comment or a table row, which are complete claims, but wrong for prose, where
  it made the guard a rule about where a sentence may wrap. Self-contained
  lines are now recognised as such and everything else is read with its
  paragraph. The readme joins the guide and the API mirror as a scanned
  document. Mutation-checked against five drifts: the readme as it stood, the
  defective row alone, the denial handling removed, every line standing alone
  again, and the parser raising `TomTimezoneException` as the old row claimed.

- **The two anchoring factories are tested where the ordinary day breaks
  (tcinc338).** Eleven tests in `timezones_test.dart` pin what
  `TomZonedDate.fromDateTime` and `TomZonedTime.fromDateTime` anchor to when
  the obvious answer is wrong. Four feed `America/Santiago` on 2024-09-08,
  where the zone springs forward at midnight: the value lands at 01:00, equals
  what the primary constructor produces, satisfies `isDate`, and survives a
  serialization round trip. Four feed `Pacific/Apia`, which stood at UTC-11 on
  1970-01-01 and at UTC+13 today: the epoch anchor is the zone's *1970* local
  date, not a fixed UTC instant, so the stored UTC day is 1970-01-01 only
  because the offset of that era is used. Three more sit in the `isDate` group
  and cover the widened predicate, including that a `TomZonedDateTime` at 02:00
  in the same zone is still rejected — widening must not become "any hour in a
  DST zone passes".

  A zone whose midnight exists cannot distinguish "anchored to the start of the
  day" from "hour forced to zero"; the two differ only on the seven zone-days
  in 2024 and five in 2025 that skip midnight, which is why every earlier test
  passed against a predicate that was wrong. Two assertions in the same groups
  that read the inherited UTC components now read the local accessors, because
  what they meant to check is the calendar reading, not the storage frame.
  Mutation-checked against four drifts: `isDate` comparing components only,
  `_zoneOf` without its `TZDateTime` branch (killed by the cross-frame
  agreement test alone), the time factory anchoring at the UTC epoch, and it
  anchoring the epoch with the zone's present-day offset.

- **The offset index has a stated contract now (tcinc337).** Five tests in
  `timezones_test.dart` hold the behaviour the shelf-life caveat describes: a
  DST zone is in the bucket for the offset it has now and in no other, over
  fifty zones move between buckets across the year, the buckets partition the
  database by current offset, and `firstWithOffset` is the head of
  `allWithOffset` — which is why the documentation can tell callers not to
  expect the well-known zone.

  Every assertion reads the zone's two offsets from the database and derives
  which is current, so each holds in either season. Hard-coding "New York is at
  -300" would pass all winter and fail all summer, which is the mistake the
  documentation itself was making. Mutation-checked against three drifts:
  indexing on a fixed winter offset, indexing a zone under both of its
  seasons, and returning the tail of the bucket.

- **`comments_read_as_is_test.dart` now tests resolvability, not provenance
  (tcinc336).** The section-reference guard exempted any `§<digits>.<digits>`,
  on the reasoning that quest bug lists are flat and so a dotted number could
  not be one. That tests where a number came from rather than whether a reader
  can follow it, and three `§5.26` citations sat in `access_controls.dart`
  naming no document — real specification sections, unreachable all the same.
  A section number is now allowed exactly when the same line says what it is a
  section *of*: a published standard, a specification this package implements,
  or a sibling document.

  The naming is required on the same line rather than anywhere in the file.
  File scope would resolve citations split across a line wrap, but it also
  licenses a work-item pointer nine hundred lines below an unrelated document
  mention; and dartdoc is read one member at a time, so in the generated API
  docs a document named forty lines up is not available to the person reading
  the citation. The practical consequence — reflow the paragraph so the
  document and its section number stay together — is stated in the guard.

- **New guard: `timezoned_dependency_table_test.dart` (tcinc335).** A dependency
  table is wholly derivable from the source, and it is the part of a document
  that goes stale most quietly: an import added to a file changes nothing a
  reader can see, and a missing row looks exactly like a dependency that was
  never there. The timezoned table had lost a `little_things` entry point that
  way. It is now compared to the module's imports in both directions — a
  dependency with no row is an omission, a row with no dependency is a leftover
  — along with the `Imported by` column per dependency, since a table can name
  the right four things and still attribute them to the wrong files.

  The closing note is checked too, bounded at both ends. It names the types
  living in `date_timestamp.dart` in an aside before stating what that file
  imports, and goes on to mention `timezones.dart` again afterwards; a scan
  reading the whole paragraph would take three class names for dependencies at
  one end and keep finding `timezones.dart` at the other however badly the claim
  itself was worded. Mutation-checked against five realistic drifts, including
  the one that produced the original defect.

- **New guard: `timezoned_shared_members_test.dart` (tcinc334).** The roster of
  members `TomTimezoned` offers is stated as code, not as strings: a map from
  each name to a closure that reads it off a base instance. A member removed
  from the class takes this file's compilation with it, and one that is renamed
  cannot be papered over by editing a literal — which is the failure mode a
  list of names has. Each closure is then run, so the entry proves the member
  is readable rather than merely declared.

  Against that anchor the guide's shared-member block is compared in both
  directions, so neither a stale entry nor a missing one survives. The scan
  reads only the first fenced block under the heading — the roster itself —
  because anything fenced after it is illustration, and illustration names
  locals and per-subclass members that would make the roster look like whatever
  the examples happen to mention. Comments and parameter lists are dropped: a
  signature names its argument too, and an argument is not a member. Three
  further tests hold `convertToTimezone` to the subclasses that declare it, and
  a fourth pins the reason it matters — that `now()` and `parseFromString`
  return the base class itself.

- **New guard: `serialized_form_trailing_space_test.dart` (tcinc333).** The
  emitted bytes are the anchor: a table of all six ways the module renders a
  value, each asserted to end in exactly one space, with the table's own size
  checked so it cannot quietly shrink. Against that, a scan over the three
  documents that state the format — the guide, the API mirror and the source
  dartdoc — reads every format template (`ISO8601_OFFSET_TIMEZONE`,
  `{offset}_{timezone}`) and requires the passage around it to name the space.

  The passage is a markdown section or one member's dartdoc run, not the whole
  file: a single mention elsewhere would otherwise cover every silent template
  in the document, which is how a reader ends up in a section that never says
  it. Whitespace is folded and three phrasings are accepted, so the guard
  constrains what is said rather than how it is worded. It found eleven silent
  sites where the report that prompted it had named two, and it is what will
  say which documents must change if the space is ever removed.

- **The serialization suite could not tell the two offsets apart (tcinc332).**
  Its authority case parsed an `Asia/Tokyo` string, and Tokyo has no DST — its
  offset now and its offset at any instant are the same `+09:00`, so the
  assertion held equally under "restates the offset from the zone now" and
  under "recomputes it for the value's instant". The one zone that could not
  distinguish the rules was the one being asked. A new case picks a DST zone
  and an instant in whichever season the suite is *not* running in, asserts
  that the two readings differ before comparing anything, and then pins the
  serialized field to the current offset and the round-tripped instant, zone
  and derived offset to the value's own.

- **New guard: `timezone_throw_contract_test.dart` (tcinc331).** One table
  lists the reasons `findTimezone` throws; each entry carries the call that
  provokes the failure and the words the documentation must use to warn about
  it. Both halves are driven from that table, so a mode cannot be listed
  without being executed and an executed mode cannot go undescribed — a
  keyword scan alone would pass against wording the code has outgrown, and a
  behaviour test alone is what the module already had while the description
  drifted.

  The two markdown files are checked passage by passage rather than as a
  whole, because the omission was a single trailing comment and a file-wide
  search finds the missing half somewhere else and reports nothing. A comment
  sitting on a call is read on its own line for the same reason: reading it
  with its block let a neighbouring line about `fromName` returning `null` for
  a name *not found* supply words that said nothing about `findTimezone`.
  Whitespace is folded before matching, so the guard constrains what the prose
  says and not where it wraps.

  `timezones_test.dart` gains the two cases its `findTimezone` group lacked —
  an unknown name with an offset and without one. The group enumerated eight
  others, and that gap is why the behaviour could go undocumented with nothing
  failing.

- **The platform-selection guard now follows the imports (tcinc330).** A sixth
  case walks each arm of the conditional import through the `timezone` package
  and rejects any `dart:` library the arm's own condition does not guarantee —
  the whole of `dart:io`, `dart:isolate`, `dart:ffi` and the web set for the
  default arm, and the opposite platform's set for a conditional one. This is
  the check that would have caught a default arm importing a filesystem-backed
  entry point, and it caught exactly that when it was written. Resolution goes
  through `.dart_tool/package_config.json` and fails loudly if that file is
  absent, because an unresolvable import would otherwise look like a clean
  result. The walk stops at every package other than `timezone`: the choice
  this import makes is between `timezone` entry points, and descending into an
  unrelated package would only report conditional imports it resolves for
  itself.

- **New guard: `timezoned_platform_selection_test.dart` (tcinc329).** The
  module picks its initializer with a conditional import whose first line is
  the *default* arm, not the native one — so every VM target, server and CLI
  and test runner and Flutter alike, takes `init_tz_flutter.dart`, and
  `init_tz.dart` is reached only where neither `dart:io` nor `dart:js` exists.
  The file names say the opposite, and that reading is unfalsifiable from
  either side alone: the source is correct and mentions no platforms, the prose
  names platforms and quotes no condition. The guard holds the two together —
  the `import` and `export` arms must stay identical (the source asks for this
  in a comment and nothing else enforced it), each arm's dartdoc must name the
  role the selection gives it, any quotation of the import block must be
  verbatim, every `package:timezone/…` library the documents name must be one
  the module imports, and every "*this entry point on that platform*" claim
  must name a library that platform's own arm actually reaches. Each scan
  carries the package's usual non-vacuity check.

- **New guard: `serialized_form_is_not_rebuilt_test.dart` (tcinc327).**
  `toString()` returns the complete serialized form, prefix included, but both
  halves are public and both look like ingredients, so joining a value's
  `getSerializationPrefix()` to the value itself is an easy and entirely silent
  mistake — the result is only wrong when something tries to read it back. The
  scan forbids that join across `lib`, `test`, `example` and `doc`, matching on
  a backreference so that joining one value's prefix to a *different* value,
  which is a deliberate act, stays allowed. A second rule forbids a doubled
  prefix reaching any artefact, wherever it came from. Both carry the
  package's usual non-vacuity checks, and this one also self-tests its
  patterns against four synthetic offenders and four legitimate uses, so a
  pattern that stopped matching would fail rather than report a clean tree.
  `timezones_test.dart` states the same rule at the library level: every
  subtype's rendering starts with its own prefix, and prepending it again
  yields a string the predicate rejects.

- **The documented settings round trip is now executed, not just written
  down.** The settings suite exercised the two DTOs thoroughly and the exchange
  not at all — which is how a transport that never existed came to be
  documented four times without anything noticing. Two cases run the shape the
  documents now show, end to end over a stubbed HTTP client: a 200 answer
  deserializes into a populated `TomGetSettingsResult` and the request really
  goes out as a `POST` to the documented URI, and a 401 reports through the
  `error` half of the pair while still handing back a result object — which is
  the reason the documented order is check-then-read, since a caller who skips
  the check reads empty settings as if they were real.
- **The settings result's "unset is null" contract is pinned on the
  deserialization path, not only the constructor.** The existing round-trip
  case set every field, so it could not observe any default at all, and the
  null-default case only exercised the constructor — leaving the path a client
  actually receives a result by unguarded for the guarantee the API mirror now
  states. Two cases close it: a default-constructed result still reports all
  eight strings `null` after a serialize/deserialize cycle, and an
  `organization` deliberately set to `""` still comes back empty rather than
  null, so the distinction the contract rests on is shown to survive the wire
  in both directions.

- **Every `TomAuthorizationGroup` inspection helper is pinned against a hidden
  member.** One case per helper — `members`, `memberCount`, `findMember`, and
  the `isEmpty` / `isNotEmpty` pair over an all-hidden group — each of which
  failed before the change. A fifth reveals a hidden member after the fact and
  asserts it returns to every helper, so the filter is proven to be evaluated
  per call rather than latched at registration. The sixth is the guard the
  other five need: unregistering a *hidden* member and then revealing it must
  not resurrect it, which is what fails if registration bookkeeping is routed
  through the visibility filter along with everything else.

- **The UTC normalisation of both 2FA expiries is pinned at the constructor.**
  One case per class builds a challenge / offer from a local `DateTime` and
  asserts the field reads back `isUtc` *and* on the same instant — normalising
  must re-label the instant, not shift it. A `toString()` case per class pins
  the printed form, which is where the drift was visible: the same challenge
  used to print two hours apart on two machines. Two guards cover what the
  cleanup must not break — the enrolment chooser's `null` deadline must stay
  `null` rather than acquire one, and `isExpired` must answer identically for a
  local `now` as for a UTC one, since the normalisation of its argument was
  dropped.
- **The 2FA freshness filter is pinned on both getters, in both directions.**
  Four cases assert that a lapsed or burned challenge / offer reads as nothing
  pending. Two more guard the boundaries the fix had to respect: `fromClaims`
  must *still* decode what the getter filters out (otherwise the filter has
  leaked into the wire decoder), and the enrolment chooser must survive the
  filter even though its absent attempt budget reads back as `isExhausted`
  (otherwise the filter deletes the choosing stop and the enrolment flow with
  it). Both of those pass before the fix as well as after — which is the point:
  they are the guards, not the demonstration.
- **The fail-closed attempt budget is pinned on both 2FA readers.** One case per
  class asserts that a payload whose `attemptsAllowed` is missing (or the wrong
  shape) still yields a *non-null* challenge / offer, but one that is already
  `isExhausted`. Written as a pair deliberately: whichever of the two siblings
  someone edits, the other's test still states the rule. Verified to bite by
  temporarily changing the fallback to the constructor's `3` — both fail with
  `Expected: <0> Actual: <3>`.
- **`TomClientLimitsInformation` has the immutability group its sibling always
  had.** Four new cases: unmodifiable `enabledModules`, unmodifiable `quotas`, a
  case asserting that an empty instance and a populated one refuse writes the
  *same* way — the asymmetry the `const` defaults created was visible only by
  comparing the two — and one proving the constructor copies rather than aliases,
  by editing the caller's own list and map afterwards and expecting the instance
  to be unmoved.
- **`TomResourceKeyAccess` is pinned to its argument.** The group grew from two
  cases to seven, covering both sides of the master switch, a `null` principal,
  and a principal that holds the key with **no zone installed** — the case that
  can only pass if the control reads what it was handed. One case sets the two
  operands against each other deliberately, running the check inside a zone
  holding a *different* principal, so a zone read cannot rescue an argument
  that lacks the key nor condemn one that holds it.
- **Scope ids are pinned at all three entry points.** A
  `scope ids are validated` group runs the five unusable ids (`a.b`, `.`, `a.`,
  `.a`, `''`) through `withScope`, the `TomScopeBase` constructor and
  `initScope` — one check covers all three, but all three are public, so all
  three are asserted — and matches on `parameters['scopeId']` so a test cannot
  pass on some *other* rejection. Three more cover what the check must not
  break: the deeper chain the dotted id used to forge still builds and still
  renders `a.b.c`; a refused id leaves the instance initialisable, so a caller
  that catches and retries with a clean id succeeds; and ids that cannot forge
  a boundary (slashes, spaces, hyphens, non-ASCII, a U+00B7 middle dot) stay
  legal, because the rule is about the ambiguity and not the alphabet. Deleting
  the guard turns all fifteen red.
- **The scope failure modes the suite stopped one case short of.** Seven tests
  close the gap between "every documented behaviour is covered" and "every way
  the module can be misused is covered". Scope identity is write-once, so a
  second `initScope` is refused and a refused call moves neither the id nor the
  parent; when an unusable id and the write-once field are violated by the same
  call the id diagnostic wins, because the check runs first and names the thing
  the caller can fix. `InScopeBuilder` is now exercised in the direction that
  distinguishes *installing* the captured scope from merely not disturbing the
  ambient one — a builder captured at the root and invoked inside
  `withScope('elsewhere')` must yield the root — and all six `wrapNn` wrappers
  are run with real callbacks rather than only `null`, since each is a separate
  hand-written forwarding body. Re-entering `withScope` with an id already on
  the zone nests and repeats the segment (`app.app`) where `runInScope` on the
  same instance does not, a contrast now pinned rather than assumed. Every one
  was proven fireable by mutating the implementation.
- New suites for every new module: `scheduling_test.dart`,
  `scheduled_job_test.dart` (plus `test/contracts/scheduling_contract.dart`, the
  shared store/lock contract), `file_transfer_test.dart`,
  `observable_enum_test.dart`, `server_principal_test.dart`.
- Bean selection is now covered end to end: `beanlocator_selection_test.dart`
  (the four tiers), `beanlocator_ambiguous_selection_test.dart` (the new throw)
  and `beanlocator_excluded_selection_test.dart`, over a shared
  `test/support/bean_selection_support.dart`.
- `timezones_logging_test.dart` and `timezones_empty_database_test.dart` pin the
  new log levels and drive the empty-database branch.
- `api_reference_coverage_test.dart` guards the doc tree against drifting from
  `lib/`.
- **`comments_read_as_is_test.dart` keeps shipped prose free of development
  history.** Roughly 170 comments across `lib/`, `test/`, `example/` and `doc/`
  pointed at internal work items (`bug §50`, `tests §34a`, quest todo ids) or
  narrated what the code used to do — both unresolvable for anyone reading the
  published package, and both easy to reintroduce while the work is fresh.
  Every site in this package has been restated as the rule that holds now,
  usually by turning the past tense into a conditional, and the new suite fails
  the build if one comes back. It distinguishes the three uses of `§` that look
  alike: citations of published standards (`RFC 4226 §5.3`, `CWE-117`) and
  specification sections (`§5.26`, `CE-ER §7`) are kept, only work-item
  pointers are refused. Traceability now runs todo → code through the todo's
  own `references` list, so the link outlives the work item without the code
  carrying its id.
- **`import_convention_test.dart` pins how the package refers to its own
  libraries, in both directions.** Inside `lib/` a sibling module is reached
  relatively; from `test/`, `example/` and `tool/` it is reached as
  `package:tom_core_kernel/…`. Each side has one correct form and the wrong one
  resolves anyway, so neither mistake announces itself. A `package:` URI into
  the package's own `src/` is what `implementation_imports` refuses for every
  other package — it passes only because the package is importing itself — and
  a relative `../lib/…` from outside gives the library a second identity, so
  the same class arrives under two types. `dart analyze` catches neither: the
  shared options enable four lint rules and neither of those two is among them.
  The barrel form inside `lib/` is deliberately not covered; it names a public
  entry point rather than reaching past one.
- **`scope_ids_test.dart` now pins the zone-elision branch it names.** The test
  called "is a no-op zone when the scope is already current" asserted only that
  `TomScope.current` was unchanged inside the body — which holds on *both*
  branches, because installing the identical scope on a child zone resolves to
  the same value. It therefore passed with the identity check deleted. It now
  compares `Zone.current`, which is what distinguishes the two paths, and also
  asserts the body ran and its result was returned; a companion test covers the
  other branch, where a different scope does get a child zone.
- **`scope_ids_test.dart` covers the window between construction and
  `initScope`.** A `before initScope has run` group asserts that installation
  is refused and the body never runs, that the instance cannot be another
  scope's parent, that `InScopeBuilder` refuses at invocation, and that `id`,
  `parent` and `getScopePath()` all name the class and the missing call. A
  fifth test holds the other side of the line — a scope identified after
  construction installs normally — so the guard cannot be tightened into
  breaking the pattern it is protecting.
- **`scope_ids_test.dart` pins the reason `buildScopePath` needs no cycle
  guard.** The walk is unguarded on the grounds that a scope built through this
  module cannot form a loop, which rests on `initScope` refusing an
  uninitialised parent and writing the link once. A
  `the parent chain cannot be made cyclic` group closes each of the three ways a
  link could be bent back — parenting to a scope that has no identity yet,
  self-parenting, and re-pointing an established parent — so relaxing either
  mechanism fails here rather than in whichever isolate later walks the loop.
  The loop itself is deliberately untested: a test that hangs until the VM dies
  takes the suite with it.
- **`oauth_contract.dart` had no test at all; it now has fifteen.** Nothing in
  the kernel suite named the file — not the four wire DTOs, not the service
  interface, not the API declaration, not one of the four id constants. Each
  DTO is round-tripped through the reflection JSON codec, which is the failure
  these types are actually prone to: they carry no behaviour, so a renamed or
  dropped field breaks nothing at compile time and surfaces only as a value
  that arrived empty. A contract group pins the `/oauth` mount, the three
  endpoint ids as literals (the server restates them as strings in
  `@TomApiEndpointImplementation`, where a rename compiles and binds the
  handler to nothing), the methods and addresses, the request and response
  types, and `TomPublicAccess` on all three — which is not a detail but the
  precondition for the flow: this is how a caller who is not yet authenticated
  becomes authenticated. The callback's `urlParameterMapping` is asserted twice
  over, as a map and as a resolved URL, because `error_description` →
  `errorDescription` is the one entry whose two spellings differ and a typo in
  it fails only at run time, on the one path a deployment cannot rehearse
  without a real provider. A compiled stub implementation links
  `TomOAuthApiService` to the endpoints it stands for — the interface and the
  declaration are two independent statements of the same three calls, and an
  implementation is the only thing that fails when one of them moves.
- **`Tom2FAMethodDescriptor.scoped` is pinned against the documented table.**
  The descriptor is three resource keys rather than three strings, and `scoped`
  is what derives them; a client resolves the result verbatim, so drift in the
  derivation is a blank label in every locale at once. Six cases cover the
  derivation itself (against the table in `doc/security/security.md`), the
  scope constant the server's resource bundle is keyed under, the
  no-literal-text rule the class documents, the all-defaults constructor the
  reflection path needs, the `toString()`, and the round-trip — the keys are
  derived on the server and read on the client, so that is where a renamed
  field would show up.

### Examples

- **The samples' process identity came from a sample rather than from whatever
  started it, so the log header changed format halfway through a run
  (tcincb4).** The framework builds its log header as
  `${TomPlatformUtils.current.getIsolateName()}-$isolateName`, and until an
  application installs a platform implementation the fallback answers with the
  empty string — so a framework log line reads `<timestamp> - INFO …` instead
  of `<timestamp> main-main INFO …`. `run_all_samples.dart` never installed one.
  The gap had been masked by an accident: `samples/beanlocator/01_…`, the first
  sample of the first module, installed `TomStandalonePlatformUtils` as a side
  effect of a runtime demonstration, and the twelve modules after it silently
  inherited it. Tidying that sample's imports removed the accident and exposed
  the coupling, leaving one run with two log formats — modules 1–13 unlabelled,
  `runtime/` onwards labelled, because those samples configure it themselves.

  The fix is not a line in the master runner. Establishing the platform there
  would relabel a full run and leave every *individual* sample run unlabelled,
  which is the same two-format fault on a different axis — confirmed by running
  `logging/01` on its own and watching it print a bare `-`. It went instead
  into the one registry-free library that every way of starting a sample funnels
  through, so a single rule covers the master run, a group runner and a single
  file: whatever prepares a sample to run establishes the process platform. That
  widened the library's job past its name, so `example/sample_asserts.dart` is
  now `example/sample_preamble.dart` and `requireAsserts()` is
  `prepareSampleProcess()`, across all 83 call sites, the sweep script's static
  check, and the README. `TomStandalonePlatformUtils` arrives through a direct
  `tom_basics_console` dev-dependency rather than through the `tom_core_server`
  one it used to be reached by: the samples need one class, not a server
  framework, and it was already in the resolved graph transitively. Switching
  `runtime/02` and `runtime/03` to that import removed `tom_core_server` from
  the hand-written samples entirely — with it went a registry that had been
  putting `TomOAuthServer`, `TomFileServer` and their neighbours into a
  *kernel* sample's list of reflected types.

  `runtime/01` also stopped leaking. It demonstrates platform detection by
  installing local stand-ins, one of which deliberately reports Android on a
  desktop, and it used to end by installing its own implementation with the
  comment *"Leave a working implementation installed for whatever runs next"* —
  the same defect stated outright. It now restores whatever the process arrived
  with.

  Every framework log line in a full run now carries the same `main-main`
  prefix, with one exception that is a different mechanism and is tracked
  separately: lines emitted from *inside* spawned worker isolates, where
  `TomPlatformUtils` is per-isolate static state that the main isolate's
  preamble cannot reach.

- **Half the sample tree could not be traced back to a file from the output it
  produced (tcincb2).** A group's `00_run_all_examples.dart` runs its samples
  back to back into one continuous stream, so the only thing separating one
  sample's contribution from the next is what the samples themselves print. Of
  98 numbered samples, 53 opened with `=== NN: Title ===` and 45 did not: 27
  printed *nothing at all* — they ran, asserted, exited 0 and left no trace, so a
  reader watching the stream could not have told they were there — and 18 printed
  freely under a heading of their own devising, or none, so their output arrived
  attached to whichever sample had last named itself. All 98 now open `run()`
  with a banner carrying the number the file is filed under.

  The 27 silent samples gained real output, not decoration. Each already
  computed and stored every interesting value in `static` fields so its
  assertions could check them, so the new blocks surface state that was there
  all along, in the numbered-section style `resources/03` established: `1. what
  this shows:` then indented `key: value` lines. Section numbers follow the
  method ordinal rather than being renumbered 1..N, so `example3bZonelessTimestamp`
  prints `3b.` and a reader who sees a block can find the method that produced
  it. Six values that had been locals were hoisted to `static` fields to be
  printable; no assertion anywhere was added, removed or weakened.

  Two further defects surfaced on the way and are fixed here. Ten group runners
  printed a per-file heading of their own before delegating — a second title for
  one file, and **five of the ten had drifted out of step** with the sample they
  introduced, so the stream announced one number and the sample then announced
  another. All 44 such headings are gone; the sample names itself and the runner
  names the group. And `logging/05` carried its banner in `main()` only, so it
  named itself on the standalone path and was anonymous inside the group runner,
  which calls `run()`.

  That last one is why `tool/run_standalone_examples.sh` gains **two** checks
  rather than one. A static check (banner present, its number equal to the
  filename's) catches the missing or mistyped banner cheaply, before 118 VM
  starts — but it reads the file as text, so it saw `logging/05`'s banner and
  passed it. Tightening it to "the banner must be inside `run()`" would be the
  wrong repair: `beanlocator/05`'s `run()` is a one-line delegation to a class
  method that holds the banner, and is correct. The property that matters is
  that the banner *reaches the stream*, and the only honest way to know is to
  read the stream — which the sweep already produces, since the group runners
  match the sample glob and are logged. So a second check reads those logs
  afterwards and requires every sample to appear in its group's. A group whose
  runner failed is skipped, so one failure is not reported as a dozen
  consequential anonymous samples.

  `test/example_numbering_test.dart` is rewritten to the convention this
  established, and two of its rules are now different rules. It had asserted
  that *the samples which announce themselves* use the right ordinal, which was
  as much as could be asked when 45 did not announce themselves at all; it now
  asserts that **every** sample announces itself, and checks the ordinal of
  each. And where it had asserted that a runner's per-file label agrees with the
  file it introduces, it now asserts that **no runner prints one**: the
  agreement it used to check is unreachable if the second label does not exist,
  and the drift it used to catch is unreachable with it. The label-pairing
  machinery and the boxed-banner branch went with them — no boxed sample banner
  survives, and there is one banner shape rather than two.

  An emptiness rule cannot prove its own scan by finding something, so the
  floor test that guarded the old label scan (which required ≥ 35 labels and
  would now find 0) is replaced by running the label pattern against the two
  shapes of the line it exists to keep out. Both new rules were falsified before
  their zeroes were believed, as was each fault class of the new stream check.

- **The two timezoned samples that advertised a "full serialized" string were
  printing one no parser accepts (tcinc327).** Both prepended
  `getSerializationPrefix()` to the value's own rendering, which already
  carries that prefix, so `02_zoned_datetime_example.dart` and
  `03_zoned_date_time_example.dart` between them printed four doubled-prefix
  strings under a label announcing them as the serialized form. Nothing failed,
  because nothing read them back — which is precisely how a sample teaches a
  format the library does not have. Both now print `toString()` alone and
  assert that what they printed satisfies its own `isTom…String` predicate, so
  a sample that stops printing a parseable string stops passing. The rule was
  already written down in `05_serialization_example.dart`; it is now enforced
  rather than only stated, by the new guard in **Tests**.

- **The settings and bearer-authentication samples now build the endpoint that
  carries the exchange.** Neither sample touched the transport, so nothing in
  the example tree contradicted the phantom service the documents described.
  The settings sample gains a ninth case that constructs the
  `TomServerEndpoint<TomGetSettingsMessage, TomGetSettingsResult>` the documents
  show and asserts its method, URI and bearer flag; the bearer-authentication
  sample makes step 1 of its token-flow walkthrough concrete by building the
  login endpoint and asserting it carries no bearer token — which is the point
  of a login. Constructing an endpoint opens no connection, so both run without
  a server; the live round trip is exercised in the settings tests.
- **The security module's example coverage is now complete (tcinc288).** A sweep
  of every public name declared under `lib/src/tombase/security/` against the
  hand-written samples found 26 that no example mentioned — not the 17 the todo
  listed, because two of its entries had since been covered by samples 07 and 08
  and because an initial sweep that included generated `*.reflection.dart` files
  reported a flattering 14. Three new samples and three additions close all 26.
- **New: `09_two_factor_login_example.dart`.** The two-pass login end to end:
  pass 1 succeeding *without* finishing (`error` empty, `requires2FA` set, no
  authorization token — the shape a client that reads only `error` walks
  straight past), the challenge crossing the wire through
  `Tom2FAChallenge.toClaims`/`fromClaims`, a stale code costing an attempt,
  the budget burning down to `isExhausted`, and the right code derived twice —
  once as an authenticator would through `TomTotp.codeFor` and once as a
  verifier does through `decodeBase32` + `counterFor` + `generateCode`, which is
  the disagreement the kernel exists to prevent. It then shows the two readings
  that must not be confused: an expired challenge, and the fail-closed fallback
  where an unreadable `attemptsAllowed` arrives as `0` rather than the
  constructor's `3`. The enrolment arc covers both of
  `Tom2FAPendingEnrolment`'s stops — choosing (an offer, no mechanism, and
  legitimately no deadline) and confirming (a mechanism, a deadline, and the
  `otpauth://` material) — including the `'true'`-or-`true` claim reading.
- **New: `10_oauth_contract_example.dart`.** The todo permitted leaving the OAuth
  DTOs example-free on the grounds that the flow needs a server. The flow does;
  the *contract* does not, and the contract is the part that can silently break.
  The sample walks `registerTomOAuthApi` (idempotent, explicit), the three
  endpoints resolved against a base URI, `TomPublicAccess` on all of them, and
  the `urlParameterMapping` seam where the provider's `error_description`
  becomes the DTO's `errorDescription` — asserting the four endpoint ids as
  literals, because those are the strings the server restates in its
  `@TomApiEndpointImplementation` annotations, where a rename compiles on both
  sides and binds the handler to nothing. It ends on the point the contract
  exists to make: `/oauth/callback` answers with `TomAuthenticationResult`
  carrying `requires2FA`, so signing in with a provider resolves a principal and
  does not finish a login.
- **New: `11_access_control_definition_example.dart`.** Every other security
  sample reads an ACI that already exists; this one builds it. It defines a
  role that inherits a role *and* joins a group, a group that belongs to a
  parent group, and an entitlement that includes other entitlements, then runs
  the one fold a login runs — `completeFromDefinition` — and shows a single
  assigned role name arriving in the token as five entitlements and three
  resource keys, two hops and a kind away. It also pins the two behaviours the
  fold is easy to assume wrong: an assignment naming something the definition
  does not define is *kept* (a configuration gap must not look like a
  revocation), and an empty definition is the identity rather than a denial.
- **`TomGuestAccess` is now shown next to the control it is confused with.**
  Section eight of `02_access_control_example.dart` puts it against
  `TomAuthenticatedAccess`, since the two differ on exactly one caller, and adds
  the case neither's documentation states: a principal with a *name* but no
  authentication is admitted by neither, because the control tests the guest
  username rather than the absence of a login.
- **`TomAccessControlHandler` and `TomAuthorizerStrategy` are named where they
  act.** The custom-access handler in `03_advanced_access_control_example.dart`
  was an anonymous closure, so the extension point's actual type never appeared;
  it is now a top-level function declared as a `TomAccessControlHandler`, with
  `getHandler` shown returning the very function that was registered. In
  `05_ui_authorization_example.dart`, the narrows-only authorizer relied on the
  default strategy and the enum was invisible; both strategies now appear with
  the same widening resolver, so the one question they differ on — may the
  resolver widen? — is visible, along with which answer is the default.
- **New: `07_resource_role_authorization_example.dart`.** The kernel's only
  shipped `TomAuthorizationAdapter` had no runnable demonstration, which is part
  of why it went undocumented for so long. The sample declares a role
  vocabulary in `TomResourceRoleRegistry`, shows one principal holding `owner`
  on one project and `viewer` on another simultaneously, and asserts both halves
  of the no-fallback guarantee — the ungranted resource and the unregistered
  role each resolving to `none`, with the principal deliberately made a global
  `admin` to demonstrate that the global grant does not leak through. It then
  installs the adapter on `TomAuthorization`, contrasts the resolved states with
  the no-adapter `full` default, and covers `stateOf` and the unmodifiable
  registry snapshot. Every snippet in the new prose section is a shape this
  sample compiles and asserts, so the documentation cannot drift from the API
  without the sample failing.
- **The resource-key sample now exercises the control rather than the ACI.**
  Section four of `03_advanced_access_control_example.dart` built an
  `emailAccess` and a `salaryAccess` and then asserted on
  `principal.aci.resourceKeys.contains(...)` directly — demonstrating the
  collection, not the access control, and needing a file-level
  `unused_local_variable` waiver to do it. It now asks the controls
  themselves through `checkAccessibility(principal)`, the same call every other
  section makes, and ends by switching `globalSettingProtectionDefault` off and
  watching the principal who was just refused be let through — the one operand
  this control has that its siblings do not.
- **The `default`-named domain scope is now shown costing something.** Section
  seven of `01_scope_basics_example.dart` demonstrated the identity rule by
  constructing the chain by hand and asserting the resulting paths; it now also
  reaches it through `withScope`, which derives each parent from `current`
  rather than being handed one, so the rule visibly does not depend on how the
  chain was assembled. Two assertions replace what had been a claim in a
  comment: `app > default` must not render as `app`, because that is a
  different existing scope's path and the two would share a lookup key; and a
  root-level `default` must not render as the empty string, because that is how
  the module spells "no scope at all". Both fail under a by-name elision, which
  the earlier assertions also catch but only by their expected values.
- `example/samples/scope_ids/01_scope_basics_example.dart` gains an eighth
  section on unusable ids. It builds the `'a'` → `'b'` → `'c'` chain first, so
  the reader sees the path the dotted id used to be indistinguishable from
  before seeing the dotted id refused, and closes with an id full of spaces and
  slashes being *accepted* — the rule is about the separator, not about
  awkward characters.
- `example/samples/scheduling/` (memory substrate, declared jobs, the five
  schedule kinds, the at-least-once execution guarantee),
  `example/samples/preferences/` (codec, contract), and
  `example/samples/observable/08_observable_enum.dart`.
- **Every sample now refuses to run without `--enable-asserts` (tcinc198).**
  The samples verify themselves with ~1800 `assert`s and nothing else, and
  `dart run` strips every one of them — so a flagless run printed its usual
  "✓ … passed" and exited 0 while checking nothing, which is worse than a
  crash because it is indistinguishable from success. Only the 37 entry points
  calling `bootstrapSamples()` were guarded; the other 77 were not, because the
  guard sat behind an import of the generated reflection registry that costs
  ~3 s of compile time and that they had no other reason to pay for. The check
  now lives in its own registry-free `example/sample_asserts.dart` as
  `requireAsserts()`, which every sample's `main()` calls (or reaches through
  `bootstrapSamples()`), and `tool/run_standalone_examples.sh` fails the sweep
  if a sample stops calling it.
- The reflection samples `01`–`06` document the command that runs them on their
  own (tcinc197); they were already standalone-runnable but said so nowhere.
- **`tool/run_standalone_examples.sh` now checks that every documented
  `dart run` command pointing into `example/` names a file that exists
  (tcinc261).** The
  sweep runs every sample, but it finds them with `find` rather than by reading
  the documentation, so it exercises the files that are there instead of the
  paths the headers claim are there. A command naming a moved, renamed or
  mistyped file was therefore invisible to the whole script and failed only for
  the reader who typed it. This was the shape of the original defect — a header
  advertising a command the file could not answer — and it is now the third
  static check, beside the `--enable-asserts` and `requireAsserts()` ones.
- `example/samples/scope_ids/03_scope_mixin_example.dart` gains a fifth section
  showing what the post-construction `initScope` pattern costs: until the call
  runs the instance is not yet a scope, and both installing it and passing it
  as a parent are refused. The example is where readers meet the pattern, so it
  is where the window it opens belongs.

### Documentation

- **`TomUserPreferencesApiService.listPreferences` now states the order it
  answers in (tcincb1_ahzg).** It said only "every preference of the caller".
  Two implementations answer it — `tom_core_server`'s store, which has always
  sorted by key, and `tom_core_flutter`'s device store, which did not — and the
  silence here is why they diverged: an unstated sequence is one each side
  invents, and a server that sorts beside a client that forwards an unsorted
  list are not two backings of one API.

  The declaration now carries the rule and its reasons. **The key is the
  ordering field** because it is the one that is unique within a caller's
  preferences and never changes while the preference exists — rewriting a value
  must not move it in the list, which rules out `updatedAt`, and there is no
  insertion order that survives a store being rebuilt. **Ascending by code
  unit**, which is exact rather than approximate only because
  `TomUserPreferenceKeys` admits ASCII alone: over that alphabet code-unit
  order, byte order and alphabetical order are one order, so a Dart `compareTo`
  and a byte-collated SQL `ORDER BY` cannot disagree. A store whose backing
  column carries a case-insensitive collation deviates from this, and the
  dartdoc says so — that is a defect in the store, not a second permitted
  reading of the sentence.

- **`TomContextProviders`' locale accessors read as a locale derivation and are
  not one, and their `"XX"` was undocumented as a sentinel (tcinc629).** The
  nine providers are single-field readers: each answers *what the principal
  says* about one field, substituting a value when it says nothing. That is
  deliberate — a caller needing one specific claim, such as an audit entry
  recording what the device reported, must be able to ask for that one and not
  be handed a blend of the stored and device pairs. But nothing said so, and the
  names `getLanguage`/`getCountry` invite `TomTextLocale(getLanguage(),
  getCountry())`, which is a *different* derivation from
  `TomTextLocale.fromPrincipal` on all three points that matter: it ignores the
  `clientLanguage`/`clientCountry` fallback, and it substitutes `"en"` and
  `"XX"` where `fromPrincipal` answers `null` precisely so the deployment's
  default is applied in one place.

  `"XX"` was the sharp end. It is in the range ISO 3166-1 permanently withholds
  from assignment (`AA`, `QM`-`QZ`, `XA`-`XZ`, `ZZ`) so applications can mean
  "none" with it, so it is not a country — but it *is* two letters, so anything
  checking only shape accepts it. `TomLoginMessage.clientCountry` defaults to
  it, which is how it reached `TomPrincipal` in ordinary traffic and how
  `tom_core_server` came to build the unreachable bundle key `en_XX`.

  No behaviour changed here. The class, the four locale accessors and
  `TomLoginMessage.clientCountry` now state the role split and name `"XX"` as a
  deliberate non-locale sentinel, `doc/context/context.md` and
  `doc/api_reference/api_summary_context.md` carry the same, and a test pins
  the sentinel inside the user-assigned range — so replacing it with a
  plausible-looking `"US"` fails rather than quietly turning "named no country"
  into a claim about where the user is. The composition itself is refused
  downstream by `TomTextLocale`'s country invariant.

- **Twelve documented constructors typed `autoLog` as `bool?` with no default,
  where it is `bool` and defaults to `false` (tcinc618).** Every one of the
  twelve is an exception that forwards with `super.autoLog`, so each inherits
  both the type and the default of `TomException`'s `this.autoLog = false`. As
  written, the summaries said two untrue things at once: that `null` is an
  accepted argument — it is not, the analyzer rejects it — and that a caller who
  omits the parameter gets no defined behaviour, when omitting it is the normal
  case and means "do not log automatically". The affected summaries are
  `http_connection` (seven), `isolate_pooling` (two), and `beanlocator`,
  `reflection` and `timezoned` (one each). Same root cause as the `stack`
  correction below: a super-parameter's type and default come from the
  constructor it forwards to, not from the field it eventually writes.

- **`TomReflectorException`'s `stack` parameter was typed `Object?` where it is
  `StackTrace?` (tcinc617).** The class extends `TomException`, and forwards
  with `super.stack`; `TomException`'s constructor narrows the parameter to
  `StackTrace?` even though the field it ultimately writes — declared on
  `TomBaseException`, in `tom_basics` — is `Object?`. The summary had described
  the field rather than the parameter, which is a difference a caller finds out
  about from the analyzer: a non-`StackTrace` argument does not compile. Part
  of a sweep that corrected the same mistake in twenty-one further constructors
  across thirteen `tom_core_server` summaries.

- **The timezoned readme credited one exception with two failures it does not
  have (tcinc339).** Its Key types row read "`TomTimezoneException` — thrown on
  unknown zones / parse failures". Parse failures raise `FormatException`, from
  `parseFromString` on all three variants, both for a malformed string and for
  one naming a zone the database does not hold. And "unknown zones" was half
  right in the other direction: `fromName` returns `null` for a name it cannot
  find, and only the strict `findTimezone` throws — a difference the table gave
  no hint of, and the one most likely to catch a caller out.

  The module refuses in three shapes and the trigger does not reveal which:
  "a zone that is not in the database" reaches all three. The row now names
  `findTimezone` as the only source of `TomTimezoneException`, and a new
  **Failures** section states the choice between the lookups and the parsers'
  separate contract. The exception's own dartdoc hedged with "common error
  scenarios include", which is what invited the readme's reading; it now says
  it is raised for exactly two reasons and explicitly not by a parse failure.
  The web note names `StateError`, the type a first access before
  `await tomSetupTimezones()` actually raises.

- **Offset lookup was documented as if its answers were permanent (tcinc337).**
  `firstWithOffset` and `allWithOffset` read an index built once, at first
  access, from each zone's offset *at that moment*, and never rebuilt. A zone
  that observes daylight saving is therefore in one bucket in winter and
  another in summer — about a third of the IANA database moves this way — and a
  process running across a transition keeps answering for the season it started
  in. Nothing at the call site said so: the narrative guide showed
  `firstWithOffset(540)` under a "Creating Timezones" heading with no caveat,
  and the API mirror said only "the first timezone matching the given UTC
  offset".

  Worse, the `allWithOffset` dartdoc illustrated its result as `'UTC',
  'Europe/London', etc.` — false for half the year, since London is on BST at
  +60 in July and is not in the zero bucket at all. Both documents and the
  dartdoc now state that the match is against the current offset, that the
  result is a snapshot rather than a membership rule, and that the name is what
  should be stored. Two further surprises are named where they bite: *first*
  means first in IANA name order, so `firstWithOffset(0)` yields
  `Africa/Abidjan` rather than `UTC`; and `findTimezone`'s name-null branch
  reads the same index and inherits the same shelf life.

- **Three specification citations named no specification (tcinc336).** The
  access-control dartdoc cited `§5.26` three times — for the worked example
  behind the pattern shape, for why server-level grants need no new class, and
  for the grant-carrier rule — without ever saying which document has a §5.26.
  A reader who wanted the source had nothing to search for. All three now name
  `codespecs_mapping.md` on the line that carries the number.

- **The type guide offered a member the base class does not have (tcinc334).**
  `doc/timezoned/timezoned.md` introduced its shared-member block with "All
  types share these features" and listed `convertToTimezone` among them.
  `TomTimezoned` declares no such method: each of the three subclasses declares
  its own. (The reason given here at the time — that the narrowed return types
  leave no signature the base could hold — is wrong; Dart permits return-type
  covariance in an override. The real reason is stated under 1.1.16.) That is
  not a pedantic distinction, because `TomTimezoned`
  is a type readers actually hold — `now()` and `parseFromString` both return
  the base class rather than a subclass — so following the document produced a
  compile error, with no diagnostic pointing at the document that caused it.
  The same block omitted `getSerializationPrefix`, which the base class does
  declare, so the roster was wrong in both directions at once.

  The block now matches the base class, and `convertToTimezone` appears in each
  of the three subclass sections with its return type shown, so narrowing is
  visible at the point of use. Two paragraphs were added for what the roster
  cannot express on its own: why no shared declaration exists, and how to
  convert a base value — rebuild it through the subclass, the instant and the
  zone being all the conversion needs. The API mirror, which had the member
  tables right, gained the same consequence in prose beside its factory list.

- **The wire format was documented without its last character (tcinc333).**
  Every string the module serializes ends in a space —
  `TomTimezone.toString()` appends one, and every zoned value renders its zone
  through that method — and eleven passages across three files gave the format
  without saying so. The narrative guide's template, its four worked example
  strings and its `TomTimezone` output lines; six rows and the overview of the
  API mirror; and the `Format:` lines of `toString` and `toStringOn`, whose own
  examples printed `'Z_UTC '` two lines below.

  It is the one part of the format that cannot be seen. Parsing is lenient —
  each regex ends in `\s?`, so a string without the space still reads — which
  is exactly what keeps the omission cheap to make and expensive to meet: a
  stored value compared against a documented literal is unequal, both strings
  are well-formed, and nothing reports why. The guide now shows the examples
  with the space inside the quotes, where the closing quote makes it visible.

  The guide's template also read as four underscore-separated fields
  (`{PREFIX}ISO8601_UTC_OFFSET_TIMEZONE`) against the three its own bullet list
  named, the middle one being the single word "UTC offset". It is now
  `{PREFIX}{ISO8601}_{OFFSET}_{TIMEZONE}{SPACE}`, with a bullet per field.

  Whether the space should exist at all is a separate open question
  (tcopen92); this pass makes the documents agree on what the format currently
  is.

- **The serialized offset was described as belonging to the value's instant
  (tcinc332).** It belongs to the moment the string was written.
  `TomTimezoned.toString()` renders the zone through
  `TomTimezone.toString()`, which reads `timezoneOffsetMin` — the offset
  *now* — so a January `America/New_York` value serialized in July carries
  `-04:00` where the same value written in January carries `-05:00`. Round
  tripping is unaffected, because the parse never reads that field, but the
  documents said something stronger than that and something untrue: that the
  offset was recomputed for the value's instant.

  Two things had run together. On parse the offset field is simply ignored —
  the UTC part and the zone name are all that is read back, and the `local*`
  reading is derived from those two through the IANA database, which is what
  makes a stale or wrong offset harmless. That is a statement about *reading*,
  and it had been carried over into the offset that gets *written*, where it
  does not hold. The serialization guide, the module's wire-format description
  and the `@T@` sample now separate the two.

- **`findTimezone`'s documented failure modes were half its real ones
  (tcinc331).** The method throws for two unrelated reasons — a name the
  database does not hold, and a name whose current offset is not the one the
  caller supplied — and one `throw` serves both, which is what made them easy
  to describe as one. Its dartdoc named only the offset mismatch, twice, and
  the narrative guide annotated the call with `Throws if mismatch`.

  The unknown-name half is the one that matters, because the neighbouring
  lookup does the opposite: `fromName('Mars/Olympus')` returns `null` where
  `findTimezone('Mars/Olympus', null)` throws on the same name. A reader who
  meets `fromName` first will expect `null`, and a description covering only
  the mismatch confirms them in it. The guide's "Null Returns" section stated
  the generalisation outright — "Lookup methods return `null` for unknown
  values" — with `findTimezone` the one lookup it does not hold for.

  All four sites now name both reasons and the contrast with `fromName`. The
  return contract was completed in the same pass: a name-null lookup yields
  `null` when no zone sits at the requested offset, which the dartdoc and the
  API mirror both omitted.

- **The timezoned platform description named the wrong entry point for native
  (tcinc329).** `doc/timezoned/timezoned.md` had the server reaching the
  `timezone` package through `standalone.dart`. It does not, and never did: the
  server, the CLI, the test runner and Flutter all load embedded data from
  `package:timezone/data/latest.dart`. The passage described the selection by
  pairing platforms with file names, which is how it went wrong — the names
  pointed the other way — so it now states the condition each arm is selected
  by and the library each one imports. That framing is what made the dead
  default arm visible, and it is fixed above.

- **shutdown_cleanup no longer teaches async teardown that the framework drops
  (tcinc322).** Teardown is synchronous throughout — every entry is called
  through a `void`-returning function and whatever it returns is discarded —
  yet three documentation sites presented `async` cleanup as a working pattern
  with no caveat: the module readme's quick start implemented `TomClosable`
  with `Future<void> close() async`, the prose's Server Application Pattern
  awaited `HttpServer.close()` inside a signal handler, and a best practice
  recommended bounding slow cleanup with `await Future.any([…, Future.delayed
  (…)])`. None of it works, and nothing warns: Dart accepts an `async` body
  wherever `void` is expected, because in return position every type is a
  subtype of `void`. A reader following any of the three believed they had an
  ordered async shutdown and had a body that ran to its first `await` and was
  abandoned there.

  All three are now synchronous. The server pattern instead has the handler
  complete a `Completer` and does the awaited `close()` back in the
  application's own control flow, which is the shape that actually works; the
  timeout advice keeps the `Future.any` snippet but as the counter-example it
  is, with an explanation of why the deadline bounds nothing. A new
  "Teardown is never awaited" section under Execution Order states the rule
  once for all three phases, `TomClosable.close` and `TomDisposable.dispose`
  and the `TomSignalHandler` typedef say it in their dartdoc, and the API
  mirror and the Limitations list carry it too.

  The section also names a consequence that was nowhere documented: a throw
  *after* an async entry's first `await` misses the per-entry failure report
  entirely, because that catch wraps the call rather than the returned future.
  It surfaces as an unhandled asynchronous error with nothing left to identify
  the phase or the entry. Two tests pin both halves of the behaviour, so if the
  contracts ever become awaited the documents are forced to change with them.

- **`doc/settings/settings.md` now documents the constructor, the defaults and
  the reflected shape (tcinc299).** The module's main prose document showed
  results only as things that arrive from a server, never as things anyone
  builds: the fourteen-parameter constructor appeared in the API mirror and
  nowhere else, and the property tables carried no default column. It now has a
  Constructor section with the signature, both default contracts — a fresh
  mutable empty collection per instance, `null` for the eight strings — and a
  snippet building a result incrementally, which is the server-side shape the
  mutable-collection contract exists to support. All four property tables gained
  a Default column.

  The gap had a visible consequence inside the document. "Handle Missing Values
  Gracefully" told the reader to write `settings.clientLanguage ?? 'en'` — right,
  and right *because* the field defaults to null — but gave the rule without the
  reason, so there was no way to tell which fields need the `??`. It now
  separates the three cases: strings need a fallback, collections never do
  (always present, always mutable), and map entries need one for the missing key
  rather than for the map.

  Both classes are also now stated to be `@tomReflector`-annotated at the point
  it explains something, rather than only in the Dependencies table: it is why
  every field is public, mutable and non-`final`, and why neither class writes a
  `toJson`/`fromJson` of its own. The module readme carried none of this and now
  carries it too.

- **The API mirrors no longer file non-supertypes under an `Extends` heading
  (tcinc298).** `api_summary_settings.md` gave both settings DTOs the bullet
  `**Extends:** annotated with @tomReflector`, reading as though the annotation
  were the base class. Neither class extends anything, and the annotation is the
  one thing about them a reader has to understand — it is why every field is
  mutable and non-final. Both bullets are now `**Annotations:**` and say so:
  the deserializer creates a zero-argument instance and assigns into it.

  The label was being misused more widely. Six classes across `scheduling` and
  `shutdown_cleanup` (`TomSchedule`, `TomJobDispatcher`, `TomJobStore`,
  `TomLeaseLock`, `TomDisposable`, `TomClosable`) carried
  `**Extends:** abstract class.` — a class *modifier* in the slot reserved for a
  supertype. They now read `**Extends:** none (abstract class).`, the form
  `api_summary_json.md`, `api_summary_scope_ids.md` and
  `api_summary_http_connection.md` were already using. `TomJobRun` had the same
  defect under the sibling label, `**Implements:** JSON round-trip via toJson /
  TomJobRun.fromJson` — a capability, not an interface, and the class implements
  nothing; it is now `**Serialization:**`.

  Every remaining `**Extends:**` bullet in the mirrors was then checked against
  the source declaration it describes; all name a real supertype.

- **Every invented exception type was removed from the samples, and the samples
  now use the vocabulary the package actually documents (tcinc297).** Five
  samples threw or constructed a type that is declared nowhere —
  `UnauthorizedException` (settings), `NetworkException` and `ConfigException`
  (`little_things`, in both the prose and the dartdoc), `CustomException`
  (the `little_things` library dartdoc) and `ConfigurationError` (json). All
  five are now `TomException` with a proper `<area>.<operation>.<condition>`
  key, which is what the rest of `little_things.md` had been showing all along.

  The `runChecked` samples gained more than a compilable name. Their whole
  subject is transforming an error, and each one was discarding the caught
  `error` and `stack` in the process — the opposite of the point. They now
  thread both through `rootException:` and `stack:`, and both the prose and the
  dartdoc say why: `onError` returns `Object`, so any type compiles, but only a
  `TomException` carries the original failure forward.

  One key was also corrected rather than invented: `settings.access.role-missing`
  was the only hyphenated error key in the package (every other one separates
  words with `_`) and it claimed the `settings.` namespace for what is
  application startup code, not the settings module. It is now
  `startup.validate.role_missing`.

- **Flutter was removed from every code sample in this Flutter-free package
  (tcinc296).** `pubspec.yaml` has no `flutter` entry, yet nine samples across
  the documentation and the shipped dartdoc were written against Flutter: the
  settings document built a dashboard from `Column` and three widgets that
  exist nowhere; the security document annotated `Widget reportsButton()`; the
  resources document imported `package:flutter/services.dart` to reach
  `rootBundle`; `access_controls.dart` and `tom_resource_provider.dart` carried
  the same shapes in dartdoc, which reaches pub.dev and IDE hover rather than
  only a reader who has the repository open.

  Every one is now plain Dart the package can compile. The lessons are
  unchanged — the settings sample still branches on `entitlements` and `roles`,
  but answers a `Set<String>` of enabled feature keys instead of a widget tree,
  and says explicitly that *what* is enabled is a kernel concern while what it
  *looks like* is not. The resources samples take the asynchronous read as a
  `Future<String> Function(String)` parameter, so the one place the Flutter
  binding was load-bearing becomes the caller's business; the prose that
  previously followed the sample to disown `rootBundle` is now unnecessary and
  gone, and `rootBundle.loadString` survives only as the named example of what
  a caller passes.

  Four neighbouring settings samples were fixed in the same pass, because the
  reason to drop the widgets — a document whose every sample is valid in its
  own package — applies equally to them: `appConfig` / `localization` (now a
  returned record), `applyBranding` (now a read), `_fetchFromServer` (the cache
  now takes its endpoint, and keeps the previous value when a refresh fails
  rather than emptying itself), and `UnauthorizedException` (now `TomException`
  with a proper dotted key).

- **Every module document's Dependencies section was checked against its
  source's imports, and ten were wrong.** The settings document was the clearest
  case: it named the **Security** and **Resources** modules, neither of which the
  module imports, and omitted the only import there is. Four documents named a
  module that is genuinely never imported — settings (security, resources),
  `shutdown_cleanup` (logging, observable), `isolate_pooling` (logging), and
  security (a "Crypto Module" that does not exist in this package; the JWT work
  is `package:tom_crypto`). Six more named only true dependencies but left real
  ones out: logging omitted isolate pooling, reflection and `atomic_file`;
  observable omitted resources and scope IDs; reflection omitted timezoned and
  `tom_basics`; timezoned omitted `formatting`, `meta` and `tom_basics`;
  `scope_ids` omitted its exception import; and
  `observable_short_reference.md` pointed at a file called `tom_exception.dart`,
  which has never existed. Every section now lists what the source actually
  imports, names the symbol taken from each, and — where the module has more
  than one source file — says which file makes the import.

  Three recurring confusions were behind most of it, and each is now called out
  where it applies. **Carrying a payload is not depending on a module:** the
  settings DTOs carry an authorization token and a texts map, which is why
  security and resources looked like dependencies; they are the modules at the
  *ends of the wire*, and the settings document now says so under its own
  heading. **A dependency has a direction:** `isolate_pooling` claimed to depend
  on logging when `logging_isolate.dart` imports the pool, not the reverse — the
  pool reports through `tomLog` from `tom_basics` precisely so the cycle stays
  open. And **`@tomReflector` belongs to the reflection module,** not to
  observable, which merely re-exports it; that misattribution appeared in the
  settings, security and `shutdown_cleanup` documents.

  Three genuine facts surfaced while checking and are now documented where they
  were previously invisible: the **observable ↔ resources cycle** (resources
  publishes `appResourcesRevision` as a `TomInt`, and `tom_observable_enum.dart`
  observes it — which is what makes a locale switch reach a bound enum label);
  the **reflection ↔ observable cycle** (reflection must recognize `TomClass` to
  convert it, and `TomClass` needs the reflector to describe itself, so neither
  can be extracted without the other); and the fact that five of
  `http_connection`'s six source files import **this package's own barrel**
  rather than their siblings, so an import list there says nothing about what the
  module uses and the analyzer cannot flag a new coupling introduced in it.
  `isolate_pooling` and `timezoned` also gained the log-level and
  conditional-import tables the check produced.

- **The settings and security documents no longer invent a transport that does
  not exist.** Every snippet showing how to *send* one of these modules' DTOs
  called a service declared nowhere in the workspace —
  `settingsService.getSettings(message)` in the settings library dartdoc and
  twice in `doc/settings/settings.md`, `authService.authenticate(message)` in
  the security library dartdoc and in `doc/security/security.md`, and
  `authService.login(message)` on `TomAuthenticationResult`. A sixth,
  `authService.currentToken`, stood in for the token source. A reader who
  searched for those names found nothing and had no pointer to what to use
  instead. The real mechanism is `TomServerEndpoint`, declared in this same
  package, so the documents were inventing a transport while the genuine one
  went unmentioned. All six snippets now show the actual round trip — build the
  endpoint over a `TomServerChannel` and `TomServerCallSpecs`, `send` the
  message, check the `(result, error)` pair — following the shape
  `doc/logging/logging.md` already used for the remote-log endpoint, and taking
  the token from `TomBearerAuthentication.authorizationToken`, which does exist.
  Two things the phantom had obscured are now stated: settings addresses the
  **API** base URI with `includeBearerAuthentication: true`, whereas a login
  addresses the **authentication** URI with it `false` — the two differ only in
  a split deployment, so a client that confused them would look correct on a
  single host; and authentication has **two** failure channels, the call's
  `error` and the result's own `error`, where the phantom's single return value
  implied one, so a client checking only the latter reads an unreachable server
  as a successful login. Not every service-shaped name was a phantom:
  `oauthService.listOAuthProviders()` and `beginOAuthAuthorization(...)` name
  real methods of the declared `TomOAuthApiService`, and the `userService`,
  `httpClient` and `reportingApi` placeholders elsewhere are arbitrary callees
  in snippets about something else. Those were left as they were.
- **The settings API mirror no longer promises an empty-string default for
  eight fields that default to `null`.** All eight of `TomGetSettingsResult`'s
  context and localization strings — `organization`, `process`, `application`,
  `country`, `language`, `clientCountry`, `clientLanguage`, `clientTimeZone` —
  were documented as `(default "")`. Every one defaults to `null`, as the
  declarations, the constructor dartdoc and the test suite all say. The mirror
  had picked up the claim from the `= ""` field initializers that this release
  removed as dead code, and those initializers never took effect either, so the
  documented default was never the real one. This is not cosmetic: a reader who
  trusted the mirror writes `settings.organization.isEmpty` and gets a null
  dereference on the default path. The class-level note, which stated only the
  collection half of the constructor's contract, now states the string half
  too, including that `null` means "not set" as distinct from a server that
  answered with the empty string. `TomGetSettingsMessage.authorizationToken` is
  the one string in the module that genuinely does default to `""`; its row now
  says so explicitly, and says not to carry the convention across.
- **Five of the six `TomResourceKeyProtection.globalSettingUseAutomatic*`
  switches say plainly that they do nothing.** A workspace-wide sweep found a
  reader for exactly one of them — `…EndpointProtection`, consulted by
  `tom_core_server`'s endpoint pipeline. The JSON, database, form-field, action
  and action-for-disabling switches are declared and documented but read
  nowhere, so setting one to `true` has no effect. Their dartdoc previously
  described the filtering they would perform, which reads like a control that is
  on; each now leads with **Not implemented** and says what does the job
  instead, and the class-level list carries the same warning. The API mirror
  rows were corrected to match. Whether each tier gets implemented or each flag
  gets deleted is a separate decision, and the `TODO:` above the block now
  states that question instead of asking whether the check was ever done.
- **`doc/security/security.md` names the five public types it never mentioned.**
  Key Concepts introduced "User" and "CLI (Client Limits Information)" by
  concept, so a reader who went looking for either class had nothing to search
  for; three more — `TomGroup`, `TomEntitlement`, `TomAccessControlHandler` —
  were used by the document without ever being named. Now:
  - A new **Identity** section documents `TomUser`: the two fields that always
    have values against the eleven that are nullable, reading it off the
    principal through the `id`/`username` forwarders, the guest sentinel that
    `TomGuestAccess` tests, the read-only contract, and — the part a reader
    cannot infer — that token serialisation runs every optional field through
    `tomProtect` under `tom.user.<field>`, a *different* key from the
    `user.email` used as an application-level example elsewhere in the same
    document, while `username`, `id` and `timeZone` always travel unfiltered.
  - A `TomClientLimitsInformation` section beside the ACI one, separating what
    the *user* may do from what the *client* has bought, and stating that the
    kernel enforces neither quota nor module — it carries the ceiling, the
    application compares against it. Its provenance is written down as it
    currently stands: the values ride in the **public** half of the JWT and are
    a login-time snapshot with no updater, so a subscription change takes
    effect at the next login and the figures are readable by any token holder.
  - The `TomAccessControlDefinition` section showed `TomRole` and stopped,
    implying the schema models roles alone. It now has the three-kind table
    (`TomRole`, `TomGroup`, `TomEntitlement` — what each may include and what
    each may grant), a schema using all three, and what the fold does with a
    name that has no definition.
  - **Custom Access Control** leads with the `TomAccessControlHandler` typedef,
    because the extension point is a function signature rather than a class to
    subclass, and states the two throwing behaviours around the registry:
    `registerHandler` refuses a duplicate name, `getHandler` refuses an unknown
    one.
  - The OAuth **endpoints** section names `tomOAuthApiId` and the three
    `tomOAuth*EndpointId` constants, and says why they are constants: the
    server restates them in `@TomApiEndpointImplementation(apiId: …)`, and a
    mistyped literal there compiles cleanly and simply never binds.
  - The Overview says once that this document is organised by concept and
    points at `api_summary_security.md` for the exhaustive member list.
- `Tom2FAChallenge.fromClaims` no longer promises it "never returns a
  half-built challenge". It does return one, on purpose: an unreadable
  `attemptsAllowed` claim falls back to `0` rather than to the constructor's
  `3`, so the challenge arrives already `isExhausted` and a malformed token
  cannot mint attempts. The dartdoc now says so and says why, and
  `Tom2FAPendingEnrolment.fromClaims` — which has always behaved identically —
  states the same rule instead of leaving it to the API mirror alone. The two
  mirror rows in `doc/api_reference/api_summary_security.md` were brought into
  line with each other. Behaviour is unchanged; the rule is now pinned by a
  test in each class, so the docs and the fallback can no longer drift apart.
- `doc/scope_ids/scope_ids.md` gains an *Ids may not contain the separator*
  section under Scope Paths, showing the two chains that used to render
  identically and why the path being an authorization prefix makes that a
  security defect rather than a cosmetic one. Best Practice 3 was rewritten
  from advice the module did not enforce into a statement of what it now
  guarantees, and the `StateError` references throughout were updated to
  `TomScopeException`. `doc/api_reference/api_summary_scope_ids.md` gains a
  `TomScopeException` entry with its three keys, and the `initScope` and
  `withScope` rows now state the id contract.
- `doc/scheduling/scheduling.md` (including the execution guarantee in full),
  `doc/preferences/preferences.md`, and the matching
  `doc/api_reference/api_summary_*.md` entries.
- `doc/scope_ids/scope_ids.md` no longer calls `runInScope` "a no-op wrapper"
  when the scope is already current. What is elided is the zone, not the call:
  the body runs and its result is returned on both branches. The old wording
  was one word away from saying the call does nothing, in a method almost
  always written as `scope.runInScope(() => …)` where the body is the point.
- `doc/scope_ids/scope_ids.md` documents the window between construction and
  `initScope` — which entry point refuses what, why the parent is checked at
  `initScope` rather than during the path walk, and the invariant the two
  checks buy: whatever `TomScope.current` returns is usable.
- **The acyclicity requirement `buildScopePath` relies on is now written down**
  — in its own dartdoc, in `initScope`'s, in `doc/scope_ids/scope_ids.md` and in
  the API summary. The walk up the parent chain is iterative and has no cycle
  guard, so a loop does not raise `StackOverflowError`: it spins silently,
  appending segments, until the heap is exhausted and the isolate dies. It is
  left unguarded because no scope built through this module can form a loop —
  `withScope` and the `TomScopeBase` constructor take a parent that already
  exists, and `initScope` refuses one that is not yet initialised and then
  writes the link once, so every parent is strictly older than its child and a
  chain that only moves backwards in time cannot return to itself. What the
  documentation adds is the part that argument does not cover: a hand-rolled
  `implements TomScope` supplies its own `parent` and carries the obligation
  itself.

## 1.1.15

### Added

- **Opt-in liveness supervision for `TomWorkerPool` (RCJ1).** A worker whose
  isolate dies (uncaught error, `Isolate.kill`, OOM) was previously neither
  detected nor replaced, and any command dispatched to it hung forever on its
  completer. `TomWorkerPool.withSize` now accepts an optional
  `healthCheckInterval` (default `null` = supervision off, existing behaviour
  unchanged) and `healthCheckTimeout`. When enabled, each worker is watched via
  `Isolate.addOnExitListener`: on an unexpected death every in-flight request is
  failed with a new `TomWorkerDiedException` (rather than re-dispatched — a
  command that already produced side effects must not run twice), and the pool
  respawns a replacement worker from its stored context to restore capacity. A
  periodic timer additionally pings **idle** workers to catch hangs that emit no
  exit signal; an unresponsive idle worker is force-killed, routing it through
  the same death/respawn path. `execute` on a closed pool now throws
  `TomWorkerException` instead of hanging. New `TomWorkerPool.isSupervised` /
  `workerCount` accessors, plus `TomWorker.superviseExit` / `ping` /
  `killUnresponsive`. Covered by tests that kill a worker isolate mid-command
  and assert recovery, and an example demonstrating recovery
  (`example/isolate_pooling/04_worker_pool_supervision_example.dart`). Closes
  the carve-out filed from RCK1.

## 1.1.14

### Added

- **Pluggable durable replay store for `TomRemoteLogOutput` (RCK9).** The
  replay queue's storage is now behind a `TomLogReplayStore` interface
  (`append` / `snapshot` / `oldest` / `removeOldest` / `trim` / `clear`). The
  default stays zero-config and entirely in process
  (`TomInMemoryLogReplayStore`, unchanged behaviour); a new file-backed
  `TomFileLogReplayStore` mirrors the queue to a JSON file on every mutation and
  reloads it on construction, so records buffered during an outage survive a
  process restart — the one edge the in-memory store cannot cover. Opt in by
  assigning `TomRemoteLogOutput.globalSettingReplayStore`; the existing
  `globalSettingReplayQueueMaxSize` gate/bound is unchanged. Record
  serialization lives in the file-store library (private
  `_encodeReplayRecord`/`_decodeReplayRecord`) so `TomRemoteLogMessage`'s
  reflected/bridged surface is untouched (no regen).
- Tests for the durable store: the full store contract on the file backend,
  persistence across a simulated restart (fresh instance at the same path
  reloads the queue), bounded trim persisting across a restart, and an
  end-to-end restart-during-outage recovery through `TomRemoteLogOutput`.
- Example 10 in `example/logging/04_isolate_and_remote_logging_example.dart`
  demonstrating the file-backed store surviving a simulated restart, assert-
  guarded under `--enable-asserts`.

### Changed

- `TomRemoteLogOutput`'s internal `_replayQueue` list is replaced by delegation
  through `globalSettingReplayStore`; `replayQueueLength` / `clearReplayQueue`
  and the enqueue/drain paths now route through the store. Default runtime
  behaviour is identical (in-memory, drop-oldest, oldest-first drain).

## 1.1.13

### Changed

- **`scope_ids/` per-module pass (RCK8).** Private-only DRY refactor with every
  public signature frozen. `TomScope.runInScope` and `TomScopeMixin.runInScope`
  had byte-identical bodies (the `identical(this, current)` no-op-zone check plus
  the `runZoned` install); the shared install policy now lives in one private
  top-level `_runScoped<T>(TomScope, body)` helper both delegate to, so a change
  to the scope-installation policy is a one-site edit. The per-arity
  `InScopeBuilder.wrapN`/`wrapNn` methods and the two trivial `getScopePath()`
  delegations (already routed through the shared `buildScopePath`) have no
  collapsible duplication and were left as-is.

### Added

- Example `example/scope_ids/03_scope_mixin_example.dart` (wired into the runner)
  covering the previously undemonstrated public surface: a custom class using
  `TomScopeMixin` directly (the real-world consumer pattern, as in the Flutter
  element providers), the custom instance participating fully as a scope
  (`current`, path, `runInScope`, `InScopeBuilder`), and the write-once
  `set id` / `set parent` setters — all assert-guarded under `--enable-asserts`.
- Tests for direct `TomScopeMixin` usage (custom mixin class + `initScope`,
  `runInScope`, `InScopeBuilder` integration) and the write-once identity
  setters. The `set id`/`set parent` setters are kept (not removed): they are
  registered by the tom_core_d4rt bridges for `TomScopeBase`.

## 1.1.12

### Changed

- **`little_things/` per-module pass (RCK7).** Private-only pass with every
  public signature frozen. The module was already DRY — the stack-trace frame
  processing shared by `tomGetStackTrace`/`tomGetStackTraceAsList`/
  `tomGetStackTraceAsTuple`/`tomPrintStackTrace` had already been extracted into
  the private `_processStackFrames` helper — so there was no further genuine
  duplication to remove.
- Removed two stale investigation `TODO` comments above the stack-trace
  utilities (design musings about `StackTrace.current` usage and the frame
  folding). The folding is deliberate and covered by tests; the comments were
  noise.

### Added

- Example `example/little_things/03_formatting_and_exceptions_example.dart`
  covering the previously undemonstrated public surface: UTC offset formatting
  (`convertMinutesToUtcOffset`), a truly-awaited `runChecked` (success and error
  paths), `tomPrintStackTrace`, `TomException.printStackTrace()`, auto-logging
  (`autoLog`), `serverCallError`, and `logRepresentation`. The runner
  (`00_run_all_examples.dart`) is now async and awaits it.
- Tests for `TomException.newField` (default-null and set/get), closing the last
  untested public member. `newField` is kept (not removed): it is referenced by
  generated reflection and the tom_core_server D4rt bridges (`LoginException`).

## 1.1.11

### Changed

- **`json/` per-module pass (RCK6).** Private-only DRY refactor of
  `map_merge_and_process.dart` with every public signature frozen. Two genuine,
  behaviour-preserving deduplications:
  - `getPathFromTree` and `getObjectFromTree` shared an identical dot-path walk
    (with identical resolution/throw messages), differing only in how they
    handle a terminal non-map value. `getPathFromTree` now delegates the walk to
    `getObjectFromTree` and only wraps the resolved value under `name` when it is
    not already a subtree — the warn/throw behaviour is unchanged.
  - `makeCleanJsonMap` and `_cleanList` repeated the same JSON-type dispatch
    (scalars pass through, maps/lists recurse, everything else is dropped). That
    dispatch now lives in one private `_cleanJsonValue(Object?)` helper both call.
- Removed a stale `TODO` on the `json/` library directive; its intent — showing
  configuration resolution via `traverseAndProcess`/`traverseAndCreate` — is now
  covered by the new example.

### Added

- **`json/` example + test coverage scaled to the full public API.** New
  `example/json/03_json_config_resolution_example.dart` demonstrates
  `substituteEnvVars`, `traverseAndCreate`, `processTree` (profile-based
  reference injection) and the `TomJsonSerializable` contract — the members that
  previously had no executable example. Added a `TomJsonSerializable` test group
  (round-trip, `makeCleanJsonMap` interop, nullable values), taking the kernel
  suite to 1695 tests.

## 1.1.10

### Changed

- **`shutdown_cleanup/` per-module pass (RCK5).** Private-only DRY refactor of
  `tom_shutdown_cleanup.dart` with every public signature frozen. Two genuine,
  behaviour-preserving deduplications:
  - `_executeCleanup` held three near-identical try/catch loops (over
    `_signalHandlers`, `_closables`, `_disposables`) that each isolated one
    callout and printed `Failed to call <noun> $item` when not `silent`. The
    per-entry isolate/report policy is now owned by a single private generic
    `_runPhase<T>(List<T> items, String label, void Function(T) action)`, and
    `_executeCleanup` is three one-line phase calls. A change to the isolation
    or diagnostic policy is now a one-site edit instead of three. The exact log
    wording (`Failed to call signalHandler/closable/disposable $item`) is
    preserved.
  - The constructor's two SIGHUP/SIGINT watcher registrations duplicated the
    exact `_signalSubscriptions.add(sig.watch().listen(_signalHandler))` body of
    `addSignal`; the constructor now calls `addSignal(...)`, so there is a
    single owner of how a signal is watched and how its subscription is retained
    for teardown (bug §53).

### Examples & Tests

- Added `example/shutdown_cleanup/02_shutdown_execution_example.dart`, wired into
  the module runner. The existing `01_*` example is descriptive and never
  actually triggers cleanup; the new example *executes* the runtime API end to
  end — phase order, once-only execution, fault isolation, `paused` (signal path
  skipped / manual path always runs), `silent`, `cancelAll`/`dispose` teardown,
  and `TomCloseAdaptor` resolving a custom-named teardown method via reflection —
  all guarded by `assert`s (run under `--enable-asserts`). Registered as a
  reflection entry point in `build.yaml`.
- Added a `test/shutdown_cleanup_test.dart` case pinning the manual-path
  contract: `performShutdown()` (the non-signal path) ignores `paused`, which
  was previously asserted only for the signal-driven path. Suite: 64 cases.

## 1.1.9

### Changed

- **`settings/` per-module pass (RCK4).** Audit of
  `settings_client_authorization.dart` (two serialization DTOs —
  `TomGetSettingsMessage`, `TomGetSettingsResult`). No genuine within-module
  duplication exists to extract: the classes are independent data holders and
  the constructor's `?? <T>{}` / `?? <T>[]` defaulting is idiomatic per-field
  initialization, not extractable logic. The one honest, signature-preserving
  cleanup: removed the dead `= ""` field initializers on `TomGetSettingsResult`'s
  eight nullable `String?` fields (`organization`, `process`, `application`,
  `country`, `language`, `clientCountry`, `clientLanguage`, `clientTimeZone`).
  Every one is an initializing formal (`this.x`) in the constructor, so the
  field-level `= ""` never took effect — the real default was already `null`
  (as the existing tests assert). The initializer was dead code that misled
  readers about the default; removing it changes no runtime behaviour and no
  public signature. `TomGetSettingsMessage.authorizationToken = ""` is
  deliberately left — it has no initializing formal, so its `= ""` is the live
  default (`''`). Constructor dartdoc corrected ("all string parameters default
  to null"). No consumer relied on a `""` default (verified across samples and
  tom_uam — they only write the fields), so no adaptation was needed.

### Examples & Tests

- No additions needed: `example/settings/01_client_authorization_example.dart`
  (15 scenarios) and `test/settings_test.dart` (72 cases) already cover the full
  public surface of both DTOs, including the null-default guard that pins the
  dead-initializer removal ("should create result with default null optional
  strings") and the reflection JSON round-trip. No reflection regen — field
  types and names unchanged. Suite: 1690 passing.

## 1.1.8

### Changed

- **`context/` per-module pass (RCK3).** Private-only DRY refactor of
  `execution_context.dart` with frozen public signatures. Two genuine
  duplications were extracted: (1) `runInContext` and `runInContextAsync` shared
  a byte-for-byte preamble that built the new `TomExecutionContext` + merged
  `TomZoneValues` and assembled the zone-values map — now a single file-private
  `_buildZoneValues`, so each run method is a one-line `runZoned` call and the
  superfluous `async` (no `await`) was dropped from `runInContextAsync`;
  (2) all nine `TomContextProviders` getters read the current zone's
  `TomPrincipal`, selected one field, and fell back to a default — that
  read-select-fallback now lives once in `_fromPrincipal`, each getter reduced to
  a one-line selector so a change to how the principal is resolved lands in one
  place.

### Examples

- **New `example/context/04_async_and_zonevalues_example.dart`** covering the
  surface examples 01–03 omit: `runInContextAsync` context propagation across an
  `await` boundary and through nested async runs (inherit-outer, inner-wins), and
  the full `TomZoneValues` mutation API (`addAll` chaining, `containsKey`,
  `remove`, `clear`) plus the `existingValues` merge constructor. Wired into
  `00_run_all_examples.dart` (now async); self-asserts under `--enable-asserts`.

### Tests

- Added the five missing principal-populated provider tests (`getProcess`,
  `getCountry`, `getTimezone`, `getClientLanguage`, `getClientCountry`) so each
  of the nine refactored one-line selectors is verified against a live principal,
  guarding against a mis-wired field selector. Suite: 1690 passing.

## 1.1.7

### Changed

- **`resources/` per-module pass (RCK2).** Private-only DRY refactor of
  `tom_resource_provider.dart` with frozen public signatures. Both providers
  resolved a key the same way — a dot-notation tree walk (`getObjectFromTree`)
  then a flat-key fallback — duplicated across eight accessor bodies
  (`TomTextResourceProvider.{exists, existsObject, getObject, getObjectOrNull,
  getText, getTextOrNull}` and `TomConfigResourceProvider.{exists, getText}`).
  That rule now lives once in two file-private helpers: `_resolveObjectOrNull`
  (any value type) backs the object family and `_resolveStringOrNull` (String
  only) backs the text family, each accessor reduced to a one-line expression
  differing solely in its missing-value fallback. The text/object split is kept
  deliberately: the text helper still consults the flat key when the tree walk
  lands on a non-String, so a literal dotted key resolves — a genuine semantic
  difference, not coincidental duplication.

### Examples

- **New `example/resources/03_app_singleton_example.dart`** covering the
  application-wide singleton surface that examples 01/02 omit: the static
  `loader` field, the loader-driven default constructor,
  `getAppResources`/`getAppConfig` lazy initialization, `setAppResourceProvider`/
  `setAppConfigProvider` replacement, singleton identity, and the independence of
  the text and config singletons. Wired into `00_run_all_examples.dart`;
  self-asserts under `--enable-asserts`.

### Tests

- **Added a `shared resolution contract` group to `test/resources_test.dart`**
  (98 → 102) pinning the extracted helpers: the flat-String fallback on a
  non-String tree hit (literal dotted key beside a nested value), object-family
  resolution at a hierarchical path, the object-vs-text divergence on a nested
  non-String, and config/text object-family parity.

## 1.1.6

### Changed

- **`isolate_pooling/` per-module pass (RCK1).** Private-only DRY refactor of
  `tom_worker.dart`: the two identical response-completion bodies (worker→creator
  and creator→worker) are now a single private `_completeFromResponse(completer,
  response)` helper that routes a `RemoteError` payload to `completeError` and any
  other payload to `complete`. Public signatures are unchanged. The stale
  `// TODO: add regular pings` note on `TomWorkerPool` is replaced by an
  explanatory comment; the liveness-supervision enhancement is tracked as quest
  todo **RCJ1**.

### Examples

- **New `example/isolate_pooling/03_creator_backchannel_example.dart`** covering
  the worker→creator back-channel that had zero example coverage:
  `TomWorker.canSendToCreator`, `executeInCreator` (request/response),
  `sendToCreator` (fire-and-forget into a creator-side `TomExecutor`), a custom
  `TomWorkerContext` with `initializeIsolate`/`initializeWorker` overrides, and
  error propagation as a `RemoteError`. Wired into `00_run_all_examples.dart`.
- **Fixed a latent bug** in `02_worker_pool_example.dart`: a missing `await` cast
  a `Future<Object?>` to `bool` and crashed the example under `--enable-asserts`.
  Also removed confusing `Future.value(pool.execute(...))` wrappers in favour of
  the plain `Future`s that `pool.execute` already returns.

### Tests

- **Scaled `test/isolate_pooling_test.dart`** (+5 tests) to the full public API:
  the base `TomCommand.execute` default (`"null"` sentinel), the
  `startRemoteIsolate` null-send-port guard (the last untested documented
  exception key), `canSendToCreator`/`sendToCreator` observed from inside a
  worker, an end-to-end `sendExecutorToIsolate` assertion, and the
  creator-thrown-exception-as-value branch of the shared response-completion
  helper.

## 1.1.5

### Added

- **`TomRemoteLogOutput` delivery resilience (RCI2).** The remote log output now
  never silently drops a record. A send is treated as *failed* both when the
  transport throws **and** when the server answers with an error result
  (`TomServerCallError.hasError`) — the previously `print()`-only returned-error
  path now routes through the fallback like the thrown path. Four new static
  knobs make resilience opt-in and predictable-by-default:
  - `globalSettingMaxSendRetries` (default `0`) — additional attempts after the
    first failure.
  - `globalSettingRetryBackoff` (default `Duration.zero`) — linear backoff; the
    wait before retry *k* is `backoff × k`.
  - `globalSettingReplayQueueMaxSize` (default `0`, disabled) — bounded
    in-memory replay queue; records that exhaust their retries are buffered and
    re-sent oldest-first on the next successful transmission, dropping the
    oldest on overflow.
  - `replayQueueLength` (read-only) and `clearReplayQueue()` — diagnostics and a
    way to discard records queued for a previous endpoint when reconfiguring.

  The defaults preserve the prior single-attempt-then-fallback behaviour, so no
  configuration is required and the path stays testable without a live server.

### Examples

- **Extended `example/logging/04_isolate_and_remote_logging_example.dart`** with
  an Example 9 that drives the resilience surface offline via a scripted
  endpoint: a flaky endpoint recovered by retry, a full outage buffering a
  record, and a recovery that drains the buffer oldest-first before the
  triggering record. Self-asserts under `--enable-asserts`.

### Tests

- **Added a `TomRemoteLogOutput` `resilience` group to `test/logging_test.dart`**
  (kernel suite 1667 → 1676): default knobs; returned-error routed to fallback;
  retry recovers a transient failure and gives up after the budget; backoff
  actually waits between retries; replay queue buffers a failed record and
  drains it in order on the next send, drops the oldest on overflow, and stops
  draining while the endpoint is still down. The `_MockLogEndpoint` test double
  gained a per-call outcome script (`ok` / throw / returned-error) and an
  `accepted` log for asserting drain ordering.

## 1.1.4

### Refactor

- **`http_connection/` per-module pass (RCI1).** Internal DRY refactor with
  frozen public signatures. The six `TomServerCall` response accessors
  (`getResponseHeaders`, `getResponseStatusCode`, `getResponseContentLength`,
  `getResponseIsRedirect`, `getResponseReasonPhrase`, `getResponseRequest`) each
  repeated the same "throw if nothing was sent yet, then await the response"
  guard with only the error key/message differing; extracted that into a private
  `_requireSentResponse(key, message)` helper so every accessor states only its
  own wording. The duplicated read-once guard in `read()`/`readAsString()` moved
  into a private `_ensureNotYetRead(key)` helper. `read()` keeps its original
  `_read = true`-before-await ordering to preserve concurrent-read semantics.

### Examples

- **Added `example/http_connection/04_auth_retry_example.dart`** exercising the
  real framework auth-retry coordinator — `tomRunWithAuthRetry`,
  `TomAuthRefresher`, `TomAuthRetryPolicy` (default, custom, and bean-resolved
  `active`), and `TomAuthExpiredException` — across the happy path, expiry
  recovery, declined refresh, persistent-expiry throw, non-expiry passthrough,
  and a custom multi-retry policy. Wired into `00_run_all_examples.dart` (now
  `async`). This closes the gap left by `03_retry_policies_example.dart`, which
  only demonstrated a hand-rolled pattern, not the kernel API.

### Tests

- **Added auth-retry coverage to `test/http_connection_test.dart`** (previously
  zero tests for `auth_retry.dart`): `TomAuthRetryPolicy` (defaults, custom
  tuning, `active` bean resolution and reset fallback), `TomAuthExpiredException`
  (status/key/message), and `tomRunWithAuthRetry` (no-refresh passthrough,
  one-refresh recovery, declined refresh, persistent-expiry throw with and
  without `errorKeyOf`, non-expiry passthrough, refresher error propagation,
  explicit-policy budget, active-bean policy resolution).

## 1.1.3

### Refactor

- **`logging/` per-module pass (RCH1).** Internal DRY refactor with frozen
  public signatures. `TomIsolateLogOutput.output` and
  `TomCreatorLogOutput.output` built the *identical* `TomInterIsolateLogMessage`
  record before dispatch (only the destination differs — worker pool vs. back
  to the creator); extracted that byte-for-byte construction into a private
  `_interIsolateMessage(...)` helper so the record's shape lives in one place.
  The two `output` bodies stay separate: their dispatch/fallback logic is a
  genuinely different concern, not coincidental duplication. Replaced the stale
  `// TODO: add error handling` note inside `TomRemoteLogOutput.output` with an
  explanatory comment; the resilience enhancement it hinted at (retry-with-
  backoff, bounded replay queue) is filed as **RCI2** in the tom_core quest
  todos rather than attempted inline in a signature-frozen pass.

### Examples

- **Added `example/logging/04_isolate_and_remote_logging_example.dart`** covering
  the kernel-owned isolate/remote logging surface, which previously had no
  runnable example (examples `01`–`03` only exercise the `tom_basics`
  `TomLogger` foundation). It drives — connection-free (zero-size worker pools,
  no configured endpoint) — `TomInterIsolateLogMessage`, `TomLoggingExecutor`,
  `TomIsolateLogOutput` (level gating), `TomCreatorLogOutput` (off-isolate
  fallback + gating), `TomLoggingWorkerContext`/`TomIsolateLogging`,
  `TomRemoteLogMessage`/`TomRemoteLogResult`/`TomLoggingContext`,
  `TomRemoteLogOutput` (no-endpoint fallback), and `TomRemoteLogServer`
  (receive, sender-prefixing, CWE-117 control-character sanitization). Wired
  into `00_run_all_examples.dart` (now async). Self-asserts under
  `dart run --enable-asserts`.

### Tests

- **Closed the `TomLoggingWorkerContext` test gap.** Added a group asserting it
  is a `TomWorkerContext` and that `initializeIsolate()` registers a
  `TomLoggingExecutor` on `TomWorker.executors` and returns `true` (with the
  global executor list snapshotted and restored). Kernel suite 1650 → 1652,
  all green; `dart analyze` clean.

## 1.1.2

### Refactor

- **`security/` per-module pass (RCG1).** Internal DRY refactor with frozen
  public signatures: `TomRoleAccess` and `TomGroupAccess` had byte-for-byte
  identical `checkAccessibility` bodies — extracted the shared rule into a
  private `_principalAciContainsAny` helper (each class supplies its ACI
  collection selector). `TomEntitlementAccess` is deliberately left separate:
  regex matching is a genuinely different rule, not coincidental duplication.

### Examples

- **Added `example/security/04_graded_access_example.dart`** covering the
  four-state `TomGradedAccess` / `TomAuthState` surface, which previously had no
  runnable example: full/read/disabled/none resolution, the `read`→`full` and
  `disabled`→`read` defaulting, `checkAccessibility`'s collapse to
  `showsContent`, the `TomAuthState` predicates, and the binary→four-state
  default bridge. Wired into `00_run_all_examples.dart`. Self-asserts under
  `dart run --enable-asserts`.

### Fixes

- **Fixed a latent stale assertion in `02_access_control_example.dart`.** Its
  Example-6 group assertions documented a since-fixed constructor bug ("groups
  populated from resourceKeys"); the `TomAccessControlInformation` constructor
  now correctly populates `_groups`, so the assertions failed under
  `--enable-asserts`. Corrected them to the real group-membership outcomes and
  removed the obsolete bug note.

### Tests

- **`security_test.dart`** +3 tests pinning the extracted helper's contract
  (empty candidate list denies; Role/Group parity for an empty ACI collection).
  Suite 1647 → 1650, all green (serial).

## 1.1.1

### Documentation

- **Added a per-module API reference under `doc/api_reference/`.** Fifteen
  hand-written summaries — one per barrel-exported `tombase` module
  (`beanlocator`, `context`, `http_connection`, `isolate_pooling`, `json`,
  `little_things`, `logging`, `observable`, `reflection`, `resources`,
  `scope_ids`, `security`, `settings`, `shutdown_cleanup`, `timezoned`) — plus a
  cross-module `api_summary_index.md`. Each summary follows the standard format
  (overview with source paths, class hierarchy, per-class constructors and
  static/instance members, enums, top-level functions/constants; public members
  only). Verified against the actual public declarations and the package barrel.
  This restores documentation symmetry with `tom_core_server`,
  `tom_core_flutter`, and `tom_core_d4rt`, which already carry `doc/api_reference/`
  sets, and linked the reference from the README. No source or behaviour change.

## 1.1.0

### Added

- **Scope IDs module** (`scope_ids`): hierarchical, zone-propagated `TomScope`
  identifiers (`TomScope`, `TomScopeBase`, `TomScopeMixin`) for namespacing
  resource and authorization lookups, plus `InScopeBuilder` for restoring a
  captured scope inside deferred framework callbacks.
- **UI authorization** (`security/tom_authorization.dart`): the four-state
  `TomAuthState` model with `narrow`/`widen` algebra, `TomAuthorizable`,
  `TomAuthorizationGroup` (with `AuthGroupMode`), the global `TomAuthorization`
  singleton and `TomAuthorizationAdapter`, `TomAuthorizer` (with
  `TomAuthorizerStrategy`), and `TomUIStateController`.
- **Observable**: `TomList.resetWith` for atomic batch replacement with a single
  notification, and `TomListLifecycleListener` (`onBeforeClear` / `onAfterReset`)
  for tearing down and recreating element-tied state around a reset.
- **Resources**: null-returning and object accessors on
  `TomTextResourceProvider` — `getTextOrNull`, `getObject`, `getObjectOrNull`,
  and `existsObject`.

### Changed

- Observable notification now snapshots its listener/observer lists before
  iterating, guarding against concurrent modification when a callback mutates
  the list during a reset.

### Documentation

- Customized the package README and updated module docs, executable examples,
  and tests for the modules above.

## 1.0.0

- Initial version.
