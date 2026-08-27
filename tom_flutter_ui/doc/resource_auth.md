# Resource-Auth Module

`resource_auth/` is the **resource-resolution and configuration** layer of
`tom_flutter_ui`. It answers two questions Tom widgets ask at build time:

1. *"What concrete `Color` / `IconData` does this resource name map to?"* — Tom
   widgets store **names** in resources (`"mRed"`, `"#FF5733"`, `"mSave"`), not
   live Flutter objects. This module turns those names into real `Color` /
   `IconData` through pluggable adapters.
2. *"What environment / platform am I running in, and which feature flags are
   set?"* — `TomConfigProvider` holds the technical configuration a widget
   resolves against, distinct from user-facing resources.

The split is deliberate: **resources are user-facing text** (resolved by
`TomCtr` in `widget_base`), while **colours, icons, and config are technical
data** resolved here.

## Table of Contents

- [Overview](#overview)
- [Colour resolution](#colour-resolution)
- [Icon resolution](#icon-resolution)
- [Configuration: `TomConfigProvider`](#configuration-tomconfigprovider)
- [Where the authorization types come from](#where-the-authorization-types-come-from)
- [Why name → object indirection?](#why-name--object-indirection)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomUIColorAdapter` | interface | Contract: resolve a colour `name` → `Color?`, plus `colorExists`. |
| `TomUIColors` | singleton | Global colour resolver; delegates to the installed adapter. |
| `AllColorsAdapter` | adapter | Resolves named (`mRed`, `cSystemBlue`), hex (`#RGB`, `#ARGB`, `#RRGGBB`, `#AARRGGBB` — alpha first), and `rgb()/rgba()` colours; supports custom registration. |
| `MaterialOnlyColorAdapter` / `CupertinoOnlyColorAdapter` | adapters | Single-family colour resolvers for smaller bundles. |
| `TomUIIconAdapter` | interface | Contract: resolve an icon `name` → `IconData?`, plus `iconExists`. |
| `TomUIIcons` | singleton | Global icon resolver; delegates to the installed adapter. |
| `AllIconsAdapter` | adapter | Resolves the full Material + Cupertino icon set; supports custom registration. |
| `MaterialOnlyIconAdapter` / `CupertinoOnlyIconAdapter` | adapters | Single-family icon resolvers for smaller bundles. |
| `TomConfigProvider` | singleton | Environment, platform, and feature-flag configuration. |
| `TomEnvironment` / `TomPlatform` | enums | `development`/`staging`/`production`; `mobile`/`web`/`desktop`. |

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
`#ARGB`, `#RRGGBB`, `#AARRGGBB`) → `rgb()/rgba()` → the generated
Material/Cupertino palette. With **no adapter installed**,
`TomUIColors.resolveColor` returns `null` and `colorExists` returns `false` — so
widgets degrade gracefully rather than throw.

> **Hex alpha comes first.** The two alpha-carrying forms are `#AARRGGBB` and
> `#ARGB`, matching Dart's `Color(0xAARRGGBB)`. CSS, Figma, Sketch and web
> palette exports put alpha **last** (`#RRGGBBAA`), and the two orderings are
> indistinguishable from the string alone — so a colour pasted from a design
> tool is not rejected, it is *misread*. `#FF5733AA`, a designer's orange at
> two-thirds alpha, resolves here to an opaque blue-violet, and `colorExists`
> returns `true` for it, so a validation pass over a resource file waves it
> through. Reorder the channels when copying a colour in; there is no way for
> the parser to detect the mistake for you.

`AllColorsAdapter.registerColors` adds or overrides names at runtime;
`AllColorsAdapter.clearCustomColors` undoes that while keeping the adapter
installed.

`MaterialOnlyColorAdapter` / `CupertinoOnlyColorAdapter` trade coverage for
bundle size exactly as their icon counterparts do — an app targeting one
platform stops carrying the other family's table. The second reason matters
more often: with a single-family adapter installed, a stray `cSystemBlue` in a
Material-only resource file resolves to `null` and gets caught, instead of
quietly working. What they drop is the *other family's generated palette* and
nothing else — registrations, hex and `rgb()/rgba()` all still resolve, because
those are syntax rather than a palette. They are a smaller palette, not a
different contract.

`TomUIColors.reset()` / `TomUIIcons.reset()` drop the adapter **and** the
registrations — that pair is the whole test-hygiene hook, so a `tearDown`
needs nothing beside them. Registries are process-global and shared by every
adapter instance, so a registration surviving a `reset()` would not fail a
later test; it would quietly change a colour in it. Reach for `clearCustom*`
only when you want to drop registrations and *keep* the adapter.

`TomUIColors.adapter` / `TomUIIcons.adapter` read as well as write, returning
`null` when nothing is installed — enough for a diagnostics screen or a startup
assertion to ask what is wired. Reading is also what makes a temporary install
reversible:

```dart
final saved = TomUIColors.adapter;
TomUIColors.adapter = MaterialOnlyColorAdapter();
// ...
TomUIColors.adapter = saved;
```

The setter accepts `null` for the sake of that last line: when nothing was
installed to begin with, `saved` is `null`, and the alternative way back —
`reset()` — would take the application's registrations with it. Restoring and
tearing down are different operations, and only one of them is `reset()`.

The palette itself is generated. `tool/generate_colors.dart` reads the Flutter
SDK's own `material/colors.dart` and `cupertino/colors.dart` and emits
`lib/src/resource_auth/tom_colors_generated.dart` — every `Colors` and
`CupertinoColors` constant the SDK declares, in declaration order, keyed
`m<Name>` / `c<Name>` with the swatch shade appended (`mRed`, `mRed500`,
`mRedAccent`, `mRedAccent100`). It parses the SDK source rather than importing
Flutter because it runs under plain `dart`, which has no `dart:ui`; the icon
table is produced the same way by `tool/generate_icons.dart`.

Rerun it after a Flutter upgrade to pick up palette changes:

```bash
dart run tool/generate_colors.dart
```

The output is **reproducible** — no timestamp, and the header's counts are
emitted from the maps — so regenerating an unchanged palette produces no diff,
and a count that moved means the SDK's palette moved. Shades are emitted as
literal values rather than `Colors.red[500]`, which is not a constant
expression; every other entry is an SDK reference, so the dynamic Cupertino
colours still resolve light/dark at lookup time.

## Icon resolution

`TomUIIcons` mirrors the colour facade for `IconData`. `AllIconsAdapter` covers
the full generated Material (`m<PascalCase>`) and Cupertino (`c<PascalCase>`)
icon sets; `MaterialOnlyIconAdapter` / `CupertinoOnlyIconAdapter` trade coverage for
bundle size by exposing a single family:

```dart
TomUIIcons.adapter = AllIconsAdapter();
TomUIIcons.resolveIcon('mSave');   // Icons.save
TomUIIcons.resolveIcon('cShare');  // CupertinoIcons.share
```

The same graceful-degradation semantics as colours apply. The original Flutter
snake_case names are converted to PascalCase (`arrow_back` → `mArrowBack`,
`left_chevron` → `cLeftChevron`).

Custom registration is **module-wide**, not per-adapter, and that holds on both
sides: `AllIconsAdapter.registerIcons` and `AllColorsAdapter.registerColors`
each fill one registry that all three adapters of their family consult *before*
their own table, and `clearCustomIcons` / `clearCustomColors` empty it for all
three. So an app can register its brand icons and then switch to
`MaterialOnlyIconAdapter` for bundle size — the one reason to switch — without
losing them, and a registration overriding a built-in name (`mSave` → a house
icon) overrides it everywhere. What the single-family adapters drop is the
*other family's generated table*, never a registration.

The registration entry points stay on the `All…` adapters even though the
registry they fill is module-wide, so that each family has exactly one place to
register. Reaching for `AllIconsAdapter.registerIcons` while running
`MaterialOnlyIconAdapter` is therefore correct, not a mistake.

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

## Where the authorization types come from

The canonical authorization set — `TomAuthState` (`none` < `disabled` < `read`
< `full`), `TomAuthorizable`, `TomAuthorizationGroup`, `AuthGroupMode`,
`TomAuthorizationAdapter`, `TomAuthorization`, `TomAuthorizer`,
`TomAuthorizerStrategy`, `TomUIStateController` — is declared by
`tom_core_kernel` (`security/tom_authorization.dart`). This module does not
define, alias, or re-export it: widget code uses the kernel names directly, and
they reach a consumer through `lib/src/kernel_types.dart`, the package's single
bridge to the kernel. See [kernel_types.md](kernel_types.md) for the rules that
decide what the bridge carries and the two guards that keep it honest.

What this module *does* own is everything a widget resolves once its
authorization state is known: the colour, icon, and configuration lookups
above.

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

No kernel dependency: every file here imports Flutter and its sibling
generated file, and nothing else.

> The colour, icon, and config resolvers are pure logic and need no widget tree,
> but the package barrel pulls in `flutter/material` (→ `dart:ui`), so run the
> example under the Flutter toolchain — see
> [`example/resource_auth/resource_auth_example.dart`](../example/resource_auth/resource_auth_example.dart),
> exercised by `flutter test`.
