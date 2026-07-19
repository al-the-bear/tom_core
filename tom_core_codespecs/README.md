# tom_core_codespecs

CodeSpecs-only **gap-filler** for `tom_core`.

**Core principle** (csm1 / `_ai/quests/tom_specs/codespecs_mapping.md` §1.1):
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
`_ai/quests/tom_specs/codespecs_new_parts_basis.md`). CE-AU (Authentication) and
CE-CF (ServerConfiguration) reuse existing `tom_core` classes, so they need no
gap class. The three remaining new parts had no `tom_core` holder:

| Class | Part | Purpose |
|-------|------|---------|
| `TomClientApplication` | CE-CL Client | Client-application descriptor (id, platforms, entry route, server URL). |
| `TomClientConfiguration` | CE-CC ClientConfiguration | Per-machine client config holder — does **not** follow the user. |
| `TomUserSettings` + `TomUserSettingsPersistence` | CE-UP UserSettings | User-settings holder with the `local` (machine-bound) / `roaming` (server-persisted, follows the user) split (§11). |

**csm210-4-1 (wave-2 W10) — CE-DB / CE-EN** (survey:
`_ai/quests/tom_specs/codespecs_code_basis.md` §3). CE-DB is a *reuse* verdict —
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

> Naming note: the csm4 survey wrote "CsDbTable"; the Band R annotations-only
> catalogue realises that as the `@CsTable` (CE-TB) + `@CsColumn` (CE-CO) pair.
> No base classes exist — a persistent entity is an ordinary `tom_core_server`
> class marked by `@CsTable`/`@CsColumn`/`@CsRepository`.

## Status

csm210-4-1 (wave-2 W10). CE-EN domain-enum gap class added; CE-DB confirmed reuse
with the entity-model placement decided (shared shape, server persistence
projection). Earlier: csm2r7 three gap classes for the four new parts (CE-CL /
CE-CC / CE-UP; CE-AU and CE-CF reuse). Later waves add gap classes for the
remaining original parts where csm4 flagged them (e.g. layout node model).
