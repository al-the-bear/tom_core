## Unreleased — cleanup pass

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
