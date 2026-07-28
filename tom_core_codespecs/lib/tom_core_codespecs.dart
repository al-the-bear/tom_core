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
/// **csm2r7 — the four new parts (`codespecs_mapping.md` §1.1b).** CE-AU
/// (Authentication) reuses `tom_core_server` `TomAuthenticationService`* and
/// CE-CF (ServerConfiguration) reuses `TomBaseServerConfiguration`, so neither
/// needs a gap class. The three remaining new parts had no `tom_core` holder and
/// land here as concrete classes: [TomClientApplication] (CE-CL),
/// [TomClientConfiguration] (CE-CC), and [TomUserSettings] (CE-UP).
///
/// **csm210-4-1 (wave-2 W10) — CE-EN domain enum.** The csm4 code-basis survey
/// (`codespecs_mapping.md` §5) flagged CE-EN as a *gap*: `tom_core` has only
/// mechanical enums, no domain-enum framework. [TomDomainEnum] (+
/// [TomDomainEnumValue]) is that thin holder — the class a `@CsEnum` CodeSpec is
/// built on. CE-DB stays a *reuse* verdict: `@CsTable`/`@CsColumn`/`@CsRepository`
/// are built directly on `tom_core_server` persistence classes, so CE-DB needs no
/// gap class here.
///
/// **csra2 — the remaining catalogued gaps.** The §4.1 catalogue marks four
/// further parts *gap*, and the csra2 cross-check confirmed each against the
/// current `tom_core`: [TomLayoutModel] (CE-LO, §5.2/§5.12/§5.22 — the
/// base/override two-layer model `tom_flutter_ui`'s rendering-leaf
/// `AclComponent` has no equivalent of), [TomMessageKeyRegistry] (CE-TX,
/// §5.8/§5.21 — the closed key catalogue behind `TomTextResourceProvider`'s
/// untyped runtime store), [TomRouteRegistry] (CE-NV, §5.11 — the route-id
/// registry and screen-flow model `TomPageRoute` assumes but cannot check), and
/// [TomJobDeclaration] (CE-JB, §5.29 — the deployment/ownership envelope around
/// the now-complete `tom_core_kernel` scheduling runtime). CE-AC (Trigger) is
/// **not** a gap: §4.1/§5.10/§5.20 record "no gap — full action implementation
/// reused", and its closed trigger vocabulary is delivered as `TriggerKind` on
/// `@CsTrigger` in `tom_code_specs` instead.
library;

export 'src/client_application.dart';
export 'src/client_configuration.dart';
export 'src/domain_enum.dart';
export 'src/job_declaration.dart';
export 'src/layout_node.dart';
export 'src/message_key.dart';
export 'src/route_flow.dart';
export 'src/user_settings.dart';
