## Unreleased — cleanup pass

- **Both demo-logic suites described a coverage landscape that had moved under
  them.** A suite's opening docstring is the argument for why it exists, so the
  claim it makes about what came before is the one part a reader is most likely
  to take on trust and least likely to re-derive.

  `forms_demos_logic_test.dart` said the five forms demos were touched only by
  "the screenshot harness (mount-once) and `widget_test.dart` (tab labels)".
  Every part of that was wrong by the time it was read. `widget_test.dart`
  touches none of them — it asserts four tab labels and three ACL tile titles
  and never opens the Forms/Actions tab. The screenshot harness is not the
  mount source but one of four consumers of the shared `demos` list, three of
  which are gates. And the sentence was written when the four Phase-2 screens
  were missing from that list; they were added when the harness went 55 → 59,
  and the docstring did not follow.

  The correction is not a smaller claim but a stronger one, because the
  original was arguing the wrong thing. What matters is not *how few* suites
  reach these demos — four do — but that every one of them only **mounts**
  them: `demo_overflow_test` measures them for overflow, `demo_coverage_test`
  constructs them, `forms_dispose_test` mounts and unmounts them twice,
  `screenshots.dart` captures them. Between them they make **zero** `tap` and
  **zero** `enterText` calls. A mount proves a demo builds and fits and says
  nothing about whether its logic is right — which is the actual case for this
  suite, and it survives the correction intact.

  `widget_demos_logic_test.dart` carried the same fault one file over, found by
  sweeping for the shape rather than the wording: it called the widget demos
  "otherwise mount/screenshot-only", which stopped being true when
  `demo_04_radio_group_test.dart` began driving `widget_04_toggles`. It now
  names that exception.

  Both rewrites state their claims as counts a reader can check with one grep,
  rather than as impressions. No new gate was added: the half that actually
  went stale — harness membership — is already gated by `demo_coverage_test`,
  which fails when the app offers a demo `demos` cannot construct, and a
  checker for "no other suite drives these" would be a grep heuristic offering
  more confidence than it earns.
- **The four Phase-2 forms demos now name the feature they exercise**, which
  closes the last gap in a convention the other 55 demos already kept: all 26
  ACL and all 28 widget demo classes carried a `///` doc naming their
  `tom_flutter_ui` target, while `SelectionVariantsDemo`, `BooleanVariantsDemo`,
  `ComplexBreakpointsDemo` and `ComplexAuthDemo` had only the `// ====` banner
  giving their letter and title. A banner says *which* demo this is; the doc
  says *what it is for*. 59 of 59 now carry one.
- **The local refactoring plan described a project that no longer exists, and
  glossed ACL as access control.** `_copilot_guidelines/refactoring_plan.md` is
  the only project-specific guideline this package has, so its errors are the
  first thing a new reader inherits.

  The damaging one was the gloss: the intro called this the harness for "ACL
  (resource authorization) behavior" and the structure table read `acl_demos/`
  as "Demos of resource authorization / access control". **ACL here is Advanced
  Container Layout** — the layout engine — as the folder's own barrel, all 26
  demo classes, the README and the catalogue all say. `lib/acl_demos/` contains
  no authorization API whatsoever (grepped: zero hits for `Authoriz`,
  `Permission`, `accessControl`), and authorization actually lives in
  `demo_28_authorization.dart` and `ComplexAuthDemo`. Someone following that
  table would have gone looking for authorization in the layout demos and found
  none of it.

  It also declared `CHANGELOG.md` and `LICENSE` "**missing** — create both".
  Both were added by `64a13a59` — the same commit that wrote the 1.0.0 entry —
  so the instruction had been stale since the day the files landed.

  The plan is rewritten to describe the project as it is: the corrected ACL
  meaning and where authorization really lives, a structure table that includes
  `test/` and `doc/`, the standing conventions a pass must not undo (the meta
  files, the per-demo docs, the `// Why:` bootstrap comments, the three places a
  new demo must be registered, the "no `_test.dart` suffix unless it can fail"
  rule, and the gated inventories), and a procedure whose done-conditions are
  the commands that actually run.
