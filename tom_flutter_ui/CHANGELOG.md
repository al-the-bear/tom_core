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
- **`theme/`** — authored `doc/theme.md` (the "Tom layers on, never replaces,
  Flutter theming" principle; `TomReadonlyStyle`'s ordered `apply` composition;
  `TomTheme` / `TomThemeScope` delivery and default fallbacks; the
  `TomButtonVariants` semantic-style factory); added
  `example/theme/theme_example.dart`; added `test/theme/theme_test.dart`
  (previously zero theme tests) covering `TomReadonlyStyle.apply`, `TomTheme`,
  `TomButtonVariants`, and the `TomThemeScope` inherited-widget lookup. No public
  API change.
- **`actions/`** — authored `doc/actions.md` (the Tom Action system as the
  behavioural counterpart to widgets: `TomAction` / `TomSimpleAction`, controller
  grouping and `<controllerId>.<actionId>` canonical paths, typed
  `TomActionContext`, the `TomActionUndo` → `TomActionTransaction` →
  `TomUndoHistory` undo model, `TomActionTrigger` widget wiring, composite
  actions, and `TomAuthorizable` integration); added
  `example/actions/actions_example.dart`; added `test/actions/actions_test.dart`
  (previously zero action tests, 25 tests) covering the controller registry,
  action/simple-action contracts, transaction record/commit/rollback/undoAll,
  the undo-history stack invariants, the trigger execution path, composite guard
  behaviour, and the undo/redo coordinator actions. No public API change.
- **`resource_auth/`** — authored `doc/resource_auth.md` (the name → object
  resolution layer: `TomUIColors` / `AllColorsAdapter` for named/hex/rgb colours,
  `TomUIIcons` with the `AllIcons` / `MaterialOnly` / `CupertinoOnly` adapters,
  the `TomConfigProvider` environment/platform/feature-flag store, and the
  authorization types re-exported from `tom_core_kernel`); added
  `example/resource_auth/resource_auth_example.dart`; added
  `test/resource_auth/resource_auth_test.dart` (previously zero tests, 18 tests)
  covering colour/icon resolution and graceful no-adapter degradation, custom
  registration precedence, hex 3/6/8-digit and rgb clamping, the config
  provider's fail-fast and flag semantics, and the `TomAuthState` ordering plus
  the legacy typedef aliases. No public API change.
- **`forms/`** — authored `doc/forms.md` (the declarative form system: the
  `TomForm` / `TomField` data/presentation split and value/dirty/commit/reset
  contract, the `Validators` factory and sealed `ValidationResult` family plus
  cross-field `FormValidationError`, `SelectableItem` / `StaticSelectableSource`,
  the typed `TomFormEvent` bus with `TomFormEventListener` / `TomFormInspector`,
  the responsive `TomBreakpoint` ladder and anatomy placement enums, and the
  `FormFieldFamily` Material-vs-Cupertino factory over the field catalogue);
  added `example/forms/forms_example.dart` (pure-logic: validators,
  selectable sources, the event bus, family field construction, a cross-field
  error, and breakpoints); added `test/forms/forms_example_test.dart` (6 tests)
  exercising the example end to end plus direct checks on the family factory,
  unmodifiable source snapshots, inspector filtering, `FormValidationError`
  ids, and breakpoint resolution. The 62-file module was already documented and
  carried 20 test files (326 tests, still green); no public API change.
- **`groups/`** — authored `doc/groups.md` (collective-visibility control: the
  `TomUIGroup` typedef over `TomAuthorizationGroup`, weak-reference member
  tracking, the three `AuthGroupMode`s — `controlsAll` / `controlsWidest` /
  `controlsNarrowest` — and `TomWidgetMixin`'s id/group/auth/resource wiring and
  four-layer `getAuth` resolution); added
  `example/groups/groups_example.dart` (pure-logic: group membership, the three
  modes via `applyMode`, a `TomWidgetMixin` field resolving through its group,
  introspection, and scope-prefixed paths); added
  `test/groups/groups_example_test.dart` (9 tests) covering the example end to
  end plus the typedef identity, each mode's ceiling/floor/replace behaviour,
  effective-auth resolution, register/unregister tracking, and scope paths. The
  module had no prior tests or example; no public API change.
