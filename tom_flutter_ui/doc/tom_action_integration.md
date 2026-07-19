# Tom Action Integration Specification

**Status:** Partially Implemented (core action classes + authorization model)
**Date:** 2026-04-07
**Package:** `tom_flutter_ui` (actions), `tom_core_kernel` (authorization primitives)

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

### Key Classes

| Class | Purpose | Location |
|-------|---------|----------|
| `TomAction<TContext, TUndo>` | Base class for all actions | `tom_flutter_ui` |
| `TomActionController` | Container for related actions | `tom_flutter_ui` |
| `TomActionContext` | Base context available to all actions | `tom_flutter_ui` |
| `TomActionTransaction` | Groups sub-actions for atomic undo | `tom_flutter_ui` |
| `TomActionTrigger` | Connects widgets to actions | `tom_flutter_ui` |
| `TomActionUndo` | Tag interface for undo state objects | `tom_flutter_ui` |
| `TomUndoHistory` | Undo/redo stack management | `tom_flutter_ui` |
| `TomCompositeAction` | Multi-step action with guards | `tom_flutter_ui` |
| `TomDualAction` | Execute/reverse pair | `tom_flutter_ui` |
| `TomAuthState` | Four-state authorization enum (none/disabled/read/full) | `tom_core_kernel` |
| `TomAuthorizer` | Per-widget/action auth modifier | `tom_core_kernel` |
| `TomAuthorizerStrategy` | How authorizer interacts with resource auth | `tom_core_kernel` |
| `TomUIStateController` | Build-time narrowing callback | `tom_core_kernel` |
| `TomAuthorizationGroup` | Group of related authorizables | `tom_core_kernel` |
| `TomAuthorization` | Global singleton for resolving auth state | `tom_core_kernel` |

---

## 2. Action ID System

### Plain IDs — No Prefixes

Action IDs and controller IDs are plain strings — no prefixes are applied. This is consistent with the widget ID system throughout the Tom UI framework.

| Element | Example ID |
|---------|------------|
| Action | `delete`, `save` |
| Action Controller | `orderMgmt`, `userAdmin` |

### Canonical Path Construction

An action's canonical path combines the controller ID with the action ID:

```
<controllerId>.<actionId>
```

**Examples:**
- `orderMgmt.delete` — delete action in orderMgmt controller
- `nav.logout` — global logout action

Every action MUST be part of an ActionController.

### Integration with Widgets

A button widget that triggers an action has its **own** widget path and references the **action's** path:

```
Widget:  shoppingApp.checkout.toolbar.deleteBtn     ← button widget
Action:  shoppingApp.checkout.orderForm.delete      ← form-based action
   or:   orderMgmt.delete                           ← standalone action
```

The button's visibility and resources come from its widget path. The action's authorization comes from its action path.

### Interdependence of Widget and Action Authorization

Widget and action authorization are independent but combine to determine the final button state.

**Authorization values (four-state model):**
- Widget: `none` (hidden), `disabled` (greyed out), `read` (readonly), `full` (editable)
- Action: `full` (triggerable), `disabled` (greyed out), or `none` (hidden) — treat `read` as `disabled`

| Widget Auth | Action Auth | Result |
|-------------|-------------|--------|
| `full` | `full` | Button enabled |
| `full` | `disabled`/`read` | Button disabled |
| `full` | `none` | Button disabled (action exists but unavailable) |
| `read` | any | Button disabled |
| `disabled` | any | Button disabled (greyed out) |
| `none` | any | Button hidden |

**Key insight:** When widget is `full` but action is `none`, the button is **disabled** (visible but greyed out), not hidden. This lets users see that an action exists but is currently unavailable.

### Widget Authorization via `authorizer`

Widgets can link to action authorization via the `authorizer` field:

```dart
TomWidget( 
  authorizer: action.authorizer, 
  onPressed: action.actionTrigger((ctx, tx) => {...}),
);
```

