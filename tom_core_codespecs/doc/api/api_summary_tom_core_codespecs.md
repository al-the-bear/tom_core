# TomSpecs CodeSpecs API Reference: tom_core_codespecs

The concrete `tom_core`-family classes CodeSpecs needs and `tom_core` does
not already carry. One library, eight source modules, no dependencies.

For task-oriented guidance see [gap_classes.md](../gap_classes.md). For which
parts are gaps and which are reuse verdicts, see
[`codespecs_mapping.md`](../codespecs_mapping.md)
§4.1 and §5.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [CE-CL — client application](#ce-cl--client-application)
    - [TomClientApplication](#tomclientapplication)
  - [CE-LO — layout model](#ce-lo--layout-model)
    - [TomLayoutContainerNode](#tomlayoutcontainernode)
    - [TomLayoutSlotNode](#tomlayoutslotnode)
    - [TomLayoutOverrideDelta](#tomlayoutoverridedelta)
    - [TomLayoutModel](#tomlayoutmodel)
  - [CE-TX — message-key registry](#ce-tx--message-key-registry)
    - [TomMessageKey](#tommessagekey)
    - [TomMessageKeyRegistry](#tommessagekeyregistry)
  - [CE-NV — routes and screen flow](#ce-nv--routes-and-screen-flow)
    - [TomRouteDefinition](#tomroutedefinition)
    - [TomFormScreenAssignment](#tomformscreenassignment)
    - [TomScreenFlowEdge](#tomscreenflowedge)
    - [TomRouteRegistry](#tomrouteregistry)
  - [CE-JB — job declaration](#ce-jb--job-declaration)
    - [TomJobDeclaration](#tomjobdeclaration)
  - [CE-NT — notification catalogue](#ce-nt--notification-catalogue)
    - [TomNotificationChannelDeclaration](#tomnotificationchanneldeclaration)
    - [TomNotificationType](#tomnotificationtype)
    - [TomNotificationPreferences](#tomnotificationpreferences)
    - [TomNotificationCatalog](#tomnotificationcatalog)
  - [CE-API — operation binding](#ce-api--operation-binding)
    - [TomBindingParameter](#tombindingparameter)
    - [TomOperationBinding](#tomoperationbinding)
  - [CE-RP — report model](#ce-rp--report-model)
    - [TomReportDimension](#tomreportdimension)
    - [TomReportMeasure](#tomreportmeasure)
    - [TomReportColumn](#tomreportcolumn)
    - [TomReportParameter](#tomreportparameter)
    - [TomReportChart](#tomreportchart)
    - [TomReportDefinition](#tomreportdefinition)
    - [TomReportResultSection](#tomreportresultsection)
    - [TomReportResult](#tomreportresult)
- [Enums](#enums)
  - [TomLayoutContainerKind](#tomlayoutcontainerkind)
  - [TomLayoutDeltaOp](#tomlayoutdeltaop)
  - [TomMessageRole](#tommessagerole)
  - [TomMessageCategory](#tommessagecategory)
  - [TomScreenPresentation](#tomscreenpresentation)
  - [TomFlowOutcome](#tomflowoutcome)
  - [TomNotificationCategory](#tomnotificationcategory)
  - [TomNotificationUrgency](#tomnotificationurgency)
  - [TomBindingSource](#tombindingsource)
  - [TomBindingErrorFormat](#tombindingerrorformat)
  - [TomReportValueKind](#tomreportvaluekind)
  - [TomReportMeasureFunction](#tomreportmeasurefunction)
  - [TomReportDeliveryChannel](#tomreportdeliverychannel)
  - [TomReportChartKind](#tomreportchartkind)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

The package declares **26 classes** and **14 enums** across eight modules.

| Module | Part | Classes | Enums |
|--------|------|---------|-------|
| `client_application.dart` | CE-CL | `TomClientApplication` | *(none)* |
| `layout_node.dart` | CE-LO | `TomLayoutContainerNode`, `TomLayoutSlotNode`, `TomLayoutOverrideDelta`, `TomLayoutModel` | `TomLayoutContainerKind`, `TomLayoutDeltaOp` |
| `message_key.dart` | CE-TX | `TomMessageKey`, `TomMessageKeyRegistry` | `TomMessageRole`, `TomMessageCategory` |
| `route_flow.dart` | CE-NV | `TomRouteDefinition`, `TomFormScreenAssignment`, `TomScreenFlowEdge`, `TomRouteRegistry` | `TomScreenPresentation`, `TomFlowOutcome` |
| `job_declaration.dart` | CE-JB | `TomJobDeclaration` | *(none)* |
| `notification_model.dart` | CE-NT | `TomNotificationChannelDeclaration`, `TomNotificationType`, `TomNotificationPreferences`, `TomNotificationCatalog` | `TomNotificationCategory`, `TomNotificationUrgency` |
| `operation_binding.dart` | CE-API | `TomBindingParameter`, `TomOperationBinding` | `TomBindingSource`, `TomBindingErrorFormat` |
| `report_model.dart` | CE-RP | `TomReportDimension`, `TomReportMeasure`, `TomReportColumn`, `TomReportParameter`, `TomReportChart`, `TomReportDefinition`, `TomReportResultSection`, `TomReportResult` | `TomReportValueKind`, `TomReportMeasureFunction`, `TomReportDeliveryChannel`, `TomReportChartKind` |

**`dependencies: {}` is an invariant.** Nothing under `lib/` imports anything
beyond `dart:core`. A candidate class that would need a `tom_core_*` type is
therefore not a gap class — it belongs in the package whose type it needs.

## Class Hierarchy

```
Object
├── CE-CL — client application
│   └── TomClientApplication
├── CE-LO — layout model
│   ├── TomLayoutContainerNode  extends TomLayoutNode
│   ├── TomLayoutSlotNode  extends TomLayoutNode
│   ├── TomLayoutOverrideDelta
│   └── TomLayoutModel
├── CE-TX — message-key registry
│   ├── TomMessageKey
│   └── TomMessageKeyRegistry
├── CE-NV — routes and screen flow
│   ├── TomRouteDefinition
│   ├── TomFormScreenAssignment
│   ├── TomScreenFlowEdge
│   └── TomRouteRegistry
├── CE-JB — job declaration
│   └── TomJobDeclaration
├── CE-NT — notification catalogue
│   ├── TomNotificationChannelDeclaration
│   ├── TomNotificationType
│   ├── TomNotificationPreferences
│   └── TomNotificationCatalog
├── CE-API — operation binding
│   ├── TomBindingParameter
│   └── TomOperationBinding
└── CE-RP — report model
    ├── TomReportDimension
    ├── TomReportMeasure
    ├── TomReportColumn
    ├── TomReportParameter
    ├── TomReportChart
    ├── TomReportDefinition
    ├── TomReportResultSection
    └── TomReportResult
```

`TomLayoutContainerNode` and `TomLayoutSlotNode` are the only subclasses — both
of the `TomLayoutNode` base the layout tree walks.

## Classes

### CE-CL — client application

#### TomClientApplication

The client-application descriptor a CodeSpec's `@CsClient` (CE-CL) is built on.

##### Constructors
```dart
TomClientApplication({
  this.clientId = '',
  this.displayName = '',
  List<String>? platforms,
  this.entryRoute = '',
  List<String>? screenIds,
  this.serverBaseUrl = '',
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `clientId` | `String` | Stable identifier of the client application (e.g. |
| `displayName` | `String` | Human-readable name of the client application. |
| `platforms` | `List<String>` | The target platforms this client is built for (e.g. |
| `entryRoute` | `String` | The route id the client opens on launch (a `TomPageRoute` id — CE-NV). |
| `screenIds` | `List<String>` | The screens this client comprises, by screen id (CE-EL / CE-FM). |
| `serverBaseUrl` | `String` | The base URL of the server this client talks to. |

### CE-LO — layout model

#### TomLayoutContainerNode

A container node in the generated base layout tree.

**Extends:** `TomLayoutNode`

##### Constructors
```dart
TomLayoutContainerNode({
  super.nodeId,
  this.kind = TomLayoutContainerKind.column,
  Map<String, Object?>? properties,
  List<TomLayoutNode>? children,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `kind` | `TomLayoutContainerKind` | Which of the nine closed container kinds this node is. |
| `properties` | `Map<String, Object?>` | Container-level properties (spacing, alignment, column count, …), keyed by property name. |
| `children` | `List<TomLayoutNode>` | Child nodes, in paint/flow order. |

#### TomLayoutSlotNode

A leaf node that *places* an element which is defined elsewhere.

**Extends:** `TomLayoutNode`

##### Constructors
```dart
TomLayoutSlotNode({
  super.nodeId,
  this.referencedId = '',
  Map<String, Object?>? hints,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `referencedId` | `String` | Id of the element (field, action, component) this slot places. |
| `hints` | `Map<String, Object?>` | Layout hints for the placed element (flex, span, alignment, …). |

#### TomLayoutOverrideDelta

One entry in the authored override layer — an id-addressed delta applied on top of the generated base tree.

##### Constructors
```dart
TomLayoutOverrideDelta({
  this.op = TomLayoutDeltaOp.setSlotHint,
  this.targetNodeId = '',
  this.newParentNodeId,
  this.position,
  Map<String, Object?>? properties,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `op` | `TomLayoutDeltaOp` | Which of the five closed operations this delta performs. |
| `targetNodeId` | `String` | The node this delta addresses. |
| `newParentNodeId` | `String?` | New parent for [TomLayoutDeltaOp.reparent] and [TomLayoutDeltaOp.insertContainer]; `null` for the other operations. |
| `properties` | `Map<String, Object?>` | Property or hint values for [TomLayoutDeltaOp.setContainerProp] and [TomLayoutDeltaOp.setSlotHint]. |

#### TomLayoutModel

The two-layer layout holder a CodeSpec's `@CsLayout` (CE-LO) is built on.

##### Constructors
```dart
TomLayoutModel({
  this.layoutId = '',
  this.base,
  List<TomLayoutOverrideDelta>? overrides,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `layoutId` | `String` | Stable identifier of this layout (typically the form or screen it lays out). |
| `base` | `TomLayoutContainerNode?` | The generated layer — regenerated wholesale from the semantic model. |
| `overrides` | `List<TomLayoutOverrideDelta>` | The authored layer — id-addressed deltas applied on top of [base]. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `findNode(String nodeId)` | `TomLayoutNode?` | The node with [nodeId] in the generated [base] tree, or `null`. |
| `reconcileWarnings()` | `List<String>` | Deltas that no longer resolve against the regenerated [base] tree — an addressed node that is gone, one that now has the wrong kind for the operation, an `insertContainer` whose id the base has taken, or a missing new parent. One warning per fault; nothing is dropped. |

### CE-TX — message-key registry

#### TomMessageKey

One catalogued message key with its base copy and per-locale translations.

##### Constructors
```dart
TomMessageKey({
  this.key = '',
  this.baseCopy = '',
  this.role = TomMessageRole.generic,
  this.category = TomMessageCategory.uiCopy,
  this.errorCode,
  List<String>? parameters,
  Map<String, String>? localeCopy,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `key` | `String` | The catalogue key (e.g. |
| `baseCopy` | `String` | Copy in the registry's base locale. |
| `role` | `TomMessageRole` | What this message is for. |
| `category` | `TomMessageCategory` | Which side of the derived/catalogued split this entry sits on. |
| `errorCode` | `String?` | The CE-ER error code this copy renders, for [TomMessageCategory.errorCopy] entries; `null` otherwise. |
| `parameters` | `List<String>` | Placeholder names the copy interpolates (e.g. |
| `localeCopy` | `Map<String, String>` | Translated copy by locale tag. |

#### TomMessageKeyRegistry

The message-key catalogue a CodeSpec's `@CsMessage` (CE-TX) is built on.

##### Constructors
```dart
TomMessageKeyRegistry({this.baseLocale = 'en'});
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `baseLocale` | `String` | Locale whose copy is held in [TomMessageKey.baseCopy]. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `hasKey(String key)` | `bool` | Whether [key] is catalogued. |
| `register(TomMessageKey entry)` | `void` | Adds [entry] to the catalogue. |
| `forErrorCode(String errorCode)` | `TomMessageKey?` | The entry rendering CE-ER code [errorCode], or `null` when the code has no copy yet. |
| `resolve(String key, String locale)` | `String` | Copy for [key] in [locale], falling back to the base-locale copy when the locale has no translation. |

### CE-NV — routes and screen flow

#### TomRouteDefinition

One addressable screen in the navigation graph.

##### Constructors
```dart
TomRouteDefinition({
  this.routeId = '',
  this.path,
  this.title = '',
  List<String>? parameters,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `routeId` | `String` | Stable identifier of the route, unique within the registry. |
| `path` | `String?` | The route's URL path, when it is deep-linkable. |
| `title` | `String` | Human-readable title of the screen. |
| `parameters` | `List<String>` | Names of the parameters the route accepts. |

#### TomFormScreenAssignment

Placement of a form onto a screen (`codespecs_mapping.md` §5.11).

##### Constructors
```dart
TomFormScreenAssignment({
  this.formId = '',
  this.routeId = '',
  this.presentation = TomScreenPresentation.replace,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `formId` | `String` | Id of the form being placed. |
| `routeId` | `String` | Id of the route the form is placed on. |
| `presentation` | `TomScreenPresentation` | Whether the form takes over the screen or is layered over it. |

#### TomScreenFlowEdge

One conditional edge of the screen flow: from a screen, via an action, for a given outcome, to a target screen.

##### Constructors
```dart
TomScreenFlowEdge({
  this.sourceRouteId = '',
  this.actionId = '',
  this.outcome = TomFlowOutcome.success,
  this.targetRouteId = '',
  this.presentation = TomScreenPresentation.replace,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `sourceRouteId` | `String` | Route the action is triggered from. |
| `actionId` | `String` | Id of the triggering action. |
| `outcome` | `TomFlowOutcome` | Outcome that selects this edge. |
| `targetRouteId` | `String` | Route reached when the action ends with [outcome]. |
| `presentation` | `TomScreenPresentation` | How the target is presented. |

#### TomRouteRegistry

The route registry and screen-flow model a CodeSpec's `@CsRoute` / `@CsScreenFlow` (CE-NV) is built on.

##### Constructors
```dart
TomRouteRegistry();
```

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `hasRoute(String routeId)` | `bool` | Whether [routeId] names a registered route. |
| `registerRoute(TomRouteDefinition route)` | `void` | Registers [route]. |
| `assignForm(TomFormScreenAssignment assignment)` | `void` | Places a form onto a screen. |
| `assignmentFor(String formId)` | `TomFormScreenAssignment?` | The placement of [formId], or `null` when the form is unplaced. |
| `addFlowEdge(TomScreenFlowEdge edge)` | `void` | Adds a conditional screen-flow edge. |
| `danglingRouteReferences()` | `Set<String>` | Route ids referenced by edges or assignments that are not registered. |

### CE-JB — job declaration

#### TomJobDeclaration

The spec-side job declaration a CodeSpec's `@CsJob` (CE-JB) is built on.

##### Constructors
```dart
TomJobDeclaration({
  this.jobId = '',
  this.displayName = '',
  this.enabled = true,
  List<String>? environments,
  this.serviceUnitId,
  List<Type>? readEntities,
  List<Type>? writtenEntities,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `jobId` | `String` | Stable identifier of the job, unique within the system. |
| `displayName` | `String` | Human-readable name of the job. |
| `enabled` | `bool` | Whether the job is deployed at all. |
| `environments` | `List<String>` | Environments the job is deployed to. |
| `serviceUnitId` | `String?` | Id of the service unit that owns this job. |
| `readEntities` | `List<Type>` | The CE-DB entities the job reads, as `Type` literals. |
| `writtenEntities` | `List<Type>` | The CE-DB entities the job writes, as `Type` literals. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `runsIn(String environment)` | `bool` | Whether the job is deployed to [environment]. |

### CE-NT — notification catalogue

#### TomNotificationChannelDeclaration

A declared delivery channel — the spec-side counterpart of `NotificationChannelEntry` (`NTFCH`).

##### Constructors
```dart
TomNotificationChannelDeclaration({
  this.channelId = '',
  this.displayName = '',
  this.fallbackChannelId,
  this.honoursQuietHours = false,
  Set<TomNotificationUrgency>? urgencyLevels,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `channelId` | `String` | Stable identifier, matching the `TomMessageChannel` name it delivers on. |
| `displayName` | `String` | Human-readable name of the channel. |
| `fallbackChannelId` | `String?` | The channel to use when this one is unavailable in a deployment. |
| `honoursQuietHours` | `bool` | Whether delivery on this channel is suppressed during a user's quiet hours. |
| `urgencyLevels` | `Set<TomNotificationUrgency>` | The urgencies this channel is allowed to carry. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `carries(TomNotificationUrgency urgency)` | `bool` | Whether this channel may carry a notification of [urgency]. |

#### TomNotificationType

A declared notification type — the spec-side counterpart of `NotificationTypeEntry` (`NTFTY`).

##### Constructors
```dart
TomNotificationType({
  this.typeId = '',
  this.displayName = '',
  this.category = TomNotificationCategory.transactional,
  this.urgency = TomNotificationUrgency.medium,
  List<String>? defaultChannelIds,
  List<String>? mandatoryChannelIds,
  this.userConfigurable = true,
  this.triggerEvent,
  this.contentTemplateKey,
  this.localized = false,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `typeId` | `String` | Stable identifier of the notification type, unique within the system. |
| `displayName` | `String` | Human-readable name ("Order Confirmation", "Password Reset"). |
| `category` | `TomNotificationCategory` | What the notification is for; see [TomNotificationCategory]. |
| `urgency` | `TomNotificationUrgency` | How urgent the notification is. |
| `defaultChannelIds` | `List<String>` | Channel ids used when the user has expressed no preference. |
| `mandatoryChannelIds` | `List<String>` | Channel ids that no preference can remove. |
| `userConfigurable` | `bool` | Whether the user may change the channels for this type at all. |
| `triggerEvent` | `String?` | The system event that emits this notification, if one is named. |
| `contentTemplateKey` | `String?` | The CE-TX message key naming the body template. |
| `localized` | `bool` | Whether the template is translated. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `channelsFor(TomNotificationPreferences? preferences)` | `List<String>` | The channel ids this type is delivered on for a user holding [preferences] (`null` for a user who has expressed none). |

#### TomNotificationPreferences

A user's notification preferences — the spec-side counterpart of `UserNotificationPreferences` (`UNP`).

##### Constructors
```dart
TomNotificationPreferences({
  this.userId,
  this.globalOptOut = false,
  Set<String>? mutedTypeIds,
  Map<String, List<String>>? channelsByTypeId,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `userId` | `String?` | The user these preferences belong to. |
| `globalOptOut` | `bool` | Whether the user has opted out of all non-essential notifications. |
| `mutedTypeIds` | `Set<String>` | Type ids the user has muted individually. |
| `channelsByTypeId` | `Map<String, List<String>>` | The channels the user chose, per type id. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `silences(TomNotificationType type)` | `bool` | Whether these preferences silence [type]'s optional channels. |

#### TomNotificationCatalog

The declared notification catalogue: every channel and every type the system has.

##### Constructors
```dart
TomNotificationCatalog({
  List<TomNotificationChannelDeclaration>? channels,
  List<TomNotificationType>? types,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `channels` | `Map<String, TomNotificationChannelDeclaration>` | The declared channels, by [TomNotificationChannelDeclaration.channelId]. |
| `types` | `Map<String, TomNotificationType>` | The declared types, by [TomNotificationType.typeId]. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `fallbackChainFrom(String channelId)` | `List<String>` | The fallback chain starting at [channelId], nearest first. |

### CE-API — operation binding

#### TomBindingParameter

One wire parameter of a [TomOperationBinding]: where it is read from, and which request member of the operation it supplies.

##### Constructors
```dart
const TomBindingParameter(
  this.name, {
  required this.source,
  required this.member,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | The parameter's name on the wire. |
| `source` | `TomBindingSource` | Where on the request the parameter is read from. |
| `member` | `String` | The operation's request member this parameter supplies. |

#### TomOperationBinding

A second HTTP shape for an operation that already has a name.

##### Constructors
```dart
const TomOperationBinding(
  this.operation, {
  required this.method,
  required this.path,
  this.versionPrefix = '',
  this.parameters = const [],
  this.successStatus = 200,
  this.responseHeaders = const [],
  this.consumes,
  this.produces = 'application/json',
  this.errorFormat = TomBindingErrorFormat.resultEnvelope,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `methods` | `Set<String>` | *(static const)* The HTTP methods a binding may declare — the closed set the CodeSpecs validator holds [method] to. |
| `operation` | `String` | The name of the operation this binding serves, verbatim. |
| `method` | `String` | The HTTP method, one of [methods]. |
| `path` | `String` | The path template after [versionPrefix], with `{name}` captures. |
| `versionPrefix` | `String` | The prefix the path is served under, such as `/scim/v2`. Empty by default. |
| `parameters` | `List<TomBindingParameter>` | How each wire parameter maps onto the operation's request members. |
| `successStatus` | `int` | The status code a successful call answers with. |
| `responseHeaders` | `List<String>` | Response headers the binding sets on success, by name. |
| `consumes` | `String?` | The request media type the binding accepts, or `null` when the request carries no body. |
| `produces` | `String` | The response media type. |
| `errorFormat` | `TomBindingErrorFormat` | The shape a failed call's CE-ER error is written in. |
| `route` | `String` | The full route the binding is served under: [versionPrefix] then [path]. |
| `pathCaptures` | `List<String>` | The names inside the `{...}` captures of [path], in order. |

### CE-RP — report model

#### TomReportDimension

One grouping key of a report — the "by what" of the grouped projection.

##### Constructors
```dart
TomReportDimension({
  required this.key,
  required this.columnName,
  required this.valueKind,
  this.label,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `key` | `String` | The stable alias the dimension is projected under, and that a [TomReportColumn] names to display it. |
| `columnName` | `String` | The CE-DB entity column being grouped by. |
| `valueKind` | `TomReportValueKind` | The value type the grouped key carries. |
| `label` | `String?` | The CE-TX message key for the dimension's display name, if it has one. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportMeasure

One aggregated value of a report — the "how much" of the grouped projection.

##### Constructors
```dart
TomReportMeasure({
  required this.key,
  required this.function,
  this.columnName,
  this.distinct = false,
  this.valueKind = TomReportValueKind.decimal,
  this.label,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `key` | `String` | The stable alias the aggregate is projected under. |
| `function` | `TomReportMeasureFunction` | The aggregate applied. |
| `columnName` | `String?` | The CE-DB entity column aggregated, or `null` for a bare row count. |
| `distinct` | `bool` | Whether the aggregate considers distinct operand values only. |
| `valueKind` | `TomReportValueKind` | The value type the aggregate yields. |
| `label` | `String?` | The CE-TX message key for the measure's display name, if it has one. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportColumn

One projected output column of a report.

##### Constructors
```dart
TomReportColumn({
  required this.name,
  required this.sourceKey,
  required this.valueKind,
  this.label,
  this.formatPattern,
  this.drillThroughRouteId,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | The column's machine-facing name in the result envelope. |
| `sourceKey` | `String` | The [TomReportDimension.key] or [TomReportMeasure.key] this column shows. |
| `valueKind` | `TomReportValueKind` | The value type rendered. |
| `label` | `String?` | The CE-TX message key for the column header. |
| `formatPattern` | `String?` | A presentation pattern for the value — a number or date format. |
| `drillThroughRouteId` | `String?` | The CE-NV route a click on a cell navigates to, if the column drills through. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportParameter

A runtime input the caller supplies when the report is run.

##### Constructors
```dart
TomReportParameter({
  required this.name,
  required this.valueKind,
  this.required = false,
  this.defaultValue,
  this.label,
  this.enumId,
  this.entityId,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | The parameter's name in the report's request shape. |
| `valueKind` | `TomReportValueKind` | The value type the caller supplies. |
| `required` | `bool` | Whether the query needs a value for this parameter. |
| `defaultValue` | `Object?` | The value used when the caller supplies none. |
| `label` | `String?` | The CE-TX message key for the input's label. |
| `enumId` | `String?` | The `domainEnum` domain enum whose values are offered, for an enumeration. |
| `entityId` | `String?` | The CE-DB entity whose instances are offered, for an entity reference. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportChart

A chart a report declares over its own projected columns.

##### Constructors
```dart
TomReportChart({
  required this.chartId,
  required this.kind,
  required this.categoryColumn,
  required this.valueColumns,
  this.title,
  this.seriesColumn,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `chartId` | `String` | The chart's id, unique within its report. |
| `kind` | `TomReportChartKind` | The chart form. |
| `title` | `String?` | The CE-TX message key for the chart title. |
| `categoryColumn` | `String` | The [TomReportColumn.name] supplying the category (x) axis. |
| `valueColumns` | `List<String>` | The [TomReportColumn.name]s supplying the plotted values. |
| `seriesColumn` | `String?` | The [TomReportColumn.name] that splits the data into series, if any. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportDefinition

A complete authored report definition — the CE-RP CodeSpec's holder.

##### Constructors
```dart
TomReportDefinition({
  required this.reportId,
  required this.sourceEntity,
  required this.columns,
  this.displayName,
  this.dimensions = const [],
  this.measures = const [],
  this.parameters = const [],
  this.charts = const [],
  this.deliveryChannels = const [TomReportDeliveryChannel.apiResponse],
  this.scheduleExpression,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `reportId` | `String` | The report's stable id — the key a `CsReportRef` const carries. |
| `displayName` | `String?` | The CE-TX message key for the report's title. |
| `sourceEntity` | `Type` | The CE-DB entity the projection selects from, as a `Type` literal. |
| `dimensions` | `List<TomReportDimension>` | The grouping keys. |
| `measures` | `List<TomReportMeasure>` | The aggregated values. |
| `columns` | `List<TomReportColumn>` | The projected output columns, in output order. |
| `parameters` | `List<TomReportParameter>` | The runtime inputs the caller supplies. |
| `charts` | `List<TomReportChart>` | The charts declared over the projected columns. |
| `deliveryChannels` | `List<TomReportDeliveryChannel>` | The channels this report is delivered on. |
| `scheduleExpression` | `String?` | When the report runs unattended — a recurrence expression, verbatim. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportResultSection

One titled block of a [TomReportResult]: columns over a stream of rows.

##### Constructors
```dart
TomReportResultSection({
  required this.columns,
  required Stream<List<Object?>> Function() openRows,
  this.title,
})
```

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String?` | An optional caption for the block. |
| `columns` | `List<TomReportColumn>` | The section's columns, in output order. |
| `rows` | `Stream<List<Object?>>` | A **fresh** stream of the section's rows, pulled once, in order. Each read calls the `openRows` factory the section was built with, so two deliveries of one result are two independent passes. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

#### TomReportResult

The shared result envelope a CE-RP report operation returns. The client renders
it; the server adapts it onto `tom_core_server`'s `TomTabularResult` to export
it.

##### Constructors

| Constructor | Description |
|-------------|-------------|
| `TomReportResult({required String reportId, required String title, required List<TomReportResultSection> sections, List<TomReportChart> charts = const [], Map<String, String> metadata = const {}})` | Creates a result. Throws `ArgumentError` when `sections` is empty. `metadata` is stored unmodifiable. |
| `TomReportResult.single({required String reportId, required String title, required TomReportResultSection section, List<TomReportChart> charts = const [], Map<String, String> metadata = const {}})` | A single-section result — the common case. |

##### Properties

| Property | Type | Description |
|----------|------|-------------|
| `reportId` | `String` | The `TomReportDefinition.reportId` this result came from. |
| `title` | `String` | The rendered document title. |
| `sections` | `List<TomReportResultSection>` | The result's sections, in output order; never empty. Each carries its own `columns` and `rows`. |
| `charts` | `List<TomReportChart>` | The charts declared for this result. |
| `metadata` | `Map<String, String>` | How the result was produced — parameter values, who ran it, the as-of timestamp. Unmodifiable. |

##### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `toString()` | `String` | A diagnostic rendering used in validation messages. |

## Enums

### TomLayoutContainerKind

The closed set of layout containers a CodeSpec may author (`codespecs_mapping.md` §5.22).

| Value | Meaning |
|-------|---------|
| `row` | Horizontal sequence. |
| `column` | Vertical sequence. |
| `wrap` | Horizontal sequence that wraps onto further lines. |
| `stack` | Overlapping children painted back to front. |
| `flex` | Proportional sequence driven by per-child flex factors. |
| `grid` | Two-dimensional cell arrangement. |
| `padding` | Insets around a single child. |
| `align` | Positions a single child within the available space. |
| `sizedBox` | Constrains a single child to fixed dimensions. |

### TomLayoutDeltaOp

The closed grammar of override deltas in the authored layer (`codespecs_mapping.md` §5.22).

| Value | Meaning |
|-------|---------|
| `reparent` | Move an existing node under a different parent. |
| `setContainerProp` | Set a property on an existing container node. |
| `setSlotHint` | Set a layout hint (flex, span, alignment) on an existing slot. |
| `insertContainer` | Add a container that the generated base does not contain. |
| `removeContainer` | Drop a container the generated base contains (its children reparent to the removed container's parent). |

### TomMessageRole

What a catalogued message is *for* (`codespecs_mapping.md` §5.21).

| Value | Meaning |
|-------|---------|
| `error` | Copy for a failure, paired 1:1 with a CE-ER error code. |
| `notification` | Copy for a user-facing notification. |
| `email` | Copy rendered into an email. |
| `report` | Copy rendered into a generated report. |
| `generic` | Copy with no channel-specific treatment. |

### TomMessageCategory

The derived-vs-catalogued split of `codespecs_mapping.md` §5.8/§5.21.

| Value | Meaning |
|-------|---------|
| `uiCopy` | Copy attached to UI surfaces that are not element labels. |
| `errorCopy` | Copy for a CE-ER error code. |

### TomScreenPresentation

How a target screen replaces or covers the current one (`codespecs_mapping.md` §5.11).

| Value | Meaning |
|-------|---------|
| `replace` | The target takes over the current screen. |
| `popup` | The target is layered over the current screen, which stays mounted. |

### TomFlowOutcome

The outcome of an action, which selects the navigation target (`codespecs_mapping.md` §5.11).

| Value | Meaning |
|-------|---------|
| `success` | The action completed. |
| `error` | The action failed with a processing error. |
| `validationError` | The action was rejected by validation. |

### TomNotificationCategory

What a notification is *for* — the closed catalogue authored in `NotificationTypeEntry.category`.

| Value | Meaning |
|-------|---------|
| `transactional` | A direct consequence of a user action (order confirmation, receipt). |
| `marketing` | Promotional content. |
| `system` | Operational messages about the system itself (maintenance, quota). |
| `security` | Security-relevant events (password reset, new-device sign-in). |

### TomNotificationUrgency

How urgent a notification is — the closed catalogue authored in `NotificationTypeEntry.urgency`.

| Value | Meaning |
|-------|---------|
| `low` | Can wait indefinitely; a digest is appropriate. |
| `medium` | The default — delivered promptly but not interrupting. |
| `high` | Should reach the user the same day. |
| `critical` | Must interrupt. |

### TomBindingSource

Where a [TomBindingParameter] finds the request member it supplies.

| Value | Meaning |
|-------|---------|
| `path` | A `{name}` capture in the binding's [TomOperationBinding.path]. |
| `query` | A query-string parameter. |
| `body` | A field of the decoded request body. |
| `header` | A request header. |

### TomBindingErrorFormat

The error shape a [TomOperationBinding] renders a failed operation in.

| Value | Meaning |
|-------|---------|
| `resultEnvelope` | The CE-ER `Result` envelope of `codespecs_mapping.md` §7 — the shape the operation's primary binding speaks. |
| `problemJson` | RFC 9457 problem details (`application/problem+json`). |
| `scim` | The SCIM error response of RFC 7644 §3.12. |
| `oauth` | The OAuth 2.0 error response of RFC 6749 §5.2. |

### TomReportValueKind

The value types a report column or parameter may carry.

| Value | Meaning |
|-------|---------|
| `string` | Free text. |
| `integer` | A whole number. |
| `decimal` | A fractional number. |
| `currency` | A monetary amount — a decimal that additionally carries a currency. |
| `date` | A calendar date with no time component. |
| `dateTime` | A point in time. |
| `boolean` | A truth value. |
| `enumeration` | A member of a `domainEnum` domain enum. |
| `entityRef` | A reference to a CE-DB entity, carried as its identity. |

### TomReportMeasureFunction

The aggregate a [TomReportMeasure] computes.

| Value | Meaning |
|-------|---------|
| `count` | The number of rows, or of non-null values of the measured column. |
| `sum` | The total of the measured column across the group. |
| `avg` | The mean of the measured column across the group. |
| `min` | The smallest value of the measured column in the group. |
| `max` | The largest value of the measured column in the group. |

### TomReportDeliveryChannel

How a rendered report reaches its audience.

| Value | Meaning |
|-------|---------|
| `apiResponse` | Returned inline from the report's own CE-API operation. |
| `fileExport` | Rendered to a file and stored, for later download. |
| `email` | Rendered and mailed, resolved as a CE-NT notification type. |

### TomReportChartKind

The chart forms a report may declare.

| Value | Meaning |
|-------|---------|
| `bar` | Categorical comparison as bars. |
| `line` | A trend across an ordered axis. |
| `pie` | Part-to-whole as circular segments. |
| `donut` | Part-to-whole with a hollow centre. |
| `scatter` | Two measures plotted against each other as points. |
| `gauge` | A single measure against a target or range. |
| `heatmap` | A measure across two dimensions, encoded as colour intensity. |

## Global Functions and Constants

The package declares none.
