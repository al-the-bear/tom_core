## Unreleased

### Added

- **`TomAuthGate`** (`groups/`) — a one-child widget that resolves a
  `tomId` / `tomGroup` / `scope` / `authorizer` / `uiStateController` through
  `TomWidgetMixin` and applies the result to its child. It exists for the
  wrappers that cannot resolve their own authorization, and it promotes a
  private helper that `tables/` had already invented for that purpose into the
  shared, correct version. `TomAuthGate.resolve(...)` takes the same five
  inputs and answers the same question without building.
- **`authorizer` and `uiStateController` parameters on the eight wrappers that
  gate a slot** — `TomDataCell` (both constructors), `TomDataColumn`,
  `TomDataRow`, `TomExpansionPanel`, `TomSnackBar`, `TomSnackBarAction`,
  `TomAnimatedPositioned` and `TomAnimatedPositionedDirectional`. They now
  present the same authorization surface as every other Tom widget rather than
  one layer of four.
- **`TomDataCell.authState` / `isVisible` / `isReadonly`**, matching
  `TomDataColumn` and `TomDataRow`. `TomDataCell.empty` renders nothing either
  way, but now answers the same question from the same four layers instead of
  feeding its inputs to `basePath` alone.

### Changed

- **`TomMessenger.showSnackBar` and `showSnackBarIfPresent` now return
  `null`** for a `TomSnackBar` whose authorization resolves to
  `TomAuthState.none`, instead of presenting an empty bar. Gating the content
  alone is not enough for a snack bar: it does not build where it is written,
  so presenting it is the last moment at which not-presenting is possible. The
  return type is now nullable.
- **`TomDataColumn` and `TomDataRow` expose `isVisible` / `isReadonly` as
  getters**, dropping the `BuildContext` parameter neither ever read, and gain
  an `authState` getter. This matches `TomForm`'s own `bool get isVisible`.
- **`TomExpansionPanel.authorizationGroup` is renamed `tomGroup`**, and the
  class gains a `scope`, matching the widget wrappers it sits among.
- **`TomAppBar` extends `TomContainerBase`** instead of `StatelessWidget` with
  `TomWidgetMixin`, joining `TomBottomAppBar` and `TomSliverAppBar` on the base
  its sub-folder implies. `PreferredSizeWidget` is an `implements` and so was
  never the obstacle. It now reports `TomWidgetFamily.container`, which is what
  `doc/widgets.md` had always claimed it did.

### Fixed

- **`TomAppBar` resolved its authorization and then ignored it.** Its `build`
  returned an `AppBar` directly, with no `checkHidden()` and no
  `applyAuthState()`, so a `none` app bar rendered in full and a `disabled` one
  stayed interactive — while `tomId`, `tomGroup`, `scope`, `authorizer` and
  `uiStateController` all type-checked. Extending `TomContainerBase` moves
  the body to `buildContent` and puts the four-state gate back in the path. The
  constructor also registered with `tomGroup` and never unregistered; the base
  owns that lifecycle now.
- **Four documents claimed every widget in the kit reports its family.** 17 of
  the 292 wrappers extend a Flutter widget directly (their parent type-checks
  for the Flutter subtype) and have no family base to get `family` from, and 9
  further types under `widgets/` are not widgets at all. The catalogue in
  `doc/widgets.md` also listed two widgets under families they do not report:
  `TomAppBar`, which had no `family` at all, and `TomSliverList`, which is a
  `TomContainerBase`. `test/widgets/widget_family_claims_test.dart` now reads
  the counts and the catalogue out of the sources, so neither can drift again.

- **Eight wrappers declared `tomId` / `tomGroup` / `scope` and never applied
  them.** `TomAnimatedPositioned`, `TomAnimatedPositionedDirectional`,
  `TomSnackBar`, `TomSnackBarAction` and `TomExpansionPanel` ignored their
  authorization entirely; `TomDataCell` and `TomDataColumn` applied it through
  a private helper that stored `tomGroup` without reading it, dropped `scope`,
  and treated `disabled` as `full`; `TomDataRow` reported through a
  `basePath`-only lookup with the same two omissions. All eight now route
  through `TomAuthGate`, so a group ceiling, an explicit scope, a per-widget
  authorizer and a UI-state controller count for them exactly as they do for
  every other Tom widget. Two of them cannot hide by gating a slot and say so
  instead: `TomDataRow` (a `DataTable` demands one cell per column from every
  row) reports for the caller to filter on, and `TomSnackBar` is declined at
  the point of presentation.
