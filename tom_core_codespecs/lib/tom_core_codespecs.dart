/// CodeSpecs-only gap-filler for `tom_core`.
///
/// **Core principle (csm1 / `codespecs_mapping.md` §1.1):** every actual class a
/// CodeSpec instantiates must be a `tom_core` class (`tom_core_kernel`,
/// `tom_core_flutter`, `tom_core_server`, `tom_core_d4rt`). Structures that
/// CodeSpecs needs but that are **not** mandatory for a general `tom_core`
/// project live here instead — keeping `tom_core` clean of CodeSpecs-only
/// concerns.
///
/// This package is an intentional **empty stub** at scaffold time (csm3). The
/// gap classes are authored by later CodeSpecs waves: csm4 surveys `tom_core`
/// per part (reuse / extend / new-in-codespecs) and the genuine gaps land here.
/// Dependencies on the relevant `tom_core_*` packages are added when the first
/// gap class that needs them is authored.
library;