The `authorizer` provides a `TomAuthorizer` that resolves the action's authorization at instantiation time (no BuildContext needed).

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

Action authorization uses `TomAuthorization`:

```dart
extension ActionAuthorization on TomAction {
  bool isAuthorized() {
    bool actionAuth = !TomAuthorization.isProtected(controller.fullPath + '.' + actionId);
    bool groupAuth = group != null ? group.isVisible() : true; // no group -> visible
    return actionAuth && groupAuth;
  }
}
```

This maps directly to the underlying authorization infrastructure found in tom_core_flutter.

### No Lookup Hierarchy

For action `delete` in controller `orderMgmt`:

```
1. orderMgmt.delete          ← controller + action
```

No lookup hierarchy.

### Group-Based Authorization

Actions can belong to groups (same as widgets):

```dart
class DeleteOrderAction extends TomAction<OrderActionContext, Order> {
  @override
  String get actionId => 'delete';
  
  TomAuthorizationGroup? get authorizationGroup;  // shares visibility with other mutations
}
```

Group path: `orders.orderMutations` — hides all members when unauthorized. A group is unauthorized if a single member is not authorized.

---

## 4. Action Declaration

### Base TomAction Class

```dart
abstract class TomAction<TContext extends TomActionContext, TUndo> {
  /// The action's unique ID within its controller scope.
  String get actionId;
  
  /// Optional group membership for collective visibility control.
  TomAuthorizationGroup? group;
  
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

```yaml
# Standalone controller path: orderMgmt.delete
orderMgmt.delete.label: "Delete Order"
orderMgmt.delete.tooltip: "Permanently delete the selected order"
orderMgmt.delete.icon: "delete"
orderMgmt.delete.confirm.title: "Delete Order?"
orderMgmt.delete.confirm.message: "This cannot be undone."

# Form-based controller path: shoppingApp.checkout.orderForm.save
shoppingApp.checkout.orderForm.save.label: "Save Order"
shoppingApp.checkout.orderForm.save.tooltip: "Save changes to the order"
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
  final TomAuthorizer? authorizer;  // NEW: custom authorization
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
    authorizer: saveAction.authorizer,
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

### Popup Menus

Popup menus, dropdown menus, and context menus use the same `actionTrigger()` pattern. Since resource resolution happens at instantiation time (no BuildContext needed), menu items can be created upfront:

```dart
// Popup menu with action items
TomPopupMenuButton(
  tomId: 'orderActions',
  itemBuilder: (context) => [
    TomPopupMenuItem(
      tomId: 'editItem',
      authorizer: editAction.authorizer,
      onTap: editAction.actionTrigger(
        contextBuilder: (_) => OrderActionContext(...),
      ),
      child: Text(editAction.label),  // Resolved at instantiation
    ),
    TomPopupMenuItem(
      tomId: 'deleteItem',
      authorizer: deleteAction.authorizer,
      onTap: deleteAction.actionTrigger(
        contextBuilder: (_) => OrderActionContext(...),
      ),
      child: Text(deleteAction.label),
    ),
  ],
)
```

**Dropdown menus:**

```dart
TomDropdownMenu(
  tomId: 'statusDropdown',
  dropdownMenuEntries: [
    TomDropdownMenuEntry(
      value: 'approve',
      authorizer: approveAction.authorizer,
      onPressed: approveAction.actionTrigger(...),
      label: approveAction.label,
    ),
    TomDropdownMenuEntry(
      value: 'reject',
      authorizer: rejectAction.authorizer,
      onPressed: rejectAction.actionTrigger(...),
      label: rejectAction.label,
    ),
  ],
)
```

**Context menus (right-click):**

```dart
TomContextMenu(
  tomId: 'rowContext',
  actions: [
    TomContextMenuAction(
      tomId: 'copyAction',
      authorizer: copyAction.authorizer,
      onPressed: copyAction.actionTrigger(...),
      child: Row(children: [
        Icon(copyAction.icon),
        Text(copyAction.label),
      ]),
    ),
  ],
)
```

