# Tom Core Samples — one app, taught across the whole layer

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These sample projects are BSD-3-Clause licensed and internal (`publish_to: none`).

`tom_core_samples` is the **code companion to the Tom Core articles**. Instead of
a scattering of unrelated snippets, every sample here contributes to **one
running application — a todo-management system** — so the same domain model
flows from the server, through the client, into the showcases. Read an article,
open the matching sample, run it, change it.

This document is the **map**; each sample ships its own article-grade `README.md`
with the depth. Nothing about a package's API is re-documented here — the samples
*use* the Tom Core packages and link back to their READMEs
([repository map](../README.md)).

**No sample package carries a `doc/` folder, and none carries a `doc/api/`
summary. That is a decision, not an omission**, and it is the same for all
fifteen. The framework packages carry API mirrors because they have consumers
who need the surface without reading the source; a sample has none. Every one
here is `publish_to: none`, nothing outside this folder imports one, and the
three libraries among them (`advanced_todo_domain`,
`advanced_todo_contracts`, `advanced_client_core`) are consumed only by their
siblings in this same tree.

What a reader of a sample wants is how the pieces fit, which is narrative — the
article-grade README beside each package, and the twenty-two guide documents in
this folder — rather than a symbol index. And a mirror here would be one nothing
holds true: the framework's summaries are derived and gated by their packages'
own suites, while a hand-copied index of a sample's internals would drift from
the first refactor with nothing to notice.

Where a sample exports a library surface worth indexing, its own README does it
instead, under a test that holds the index to the source: `todo_domain`,
`core_server_sample`, `advanced_client_core`, `advanced_ops_server` and
`advanced_todo_domain` carry a signature-level `## API` section checked in both
directions,
`advanced_app_server` and `advanced_auth_server` a library-level `## API` table,
and `advanced_todo_contracts` an endpoint table generated from its registry.

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

Each row is a self-contained subproject with its own article-grade `README.md`,
linked from its name.

### Shared domain

| Project | What it is | Exercises |
| --- | --- | --- |
| [`todo_domain`](todo_domain/README.md) | The shared, reflected todo-management model (`User`, `Project`, `TodoList`, `TodoItem`, label/priority enums). Single source of truth depended on by both the server and the client samples. | [`tom_core_kernel`](../tom_core_kernel/README.md) reflection |

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

## Examples

Which samples ship an `example/` folder, and why the others do not. A sample is
itself an example, so the rule is about *what a reader runs*: a package whose
entry point is an application needs no second one, while a library or a
server whose most useful seam needs no infrastructure gets a runnable file.

