# Tom Core — the foundation layer of the Tom Framework

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Tom Core is the set of packages every Tom application is built on: a
platform-neutral kernel (dependency injection, observable state, security,
resources, logging) and the runtimes layered on top of it — a server stack, two
Flutter layers, and a set of agentic building blocks.

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
- **Assemble agent runtimes** from generic, domain-free, `dart:io`-free
  building blocks ([`tom_core_agentic`](tom_core_agentic/README.md)).

---

## How the layer fits together

Everything roots at the **kernel**. The two runtimes (**server** and **Flutter**)
re-export it, so an app depends on one of them and gets the kernel API for free.
The **UI library** is the rich widget set that the Flutter runtime's thin
integration layer complements. The **agentic** blocks sit beside the kernel,
depending only on `tom_basics`.

```
                    tom_core_kernel            (platform-neutral foundation)
                   /       |        \
       tom_core_server  tom_core_flutter  tom_flutter_ui
         (backend)      (Flutter glue)    (widget library)

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
| 0 | [`todo_domain`](tom_core_samples/todo_domain/README.md) | The shared reflected entities (`User`, `Project`, `TodoList`, `TodoItem`) every other sample reuses. |
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
tom_core_agentic/      domain-free agentic building blocks (dart:io-free)      (agentic)
tom_flutter_form_test/ runnable demo: the form framework                      (demo app)
tom_flutter_ui_test/   runnable demo/smoke-test: the whole widget library     (demo app)
tool/                  repo-wide developer tooling (see below)                (tooling)
```

Dependency direction, simplified: everything roots at `tom_core_kernel`;
`tom_core_server` and `tom_core_flutter` build on and re-export it;
`tom_flutter_ui` builds on the kernel and is exercised by the two demo apps;
`tom_core_agentic` depends only on `tom_basics`.

## Repository tooling

Tools that span the whole repository live in `tool/`; anything scoped to one
package lives in that package's own `tool/`.

Every `check_*.py` below is a **gate**: it counts documentation faults and exits
non-zero when it finds any. They are run together by `tool/check_gates.py`,
which `tom_flutter_ui/test/repo_doc_gates_test.dart` invokes — so a gate that
starts failing surfaces in `flutter test` / `testkit :test` rather than waiting
for somebody to run it by hand.

```bash
python3 tool/check_gates.py            # run them all, report, gate
python3 tool/check_gates.py --update   # re-record the baselines to today
```

Each gate is pinned to a fault count in
[`tool/gate_baselines.json`](tool/gate_baselines.json), not to zero. Demanding
zero on the day the runner landed would have meant repairing several hundred
documentation faults before anything at all was enforced, and until they were,
every *new* fault would land unnoticed among them. So the backlog is frozen
where it is and the next fault is a failure. Clearing a backlog is separate
work, and lowering its baseline is part of that work.

The ratchet turns both ways: a count *below* its baseline fails too, asking for
the baseline to be lowered, because otherwise repaired ground reopens silently.
Gates are discovered by glob, so a checker added tomorrow is enforced tomorrow —
it fails as unbaselined until it is recorded. To be run, a gate must be named
`check_*.py` in `tool/` and end its `main()` with `report_faults(n)` from
[`tool/gate_report.py`](tool/gate_report.py); `report_*.py` names a tool that
reports and never gates.

| Tool | What it does |
| ---- | ------------ |
| [`tool/check_gates.py`](tool/check_gates.py) | Runs every gate below and holds each to its recorded fault count |
| [`tool/gate_report.py`](tool/gate_report.py) | The contract a gate implements: prints the machine-readable fault total and derives the exit status from it |
| [`tool/check_tooling_table.py`](tool/check_tooling_table.py) | Pins this table, and the prose sections below it, to the contents of `tool/` |
| [`tool/check_doc_tocs.py`](tool/check_doc_tocs.py) | Audits a document's own navigation: its `## Table of Contents` and every anchor it links to itself |
| [`tool/check_doc_inventories.py`](tool/check_doc_inventories.py) | Audits the file inventories in the completion documents against the tree |
| [`tool/check_doc_dependencies.py`](tool/check_doc_dependencies.py) | Audits each package document's Dependencies section against the names its `pubspec.yaml` declares |
| [`tool/check_module_dependencies.py`](tool/check_module_dependencies.py) | Audits each *module* document's Dependencies table against the imports its module actually has |
| [`tool/check_dart_format.py`](tool/check_dart_format.py) | Holds every Dart file in the repository to `dart format`, across all 23 packages |
| [`tool/check_doc_error_keys.py`](tool/check_doc_error_keys.py) | Audits the error vocabulary a document states — the completion documents' "Error keys" sections, and the hand-written module guides — against the keys the code raises |
| [`tool/check_dartdoc_refs.py`](tool/check_dartdoc_refs.py) | Finds dartdoc references to private names that no longer exist |
| [`tool/check_dartdoc_build.py`](tool/check_dartdoc_build.py) | Builds each gated package's API documentation and requires `dart doc` to report nothing |
| [`tool/check_consumer_claims.py`](tool/check_consumer_claims.py) | Finds dartdoc that names a consumer which does not consume |
| [`tool/check_doc_attributions.py`](tool/check_doc_attributions.py) | Finds prose that names a source file and then names a type that file has not got |
| [`tool/check_member_attributions.py`](tool/check_member_attributions.py) | Finds documentation that writes `Type.member` for a member the type does not declare |
| [`tool/check_doc_samples.py`](tool/check_doc_samples.py) | Finds Dart samples in the docs that call a constructor the wrong way, quote its signature with the wrong parameter kind, or `const` one that is not |
| [`tool/check_doc_dart_blocks.py`](tool/check_doc_dart_blocks.py) | Runs every ` ```dart ` block in a package's documents through the analyzer: it must parse, every framework name in it must resolve, and a fence marked ` ```dart complete ` must analyze clean outright |
| [`tool/check_section_refs.py`](tool/check_section_refs.py) | Finds `§` references in shipped code and prose that name no resolvable document |
| [`tool/check_section_numbers.py`](tool/check_section_numbers.py) | Finds `§` references that resolve to a document but cite a section it does not have |
| [`tool/check_comments_read_as_is.py`](tool/check_comments_read_as_is.py) | Finds work-item ids and history narration in shipped text |
| [`tool/check_shared_chrome.py`](tool/check_shared_chrome.py) | Finds files copied between packages that do not name their siblings, or whose pointers disagree |
| [`tool/check_test_inventories.py`](tool/check_test_inventories.py) | Audits a document that claims to inventory a package's test files against the files the runner discovers |
| [`tool/check_source_citations.py`](tool/check_source_citations.py) | Finds Dart comments, SVG figures and navigating documentation that cite a line number instead of naming the thing |
| [`tool/check_doc_kinds.py`](tool/check_doc_kinds.py) | Finds `Kind` columns whose cell names something Dart does not declare |
| [`tool/check_unimplemented_claims.py`](tool/check_unimplemented_claims.py) | Finds documentation that calls a shipped `Tom*` type unimplemented |
| [`tool/check_doc_overview_types.py`](tool/check_doc_overview_types.py) | Holds a module document's Overview table to every public type its module's barrel exports |
| [`tool/check_doc_class_inventories.py`](tool/check_doc_class_inventories.py) | Holds a document's marked class inventory to the directory it inventories, in both directions |
| [`tool/check_field_grade_matrix.py`](tool/check_field_grade_matrix.py) | Pins every documented copy of the advanced field-grade matrix — tables and prose remainders — to the map in code |
| [`tool/check_resource_key_namespace.py`](tool/check_resource_key_namespace.py) | Finds resource keys written with the field-grade scope glued to the front of the type |
| [`tool/check_figure_wellformed.py`](tool/check_figure_wellformed.py) | Finds SVG figures that are not well-formed XML, and so render as nothing |
| [`tool/check_barrel_exports.py`](tool/check_barrel_exports.py) | Finds a Dart file beside a barrel that no barrel reaches and no marker declares |
| [`tool/check_kernel_bridge.py`](tool/check_kernel_bridge.py) | Audits the kernel bridge registrations against the types the bridge declares |
| [`tool/check_demo_counts.py`](tool/check_demo_counts.py) | Pins the demo screen/tile counts printed in `tom_flutter_ui_test/README.md` to the source |
| [`tool/check_pubspec_boilerplate.py`](tool/check_pubspec_boilerplate.py) | Finds pubspecs still carrying a `flutter create` / `dart create` placeholder description or its tutorial commentary |
| [`tool/check_doc_source_paths.py`](tool/check_doc_source_paths.py) | Checks that every `**Source:**` pointer in documentation names a path that exists |
| [`tool/check_doc_links.py`](tool/check_doc_links.py) | Finds markdown links that open nothing, and links from a package's documentation into `_copilot_guidelines/` |
| [`tool/check_doc_artifacts.py`](tool/check_doc_artifacts.py) | Finds machine-generated artifacts tracked under a package's `doc/` |
| [`tool/check_doc_ai_citations.py`](tool/check_doc_ai_citations.py) | Finds shipped documents citing a path under `_ai/`, which no reader of the package can open |
| [`tool/check_reflection_artifacts.py`](tool/check_reflection_artifacts.py) | Analyzes the checked-in reflection artifacts, which the analysis options exclude, and fails on a name that no longer resolves |
| [`tool/report_crosslib_refs.py`](tool/report_crosslib_refs.py) | **Reports** (never gates) dartdoc links naming a repo type the writing library cannot see |