- **A `disabled` gated slot was rendered as if it were `full`.**
  `TomAuthState.disabled.isVisible` is true, so the "hide if not visible, else
  dim if read, else pass through" shape the replaced helper used let a disabled
  cell render fully interactive. Routing through `TomAuthGate` applies the
  theme's disabled treatment — dimmed and pointer-absorbing — for all four
  states rather than three. `test/widgets/wrapper_auth_layers_test.dart` pins
  it, along with both narrowing layers.
- **A plain `TomCupertinoSearchTextField()` can be constructed again.** Its
  placeholder resolved through an unguarded `TomCtr.textOrFail` into a
  non-nullable `String`, so a search box with no `placeholder` and no `tomId`
  threw a `StateError` — for a property Flutter treats as optional, and which
  `CupertinoSearchTextField` fills with the localized "Search" when handed
  `null`. Resolving it unconditionally therefore replaced a working default
  with either a resource requirement or an exception. It is now `String?` and
  looked up only when the widget has a `tomId`, matching its two siblings
  `TomCupertinoTextField` and `TomCupertinoTextFormFieldRow` and the sweep
  that had already made every other optional slot behave this way.
- **A `TomIconButton` with no icon now says so instead of rendering a warning
  glyph.** The icon *is* this widget, but it resolved through the nullable
  `TomCtr.icon` and fell back to `const Icon(Icons.error_outline)` — leaving a
  control that is present and tappable and names neither itself nor the key it
  looked for. Worse, that fallback was reached identically by a bundle naming
  no icon and a bundle naming a misspelt one, because `TomCtr.icon` answers
  `null` to both. It now resolves through the new `TomCtr.iconOrFail` and
  throws a `StateError` naming the missing key. **Behavioural change:** a
  `TomIconButton` with neither an `icon` argument nor a resolvable
  `<tomId>.icon` resource now throws from its constructor rather than
  building. An icon beside
  a label — `TomFloatingActionButton.extended` — is genuinely optional and
  deliberately keeps the nullable accessor.
- **`TomIcon` no longer drops an icon whose name ends in `.icon`.** It read the
  resource through `textOrFail` and decided whether it had found anything by
  asking whether the answer ended in `.icon`, because `textOrFail` returns the
  *key* when nothing is installed. That is a second implementation of what
  `TomCtr.icon` already does, and it reads a returned *value* as if it were a
  key: an icon actually named `brand.icon` was indistinguishable from a missing
  one and was silently discarded. It now calls `TomCtr.icon`.
- **`TomScope` is nameable from the package barrel.** `scope:` is a parameter
  on every Tom widget and its type is the kernel's `TomScope`, but the package
  does not re-export `tom_core_kernel` wholesale and `TomScope` was absent from
  the only `show` list it had — so a consumer could read the parameter in a
  signature and had no way to name its type or build an argument for it.
  Nothing inside `lib/` could catch that, because the ~85 files declaring those
  signatures import the kernel barrel unfiltered; the omission was visible only
  from outside. Every kernel type in a public signature is now audited and
  carried.
- **An explicit `decoration` on the text inputs is no longer overwritten.**
  `TomTextField` and `TomTextFormField` resolved their label from resources
  unconditionally and wrote it over the supplied `InputDecoration` at the end,
  so `decoration: InputDecoration(labelText: 'Name')` was silently discarded —
  and a caller who supplied a decoration but no `label` and no `tomId` was told
  the widget "requires either an explicit label or a tomId" for a string the
  decoration already carried. The label and hint now follow a chain rather than
  a merge: `label` → `decoration.labelText` → the `<tomId>.label` resource, with
  the resource lookup last and therefore only performed when nothing earlier
  supplied one. Omitting every source still throws. **Behavioural change:** a
  caller who passed *both* a `decoration.labelText` and a label resource now
  sees the decoration's value where they previously saw the resource's.
