## Unreleased — cleanup pass

- Documentation: every demo, demo-backing form, and the public `@tomReflector`
  classes gained feature-naming `///` class doc comments stating the
  `tom_flutter_ui` (or `tom_core_kernel`) feature they exercise; added
  `doc/demo_catalogue.md` mapping each of the 33 demos and 5 examples to its
  source file, the upstream feature it validates, and how to launch it; README
  layout table and demo count updated to point at the catalogue.
- Tests: scoped every `tester.scrollUntilVisible(...)` to the active list
  (`scrollable: find.descendant(of: find.byType(DemoListScreen), …)`) across 35
  test files — the Examples-tab `TabBarView` introduced a second `Scrollable`
  that made bare scroll finders throw `Bad state: Too many elements`; removed
  redundant internal `tom_field_widget_adapter.dart` imports now that the
  `tom_flutter_ui` barrel exports `TomFieldWidgetAdapter`.
- Quality: `dart analyze` clean (zero warnings); full `flutter test` suite green
  (`+350 / 0`). No production behaviour changes.

## 1.0.0

- Demo application for the Tom Form Framework: a two-tab Flutter showcase
  (Demos + Examples) exercising the `tom_flutter_ui` form widgets and field
  system driven by `tom_core_kernel` resources, security, and reflection.
- ~30 demos across Phase 1 (form lifecycle, validation, authorization, nested
  forms, ACL layout, responsive breakpoints, master-detail / table patterns),
  Phase 2 (numeric, date/time, enum/object, file/nullable, and Cupertino field
  flavours, family-swap-on-breakpoint, tree/radio/infinite selection), plus
  supporting field-layout reference demos.
- Examples tab with stripped-down, copy-friendly samples under `lib/examples/`.

### Documentation

- Replaced the default Flutter template `README.md` with an accurate overview:
  what the app demonstrates (the Demos and Examples tabs and their sections),
  how to run it (`flutter pub get` → `reflection_generation.sh` →
  `flutter run`), the resource-bootstrap flow, and the project layout. No source
  changes.
- Added this `CHANGELOG.md` and a `LICENSE` (the workspace proprietary license,
  matching the sibling `tom_core_*` packages).
