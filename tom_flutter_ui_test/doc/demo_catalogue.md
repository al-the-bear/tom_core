# Demo Catalogue — Tom Flutter UI Test

This app (`tom_flutter_ui_test`) is a manual showcase for the **`tom_flutter_ui`**
package: its Advanced Container Layout (ACL) engine, its wrapped Tom widget set,
and its form / authorization / resource framework — all driven over the
observable, reflection and resource APIs of **`tom_core_kernel`**.

> **Upstream package note.** This app depends on **`tom_flutter_ui`** (widgets,
> ACL builder, forms) and **`tom_core_kernel`** (resources / scope / locale) —
> it does **not** depend on `tom_core_flutter`. The "feature validated" column
> below therefore names the `tom_flutter_ui` API (or kernel API) each screen
> exercises.

The single `MaterialApp` (`lib/main.dart`) is a **four-tab** shell; the four
tables below map one-to-one to those tabs:

- **ACL Demos** (`lib/acl_demos/`) — the Advanced Container Layout engine.
- **Widget Demos** (`lib/widget_demos/`) — individual wrapped-widget showcases.
- **Forms/Actions** (`lib/forms_demos/`) — the form-field framework.
- **Authorization/Resources** (`lib/widget_demos/`) — widget auth + resource
  resolution (reuses two widget-demo screens).

---

## How to launch

There is **one** Flutter entry point (`lib/main.dart`); individual demos are not
separately runnable — they are reached by navigating inside the running app.

Unlike the sibling `tom_flutter_form_test`, this app has **no reflection /
codegen step and no asset bundle** (no `reflection_generation.sh`, no
`.reflection.dart`, no `assets/`). All resources are registered in Dart by
`initializeDemoResources()` (see `lib/demo_resources.dart`) before the first
frame — so a plain `flutter run` is all that is needed:

```bash
flutter pub get
flutter run            # add -d <device-id> to target a specific device
```

The app opens on `MainTabsPage`, a four-tab shell (`DefaultTabController`). Pick
a tab, then tap a `DemoTile` to push its screen with `Navigator.push`; the back
button returns to the list. The `AppBar` carries a `LanguageSelectorButton`
backed by the app-wide `localeSettingsService` (persisted across launches).

---

## ACL Demos (`lib/acl_demos/`)

The Advanced Container Layout engine: declarative rows of components with
expand flags, size constraints, reference alignment, borders/groups and
responsive breakpoints, built fluently via `AclBuilder`.

| Demo | Source file | `tom_flutter_ui` feature validated |
| ---- | ----------- | ---------------------------------- |
| Basic Row Layout | `basic_row_demo.dart` | Base `AclBuilder` / `newRow` — horizontal arrangement of components |
| Multiple Rows | `multi_row_demo.dart` | Vertical stacking with `newRow()` |
| Row Alignment | `alignment_demo.dart` | LEFT / CENTER / RIGHT row alignment |
| All Dimensions | `all_dimensions_demo.dart` | Full-window layout: `expandX` + `expandY` + both combined |
| Expand Flags | `expand_demo.dart` | `expandX` / `expandY` flexible-layout flags |
| Spacing & Gaps | `spacing_demo.dart` | Component (`dist:`) and row spacing |
| Size Constraints | `size_constraints_demo.dart` | Minimum / preferred / maximum (M/P/X) size behaviour |
| Reference Constraints | `reference_constraints_demo.dart` | `sameSize` + left/right/center/vertical alignment to references |
| Cross-Row Alignment | `convenience_placement_demo.dart` | Cross-row reference methods: `alignTopToBottom`, `alignRightToRight`, … |
| Mixed Placement Playground | `mixed_placement_playground_demo.dart` | Cross-row alignment combined with regular rows, `sameSize`, `expandX` |
| Responsive Layout | `responsive_convenience_demo.dart` | Shrink/grow between preferred and minimum sizes as the window resizes |
| Character Width Sizing | `character_width_sizing_demo.dart` | `setPWidthInChars` / `setMWidthInChars` / `setXWidthInChars` |
| Border Styles | `border_styles_demo.dart` | `AclBorderStyle` / `AclBorderKind` variants and border insets |
| Groups (Titled Borders) | `groups_demo.dart` | Titled group boxes |
| Bordered Groups | `bordered_groups_demo.dart` | Single-line borders with topLeft / topCenter / topRight titles (`AclTitlePosition`) |
| Nested Containers | `nested_containers_demo.dart` | Containers within containers |
| Form Layout | `form_layout_demo.dart` | Typical form layout pattern |
| Complex Layout | `complex_layout_demo.dart` | Combined-features demonstration |
| Comprehensive Form | `comprehensive_form_demo.dart` | 2-column form with gap slots (`gap()` / `gapRow()`), separators, cross-row alignment |
| Dynamic Resize Demo | `dynamic_resize_demo.dart` | Live layout adaptation as the window resizes |
| Fluent Builder API | `fluent_api_demo.dart` | The fluent `AclBuilder` extension API |
| Group Visibility Control | `group_visibility_demo.dart` | Group visibility controllers toggled via switches / input callbacks |
| Responsive Variants | `responsive_variants_demo.dart` | `addVariant` — different layouts at different container widths |
| Row Breakpoints | `row_breakpoints_demo.dart` | `addRowBreakpoint` — rows split into multiple rows at narrow widths |
| Breakpoint Expansion | `breakpoint_expansion_demo.dart` | 4 expanding items: 1 → 2 → 4 rows as width shrinks |
| Inline Component Variants | `inline_variants_demo.dart` | Inline variants — different components in the same row at different widths |

