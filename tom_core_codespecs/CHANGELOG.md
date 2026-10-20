# Changelog

## 0.13.2

- Documentation only: the derivation contract's per-kind slot paragraph names
  `CsJob`'s four trigger arms (`interval` included).

## 0.13.1

- Documentation only: the CodeSpecs mapping and derivation contract name the
  `interval` job trigger (`CsJobTrigger.interval`, `SCJOB-INTV`, lowered onto
  `TomIntervalSchedule`).

## 0.13.0

- **`TomOperationBinding`** (`lib/src/operation_binding.dart`), with
  `TomBindingParameter`, `TomBindingSource` and `TomBindingErrorFormat`: a
  const value class that binds an already-named operation to a second HTTP
  shape — method, `versionPrefix` + `path` (`route`, `pathCaptures`), the wire
  parameter → request member mapping, success status, response headers, media
  types and the error format (the CE-ER result envelope, RFC 9457, SCIM or
  OAuth). It is the holder a CodeSpec's `@CsOperationBinding` (CE-API) marks
  in the server project (`codespecs_mapping.md` §5.30,
  `codespecs_derivation_contract.md` §3.4.5). `tom_core_server` declares one
  HTTP shape per endpoint and has no second binding of a named operation; the
  class moves to `tom_core` when a generic protocol capability over named
  operations ships there.
- `example/operation_binding_example.dart`; the gap-class inventory, README,
  `doc/gap_classes.md` and the API summary list the new module.

## 0.12.4

- Documentation only. `codespecs_derivation_contract.md` names the stored
  sources of `@CsTrigger.kind` (`triggerKind`) and `@CsNotification.body`
  (`bodyMessageKey`), and `codespecs_mapping.md` §10 has nothing open against
  it. The README states the current version.

## 0.12.3

- Documentation only. `codespecs_derivation_contract.md` names the validator's
  `--json` report and back-link index and says the extract reader is the SOM
  runtime's `CodeSpecsExtractSet`; `codespecs_mapping.md` §10 indexes the open
  work on two required arguments with no SOM source.

## 0.12.2

- The archive no longer ships `test/ai_citation_test.dart` and
  `test/formatting_test.dart`. Both import tom_ai/core's repository-root
  `tool/` and so failed to load from an installed 0.12.1; they keep running
  in the repository, where that `tool/` exists. No library change.

## 0.12.1

### Tests

- **`test/ai_citation_test.dart`** fails the suite when an artefact of the
  package cites a document in the AI-state mount. It runs
  `tom_ai/core/tool/check_doc_ai_citations.py` over the package through
  `tom_ai/core/tool/package_gate.dart`; the rule and its one exemption (the
  runtime `_ai/trail/` directory) are stated in the checker alone.
- **`test/formatting_test.dart`** fails the suite when a Dart file the
  package authors is not `dart format`-clean. It states the package's file
  floor, landmark directories and generated output, and delegates the
  sweep to `tom_ai/core/tool/package_format_guard.dart`, which every
  package under `tom_ai/core` shares.

### Changed

- **The CodeSpecs design ships with the package.** `codespecs_mapping.md`
  and `codespecs_derivation_contract.md` now live in `doc/`, so every `§`
  citation in this package's source and documentation resolves for a reader
  of the package. Both remain members of the TomSpecs document set, which
  links to them here.
- **`TomReportResultSection` takes a row factory, not a stream (tcopen358).**
  Its dartdoc said "rendering the same result twice needs a section that can
  produce a fresh stream" — and the type could not: `rows` was a stored
  `Stream`, with no factory, no `copyWith` and no re-subscription surface. Over
  a genuinely single-subscription source the first render returned the rows and
  the second threw `Bad state: Stream has already been listened to`. Over
  `Stream.fromIterable` it survived, which is why the suite was green.

  The constructor now takes `openRows`, a `Stream<List<Object?>> Function()`,
  and `rows` is a getter that calls it. The argument for fixing rather than
  softening is on the definition: `deliveryChannels` is a **list**, and a report
  declaring `apiResponse` and `fileExport` is one run delivered two ways, so
  each delivery reads the rows. The factory must return a new stream on every
  call — open the query inside the closure — which is the one part the type
  cannot enforce and is therefore stated on the constructor and pinned by a
  test that shows the failure mode.

  Every case is pinned against a `StreamController` rather than
  `Stream.fromIterable`, with a control asserting the fixture really is
  single-subscription; the easy fixture is what hid the defect.


