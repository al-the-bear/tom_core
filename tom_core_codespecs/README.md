# tom_core_codespecs

CodeSpecs-only **gap-filler** for `tom_core`.

**Core principle** (csm1 /
`../../ai_build/tom_specs_model/doc/codespecs_mapping.md` §1.1): every actual
class a CodeSpec instantiates must be a `tom_core`-family class — one of the
five packages `tom_core_kernel`, `tom_core_flutter`, `tom_core_server`,
`tom_core_d4rt`, and `tom_flutter_ui` (the fifth basis, dsb6 /
`codespecs_mapping.md` §1.1b). Prefer reusing an existing `tom_core` class
directly; only the **concrete** gap classes `tom_core` genuinely lacks belong
here — **never abstract `Cs*` bases** (the framework carries annotations only,
`codespecs_mapping.md` §1.1) — so `tom_core` stays free of CodeSpecs-only
concerns.

## Gap classes

The gap classes are added by the CodeSpecs waves: each surveys `tom_core` per
part (reuse / extend / new-in-codespecs) and the genuine gaps land in this
package as concrete classes.

**csm2r7 — the four new parts** (survey:
`../../ai_build/tom_specs_model/doc/codespecs_mapping.md`). CE-AU
(Authentication) and CE-CF (ServerConfiguration) reuse existing `tom_core`
classes, so they need no gap class. Neither does **CE-CC**
(ClientConfiguration): `tom_core_flutter`'s `TomBaseClientConfiguration` /
`TomSetting<T>` / `TomClientConfigurationStore` is the (client app, machine)
holder — typed declaration through `declareSettings()`, baselines resolved from
`TomConfigResourceProvider`, overrides persisted and *only* overrides, and
observation both per field and holder-wide — with no user in the key, which is
the whole CE-CC discriminator (`codespecs_mapping.md` §4.1, §5.16, §11). The two
parts that had no `tom_core` holder:

| Class | Part | Purpose |
|-------|------|---------|
| `TomClientApplication` | CE-CL Client | Client-application descriptor (id, platforms, entry route, server URL). |
| `TomUserSettings` + `TomUserSettingsStore` | CE-UP UserSettings | The typed user-settings holder and the server-side per-user persistence seam — both halves of the gap `codespecs_mapping.md` §4.1 names. Single-moded: user-scoped and server-persisted, because `codespecs_mapping.md` §11 lets the scope key alone decide where a value lives (csra3, below). |

