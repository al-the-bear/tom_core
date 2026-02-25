# Tom Core Server Refactoring Guide

Project-specific refactoring workflow for tom_core_server modules.

**Base workflow:** Follow [project_refactoring_guidelines.md](/_copilot_guidelines/project_refactoring_guidelines.md)

---

## Project Overview

Tom Core Server provides server-side components and utilities for building Dart server applications using the Tom framework.

**Project type:** dart_server
**Source location:** `lib/src/tomserver/`

---

## Target Modules

| Module | Description |
| ------ | ----------- |
| `authentication/` | User authentication and identity |
| `authorization/` | Permission and access control |
| `cache/` | Server-side caching mechanisms |
| `cmdline/` | Command-line argument handling |
| `configuration/` | Server configuration management |
| `datasources/` | Data source abstractions |
| `db_migration/` | Database migration utilities |
| `endpoints/` | HTTP endpoint handling |
| `externalapis/` | External API integrations |
| `healthcheck/` | Health check endpoints |
| `little_things/` | Small utility functions |
| `object_persistence/` | Object-relational mapping |
| `runtime/` | Server runtime utilities |
| `server/` | Core server framework |
| `transactions/` | Transaction handling |

---

## Reference Projects

Always consult these projects to understand intended usage patterns:

| Project | Purpose |
| ------- | ------- |
| `tom_uam_server` | Primary server application using tom_core_server |
| `tom_uam_shared` | Shared code patterns between client and server |
| `tom_uam_client` | Client-side patterns (for understanding client-server interaction) |

---

## Project-Specific Notes

### Server Testing

When creating tests for server modules:

- Use `test` package for unit tests
- Mock external services (databases, APIs)
- Test both success and error paths
- Consider concurrency scenarios

### Example Structure

Examples should demonstrate:

- Server initialization patterns
- Endpoint configuration
- Database connection handling
- Authentication/authorization flows

---

## Refactoring Task Template

When starting a refactoring session, create and execute this TODO list:

```text
TODO 1: Read all files in {module_name} module
TODO 2: Identify public API surface (classes, methods, members)
TODO 3: Review usage in tom_uam_server for real-world patterns
TODO 4: Refactor code following coding_guidelines.md
TODO 5: Quality check - verify no public API changes, run dart analyze
TODO 6: Create module documentation in doc/{module_name}.md
TODO 7: Quality check - verify all public API documented
TODO 8: Create examples following examples.md
TODO 9: Quality check - verify examples are executable and run
TODO 10: Create tests following tests.md
TODO 11: Quality check - run dart test, verify all pass
TODO 12: Create API summary in doc/api/api_summary_{module_name}.md
TODO 13: Quality check - verify API summary matches code
TODO 14: Final quality review - all phases complete
TODO 15: If issues found, return to appropriate phase and repeat
```

---

## Quick Start Prompt

Copy this prompt to start a refactoring session:

```text
I want to refactor the {module_name} module in tom_core_server.

Read the local copilot guidelines in tom_core_server/_copilot_guidelines/refactoring_guide.md.

Follow the global project_refactoring_guidelines.md for the workflow.

Create the TODO list from the Refactoring Task Template section and execute each item.

Reference tom_uam_server for real-world usage patterns.
Do not change public API surface.
Repeat quality checks until all issues are resolved.
```
