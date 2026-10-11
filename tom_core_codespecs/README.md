# tom_core_codespecs — the CodeSpecs gap classes for `tom_core`

> **Cross-references.**
> [`doc/codespecs_mapping.md`](doc/codespecs_mapping.md)
> owns the **parts catalogue** (`codespecs_mapping.md` §4.1), the
> **five-package `tom_core`-family basis** every CodeSpec is built on
> (`codespecs_mapping.md` §1.1) and the per-part **spec-authorable attribute
> surfaces** (`codespecs_mapping.md` §5).
> [`doc/codespecs_derivation_contract.md`](doc/codespecs_derivation_contract.md)
> owns **what code each marker produces** and which superclass it is built on.
> This README is the inventory of *what this package ships and why each class
> exists*; those documents own *which specification section produces it* and
> *what the generator must emit*.

CodeSpecs-only gap-filler for tom_core — structures needed by CodeSpecs but not
mandatory for a general tom_core project.

## Where this fits

**TomSpecs** builds software from structured specification documents in phases;
**Phase 4 — CodeSpecs** turns those documents into a skeletal, compilable Dart
application. A rule governs that skeleton: every class it instantiates must be a
`tom_core`-family class — one of the four packages `tom_core_kernel`,
`tom_core_flutter`, `tom_core_server` and `tom_flutter_ui` (the fourth being
the basis for the UI parts,
[`codespecs_mapping.md`](doc/codespecs_mapping.md)
§1.1 pillar (b)). Generated code therefore runs on the framework a hand-written
Tom application runs on, rather than on a parallel one invented for generation.

`tom_core_codespecs` exists because that rule occasionally has nowhere to land.
For a handful of parts the framework genuinely has no holder — it has the
*runtime* half and not the *authoring* half — and without this package the
choice would be to weaken the rule or to push CodeSpecs-only concerns into
`tom_core` itself. This package is the third option: the concrete classes
`tom_core` lacks, kept outside it, so `tom_core` stays free of concerns only a
generator has.

## Overview

Every part of the
[`codespecs_mapping.md`](doc/codespecs_mapping.md)
§4.1 catalogue is surveyed against `tom_core` with one of three verdicts —
**reuse** (build on a shipped class), **extend**, or **new-in-codespecs**. Only
the third lands here, as a **concrete** class; never an abstract `Cs*` base,
because the framework in
[`tom_code_specs`](../../ai_build/tom_code_specs) carries annotations only
(`codespecs_mapping.md` §1.1). Seven parts survive that survey: CE-CL, CE-LO,
CE-TX, CE-NV, CE-JB, CE-NT and CE-RP.

> **The package is dependency-free, and that is an invariant.** `pubspec.yaml`
> declares `dependencies: {}` and nothing under `lib/` carries an import
> directive at all. It is load-bearing rather than incidental: it is why
> `TomReportResult` does not extend `tom_core_server`'s `TomTabularResult`, and
> why a job's CE-RP targets ride `@CsJob(targetReports:)` in `tom_code_specs`
> instead of on `TomJobDeclaration`. A candidate gap class that would need a
> `tom_core_*` type is therefore **not** a gap class — it belongs in the package
> whose type it needs. Both halves are checked by
> `test/gap_class_inventory_test.dart`, so a single added import fails the suite
> rather than quietly retracting two decisions.

## Installation

```yaml
dependencies:
  tom_core_codespecs: ^0.11.2
```

or

```bash
dart pub add tom_core_codespecs
```

```dart
import 'package:tom_core_codespecs/tom_core_codespecs.dart';
```

## Features

One gap-class subject per file, one file per part. The inventory is pinned to
its justifications by `test/gap_class_inventory_test.dart`: adding or removing a
file means a part changed its reuse verdict, and that has to be stated in the
test next to the part it claims.

### The client-application descriptor

| Class | Part | Purpose |
|-------|------|---------|
| `TomClientApplication` | CE-CL Client | Client-application descriptor (id, platforms, entry route, screens, server URL). |

`tom_core` has no client-application *descriptor* root:
`TomAuthenticationData` carries a `client` id string and
`TomClientRemoteContext` models a live connection, but neither names the client
application as a first-class, spec-authorable unit.

