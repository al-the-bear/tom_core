# widgets

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The general-purpose widget kit: every common Flutter widget given a Tom wrapper
that adds a `tomId`, the kernel's four-state authorization, and resource-resolved
labels / colours / icons. Each widget exposes `effectiveAuthState`. 273 of the
290 also expose `family` — the other 17 extend a Flutter widget directly and
pick the Tom surface up from `TomWidgetMixin`, so they have no family base to
get `family` from.

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

Every widget accepts the same base parameters `tomId`, `tomGroup`, `scope`,
`authorizer` and `uiStateController` — inherited from `TomNodeBase` by the 273
that extend a family base, declared by `TomWidgetMixin` for the other 17 (see
[`widget_base`](../widget_base/readme.md)).

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