```bash
python3 tool/check_tooling_table.py    # the whole repository
```

The table above and the prose below it are an inventory of `tool/`, and both are
kept by hand — adding a script touches neither. So a gate can land, be picked up
by `check_gates.py`'s glob, run on every build, and be documented nowhere; the
reader who came to the README to learn what the repository checks gets a
confident, incomplete answer, and the undocumented gate is the first candidate
for deletion because nothing points at it.

This has already re-opened once, which is why it is a gate rather than a
promise. `check_kernel_bridge.py` and `check_section_numbers.py` each ran
undocumented long enough to be noticed and written up — and by the time they
were, `check_unimplemented_claims.py` had silently taken their place. Clearing
the backlog was never the difficulty. Nobody who reviewed the commit that added
a script made a mistake either: the omission is in a file that commit did not
touch, so there is no diff in which to see it.

Three counts are kept apart: a script with no row, a row naming no script (the
reverse drift, left behind by a rename), and a `check_*.py` with no invocation
block. `gate_report.py` legitimately has no block — it is the contract a gate
implements rather than a gate to run, and its row says so. Accuracy is not
checked, only presence: whether a summary is *true* needs judgement, whether a
row exists does not. That is the same line `check_doc_inventories.py` and
`check_test_inventories.py` draw.

```bash
python3 tool/check_doc_tocs.py                # the whole repository
python3 tool/check_doc_tocs.py tom_core_kernel   # one subtree
```

It reports four faults and exits non-zero if it finds any: sections the
contents omit, entries whose link resolves to no heading, entries listed in an
order the document does not follow, and links *in the body* pointing at an
anchor of their own document that no heading provides. The third is the one a
reader cannot easily catch, and a presence check passes it silently.

