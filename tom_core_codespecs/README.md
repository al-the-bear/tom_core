# tom_core_codespecs

CodeSpecs-only **gap-filler** for `tom_core`.

**Core principle** (csm1 / `../../ai_build/tom_specs_model/doc/codespecs_mapping.md` §1.1):
every actual class a CodeSpec instantiates must be a `tom_core`-family class —
one of the five packages `tom_core_kernel`, `tom_core_flutter`,
`tom_core_server`, `tom_core_d4rt`, and `tom_flutter_ui` (the fifth basis,
dsb6 / §1.1b). Prefer reusing an existing `tom_core` class directly; only the
**concrete** gap classes `tom_core` genuinely lacks belong here — **never
abstract `Cs*` bases** (the framework carries annotations only, §0) — so
`tom_core` stays free of CodeSpecs-only concerns.

## Gap classes

The gap classes are added by the CodeSpecs waves: each surveys `tom_core` per
part (reuse / extend / new-in-codespecs) and the genuine gaps land in this
package as concrete classes.

**csm2r7 — the four new parts** (survey:
`../../ai_build/tom_specs_model/doc/codespecs_mapping.md`). CE-AU (Authentication) and
CE-CF (ServerConfiguration) reuse existing `tom_core` classes, so they need no
gap class. The three remaining new parts had no `tom_core` holder:

| Class | Part | Purpose |
|-------|------|---------|
| `TomClientApplication` | CE-CL Client | Client-application descriptor (id, platforms, entry route, server URL). |
| `TomClientConfiguration` | CE-CC ClientConfiguration | Per-machine client config holder — does **not** follow the user. |
| `TomUserSettings` + `TomUserSettingsPersistence` | CE-UP UserSettings | User-settings holder with the `local` (machine-bound) / `roaming` (server-persisted, follows the user) split (§11). |

**csm210-4-1 (wave-2 W10) — CE-DB / CE-EN** (survey:
`../../ai_build/tom_specs_model/doc/codespecs_mapping.md` §3). CE-DB is a *reuse* verdict —
`@CsTable`/`@CsColumn`/`@CsRepository` are built directly on `tom_core_server`
persistence classes (`@TomDbTable`, `@TomDbColumn`, `@TomEntityId`, `@TomDbScope`,
`TomRepository<T,K>`, `TomSqlDatasourceRepository`, `query_builder`,
`TomTransaction`), so CE-DB needs no gap class. CE-EN is a *gap*:

| Class | Part | Purpose |
|-------|------|---------|
| `TomDomainEnum` + `TomDomainEnumValue` | CE-EN Enumeration | Domain-enum holder (a business closed value set) a `@CsEnum` is built on — `tom_core_kernel` has only mechanical enums, no domain-enum framework. Stable `valueId` token separated from display `label`. |

### Entity-model placement (CE-DB) — decided

A CodeSpecs data entity is referenced by both the client (as DTO/view) and the
server (as persistence). The entity's **field shape is authored once in the
`shared` project** of the three-project output trio (§4.2) as the canonical
entity; the server-only `@CsTable`/`@CsColumn`/`@CsRepository` persistence
projection and the client-only DTO/view both derive from that shared shape. This
keeps the client free of any dependency on a server-authored type and mirrors the
CE-UP `roaming` pattern (a shared shape with a server-side persistence facet).
The persistence markers themselves remain **server-side** parts
(`service_annotations.dart`).

> Naming note: an earlier survey wrote "CsDbTable"; the annotations-only
> catalogue realises CE-DB as the `@CsTable` + `@CsColumn` + `@CsRepository`
> trio. No base classes exist — a persistent entity is an ordinary
> `tom_core_server` class marked by those three.

**csra2 — the remaining catalogued gaps.** Four parts the §4.1 catalogue marks
*gap*, each re-verified against the current `tom_core` before the class was
written:

| Class | Part | Purpose | Why the substrate does not cover it |
|-------|------|---------|-------------------------------------|
| `TomLayoutModel` (+ `TomLayoutContainerNode`, `TomLayoutSlotNode`, `TomLayoutOverrideDelta`, `TomLayoutContainerKind`, `TomLayoutDeltaOp`) | CE-LO Layout (§5.2/§5.12/§5.22) | Two-layer layout: a generated `base` tree plus an authored `overrides` layer of id-addressed deltas. `reconcileWarnings()` reports a delta whose target vanished, never drops it. | `tom_flutter_ui`'s `AclComponent` is a rendering leaf holding a live `Widget` — no base/override layering, no delta grammar, no id-addressed placement. |
| `TomMessageKeyRegistry` (+ `TomMessageKey`, `TomMessageRole`, `TomMessageCategory`) | CE-TX Text (§5.8/§5.21) | The closed message-key catalogue. Locale fallback goes to base copy, never the raw key; an uncatalogued key is a spec error; error copy is keyed by its CE-ER code. | `tom_core_kernel`'s `TomTextResourceProvider` is an untyped runtime `Map<String, dynamic>` — it answers "what text is behind this key", not "which keys may exist". |
| `TomRouteRegistry` (+ `TomRouteDefinition`, `TomFormScreenAssignment`, `TomScreenFlowEdge`, `TomScreenPresentation`, `TomFlowOutcome`) | CE-NV Navigation (§5.11) | Route-id registry (uniqueness + dangling-reference checks) and the screen-flow model: form→screen as replace/popup, action targets conditional on outcome. | `tom_flutter_ui`'s `TomPageRoute` is a bare `MaterialPageRoute` subclass with no route id and no registry — the framework assumes uniqueness with nowhere to check it. |
| `TomJobDeclaration` | CE-JB Job (§5.29) | The deployment/ownership envelope around a job: `enabled`, `environments`, `serviceUnitId`, `targetRefs`. | `tom_core_kernel`'s scheduling module now supplies the entire *runtime* half (`TomJobDefinition`, `TomSchedule`, `TomScheduler`, `TomJobStore`, `TomLeaseLock`, `TomJobDispatcher`) and is reused as-is; what it has no home for is the spec-side decision to deploy the job at all. |

**CE-AC (Trigger) is not a gap.** §4.1 / §5.10 / §5.20 all record "no gap — full
action implementation reused": the trigger taxonomy is a documented
classification over the reused `tom_flutter_ui` action classes. Its closed
five-kind vocabulary therefore ships as `TriggerKind` on `@CsTrigger` in
`tom_code_specs`, not as a class here.

## Status

csra2. The four remaining catalogued gap classes added (CE-LO / CE-TX / CE-NV /
CE-JB), CE-AC confirmed reuse. Earlier: csm210-4-1 CE-EN domain enum with CE-DB
confirmed reuse and the entity-model placement decided (shared shape, server
persistence projection); csm2r7 three gap classes for the four new parts (CE-CL /
CE-CC / CE-UP; CE-AU and CE-CF reuse). Every part the §4.1 catalogue marks *gap*
now has its class; later waves add classes only if a new part is promoted out of
§4.3.
