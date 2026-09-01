# Demo & Example Catalogue — Tom Form Framework

This app (`tom_flutter_form_test`) is a manual showcase for the **Tom Form
Framework**: the form widgets and field concretes published by
**`tom_flutter_ui`**, driven by the observable state, reflection, resources and
security APIs of **`tom_core_kernel`**.

> **Upstream package note.** Although the plan wording mentions
> "`tom_core_flutter` / `tom_flutter_ui`", this app depends on **`tom_flutter_ui`**
> (form widgets/fields) and **`tom_core_kernel`** (observables / reflection /
> resources) — it does **not** depend on `tom_core_flutter`. The "feature
> validated" column below therefore names the `tom_flutter_ui` concrete (or the
> kernel API) exercised by each screen.

The two tabs map to the two tables below:

- **Demos tab** — full-featured demos with event logs, inspectors and control
  panels (`lib/demos/`). One screen per row.
- **Examples tab** — stripped-down, copy-friendly sample code with no
  scaffolding (`lib/examples/`). Each H-A…H-E example ships in a **Material**
  and a **Cupertino** flavour selected by a single `ExampleFamily` constructor
  argument.

---

## How to launch

There is **one** Flutter entry point (`lib/main.dart`); individual demos and
examples are not separately runnable — they are reached by navigating inside the
running app.

1. (First run, or after changing a reflected type signature) regenerate the
   reflection metadata:

   ```bash
   ./reflection_generation.sh
   ```

2. Launch the app from the project root:

   ```bash
   flutter run            # add -d <device-id> to target a specific device
   ```

3. The app opens on `RootScreen`, a two-tab shell:
   - **Demos** tab → scroll to the phase section → tap the demo tile.
   - **Examples** tab → tap the Material or Cupertino tile under each H-section.

