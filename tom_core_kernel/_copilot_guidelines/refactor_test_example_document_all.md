# Tom Core Kernel Refactoring Workflow

Project-specific workflow for refactoring, testing, documenting, and creating examples for tom_core_kernel modules.

---

## Target Modules

Located in `lib/src/tombase/`:

- `/tombase/beanlocator`
- `/tombase/context`
- `/tombase/crypto`
- `/tombase/http_connection`
- `/tombase/isolate_pooling`
- `/tombase/json`
- `/tombase/little_things`
- `/tombase/logging`
- `/tombase/observable`
- `/tombase/reflection`
- `/tombase/resources`
- `/tombase/runtime`
- `/tombase/security`
- `/tombase/settings`
- `/tombase/shutdown_cleanup`
- `/tombase/timezoned`

---

## Workflow Prompts

### Prompt 1: Full Module Refactoring

1. Go through all subfolders of the tombase folder (exception: observable, timezoned, reflection) and refactor and document the files according to the guidelines in `coding_guidelines.md`. Don't change the functionality or remove/add additional public methods, members, or accessors. You can introduce new private members, methods, and accessors.

2. Create comprehensive examples according to the guidelines in `examples.md` (global). The number of examples should vary depending on the number of methods, classes, etc. to ensure examples cover every important aspect of the functionality.

3. Create comprehensive tests according to the guidelines in `tests.md` (global). The number of tests should vary depending on the number of methods, classes, etc. to ensure tests cover every important aspect of the functionality.

4. Make sure all the examples and tests run. Add files to `build.yaml` for generation using the reflection generator as needed. Import and initialize reflection. Fix any bugs found.

5. Create a package documentation file according to the guidelines in `documentation_guidelines.md`. The length should vary depending on complexity. Name the file after the folder (e.g., `http_connection.md` for `/http_connection/`).

6. Create the API file `api.dart` according to the API file creation rules in the api subfolder. Delete any existing `api.dart` if necessary.

7. Read the complete newly generated `api.dart` file and verify that the API listed matches the code.

8. Verify that documentation covers all public classes, methods, and members. Verify documentation doesn't show features that don't exist in the code. Extract code samples from documentation into an additional example file and ensure examples run. Update documentation if changes are required.

---

### Prompt 2: Example and Documentation Revision

**Group 1: Guidelines Update**

Revise `examples.md` to emphasize that examples must be **executable code**, not code printed to the console.

**Group 2: Example Revision**

Revise all examples using the guidelines in `examples.md`. Replace printed code with actually executed code. Example quality and usefulness for future framework users is priority.

**Reference Projects**: Always use the code in `tom_uam_client`, `tom_uam_server`, `tom_uam_shared` and derived modules in `tom_client/tom_server` source folders to understand intended usage.

**Tasks** (in order):
1. Update documentation according to `documentation_guidelines.md`
2. Update examples according to `examples.md`
3. Update tests according to `tests.md`
4. Verify that examples and tests actually run
5. Verify documentation covers all parts of the code
6. Verify tests cover all parts of the code
7. Verify examples cover all parts of the code and typical usage scenarios

---

## Guidelines References

| Guideline | Location | Scope |
|-----------|----------|-------|
| Coding Guidelines | `lib/src/tombase/coding_guidelines.md` | tom_core_kernel |
| Documentation Guidelines | `lib/src/tombase/documentation_guidelines.md` | tom_core_kernel |
| Test Guidelines | `/_copilot_guidelines/tests.md` (global) | All projects |
| Example Guidelines | `/_copilot_guidelines/examples.md` (global) | All projects |