### The catalogued gaps

Four parts the
[`codespecs_mapping.md`](doc/codespecs_mapping.md)
§4.1 catalogue marks *gap*, each verified against `tom_core` before the class
was written:

| Class | Part | Purpose | Why the substrate does not cover it |
|-------|------|---------|-------------------------------------|
| `TomLayoutModel` (+ `TomLayoutNode` and its two subtypes `TomLayoutContainerNode` and `TomLayoutSlotNode`, `TomLayoutOverrideDelta`, `TomLayoutContainerKind`, `TomLayoutDeltaOp`) | CE-LO Layout (`codespecs_mapping.md` §5.2/§5.12/§5.22) | Two-layer layout: a generated `base` tree plus an authored `overrides` layer of id-addressed deltas. `reconcileWarnings()` reports a delta whose target vanished **or now names the wrong kind of node**, never drops it. | `tom_flutter_ui`'s `AclComponent` is a rendering leaf holding a live `Widget` — no base/override layering, no delta grammar, no id-addressed placement. |
| `TomMessageKeyRegistry` (+ `TomMessageKey`, `TomMessageRole`, `TomMessageCategory`) | CE-TX Text (`codespecs_mapping.md` §5.8/§5.21) | The closed message-key catalogue. Locale fallback goes to base copy, never the raw key; an uncatalogued key is a spec error; error copy is keyed by its CE-ER code. | `tom_core_kernel`'s `TomTextResourceProvider` is an untyped runtime `Map<String, dynamic>` — it answers "what text is behind this key", not "which keys may exist". |
| `TomRouteRegistry` (+ `TomRouteDefinition`, `TomFormScreenAssignment`, `TomScreenFlowEdge`, `TomScreenPresentation`, `TomFlowOutcome`) | CE-NV Navigation (`codespecs_mapping.md` §5.11) | Route-id registry (uniqueness + dangling-reference checks) and the screen-flow model: form→screen as replace/popup, action targets conditional on outcome. | `tom_flutter_ui`'s `TomPageRoute` is a bare `MaterialPageRoute` subclass with no route id and no registry — the framework assumes uniqueness with nowhere to check it. |
| `TomJobDeclaration` | CE-JB Job (`codespecs_mapping.md` §5.29) | The deployment/ownership envelope around a job: `enabled`, `environments`, `serviceUnitId`, and its CE-DB entity targets as `Type` literals (`readEntities` / `writtenEntities`, with `targetEntities` the union). Its CE-RP report targets ride `@CsJob(targetReports:)` in `tom_code_specs` instead — `codespecs_mapping.md` §5.23 makes the `Cs*Ref` family the annotation *parameter* vocabulary, which is also what keeps this package dependency-free. | `tom_core_kernel`'s scheduling module supplies the entire *runtime* half (`TomJobBase`, `TomJobDefinition`, `TomSchedule`, `TomScheduler`, `TomJobStore`, `TomLeaseLock`, `TomJobDispatcher`) and is reused as-is; what it has no home for is the spec-side decision to deploy the job at all. |

### The two promoted parts

Both were
[`codespecs_mapping.md`](doc/codespecs_mapping.md)
§4.3 deferred candidates. The `codespecs_mapping.md` §8.1 authored-input test
decides which of those can be built at all — a candidate whose SOM section is
free text gives a generator nothing to read.

