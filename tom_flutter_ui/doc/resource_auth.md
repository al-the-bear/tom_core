# Resource-Auth Module

`resource_auth/` is the **resource-resolution and authorization** layer of
`tom_flutter_ui`. It answers two questions Tom widgets ask at build time:

1. *"What concrete `Color` / `IconData` does this resource name map to?"* — Tom
   widgets store **names** in resources (`"mRed"`, `"#FF5733"`, `"mSave"`), not
   live Flutter objects. This module turns those names into real `Color` /
   `IconData` through pluggable adapters.
2. *"What authorization state applies here, and what environment/platform am I
   running in?"* — it re-exports the canonical authorization types from
   `tom_core_kernel` and provides the `TomConfigProvider` for environment /
   platform / feature-flag data.

The split is deliberate: **resources are user-facing text** (resolved by
`TomCtr` in `widget_base`), while **colours, icons, and config are technical
data** resolved here.

## Table of Contents

- [Overview](#overview)
- [Colour resolution](#colour-resolution)
- [Icon resolution](#icon-resolution)
- [Configuration: `TomConfigProvider`](#configuration-tomconfigprovider)
- [Authorization re-exports](#authorization-re-exports)
- [Why name → object indirection?](#why-name--object-indirection)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomUIColorAdapter` | interface | Contract: resolve a colour `name` → `Color?`, plus `colorExists`. |
| `TomUIColors` | singleton | Global colour resolver; delegates to the installed adapter. |
| `AllColorsAdapter` | adapter | Resolves named (`mRed`, `cSystemBlue`), hex (`#RRGGBB`), and `rgb()/rgba()` colours; supports custom registration. |
| `TomUIIconAdapter` | interface | Contract: resolve an icon `name` → `IconData?`, plus `iconExists`. |
| `TomUIIcons` | singleton | Global icon resolver; delegates to the installed adapter. |
| `AllIconsAdapter` | adapter | Resolves the full Material + Cupertino icon set; supports custom registration. |
| `MaterialOnlyAdapter` / `CupertinoOnlyAdapter` | adapters | Single-family icon resolvers for smaller bundles. |
| `TomConfigProvider` | singleton | Environment, platform, and feature-flag configuration. |
| `TomEnvironment` / `TomPlatform` | enums | `development`/`staging`/`production`; `mobile`/`web`/`desktop`. |
| `TomAuthState`, `TomAuthorizable`, `TomAuthorization`, `TomAuthorizer`, … | re-exports | The canonical authorization types from `tom_core_kernel`. |

## Colour resolution

`TomUIColors` is a thin global facade over a `TomUIColorAdapter`. Install one at
startup, then resolve names anywhere:

```dart
TomUIColors.adapter = AllColorsAdapter();
TomUIColors.resolveColor('mRed');      // Colors.red
TomUIColors.resolveColor('#FF5733');   // Color(0xFFFF5733)
TomUIColors.resolveColor('rgb(0,128,255)');
```

`AllColorsAdapter` resolves, in order: custom registered colours → hex (`#RGB`,
`#RRGGBB`, `#AARRGGBB`) → `rgb()/rgba()` → the generated Material/Cupertino
palette. With **no adapter installed**, `TomUIColors.resolveColor` returns `null`
and `colorExists` returns `false` — so widgets degrade gracefully rather than
throw. `AllColorsAdapter.registerColors` adds or overrides names at runtime;
`clearCustomColors` undoes that. `TomUIColors.reset()` clears the adapter (test
hygiene).

## Icon resolution

`TomUIIcons` mirrors the colour facade for `IconData`. `AllIconsAdapter` covers
the full generated Material (`m<PascalCase>`) and Cupertino (`c<PascalCase>`)
icon sets; `MaterialOnlyAdapter` / `CupertinoOnlyAdapter` trade coverage for
bundle size by exposing a single family:

```dart
TomUIIcons.adapter = AllIconsAdapter();
TomUIIcons.resolveIcon('mSave');   // Icons.save
TomUIIcons.resolveIcon('cShare');  // CupertinoIcons.share
```

The same graceful-degradation and custom-registration semantics as colours
apply. The original Flutter snake_case names are converted to PascalCase
(`arrow_back` → `mArrowBack`, `left_chevron` → `cLeftChevron`).

## Configuration: `TomConfigProvider`

`TomConfigProvider` carries **technical** data that varies by environment and
platform — distinct from user-facing resources. Initialise it once at startup;
reading `current` before initialisation throws a `StateError` (a deliberate
fail-fast, since config is a hard startup dependency):

```dart
TomConfigProvider.initialize(TomConfigProvider.create(
  environment: TomEnvironment.production,
  platform: TomPlatform.web,
  flags: {'newCheckout': true, 'maxItems': 50},
));

TomConfigProvider.current.isEnabled('newCheckout');   // true
TomConfigProvider.current.feature<int>('maxItems');   // 50
```

`feature<T>` returns the flag value when it matches the requested type (else
`null`); `isEnabled` treats `true`, `'true'`, and `1` as truthy. Flags are stored
unmodifiable.

## Authorization re-exports

`tom_auth_state.dart` does not define new authorization types — it **re-exports**
the canonical set from `tom_core_kernel`
(`security/tom_authorization.dart`): `TomAuthState` (`none` < `disabled` <
`read` < `full`), `TomAuthorizable`, `TomAuthorizationGroup`,
`TomAuthorizationAdapter`, `TomAuthorization`, `TomAuthorizer`,
`TomAuthorizerStrategy`, `TomUIStateController`. Widget code uses these
canonical kernel names directly — there are no UI-specific aliases. Consuming the
auth types through this barrel means widget code imports a single
`tom_flutter_ui` surface rather than reaching into the kernel directly.

## Why name → object indirection?

Storing `"mRed"` / `"mSave"` in resources rather than `Colors.red` / `Icons.save`
keeps the resource layer **pure data** (serialisable, theme-swappable,
authorable without importing Flutter) and defers the binding to Flutter objects
to a single, swappable adapter. An app can re-skin by swapping the adapter or
registering overrides, with zero widget changes.

## Dependencies

- `dart:ui` / `package:flutter/widgets.dart` / `package:flutter/material.dart` /
  `package:flutter/cupertino.dart` — `Color`, `IconData`, and the generated
  palettes/icon sets.
- `package:tom_core_kernel/...` — the re-exported authorization types.

> The colour, icon, and config resolvers are pure logic and need no widget tree,
> but the package barrel pulls in `flutter/material` (→ `dart:ui`), so run the
> example under the Flutter toolchain — see
> [`example/resource_auth/resource_auth_example.dart`](../example/resource_auth/resource_auth_example.dart),
> exercised by `flutter test`.
