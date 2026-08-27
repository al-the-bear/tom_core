# widgets

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The general-purpose widget kit: every common Flutter widget given a Tom wrapper
that adds a `tomId`, the kernel's four-state authorization, and resource-resolved
labels / colours / icons. Each widget exposes `effectiveAuthState` and renders
Material or Cupertino per the ambient family. 275 of the 292 also expose
`family` — the other 17 extend a Flutter widget directly because their parent
type-checks for it, and so have no family base to get it from.

## Key types

| Type | What it is |
| ---- | ---------- |
| `TomElevatedButton` / `TomTextButton` / `TomIconButton` | Authorization-aware buttons |
| `TomText` / `TomLabel` / `TomBadge` / `TomChip` | Resource-bound display widgets |
| `TomCard` / `TomListTile` / `TomColumn` / `TomCenter` / `TomAlign` | Containers & layout |
| `TomCheckbox` / `TomSwitch` / `TomSlider` / `TomAutocomplete` | Inputs & toggles |
| `TomLinearProgressIndicator` / `TomCircularProgressIndicator` | Progress |
| `TomAlertDialog` / `TomBottomSheet` / `TomBanner` | Dialogs & surfaces |
| `TomAnimatedContainer` / `TomAnimatedOpacity` / `TomAnimated…` | Animated variants |
| `TomAclBuilder` | Widget-level entry into the [`advanced_container_layout`](../advanced_container_layout/readme.md) engine |

Every widget accepts the same base parameters `tomId`, `tomGroup`, `scope`,
`authorizer` and `uiStateController` — inherited from `TomNodeBase` by the 275
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
