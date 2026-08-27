# Groups Module

`groups/` is the **collective-visibility** layer of `tom_flutter_ui`. A group
controls the authorization of a whole region of related widgets without putting
an id (and an auth rule) on every leaf: tag the widgets with one
`TomAuthorizationGroup`, and the group's resolved state flows into each member
according to the group's mode.

The module is deliberately thin. The group *implementation*
(`TomAuthorizationGroup`) lives in `tom_core_kernel` and reaches consumers
through `kernel_types.dart` together with its `AuthGroupMode`, so importing
`tom_flutter_ui` is enough to name both. What `groups/` itself adds is
the `TomWidgetMixin` that wires the Tom UI concerns (id, group, authorization,
resources) into widgets that extend Flutter widgets directly.

## Table of Contents

- [Overview](#overview)
- [`TomAuthorizationGroup`](#tomauthorizationgroup)
- [Group modes](#group-modes)
- [Introspecting a group](#introspecting-a-group)
- [`TomWidgetMixin`](#tomwidgetmixin)
- [Typed resource resolution](#typed-resource-resolution)
- [Effective authorization](#effective-authorization)
- [Scope-aware paths](#scope-aware-paths)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomAuthorizationGroup` | class | A group of `TomAuthorizable` members with weak-reference tracking, a mode, and collective auth resolution. Defined in `tom_core_kernel`, re-exported here. |
| `AuthGroupMode` | enum | `controlsAll` / `controlsWidest` / `controlsNarrowest` — how the group's state applies to members. Re-exported alongside the group. |
| `TomWidgetMixin` | mixin | Gives a Flutter-widget subclass the Tom id/group/auth/resource API; implements `TomAuthorizable`. |

## `TomAuthorizationGroup`

Create a group and pass it to each related widget:

```dart
final shipping = TomAuthorizationGroup('shipping'); // default mode: controlsWidest

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

## Introspecting a group

Every inspection helper reports on **visible** membership: a member whose
`effectiveAuthState` is `none` does not exist from the user's perspective, so
it does not exist for inspection either. `members` is the single place that
filter is applied and every other helper is defined in terms of it, so they
cannot disagree about who is in the group. Registration is the deliberate
exception — `register` / `unregister` work on the raw registrations, so a
hidden member is still tracked and can still be removed.

| Helper | Answer for a group with nothing visible |
| ------ | --------------------------------------- |
| `members` | empty |
| `memberCount` | `0` |
| `isEmpty` / `isNotEmpty` | `true` / `false` |
| `findMember(tomId)` | `null` |
| `isUniform` | `true` |
| `mostRestrictive` | `TomAuthState.none` |

`mostRestrictive` returns the tightest effective state among visible members,
and `none` when there are none. That covers both an empty group and one whose
members are all hidden — to the user those are the same thing, and both show
nothing. It does **not** return `full`, even though `full` is where the
narrowing fold starts: that is the fold's identity element, not a state any
member reported. Leaking it would give the most permissive possible answer for
the one case where the group displays nothing, so a section gated on
`mostRestrictive == full` would treat a fully hidden group as fully editable,
and one gated on `mostRestrictive != none` would render an empty header.

`isUniform` keeps the opposite convention on purpose: "all visible members
share one state" is vacuously true of no members, the same rule
`Iterable.every` follows. When the question is really "does this group have
anything to show?", ask `isEmpty` — that is what it is for.

## `TomWidgetMixin`

`TomWidgetMixin` is `on Widget implements TomAuthorizable`. Mix it into a widget
that extends a Flutter original to gain:

- `tomId` / `tomGroup` / `scope` / `authorizer` / `uiStateController` hooks,
- `effectiveScope` (the explicit `scope`, or `TomScope.current`),
- `basePath` (the canonical `<scopePath>.<tomId>` path),
- `getAuth()` / `effectiveAuthState`,
- [typed resource resolution](#typed-resource-resolution) via `TomCtr`,
- visual helpers `checkHidden()` and `applyAuthState(context, child)`,
- `debugLabel`, a `<RuntimeType>(id: w, group: grp)` description that omits
  whichever of the two is absent. It matches `TomNodeBase.debugLabel`, so a
  widget reads the same way whether it mixes this in or extends the base
  class.

## Typed resource resolution

Seven helpers resolve `<basePath>.<suffix>` through `TomCtr`, so they follow
the widget's scope exactly as `basePath` does. They differ in what they do when
the resource is **not** there, and that difference is the thing to know before
picking one:

| Helper | Returns | If the resource is absent |
| ------ | ------- | ------------------------- |
| `getText(suffix)` | `String` | the resolved key itself, e.g. `'w.label'` — or `''` when the widget has no `tomId` |
| `resolveColorOrNull(suffix)` | `Color?` | `null` |
| `resolveDoubleOrNull(suffix)` | `double?` | `null` |
| `resolveIntOrNull(suffix)` | `int?` | `null` |
| `resolveBoolOrNull(suffix)` | `bool?` | `null` |
| `resolveEdgeInsetsOrNull(suffix)` | `EdgeInsets?` | `null` |
| `resolveDoubleOrFail(suffix)` | `double` | **throws `StateError`** |

`resolveDoubleOrFail` is the only member that can bring a build down, so it is
for values a widget genuinely cannot render without — a size it has no default
for. It throws for three separate reasons, each with its own message: the
widget has no `tomId` (so there is no key to look up), no resource exists at
the key, or the value exists but is not numeric. The `OrNull` siblings answer
`null` to all three, including the unparseable case.

```dart
// tomId: 'w', with no resource installed
widget.resolveDoubleOrNull('size');  // null
widget.resolveDoubleOrFail('size');  // StateError: Tom widget requires either
                                     // an explicit size or a numeric resource
                                     // value at w.size.
```

`getText` is the member whose behaviour the name does *not* announce. It
neither returns `null` nor throws — a miss yields the key back, so an
unresourced label renders as `w.label` on screen instead of silently
disappearing. That is deliberate (it makes a missing translation obvious during
development), but it means `getText` never signals absence in-band; use
`TomCtr.exists` if you need to branch on it.

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

Both the member and the group path are prefixed by the scope, so the same
`tomId`/`groupId` resolves to different rules per context. A scope reaches a
widget in one of two ways, and both prefix both paths.

**Ambient** — the widget is constructed inside the scope's zone, and reads it
from there:

```dart
TomScope.withScope('checkout', () {
  final field = TomTextField(tomId: 'street', tomGroup: shipping);
  field.basePath;              // 'checkout.street'
  shipping.resolveGroupPath(); // 'checkout.shipping'
});
```

**Explicit** — the scope is handed over as a value. This is what the `scope`
constructor parameter is for, and it is the case
[`InScopeBuilder`](../lib/src/widget_base/tom_scope_widgets.dart) exists to
serve: Flutter invokes a builder callback from its own zone, long after the
constructing one has been left, so `TomScope.current` there is the *wrong*
answer and the scope has to travel as an argument instead.

```dart
final checkout = TomScopeBase(scopeId: 'checkout');

// Constructed outside any zone — the scope arrives as an argument.
final field = TomTextField(
  tomId: 'street',
  tomGroup: shipping,
  scope: checkout,
);

field.basePath;                      // 'checkout.street'
shipping.resolveGroupPath(checkout); // 'checkout.shipping'
```

The two forms are interchangeable: `getAuth()` resolves the member and the
group in one frame — `effectiveScope`, which is the explicit `scope` when there
is one and `TomScope.current` otherwise — so the same widget, group and rules
produce the same answer either way.

That single frame is the whole point. The member path and the group path are a
`<prefix>.<id>` pair; if the prefix differed between them, the group would be
looked up at a path that belongs to nobody — or, worse, to a *different*
group of the same name in another scope, whose rule then silently replaces the
ceiling this member was supposed to be under.

`resolveGroupPath()` and `applyMode(state)` both take the scope as an optional
argument and fall back to `TomScope.current`, so a caller standing in the frame
it is asking about passes nothing.

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
