# Tom Core Samples — one app, taught across the whole layer

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These sample projects are BSD-3-Clause licensed and internal (`publish_to: none`).

`tom_core_samples` is the **code companion to the Tom Core articles**. Instead of
a scattering of unrelated snippets, every sample here contributes to **one
running application — a todo-management system** — so the same domain model
flows from the server, through the client, into the showcases. Read an article,
open the matching sample, run it, change it.

This document is the **map**; each sample ships its own article-grade `readme.md`
with the depth. Nothing about a package's API is re-documented here — the samples
*use* the Tom Core packages and link back to their READMEs
([repository map](../README.md)).

> **New here?** Start with the shared domain — `todo_domain` — to meet the
> entities every sample reuses, then follow the [learning path](#learning-path)
> from the server up through the responsive UI. The samples are designed to be
> read in that order; each one assumes the one before it.

> **Looking for the secured, full-stack version?** The `advanced_*` packages in
> this folder form a separate suite — **two servers, two databases, two Flutter
> clients** with live four-state field authorization and cross-user sharing. It
> is the secured successor to `core_server_sample` / `core_client_sample`. See
> its own map: [**Advanced Tom Core Full-Stack Sample**](README_advanced_sample.md).

> **Status: built.** All seven subprojects below are present and analyze-clean
> with green test suites — the shared `todo_domain` package and the six samples.
> Each links back here and to the package READMEs it exercises. The two live
> demo apps in the repository root —
> [`tom_flutter_form_test`](../tom_flutter_form_test/README.md) and
> [`tom_flutter_ui_test`](../tom_flutter_ui_test/README.md) — remain the broadest
> runnable reference for the UI layer.

---

## What you can build by working through the samples

- **A real backend** — a todo-management API on `tom_core_server`: endpoints,
  a type-safe persistence layer against MySQL-in-Docker, configuration,
  caching, healthcheck, and four-state authorization.
- **A real Flutter client** — a login-gated todo app on `tom_core_flutter` +
  `tom_flutter_ui`, with CRUD forms whose fields render hidden / read-only /
  disabled / editable straight from the server's authorization decisions.
- **A working mental model of `tom_flutter_ui`** — the widget set, the forms
  framework, and the Advanced Container Layout engine, each shown beside the
  exact instantiation code that produced the rendered result.
- **Responsive layouts done the Tom way** — breakpoints, family-swap, and
  adaptive composition on the ACL engine across phone / tablet / desktop.

---

## The one application

Every sample shares a single domain — the reflected entities in `todo_domain`
(`User`, `Project`, `TodoList`, `TodoItem`, plus label/priority enums). The
server persists them, the client edits them, and the showcases render them. That
single source of truth is what lets the articles build on one another instead of
restarting from scratch each time.

```
                         todo_domain
              (shared reflected entities: the model)
                       /              \
          core_server_sample     core_client_sample
            (persist + serve)      (login + CRUD UI)
                                          |
        ┌─────────────────────────────────┴───────────────────────────┐
   core_flutter_ui_showcase   core_flutter_form_showcase
   core_flutter_acl_sample    core_flutter_acl_responsive
        (the tom_flutter_ui library, taught surface by surface)
```

---

## The samples

Each row is a self-contained subproject with its own article-grade `readme.md`,
linked from its name.

### Shared domain

| Project | What it is | Exercises |
| --- | --- | --- |
| [`todo_domain`](todo_domain/readme.md) | The shared, reflected todo-management model (`User`, `Project`, `TodoList`, `TodoItem`, label/priority enums). Single source of truth depended on by both the server and the client samples. | [`tom_core_kernel`](../tom_core_kernel/README.md) reflection |

### Client & server

| Project | What it is | Exercises |
| --- | --- | --- |
| [`core_server_sample`](core_server_sample/README.md) | The backend: hosts the todo-management API and the security infrastructure, runs MySQL in Docker (compose + bootstrap), persists `todo_domain` entities, and enforces four-state authorization. | [`tom_core_server`](../tom_core_server/README.md) |
| [`core_client_sample`](core_client_sample/README.md) | The Flutter client: login/auth, todo lists, CRUD forms, and four-state field authorization. Runs against a seeded in-memory backend by default, with an honest live read path to `core_server_sample`. | [`tom_core_flutter`](../tom_core_flutter/README.md) · [`tom_flutter_ui`](../tom_flutter_ui/README.md) |

### `tom_flutter_ui` showcases

| Project | What it is | Exercises |
| --- | --- | --- |
| [`core_flutter_ui_showcase`](core_flutter_ui_showcase/README.md) | A component gallery: every `tom_flutter_ui` widget/component grouped by similarity, each cell pairing the **instantiation code** with the rendered widget. | [`tom_flutter_ui`](../tom_flutter_ui/README.md) widgets |
| [`core_flutter_form_showcase`](core_flutter_form_showcase/README.md) | The forms framework in depth — field types, validation, layout, theming, master-detail, and list forms. | [`tom_flutter_ui`](../tom_flutter_ui/README.md) forms |
| [`core_flutter_acl_sample`](core_flutter_acl_sample/README.md) | The Advanced Container Layout engine — sizing (M/P/X), growth, alignment, nesting, borders/titles, variants/breakpoints, and the four authorization states. | [`tom_flutter_ui`](../tom_flutter_ui/README.md) ACL |
| [`core_flutter_acl_responsive`](core_flutter_acl_responsive/README.md) | Responsive UIs on the ACL engine — breakpoints, family-swap, and adaptive layouts across phone / tablet / desktop widths. | [`tom_flutter_ui`](../tom_flutter_ui/README.md) ACL |

---

## Learning path

Read the samples in this order — each assumes the model and infrastructure the
previous ones introduced.

| Order | Sample | Introduces |
| --- | --- | --- |
| 0 | [`todo_domain`](todo_domain/readme.md) | The shared reflected entities every other sample reuses. |
| 1 | [`core_server_sample`](core_server_sample/README.md) | The server stack against MySQL-in-Docker — endpoints, persistence, auth, healthcheck. |
| 2 | [`core_client_sample`](core_client_sample/README.md) | A Flutter todo app with four-state field authorization — in-memory backend by default, live read path to the server. |
| 3 | [`core_flutter_ui_showcase`](core_flutter_ui_showcase/README.md) | Every `tom_flutter_ui` widget group, each shown with its instantiation code. |
| 4 | [`core_flutter_form_showcase`](core_flutter_form_showcase/README.md) | The forms framework in depth. |
| 5 | [`core_flutter_acl_sample`](core_flutter_acl_sample/README.md) | The Advanced Container Layout engine and the four authorization states. |
| 6 | [`core_flutter_acl_responsive`](core_flutter_acl_responsive/README.md) | Responsive UIs on the ACL engine. |

---

## Running the samples

Each sample documents its own run command in its `readme.md`. The common shape:

```bash
# Headless / server samples
cd tom_core_samples/<sample>
dart run                       # or: dart run example/run_all_examples.dart

# Flutter samples (UI showcases, client)
cd tom_core_samples/<sample>
./reflection_generation.sh     # regenerate reflection if the model changed
flutter run                    # pick a device when prompted
```

`core_server_sample` additionally brings up MySQL in Docker (compose file +
bootstrap) — see its `readme.md` for the one-command bring-up.

---

## Documentation index

| Topic | Document |
| --- | --- |
| Tom Core repository map | [`../README.md`](../README.md) |
| Kernel (foundation) | [`../tom_core_kernel/README.md`](../tom_core_kernel/README.md) |
| Server stack | [`../tom_core_server/README.md`](../tom_core_server/README.md) |
| Flutter integration | [`../tom_core_flutter/README.md`](../tom_core_flutter/README.md) |
| Widget library | [`../tom_flutter_ui/README.md`](../tom_flutter_ui/README.md) |
| Live form demo app | [`../tom_flutter_form_test/doc/demo_catalogue.md`](../tom_flutter_form_test/doc/demo_catalogue.md) |
| Live UI demo app | [`../tom_flutter_ui_test/doc/demo_catalogue.md`](../tom_flutter_ui_test/doc/demo_catalogue.md) |

---

## Repository layout

```
tom_core_samples/
  README.md                      this map
  todo_domain/                   shared reflected model (User, Project, TodoList, TodoItem)   (built)
  core_server_sample/            backend: API + persistence + auth + MySQL-in-Docker          (built)
  core_client_sample/            Flutter client: login + todo CRUD + ACL field states         (built)
  core_flutter_ui_showcase/      widget gallery: component + instantiation code               (built)
  core_flutter_form_showcase/    forms framework in depth                                     (built)
  core_flutter_acl_sample/       Advanced Container Layout engine + four auth states          (built)
  core_flutter_acl_responsive/   responsive layouts on the ACL engine                         (built)
```

## License

BSD 3-Clause licensed. Each sample carries the same
[`LICENSE`](../tom_core_kernel/LICENSE) as the rest of Tom Core; see any package
folder for the full text.