- **`reconcileWarnings()` checks the node KIND, not only that the id resolves
  (tcopen357).** The delta grammar's documentation states which kind each
  operation addresses — `setContainerProp` and `removeContainer` a container,
  `setSlotHint` a slot — and the sealed `TomLayoutNode` base exists so the two
  can be told apart. Nothing checked it: a `setSlotHint` addressed at a
  container, a `setContainerProp` or `removeContainer` at a slot, and a slot
  named as a new parent all produced an empty warning list.

  That is the check the two-layer design most needs. An id that vanished is
  conspicuous and the existence check already caught it; an id a regeneration
  re-used for a different kind of node still resolves, so the delta went on
  applying and quietly meant something else — a hint authored for a field
  landing on the row that now carries that id.

  Two further faults are reported for the same reason: an `insertContainer`
  whose id the base has since taken (a node id is unique across the tree, so
  the insert would duplicate one), and an operation that needs a
  `newParentNodeId` and names none. Nothing is dropped in any case.

### Added

- **`example/` — one runnable example per gap class, plus an aggregator
  (tcopen355).** The package shipped none, which was a real gap rather than a
  formality: every gap class is a holder a specification author fills in, and
  several have shapes that only make sense seen whole. `TomLayoutModel`'s two
  layers are the hardest idea here, and the example shows the part a class
  listing cannot — that a delta whose target a regeneration removed is
  **reported and kept**, never dropped. `TomReportDefinition`'s six refusals
  are demonstrated by provoking all six. `TomNotificationCatalog`'s resolution
  order is run rather than described: mandatory channels first, a user
  selection that **replaces** the defaults rather than adding to them, then a
  per-channel urgency ceiling — which is why a user-chosen channel can
  legitimately deliver nothing.

  `test/examples_test.dart` runs all seven and the aggregator under exactly the
  command their headers document, and requires each to **refuse** a run without
  `--enable-asserts`, since every check in them is an `assert` and a flagless
  run would print the same transcript while verifying nothing. It also holds
  the folder to `gap_class_inventory_test.dart`'s inventory in both directions,
  so a gap class added without an example fails rather than going unnoticed.

## 0.12.0

8 files, +1878/-142 since 0.11.2.

- The gap-class set grew with the CodeSpecs parts catalogue: only the concrete
  classes `tom_core` genuinely lacks live here, and `doc/gap_classes.md` states
  which and why for each.
- The barrel re-exports the additions.
- Documented and test-covered at the quest's standard; the README's status
  block is now derived rather than transcribed.

## 0.11.2

- Docs only, no API change: the README's `## Status` block stated "95 tests,
  all passing". Nothing connected that number to the suite, so it could only
  rot — every added test would have been a README edit nobody makes. The block
  now says how the suite is run and gives no count; the version beside it is
  pinned to `pubspec.yaml` by `tom_ai/core/tool/check_readme_status.py`
  (tcincb153).

- Docs only, no API change: five test comments cited a bare section number of
  `codespecs_mapping.md`, which does not ship with this package, so the
  justification a reader needed was one indirection away and unreachable. Each
  now states the reasoning directly — why `domainEnum` needs no gap class, why
  CE-UP reuses `tom_core_server`'s preferences plane, and why the CE-RP
  drill-through target stays an open route-id string.

## 0.11.1

- Docs only, no API change: the library dartdoc and README now name the CE-AC
  trigger vocabulary `CsTriggerKind`, following its rename in `tom_code_specs`
  0.12.0. The note itself stays — it records that CE-AC is *not* a gap and that
  its vocabulary is delivered as an annotation argument elsewhere, which is
  still worth stating. What the rename removes is the part a reader had to be
  told: the symbol now names its own package.
- No API change: the library dartdoc now states dependency-freedom as an
  **invariant** rather than a step still to be taken. `dependencies: {}` and the
  absence of any `import` under `lib/` are what let `TomReportResult` decline to
  extend `TomTabularResult` and what put a job's CE-RP targets on
  `@CsJob(targetReports:)`; five places already argued from that premise while
  the barrel promised the opposite. A class needing a `tom_core_*` type is
  therefore not a gap class — it belongs in the package owning that type.
- Two tests pin the invariant, so a single added import can no longer retract
  those two placement decisions without failing a check.