| Class | Part | Purpose | Why the substrate does not cover it |
|-------|------|---------|-------------------------------------|
| `TomNotificationType`, `TomNotificationChannelDeclaration`, `TomNotificationPreferences`, `TomNotificationCatalog` (+ `TomNotificationCategory`, `TomNotificationUrgency`) | CE-NT Notification (`codespecs_mapping.md` §4.3.2) | The *choosing* layer: which notification types exist, which channels each goes out on, and how user preferences narrow that set. `channelsFor` resolves type constraints against preferences (mandatory first); `deliveryChannelsFor` adds the channel's own urgency ceiling. | `tom_core_server`'s `messaging` module (`TomMessage`, `TomMessageChannel`, `TomMessageRouter`, `TomMessageOutbox`) *delivers* — it takes an already-composed message on an already-chosen channel. It is reused as-is; the choosing is what a specification authors. |
| `TomReportDefinition` (+ `TomReportDimension`, `TomReportMeasure`, `TomReportColumn`, `TomReportParameter`, `TomReportChart`, `TomReportValueKind`, `TomReportMeasureFunction`, `TomReportDeliveryChannel`, `TomReportChartKind`) | CE-RP Reporting (`codespecs_mapping.md` §5.28) | The grouped projection a specification authors — dimension by dimension, measure by measure — plus the output columns that display them, the per-execution parameters, and the charts declared over the projection. | `TomGroupedSelect` is a *query*, compiled from an already-decided grouping. Nothing in `tom_core` holds the decision itself, nor the report's identity or delivery channels. |
| `TomReportResult` (+ `TomReportResultSection`) | CE-RP Reporting (`codespecs_mapping.md` §5.28) | The **shared** result envelope: sections of columns over a `Stream` of rows, plus the chart declarations and run metadata. | `tom_core_server`'s `TomTabularResult` is server-side, and the envelope's locus is *shared* — the client renders a report too. |

CE-LG was promoted alongside CE-NT but is a *reuse* verdict — `@CsAudited`
marks the framework's own `@TomAudited` — so it needs no gap class here.

## Quick start

A gap class is an ordinary Dart class with no framework around it. The CE-TX
catalogue is the smallest one that shows why the part is a gap at all: it
answers *which keys may exist*, which the runtime lookup store cannot.

```dart complete
// dart run example.dart
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final texts = TomMessageKeyRegistry(baseLocale: 'en')
    ..register(
      TomMessageKey(
        key: 'app.error.amount.tooLarge',
        baseCopy: 'Amount must not exceed {max}.',
        role: TomMessageRole.error,
        category: TomMessageCategory.errorCopy,
        errorCode: 'AMOUNT_TOO_LARGE',
        parameters: ['max'],
        localeCopy: {'de': 'Betrag darf {max} nicht überschreiten.'},
      ),
    );

  print(texts.resolve('app.error.amount.tooLarge', 'de'));
  // Betrag darf {max} nicht überschreiten.

  // A locale with no translation falls back to base copy — never to the key.
  print(texts.resolve('app.error.amount.tooLarge', 'fr'));
  // Amount must not exceed {max}.

  print(texts.forErrorCode('AMOUNT_TOO_LARGE')?.key);
  // app.error.amount.tooLarge

  print(texts.hasKey('app.error.unlisted'));
  // false — and resolving it throws, because the catalogue is closed
}
```

## Usage

### Deciding whether something belongs here

The question is not "does CodeSpecs need this" but **"does `tom_core` already
hold it"**. Four verdicts recur, and each has a settled answer:

| Verdict | What it means | Example |
|---------|---------------|---------|
| **reuse** | A shipped `tom_core` class is the holder. | CE-AU on `TomAuthenticationService`, CE-CF on `TomBaseServerConfiguration` |
| **reuse via annotation** | The part is markers over shipped classes; nothing to hold. | CE-DB — `@CsTable`/`@CsColumn`/`@CsRepository` over `tom_core_server` persistence |
| **no holder needed** | Every attribute lives on the annotated member, an annotation argument, or another part. | CE-UP, domain enums |
| **gap** | Nothing holds it. A concrete class lands here. | The seven parts above |

A candidate that would need to import a `tom_core_*` type fails the
dependency-free invariant and is not a gap class at all — it belongs in the
package whose type it needs.

### The reuse verdicts worth stating explicitly

**CE-CC (ClientConfiguration).** `tom_core_flutter`'s
`TomBaseClientConfiguration` / `TomSetting<T>` / `TomClientConfigurationStore`
is the (client app, machine) holder — typed declaration through
`declareSettings()`, baselines resolved from `TomConfigResourceProvider`,
overrides persisted and *only* overrides, and observation both per field and
holder-wide — with **no user in the key**, which is the whole CE-CC
discriminator (`codespecs_mapping.md` §4.1, §5.16, §11). This is the drift the
inventory test was introduced to close: a `TomClientConfiguration` was still
exported here after `TomBaseClientConfiguration` landed in `tom_core_flutter`.

