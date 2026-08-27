# resource_auth

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The resource and configuration inputs every Tom widget resolves against: colour
and icon namespaces (each backed by a pluggable adapter) and a config /
environment provider. Widgets look up colours, icons, and feature flags by name
so the same widget tree renders differently per theme, platform, or
environment.

## Key types

All thirteen types the module exports. The colour and icon halves are
deliberate mirrors of each other, so every row names both.

| Type | Responsibility |
| ---- | -------------- |
| `TomUIColors` / `TomUIIcons` | Static colour / icon namespaces resolved through an adapter |
| `TomUIColorAdapter` / `TomUIIconAdapter` | The pluggable adapter contracts |
| `AllColorsAdapter` / `AllIconsAdapter` | The default adapters: registrations first, then the full Material **and** Cupertino tables. Both families' registration entry points live here |
| `MaterialOnlyColorAdapter` / `MaterialOnlyIconAdapter` | Material only — for bundle size, or to make a stray `c…` name resolve to `null` and be caught instead of quietly working |
| `CupertinoOnlyColorAdapter` / `CupertinoOnlyIconAdapter` | Cupertino only; the same two reasons mirrored |
| `TomConfigProvider` | Config / feature-flag provider |
| `TomEnvironment` / `TomPlatform` | Environment & platform enums feeding config + responsive layout |

## Entry points, by lifecycle stage

| Stage | Colours | Icons | Configuration |
| ----- | ------- | ----- | ------------- |
| Install | `TomUIColors.adapter =` | `TomUIIcons.adapter =` | `TomConfigProvider.initialize` of a `TomConfigProvider.create` |
| Inspect | `TomUIColors.adapter` | `TomUIIcons.adapter` | `TomConfigProvider.current` |
| Resolve | `TomUIColors.resolveColor` | `TomUIIcons.resolveIcon` | `TomConfigProvider.current`, then `feature<T>` / `isEnabled` / `environment` / `platform` |
| Probe | `TomUIColors.colorExists` | `TomUIIcons.iconExists` | — |
| Register | `AllColorsAdapter.registerColors` | `AllIconsAdapter.registerIcons` | flags are fixed at `create` |
| Unregister | `AllColorsAdapter.clearCustomColors` | `AllIconsAdapter.clearCustomIcons` | — |
| Tear down | `TomUIColors.reset` | `TomUIIcons.reset` | `TomConfigProvider.reset` |

**Read the last two rows before writing a test.** Each registry is module-wide
and process-global — shared by all three adapters of its family — so a
registration left behind does not fail the next test, it silently changes a
colour or icon in it. `reset()` drops the adapter **and** the registrations,
which is what makes it the whole hygiene hook: a `tearDown` needs nothing
beside it. `clearCustomColors` / `clearCustomIcons` are the narrower tool, for
dropping registrations while *keeping* the installed adapter.

**Inspect and tear down are not the same row either.** `adapter` reads back the
installed adapter, or `null` — which is what lets a caller install one for a
single operation and then put the previous one back (`final saved =
TomUIColors.adapter; … TomUIColors.adapter = saved;`). The setter accepts
`null` precisely so that restore is total: when nothing was installed, `saved`
is `null`, and the only other way back would be `reset()`, which would drop the
application's registrations as collateral. The configuration column differs on
one point — `TomConfigProvider.current` **throws** before `initialize` rather
than returning `null`, because a missing config is a startup bug while a
missing adapter is a supported degraded mode.

**A flag is enabled when it spells `true` or `1`.** `isEnabled` accepts the
boolean `true`, a number equal to `1` (so `1.0` counts), and a string reading
`true` or `1` once case and surrounding whitespace are folded away — because a
flag is spelled differently depending on where it was authored, and
`--dart-define` and environment variables can carry nothing but text. It stops
at spelling: `'yes'`, `'on'` and `2` are **not** enabled, in the same way
`AllColorsAdapter` folds case in `#FFF` syntax without knowing what `crimson`
means. Anything outside the vocabulary is still readable through `feature<T>`.

Registration stays on the `All…` adapters even though the registry it fills is
module-wide, so that each family has exactly one place to register. Calling
`AllIconsAdapter.registerIcons` while `MaterialOnlyIconAdapter` is installed is
therefore correct rather than a mistake — the name still resolves.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void wireResources() {
  TomUIColors.adapter = AllColorsAdapter();
  TomUIIcons.adapter = AllIconsAdapter();
  AllColorsAdapter.registerColors({'brandPrimary': const Color(0xFF123456)});
  AllIconsAdapter.registerIcons({'brandMark': Icons.star});

  final red = TomUIColors.resolveColor('mRed');   // Material red
  final hex = TomUIColors.resolveColor('#FF5733'); // literal hex
  // Alpha leads: #AARRGGBB and #ARGB, as in Color(0x...).
  final faded = TomUIColors.resolveColor('#80FF5733'); // 50% orange
  final save = TomUIIcons.resolveIcon('mSave');   // Icons.save

  TomConfigProvider.initialize(TomConfigProvider.create(
    environment: TomEnvironment.production,
    platform: TomPlatform.web,
    flags: {'newCheckout': true, 'maxItems': 50},
  ));
  print(TomConfigProvider.current.isEnabled('newCheckout')); // true
}

/// One call per namespace, and the module holds no state again.
void tearDownResources() {
  TomUIColors.reset();
  TomUIIcons.reset();
  TomConfigProvider.reset();
}
```

**Hex alpha comes first.** `#AARRGGBB` and `#ARGB` follow Dart's
`Color(0xAARRGGBB)`, not the `#RRGGBBAA` that CSS and design tools emit. The
two are indistinguishable from the string, so a colour pasted from Figma is
misread rather than rejected — `#FF5733AA` becomes an opaque blue-violet and
`colorExists` still answers `true`. Reorder the channels when copying one in.

The four-state `TomAuthState` (hidden / disabled / read-only / editable) is
defined in [`tom_core_kernel`](../../../../tom_core_kernel/README.md) and
reaches consumers through `../kernel_types.dart`. This module resolves what a
widget renders once that state is known; it declares no authorization types of
its own and imports nothing from the kernel.

---

Part of [`tom_flutter_ui`](../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