- Docs only: the README's CE-RP row no longer counts an "authorization key"
  among the responsibilities that justify the gap. `TomReportDefinition`
  declines that field on purpose — authorization rides a `@CsAuthorize` beside
  the `@CsReport` marker (`codespecs_mapping.md` §5.15) — so the README was
  sending a reader to look for a field whose absence is the design. The
  absence is now **stated** rather than merely not-claimed, and tied to the
  rule it follows from: the `Cs*Ref` family lives in `tom_code_specs`, and
  `tom_core`-family classes hold plain ids, so an edge wanting a typed ref
  belongs on the annotation. Same rule as `TomJobDeclaration`'s report targets.
- Docs only: the README's CE-LO row named six of the seven layout symbols,
  dropping `TomLayoutNode` — the sealed base that types
  `TomLayoutContainerNode.children` and `TomLayoutModel.findNode`'s return, and
  whose sealedness is what makes the two-layer reconcile exhaustive. A reader
  working from the README could see neither. The row now names it ahead of its
  two subtypes, so the hierarchy reads in order.
- A test pins the inventory: every public top-level declaration under `lib/src`
  must be named in the README. Only that direction is checkable — the README
  legitimately names types from other packages — but it is the direction that
  drifted, and dropping one name from a parenthesised list is exactly the edit
  review does not catch.
- Docs only: `TomReportDefinition`'s construction checks were described in
  three places and agreed in none — the README counted three, the constructor
  dartdoc named a different three, and the completion record listed five. All
  three understated a constructor that rejects six defects. The dartdoc is now
  the one normative enumeration: it sits beside the code, so a seventh check is
  a diff a reviewer sees next to the list it belongs in. The README stops both
  counting and enumerating and points there instead, since a count repeated in
  prose is a count that goes stale.
- Five tests close the gap the divergence hid. The empty-`reportId` check — the
  one all three descriptions omitted — had no test at all, and of the five
  namespaces `_rejectDuplicates` guards only column name was exercised, so four
  could have been dropped from the call list without failing anything. The
  duplicate cases assert the *message*, not just `ArgumentError`: a repeated
  dimension key also trips the key-claimed-by-both check, so a weaker matcher
  passes with the duplicate check deleted.
- Docs only: three dartdoc sites and one CHANGELOG entry cited
  `codespecs_mapping.md` **§1.1b**, which that document does not contain. The
  referent is §1.1's lettered pillar **(b)**, carried as a bold inline marker
  under one heading rather than as a heading of its own. The package already
  wrote it correctly in `README.md`, so one passage was cited two ways. All
  four now match the README's `§1.1 pillar (b)`.
- The form was plausible because lettered sections are real in this tree —
  `acl_design_specification.md` genuinely has `## 26b.` — so the convention was
  borrowed from a document that has it to one that does not.
  `check_section_refs` cannot see that: it asks whether a `§` reference *names*
  a document, never whether the number is in it, which is why a citation naming
  the right file and the wrong section outlived the ones naming no file at all.

## 0.11.0

- **Breaking: remove `TomUserSettings`, `TomUserSettingsStore` and
  `TomMemoryUserSettingsStore` (CE-UP).** They were authored on the premise that
  `tom_core` had neither a typed user-settings holder nor a server-side per-user
  persistence seam. `tom_core` now ships the whole preferences plane —
  `TomUserPreferences` over `TomUserPreferenceRepository` scoped by
  `@TomDbScope(field: 'principal_id')` in `tom_core_server`, with
  `TomUserPreferenceDto`, `TomUserPreferenceKeys` and `tomUserPreferencesApi`'s
  four endpoints in `tom_core_kernel` — so the seam here was a second, worse
  home for it: an in-memory map with no scope and no rows.
- **The holder was never needed either.** `codespecs_mapping.md` §5.16 authors a
  user setting as `@CsUserSetting('user.preferredLanguage') String
  preferredLanguage = 'de';` — the key is the annotation's own argument and the
  **type and default are the member**, exactly as a domain enum's default
  belongs to the member that has one. `effectiveValue`'s persisted-value →
  default order is `TomUserPreferences.getOr(key, <the member's initialiser>)`,
  and `displayName` was a label's second home, which the closed-vocabulary rule
  forbids (§1.2 consequence 1, §5.21). CE-UP is a **reuse** verdict, not a gap.
- `csrb2`'s pinned gap-class inventory drops `user_settings.dart` and gains a
  CE-UP absence test, the shape `csrb7` uses for domain enums.

