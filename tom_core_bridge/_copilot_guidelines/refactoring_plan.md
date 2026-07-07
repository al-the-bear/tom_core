# Tom Core Bridge — Refactoring Plan (Application)

Project-specific workflow for cleaning up, documenting, and stabilizing
**tom_core_bridge** — a standalone **executable**, not a library. The goal is
not per-module API documentation but **clean, well-explained application code**
plus clear documentation of *what the application does and how it runs*.

**Project type:** Standalone executable (`publish_to: none`)
**Entrypoint:** `bin/core_bs.dart`
**What it does:** Extended VS Code bridge server. It combines
`tom_vscode_bridge` (the base bridge server) with `tom_core_d4rt` (the full Tom
Framework D4rt bridges) into a single binary that the VS Code extension can
launch as an alternative to the basic `tom_bs` bridge. It communicates with the
extension over stdin/stdout using a JSON-RPC-like protocol and exposes all Tom
Framework classes/functions inside the D4rt scripting environment.

---

## Concrete Step List

Iterate in order. Each step states its **done** condition.

1. **Meta files.** Ensure `README.md` (summary + overview: what the binary is,
   how to build it, how to register it in the VS Code extension), `CHANGELOG.md`
   (short, pre-publish), and `LICENSE` (BSD 3-Clause) exist at the project root.
   `CHANGELOG.md` is **missing** — create it. *Done when all three exist and the
   README explains the binary's purpose and usage.*
2. **Entrypoint clarity.** Review `bin/core_bs.dart`; confirm `main()` is thin
   and only wires `VSCodeBridgeServer` with the bridge registrars. Document the
   stdin/stdout protocol contract and the `additionalBridgeRegistrars` argument
   with `// Why:` comments where the wiring is non-obvious. *Done when a new
   reader can understand the startup path from the file alone.*
3. **Dependency boundaries.** Verify the binary only orchestrates
   `tom_vscode_bridge` + `tom_core_d4rt` and contains no logic that belongs in
   those libraries. If shared behavior has crept in, push it down into the owning
   library. *Done when `lib/src/` holds only app-local glue (plus the generated
   `version.versioner.dart`).*
4. **Clean code pass.** Apply
   [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md)
   and [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md):
   naming, early returns, no dead code, error handling at the process boundary.
   *Done when `dart analyze` is clean (zero warnings).*
5. **Operational docs.** In `doc/`, document how to build the binary, where the
   built artifact is placed, how to point the VS Code extension at it, and how to
   troubleshoot a failed launch. *Done when the run/deploy story is captured.*
6. **Smoke test.** Add at least one test (or a documented manual smoke
   procedure) that builds the binary and verifies it starts and answers a
   minimal bridge request. *Done when the smoke check passes.*
7. **Final review.** Run `dart analyze`; confirm README/CHANGELOG/LICENSE are
   accurate; update `CHANGELOG.md` with a one-line summary of the cleanup pass.

---

## Guidelines References

| Guideline | Location |
| --------- | -------- |
| Clean Code | [`dart/clean_code_principles.md`](/_copilot_guidelines/dart/clean_code_principles.md) |
| Coding Guidelines | [`dart/coding_guidelines.md`](/_copilot_guidelines/dart/coding_guidelines.md) |
| Documentation | [`documentation_guidelines.md`](/_copilot_guidelines/documentation_guidelines.md) |
| D4rt Bridges | [`d4rt/d4rt_bridgedclass_guidelines.md`](/_copilot_guidelines/d4rt/d4rt_bridgedclass_guidelines.md) |
