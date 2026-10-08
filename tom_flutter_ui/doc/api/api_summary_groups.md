# tom_flutter_ui API Reference: Groups Module

The public surface of `lib/src/groups/`, as its barrel exports it.

## Overview

Sources: `lib/src/groups/groups.dart`, `lib/src/groups/tom_auth_gate.dart`, `lib/src/groups/tom_widget_mixin.dart`.

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
| `resolve` | `static TomAuthState resolve({ required String? tomId, TomAuthorizationGroup? tomGroup, TomScope? scope, TomAuthorizer? authorizer, TomUIStateController? uiStateController})` | The state a gate with these inputs would apply, without building one. |
| `scope` | `final TomScope? scope` |  |
| `tomGroup` | `final TomAuthorizationGroup? tomGroup` |  |
| `tomId` | `final String? tomId` |  |
| `uiStateController` | `final TomUIStateController? uiStateController` |  |

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
| `registerWithGroup` | `void registerWithGroup()` |  |
| `scope` | `TomScope? get scope` |  |
| `tomGroup` | `TomAuthorizationGroup? get tomGroup` |  |
| `tomId` | `String? get tomId` |  |
| `uiStateController` | `TomUIStateController? get uiStateController` | Optional build-time state controller. |
| `unregisterFromGroup` | `void unregisterFromGroup()` |  |

## Global Functions and Constants

None — this module exports types only.
