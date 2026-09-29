## Unreleased — cleanup pass

Each pass count below (`+513`, `+491`, `+433 -22`) is the one its change was
measured at, and stays as the evidence for that change; it is not a description
of the suite today. The current suite is described in the README's
[Tests](README.md#tests) section, whose figures a gate holds to `test/`.

- The Demos tab's grouping is stated once and checked. The README said the tab
  had three sections; it renders ten, the same ten `doc/demo_catalogue.md` uses.
  The README now names them, and `demo_catalogue_sections_test.dart` reads the
  section headers and `Demo <id>:` tiles out of `lib/main.dart` and holds the
  catalogue's headings, the demos under each, and the README's counts to them.
  The Phase 6 header lost a bare "(§23)" that named no document; the catalogue
  cites `tom_ui_widgets_forms.md` §23 by name instead.
- The Phase 2a order items keep `quantity` / `unitPrice` as text, and
  `lib/state/phase2a_state.dart` now gives the reason that holds: these demos
  are about invalid rows, and only typed text reaches the validators'
  non-number branch. `phase2a_h_b_errors_test.dart` pins that case. The
  numerically typed order item is the Examples tab's.
- The README says why there is no `example/` directory: the app has no
  importable surface, and its Examples tab is the package's examples.
- Suite: `+513`, `flutter analyze` clean.
- Multi-selects bind like every other field. With the kernel re-typing a
  serialized list for a `List<String>` field, `ProjectBriefForm` carries
  `tags` as a member bound to `ProjectBrief.tags`, and Demo G drops the field
  it owned, its seed and its hand-written write-back; the tag edit now reaches
  the brief on Save, inside dirty tracking and `discard()`.
  `Phase5DemoState` gains the `tags` member it had to omit, and Demo M's
  panels open on its seed.

- **The suite takes a bare `flutter test`; the `-j 1` in the refactoring plan is
  gone.** Serial runs were required on the ground that parallel test isolates
  would corrupt process-global state — the resource bundle, the authorization
  adapter, the reflection registry the forms build. They cannot: `flutter test`
  gives **every suite file its own `flutter_tester` process** (measured —
  twelve suites at default concurrency, twelve distinct pids, no reuse), so
  each file's registrations are its own. Tests *within* a file share a process
  and still reset in `setUp`/`tearDown`, but package:test runs them one at a
  time regardless of `-j`. No suite here opens a socket, writes a file or
  reaches a database, so there is nothing outside the process to contend for
  either. Confirmed by running the full `+491` without the flag, repeatedly,
  green each time and about twice as fast. The convention's source,
  `tom_core_samples/README_advanced_12_testing_integration.md`, carries the
  measurement.

- Docs only: 32 source comments cited a bare section number — `§24b Demo A`,
  `spec §16`, `review finding tests §64` — of a workspace-only planning
  document that ships with neither this package nor its tests. Each now states
  what it meant in its own words. The two that genuinely referred to a
  shipped document name it: `OrderForm` and `tom_list_form_test.dart` cite
  `tom_flutter_ui`'s `doc/tom_ui_list_forms.md` for the List Forms pattern.
  Suite unchanged at `+491`.

- Fix: the suite is green — `+491 -0`, from `+433 -22`. The 21 scope-id
  failures are gone because the `examples/` forms no longer spell their ids
  with a `.`: `example.customer` is now `exampleCustomer`, and likewise for
  `exampleOrder`, `exampleOrderItem` and `exampleAddress`. A form id is handed
  to `TomScope.withScope` and joined into the form's `basePath`, so it *is* a
  scope id, and the kernel refuses one containing the separator that scope
  paths are joined with — `example.customer` rendered identically to the
  unrelated chain `example` → `customer`, which is how a form named from data
  could reach another scope's resources. The `example` prefix therefore moved
  *inside* the id rather than staying a level above it, and the paths that
  follow the ids moved with them: `shared/example_resources.dart` now has five
  prefixed top-level keys where it had one nested `example` key, and the ACL
  entry in `shared/example_authorization.dart` is keyed `exampleCustomer.tier`.
  `form_ids_are_usable_scope_ids_test.dart` now holds every id in the package
  to the rule, by handing it to the kernel rather than by restating it.
- Fix: the 22nd failure had a cause of its own and is fixed in `tom_flutter_ui`
  — "Discard all" on a root form blanked the detail pane of any
  `TomMasterDetailListForm` below it. `TomListForm` rebuilds its sub-forms
  between `onBeforeClear` and `onAfterReset`, and each step of that rebuild was
  forwarded to its observers, so the master-detail widget heard that the list
  had emptied, cleared its selection accordingly, and had nothing to restore it
  when the rows came back. The rebuild is now one notification, as
  `TomList.resetWith` already promised its own observers.
- Documentation: `pubspec.yaml` and `analysis_options.yaml` stripped of their
  `flutter create` scaffolding — 95 lines down to 45 and 33 down to 6. The
  pubspec's `description` said "A new Flutter project."; it now states what the
  app is. Removed were the publishing/versioning preamble, the "how to upgrade
  dependencies" note, the asset-variant and package-asset explanations, and a
  commented-out `fonts:` example for two fonts the app does not use; the
  `cupertino_icons` rationale is kept, being the one comment that records a real
  decision. From `analysis_options.yaml` went the header, the trailing link, and
  a `linter: rules:` block whose every entry was commented out — `flutter
  analyze` reports the same 20 issues before and after, so it configured
  nothing. The same template `description` ("A new Flutter project.") was also
  replaced in `web/manifest.json` and `web/index.html`, where it is visible in
  the browser tab and the PWA install prompt.
- Documentation: `_copilot_guidelines/refactoring_plan.md` reconciled with the
  project it describes — it named `tom_core_flutter` (never a dependency; see
  `pubspec.yaml`) as an upstream, called `CHANGELOG.md` and `LICENSE` missing
  when both are tracked, said a catalogue still had to be written when
  `doc/demo_catalogue.md` covers all 33 demo screens, and prescribed
  `dart analyze` where a Flutter application is gated by `flutter analyze`. Its
  QA step now carries the measured baseline instead of an unreachable "all
  green". `doc/demo_catalogue.md` dropped the correction note that existed only
  to work around the plan's wrong upstream.
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
- Tests: renamed `demo_tests.dart`, `form_validation_tests.dart`,
  `layout_tests.dart` and `screenshot_tests.dart` to the singular
  `*_test.dart`. `flutter test` discovers `**_test.dart` only, so the plural
  names matched nothing and all 43 of their tests had never run — hiding one
  test that had rotted against the grown demo list and five golden baselines
  (`demo1`–`demo5`) that nothing compared. `demo_test.dart` T01 now scrolls
  with `maxScrolls: 200` in addition to the scoped `scrollable:` finder: its
  first hop crosses the whole 33-tile list and needs ~60 drags of 80 px, past
  the default budget of 50.
- Quality: `flutter analyze` clean over `test/` (zero issues). Full `flutter
  test -j 1` runs 455: `+433 -22`. The 22 failures are pre-existing and
  unchanged in count, file and name by the work above, and have **two** causes:
  21 come from the kernel rejecting the `examples/` subsystem's dotted scope ids
  (`example.customer`, `example.order`) with
  `scope_ids.init_scope.separator_in_id`; the 22nd is unrelated to scope ids —
  `list_form_widget_repro_test.dart:249`, where "Discard all" leaves the items
  list short of the 3 rows it must restore. No production behaviour changes.

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
- Added this `CHANGELOG.md` and a `LICENSE` (the workspace BSD 3-Clause license,
  matching the sibling `tom_core_*` packages).