- **A one-dimensional `minimumSize` no longer makes a button demand the whole
  width.** `parseButtonStyle` completed a missing `width` / `height` with
  `double.infinity` for all three of `minimumSize`, `maximumSize` and
  `fixedSize`, so `minimumSize: {height: 40}` parsed to `Size(Infinity, 40)` —
  a minimum of every available pixel, from a resource that only asked for a
  height. Each slot now completes with what it means: an unspecified *minimum*
  is `0`, an unspecified *maximum* stays `double.infinity`, and a `fixedSize`
  missing either dimension is discarded, since neither value is what "fixed"
  means. A size map naming neither dimension is now discarded in all three
  slots rather than parsing to `Size(Infinity, Infinity)`, so `minimumSize: {}`
  can no longer be the sole reason a `ButtonStyle` comes back non-null.
- **`TomInputDatePickerFormField` no longer demands four resources.** Its
  label, hint and two error messages are optional in Flutter (defaulted from
  `MaterialLocalizations`), but all four were required, which made a plain
  `TomInputDatePickerFormField(...)` unconstructible. They are now looked up
  only when the widget has a `tomId`.

### Removed

- **`TomUIGroup` is gone; use `TomAuthorizationGroup`.** The alias was
  documented as deprecated yet was the declared type of `tomGroup` in ~20
  widget classes, while its two siblings (`TomUIAuthorization`,
  `TomUIAuthorizationAdapter`) had already been deleted — so the package
  carried one spelling that was simultaneously discouraged and canonical. Every
  declaration, example, test and document now names the kernel type directly,
  leaving one spelling per type across the framework. `lib/src/groups/` keeps
  only `TomWidgetMixin`; the group type reaches consumers through
  `kernel_types.dart`.
- **The assertions that the removed alias still existed are gone too.** That
  rename was applied inside the sentences explaining the alias, so the groups
  example and its test were left stating that `TomAuthorizationGroup` is a
  typedef for itself — and backing it with `identical(X, X)`, an assert that
  cannot fail. The example's header sentence and its tautological assert are
  deleted, and the `TomAuthorizationGroup typedef` test group goes with them;
  its one real test (`default mode is controlsWidest`) survives under
  `AuthGroupMode`, beside the mode behaviours it belongs with.

### Added

- **`TomCtr.iconOrFail`, and a stated rule for which accessors get an
  `…OrFail` at all.** The family had grown to four with no criterion written
  anywhere, so its shape read as an accident and the one widget that most
  needed a throwing icon accessor did not have one. The rule is now stated in
  `doc/widget_base.md` and in the `TomCtr` dartdoc: an accessor gets an
  `…OrFail` when the resource it reads can be a widget's *only* source for a
  required parameter that has no default. `boolVal` and `edgeInsets` are
  excluded because Flutter always defaults those parameters, so a resource
  overrides rather than supplies; `value`, `list` and `map` because `TomCtr`
  is not told what the caller means to do with them and so cannot decide what
  "unusable" is. `tom_ctr_helpers_test.dart` scans the source and holds the
  set to exactly the five members and the five deliberate exclusions, so a
  sixth variant added without re-reading the rule fails the suite.
- **`lib/src/kernel_types.dart` — one bridge to `tom_core_kernel`, and two
  guards on it.** The package's kernel re-exports were split across
  `resource_auth/tom_auth_state.dart` (nine authorization names) and
  `widget_base/tom_authorizable.dart` (one), which is why nobody had ever
  audited what the bridge carries against what the public signatures need. Both
  files are replaced by one package-level list of 26 names, with the membership
  rules written down beside it. `tool/check_kernel_bridge.py` fails when a
  kernel type reaches a public declaration position without reaching the list;
  `test/kernel_types_test.dart` imports nothing but the package barrel and uses
  each bridged type, so a name that does not actually resolve stops the file
  compiling. A blanket re-export is not the alternative: the kernel barrel
  re-exports `tom_basics`, which declares a `TomEnvironment` and a `TomPlatform`
  colliding with this package's own enums of those names, so every use of
  either would be an `ambiguous_import`.
