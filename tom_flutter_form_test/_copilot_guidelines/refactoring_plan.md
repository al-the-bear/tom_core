# Tom Flutter Form Test — Refactoring Plan (Application)

Project-specific workflow for cleaning up, documenting, and stabilizing
**tom_flutter_form_test** — a standalone **Flutter demo / test application**,
not a library. The goal is **clean, well-explained application code** plus clear
documentation of *what the app demonstrates and how each demo works*. It is the
end-to-end exercise harness for the Tom forms stack (`tom_core_flutter` forms
and `tom_flutter_ui` form widgets).

**Project type:** Flutter application (`publish_to: none`)
**Entrypoint:** `lib/main.dart` (+ `lib/main.reflection.dart`,
`lib/reflection_init.dart`)

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

1. **Meta files.** Ensure `README.md` (summary + overview: what the app
   demonstrates, how to run it, what each demo shows), `CHANGELOG.md` (short,
   pre-publish), and `LICENSE` (BSD 3-Clause) exist at the project root.
   `CHANGELOG.md` and `LICENSE` are **missing** — create both (copy the
   BSD 3-Clause `LICENSE` wording from a sibling project). *Done when all three
   exist and the README orients a new reader.*
2. **Entry + bootstrap clarity.** Review `main.dart`, `reflection_init.dart`,
   and `main.reflection.dart`; document the startup path and reflection
   initialization with `// Why:` comments where non-obvious. Only regenerate
   reflection on signature changes. *Done when the startup path is clear from
   the files.*
3. **Per-area clean-up — `common/`, `actions/`, `state/`.** Apply clean-code
   principles; remove dead code and unused declarations; name demos by intent.
   *Done when `dart analyze` is clean for these areas.*
4. **Per-area clean-up — `forms/`, `panels/`, `demos/`, `examples/`.** Each demo
   should have a short doc comment stating which `tom_core_flutter` /
   `tom_flutter_ui` feature it exercises. *Done when every demo names its target
   feature.*
5. **Demo catalogue doc.** In `doc/`, add a catalogue mapping each demo/example
   to the upstream feature it validates, plus how to launch each. *Done when the
   catalogue covers every demo screen.*
6. **Whole-app QA.** Run `dart analyze` (zero warnings) and `flutter test` (all
   green; never run Flutter test invocations in parallel — they corrupt
   results). *Done when analyzer and the existing test suite are clean.*
7. **Final review.** Confirm README/CHANGELOG/LICENSE are accurate; update
   `CHANGELOG.md` with a one-line summary of the cleanup pass.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| Unit Tests | [`dart/unit_tests.md`](/_copilot_guidelines/dart/unit_tests.md) |
