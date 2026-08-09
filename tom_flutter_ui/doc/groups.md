# Groups Module

`groups/` is the **collective-visibility** layer of `tom_flutter_ui`. A group
controls the authorization of a whole region of related widgets without putting
an id (and an auth rule) on every leaf: tag the widgets with one
`TomUIGroup`, and the group's resolved state flows into each member according to
the group's mode.

The module is deliberately thin. The group *implementation*
(`TomAuthorizationGroup`) lives in `tom_core_kernel`; `groups/` adds the
backward-compatible `TomUIGroup` typedef and the `TomWidgetMixin` that wires the
Tom UI concerns (id, group, authorization, resources) into widgets that extend
Flutter widgets directly.

## Table of Contents

- [Overview](#overview)
- [`TomUIGroup`](#tomuigroup)
- [Group modes](#group-modes)
- [`TomWidgetMixin`](#tomwidgetmixin)
- [Effective authorization](#effective-authorization)
- [Scope-aware paths](#scope-aware-paths)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomUIGroup` | typedef | Backward-compatible alias for `TomAuthorizationGroup` (from `tom_core_kernel`). |
| `TomAuthorizationGroup` | class | A group of `TomAuthorizable` members with weak-reference tracking, a mode, and collective auth resolution. |
| `AuthGroupMode` | enum | `controlsAll` / `controlsWidest` / `controlsNarrowest` — how the group's state applies to members. |
| `TomWidgetMixin` | mixin | Gives a Flutter-widget subclass the Tom id/group/auth/resource API; implements `TomAuthorizable`. |

## `TomUIGroup`

`TomUIGroup` is a `typedef` for `TomAuthorizationGroup`; the two names are the
same type. Create a group and pass it to each related widget:

```dart
final shipping = TomUIGroup('shipping'); // default mode: controlsWidest

TomTextField(tomId: 'street', tomGroup: shipping, ...),
TomTextField(tomId: 'city',   tomGroup: shipping, ...),
```

Members are tracked as **weak references**, so a group never keeps a disposed
widget alive; `memberCount`, `members`, and `isEmpty` prune stale entries on
access. `register` / `unregister` (surfaced on widgets as `registerWithGroup` /
`unregisterFromGroup`) manage membership, and `findMember(tomId)` looks one up.

## Group modes

A group resolves its own `authState` from its canonical path
(`<scopePath>.<groupId>`) and then combines it with each member's state via
`applyMode`, governed by `AuthGroupMode`:

| Mode | Rule | Example (group = `read`) |
| ---- | ---- | ------------------------ |
| `controlsAll` | Group state **replaces** the member's state. | `full` → group state |
| `controlsWidest` | Group state is the **ceiling**; members may be narrower, not wider. | `full` → `read`; `disabled` → `disabled` |
| `controlsNarrowest` | Group state is the **floor**; more-restrictive members are lifted. | `disabled` → `read`; `full` → `full` |

State ordering, most to least restrictive: `none` < `disabled` < `read` <
`full`. `controlsWidest` uses `narrow`, `controlsNarrowest` uses `widen`.

For introspection, `mostRestrictive` returns the tightest effective state among
visible members, `isUniform` reports whether all visible members share one
state, and both skip hidden (`none`) members.

## `TomWidgetMixin`

`TomWidgetMixin` is `on Widget implements TomAuthorizable`. Mix it into a widget
that extends a Flutter original to gain:

- `tomId` / `tomGroup` / `scope` / `authorizer` / `uiStateController` hooks,
- `basePath` (the canonical `<scopePath>.<tomId>` path),
- `getAuth()` / `effectiveAuthState`,
- typed resource resolution (`getText`, `resolveColorOrNull`,
  `resolveDoubleOrNull`, `resolveIntOrNull`, `resolveBoolOrNull`,
  `resolveEdgeInsetsOrNull`) via `TomCtr`,
- visual helpers `checkHidden()` and `applyAuthState(context, child)`.

## Effective authorization

`getAuth()` composes the resolution layers in order:

1. **Resource auth** for `basePath` (via `TomAuthorization.resolveAuth`).
2. **Group** (`tomGroup.applyMode`).
3. **Per-widget authorizer** (`authorizer.effectiveAuth`).
4. **Build-time UI state controller** (`uiStateController.apply`, narrows only).

So a field whose resource auth is `full` but whose group resolves to `read`
under `controlsWidest` ends up `read`. The model needs no `BuildContext` — only
the visual `applyAuthState` does (it returns `SizedBox.shrink()` for `none`, a
dimmed `AbsorbPointer` for `disabled`, the read-only style for `read`, and the
child unchanged for `full`).

## Scope-aware paths

Inside a `TomScope`, both member and group paths are prefixed by the scope, so
the same `tomId`/`groupId` resolves to different rules per context:

```dart
TomScope.withScope('checkout', () {
  field.basePath;              // 'checkout.street'
  shipping.resolveGroupPath(); // 'checkout.shipping'
});
```

## Dependencies

- `package:flutter/widgets.dart` — `Widget`, `BuildContext`, the visual
  treatments in `applyAuthState`.
- `package:tom_core_kernel/...` — `TomAuthorizationGroup`, `AuthGroupMode`,
  `TomAuthState`, `TomAuthorization`, `TomAuthorizer`, `TomScope`, `TomCtr`.
- `../theme/tom_theme.dart` — the read-only style for the `read` treatment.

> The group and mixin resolution logic is pure and needs no widget tree (only
> `applyAuthState` does), but the package barrel pulls in `flutter/material`
> (→ `dart:ui`), so run the example under the Flutter toolchain — see
> [`example/groups/groups_example.dart`](../example/groups/groups_example.dart),
> exercised by `flutter test`.
