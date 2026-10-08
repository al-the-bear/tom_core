# Tom Flutter UI API Reference: Resource Auth Module

Resource resolution: turning the names a resource bundle stores — `mRed`,
`#FF5733`, `mSave` — into the `Color` and `IconData` a widget renders, plus the
environment and platform facts a resolution may depend on.

## Table of Contents

- [Overview](#overview)
- [Naming](#naming)
- [Class Hierarchy](#class-hierarchy)
- [Colours](#colours)
  - [TomUIColors](#tomuicolors)
  - [TomUIColorAdapter](#tomuicoloradapter)
  - [TomAllColorsAdapter](#tomallcolorsadapter)
  - [TomMaterialOnlyColorAdapter](#tommaterialonlycoloradapter)
  - [TomCupertinoOnlyColorAdapter](#tomcupertinoonlycoloradapter)
- [Icons](#icons)
  - [TomUIIcons](#tomuiicons)
  - [TomUIIconAdapter](#tomuiiconadapter)
  - [TomAllIconsAdapter](#tomalliconsadapter)
  - [TomMaterialOnlyIconAdapter](#tommaterialonlyiconadapter)
  - [TomCupertinoOnlyIconAdapter](#tomcupertinoonlyiconadapter)
- [Configuration](#configuration)
  - [TomConfigProvider](#tomconfigprovider)
  - [TomConfigEnvironment](#tomconfigenvironment)
  - [TomConfigPlatform](#tomconfigplatform)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/resource_auth/resource_auth.dart`, `lib/src/resource_auth/tom_colors.dart`, `lib/src/resource_auth/tom_config_provider.dart`, `lib/src/resource_auth/tom_icons.dart`.

The module `lib/src/resource_auth/` is barrelled by `resource_auth.dart`.

Tom widgets store *names* in their resources, never live Flutter objects. That
is what lets a resource bundle be data — loaded from a file, edited without a
rebuild, shared with tooling that has no Flutter binding. This module is the
layer that resolves those names.

Thirteen exported types in three groups: the colour catalogue, the icon
catalogue — parallel by construction, with the same five types and the same
contract on each side — and the configuration the two resolve against.

**The generated tables are not part of this surface.** 10,739 of the module's
11,346 lines are `tom_colors_generated.dart` and `tom_icons_generated.dart`,
scraped from the Flutter SDK, and the barrel declares both `not-exported`. What
an application needs from them is not their entries but the two facts stated
here: the catalogues resolve against **355 colours** (308 Material, 47
Cupertino) and **10,147 icons** (8,825 Material, 1,322 Cupertino), and a name
is extended by registering, never by editing a table. Listing the entries in
this document would copy a machine-written file into a hand-written one, where
it could only go stale.

## Naming

Both catalogues read a name and hand back an object or `null`.

| Family | Colour | Icon |
| ------ | ------ | ---- |
| Material | `m<ColorName>`, `m<ColorName><Shade>`, `m<ColorName>Accent` | `m<PascalCase>` |
| Cupertino | `c<ColorName>` | `c<PascalCase>` |

The Flutter SDK's `snake_case` icon names become PascalCase: `arrow_back` is
`mArrowBack`, `left_chevron` is `cLeftChevron`.

Colours additionally accept two literal syntaxes, which belong to no family:

- **hex** — `#RGB`, `#ARGB`, `#RRGGBB`, `#AARRGGBB`;
- **rgb** — `rgb(r, g, b)` or `rgba(r, g, b, a)`, clamped.

**Alpha leads in hex**, as in Dart's `Color(0xAARRGGBB)` — not the trailing
alpha (`#RRGGBBAA`) that CSS, Figma and Sketch emit. The two orderings cannot
be told apart from the string: `#FF5733AA` is a designer's orange at two-thirds
alpha and is read here as opaque blue-violet. Nothing detects it, so check the
channel order when copying a colour in from a design tool.

Resolution order is fixed for every colour adapter: **registrations, then
hex/rgb syntax, then the adapter's own palette**. Icons have no literal syntax,
so theirs is registrations then the adapter's table. The order is stated on the
shared base rather than in each adapter, so "registrations win" cannot hold for
one adapter and not another.

## Class Hierarchy

```
TomUIColorAdapter (abstract)          TomUIIconAdapter (abstract)
└── TomAllColorsAdapter                  └── TomAllIconsAdapter
    TomMaterialOnlyColorAdapter              TomMaterialOnlyIconAdapter
    TomCupertinoOnlyColorAdapter             TomCupertinoOnlyIconAdapter

TomUIColors    — the installed colour adapter, statically
TomUIIcons     — the installed icon adapter, statically

TomConfigProvider
├── TomConfigEnvironment
└── TomConfigPlatform
```

## Colours

### TomUIColors

The static entry point. `TomUIColors.adapter` is the installed
`TomUIColorAdapter` and is readable as well as writable — a diagnostics screen
can ask what is wired, and code installing an adapter for one operation can put
the previous one back. `TomUIColors.resolveColor` returns the `Color` or `null`
(including when no adapter is installed), and `TomUIColors.colorExists`
answers `false` in that case rather than throwing.

`TomUIColors.reset` drops the adapter **and** every registration. It is the
whole teardown hook: after it the module holds no state, which is what a suite
needs, because the registry is process-global and a registration left behind
would silently change a colour in every later test.

### TomUIColorAdapter

The contract: `resolveColor(String name)` and `colorExists(String name)`. An
application implements it only to replace the catalogue wholesale; to *extend*
one, register.

### TomAllColorsAdapter

Material and Cupertino together, plus the hex and rgb syntax. The recommended
adapter. It owns the module's two registration statics:
`TomAllColorsAdapter.registerColors` adds or overrides names for **every** adapter
in the module, and `TomAllColorsAdapter.clearCustomColors` drops them while
leaving the installed adapter alone — the narrower tool `TomUIColors.reset`
is the blunt version of.

They are static on this class and module-wide in effect, which is deliberate:
an application that registers its brand colours and then switches to
`TomMaterialOnlyColorAdapter` for bundle size must not lose them, and losing them
would be silent — every registered name would simply resolve to `null`.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `existsInPalette` | `bool existsInPalette(String name)` |  |
| `resolveInPalette` | `Color? resolveInPalette(String name)` |  |

### TomMaterialOnlyColorAdapter

The Material palette only. Two reasons to reach for it: bundle size, and making
a stray `cSystemBlue` in a resource file resolve to `null` and be caught rather
than quietly working. Registrations, hex and rgb all still resolve; only the
Cupertino table is gone.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `existsInPalette` | `bool existsInPalette(String name)` |  |
| `resolveInPalette` | `Color? resolveInPalette(String name)` |  |

### TomCupertinoOnlyColorAdapter

The iOS-facing counterpart, with the same two reasons and the same guarantees.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `existsInPalette` | `bool existsInPalette(String name)` |  |
| `resolveInPalette` | `Color? resolveInPalette(String name)` |  |

## Icons

### TomUIIcons

The static entry point, mirroring `TomUIColors` member for member:
`TomUIIcons.adapter`, `TomUIIcons.resolveIcon`, `TomUIIcons.iconExists` and
`TomUIIcons.reset`, with the same nullability and the same teardown contract.

### TomUIIconAdapter

The contract: `resolveIcon(String name)` and `iconExists(String name)`.

### TomAllIconsAdapter

Material and Cupertino together — the recommended adapter — and the owner of
`TomAllIconsAdapter.registerIcons` and `TomAllIconsAdapter.clearCustomIcons`, which
are the icon side of the same module-wide registry.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `existsInFamily` | `bool existsInFamily(String name)` |  |
| `resolveInFamily` | `IconData? resolveInFamily(String name)` |  |

### TomMaterialOnlyIconAdapter

The Material table only; registrations still resolve.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `existsInFamily` | `bool existsInFamily(String name)` |  |
| `resolveInFamily` | `IconData? resolveInFamily(String name)` |  |

### TomCupertinoOnlyIconAdapter

The Cupertino table only; registrations still resolve.

#### Properties and Methods — further members

| Member | Declaration | Description |
| ------ | ----------- | ----------- |
| `existsInFamily` | `bool existsInFamily(String name)` |  |
| `resolveInFamily` | `IconData? resolveInFamily(String name)` |  |

## Configuration

### TomConfigProvider

Technical configuration, as distinct from resources: resources are user-facing
text, configuration is endpoints, feature flags and platform behaviour that
vary by environment.

Constructed through `TomConfigProvider.create` with an environment, a platform
and an immutable flag map. `TomConfigProvider.initialize` installs the instance
and `TomConfigProvider.current` reads it — **throwing** a `StateError` when
none is installed, rather than returning null, because an application reading
configuration before start-up finished has a bug and not a default.
`TomConfigProvider.reset` uninstalls it, for tests.

`feature<T>(name)` returns the raw value when it is a `T`, and `isEnabled(name)`
reduces it to a bool: `true`, a number equal to `1`, or the strings `true` /
`1` once case and surrounding whitespace are folded. Everything else is
disabled — including `'yes'`, `'on'` and `2`. The tolerance exists because a
flag arrives spelled differently depending on where it was authored (Dart hands
over a `bool`, YAML a `bool` or a `num`, `--dart-define` only text), and the
source must not change the meaning. It stops at spelling, because admitting one
synonym commits the module to a list of them nobody agreed on. A value outside
the vocabulary is not lost: `feature` still reports it unchanged, which is
where anything richer than on/off belongs.

### TomConfigEnvironment

`development`, `staging` or `production`.

### TomConfigPlatform

`mobile`, `web` or `desktop` — the logical platform, not the physical one.

## Global Functions and Constants

None — this module exports types only.