Helper scaffolding (not feature demos): `demo_helpers.dart` (`DemoBox` /
`CodeBlock`), `expanding_box.dart` (`ExpandingBox`), `resizable_box.dart`
(`ResizableBox`).

---

## Widget Demos (`lib/widget_demos/`)

Each screen showcases one category of the wrapped Tom widget set. Screens are
wrapped in a `TomScope.withScope('demoNN', …)` so resource resolution and
scoped actions work.

### Input & Actions

| Demo | Source file | `tom_flutter_ui` widgets exercised |
| ---- | ----------- | ---------------------------------- |
| Buttons | `demo_01_buttons.dart` | ElevatedButton, TextButton, IconButton, FAB, … |
| Text Inputs | `demo_02_inputs.dart` | TextField, SearchBar, Autocomplete, DatePickers, … |
| Selection Controls | `demo_03_selection.dart` | Dropdowns, Popup Menus, Menu Anchors, Segmented Controls |
| Toggles & Options | `demo_04_toggles.dart` | Checkbox, Switch, Radio, ToggleButtons, ExpansionTile |
| Sliders & Ranges | `demo_05_sliders.dart` | Slider, RangeSlider, CupertinoSlider, Stepper |

### Layout & Structure

| Demo | Source file | `tom_flutter_ui` widgets exercised |
| ---- | ----------- | ---------------------------------- |
| Cards & Panels | `demo_06_cards_panels.dart` | Card, ExpansionPanel, ListTile variants, Material surfaces |
| Layout Widgets | `demo_07_layout.dart` | Row, Column, Stack, Wrap, Flow, Flex, Table |
| Scrollable Containers | `demo_08_scrollable.dart` | ListView, GridView, SingleChildScrollView, PageView |
| Dialogs & Overlays | `demo_09_dialogs.dart` | AlertDialog, BottomSheet, SnackBar, Tooltip, Banner |
| Tables & Data | `demo_10_tables.dart` | DataTable, PaginatedDataTable, sorting and selection |

### Display & Info

| Demo | Source file | `tom_flutter_ui` widgets exercised |
| ---- | ----------- | ---------------------------------- |
| Labels & Text | `demo_11_labels.dart` | Text, RichText, SelectableText, Badge, Chip |
| Images & Media | `demo_12_images.dart` | Image, Icon, CircleAvatar, FadeInImage, decorations |
| Navigation | `demo_13_navigation.dart` | AppBar, TabBar, BottomNavigationBar, Drawer, NavigationRail |
| Progress Indicators | `demo_14_progress.dart` | Circular / Linear progress, RefreshIndicator |
| Lists & Items | `demo_15_lists.dart` | ListTile, CheckboxListTile, SwitchListTile, Dismissible |

### Advanced

