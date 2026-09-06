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
| **Widget Demos** | `lib/widget_demos/demo_01…demo_27` | 27 of the 28 screens in `lib/widget_demos/`, grouped into Input & Actions, Layout & Structure, Display & Info, Advanced, and Scope & Architecture — the Tom wrappers over buttons, inputs, selection, toggles, sliders, cards, tables, navigation, slivers, animation, effects, plus resource resolution and scoped element providers. |
| **Forms/Actions** | `lib/forms_demos/` | The Tom form framework: `TomForm` field types with validation, selection/boolean variants over a shared `TomSelectableSource`, `TomFormStyleScope` breakpoint overrides, and complex action/authorization gating. |
| **Authorization/Resources** | `lib/widget_demos/demo_21…`, `demo_28…` | Resource resolution (labels/icons/tooltips by `tomId`) and widget authorization (visibility, readonly, `TomAuthorizationGroup`). |

**28 widget screens, 29 widget tiles.** `lib/widget_demos/` holds
`demo_01…demo_28`, but the Widget Demos tab lists only `demo_01…demo_27`:
`demo_28_authorization.dart` is surfaced from Authorization/Resources instead,
which also repeats `demo_21_resource_resolution.dart` because that screen is the
resource half of the same tab's subject. So the file count (28) and the tab
counts (27 + 2) are both right, and differ by the one screen that appears twice.
`demo_coverage_test.dart` compares tiles to harness entries by runtime type, not
by name, for exactly this reason.

Because a demo can be counted two ways that are both correct, the counts are
given as a pair — screens declared in `lib/`, tiles offered by `lib/main.dart` —
and checked against the source by `tool/check_demo_counts.py`. A tile is
attributed to the folder that declares its screen class, so the two
Authorization/Resources tiles appear in the Widget Demos row rather than in a
row of their own:

<!-- demo-counts:begin -->

| Group | Screens | Tiles | Declared in |
| --- | --- | --- | --- |
| ACL Demos | 26 | 26 | `lib/acl_demos/` |
| Widget Demos | 28 | 29 | `lib/widget_demos/` |
| Forms/Actions | 5 | 5 | `lib/forms_demos/` |

<!-- demo-counts:end -->

That is **59 demo screens and 60 demo tiles**. A screen is a top-level class
whose name ends in `Demo`; counting files instead gets the Forms/Actions row
wrong, because `lib/forms_demos/` packs its five demos into two files.

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
flutter test                       # default gate
flutter test test/screenshots.dart # on-demand visual-capture harness (not a gate)
```

Two files under `test/` deliberately lack the `_test.dart` suffix, which is how
`flutter test` discovers suites, and so are not part of the gate:
`screenshots.dart` is a manual "rerun and diff the PNGs" tool that asserts
nothing, and `demo_harness.dart` is the shared demo mount both it and the
overflow gate build on. Everything else is a gate, and this is all of it:

<!-- test-inventory:begin -->

| Suite | What it asserts |
| --- | --- |
| `package_compiles_test.dart` | `dart analyze` reports no errors under `lib/` or `test/` — the one check that still runs when the package does not compile, because it shells out instead of importing. |
| `demo_overflow_test.dart` | Every demo mounts in a 1280×2400 viewport without overflowing — one test per slug in `demos`. |
| `demo_coverage_test.dart` | The harness can construct every screen the app actually offers, compared by runtime type across all four tabs. |
| `demo_icon_names_test.dart` | Every `*.icon` name in `demo_resources.dart` resolves through `TomUIIcons` — an unknown name renders nothing and reports nothing, so only a gate catches it. |
| `demo_04_radio_group_test.dart` | The five radio groups in `demo_04_toggles.dart` start on their seed and move independently — wiring a missing `RadioGroup` ancestor would break silently. |
| `demo_scaffold_test.dart` | `DemoTile.onTap` pushes a `DemoScaffold` route, and the RTL switch re-wraps the body in `Directionality` + `AclDirectionScope`. |
| `forms_demos_logic_test.dart` | The validate → save → commit gate, the shared-source item swap, the boolean lock-step guard, and the 600 px breakpoint branching. |
| `forms_dispose_test.dart` | Each of the five demo `State` classes releases what it owns on unmount — fields, observers, and the shared broadcast controller. |
| `locale_settings_test.dart` | `AppLocales.find()`'s three-tier fallback, `initialize()` idempotency, the corrupt-prefs guard, and notify-before-write persistence. |
| `resizable_box_test.dart` | 1:1 drag deltas on the right / bottom / corner handles, the 100 px minimum clamps, and first-drag intrinsic-height seeding. |
| `widget_demos_logic_test.dart` | `DemoAuthorizationAdapter.resolveAuth`'s exact-then-parent-walk resolution, and `createPlaceholderBytes` as a pure PNG generator. |
| `widget_test.dart` | The app builds and the tab shell renders. |
| `debug_shrink_test.dart` | Panel 4 of `size_constraints` shrinks cleanly from 800 px down to 300 px, and the only exception on the way is the by-design overflow below the 328 px minimum floor. |

<!-- test-inventory:end -->

That table is checked against the directory by
`tom_ai/core/tool/check_test_inventories.py`, which fails on a suite that runs
but is unlisted and on a name listed here that no longer exists. It is gated
because the untrue version of this section was worse than none: it named five
suites as though they were all of them, and the six it left out were the whole
of the coverage the last cleanup pass added.

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
| `lib/locale_settings.dart` | `LocaleSettingsService` (persisted locale) and the `LanguageSelectorButton` that `lib/main.dart` mounts in the app bar. |
| `lib/acl_demos/` | ACL-engine demos and their scaffolding helpers. |
| `lib/widget_demos/` | Per-category widget demos (`demo_01…demo_28`). |
| `lib/forms_demos/` | Form-framework demos. |
| `lib/common/` | Shared `DemoTile` / `DemoScaffold`. |
| `doc/` | `demo_catalogue.md` (navigation map of every demo) plus developer notes on widget resource parameters and discovery. |
| `test/` | The twelve gating suites inventoried under [Tests](#tests), plus the shared demo mount and the on-demand screenshot harness, neither of which the runner picks up. |

## Dependencies

- `tom_flutter_ui` — the library under test (path dependency).
- `tom_core_kernel` — observables, resources, reflection, security.
- `flutter_localizations`, `shared_preferences`, `cupertino_icons`.
