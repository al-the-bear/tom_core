# Tom Core Kernel — Refactoring Plan

Project-specific workflow for refactoring, testing, documenting, and creating
examples for **tom_core_kernel**. This is the **reference package** for the Tom
Core repository: every other package-style project's refactoring plan targets
the state achieved here (clean code, full dartdoc, per-module documentation,
executable examples, comprehensive tests, generated `api.dart`).

**Project type:** Dart library (`publish_to: none`)
**Source location:** `lib/src/tombase/`

---

## Target Modules

Located in `lib/src/tombase/` (keep this list in sync with the folder — update
the plan whenever a module is added or removed):

| Module | Refactor? | Notes |
| ------ | --------- | ----- |
| `beanlocator/` | yes | Bean locator / dependency injection |
| `context/` | yes | Execution context management |
| `http_connection/` | yes | HTTP connection utilities |
| `isolate_pooling/` | yes | Isolate pool management |
| `json/` | yes | JSON helpers |
| `little_things/` | yes | Small cross-cutting utilities |
| `logging/` | yes | Logging (incl. isolate & remote logging) |
| `observable/` | **no** | Stable — do not refactor (see Prompt 1) |
| `reflection/` | **no** | Stable — do not refactor |
| `resources/` | yes | Resource providers |
| `scope_ids/` | yes | Scope identifier utilities |
| `security/` | yes | Auth, authorization, bearer auth, access control |
| `settings/` | yes | Settings management |
| `shutdown_cleanup/` | yes | Shutdown cleanup hooks |
| `timezoned/` | **no** | Stable — do not refactor |

Crypto lives in the separate `tom_crypto` dependency (not a module here).
The generated `version.versioner.dart` is tooling output — never hand-edit it.

---

## Concrete Step List

Iterate through these steps in order. Each step states its **done** condition.