- **`MaterialOnlyColorAdapter` and `CupertinoOnlyColorAdapter`.** The icon side
  of `resource_auth/` shipped three adapters and the colour side one, although
  `GeneratedColors` has exposed `materialColors` and `cupertinoColors` as
  separate maps all along. Both reasons for the icon adapters apply equally to
  colours: an app targeting one platform stops carrying the other family's
  table, and — the reason that surfaces as a bug rather than a bundle size — a
  stray `cSystemBlue` in a Material-only resource file now resolves to `null`
  and is caught instead of quietly working. Registrations, hex and `rgb()` still
  resolve through them; only the other family's palette is gone.

### Changed

- **The test suite reaches the package through the barrel, so the exports are
  load-bearing.** 60 of the 114 test files reached into `lib/src` by path —
  230 imports in all — which meant a symbol dropped from a module
  barrel, or a module dropped from the package barrel, left the whole suite
  green and surfaced in a consumer instead. Every export line was load-bearing
  for consumers and inert for the tests that covered it. All 60 now import
  `package:tom_flutter_ui/tom_flutter_ui.dart`; no test body needed an edit,
  which is the evidence that the barrel already carried everything. Two files
  keep their `src/` imports for reasons the barrel cannot express and are
  exempted by name and reason: `file_opener_test.dart`, which asserts the two
  halves of a conditional import against the resolved one, and the generated
  `*.reflection.dart` fixture. `package_barrel_test.dart` now checks the
  property directly rather than relying on it as a side effect of imports
  somebody could rewrite, and holds the exemption list to being non-stale.
  Ten `tom_core_kernel` imports became redundant in the process and are gone —
  those files now name kernel types through the bridge, exactly as a consumer
  does.
- **The single-family icon adapters are renamed `MaterialOnlyIconAdapter` and
  `CupertinoOnlyIconAdapter`.** With colour siblings beside them, the old
  `MaterialOnlyAdapter` / `CupertinoOnlyAdapter` no longer said which family
  they carried.
- The colour adapters now share a `_RegistryFirstColorAdapter` base that holds
  the registry-then-hex-then-rgb order once, mirroring the icon side. Hex and
  `rgb()` live in the base because they are syntax rather than a palette, so a
  single-family adapter is a smaller palette and not a different contract.
- The two byte-identical private `_resolveDecoration` methods on the text
  inputs are replaced by one shared `_resolveInputDecoration` helper carrying
  the precedence rule and its rationale.
- **`AuthGroupMode` is carried by the kernel bridge.** It was absent from the
  package's `show` list, so group code that named a mode had to import
  `tom_core_kernel` as well. Importing `tom_flutter_ui` is now sufficient for
  the group type and its mode enum together.

### Documentation

- **`doc/widgets.md` describes what a widget does with a missing text
  resource, rather than what its resolver is named.** The section led with the
  claim that the `*OrFail` resolvers "throw so a missing required value fails
  loudly at construction rather than rendering blank". `textOrFail` — the text
  resolver of the whole kit, at some seventy call sites — throws only when
  there is no `tomId` to look under; given one and no resource it returns the
  dotted key, so a `TomText(tomId: 'nope')` paints `nope.label`. The contrast
  with "rendering blank" had it backwards: blank is the visibly wrong outcome
  that gets caught in review, and a key that reads like words, at the right
  size in the right place, is the one that ships.
  The section now tabulates the **three compositions** the wrappers actually
  use — required, `tomId`-guarded optional, and superseded-by-a-widget-slot —
  because the resolver's contract does not determine the widget's behaviour
  and the same missing resource gets three different answers depending on
  which composition the property got. The same correction is applied to the
  `_resolveInputDecoration` dartdoc, which had described only the throwing
  half. `test/widgets/missing_text_resource_test.dart` pins all three.
  and `doc/widget_base.md` described `families` as letting a widget "report
  more than one" and stopped there, which leaves the reader to assume the
  obvious composition. It is not the one in force: `isFamily` reads `families`
  alone and never consults `family`, and the base class does not fold the
  primary back in — so an override that omits `family` produces a widget that
  denies its own primary family while `family` keeps returning it. Both places
  now state the rule and the trap, and direct overrides to write `{family, …}`.
  Nothing in `lib/` overrides `families`, so the first widget to do so would
  otherwise have discovered this by accident;
  `test/widget_base/tom_widget_family_coverage_test.dart` now pins the
  behaviour, including the disowned-primary case, so the warning stays true.
  The same file also pins each of the twenty branch bases to the family its
  *name* claims. Every assertion it previously made was about sets — twenty
  bases, distinct families, covering exactly the Flutter-derived values — and
  no set assertion can see a permutation: swapping the bodies of
  `TomListBase.family` and `TomChipBase.family` left all of them passing while
  two bases lied about what they were. The bases are near-identical
  boilerplate differing in one line, which is the shape that invites exactly
  that slip, and neither the analyzer nor a rendering test can catch it.
