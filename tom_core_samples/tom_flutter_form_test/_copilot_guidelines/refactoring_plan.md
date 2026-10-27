# Tom Flutter Form Test — Refactoring Plan (Application)

Project-specific workflow for cleaning up, documenting, and stabilizing
**tom_flutter_form_test** — a standalone **Flutter demo / test application**,
not a library. The goal is **clean, well-explained application code** plus clear
documentation of *what the app demonstrates and how each demo works*. It is the
end-to-end exercise harness for the Tom forms stack: the form widgets and field
concretes published by **`tom_flutter_ui`**, driven by the observable state,
reflection, resources and security APIs of **`tom_core_kernel`**.

**The app does not depend on `tom_core_flutter`** — see `pubspec.yaml`. The
upstreams are spelled out because that substitution is an easy one to make, and
it has been made here before.

**Project type:** Flutter application (`publish_to: none`)
**Entrypoint:** `lib/main.dart` (+ `lib/main.reflection.dart`, generated from it)

---

## App Structure

| Folder | Role |
| ------ | ---- |
| `actions/` | Action wiring used by the demos |
| `common/` | Shared scaffolding, theming, helpers |
| `demos/` | Interactive demo screens |
| `examples/` | Worked examples (`forms/`, `shared/`, `state/`) |
| `forms/` | Form definitions exercised by the app |
| `panels/` | Demo panels / navigation |
| `state/` | Observable state used by the demos |

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

1. **Meta files.** `README.md` (summary + overview: what the app demonstrates,
   how to run it, what each demo shows), `CHANGELOG.md` (short, pre-publish) and
   `LICENSE` (the workspace BSD 3-Clause, matching the sibling `tom_core_*`
   packages) all **exist** at the project root and are tracked. *Done when the
   three stay accurate — i.e. a cleanup pass adds its CHANGELOG line and the
   README still orients a new reader.*
2. **Entry + bootstrap clarity.** Review `main.dart` and `main.reflection.dart`;
   document the startup path and reflection initialization with `// Why:`
   comments where non-obvious.

   Regenerate reflection when a reflected signature changes — **or when
   `./reflection_generation.sh --check` says the committed mirror no longer
   matches its source.** The second case is not hypothetical: a generator fix
   changes what the same sources produce, and the mirror in git is the one
   `initializeReflection()` registers. `--check` is the exact gate (four to
   eleven minutes, it regenerates and compares); `test/reflection_currency_test.dart`
   is the fast one that runs in the suite and catches the mistake people
   actually make — a class or state field added and the slow script forgotten.

   Read the generator's closing line when you do regenerate. A run that ends
   `N SEVERE diagnostic(s) … the generated mirror is incomplete` wrote a file
   that describes less than the source does, and that is invisible to both
   `flutter analyze` and the suite. *Done when the startup path is clear from
   the files and `--check` passes.*
3. **Per-area clean-up — `common/`, `actions/`, `state/`.** Apply clean-code
   principles; remove dead code and unused declarations; name demos by intent.
   *Done when `flutter analyze` is clean for these areas.*
4. **Per-area clean-up — `forms/`, `panels/`, `demos/`, `examples/`.** Each demo
   should have a short doc comment stating which `tom_flutter_ui` /
   `tom_core_kernel` feature it exercises. *Done when every demo names its target
   feature.*
5. **Demo catalogue doc.** `doc/demo_catalogue.md` **exists** and maps all 33
   demo screens and the examples to the upstream feature each validates, plus
   how to launch them. *Done when it still covers every demo screen — a new
   demo means a new catalogue row.*
6. **Whole-app QA.** Run `flutter analyze` and `testkit :test` — no concurrency
   flag, since each suite file gets its own `flutter_tester` process. Measured
   2026-09-05:

   | Gate | Result |
   | ---- | ------ |
   | `flutter analyze` | 25 issues, every one an `info`-level `unnecessary_import`; zero errors, zero warnings |
   | `testkit :test` | 501 passed, 0 failed |

   **The suite is green.** It was not always: an earlier pass recorded 22
   failures with two distinct causes — 21 from the kernel refusing the
   `examples/` subsystem's dotted scope ids
   (`scope_ids.init_scope.separator_in_id`) and one in
   `list_form_widget_repro_test.dart`, where "Discard all" failed to restore a
   removed items row. Both are fixed. A green suite is therefore the standard
   here, not a number to match: a single failure is a regression. *Done when a
   pass leaves the suite green and every analyze issue `info`-level; any error
   or warning is yours to explain.*
7. **Final review.** Confirm README/CHANGELOG/LICENSE are accurate; update
   `CHANGELOG.md` with a one-line summary of the cleanup pass.

---

## Known Defects

### Demo P pairs each family with the other family's style

`lib/demos/demo_p_family_swap_breakpoint.dart` states its intent in a comment at
`:78-79` — "Width >= 700 px → Material3, width < 700 px → Cupertino" — and the
family selector at `:87-90` implements exactly that (`isWide ? material :
cupertino`). The `TomFormStyleScope` above it does the opposite:

```dart
style: const TomFormStyle(),                              // :81
styleBpOverrides: [
  (_phase5cBreakpoint, TomCupertinoFormStyle.cupertino),  // :83
],
```

`styleBpOverrides` entries are `(minWidth, style)` and resolution picks the
highest `minWidth <= width` (`tom_flutter_ui/.../tom_form_style_scope.dart`), so
an entry keyed at 700 applies **at and above** 700 — the Material side. The base
`style:` covers everything below the lowest override — the Cupertino side. Demo
P therefore renders the Material family in Cupertino chrome above the breakpoint
and the Cupertino family under the Material3 default below it: each family
wearing the other's dress.

The correction is to swap the two values — `TomCupertinoFormStyle.cupertino` as
the scope's base and `TomFormStyle.material3` as the override at
`_phase5cBreakpoint` — leaving the family selector and the badge alone, since
four artifacts (the comment, the selector, the badge, the demo catalogue) already
agree on wide = Material.

The pairing is easy to invert because the wrong form reads more naturally, and
no assertion here distinguishes the two: the demo has no widget test, and a test
that checks only which *family* renders passes either way. A regression test must
read the resolved style — `TomFormStyleScope.of(context)` from a descendant —
and assert `isA<TomCupertinoFormStyle>()` plus `defaults.borderRadius` (6.0 for
the Cupertino preset, 8.0 for Material3) on both sides of the breakpoint and at
the boundary itself. `TomCupertinoFormStyle.withTheme` re-wraps its result to
preserve the subtype precisely so that check stays answerable.

A working reference implementation of both the fix and the test lives in
`tom_core_samples/core_flutter_acl_responsive` (`lib/groups/family_swap_group.dart`
and `test/family_swap_test.dart`), which was re-cast from this demo.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Clean Code | [`dart/clean_code_principles.md`](../../../../../_copilot_guidelines/dart/clean_code_principles.md) |
| Coding Guidelines | [`dart/coding_guidelines.md`](../../../../../_copilot_guidelines/dart/coding_guidelines.md) |
| Documentation | [`documentation_guidelines.md`](../../../../../_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](../../../../../_copilot_guidelines/dart/unit_tests.md) |
