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

## Status

csm2r7. Three concrete gap classes for the four new parts (CE-CL / CE-CC / CE-UP;
CE-AU and CE-CF reuse). Later waves add gap classes for the original parts where
csm4 flagged them (e.g. domain-enum marker, layout node model).