- **`TomStyleResolvers` no longer opens with a type list that had fallen five
  types behind its own members.** The class dartdoc summarised the class as
  resolving twelve named Flutter objects, an enumeration written when that was
  true and never revisited as the class grew to nineteen parsers — so
  `VisualDensity`, `IconThemeData`, `StrutStyle`, `TextHeightBehavior` and
  `ScrollPhysics` were absent from the one paragraph a reader starts at. The
  summary now describes what the class produces by category and points at the
  `parse…` members as the list, and the counts the comment still states about
  its own members — nineteen parsers, seventeen with a `resolve…` partner here,
  twelve taking a map and seven a raw value — are checked against those members
  by `style_resolvers_layering_test.dart`, so the shorter claim cannot drift the
  way the list did.
- **`TomErrorBoundary`'s library comment describes the interception the widget
  performs (tcinc349).** It claimed two layers, the first of which was a wrapped
  `FlutterError.onError` hook catching errors "flagged with the boundary's
  `_TomErrorBoundaryMarker`". `FlutterError.onError` is never assigned anywhere
  in the file and no marker type exists — the dangling reference was the visible
  end of a paragraph describing a mechanism that had been replaced. There is one
  layer: a ref-counted global `ErrorWidget.builder` returning a reporter widget
  that walks the element tree to its nearest enclosing boundary, which is what
  makes nested boundaries route correctly regardless of mount order. That is now
  what the comment says, including why the indirection is there.
- **`TomForm._enclosingForm` points somewhere real.** It referred the reader to
  `[_resolveCommitBaselines]` for the nested-save rule; no such member exists,
  and the rule lives in `save`'s "Nested-save semantics" paragraph, which the
  comment now names.
- **All three `widget_base` pillars now have an executable example.**
  `doc/widget_base.md` opens by naming identity/scope, authorization and
  resource binding as the three things every Tom node does, but the module's
  only example covered resource binding — the two harder pillars were prose.
  `example/widget_base/widget_base_nodes_example.dart` covers them: it composes
  a nested `TomScreenElementsProviderBase`, asserts the base paths that come
  out, walks the authorization gate one layer at a time (resource grant → group
  ceiling → authorizer → the controller that cannot widen), and reports the
  family each widget declares. None of it needs a widget tree — `basePath` is
  computed in the constructor, `resolveEffectiveAuth()` takes no
  `BuildContext`, and `family` is a plain getter — so the example asserts on
  constructed nodes rather than pumping them, and
  `test/widget_base/widget_base_nodes_example_test.dart` runs it.

## 1.1.0

Adapts the widget set to the Flutter 3.44 scroll/reorder API changes. **This is
a breaking change with no backwards-compatibility shims** (per framework
policy).

### Changed

- **Reorder callback renamed `onReorder` → `onReorderItem`** on
  `TomReorderableListView`, `TomReorderableList`, and `TomSliverReorderableList`,
  mirroring Flutter's own rename. The new callback's `newIndex` is **already
  adjusted for the removed item**, so callers must drop the classic
  `if (newIndex > oldIndex) newIndex -= 1` fixup — the plain
  `removeAt(oldIndex)` / `insert(newIndex, item)` body is now correct. All
  demos and consumers updated accordingly.
- **`cacheExtent` now flows through `ScrollCacheExtent` internally.** The public
  `cacheExtent` field and the `cacheExtent` resource key stay `double?` (pixel)
  for API/config stability; the widgets wrap the resolved value via
  `ScrollCacheExtent.pixels(...)` and pass `scrollCacheExtent:` to the
  underlying Flutter widgets (`TomListView`, `TomGridView`,
  `TomCustomScrollView`, `TomReorderableList`, `TomReorderableListView`).
