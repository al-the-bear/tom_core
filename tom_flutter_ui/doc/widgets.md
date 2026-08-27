# Widgets Module

`widgets/` is the **general widget kit** of `tom_flutter_ui`: 299 Tom types,
290 of them thin wrappers over the Flutter and Cupertino widget set. Each
wrapper adds the Tom concerns — a `tomId`, scope-resolved `basePath`,
authorization, group membership, and resource-driven display values — on top of
the Flutter widget it delegates to, while keeping the familiar Flutter
constructor shape.

The kit spans **20 sub-folders**, one per widget family, behind the
`widgets.dart` barrel. 273 of the 290 wrappers extend their family base class
(`TomButtonBase`, `TomLabelBase`, …) from `widget_base/`; the other 17 mix in
`TomWidgetMixin` because their Flutter original must stay a specific subtype
(see [Family catalogue](#family-catalogue)). Both routes give the same `tomId`,
`basePath` and authorization contract — only the family tag is exclusive to the
base classes. See [`doc/widget_base.md`](widget_base.md) for the node hierarchy
and the four-state authorization gate that underpins it.

The remaining nine types are *not* widgets: seven are plain classes that hold
widgets (a data cell, a tree node, …) and are documented beside the widget that
takes them, and two — a page route and a static messenger facade — are
catalogued under [Navigation and messaging](#navigation-and-messaging), below
the family table.

## Table of Contents

- [Overview](#overview)
- [The shared family contract](#the-shared-family-contract)
- [Family catalogue](#family-catalogue)
- [Navigation and messaging](#navigation-and-messaging)
- [Resource-driven construction](#resource-driven-construction)
- [Authorization, groups, and scope](#authorization-groups-and-scope)
- [Dependencies](#dependencies)

---

## Overview

| Concern | Where it comes from | Pure-logic? |
| ------- | ------------------- | ----------- |
| Widget family tag (`family` / `families` / `isFamily`) | `TomFamilyBase` (one base per family) | yes |
| `tomId` → `basePath` (scope-prefixed) | `TomNodeBase` | yes |
| `effectiveAuthState` (resource + authorizer + UI-state + group) | `TomPolicyNodeBase` | yes |
| Resource-resolved display values | `TomCtr` (construction-time) | yes (no `BuildContext`) |
| Rendering (`buildContent` / readonly / disabled treatments) | each wrapper | no (needs a tree) |

## The shared family contract

273 of the kit's 290 widgets are `TomFamilyBase` subclasses and therefore
report the family they belong to:

```dart
final button = TomElevatedButton(tomId: 'save', onPressed: save, child: TomText(text: 'Save'));
button.family;                          // TomWidgetFamily.button
button.isFamily(TomWidgetFamily.button); // true
button.families;                         // {TomWidgetFamily.button}
```

`family` is the primary family; `families` (defaulting to `{family}`) supports
multi-family membership, and `isFamily(type)` tests membership. These are plain
getters — no widget tree required.

Through `TomNodeBase` the widget also exposes a `tomId` and a `basePath`
(`<scopePath>.<tomId>`, computed at construction time), and through
`TomPolicyNodeBase` an `effectiveAuthState`. Both resolve without a
`BuildContext`, which is what makes the kit's Tom behaviour unit-testable
without `testWidgets`.

The 17 wrappers that mix in `TomWidgetMixin` instead expose the same `tomId`,
`basePath` and `effectiveAuthState` — the mixin declares them — so only
`family`, `families` and `isFamily` are exclusive to the base classes. Code
that must handle any wrapper should therefore test for `TomFamilyBase` rather
than assume it; the counts here are pinned by
`test/widgets/widget_family_claims_test.dart`, which reads them out of the
sources so this paragraph cannot drift from them.

## Family catalogue

| Family (`TomWidgetFamily`) | Base | Representative widgets |
| -------------------------- | ---- | ---------------------- |
| `button` | `TomButtonBase` | `TomElevatedButton`, `TomTextButton`, `TomOutlinedButton`, `TomFilledButton`, `TomIconButton`, `TomFloatingActionButton`, `TomSegmentedButton`, `TomMenuBar` |
| `input` | `TomInputBase` | `TomTextField`, `TomTextFormField`, `TomSearchBar`, `TomAutocomplete`, `TomSearchAnchor`, `TomCupertinoTextField` |
| `select` | `TomSelectBase` | `TomDropdownButton`, `TomPopupMenuButton`, `TomDropdownMenu`, `TomMenuAnchor`, `TomCupertinoPicker` |
| `toggle` | `TomToggleBase` | `TomSwitch`, `TomCheckbox`, `TomRadio`, `TomSwitchListTile`, `TomCheckboxListTile`, `TomToggleButtons` |
| `slider` | `TomSliderBase` | `TomSlider`, `TomRangeSlider`, `TomCupertinoSlider` |
| `container` | `TomContainerBase` | `TomCard`, `TomScaffold`, `TomAppBar`, `TomContainer`, `TomColumn`, `TomRow`, `TomStack`, `TomExpansionTile` |
| `dialog` | `TomDialogBase` | `TomAlertDialog`, `TomSimpleDialog`, `TomBottomSheet`, `TomTooltip`, `TomCupertinoAlertDialog`, `TomDatePickerDialog` |
| `table` | `TomTableBase` | `TomDataTable`, `TomPaginatedDataTable`, `TomTable`, `TomGridView`, `TomReorderableListView` |
| `label` | `TomLabelBase` | `TomText`, `TomSelectableText`, `TomRichText`, `TomBadge`, `TomListTile`, `TomChip` |
| `image` | `TomImageBase` | `TomIcon`, `TomImage`, `TomCircleAvatar`, `TomFadeInImage`, `TomNetworkImage`, `TomAssetImage` |
| `navigation` | `TomNavigationBase` | `TomNavigationRail`, `TomNavigationBar`, `TomTabBar`, `TomDrawer`, `TomStepper`, `TomPageView` |
| `progress` | `TomProgressBase` | `TomCircularProgressIndicator`, `TomLinearProgressIndicator`, `TomRefreshIndicator`, `TomCupertinoActivityIndicator` |
| `chip` | `TomChipBase` | `TomFilterChip`, `TomChoiceChip`, `TomActionChip`, `TomInputChip`, `TomRawChip` |
| `list` | `TomListBase` | `TomListView`, `TomAnimatedList`, `TomDismissible`, `TomReorderableList`, `TomCupertinoListSection` |
| `tree` | `TomTreeBase` | `TomTreeView`, `TomTreeSliver` |
| `sliver` | `TomSliverBase` | `TomSliverPadding`, `TomSliverFixedExtentList`, `TomSliverPrototypeExtentList`, `TomSliverPersistentHeader`, `TomSliverVisibility` |
| `animated` | `TomAnimatedBase` | `TomAnimatedContainer`, `TomAnimatedOpacity`, `TomAnimatedSwitcher`, `TomHero`, `TomFadeTransition` |
| `effect` | `TomEffectBase` | `TomBackdropFilter`, `TomColorFiltered`, `TomShaderMask`, `TomSelectionArea` |
| `interaction` | `TomInteractionBase` | `TomGestureDetector`, `TomInkWell`, `TomDraggable`, `TomDragTarget`, `TomMouseRegion` |
| `builder` | `TomBuilderBase` | `TomStreamBuilder`, `TomFutureBuilder`, `TomValueListenableBuilder`, `TomLayoutBuilder` |

Twenty rows, twenty sub-folders. The `containers/acl/` subfolder additionally
hosts `TomAclBuilder<T>`, the widget-side bridge to the
[advanced container layout](advanced_container_layout.md) engine.
`TomWidgetFamily` declares six further values — `formField`, `dateTimePicker`,
`listEditor`, `masterDetail`, `searchField`, `fileUpload` — which have no row
here because they have no branch base and no widget reports them, in this kit
or anywhere else. They are reserved for the [forms](forms.md) module, but
forms does not use the enum today; see
[widget_base.md](widget_base.md#the-widget-family-taxonomy).

**Seventeen wrappers have no row here**, because they extend a Flutter widget
directly and mix in `TomWidgetMixin` instead of a family base. They exist
because their Flutter original must remain a specific subtype for the parent
that accepts it — `Flex` type-checks for `Flexible`, `PopupMenuButton` for
`PopupMenuEntry`, `TabBar` for `Tab`, and so on — so a Tom base class cannot be
inserted above them. In full: `TomAnimatedPositioned`,
`TomAnimatedPositionedDirectional`, `TomCheckedPopupMenuItem`,
`TomCupertinoTabView`, `TomDropdownMenuItem`, `TomExpanded`, `TomFlexible`,
`TomNavigationDestination`, `TomNavigationDrawerDestination`,
`TomPopupMenuDivider`, `TomPopupMenuItem`, `TomRefreshProgressIndicator`,
`TomSnackBar`, `TomSnackBarAction`, `TomSpacer`, `TomTab`, `TomTableCell`.

**A further nine types under `widgets/` are not widgets at all** and so cannot
report a family either: `TomDialogs` and `TomMessenger` are static facades,
`TomPageRoute` is a route, and `TomAclBuilder`, `TomDataCell`, `TomDataColumn`,
`TomDataRow`, `TomExpansionPanel` and `TomTreeNode` are plain classes that hold
widgets without being one. Four of the nine — `TomDataCell`, `TomDataColumn`,
`TomDataRow` and `TomExpansionPanel` — nonetheless carry `tomId`/`tomGroup` and
are gated through `TomAuthGate`, which wraps the slot they own; see
[Authorization, groups, and scope](#authorization-groups-and-scope).

273 + 17 + 9 = 299.

## Navigation and messaging

Two of the nine non-widgets are documented here rather than beside the type
they hold, because they exist for the same reason the wrappers do: to give a
Flutter *mechanism* — a route push, a messenger — a Tom-owned surface, so a
screen does not have to reach past the framework.

**`TomPageRoute<T>`** (`navigation/tom_page_route.dart`) is a
`MaterialPageRoute` that carries the active `TomScope` across a push. Flutter
builds a route's child lazily — inside the `Navigator`'s build, not at the push
site — so a screen pushed with a raw `MaterialPageRoute` captures whatever
scope is current *there* (normally `TomScope.defaultScope`) and silently drops
the one that was active when the push happened. `TomPageRoute` captures
`TomScope.current` at construction and re-enters it around the builder, so the
pushed screen resolves its resources and identity against the pushing scope.
Pass `scope:` to override the captured one.

```dart
Navigator.of(context).push(
  TomPageRoute<bool>(builder: (_) => DetailScreen(item: item)),
);
```

**`TomMessenger`** (`dialogs/tom_messenger.dart`) is an `abstract final` class —
a static facade, no state — over `ScaffoldMessenger`. Every method forwards to
the ambient messenger:

| Method | Behaviour |
| ------ | --------- |
| `showSnackBar(context, snackBar)` | `ScaffoldMessenger.of` — **throws** when none is in scope. |
| `showSnackBarIfPresent(context, snackBar)` | `ScaffoldMessenger.maybeOf` — a no-op returning `null` instead. |
| `showMessage(context, message)` | Wraps the string in a `TomSnackBar`/`TomText`, the one-line case. |

```dart
TomMessenger.showSnackBar(context, TomSnackBar(tomId: 'saveSuccess'));
TomMessenger.showMessage(context, 'Saved.');
```

Reach for `showSnackBarIfPresent` from code paths that may run without a
surrounding `Scaffold` — a field callback, for instance.

## Resource-driven construction

A wrapper resolves its display values from Tom resources **at construction
time** via `TomCtr`, falling back to an explicit argument when one is given:

```dart
TomText(text: 'Hello');        // explicit — no resource lookup for the text
TomText(tomId: 'app.greeting'); // resolves the label from resources by basePath
```

Nullable resolvers (`TomCtr.intVal`, `TomCtr.textStyle`, …) return `null` when
the key is absent. The `*OrFail` resolvers are for values a widget structurally
requires — but what counts as missing differs by type, and only three of the
four throw for an absent resource:

```dart
TomText();                      // throws — no text and no tomId, nothing to look up
TomText(tomId: 'app.greeting'); // no `app.greeting.label` resource: renders
                                // 'app.greeting.label', it does not throw
TomOpacity(tomId: 'fade');      // no `fade.opacity` resource: throws
```

`textOrFail` returns the key rather than throwing once a `tomId` is present —
deliberately, so a missing translation is visible on screen — while
`colorOrFail`, `doubleOrFail` and `intOrFail` throw for an absent resource as
well as an absent `tomId`. The full matrix is in
[widget_base.md](widget_base.md#resource-resolution-tomctr).

What a *widget* does with a missing text resource is not read off that matrix,
though, because each call site composes the resolver, and the wrappers use
three compositions. Which one a property gets follows from whether the
underlying Flutter widget can do without it:

| Composition | Used for | No `tomId` | `tomId`, no resource |
| --- | --- | --- | --- |
| `x ?? textOrFail(basePath, k)` | a value the widget cannot render without — `TomText.text`, a `TextField` label, `TomTooltip.message` | throws | renders `'<basePath>.<k>'` |
| `x ?? (tomId != null ? textOrFail(basePath, k) : null)` | a value Flutter itself treats as optional — every hint/placeholder, semantic labels, dialog titles | `null`, no lookup | renders `'<basePath>.<k>'` |
| `x ?? textOrFail(basePath, k, supersededBy: w)` | a string paired with a widget slot that renders instead of it — `TomElevatedButton.child` beside `label`, `TomListTile.title` beside `titleText` | `''` when `w` is non-null, else throws | `''` when `w` is non-null, else the key |

So the visible failure for a missing text resource is the key painted where the
text belongs — never a blank, and never a crash once a `tomId` is present.
`nope.label` renders at the right size in the right place and reads like a
label, so it is easy to miss in review; treat a key on screen as the signal
that a resource was never registered.
`test/widgets/missing_text_resource_test.dart` pins all three compositions.

Construction needs a resource provider installed
(`TomTextResourceProvider.setAppResourceProvider`) but **no** `BuildContext`.

## Authorization, groups, and scope

`effectiveAuthState` composes, in order: resource auth for `basePath`, the
`tomGroup` mode, the per-widget `authorizer`, and the build-time
`uiStateController` (narrows only). At render time `TomPolicyNodeBase` maps the result —
`none` → `SizedBox.shrink`, `disabled` → greyed `AbsorbPointer`, `read` → the
read-only style, `full` → the content. The resolution itself is pure:

```dart
TomAuthorization.adapter = myAdapter; // 'save' → read
TomElevatedButton(tomId: 'save', …).effectiveAuthState; // TomAuthState.read
```

Membership in a `TomAuthorizationGroup` narrows (or replaces/lifts) the member per the
group mode, and constructing a widget inside `TomScope.withScope('settings', …)`
prefixes its `basePath` (`settings.<tomId>`) — see [groups](groups.md) and
[widget_base](widget_base.md) for the full resolution rules.

A handful of wrappers cannot be policy nodes at all — `TomDataCell`,
`TomDataColumn`, `TomDataRow` and `TomExpansionPanel` extend Flutter classes
that are not widgets, and `TomSnackBar`, `TomSnackBarAction`,
`TomAnimatedPositioned` and `TomAnimatedPositionedDirectional` extend widgets
whose `State` is framework-private. They accept the same four inputs
(`tomId`/`tomGroup`/`scope`, `authorizer`, `uiStateController`) and put a
[`TomAuthGate`](groups.md#tomauthgate) in the slot they own, so they compose
the same four layers and get the same four treatments — a `disabled` cell is
dimmed and unclickable, not merely visible. The two whose extent Flutter fixes
before they can hide report instead of rendering: filter `TomDataRow` and
`TomDataColumn` on `isVisible`, and `TomMessenger` declines a `none`
`TomSnackBar` at the moment of presentation. `TomDataCell.empty` renders
nothing either way but answers `authState` from all four layers like the rest.
`test/widgets/wrapper_auth_layers_test.dart` pins the treatments and both
narrowing layers.

## Dependencies

- `package:flutter/material.dart` + `package:flutter/cupertino.dart` — the
  underlying widgets every wrapper delegates to.
- `package:tom_core_kernel/...` — `TomAuthState`, `TomAuthorization`,
  `TomAuthorizationGroup`, `TomScope`, `TomTextResourceProvider`, and the
  authorizer/UI-state types.
- `../widget_base/...` — the family base classes, `TomCtr`, and the style
  resolvers; `../groups/...` for `TomWidgetMixin`; `../theme/...` for the
  read-only style used by the readonly treatment.

> The family tags, `basePath`, `effectiveAuthState`, and resource resolution
> are all pure (no widget tree), but the package barrel pulls in
> `flutter/material` (→ `dart:ui`), so run the example under the Flutter
> toolchain — see [`example/widgets/widgets_example.dart`](../example/widgets/widgets_example.dart),
> exercised by `flutter test`. Visual rendering is covered by the per-widget
> `testWidgets` suites and the `gallery_demo.dart` demo.