- **`dart analyze` is not a gate for this package, and the plan prescribed it
  twice.** This is the same command confusion as the CHANGELOG entry below, but
  worse, because here it was the *instruction* rather than the record — and
  measuring it showed the difference is not cosmetic. Both commands read the
  same `analysis_options.yaml` and report the *same* findings; but on a probe
  widget with a missing `key`, a non-const immutable constructor and a redundant
  `Container`, `dart analyze` reported all three and **exited 0**, while
  `flutter analyze` reported all three and **exited 1**. `flutter_lints` raises
  most rules at `info` severity, so a done-condition of "`dart analyze` is
  clean" would have been satisfied by a package full of lint violations. The
  plan now says `flutter analyze` and records why.
- **The 1.0.0 entry's demo counts were wrong when they were written, and are
  corrected rather than left standing as history.** It claimed "27 layout
  demos"; `lib/acl_demos/` holds 26 screens and four support files (the barrel,
  `demo_helpers`, `expanding_box`, `resizable_box`), and `doc/demo_catalogue.md`,
  the completion document and `AclDemosTab` have all said 26 throughout.

  The distinction matters, because a release log normally *should* be left
  alone — an earlier repair in this same pass declined to touch it on exactly
  that ground. So the premise was checked instead of assumed: `git log
  --diff-filter=DR` over `lib/acl_demos/` is **empty** — no ACL demo has ever
  been deleted or renamed — and every one was added in `1b501689`
  (2026-03-31), two and a half months *before* `64a13a59` (2026-06-16) wrote
  the entry. At that commit `AclDemosTab` already listed 26 tiles. There is no
  state of this repository in which 27 was true, so this is a miscount, not a
  record of a former shape, and correcting it removes an error instead of
  falsifying a release.

  The same entry's widget bullet is corrected on the same evidence: it paired
  "27 per-category widget showcases" with the range `demo_01…demo_28`, then
  added "plus the resource-resolution and scoped-element-provider demos" —
  which double-counted, since `demo_21` and `demo_26` are inside the range it
  had just given. It now states the 28-screens / 27-tab-entries split and the
  reason for it, as the README does.
- **The recorded gate is now the command that runs.** An Unreleased entry
  recorded `dart analyze` as the verification for what is a Flutter
  application, where `flutter analyze` is the gate. (`dart analyze` does run
  here and reports "No issues found!" — so nothing was being hidden; the
  CHANGELOG simply named a verification other than the one performed.)
- **`tool/check_demo_counts.py`** — the third defect filed against this one
  number, so the number is now checked. Two earlier repairs each restated a
  count that nothing verified, which is why there was a third. The gate reads
  the demo classes out of `lib/` and the tiles out of `lib/main.dart`, and
  holds the README's counts table to both.

  It reports **screens and tiles side by side** because a bare count is
  ambiguous *even when it is right*: 28 widget screens produce 29 widget tiles,
  and the app declares 59 screens while offering 60. A document must now say
  which it means. Counting classes rather than files is likewise deliberate —
  `lib/forms_demos/` packs five demos into two files, so a file count gets that
  row wrong.

  Falsified in six directions before being trusted: a wrong screen count, a
  wrong tile count, a deleted row, a demo added to `lib/` but not to the
  document, a tile naming a class no folder declares, and a demo folder renamed
  away. The fifth and sixth exposed a defect in the checker itself — the two
  source-side branches counted a fault but printed nothing, so the run exited
  non-zero with no reason on stdout. Fixed, then re-provoked to confirm.
- **The README now names all eleven gating suites, and the list is gated.** An
  earlier entry below records replacing the README's stale five-name list with
  the discovery rule — "`flutter test` takes `*_test.dart`; no list is kept here
  to fall out of date". That was accurate and it was the wrong repair. The rule
  describes what the *runner* collects, which a reader can work out from the
  directory; what they cannot work out is what the suite is *for*, and the
  package's front door said nothing about it. The omission was also already
  self-contradicted, since the section went on to devote a full paragraph to
  `demo_overflow_test.dart` — a partial inventory kept for the one suite worth
  explaining.

  A list is kept because it can now be *checked*.
  `tool/check_test_inventories.py` gained the ability to register a document
  outside the quest completion folder (`INVENTORIES` entries carry an explicit
  document path rather than resolving against one hard-coded root), and this
  README is registered against `test/`. It fails on a suite that runs but is
  unlisted, and on a name listed that no longer exists — the two ways the old
  list rotted. Both directions were provoked before being trusted: renaming a
  row's file reported `UNLISTED widget_test.dart`, and listing a
  `golden_baseline_test.dart` that does not exist reported `PHANTOM`.

  `tom_flutter_ui_test` is now inventoried twice, by its completion document and
  by its README, deliberately: the two are read by different people, and both
  are held to set equality against the same directory, so they cannot drift
  apart. Gate `2 → 3` inventories, `72 → 83` files, 0 faults.
