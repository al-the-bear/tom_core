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
