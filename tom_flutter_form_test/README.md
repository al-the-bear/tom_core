# Tom Flutter Form Test

A Flutter demo application for the **Tom Form Framework** — the form widgets and
field system from [`tom_flutter_ui`](../tom_flutter_ui), driven by the resource,
security, and reflection facilities of [`tom_core_kernel`](../tom_core_kernel).

It is a runnable showcase (not a published package — `publish_to: none`) used
to exercise the form stack end to end. The showcase is the visible half; the
other half is the gate under [`test/`](test/), which drives the same screens
and is where a regression in the stack is actually caught. See
[Tests](#tests).

## What it demonstrates

The app opens on a two-tab shell (`RootScreen`):

### Demos tab

The Demos tab lists 33 demos in ten sections.
[`doc/demo_catalogue.md`](doc/demo_catalogue.md) uses the same ten headings
and maps each demo to the `tom_flutter_ui` or kernel feature it validates;
`test/demo_catalogue_sections_test.dart` holds the two to the same headings and
the same demos under each.

- **Phase 1 — Spec-aligned demos** (`Demo A`–`Demo D`): form lifecycle
  (bind / save / discard, pristine behaviour) with sync / async / cross-field
  validation and error banners, authorization & events, nested forms & theming,
  and hide-on-authorization.
- **Phase 2 — Extended field flavours** (`Demo E`–`Demo H`): selection and
  boolean variants, complex breakpoint and authorization scenarios.
- **Phase 2a — Collections & master-detail** (`Demo H-A`–`H-E`): the
  master-detail, expandable-row, editable-table and customer-form patterns.
- **Phase 3 — Numeric, date/time & duration fields** (`Demo I`, `Demo J`).
- **Phase 4 — Enum, object, file & nullable fields** (`Demo K`, `Demo L`):
  enum / object / lookup, files and nullable variants.
- **Phase 5a — Cupertino string + bool + selection** (`Demo M`): Material and
  Cupertino fields side by side.
- **Phase 5b — Cupertino numeric + date/time** (`Demo N`).
- **Phase 5c — Cupertino search/lookup/file + family swap** (`Demo O`,
  `Demo P`): Cupertino search, lookup and file fields, and the
  family swap on a breakpoint.
- **Phase 6 — Non-form custom widgets** (`Demo Q`, `Demo R`): auth / empty /
  overlay, and tree / radio / infinite-scroll selection.
- **Supporting reference demos** (`Demo 1`–`Demo 10`): basic and nested forms,
  authorization, validation, settings, field-layout options, error placement,
  breakpoints, the preset showcase, and central JSON-driven styling.

### Examples tab

Stripped-down, copy-friendly sample code under [`lib/examples/`](lib/examples/)
— the same patterns as the demos but reduced to the minimum needed to read and
reuse (customer forms, master-detail, expandable rows, editable tables,
read-only variants, plus shared scaffolding/resources/authorization helpers).

## How to run

```bash
flutter pub get

# Reflection glue (lib/main.reflection.dart) is generated and committed.
# Only regenerate it when reflected type signatures change:
./reflection_generation.sh   # wraps `dart run tom_reflection_generator --nested`
                             # set DART=/path/to/dart if dart is not on PATH

flutter run                  # on any configured device/emulator
flutter test                 # the gate — see Tests below
```

On startup the app loads `assets/demo_resources.json`, merges in the Examples
section's resource keys, registers them with `TomTextResourceProvider`, and
initializes reflection before `runApp`.

## Tests

```bash
flutter test
```

<!-- test-inventory:counts-begin -->

`flutter test` runs **66** gating suites, every one of them a `*_test.dart`
file under [`test/`](test/):

| Kind | Suites | What they cover |
| --- | ---: | --- |
| Demo interaction tests | 24 | Mount one demo or example screen and drive it, asserting that screen's own behaviour — including validator and debounce behaviour, and overflow-free layout at several viewport sizes |
| Smoke tests | 10 | That every screen of a phase — and, for `widget_test.dart`, the demo list itself — builds and reaches a settled frame. No behaviour beyond "it mounts" |
| Blanket exception sweep | 1 | One case per demo tile: boot the app, scroll the tile into view, tap it, and fail if any framework error fired |
| Regression guards | 13 | One reported defect each, pinned so it cannot come back. The file's opening dartdoc names the report it belongs to |
| Behaviour matrices | 2 | One case per cell of a matrix documented elsewhere, so the table and the behaviour cannot drift apart |
| Widget-family coverage | 1 | The list-form widgets driven directly rather than through a demo screen |
| Golden screenshots | 3 | Rendered pixels against the committed baselines under `test/goldens/` — the five numbered demos, the Examples section, and the ≥1600 px bordered band. These are why `test/fonts/` is checked in |
| Source invariants | 4 | That the committed `lib/main.reflection.dart` still covers the sources it mirrors, that every `formId` / `listId` literal in `lib/` is a usable scope id, and that the demo catalogue and this README group the demos exactly as the Demos tab does |
| Unit tests | 8 | Arithmetic and mapping, with no widget tree |

<!-- test-inventory:counts-end -->

Those figures are gated by `tom_ai/core/tool/check_test_inventories.py`, which
holds every kind, their sum, and the total against the directory itself — so a
suite added or deleted without touching this table fails the build. The table
names no filenames on purpose: sixty-six of them would be the longest section
of this README and still a worse list than `test/`, which is exact by
construction. What the counts buy is the one thing the directory cannot say
about itself, which is that its population is the one somebody wrote down.

**Every file under `test/` ends in `_test.dart`, singular.** `flutter test`
discovers `**_test.dart` only, so a plural `_tests.dart` name is matched by
nothing and reported by nothing — that is not hypothetical here, and it is why
the gate above exists. Three files under `test/` are helpers rather than suites
and are excluded by that same rule: `flutter_test_config.dart` (the per-suite
harness config Flutter loads automatically), `support/test_fonts.dart` and
`support/form_id_sites.dart`. A test whose golden is compared must `await
loadTestFonts()` in `setUpAll`, after reflection is initialized and the resource
provider registered.

**The run is deliberately parallel — do not add `-j 1`.** Serial runs were once
required here on the ground that parallel isolates would corrupt process-global
state: the resource bundle, the authorization adapter, the reflection registry
the forms build. They cannot. `flutter test` gives every suite file its own
`flutter_tester` process, so each file's registrations are its own, and no suite
here opens a socket, writes a file or reaches a database, so there is nothing
outside the process to contend for either. Dropping the flag runs the whole
suite green in about half the time.

## Project layout

| Path | Contents |
| --- | --- |
| `lib/main.dart` | App entry point, resource bootstrap, two-tab shell |
| `lib/main.reflection.dart` | Generated reflection registration, seeded from `lib/main.dart` (do not hand-edit) |
| `lib/demos/` | The Demos-tab catalogue (one file per demo) |
| `lib/examples/` | The Examples-tab stripped-down samples |
| `lib/forms/` | Form definitions shared across demos |
| `lib/panels/` | Reusable panel widgets |
| `lib/state/` | Application/demo state objects |
| `lib/actions/` | Form action handlers |
| `lib/common/` | Shared helpers |
| `assets/demo_resources.json` | Text resources consumed by the demos |
| `test/` | The gating suites, plus the `goldens/`, `fonts/` and `support/` they need |
| `doc/demo_catalogue.md` | Demo/example → upstream feature map and launch guide |

## License

BSD 3-Clause licensed — see [`LICENSE`](LICENSE).
