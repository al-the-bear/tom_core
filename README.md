# Tom Core — the foundation layer of the Tom Framework

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Tom Core is the set of packages every Tom application is built on: a
platform-neutral kernel (dependency injection, observable state, security,
resources, logging) and the runtimes layered on top of it — a server stack, two
Flutter layers, a DartScript bridge tool, a VS Code bridge server, and a set of
agentic building blocks.

This repository ([`al-the-bear/tom_core`](https://github.com/al-the-bear/tom_core))
holds the whole layer. This document is the **map**; each package has its own
`README.md` and `doc/` folder for the detail. Nothing about a package's API is
re-documented here — one phrase of "what it is" plus the link is the contract.

> **New here?** The richest on-ramp is the
> [`tom_core_samples/`](tom_core_samples/README.md) learning path (see
> [Sample learning path](#sample-learning-path)) — a shared todo app built up
> from a server, a Flutter client and four UI showcases. For the foundation,
> read [`tom_core_kernel`](tom_core_kernel/README.md); for the broadest live UI
> reference, run [`tom_flutter_form_test`](tom_flutter_form_test/README.md)
> (the form stack) or [`tom_flutter_ui_test`](tom_flutter_ui_test/README.md)
> (the full widget set).

---

## What you can do with Tom Core

- **Build a backend service** — HTTP host, an endpoint pipeline, a type-safe
  relational persistence layer with datasources and migrations, configuration,
  caching, and authentication/authorization — from one dependency
  ([`tom_core_server`](tom_core_server/README.md)).
- **Build a Flutter app** from authorization-aware, observable, resource-bound
  widgets — a Material/Cupertino widget set, a declarative form system, and a
  fluent layout engine ([`tom_flutter_ui`](tom_flutter_ui/README.md)).
- **Share one model of state, security, and resources** across server and
  client — the platform-neutral [`tom_core_kernel`](tom_core_kernel/README.md)
  is the single source of those cross-cutting concerns.
- **Script the framework** — expose the kernel, server, build, and document
  toolkits to sandboxed DartScript through
  [`tom_core_d4rt`](tom_core_d4rt/README.md).
- **Assemble agent runtimes** from generic, domain-free, `dart:io`-free
  building blocks ([`tom_core_agentic`](tom_core_agentic/README.md)).

---

## How the layer fits together

Everything roots at the **kernel**. The two runtimes (**server** and **Flutter**)
re-export it, so an app depends on one of them and gets the kernel API for free.
The **UI library** is the rich widget set that the Flutter runtime's thin
integration layer complements. The **scripting** and **bridge** tools wrap the
runtimes for DartScript and the VS Code extension. The **agentic** blocks sit
beside the kernel, depending only on `tom_basics`.

```
                    tom_core_kernel            (platform-neutral foundation)
                   /       |        \
       tom_core_server  tom_core_flutter  tom_flutter_ui
         (backend)      (Flutter glue)    (widget library)
              |
       tom_core_d4rt  ── tom_core_bridge        (DartScript / VS Code bridge)

       tom_core_agentic  (agent building blocks; depends only on tom_basics)
```

---

## The packages

Every package below has a `README.md` (linked) and a `doc/` folder. Base path
for all entries is this repository root.

### Foundation

| Package | What it is |
| --- | --- |
| [`tom_core_kernel`](tom_core_kernel/README.md) | The platform-neutral foundation: dependency injection (bean locator), observable state, security and four-state authorization, resource resolution, logging, JSON, and runtime utilities. Reflection-aware; no UI or server-runtime dependency, so any Dart target can consume it. |

### Runtimes

| Package | What it is |
| --- | --- |
| [`tom_core_server`](tom_core_server/README.md) | The server layer: an HTTP host, an endpoint pipeline, a relational persistence layer with a type-safe query model, datasources and migrations, server configuration, caching, and authentication/authorization. Re-exports the kernel through its own barrel. |
| [`tom_core_flutter`](tom_core_flutter/README.md) | The Flutter integration layer: re-exports the kernel and adds Flutter widgets that bind to observable kernel state, form primitives, typed UI properties, client-side platform detection, and client auth helpers. |

### UI

| Package | What it is |
| --- | --- |
| [`tom_flutter_ui`](tom_flutter_ui/README.md) | The Flutter widget library: a Material/Cupertino-aware widget set, a declarative form system, a behavioural action system, and a fluent row-based layout engine (Advanced Container Layout). Every widget understands the kernel's `tomId`/`tomGroup` visibility, the four-state `TomAuthState` model, and resource-driven styling. |

### Scripting & bridges

| Package | What it is | Binary |
| --- | --- | --- |
| [`tom_core_d4rt`](tom_core_d4rt/README.md) | The D4rt scripting tool with the full Tom Framework bridge set — an interactive REPL and headless script runner that exposes the kernel, server, build, distributed, and document toolkits to sandboxed DartScript. | `d4rt` |
| [`tom_core_bridge`](tom_core_bridge/README.md) | The VS Code bridge server extended with the complete Tom D4rt bridge set — `tom_bs` (DCli + VS Code API bridges) plus everything `tom_core_d4rt` registers. | `core_bs` |

### Agentic

| Package | What it is |
| --- | --- |
| [`tom_core_agentic`](tom_core_agentic/README.md) | Generic, domain-free, `dart:io`-free building blocks for agentic systems — placeholder resolution, path-scoped sandboxing, content-hash conventions, config read/write. Depends only on `tom_basics`; reusable across the brain, the assistant, and any agent runtime. |

### Demo & test apps

These are runnable harnesses (`publish_to: none`), not libraries — they exercise
the layer end-to-end against the live Flutter engine.

| App | What it is |
| --- | --- |
| [`tom_flutter_form_test`](tom_flutter_form_test/README.md) | A two-tab Flutter showcase of the **form framework** (`tom_flutter_ui` forms/fields over the kernel's resources, security, and reflection). See its [demo catalogue](tom_flutter_form_test/doc/demo_catalogue.md). |
| [`tom_flutter_ui_test`](tom_flutter_ui_test/README.md) | A four-tab Flutter demo / smoke-test of the **whole `tom_flutter_ui` library** — the ACL layout engine, the widget set, the form framework, and the resource/authorization machinery. See its [demo catalogue](tom_flutter_ui_test/doc/demo_catalogue.md). |

---

## Sample learning path

The [`tom_core_samples/`](tom_core_samples/README.md) folder builds one
todo-management application across a shared domain plus six subprojects, ordered
as a learning path from a backend up through responsive UI. Start with the
[samples map](tom_core_samples/README.md); the two demo apps above remain the
broadest live UI reference.

| Order | Sample | Introduces |
| --- | --- | --- |
| 0 | [`todo_domain`](tom_core_samples/todo_domain/readme.md) | The shared reflected entities (`User`, `Project`, `TodoList`, `TodoItem`) every other sample reuses. |
| 1 | [`core_server_sample`](tom_core_samples/core_server_sample/README.md) | The server stack against MySQL-in-Docker — endpoints, persistence, auth, healthcheck. |
| 2 | [`core_client_sample`](tom_core_samples/core_client_sample/README.md) | A Flutter todo app on `tom_core_flutter` + `tom_flutter_ui` with four-state field authorization — in-memory backend, live read path to the server. |
| 3 | [`core_flutter_ui_showcase`](tom_core_samples/core_flutter_ui_showcase/README.md) | Every `tom_flutter_ui` widget group, each shown with its instantiation code. |
| 4 | [`core_flutter_form_showcase`](tom_core_samples/core_flutter_form_showcase/README.md) | The forms framework in depth — field types, validation, layout, theming, master-detail, lists. |
| 5 | [`core_flutter_acl_sample`](tom_core_samples/core_flutter_acl_sample/README.md) | The Advanced Container Layout engine — sizing, growth, alignment, nesting, borders, variants, and the four authorization states. |
| 6 | [`core_flutter_acl_responsive`](tom_core_samples/core_flutter_acl_responsive/README.md) | Responsive UIs on the ACL engine — breakpoints, family-swap, adaptive layouts across phone/tablet/desktop. |

---

## Documentation index

Each package keeps its user documentation in its own `doc/` folder; the READMEs
above link the relevant files. The most common entry points:

| Topic | Document |
| --- | --- |
| Kernel module reference | [`tom_core_kernel/doc/`](tom_core_kernel/doc/) (per-module folders) |
| Server modules (persistence, endpoints, auth, …) | [`tom_core_server/doc/`](tom_core_server/doc/) |
| Flutter integration modules | [`tom_core_flutter/doc/`](tom_core_flutter/doc/) |
| Widget library — ACL engine | [`tom_flutter_ui/doc/advanced_container_layout.md`](tom_flutter_ui/doc/advanced_container_layout.md) |
| Widget library — forms & authorizers | [`tom_flutter_ui/doc/forms.md`](tom_flutter_ui/doc/forms.md) · [`form_authorizers.md`](tom_flutter_ui/doc/form_authorizers.md) |
| DartScript bridge groups | [`tom_core_d4rt/doc/`](tom_core_d4rt/doc/) (one `.md` per bridged package) |
| VS Code bridge operations | [`tom_core_bridge/doc/operations.md`](tom_core_bridge/doc/operations.md) |
| Agentic building blocks | [`tom_core_agentic/doc/`](tom_core_agentic/doc/) |
| Form demo catalogue | [`tom_flutter_form_test/doc/demo_catalogue.md`](tom_flutter_form_test/doc/demo_catalogue.md) |
| UI demo catalogue | [`tom_flutter_ui_test/doc/demo_catalogue.md`](tom_flutter_ui_test/doc/demo_catalogue.md) |

---

## Repository layout

```
tom_core_kernel/       platform-neutral foundation (DI, state, security, …)   (foundation)
tom_core_server/       backend runtime: HTTP, persistence, auth               (runtime)
tom_core_flutter/      Flutter integration layer (re-exports the kernel)      (runtime)
tom_flutter_ui/        Flutter widget library: widgets, forms, ACL engine     (UI)
tom_core_d4rt/         DartScript REPL + runner with full Tom bridges (d4rt)   (scripting)
tom_core_bridge/       VS Code bridge server with the Tom bridge set (core_bs) (bridge)
tom_core_agentic/      domain-free agentic building blocks (dart:io-free)      (agentic)
tom_flutter_form_test/ runnable demo: the form framework                      (demo app)
tom_flutter_ui_test/   runnable demo/smoke-test: the whole widget library     (demo app)
tool/                  repo-wide developer tooling (see below)                (tooling)
```

Dependency direction, simplified: everything roots at `tom_core_kernel`;
`tom_core_server` and `tom_core_flutter` build on and re-export it;
`tom_flutter_ui` builds on the kernel and is exercised by the two demo apps;
`tom_core_d4rt` bridges the runtimes into DartScript and `tom_core_bridge`
serves those bridges to the VS Code extension; `tom_core_agentic` depends only
on `tom_basics`.

## Repository tooling

Tools that span the whole repository live in `tool/`; anything scoped to one
package lives in that package's own `tool/`.

| Tool | What it does |
| ---- | ------------ |
| [`tool/check_doc_tocs.py`](tool/check_doc_tocs.py) | Audits every `## Table of Contents` in the tree against its own document |
| [`tool/check_doc_inventories.py`](tool/check_doc_inventories.py) | Audits the file inventories in the completion documents against the tree |
| [`tool/check_dartdoc_refs.py`](tool/check_dartdoc_refs.py) | Finds dartdoc references to private names that no longer exist |

```bash
python3 tool/check_doc_tocs.py                # the whole repository
python3 tool/check_doc_tocs.py tom_core_kernel   # one subtree
```

It reports three faults and exits non-zero if it finds any: sections the
contents omit, entries whose link resolves to no heading, and entries listed in
an order the document does not follow. The last is the one a reader cannot
easily catch, and a presence check passes it silently.

Documents drift from their contents whenever a section is added without the
list being touched, so the check is worth running after editing any document
that has one.

```bash
python3 tool/check_doc_inventories.py         # every completion document
python3 tool/check_doc_inventories.py --fix   # re-measure and write back
```

The completion documents in the `_ai` layer open by naming a module's directory
and how much is in it, then tabulate it a file at a time. Those numbers are
measurements taken by hand, so every commit to a module can falsify them, and
nothing about editing a module brings its completion document into view. The
check re-measures: it reports line counts that have moved, tabulated files that
no longer exist, files on disk the table omits, and opening claims that
disagree with the directory. `--fix` writes the measurements back; the two
faults it leaves alone are adding and retiring rows, because each needs a
sentence saying what the file carries.

```bash
python3 tool/check_dartdoc_refs.py                 # the whole repository
python3 tool/check_dartdoc_refs.py tom_core_server # one subtree
```

A `[name]` in a `///` comment renders as a link when it resolves and as plain
text when it does not, so renaming a member turns every reference to it into
prose without anything failing. The obvious detector, the `comment_references`
lint, is the wrong tool here: it flags 150-odd *correct* references to real
classes in sibling files, and satisfying it would mean adding imports that exist
only for prose, several of them cycles. This check takes the part of the problem
that has no such ambiguity — a private name can only ever resolve inside its own
library, so whether it exists is answerable from that library alone. That is
also exactly the shape a rename leaves behind.

## License

BSD 3-Clause licensed. Each package carries the same
[`LICENSE`](tom_core_kernel/LICENSE); see any package folder for the full text.