> **OT1 baseline pass done (2026-07-15).** Steps 1, 14, and 15 are complete —
> the package passes every automated gate (`dart analyze` clean, `testkit :test`
> 1636/1636 green). The per-module deep passes (Steps 2–13) are tracked as a
> resumable iteration under quest todo **RCE2** (one module per iteration); see
> `_ai/quests/tom_core/todos.tom_core.todo.yaml`.
>
> ✅ **RCE2 done (2026-07-15) — documentation half.** The Per-Module Workflow's
> API-documentation deliverable (sub-steps 6–8: the `api.dart`-equivalent
> reference + "docs cover all public API, describe nothing absent") is complete
> for all 15 barrel modules: `doc/api_reference/` now holds one verified
> per-module `api_summary_*.md` plus `api_summary_index.md` (kernel 1.1.1). The
> open-ended internal-refactor + example/test-surface scaling (sub-steps 1–4) is
> deferred as low-priority depth work under quest todo **RCF1**.
>
> ✅ **RCF1 first module done (2026-07-15) — `beanlocator/` sub-steps 1–4.** One
> bounded module iteration: a private-only DRY refactor of `bean_locator.dart`
> (four `_find*Match` methods → one `_findImplementation` chain + `_findSingleMatch`
> helper; public signatures frozen), example surface scaled (new
> `04_type_and_environment_registration_example.dart` covering the type/env-keyed
> API), test surface scaled (`beanlocator_test.dart` 29 → 40 tests, all documented
> exception keys asserted), and 4 latent example-assertion bugs fixed (surfaced by
> running examples under `dart run --enable-asserts`). `dart analyze` clean;
> `testkit :test` 1647/1647 (serial). The remaining 11 modules continue under quest
> todo **RCG1**.
>
> ✅ **RCG1 first module done (2026-07-15) — `security/` sub-steps 1–4.** One
> bounded iteration: private-only DRY refactor of `access_controls.dart`
> (`TomRoleAccess` + `TomGroupAccess` identical bodies → shared private
> `_principalAciContainsAny` helper; `TomEntitlementAccess` left separate as its
> regex rule is genuinely different; public signatures frozen), example surface
> scaled (new `04_graded_access_example.dart` covering the four-state
> `TomGradedAccess`/`TomAuthState` surface that had zero example coverage, wired
> into `00_run_all_examples.dart`), test surface scaled (`security_test.dart`
> 1647 → 1650, pinning the extracted helper's contract), and 1 latent
> example-assertion bug fixed in `02_access_control_example.dart` (stale
> assertions of a since-fixed group-constructor bug, surfaced under
> `--enable-asserts`). `dart analyze` clean; `testkit :test` 1650/1650 (serial).
> The remaining 10 modules continue under quest todo **RCH1**.
>
> ✅ **RCH1 first module done (2026-07-15) — `logging/` sub-steps 1–4.** One
> bounded iteration: private-only DRY refactor of `logging_isolate.dart`
> (`TomIsolateLogOutput.output` + `TomCreatorLogOutput.output` built the
> identical `TomInterIsolateLogMessage` record → shared private
> `_interIsolateMessage(...)` helper; the two dispatch bodies left separate as
> their routing/fallback is genuinely different; public signatures frozen) plus a
> stale `// TODO` in `TomRemoteLogOutput.output` replaced by an explanatory
> comment (retry/replay-queue resilience filed as **RCI2**). Example surface
> scaled (new `04_isolate_and_remote_logging_example.dart` covering the
> kernel-owned isolate/remote surface — inter-isolate record, executor, isolate
> & creator outputs with gating/fallback, worker context, remote message/result/
> context, remote output, and the remote server incl. CWE-117 sanitization —
> which had zero example coverage; wired into `00_run_all_examples.dart`, now
> async). Test surface scaled (`logging_test.dart` closed the
> `TomLoggingWorkerContext.initializeIsolate` gap; 1650 → 1652). `dart analyze`
> clean; every example self-asserts under `--enable-asserts`; `testkit :test`
> 1652/1652 (serial). The remaining 9 modules continue under quest todo **RCI1**.
>
> ✅ **RCI1 first module done (2026-07-16) — `http_connection/` sub-steps 1–4.**
> One bounded iteration: private-only DRY refactor of `server_connection.dart`
> (the six `TomServerCall.getResponse*` accessors each repeated the same
> `response == null` guard → shared private `_requireSentResponse(key, message)`
> helper; the read-once guard in `read()`/`readAsString()` → private
> `_ensureNotYetRead(key)` helper; `read()` keeps its original
> `_read = true`-before-await ordering so concurrent-read semantics are
> unchanged; public signatures frozen). Example surface scaled (new
> `04_auth_retry_example.dart` covering the real kernel auth-retry coordinator —
> `tomRunWithAuthRetry`, `TomAuthRefresher`, `TomAuthRetryPolicy` incl. the
> bean-resolved `active`, and `TomAuthExpiredException` — which had **zero**
> example coverage; the pre-existing `03_retry_policies_example.dart` only showed
> a hand-rolled pattern; wired into `00_run_all_examples.dart`, now async). Test
> surface scaled (`auth_retry.dart` had **zero** tests; added `TomAuthRetryPolicy`,
> `TomAuthExpiredException` and `tomRunWithAuthRetry` groups). `dart analyze`
> clean; every example self-asserts under `--enable-asserts`; `testkit :test`
> 1667/1667 (serial). The remaining 8 modules continue under quest todo **RCJ1**.
>
> ✅ **RCI2 done (2026-07-16) — `logging/` `TomRemoteLogOutput` resilience.** Not a
> per-module refactor Step but the behaviour enhancement carved out of RCH1's
> signature-frozen pass (the old `// TODO: retry/queue` note). `output()` now
> treats a *returned* `TomServerCallError` as a failure (not just a thrown one)
> and routes it through the fallback — no record silently `print()`ed away. Added
> opt-in static knobs `globalSettingMaxSendRetries` (bounded retry) +
> `globalSettingRetryBackoff` (linear `backoff × attempt`) + a bounded drop-oldest
> in-memory replay queue (`globalSettingReplayQueueMaxSize`, drains oldest-first
> on the next send) with `replayQueueLength` / `clearReplayQueue()`. Defaults
> (0/zero/0) preserve prior single-attempt-then-fallback behaviour. Example 04
> gained an Example 9 (retry-recovery, outage-buffering, ordered drain);
> `logging_test.dart` gained a `resilience` group. `dart analyze` clean; example
> self-asserts under `--enable-asserts`; `testkit :test` 1676/1676 (serial);
> kernel 1.1.4 → 1.1.5. Durable/persistent replay queue filed as **RCJ2**.
>
> ✅ **RCK1 first module done (2026-07-16) — `isolate_pooling/` sub-steps 1–4.**
> One bounded iteration: private-only DRY refactor of `tom_worker.dart` (the two
> identical response-completion bodies — the `_TomIsolateResponse` branch of the
> instance `_handleResponsesFromIsolate` and the `_TomCreatorResponse` branch of
> the static `_handleCommandsToIsolate` — collapsed into one static
> `_completeFromResponse(completer, response)` helper: `RemoteError` →
> `completeError`, else `complete`; the three executor-chain loops left separate
> as their send-timing and error-logging genuinely differ; public signatures
> frozen) plus the stale `// TODO: add regular pings` note on `TomWorkerPool`
> replaced by an explanatory comment (liveness supervision filed as **RCJ1**).
> Example surface scaled (new `03_creator_backchannel_example.dart` covering the
> worker→creator back-channel — `canSendToCreator`, `executeInCreator`,
> `sendToCreator` into a creator-side executor, a custom `TomWorkerContext` with
> init-hook overrides, and `RemoteError` propagation — which had **zero** example
> coverage; wired into `00_run_all_examples.dart`) and a latent example bug fixed
> (`02_worker_pool_example.dart` cast a `Future<Object?>` to `bool` without
> `await`, crashing under `--enable-asserts`; the confusing
> `Future.value(pool.execute(...))` wrappers were also removed). Test surface
> scaled (`isolate_pooling_test.dart` 53 → 58: base `TomCommand.execute` default,
> the last untested exception key `attempt_to_start_isolate_but_sendport_is_null`,
> in-worker `canSendToCreator`/`sendToCreator`, end-to-end `sendExecutorToIsolate`,
> and the non-error creator-channel branch of the extracted helper). `dart analyze`
> clean; every example self-asserts under `--enable-asserts`; `testkit :test`
> 1681/1681 (serial); kernel 1.1.5 → 1.1.6. The remaining 7 refactorable modules
> continue under quest todos **RCK2–RCK8**; the isolate-pool liveness supervision
> carved out of this pass is filed as **RCJ1**.
>
> ✅ **RCK2 done (2026-07-16) — `resources/` sub-steps 1–4.** One bounded
> iteration: private-only DRY refactor of `tom_resource_provider.dart`. Both
> providers resolved a key with the same rule (dot-notation tree walk via
> `getObjectFromTree`, then a flat-key fallback), duplicated across **eight**
> accessor bodies — `TomTextResourceProvider.{exists, existsObject, getObject,
> getObjectOrNull, getText, getTextOrNull}` and `TomConfigResourceProvider.
> {exists, getText}`. Extracted two file-private top-level helpers holding that
> rule once: `_resolveObjectOrNull(resources, path)` (any value type) backs the
> object family, and `_resolveStringOrNull(resources, path)` (String only, but
> still consulting the flat key when the tree walk lands on a non-String) backs
> the text family; every accessor is now a one-line expression differing only in
> its missing-value fallback (`?? key`, `!= null`, or the raw value). The
> text/object split is preserved deliberately — collapsing the text family onto
> the object helper would drop the flat-String fallback for a literal dotted key
> (e.g. `'a.b'` present alongside a nested `'a'→'b'`), a genuine semantic
> difference, not coincidental duplication. Public signatures and all dartdoc
> frozen. Example surface scaled (new `03_app_singleton_example.dart` covering
> the app-wide singleton surface — the static `loader`, loader-driven default
> constructor, `getAppResources`/`getAppConfig` lazy init, `setApp*Provider`
> replacement, singleton identity, and text/config singleton independence —
> which examples 01/02 did not cover; wired into `00_run_all_examples.dart`; no
> latent example bug surfaced under `--enable-asserts`). Test surface scaled
> (`resources_test.dart` 98 → 102: a `shared resolution contract` group pinning
> the flat-String fallback on a non-String tree hit, object-family resolution at
> a hierarchical path, the object-vs-text divergence on a nested non-String, and
> config/text object-family parity). No reflection regen needed — no new
> reflected types or annotations, signatures frozen (`resources_test.dart` is in
> `build.yaml` `generate_for` but does not import its generated part). `dart
> analyze` clean; every example self-asserts under `--enable-asserts`; `testkit
> :test` 1685/1685 (serial); kernel 1.1.6 → 1.1.7. No residual carved out —
> nothing deferred, no new RCJ filed.

> ✅ **RCK3 done (2026-07-16) — `context/` sub-steps 1–4.** One bounded
> iteration: private-only DRY refactor of `execution_context.dart` with all
> public signatures and dartdoc frozen. Two genuine duplications extracted:
> (1) `runInContext` and `runInContextAsync` shared a byte-for-byte preamble
> (build new `TomExecutionContext` merged over the zone's context, wrap
> `zoneValues` in a `TomZoneValues` merged over the zone's, assemble the
> `{TomExecutionContext, TomZoneValues}` map) — now the file-private
> `_buildZoneValues`, each run method reduced to a one-line `runZoned`, and the
> superfluous `async` (no `await`) dropped from `runInContextAsync` (return type
> `Future<T>` preserved via `runZoned<Future<T>>`). (2) All nine
> `TomContextProviders` getters read the zone's `TomPrincipal`, selected one
> field, and fell back to a default — that read-select-fallback now lives once in
> `_fromPrincipal(select, fallback)`, each getter a one-line selector so a change
> to principal resolution lands in one place. Example surface scaled (new
> `04_async_and_zonevalues_example.dart` covering `runInContextAsync` propagation
> across an `await` boundary and through nested async runs, plus the full
> `TomZoneValues` mutation API — `addAll` chaining, `containsKey`, `remove`,
> `clear` — and the `existingValues` merge; `00_run_all_examples.dart` made async
> to await it; no latent bug surfaced under `--enable-asserts`). Test surface
> scaled (`context_test.dart` 61 → 66: added the five missing principal-populated
> provider tests — `getProcess`, `getCountry`, `getTimezone`,
> `getClientLanguage`, `getClientCountry` — so each of the nine one-line
> selectors is verified against a live principal, guarding a mis-wired field
> selector). No reflection regen — no new reflected types or annotations,
> signatures frozen, `context_test.dart` not in `build.yaml` `generate_for` and
> uses no reflection. `dart analyze` clean; every example self-asserts under
> `--enable-asserts`; `testkit :test` 1690/1690 (serial); kernel 1.1.7 → 1.1.8.
> No residual carved out — nothing deferred, no new RCJ filed.

> ✅ **RCK4 done (2026-07-16) — `settings/` sub-steps 1–4.** One bounded
> iteration, audit outcome. `settings_client_authorization.dart` holds two
> independent serialization DTOs (`TomGetSettingsMessage`,
> `TomGetSettingsResult`) with no shared logic — no genuine within-module
> duplication to extract (the constructor's `?? <T>{}` / `?? <T>[]` defaulting is
> idiomatic per-field initialization, which DRY discipline says not to abstract).
> The one honest, signature-preserving cleanup done in sub-step 1: removed the
> dead `= ""` field initializers on `TomGetSettingsResult`'s eight nullable
> `String?` fields (`organization`, `process`, `application`, `country`,
> `language`, `clientCountry`, `clientLanguage`, `clientTimezone`) — each is an
> initializing formal (`this.x`) in the constructor, so the field-level `= ""`
> never took effect and the real default was already `null` (as the existing
> tests assert). It was dead code that misled about the default; removal changes
> no runtime behaviour and no public signature. `TomGetSettingsMessage.
> authorizationToken = ""` left intact (no initializing formal → its `= ""` is
> the live default). Constructor dartdoc corrected. Example
> (`01_client_authorization_example.dart`, 15 scenarios) and tests
> (`settings_test.dart`, 72 cases) already covered the full public surface of
> both DTOs — including the null-default guard that pins the removal and the
> reflection JSON round-trip — so sub-steps 2–3 needed no additions. No
> reflection regen (field types/names unchanged; `settings_test.dart` is in
> `build.yaml` `generate_for` and its generated part still round-trips green).
> Verified no consumer relied on a `""` default across samples and tom_uam (they
> only write the fields), so no adaptation was needed. `dart analyze` clean;
> example self-asserts under `--enable-asserts`; `testkit :test` 1690/1690
> (serial); kernel 1.1.8 → 1.1.9. No residual carved out — nothing deferred, no
> new RCJ filed.

> ✅ **RCK5 done (2026-07-16) — `shutdown_cleanup/` sub-steps 1–4.** Private-only
> DRY refactor of `tom_shutdown_cleanup.dart`, all public signatures frozen. Two
> genuine, behaviour-preserving deduplications: (1) `_executeCleanup`'s three
> near-identical try/catch loops (over `_signalHandlers`/`_closables`/
> `_disposables`) collapse into a single private generic
> `_runPhase<T>(List<T>, String label, void Function(T))` that owns the per-entry
> isolate-and-report policy — `_executeCleanup` is now three one-line phase
> calls, and a change to the isolation/diagnostic policy is a one-site edit (was
> three). Exact log wording preserved. (2) The constructor's two SIGHUP/SIGINT
> registrations duplicated `addSignal`'s exact
> `_signalSubscriptions.add(sig.watch().listen(_signalHandler))` body; the
> constructor now calls `addSignal(...)`, giving a single owner of signal-watch +
> subscription-retention (bug §53). No other genuine duplication (`TomCloseAdaptor`
> already had `_resolveCloseMethod` extracted; the DTO-style getters are
> independent). Sub-step 2: added `example/shutdown_cleanup/
> 02_shutdown_execution_example.dart` (wired into the runner) that *executes* the
> API — the pre-existing `01_*` is purely descriptive and never triggers cleanup;
> the new one drives phase order, once-only, fault isolation, `paused`
> (signal-skip vs manual-always), `silent`, `cancelAll`/`dispose`, and
> `TomCloseAdaptor` on a reflected custom-teardown target, all `assert`-guarded
> under `--enable-asserts`. Sub-step 3: added one test pinning the manual-path
> contract (`performShutdown()` ignores `paused` — previously only the signal
> path was asserted); suite 63 → 64. Sub-step 4: new reflected example added to
> `build.yaml` `generate_for` and its `.reflection.dart` generated via
> build_runner (the only regen — a genuinely new entry point, not a no-op regen).
> `dart analyze` clean; example self-asserts under `--enable-asserts`;
> `testkit :test` green (serial); kernel 1.1.9 → 1.1.10. No residual carved out —
> nothing deferred, no new RCJ filed.

> ✅ **RCK6 done (2026-07-16) — `json/` sub-steps 1–4.** Private-only DRY refactor
> of `map_merge_and_process.dart`, all public signatures frozen. Two genuine,
> behaviour-preserving deduplications: (1) `getPathFromTree` and
> `getObjectFromTree` shared an identical dot-path walk with identical
> resolution/throw messages, differing only at a terminal *non-map* value;
> `getPathFromTree` now delegates the walk to `getObjectFromTree` and only wraps
> the resolved value under `name` when it is not already a subtree — the
> `tomLog.warn` and all `Exception` wording are preserved (the wrap context is
> always the final path segment, since an interior non-map throws inside the
> delegate). (2) `makeCleanJsonMap` and `_cleanList` repeated the same JSON-type
> dispatch (String/int/double/bool pass through, Map/List recurse, everything
> else dropped); that dispatch now lives in one private
> `_cleanJsonValue(Object?)` helper both call, so the filter policy is a one-site
> edit. Removed a stale `TODO` on the library directive. `_MergeArrays`,
> `mergeMapsOneSided`, the `traverse*` pair (semantically distinct — value
> processing vs. key-name creation), `_TreeModification`/`processTree`, and the
> env-var helpers had no genuine duplication and were left as-is. Sub-step 2:
> added `example/json/03_json_config_resolution_example.dart` (wired into the
> runner) covering the members that had no executable example —
> `substituteEnvVars` (with defaults), `traverseAndCreate`, `processTree`
> (profile `@`/`...` directives) and `TomJsonSerializable` — all `assert`-guarded
> under `--enable-asserts`; this fulfils the removed TODO's intent. Sub-step 3:
> added a `TomJsonSerializable` test group (toJson exposure, `jsonEncode`/
> `jsonDecode` round-trip, `makeCleanJsonMap` interop, nullable values); json
> group 102 → 106, kernel suite 1691 → 1695. Sub-step 4: the `json/` module uses
> no reflection and the new example implements a plain interface, so no
> `build.yaml`/reflection change and no regen. `dart analyze` clean; examples
> self-assert under `--enable-asserts`; `testkit :test` green (serial); kernel
> 1.1.10 → 1.1.11. No residual carved out — nothing deferred, no new RCJ filed.

> ✅ **RCK7 done (2026-07-16) — `little_things/` sub-steps 1–4.** Light pass, as
> predicted. Sub-step 1: the module was already DRY — the stack-trace frame
> processing shared by `tomGetStackTrace`/`AsList`/`AsTuple`/`tomPrintStackTrace`
> had already been extracted into private `_processStackFrames` — so there was no
> further genuine duplication to remove. `formatting.dart`
> (`convertMinutesToUtcOffset`) and `exception_base.dart` (`TomException`) are
> single-unit files with no duplication. The only sub-step-1 action was removing
> two stale investigation `TODO` comments above the stack-trace utilities (vague
> design musings; the folding is deliberate and tested). All public signatures
> frozen. Sub-step 2: added `example/little_things/
> 03_formatting_and_exceptions_example.dart` (async; wired into the now-async
> runner) covering the previously undemonstrated public surface —
> `convertMinutesToUtcOffset`, a *truly-awaited* `runChecked` success+error (the
> pre-existing `02_*` only checked `is Future`), `tomPrintStackTrace`,
> `TomException.printStackTrace()`, `autoLog` (observed via a recording
> `TomLogOutput`), `serverCallError`, and `logRepresentation` — all
> `assert`-guarded under `--enable-asserts`. Sub-step 3: added a `newField`
> test group (default-null + set/get), closing the last untested public member;
> kernel suite 1695 → 1697. **Decision: `newField` is KEPT, not removed** — grep
> shows it is referenced by generated reflection (`uam_generated.r.dart`) and the
> tom_core_server D4rt bridges (`LoginException.newField`), so it is live
> reflected/bridged surface, not dead code; removing it would cascade
> disproportionately for a light pass. Sub-step 4: the `little_things` examples
> use no reflection and the new example implements no reflected types, so no
> `build.yaml`/reflection change and no regen (the legacy
> `little_things_test.reflection.dart` is unused by the test and left untouched).
> `dart analyze` clean; examples self-assert under `--enable-asserts`;
> `testkit :test` green (serial); kernel 1.1.11 → 1.1.12. No residual carved out
> — nothing deferred, no new RCJ filed.

> ✅ **RCK8 done (2026-07-16) — `scope_ids/` sub-steps 1–4.** Last of the eight
> RCJ1 modules. Sub-step 1 (DRY, private-only, signatures frozen): `TomScope.
> runInScope` and `TomScopeMixin.runInScope` had byte-identical bodies (the
> `identical(this, current)` no-op-zone check + `runZoned` install), forced apart
> only because the mixin `implements TomScope` rather than extending it; the
> shared install policy is now one private top-level `_runScoped<T>(TomScope,
> body)` helper both delegate to. The per-arity `InScopeBuilder.wrapN`/`wrapNn`
> methods cannot be collapsed (Dart has no variadic generics) and the two
> `getScopePath()` delegations already route through the shared `buildScopePath`,
> so no other genuine duplication. Sub-step 2: added `example/scope_ids/
> 03_scope_mixin_example.dart` (wired into the runner) covering the previously
> undemonstrated surface — a custom class using `TomScopeMixin` *directly* (the
> real consumer pattern, e.g. tom_flutter_ui's `TomScreenElementsProviderBase`),
> the instance participating fully as a scope (`current`, path, `runInScope`,
> `InScopeBuilder`), and the write-once `set id`/`set parent` setters — all
> `assert`-guarded under `--enable-asserts`. Sub-step 3: added a `TomScopeMixin`
> test group (custom mixin class + `initScope`, `runInScope`, `InScopeBuilder`
> integration, and the write-once setters); kernel suite 1697 → 1701.
> **Decision: the `set id`/`set parent` setters are KEPT, not removed** — although
> no Dart consumer uses them (all use `initScope`), they are registered by the
> tom_core_d4rt bridges for `TomScopeBase` (bridge setters at
> `tom_core_kernel_bridges.b.dart`), so removal would cascade into a bridge regen,
> disproportionate for a light pass (same reasoning as RCK7's `newField`).
> Sub-step 4: `scope_ids` is not in `build.yaml` and the new example implements no
> reflected types, so no `build.yaml`/reflection change and no regen. `dart
> analyze` clean; examples self-assert under `--enable-asserts`; `testkit :test`
> green (serial); kernel 1.1.12 → 1.1.13. No residual carved out — nothing
> deferred, no new RCJ filed.

> ✅ **RCK9 done (2026-07-16) — durable replay store for `TomRemoteLogOutput`.**
> A former RCJ residual (feature todo, not a numbered per-module pass), hardening
> the one edge RCI2's in-memory replay queue cannot cover: a process restart
> *during* an endpoint outage. Made the replay-queue storage pluggable behind a
> minimal `TomLogReplayStore` interface (`append` / `snapshot` / `oldest` /
> `removeOldest` / `trim` / `clear` / `length`), with `TomInMemoryLogReplayStore`
> as the zero-config default (byte-identical runtime behaviour to the old inline
> `_replayQueue` list) and a new file-backed `TomFileLogReplayStore` in a
> separate `file_log_replay_store.dart` (imports `dart:io`, consistent with the
> barrel-exported `tom_shutdown_cleanup` precedent). `TomRemoteLogOutput` now
> delegates enqueue/drain through `globalSettingReplayStore`; the
> `globalSettingReplayQueueMaxSize` gate/bound is unchanged. **Decision: record
> serialization (`_encodeReplayRecord`/`_decodeReplayRecord`) lives as private
> top-level functions in the file-store library, NOT on `TomRemoteLogMessage`** —
> that type is `@tomReflector` + tom_core_d4rt-bridged, so putting JSON helpers
> on it would force a reflection/bridge regen; the 8 fields are all JSON-native,
> so an external encoder keeps the reflected/bridged surface untouched (no regen).
> **Decision: file-store tests use `Directory.systemTemp.createTempSync(...)`
> with a guaranteed `tearDown` delete** (idiomatic ephemeral test fixtures; the
> ztmp rule targets durable agent scratch, not cleaned-up test tempdirs). Added
> a `durable replay store` test group (store contract, persistence-across-restart,
> bounded-trim-across-restart, end-to-end restart-during-outage recovery) and
> Example 10 in `04_isolate_and_remote_logging_example.dart` (assert-guarded).
> `dart analyze` clean; example self-asserts under `--enable-asserts`; `testkit
> :test` green (serial), kernel suite 1701 → 1706; kernel 1.1.13 → 1.1.14. No
> residual carved out — nothing deferred, no new RCJ filed.

1. **Meta files.** ✅ **Done (OT1, 2026-07-15).** `README.md` (customized, 252
   lines), `CHANGELOG.md` (1.1.0), and `LICENSE` (BSD 3-Clause) all present and
   accurate. Ensure `README.md` (summary + overview), `CHANGELOG.md`
   (short, pre-publish list of recent changes), and `LICENSE` (BSD 3-Clause —
   copy the wording from the existing `LICENSE`) exist at the project root.
   Create any that are missing; customize a template `README.md`.
   *Done when all three exist and the README describes the package accurately.*
2. **Per-module pass — `beanlocator/`.** ✅ **Sub-steps 1–4 done (RCF1, 2026-07-15).** Documentation half done under RCE2. Run the Per-Module Workflow below.
3. **Per-module pass — `context/`.** ✅ **Sub-steps 1–4 done (RCK3, 2026-07-16).** Documentation half done under RCE2.
4. **Per-module pass — `http_connection/`.** ✅ **Sub-steps 1–4 done (RCI1, 2026-07-16).** Documentation half done under RCE2.
5. **Per-module pass — `isolate_pooling/`.** ✅ **Sub-steps 1–4 done (RCK1, 2026-07-16).** Documentation half done under RCE2.
6. **Per-module pass — `json/`.** ✅ **Sub-steps 1–4 done (RCK6, 2026-07-16).** Documentation half done under RCE2.
7. **Per-module pass — `little_things/`.** ✅ **Sub-steps 1–4 done (RCK7, 2026-07-16).** Documentation half done under RCE2.
8. **Per-module pass — `logging/`.** ✅ **Sub-steps 1–4 done (RCH1, 2026-07-15).** Documentation half done under RCE2.
9. **Per-module pass — `resources/`.** ✅ **Sub-steps 1–4 done (RCK2, 2026-07-16).** Documentation half done under RCE2.
10. **Per-module pass — `scope_ids/`.** ✅ **Sub-steps 1–4 done (RCK8, 2026-07-16).** Documentation half done under RCE2.
11. **Per-module pass — `security/`.** ✅ **Sub-steps 1–4 done (RCG1, 2026-07-15).** Documentation half done under RCE2.
12. **Per-module pass — `settings/`.** ✅ **Sub-steps 1–4 done (RCK4, 2026-07-16).** Documentation half done under RCE2.
13. **Per-module pass — `shutdown_cleanup/`.** ✅ **Sub-steps 1–4 done (RCK5, 2026-07-16).** Documentation half done under RCE2.
14. **Barrel exports.** ✅ **Done (OT1, 2026-07-15).** `lib/tom_core_kernel.dart`
    exports all 15 modules (38 directives); analyzer clean ⇒ no unreachable public
    type. Verify every public symbol of every module is exported
    from the package barrel(s) in `lib/`. *Done when `dart analyze` is clean and
    no public type is unreachable from the package entrypoint.*
15. **Whole-package QA.** ✅ **Done (OT1, 2026-07-15).** `dart analyze` clean +
    `testkit :test` 1636/1636 green (serial). Run `dart analyze` (zero warnings)
    and `testkit :test` (all green). Confirm reflection is initialized for
    examples/tests and that `build.yaml` lists every file needing generation.
    *Done when analyzer and test suite are both clean.*
16. **Final review.** *(RCE2 — after the per-module passes.)* Re-read each module
    doc and `api.dart`; confirm docs only describe features that exist and cover
    all public API. Update `CHANGELOG.md` with a one-line summary of the pass.

> Modules `observable/`, `reflection/`, and `timezoned/` are intentionally
> **excluded** from the per-module passes — they are stable. Document and test
> coverage for them is maintained, but their implementation is not refactored.

---

## Per-Module Workflow

For each module step above, perform these sub-steps (do not change public
behavior; you may add private members/methods):

1. Refactor and document the files per
   [`dart/coding_guidelines.md`](../../../../_copilot_guidelines/dart/coding_guidelines.md).
   Do not add/remove/rename public methods, members, or accessors.
2. Create comprehensive **executable** examples per
   [`dart/examples.md`](../../../../_copilot_guidelines/dart/examples.md). Scale the count
   to the surface area so every important aspect is demonstrated.
3. Create comprehensive tests per
   [`dart/unit_tests.md`](../../../../_copilot_guidelines/dart/unit_tests.md). Scale the
   count to the surface area so every important aspect is covered.
4. Make examples and tests run. Add files to `build.yaml` for the reflection
   generator as needed; import and initialize reflection. Fix any bugs found.
5. Create the module documentation file per
   [`documentation_guidelines.md`](../../../../_copilot_guidelines/documentation_guidelines.md),
   named after the folder (e.g. `doc/http_connection.md`). Length scales with
   complexity.
6. Create / regenerate the module `api.dart` per the API file rules. Delete any
   stale `api.dart` first.
7. Read the generated `api.dart` and verify it matches the code.
8. Verify documentation covers all public classes, methods, and members and
   describes nothing that does not exist. Extract code samples from the docs
   into an example file and confirm they run.

---

## Guidelines References

| Guideline | Location | Scope |
| --------- | -------- | ----- |
| Coding Guidelines | [`dart/coding_guidelines.md`](../../../../_copilot_guidelines/dart/coding_guidelines.md) | All Dart |
| Clean Code | [`dart/clean_code_principles.md`](../../../../_copilot_guidelines/dart/clean_code_principles.md) | All Dart |
| Documentation | [`documentation_guidelines.md`](../../../../_copilot_guidelines/documentation_guidelines.md) | All projects |
| Unit Tests | [`dart/unit_tests.md`](../../../../_copilot_guidelines/dart/unit_tests.md) | All projects |
| Examples | [`dart/examples.md`](../../../../_copilot_guidelines/dart/examples.md) | All projects |
| API Summary | [`dart/api_summary_creation.md`](../../../../_copilot_guidelines/dart/api_summary_creation.md) | All projects |