| Demo | Source file | `tom_flutter_ui` widgets exercised |
| ---- | ----------- | ---------------------------------- |
| Trees & Hierarchies | `demo_16_trees.dart` | TreeView, expandable nodes, drag-and-drop trees |
| Slivers | `demo_17_slivers.dart` | SliverAppBar, SliverList, SliverGrid, SliverPersistentHeader |
| Animated Widgets | `demo_18_animated.dart` | AnimatedContainer, AnimatedOpacity, Hero, AnimatedSwitcher |
| Visual Effects | `demo_19_effects.dart` | BackdropFilter, ShaderMask, ColorFiltered, ClipPath |
| Interactions | `demo_20_interactions.dart` | GestureDetector, Draggable, InkWell, MouseRegion |
| Resource Resolution | `demo_21_resource_resolution.dart` | How widgets resolve labels / icons / tooltips from resources |
| Extension Widgets | `demo_22_extension_widgets.dart` | AppBar, NavigationDestination, TableCell, CupertinoTabView, RefreshProgressIndicator |
| Builders, Clips & Base | `demo_23_builders_clips.dart` | FutureBuilder, StreamBuilder, LayoutBuilder, Clips, Opacity, RawChip, EditableText |
| Containers & Layout | `demo_24_containers_layout.dart` | Scaffold, DecoratedBox, Transform, Flow, CustomPaint, GridTile, Slivers |
| Remaining Widgets | `demo_25_remaining_widgets.dart` | Dialogs, Buttons, Navigation, Labels, Lists, Images |

### Scope & Architecture

| Demo | Source file | `tom_flutter_ui` feature exercised |
| ---- | ----------- | ---------------------------------- |
| Scope & Action | `demo_26_scope_action.dart` | `TomScreenElementsProviderBase`, nested scopes, reusable widget trees |
| Forms | `demo_27_forms.dart` | Form fields in scoped providers, validation, ACL form layout |

---

## Forms/Actions (`lib/forms_demos/`)

The form-field framework: concrete `TomForm` field types, validation and the
Phase-2 selection / boolean / breakpoint / authorization variants.

| Demo | Source file | `tom_flutter_ui` feature validated |
| ---- | ----------- | ---------------------------------- |
| Forms Overview | `forms_demos.dart` (`FormsOverviewDemo`) | `TomForm` field concretes (email / password / text / int / double) standalone — `validate()` / `save()` / `reset()` / `getField()` |
| Demo E — Selection Variants | `phase2_demos.dart` (`SelectionVariantsDemo`) | Single/multi-select concretes (Segmented / RadioGroup / ChoiceChips / FilterChips / MultiCheckbox) over one shared `TomSelectableSource<String>` |
| Demo F — Boolean Variants | `phase2_demos.dart` (`BooleanVariantsDemo`) | Boolean concretes (Checkbox / Switch / Toggle) independently, in lock-step, and in a mixed settings layout |
| Demo G — Complex Breakpoints | `phase2_demos.dart` (`ComplexBreakpointsDemo`) | `TomFormStyleScope` with `styleBpOverrides`, nested theme-only scope, two-column → one-column collapse |
| Demo H — Complex Authorization | `phase2_demos.dart` (`ComplexAuthDemo`) | Action-icon auth gating, `UIStateController` cross-field deps, group modes, subform auth ceiling |

---

## Authorization/Resources (`lib/widget_demos/`)

A focused tab that re-surfaces the two screens covering widget authorization and
resource resolution.

| Demo | Source file | `tom_flutter_ui` feature validated |
| ---- | ----------- | ---------------------------------- |
| Resource Resolution | `demo_21_resource_resolution.dart` | Widget label / icon / tooltip resolution from resources (same screen as the Widget Demos tab) |
| Authorization | `demo_28_authorization.dart` | Widget visibility, readonly state, group authorization, `TomUIGroup` |

---

## Reference docs (folded in)

The deeper design / inventory notes that previously stood alone in `doc/`
remain the authoritative references behind this catalogue:

| Document | Scope |
| -------- | ----- |
| `widget_demo.md` | Original specification of the widget demo views (architecture + per-demo intent across the ~292 wrapped widgets). |
| `widget_resource_parameters.md` | Complete inventory of every widget constructor parameter that can be loaded from resources (per-widget ✅/⛔/⬜ status). |
| `widget_optional_parameters_resource_discovery.md` | Proposal for optional-parameter discovery, list-based resources and auto-assembling components. |

This catalogue is the **navigation map**; those three are the **detail**.