**csm210-4-1 (wave-2 W10) — CE-DB / domain enums** (survey:
`../../ai_build/tom_specs_model/doc/codespecs_mapping.md` §3). CE-DB is a
*reuse* verdict — `@CsTable`/`@CsColumn`/`@CsRepository` are built directly on
`tom_core_server` persistence classes (`@TomDbTable`, `@TomDbColumn`,
`@TomEntityId`, `@TomDbScope`, `TomRepository<T,K>`,
`TomSqlDatasourceRepository`, `query_builder`, `TomTransaction`), so CE-DB needs
no gap class. **Neither do domain enums** — `codespecs_mapping.md` §4.1 realises
the `domainEnum` member kind as a **plain Dart `enum`**, so there is no class to
build on and none to supply. An earlier reading of the survey ("`tom_core` has
only mechanical enums, no domain-enum framework") produced a
`TomDomainEnum`/`TomDomainEnumValue` holder here; it was removed in 0.9.0. The
question the survey answers is *what does `tom_core` lack*, and the answer is
nothing, because a domain enum has no authored attributes of its own to hold:

| Would-be attribute | Where it actually lives |
|--------------------|-------------------------|
| value token (`valueId`) | the enum constant's own identifier — no second string to drift from the name |
| value label | CE-TX copy in the message-key registry, like every other label (`codespecs_mapping.md` §1.2 consequence 1, §5.21) |
| description | the doc comment the generator writes above the enum and each constant (`codespecs_derivation_contract.md` §3.1.1) |
| default value | the enum-typed *member* that has one (a CE-DB column, a CE-CF/CE-CC/CE-DS/CE-UP setting, a CE-ST field) — two members of the same type may default differently |

A holder would hold nothing, and it would give value labels a **second** home,
which the closed-vocabulary rule forbids.

### Entity-model placement (CE-DB) — decided

A CodeSpecs data entity is referenced by both the client (as DTO/view) and the
server (as persistence). The entity's **field shape is authored once in the
`shared` project** of the three-project output trio (`codespecs_mapping.md`
§4.2) as the canonical entity; the server-only
`@CsTable`/`@CsColumn`/`@CsRepository` persistence projection and the
client-only DTO/view both derive from that shared shape. This keeps the client
free of any dependency on a server-authored type and mirrors the CE-UP `roaming`
pattern (a shared shape with a server-side persistence facet). The persistence
markers themselves remain **server-side** parts (`service_annotations.dart`).

> Naming note: an earlier survey wrote "CsDbTable"; the annotations-only
> catalogue realises CE-DB as the `@CsTable` + `@CsColumn` + `@CsRepository`
> trio. No base classes exist — a persistent entity is an ordinary
> `tom_core_server` class marked by those three.

**csra2 — the remaining catalogued gaps.** Four parts the `codespecs_mapping.md`
§4.1 catalogue marks *gap*, each re-verified against the current `tom_core`
before the class was written:

| Class | Part | Purpose | Why the substrate does not cover it |
|-------|------|---------|-------------------------------------|
| `TomLayoutModel` (+ `TomLayoutContainerNode`, `TomLayoutSlotNode`, `TomLayoutOverrideDelta`, `TomLayoutContainerKind`, `TomLayoutDeltaOp`) | CE-LO Layout (`codespecs_mapping.md` §5.2/§5.12/§5.22) | Two-layer layout: a generated `base` tree plus an authored `overrides` layer of id-addressed deltas. `reconcileWarnings()` reports a delta whose target vanished, never drops it. | `tom_flutter_ui`'s `AclComponent` is a rendering leaf holding a live `Widget` — no base/override layering, no delta grammar, no id-addressed placement. |
| `TomMessageKeyRegistry` (+ `TomMessageKey`, `TomMessageRole`, `TomMessageCategory`) | CE-TX Text (`codespecs_mapping.md` §5.8/§5.21) | The closed message-key catalogue. Locale fallback goes to base copy, never the raw key; an uncatalogued key is a spec error; error copy is keyed by its CE-ER code. | `tom_core_kernel`'s `TomTextResourceProvider` is an untyped runtime `Map<String, dynamic>` — it answers "what text is behind this key", not "which keys may exist". |
| `TomRouteRegistry` (+ `TomRouteDefinition`, `TomFormScreenAssignment`, `TomScreenFlowEdge`, `TomScreenPresentation`, `TomFlowOutcome`) | CE-NV Navigation (`codespecs_mapping.md` §5.11) | Route-id registry (uniqueness + dangling-reference checks) and the screen-flow model: form→screen as replace/popup, action targets conditional on outcome. | `tom_flutter_ui`'s `TomPageRoute` is a bare `MaterialPageRoute` subclass with no route id and no registry — the framework assumes uniqueness with nowhere to check it. |
| `TomJobDeclaration` | CE-JB Job (`codespecs_mapping.md` §5.29) | The deployment/ownership envelope around a job: `enabled`, `environments`, `serviceUnitId`, and its CE-DB entity targets as `Type` literals (`readEntities` / `writtenEntities`, with `targetEntities` the union). Its CE-RP report targets ride `@CsJob(targetReports:)` in `tom_code_specs` instead — §5.23 makes the `Cs*Ref` family the annotation *parameter* vocabulary, which is also what keeps this package dependency-free. | `tom_core_kernel`'s scheduling module supplies the entire *runtime* half (`TomJobBase`, `TomJobDefinition`, `TomSchedule`, `TomScheduler`, `TomJobStore`, `TomLeaseLock`, `TomJobDispatcher`) and is reused as-is; what it has no home for is the spec-side decision to deploy the job at all. |

**CE-AC (Trigger) is not a gap.** `codespecs_mapping.md` §4.1 / §5.10 / §5.20
all record "no gap — full action implementation reused": the trigger taxonomy is
a documented classification over the reused `tom_flutter_ui` action classes. Its
closed five-kind vocabulary therefore ships as `TriggerKind` on `@CsTrigger` in
`tom_code_specs`, not as a class here.

**csra3 — CE-UP is single-moded.** `codespecs_mapping.md` §11 splits
configuration and settings into four parts, **one per scope key, each
single-moded**: CE-CF (server/system), CE-CC (client app + machine, no user),
CE-DS (user + device, device-persisted), CE-UP (user, server-persisted). The
scope key alone decides where a value lives, so no part carries a persistence
discriminator — the choice is *which part you use*. `TomUserSettings`
accordingly lost its `local`/`roaming` enum: the `local` arm is CE-DS, which
`codespecs_mapping.md` §4.1 marks *reuse — no new class* and which is therefore
deliberately **not** re-created here.

The same pass closed the second half of the CE-UP gap. `codespecs_mapping.md`
§4.1 names it as "typed user-settings holder **+** server-side per-user
persistence"; only the holder existed. The reused kernel carrier
(`TomGetSettingsMessage` / `TomGetSettingsResult`) is a read-only bootstrap
payload with no write-back path, so a user's chosen preference had nowhere to be
stored — `TomUserSettingsStore` is that seam, keyed by user in every method
because the user key *is* the scope.

**csra7 — CE-NT, promoted out of `codespecs_mapping.md` §4.3.** The
`codespecs_mapping.md` §8.1 authored-input test decides which deferred
candidates can be built at all: CE-NT's SOM section (`NotificationModel`) is a
structured entry list rather than free text, so a generator has something to
read, and the part was promoted. The sibling promotion CE-LG is a *reuse*
verdict — `@CsAudited` marks the framework's own `@TomAudited` — so it needs no
gap class here.

| Class | Part | Purpose | Why the substrate does not cover it |
|-------|------|---------|-------------------------------------|
| `TomNotificationType`, `TomNotificationChannelDeclaration`, `TomNotificationPreferences`, `TomNotificationCatalog` (+ `TomNotificationCategory`, `TomNotificationUrgency`) | CE-NT Notification (`codespecs_mapping.md` §4.3.2) | The *choosing* layer: which notification types exist, which channels each goes out on, and how user preferences narrow that set. `channelsFor` resolves type constraints against preferences (mandatory first); `deliveryChannelsFor` adds the channel's own urgency ceiling. | `tom_core_server`'s `messaging` module (`TomMessage`, `TomMessageChannel`, `TomMessageRouter`, `TomMessageOutbox`) *delivers* — it takes an already-composed message on an already-chosen channel. It is reused as-is; the choosing is what a specification authors. |

Essentiality is a property of the **type** (`isEssential`), not of the
preferences: a type the user cannot configure, or one with a mandatory channel,
survives a blanket opt-out whole. Silencing is therefore all-or-nothing per type
and can only ever reach a non-essential one — never a per-channel narrowing of
an essential type.

**csra8 — CE-RP, promoted out of `codespecs_mapping.md` §4.3.** A report is a
*grouped projection over the domain model, delivered as a rendered artifact*.
The composition hypothesis (CE-API + CE-DB + CE-FM) fails on its first term:
`tom_core_server`'s `TomGroupedSelect` / `TomAggregate` supply the runtime
grammar, but CE-DB's **spec-authorable** surface is row-shaped, so a dimension
and a measure have nowhere to be authored. That gap is what these classes hold.

| Class | Part | Purpose | Why the substrate does not cover it |
|-------|------|---------|-------------------------------------|
| `TomReportDefinition` (+ `TomReportDimension`, `TomReportMeasure`, `TomReportColumn`, `TomReportParameter`, `TomReportChart`, `TomReportValueKind`, `TomReportMeasureFunction`, `TomReportDeliveryChannel`, `TomReportChartKind`) | CE-RP Reporting (`codespecs_mapping.md` §5.28) | The grouped projection a specification authors — dimension by dimension, measure by measure — plus the output columns that display them, the per-execution parameters, and the charts declared over the projection. | `TomGroupedSelect` is a *query*, compiled from an already-decided grouping. Nothing in `tom_core` holds the decision itself, nor the report's identity, delivery channels or authorization key. |
| `TomReportResult` (+ `TomReportResultSection`) | CE-RP Reporting (`codespecs_mapping.md` §5.28) | The **shared** result envelope: sections of columns over a `Stream` of rows, plus the chart declarations and run metadata. | `tom_core_server`'s `TomTabularResult` is server-side, and the envelope's locus is *shared* — the client renders a report too. See below. |

`TomReportResult` deliberately does **not** extend `TomTabularResult`. A shared
type cannot depend on a server type, so the server adapts one way onto the
tabular shape when exporting — the CE-DB entity-placement decision applied again.
The adaptation is honoured in one inherited constraint: rows stay a `Stream`,
because a report exists for results too large to hold inline.

`TomReportMeasureFunction` is 1:1 with `tom_core_server`'s `TomAggregateFunction`
— a measure the query layer cannot compile is a measure that cannot run — and
`COUNT(*)` / `COUNT(DISTINCT c)` are expressed as fields (`columnName`,
`distinct`) rather than as extra members. Three checks run at construction,
because each is a specification defect no generator can repair: a column whose
`sourceKey` names neither a dimension nor a measure, one key claimed by both,
and a chart plotting a column the report does not project.

## Status

csra8. CE-RP's report model added on its promotion out of `codespecs_mapping.md`
§4.3, leaving CE-WF as the sole deferred candidate. Earlier: csra7 CE-NT's
notification model (CE-LG, promoted in the same pass, is reuse and needs no
class); csra3 CE-UP single-moded and its persistence seam added; csra2 the four
remaining catalogued gap classes (CE-LO / CE-TX / CE-NV / CE-JB) with CE-AC
confirmed reuse; csm210-4-1 the `domainEnum` holder with CE-DB confirmed reuse
and the entity-model placement decided (shared shape, server persistence
projection); csm2r7 three gap classes for the four new parts (CE-CL / CE-CC /
CE-UP; CE-AU and CE-CF reuse). Every part the `codespecs_mapping.md` §4.1
catalogue marks *gap* now has its class; later waves add classes only if a
further part is promoted out of `codespecs_mapping.md` §4.3.
