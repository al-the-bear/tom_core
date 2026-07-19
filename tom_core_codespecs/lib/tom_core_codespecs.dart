/// CodeSpecs-only gap-filler for `tom_core`.
///
/// **Core principle (csm1 / `codespecs_mapping.md` §1.1):** every actual class a
/// CodeSpec instantiates must be a `tom_core`-family class — one of the five
/// packages `tom_core_kernel`, `tom_core_flutter`, `tom_core_server`,
/// `tom_core_d4rt`, and `tom_flutter_ui` (the fifth basis, dsb6 / §1.1b). Prefer
/// reusing an existing `tom_core` class directly; only the **concrete** gap
/// classes `tom_core` genuinely lacks live here — **never abstract `Cs*` bases**
/// (the framework carries annotations only, §0) — keeping `tom_core` clean of
/// CodeSpecs-only concerns.
///
/// This package is an intentional **empty stub** at scaffold time (csm3). The
/// gap classes are authored by later CodeSpecs waves: csm4 surveys `tom_core`
/// per part (reuse / extend / new-in-codespecs) and the genuine gaps land here.
/// Dependencies on the relevant `tom_core_*` packages are added when the first
/// gap class that needs them is authored.
library;
