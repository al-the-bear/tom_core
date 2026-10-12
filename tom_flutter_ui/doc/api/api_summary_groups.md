# tom_flutter_ui API Reference: Groups Module

The public surface of `lib/src/groups/`, as its barrel exports it.

## Overview

Sources: `lib/src/groups/groups.dart`, `lib/src/groups/tom_auth_gate.dart`, `lib/src/groups/tom_group_membership.dart`, `lib/src/groups/tom_widget_mixin.dart`.

## Classes

### TomAuthGate

**Kind:** `class`

Applies Tom authorization to a subtree that cannot apply it itself.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `authorizer` | `final TomAuthorizer? authorizer` |  |
| `build` | `Widget build(BuildContext context)` |  |
| `child` | `final Widget child` | The subtree this gate governs. |
| `joinsGroup` | `final bool joinsGroup` | Whether this gate is a member of [tomGroup] while mounted. |
| `resolve` | `static TomAuthState resolve({ required String? tomId, TomAuthorizationGroup? tomGroup, TomScope? scope, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | The state a gate with these inputs would apply, without building one. |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `createElement` | `StatelessElement createElement()` |  |

### TomGroupMemberElement

**Kind:** `mixin`

Keeps the element's widget registered with its [TomAuthorizable.tomGroup] for exactly as long as the element is active.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `activate` | `void activate()` | Rejoins the group when the element is reinserted. |
| `deactivate` | `void deactivate()` | Leaves the group when the element leaves the tree. |
| `groupMemberFor` | `TomAuthorizable? groupMemberFor(Widget widget)` | The member to register for [widget], or `null` when it joins no group. |
| `mount` | `void mount(Element? parent, Object? newSlot)` | Joins the group when the element is first mounted. |
| `unmount` | `void unmount()` | Leaves the group, if [deactivate] has not already. |
| `update` | `void update(covariant Widget newWidget)` | Moves the registration from the replaced widget to the new one. |

### TomParentDataGroupMemberElement

**Kind:** `class`

The element of a parent-data Tom widget (`TomExpanded`, `TomFlexible`): a [ParentDataElement] that keeps its widget's group membership — see [TomGroupMemberElement].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `TomParentDataGroupMemberElement` | `TomParentDataGroupMemberElement(super.widget)` | Creates the element for [widget]. |

### TomStatefulGroupMemberElement

**Kind:** `class`

The element of a stateful Tom widget: a [StatefulElement] that keeps its widget's group membership — see [TomGroupMemberElement].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `TomStatefulGroupMemberElement` | `TomStatefulGroupMemberElement(super.widget)` | Creates the element for [widget]. |

### TomStatelessGroupMemberElement

**Kind:** `class`

The element of a stateless Tom widget: a [StatelessElement] that keeps its widget's group membership — see [TomGroupMemberElement].

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `TomStatelessGroupMemberElement` | `TomStatelessGroupMemberElement(super.widget)` | Creates the element for [widget]. |

### TomWidgetMixin

**Kind:** `mixin`

Mixin for Tom widgets that extend Flutter widgets directly.

#### Properties and Methods

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `applyAuthState` | `Widget applyAuthState(BuildContext context, Widget child)` | Applies the appropriate visual treatment based on auth state. |
| `authorizer` | `TomAuthorizer? get authorizer` | Optional per-widget authorizer. |
| `basePath` | `String? get basePath` |  |
| `checkHidden` | `Widget? checkHidden()` | Returns `SizedBox.shrink()` if authorization says hidden, `null` otherwise. |
| `debugLabel` | `String get debugLabel` | Debug description for this widget. |
| `effectiveAuthState` | `TomAuthState get effectiveAuthState` |  |
| `effectiveScope` | `TomScope get effectiveScope` | The scope this widget resolves in: the explicit [scope] when it was given one, otherwise whatever the zone carries. |
| `getAuth` | `TomAuthState getAuth()` | Gets the effective authorization state for this widget. |
| `getText` | `String getText(String suffix)` | Gets a text resource for this widget. |
| `scope` | `TomScope? get scope` |  |
| `tomGroup` | `TomAuthorizationGroup? get tomGroup` |  |
| `tomId` | `String? get tomId` |  |
| `uiStateController` | `TomUIStateController? get uiStateController` | Optional build-time state controller. |

## Global Functions and Constants

None — this module exports types only.
