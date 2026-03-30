# Tom Widget Required & Positional Parameter Analysis

## Positional Parameters (3) — COMPLETED

All 3 positional params have been converted to named params:

| Class | Old Param | New Param | Type | Status |
|-------|-----------|-----------|------|--------|
| **TomIcon** | `icon` (positional) | `icon` (named) | `IconData?` | ✅ Done |
| **TomText** | `data` (positional) | `text` (named) | `String?` | ✅ Done |
| **TomSelectableText** | `data` (positional) | `text` (named) | `String?` | ✅ Done |

All 3 are nullable and fall back to resource resolution when `null`.

## Required Named Parameters (225 total, across ~130 widgets)

| Category | Count | Could be optional? | Examples |
|----------|-------|---------------------|----------|
| **`child` / `children` / `sliver`** — structural children | ~55 | **No** — widget is meaningless without content | `TomExpanded(child:)`, `TomSliverPadding(sliver:)` |
| **`builder` / `delegate`** — render callbacks | ~25 | **No** — widget can't render without them | `TomFutureBuilder(builder:)`, `TomLayoutBuilder(builder:)` |
| **`duration`** — animation timing | 13 | ✅ **Done** — defaults to 300ms, resource-configurable | All `TomAnimated*` widgets (13 of 15; 2 extend Flutter directly) |
| **`value` / `values` / `selected`** — current state | ~18 | **No** — controlled widgets need state | `TomSwitch(value:)`, `TomSlider(value:)` |
| **`onChanged` / `onReorder` / callbacks** — user must handle | ~12 | ✅ **3 fixed** — removed `required` from nullable callbacks | `TomCupertinoSwitch`, `TomCupertinoSlider`, `TomExpandIcon` |
| **`items` / `destinations` / `segments` / data lists** | ~20 | **No** — widget has nothing to show | `TomNavigationRail(destinations:)`, `TomTabBar(tabs:)` |
| **Date params** (`firstDate`, `lastDate`, `initialDate`) | ~15 | **No** — date pickers need boundaries | `TomCalendarDatePicker` |
| **`content` / `actions`** — dialog content | ~5 | **Some** — `content` could fallback to empty | `TomSnackBar(content:)` |
| **Domain-specific required** (filter, transform, etc.) | ~30 | **No** — meaningless without the core config | `TomBackdropFilter(filter:)`, `TomTransform(transform:)` |
| **Tom-specific** (`id`, `elementProvider`) | 2 | **No** — TomAclBuilder needs both for scoping | `TomAclBuilder(id:, elementProvider:)` |
| **Resource-resolvable candidates** (`label`, `title`, `style`) | ~15 | **See feasibility below** | `TomSnackBarAction(label:)`, `TomNavigationDestination(label:)` |

## Resource-Resolvable Feasibility

| Class | Param | Type | Feasible? | Reason |
|-------|-------|------|-----------|--------|
| `TomSnackBarAction` | `label` | `String` | ❌ No | Extends `SnackBarAction` directly; `super.label` runs before BuildContext |
| `TomTreeNode` | `title` | `Widget` | ❌ No | Data class, not a widget — cannot access BuildContext |
| `TomNavigationDestination` | `label` | `String` | ❌ No | Extends `NavigationDestination` directly; super params pre-BuildContext |
| `TomNavigationDestination` | `icon` | `Widget` | ❌ No | Same — extends Flutter directly |
| `TomNavigationDrawerDestination` | `label` | `Widget` | ❌ No | Extends `NavigationDrawerDestination` directly |
| `TomNavigationDrawerDestination` | `icon` | `Widget` | ❌ No | Same — extends Flutter directly |
| `TomDropdownMenuEntry` | `value` | `T` | ❌ No | Generic business data, not a UI parameter |
| `TomDefaultTextStyle` | `style` | `TextStyle` | ⚠️ Possible | Has `buildContent()` — would need `style` made nullable + resolver |

## Changes Applied

### Callbacks made optional (3 widgets)
- `TomCupertinoSwitch.onChanged` — removed `required` (type already `ValueChanged<bool>?`)
- `TomCupertinoSlider.onChanged` — removed `required` (type already `ValueChanged<double>?`)
- `TomExpandIcon.onPressed` — removed `required` (type already `ValueChanged<bool>?`)

### Duration made optional + resource-configurable (13 widgets)
Default: `Duration(milliseconds: 300)`, overridable via resource key `duration` (int milliseconds).

Widgets: TomAnimatedAlign, TomAnimatedContainer, TomAnimatedCrossFade, TomAnimatedDefaultTextStyle, TomAnimatedFractionallySizedBox, TomAnimatedOpacity, TomAnimatedPadding, TomAnimatedPhysicalModel, TomAnimatedRotation, TomAnimatedScale, TomAnimatedSize, TomAnimatedSlide, TomAnimatedSwitcher.

**Not changed** (extend Flutter directly, `required super.duration`): TomAnimatedPositioned, TomAnimatedPositionedDirectional.