**CE-DB (Data).** A *reuse* verdict — the markers are built directly on
`tom_core_server` persistence classes (`@TomDbTable`, `@TomDbColumn`,
`@TomEntityId`, `@TomDbScope`, `TomRepository<T,K>`,
`TomSqlDatasourceRepository`, `query_builder`, `TomTransaction`).

**Domain enums.** `codespecs_mapping.md` §4.1 realises the `domainEnum` member
kind as a **plain Dart `enum`**, so there is no class to build on and none to
supply. A domain enum has no authored attributes of its own to hold:

| Would-be attribute | Where it actually lives |
|--------------------|-------------------------|
| value token (`valueId`) | the enum constant's own identifier — no second string to drift from the name |
| value label | CE-TX copy in the message-key registry, like every other label (`codespecs_mapping.md` §1.2 consequence 1, `codespecs_mapping.md` §5.21) |
| description | the doc comment the generator writes above the enum and each constant (`codespecs_derivation_contract.md` §3.1.1) |
| default value | the enum-typed *member* that has one (a CE-DB column, a CE-CF/CE-CC/CE-DS/CE-UP setting, a CE-ST field) — two members of the same type may default differently |

A holder would hold nothing, and it would give value labels a **second** home,
which the closed-vocabulary rule forbids.

**CE-AC (Trigger).** `codespecs_mapping.md` §4.1 / §5.10 / §5.20 all record "no
gap — full action implementation reused": the trigger taxonomy is a documented
classification over the reused `tom_flutter_ui` action classes. Its closed
five-kind vocabulary therefore ships as `CsTriggerKind` on `@CsTrigger` in
[`tom_code_specs`](../../ai_build/tom_code_specs), not as a class here.

**CE-UP (UserSetting).** `codespecs_mapping.md` §11 splits configuration and
settings into four parts, **one per scope key, each single-moded**: CE-CF
(server/system), CE-CC (client app + machine, no user), CE-DS (user + device,
device-persisted), CE-UP (user, server-persisted). The scope key alone decides
where a value lives, so no part carries a persistence discriminator — the choice
is *which part you use*. A `local`/`roaming` mode on a CE-UP class would be a
second way to say what the part already says: the `local` arm is CE-DS, which
`codespecs_mapping.md` §4.1 marks *reuse — no new class*. Its whole surface
resolves onto shipped classes and onto the annotated member itself:

