## 1.0.0

First versioned release of the Tom Flutter UI widget library. Promotes the
package from the `0.0.1` Flutter template stub to a real, documented `1.0.0`:
authored the package `README.md` (description + module/widget catalogue + form
field catalogue), the proprietary `LICENSE`, and this changelog. No source
change — this release records the widget set that already exists.

### Added

- **`widget_base/`** — the foundational layer: the `TomAuthorizable` contract,
  construction-time helpers, the widget/family base classes (`TomNodeBase`,
  `TomPolicyNodeBase`, `TomWidgetFamily`), scope widgets, the screen-elements
  provider, and the style resolvers.
- **`theme/`** — `TomTheme`, the read-only style, and the style-variant system.
- **`actions/`** — the Tom Action system: typed, authorization-aware actions
  (`TomAction`, `TomActionController`, `TomActionContext`) with atomic
  transactions, undo/redo history, composite actions, and widget triggers.
- **`resource_auth/`** — `TomAuthState`, resource-resolved `TomColors` /
  `TomIcons`, and the config provider.
- **`forms/`** — the declarative form system: the `TomForm` data model,
  validators, selectable sources, the form event bus, the Material + Cupertino
  style/decoration system, and the full field catalogue behind a
  `FormFieldFamily` factory (string, bool, numeric, date/time, duration,
  enum/object, search/lookup, file, nullable, and list/master-detail forms).
- **`groups/`** — `TomUIGroup` collective-visibility control.
- **`advanced_container_layout/`** — the fluent, row-based `AdvancedContainerLike`
  layout engine with ACL integration.
- **`widgets/`** — the general widget kit (buttons, chips, containers, dialogs,
  inputs, labels, lists, navigation, progress, selects, sliders, slivers, tables,
  toggles, trees, plus animated/builder/effect/image/interaction helpers).
- **`custom/`** — non-form composite widgets (auth guard, auth tree, empty state,
  error boundary, infinite scroll, loading overlay, radio group, skeleton loader).

### Documentation

- **`widget_base/`** — authored `doc/widget_base.md` (the node hierarchy
  `TomNodeBase → TomPolicyNodeBase → TomFamilyBase`, the four-state
  authorization gate, the `TomWidgetFamily` taxonomy, scope propagation, screen-
  element providers, and the `TomCtr` / `TomStyleResolvers` resource helpers);
  added `example/widget_base/widget_base_example.dart`; added
  `test/widget_base/widget_base_resolvers_test.dart` covering `TomStyleResolvers`
  (previously untested) and the example end to end. No public API change.