- The list-form widgets (`TomInlineListForm`, `TomExpandableListForm`) migrate
  their internal `ReorderableListView.builder` usage to `onReorderItem`; their
  public `onReorder(from, to)` domain callback is unchanged (still delivers the
  final destination index).

### Added

- Widget test asserting the reorder behaviour end-to-end: a real drag on
  `TomReorderableListView` moves the first row down one slot and reports the
  post-removal `newIndex` (proving the manual fixup is gone).

## 1.0.0

First versioned release of the Tom Flutter UI widget library. Promotes the
package from the `0.0.1` Flutter template stub to a real, documented `1.0.0`:
authored the package `README.md` (description + module/widget catalogue + form
field catalogue), the BSD 3-Clause `LICENSE`, and this changelog. No source
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
- **`TomFieldWidgetAdapter`** — now exported from the `forms/` barrel. It wraps
  every concrete field's rendered widget so `TomAuthorizable`-aware consumers
  (e.g. ACL hide-unauthorized) can reach a field's auth state; it appears in the
  public widget tree, so consumers must be able to name the type. (The generated
  `GeneratedColors` / `GeneratedIcons` lookup tables remain internal — they back
  the public `TomUIColors` / `TomUIIcons` resolvers.)

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
  `TomUIIcons` with the all / Material-only / Cupertino-only icon adapters,
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
- **`advanced_container_layout/`** — authored `doc/advanced_container_layout.md`
  (the fluent, row-based ACL layout engine: the `AclBuilder` → `Acl` build
  pipeline and its append/gap/row/size/alignment vocabulary, the `AclFlags`
  AWT-style attribute bits, `RowAlignment`, responsive variants vs. row
  breakpoints, the `AclDeviceContext` static resolvers and AND-combined
  `buildConvenienceDetector`, the `AclBinaryVisibilityController` /
  `AclCallbackVisibilityController` group-visibility controllers, `AclScope`
  id/group propagation, and the `setAclDefaultHideUnauthorized` /
  `setHideUnauthorized` authorization-aware hiding); added
  `example/advanced_container_layout/advanced_container_layout_example.dart`
  (pure-logic: `AclFlags` bit composition, the device-context resolvers and
  convenience detector, the two visibility controllers driven by
  `ValueNotifier`s, and an `AclBuilder` fluent chain producing an `Acl`); added
  `test/advanced_container_layout/advanced_container_layout_example_test.dart`
  (11 tests) covering the example end to end plus the flag composition, the
  width/density/platform resolver thresholds, the convenience-detector
  null-vs-predicate contract, both controllers' notifier-driven mode updates,
  and `build()` producing an `Acl` (including the duplicate-instance guard). The
  module already carried `acl_hide_unauthorized_test.dart` (10 tests, still
  green); no public API change.
- **`widgets/`** — authored `doc/widgets.md` (the general widget kit: ~200 Tom
  wrappers over Flutter/Cupertino across 21 families behind `widgets.dart`, the
  shared `TomFamilyBase` → `TomPolicyNodeBase` → `TomNodeBase` contract — family
  tagging, `tomId`/`basePath`, `effectiveAuthState`, and construction-time
  `TomCtr` resource resolution — a full family catalogue, and the
  authorization/group/scope rules); added
  `example/widgets/widgets_example.dart` (pure-logic: family tagging across
  button/label/toggle/container/progress wrappers, `basePath` resolution and
  scope prefixing, and `effectiveAuthState` resolution via resource auth and a
  `TomUIGroup` ceiling — all without a `BuildContext`); added
  `test/widgets/widgets_example_test.dart` (7 tests) covering the example end to
  end plus direct checks on `family`/`families`/`isFamily`, `basePath` (top
  level and scoped), and auth resolution (resource read, default full, group
  narrowing). Scoped to module doc + pure-logic example/smoke test, not a
  ~23k-LOC refactor of thin Flutter wrappers; per-widget visual rendering stays
  with the `testWidgets` suites / `phase1_demo.dart`. No public API change.
