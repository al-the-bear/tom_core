# Tom Action Integration Specification

**Status:** Design Specification (Not yet implemented)  
**Date:** 2026-04-02  
**Package:** `tom_flutter_ui`

---

## Table of Contents

1. [Overview](#1-overview)
2. [Action ID System](#2-action-id-system)
3. [Action Authorization](#3-action-authorization)
4. [Action Declaration](#4-action-declaration)
5. [Widget Integration](#5-widget-integration)
6. [Action Adapters](#6-action-adapters)
7. [Widget Catalog by Action Usage](#7-widget-catalog-by-action-usage)
8. [Implementation Roadmap](#8-implementation-roadmap)
9. [API Summary](#9-api-summary)

---

## 1. Overview

Actions in the Tom UI framework are the **behavioral counterpart to widgets**. While widgets display and capture data, actions execute business logic. This document specifies how actions integrate with:

- The **ID system** — canonical paths for resource lookup and authorization
- The **authorization system** — visibility control for actions and their triggers
- The **widget system** — 299 Tom widgets that may trigger or display actions

### Design Principles

1. **Actions are stateless** — no mutable instance state survives between invocations
2. **Actions are typed** — context requirements and undo state are declared via generics
3. **Actions are authorized** — visibility is controlled via the global authorization adapter
4. **Triggers are unified** — a button, menu, keyboard shortcut, or context menu triggers the same action
5. **Resources are consistent** — label, icon, tooltip come from the resource adapter

### Key Classes (Specified, Not Yet Implemented)

| Class | Purpose |
|-------|---------|
| `TomAction<TContext, TUndo>` | Base class for all actions |
| `TomActionController` | Container for related actions |
| `TomActionContext` | Base context available to all actions |
| `TomActionTransaction` | Groups sub-actions for atomic undo |
| `TomActionTrigger` | Connects widgets to actions |

---

## 2. Action ID System

### ID Prefixes

| Prefix | Element | Example |
|--------|---------|---------|
| `a-` | Action | `a-delete`, `a-save` |
| `ac-` | Action Controller | `ac-orderMgmt`, `ac-userAdmin` |

### Canonical Path Construction

An action's canonical path combines the actioncontroller with the action ID:

```
ac-<controller>.a-<action>
```

**Examples:**
- `ac-orderMgmt.a-delete` — delete action in orderMgmt controller on orders route
- `ac-nav.a-logout` — global logout action (no route)

Every action MUST be part of an ActionController.

### Integration with Widgets

Actions and widgets don't share scope inheritance but use different prefixes. A button widget that triggers an action has its **own** widget ID and the **action's** action ID:

```
Widget:  r-orders.c-toolbar.w-deleteBtn     ← button widget
Action:  ac-orderMgmt.a-delete              ← action being triggered
```

The button's visibility and resources come from its widget path. The action's authorization and resources come from its action path, which is always of the structure: $actioncontroller-id.$action-id.

### Interdependence of Widget and Action Authoriuztion

A widget can be authorized while its action is not (button visible but disabled), or vice versa (button hidden because unauthorized). The two authorization checks are independent, but are combined:

| Widget Auth | Action Auth | Result |
|-------------|-------------|--------|
| Visible | Visible | Button visible, enabled |
| Visible | Hidden | Button disabled |
| Hidden | Visible | Button hidden |
| Hidden | Hidden | Button hidden |

### Extending TomNodeScope

To support action paths, extend `TomNodeScope` with controller awareness:

```dart
class TomNodeScope extends InheritedWidget {
  // ... existing fields ...
  final CustomAuthorization? authorizor;  // NEW: custom authorization
  
}
```

This can then be used to link the Widget to the action authorization:

```dart
TomWidget( 
    authorizor = action.authorizor, 
    onPressed = action.actionTrigger( (bc, tx) => {...} )
    
    );
```

### TomIdPrefix Additions

```dart
class TomIdPrefix {
  // ... existing ...
  static const action = 'a-';
  static const actionController = 'ac-';
}
```

---

## 3. Action Authorization

### Authorization Differences from Widgets

| Aspect | Widgets | Actions |
|--------|---------|---------|
| Visible | Yes | Yes |
| Readonly | Yes (inputs become non-editable) | No — actions are either visible or hidden |
| Disabled | Business logic (`canExecute()`) | Business logic (`canExecute()`) |

Actions have no "readonly" state because an action either can be triggered or cannot. The `canExecute()` method handles business-rule disabling (e.g., "can't delete a shipped order").

### Authorization Resolution

Action authorization uses the a new `TomActionAuthorization` singleton as widgets:

```dart
extension ActionAuthorization on TomAction {
  bool isAuthorized() {
    bool actionAuth = !TomActionAuthorization.isProtected($controllerId.$actionId);
    bool groupAuth = group!=null ? group.isVisible() : true; // no group -> visible
    return actionAuth && groupAuth;
  }
  
}
```

This maps directly to the underlying authorization infrastructure found in tom_core_flutter.

### No Lookup Hierarchy

For action `a-delete` in controller `ac-orderMgmt`:

```
1. ac-orderMgmt.a-delete          ← controller + action
```

No lookup hierarchy.

### Group-Based Authorization

Actions can belong to groups (same as widgets):

```dart
class DeleteOrderAction extends TomAction<OrderActionContext, Order> {
  @override
  String get actionId => 'delete';
  
  TomGroup? get group;  // shares visibility with other mutations
}
```

Group path: `r-orders.g-orderMutations` — hides all members when unauthorized. A group is unauthorized if a single member is not authorized.

---

## 4. Action Declaration

### Base TomAction Class

```dart
abstract class TomAction<TContext extends TomActionContext, TUndo> {
  /// The action's unique ID within its controller scope.
  String get actionId;
  
  /// Optional group membership for collective visibility control.
  TomGroup? group;
  
  /// Back-reference set during initialization
  TomActionController controller;
  
  /// Whether this action can currently execute.
  bool canExecute(TContext context);
  
  /// Executes the action. Returns undo state if undoable.
  TUndo? execute(TContext context, TomActionTransaction tx);
  
  /// Whether this action supports undo.
  bool get isUndoable => false;
  
  /// Reverses the action using saved undo state.
  void undo(TUndo undoState) {
    throw UnsupportedError('Action $actionId does not support undo');
  }
}
```

### TomActionContext

Base context always provides:

```dart
class TomActionContext {
  final TomClass appState;
  final TomRouteContext routeContext; // What is the TomRouteContext? Explain
  final BuildContext? widgetContext; // optional, can be used for custom detection of "canExecute()"
  
  const TomActionContext({
    required this.appState,
    required this.routeContext,
    this.widgetContext, // optional!
  });
}
```

Specific contexts add the state subtree the action operates on:

```dart
class OrderActionContext extends TomActionContext {
  final Order selectedOrder;
  final OrderRepository orderRepo;
  
  OrderActionContext({
    required super.appState,
    required super.routeContext,
    required this.selectedOrder,
    required this.orderRepo,
    super.widgetContext,
  });
}
```

### TomActionController

Controllers group related actions:

```dart
@tomReflect
class OrderController extends TomActionController {
  @override
  String get controllerId => 'orderMgmt';
  
  final create = CreateOrderAction(this);
  final update = UpdateOrderAction(this);
  final delete = DeleteOrderAction(this);
  final archive = ArchiveOrderAction(this);
  
  // Reflection discovers all TomAction fields automatically
}
```

**Reflection sets:**
- Builds the `actions` list, a TomClass always has a map of it's members

**Validation:**
- Validates ID uniqueness within controller constructor

### Action Resources

Actions resolve resources using their canonical path:

```dart
// Path: ac-orderMgmt.a-delete
ac-orderMgmt.a-delete.label: "Delete Order"
ac-orderMgmt.a-delete.tooltip: "Permanently delete the selected order"
ac-orderMgmt.a-delete.icon: "delete"
ac-orderMgmt.a-delete.confirm.title: "Delete Order?"
ac-orderMgmt.a-delete.confirm.message: "This cannot be undone."
```

Sample resource suffixes:

| Suffix | Purpose |
|--------|---------|
| `label` | Button/menu text |
| `tooltip` | Hover tooltip |
| `icon` | Icon name |
| `confirm.title` | Confirmation dialog title |
| `confirm.message` | Confirmation dialog body |
| `error.<code>` | Error message by code |

---

## 5. Widget Integration

### Current Button Implementation

Current buttons use `VoidCallback? onPressed`:

```dart
class TomElevatedButton extends TomButtonBase {
  final VoidCallback? onPressed;
  // This get extended (see above):
  final CustomAuthorization? authorizor;  // NEW: custom authorization
  // ...
}
```



This requires developers to wire authorization, enabled state, and callbacks manually.

### Action-Aware Button Usage

The goal is to optionally bind buttons directly to actions:

```dart
// the widget don't have to aware of their action directly

var button = TomElevatedButton( 
    tomId: "saveButton",
    authorizor: saveAction.authorizor,
    onPressed: saveAction.actionTrigger(
       contextBuilder: (widgetCtx) => OrderActionContext(
            appState: appState,
            routeContext: routeContext,
            selectedOrder: selectedOrder,
            orderRepo: orderRepo,
            widgetContext: widgetCtx,
        ),
       )
    )

```

---

### Popup-Menus and etc.

a similar pattern as above is used to use the standard widgets and integrate them with actions

USER: please fill in!!!

### Multiple actions

if a widget is linked to more than one action, there is a multi-action authorizor:

authorizor = TomMultiAuthorizor([ action1.authorizor, action2.authorizor ]);

widget can link to multiple actions either:

- through multiple callbacks
- using a multi-action callback adaptor

USER: please fill in!!!

---

## 7. Widget Catalog by Action Usage

Analysis of all 299 Tom widgets and their relationship to actions.

Actions can be wired to ALL possible events (onChanged, onTap, onPressed, onSelectionChanged, onEnter, onExit)

USER: update the table to reflect which Widgets/callbacks might needed additional adapter classes (typically additional accessors on TomAction to provide these).

### Primary Action Triggers (39 widgets)

These widgets have `onPressed`, `onTap`, or equivalent handlers that should support action binding:

| Widget | Handler | Action Integration |
|--------|---------|-------------------|
| `TomElevatedButton` | `onPressed` | ✅ Primary candidate |
| `TomTextButton` | `onPressed` | ✅ Primary candidate |
| `TomOutlinedButton` | `onPressed` | ✅ Primary candidate |
| `TomFilledButton` | `onPressed` | ✅ Primary candidate |
| `TomFloatingActionButton` | `onPressed` | ✅ Primary candidate |
| `TomIconButton` | `onPressed` | ✅ Primary candidate |
| `TomMenuItemButton` | `onPressed` | ✅ Primary candidate |
| `TomSubmenuButton` | `onPressed` | ✅ Primary candidate |
| `TomBackButton` | `onPressed` | ⚠️ Navigation action |
| `TomCloseButton` | `onPressed` | ⚠️ Dialog/sheet close |
| `TomExpandIcon` | `onPressed` | ⚠️ Expansion toggle |
| `TomCheckboxMenuButton` | `onChanged` | ⚠️ Toggle, not action |
| `TomRadioMenuButton` | `onChanged` | ⚠️ Selection, not action |
| `TomSegmentedButton` | `onSelectionChanged` | ⚠️ Selection, not action |
| `TomButtonBar` | (contains buttons) | ⚠️ Container |
| `TomMaterialButton` | `onPressed` | ✅ Primary candidate |
| `TomDropdownMenuEntry` | `onPressed` | ✅ Menu action |
| `TomCupertinoButton` | `onPressed` | ✅ Primary candidate |
| `TomCupertinoActionSheetAction` | `onPressed` | ✅ Action sheet item |
| `TomCupertinoDialogAction` | `onPressed` | ✅ Dialog button |
| `TomCupertinoContextMenuAction` | `onPressed` | ✅ Context menu item |
| `TomActionChip` | `onPressed` | ✅ Action chip |

### Secondary Action Triggers (15 widgets)

These trigger actions through tap handlers but are primarily for navigation or selection:

| Widget | Handler | Action Integration |
|--------|---------|-------------------|
| `TomListTile` | `onTap`, `onLongPress` | ⚠️ Navigation/selection |
| `TomCheckboxListTile` | `onTap` | ⚠️ Toggle |
| `TomRadioListTile` | `onTap` | ⚠️ Selection |
| `TomSwitchListTile` | `onTap` | ⚠️ Toggle |
| `TomExpansionTile` | `onTap` | ⚠️ Expansion |
| `TomInkWell` | `onTap`, `onLongPress`, `onDoubleTap` | ✅ Generic action |
| `TomInkResponse` | `onTap`, `onLongPress`, `onDoubleTap` | ✅ Generic action |
| `TomGestureDetector` | multiple | ✅ Generic action |
| `TomMouseRegion` | `onEnter`, `onExit` | ⚠️ Hover, not action |
| `TomTooltip` | `onTriggered` | ⚠️ Display, not action |

### Action Containers (12 widgets)

These contain or coordinate multiple action triggers:

| Widget | Purpose | Action Integration |
|--------|---------|-------------------|
| `TomMenuBar` | Menu system root | Contains `TomMenuItemButton`s |
| `TomMenuAnchor` | Menu popup anchor | Opens menu with actions |
| `TomPopupMenuButton` | Popup menu | Contains `TomPopupMenuItem`s |
| `TomDropdownMenu` | Dropdown menu | Contains `TomDropdownMenuEntry`s |
| `TomContextMenu` | Context menu | Contains actions |
| `TomBottomAppBar` | Toolbar container | Contains action buttons |
| `TomButtonBar` | Button row | Contains action buttons |
| `TomAppBar` | App bar | Leading/trailing actions |
| `TomNavigationBar` | Bottom nav | Navigation actions |
| `TomNavigationRail` | Side nav | Navigation actions |
| `TomStepper` | Step navigation | Next/back actions |
| `TomTabBar` | Tab navigation | Tab switch actions |

### Dialog Actions (14 widgets)

Dialogs with built-in action buttons:

| Widget | Actions | Action Integration |
|--------|---------|-------------------|
| `TomAlertDialog` | OK/Cancel buttons | ⚠️ Typically inline |
| `TomSimpleDialog` | Options | ⚠️ Selection |
| `TomDialog` | Custom | ✅ Custom actions |
| `TomBottomSheet` | Custom | ✅ Custom actions |
| `TomModalBottomSheet` | Custom | ✅ Custom actions |
| `TomDatePickerDialog` | OK/Cancel | ⚠️ Built-in |
| `TomTimePickerDialog` | OK/Cancel | ⚠️ Built-in |
| `TomDateRangePickerDialog` | OK/Cancel | ⚠️ Built-in |
| `TomAboutDialog` | Close | ⚠️ Built-in |
| `TomLicensePage` | Back | ⚠️ Navigation |
| `TomCupertinoAlertDialog` | Actions | ✅ Custom actions |
| `TomCupertinoActionSheet` | Actions | ✅ Custom actions |
| `TomMaterialBanner` | Actions | ✅ Custom actions |
| `TomSnackBar` | Action | ✅ Single action |

### Non-Action Widgets (219 widgets)

These widgets still need to be analyzed, as every callback can be linked to an action if needed:

- **Containers** (~85): Layout, structure, framing
- **Labels** (~10): Text display
- **Inputs** (~15): Data capture (have `onChanged`, not `onPressed`)
- **Toggles** (~10): State toggles (have `onChanged`)
- **Selects** (~10): Selection widgets (have `onChanged`)
- **Sliders** (~3): Value sliders (have `onChanged`)
- **Progress** (~5): Loading indicators
- **Images** (~10): Image display
- **Animated** (~20): Animation wrappers
- **Builders** (~10): Builder patterns
- **Tables** (~5): Data display
- **Slivers** (~20): Scroll view components
- **Trees** (~3): Tree display
- **Effects** (~5): Visual effects
- **Navigation** (~8): Route/tab containers (not triggers)

---

## Related Documents

- [tom_ui_design_architecture.md](../../../_doc/tom/tom_ui_design_architecture.md) — Full UI architecture (§10: Actions)
- [tom_ui_widgets_forms.md](../../../_doc/tom/tom_ui_widgets_forms.md) — Form actions (save, discard, validate)
- [id_system_overhaul.md](id_system_overhaul.md) — ID system design
- [resource_and_authorization_ids.md](../../../_doc/tom/resource_and_authorization_ids.md) — Authorization paths