**Key benefit:** All menu items resolve their labels, icons, and authorization at instantiation time. No need to access BuildContext during menu construction.

### Multiple Actions

When a widget is linked to more than one action, use `TomMultiAuthorizer` to combine authorization:

```dart
// Multi-action authorization: button enabled only if ALL actions are authorized
authorizer: TomMultiAuthorizer([
  action1.authorizer,
  action2.authorizer,
])
```

**Multiple callbacks via separate handlers:**

```dart
TomListTile(
  tomId: 'orderRow',
  authorizer: TomMultiAuthorizer([viewAction.authorizer, editAction.authorizer]),
  onTap: viewAction.actionTrigger(
    contextBuilder: (_) => OrderActionContext(...),
  ),
  onLongPress: editAction.actionTrigger(
    contextBuilder: (_) => OrderActionContext(...),
  ),
)
```

**Action sequence via `TomActionSequence`:**

```dart
// Execute multiple actions in sequence
final validateAndSave = TomActionSequence([
  validateAction,
  saveAction,
]);

TomElevatedButton(
  tomId: 'saveBtn',
  authorizer: validateAndSave.authorizer,  // Combined: all must be authorized
  onPressed: validateAndSave.actionTrigger(
    contextBuilder: (_) => FormActionContext(...),
  ),
)
```

**Conditional action selection:**

```dart
// Choose action based on state
TomElevatedButton(
  tomId: 'toggleBtn',
  authorizer: TomMultiAuthorizer([enableAction.authorizer, disableAction.authorizer]),
  onPressed: () {
    final action = isEnabled ? disableAction : enableAction;
    action.execute(context);
  },
)
```

---

## 6. Widgets Requiring Modification

### Implemented (authorizer, scope, and auth model)

The following have been added to **all** Tom widget base classes (`TomNodeBase`, `TomPolicyNodeBase`, `TomFamilyBase`, and `TomWidgetMixin`):

| Parameter | Type | Purpose |
|-----------|------|---------|
| `authorizer` | `TomAuthorizer?` | Per-widget authorization modifier |
| `authorizerStrategy` | `TomAuthorizerStrategy` | How authorizer interacts with resource auth (default: narrowsOnly) |
| `uiStateController` | `TomUIStateController?` | Build-time state narrowing callback |
| `authorizationGroup` | `TomAuthorizationGroup?` | Group membership (replaces old `tomGroup`) |

Authorization resolution order: resource auth → authorizer → uiStateController (each can only narrow).

Four-state build behavior in `TomPolicyNodeBase`:
| State | Visual |
|-------|--------|
| `none` | `SizedBox.shrink()` (hidden) |
| `disabled` | `AbsorbPointer` + 0.38 opacity |
| `read` | Readonly style applied via `TomThemeScope` |
| `full` | Normal interactive content |

### Widgets Still Needed

| Widget | Purpose |
|--------|---------|
| `TomActionButton` | Action-first button that takes a `TomAction` directly |
| `TomActionMenuItem` | Menu item that takes a `TomAction` directly |

### Action Accessors on TomAction

| Accessor | Type | Purpose |
|----------|------|---------|
| `authorizer` | `TomAuthorizer` | Authorization provider for widgets |
| `label` | `String` | Resolved label text |
| `tooltip` | `String?` | Resolved tooltip text |
| `icon` | `IconData?` | Resolved icon |
| `actionTrigger()` | `VoidCallback Function(...)` | Creates callback with context builder |

---

## 7. Widget Catalog by Action Usage

Analysis of all 299 Tom widgets and their relationship to actions.

Actions can be wired to ALL possible events (onChanged, onTap, onPressed, onSelectionChanged, onEnter, onExit).

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