| CE-UP surface | Where it lives |
|---------------|----------------|
| the setting's key | `@CsUserSetting('user.preferredLanguage')`'s own argument, against `TomUserPreferenceKeys` (`tom_core_kernel`) |
| its type and default | **the annotated member** — `String preferredLanguage = 'de'` (`codespecs_mapping.md` §5.16), exactly as a domain enum's default belongs to the member that has one |
| the user's persisted value | `TomUserPreferences` (`tom_core_server`) over `TomUserPreferenceRepository`, scoped by `@TomDbScope(field: 'principal_id')` |
| the wire | `tomUserPreferencesApi`'s four endpoints and `TomUserPreferenceDto` (`tom_core_kernel`) |
| `codespecs_mapping.md` §5.16's persisted-value → default order | `TomUserPreferences.getOr(key, <the member's initialiser>)` |
| the setting's display name | CE-TX copy in the message-key registry (`codespecs_mapping.md` §1.2 consequence 1, `codespecs_mapping.md` §5.21) — a label has one home |

A persistence seam here would also be strictly worse than the shipped one: an
in-memory map with no scope and no rows, standing in front of a persistent,
principal-scoped service. Note that `TomGetSettingsMessage` /
`TomGetSettingsResult` is **not** that seam and never was — it is the client
bootstrap payload (texts, config, groups, roles, entitlements), read-only and
not per-user-preference.

### Placing a class in the generated trio

Phase 4 emits three projects — shared, client-only and server-only
(`codespecs_mapping.md` §4.2) — and a gap class is authored against whichever
locus its part carries.

**Entity-model placement (CE-DB).** A CodeSpecs data entity is referenced by
both the client (as DTO/view) and the server (as persistence). The entity's
**field shape is authored once in the `shared` project** as the canonical
entity; the server-only `@CsTable`/`@CsColumn`/`@CsRepository` persistence
projection and the client-only DTO/view both derive from that shared shape. This
keeps the client free of any dependency on a server-authored type and mirrors
CE-UP, whose key and value type are shared while only its persistence is
server-side. The persistence markers themselves remain **server-side** parts.

**The same rule applied to results.** `TomReportResult` deliberately does
**not** extend `TomTabularResult`: a shared type cannot depend on a server type,
so the server adapts one way onto the tabular shape when exporting. The
adaptation is honoured in one inherited constraint — rows stay a `Stream`,
because a report exists for results too large to hold inline. A section is built
from a `Stream Function()` rather than a stream, since `deliveryChannels` is a
list and one run delivered twice must read its rows twice.

**Typed edges ride the annotation, not the class.** A report's authorization is
not held here; it rides a `@CsAuthorize` beside the `@CsReport` marker, per
`codespecs_mapping.md` §5.15's field-level rule, so the access level and the
permitted roles are that annotation's requirement kind and its typed `CsRoleRef`
list and the edge is compile-checked instead of being an id string on the
definition. `TomJobDeclaration` follows the same rule: `tom_core`-family classes
hold plain ids, and an edge that wants a typed ref belongs on the annotation.

## Architecture

```
tom_core_codespecs                    (dependencies: {} — no imports at all)
└── lib/src/
    ├── client_application.dart   CE-CL  TomClientApplication
    ├── job_declaration.dart      CE-JB  TomJobDeclaration
    ├── layout_node.dart          CE-LO  TomLayoutModel + node tree + deltas
    ├── message_key.dart          CE-TX  TomMessageKeyRegistry + entries
    ├── notification_model.dart   CE-NT  TomNotificationCatalog + types
    ├── report_model.dart         CE-RP  TomReportDefinition + TomReportResult
    └── route_flow.dart           CE-NV  TomRouteRegistry + screen flow

  a CodeSpec class          is a          gap class here
        │                                       │
        └── marked by a Cs* marker ─────────────┘
            (tom_code_specs)          … or, far more often, is a
                                      shipped tom_core-family class
```

| Type | Responsibility |
| --- | --- |
| `TomClientApplication` | The client application as a spec-authorable unit: id, platforms, entry route, screen ids, server base URL. |
| `TomLayoutModel` | The base/override two-layer layout, with reconciliation that reports orphaned deltas rather than dropping them. |
| `TomMessageKeyRegistry` | The closed message-key catalogue: which keys may exist, their role and category, and which CE-ER code each error string renders. |
| `TomRouteRegistry` | Route-id uniqueness and dangling-reference checking, plus the screen-flow edges between forms and screens. |
| `TomJobDeclaration` | The spec-side decision to deploy a job at all, and the entity targets it reads and writes. |
| `TomNotificationCatalog` | Which notification types exist and which channels each may go out on, narrowed by preferences. |
| `TomReportDefinition` | The grouped projection a specification authors — dimensions, measures, columns, parameters and charts. |
| `TomReportResult` | The shared result envelope both the server and the client read. |

### Where consistency is settled

Construction is where a class's internal consistency is settled: constructors
throw `ArgumentError` on each specification defect no generator can repair —
anything that would leave the emitted code referring to something that does not
exist. `TomReportDefinition`'s constructor dartdoc enumerates its cases, and is
the one place that does; a count repeated in prose is a count that goes stale.
`TomReportMeasureFunction` is 1:1 with `tom_core_server`'s
`TomAggregateFunction` — a measure the query layer cannot compile is a measure
that cannot run — and `COUNT(*)` / `COUNT(DISTINCT c)` are expressed as fields
(`columnName`, `distinct`) rather than as extra members.

Essentiality is likewise a property of the **type** (`isEssential`), not of the
preferences: a type the user cannot configure, or one with a mandatory channel,
survives a blanket opt-out whole. Silencing is therefore all-or-nothing per type
and can only ever reach a non-essential one — never a per-channel narrowing of
an essential type.

## Ecosystem

```
  tom_core family                  the substrate a CodeSpec is built on
  kernel / flutter / server /
  tom_flutter_ui
        │
        │ what it lacks
        ▼
  tom_core_codespecs               ← this package: 7 concrete gap classes
        ▲
        │ built on
  generated CodeSpecs trio         shared / client / server
        ▲
        │ marked by
  tom_code_specs                   the Cs* annotation family
        ▲
        │ routed by
  tom_specs_model                  the SOM sections a part is derived from
