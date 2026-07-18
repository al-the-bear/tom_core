# tom_core_codespecs

CodeSpecs-only **gap-filler** for `tom_core`.

**Core principle** (csm1 / `_ai/quests/tom_specs/codespecs_mapping.md` §1.1):
every actual class a CodeSpec instantiates must be a `tom_core` class
(`tom_core_kernel`, `tom_core_flutter`, `tom_core_server`, `tom_core_d4rt`).
Structures that CodeSpecs needs but that are **not** mandatory for a general
`tom_core` project belong here — so `tom_core` stays free of CodeSpecs-only
concerns.

## Status

Intentional **empty stub** (csm3). The gap classes are added by later CodeSpecs
waves: csm4 surveys `tom_core` per part (reuse / extend / new-in-codespecs) and
the genuine gaps land in this package. Dependencies on the relevant `tom_core_*`
packages are added when the first gap class that needs them is authored.