- **"27 widget showcases" contradicted the README's own layout table**, which
  says `demo_01…demo_28`. Both numbers were right and neither said so: the
  Widget Demos tab lists `demo_01…demo_27`, while `demo_28_authorization.dart`
  is surfaced from Authorization/Resources, which *also* repeats
  `demo_21_resource_resolution.dart`. So 28 screens produce 29 widget tiles.
  The README states the split and the reason for it rather than a bare count —
  the same trap as the 59-screens/60-tiles one, and `demo_coverage_test.dart`
  compares by runtime type precisely because of it.
- **Two suites were in the gate that could not fail.** `debug_form_test.dart`
  and `debug_heights_test.dart` mounted a layout, `print()`ed measurements and
  contained no `expect` between them — three tests whose only cost was their
  mount time. This is the criterion the package had already applied to the
  screenshot harness, and written down: `screenshots.dart` explains that it
  dropped the `_test.dart` suffix because "a suite that always passes has no
  business in the gating run". The two debug files were the same artefact and
  had kept the suffix.

  Both are **deleted** rather than renamed, because neither investigation is
  open. `debug_form_test` was probing "the 3397 px overflow reported in the
  engine" in `comprehensive_form` — an overflow this same cleanup pass fixed
  (`acl_19`, `isExpanded` + a 500→540 `ResizableBox`) — and it was never
  finished: it declared `var flexWidths = <double>[]`, never wrote to it, and
  printed `flexWidths=[]` unconditionally. The demo itself stays gated against
  overflow by `demo_overflow_test.dart`, which mounts `acl_19` with the other
  58, so deleting the probe costs no coverage.

  `debug_heights_test` was the one with something to say, and it is said
  properly now — see the `tom_flutter_ui` entry of the same date. Its rects
  were of a raw `AclBuilder`, not of any demo: a library test that had been
  living in the demo app.

  `debug_shrink_test.dart` keeps its name and its place. It has a real `fail()`
  for anything that is not the by-design minimum-size overflow, so it is a gate;
  the `debug_` prefix describes how the file reads, not whether it can fail.

  Gate `+116 → +113`, the three assertionless tests and nothing else;
  `flutter analyze` clean.
- **The demo app was the one consumer left behind by the `RadioGroup<T>`
  ancestor migration**, and the omission was larger than it looked.
  `demo_04_toggles.dart` still passed `groupValue:` / `onChanged:` to its five
  radio groups — 18 `undefined_named_parameter` errors — and three uses of the
  kernel's `>>` operator did not resolve. `flutter analyze` reported 21 errors,
  and four test files never loaded as a result, **`demo_overflow_test.dart`
  among them**: the layout gate was not missing four demos, it was measuring
  none. All five groups now sit under a `RadioGroup<String>` that carries the
  selection, and the radios forward only their `value`. Analyze clean.
- **The four Phase-2 forms screens are in the harness** (`demos` in
  `test/demo_harness.dart`: 55 → 59 slugs, all passing the overflow gate).
  `SelectionVariantsDemo`, `BooleanVariantsDemo`, `ComplexBreakpointsDemo` and
  `ComplexAuthDemo` are the widest layouts in the package — Demo G is a
  two-column → one-column collapse — so they were the demos most likely to
  overflow, not the least.
- **`test/demo_coverage_test.dart`** — opens each of the four tabs, reads the
  screen off every `DemoTile` the app builds, and fails when `demos` cannot
  construct one of the same type. Keeping the two in step was a documented
  manual step in the "Adding a demo" procedure, and that is exactly the step
  that was skipped; this replaces the instruction with a failure. The
  comparison is by runtime type, not by slug — a slug is the harness's own name
  and proves nothing about the app.
