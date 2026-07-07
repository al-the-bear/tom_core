# Tom Flutter Form Test

A Flutter demo application for the **Tom Form Framework** — the form widgets and
field system from [`tom_flutter_ui`](../tom_flutter_ui), driven by the resource,
security, and reflection facilities of [`tom_core_kernel`](../tom_core_kernel).

It is a manual, runnable showcase (not a published package — `publish_to: none`)
used to exercise and visually validate the form stack end to end.

## What it demonstrates

The app opens on a two-tab shell (`RootScreen`):

### Demos tab

A catalogue of 33 demos, grouped into three sections (each mapped to the
upstream feature it validates in [`doc/demo_catalogue.md`](doc/demo_catalogue.md)):

- **Phase 1 — Spec-aligned demos** (`Demo A`–`Demo D`): form lifecycle
  (bind / save / discard, pristine behaviour) with sync / async / cross-field
  validation and error banners, authorization & events, nested forms & theming,
  and hide-on-authorization.
- **Phase 2 — Extended field flavours** (`Demo E`–`Demo R`): selection and
  boolean variants, complex breakpoint and authorization scenarios, the
  master-detail / expandable-row / editable-table / customer-form patterns
  (`Demo H-A`–`H-E`), numeric and date/time/duration forms, enum / object /
  lookup, files & nullable variants, Material-vs-Cupertino fields (basics,
  numeric & date/time, search / lookup / file), family-swap-on-breakpoint,
  auth / empty / overlay, and tree / radio / infinite-scroll selection.
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
./reflection_generation.sh   # wraps `dart run tom_reflection_generator build`

flutter run                  # on any configured device/emulator
```

On startup the app loads `assets/demo_resources.json`, merges in the Examples
section's resource keys, registers them with `TomTextResourceProvider`, and
initializes reflection before `runApp`.

## Project layout

| Path | Contents |
| --- | --- |
| `lib/main.dart` | App entry point, resource bootstrap, two-tab shell |
| `lib/main.reflection.dart` | Generated reflection registration (do not hand-edit) |
| `lib/reflection_init.dart` | Reflection initialization wiring |
| `lib/demos/` | The Demos-tab catalogue (one file per demo) |
| `lib/examples/` | The Examples-tab stripped-down samples |
| `lib/forms/` | Form definitions shared across demos |
| `lib/panels/` | Reusable panel widgets |
| `lib/state/` | Application/demo state objects |
| `lib/actions/` | Form action handlers |
| `lib/common/` | Shared helpers |
| `assets/demo_resources.json` | Text resources consumed by the demos |
| `doc/demo_catalogue.md` | Demo/example → upstream feature map and launch guide |

## License

BSD 3-Clause licensed — see [`LICENSE`](LICENSE).
