# widgets

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The general-purpose widget kit: every common Flutter widget given a Tom wrapper
that adds a `tomId`, the kernel's four-state authorization, and resource-resolved
labels / colours / icons. Each widget exposes `effectiveAuthState`. 273 of the
290 also expose `family` — the other 17 extend a Flutter widget directly and
pick the Tom surface up from `TomWidgetMixin`, so they have no family base to
get `family` from.

Both routes arrive at the same interface, `TomWidgetSurface`, and every one of
the 290 is checked against it:
`test/widgets/widget_conformance_test.dart` constructs the whole kit and
asserts per widget that it reports the id it was given, resolves its own
`basePath` bare and under a scope, reports the family its base fixes, and
answers all four authorization states from that path and no other. A wrapper
added to this folder and not to that suite's registry fails it, so "every
widget carries the Tom surface" is a checked claim rather than a convention.

**Nothing here reads the platform.** A wrapper delegates to exactly one Flutter
widget, and which design language you get is decided by the type you name:
`TomSwitch` wraps `Switch`, `TomCupertinoSwitch` wraps `CupertinoSwitch`, and
neither consults `defaultTargetPlatform`. 35 of the wrappers are Cupertino
ones, but they are not a parallel Material kit — only 11 have a sibling of the
same name without the infix; the other 24 (`TomCupertinoActionSheet`,
`TomCupertinoPicker`, `TomCupertinoPageScaffold`, …) wrap a control Material
has no equivalent for. Picking a design language is the call site's job, and
the census is asserted from the sources by
`test/widgets/widget_family_claims_test.dart`.

`family` has nothing to do with that. It is a `TomWidgetFamily` role tag —
`button`, `input`, `label`, `dialog` — fixed on the base class at compile time,
and it says what a widget is *for*, not what it looks like. The kit's one
runtime Material-vs-Cupertino switch lives in [`forms`](../forms/readme.md),
where `FormFieldFamily` builds either concrete from a single declaration; even
there the caller chooses (by breakpoint, typically), so it is a decision rather
than a probe.

## Key types

| Type | What it is |
| ---- | ---------- |
| `TomElevatedButton` / `TomTextButton` / `TomIconButton` | Authorization-aware buttons |
| `TomText` / `TomRichText` / `TomBadge` / `TomChip` | Resource-bound display widgets |
| `TomCard` / `TomListTile` / `TomColumn` / `TomCenter` / `TomAlign` | Containers & layout |
| `TomCheckbox` / `TomSwitch` / `TomSlider` / `TomAutocomplete` | Inputs & toggles |
| `TomLinearProgressIndicator` / `TomCircularProgressIndicator` | Progress |
| `TomAlertDialog` / `TomBottomSheet` / `TomBanner` | Dialogs & surfaces |
| `TomAnimatedContainer` / `TomAnimatedOpacity` / `TomAnimated…` | Animated variants |
| `TomAclBuilder` | Widget-level entry into the [`advanced_container_layout`](../advanced_container_layout/readme.md) engine |

Every widget accepts the same six base parameters — inherited from
`TomNodeBase` by the 273 that extend a family base, declared by
`TomWidgetMixin` for the other 17 (see
[`widget_base`](../widget_base/readme.md)):

| Parameter | Type | Purpose |
| --------- | ---- | ------- |
| `key` | `Key?` | Flutter's widget key, forwarded unchanged |
| `tomId` | `String?` | Identity; combines with the active scope into `basePath` |
| `tomGroup` | `TomAuthorizationGroup?` | Collective-authorization group membership |
| `scope` | `TomScope?` | Explicit scope override; defaults to `TomScope.current` at construction |
| `authorizer` | `TomAuthorizer?` | Per-widget verdict, combined per its `TomAuthorizerStrategy` |
| `uiStateController` | `TomUIStateController?` | Build-time narrowing callback |

`uiStateController` is the only one of the six that runs at build time rather
than at construction, and the only hook for state the resource layer cannot
know — whether *this* row's record is locked, whether the user owns *this*
item. `effectiveAuthState` composes four layers in order: the resource state
for `basePath`, the `tomGroup` mode, the `authorizer`, then the controller.
The controller runs last so that its "can only narrow" promise holds — a group
applied afterwards would undo the narrowing, because `applyMode` widens under
`controlsNarrowest` and replaces outright under `controlsAll`. The narrowing
is enforced rather than trusted: `TomUIStateController.apply` returns
`currentAuth.narrow(result)`, so a controller that answers `full` for a `read`
widget still yields `read`. The order is pinned by
`test/widget_base/auth_resolution_order_test.dart`.

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void buildWidgets() {
  // Tom widgets resolve through the resource layer; install a provider and the
  // all-colours adapter so explicit values render without a lookup miss.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(const {}),
  );
  TomUIColors.adapter = AllColorsAdapter();

  final button = TomElevatedButton(
    tomId: 'save',
    onPressed: () {},
    child: TomText(text: 'Save'),
  );

  print(button.family); // TomWidgetFamily.button
}
```

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