The body-link check is why the gate scans every document rather than only the
117 that carry contents. `check_doc_links` accepts any `#fragment` and names
this gate as the one that decides whether the heading exists, so an anchor
nobody indexed was an anchor neither gate looked at: a `[§10](#…)` in running
prose whose heading had since been reworded resolved to nothing, and so did two
appendix cross-references that had picked up a doubled dash. `STALE` is this
same fault confined to the contents block.

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
python3 tool/check_doc_dependencies.py                  # every package document
python3 tool/check_doc_dependencies.py tom_core_samples # one prefix
```

A package document's Dependencies section tells a reader what the package is
wired to, and it is written once and never revisited. Measured against the
pubspecs, eleven of these sections existed and seven were incomplete, with 28
declared entries missing between them and four further package documents
carrying no section at all. The omissions all fell the same way: every one was a
*build-time* entry (`build`, `build_runner`, `tom_reflection_generator`, `lints`,
`test`, `flutter_test`, `flutter_lints`) and the runtime half was in every case
complete. That is the worst half to drop, because it is exactly what a reader
needs in order to reproduce a generated file — a section listing what a package
links and omitting what built it reads as finished and answers the wrong
question.

The check requires each declared name to appear as a whole inline code span, so
`build.yaml` is not evidence for `build` and `tom_reflection` is not evidence for
`tom_reflection_generator`. It is one-directional on purpose: a name in the
section that the pubspec does not declare is not a fault, because these sections
earn much of their value from naming what is *absent* — no Flutter, no
`tom_core_server`, `tom_reflection` arriving transitively through the kernel.
A document is audited when its opening inventory resolves to a directory with a
`pubspec.yaml`, the same rule `check_doc_inventories.py` uses, so module
documents are skipped rather than faulted.

```bash
python3 tool/check_module_dependencies.py                # every module document
python3 tool/check_module_dependencies.py tom_core_kernel # one package
python3 tool/check_module_dependencies.py --self-test     # perturb and require detection
```

Module documents get the same audit one level down, against imports rather than
against a pubspec. A dependency table is the one part of a prose document that
is wholly derivable from the source, and the part that goes stale most quietly:
an import added to a file changes nothing a reader can see, so the table keeps
listing what the module used to need and the omission looks exactly like a
dependency that was never there. It is checked in both directions, and the
`Imported by` column per dependency — a table can name the right four
dependencies and still attribute them to the wrong files.

That is only possible because there is one shape to parse. These 57 sections
came in four table layouts plus 51 written as prose, which is why exactly one of
them had ever been checked: a checker tolerant of five formats can verify only
what each format happens to state, and `| Dependency | Used for |` names no
importing file at all. The `For` column is prose and is held only to being
non-empty; requiring every name in it to resolve was tried and rejected, because
those cells routinely name a type the dependency does not declare, which is the
sentence worth writing.

```bash
python3 tool/check_dart_format.py           # every package
python3 tool/check_dart_format.py --fix     # format them instead
python3 tool/check_dart_format.py --self-test
```

Formatting drift is invisible to the check everybody runs: `dart analyze` says
nothing about line wrapping, so a file can be analyzer-clean, test-green,
reviewed and merged while being unformatted. The cost is not the whitespace — it
is that every later change drags an arbitrary slice of the pending reformat into
its diff, so a 173-line change arrives as a 6,000-line one and stops being
reviewable. This repository has paid that bill four times, and on the day this
gate landed a fifth package had four drifted files that nothing could see.

The scope is every `.dart` file under `tom_ai/core`, found by walking it rather
than from a list of directories to keep up to date. Left out: dot-directories,
`tool/ztmp` (the scratch tree `check_doc_dart_blocks.py` writes documentation
snippets into — their wrapping is not a package's defect), and generated output.
`tom_core_kernel` and `tom_core_server` keep their own in-suite
`formatting_test.dart`, which is where a developer working in those packages
gets the signal; this covers the other 21, which had nothing.

```bash
python3 tool/check_doc_error_keys.py                 # every section and guide
python3 tool/check_doc_error_keys.py tom_core_server # one project's documents
python3 tool/check_doc_error_keys.py --list          # print each census
```

A module's error keys are its public vocabulary of failure, and the section is
written as a reference a client author branches on. So a key that is raised and
not listed is a branch nobody knows to write, and a key that is listed and not
raised is a branch that can never be taken. Both are silent — neither the
compiler nor any test notices, because the section lives in another repository
from the code it describes. The check reports them as `ABSENT` and `UNKNOWN`.

Deciding what counts as an error key cannot be done from the shape of a string
literal, because plenty of dotted lowercase literals are configuration keys,
claim names or table names. So it works in two passes: the first argument of
every `SomethingException(` establishes a key, those keys establish their
*families*, and any other dotted literal of an established family counts too.
The second pass is what catches the keys that reach a client without being
thrown — handed to a result object, assigned to an `error` field, returned by a
local `_error` helper. Deriving the families from the raises rather than listing
them keeps the rule general while still excluding `oauth.providers`, a
configuration key whose family no exception establishes.

This table has proved as prone to decay as the inventories: one hand census
found six glosses describing the wrong condition, and a later one found thirteen
keys missing outright — including an entire family, every failure an external
login can report. A hand census also invents keys, which is why `UNKNOWN` is
worth reporting at all.

**Three genres, two assertions.** A completion document's `Error keys` section
promises to be the whole vocabulary in one place, so both faults are reported
against it. A sample's package document and a package's hand-written **module
guide** (`tom_core_*/doc/`) are read whole instead, and only `ABSENT` is.

The weaker assertion is not a shortcut in either case. A guide distributes its
keys by topic on purpose — `authentication.md` houses seventeen
`login.error.2fa.*` in an `### Outcomes` table and the rest across two
`Failure keys` tables — so reading only the first matching section would report
the other twenty-odd as missing. And prose about an API is full of dotted tokens
that are not keys: `preferences.getOr` is a method reference, and no shape tells
it from a key of the `preferences` family. Over the whole corpus `UNKNOWN`
produced six findings on the guides and four were exactly that.

Adding the guides is what the 330 in this gate's baseline are. The gate had
audited only sections headed exactly `Error keys`, in one repository; the guides
spell theirs `Failure keys` and live in this one, so they were reported clean by
never being opened — which is how six keys went missing from `authentication.md`
while the run before it read *0 defective across 2 sections*. 33 guides carry a
vocabulary, 24 are short of it, and four documents hold most of the debt. It is
frozen rather than repaired for the reason the ratchet exists: writing 330
reference entries is separate work, and until it is done every *new* unnamed key
would land unnoticed among them.

A guide is matched to its module by position — `PROSE_PACKAGES`, the same map
`check_module_dependencies.py` walks — because unlike a completion document a
guide does not open with its source path. Both genres are required to resolve,
and separately: one is found by a glob and the other by that map, so either can
stop resolving while the other still does, and a single combined count would
hide it. Breaking the map makes the run exit 2, not report clean.

```bash
python3 tool/check_dartdoc_refs.py                 # the whole repository
python3 tool/check_dartdoc_refs.py tom_core_server # one subtree
```

A `[name]` in a `///` comment renders as a link when it resolves and as plain
text when it does not, so renaming a member turns every reference to it into
prose without anything failing. The obvious detector, the `comment_references`
lint, is the wrong tool here: it flags hundreds of *correct* references to real
classes in sibling files (353 of 5556, measured — see `report_crosslib_refs.py`
below), and satisfying it would mean adding imports that exist only for prose,
several of them cycles. This check takes the part of the problem that has no
such ambiguity — a private name can only ever resolve inside its own library, so
whether it exists is answerable from that library alone. That is also exactly
the shape a rename leaves behind.

```bash
python3 tool/check_dartdoc_build.py                  # the gated packages
python3 tool/check_dartdoc_build.py tom_core_server  # one package, ad hoc
```

The other half of the same question, and the only thing in the toolchain that
answers it: `dart doc` itself. The gate above asks whether a referenced name
*exists*; this one builds the documentation and requires the build to say
nothing at all.

The two are complements rather than rivals, and the difference is the
population. `comment_references` judges every reference in the tree, which is
why it cannot be turned on here. `dart doc` judges only what is reachable from
the package barrel — the surface that ships, where a reference either resolves
for the reader or does not and there is no import graph to trade away. Eleven
references in `tom_core_kernel`, against the 353 the lint would have raised.

Left alone the class does not stay still: eight unresolved references were
recorded in this package on 2026-08-19, and three weeks later the same command
reported eleven — two of the original eight repaired in passing, five new ones
arrived, across four unrelated modules. Each is one bracketed word inside a
comment that reads perfectly, which is why review does not catch them and a
build does.

Every warning counts, not only unresolved references: a documentation build
that is allowed to say one thing is a build nobody reads. The rendered HTML is
thrown away — 18 MB for `tom_core_kernel` alone, and what the gate wants is the
log, which names every fault by file and line. The log is kept under
`tool/ztmp/dartdoc/`. Packages are gated only once they are silent, the same
rule `check_doc_dart_blocks.py` states.

```bash
python3 tool/check_consumer_claims.py                 # the whole repository
python3 tool/check_consumer_claims.py tom_flutter_ui  # one subtree
```

"Used by `[TomFoo]`" is the most load-bearing sentence an opening paragraph can
carry, because it is the one a reader uses to decide what the thing is *for* —
and nothing about deleting a class visits the prose in the files that recommended
it, so the sentence survives fluently and wrong. `TomEmptyState` opened with
"Used by `TomListForm` when its bound list is empty" and `TomListForm` is a pure
model with no Flutter import and no `build`; the unsaved-changes guard pointed at
`TomMasterDetailScaffold`, deleted on purpose and documented as deleted two files
away. This is not the previous check's question: `[TomListForm]` *resolves*
perfectly. Link checking and fact checking are different questions, and only the
first was being asked.

A claim counts as backed when the named consumer's own code — its doc comments
excluded, since a mention in prose is not a use — references anything the
claiming library declares. A `Tom`-prefixed name declared nowhere in the
repository is reported separately as deleted, which is why the index is always
built repo-wide even when one subtree is checked: `[TomForm]` is not missing
just because `tom_flutter_ui` does not declare it.

```bash
python3 tool/check_doc_attributions.py                 # the whole repository
python3 tool/check_doc_attributions.py tom_flutter_ui  # one subtree
```

The previous two checks ask whether a name *resolves*. This one asks whether it
resolves **where the prose says it does** — a different question, and the one
two READMEs got wrong. `advanced_authadmin_client` called
`lib/screens/grants_screen.dart` a `DataTable`; the screen builds a
`TomDataTable`. Its neighbour said `lib/screens/board_screen.dart` re-runs when
the `DropdownButtonFormField` changes; that screen has a `TomDropdownButton`.
Both wrong names are real Flutter classes, in scope in every package here, so
resolution finds nothing to object to. Misattribution is a two-place relation,
and nothing about a name on its own says which file it was claimed for.

The unit of judgement is therefore neither the document nor the name but the
**claim**: one cited `.dart` path, and the span of prose still speaking about
it — the citation's own sentence, plus the next one only when it opens
anaphorically (`It`, `This`, `The file`). That last rule is what a
character-count window cannot express, and it is load-bearing: without it the
same corpus yields six false positives, every one a sentence that had moved on
to a new subject. Names under a negation are skipped, because "carries no
`TomForm` of its own" is prose whose whole point is that the file does not
contain it; a claim is judged against everything it cites rather than the first
path only; and containment follows `export` and `part` transitively, since a
barrel declares nothing itself. Changelogs and `_copilot_guidelines/` are out
of scope — one describes a past tree and the other an intended one, and neither
can be repaired.

Measured before being switched on: 441 claims, 105 type names judged, one true
fault — `tom_flutter_ui_test` calling `lib/locale_settings.dart` an "`AppBar`
language selector" where the file declares `LanguageSelectorButton`. The naive
rule this replaces — is the name absent from the package's own `lib/`? — scored
two true faults in 24 candidates across the sample READMEs, where four of the
rest were not types at all and eighteen were deliberate contrast mentions that
have to stay. A rule that never cries wolf is one people leave switched on.

```bash
python3 tool/check_doc_samples.py                  # the whole repository
python3 tool/check_doc_samples.py tom_core_server  # one subtree
```

It reports the two halves of one mistake: a constructor taking named parameters
only, called positionally, and a constructor whose first parameter is a required
positional, called with a named argument first. Either way the sample does not
compile, and nothing about editing a signature brings the samples into view.

A third fault is about a keyword rather than a bracket: a const instance —
`const Foo(...)` or `const x = Foo(...)` — of a class with no const
constructor. This one rots in place. A sample written while the constructor was
const stays on the page after someone drops the modifier, and the build stays
quiet. That is not hypothetical: `TomEmptyState` gave up its `const` so a
missing title would fail at the call site rather than becoming an error card
inside some enclosing `TomErrorBoundary`, and `custom/readme.md` went on showing
a const one until this check was written.

A fourth reads a line as a *claim* rather than a call: a document quoting a
constructor with the wrong parameter kind, `SelectableItem(T value, String
label)` where the real declaration is named-only. Of the two this is the worse
defect, because a reader cannot detect it from the page — a miscalled sample
fails when it is pasted, a misquoted signature is simply believed. Only the kind
is compared: a quoted list is routinely elided or cut down to the parameters
under discussion, and none of that is wrong, but `{` against a positional
declaration is wrong however much of the list is shown.

This check reads text and never invokes a compiler, which is what lets it run
over all 3432 fences in both git roots rather than the packages a heavier gate
has been triaged for. It is a narrow slice of "does the sample compile", but it
is the slice that catches the copy-paste failure: a reader pastes the shortest
snippet in the document, and the shortest snippet is the one nobody re-checked
after the signature grew a named parameter. Running the fences through the
analyzer is the sibling gate below, and the two answer different questions —
that one cannot see a call whose *arguments* are the wrong shape for a
constructor that does exist.

Names resolve within the document's own package only. Without an import graph
there is no telling a real cross-package reference from a collision, and
collisions dominate — the `User` a document sketches inside its own fence is not
some other package's `User`.

**The quest's completion documents are in scope too**, though they live outside
this repository and inside no package. They describe the same constructors the
package documents do, in the same fences, for the same reader; while a
document's package was read from its *path* they were not merely unchecked but
unreachable. A document no path places is placed by its **name** — the corpus is
named for what it documents, so `tom_core_server_export_new.md` resolves against
`tom_core_server`, by longest package prefix so that
`tom_flutter_ui_test_app_changes.md` stays with `tom_flutter_ui_test`. That
makes a naming convention load-bearing, so the run prints how many documents it
could not place and names them, every time including a clean run: a rename that
drops a document out of coverage appears in that list rather than as silence.

```bash
python3 tool/check_doc_dart_blocks.py                  # the gated packages
python3 tool/check_doc_dart_blocks.py tom_core_server  # one package, ad hoc
```

The sibling that does invoke the compiler. Every ` ```dart ` block in a
package's documents is written into a scratch package with a path dependency on
that package and handed to `dart analyze`, under two rules. Three trees are
walked rather than listed: `doc/`, the package `README.md`, and the per-module
`readme.md` files under `lib/` — the documentation closest to the code, and the
one a developer reads while already in the source.

**It must parse.** A block is wrapped in each context a sample can occupy — at
top level, inside an async function, as class members, as a single expression,
or a declaration followed by statements using it — and one success is enough.
Trying every context beats classifying first: classification is the harder
problem, and a wrong answer reports a fault that is really a mis-wrap.

**Every framework name in it must resolve.** A sample is free to invent
`Person`, `OrderService`, `settings` — that is its own illustrative fiction, and
resolving it would mean writing the fiction out as stubs, which is a great deal
of invention *and self-fulfilling*, since a stub written to match a sample can
never contradict it. Auto-stubbing is worse: it would define away the exact
failure the gate exists to find, because a mistyped `TomBeen` would be stubbed
into existence and pass. A name beginning `Tom`/`tom` is not fiction — that
prefix is the framework's, so a sample using one is *claiming* the framework has
it.

**A fence that says it is whole must analyze clean.** The second rule's
concession is also its blind spot: a snippet using an undeclared `preference`
and reading back a `stored` it never named passed both rules, because neither
name begins `Tom` and that fiction is what the rule allows. A fence can opt in
by naming itself in its own info string — ` ```dart complete ` — and is then
judged by *every* diagnostic. Opt-in and not opt-out, because most fences here
are deliberately fragments; a snippet that wants checking is written whole
rather than given a preamble the reader cannot see.

The marker is a claim the gate holds the page to. Of 29 fences carrying both an
import and a `main` — and so *looking* whole — 22 were: three import a file
`build_runner` generates and four stand in an application they invent, and those
stay unmarked. One was neither, and is the reason the rule exists:
`logging.md`'s multi-isolate sample passed `args` to `startIsolatedLogging` from
a `main()` that declared none, so a reader copying it got an undefined name.

The documents' elision conventions are honoured rather than edited away: `{ ... }`
for a body and `// ...` for elided statements are how a sample says "the rest is
not the point". Three positions for `{ ... }` have to be told apart, because
Dart accepts different things in each — a type body becomes empty, a collection
literal becomes empty, and a function body throws, since a non-void function
that completes normally is an error.

This is the defect class that is invisible to review by construction. Four
non-compiling samples were found in `beanlocator.md`; two were spotted by
reading, and two — an elided `[...]` in argument position, and a class declared
twice in one block — were not, having already survived a careful pass. A
failing block is left behind as the source the analyzer actually saw — under
`tool/ztmp/doc_dart_blocks/<package>/lib/samples/` — which reads far more
easily than a line number; a clean run leaves nothing. The scratch directory is
per package, because the pubspec inside it names exactly one path dependency.

The generated API summaries are excluded — `doc/api_reference/` in some
packages, `doc/api/` in others, one category under two names. Those fences
quote *signatures*, and a signature is a declaration rather than a use: making
them parse would take a mechanical `;` per block and buy nothing, because a
declaration never consults the real API and so the second rule could never
fire. A green light there would be coverage in appearance only.

`tom_core_kernel`, `tom_core_agentic`, `tom_core_codespecs` and
`tom_core_flutter` are triaged to zero and gated; `tom_core_server`,
`tom_flutter_ui` and `tom_flutter_ui_test` still answer with faults, and adding
one to `PACKAGES` before repairing it would pin that backlog in place rather
than fix it — run them with the argument in the meantime. Gating
`tom_core_flutter` means the scratch package resolves against the Flutter SDK,
so this gate needs one on PATH; the two `tom_flutter_*` packages need more than
that, a `package:flutter` preamble the checker does not yet write.

```bash
python3 tool/check_section_refs.py                  # the whole repository
python3 tool/check_section_refs.py tom_core_server  # one subtree
python3 tool/check_section_refs.py --self-test      # check the checker
```

A `§` reference is fine when the sentence says what it indexes — ``per
`codespecs_mapping.md` §5.16``, `RFC 7636 §1` — and a fault when it stands bare:
`(bug §75)`, `Before §22 the unanchored regex accepted this`. The bare numbers
index sections of the quest plans, working documents that ship with neither a
package nor its tests, so a reader of the shipped artefact cannot resolve them
and a reader who could would find a build log rather than a rule. A test name is
the sharpest case: it is read as a specification, and `bug §75` specifies
nothing, so a failure reports an index entry instead of the contract that broke.

The check covers everything that leaves the workspace: the Dart under `lib/`,
`test/`, `example/`, `bin/` and `tool/`, and the prose in each package's `doc/`
and `README.md`. Quest plans are not scanned, because cross-referencing its own
sections is what a plan is for.

Shipped prose was once excluded on the same reasoning, and the exclusion cost
the gate its whole markdown population — the sample packages' documentation
carried references the Dart-only scan could never see. Almost all of them are
correct: a `§N` that indexes a numbered heading of the *citing* document, which
a reader resolves by scrolling, so the gate resolves it the same way. What the
widened scope catches is the one reference that looks identical and is not — a
bare `§23` in a document that has no §23, which in this tree matched a numbered
heading in two different specifications. That is worse than an unresolvable
reference: a reader who follows it lands somewhere plausible and wrong.

The question it asks is the one that matters to the reader: *can I see, from
here, which document this indexes?* A document name is a markdown-quoted or bare
`.md` filename, an `RFC <n>`, or one of the specification names used in this
tree, and it counts when it sits **in view** of the reference — on the same line,
or on a line immediately above or below within the same comment block. In view
rather than immediately-to-the-left, because a wrapped sentence is one sentence
and the writer did not choose where it broke; the narrower rule reported ``(§11.2
/ §11.4 of `tom_specs_editor_specification.md`)`` and its kind as faults, and a
gate that fails correct work is a gate that gets switched off. A bare `bug §75`
still cannot be resolved from anywhere and is still a fault.
A **quoted** reference is skipped, because a rule has to be able to exhibit the
shape it rejects. What tells the exhibit from the citation is where the sign
falls relative to an inline code span: the house style writes the *document* in
code and the section beside it — `` `codespecs_mapping.md` §5.16`` — so a real
citation's sign lands outside the span, and only a text shown as text puts the
whole of itself inside one. Measured before it was written: across the shipped
corpus exactly three references sit inside a span, all three in a guard file,
and every one of the four hundred-odd real citations sits outside.

That replaced skipping `comments_read_as_is_test.dart` by name. The filename
exemption cost that file every *other* reference it might carry — a bare `§45`
added to it would never have been reported — and covered only the one guard
anybody had noticed; `acl_shipped_text_test.dart` quotes the same shapes and was
never listed, passing by the accident that a document name sat in view of each.

The whole repository is clean and held there, prose included — every package,
in one pass, which is what makes it a gate rather than a thing somebody
remembers to run per package. The two `*_test` harnesses are held to the same
rule as shipped code: they never leave the workspace, but a test name is read as
a specification wherever it lives, and a red `createPlaceholderBytes (§69)`
names nothing.

Zero is also the count this checker would report if it had stopped reading, and
that risk is sharper here than elsewhere: five of its six rules *resolve* a
reference rather than fault it, so a regex that quietly stopped matching would
look like a repository that got cleaner. `--self-test` writes one reference of
each shape to a scratch directory and requires the stated verdict on it —
faulting probes and resolving probes both, since a suite of one kind alone would
pass a checker that answered everything the same way.

```bash
python3 tool/check_section_numbers.py                  # the whole repository
python3 tool/check_section_numbers.py tom_core_server  # one subtree
```

The sibling of the check above, one step further in. `check_section_refs.py`
asks whether a `§` reference names a document a reader can reach;
`check_section_numbers.py` takes the ones that do and asks whether the document
actually has that section. Both failures read identically in the source — a
plausible number beside a plausible filename — and only the second survives the
first check, so it needs its own pass.

The two scan **the same files**, and that is a property to preserve rather than
a coincidence. They ask consecutive questions about one reference, so a file only
one of them sees is half-checked in the shape hardest to notice: a green pair of
gates. Widening the first to shipped prose therefore widened this one too, which
brought 41 previously invisible markdown citations under it; widening again to
the markdown that ships outside `doc/` — every module `readme.md` under
`lib/src/`, and the samples package's `README_advanced_*` chapters — brought 72
more documents under both, and both stayed at zero.

They scan **exactly** the same files, with no exception. There was one:
`check_section_refs.py` skipped `comments_read_as_is_test.dart` by name, so the
pair differed by two files. Recognising a quoted reference by its code span
retired that exemption, and the populations closed.

```bash
python3 tool/check_comments_read_as_is.py                  # the whole repository
python3 tool/check_comments_read_as_is.py tom_core_server  # one subtree
```

The third member of that family, and the one that does not involve a `§` at all.
Shipped text is read **as is**, by someone holding the package and nothing else,
and two constructions break that. **Work-item ids** — `tcincb154_ahzj`, `RCK13`,
`RCC5`, `Todo 9` — name rows in quest documents that ship with neither the
package nor its tests. **History narration** — "used to return", "before the fix
it threw" — describes the sequence of states that produced the code, which is
the commit log's job; the repair is almost always to turn the past indicative
into a conditional, so *before the fix it threw* becomes *doing X instead would
throw*, which says the same thing to the reader and stays true.

Traceability is not lost, it is reversed: a todo may name the file it changed,
so the pointer lives in the document that can hold it. Todo → code, never code →
todo.

Three things are deliberately not faults. A testkit id in the leading
`ID: description` position of a test or group name is the join key of
`testlog/baseline_*.csv`, so renaming one discards that test's result history —
exempt there, and only there. `G-API-3`, `TC-14` and a bare `C-5` index the
framework's published guideline, testkit and concept vocabularies rather than a
work item. And `step 4` in an example refers to something the reader is holding;
only `Todo <n>` and `plan step <n>` point outside the artefact.

This is a Python gate rather than a copy of
`tom_core_kernel/test/comments_read_as_is_test.dart` per package because the
rule is one rule: hand-synchronised copies in two dialects — `tom_core_flutter`
runs on `flutter_test`, and `tom_core_samples` is not a package at all — would
drift, and Dart cannot share `test/` code across packages without publishing it.

That drift is not a prediction. Two copies existed and did not implement the same
rule: the kernel's matched a list of known quest prefixes, while
`advanced_ops_server`'s matched ids by *shape*, because the prefix list had let
`csexd4` and `csexd6` open that package's authorization suite while reporting it
clean. The fix was made in the copy and never travelled back — so the kernel's
guard still had the blind spot, and so did this gate, by which time the same
`cs` family had reached shipped `lib/` dartdoc in three further packages.
Sixteen copies would not be sixteen guards, only sixteen places for the next fix
to fail to leave. Coverage lives here, where there is one implementation to fix;
the two in-suite guards stay as the fastest signal for the packages they guard.

All three now match the shape, and the reason is the shape of the two lists
rather than a preference. A list of quest prefixes is **open**: it grows every
time anyone mints one, so a guard built on it fails open and in silence — the
`cs` leak is exactly that failure, and so is the plan-id half, which knew `RCB`,
`RCC` and `RCK` and not `RCA`, `RCD`, `RCF`, `RCI`, `RCJ` or `RCL`, six families
that were between them shipping 29 pointers past a green gate. A list of English
and published technical words is **closed**: minting `zzq7` does not make `zzq` a
word, so the guard fails loudly, on the new id, in the commit that adds it.

What had kept the shape rule from travelling repo-wide was a measurement taken
wrong. The claim was that it matches "397 further tokens" of mostly-real
vocabulary, so the exemption list would grow without bound — but that counted
*whole lines, code included*, and a numeric suffix is how Dart names things.
The number that decides whether a list is writable is the count of distinct
**stems**, and it depends entirely on where prose is held to end: 177 over whole
lines, 120 if every string literal counts, **59** over the prose the rule is
actually about — comment bodies and `test`/`group` descriptions. Fifty-nine is
readable, and every one of them is a word (`sha256`, `utf8`, `material3`,
`black54`). That gap is also the boundary's justification: a fixture string like
`user1` is data the test feeds to the code, not prose a reader reads.

Ids are matched in both cases. Lowercase (`tcincb154_ahzj`) and ALL-CAPS
(`RCK13`, `CSEXF1`) are separate patterns with separate vocabularies, kept apart
so neither list has to carry the other's words. Capitals are matched only as a
whole run, never camelCase, which is what keeps that list to twenty entries: a
Dart identifier with a numeric suffix is written `addressLine1`, `promptSha256`,
`mBlue100`, and a work-item id never is.

Generated Dart is skipped. `*.reflection.dart` carries whatever its sources
carried and is repaired by regenerating, never by editing; both in-suite guards
had always skipped it and this gate had not. The omission was invisible only
because no generated name happened to collide with a quest prefix, and it nearly
stopped being invisible — the reflection seed emits `prefix167`-style names, and
one file alone carries 46,929 of them, so the first collision would have buried
the report rather than sharpened it.

```bash
python3 tool/check_shared_chrome.py                  # the whole repository
python3 tool/check_shared_chrome.py tom_core_samples # one subtree
```

Some files exist several times over on purpose. Four showcase samples each carry
their own `lib/common/showcase_section.dart`, because a sample a reader can run
has to be self-contained — factor the chrome into a package and the interesting
file becomes the one *outside* the sample. The cost is that a fix applied to one
copy reaches none of the others, and nothing in the file says the others are
there. The convention that answers this is a sentence in the file's header
comment naming its siblings: ``Shared in shape with `core_flutter_acl_sample` /
`core_flutter_acl_responsive`.``

It works only while it is true, and it is the kind of claim that stops being true
in silence. `demo_box.dart` in `core_flutter_ui_showcase` named both its
siblings and neither named it back, so a developer editing either of those two
was told about one other copy out of two — an asymmetry that outlived the commit
declaring the pointers "complete and symmetric" by a single day.

Two independent questions are asked, because one rule cannot answer both.
*Is a copy declared?* — settled by content, since a file with no pointer is
invisible to any check that starts from the pointers. Two files sharing a
basename in different packages whose code is identical once comments and
whitespace are stripped are copies, and must be declared together. Comments are
stripped because copies drift in their prose long before they drift in their
behaviour, and behaviour is what a fix lands in. There is no similarity
threshold: a threshold drops a pair out of the gate exactly as it starts to
diverge, which is this gate's own failure mode arriving quietly.
*Do the declarations agree?* — settled by the pointers alone. "Shared in shape
with" is an equivalence relation, so each file's declared siblings must be its
whole connected component. Checking symmetry alone would pass A↔B and B↔C with A
never hearing about C.

Neither question subsumes the other, and the repository shows both.
`showcase_cell.dart` is declared across four packages but identical in only
three — the form showcase's copy has drifted, so content discovery sees three
and the declaration carries the fourth. `dto_reflection.dart` was identical in
`todo_domain` and `advanced_todo_contracts` and declared in neither, so the
declaration had nothing to say and content discovery found it; the same was true
of `login_credentials.dart` across the two client samples.

The pointer must sit in the file's header comment — the first run of `///`
lines, which dartdoc renders as the file's description and an editor shows on
open. That is the one place a reader is certain to have passed before making the
edit that needs to reach the siblings, so a pointer further down is reported as
misplaced rather than accepted. Whether the copies *should* be copies is left
alone: extracting shared chrome is a decision about what a sample is for, and
this gate only insists that whatever is duplicated is duplicated in the open.

```bash
python3 tool/check_test_inventories.py
```

Audits a document that claims to inventory a package's test files. The claim
has two halves and both rot: every file on disk should appear in the document,
and every file in the document should exist on disk. The second is the one that
bites — a document naming a file the runner never discovers vouches for a suite
that cannot run, and is the *reason* nobody looks. `tom_flutter_form_test`'s
completion document listed `screenshot_tests.dart`, plural; `flutter test`
matches `**_test.dart` and found nothing, so five committed golden baselines had
no comparer at all while the document said they were guarded.

The check requires **literal filenames** and so rejects a table that describes
its rows with patterns. That is the point rather than a limitation: the same
table once used `demo_*_test.dart` and `phase*_test.dart`, and a pattern cannot
be wrong — twelve files matched no row, including every regression guard in the
package, and the gap was invisible from inside the document. A row that names
its files can be falsified; a row that describes a shape cannot.

Registration is explicit, one entry in the script's `INVENTORIES` map, because a
document earns an entry by claiming to be exhaustive and most documents that
mention a test file in passing do not. The inventory itself is delimited by
`<!-- test-inventory:begin -->` / `<!-- test-inventory:end -->`, and only the
files column of the table inside is read — so the description column stays free
to name a file when it has something specific to say about it.

```bash
python3 tool/report_crosslib_refs.py                  # the whole repository
python3 tool/report_crosslib_refs.py tom_flutter_ui   # one subtree
```

The odd one out: it **reports and never gates**, and always exits 0. Everything
above fails a build when it finds something; this cannot, because what it finds
is not by itself a defect. It counts the population `check_dartdoc_refs.py`
declines to police — `[Name]` references naming a type this repository declares
but the writing library cannot see — which is 353 of 5556 repo-wide, and 68 of
744 in `tom_flutter_ui` alone.

It exists so that number stays checkable instead of becoming folklore. The
decision to leave public references alone rests on the population being large
and untriageable, and a claim like that decays in silence — exactly what the
checks above are for. Untriageable is the operative half: whether a given
reference wants an import or a demotion to backticks turns on whether the two
libraries *ought* to depend on each other, which is an architectural judgement
and not a property of the reference. `custom/tom_loading_overlay.dart` linking
`[SlowValidator]` over in `forms/validation` wanted backticks — that dependency
would have been new and wrong; `[TomForm]` from `tom_form_child_container.dart`
plausibly wants the link. No single rule separates them, so a gate here would
spend most of its output being wrong. Re-run the report before revisiting any of
this.

```bash
python3 tool/check_source_citations.py                 # the whole repository
python3 tool/check_source_citations.py tom_flutter_ui  # one subtree
```

It reports Dart comments — and every line of an SVG figure or of documentation
written to be read beside the code — that cite a line number rather than naming
what they point at: `SELF` when no file is named, so
the citation lands in its own file, and `CROSS` when one is. `// Per the class
contract (lines 13-17)` was the case that prompted it. That citation was
accurate the day it was written, and any insertion above it would have left it
describing whatever slid into those lines — with nothing dangling, nothing
failing to compile, and nothing for a reader to notice.

**Figures are the worst host of all**, which is why they are scanned end to end
rather than only in their XML comment. A figure is an asset: nothing compiles
it, no test opens it, and the citation a reader actually sees is the one drawn
in a `<text>` element. `advanced_09_grade_data_path.svg` carried five such
citations — three distinct ones, each written twice, because a figure states
its claims in both the comment and the drawing — and all three had rotted: one
pointed a whole layer away from the layer it named, one named a path that no
longer existed, one had a stale end line. Nothing reported any of it.

**Markdown is scanned where it navigates**, which is a property of the document
rather than a list of paths: `doc/` pages, package `README.md` files and the
sample guides are written to be read beside the code, so there a `file.dart:12`
is an instruction to go and look. The scope was originally drawn around
`tom_core_samples/` alone — around where the fault had *accumulated* rather than
where it could *do harm* — and twelve citations outside it went on rotting
unwatched, nine of them in `doc/` pages shipped to consumers. One had failed in
the worst available way: `form_authorizers.md` opened its section on the real
`TomAuthorizer` API by citing `tom_authorization.dart:352`, a doc comment
belonging to a different class eighty lines above the one it named. It resolved,
it read fluently, and it was wrong. Three others named their target *and* cited
a line, and one cited `(line 151)` for a declaration whose file had since been
deleted — which is the argument against the tempting alternative of *validating*
the numbers instead: where the annotation exists it has already made the number
redundant, and where it doesn't the citation is unverifiable.

CHANGELOGs, `_copilot_guidelines/` and this README are out, each for a reason
that can be stated rather than listed. A CHANGELOG is a dated record, so its
citations describe a tree that no longer exists and repairing one would falsify
the entry. `_copilot_guidelines/` is workspace tooling that ships with neither
the package nor its pub.dev page — the same seam `check_doc_links.py` draws.
And this README is where the suite explains its rules, which it cannot do
without quoting the shapes it forbids; excluding it is what lets the gate keep
its documentation instead of acquiring a per-site suppression list.

**A citation may name any kind of file, and for a long time only Dart targets
were seen.** Two dimensions live in this rule and only one of them was widened:
which files are *scanned*, and which files a citation is allowed to *name*. The
target side stayed `.dart:<n>`, so `audit.md:496` in a guide was read and passed
over — though nothing in the argument above mentions Dart, and a markdown target
is worse if anything, since no compiler or test ever resolves it. It had already
cost the sample: `advanced_ops_server` carried nine pins into `.md` pages, all
nine had gone stale — some by 150+ lines, within nineteen days of being written
— and this gate reported the package green throughout, until they were found and
repaired by hand. The set of extensions is now read off the tree on every run
rather than listed, because a hand-kept list is permanently one commit behind
and goes quiet rather than loud on the day it falls behind. It does have to be
constrained to *something*: an unconstrained extension reads `server.port: 8080`
in a YAML example as a citation of a file called `server.port`, and
`127.0.0.1:3307` as one of a file called `127.0.0.1`. Suppressing those needs a
list of the things that are *not* files, which is an open set; the things that
*are* files are a closed one the tree can be asked for.

The rule now fires **zero** times across 1510 Dart files, 9 figures and 177
documents, over the 46 file extensions this repository contains, and that is the
argument for it rather than against. A gate
earns its place by whether the fault would be caught if it came back, not by how
much it currently finds; this fault is invisible by construction, and a
convention met once a year is one no reviewer can be asked to hold. Because the
rule is silent on the existing tree it adds no triage burden — the opposite of
the two rules declined nearby, at 353 and 519 violations of judgement. Naming
the target is always possible, which is what keeps the rule fair: every line
range sits inside a class, a member or a headed list that has a name, and the
named form survives the edit that breaks the numbered one.

**The guides were the largest host, and are now scanned too.** Markdown was
originally excluded on arithmetic — 173 occurrences across 18 files would have
meant 173 judgement calls on day one. Those calls have since been made for
`tom_core_samples/`: every anchor was resolved by hand and replaced with the
name of the declaration it pointed at. Checking them first settled whether the
fault was theoretical. It was not: *essentially every* anchor had drifted, and
almost all of them still resolved — to real code that was simply not the code
the sentence described. An anchor for the login JWT pair landed inside
two-factor submission; one for the closed-safe grade default landed on a
different method; several landed on blank lines and closing braces. Only two
pointed past end of file, which is the sole variant a reader can detect
unaided. Making those calls is what let the boundary move from that subtree to
every document that navigates.

A citation must show it is one — a plural range, a parenthesis, or a pointing
word — so `a line 2 pixels wide` is left alone, and URLs are skipped whole,
since a permalink pinned at a commit is the stable form this check is asking
for.

```bash
python3 tool/check_doc_kinds.py                  # the whole repository
python3 tool/check_doc_kinds.py tom_core_agentic # one subtree
```

Most module documents open with an Overview table whose second column is `Kind`,
and a reader uses that column to decide what they may *do* with the symbol
before reading another line. `abstract interface class` means implement me, do not
extend me; `final class` means you may not subclass this at all; `class` means
both are open. Those are not synonyms, and the difference is the entire reason
the column exists — the neighbouring `Purpose` cell already says what the thing
is *for*.

The column decays in one direction. Nobody writes `exception`, `widget`,
`entity` or `annotation` by misreading the source; they write it because it is
the more *informative* word and Dart has no keyword for it. So the cell reads
fluently, describes the symbol's role correctly, and answers the question the
column is actually asked — may I subclass this? — with a word that cannot answer
it. `BearerAuthFailure` was listed as `exception`: true as a description, and it
happens to be a plain `class`, so a reader wanting to extend it was left to
guess.

This is a checker rather than a careful read because the fault was found three
times by hand, one document at a time, and each fix took two minutes. Three
identical findings in three consecutive scans is not bad luck — the documents
were written by one pass, and a pass writes its habits into everything it
touches. It is invisible to the neighbouring gates by construction:
`check_doc_inventories` audits *measurements*, and a kind is not a measurement;
`check_dartdoc_refs` and `check_consumer_claims` both ask whether a name
resolves, and every symbol in these tables resolves perfectly while the sentence
about it is still wrong.

Only tables whose header has `Kind` as its second column are read, and that
restriction is what keeps it honest — module documents carry other two-column
tables of the same shape, and reading those as kind claims produced four false
positives per real one when first measured. A symbol the repo does not declare
is skipped rather than reported, since these documents name Flutter and Dart
core types freely.

```bash
python3 tool/check_unimplemented_claims.py                 # the whole repository
python3 tool/check_unimplemented_claims.py tom_flutter_ui  # one subtree
```

A planning table is written before the work, listing what is to be built with an
`Implemented` column reading `No`. The work then happens, and nothing brings the
writer back to the column. In `tom_flutter_ui` such a table sat for months
denying eleven widgets, nine of which ship and seven of which have their own
section in `doc/custom.md` — and one row denied a widget the same document had
already recorded as wrapped, three hundred lines higher up.

That decay is why this is mechanical rather than a review item. Most
documentation faults are a sentence that was always wrong; this one was *right
when written*, so nobody who reviewed it erred, and the moment it turned false
left no trace in either file's diff. Building `TomEmptyState` does not touch the
document that says `TomEmptyState` does not exist. There is no edit to review,
so only re-checking finds it.

The neighbouring gates ask different questions. `check_dartdoc_refs` and
`check_consumer_claims` ask whether a name *resolves* — every name in these
tables resolves, and the row about it is still false. `check_doc_kinds` reads
the cell beside a symbol, but only where the second column is `Kind`, and it
asks what the symbol *is* rather than whether it is. The two share one
`DECLARATION` index rather than a copy of it, so they cannot come to disagree
about what Dart declares.

Three restrictions stop it inventing claims. The table needs a header naming
existence (`Implemented`, `Ships`, `Wrapped`, …) — `Status` is deliberately
excluded, because a "No" there is a workflow state, not a denial. The cell must
open with a denial once emphasis and backticks are stripped, so an emphasised
"No — superseded" still reads as one, and the qualification after the dash
survives into the report.
And the row's first cell must name a `` `Tom*` `` symbol in backticks: reading
prose mentions as row claims was the source of its false positives. Only type
declarations count, never a same-named function. `CHANGELOG.md` is out of scope
— an entry records what was true when it was written, and editing it would
falsify a record rather than repair a claim.

```bash
python3 tool/check_member_attributions.py                 # the whole repository
python3 tool/check_member_attributions.py tom_flutter_ui  # one subtree
python3 tool/check_member_attributions.py --self-test     # check the checker
```

A document that writes `` `TomCtr.doubleVal` `` is making two claims at once, and
the neighbouring gates check only the first. `check_dartdoc_refs` and
`check_doc_attributions` ask whether the *type* resolves — `TomCtr` does, so both
pass — while the assertion a reader actually acts on is that `doubleVal` is a
thing they can call on it. That second half went unchecked, and
`tom_flutter_ui_test/doc/widget_resource_parameters.md` showed what accumulates
in the gap: a nineteen-row table of resolver methods, seven of which existed
nowhere, attributed to a type that declares no resolvers at all, and citing the
wrong exception for four more. Every individual row looked vetted.

The interesting property of that document is that it was not invented. Each
fictional name mapped one-to-one onto a real member — `resolveDoubleOrNull` onto
`TomCtr.doubleVal`, `resolveColorOrFail` onto `TomCtr.colorOrFail` — and the
per-method citation counts tracked the real call-site counts, one of them
exactly. It was a systematic rename away from the truth rather than fiction,
which is harder to see by reading and trivial to see by checking.

**Writing a name qualified is what puts it in scope.** The checker reads
`` `Type.member` `` and nothing else, so a document that names its methods bare
under a heading is invisible to it — which is precisely how that table survived.
Repairing it meant qualifying all 1,181 references, and that, not the renaming,
is what moved the document from unverifiable to verified.

Four restrictions keep it from inventing faults. The reference must be
backticked and qualified; the type must start `Tom` and be declared in this
repository, which puts SDK types out of scope by construction; the member must
start lowercase, so `Type.NestedType` is not read as a member; and — the
load-bearing one — **it abstains entirely when the inheritance closure leaves the
repository**. A class extending `StatelessWidget` has a member list this repo
cannot see, and reporting half a list as complete would fail open on what it has
while accusing documents of naming members that genuinely exist. Members Dart
supplies without declaring them are added back: `Object`'s four, and `index` /
`name` / `values` on an enum, which implements `Enum` implicitly and so offers
`closure` no supertype to abstain on.

```bash
python3 tool/check_doc_class_inventories.py                # every document
python3 tool/check_doc_class_inventories.py tom_flutter_ui # one subtree
python3 tool/check_doc_class_inventories.py --self-test    # check the checker
```

An *inventory* is a region of a document that undertakes to list a family of
classes completely. It is not the same thing as a document that mentions
classes: a reader consults an inventory to answer "what is there?", and takes
its silence as an answer. That is what makes it decay differently from ordinary
prose. Prose that has fallen behind is merely incomplete, and reads as such; an
inventory that has fallen behind is **confidently wrong in two directions at
once**, and reads as authoritative in both.

Both directions were live in `tom_ui_widgets_forms.md`, in one 300-line
appendix: 81 rows carried a `**(TBD)** = class needs to be created` marker
against classes that had shipped — `TomFormStringInput`, `TomFormBoolSwitch`,
`TomFormDatePicker` among them — while 42 of the names in the same appendix
named nothing at all, because the catalogue was built under different names
(`TomCupertinoFormDatePicker`, not `TomFormCupertinoDatePicker`) or was never
built. The three concretes that shipped later — `TomFormFileDropzone`,
`TomFormFileThumbnail`, `TomFormDateTextInput` — appeared nowhere.

The second and third findings are why clearing the markers would have been the
wrong repair. It converts "wrongly says this does not exist" into "wrongly says
this does", which is strictly worse: a reader can check the first claim by
opening the file and finding the class, and cannot check the second by any means
short of the exercise this gate performs.

Nothing in a table's shape says whether it is an inventory or an illustration,
and guessing wrong is expensive in both directions — a missed inventory is a
gate that checks nothing, and a table read as an inventory by mistake demands
that a five-row example list ninety classes. So the region declares itself:

```markdown
<!-- class-inventory: tom_flutter_ui/lib/src/forms/fields extends TomField -->
... tables ...
<!-- /class-inventory -->
```

The declaration is also the only durable place to record *what the region is
for*. A section heading says "Form Class Hierarchy Inventory"; the marker says
which directory that sentence is about, which is the fact that makes the
sentence checkable.

`MISSING` reports a class the directory declares and the region never names —
the `TomFormFileDropzone` case. Only classes whose `extends` chain reaches the
base named in the marker are demanded, so the private widget and `State` classes
that make up most of a Flutter field file are not inventory entries and are not
asked for. `PHANTOM` reports a `Tom*` name the region lists that no `lib/` in
the repository declares — the `TomFormEmailStringInput` case, a planned name the
build reached by another route. The phantom index spans every package rather
than the marked directory, because an inventory legitimately mentions its
neighbours (`TomList`, `TomSelectableSource`, `TomAuthState`) and a gate that
called those phantoms would be unusable. There is deliberately no third fault
for a name that exists elsewhere in the repository but not under the marked
directory: `TomListForm` belongs to the list module and is named in the forms
inventory for contrast, and demanding that every mentioned class live in the
inventoried folder would forbid the sentence that tells a reader where the
boundary runs.

A gate baselined at zero passes just as well when it has stopped reading
anything, so this one refuses to run rather than report success: it exits 2 when
the declaration index is empty, when no marked region is found at all, and when
a marked region resolves to a directory that declares nothing of the named
family. `--self-test` asks the opposite question directly — it perturbs a real
inventory by one name in each direction and requires the checker to object.

```bash
python3 tool/check_field_grade_matrix.py                  # the whole repository
python3 tool/check_field_grade_matrix.py tom_core_samples # one subtree
```

The advanced sample's per-field grade matrix is its worked example of the
four-state authorization model, so it is quoted far more often than a normal
constant: three documents reproduce the whole 7×4 table and a dozen sentences
paraphrase one of its columns. `grant_matrix_key_consistency_test.dart` already
pins the *seed SQL* against the map, cell for cell — but nothing pinned the
**documentation** copies, and that is exactly where the drift landed.

The two questions it asks are different because the fault was asymmetric. All 84
documented cells were correct; four separate sentences beneath them were not.
Each said a `viewer` sees `status` disabled "while the rest are read-only", when
the viewer's `estimate` is `none` — masked, not read-only. A reader who trusted
the prose expected a greyed estimate on the item screen and would find nothing
there, which is why this outranks a wording slip: `none` and `read` differ in
what the user *sees*, not merely in what they may change.

So tables are compared cell for cell, and remainder claims are checked
separately. "The rest are read-only" is sound only when the named role has
exactly one non-`read` cell; the advanced `viewer` has two, so the sentence is
false however fluently it reads. The repaired form — "the remaining five are
read-only" — is checked numerically against the column, which makes it
self-checking: adding a field to the matrix breaks the count rather than
silently widening the word "rest".

Two restrictions keep it from crying wolf. A sentence must name exactly one
role, because a summary walking all four in one breath gives no mechanical way
to say which column "the rest" belongs to. And the whole check is scoped to
files mentioning `commenter` — a role only the advanced matrix has, which
cleanly separates it from `core_client_sample`, whose own three-role matrix
makes the identical sentence true.

```bash
python3 tool/check_resource_key_namespace.py                  # the whole repository
python3 tool/check_resource_key_namespace.py tom_core_samples # one subtree
```

The advanced sample addresses things in two key spaces that meet at exactly one
point: `item:<id>` names a **resource** and picks the principal's role, while
`todo.item.<field>` is a `TomField` basePath and picks the grade within that
role's row. Gluing the dotted scope to the front of the type merges them, and
the merged form was printed in roughly fifteen places across the guides and in
both representations of figure 09 — with doc 07 stating the rule those examples
violate six lines above them.

Nothing reported any of it, and nothing would: no compiler sees a string in
prose, and the merged key is invisible even when *executed* — the adapter gates
any key containing `:`, so it resolves as a resource key, matches no grant, and
collapses the field to `none`. Closed-safe, so it fails as silence.

The rule keys on the type segment rather than on "a dotted path before a colon",
which would match every source citation in the tree (`tom_form.dart:823`). The
four type names are read from `resource_keys.dart`, so a fifth resource type is
covered by construction. Two narrowings separate the fault from a Dart `switch`
label (`case AppResourceTypes.item:`, ten of them here): the scope segment must
start lowercase, and the colon must be followed by something on the same line.

```bash
python3 tool/check_figure_wellformed.py                  # the whole repository
python3 tool/check_figure_wellformed.py tom_core_samples # one subtree
```

SVG is an XML dialect, so a figure that is not well-formed does not render
partially — it does not render at all. `advanced_09_grade_data_path.svg` spent
four commits in that state: its description contained `--` inside an XML
comment, which the specification forbids. Nothing compiled it, no test opened
it, and no other checker parsed it; the two later commits that edited the very
same comment left it there.

It hides at the reading end too. A missing image looks like a bad path or a
stale checkout, not like a file that is present, visually correct, and rejected
over two characters in a comment nobody reads. Well-formedness is decidable, so
the check is total for the fault it names — and it fires zero times on the nine
figures today.

```bash
python3 tool/check_barrel_exports.py                 # the whole repository
python3 tool/check_barrel_exports.py tom_flutter_ui  # one package
```

Holds every barrel to the directory it claims to inventory.
`advanced_app_client/lib/app/app.dart` declared three exports beside four
exportable files, and the missing one was a real public type — imported by a
screen, documented in its own section, and unreachable by name to anyone
importing the barrel. `check_doc_inventories.py` caught that one only by
accident: its `barrel — N exports` label happened to say 4 while the barrel said
3, so the number was right about what the barrel was *for*. Had the label
agreed, the type would still have been unreachable. That gate compares a claim
against the code; this one compares the code against itself.

A barrel is a file that declares nothing of its own and carries at least one
unconditional `export`. Both halves matter: the first separates a barrel from a
library that happens to re-export a neighbour, and the second excludes the
platform shims — `export 'file_opener_stub.dart' if (dart.library.io)
'file_opener_io.dart';` names a *variant*, not an inventory, and reading it as
one would demand it export the other six files in its directory.

The claim is the barrel, not the directory. A directory with no barrel is
reported on by nothing, which is what keeps the six Flutter sample applications
out: their `screens/` and `groups/` directories correctly re-export nothing, and
demanding coverage there would produce some ninety faults, every one wrong.
Coverage is then reachability across *all* the package's barrels rather than the
one beside the file, so a sub-barrel works: `dtos.dart` should not export the
two neighbours that are not DTOs, and the package barrel already offers them.

Correct omissions are declared in the barrel itself, where they survive a file
move and are visible to whoever is editing the exports:

```dart
// not-exported: reflection_seed.dart — the apps install their own
// initializeReflection; exporting this one would collide with theirs.
```

The reason is required, and the marker is held to being real: one naming a file
that is not there, or one the barrels reach after all, is a fault. Generated
output (`*.reflection.dart`, `*.versioner.dart`, `*.g.dart`, `*.freezed.dart`)
is skipped by shape instead, since a marker about a file the next build rewrites
gives a reader nothing to weigh. Four markers exist today and the gate is at
zero.

```bash
python3 tool/check_kernel_bridge.py    # the whole repository
```

Audits the kernel bridge: every type the bridge registers should appear in a
declaration position, and the companions that legitimately do not are named
explicitly rather than passed silently.

```bash
python3 tool/check_demo_counts.py      # the whole repository
```

Pins the demo counts in `tom_flutter_ui_test/README.md` to `lib/`. A demo can be
counted two ways that are both correct — screens declared in `lib/`, tiles
offered by `lib/main.dart` — and three separate filings had each restated an
unchecked number. The counts live between `<!-- demo-counts:begin -->` markers
so the check compares a table, not prose.

```bash
python3 tool/check_pubspec_boilerplate.py                  # the whole repository
python3 tool/check_pubspec_boilerplate.py tom_core_samples # one subtree
```

Finds pubspecs still carrying generator boilerplate: a placeholder `description:`
("A new Flutter project."), or the tutorial commentary explaining versioning,
`pub upgrade`, `flutter_lints`, and how one *would* declare assets and fonts.

The description is the one place a tool reads the package's own summary, so a
placeholder there is the package failing to say what it is however well its
README reads. The commentary is worse than merely useless: in
`tom_flutter_ui_test` it was 62 of 100 lines, and its commented-out asset block
described an asset bundle the package does not have.

Unlike a prose slip this defect is machine-generated, reproducibly, by the
standard way packages are created — so every future `flutter create` reintroduces
it in full. The match is exact rather than heuristic: every sentinel was verified
verbatim against freshly generated `flutter create` (app and package) and
`dart create` (package and console) output, so a hand-written description is
never a false positive.

```bash
python3 tool/check_doc_overview_types.py                 # every document
python3 tool/check_doc_overview_types.py tom_core_server # one package
python3 tool/check_doc_overview_types.py --self-test     # check the checker
```

Holds a module document's Overview table to the types its module exports. The
table lists **every** public type the package barrel reaches from the module,
not a selection: a curated table cannot be checked, and `doc/preferences.md`
named five of six public types with the missing one the subject of the
document's own longest section. Nobody noticed, because with no rule about what
belongs there was nothing for the omission to contradict.

Exhaustive costs something and the cost is accepted. `object_persistence`
exports eighty-five types and its table has eighty-five rows. A table that long
is closer to an index than an overview — but an index that is complete beats an
overview that is silently partial, because a reader takes the silence of a list
for an answer. Rows may still group what is used as a set (`` `TomSelect` /
`TomCount` / `TomDelete` `` on one row); what the gate asks is that the name
appear somewhere in the table.

A document declares itself in scope by the shape it already has: an Overview
holding a table with a `Type` (or `Symbol`) column beside a `Kind` column. All
twenty `tom_core_server` module documents write that, and eleven others across
`tom_flutter_ui` and `tom_core_agentic`; `tom_core_kernel`'s Overviews are prose
and are out of scope until they are not.

```bash
python3 tool/check_reflection_artifacts.py             # the whole repository
python3 tool/check_reflection_artifacts.py --self-test # prove it can report
```

Analyzes every checked-in `*.reflection.dart` and fails on an `error`-severity
finding — a name the mirror writes that no longer resolves.

`analysis_options.yaml` excludes these files, for a good reason: a mirror
reflects whatever its source declares, including deprecated and
`@visibleForTesting` members, and a generated file that trips several lints per
package teaches everyone to ignore the analyzer. The cost is that the artifact
becomes the one file in the repository nothing reads — not analyzed, not
formatted, not reviewed — so a reference in it rots silently.
`advanced_ops_server` carried one: `MariadbMigrationAdaptor` lost
`splitSqlStatements` to the SQL-lexer extraction, the checked-in mirror went on
naming it, and `dart analyze lib test` reported "No issues found!" while every
test file in the package failed to load with `Member not found`.

An explicitly named file is analyzed whether or not the options exclude it,
which is what makes the check possible without changing them. Only `error`
severity counts: a warning or an info in generated code is the generator's
style, and faulting on it would recreate the noise the exclusion suppresses.

This is the cheap half of the question. `reflection_generation.sh --check`
answers the stronger one — is this file what the generator would emit today —
in about ninety seconds per package against four here, so it belongs before a
release rather than in a gate pass. An artifact can pass this gate and still be
stale, because a mirror merely *missing* a class the source has added references
nothing that does not exist. What it cannot do is pass and fail to compile,
which is the failure that takes a suite down.

```bash
python3 tool/check_doc_source_paths.py                  # the whole repository
python3 tool/check_doc_source_paths.py tom_flutter_ui   # one subtree
```

Checks that every `**Source:**` pointer in the documentation names something
that is actually on disk. A pointer resolves against the workspace root (for
cross-repo targets), the repo root (the usual package-prefixed form), or — when
an adjacent `**Package:**` line supplies the prefix — that package's root. That
third root is what makes the rule fair rather than merely strict: a bare
`lib/src/...` under a `**Package:**` header is correct, and the same path
without one has no package to be relative to.

Nothing else reads these paths, so a pointer at a deleted directory breaks
silently and stays broken. The instance that prompted the check had a part
header naming a `tomclient/forms/` directory removed refactors earlier, while a
subsection of that same part correctly named the directory it had moved to.

There is no exemption for history documents. Naming a removed type in prose is
fine and often necessary; `**Source:**` is different, because it is an
instruction to go and read something, and that instruction is false once the
target is gone.

```bash
python3 tool/check_doc_artifacts.py                  # the whole repository
python3 tool/check_doc_artifacts.py tom_core_kernel  # one subtree
```

Finds machine-generated files that version control carries under a package's
`doc/`. That folder holds the documentation a person wrote, which three places
already state — the repository `.gitignore`, testkit's `trackingDirName`, and
the documentation-placement guideline. None of the three could notice being
broken, and all three were: six generated files sat in `doc/` across three
packages, the youngest months stale.

Staleness is the defect, not weight. A tracked artifact photographs one
machine's build and nothing updates it, so it cannot be told apart from a
current one without finding the live path and comparing dates — a reader who
trusts it is misled, and a reader who does not gains nothing. The kernel's
captured test run being 934 KB was the smaller problem; its being eleven weeks
out of date was the real one.

```bash
python3 tool/check_doc_links.py                  # the whole repository
python3 tool/check_doc_links.py tom_core_kernel  # one subtree
```

Follows every markdown link in the tree. A link is the one part of a document
that promises to take you somewhere, and it was the part nothing verified: the
sweep that prompted this gate found 89 broken links under this repo and 371 of
a single shape across the workspace — every project's
`_copilot_guidelines/index.md` opened with a table of links to the shared
guidelines, and not one of them worked anywhere.

Three faults. `ABSOLUTE` is a target beginning with `/`, which reads like "from
the workspace root" and means the *filesystem* root, so it opens neither in VS
Code nor on GitHub; that is the shape that reached 371, copied from a template
that carried the defect, growing by one table per new project. `DEAD` is a
relative target not on disk — the kernel's API index offered a "Result" row
pointing at a summary nobody wrote, for a module the kernel does not have, in a
table whose own header says seventeen and which listed eighteen. `GUIDELINE` is
a link from outside `_copilot_guidelines/` into it: not broken, but a layering
fault, because `doc/` and `README.md` are what a consumer reads and
`_copilot_guidelines/` ships with neither the package nor its pub.dev page.

Anchors are deliberately not checked here — whether a heading exists is
`check_doc_tocs`'s question, and answering it twice in two dialects of
heading-slug is how two gates come to disagree. That deferral is load-bearing
in both directions, so `check_doc_tocs` checks body anchors and not only the
ones a table of contents uses. Fenced blocks are skipped and
inline code spans blanked, which is correctness rather than tidiness in both
directions: a naive scan reads `operator [](Object? key)` in every
`api_summary_*.md` as a link, and *rewrites* the template inside a ` ```markdown `
fence into something true only of the file containing it. Both happened while
this gate was being written.

```bash
python3 tool/check_doc_ai_citations.py                 # the whole repository
python3 tool/check_doc_ai_citations.py tom_flutter_ui  # one subtree
```

Finds shipped documents — `doc/` and package `README.md` files — that cite a
path under `_ai/`. That layer is a separate repository (`tom_agent_state`)
mounted by symlink, absent from any checkout of `tom_ai/core`, so such a
citation cannot resolve for the audience `doc/` is written for. Two sites in
`tom_flutter_ui/doc/` cited a quest planning document, and the section doing so
called it *the canonical layout contract* — a shipped document deferring its
authority to a file its reader cannot obtain, which leaves the contract
effectively unstated.

The cited file existed, so this is not a dangling link but an unreachable one,
and that distinction is why the defect survives a scan: neither `find` nor `git
ls-files` follows the `_ai` symlink, so a citation of a file that is present
reads as "file does not exist" to any tool run from the container root. Keying
on the citation rather than on the target is what makes the answer stable.

`_copilot_guidelines/` and `CHANGELOG.md` are out of scope, both because `_ai/`
is genuinely reachable for their readers: development documentation is written
for the agent working in this workspace, where the mount is present, and a
changelog naming a completion folder is recording how a change was verified
rather than pointing at a contract.

The rule keys on what a person authors rather than on a list of known generated
filenames, which only ever catches the artifact someone already found.
Documentation is markdown, with diagrams and the occasional released PDF beside
it; anything else under `doc/` was put there by a tool. And the question is what
version control carries, so the inventory comes from `git ls-files` — a tool
writing under `doc/` on one machine costs nobody anything until it is committed.

## License

BSD 3-Clause licensed. Each package carries the same
[`LICENSE`](tom_core_kernel/LICENSE); see any package folder for the full text.
