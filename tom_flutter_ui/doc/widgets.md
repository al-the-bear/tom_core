# Widgets Module

`widgets/` is the **general widget kit** of `tom_flutter_ui`: roughly 200 thin
Tom wrappers over the Flutter and Cupertino widget set. Each wrapper adds the
Tom concerns — a `tomId`, scope-resolved `basePath`, authorization, group
membership, and resource-driven display values — on top of the Flutter widget
it delegates to, while keeping the familiar Flutter constructor shape.

The wrappers are organised into **21 families**, one Dart file per family
behind the `widgets.dart` barrel. Every wrapper extends its family base class
(`TomButtonBase`, `TomLabelBase`, …) from `widget_base/`, so the whole kit
shares one contract; see [`doc/widget_base.md`](widget_base.md) for the node
hierarchy and the four-state authorization gate that underpins it.

## Table of Contents

- [Overview](#overview)
- [The shared family contract](#the-shared-family-contract)
- [Family catalogue](#family-catalogue)
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

Every widget in the kit is a `TomFamilyBase` subclass and therefore reports the
family it belongs to:

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
| `sliver` | `TomSliverBase` | `TomSliverPadding`, `TomSliverList` family, `TomSliverPersistentHeader`, `TomSliverVisibility` |
| `animated` | `TomAnimatedBase` | `TomAnimatedContainer`, `TomAnimatedOpacity`, `TomAnimatedSwitcher`, `TomHero`, `TomFadeTransition` |
| `effect` | `TomEffectBase` | `TomBackdropFilter`, `TomColorFiltered`, `TomShaderMask`, `TomSelectionArea` |
| `interaction` | `TomInteractionBase` | `TomGestureDetector`, `TomInkWell`, `TomDraggable`, `TomDragTarget`, `TomMouseRegion` |
| `builder` | `TomBuilderBase` | `TomStreamBuilder`, `TomFutureBuilder`, `TomValueListenableBuilder`, `TomLayoutBuilder` |

The `containers/acl/` subfolder additionally hosts `TomAclBuilder<T>`, the
widget-side bridge to the [advanced container layout](advanced_container_layout.md)
engine. (Five further families — `formField`, `dateTimePicker`, `listEditor`,
`masterDetail`, `searchField`, `fileUpload` — belong to the [forms](forms.md)
module, not this kit.)

A handful of wrappers extend a Flutter widget directly and mix in
`TomWidgetMixin` instead of a family base (`TomExpanded`, `TomFlexible`,
`TomSpacer`, the `Tom*PopupMenuItem`/`Tom*DropdownMenuItem` entries) — these
exist because their Flutter originals must be a specific subtype to satisfy
their parent (`Flex`, `PopupMenuButton`, …).

## Resource-driven construction

A wrapper resolves its display values from Tom resources **at construction
time** via `TomCtr`, falling back to an explicit argument when one is given:

```dart
TomText(text: 'Hello');        // explicit — no resource lookup for the text
TomText(tomId: 'app.greeting'); // resolves the label from resources by basePath
```

Nullable resolvers (`TomCtr.intVal`, `TomCtr.textStyle`, …) return `null` when
the key is absent; the `*OrFail` resolvers (e.g. a `TomText` with neither
`text` nor a `label` resource) **throw** so a missing required resource fails
loudly at construction rather than rendering blank. Construction needs a
resource provider installed (`TomTextResourceProvider.setAppResourceProvider`)
but **no** `BuildContext`.

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

Membership in a `TomUIGroup` narrows (or replaces/lifts) the member per the
group mode, and constructing a widget inside `TomScope.withScope('settings', …)`
prefixes its `basePath` (`settings.<tomId>`) — see [groups](groups.md) and
[widget_base](widget_base.md) for the full resolution rules.

## Dependencies

- `package:flutter/material.dart` + `package:flutter/cupertino.dart` — the
  underlying widgets every wrapper delegates to.
- `package:tom_core_kernel/...` — `TomAuthState`, `TomAuthorization`, `TomScope`,
  `TomTextResourceProvider`, and the authorizer/UI-state types.
- `../widget_base/...` — the family base classes, `TomCtr`, and the style
  resolvers; `../groups/...` for `TomUIGroup`; `../theme/...` for the read-only
  style used by the readonly treatment.

> The family tags, `basePath`, `effectiveAuthState`, and resource resolution
> are all pure (no widget tree), but the package barrel pulls in
> `flutter/material` (→ `dart:ui`), so run the example under the Flutter
> toolchain — see [`example/widgets/widgets_example.dart`](../example/widgets/widgets_example.dart),
> exercised by `flutter test`. Visual rendering is covered by the per-widget
> `testWidgets` suites and the `phase1_demo.dart` demo.
