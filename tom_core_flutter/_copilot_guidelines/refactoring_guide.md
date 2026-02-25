# Tom Core Flutter Refactoring Guide

Project-specific refactoring workflow for tom_core_flutter modules.

**Base workflow:** Follow [project_refactoring_guidelines.md](/_copilot_guidelines/project_refactoring_guidelines.md)

---

## Project Overview

Tom Core Flutter provides Flutter-specific components and utilities for building Flutter applications using the Tom framework.

**Project type:** flutter_app
**Source location:** `lib/src/tomclient/`

---

## Target Modules

| Module | Description |
| ------ | ----------- |
| `camera/` | Camera integration and image capture |
| `forms/` | Form handling and validation |
| `iding/` | Identity and identification utilities |
| `little_things/` | Small utility widgets and helpers |
| `localstorage/` | Local storage abstraction |
| `observing/` | Observable state patterns for Flutter |
| `preferences/` | User preferences management |
| `qrcode/` | QR code generation and scanning |
| `resources/` | Resource loading and management |
| `runtime/` | Flutter runtime utilities |
| `security/` | Security utilities for mobile/web |

---

## Reference Projects

Always consult these projects to understand intended usage patterns:

| Project | Purpose |
| ------- | ------- |
| `tom_uam_client` | Primary Flutter client using tom_core_flutter |
| `tom_uam_shared` | Shared code patterns between client and server |
| `tom_uam_server` | Server-side patterns (for understanding client-server interaction) |

---

## Project-Specific Notes

### Flutter Widget Testing

When creating tests for Flutter modules:

- Use `flutter_test` package
- Use `WidgetTester` for widget tests
- Mock platform channels where needed
- Test both Android and iOS behaviors where applicable

### Example Structure

Examples should demonstrate:

- Widget integration patterns
- State management with observable patterns
- Platform-specific considerations

---

## Refactoring Task Template

When starting a refactoring session, create and execute this TODO list:

```text
TODO 1: Read all files in {module_name} module
TODO 2: Identify public API surface (classes, methods, members)
TODO 3: Review usage in tom_uam_client for real-world patterns
TODO 4: Refactor code following coding_guidelines.md
TODO 5: Quality check - verify no public API changes, run dart analyze
TODO 6: Create module documentation in doc/{module_name}.md
TODO 7: Quality check - verify all public API documented
TODO 8: Create examples following examples.md
TODO 9: Quality check - verify examples are executable and run
TODO 10: Create tests following tests.md
TODO 11: Quality check - run flutter test, verify all pass
TODO 12: Create API summary in doc/api/api_summary_{module_name}.md
TODO 13: Quality check - verify API summary matches code
TODO 14: Final quality review - all phases complete
TODO 15: If issues found, return to appropriate phase and repeat
```

---

## Quick Start Prompt

Copy this prompt to start a refactoring session:

```text
I want to refactor the {module_name} module in tom_core_flutter.

Read the local copilot guidelines in tom_core_flutter/_copilot_guidelines/refactoring_guide.md.

Follow the global project_refactoring_guidelines.md for the workflow.

Create the TODO list from the Refactoring Task Template section and execute each item.

Reference tom_uam_client for real-world usage patterns.
Do not change public API surface.
Repeat quality checks until all issues are resolved.
```