- **`custom/`** — authored `doc/custom.md` (the eight non-form composite
  widgets: the auth-gated `TomAuthGuard`, the per-node `TomAuthTreeView` /
  `TomAuthTreeNode` with its `ownAuth.narrow(inheritedAuth)` inheritance rule,
  the group-gated `TomRadioGroup` / `TomRadioGroupItem`, and the
  `TomEmptyState` / `TomLoadingOverlay` / `TomSkeletonLoader` /
  `TomErrorBoundary` / `TomInfiniteScroll` state idioms — the shared
  four-outcome auth contract, the scope-qualified `TomAuthorization.resolveAuth`
  lookup, and the ref-counted nearest-boundary error routing); added
  `example/custom/custom_example.dart` (pure-logic: the four-state auth lookup,
  the `TomAuthState.narrow` lattice the tree inherits with, the
  `TomRadioGroupItem` / `TomAuthTreeNode` data models, and context-free
  construction of all eight widgets); added `test/custom/custom_example_test.dart`
  (13 tests) covering the example end to end, `TomAuthGuard.resolveAuthState`
  across the four states, and `testWidgets` render cases for the auth gate
  (none collapses / disabled fades / full renders), `TomRadioGroup` gating,
  `TomEmptyState` / `TomLoadingOverlay` / `TomSkeletonLoader` / `TomErrorBoundary`
  rendering, and the data models. The module had no prior doc, example, or test;
  no public API change.
- **`example/phase1_demo.dart`** — promoted the standalone demo from a
  forms-only `runApp` (which imported the `src/forms/` barrel and crashed on
  pump because its `@tomReflector` form models need reflection data this package
  never wires) into a runnable, reflection-free-by-default demo. It now imports
  the public `package:tom_flutter_ui/tom_flutter_ui.dart` barrel, installs the
  text-resource provider + `AllColorsAdapter` in `main()`, and pages a
  `NavigationBar` across three galleries: **Widgets** (the general kit —
  `TomElevatedButton` / `TomFilledButton` / `TomOutlinedButton`, `TomText`,
  `TomBadge`, `TomChip`, `TomCard` + `TomListTile`, `TomSwitch`, `TomCheckbox`,
  `TomSlider`, `TomCircularProgressIndicator` / `TomLinearProgressIndicator`),
  **Custom** (`TomAuthGuard`, `TomRadioGroup`, `TomSkeletonLoader`,
  `TomLoadingOverlay`, `TomEmptyState` inside a `TomErrorBoundary`), and the
  existing **Forms** screen. The default landing tab is Widgets, so the app
  pumps cleanly; the Forms screen now tolerates missing reflection (it catches
  the construction error and shows an explanatory panel instead of taking the
  app down). Added `test/phase1_demo_test.dart` (3 tests) pumping the app,
  asserting the Widgets gallery renders, navigating to the Custom gallery, and
  exercising a toggle. No public API change.
- **Documentation review (close-out)** — final cross-module pass confirming the
  nine module docs match the code: every `Tom*` type named in
  `doc/actions.md`, `doc/advanced_container_layout.md`, `doc/custom.md`,
  `doc/forms.md`, `doc/groups.md`, `doc/resource_auth.md`, `doc/theme.md`,
  `doc/widget_base.md`, and `doc/widgets.md` was checked against the actual
  `class` / `enum` / `mixin` / `typedef` / `extension` / `interface`
  declarations in `lib/src` (and the re-exported `tom_core_kernel` types). One
  stale reference was corrected — `doc/forms.md` described a non-existent
  `TomColorTokens` type; `tom_color_tokens.dart` actually exposes the `cs.*`
  token-resolver functions (`resolveColorSchemeToken` / `resolveAnyColor` /
  `isColorSchemeToken`), so the doc now names those plus `TomThemeSpec`. Each of
  the nine `lib/src` modules is exported from the public
  `lib/tom_flutter_ui.dart` barrel and has a matching `doc/*.md`; barrel
  coverage of the public symbol set was verified earlier (the only two
  unexported `lib/src` files are the generated `GeneratedColors` /
  `GeneratedIcons` lookup tables, intentionally internal behind the public
  `TomUIColors` / `TomUIIcons` resolvers). No public API change.
