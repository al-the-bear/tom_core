# TomSpecs CodeSpecs — The `tom_core` Gap Classes

This package holds the **concrete classes `tom_core` genuinely lacks** for
CodeSpecs, and nothing else. This guide covers the eight modules, the shape each
holder has, and — because it is the question that actually comes up — how to
tell whether a candidate class belongs here at all. Which parts are gaps and
which are reuse verdicts is
[`codespecs_mapping.md`](codespecs_mapping.md)
§4.1 and §5; this guide states the API and cites that.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [The eight modules](#the-eight-modules)
  - [The dependency-free invariant](#the-dependency-free-invariant)
- [The layout model: base plus overrides](#the-layout-model-base-plus-overrides)
- [The message-key registry](#the-message-key-registry)
- [The route registry and screen flow](#the-route-registry-and-screen-flow)
- [The notification catalogue](#the-notification-catalogue)
- [The report model](#the-report-model)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## Overview

The core principle is that every class a CodeSpec instantiates is a
`tom_core`-family class — one of `tom_core_kernel`, `tom_core_flutter`,
`tom_core_server` and `tom_flutter_ui`. Reuse an existing
`tom_core` class wherever one fits; only the concrete gaps land here, which is
what keeps `tom_core` free of CodeSpecs-only concerns.

What is here is therefore small and deliberate — **eight source files, 26
classes and 14 enums** — and what is *not* here is as much of the design as what
is. `tom_core` already carries the substrate for authentication, server
configuration, client configuration, user preferences, persistence and the audit
trail, so none of those needs a holder here.

There are **no abstract `Cs*` bases**. The framework in `tom_code_specs` carries
annotations only; this package carries the concrete things those annotations
mark.

## Quick Start

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final app = TomClientApplication(
    clientId: 'admin_console',
    displayName: 'Admin Console',
    platforms: ['web', 'macos'],
    entryRoute: 'dashboard',
    screenIds: ['dashboard', 'userList'],
    serverBaseUrl: 'https://api.example.com',
  );

  print('${app.clientId}: ${app.displayName}');
  print(app.platforms.join(', '));
  print('${app.screenIds.length} screens, entry = ${app.entryRoute}');
}
```

Output:

```
admin_console: Admin Console
web, macos
2 screens, entry = dashboard
```

Every collection argument defaults to a **fresh** empty collection, never a
shared constant, so two default-constructed holders never alias:

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final a = TomClientApplication();
  final b = TomClientApplication();
  a.platforms.add('web');

  print(a.platforms);
  print(b.platforms);
  print(identical(a.platforms, b.platforms));
}
```

Output:

```
[web]
[]
false
```

A client with no screens is representable, and that matters: a command-line
client or a server calling in ships none, so the empty list is the answer rather
than a missing one.

## Core Components

### The eight modules

| Module | Part | Holder(s) | Fills the gap in |
|--------|------|-----------|------------------|
| `client_application.dart` | CE-CL | `TomClientApplication` | Which clients exist, and what each entry point is |
| `layout_node.dart` | CE-LO | `TomLayoutModel`, `TomLayoutContainerNode`, `TomLayoutSlotNode`, `TomLayoutOverrideDelta` | The base/override two-layer layout a rendering leaf has no equivalent of |
| `message_key.dart` | CE-TX | `TomMessageKeyRegistry`, `TomMessageKey` | A *closed* key catalogue behind the untyped runtime text store |
| `route_flow.dart` | CE-NV | `TomRouteRegistry`, `TomRouteDefinition`, `TomFormScreenAssignment`, `TomScreenFlowEdge` | The route-id registry and screen-flow model a page route assumes but cannot check |
| `job_declaration.dart` | CE-JB | `TomJobDeclaration` | The deployment/ownership envelope around the scheduling runtime |
| `notification_model.dart` | CE-NT | `TomNotificationCatalog`, `TomNotificationType`, `TomNotificationChannelDeclaration`, `TomNotificationPreferences` | The layer that *chooses* a channel, above the messaging module that delivers on one |
| `operation_binding.dart` | CE-API | `TomOperationBinding`, `TomBindingParameter` | A second HTTP shape for an already-named operation, which an endpoint — being its own shape — cannot give (`codespecs_mapping.md` §5.30) |
| `report_model.dart` | CE-RP | `TomReportDefinition` (+ dimension, measure, column, parameter, chart) and `TomReportResult` | A grouped projection's authorable shape, which the row-shaped persistence surface has no home for |

### The dependency-free invariant

`pubspec.yaml` declares `dependencies: {}` and nothing under `lib/` imports
anything beyond `dart:core`. **The property is load-bearing, not incidental**,
and it is the first test a candidate class has to pass:

> A candidate gap class that would need a `tom_core_*` type is not a gap class.
> It belongs in the package whose type it needs.

Two shipped decisions rest on it. `TomReportResult` deliberately does not extend
the server's tabular-result type, because the envelope's locus is *shared* — the
client reads it too. And a job's report targets ride on the `@CsJob` annotation
in `tom_code_specs` rather than on `TomJobDeclaration` itself. Taking a
dependency here would retract both.

## The layout model: base plus overrides

`TomLayoutModel` is two layers. The **base** is a generated container tree; the
**overrides** are an authored list of id-addressed deltas applied on top of it.
Keeping them apart is what lets the base be regenerated without losing authored
adjustments.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final model = TomLayoutModel(
    layoutId: 'customerForm',
    base: TomLayoutContainerNode(
      nodeId: 'root',
      kind: TomLayoutContainerKind.column,
      children: [
        TomLayoutSlotNode(nodeId: 'nameSlot', referencedId: 'name'),
        TomLayoutSlotNode(nodeId: 'emailSlot', referencedId: 'email'),
      ],
    ),
    overrides: [
      TomLayoutOverrideDelta(
        op: TomLayoutDeltaOp.setSlotHint,
        targetNodeId: 'emailSlot',
        properties: {'flex': 2},
      ),
    ],
  );

  print(model.layoutId);
  print(model.base!.children.length);
  print(model.findNode('emailSlot')?.nodeId);
  print(model.findNode('noSuchNode'));
  print(model.reconcileWarnings());
  print(TomLayoutContainerKind.values.length);
  print(TomLayoutDeltaOp.values.map((o) => o.name).join(', '));
}
```

Output:

```
customerForm
2
emailSlot
null
[]
9
reparent, setContainerProp, setSlotHint, insertContainer, removeContainer
```

`reconcileWarnings()` is the method to reach for after a regeneration. It
reports three things, and the second is the one the two-layer design most needs:

- an override whose addressed id the new base no longer contains, so a delta
  orphaned by a model change surfaces instead of silently doing nothing;
- an override whose id still resolves but now names the **wrong kind of node** —
  `setSlotHint` on a container, `setContainerProp` or `removeContainer` on a
  slot, or a slot named as a new parent, which cannot own children. A vanished
  id is conspicuous; an id a regeneration re-used for a different kind of node
  goes on applying and quietly means something other than what was authored;
- an `insertContainer` whose id the base has since taken, or an operation that
  needs a new parent and names none.

Nothing is dropped in any case — the list is advice to whoever regenerated the
base.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final model = TomLayoutModel(
    layoutId: 'customerForm',
    base: TomLayoutContainerNode(nodeId: 'root'),
    overrides: [
      TomLayoutOverrideDelta(
        op: TomLayoutDeltaOp.setSlotHint,
        targetNodeId: 'removedSlot',
      ),
    ],
  );

  print(model.reconcileWarnings().length);
  print(model.reconcileWarnings().first.contains('removedSlot'));
}
```

Output:

```
1
true
```

## The message-key registry

`TomMessageKeyRegistry` is the *closed* catalogue: every piece of user-facing
copy has exactly one key, one base copy, and its per-locale translations.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final registry = TomMessageKeyRegistry(baseLocale: 'en')
    ..register(TomMessageKey(
      key: 'customer.form.title',
      baseCopy: 'Customer',
      localeCopy: {'de': 'Kunde'},
    ))
    ..register(TomMessageKey(
      key: 'customer.notFound',
      baseCopy: 'No such customer.',
      role: TomMessageRole.error,
      category: TomMessageCategory.errorCopy,
      errorCode: 'CUSTOMER_NOT_FOUND',
    ));

  print(registry.keys.length);
  print(registry.resolve('customer.form.title', 'de'));
  print(registry.resolve('customer.form.title', 'fr'));
  print(registry.forErrorCode('CUSTOMER_NOT_FOUND')?.key);
  print(registry.hasKey('customer.missing'));
}
```

Output:

```
2
Kunde
Customer
customer.notFound
false
```

`resolve` falls back to the base copy for an unknown locale rather than
returning null — an untranslated string is still a string a user can read.
`forErrorCode` is the reverse lookup an error envelope needs: given a code, find
the copy that explains it.

## The route registry and screen flow

`TomRouteRegistry` holds three things: the addressable screens, which form sits
on which screen, and the conditional edges between screens.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final registry = TomRouteRegistry()
    ..registerRoute(TomRouteDefinition(routeId: 'customerList', title: 'Customers'))
    ..registerRoute(TomRouteDefinition(routeId: 'customerEdit', title: 'Edit'))
    ..assignForm(TomFormScreenAssignment(
      formId: 'customerForm',
      routeId: 'customerEdit',
      presentation: TomScreenPresentation.popup,
    ))
    ..addFlowEdge(TomScreenFlowEdge(
      sourceRouteId: 'customerList',
      actionId: 'edit',
      outcome: TomFlowOutcome.success,
      targetRouteId: 'customerEdit',
    ));

  print(registry.routes.length);
  print(registry.hasRoute('customerEdit'));
  print(registry.assignmentFor('customerForm')?.presentation.name);
  print(registry.flowEdges.single.targetRouteId);
  print(registry.danglingRouteReferences());
}
```

Output:

```
2
true
popup
customerEdit
{}
```

`danglingRouteReferences()` is the integrity check: it returns every route id an
assignment or a flow edge names that the registry does not hold. It is a **`Set`**,
not a list — the same missing route named by three edges is one problem — so an
empty set is the pass.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final registry = TomRouteRegistry()
    ..registerRoute(TomRouteDefinition(routeId: 'customerList'))
    ..addFlowEdge(TomScreenFlowEdge(
      sourceRouteId: 'customerList',
      actionId: 'edit',
      targetRouteId: 'customerEdit', // never registered
    ));

  print(registry.danglingRouteReferences());
}
```

Output:

```
{customerEdit}
```

## The notification catalogue

The gap here is precise: the messaging runtime delivers a composed message on a
*named* channel, but takes the channel as already chosen. The layer that chooses
— types, their channels, and the preferences that narrow them — is what this
module holds.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

void main() {
  final catalog = TomNotificationCatalog(
    channels: [
      TomNotificationChannelDeclaration(
        channelId: 'push',
        fallbackChannelId: 'email',
        urgencyLevels: {TomNotificationUrgency.high, TomNotificationUrgency.critical},
      ),
      TomNotificationChannelDeclaration(channelId: 'email'),
    ],
    types: [
      TomNotificationType(
        typeId: 'order.shipped',
        category: TomNotificationCategory.transactional,
        urgency: TomNotificationUrgency.high,
        defaultChannelIds: ['push', 'email'],
        mandatoryChannelIds: ['email'],
      ),
    ],
  );

  final prefs = TomNotificationPreferences(
    userId: 'u1',
    channelsByTypeId: {'order.shipped': ['push']},
  );

  final type = catalog.types['order.shipped']!;
  print(type.isEssential);
  print(type.channelsFor(prefs));
  print(catalog.fallbackChainFrom('push'));
  print(prefs.silences(type));
}
```

Output:

```
true
[email, push]
[push, email]
false
```

Three behaviours are worth reading off that output. A type with a **mandatory**
channel is *essential*, so a user preference cannot remove it: `channelsFor`
returns the mandatory `email` as well as the chosen `push`, and `silences`
answers `false` because an essential type cannot be silenced. The mandatory
channels come first, so the order is not the preference order. And
`fallbackChainFrom` walks the `fallbackChannelId` links, guarding against a
cycle rather than looping.

## The report model

A report is a grouped projection: **dimensions** are the "by what", **measures**
the "how much", and **columns** what is actually displayed. `TomReportDefinition`
is the authored holder; `TomReportResult` is the shared envelope an operation
returns.

```dart complete
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

class Order {}

void main() {
  final definition = TomReportDefinition(
    reportId: 'sales.byRegion',
    displayName: 'Sales by region',
    sourceEntity: Order,
    dimensions: [
      TomReportDimension(
        key: 'region',
        columnName: 'region_code',
        valueKind: TomReportValueKind.string,
      ),
    ],
    measures: [
      TomReportMeasure(
        key: 'total',
        function: TomReportMeasureFunction.sum,
        columnName: 'total_amount',
        valueKind: TomReportValueKind.currency,
      ),
    ],
    columns: [
      TomReportColumn(
        name: 'region',
        sourceKey: 'region',
        valueKind: TomReportValueKind.string,
      ),
      TomReportColumn(
        name: 'total',
        sourceKey: 'total',
        valueKind: TomReportValueKind.currency,
      ),
    ],
  );

  print(definition.reportId);
  print(definition.dimensions.single.columnName);
  print(definition.measures.single.function.name);
  print(definition.columns.map((c) => c.name).join(', '));
  print(TomReportValueKind.values.length);
  print(TomReportChartKind.values.map((k) => k.name).join(', '));
}
```

Output:

```
sales.byRegion
region_code
sum
region, total
9
bar, line, pie, donut, scatter, gauge, heatmap
```

`TomReportResultSection.rows` is a **`Stream`**, not a `List`, and deliberately:
a report exists for results too large to hold inline.

The section is built from a **factory** rather than from a stream, because it is
read once per delivery and `deliveryChannels` is a list — a report declaring
`apiResponse` and `fileExport` is one run delivered two ways. `rows` calls that
factory on every read, so the second delivery gets its own pass instead of a
second listen on a spent stream. A large result is single-subscription, which is
exactly the case the streaming shape exists for, so handed a stream the second
delivery would throw.

The factory must return a new stream on every call — open the query, or the
file, *inside* the closure. That is the one part the type cannot enforce.

## Error Handling

Unlike the rest of this package's holders, the **report model validates in its
constructors** and throws `ArgumentError` on an ill-formed definition. That is
the one asymmetry, and it is there because a report definition is the only
holder whose parts refer to each other by key: a column's `sourceKey` must name
a dimension or a measure, so an unresolvable one is detectable at construction
rather than at render.

| Situation | Result |
|-----------|--------|
| `TomReportDimension(key: '')` | `ArgumentError` — an empty key names nothing |
| `TomReportColumn(name: '')` | `ArgumentError` |
| `TomReportResultSection(columns: [])` | `ArgumentError` — a section with no columns renders nothing |
| Duplicate column names in one definition | `ArgumentError` |
| `TomLayoutModel` override targeting a missing node | **No throw** — reported by `reconcileWarnings()` |
| `TomLayoutModel` override targeting the wrong node kind | **No throw** — reported by `reconcileWarnings()` |
| `TomRouteRegistry` edge to an unregistered route | **No throw** — reported by `danglingRouteReferences()` |
| `TomMessageKeyRegistry.resolve` for an unknown locale | **No throw** — falls back to the base copy |
| `TomMessageKeyRegistry.resolve` for an unknown key | `ArgumentError` — the catalogue is closed, so an unknown key is a defect, not a miss |
| `TomReportColumn.sourceKey` naming no dimension or measure | `ArgumentError` at definition construction |
| An empty `reportId` | `ArgumentError` |
| A notification channel fallback cycle | **No throw** — `fallbackChainFrom` stops at the repeat |

The pattern behind that table is worth stating, because it is what tells you
where to look when something goes wrong:

- **A structural error throws at construction** — an empty key, an empty column
  list, a duplicate name, a `sourceKey` naming nothing. These are decidable from
  the object alone, so there is no reason to defer them.
- **A referential error across separately-built objects is reported by a named
  method** — `reconcileWarnings()`, `danglingRouteReferences()`. These are often
  *transient*: mid-edit, or mid-regeneration, a layout override may name a node
  the new base has not yet acquired. Throwing would make that intermediate state
  unrepresentable.

`TomMessageKeyRegistry.resolve` sits on the first side of that line and is worth
noting explicitly: an unknown *locale* falls back, but an unknown *key* throws.
The catalogue is closed, so a key it does not hold is a defect in the caller
rather than a translation that has not been done yet.

## Best Practices

- **Check `tom_core` before adding a class here.** The catalogue of reuse
  verdicts in `codespecs_mapping.md` §5 exists because most candidates already
  have a home.
- **Never take a dependency.** A holder needing a `tom_core_*` type belongs in
  that package, not here — the empty `dependencies:` block is the check.
- **Run `reconcileWarnings()` after regenerating a layout base**, and
  `danglingRouteReferences()` after editing routes. Neither throws, so neither
  reports itself.
- **Keep the layout override layer small.** Every delta is a claim about a node
  id that a base regeneration can invalidate.
- **Give every message key an `errorCode` when it is error copy.** It is what
  makes the reverse lookup from an error envelope possible.
- **Model a large report as a stream, not a list.** `TomReportResult` already
  assumes it; materialising defeats the reason.

---

Back to the [documentation index](index.md).
