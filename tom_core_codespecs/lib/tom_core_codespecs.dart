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
/// The gap classes are authored by the CodeSpecs waves: csm4 surveys `tom_core`
/// per part (reuse / extend / new-in-codespecs) and the genuine gaps land here.
/// Dependencies on the relevant `tom_core_*` packages are added when the first
/// gap class that needs them is authored.
///
/// **csm2r7 — the four new parts (`codespecs_new_parts_basis.md`).** CE-AU
/// (Authentication) reuses `tom_core_server` `TomAuthenticationService`* and
/// CE-CF (ServerConfiguration) reuses `TomBaseServerConfiguration`, so neither
/// needs a gap class. The three remaining new parts had no `tom_core` holder and
/// land here as concrete classes: [TomClientApplication] (CE-CL),
/// [TomClientConfiguration] (CE-CC), and [TomUserSettings] with
/// [TomUserSettingsPersistence] (CE-UP, the `local`/`roaming` split, §11).
///
/// **csm210-4-1 (wave-2 W10) — CE-EN domain enum.** The csm4 code-basis survey
/// (`codespecs_code_basis.md` §3) flagged CE-EN as a *gap*: `tom_core` has only
/// mechanical enums, no domain-enum framework. [TomDomainEnum] (+
/// [TomDomainEnumValue]) is that thin holder — the class a `@CsEnum` CodeSpec is
/// built on. CE-DB stays a *reuse* verdict: `@CsTable`/`@CsColumn`/`@CsRepository`
/// are built directly on `tom_core_server` persistence classes, so CE-DB needs no
/// gap class here.
library;

export 'src/client_application.dart';
export 'src/client_configuration.dart';
export 'src/domain_enum.dart';
export 'src/user_settings.dart';
