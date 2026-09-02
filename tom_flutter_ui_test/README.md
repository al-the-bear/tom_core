# tom_flutter_ui_test

A Flutter demo / smoke-test application for the **Tom Flutter UI** library
(`tom_flutter_ui`). It is an internal harness — `publish_to: none` — that
exercises every part of the library against the live Flutter engine: the
Advanced Container Layout (ACL) engine, the Tom-wrapped Material/Cupertino
widget set, the form framework, and the resource / authorization machinery
driven by `tom_core_kernel`.

## What it demonstrates

The app is a four-tab `MaterialApp` (see `lib/main.dart`). Each tab is a list
of `DemoTile`s that open a single full-screen demo:

| Tab | Source | What it shows |
| --- | --- | --- |
| **ACL Demos** | `lib/acl_demos/` | The Advanced Container Layout engine: rows, alignment, expand flags, spacing, min/preferred/max sizing, character-width sizing, reference & cross-row constraints, titled/bordered groups, nested containers, responsive shrink/grow, row breakpoints, and the fluent `AclBuilder` API. |
| **Widget Demos** | `lib/widget_demos/` | 27 widget showcases grouped into Input & Actions, Layout & Structure, Display & Info, Advanced, and Scope & Architecture — the Tom wrappers over buttons, inputs, selection, toggles, sliders, cards, tables, navigation, slivers, animation, effects, plus resource resolution and scoped element providers. |
| **Forms/Actions** | `lib/forms_demos/` | The Tom form framework: `TomForm` field types with validation, selection/boolean variants over a shared `TomSelectableSource`, `TomFormStyleScope` breakpoint overrides, and complex action/authorization gating. |
| **Authorization/Resources** | `lib/widget_demos/demo_21…`, `demo_28…` | Resource resolution (labels/icons/tooltips by `tomId`) and widget authorization (visibility, readonly, `TomAuthorizationGroup`). |

## Running it

```bash
flutter pub get
flutter run            # pick a device/emulator
```

There is **no code-generation step** — unlike the sibling
`tom_flutter_form_test`, this app does not use reflection generation and has no
runtime asset bundle. Demo resources (text, icons, colors) are registered
entirely in Dart by `initializeDemoResources()` (`lib/demo_resources.dart`),
which `main()` calls **before** `runApp` so the first frame resolves every
widget's labels, icons and colors. The persisted UI language is loaded by
`LocaleSettingsService` (`lib/locale_settings.dart`) before the first frame and
can be changed live from the `AppBar` language selector.

## Tests

```bash
flutter test --concurrency=1       # default gate; serial, never parallel
flutter test test/screenshots.dart # on-demand visual-capture harness (not a gate)
```

`test/screenshots.dart` is a manual "rerun and diff the PNGs" tool, deliberately
excluded from the default gate — `flutter test` discovers `*_test.dart` and
nothing else, and neither it nor `demo_harness.dart` carries the suffix. Every
other file under `test/` does, and together they are the automated suite; the
suffix is the whole rule, so no inventory of names is kept here to fall out of
date.

`demo_overflow_test.dart` mounts every demo and fails if any of them overflows
the 1280x2400 viewport — an overflow hides a control the demo exists to show, so
in a gallery of worked examples it is a documentation fault. It shares its mount
with the screenshot harness (`test/demo_harness.dart`) and differs in exactly
one respect: **the gate measures the Ahem placeholder font, the screenshots use
the real SDK fonts.** Ahem's glyphs are full em squares and therefore wider than
Roboto's, which makes the gate the stricter of the two and keeps it reproducible
on machines that have not downloaded the `material_fonts` artifact. A failure's
pixel count is Ahem's, so it overstates what the running app shows; the fault it
points at is real either way. To see it, run the screenshot harness and look for
the striped banner in `test/screenshots/<demo>.png`.

## Project layout

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Entry point, bootstrap ordering, and the four-tab registry. |
| `lib/demo_resources.dart` | Registers the text/icon/color resource adapters consumed by the demos. |
| `lib/locale_settings.dart` | Persisted-locale service + `AppBar` language selector. |
| `lib/acl_demos/` | ACL-engine demos and their scaffolding helpers. |
| `lib/widget_demos/` | Per-category widget demos (`demo_01…demo_28`). |
| `lib/forms_demos/` | Form-framework demos. |
| `lib/common/` | Shared `DemoTile` / `DemoScaffold`. |
| `doc/` | `demo_catalogue.md` (navigation map of every demo) plus developer notes on widget resource parameters and discovery. |
| `test/` | Automated widget suite (including the demo overflow gate), the shared demo mount, and the on-demand screenshot harness. |

## Dependencies

- `tom_flutter_ui` — the library under test (path dependency).
- `tom_core_kernel` — observables, resources, reflection, security.
- `flutter_localizations`, `shared_preferences`, `cupertino_icons`.
