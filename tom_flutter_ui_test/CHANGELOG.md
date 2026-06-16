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
- Added this `CHANGELOG.md` and a `LICENSE` (the workspace proprietary license,
  matching the sibling `tom_flutter_ui` / `tom_core_*` packages).