```

## Further documentation

**TomSpecs subject matter** — the authorities behind every verdict here:

| Document | Authority for |
|----------|---------------|
| [index.md](../../ai_build/tom_specs_model/doc/index.md) | The catalogue of the whole TomSpecs document set, and the `§` citation convention |
| [codespecs_mapping.md](doc/codespecs_mapping.md) | The parts catalogue, the five-package `tom_core`-family basis, the attribute surfaces, the three-project trio, the deferred candidates |
| [codespecs_derivation_contract.md](doc/codespecs_derivation_contract.md) | What code comes out per marker — inputs, emitted Dart, superclass, naming rules, validator checks |
| [codespecs_prompt.md](../../ai_build/tom_specs_model/doc/codespecs_prompt.md) | When a Phase-4 run may begin at all — the mechanical gate and the per-area judgment |
| [tom_specs_project_flow.md](../../ai_build/tom_specs_model/doc/tom_specs_project_flow.md) | The phase model Phase 4 sits in, and the quality gate it must pass |


**This package** — its own guides:

| Guide | Covers |
|-------|--------|
| [doc/index.md](doc/index.md) | The catalogue of this package's documentation |
| [doc/gap_classes.md](doc/gap_classes.md) | The seven modules, the dependency-free invariant, and where each kind of error surfaces |
| [doc/api/api_summary_tom_core_codespecs.md](doc/api/api_summary_tom_core_codespecs.md) | Every class and enum, its constructor, properties and methods |

**Runnable examples** — one per gap class, under [example/](example):

```bash
dart run --enable-asserts example/run_all_samples.dart
```

The flag is not cosmetic. Every example states its expected outcome with
`assert` and nothing else, and `dart run` strips asserts — so a flagless run
prints the same transcript, exits 0 and verifies nothing. Each example refuses
that run rather than letting it look like a pass, and
`test/examples_test.dart` runs all seven plus the aggregator under exactly the
command their headers document. It also holds the folder to the gap-class
inventory in both directions, so a gap class without an example is a failure
rather than an omission.

**Siblings** — packages you will reach for next:

| Package | What it is |
|---------|-----------|
| [tom_code_specs](../../ai_build/tom_code_specs) | The `Cs*` annotation family that marks a class as a part, and the typed cross-part references |
| [tom_specs_core](../../ai_build/tom_specs_core) | The SOM annotation vocabulary, and the home of `@CodeSpecKind` / `CodeSpecPart` |
| [tom_specs_model](../../ai_build/tom_specs_model) | The SOM source model whose sections route into these parts |
| [tom_specs_clitool](../../ai_build/tom_specs_clitool) | The CodeSpecs validator that checks a generated trio against the derivation contract |

## Status

Version **0.12.1**, published on pub.dev. The suite runs with `dart test`; no
count is given, because a count is a claim nothing checks and every added test
would be a README edit nobody makes. The version is checked.

Every part the
[`codespecs_mapping.md`](doc/codespecs_mapping.md)
§4.1 catalogue marks *gap* has its class here — CE-CL, CE-LO, CE-TX, CE-NV,
CE-JB, CE-NT and CE-RP. Every other part resolves onto shipped `tom_core`
classes and needs none. **CE-WF is the sole remaining `codespecs_mapping.md`
§4.3 deferred candidate**, and it is deferred permanently; a class is added here
only if a further part is ever promoted out of `codespecs_mapping.md` §4.3.
