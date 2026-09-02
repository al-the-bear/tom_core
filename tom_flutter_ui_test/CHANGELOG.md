## Unreleased — cleanup pass

- **The demo app was the one consumer left behind by the `RadioGroup<T>`
  ancestor migration**, and the omission was larger than it looked.
  `demo_04_toggles.dart` still passed `groupValue:` / `onChanged:` to its five
  radio groups — 18 `undefined_named_parameter` errors — and three uses of the
  kernel's `>>` operator did not resolve. `flutter analyze` reported 21 errors,
  and four test files never loaded as a result, **`demo_overflow_test.dart`
  among them**: the layout gate was not missing four demos, it was measuring
  none. All five groups now sit under a `RadioGroup<String>` that carries the
  selection, and the radios forward only their `value`. Analyze clean.
- **The four Phase-2 forms screens are in the harness** (`demos` in
  `test/demo_harness.dart`: 55 → 59 slugs, all passing the overflow gate).
  `SelectionVariantsDemo`, `BooleanVariantsDemo`, `ComplexBreakpointsDemo` and
  `ComplexAuthDemo` are the widest layouts in the package — Demo G is a
  two-column → one-column collapse — so they were the demos most likely to
  overflow, not the least.
- **`test/demo_coverage_test.dart`** — opens each of the four tabs, reads the
  screen off every `DemoTile` the app builds, and fails when `demos` cannot
  construct one of the same type. Keeping the two in step was a documented
  manual step in the "Adding a demo" procedure, and that is exactly the step
  that was skipped; this replaces the instruction with a failure. The
  comparison is by runtime type, not by slug — a slug is the harness's own name
  and proves nothing about the app.
- **`test/demo_04_radio_group_test.dart`** — pins the migrated wiring, which
  otherwise fails silently: a radio with no `RadioGroup` ancestor still
  compiles, renders unselected and does nothing. Asserts each of the five
  groups starts on its seed and that picking a value moves that group alone.
- README: the test-file inventory named 5 files when 12 exist. Replaced the
  enumeration with the discovery rule (`flutter test` takes `*_test.dart`;
  `screenshots.dart` and `demo_harness.dart` deliberately lack the suffix) so
  no list is kept there to fall out of date.

  Default `flutter test` gate `+116 / 0`, serial (was `+37 / -4`);
  `flutter analyze` clean.

- Follows `tom_flutter_ui`'s removal of the `TomUIGroup` alias: the demo app
  names `TomAuthorizationGroup` throughout. `phase2_demos.dart` also drops its
  `tom_core_kernel` import, which became redundant once `tom_flutter_ui` began
  re-exporting `AuthGroupMode`.
- Documentation: added intent-explaining `// Why:` comments to the bootstrap
  seams (`main.dart` ordering contract, `demo_resources.dart` merge rationale,
  `locale_settings.dart` idempotent-init / notify-before-persist), and a
  feature-naming `///` doc to each of the 26 `acl_demos/` demo classes (the
  widget/forms demos were already documented).
- Added `doc/demo_catalogue.md`: a four-table navigation map (one per tab)
  linking every demo tile → source file → the `tom_flutter_ui` API/widget it
  validates, with the correct launch path (no codegen / no asset bundle) and
  the pre-existing `doc/*.md` widget-resource notes folded in.
- Dead-code removal: deleted the unused `lib/common/demo_widgets.dart`, removed
  the unreferenced `DemoGrid` / common `ExpandingBox` from `demo_scaffold.dart`,
  and dropped the vestigial `fullScreen` flag plumbed through `DemoTile` /
  `DemoScaffold` but never read.
- Tests: reclassified `test/screenshots_test.dart` → `test/screenshots.dart`
  (a manual capture-and-diff harness, per its own docstring not a gate) and
  fixed its fake-async raster deadlock via `tester.runAsync()`; drained the
  by-design overflow in `debug_shrink_test.dart` so its measurement loop
  completes. `dart analyze` clean; default `flutter test` gate `+6 / 0`, serial.
- Layout gate: extracted the demo mount into `test/demo_harness.dart` and added
  `test/demo_overflow_test.dart`, which fails when a demo overflows the
  1280x2400 viewport. The gate measures the Ahem placeholder font — wider than
  Roboto, and present on every machine — while the screenshot harness keeps the
  real SDK fonts so its PNGs stay readable.
- Layout fixes for the four demos the gate found: `widget_04_toggles` gives its
  three-radio `TomRow` `expandX()` instead of the builder's 150 px default
  width; `acl_19_comprehensive_form` sets `isExpanded` on the width-pinned
  priority dropdown so its label ellipsizes; and `acl_17`, `acl_19`, `acl_20`
  size their `ResizableBox` frames with real slack (320→360, 500→540, 300→380)
  rather than to within 3 px of their content.

  Default `flutter test` gate `+105 / 0`, serial; `flutter analyze` clean.

## 1.0.0

- Demo / smoke-test application for the **Tom Flutter UI** library: a four-tab
  Flutter showcase (ACL Demos, Widget Demos, Forms/Actions,
  Authorization/Resources) exercising the `tom_flutter_ui` Advanced Container
  Layout engine, the Tom-wrapped Material/Cupertino widget set, and the form /
  authorization framework, driven by `tom_core_kernel` resources and security.
- ACL Demos: 27 layout demos (rows, alignment, expand flags, spacing,
  min/preferred/max sizing, character-width sizing, reference and cross-row
  constraints, titled/bordered groups, nested containers, responsive shrink/grow,
  row breakpoints, fluent `AclBuilder`).
- Widget Demos: 27 per-category widget showcases (`demo_01…demo_28`) plus the
  resource-resolution and scoped-element-provider demos.
- Forms/Actions and Authorization/Resources tabs covering `TomForm` validation,
  selection/boolean variants, `TomFormStyleScope` breakpoints, action/auth
  gating, and `TomUIGroup` authorization.

### Documentation

- Replaced the default Flutter template `README.md` with an accurate overview:
  what the app demonstrates (the four tabs and their demo sources), how to run
  it (`flutter pub get` → `flutter run`; note this app has **no** reflection /
  codegen step and no asset bundle — resources are registered in Dart by
  `initializeDemoResources()`), the locale-bootstrap flow, the test layout, and
  the project structure.
- Added this `CHANGELOG.md` and a `LICENSE` (the workspace BSD 3-Clause license,
  matching the sibling `tom_flutter_ui` / `tom_core_*` packages).
