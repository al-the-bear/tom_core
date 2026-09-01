## Unreleased — cleanup pass

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
