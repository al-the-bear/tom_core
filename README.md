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

| Tool | What it does |
| ---- | ------------ |
| [`tool/check_doc_tocs.py`](tool/check_doc_tocs.py) | Audits every `## Table of Contents` in the tree against its own document |
| [`tool/check_doc_inventories.py`](tool/check_doc_inventories.py) | Audits the file inventories in the completion documents against the tree |
| [`tool/check_doc_error_keys.py`](tool/check_doc_error_keys.py) | Audits the "Error keys" sections in the completion documents against the keys the code raises |
| [`tool/check_dartdoc_refs.py`](tool/check_dartdoc_refs.py) | Finds dartdoc references to private names that no longer exist |
| [`tool/check_consumer_claims.py`](tool/check_consumer_claims.py) | Finds dartdoc that names a consumer which does not consume |
| [`tool/check_doc_samples.py`](tool/check_doc_samples.py) | Finds Dart samples in the docs that call a constructor the wrong way, or `const` one that is not |
| [`tool/check_section_refs.py`](tool/check_section_refs.py) | Finds `§` references in shipped code that name no resolvable document |
| [`tool/check_source_citations.py`](tool/check_source_citations.py) | Finds source comments that cite a line number instead of naming the thing |
| [`tool/check_doc_kinds.py`](tool/check_doc_kinds.py) | Finds `Kind` columns whose cell names something Dart does not declare |
| [`tool/check_field_grade_matrix.py`](tool/check_field_grade_matrix.py) | Pins every documented copy of the advanced field-grade matrix — tables and prose remainders — to the map in code |
| [`tool/check_resource_key_namespace.py`](tool/check_resource_key_namespace.py) | Finds resource keys written with the field-grade scope glued to the front of the type |
| [`tool/check_figure_wellformed.py`](tool/check_figure_wellformed.py) | Finds SVG figures that are not well-formed XML, and so render as nothing |
| [`tool/report_crosslib_refs.py`](tool/report_crosslib_refs.py) | **Reports** (never gates) dartdoc links naming a repo type the writing library cannot see |

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
python3 tool/check_doc_error_keys.py                 # every "Error keys" section
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

The obvious guard — extract every ` ```dart ` fence and analyze it — is a much
larger job than it sounds. There are 1770 fences here and most are fragments: no
imports, undefined variables, a method body with no class around it. Making them
compilable needs a harness per sample, and a check that expensive to satisfy gets
switched off. This takes the part that is decidable from the text alone, because
whether a call is positional or named is visible in the call and whether the
constructor accepts that is visible in the signature. It is a narrow slice, but
it is the slice that catches the copy-paste failure: a reader pastes the shortest
snippet in the document, and the shortest snippet is the one nobody re-checked
after the signature grew a named parameter.

Names resolve within the document's own package only. Without an import graph
there is no telling a real cross-package reference from a collision, and
collisions dominate — the `User` a document sketches inside its own fence is not
some other package's `User`.

```bash
python3 tool/check_section_refs.py                  # the whole repository
python3 tool/check_section_refs.py tom_core_server  # one subtree
```

A `§` reference is fine when the sentence says what it indexes — ``per
`codespecs_mapping.md` §5.16``, `RFC 7636 §1` — and a fault when it stands bare:
`(bug §75)`, `Before §22 the unanchored regex accepted this`. The bare numbers
index sections of the quest plans, working documents that ship with neither a
package nor its tests, so a reader of the shipped artefact cannot resolve them
and a reader who could would find a build log rather than a rule. A test name is
the sharpest case: it is read as a specification, and `bug §75` specifies
nothing, so a failure reports an index entry instead of the contract that broke.

The check covers `lib/`, `test/` and `example/` — the three directories whose
contents leave the workspace. Plans and other markdown are not scanned, because
cross-referencing its own sections is what a plan is for. What counts as naming
the document is deliberately literal: the text immediately left of the sign must
end in an `.md` filename, an `RFC <n>`, or one of the specification names used
here. That rule is cheap to satisfy correctly — write the document name you
meant — and cannot be satisfied by accident, which is what makes it worth gating
on. `tom_core_server` is clean; the other packages are not yet, so run it with a
subtree argument.

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

It reports comments that cite a line number rather than naming what they point
at: `SELF` when no file is named, so the citation lands in its own file, and
`CROSS` when one is. `// Per the class contract (lines 13-17)` was the case that
prompted it. That citation was accurate the day it was written, and any
insertion above it would have left it describing whatever slid into those lines
— with nothing dangling, nothing failing to compile, and nothing for a reader
to notice.

This one fires **zero** times across 1443 files, and that is the argument for
it rather than against. A gate earns its place by whether the fault would be
caught if it came back, not by how much it currently finds; this fault is
invisible by construction, and a convention met once a year is one no reviewer
can be asked to hold. Because the rule is silent on the existing tree it adds
no triage burden — the opposite of the two rules declined nearby, at 353 and
519 violations of judgement. Naming the target is always possible, which is
what keeps the rule fair: every line range sits inside a class, a member or a
headed list that has a name, and the named form survives the edit that breaks
the numbered one.

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

## License

BSD 3-Clause licensed. Each package carries the same
[`LICENSE`](tom_core_kernel/LICENSE); see any package folder for the full text.
