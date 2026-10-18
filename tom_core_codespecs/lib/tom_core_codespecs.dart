/// CodeSpecs-only gap-filler for `tom_core`.
///
/// **Core principle (`codespecs_mapping.md` §1.1):** every actual class
/// a CodeSpec instantiates must be a `tom_core`-family class — one of the four
/// packages `tom_core_kernel`, `tom_core_flutter`, `tom_core_server` and
/// `tom_flutter_ui` (the fourth being the basis for the UI parts,
/// `codespecs_mapping.md` §1.1 pillar (b)). Prefer reusing an existing
/// `tom_core` class directly; only the **concrete** gap classes `tom_core`
/// genuinely lacks live here — **never abstract `Cs*` bases** (the framework
/// carries annotations only, `codespecs_mapping.md` §1.1) — keeping
/// `tom_core` clean of CodeSpecs-only concerns.
///
/// The gap classes are what survives a per-part survey of `tom_core` (reuse /
/// extend / new-in-codespecs): only the genuine gaps land here.
///
/// **The package is dependency-free, and that is an invariant.**
/// `pubspec.yaml` declares `dependencies: {}` and nothing under `lib/` imports
/// anything beyond `dart:core`. The property is load-bearing rather than
/// incidental: it is why [TomReportResult] does not extend `tom_core_server`'s
/// `TomTabularResult` (below), and why a job's CE-RP targets ride
/// `@CsJob(targetReports:)` in `tom_code_specs` instead of [TomJobDeclaration]
/// itself. A candidate gap class that would need a `tom_core_*` type is
/// therefore not a gap class — it belongs in the package whose type it needs,
/// since taking the dependency here would retract both of those decisions.
///
/// **The four new parts (`codespecs_mapping.md` §1.1 pillar (b)).**
/// CE-AU (Authentication) reuses `tom_core_server`
/// `TomAuthenticationService`* and CE-CF (ServerConfiguration) reuses
/// `TomBaseServerConfiguration`, so neither needs a gap class. CE-CC
/// (ClientConfiguration) reuses `tom_core_flutter`'s
/// `TomBaseClientConfiguration` / `TomSetting<T>` /
/// `TomClientConfigurationStore` (`codespecs_mapping.md` §4.1/§5.16), which is
/// the (client app, machine) holder with no user in the key — so it needs no
/// gap class either. Of the four, only CE-CL had no `tom_core` holder, and it
/// lands here as [TomClientApplication].
///
/// **CE-UP is not a gap either — it is full reuse of the preferences plane.**
/// A user setting needs no holder here at all: every part of its surface
/// resolves onto a shipped `tom_core` class or onto the annotated member
/// itself.
///
/// | CE-UP surface | Where it lives |
/// |---------------|----------------|
/// | the setting's key | `@CsUserSetting('user.preferredLanguage')`'s own argument, against `TomUserPreferenceKeys` (`tom_core_kernel`) |
/// | its type and default | **the annotated member** — `String preferredLanguage = 'de'` (`codespecs_mapping.md` §5.16), exactly as a domain enum's default belongs to the member that has one |
/// | the user's persisted value | `TomUserPreferences` (`tom_core_server`) over `TomUserPreferenceRepository`, scoped by `@TomDbScope(field: 'principal_id')` |
/// | the wire | `tomUserPreferencesApi`'s four endpoints and `TomUserPreferenceDto` (`tom_core_kernel`) |
/// | `codespecs_mapping.md` §5.16's persisted-value → default order | `TomUserPreferences.getOr(key, <the member's initialiser>)` |
/// | the setting's display name | CE-TX copy in the message-key registry (`codespecs_mapping.md` §5.21, §1.2 consequence 1) — a label has one home |
///
/// A holder here would therefore hold nothing that is not already held, and a
/// persistence seam here would be strictly worse than the shipped one — an
/// in-memory map with no scope and no rows, standing in front of a persistent,
/// principal-scoped service. Note that the setting's *scope* is what separates
/// CE-UP from its three siblings: `(user)` alone, so it travels with the
/// account across every device, which is exactly what `TomUserPreferences`
/// stores and what `tom_core_flutter`'s device store deliberately does not.
///
/// **CE-DB and domain enums are both *not* gaps.** CE-DB is a reuse verdict —
/// `@CsTable`/`@CsColumn`/`@CsRepository` are built directly on
/// `tom_core_server` persistence classes. A **domain enum needs no holder at
/// all**: `codespecs_mapping.md` §4.1 realises it as a plain Dart `enum`, and
/// every attribute a holder would have carried belongs elsewhere — the value
/// token is the enum constant's own identifier, the value label is CE-TX copy
/// in the message-key registry (`codespecs_mapping.md` §5.21, §1.2
/// consequence 1), the description is
/// the generated doc comment (`codespecs_derivation_contract.md` §3.1.1), and a
/// default belongs to the enum-typed member rather than the enum. A holder
/// would therefore hold nothing, and it would give labels a second home — which
/// the closed-vocabulary rule forbids.
///
/// **The remaining catalogued gaps.** The `codespecs_mapping.md` §4.1
/// catalogue marks four further parts *gap*, and each was cross-checked
/// against the current `tom_core`: [TomLayoutModel] (CE-LO,
/// `codespecs_mapping.md` §5.2/§5.12/§5.22 — the base/override two-layer model
/// `tom_flutter_ui`'s rendering-leaf `AclComponent` has no equivalent of),
/// [TomMessageKeyRegistry] (CE-TX, `codespecs_mapping.md` §5.8/§5.21 — the
/// closed key catalogue behind `TomTextResourceProvider`'s untyped runtime
/// store), [TomRouteRegistry] (CE-NV, `codespecs_mapping.md` §5.11 — the
/// route-id registry and screen-flow model `TomPageRoute` assumes but cannot
/// check), and [TomJobDeclaration] (CE-JB, `codespecs_mapping.md` §5.29 — the
/// deployment/ownership envelope around the now-complete `tom_core_kernel`
/// scheduling runtime). CE-AC (Trigger) is **not** a gap:
/// `codespecs_mapping.md` §4.1/§5.10/§5.20 record "no gap — full action
/// implementation reused", and its closed trigger vocabulary is delivered as
/// `CsTriggerKind` on `@CsTrigger` in `tom_code_specs` instead.
///
/// **CE-NT's promotion out of the deferred candidates.** `tom_core_server`'s
/// `messaging` module delivers a composed message on a named channel, but takes
/// the channel as already chosen. The layer that chooses — notification types,
/// their channels, and the user preferences that narrow them — is the gap:
/// [TomNotificationType], [TomNotificationChannelDeclaration],
/// [TomNotificationPreferences] and [TomNotificationCatalog]. CE-LG is **not** a
/// gap alongside it: `tom_core_server`'s `audit` module already carries the
/// declaration (`TomAudited`) and the trail, so CE-LG is pure reuse.
///
/// **CE-RP's promotion out of the deferred candidates.** A report is a grouped
/// projection over the domain model — dimensions, measures and the output
/// columns that display them — and no active part has an authoring home for
/// that shape: `tom_core_server`'s `TomGroupedSelect` supplies the runtime
/// grammar, but CE-DB's *authorable* surface is row-shaped. [TomReportDefinition]
/// (with [TomReportDimension], [TomReportMeasure], [TomReportColumn],
/// [TomReportParameter] and [TomReportChart]) is that holder, and
/// [TomReportResult] is the **shared** result envelope its two consumers need.
/// The envelope deliberately does **not** extend `tom_core_server`'s
/// `TomTabularResult`: the envelope's locus is *shared* (the client reads it
/// too) and this package is dependency-free, so the server adapts one way onto
/// the tabular shape — the same placement decision CE-DB records for entities.
/// **CE-API's second binding (`codespecs_mapping.md` §5.30).** CE-API itself is
/// reuse — `TomApiEndpoint` and the `TomEndpoint` pipeline — but an endpoint
/// *is* its HTTP shape, so `tom_core` cannot bind an already-named operation a
/// second time. [TomOperationBinding] (with [TomBindingParameter],
/// [TomBindingSource] and [TomBindingErrorFormat]) holds that second shape
/// until `tom_core` ships a generic protocol capability over named operations,
/// at which point it moves there.
/// @docImport 'src/client_application.dart';
/// @docImport 'src/job_declaration.dart';
/// @docImport 'src/layout_node.dart';
/// @docImport 'src/message_key.dart';
/// @docImport 'src/notification_model.dart';
/// @docImport 'src/operation_binding.dart';
/// @docImport 'src/report_model.dart';
/// @docImport 'src/route_flow.dart';
library;

export 'src/client_application.dart';
export 'src/job_declaration.dart';
export 'src/layout_node.dart';
export 'src/message_key.dart';
export 'src/notification_model.dart';
export 'src/operation_binding.dart';
export 'src/report_model.dart';
export 'src/route_flow.dart';