## 0.10.0

- **Breaking: `TomJobDeclaration.targetRefs` (`List<String>`) is replaced by
  `readEntities` / `writtenEntities` (`List<Type>`).** `codespecs_mapping.md`
  §5.29 scope part 3 and §4.4.1 both required a job's targets to be
  compiler-checked; the shipped member was a string list, so a renamed entity
  silently stopped resolving. Entities are already Dart types, so they are cited
  as `Type` literals — §5.23 gives them no `Cs*Ref` const **by design**, and a
  `Type` needs nothing but `dart:core`, so the package stays dependency-free.
- Read and written targets are **separate members**, not one union. `SCJOB-WORK`
  authors them as two SOM fields and impact analysis needs the difference: a
  schema change breaks a writer differently from a reader. `targetEntities` is
  the deduplicated union for callers that only ask whether a job touches an
  entity at all.
- A job's **CE-RP report targets are not here** — they ride
  `@CsJob(targetReports:)` in `tom_code_specs` as `CsReportRef` consts, because
  `codespecs_mapping.md` §5.23 places the `Cs*Ref` family in the annotation
  *parameter* vocabulary, beside the `CsMessageKey` that annotation already
  carries for `failureAlert`.

## 0.9.0

- **Breaking: remove `TomDomainEnum` / `TomDomainEnumValue` (the `domainEnum`
  member kind).** `codespecs_mapping.md` §4.1 realises a domain enum as a
  **plain Dart `enum`** — a member declaration of the part that introduces it,
  with no `tom_core` basis to build on — and
  `codespecs_derivation_contract.md` §3.1.1 emits exactly that. The holder was
  authored from a different reading of the same survey ("`tom_core` has only
  mechanical enums, no domain-enum framework") and the two sides then disagreed
  about whether a class exists at all. The plain-enum arm stands, for a reason
  stronger than precedence: the holder had nothing to hold. Each of its fields
  belongs somewhere else, and belongs there exclusively — the value token is the
  enum constant's own identifier (no second string to drift from the name), the
  value label is CE-TX copy in the message-key registry like every other label
  (§1.2 consequence 1, §5.21), the description is the doc comment the generator
  writes, and a default belongs to the enum-typed *member*, since two members of
  the same type may default differently. Keeping the holder would have given
  value labels a second home, which the closed-vocabulary rule forbids.
- `test/gap_class_inventory_test.dart` drops `domain_enum.dart` — with it, the
  one entry that was marked *verdict contested* — and pins the removal the way
  CE-CC's is pinned, so re-adding the class means arguing with a test.

## 0.8.0

- **Breaking: remove `TomClientConfiguration` (CE-CC).** It was authored when
  `tom_core` had no per-machine client-configuration holder. `tom_core_flutter`
  now carries one — `TomBaseClientConfiguration` with `TomSetting<T>` and
  `TomClientConfigurationStore` — so CE-CC is a **reuse** verdict
  (`codespecs_mapping.md` §4.1, §5.16) and keeping a second holder would breach
  the §1.1 pillar that a gap class exists only where `tom_core` genuinely lacks
  one. Nothing is lost in the trade: the reused holder has typed declaration,
  baseline resolution from `TomConfigResourceProvider`, override-only
  persistence and per-field plus holder-wide observation, where this class had
  three `String` fields and two untyped maps. A `@CsClientConfig` CodeSpec now
  extends `TomBaseClientConfiguration` and declares each setting in
  `declareSettings()`.
- Add `test/gap_class_inventory_test.dart`, pinning the shipped gap-class files
  to the parts that justify them. A gap class is a verdict about *another*
  package, so it can go stale without anything here changing — which is exactly
  how CE-CC came to have two holders. The inventory makes adding or removing one
  an edit that has to be justified next to its part.

## 0.7.0

- csra8: add the CE-RP report model — `TomReportDefinition` with
  `TomReportDimension`, `TomReportMeasure`, `TomReportColumn`,
  `TomReportParameter` and `TomReportChart`, plus the shared `TomReportResult` /
  `TomReportResultSection` envelope and the `TomReportValueKind` /
  `TomReportMeasureFunction` / `TomReportDeliveryChannel` / `TomReportChartKind`
  closed sets. CE-RP was promoted out of `codespecs_mapping.md` §4.3 on the
  finding that a **grouped projection** — dimensions and measures — has no
  authoring home in any active part: `tom_core_server`'s `TomGroupedSelect`
  supplies the runtime grammar, but CE-DB's spec-authorable surface is
  row-shaped.
- The envelope deliberately does **not** extend `tom_core_server`'s
  `TomTabularResult`. Its locus is *shared* — the client renders a report too —
  and a shared type cannot depend on a server type, so the server adapts it one
  way onto the tabular shape when exporting. That is the CE-DB entity
  placement decision applied again. The adaptation is honoured in one inherited
  constraint: rows stay a `Stream`, because a report exists for results too
  large to hold inline.
- `TomReportMeasureFunction` is 1:1 with `TomAggregateFunction`, and
  `COUNT(*)` / `COUNT(DISTINCT c)` are fields (`columnName`, `distinct`) rather
  than members — a measure the query layer cannot compile is a measure that
  cannot run, so the authorable set is exactly the compilable set.
- Three checks run at construction, because each is a specification defect a
  generator cannot repair: a column whose `sourceKey` names neither a dimension
  nor a measure, one key claimed by both, and a chart plotting a column the
  report does not project.

## 0.6.0

- csra7: add the CE-NT notification model — `TomNotificationType`,
  `TomNotificationChannelDeclaration`, `TomNotificationPreferences`,
  `TomNotificationCatalog` and the `TomNotificationCategory` /
  `TomNotificationUrgency` closed sets. CE-NT was promoted out of
  `codespecs_mapping.md` §4.3 because its SOM section (`NotificationModel`) is a
  structured entry list, not free text.
- Only the *choosing* layer is new. `tom_core_server`'s `messaging` module
  already delivers on a named channel (`TomMessage`, `TomMessageChannel`,
  `TomMessageRouter`, `TomMessageOutbox`) and is reused as-is per pillar (b);
  what it has no home for is which types exist, which channels each goes out
  on, and how a user's preferences narrow that set.
- Essentiality lives on the *type* (`isEssential`), so a preference object can
  never be constructed into a state that silences something it must not. A
  mute or a global opt-out silences a type outright and can only reach a
  non-essential one — it is not a per-channel narrowing.

## 0.5.0

- csra3: make CE-UP **single-moded** and close the second half of its gap.
  - Remove `TomUserSettingsPersistence` and the `persistence` / `isRoaming`
    members from `TomUserSettings`. They predate the settings re-cut and
    contradict `codespecs_mapping.md` §11, which splits configuration and
    settings into four parts — one per scope key, each single-moded, with the
    scope key alone deciding where a value lives. The old `local` arm is now
    CE-DS `@CsDeviceSetting` (a *reuse* verdict over existing `tom_core`
    property/settings classes, so it is deliberately **not** re-created here);
    the old `roaming` arm is the only meaning CE-UP has.
  - Add `TomUserSettingsStore` + `TomMemoryUserSettingsStore` — the
    **server-side per-user persistence** seam. `codespecs_mapping.md` §4.1
    names the CE-UP gap as "typed user-settings holder **+** server-side
    per-user persistence", and
    only the holder existed; the reused kernel carrier
    (`TomGetSettingsMessage`/`TomGetSettingsResult`) is a read-only bootstrap
    payload with no write-back path, so a user's chosen preference had nowhere
    to be stored. The user key is in every method signature because it *is* the
    scope — the sibling `TomClientConfigurationStore` deliberately has no user
    parameter at all.
  - Add `TomUserSettings.effectiveValue`, encoding `codespecs_mapping.md`
    §5.16's intra-scope
    precedence for CE-UP (persisted user value → declared default). A `value` of
    `null` means *unset*, not *set to null*.
  - Correct the `TomClientConfiguration` doc-comment, which distinguished CE-CC
    from "CE-UP roaming". The discriminator is **user identity in the key**: no
    user → CE-CC; per signed-in user → CE-DS or CE-UP.

**Breaking:** `TomUserSettingsPersistence` is gone, and
`TomUserSettings(persistence: …)` / `.isRoaming` no longer compile.

## 0.4.0

- csra2: add the four remaining gap classes the `codespecs_mapping.md` §4.1
  catalogue marks *gap*, each re-verified against the current `tom_core` before
  being written:
  - `TomLayoutModel` (CE-LO, `codespecs_mapping.md` §5.2/§5.12/§5.22) — the
    two-layer layout holder:
    a generated `base` tree of `TomLayoutContainerNode` / `TomLayoutSlotNode`
    over the closed nine `TomLayoutContainerKind`, plus an authored `overrides`
    layer of id-addressed `TomLayoutOverrideDelta` over the closed five
    `TomLayoutDeltaOp`. `reconcileWarnings()` **reports** a delta whose target
    id has vanished and never drops it, so manual layout survives regeneration.
    `tom_flutter_ui`'s `AclComponent` is a rendering leaf holding a live
    `Widget` — it has no base/override layering and no delta grammar.
  - `TomMessageKeyRegistry` (CE-TX, `codespecs_mapping.md` §5.8/§5.21) — the
    closed message-key
    catalogue: `TomMessageKey` with base copy, per-locale copy, declared
    parameters, the closed `TomMessageRole` five and `TomMessageCategory` pair.
    `resolve()` falls back to base copy and **never to the raw key**, and
    rejects an uncatalogued key as a generation-time spec error; error copy must
    name its CE-ER code, because that namespace *is* the code namespace.
    `tom_core_kernel`'s `TomTextResourceProvider` is an untyped runtime
    `Map<String, dynamic>` with no key vocabulary.
  - `TomRouteRegistry` (CE-NV, `codespecs_mapping.md` §5.11) — the route-id
    registry (`registerRoute`
    rejects a duplicate id; `danglingRouteReferences()` finds edges and
    assignments naming an unregistered route) plus the screen-flow model:
    `TomFormScreenAssignment` (replace vs popup) and `TomScreenFlowEdge`
    (per-`TomFlowOutcome` conditional targets). `tom_flutter_ui`'s
    `TomPageRoute` is a bare `MaterialPageRoute` subclass carrying no id.
  - `TomJobDeclaration` (CE-JB, `codespecs_mapping.md` §5.29) — the
    deployment/ownership envelope
    (`enabled`, `environments`, `serviceUnitId`, `targetRefs`, `runsIn()`).
    Deliberately **narrow**: `tom_core_kernel`'s scheduling module now supplies
    the whole runtime half (`TomJobDefinition`, `TomSchedule`, `TomScheduler`,
    `TomJobStore`, `TomLeaseLock`, `TomJobDispatcher`), which is reused as-is.
- CE-AC (Trigger) is confirmed **not** a gap and gets no class here —
  `codespecs_mapping.md` §4.1 / §5.10 / §5.20 record "no gap — full action
  implementation reused". Its closed five-kind taxonomy ships as `TriggerKind`
  on `@CsTrigger` in `tom_code_specs` 0.5.0 instead.

## 0.3.0

- csm210-4-1 (wave-2 W10): add the CE-EN domain-enum gap class flagged *gap* by
  the csm4 code-basis survey (`codespecs_mapping.md` §5 — `tom_core_kernel`
  has only mechanical enums, no domain-enum/value-object framework):
  - `TomDomainEnum` — the holder a `@CsEnum` (CE-EN) CodeSpec is built on:
    `enumId`, `displayName`, an ordered `values` list, optional `defaultValueId`,
    and `hasValue(id)`.
  - `TomDomainEnumValue` — one member: stable `valueId` (wire/storage token)
    separated from display `label`, plus optional `description`.
- CE-DB stays a *reuse* verdict — `@CsTable`/`@CsColumn`/`@CsRepository` are built
  directly on `tom_core_server` persistence classes, so CE-DB needs no gap class.

## 0.2.0

- csm2r7: add the first concrete gap classes for the four new csm2r5 parts
  (survey `codespecs_mapping.md` §1.1 pillar (b)). CE-AU (Authentication) and
  CE-CF (ServerConfiguration) reuse existing `tom_core` classes; the three
  parts with no `tom_core` holder land here:
  - `TomClientApplication` (CE-CL) — client-application descriptor.
  - `TomClientConfiguration` (CE-CC) — per-machine client config holder.
  - `TomUserSettings` + `enum TomUserSettingsPersistence { local, roaming }`
    (CE-UP) — user-settings holder with the `codespecs_mapping.md` §11
    `local`/`roaming` persistence split (default `roaming`).
- The package is no longer an empty stub.

## 0.1.0

- Initial scaffold (csm3). Empty gap-filler package under `tom_core`.
- Gap classes are added by later CodeSpecs waves (csm4 surveys tom_core per
  part and identifies which structures belong here).