Each tile pushes its screen with `Navigator.push`; use the back button to return
to the list. Text labels are loaded from `assets/demo_resources.json` (merged
with the Examples section's `example.*` keys) at startup — see `lib/main.dart`.

---

## Demos (`lib/demos/`)

### Phase 1 — Spec-aligned demos

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| A — Lifecycle & Validation | `demo_a_lifecycle.dart` | `TomForm` lifecycle (`bind` / `save` / `discard`), sync / async / cross-field validators, pristine tracking, `TomErrorView` banner, form actions |
| B — Authorization & Events | `demo_b_authorization.dart` | Authorizer + four auth states, groups + modes, UI-state controller, live event bus (`FieldAuthChangedEvent`) |
| C — Nested Forms & Theming | `demo_c_nested_theming.dart` | Nested `TomForm` (CustomerForm + billing/shipping), dirty tracking, live `TomFormStyle` switching, `styleBpOverrides`, per-section styling |
| D — Hide on Authorization | `demo_d_hide_unauthorized.dart` | `setAclDefaultHideUnauthorized`, read / disabled states, row elision, gallery of ten non-form Tom widgets |

### Phase 2 — Extended field flavours

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| E — Selection Variants | `demo_e_selection_variants.dart` | Single/multi-select concretes (FilterChips / MultiCheckbox / Segmented / RadioGroup / ChoiceChips) over one shared `SelectableSource` |
| F — Boolean Variants | `demo_f_boolean_variants.dart` | `TomFormBoolCheckbox` / `TomFormBoolSwitch` / `TomFormBoolToggle`, once as three independent fields and once as a lock-step trio propagating through the observable channel |
| G — Complex Breakpoint Scenarios | `demo_g_breakpoint_scenarios.dart` | `ProjectBriefForm` across four style + theme presets at 400 / 800 / 1200 / 1600 px, every ACL breakpoint API + priority widget-type swap |
| H — Complex Authorization Scenarios | `demo_h_complex_authorization.dart` | Per-field / per-section / form-level auth switches driving verifiable live re-layout |

### Phase 2a — Collections & master-detail

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| H-A — Master-Detail Customer Editor | `demo_h_a_master_detail.dart` | `TomMasterDetailListForm` + `TomListForm`, row sub-form in the detail pane, `TomUnsavedChangesGuard`, `TomReorderHandle`, `TomListFormToolbar` |
| H-B — Expandable Rows (Order Items) | `demo_h_b_expandable_rows.dart` | `TomListForm` as one `ExpansionTile` per row, `TomFormSearchInput` picker, aggregated `isDirty` / `isValid` |
| H-C — Editable Order-Items Table | `demo_h_c_editable_table.dart` | Field widgets in Material `DataTable` cells, computed-total column, `TomReorderHandle`, `TomErrorView`, `TomAclBuilder`, `TomFormStyleScope` |
| H-D — Customer Form (master-detail) | `demo_h_d_customer_form.dart` | Deep form: flat fields + two nested `TomMasterDetailListForm`s, `TomReorderHandle`, `TomListFormToolbar`, `TomUnsavedChangesGuard`, `TomErrorView` |
| H-E — Customer Form (read-only + edit dialogs) | `demo_h_e_customer_form_ro.dart` | `TomMasterDetailListForm` inside a modal edit overlay, read-only summary lists bound to the same `TomClass` instances |

### Phase 3 — Numeric, date/time & duration fields

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| I — Numeric Forms | `demo_i_numeric_forms.dart` | `TomFormIntInput` / `IntSlider` / `IntStepper`, `CurrencyDoubleInput` (locale switcher), `PercentDoubleInput`, `DoubleSlider`, `IntRangeSlider`, `DoubleRangeSlider` over `TomInt` / `TomDouble` |
| J — Date/Time/Duration Forms | `demo_j_date_time_forms.dart` | `TomFormDatePicker`, `DateCalendar` (inline), `TimePicker`, `DateTimePicker`, `DateRangePicker`, `DurationInput`, typed `Date/Time/DateTime` text inputs with configurable `TomDateTimeFormat` |

### Phase 4 — Enum, object, file & nullable fields

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| K — Enum, Object & Lookup | `demo_k_enum_object.dart` | Enum dropdown / segmented / radio / chips, object dropdown + chips, `SearchInput` over a ~5 000-item source, modal `LookupSheet` dialog |
| L — Files & Nullable Variants | `demo_l_file_nullable.dart` | `FileUpload` + `FileDropzone` with a shared in-memory picker, plus a nullable subform (`NString` / `NInt` / `NDouble` / `NDate`) distinguishing pristine vs set vs explicitly-null |

### Phase 5a — Cupertino string + bool + selection

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| M — Material vs Cupertino | `demo_m_cupertino_basics.dart` | Material vs Cupertino concretes side-by-side over one shared state; live `TomFormStyleScope.style` swap (material3 ↔ cupertino) |

### Phase 5b — Cupertino numeric + date/time

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| N — Cupertino numeric + date/time | `demo_n_cupertino_numeric_datetime.dart` | Nine Cupertino numeric / date / time / duration / range concretes inside a nested `TomFormStyleScope` (`style: null`, `themeSpec` swapped by breakpoint) |

### Phase 5c — Cupertino search/lookup/file + family swap

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| O — Cupertino search / lookup / file | `demo_o_cupertino_search_lookup_file.dart` | Cupertino `SearchInput<City>`, `LookupSheet<Country>`, `FileUpload`, and four nullable variants pinned to `TomCupertinoFormStyle.cupertino` |
| P — FormFieldFamily swap by breakpoint | `demo_p_family_swap_breakpoint.dart` | One `Phase5cFamilyForm` resolving Material vs Cupertino concretes via `FormFieldFamily`; `LayoutBuilder` + `styleBpOverrides` flip family + style at 700 px with shared state surviving |

### Phase 6 — Non-form custom widgets (§23)

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| Q — Auth / Empty / Overlay | `demo_q_auth_empty_overlay.dart` | `TomAuthGuard`, `TomEmptyState`, `TomLoadingOverlay` (600 ms simulated save scrim) |
| R — Tree / Radio / Infinite scroll | `demo_r_tree_radio_infinite.dart` | `TomAuthTreeView` (per-node auth + inheritance), `TomRadioGroup` (group-level auth), `TomInfiniteScroll` over 10 000 rows with `TomSkeletonLoader` + `TomErrorBoundary` |

### Supporting reference demos

| Demo | Source file | `tom_flutter_ui` / kernel feature validated |
| ---- | ----------- | ------------------------------------------- |
| 1 — Basic Form | `demo_1_basic_form.dart` | `TomForm` binding, `TomFormStringInput` / `Dropdown`, validators, slow validation with pending state |
| 2 — Nested Forms | `demo_2_nested_forms.dart` | Parent form with nested `AddressForm` + `PersonForm`, hierarchical validation |
| 3 — Authorization | `demo_3_authorization.dart` | Per-resource authorization, dynamic auth changes, read-only and hidden states |
| 4 — Validation | `demo_4_validation.dart` | Fast vs slow validators, validation states, `TomFormInspector` |
| 5 — Settings Form | `demo_5_settings.dart` | Dropdown fields, compact style, boolean toggles |
| 6 — Field Layout Options | `demo_6_field_layout.dart` | Live-switch `labelPlacement`, `requiredIndicator`, `descriptionPlacement` |
| 7 — Error Placement | `demo_7_error_placement.dart` | `ErrorPlacement` options incl. `replaceDescription`; 3-step error-message resolution chain |
| 8 — Breakpoints | `demo_8_breakpoints.dart` | Draggable splitter drives `TomFormStyleScope` width; gaps / error border / error icon react via breakpoint overrides |
| 9 — Preset Showcase | `demo_9_preset_showcase.dart` | Grid of field types × presets (material3 / compact / bordered) with a `withTheme()` toggle |
| 10 — Central JSON-Driven Style | `demo_10_central_json_style.dart` | Single root-level `TomFormStyleScope`; every style property + breakpoint variant defined in `demo_resources.json` |

---

## Examples (`lib/examples/`)

Each H-section example is one source file rendered in two flavours (Material /
Cupertino) selected by the `ExampleFamily` constructor argument — switching
family is the **only** difference between the two tiles; layout, form definition
and state binding are family-agnostic.

| Example | Source file | `tom_flutter_ui` / kernel feature validated | Flavours |
| ------- | ----------- | ------------------------------------------- | -------- |
| H-A — Master / Detail | `examples/example_h_a_master_detail.dart` | `TomMasterDetailListForm` + `TomListForm`, `AclBuilder` rows, breakpoint-aware master pane, static resources/auth maps, `FormFieldFamily` | Material · Cupertino |
| H-B — Expandable rows | `examples/example_h_b_expandable_rows.dart` | `TomExpandableListForm` (header/summary/body/toolbar builders + controller), per-row `AclBuilder` breakpoints, `TomMultiObservableBuilder` summaries, `FormFieldFamily` | Material · Cupertino |
| H-C — Editable table | `examples/example_h_c_editable_table.dart` | Editable items table with int/double inputs, derived line totals, 720 px column-to-card reflow, `FormFieldFamily` | Material · Cupertino |
| H-D — Full customer form | `examples/example_h_d_customer_form.dart` | Rich form across every field family (string / search / bool / int / double / date) + address & order master-detail sub-lists, `AclBuilder` 700 px reflow | Material · Cupertino |
| H-E — Read-only with edit dialogs | `examples/example_h_e_read_only.dart` | Same data graph as H-D as compact read-only rows; per-row Edit opens a modal form; Save commits / Cancel discards through the observable | Material · Cupertino |

Shared example infrastructure lives in `examples/shared/`
(`example_resources.dart`, `example_authorization.dart`, `example_scaffold.dart`),
the example forms in `examples/forms/`, and the example state in
`examples/state/`.