- **`test/demo_04_radio_group_test.dart`** — pins the migrated wiring, which
  otherwise fails silently: a radio with no `RadioGroup` ancestor still
  compiles, renders unselected and does nothing. Asserts each of the five
  groups starts on its seed and that picking a value moves that group alone.
- README: the test-file inventory named 5 files when 12 exist. Replaced the
  enumeration with the discovery rule (`flutter test` takes `*_test.dart`;
  `screenshots.dart` and `demo_harness.dart` deliberately lack the suffix) so
  no list is kept there to fall out of date.

  Default `flutter test` gate `+116 / 0`, serial (was `+37 / -4`);
  `flutter analyze` clean.

- Follows `tom_flutter_ui`'s removal of the `TomUIGroup` alias: the demo app
  names `TomAuthorizationGroup` throughout. `phase2_demos.dart` also drops its
  `tom_core_kernel` import, which became redundant once `tom_flutter_ui` began
  re-exporting `AuthGroupMode`.
- Documentation: added intent-explaining `// Why:` comments to the bootstrap
  seams (`main.dart` ordering contract, `demo_resources.dart` merge rationale,
  `locale_settings.dart` idempotent-init / notify-before-persist), and a
  feature-naming `///` doc to each of the 26 `acl_demos/` demo classes (the
  widget/forms demos were already documented).
- Added `doc/demo_catalogue.md`: a four-table navigation map (one per tab)
  linking every demo tile → source file → the `tom_flutter_ui` API/widget it
  validates, with the correct launch path (no codegen / no asset bundle) and
  the pre-existing `doc/*.md` widget-resource notes folded in.
- Dead-code removal: deleted the unused `lib/common/demo_widgets.dart`, removed
  the unreferenced `DemoGrid` / common `ExpandingBox` from `demo_scaffold.dart`,
  and dropped the vestigial `fullScreen` flag plumbed through `DemoTile` /
  `DemoScaffold` but never read.
- Tests: reclassified `test/screenshots_test.dart` → `test/screenshots.dart`
  (a manual capture-and-diff harness, per its own docstring not a gate) and
  fixed its fake-async raster deadlock via `tester.runAsync()`; drained the
  by-design overflow in `debug_shrink_test.dart` so its measurement loop
  completes. `flutter analyze` clean; default `flutter test` gate `+6 / 0`,
  serial.
- Layout gate: extracted the demo mount into `test/demo_harness.dart` and added
  `test/demo_overflow_test.dart`, which fails when a demo overflows the
  1280x2400 viewport. The gate measures the Ahem placeholder font — wider than
  Roboto, and present on every machine — while the screenshot harness keeps the
  real SDK fonts so its PNGs stay readable.
- Layout fixes for the four demos the gate found: `widget_04_toggles` gives its
  three-radio `TomRow` `expandX()` instead of the builder's 150 px default
  width; `acl_19_comprehensive_form` sets `isExpanded` on the width-pinned
  priority dropdown so its label ellipsizes; and `acl_17`, `acl_19`, `acl_20`
  size their `ResizableBox` frames with real slack (320→360, 500→540, 300→380)
  rather than to within 3 px of their content.

  Default `flutter test` gate `+105 / 0`, serial; `flutter analyze` clean.

## 1.0.0

- Demo / smoke-test application for the **Tom Flutter UI** library: a four-tab
  Flutter showcase (ACL Demos, Widget Demos, Forms/Actions,
  Authorization/Resources) exercising the `tom_flutter_ui` Advanced Container
  Layout engine, the Tom-wrapped Material/Cupertino widget set, and the form /
  authorization framework, driven by `tom_core_kernel` resources and security.
- ACL Demos: 26 layout demos (rows, alignment, expand flags, spacing,
  min/preferred/max sizing, character-width sizing, reference and cross-row
  constraints, titled/bordered groups, nested containers, responsive shrink/grow,
  row breakpoints, fluent `AclBuilder`).
- Widget Demos: 28 per-category widget screens (`demo_01…demo_28`), of which the
  tab lists `demo_01…demo_27`; `demo_28_authorization.dart` and a second entry
  for `demo_21_resource_resolution.dart` are surfaced from the
  Authorization/Resources tab instead.
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
- Added this `CHANGELOG.md` and a `LICENSE` (the workspace BSD 3-Clause license,
  matching the sibling `tom_flutter_ui` / `tom_core_*` packages).