| Project | `example/` | Why, or what to run instead |
| --- | --- | --- |
| `todo_domain` | yes — three examples and `run_all_examples.dart` | a library; see [`example/README.md`](todo_domain/example/README.md) |
| `core_server_sample` | yes — `run_all_examples.dart` | a database-free walkthrough of the server core — the domain ↔ record mapping and the four-state field authorization — that asserts its own results |
| `core_client_sample` | **no — exempt** | a Flutter GUI app: `lib/main.dart` is the entry point and the serial widget suite is its smoke test; argued in its README, [§13 Tests](core_client_sample/README.md#13-tests) |
| `core_flutter_ui_showcase`, `core_flutter_form_showcase` | **no — exempt** | Flutter showcase apps: each screen is an example, run with `flutter run` |
| `core_flutter_acl_sample`, `core_flutter_acl_responsive` | **no — exempt** | Flutter showcase apps, as above |
| the eight `advanced_*` packages | the three libraries and `advanced_ops_server` — yes; the other four runtimes — **no, exempt** | stated per package in [the advanced family's index](README_advanced_sample.md#the-eight-packages) |

An exempt row is a decision, not a gap: a sweep that finds no `example/` in one
of those packages has found what this table says.

## Learning path

Read the samples in this order — each assumes the model and infrastructure the
previous ones introduced.

| Order | Sample | Introduces |
| --- | --- | --- |
| 0 | [`todo_domain`](todo_domain/README.md) | The shared reflected entities every other sample reuses. |
| 1 | [`core_server_sample`](core_server_sample/README.md) | The server stack against MySQL-in-Docker — endpoints, persistence, auth, healthcheck. |
| 2 | [`core_client_sample`](core_client_sample/README.md) | A Flutter todo app with four-state field authorization — in-memory backend by default, live read path to the server. |
| 3 | [`core_flutter_ui_showcase`](core_flutter_ui_showcase/README.md) | Every `tom_flutter_ui` widget group, each shown with its instantiation code. |
| 4 | [`core_flutter_form_showcase`](core_flutter_form_showcase/README.md) | The forms framework in depth. |
| 5 | [`core_flutter_acl_sample`](core_flutter_acl_sample/README.md) | The Advanced Container Layout engine and the four authorization states. |
| 6 | [`core_flutter_acl_responsive`](core_flutter_acl_responsive/README.md) | Responsive UIs on the ACL engine. |

---

## Running the samples

Each sample documents its own run command in its `README.md`. The common shape:

```bash
# Headless / server samples
cd tom_core_samples/<sample>
dart run                       # or: dart run example/run_all_examples.dart

# Flutter samples (UI showcases, client)
cd tom_core_samples/<sample>
./reflection_generation.sh     # regenerate reflection if the model changed
flutter create --empty --platforms=macos .   # once per machine; or linux, windows, web
flutter run                    # pick a device when prompted
```

No Flutter sample ships platform folders, so each needs one generated before its
first run. `--empty` keeps `flutter create` from writing a counter-app test the
package cannot compile, and every sample's `.gitignore` covers what it writes.
Each sample's README names the platforms it supports — the two that talk to a
server over `dart:io` cannot target web — and
`tool/check_flutter_platform_step.py` holds every README to naming the step.

`core_server_sample` additionally brings up MySQL in Docker (compose file +
bootstrap) — see its `README.md` for the one-command bring-up.

---

## Reflection seeds

Thirteen of the fifteen packages carry a generated `*.reflection.dart` — the
reflection seed an entrypoint or a barrel installs with `initializeReflection()`.
The rule for them is the same in every package, decided once here:

**Seeds are tracked, and kept equal to what the generator emits today.** They
are not gitignored, because a fresh checkout must analyze, test and run without
anyone running the generator first: `todo_domain` re-exports its seed through
its public barrel, and every server entrypoint imports its own. And they are not
pinned to a generator version, because a pinned seed is one that no run of
`./reflection_generation.sh` reproduces — a consumer who regenerates then sees a
diff indistinguishable from a real model change.

What makes the rule hard to keep is that a seed goes stale **without any edit in
its package**. It mirrors every type reachable from its root, including the
framework's, so a change in `tom_core_kernel` or `tom_core_server`, or a new
generator release, moves it. A stale seed still analyzes and still passes the
suites, so nothing fails; the check that sees it is the generator's own:

```bash
cd tom_core_samples/<sample>
./reflection_generation.sh --check   # exits non-zero, naming the file, when stale
```

Run it after a model change, after a framework change the sample reaches, and
before committing a regenerated seed. When it fails: regenerate, run the
package's suite — and its live runner, where it has one — against the result,
and commit the seed together with the change that moved it.

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
  README_advanced_*.md           the advanced sample's guides — start at README_advanced_sample.md
  README_tom_core_guidelines.md  the normative structure rules every sample is held to
  assets/                        the guides' figures (documentation only — see assets/README.md)
  tool/                          suite-level checks
  todo_domain/                   shared reflected model (User, Project, TodoList, TodoItem)
  core_server_sample/            backend: API + persistence + auth + MySQL-in-Docker
  core_client_sample/            Flutter client: login + todo CRUD + ACL field states
  core_flutter_ui_showcase/      widget gallery: component + instantiation code
  core_flutter_form_showcase/    forms framework in depth
  core_flutter_acl_sample/       Advanced Container Layout engine + four auth states
  core_flutter_acl_responsive/   responsive layouts on the ACL engine
  advanced_todo_domain/          the advanced sample's reflected domain and grade vocabulary
  advanced_todo_contracts/       its wire DTOs and endpoint registry
  advanced_client_core/          its Flutter-free authenticated HTTP client
  advanced_auth_server/          JWT issuer and /admin/* API          (:8081, auth_db :3307)
  advanced_app_server/           the secured task API                 (:8080, app_db :3308)
  advanced_ops_server/           scheduled back-office work over app_db
  advanced_app_client/           end-user Flutter app
  advanced_authadmin_client/     administrator Flutter console
```

Four of the packages also have an `assets/` folder of their own — the servers'
runtime configuration, loaded at boot. The suite-level `assets/` is not one of
those; it holds only figures.

## License

BSD 3-Clause licensed. Each sample carries the same
[`LICENSE`](../tom_core_kernel/LICENSE) as the rest of Tom Core; see any package
folder for the full text.
