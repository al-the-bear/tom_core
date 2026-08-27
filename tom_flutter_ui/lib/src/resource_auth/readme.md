# resource_auth

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The resource and configuration inputs every Tom widget resolves against:
colour and icon namespaces (each backed by a pluggable adapter), the UI
authorization bridge onto the kernel's `TomAuthState`, and a config / environment
provider. Widgets look up colours, icons, and feature flags by name so the same
widget tree renders differently per theme, platform, or environment.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomUIColors` / `TomUIIcons` | Static colour / icon namespaces resolved through an adapter |
| `AllColorsAdapter` / `AllIconsAdapter` | Default adapters; `registerColors` extends the colour set |
| `TomUIColorAdapter` / `TomUIIconAdapter` | The pluggable adapter contracts |
| `TomAuthorization` / `TomAuthorizationAdapter` | The kernel's four-state authorization, re-exported for UI code |
| `TomConfigProvider` | Config / feature-flag provider (`create` + `initialize` + `current`) |
| `TomEnvironment` / `TomPlatform` | Environment & platform enums feeding config + responsive layout |

## Quick start

```dart
import 'package:flutter/widgets.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void wireResources() {
  TomUIColors.adapter = AllColorsAdapter();
  AllColorsAdapter.registerColors({'brandPrimary': const Color(0xFF123456)});

  final red = TomUIColors.resolveColor('mRed');   // Material red
  final hex = TomUIColors.resolveColor('#FF5733'); // literal hex
  // Alpha leads: #AARRGGBB and #ARGB, as in Color(0x...).
  final faded = TomUIColors.resolveColor('#80FF5733'); // 50% orange

  TomConfigProvider.initialize(TomConfigProvider.create(
    environment: TomEnvironment.production,
    platform: TomPlatform.web,
    flags: {'newCheckout': true, 'maxItems': 50},
  ));
  print(TomConfigProvider.current.isEnabled('newCheckout')); // true
}
```

**Hex alpha comes first.** `#AARRGGBB` and `#ARGB` follow Dart's
`Color(0xAARRGGBB)`, not the `#RRGGBBAA` that CSS and design tools emit. The
two are indistinguishable from the string, so a colour pasted from Figma is
misread rather than rejected — `#FF5733AA` becomes an opaque blue-violet and
`colorExists` still answers `true`. Reorder the channels when copying one in.

The four-state `TomAuthState` (hidden / disabled / read-only / editable) is
defined in [`tom_core_kernel`](../../../../tom_core_kernel/README.md) — this
module is the UI-side bridge that honours it.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
