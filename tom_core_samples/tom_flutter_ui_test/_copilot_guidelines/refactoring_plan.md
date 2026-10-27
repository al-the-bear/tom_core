# Tom Flutter UI Test — Refactoring Plan (Application)

Project-specific workflow for cleaning up, documenting, and stabilizing
**tom_flutter_ui_test** — a standalone **Flutter demo / test application**, not a
library. The goal is **clean, well-explained application code** plus clear
documentation of *what the app demonstrates and how each demo works*. It is the
end-to-end exercise harness for the `tom_flutter_ui` widget catalogue, its form
framework, and its **ACL — Advanced Container Layout** engine.

**ACL here means Advanced Container Layout**, not access control. It is
`tom_flutter_ui`'s layout engine: rows, alignment, expand flags, min/preferred/
max sizing, character-width sizing, reference and cross-row constraints,
titled/bordered groups, nested containers, responsive shrink/grow, row
breakpoints, and the fluent `AclBuilder` API. Nothing in `lib/acl_demos/`
touches authorization — resource authorization is demonstrated by
`lib/widget_demos/demo_28_authorization.dart` and the Authorization/Resources
tab, and by `ComplexAuthDemo` in `lib/forms_demos/phase2_demos.dart`.

**Project type:** Flutter application (`publish_to: none`)
**Entrypoint:** `lib/main.dart`

---

## App Structure

| Folder / file | Role |
| ------------- | ---- |
| `lib/acl_demos/` | Demos of the Advanced Container Layout engine (26 screens + 4 support files) |
| `lib/widget_demos/` | Demos of the `tom_flutter_ui` widget catalogue (28 screens) |
| `lib/forms_demos/` | Demos of the form widgets and bindings (5 screens across 2 files) |
| `lib/common/` | Shared scaffolding, theming, helpers |
| `lib/demo_resources.dart` | Resource definitions registered before `runApp` |
| `lib/locale_settings.dart` | Locale configuration for the demos |
| `test/` | The gating suites, plus `demo_harness.dart` and the on-demand `screenshots.dart` |
| `doc/demo_catalogue.md` | Demo → source → exercised `tom_flutter_ui` feature map |

The remaining `doc/*.md` notes (`widget_demo.md` and
`widget_resource_parameters.md`) are widget-resource design notes that feed the
catalogue.

Demo counts are deliberately stated as **screens and tiles separately** — see
the counts table in `README.md`, which `tool/check_demo_counts.py` holds to the
source. A bare demo count is ambiguous even when correct, because one screen can
be listed on two tabs.

---

## Standing conventions

These hold now and are the things a refactoring pass must not undo.

- **Meta files exist** — `README.md`, `CHANGELOG.md` and `LICENSE` (BSD
  3-Clause) are present and tracked at the project root. Keep the CHANGELOG's
  `## Unreleased` section current as work lands.
- **Every demo names its target feature.** All 59 demo classes carry a `///`
  doc naming the `tom_flutter_ui` feature they exercise. A new demo without one
  is incomplete.
- **Bootstrap seams carry `// Why:` comments** — the `main.dart` ordering
  contract, the `demo_resources.dart` merge rationale, and
  `locale_settings.dart`'s idempotent-init / notify-before-persist behaviour.
- **A new demo must be added to three places**, not one: its folder, the tile
  list in `lib/main.dart`, and `demos` in `test/demo_harness.dart`.
  `demo_coverage_test.dart` fails if the app offers a demo the harness cannot
  construct, and `demo_overflow_test.dart` then holds the new screen to the
  layout gate.
- **A test file only carries the `_test.dart` suffix if it can fail.** The
  screenshot harness (`screenshots.dart`) and the shared mount
  (`demo_harness.dart`) deliberately lack it, because the runner collects by
  suffix and a suite that always passes has no business in the gating run.
- **The gating suites are inventoried in `README.md`** and held to set equality
  against `test/` by `tool/check_test_inventories.py` — a suite that runs but is
  unlisted fails, as does a listed name that no longer exists.

---

## Working procedure

Iterate in order. Each step states its **done** condition.

1. **Entry + bootstrap clarity.** Review `main.dart`, `demo_resources.dart`, and
   `locale_settings.dart`; document the startup path and resource/locale setup
   with `// Why:` comments where non-obvious. *Done when the startup path is
   clear from the files.*
2. **Per-area clean-up — `common/`, resources, locale.** Apply clean-code
   principles; remove dead code and unused declarations. *Done when
   `flutter analyze` is clean.*
3. **Per-area clean-up — `acl_demos/`, `widget_demos/`, `forms_demos/`.** Each
   demo should have a short doc comment naming the `tom_flutter_ui` feature it
   exercises. *Done when every demo names its target feature.*
4. **Demo catalogue doc.** Keep `doc/demo_catalogue.md` mapping each demo to the
   widget/feature it validates and how to launch it. *Done when the catalogue
   covers every demo.*
5. **Whole-app QA.** Run `flutter analyze` (zero issues) and `flutter test`
   (all green). No concurrency flag — each suite file gets its own
   `flutter_tester` process, so there is nothing to serialize. *Done when the
   analyzer and the suites are clean.*
6. **Final review.** Confirm README/CHANGELOG/LICENSE are accurate and add a
   `## Unreleased` CHANGELOG entry summarising the pass.

**Use `flutter analyze`, not `dart analyze`.** Both read the same
`analysis_options.yaml` and report the same lints here, but `dart analyze`
**exits 0** on `info`-severity lints while `flutter analyze` exits 1 on them.
Since `flutter_lints` issues most of its rules at `info`, `dart analyze` would
pass a package with lint violations — it reports the problems without gating on
them. Verified by probe: a widget with a missing `key`, a non-const immutable
constructor and a redundant `Container` produced three identical findings from
both commands, `dart analyze` exit 0, `flutter analyze` exit 1.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Clean Code | [`dart/clean_code_principles.md`](../../../../../_copilot_guidelines/dart/clean_code_principles.md) |
| Coding Guidelines | [`dart/coding_guidelines.md`](../../../../../_copilot_guidelines/dart/coding_guidelines.md) |
| Documentation | [`documentation_guidelines.md`](../../../../../_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](../../../../../_copilot_guidelines/dart/unit_tests.md) |
