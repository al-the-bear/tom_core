# CodeSpecs Mapping

**Quest:** tom_specs · **Status:** grounding doc

## 1. Purpose

CodeSpecs is **Phase 4** of TomSpecs: it turns the Phase 3 specification
documents (the DocSpecs, typed by the **SOM** — the `tom_specs_model` object
model) into a **skeletal, compilable Dart application** whose every element
carries traceability annotations back to its source spec.

**CodeSpecs is code only.** It is the `Cs*` annotation family (in
`tom_code_specs`) applied to `tom_core`-family classes, plus the generated
skeletal Dart — there is **no separate "CodeSpecs document" model**. The link
between a DocSpecs section and its CodeSpec code is carried by annotations and
section metadata, not by a parallel document type — see §9.

This document is the **grounding reference** for the CodeSpecs derivation. It:

1. states what CodeSpecs means,
2. canonicalises the target element taxonomy (26 active parts, §4),
3. defines the three-project output structure (§4.2),
4. compares the taxonomy against existing coverage and flags gaps (§5–§6),
5. records the server-contract and configuration/settings decisions (§7, §11),
6. maps **SOM → CodeSpecs** — per part, which documents its sections live in,
   where the walk enters and where the walk itself is stated (§8, §8.5),
7. defines the **bidirectional DocSpecs ↔ CodeSpecs link** (§9), and
8. records the `code_spec` architecture principles (§12).

### 1.1 General approach (five pillars)

Five pillars frame the CodeSpecs implementation.

**(a) `tom_code_specs` holds the CodeSpecs *annotations* — nothing else.**
`tom_code_specs` (in the `tom_ai/ai_build` repo) owns the `Cs*` annotation family
and the §9 link annotations (`@CodeSpec`, `@DocSpec`/`DocRef`), plus any helper
code/tools. It
carries **no base classes** — CodeSpecs has no `Cs*`/abstract scaffolding. All
annotations use the **`Cs*` prefix**. The general
type-level link annotation `@CodeSpecKind` and its `CodeSpecPart` enum live one
layer lower, in `tom_specs_core` (§9.5), because they annotate SOM *model*
classes. The framework is owned by the **`tom_specs` quest** (§12).

**(b) Every class a CodeSpec builds on is a `tom_core`-family class.** The
concrete types a CodeSpec is built from (data models, endpoints, repositories,
widgets, forms, …) come from the `tom_core` family under `tom_ai/core/` — **five**
packages: `tom_core_kernel` / `tom_core_flutter` / `tom_core_server` /
`tom_core_d4rt` **and `tom_flutter_ui`**. `tom_flutter_ui` is the
code basis for the entire client-side UI substrate — forms
(CE-FM), actions (CE-AC), the ScreenElementsProvider / input-element / widget
family (CE-EL), layout (CE-LO), text/i18n (CE-TX), validation (CE-VA), navigation
(CE-NV), view-state (CE-ST) — via `TomForm` / `TomField` / `TomAction` /
`Validators` / `TomPageRoute` / the `Acl*` layout family / `TomText` /
`TomObservable`. **Reuse an existing `tom_core` class directly wherever possible.**
Only the concrete structures `tom_core` genuinely lacks go into the new
**`tom_core_codespecs`** project — and those are **concrete classes, not abstract
`Cs*` bases**. `tom_core` stays clean of CodeSpecs-only concerns.

Two consequences of the survey that grounded this pillar are worth stating once:
`tom_core_flutter` carries only observing / resources / runtime / security — the
real form, field, action, validation, layout and navigation classes live in
`tom_flutter_ui`, which depends **directly** on `tom_core_kernel` and not through
`tom_core_flutter`. And **`tom_core_d4rt` contributes no substrate at all**: it is
a bridge aggregator re-exposing the other packages to the interpreter, so no part
maps to it and later waves need not re-survey it.

**Where a gap class lands** follows from *who else could use it*: a structure
`tom_core` is simply missing and that is **generally useful** goes into the
relevant `tom_core_*` package (the §7 `Result`/`ErrorResult` envelope is the
worked example — it belongs in `tom_core_kernel`, not in CodeSpecs). A structure
that is a **CodeSpecs-only framing** of already-present behaviour goes into
`tom_core_codespecs`. Domain enums need no gap structure at all — a plain Dart
`enum` marked `@CsEnum`, authored as a member of its owning part.

**(c) DocSpecs stays technology-neutral; the mapping names CodeSpecs part
*types*.** Each SOM section type carries `@CodeSpecKind` (the general type-level
link of §9.1) naming the **kind(s)** of CodeSpecs part it must become — never a
concrete class or member. DocSpecs keeps abstract, technology-neutral vocabulary
(Field, Form, Validation rule, Server interaction, Client, User setting, …). The
CodeSpecs-specific detail is a **deeper level within** each mapped section. A
section may name **several** kinds (§9.1).

**(d) Wave-based execution model.** The *quest's own* work — building the
annotation framework, the mapping and the derivation contract — runs in waves;
every wave that emits further todos ends with a "restructure new todos" closer
that produces the next wave's execution list. The execution list is the open todo
series of the TomSpecs quest, indexed in §10. This is the model for *building*
CodeSpecs, not for *running* Phase 4 against a project — that is pillar (e), and
the two have separate id families precisely so a reader never has to work out
which tree a todo belongs to.

**(e) CodeSpecs code is produced by a generator *and* an author, and the boundary
between them is fixed.** Phase 4 is neither a compiler pass nor free authoring.
A **generator** collects, per CodeSpecs area, everything in the specification
document that maps to that area into a bounded, cited **extract**; a
**prompt/agent** pass then writes the CodeSpecs code from that extract, guided by
this document and by `codespecs_derivation_contract.md`. The generator makes no
judgment; the agent makes every judgment natural-language input requires, and
makes it against an input that is bounded and whose provenance is recorded. The
split exists because the two halves fail differently: a mechanical rule applied
to prose invents structure that is not there, and an author given a
652-section document reads the wrong parts of it. §1.1.1 states the boundary as a
rule, and fixes the three things every downstream step needs from it — what the
extract is, where the extractor lives, and what ids the generated todo tree
occupies.

#### 1.1.1 The Phase-4 production contract

**The boundary, as a rule rather than a preference.** The generator may **copy
and index**. It may not summarise, rephrase, compose a sentence out of field
values, or choose a name. Those are not new prohibitions invented here: they are
exactly `codespecs_derivation_contract.md` §2.8 **C1**'s — *"No summarising, no
rephrasing, no sentence assembled from field values, no model"* — and they bind
the extract generator word for word, because an extract is the same kind of
artifact a comment is: text that reads as specification and must therefore *be*
specification. C1 is the single statement; this pillar only names the second
party it binds. The consequence is checkable rather than trusted: every scalar in
every extract must occur character-for-character in the source document, which is
a test, not a review.

The agent's side of the line is the complement, and is equally bounded — it may
exercise judgment only where the derivation contract leaves a judgment open, and
`codespecs_derivation_contract.md` is normative for it. Where the specification
does not carry what a derivation needs, the outcome is neither an invention nor a
silent omission: it is a `decision-needed` todo that pauses the queue (item 3's
id scheme below, and §1.1.3's tree design that uses it).

**1 — The extract artifact.** Per area, **two files**: a YAML file that is the
artifact of record, and a Markdown file rendered *from* that YAML for the agent
to read.

| | |
|---|---|
| **Location** | `<spec-root>/generated-doc/codespecs_extracts/` — the `generated-doc/<type>/` convention, rooted at the folder that holds the specification document. For TomSpecs' own worked example that root is `tom_ai/ai_build/tom_specs_model/`; for a specified project it is that project's. |
| **Names** | `<CE-CODE>.extract.yaml` and `<CE-CODE>.extract.md`, where `<CE-CODE>` is the §4.1 registry key verbatim — `CE-FM.extract.yaml`, `CE-API.extract.md`. The registry key is used because §4.1 fixes it as permanent: never reused, never renamed. |
| **Entry** | Extract token (the routed field's `@SectionId`, or its own name where it carries none — `codespecs_derivation_contract.md` §2.5 rule 2) · the enclosing section instance's headline, copy-only (the stored headline, else the `@Headline` type default, else null) — the `codespecs_derivation_contract.md` §2.1 N1 headline source · the enclosing instance's stored id (`instanceId`), copy-only (see below) · class name · field name · form field where applicable · the verbatim value · the `@CodeSpecKind` value that routed it here · source location. |
| **Authority** | The YAML is the artifact of record; the Markdown is a *view* and is regenerated from it. Nothing reads the Markdown as input. |
| **Gate record** | `gate.verdicts.yaml`, beside the extracts — the Stage-B verdicts persisted per area (`codespecs_prompt.md` §6.3). It is the scope of the pass: the §6-of-`codespecs_derivation_contract.md` transfer checks hold the trio to the `sufficient` areas only, so a recorded partial pass (a descoped *insufficient* area, a *not applicable* area) neither fails coverage nor forces coarse citations. Absent the record, the whole extract tree is the obligation set. |

The YAML carries the authority because the whole value of an extract is that its
provenance is machine-checkable — the (id, verbatim value) pair is the second
side `codespecs_derivation_contract.md` §2.8 C4.2 needs to assert that an emitted
comment line equals its source line. A Markdown-only extract is a second copy of
the document with the provenance thrown away. The Markdown exists because the
agent reads it far better than it reads YAML, and a rendered view cannot drift
from a generated source.

**`instanceId` — what it is and is not.** Each entry carries the nearest
enclosing list-item instance's **stored** section id — the `<!--[…]-->` id the
document serializes (`som_multiplatform_spec_model.md` §11.2), resolved once per
class node walking outward (the node's own stored item id, else the enclosing
instance's; a scalar list item prefers its own stored id, being itself an
instance of its list). Only a *stored* id qualifies: the render-time positional
default (`CARD-2`) is derived, and carrying a derivation is what
`codespecs_derivation_contract.md` §2.8 C1 forbids — so an id-less instance
yields null, never a synthesized position. The field is **auxiliary trace data
only**: it lets the agent and the §6 checks tell two instances of the same list
apart without parsing paths. It is **not** the back-link vocabulary — a
`DocRef.sectionId` still names the **extract token** of
`codespecs_derivation_contract.md` §2.5 rule 2 (§9.3), and no migration of that
vocabulary onto instance ids is intended: the token is total (every entry has
one) where the instance id is partial (only stored ids qualify), and a partial
key cannot carry the §8 set-difference.

Routing is by `@CodeSpecKind`, which is **list-valued** (§9.1): a section feeding
three areas appears, whole, in three extracts. Extracts are **not** deduplicated
across areas — each area's prompt must be self-sufficient, and a cross-reference
the reader has to follow is exactly the context-budget cost the extracts exist to
remove.

**2 — Where the extractor lives.** In the **language-specific SOM runtimes**, as
a `spec_codespecs_extract` surface present in **all nine** — not in
`tom_specs_clitool`. The extractor reads a filled specification document plus the
`@CodeSpecKind` routing the meta already carries (§8.4), which is exactly the
input every SOM runtime already resolves; making it a Dart-only tool would make
Phase 4 a Dart-only phase, and the nine-language SOM exists so that a project
specified in TomSpecs is not thereby a Dart project. It is therefore a
nine-language surface under the ordinary discipline: a conformance corpus table
that every runner loads, and the parity gate that proves all nine read it
(`tom_som_conformance/tool/parity_gate.sh`). A vocabulary implemented nine ways
and asked about by no corpus case is a vocabulary that can be wrong in agreement
— the standing lesson this quest has paid for three times.

A Phase-4 run extracts from **one** specification document, so the extractor
walks **one** `@Document` root, resolved when it is constructed and not
re-decided per call — which is what keeps its routing diagnostic and its extracts
talking about the same walk. All nine expose the same optional root argument
(type name or section id), defaulting to the document's single populated root;
the two ways an operator would otherwise get this wrong — unioning all fourteen
roots, or naming `D13CodeSpecsProjection` and receiving 26 silently empty
extracts — are closed by the API rather than by instruction
(`codespecs_prompt.md` §5).

**3 — The generated todo tree's id ranges.** The workspace queue iterates by id
prefix, so the ranges are predetermined for the whole Phase-4 run rather than
allocated as it goes. **Digits appear only at the end of an id**, and they are
the iteration index — a prefix is therefore always a pure letter string, and
`<prefix>*` always names a whole level or a whole area.

| Level | Ids | One todo per | Prefix run |
|-------|-----|--------------|------------|
| **L0** — open questions | `csopen<n>` | unresolved specification ambiguity the quality gate surfaced; all `decision-needed` | `csopen*` |
| **L1** — scaffolding | `csproj<n>` | the §4.2 project trio, its pubspecs and per-area folders | `csproj*` |
| **L2** — per authoring step | `csgen<n>` | authoring step — one emission unit, or a whole strongly connected component, or a co-emitted pair — `<n>` its ordinal in §4.4.6's thirty-one-step order. A step spanning more than one part reads one extract per part | `csgen*` |
| **L3** — per specification element | `cs<area><n>` | extract entry — a (section, area) pair — `<area>` the §4.1 CE code lower-cased, `<n>` allocated per §4.4.8 | `csfm*`, `csapi*`, … |

`csgen*` runs the whole phase in authoring order; `csgen` followed by a step's
ordinal and `*`, being a pure prefix, runs that step alone; `csfm*` runs every CE-FM section todo, in the order §4.4.8
fixes. A step is the unit rather than an area because an area is not always a
thing that can be authored in one act — six of them are one strongly connected
component (§4.4.7) and nine are split by locus across steps. The CE codes are
mutually non-prefixing and none of them is `open`, `proj` or `gen`, so every
prefix in the table names exactly one level or one area. (`CE-API` is the one
three-letter code; the scheme needs only *letters then digits*, so it absorbs it
without a special case.) The date-code suffix still comes from
`tomAi_generateIdPrefix` per the workspace rule — the id shape here is the part
before it. Where two TomSpecs projects are worked in the same fleet-shared `_ai`
layer at once, the whole family takes the project id as a further leading
segment; the shape is unchanged and the digits still trail.

L0 running first and to exhaustion is the mechanism by which an underspecified
project stops the run instead of being guessed through: `CLAUDE.md` rules that
`<prefix>*` iteration **refuses** a `decision-needed` todo and pauses the queue.
That is why the quality gate is the starting prompt's first act rather than a
review afterwards.

#### 1.1.2 The Phase-4 run procedure

§1.1.1 fixes the **contract** — what an extract is, where the extractor lives,
and what ids the generated todo tree occupies. A contract is not a procedure,
and this subsection is the procedure: the order in which one run performs those
things against one specified project. Nothing here restates §1.1.1. The extract
names and location, and the four id ranges, are **cited** from it, because a
second copy of them in the same document is a second thing to keep current and
the first to go stale.

**Six stages, each one's output the next one's input.**

| # | Stage | Produces | Ordered by |
|---|-------|----------|------------|
| **0** | **Open questions** — read the specification against the derivation contract's required inputs and record every place it does not carry what a derivation needs. The reading is per area, over a pre-gate extraction run (§1.1.3) | one L0 todo per unresolved ambiguity, all `decision-needed` | — |
| **1** | **Extract** — run the `spec_codespecs_extract` surface of whichever SOM runtime the project uses, over the filled Phase-3 document set | one extract pair per **active** part (§4.1's 26), at the location §1.1.1 item 1 fixes | §4.1 |
| **2** | **Scaffold** — create the §4.2 project trio, its pubspecs and its per-area folders | one L1 todo per scaffolding unit | §4.2 |
| **3** | **Author, per step** — walk the thirty-one authoring steps | one L2 todo per step; the step's generated files | §4.4.6 |
| **4** | **Author, per element** — *inside* a step, walk that step's extract entries | one L3 todo per (section, area) pair | §4.4.8 |
| **5** | **Validate** — run `validate_codespecs.dart` over the trio, and a second time over a regenerated trio | a pass/fail verdict on the [`codespecs_derivation_contract.md`](codespecs_derivation_contract.md) §6 checks | §6 |

The id ranges the four todo levels occupy — `csopen<n>`, `csproj<n>`,
`csgen<n>`, `cs<area><n>` — and the prefix-iteration properties that make them
runnable are §1.1.1 item 3's.

**Stage 0 is carried by one text**, and it is not the authoring prompt:
[`codespecs_prompt.md`](../../../ai_build/tom_specs_model/doc/codespecs_prompt.md) holds the **starting prompt**, whose
first act is the quality gate that decides whether the run may begin — a
mechanical tier, then a per-area verdict of `sufficient` / `not applicable` /
`insufficient` whose failure output names the section that should have carried
each missing input. It creates the L0 todos of this stage and the L1/L2 rungs
stages 2 and 3 will consume, and it writes no code. The two Phase-4 prompts
partition the phase cleanly: the starting prompt produces todos and no code,
[`codespecs_derivation_contract.md`](codespecs_derivation_contract.md) §2.9's
authoring prompt produces code and no todos.

**Stages 3 and 4 are nested, not consecutive.** Stage 3 is the walk over steps
and stage 4 is what one step consists of; a run does not finish every step and
then start on elements. This is why the L2 todo is the unit a prompt pass
occupies and the L3 todo is the unit of work inside it.

**What a step is given.** One extract per **area the step covers** — usually
one, two where §4.4.6 records a step as spanning parts (step 18 authors CE-SU
co-emitting the CE-API handler half, so it reads both extracts), six for
SCC-B. A step never reads a document, and never reads an extract belonging to an
area it does not cover: that bound is the whole reason the extracts are not
deduplicated across areas (§1.1.1 item 1). The prompt that carries a step is
[`codespecs_derivation_contract.md`](codespecs_derivation_contract.md) §2.9,
instantiated from the step's row in §4.4.6 — the procedure is grounding and
lives here, the text that produces code is derivation and lives there.

**A component step is one todo, run in two passes.** Where §4.4.6's step is an
SCC — step 2 and step 23 — §4.4.7's declare-then-wire pass pair happens **inside**
the single L2 todo, never as two. The component does not compile between the
passes, so a run that stopped there would stop in a state no gate can accept.

**What stops the run.** Stage 0 runs first and to exhaustion because
`CLAUDE.md`'s queue semantics make a `decision-needed` todo **refuse** to run
and pause the queue. The same mechanism applies mid-run: a generation error
discovered in stage 3 or 4
([`codespecs_derivation_contract.md`](codespecs_derivation_contract.md) §2.0)
files a new L0 todo and the declaration is **not written**. An underspecified
project therefore halts Phase 4 at the point of the gap, rather than being
guessed through and discovered in Phase 6.

**What the run is finished against.** Stage 5's validator decides admissibility
of what was written; **§9.6's self-sufficiency rule** decides whether it carries
what it was written from. The two are independent — a trio can pass every §6
check while having silently dropped half of a description — and the project-flow
gate G4 (`tom_specs_project_flow.md` §PF-GAT-G4) is where both are reviewed
together with the judgement neither can make.

**Re-running.** A specification change is answered by re-running the affected
stages, not by editing the trio: [`codespecs_derivation_contract.md`](codespecs_derivation_contract.md)
§2.1, §2.8 — N8's derived names and C5's verbatim comments — make regeneration
byte-identical over an unchanged document,
so a diff in a regenerated trio is exactly the specification's diff. Hand-editing
generated code destroys that property silently, which is why §6 check 31 compares
two runs rather than trusting one.

#### 1.1.3 The generated todo tree

§1.1.1 item 3 fixes the four levels' **ids**; §1.1.2 fixes the **order** the
stages run in. Neither says what a rung *contains* — what generates it, what that
generator must establish before generating, and when a generated todo is emitted
`decision-needed` rather than `not-started`. This subsection is that, and only
that: the ids are cited from §1.1.1 unchanged and the stage order from §1.1.2.

**Why the rung has to be designed rather than left to the generating agent.** The
queue is the safety mechanism, not a convenience: `CLAUDE.md` rules that a
`decision-needed` todo **refuses** to run and pauses the queue. That mechanism is
only as good as the rule that decides which todos carry it. If each generating
pass decided by taste, an underspecified project would halt or not depending on
who ran it — the one property Phase 4 cannot have, since the whole point of the
two-role split (§1.1) is that the run is reproducible.

**What generates what, and when.**

| Rung | Generated by | At | Determined by |
|------|--------------|----|---------------|
| **L0** `csopen<n>` | the starting prompt's first act; thereafter any generation error | stage 0, and mid-run | the document, read per area against `codespecs_derivation_contract.md` §3's required inputs |
| **L1** `csproj<n>` | the starting prompt | stage 0, with L2 | §4.2 alone |
| **L2** `csgen<n>` | the starting prompt | stage 0, with L1 | §4.4.6's step table alone |
| **L3** `cs<area><n>` | its own L2 todo, as that todo's first act | inside stage 3 | the step's extracts + §4.4.8 |

Three of the four rungs exist before the first line of code is authored. **L1 and
L2 are document-independent** — the trio is the same three projects for every
project, and the thirty-one steps are this document's, not the specification's —
so they are instantiated once, complete, from the tables that fix them. **L3 is
the exception, and the reason is stage order**: an L3 rung is derived from the
extracts an authoring step reads, those are stage 1's, and stage 1 runs *after*
L0 is exhausted because an answered open question changes the document and
therefore changes the extract. Pre-generating L3 would mean generating it from a
document already known to be wrong.

**L0 — one todo per unresolved input.** Its generation is a comparison, not a
reading: for every section `@CodeSpecKind` routes, and for every area it routes
to, the part's `codespecs_derivation_contract.md` §3 entry names the inputs its
derivation requires; each one the section does not carry is one todo. Two
sections missing the same field are two todos, because they are answered
separately. Ordinals follow §4.4.8's order — SOM document order
(`codespecs_derivation_contract.md` §2.1 N8), tie-broken by §4.1 catalogue
position — reused rather than re-invented so that
the same document always yields the same numbering. Every L0 is
`decision-needed` by construction: a resolved question is not one.

**The comparison is made per area, against that area's extract**, not against the
document at large — the gate's verdict has to be reportable per area, and a
missing input is only missing *for the derivation that needed it*. That means an
extraction run precedes the gate, and it **does not reorder §1.1.2's stages**.
Stage 1 is the extraction whose output the *authoring* reads; it is re-run once
L0 closes, because an answered question changes the document. The pre-gate run is
the same deterministic program over an earlier document, so running it twice
costs a run rather than a decision — and the second run is L2 precondition 1
(below) satisfied in advance rather than discovered as a failure.

L0 is exhausted before L1 begins. A layout chosen around an unanswered question
is a layout that gets redone, and — more sharply — an extract taken from a
document that is about to change is an extract every L3 under it is derived from
wrongly.

**L0 after stage 0.** The rung does not close permanently. A generation error
found while authoring (`codespecs_derivation_contract.md` §2.0, §2.9's STOP)
files a new `csopen<n>` and leaves the entry's L3 todo open against it. This does
**not** halt the step — `codespecs_derivation_contract.md` §2.9 has the agent
continue with the next entry — because
by then the question is bounded to one element, and stopping a whole step for it
would discard work that is already correct. The run ends with those L0s open and
their L3s open, which is precisely how an incomplete run is visible without
anyone having to notice it.

**L1 — one todo, because the trio is not separable.** The scaffolding unit
§1.1.2 stage 2 names is the trio, not the project: `<app>_codespec_client` and
`<app>_codespec_server` both carry a path dependency on `<app>_codespec_shared`
(§4.2), so a run that created one project and stopped leaves a tree that does not
resolve — a state no later rung can start from. The single todo creates all three
projects, their pubspecs and dependency edges, and the per-area folders, each
area under the locus §4.2's table gives it. Nothing in it is chosen: given §4.2
and the application name, the whole of L1 is determined.

**L2 — one todo per authoring step, all thirty-one, up front.** `<n>` is the
step's §4.4.6 ordinal, so `csgen*` runs the phase in authoring order and
`csgen` plus one step's ordinal and `*` runs that step alone. The rung is complete even where a step will turn out
to have nothing to do: a step whose parts are unrouted in this project completes
having generated an empty L3 rung, and *that is the point* — "the step had
nothing" is then a recorded outcome rather than an absence, and the coverage
question §9.6 asks later has an answer for every step.

An L2 todo's work is two acts in one pass: **generate its L3 rung**, then author
the step by running `codespecs_derivation_contract.md` §2.9's prompt over it. It
is one todo and not two because §1.1.2's stages 3 and 4 are nested — the prompt
pass *is* the step.

**What an L2 todo establishes before generating.** Three preconditions, checked
in this order; each is decidable, and none of them is a question for the user:

1. **The extracts exist and are fresh.** Every extract the step's §4.4.6 row
   names is present at §1.1.1 item 1's location, and was produced from the
   current document set. A stale extract yields an L3 rung that does not match
   the code the step is about to write — the two would then disagree with nothing
   comparing them.
2. **The step's slice is READY** in all four of §4.4.4's blocking modes (**E**,
   **E(lossy)**, **R**, **V**). Every slice is clear against current `tom_core`
   (§10), so this is not a formality only in the case that matters: a project
   pinning an older `tom_core` can fail it.
3. **Every part the step cites is already authored.** Each §4.4.1 edge out of
   this step's parts points into a part whose step is earlier and whose L2 todo
   is `completed`. This is §4.4.3's no-forward-reference rule checked *before*
   the prompt runs rather than found in its output.

A failed precondition is **not** a `decision-needed` todo. `decision-needed`
means *only the user can resolve this*; a missing extract, an old dependency and
an unrun earlier step are all resolved by acting, so the L2 todo simply does not
start and the run addresses the cause. Conflating the two would put mechanical
faults into the queue-pausing channel and make a paused queue stop meaning
"the specification is incomplete".

**L3 — one todo per extract entry, and when it is born blocked.** The unit and
its numbering are §4.4.8's: an entry is a (section, area) pair, entries run in
SOM document order across all the step's parts together, and ordinals are
allocated contiguously per step in step order. What §4.4.8 does not say is which
of them the generating L2 todo must emit `decision-needed`. **These four, and
nothing else:**

| # | The entry… | Because |
|---|-----------|---------|
| **D1** | does not carry a value for a field a **required** argument of its part's marker derives from — absent, or empty after trimming | The agent's only alternatives are to invent the value or to omit a required argument; `codespecs_derivation_contract.md` §2.8 C1 forbids the first and the marker forbids the second |
| **D2** | carries the value, but it is a **reference** — a §5.23 `Cs*Ref`, a closed-catalogue selection — that resolves against no id or member in the extract's referenced set | A near-match is still non-resolving. Picking the near one is exactly the inference `codespecs_derivation_contract.md` B8 forbids, and it is undetectable afterwards because the result compiles |
| **D3** | does not decide a **contract branch** the derivation takes from the input — most often form 3a vs form 3b (`codespecs_derivation_contract.md` §2.4) | `codespecs_derivation_contract.md` §2.4 decides the body shape *from the input*; where the input does not decide it, the agent would be deciding what the specification says |
| **D4** | carries two facts that **cannot both hold** — one id given two shapes, a field required and given no kind | A contradiction has no admissible resolution; choosing a side silently ratifies half a specification |

Everything else is emitted `not-started`. In particular, **thin prose is not a
criterion**: a one-line description is copied as it stands
(`codespecs_derivation_contract.md` §2.8 C1), and only
*absence* — never brevity, vagueness or a description an author might have
written better — makes an entry unauthorable. D1–D4 are decidable from the entry
plus the extract's referenced sets, which is exactly what the generating todo
holds, so the same document yields the same blocked set every time.

**Where a question lives depends on when it was found.** One question, one home —
otherwise the same gap is counted twice and the queue reports work that does not
exist.

| Found | Home | The L3 |
|-------|------|--------|
| At stage 0, before any L3 exists | `csopen<n>`, `decision-needed` | does not exist yet; when it is generated later it is `not-started`, the question having been answered |
| At L3 generation (D1–D4) | the L3 itself, `decision-needed`, carrying the question in its `decisions:` block | *is* the question's home — no `csopen<n>` is filed |
| During authoring, the L3 already `not-started` | `csopen<n>`, `decision-needed` (`codespecs_derivation_contract.md` §2.9's STOP) | is left open against it, and the step continues |

**A strongly connected component's L3 rung is generated once, over the whole
component.** §4.4.7 already fixes the pass pair as **one** `csgen<n>` todo; what
follows for L3 is that the passes are **not a level**. The rung is generated over
the union of the component's extracts in §4.4.8's single order, and an entry is
one L3 todo whether its declaration is written in pass 1 or its intra-component
slot filled in pass 2. An L3 of a component step is therefore completed only
after pass 2 — an entry whose slots are still empty is not done. Two rungs, one
per pass, would make it possible to run pass 1's rung to completion and stop, in
the state §4.4.7 says no gate can accept.

**A section routed to several areas is written once and cited from the others.**
It appears in several extracts by design (§1.1.1 item 1) and yields several L3
todos (§4.4.8), but those are different pieces of work, not copies: each emits
**its own area's** part. Exactly one of them emits the **declaration**, and which
one is derived rather than chosen — it is the entry whose step is **earliest** in
§4.4.6, necessarily, because §4.4.3's no-forward-reference rule means a later
step can only cite an earlier one. The others emit their area's part typed by a
§5.23 `Cs*Ref` to that declaration. A non-owning todo that would emit an
identical declaration must not: two declarations of one specification fact
violate §4.4.3's partition invariant, and they are the one kind of drift §9.6's
comparison 2 cannot detect, since both copies are faithful to the same source.
(Where an *area* rather than a section spans steps, §4.4.8's split rule already
applies and each emitting unit has its own L3.)

**What a completed L3 reports.** The report is what makes the run auditable, so
it is fixed here rather than left to the reporting agent. Four items:

1. **What was emitted** — each declaration by fully-qualified name and file,
   under its locus project; or, for a non-owning entry, the single reference
   emitted and the declaration it points at.
2. **The extract token it was derived from**, verbatim from the entry, so the
   report and the emitted `@CodeSpec.source` can be compared without reading the
   code.
3. **The `Cs*` markers applied**, and for each whether every required argument
   was filled from the entry.
4. **Any intra-component slot left for pass 2** — empty for an ordinary step, the
   pass-2 worklist for a component one.

An L3 that could **not** complete reports the `csopen<n>` it stands open against
and nothing else. A partial report of a stopped entry reads like progress, which
is the one thing an audit trail must never do.

The union of a step's L3 reports is exactly `codespecs_derivation_contract.md`
§2.9's HAND BACK block, and the union
over the run is §9.6's comparison 1 at element granularity — computed *from the
run* as it happens, rather than reconstructed from the finished trio afterwards.

### 1.2 Neutral vocabulary and the attribute-surface convention

Pillar (c) is only enforceable if the neutral vocabulary is a **closed set**. The
per-part attribute surfaces in §5 draw their author-facing terms from this
glossary, and nothing else:

> **Data entity · Data attribute · File reference · Storage group · File store ·
> Content kind · Identity attribute · Scope rule ·
> Query/Filter · Sort · Domain enum · Enum value · Operation · Operation name ·
> Request shape · Response shape · Service unit · Authorization requirement ·
> Error result · Error code · Field-level error · Field · Field kind · Form ·
> Subform · Layout node · Copy/Text · Message key · Validation rule (Field rule /
> Form rule) · Action · Trigger · Server interaction · View state · Navigation
> target · Configuration setting · Traceability link · Report · Report section ·
> Report column · Report dimension · Report measure · Report parameter · Chart ·
> Delivery channel · Report schedule · Report recipient.**

The last ten are CE-RP's (§5.28). **Report column** is deliberately the
output-side peer of **Field**, not a use of it: a field is an input a user
edits, a report column an output projection carrying an aggregate and a format.

**File reference** and its three supporting terms are CE-DB's (§5.13). A **file
reference** is a data attribute whose value is the *address* of a stored file
rather than the file's content — the one attribute kind that is not fully
described by its value type. It is a peer of **Data attribute**, not a use of
it, because the three things it must additionally declare have no counterpart on
an ordinary attribute: a **storage group** (the naming group files are filed
under, which sets their retention and access partition), a **file store** (the
named store holding them, defaulting to the deployment's), and the **content
kinds** it accepts. All four are storage-*neutral* by construction — "blob",
"bucket", "S3" and every other storage-technology name stay out of DocSpecs and
live only in the deployment configuration that selects a store backend.

Every term maps onto a `tom_specs_model` section (§8). Adding a term is a
deliberate act: a new neutral term means a new author-facing concept, so it must
be justified against the existing set before it is introduced — most candidates
turn out to be a *deeper level within* an existing term rather than a peer of it.

**How a part's attribute surface is stated.** Each part in §5 lists the
**complete set of attributes a DocSpecs specification must carry** so the
corresponding CodeSpecs code can be generated with *nothing left to guess at
generation time*, in four columns:

| Column | Meaning |
|--------|---------|
| **Attribute** | The spec-authorable attribute, named neutrally. |
| **`tom_core` source** | The concrete constructor parameter / field / annotation member it maps to, with the class it comes from. |
| **Req?** | **Y** = a spec MUST supply it · **N** = optional · **D** = derived (computed during derivation, never authored). |
| **Neutral DocSpecs term** | The glossary term above that the DocSpecs author works in. Never a Dart type. |

**Spec-authorable vs framework-internal.** The `tom_core` classes carry many
members that are *runtime wiring*, not specification input — `focusNode`,
`uiStateController`, `authorizer`, `clientFactory`, middleware handlers,
reflection handles (`InstanceMirror`/`MethodMirror`), `Completer`/abort triggers,
listenables. These are **excluded by rule**: the framework supplies them, a spec
never authors them. Across every part the spec-authorable surface is a small
fraction of the class's members — which is what makes pillar (c) hold: DocSpecs
stays neutral *and* thin.

**Cross-cutting consequences of the vocabulary.** Three follow from the glossary
being closed, and they constrain the whole design:

1. **Copy is shared, not duplicated.** Field and action labels, domain-enum value
   labels, error messages and free copy all resolve through the *same*
   message-key mechanism. **Message key** is the single join; a spec authors copy
   once and references it (§5.21).
2. **Error codes are the CE-VA ↔ CE-ER ↔ CE-TX spine.** A validation failure, an
   application error and its user-facing copy share **one** error-code
   vocabulary, sourced from a single registry: an entry authored once, emitted by
   CE-VA, copied by CE-TX, carried by CE-ER (§5.19, §5.21, §7).
3. **Authorization is an attribute, not a leaf.** Every authorization requirement
   is a small attribute set attached to an operation, a screen element or a data
   column — never a standalone element (§5.15).

## 2. Sources analyzed

| Source | What it contributes |
|--------|--------------------|
| `tom_specs_project_flow.md` §PF-PHA-P4 | The Phase 4 CodeSpec **components**, the traceability requirement, the fixed Tom Architecture (Flutter/CLI client → server interface → Dart server → SQL), the Phase 3→CodeSpec requirement-mapping table, and the Phase 4 exit criterion (compiles but does not execute). |
| **`code_spec` architecture principles** (§12) | The multi-project separation (shared spec / client impl / server impl), the three-layer UI split (semantic / widget-behaviour / layout), analyzer-driven validation beyond the compiler, `//$` production stripping, test-generation-from-specs, and the auth-server/stateless-API/SQL target architecture. |
| `tom_ai/ai_build/tom_specs_model/` | The **SOM**: 12 Phase 3 document roots `D01…D12` under the `D00SolutionBlueprint` master, plus the `D13CodeSpecsProjection` generation projection. The derivation *inputs*. |
| `tom_core_kernel` / `_server` / `_flutter` / `_d4rt` / `tom_flutter_ui` | Direct source survey of the five core-family packages — the exact constructor/field/annotation signatures behind every §5 attribute-surface row. |

**This document is the CodeSpecs *grounding* document.** The per-part code
basis, attribute surfaces, section→part coverage, closed-choice inventory,
follow-up split and review decisions are all sections of this file. Remaining
work is tracked as `csra*` quest todos (§10), not in prose.

Exactly one CodeSpecs subject lives elsewhere: **what code comes out**. The
per-`Cs*`-annotation derivation contract — the exact Dart Phase 4 emits,
the deterministic naming rules, each annotation's argument shape and the
validator checks — is
[codespecs_derivation_contract.md](codespecs_derivation_contract.md), which is
the authority for all of it. This document says *which SOM section feeds which
part*; that one says *what is written*.

## 3. CodeSpecs in one paragraph

A CodeSpec is annotated Dart built on `tom_core`. A screen element, form, layout,
action, server call, endpoint, service unit, table, repository, view-model, route,
enum, error result, configuration, client, or user setting is declared as a class
that **extends or instantiates the appropriate existing `tom_core`-family class**
(e.g. `TomForm`, `TomField`, `TomServerEndpoint`, the Tom persistence model,
`TomObservable`) and is decorated with **`Cs*` annotations** (`@CsForm`,
`@CsTable`, `@CsColumn`, `@CsEndpoint`, `@CsWidget`, …) plus a `@CodeSpec(id,
source, requirements)` traceability link. Where `tom_core` has no suitable class,
a **concrete** class from `tom_core_codespecs` fills the gap. Method bodies are
one of the two shapes `codespecs_derivation_contract.md` §2.4 defines — a bare
`throw UnsupportedError('<explication>')`, or a statement sequence over an
abstract collaborator. A validator enforces required annotations and
cross-references (FKs resolve, widget refs exist, routes unique) beyond what the
compiler alone checks. Before production, a cleanup tool comments spec-only code
with `//$`.

**CodeSpecs is not required to be purely declarative.** A CodeSpec may carry a
**first level of implementation** — real Dart method bodies expressing the intended
behaviour as *compilable pseudo-code* — even though the skeleton as a whole does not
yet run. Such a body calls an **abstract collaborator** (an injected
service laid out as an abstract class whose methods carry detailed doc-comments
stating what each is to do); the collaborator is implemented in Phase 6. This lets a
part be specified as annotated + partially-implemented code rather than annotations
alone — a login or interaction flow emitted as its steps in order, a repository
query composed over `TomQueryBuilder`, and any action whose logic is clearer as
code than as a declaration all use this latitude.

`codespecs_derivation_contract.md` §2.4 is where that latitude is made
deterministic. It splits the coding form §4.1.1 calls "compilable pseudo-code"
into **3a**, whose entire body is `throw UnsupportedError('<explication>')`, and
**3b**, the pseudo-implementation described here; it fixes 3b's admissible
statements; and it makes the choice between them structural — 3b where the
contributing SOM section carries an ordered step list, 3a where the specification
is prose, so that no sequence is invented out of a sentence. The Phase-4
exit criterion is unchanged either way: no generated body runs to a result
Phase 4 invented — a 3a body throws on entry, and a 3b body holds nothing of
its own, only calls into declarations Phase 6 has yet to implement.

The collaborator itself has a contract entry of its own —
`codespecs_derivation_contract.md` §3.0.1 — because it is **generated, not
assumed**: one abstract class per emitting declaration, its methods derived from
that declaration's step list, injected as the declaration's one `collaborator`
field, and carrying on each method's doc comment the behaviour narrative this
section asks it to state.

**How a step list becomes that sequence** is that document's behaviour-to-body
derivation, `codespecs_derivation_contract.md` §2.4 rules B1–B8: document order
is the statement
order, one contributing step is one call, and a branch the spec states becomes an
`if` over a **guard method** on the same collaborator, so the condition is
reached through the Phase-6 seam rather than parsed out of its prose. The rules
are deliberately narrow, and where the SOM carries no structure for something the
derivation would need, the outcome is a **field on the model**, never a heuristic
in the derivation: where a branch attaches and where control resumes became
`branchPoint` and `returnKind`, and which of a server call's three handling roles
a step feeds became `SVCST.role`. Until such a field exists the part it would
drive is stated as **not emitted**. Nothing is inferred from spec prose.

## 4. Target element taxonomy

The taxonomy has **26 active parts** spanning client, shared contract, server,
and database. The Note column states
how each part is realised: which `tom_core`-family classes it is
built on, whether it is a pure annotation over existing classes, and where
`tom_core` has no class of its own — such a gap is filled by a concrete class in
`tom_core_codespecs`, whose eight source files cover the eight parts that need
one (CE-LO, CE-TX, CE-NV, CE-UP, CE-CL, CE-JB, CE-NT, CE-RP).
Beyond these, **one deferred candidate part** is reserved for *mapping only*
— see §4.3.

| Code | Element | Locus | Note |
|------|---------|-------|------|
| **CE-EL** | Standalone screen elements — what remains after input elements are grouped into forms (static display, action-trigger elements, form-hosting containers); semantic type, then concrete implementation | client | **Pure reuse — no new class.** Built on `TomScreenElementsProvider` + the `Tom*` `tom_flutter_ui` element/widget family; forms already have their semantic classes. The semantic element kinds are the existing `Tom*` widget types — a documented catalogue over reused classes, not a new `tom_core_codespecs` class (§5.7.1, §5.18). |
| **CE-FM** | Form / subform tree **including its member input elements** — forms are part of the screen-element description | client | Reuses `TomForm<T>` / `TomFormChildContainer` / `TomField<T>` (`tom_flutter_ui`) directly; no new classes (§5.7.2). |
| **CE-LO** | Screen layout (Flutter layout) | client | Containers/slots reuse the ACL substrate (`AclRow`/`AclContainer`/`AclComponent` plus `AclFlowContainer` for the `wrap`/`grid` kinds, `tom_flutter_ui`); the override-separable two-layer node model is `TomLayoutModel` over the sealed `TomLayoutNode` (`TomLayoutContainerNode` / `TomLayoutSlotNode`) plus `TomLayoutOverrideDelta`, in `tom_core_codespecs` (`layout_node.dart`) (§5.2, §5.12, §5.22). |
| **CE-TX** | Texts **other than** screen-element texts — server/error copy, notification/email bodies, report copy, and any message not owned by an element. (A screen element's own placeholder/label/help/error copy is **not** catalogued here: it is derived from the element's `basePath` — see below.) | client + shared | i18n keys shared with server error codes. Reuses `TomText`/`TomLabelBase` (`tom_flutter_ui`) + `TomTextResourceProvider` (`tom_core_kernel`); the message/i18n-key catalogue for these *other* texts is `TomMessageKey` + `TomMessageKeyRegistry` in `tom_core_codespecs` (`message_key.dart`) (§5.8, §5.21). |
| **CE-VA** | Validation — per-field + cross-field (form) rules | client + shared | **No new class.** Provided as **Dart code** — standalone validator classes with validation methods, or validation methods on the `TomForm` subclass (the first-level-implementation latitude, §3). Reuses `Validators`/`TomValidatorRegistry`/`ValidationResult`/`FormValidationError` (`tom_flutter_ui`); the field-vs-form distinction is a code convention, not a `tom_core_codespecs` class (§5.9, §5.19). |
| **CE-AC** | Actions and their triggers | client | **Pure reuse — no new class.** Actions have a full implementation in `tom_flutter_ui`: `TomAction`/`TomActionController`/`TomActionTrigger`. The trigger taxonomy is documented over these existing classes (§5.10, §5.20). |
| **CE-SC** | Server call — the client call-site binding of a CE-API operation (cites the operation's typed `CsOperationRef` const, §5.23; N call sites : 1 operation) | client | Pure annotation over the existing kernel transport — `TomServerEndpoint`/`TomServerCallSpecs`/`TomServerChannel` (`tom_core_kernel`); no new classes (§5.3). |
| **CE-API** | Server API — request/response types + operation name + error contract | shared (contract) + server (handler) | Reuses `TomApi`/`TomApiEndpoint` (`tom_core_kernel`) + the `TomEndpoint` pipeline (`tom_core_server`), narrowed by annotation to the §7 contract; no new classes (§5.6.1, §5.14). |
| **CE-SU** | Server-side logical units — clustering the server API into functional groups, each ideally a **closure**: an independently useful service with no dependency on other units | server | **No new class.** Modelled as ordinary **(abstract) classes** carrying the `tom_core_server` server-API mapping annotations (`@tomService`/`TomApiImplementation`); the unit is the class grouping its operations. Boundary = §5.1 (owned-aggregate primary + closure/independence) (§5.6.2, §5.17). |
| **CE-DB** | Database access object model | server | Reuses the `tom_core_server` persistence model (entities, columns, repositories) directly; no new classes (§5.13). |
| **CE-ST** | View-model / UI state | client | Reuses `TomObservable`/`TomObject`/`TomClass`/`TomList`/`TomMap` (`tom_core_kernel`) + `TomObservingWidget` (`tom_core_flutter`); no new classes (§5.4). |
| **CE-NV** | Navigation / routing **+ screen-flow** — the screen map that results from combining the interaction scenarios into interactions with **screens** (Flutter routes): which form is assigned to which screen and whether it **replaces** the current screen or **overlays** it as a popup; navigation is triggered by CE-AC actions and its target is **conditional** (success → confirmation or back to the previous screen; error / validation error → error display) | client | Reuses `TomPageRoute` + the `tom_navigation` destinations (`tom_flutter_ui`); the stable route-id registry **and the screen-flow model** (screen↔form assignment, replace-vs-popup, action-conditional transitions) are `TomRouteDefinition` / `TomFormScreenAssignment` / `TomScreenFlowEdge`, resolved by `TomRouteRegistry`, in `tom_core_codespecs` (`route_flow.dart`). Authored from the SOM screen route map (§5.11). |
| **CE-AZ** | Authorization per operation | server | Modifier on CE-API. Reuses the kernel `TomAccessControl` family + the `tom_core_server` graded-authorization runtime; no new classes (§5.6.3, §5.15). |
| **CE-ER** | Structured error-result contract | shared | One envelope for all operations, authored as plain annotated classes in `<app>_codespec_shared` (§4.4.2 project 1) → **gap**. No framework type backs it: a response envelope is application domain, not kernel surface, so there is nothing to reuse (§7). |
| **CE-CF** | Server / system configuration | server | Reuses `TomBaseServerConfiguration`/`TomServerConfigResourceProvider` (`tom_core_server`) directly; no new classes (§5.5, §5.16). |
| **CE-CC** | Client configuration — per-machine settings of a client app | client | Reuses `TomBaseClientConfiguration`/`TomSetting<T>`/`TomClientConfigurationStore` (`tom_core_flutter`, `tomclient/configuration/`) directly; no new classes (§5.16, §11). |
| **CE-DS** | Device settings — user-specific settings of a user-owned device, device-persisted | client | Declared over `TomDevicePreferences` (`tom_core_flutter`), the typed device store with a backend per platform (§11, §5.16). Its API carries no principal: the **user half of the scope is the application's**, supplied by the store's `location`, which makes CE-DS CE-CC's substrate at a per-account address. |
| **CE-UP** | User settings — user-scoped, server-persisted, follow the user | client + server | Declared over the shipped preferences round trip (§11, §5.16): `tomUserPreferencesApi`'s four authenticated endpoints carrying `TomUserPreferenceDto` (`tom_core_kernel`), served by `TomUserPreferences` over its repository (`tom_core_server`) and called by `TomUserPreferencesClient` (`tom_core_flutter`). No gap class. Its API carries no principal either, but for the opposite reason to CE-DS: the **user half of the scope is the framework's**, bound from the request zone. |
| **CE-CL** | Client application — which clients exist (Flutter app, CLI, other server) | client | The client-application descriptor `TomClientApplication` is a `tom_core_codespecs` gap class (`client_application.dart`); the four original `tom_core` packages name a client only as an id string on a login or a live connection. |
| **CE-AU** | Authentication / session — credential flow, token, session (distinct from CE-AZ) | shared + client + server | Pure reuse of the `tom_core` auth stack (no gap class): `TomAuthenticationServer` + the app's `TomAuthenticationService` implementation (server), `TomBearerAuthentication`/`TomClientJwtToken`/wire types (kernel, shared), login endpoint triple + token store (client). Mechanics framework-fixed; the spec surface is binding/methods/flows/policies (§5.25). |
| **CE-ID** | Identity — the principal model plus app-declared identity-attribute extensions in the public and encrypted token payloads (distinct from CE-AU authentication and CE-AZ authorization) | shared + server | **Reuse — no new class.** Built on `TomUser` + `TomPrincipal` (`tom_core_kernel`); the profile extension is modelled as an **ordinary class**, directly reusable and carried as **JSON via reflection** in the user profile (§5.24). |
| **CE-MG** | Schema migration — database schema versioning / migration artifacts derived from the data model's evolution (initial DDL, base/seed data, iteration scripts) | database | Pure reuse of the `tom_core_server` migration engine — `TomDbMigrations`/`TomDbMigrator`/`TomMigrationFileName`/`TomDbMigrationAdaptor` + `MariadbMigrationAdaptor`; the artifacts are numbered SQL files in the migrations directory tree, not Dart classes (§5.27). |
| **CE-JB** | BackgroundJob — scheduled / background / queued jobs (cron, calendar, event triggers) distinct from request-driven CE-API: trigger + work definition + target refs + retry/backoff/timeout/alerting | server | Built on `tom_core_kernel`'s `scheduling` module — `TomJobBase`, `TomJobDefinition`, the `TomSchedule` family, `TomScheduler`, `TomJobStore`, `TomLeaseLock` and `TomJobDispatcher` — over the `TomCommand`/`TomExecutor`/`TomWorker` isolate-pooling substrate, so the job base class, scheduler runtime, durable job queue, multi-node single-fire locking and the pluggable-execution seam are all reused rather than specified. `tom_core_codespecs` carries only the deployment/ownership envelope `TomJobDeclaration` (`job_declaration.dart`). The job body is **form 3b** over the `SCJOST` work-step list — one statement per step, in list order — falling back to form 3a on `SCJOB-WORK.workSummary` for a job that lists no steps, which is the common case since most jobs are a single action (§5.29; `codespecs_derivation_contract.md` §2.4, §3.7.1). |
| **CE-LG** | Audit log — the business-relevant trail of who did what, when; distinct from diagnostic logging | server | **Pure reuse — no new class.** The `tom_core_server` `audit` module (`TomAuditTrail`/`TomAuditRecord`/`TomAuditSink`) records automatically at two chokepoints — the CE-API handler and the CE-DB write path — so a specification authors only the *declared* half, carried by the framework's own `@TomAudited` (`enabled`/`redact`) alongside the `@CsAudited` marker. Retention and log format are CE-CF settings on the sink (§4.3.2). |
| **CE-NT** | Notification — which outbound notification types exist, which channels each goes out on, and how user preferences narrow that set | shared (declarations) + server (delivery) | Delivery is pure reuse of the `tom_core_server` `messaging` module (`TomMessage`/`TomMessageRouter`/`TomSmtpTransport`/`TomMessageOutbox`), which takes an already-chosen channel. The layer that *chooses* is the `tom_core_codespecs` class family in `notification_model.dart` — `TomNotificationType`/`TomNotificationChannelDeclaration`/`TomNotificationPreferences`, resolved by `TomNotificationCatalog` (§4.3.2). |
| **CE-RP** | Reporting — a grouped projection over the domain model (dimensions, measures, output columns, charts, parameters), delivered as a rendered artifact | server (definition + execution) + shared (result envelope) | Query execution (`TomGroupedSelect`/`TomAggregate`) and rendering (`TomTabularResult` + the CSV/XLSX/PDF renderers) are pure `tom_core_server` reuse. The **grouped projection** they leave unauthorable is the `tom_core_codespecs` class family in `report_model.dart` — `TomReportDefinition` with `TomReportDimension`/`TomReportMeasure`/`TomReportColumn`/`TomReportParameter`/`TomReportChart`, plus the shared `TomReportResult` envelope over `TomReportResultSection` (§5.28). |

**Member kind — domain enums.** Domain enums are not a part in this table:
`domainEnum` is a **member kind**. A domain enum is authored within its owning
part — a CE-DB entity, a CE-CF/CE-CC/CE-DS/CE-UP setting, a CE-ST view model, or a
CE-API contract member — and marked `@CsEnum`; see the §4.1 rule for the
placement rule and for **CE-EN**, the member kind's extract home in the areas
catalogue.

### 4.1 Authoritative parts catalogue

This is the **authoritative, stable catalogue**. Each part has **one canonical
id** (a PascalCase noun) that drives its surfaces (there is no base-class
surface — pillar (a)/(b)):

1. **`@CodeSpecKind` value** — `CodeSpecPart.<camelCase(id)>`. The enum value a SOM
   section type carries (in a **list**, §9.1) to say "realise me as this kind".
   The enum is named `CodeSpecPart`; `@CodeSpecKind` is the annotation class.
2. **`Cs*` annotation(s)** — the `@Cs<id>` family (all `Cs*`-prefixed), plus
   finer-grained members.
3. **Reused `tom_core` class** — the concrete existing class the CodeSpec is built
   on. A **`gap`** marker means the concrete class is added in `tom_core_codespecs`
   (never an abstract `Cs*` base).

| CE | Canonical id | `@CodeSpecKind` value | `Cs*` annotation(s) | Built on (`tom_core` class / `gap`) |
|----|--------------|-----------------------|---------------------|--------------------------------------|
| CE-EL | ScreenElement | `screenElement` | `@CsElement`, `@CsWidget` | `TomScreenElementsProvider` + the `Tom*` element/widget family (`tom_flutter_ui`); **reuse, no gap** — the element kinds are the existing `Tom*` widgets (§5.7.1, §5.18) |
| CE-FM | Form | `form` | `@CsForm` | `TomForm`, `TomFormChildContainer` (`tom_flutter_ui`) |
| CE-LO | Layout | `layout` | `@CsLayout` | `AclContainer` / `AclRow` / `AclComponent` (`tom_flutter_ui`); node model `TomLayoutModel` / `TomLayoutNode` / `TomLayoutOverrideDelta` (`tom_core_codespecs`) → **gap** (§5.2, §5.12) |
| CE-TX | Text | `text` | `@CsText` | `TomText` (`tom_flutter_ui`) + `TomTextResourceProvider` (`tom_core_kernel`); message/i18n-key model `TomMessageKey` / `TomMessageKeyRegistry` (`tom_core_codespecs`) → **gap** (§5.8, §5.21) |
| CE-VA | Validation | `validation` | `@CsValidation`, `@CsFieldRule`, `@CsFormRule` | `Validators` (`tom_flutter_ui`); **no gap** — provided as **Dart validation methods** (standalone validator classes or methods on the `TomForm` subclass), the §3 first-level-implementation latitude (§5.9, §5.19) |
| CE-AC | Action | `action` | `@CsAction`, `@CsTrigger` *(required `CsTriggerKind`)* | `TomAction` / `TomActionController` / `TomActionTrigger` (`tom_flutter_ui`); **no gap** — full action implementation reused (§5.10, §5.20). The closed 5-kind trigger taxonomy rides `@CsTrigger` as a documented classification, not a class |
| CE-SC | ServerCall | `serverCall` | `@CsServerCall` | `TomServerEndpoint<T,R>` + `TomServerCall` / `TomServerCallSpecs` / `TomServerChannel` (`tom_core_kernel`, §5.3) |
| CE-API | ServerApi | `serverApi` | `@CsEndpoint` | `TomApi` / `TomApiEndpoint<R,Q>` / `TomRemoteApis` (`tom_core_kernel`) + `TomEndpoint` / `TomEndpointHandler` / `TomEndpointRouting` / `TomServer` (`tom_core_server`) (§5.6.1) |
| CE-SU | ServiceUnit | `serviceUnit` | `@CsServiceUnit` | **no gap** — ordinary **(abstract) classes** clustering the server API into functional-group *closures*, carrying the `tom_core_server` server-API mapping annotations (`@tomService` / `TomApiImplementation`) (§5.1, §5.6.2) |
| CE-DB | DataAccess | `dataAccess` | `@CsTable`, `@CsColumn`, `@CsRepository` | Tom persistence model + repository (`tom_core_server`) |
| CE-ST | ViewState | `viewState` | `@CsViewModel` | `TomObservable` / `TomObject` (`tom_core_kernel`) |
| CE-NV | Navigation | `navigation` | `@CsRoute`, `@CsScreenFlow` | `TomPageRoute` (`tom_flutter_ui`); route-id + **screen-flow** model `TomRouteDefinition` / `TomFormScreenAssignment` / `TomScreenFlowEdge` / `TomRouteRegistry` (`tom_core_codespecs`; screen↔form assignment as *replace* / *popup overlay*; action-triggered, conditional targets) → **gap** (§5.11) |
| CE-AZ | Authorization | `authorization` | `@CsAuthorize` | `TomAccessControl*` hierarchy + `TomPrincipal` (`tom_core_kernel`); enforcement `checkAccess` / graded auth (`tom_core_server`) (§5.6.3, §5.15) |
| CE-ER | ErrorResult | `errorResult` | `@CsError` | **gap** — plain annotated result/error classes in `<app>_codespec_shared`; no framework counterpart (§7) |
| CE-CF | ServerConfiguration | `serverConfiguration` | `@CsServerConfig` | `TomBaseServerConfiguration` + `TomServerConfigResourceProvider` (`tom_core_server`) (§5.5, §5.16) |
| CE-CC | ClientConfiguration | `clientConfiguration` | `@CsClientConfig` | `TomBaseClientConfiguration` + `TomSetting<T>` + `TomClientConfigurationStore` (`tom_core_flutter`); baseline layer `TomConfigResourceProvider` (`tom_core_kernel`) (§5.16) |
| CE-UP | UserSettings | `userSettings` | `@CsUserSetting` | `TomUserPreferences` + `TomUserPreferenceRepository` + `TomUserPreferencesServer` (`tom_core_server`) and `TomUserPreferencesClient` (`tom_core_flutter`), both over `tomUserPreferencesApi` + `TomUserPreferenceDto` + `TomUserPreferenceCodec` (`tom_core_kernel`) (§5.16) |
| CE-DS | DeviceSettings | `deviceSettings` | `@CsDeviceSetting` | `TomDevicePreferences` + `TomStoredDevicePreferences` over a per-platform `TomDevicePreferenceStore` (`tom_core_flutter`); the user half of the scope rides the store's `location` (§5.16, §11) |
| CE-CL | Client | `client` | `@CsClient` | `TomClientApplication` (`tom_core_codespecs`) |
| CE-AU | Authentication | `authentication` | `@CsAuth` | `TomAuthenticationServer` + `TomAuthenticationService` (`tom_core_server`); `TomBearerAuthentication` / `TomClientJwtToken` / wire types (`tom_core_kernel`); login endpoint triple client-side |
| CE-ID | Identity | `identity` | `@CsIdentity`, `@CsIdentityAttribute` *(with `placement: public\|encrypted`)* | `TomUser` / `TomPrincipal` (`tom_core_kernel`); **reuse — no new class** — the profile extension is an **ordinary class**, directly reusable and carried as **JSON via reflection** in the user profile (§5.24) |
| CE-MG | SchemaMigration | `schemaMigration` | `@CsMigration` | `TomDbMigrations` / `TomDbMigrator` / `TomMigrationFileName` / `TomDbMigrationAdaptor` / `MariadbMigrationAdaptor` (`tom_core_server`) (§5.27) |
| CE-JB | BackgroundJob | `backgroundJob` | `@CsJob` | `TomJobBase` over the `TomCommand` / `TomExecutor` / `TomWorker` isolate-pooling substrate, `TomJobDefinition` / `TomSchedule` / `TomScheduler` / `TomJobStore` / `TomLeaseLock` / `TomJobDispatcher` (`tom_core_kernel`, `tombase/scheduling/`) — **the whole runtime half is reused**; `TomJobDeclaration` (`tom_core_codespecs`) → **narrow gap** for the deployment-and-ownership envelope only. The work body is **form 3b** over the `SCJOST` work-step list, falling back to 3a on the prose work intent where a job lists no steps (§5.29) |
| CE-LG | AuditLog | `auditLog` | `@CsAudited` | `TomAuditTrail` / `TomAuditRecord` / `TomAuditSink` + the `@TomAudited` declaration (`tom_core_server` `audit`); **reuse, no gap** — the trail records automatically at the endpoint and repository chokepoints, and the spec authors only the declared half (§4.3) |
| CE-NT | Notification | `notification` | `@CsNotification`, `@CsNotificationChannel` | `TomNotificationType` / `TomNotificationChannelDeclaration` / `TomNotificationPreferences` / `TomNotificationCatalog` (`tom_core_codespecs`) → **gap** for the choosing layer, over `TomMessage` / `TomMessageRouter` / `TomMessageOutbox` (`tom_core_server` `messaging`) for delivery (§4.3) |
| CE-RP | Reporting | `reporting` | `@CsReport`, `@CsReportColumn`, `@CsReportChart`, `@CsReportParameter` | `TomReportDefinition` / `TomReportResult` (+ dimension / measure / column / parameter / chart) (`tom_core_codespecs`) → **gap** for the grouped projection and the shared result envelope, over `TomGroupedSelect` / `TomAggregate` (`tom_core_server` `object_persistence`) for execution and `TomTabularResult` + the CSV/XLSX/PDF renderers (`tom_core_server` `export`) for rendering (§5.28) |

**Rules that make the catalogue authoritative:**

- **CE is the stable key; the canonical id is the identifier.** The `CE-*` code is
  the permanent registry key (never reused, never renamed). `@CodeSpecKind` values
  are the camelCased canonical ids — **the `CodeSpecPart` enum is generated from
  this table**, so kind values and ids never drift.
- **Collision-free.** All 26 active canonical ids are distinct nouns; all 26
  active kind values are distinct; all `Cs*`
  annotation names are distinct. The **1 deferred candidate id and kind value**
  of §4.3 and the member kind `domainEnum` are drawn from the same namespace and
  are collision-free against these 26 — giving **28 distinct kind values** in
  the `CodeSpecPart` enum.
- **Promotion never moves an enum value.** A reserved `CodeSpecPart` value keeps
  its declared position when its part is promoted — the enum is append-only in
  ordering terms, so the total stays 28 whichever readiness class a part is in.
  `notification`, `auditLog`, `backgroundJob` and `reporting` are active parts
  sitting at reserved positions, which is what that guarantee looks like in the
  shipped enum.
- **Deferred parts are mapping-only (§4.3).** A deferred part gets a **reserved
  `CodeSpecPart` value** so its SOM section can already carry `@CodeSpecKind`, but has
  **no `Cs*` annotation, no "Built on" `tom_core` class and no generated code**
  until it is promoted into this table. Promotion adds the missing surfaces; the
  reserved kind value is stable and never changes.
- **No base classes.** The catalogue has **no `Cs*` base-class column** — a
  CodeSpec is built on the "Built on" `tom_core` class, marked by its `Cs*`
  annotation(s). A `gap` there is a **concrete** `tom_core_codespecs` class.
- **Traceability is not in the catalogue.** Traceability rides on *every*
  element via the §9 link — the section's `codeSpec` member and the code's
  `@CodeSpec` forward, `@DocSpec`/`DocRef` back. Its sole home is **§9**; no SOM
  section type maps to it. The **`CE-TR`** token remains the stable registry key naming
  that cross-cutting mechanism (registry keys are never reused or renamed).
- **Domain enums are member kinds, not parts.** A domain enum is a **member
  declaration of the part that introduces it** — a CE-DB entity column, a
  CE-CF/CE-CC/CE-DS/CE-UP setting, a CE-ST view-model field, or a CE-API
  request/response member. The enum declaration is authored **once**, marked
  `@CsEnum` (which keeps the `@DocSpec` back-trace to its SOM `DMENE` entry and
  keeps it discoverable as an `@OneOf` discriminator source), and realised as a
  plain Dart `enum` — no `tom_core_codespecs` class. **Placement:** the shared
  project iff a shared contract type (a CE-API request/response type or CE-ER)
  references it; otherwise the owning part's project. `CodeSpecPart.domainEnum`
  is the corresponding **member kind** — SOM sections (`DMENE`, `OBST`) carry
  it like any other `@CodeSpecKind` value; the SOM `DomainEnumRegistry` (DOMEN)
  stays the single document-model authoring home for closed value sets, while
  the owning part determines where the generated enum lives.
- **`CE-EN` is the member kind's extract home.** Being a member kind keeps
  `domainEnum` out of this parts catalogue, but the Phase-4 extract pass still
  has to put its routed values *somewhere*: `DOMEN`/`DMENE`/`DMEVA` carry
  `@CodeSpecKind([CodeSpecPart.domainEnum])`, and an extractor that finds no
  area claiming the kind would drop the registry from every extract — leaving
  §4.4.6's authoring step 1 with no extract of its own and tripping the §9.6
  extract-presence checks on every conforming `@CsEnum` back-link. So the
  registry key **`CE-EN`** (canonical id `DomainEnum`) is allocated as an
  **areas-catalogue entry that is not a parts-catalogue row**: it claims
  `CodeSpecPart.domainEnum`, rides slice 1 / authoring step 1 at position 0
  (§4.4.3, §4.4.6), and yields `CE-EN.extract.yaml` like any area. The
  precedent is CE-TR — a `CE-*` registry key may name a non-part mechanism, and
  registry keys are never reused or renamed — with one difference: CE-TR names
  a mechanism no value routes to, so it stays out of the areas catalogue, while
  CE-EN exists precisely because values route to it. §4.1's part count stays
  **26**; the areas catalogue counts **27** entries.
- **A domain enum holds no authored attributes of its own** — which is *why*
  the realisation is a plain `enum` and not a holder class. Each attribute a
  holder would have carried already belongs to something else, and belongs
  there exclusively: the **value token** is the enum constant's own identifier
  (there is no second `valueId` string that could drift from the name); the
  **value label** is CE-TX copy, resolved through `TomTextResourceProvider`
  like every other label — §1.2 consequence 1 names domain-enum value labels
  explicitly, and §5.21 fixes the shape, which is the **derived** one keyed off
  the value rather than a catalogue entry (§5.18); the **description** is the
  doc comment emitted above the enum and above each constant
  (`codespecs_derivation_contract.md` §3.1.1); and a **default value** belongs
  to the enum-typed member that has one — a CE-DB column, a CE-CF/CE-CC/CE-DS/
  CE-UP setting, a CE-ST field — never to the enum, since two members of the
  same type may default differently. Nothing is left for a holder to hold.
- **CE-AZ is a modifier**, applied as a `@CsAuthorize` attribute on the owning
  `@CsEndpoint`.
- **Settings parts are owner-keyed and single-moded.** Each configuration/
  settings part is pinned to exactly one scope key — CE-CF (server/system),
  CE-CC (client app + machine, no user), CE-DS (user + device,
  device-persisted), CE-UP (user, server-persisted — follows the user). No
  part carries a persistence discriminator; the scope key alone decides where
  a value lives (§11).
- **Two internal-modeling decisions.** The CE-SU service-unit boundary
  criterion is defined in **§5.1**; the CE-LO layout-node representation in
  **§5.2**.

#### 4.1.1 Part readiness — mapping, examples and gap analysis

This table details, per part — **including the §4.3 deferred parts** — how the
part is actually coded in CodeSpecs: the `tom_core`-family classes it builds on,
the `Cs*` annotations that carry specification detail beyond what plain Dart
code can express, and the two gap dimensions.

**The coding-form spectrum.** "Built on a `tom_core` class" is relative — a
CodeSpec takes one of four coding forms:

1. **Framework subclass/instantiation** — extends or instantiates a
   `tom_core`-family class (`TomForm`, `TomAction`, `TomApiEndpoint`,
   `TomServerEndpoint`, …).
2. **Plain annotated model class** — a totally new, ordinary Dart data/object
   class whose spec detail rides entirely on `Cs*` annotations and doc comments:
   API request/response objects, config/settings holders, identity extensions,
   the client descriptor, message-key and error-code catalogues.
3. **Compilable pseudo-code** — algorithmic CodeSpecs with a real body. It has
   two shapes, and `codespecs_derivation_contract.md` §2.4 is authoritative for
   both: **3a**, whose entire body is `throw
   UnsupportedError('<free-text explication>')` — it compiles, names its inputs
   and outputs, and defers the algorithm to Phase 6 — and **3b**, a statement
   sequence over an **abstract collaborator**, used where the contributing SOM
   section carries an ordered step list. Every §3 contract entry names which of
   the two it emits.
4. **Annotation-only modifier** — no class of its own; an attribute on another
   part's element (CE-AZ as `@CsAuthorize` on `@CsEndpoint`).

**Gap definitions.** A ***`tom_core` gap*** means new base classes, abstraction
classes or annotations are needed in the core family (concrete gap classes land
in `tom_core_codespecs`, §1.1). A ***`tom_code_specs` gap*** means the CodeSpecs
code needs **additional annotations** so the code carries the specification
details *completely* — beyond what simple code can express (element kinds,
maximum lengths, format restrictions, placement, schedules, grades, …).

**Annotation authoring state.** 39 part markers exist in `tom_code_specs` today —
one per part, plus the several markers a part may own (CE-EL, CE-AC, CE-NV,
CE-DB, CE-VA, CE-NT) — and one further marker, `@CsCollaborator`, which is **not
a part**: it has no `CE-*` code and no `CodeSpecPart` value, and this catalogue
gains no row for it, because a part is what a SOM section is realised *as* while
a collaborator is what a realisation's body needs in order to compile
(`codespecs_derivation_contract.md` §3.0). That is 40 markers and 42 classes,
counting the two facet value classes `CsFileReference` and `CsGradedAccess`,
which are annotation *arguments* rather than markers. The §4.3 deferred
candidates deliberately have **no** annotation: a deferred part's `CodeSpecPart`
value is reserved so a SOM section can already carry `@CodeSpecKind`, but the
marker is authored only on promotion.

**The family is a marker set *and* an attribute surface.** 24 of the 40 markers
take arguments; the other 16 carry a single optional `note`, because everything
their part authors is already carried by the annotated declaration itself or by
a `tom_core` substrate constructor. Which attributes become constructor
parameters and which stay on the declaration is decided by
[codespecs_derivation_contract.md](codespecs_derivation_contract.md) §2.3's
three tests, and its §5.1–§5.3 (not this document's) give the resulting constructor shape of every
marker, the 16 that stay note-only, and the closed catalogues the arguments
select from. Every example in this document is a **call that compiles**.

Two parameter families the constructors consume ship beside the markers, and
neither holds annotations of its own: the §5.23 `Cs*Ref` typed-reference family
(`cross_part_refs.dart`), which makes a reference from one part to another a
compiler-checked const rather than a string, and the closed catalogues
(`vocabulary.dart`), which are enums for the same reason — a catalogue grows by
a reviewed taxonomy edit, not by a specification inventing a value in passing.
Both are declared locally rather than imported, because `tom_code_specs`
deliberately does not depend on `tom_core` (§9.5); a named validator check
asserts each mirrored catalogue stays complete.

The gap columns cite the owning open-work todos on both sides of each gap. A
`tom_core` capability is owned by a `tcca*` todo of the Tom Core quest; the
CodeSpecs-side consequence of that capability landing is owned by a `csra*` /
`csrc*` / `qrc*` todo of the TomSpecs quest (§10). A cell naming a pair reads in that order:
the core-side prerequisite first, the mapping-side todo that states the
resulting position second.

| Part ID | Part Description | Mapping to CodeSpecs | Gap analysis `tom_core` | Gap analysis `tom_code_specs` |
|---------|------------------|----------------------|-------------------------|-------------------------------|
| **CE-EL** ScreenElement | A single visible/interactive element of a screen. Closed **11-kind catalogue** (§5.18): form-member kinds *TextInput, Number, Toggle, DateInput, Choice, MultiChoice, FileInput*; standalone kinds *Label, Button, MenuEntry, FormHost*. | **Built on:** `TomScreenElementsProvider` + the `Tom*` widget family (`tom_flutter_ui`) — TextInput → `TomFormStringField`, Number → `TomFormIntField`/`TomFormDoubleField`, Toggle → `TomFormBoolField` (`TomFormNullableBoolField` when `tristate`), DateInput → `TomFormDateField`/`TomFormTimeField`, FileInput → `TomFormFileUpload`/`TomFormFileDropzone`/`TomFormFileThumbnail`, Label → `TomText`/`TomLabelBase`, FormHost → the CE-FM `TomForm` host. Form-member elements are coded as CE-FM field members; standalone elements as provider-created widgets.<br>**Annotations:** `@CsElement(kind: …)` on the field/member; `@CsWidget` on a standalone widget CodeSpec.<br>**Example:** `@CsElement(kind: CsElementKind.textInput) late final TomString email;` inside the `@CsForm` class — the kind is the annotation's argument; label key and grade ride the field's own `tom_flutter_ui` declaration. | None — the closed catalogue maps 1:1 onto shipped `tom_flutter_ui` widgets and needs no new base class: the `TomFormNullableBoolField` family carries `tristate`, the `minItems`/`maxItems` field rules carry the MultiChoice selection bounds, and FileInput reuses the shipped `TomFormFileField` family, all three `presentation` values included (§4.1.2). **A per-value option label is bundle-resolved like every other label**: the widgets render `SelectableItem.label` verbatim (`forms/fields/tom_form_enum_object_fields.dart`), so the label's provenance is the source class's concern, and the shipped `TomEnumSelectableSource<E>` / `TomEnumNameSelectableSource<E>` pair (`forms/selection/tom_enum_selectable_source.dart`) resolves each option through `TomObservableEnum.resolveText` under `<scope path>.<enumType>.<value>` and re-emits on a bundle change. A *Choice* / *MultiChoice* therefore emits one of those rather than a literal `TomSelectableSource` (§5.18), and §5.21's promise holds at emission too. **The text-controller write path is guarded throughout**: `_setControllerText` is the class's only write to the controller and it suppresses the input listener around it (`forms/tom_form.dart`), `set()` routes through it (`:1245`), and `reset()` carries no override at all — `TomField.reset` resets through the virtual `set` (`:775`). A programmatic write is therefore never judged by the input validators, which exist to judge keystrokes. | `@CsElement` carries the one thing code cannot state: the element **kind**, since the declared Dart type does not fix *TextInput* vs *Choice*. It is required — no kind is a sensible default, and the kind selects both the per-kind attribute set and the default widget. Label/hint **message keys** and display/read-only **grade** defaults are *not* arguments: each maps onto a named `tom_flutter_ui` widget property, so they ride the field's own declaration rather than being repeated here (`codespecs_derivation_contract.md` §2.3 test **b**). `@CsWidget` stays note-only for the same reason — it marks the widget instantiation, which already carries the per-kind extras. |
| **CE-FM** Form | A user-facing form: typed field collection, lifecycle (load/edit/submit), per-field grades. | **Built on:** subclass of `TomForm<T extends TomClass>` (`tom_flutter_ui/lib/src/forms/tom_form.dart`); fields as `TomField<T>` members; nesting via `TomFormChildContainer`.<br>**Annotations:** `@CsForm()` on the class, with `@CodeSpec` carrying its id; fields carry `@CsElement` + `@CsValidation`.<br>**Example:** `@CsForm() @CodeSpec('customer_edit') class CustomerEditForm extends TomForm<Customer> { … }` | None — full reuse, and nothing is inherited from CE-EL either. The form's load path writes each field through `TomField.set()`, which on a text field is the guarded controller write named there, so loading a form is not processed as a burst of keystrokes. | `@CsForm` stays note-only. Each of the three things it might have carried already has a carrier: the bound view-model link is the `TomForm<T>` **generic** (`codespecs_derivation_contract.md` §2.3 test **a**), the submit target is **derived from the `@CsTrigger`** that fires the submitting action rather than authored a second time, and form-level grade defaults ride the field declarations. The form's id is `@CodeSpec`'s. |
| **CE-LO** Layout | Two-layer **id-addressed** layout: container tree (rows/containers) + component placement; delta overrides via the closed **5-op grammar** (§5.22): *reparent, set-container-prop, set-slot-hint, insert-container, remove-container*. | **Built on:** `AclRow` / `AclContainer` / `AclComponent` (`tom_flutter_ui/src/advanced_container_layout/acl_container.dart`), rendered via `TomObservingWidget`. The layout CodeSpec itself is a **plain annotated model class** describing the node tree.<br>**Annotations:** `@CsLayout` on the node-model class.<br>**Example:** a layout class whose members declare container nodes with stable ids and component slots, each slot naming its CE-EL element. | **Gap filled in `tom_core_codespecs`** — the id-addressed **node model** (stable node ids over the `Acl*` tree + the 5-op delta grammar) has no `tom_core` class, so `layout_node.dart` carries `TomLayoutModel` over the sealed `TomLayoutNode` (`TomLayoutContainerNode` / `TomLayoutSlotNode`) plus `TomLayoutOverrideDelta` over `TomLayoutContainerKind` + `TomLayoutDeltaOp` (§5.2, §5.12). The runtime `Acl*` classes themselves are ready. | `@CsLayout` carries the node **id** as its required first positional argument — the one thing the `Acl*` substrate genuinely lacks, and what the whole §5.22 delta grammar addresses nodes by. **Slot hints** are `AclComponent` properties and **container kind** is which `Acl*` class is instantiated, so neither is an argument (`codespecs_derivation_contract.md` §2.3 test **b**). A delta targets a node *within the same layout declaration*, so addressing it by id string is a local coordinate, not a §5.23 cross-part reference. |
| **CE-TX** Text | User-visible text: message/i18n **keys** (shared), per-client **copy**. | **Built on:** `TomTextResourceProvider` (`tom_core_kernel`, `tombase/resources/tom_resource_provider.dart`) resolves keys; copy is basePath-derived client-side.<br>**Annotations:** `@CsText` on each **member** of a message-key catalogue class in the shared project; keys as §5.23 `CsMessageKey` consts.<br>**Example:** `class Messages { @CsText(baseCopy: 'Customer name') static const custNameLabel = CsMessageKey('customer.name.label'); }` | **Gap filled in `tom_core_codespecs`** — the typed **message-key registry** model (the catalogue of keys, SOM home MSGKR) has no core class, so `message_key.dart` carries `TomMessageKeyRegistry` over `TomMessageKey` + `TomMessageRole` / `TomMessageCategory` (§5.8, §5.21). | `@CsText` carries the **base-language copy** (required — a key with no copy is a key with no message), the **role** the copy plays and which catalogue **half** it belongs to. The **key** is not an argument: it is the `CsMessageKey` const the member already holds. Nor are the message **parameters**: §5.21 derives them from the copy's placeholders, so a second parameter list would be a source that could disagree with the copy it describes. A validator asserts `role == error ⇒ category == errorCopy`. |
| **CE-VA** Validation | Field + form validation; closed **10-rule catalogue**: *required, email, minLength, maxLength, pattern, min, max, minItems, maxItems, compose*. | **Built on:** `Validators` static catalogue + `TomValidatorRegistry` declaration strings (`'required, minLength:8, pattern:^[A-Z]'`) + the sealed `ValidationResult` family and `FormValidationError` (`tom_flutter_ui/lib/src/forms/validation/`). Coded as **Dart validation methods** on the form or standalone validator classes; cross-field form rules are **form-3a** methods on the form — a rule is stated as prose, so it reaches code as a signature plus its explication (`codespecs_derivation_contract.md` §3.2.4).<br>**Annotations:** `@CsValidation` on the method/field.<br>**Example:** `@CsValidation(rules: 'required, maxLength:80') late final TomString name;` | None — the 10-rule catalogue is shipped 1:1 in `Validators`. | All three markers are authored. `@CsFieldRule` and `@CsFormRule` mark the two rule *shapes* — a standalone `Validator<T>` versus a cross-field method on the form — because they differ in signature, not merely in scope, and `@CsValidation` alone cannot tell them apart. The **standard** rules need no marker of their own: they are the `rules` declaration string on the field, so only project-specific rules get a marker, each naming its error text as a `CsMessageKey`. `rules` is named rather than positional because Dart forbids one signature carrying both optional-positional and named parameters, and every marker keeps a named `note`. |
| **CE-AC** Action | A user-triggerable action with undo/transaction support; closed **5-kind trigger taxonomy**: *user-gesture, in-form event, lifecycle, server-event, condition*. | **Built on:** subclass of `TomAction<TContext, TUndo>`, registered on `TomActionController`, wired by `TomActionTrigger` (the single authoring home of the element→action edge), with `TomActionTransaction` / `TomActionContext` (`tom_flutter_ui/lib/src/actions/`). An action's `perform` is a **form-3b** body over the ISC steps that state the interaction, in order (`codespecs_derivation_contract.md` §3.5.5); an action with no contributing step falls back to form 3a.<br>**Annotations:** `@CsAction` on the class; `@CsTrigger(kind: …, action: …)` on the trigger declaration.<br>**Example:** `@CsAction() @CodeSpec('save_customer') class SaveCustomerAction extends TomAction<…> { @override perform(ctx) => throw UnsupportedError('persist via CustomerService.save'); }` — the 3a fallback, for an action no ISC step contributes to — triggered by `@CsTrigger(kind: CsTriggerKind.userGesture, action: CsActionRef('saveCustomer'), element: CsElementRef('save', form: 'customerEdit'), gesture: CsGesture.tap)`. | None — the full action implementation is reused. | `@CsTrigger` carries the trigger **kind** plus that kind's slots — Dart annotations have no sum types, so each kind's payload is a separate optional argument and a validator asserts only the declared kind's are non-null. `@CsAction` stays note-only: the action id is its declaration name, the owning controller its declaration site, `TContext` its generic, and the two-hop CE-AC → CE-SC → CE-API edge is **derived from the trigger**, never authored twice. |
| **CE-SC** ServerCall | The client-side declaration of a call to a server operation. | **Built on:** `TomServerEndpoint<T, R>` + `TomServerCall` / `TomServerCallSpecs` / `TomServerChannel` (`tom_core_kernel`, `tombase/http_connection/server_connection.dart`); declared as typed endpoint fields in a client calls class (§7: all POST, the operation name carries the intent). Request assembly, response handling and error handling are three **form-3b** methods (`codespecs_derivation_contract.md` §3.5.7): each derives from the `ServerCallStepEntry` (`SVCST`) steps its `role` routes to it — `assembleRequest` / `handleResponse` / `handleError`, the three enum values being the three method names — falling back to form 3a on the issuing step's own behaviour text for a role that lists no steps.<br>**Annotations:** `@CsServerCall(operation)`.<br>**Example:** `@CsServerCall(CsOperationRef('customer.save')) final saveCustomerCall = TomServerEndpoint<CustomerSaveRequest, CustomerDto>(…);` | None. | Takes a `CsOperationRef` (§5.23) so the call ties to its `@CsEndpoint` by **typed reference**, not by string. It is the one edge the code cannot carry itself — the call site is client, the operation shared, and nothing in the Dart declaration names the link. Call options ride `TomServerCallSpecs`. |
| **CE-API** ServerApi | A server-side operation endpoint under the §7 contract: POST-only, CE-ER result envelope, 5xx = transport only. | **Built on:** `TomApi` / `TomApiEndpoint<ReturnType, RequestType>` / `TomRemoteApis` (`tom_core_kernel`) + `TomEndpointHandler` / `TomEndpointRouting` / `TomApiEndpointImplementation` / `TomServer` (`tom_core_server`). Request/response types are **plain annotated model classes** in the shared project.<br>**Annotations:** `@CsEndpoint(operation)` + the `@CsAuthorize` modifier (CE-AZ).<br>**Example:** `@CsEndpoint('customer.save') @CsAuthorize(requirement: CsAuthRequirement.role, roles: [CsRoleRef('sales')])` on the operation; its `CustomerSaveRequest` members carrying field-constraint annotations. | None. | The request/response **members** carry their field-level constraints as `@CsValidation` declaration strings — maximum length, format restriction, required-ness — plus `CsErrorCode` refs (§5.23) enumerating which CE-ER codes the operation can return. |
| **CE-SU** ServiceUnit | A functional-group *closure* of the server API (§5.1 boundary: owned-aggregate primary, process cohesion, bounded context); id `<RootAggregate>Service`; membership **derived, not listed**. | **Built on:** ordinary **(abstract) classes** carrying the `tom_core_server` mapping annotations (`@tomService` / `TomApiImplementation`, discovered via `scanClasses` / `TomComponentReference`); methods are the operations, and a handler body is **form 3a** — `SVOPE.purpose` is prose (`codespecs_derivation_contract.md` §3.4.2).<br>**Annotations:** `@CsServiceUnit(rootAggregate: …, boundedContext: …)`.<br>**Example:** `@CsServiceUnit(rootAggregate: Customer, boundedContext: 'Sales') abstract class CustomerService { Future<CustomerDto> save(CustomerSaveRequest r); }` | None. | `@CsServiceUnit` carries the **boundary criterion** as its two required arguments — the owned root aggregate (a bare `Type`, since entities are already Dart types) and the bounded context it sits in. Cross-unit references use `CsServiceUnitRef` (§5.23). |
| **CE-DB** DataAccess | Persistence: entities/tables, columns, repositories, queries (server-only placement; §5.13 three-level attribute surface). | **Built on:** the `tom_core_server` persistence model — CRUD/MariaDB repositories, query builder, persistence annotations. Entities are **plain annotated model classes**; a named query is a **form-3b** repository method composing `TomQueryBuilder` (`codespecs_derivation_contract.md` §3.3.4).<br>**Annotations:** `@CsTable('customer')` on the entity, `@CsColumn(…)` per attribute, `@CsRepository` on the repository class.<br>**Example:** `@CsTable('customer') class Customer { @CsColumn(length: 80) late String name; }` | None — the aggregation grammar is carried by `tom_core_server`'s `object_persistence/grouped_query.dart`: `TomAggregateFunction` (`count` / `sum` / `avg` / `min` / `max`, `distinct`-capable), `groupBy` key columns and a `having` group predicate, compiled through the query builder and sentence compiler and surfaced on the CRUD repository. Aggregate query specs are realisable over the query model, for **active CE-DB** as well as for **CE-RP**, whose dimensions and measures compile onto it (§5.28). **A repository's declared transaction scope has a per-flow substrate**: `TomTransactionManager` holds the current transaction in a **`Zone` value** (`tom_core_server` `transactions/transaction_manager.dart`), and `TomServer` forks a scope per request (`tomserver/server/server.dart`), so two concurrently served requests each run in their own unit of work. The scope is **ambient**, not threaded through a call, which is why `@CsRepository` carries nothing for it. Work that runs outside a request opens its own scope: CE-JB's emitted job body is wrapped in `runInTransactionScope` (§5.13, §5.29). An **optional** attribute emits a **plain nullable Dart field** (`String?`), keyed on `DATAA.nullable` — never a `TomN*` observable, which the shipped repository can read but not write (§5.13). | `@CsColumn` expresses what Dart types cannot: the physical **column name and type**, the **max length**, and the column-level access guard (`accessKey`, §5.13) — plus the `CsFileReference` facet whose presence *is* the column kind. `@CsRepository` stays note-only: entity and key type are the class's generics, and the named-query intent is one form-3 method each. |
| **CE-ST** ViewState | Observable client view-model state. | **Built on:** `TomObservable` / `TomObject<T>` / `TomString` / `TomInt` / `TomBool` / `TomClass` / `TomList` / `TomMap` (`tom_core_kernel` observable) + `TomObservingWidget` / `ValueListenableObserver` (`tom_core_flutter`). The view-model is a `TomClass` subclass with observable members.<br>**Annotations:** `@CsViewModel`.<br>**Example:** `@CsViewModel(scope: CsLifecycleScope.route) class CustomerListState extends TomClass { final customers = TomList<…>(…); }` | No class gap — the observable family is shipped, **including a nullable arm** (`TomNString` / `TomNInt` / `TomNDouble` / `TomNBool` / `TomNDateTime`, `tom_core_kernel` `tombase/observable/tom_observable_objects.dart`). An **optional** field emits that nullable arm, initialised to `null`, keyed on the attribute's `mandatory` level. The rule stops at CE-ST: CE-DB's `@CsColumn` emits a **plain nullable field** instead, because the persistence write path cannot bind an observable (§5.13). | `@CsViewModel` carries the state's **lifecycle scope**, defaulting to the narrowest arm (`screen`) so widening a view model's lifetime is a deliberate authored act. The fields, their types and their binding are the declaration itself, and binding to a widget is `TomObservingWidget`'s own surface (`codespecs_derivation_contract.md` §2.3 tests **a**/**b**). |
| **CE-NV** Navigation | Routes + **screen flow**: screen↔form assignment as *replace* / *popup overlay*; action-triggered, conditional targets. | **Built on:** `TomPageRoute<T>` + `TomNavigationDestination`/Rail/Bar/Drawer (`tom_flutter_ui`) for shell chrome. The route registry is a **plain annotated constants class**.<br>**Annotations:** `@CsRoute()` per route; `@CsScreenFlow()` on flow declarations.<br>**Example:** `@CsRoute() static const customerEditRoute = TomRouteDefinition(routeId: 'customer/edit', …);` | **Gap filled in `tom_core_codespecs`** — `tom_core` has no route-id registry or screen-flow model, so `route_flow.dart` carries `TomRouteRegistry` / `TomRouteDefinition` / `TomFormScreenAssignment` / `TomScreenFlowEdge` over `TomScreenPresentation` + `TomFlowOutcome` (§5.11); the SOM authoring home is the **screen route map** (`SCRTMP`) under D09 XDS `ScreenFlowStructure`. | Both markers stay note-only: the **transition kind** (*replace* vs *popup overlay*), the outcome and the `CsRouteRef` / `CsActionRef` edges all ride `TomRouteDefinition` / `TomFormScreenAssignment` / `TomScreenFlowEdge`'s own constructors, so repeating them as marker arguments would create the second, disagreeing source `codespecs_derivation_contract.md` §2.3 exists to prevent. |
| **CE-AZ** Authorization | Access control on operations/resources; presets (`TomNoAccess` / `TomPublicAccess` / `TomAuthenticatedAccess` / `TomGuestAccess`) + **six configurable kinds**. | **Built on:** the `TomAccessControl` family (`tom_core_kernel`, `tombase/security/access_controls.dart`) — `TomRoleAccess`, `TomGroupAccess`, `TomEntitlementAccess`, `TomResourceKeyAccess`, `TomCustomAccess`, `TomGradedAccess` — evaluated via `checkAccessibility(TomPrincipal?)` + `resolveAuthState` against `TomPrincipal`.<br>**Annotations:** applied as the `@CsAuthorize` **modifier** on the owning `@CsEndpoint` (annotation-only form — no class of its own).<br>**Example:** `@CsEndpoint('customer.save') @CsAuthorize(requirement: CsAuthRequirement.role, roles: [CsRoleRef('sales')])` | None — `TomServerPrincipal` holds the ambient server principal and both evaluation entry points apply the `min(user, server)` meet (§5.26). | `@CsAuthorize` takes `CsRoleRef` / `CsResourceKeyRef` typed refs (§5.23) rather than raw strings, and the graded arm's three-slot tree as a `CsGradedAccess` whose slots are themselves `@CsAuthorize` values — the recursion §5.15 defines. `requirement` has **no default**: defaulting it is the exact failure §5.16's fail-safe rule prevents. |
| **CE-ER** ErrorResult | The shared error/result envelope + the error-code catalogue. | **Built on:** nothing in the framework — the envelope (success/failure arms, error code, message, field-level details, severity) is **authored per application** as plain annotated classes in `<app>_codespec_shared`, alongside the error catalogue (a **plain annotated constants class**); texts keyed via CE-TX.<br>**Annotations:** `@CsError` per code.<br>**Example:** `@CsError(severity: CsErrorSeverity.error) static const custNotFound = CsErrorCode('CUST-404');` | The envelope + field-error types themselves. | `@CsError` carries the **severity** from the closed `CsErrorSeverity` catalogue (`tom_code_specs`), which now mirrors no framework enum. It carries no message key: §5.21 keys error copy *by the error code*, so the key is derived, not authored. The codes themselves are §5.23 `CsErrorCode` consts. |
| **CE-CF** ServerConfiguration | Server/system-scope configuration; precedence config-tree → env → `.env` → cmdline; secret marking. | **Built on:** subclass of `TomBaseServerConfiguration` + `TomServerConfigResourceProvider` (`tom_core_server`). A **plain typed config class**; config keys stay strings (§5.23 exemption).<br>**Annotations:** `@CsServerConfig(key)` per setting member.<br>**Example:** `class AppServerConfig extends TomBaseServerConfiguration { @CsServerConfig('smtp.password', envAlias: 'SMTP_PASSWORD') late String smtpPassword; }` | None. | `@CsServerConfig` carries the setting **key** and its env / cmdline **aliases** — all three verbatim, being §5.23 exemption 1 — plus the required `overridableBy` scope opt-in (§5.16) and the `secret` flag. Type and default are the member declaration and its initialiser; precedence is not an argument, because §5.16 fixes it for every setting and a per-setting override would be a second, disagreeing rule. The SMTP settings (`smtpHost`, `smtpPort`, `smtpSecurity`, `smtpUsername`, `smtpPassword`, `smtpFrom*`, `smtpClientName`) are the live exemplar: declared on `TomBaseServerConfiguration`, with `smtpPassword` secret-bearing — its *declaration* authored, its *value* supplied only through the precedence chain. |
| **CE-CC** ClientConfiguration | Client-app + machine scope (no user); single-moded per §11. | **Built on:** subclass of `TomBaseClientConfiguration` (`tom_core_flutter`, `tomclient/configuration/client_configuration.dart`) — settings declared in `declareSettings()` as `TomSetting<T>` under dotted keys, baselines resolved from `TomConfigResourceProvider` (`tom_core_kernel`), overrides persisted through a `TomClientConfigurationStore` (memory / JSON-file variants).<br>**Annotations:** `@CsClientConfig(key)` per setting member.<br>**Example:** `class AppClientConfig extends TomBaseClientConfiguration { @CsClientConfig('client.server.url') late final TomSetting<String> serverUrl; @override void declareSettings() { serverUrl = stringSetting('client.server.url', 'https://…'); } }` | None — the holder carries typed access, defaults, load-at-startup, persistence of **overrides only**, and observation both per field and holder-wide. | `@CsClientConfig` carries the setting **key**, its env **alias** and the required `overridableBy` scope opt-in, as CE-CF does. It has no cmdline alias: a client app is launched by its platform, not by a command line the specification controls. |
| **CE-UP** UserSettings | User-scope, **server-persisted** settings — follows the user (§11). Single-moded: there is no persistence argument, because the scope key alone decides where a value lives. | **Built on:** `TomUserPreferences` (`tom_core_server`, `tomserver/preferences/user_preferences_service.dart`) over a `TomUserPreferenceRepository`, reached from a client through the kernel's `tomUserPreferencesApi` (`tombase/preferences/user_preferences_contract.dart`) — four authenticated endpoints carrying `TomUserPreferenceDto` — implemented server-side by `TomUserPreferencesServer` and called client-side by `TomUserPreferencesClient` (`tom_core_flutter`). Pure reuse.<br>**Annotations:** `@CsUserSetting(key)` per field.<br>**Example:** `@CsUserSetting('user.preferredLanguage') String preferredLanguage = 'de';` — the default is the member initialiser. | None — the round trip ships end to end: the kernel declares the contract and the codec, `TomUserPreferences` persists per user through the repository, `TomUserPreferencesServer` implements the four endpoints, and `TomUserPreferencesClient` calls them. The **user is bound from the request zone, not passed as an argument**, so a generated `@CsUserSetting` accessor has no principal parameter to get wrong; the persisted-value → default order is the store's own (`getOr`). Both ends resolve their URIs from the one `TomApi` declaration, so client and server cannot address different paths. | `@CsUserSetting` carries the setting **key** and its required `overridableBy` scope opt-in (§5.16) — type and default are the member. Single-moded for the §11 reason: a setting that must stay on the machine is `@CsDeviceSetting`, not this marker with a flag. Both halves of the declaration use the same key and the same member names, so the wire mapping is identity. |
| **CE-DS** DeviceSettings | (user, device) scope, device-persisted (§11). | **Built on:** the `tom_core` property/settings classes (§5.16).<br>**Annotations:** `@CsDeviceSetting(key)` per field.<br>**Example:** `@CsDeviceSetting('device.lastOpenedTab') int lastOpenedTab = 0;` | **A `@CsDeviceSetting` emits onto `TomDevicePreferences`** (`tom_core_flutter` `tomclient/preferences/device_preferences.dart`) — the typed device store, resolved as a bean, implemented by `TomStoredDevicePreferences` over a `TomDevicePreferenceStore` chosen per platform by dependency injection, so the call site never branches on the platform. The **user dimension is the application's, supplied by the store's `location`**: the API carries no principal, a store is one flat key space, and an install on which more than one account signs in gives each its own location. CE-DS is therefore CE-CC's substrate at a different address (§5.16, §11). | `@CsDeviceSetting` carries the setting **key** and nothing else — CE-DS is the lattice's narrowest scope, so unlike CE-UP it carries no `overridableBy` counterpart (§5.16), and for the same §11 reason there is no persistence-mode argument on either. |
| **CE-CL** Client | A client application of the system: which screens it comprises, its platform targets, its entry route. SOM home CLIAPP (the client-application list under `ClientRequirementsSection` CLRESE, D06 ATS). | **Built on:** `TomClientApplication` (`tom_core_codespecs`, `client_application.dart`) — `clientId` / `displayName` / `platforms` / `entryRoute` / `screenIds` / `serverBaseUrl`. The CodeSpec is a subclass carrying the marker.<br>**Annotations:** `@CsClient` on the descriptor.<br>**Example:** `@CsClient('backoffice', kind: CsClientKind.flutterApp) class BackofficeClient extends TomClientApplication { … }`, its members naming platform targets and its entry route (`CsRouteRef`). | **Gap filled in `tom_core_codespecs`** — the four original `tom_core` packages have no client-application *descriptor*: `TomAuthenticationData` carries a client id string and `TomClientRemoteContext` models a live connection, but neither names the client application as a first-class, spec-authorable unit. `client_application.dart` carries that unit. | `@CsClient` carries the client **id** and its **kind**, the latter required because the kind decides which other parts the client may carry — a CLI has no CE-EL — so defaulting it would silently admit impossible combinations. The kind is the one attribute with **no descriptor member**: platform targets, entry route and screen set are all `TomClientApplication`'s own. The client's **configuration** is not among them either — a CE-CC setting names its owning client (§11), so a client-side list would be the second source the two would disagree through. |
| **CE-AU** Authentication | Login, token issuance/refresh; optional 2FA. | **Built on:** `TomAuthenticationServer` + the app's `TomAuthenticationService` (`tom_core_server`); wire/token types `TomBearerAuthentication` / `TomClientJwtToken` / `TomAuthenticationMessage` / `TomAuthenticationResult` / `TomServerJwtToken` (`tom_core_kernel` / `tom_core_server`). Pure reuse; the login endpoint triple is client-side.<br>**Annotations:** `@CsAuth` marks the app's auth service + client flow. | None — the second-factor round trip is complete in all three loci, so CE-AU stays pure reuse. **Server:** pass 1 issues a `Tom2FAChallenge` interim token carrying the access-control payload it already resolved, `authenticatePass2` verifies it statelessly through the `Tom2FARegistry` adaptor, and the challenge's `validity` plus its attempt allowance bound the chain; whether a factor is owed and which mechanisms may answer it is `Tom2FAPolicy.decideFor` → `Tom2FADecision` (requirement level, mechanisms in preference order, grace count), with `TomRole2FAPolicy` shipped and `TomPrincipalFlag2FAPolicy` the const fallback; enrolment is `Tom2FAEnrolmentSupport` (`beginEnrolment` / `confirmEnrolment`), implemented by `TomTotp2FAService` with secret generation and the `otpauth://` provisioning URI, persisted through `Tom2FAEnrolmentStore`. **Wire:** `TomAuthenticationResult` carries `requires2FAEnrolment`, `availableTwoFactorMethods` and `twoFactorEnrolmentSkippable` beside the unchanged `requires2FA` / `twoFactorType`. **Client:** `Tom2FAFlowPanel` over the app's `Tom2FAFlowController` owns the chooser, attempt counter and skip affordance, with `Tom2FAClientMechanism` per mechanism (`tom_core_flutter`). See §5.25. | `@CsAuth` stays note-only, on a different `codespecs_derivation_contract.md` §2.3 ground per group. The **set of enabled methods and flows** is test **a**: there is one marked declaration per enabled method/flow, so the set of declarations *is* the enabled set, and a flow-kind argument would invent a closed method catalogue the SOM does not have. The **second-factor policy** — requirement level, mechanism preference order, grace count — is test **b**: those are `TomRole2FAPolicy`'s own constructor parameters (`requirementByRole`, `defaultRequirement`, `mechanisms`, `graceLogins`), so `MfaConfiguration` (`MC`) emits a *further marked declaration*, the deployment's `Tom2FAPolicy` binding, rather than arguments on the first. Whether declining an enrolment offer is allowed is **not authorable at all**: the server derives it as *optional-or-on-grace* (§5.25). Token lifetime, refresh policy and credential policy are values on the `@CsServerConfig` holder. |
| **CE-ID** Identity | User identity + the app-specific profile extension; per-attribute **public vs encrypted** placement. | **Built on:** `TomUser` / `TomPrincipal` (`tom_core_kernel`, `tombase/security/user_principal_aci.dart`). The profile extension is an **ordinary class carried as JSON via reflection** — public carrier `TomUser.attributes`, encrypted carrier `TomPrincipal.currentContext` via `convertPrincipalToTokenPayload` (§5.24).<br>**Annotations:** `@CsIdentity` on the extension class; `@CsIdentityAttribute(placement: CsIdentityAttributePlacement.public)` / `…encrypted` per field — `placement` is a **required** named argument of the closed `CsIdentityAttributePlacement` enum, never defaulted, because §5.16's fail-safe rule forbids choosing a token-payload arm by omission.<br>**Example:** `@CsIdentity() class EmployeeProfile { @CsIdentityAttribute(placement: CsIdentityAttributePlacement.encrypted, systemOfRecord: 'hr') String? costCenter; }` | None — reuse; both carriers exist. | `@CsIdentityAttribute` carries the **placement**, the field-level access guard (`CsResourceKeyRef`), the **system of record** and whether the attribute is **required** — identity attributes are the prime example of annotation-borne restrictions the code alone cannot state. The attribute's type stays on the member; `@CsIdentity` stays note-only. |
| **CE-MG** SchemaMigration | The SQL migration chain; filename grammar `[<version>]-<description>[@<env>].<ext>`. | **Built on:** `TomDbMigrations` / `TomDbMigrator` / `TomMigrationFileName` / `@TomDbMigrationAdaptor` / `MariadbMigrationAdaptor` (`tom_core_server`, `tomserver/db_migration/`). Migration files are SQL assets; the CodeSpec is the registration class.<br>**Annotations:** `@CsMigration` on the migrations class. Migration **filenames stay strings** (§5.23 exemption). | None — execution substrate is pure reuse, and the **schema-diff engine** proving cumulative migration DDL ≡ the `@CsTable`/`@CsColumn` entity model (the §5.27 named validator check) ships alongside it as `schema_model.dart` / `schema_ddl_reader.dart` / `schema_convergence.dart`. That check is the **only integrity guard** available over the string-exempt migration filenames, so it is the one every CE-MG spec relies on. | `@CsMigration` carries the **datasource**, the **schema** and the artifact **kind** — all three required: datasource + schema *are* the artifact directory path, and generating an initial DDL where an iteration was meant would rewrite a live schema. Artifact **filenames** stay strings (§5.23 exemption 3), which is exactly why the convergence obligation against the `@CsTable` / `@CsColumn` model is a named generation-time validator check rather than a compile-time edge. |
| **CE-JB** BackgroundJob | Scheduled / queued background work. | **Built on:** `tom_core_kernel`'s `tombase/scheduling/` module — `TomJobDefinition`, the `TomSchedule` family, `TomScheduler`, `TomJobStore`, `TomLeaseLock`, `TomJobDispatcher` — over the `TomCommand` / `TomExecutor` / `TomWorker` isolate-pooling substrate. A job pairs a `TomJobDeclaration` (the gap: deployment/ownership envelope) with its own `TomJobDefinition`, whose work body is **form 3b** over the `SCJOST` work-step list, falling back to 3a on the prose work intent where a job lists no steps (§5.29).<br>**Annotations:** `@CsJob`.<br>**Example:** `@CsJob(trigger: CsJobTrigger.cron, cron: '0 3 * * *', maxRetries: 2) class NightlyCleanupJob { final declaration = TomJobDeclaration(jobId: 'nightly_cleanup', serviceUnitId: 'sessions'); ... }` | None — the runtime is reused wholesale from `tom_core_kernel`'s `scheduling` module (scheduler, durable job store, multi-node lease), and the deployment/ownership envelope `tom_core` has no place for is carried by `tom_core_codespecs`'s `TomJobDeclaration` (`jobId` / `displayName` / `enabled` / `environments` / `serviceUnitId` / `readEntities` / `writtenEntities` as `Type` literals, with `targetEntities` and `runsIn(environment)`). Gating is **opt-out** and an empty `environments` list means *every* environment, so a spec states only the exceptions. | `@CsJob` carries the **trigger** plus that trigger's schedule slot (`cron` / `calendar` / `event`), the **retry / backoff / timeout / failure-alert** policy — each lowered onto the reused `TomSchedule` / `TomRetryPolicy` / `TomJobAlert` surface — and the job's **CE-RP targets** as `CsReportRef` consts. A `TomSchedule` is not a const, which is why the annotation carries per-kind strings rather than an instance. |
| **CE-RP** Reporting | A grouped projection over the domain model, delivered as a rendered artifact: dimensions, measures, output columns, charts and runtime parameters. SOM home REPENT (D09 XDS). | **Built on:** `TomReportDefinition` (+ `TomReportDimension` / `TomReportMeasure` / `TomReportColumn` / `TomReportParameter` / `TomReportChart`) and the shared `TomReportResult` envelope (`tom_core_codespecs`, `report_model.dart`), over `TomGroupedSelect` / `TomAggregate` for execution and `TomTabularResult` + the CSV/XLSX/PDF renderers for rendering (`tom_core_server`).<br>**Annotations:** `@CsReport` on the report, `@CsReportColumn` / `@CsReportChart` / `@CsReportParameter` on its members.<br>**Example:** `@CsReport() @CsAuthorize(requirement: role, roles: [salesManager]) final salesByRegion = TomReportDefinition(reportId: 'sales_by_region', sourceEntity: Order, …);` | **Gap filled in `tom_core_codespecs`** — the aggregation grammar and the renderers both exist, but neither offers a place to *author* a dimension or a measure: CE-DB's spec-authorable surface is row-shaped. `report_model.dart` carries the grouped projection and the shared result envelope, with the three generation-time consistency checks (§5.28). The envelope is **adapted onto** the renderers' minimal tabular shape rather than replacing it; its one inherited constraint is that rows stay streamable. Charts are declared, not rendered — an exporter that cannot draw one omits it. | All four CE-RP markers stay note-only: §5.28's 22-row surface maps onto `TomReportDefinition`'s constructor and its dimension/measure members, so the gap was the *classes* and nothing is left for an annotation to carry. Every label is a `CsMessageKey`. **No cross-part target contradicts that**, because only one of the four is a cross-part reference at all: the **source entity** is a `Type` literal on the definition (an entity is already a Dart type, so §5.23 gives it no ref const, and a `Type` costs `tom_core_codespecs` no dependency); the **schedule** is a recurrence expression, not a job reference, since §5.29 realises the CE-JB job *from* it and a job id here would be the second source that rule forbids; **authorization** rides a `@CsAuthorize` beside the marker per §5.15's field-level rule, so the report's access level and permitted roles are that annotation's requirement kind and its typed `CsRoleRef` list. Only the **drill-through** remains an open id string, and permanently: §5.23's locus rule bars a server-side definition from citing a client-owned route. Unlike the four §5.23 exemptions its referent *is* a Dart declaration, so the lost compile-time edge is replaced by a named validator check (`codespecs_derivation_contract.md` §6 check 18). |
| **CE-WF** Workflow *(deferred **permanently**, §4.3)* | Long-running multi-step business process; SOM home DEPRWO (D02). | Mapping-only — reserved kind value; no surfaces. Would require a state-machine / process runtime. | **No substrate, and none to be built** — the survey in **§4.3.1** found DEPRWO is free text with no machine-readable step graph, no driving system needing a durable wait or compensation, and the realistic cases already served by CE-JB jobs + CE-AC actions + CE-DB state. The one gap it found — a one-shot timer schedule — was a small `TomSchedule` subclass, not an engine, and it ships as `TomOnceSchedule` in CE-JB's schedule family (`tom_core_kernel` `tombase/scheduling/schedule.dart`). | Future annotation family undefined; §4.3.1 §6 fixes the **at-least-once, idempotent step body** guarantee any future surface must carry, and §4.3.1 §7 the three conditions that would reopen the decision. |
| **CE-NT** Notification | Outbound user notifications, email first: which types exist, which channels each goes out on, and how user preferences narrow that set. SOM home NM (`introduction_and_scope.dart`). | **Built on:** `TomNotificationType` / `TomNotificationChannelDeclaration` / `TomNotificationPreferences` / `TomNotificationCatalog` (`tom_core_codespecs`, `notification_model.dart`) for the declarations, over `TomMessage` / `TomMessageRouter` / `TomMessageOutbox` / `TomSmtpTransport` (`tom_core_server` `messaging`) for delivery. The catalogue is a **plain annotated model class**.<br>**Annotations:** `@CsNotification` per type, `@CsNotificationChannel` per channel.<br>**Example:** `@CsNotification(body: CsMessageKey('notification.order.shipped')) final orderShipped = TomNotificationType(typeId: 'order.shipped', urgency: high, defaultChannelIds: ['email']);` | **Gap filled in `tom_core_codespecs`** — `messaging` delivers a composed message on an already-chosen channel; the layer that *chooses* had no home, so `notification_model.dart` carries the type ⇄ channel ⇄ preference model (with the `channelsFor` / `deliveryChannelsFor` resolution and the essential-type compliance rule). Transport, SMTP and the durable outbox are pure reuse. | `@CsNotification` carries the **body copy** as a `CsMessageKey` (§5.23) — required, and never inline text. Type id, urgency and default channels are `TomNotificationType`'s own constructor parameters, so none is an argument. `@CsNotificationChannel` stays note-only: `channelId` rides its gap class and is an **open** named value, which is also why no `CsChannelRef` type exists. Its **fallback edge points at a sibling channel** — the SOM authors it on the channel entry ("Alternative channel if delivery fails", beside `retryPolicy`), the substrate holds it as `TomNotificationChannelDeclaration.fallbackChannelId`, and `TomNotificationCatalog.fallbackChainFrom` walks channel → channel. Being **intra-part**, it is a local coordinate rather than a §5.23 cross-part reference (§5.23, the same ruling CE-LO's delta node ids get); it stays an id string, guarded by validator check 17. |
| **CE-LG** AuditLog | Business-relevant audit trail — **distinct from diagnostic logging**; SOM home SAS (D08). | **Built on:** `TomAuditTrail` / `TomAuditRecord` / `TomAuditSink` + the `@TomAudited` declaration (`tom_core_server` `audit`; `doc/audit.md`). The CodeSpec is the *audited* endpoint or repository itself, carrying the framework's own `@TomAudited` alongside the part marker — the CE-SU shape (an ordinary class carrying `@tomService`, marked by `@CsServiceUnit`).<br>**Annotations:** `@CsAudited` on the audited element.<br>**Example:** `@CsEndpoint('customer.save') @CsAudited() @TomAudited(redact: ['iban'])` | None — **pure reuse**. The trail records at two chokepoints no handler can opt out of (`TomEndpointHandler.handleMethodCall`; `TomSqlDatasourceRepository`'s write path), so there is nothing above them for a gap class to hold: the declared half is exactly `@TomAudited`'s three arguments. | `@CsAudited` carries no attributes of its own by design — the declaration rides `@TomAudited`. Retention, log format and the compliance report are **`@CsServerConfig`**, not CE-LG: they are deployment settings on the sink. |

**Readiness classification** (derived from the gap columns):

- **READY — pure reuse, no core gap:** CE-VA, CE-AC, CE-SC, CE-API, CE-SU,
  CE-ER, CE-CF, CE-CC, CE-ID, CE-AZ, **CE-MG** (schema-diff convergence
  shipped), **CE-LG** (the `audit` module records at two chokepoints; the spec
  authors only `@TomAudited`'s declared half), **CE-ST** (the observable family
  ships including its `TomN*` nullable arm, and what an optional field emits is
  settled — §5.4), **CE-DB** (the aggregation grammar ships, and a declared
  transaction scope resolves per flow through the zone-held current transaction —
  §5.13), **CE-AU** (the second factor decides, enrols, offers a choice and
  challenges across all three loci — §5.25), **CE-FM** (the form's load path
  writes each field through the guarded controller write, so a load is not a
  burst of keystrokes — §4.1.1), **CE-EL** (the eleven-kind catalogue maps 1:1
  onto shipped widgets, and an option label resolves through the text-resource
  provider like every other label because the element emits a bundle-labelled
  source class rather than a literal one — §5.18), **CE-DS** (`TomDevicePreferences`
  persists a typed value on every platform, and the user half of the scope is
  supplied by the application through the store's `location` rather than by a
  principal in the API — §5.16), **CE-UP** (the preferences round trip ships end
  to end — kernel contract and codec, server service over its repository, the
  four endpoints, and the Flutter client — with the user bound from the request
  zone rather than from an argument — §5.16).
- **NEEDS EXTENSION — the class to build on exists, a capability under it does
  not:** *empty*. No part waits on behaviour that a shipped class does not yet
  have. Nothing in the matrix is emission-blocking, nothing is lossy, and
  nothing emits code that compiles into an application which cannot run.
- **READY VIA `tom_core_codespecs` — the part reuses `tom_core` plus one
  concrete gap class:** CE-LO (`layout_node.dart`), CE-TX (`message_key.dart`),
  CE-NV (`route_flow.dart`), CE-CL
  (`client_application.dart`), CE-JB (`job_declaration.dart`), **CE-NT**
  (`notification_model.dart`), **CE-RP** (`report_model.dart`). The gap classes
  carry only what `tom_core` has no
  place for; everything below them is reuse. Nothing is open inside this class
  on the code side — CE-LO's container-kind set reconciles against the ACL
  substrate.
- **Deferred:** **CE-WF** alone, and **deferred permanently** — its deferral is
  a decision rather than a waiting state. §4.3.1 records why (no authored input,
  no driving requirement, the realistic cases already covered) and §4.3.1 §7 the
  three conditions that would reopen it.
- **Resolution hazards:** **§4.1.2** names the four `tom_core` symbols whose
  obvious name is wrong or ambiguous, so a citation is written from the source
  rather than from intuition. None of them is a framework gap — the shipped API
  is the authority, and a name that resolves nowhere is a defect in this
  document.

These classifications are sequenced along the **generation slices** of §4.4,
which fixes the slice order, the per-slice readiness gate and the blocking mode
(emission / runtime / verification) of each gap.

#### 4.1.2 Built-on resolution + closed-catalogue verification

Every `tom_core`-family symbol this document names is **resolved against the real
sources** of the five built-on packages (`tom_core_kernel`, `tom_core_flutter`,
`tom_core_server`, `tom_core_d4rt`, `tom_flutter_ui`) — the pillar-(b) claim that
every class a CodeSpec instantiates is a shipped framework class is only worth
what its symbols actually resolve to. The sweep collects every `class` / `enum` /
`mixin` / `extension` / `typedef` declaration in those packages' `lib/` trees and
matches it against the backticked type names in this document.

**Resolution result — every named type resolves.** The bulk are declared
directly in one of the five built-on packages, so the built-on claim holds
verbatim. Exactly three resolve somewhere else, and they are listed by name
rather than counted, because *which* names they are is the whole content:

| Type | Home | Why it is conformant |
|------|------|----------------------|
| `TomRuntime`, `TomClientJwtToken`, `TomServerJwtToken` | `tom_basics` / `tom_crypto`, **re-exported** by the kernel barrel | See the re-export ruling below |

A name that resolves nowhere is a **document defect**, not a framework gap: the
shipped API is the authority, so the cure is always to fix the citation here.

**Re-export ruling.** `tom_core_kernel.dart` re-exports `package:tom_basics` and
`package:tom_crypto` wholesale in its barrel's export list. A CodeSpec that names
`TomRuntime` or `TomClientJwtToken` therefore imports **only**
`tom_core_kernel` — the symbol arrives through the kernel's public surface. So
pillar (b)'s legitimate built-on surface is **the five packages *plus* whatever
they re-export**, and these three names are conformant, not drift. What they are
*not* is kernel-declared: any change to them is a change to `tom_basics` /
`tom_crypto` and must be scoped there.

**Resolution hazards — where the obvious name is wrong.** Four `tom_core`
symbols do not have the shape a reader would guess, so a citation written from
intuition rather than from the source lands on a name that does not exist, or on
the wrong one of several. Each row states the **current** API and the trap it
sets. This is a standing list of names to write from the source, **not** a record
of past corrections — git holds those — and a history-phrasing sweep must not
read it as one.

| The guess | The API | The trap |
|-----------|---------|----------|
| a single container-layout class | `AclContainer` / `AclRow` / `AclComponent` (`tom_flutter_ui/src/advanced_container_layout/acl_container.dart`) | The advanced container layout is a **concept, not a type** — there is no one class to cite. Name the `Acl*` family member meant. |
| a single `TomButton` | `TomButtonBase` (`widget_base/tom_family_base.dart`) + the concrete variants (`TomElevatedButton`, `TomFilledButton`, `TomTextButton`, `TomOutlinedButton`, `TomIconButton`, …) and the `variant` tokens in `TomButtonVariants` (`theme/tom_style_variants.dart`) | There is no single `TomButton`. Button's `variant` per-kind attribute is what selects the concrete class, so a spec that names one class has already lost the attribute. |
| `TomField.initialValue` is readable | Constructor-positional `_initialValue` (`forms/tom_form.dart`) — **no public getter** | The attribute is authorable but the framework exposes **no read-back**, so a derivation that wants to read it back has nowhere to read from. |
| `checkAccess` names one method | `TomAccessControl.checkAccessibility(TomPrincipal?)` + `resolveAuthState` for the kernel evaluation; `TomEndpointHandler.checkAccess` (`tom_core_server`, `endpoint_pipeline.dart`) for the pipeline step | **Two genuinely different methods share the stem.** The kernel evaluation is `checkAccessibility`; the pipeline method really is called `checkAccess` (§5.6.3 / §5.15 use it correctly). Neither is a defect — establish which layer is meant before "fixing" either. |

Two further symbols are plain renames with nothing left to say — the shipped
names `MariadbMigrationAdaptor` (`tom_core_server/src/tomserver/db_migration/mariadb_migration_adapter.dart`,
`implements TomDbMigrator`) and `TomTextField.obscureText`
(`widgets/inputs/tom_inputs.dart`) are what this document cites, and there is
no ambiguity around either.

**Closed-catalogue verification.** The four closed catalogues are checked
entry-by-entry against the real member surface — a closed catalogue is
enforceable only if every entry has a carrier.

- **§5.19 CE-VA — 10 rules: fully carried.** `required`, `email`, `minLength`,
  `maxLength`, `pattern`, `min`, `max`, `minItems`, `maxItems`, `compose` all
  exist on `Validators` (`forms/validation/validators.dart`), and all four
  registry entry points (`resolve`, `resolveOrThrow`, `resolveSpec`,
  `resolveDeclaration`) plus `parseSpec` exist on `TomValidatorRegistry`.
  **Clarification:** `compose` is **not a declarable token** —
  `_registerBuiltins()` registers nine names, and composition is the implicit
  semantics of the comma list (`'required, minLength:8'` *is* a compose). Specs
  must not write `compose:…` in a declaration string.
- **§5.15 CE-AZ — 6 requirement kinds: fully carried.** `TomRoleAccess`,
  `TomGroupAccess`, `TomEntitlementAccess`, `TomResourceKeyAccess`,
  `TomCustomAccess`, `TomGradedAccess` all exist in
  `tombase/security/access_controls.dart`, each carrying the payload member
  §5.15's table names, as do the four argument-free presets `TomNoAccess` /
  `TomPublicAccess` / `TomAuthenticatedAccess` / `TomGuestAccess`. Every one of
  the six requirement kinds has its carrier; none is unresolved.
- **§5.22 CE-LO — id addressing and the container kinds both carried.** The
  5-op delta grammar needs stable node ids, and the ACL substrate has **native
  string id-addressing**: `AclComponent.id` (l. 174), `AclRow.id` (l. 329),
  `AclContainer.aclId` + `parentIdPath` + `idScope`; every slot hint the grammar
  sets (`preferredSize`/`minimumSize`/`maximumSize`, `alignXToKey`/`alignYToKey`
  + axis points and gaps, `group`) is a public final. The delta grammar is
  therefore realisable over the shipped substrate. **The kind set is four** —
  *row*, *column*, *wrap*, *grid* — and four is exactly what a driving SOM can
  author: D09 XDS `ssel-form.layoutDirection` is the closed enum
  *Horizontal/Vertical/Wrap/Grid*. Nothing outside that set is a kind. *padding*,
  *align* and *sizedBox* are container/slot **properties**, not container kinds;
  *stack* and *flex* are neither authorable from any driving section nor
  substantiated by one, so admitting them would be a catalogue entry with no
  input. *row* and *column* are native ACL; *wrap* and *grid* are
  `AclFlowContainer` (`acl_flow.dart`), row-generating containers over the same
  engine, one widget test each. Every kind in §5.22's table names an ACL source.
- **§5.18 CE-EL — 11 kinds, every attribute and every per-kind value carried.** Every kind
  resolves to a shipped widget/field and every base attribute has a carrier
  (`tomId`, `validators`, `authorizer`, `autoValidate`, `form`). The three
  three attributes that need a carrier beyond that base set have one: **`tristate`** by the
  nullable field family `TomFormNullableBoolField` (`TomField<bool?>`, where
  `null` *is* the third state) with the Material `TomFormNullableBoolCheckbox`
  and Cupertino `TomCupertinoFormNullableBoolToggle` concretes reachable through
  `FormFieldFamily.nullableBoolToggle`; and **`minSelections` / `maxSelections`**
  by the `Validators.minItems` / `Validators.maxItems` field rules registered in
  `TomValidatorRegistry` (the §5.18 desugaring boundary — a selection bound is a
  CE-VA rule, not a widget-level cap). The eleventh kind, **FileInput**,
  reuses the shipped `TomFormFileField` family whole, with `allowedExtensions`,
  `maxSizeBytes`, `pickKind` and `autoUpload` all carried and the storage group
  derived from the §5.13.1 column. Each of the three `presentation` values has a
  concrete reachable through `FormFieldFamily`: *link* is `TomFormFileUpload` /
  `TomCupertinoFormFileUpload` (`fileUpload`), *dropzone* is
  `TomFormFileDropzone`, and *thumbnail* is `TomFormFileThumbnail` /
  `TomCupertinoFormFileThumbnail` (`fileThumbnail`). The thumbnail paints the
  file's own content and falls back to the file-kind icon for anything Flutter
  has no codec for, so a non-image file stays authorable under that value. Its
  carrier is a **`tom_flutter_ui` extension, not a `tom_core_codespecs`
  class**, on the same grounds as the `tristate` family: CE-EL is a documented
  catalogue over reused widgets (§5.7.1), so a missing rendering is a missing
  widget.

**Consequence for §4.1.1.** CE-EL is **READY** without qualification — its
catalogue maps 1:1 onto shipped widgets, per-kind values included.
CE-VA and CE-AZ keep their classifications —
CE-VA's catalogue grew from eight rules to ten to absorb the selection bounds.
CE-LO has no substrate-level item and no remaining
dependency: its node-model gap class ships in `tom_core_codespecs`
(`layout_node.dart`).

### 4.2 CodeSpecs output structure — three generated projects + implementation

The generated/derived CodeSpecs code is **split by deployment locus** into three
projects, per the multi-project architecture principle (§12):

| Generated project | Holds | Parts |
|-------------------|-------|-------|
| **`<app>_codespec_shared`** | The contract both sides depend on | CE-API request/response types **and the operation-ref catalogue**, CE-ER error result **+ error-code catalogue**, domain enums referenced by shared contract types, CE-TX message keys, shared CE-VA rules, **CE-AZ role + resource-key catalogues** (§5.23 — cited from both sides), CE-AU reused kernel wire/token types, CE-ID identity-extension declarations, **CE-NT type + channel declarations** (the client renders the preference UI against the same catalogue the server dispatches from), **CE-RP result envelope + parameter shapes** (the client renders a report, the server exports it — §5.28) |
| **`<app>_codespec_client`** | Client-only CodeSpecs | CE-EL, CE-FM, CE-LO, CE-TX (copy), CE-AC, CE-SC, CE-ST, CE-NV (routes + screen-flow), CE-CL, CE-CC, CE-DS, CE-UP (client shape), CE-AU (client flow) |
| **`<app>_codespec_server`** | Server-only CodeSpecs | CE-SU, CE-DB, CE-API (handlers), CE-AZ, CE-CF, CE-UP (persistence), CE-AU (server flow), CE-ID attribute population (in the CE-AU flow), CE-MG (the migrations directory tree + numbered SQL skeleton artifacts — file assets shipped with the server project, not Dart classes, §5.27), CE-JB job definitions + work-body skeletons (§5.29), **CE-LG** audit declarations (the trail is a server chokepoint), **CE-NT delivery** — channel routing and the outbox, the half that never reaches the client, **CE-RP report definitions + execution** (the definition is where the report runs; only its result and parameter shapes cross to the client, §5.28) |

The **Phase-5/6 implementation** fills the skeletons in parallel projects that
depend on the generated ones:

| Implementation project | Depends on | Created in |
|------------------------|-----------|-----------|
| **`<app>_shared`** | `<app>_codespec_shared` | Phase 5 (potentially) |
| **`<app>_client`** | `<app>_codespec_client` + `<app>_shared` | Phase 6 |
| **`<app>_server`** | `<app>_codespec_server` + `<app>_shared` | Phase 6 |

The generation-projection `@Document` (`D13CodeSpecsProjection`) targets this
three-way split — each SOM section's parts route to the shared / client / server
project by the **Locus** column of §4.

### 4.3 Deferred element candidates (mapping-only)

One further element sits outside the 26 active parts. It is a real system
concern, but it is not realised in CodeSpecs: it is **reserved for mapping
only** — it keeps a stable `CE-*` key and a reserved `CodeSpecPart` value so its
SOM section can carry `@CodeSpecKind` **immediately**, and its SOM home is
recorded so the section is authored in the right place. It has **no `Cs*`
annotation, no built-on `tom_core` class and no generated code**.

**CE-WF is decided, not waiting** — permanently deferred on the merits (§4.3.1),
not pending a substrate that might arrive. That is the whole of the deferred set —
every other candidate is active. CE-RP is the closest call among them, and it is
active because a grouped projection has no authoring home in any other part
(§5.28).

| CE | Canonical id | `@CodeSpecKind` value | SOM home section (`@SectionId`) — file | What it will model |
|----|--------------|-----------------------|-----------------|--------------------|
| **CE-WF** | Workflow | `workflow` | `DetailedProcessWorkflow` (`DEPRWO`, in `TargetBusinessProcessModel`) + `BusinessProcessEntry` — `business_process_model.dart` (D02 TOM) | Multi-step process / **workflow-engine** orchestration (state machines, long-running processes). **Deferred permanently** — see §4.3.1: DEPRWO is free text (an activity narrative plus a BPMN-style diagram), no driving system needs a durable wait or compensation, and what a process does need is already served by CE-JB jobs, CE-AC actions and CE-DB state. Basic workflows remain covered by CE-NV (the screen-flow). |

**Homes are wired.** Each home section above already carries a **class-level**
`@CodeSpecKind([CodeSpecPart.<kind>])` — mapping-only, with no CodeSpecs
counterpart. Where a concern shows up in more than one place, the annotation
attaches to the section that best represents the *element* itself, not to every
section that mentions it.

**Promotion criterion.** A deferred candidate becomes an active §4.1 part when a
concrete `tom_core`-family built-on class (or a decided `tom_core_codespecs` gap)
and a `Cs*` annotation are chosen for it. Until then its only surface is the
reserved kind value and the SOM `@CodeSpecKind`. A promoted part **keeps its
reserved enum position** — promotion adds surfaces, it never renumbers the
`CodeSpecPart` enum.

**Promotion is not automatic.** Substrate availability makes a part *decidable*,
not *promoted*. The decision is a second, independent question — §4.3.2 records
how it is answered and what it answered for the three parts that reached that
point together.

#### 4.3.1 CE-WF — workflow substrate survey

CE-WF is the deferred candidate with the largest distance from the framework:
it is the only one whose promotion would require a runtime `tom_core` does not
have in any form. This subsection is the substrate survey behind the §4.3.2
decision — the evidence that CE-WF is deferred **on the merits** rather than on
availability.

**Outcome: permanently deferred.** No process/workflow runtime is to be built,
and **no built-on class is proposed** — so the §4.3 promotion criterion is
deliberately left unmet. The reasoning is below; the conditions that would
reverse it are at the end.

**1 — What the SOM actually asks for.** CE-WF's home is
`DetailedProcessWorkflow` (`DEPRWO`) in `business_process_model.dart` (D02 TOM).
It is a **single free-text `String? content` section**. Its `@ContentHelp` asks
for an activity list with inputs/outputs, decision points with branch conditions,
handoffs, per-step timing and SLAs, exception branches — and *"a BPMN-style
diagram per process"*. `ProcessExceptionHandling` (`PREXHA`) is likewise one free
text field. The structured sections around them (`ProcessCharacteristics`,
`ProcessExceptions`) are `@Form` blocks of **descriptive `String` fields**:
`automationLevel`, `straightThroughRate`, `exceptionRate`,
`exceptionPhilosophy`, `exceptionRouting`, `resolutionSla`, `escalationPath`.

Nothing in D02 carries a step identity, a transition guard, a machine-readable
wait condition or a compensation binding. There is **no authored artefact a
derivation could read**. A promoted CE-WF would have to invent its own input,
which inverts the direction CodeSpecs works in (§8.1: the CodeSpecs surface is
bounded by what the SOM authors). D02 describes processes *for humans to
implement*; it does not declare them for a machine to execute.

**2 — What the driving systems ask for.** The requirement is taken from the
systems that would consume CE-WF, not from a workflow-engine feature catalogue.
`tom_sqm`'s longest-lived concern — payment failure — is specified as a
*configurable retry schedule*, which is a CE-JB job. `tom_provisioning`
delegates dependency ordering and rollback to the cloud provider's own engine
(Terraform / CloudFormation) rather than orchestrating them itself.
`tom_worktracker` advances a status column through direct service calls.
`tom_assistant`'s procedure engine is synchronous and in-memory. Across those
quests, **no document names a durable wait, a human-approval resume, a
compensating transaction or a timer-driven continuation**.

**3 — What the existing substrate already covers.** The parts a long-running
process is usually decomposed into are active and shipped:

| Need | Covered by |
|------|-----------|
| Deferred / recurring step execution | CE-JB — `TomJobDefinition` + `TomScheduler` over `TomJobStore` (`tom_core_kernel`, `tombase/scheduling/`) |
| Durable step state across a restart | `TomJobRun` (`id` stable across restarts, `scheduledFor` as the idempotence key, a JSON-round-trippable `payload`) and CE-DB columns for business state |
| Retry / backoff / permanent failure | `TomRetryPolicy` + the `TomPermanentFailure` mixin |
| Single-fire across a cluster | the `TomLeaseLock` family (fencing tokens) |
| Step-level effects and hand-offs | CE-AC actions, CE-EP operations, `TomMessageOutbox` (`tom_core_server` `messaging`) |
| Who-did-what across a process | CE-LG — the `audit` module's endpoint + repository chokepoints |

`TomMessageOutbox` is the existence proof: durable, retried, multi-attempt
outbound work carried entirely on `TomJobStore` + `TomRetryPolicy`, with no
process engine anywhere. A process expressed as CE-AC actions and CE-EP
operations, whose deferred continuations are CE-JB jobs and whose state lives in
CE-DB columns, is served by parts that are **already active**.

**4 — The one workflow primitive that is not generic scheduling, and its size.**
The distinctively workflow-shaped primitive is the **one-shot absolute deadline**
("fire once at a given instant, then never") — the timer wait. It is not an
architectural hole: `TomSchedule` is a pure `DateTime? nextFireAfter(DateTime
from)` in which `null` already means *"never again"*, so a one-shot schedule is a
small subclass **inside the existing contract**. That the distinctive primitive
is this small is itself an argument against the engine — the capability a
workflow runtime is usually reached for is, here, one class. It ships as
`TomOnceSchedule` in CE-JB's schedule family, alongside cron, calendar, interval
and event.

**5 — The build being declined, costed honestly.** For the record, promotion
would need a gap-class family no existing `tom_core` class can stand in for: a
**process definition** (named steps, guarded transitions), a **durable process
instance** (current step, variables, history) surviving restart on CE-DB, three
**wait kinds** (event / timer / human task) with resume, **per-step failure
semantics** (retry / compensate / halt) and therefore compensation registration,
and an **operations surface** (in-flight instances, stuck instances, manual
intervention). Estimate: on the order of **3–4 focused weeks** for runtime,
persistence, adapters and tests in `tom_core_server`. The larger cost is
permanent, not one-off: **versioning process definitions against in-flight
instances** — a deployed change must decide, for every instance mid-flight,
whether it continues on the old definition or migrates — is a maintenance
surface that never closes. `TomTransactionManager` does not reduce it; it is
in-process two-phase and does **not** resume after a restart. Set against zero
driving requirements, that is the wrong trade.

**6 — Execution guarantee, recorded now so it is not re-litigated.** Were CE-WF
ever built, its step dispatch would ride the CE-JB scheduler and therefore
inherit its guarantee: **at-least-once dispatch, with idempotent step bodies as
the default contract**. A step body must be safe to run twice — after a crash
between "step ran" and "step recorded", the step runs again. Exactly-once is not
offered and must not be implied by a process notation that looks sequential.
Any future CE-WF annotation surface has to make that visible at the step, not
bury it.

**7 — What would reopen the decision.** Promote CE-WF only when **all three**
hold:

1. a driving system specifies a process with a **durable wait** — human approval
   or timer — whose state must survive a server restart;
2. DEPRWO (or a successor section) is given a **machine-readable step/transition
   shape**, so the derivation has an authored input instead of prose and a diagram;
3. that process needs **compensation across steps** that the CE-DB transaction
   boundary cannot cover.

Until then CE-WF stays mapping-only: the reserved `CodeSpecPart.workflow` value
and the SOM `@CodeSpecKind` on `DetailedProcessWorkflow`.

#### 4.3.2 The promotion test, and the three decisions it settled

Availability is not the whole criterion. CE-LG, CE-NT and CE-WF are all decided
against **one** test rather than three separate judgements — substrate
availability alone would have admitted CE-WF, which fails the test below.

**The test is §8.1's: does the SOM author a machine-readable input for this
part?** The CodeSpecs surface is bounded by what the SOM actually authors. A part
whose only SOM input is prose has nothing a derivation can read, and promoting it
would force CodeSpecs to *invent* its input — inverting the direction the whole
method works in. §4.3.1 settles CE-WF by the same test; applying
it to the other two makes the three outcomes one rule instead of three opinions.

| Part | SOM input | Passes §8.1? | Decision |
|------|-----------|--------------|----------|
| **CE-WF** | `DetailedProcessWorkflow` (`DEPRWO`) — a single free-text `String? content` plus a BPMN-style diagram; `ProcessExceptionHandling` likewise free text | **No** — no step identity, no transition guard, no machine-readable wait or compensation | **Deferred permanently** (§4.3.1) |
| **CE-LG** | `AuditAndLogging` (`AUANLO`) with `SecurityEventLoggingPolicy` (`SELP`) and `DataAccessEventPolicy` — `@Form` blocks whose fields map onto `@TomAudited`'s arguments | **Yes** | **Promoted** — `@CsAudited`, server locus |
| **CE-NT** | `NotificationModel` (`NM`) with the `NotificationChannelEntry` / `NotificationTypeEntry` / `UserNotificationPreferences` entry lists | **Yes** | **Promoted** — `@CsNotification` + `@CsNotificationChannel`, shared + server locus |

**CE-LG — why a marker with no attributes is still a part.** The objection to
promoting CE-LG is that `@CsAudited` would be a thin alias over `@TomAudited`,
adding nothing. But thinness is the *design*, not a defect: pillar (a) says a
CodeSpec is an ordinary class built on a `tom_core` class and **marked** by a
`Cs*` annotation, so every marker in the family is thin over the thing it marks —
`@CsForm` over `TomForm`, `@CsJob` over the job declaration. **CE-SU is the exact
structural precedent**: the CodeSpec is an ordinary class carrying the
framework's own `@tomService`, and `@CsServiceUnit` marks it as the part.
`@CsAudited` sits alongside `@TomAudited` in precisely that relation. Without the
marker, an audit declaration would be the one specified concern with no
`@CodeSpecKind` route from its SOM section into generated code — the audit
policy would be authored in D08 and then silently not arrive anywhere.

The boundary the promotion draws: what CE-LG owns is the **declared** half —
which endpoint invocations are auditable, whether the type is audited at all,
which fields are redacted. A SOM band that says reads count lands on the
*endpoint*, not the entity: the substrate never audits a repository read, so
"record who looked" is an invocation-level `@TomAudited()`.
Retention, log format and the compliance report are deployment
settings on the sink and belong to **CE-CF** (`@CsServerConfig`). The recording
itself is automatic at two chokepoints, and is not authored at all.

**CE-NT — why the gap class is the choosing layer, not the transport.**
`tom_core_server`'s `messaging` module is reused wholesale: `TomMessage`,
`TomMessageRouter`, `TomSmtpTransport`, the durable `TomMessageOutbox`.
Re-implementing any of it would be exactly the mistake pillar (b) forbids. What
the transport has no home for is the layer *above* it — it takes an
already-composed message on an already-chosen channel, and the **choosing** is
what a specification authors. That layer is `notification_model.dart` in
`tom_core_codespecs`: `TomNotificationType` ⇄ `TomNotificationChannelDeclaration`
⇄ `TomNotificationPreferences`, resolved by `TomNotificationCatalog`.

The compliance surface is why the resolution lives in the model rather than in
each caller: a user must not be able to silence a security notification.
`TomNotificationType.isEssential` (a type that is not user-configurable, or that
has a mandatory channel) is the single definition of "essential", and
`channelsFor` applies mandatory channels **first**, before every narrowing rule,
so no ordering of preferences can remove them.

**Projection membership.** CE-NT's SOM home `NotificationModel` (NM) is a clean
CodeSpecs subtree — content plus three entry lists, nothing follow-up — so it
joins `D13CodeSpecsProjection` directly, at the shared locus.

CE-LG's home `AuditAndLogging` (`AUANLO`, SAS) needed a split first: it grouped
three bands with different destinations. The split ran the boundary the
paragraph above draws — **declared vs deployed vs performed**:

| Band | Content | Destination |
|------|---------|-------------|
| Declared | `SecurityEventsDefinition` SEEVDE + its five policy forms | **CE-LG** — `@CsAudited` |
| Deployed | `AuditLogFormat` AULOFO + storage / protection / retention / attribute policies | **CE-CF** — `@CsServerConfig` |
| Performed | `ComplianceReporting` COMREP + review / privilege-usage / anomaly / regulatory-support | **Follow-up** — `@FollowUpKind([ops, cmp])` |

The first two are both authored input and both server locus, so they stay
together under `AUANLO`, which is now a purely-CodeSpecs subtree and a
`D13CodeSpecsProjection` root (`locus: server — CE-LG/CE-CF`). Keeping the sink
settings beside the events they configure — rather than re-homing them next to
the other CE-CF content in `TechnicalFrameworkConcept` — is deliberate: a
retention period is only meaningful against the event set it retains, and
`@CodeSpecKind` is list-valued precisely so one subtree can name two parts.

The third band is the only one that leaves. It moved to
`SecurityOperationsFollowUp` (`SCOF`), where the audit *operations* already
belonged — everything in it is a routine run against an existing log rather than
a declaration the derivation can read. D08 reaches it directly, since SAS still
owns the content.

**CE-RP's home needed the same treatment**, on a different boundary. Its home
`PrintAndExportLayout` (`PRLA`, XDS) grouped two bands — **defined vs deployed**:

| Band | Content | Destination |
|------|---------|-------------|
| Defined | `ReportEntry` REPENT + its section / column / chart / filter / schedule / distribution / recipient entries | **CE-RP** — `@CsReport` |
| Deployed | The print settings + `ExportFormatEntry` / `ExportSizeSettings` / `ExportFieldMappingEntry` / `ExportTemplateEntry` | **CE-CF** — `@CsServerConfig` |

Here, unlike CE-LG's, the two bands do **not** stay together: a report definition
is generation input for a different part than the renderer that prints it, and
the renderer settings are environment-wide rather than per-report. So the
*defined* band left, into a new sibling `ReportDefinitions` (`REDF`) directly
under `ExperienceAndInterfaceDesign` — a `D13CodeSpecsProjection` root at the
server locus. `PRLA` keeps its name, because after the move it describes exactly
what it holds: the print and export *layout* settings. D09 reaches both, since
XDS still owns the content.

Two boundaries are easy to draw in the wrong place:

- **`ExportFieldMappingEntry` (`EXFIMA`) is CE-CF, not CE-RP.** It looks like a
  report column, but it is the column layout of one catalogue entry — and its
  container `ExportFormatEntry` is `serverConfiguration`. A CE-RP leaf inside a
  CE-CF container could be neither projected nor hoisted, because a field mapping
  is meaningless apart from the format it maps. The authored projection is
  `ReportColumnEntry`.
- **A `@CodeSpecKind` section inside a `@FollowUpKind` subtree is not itself a
  defect.** `PRLA` still sits under `ExperienceDesignFollowUp`
  (`@FollowUpKind([doc])`), as `UserAssistance` and `MultiLanguageSupport` do
  under theirs. What matters is whether the section must become a **projection
  root** — only then does it have to be reachable from the generation input —
  and *where it sits in the SBP tree is not what decides that*. `PRLA` is the
  case in point: it became a projection root, reached **past** its follow-up
  parent rather than hoisted out from under it, because the parent is a grouping
  of subject matter and the projection's membership follows the part (§8.3).
  Hoisting is one way to make a section reachable; reaching past a root cut one
  level too high is the other, and it is the right one when the root's remaining
  children are genuinely process-delivered.

### 4.4 Generation slices — the per-slice `tom_core` capability contract

A **generation slice** is a set of parts emitted together into the §4.2 projects.
This section fixes **which slices exist, in which order, and what each one needs
from `tom_core` before it can be emitted**. It answers only that question: *what
must already exist for the emitted code to compile*. It does **not** say what
code comes out of a given SOM section — the per-annotation SOM→Dart derivation
contract is a separate, tom_specs-owned concern.

#### 4.4.1 The authored reference graph

Slice order is derived from the **authored** cross-part reference edges — the
§5.23 `Cs*Ref` const citations, the `Type`-literal citations, and the
containment/binding edges the §5.x sections fix. **Derived** back-references
(§5.10/§5.18 element→action hooks; §5.17 CE-SU owned-entity/operation sets) are
computed from the authored edge and impose no ordering of their
own beyond the authored direction.

| Referrer | Referent | Edge | Source |
|----------|----------|------|--------|
| CE-DB column `authKey` | CE-AZ resource-key catalogue | `CsResourceKeyRef` | §5.13, §5.15 |
| CE-DB, CE-API DTO, CE-ST, CE-CF/CC/DS/UP members | domain enums | Dart `enum` type | §4.1 |
| CE-API operation | CE-ER envelope · CE-AZ · CE-TX description | `Result<T>` · `@CsAuthorize` · `CsMessageKey` | §5.14, §5.6.3 |
| CE-ER code | CE-TX message key | `CsMessageKey` on `@CsError` | §4.1.1 CE-ER |
| CE-TX error-copy entry | CE-ER code | `CsErrorCode` | §5.21, §5.23 |
| CE-VA rule failure | CE-TX · CE-ER | `CsMessageKey` / `CsErrorCode` | §5.9, §5.19 |
| CE-SU | CE-DB entities/repos · CE-API operations | `Type` literals · `CsOperationRef` | §5.17 |
| CE-SC | CE-API operation | `CsOperationRef` (hop 2) | §5.3, §5.14 |
| CE-SC | CE-ST · CE-FM (request assembly) | field-source mapping | §5.3 attr 2 |
| CE-SC | CE-ST · CE-NV (response handling) | view-model update · `CsRouteRef` | §5.3 attr 3 |
| CE-AC | CE-SC | `CsCallRef` (hop 1) | §5.3, §5.23 |
| CE-AC | CE-NV | `CsRouteRef` (navigation outcome) | §5.11, §5.23 |
| `@CsTrigger` (CE-AC) | CE-EL | source-element ref (the join's other endpoint) | §5.10 |
| CE-NV `@CsScreenFlow` | CE-AC · CE-FM | `CsActionRef` · form→screen assignment | §5.11 |
| CE-FM | CE-ST · CE-SC/CE-AC · CE-VA · CE-EL | view-model link · submit target `CsCallRef`/`CsActionRef` · `@CsValidation` · field members | §4.1.1 CE-FM, §5.7.2 |
| CE-EL kind *FormHost* | CE-FM | hosted-form ref | §4.1.1 CE-EL, §5.18 |
| CE-ST | CE-EL · CE-FM | binding target (reference-by-id) | §5.4 attr 3 |
| CE-LO slot node | CE-EL · CE-FM | reference-by-id | §5.2, §5.12 |
| CE-CL | CE-NV · CE-EL | `CsRouteRef` (entry route) · included screens, by id | §4.1.1 CE-CL |
| CE-UP | CE-FM | settings-form link | §4.1.1 CE-UP |
| CE-AU | CE-ID · CE-CF | consumes the extension declaration · key material | §5.24, §5.25 |
| CE-NT type declaration | CE-TX | `CsMessageKey` (title + body copy) | §4.3.2 |
| CE-NT delivery | CE-NT declarations · CE-CF | catalogue resolution · transport settings | §4.3.2 |
| CE-RP definition | CE-DB · CE-TX · CE-AZ (· CE-NV) | source entity by **`Type` literal** · `CsMessageKey` labels · authorization by a `@CsAuthorize` beside the marker, whose roles are `CsRoleRef` consts (· drill-through route by **open id string** — the definition is server and a route is client-owned, so §5.23 permits no typed ref and the edge imposes no ordering) | §5.28 |
| CE-JB | CE-DB · CE-SU (· CE-RP) | `Type` literals · ownership (· `CsReportRef`) | §5.29 |
| CE-LG | *(none)* | an annotation over another part's declaration — it cites nothing and rides its host | §4.3.2 |
| CE-MG | CE-DB | schema-convergence check (validator, not a citation) | §5.27 |

**Three genuine cycles.** The graph is **not** a DAG at part granularity:

1. **CE-ER ↔ CE-TX** — an error code carries its message key; the message-key
   registry's error-copy entries carry the error code. Both shared.
2. **CE-AC → CE-SC → CE-NV → CE-AC** — an action names the call it issues, the
   call names the route its response navigates to, the screen flow names the
   action that triggers the transition. All client.
3. **CE-ST ↔ CE-FM and CE-EL ↔ CE-FM** — the view-model binds to form fields
   while the form links its bound view-model type; a *FormHost* element names
   the form it hosts while the form's members are elements. All client.

Because CE-AC, CE-SC and CE-NV already share cycle 2, and CE-FM reaches CE-SC
and CE-AC (submit target) while CE-NV reaches CE-FM (screen assignment), cycles
2 and 3 merge. The **strongly connected components** of the authored graph are
therefore:

- **SCC-A = {CE-ER, CE-TX message keys}** — shared;
- **SCC-B = {CE-ST, CE-EL, CE-FM, CE-AC, CE-SC, CE-NV}** — client;
- every other part is its own singleton component.

The three operational server parts are singletons for reasons worth stating, since
each looks cyclic at first glance. **CE-LG** cites nothing at all. **CE-NT**'s two
halves cite in one direction only — delivery resolves the declarations, never the
reverse — and they are separate emission units per §4.4.2's corollary, so the edge
is across slices rather than within a component. **CE-RP ↔ CE-JB is not a cycle**:
only CE-JB → CE-RP is authored (`CsReportRef`); the definition merely *names* its
schedule, and per §5.17 a derived back-name is computed during derivation and
carries no ordering of its own.

**Validated property: no SCC spans two §4.2 projects.** This matters, because the
two constraints have different force. Dart permits **circular imports between
libraries of the same package**, so an SCC co-emitted into one project compiles;
Dart forbids **circular dependencies between packages**, so a cycle crossing the
shared/client/server boundary would be unresolvable. The §4.2 split is
reference-cycle-safe, and the *shared → {client, server}* arrow is an absolute
constraint no slice order may bend.

#### 4.4.2 The forward-reference rule

**Decision: strict ordering, with slice boundaries cut at SCC boundaries.**
Declared-but-unimplemented stubs are **rejected**.

- **Why not stubs.** A stub would author the same referenceable identity twice —
  once as a placeholder in the earlier slice, once for real in its owning part —
  which breaks the "declare once, cite everywhere" invariant that §5.23 and §5.3
  make load-bearing. Worse, a stub `CsRouteRef` is type-identical to a real one,
  so the **compiler — the designated §4.2 cross-part integrity checker (§5.23) —
  could no longer distinguish a satisfied reference from an unsatisfied one**.
  Stubs would disable the exact mechanism the typed-ref family exists to provide.
- **Why strict ordering alone is not enough.** At part granularity the graph has
  the three cycles above, so no linear order over the active parts exists. Ordering
  parts is impossible; ordering *components* is not.
- **The rule.** The slice **is** the strongly connected component (or a union of
  components at the same topological rank, grouped for readability). Slice order
  is a topological order of the graph's condensation. **Within** a slice, mutual
  reference is legal and expected. **Across** slices the rule is absolute: *no
  slice may reference a symbol a later slice emits* — achievable by construction,
  because every backward edge has been absorbed into a component.

**Slice order is a hard constraint, not a preference.** Two independent
mechanisms enforce it: within a project, a cross-slice backward reference is a
Dart compile error at the citing const (§5.23); across projects, it is an
unresolvable package cycle. Neither is recoverable by generation order, so a
slice order that violates the rule cannot be made to work by emitting more
carefully — it must be re-cut.

**Corollary — a part may be split across slices, an SCC may not.** Where §4.2
already splits a part by locus (CE-API contract vs handlers, CE-TX keys vs copy,
CE-AZ catalogue vs modifier applications, CE-AU shared/client/server, CE-UP
client shape vs server persistence, CE-ID declaration vs population, CE-NT
declarations vs delivery, CE-RP result envelope vs report definition), the halves
are separate emission units and sit in different slices. This is what keeps
SCC-A and SCC-B single-project.

**A second, weaker split: an annotation-only part follows its hosts.** CE-LG
authors no declaration of its own — `@CsAudited` marks a declaration another part
emits. It is therefore emitted wherever its host is, which for its two chokepoints
means two slices (the CE-DB write path and the CE-API handler). Unlike a locus
split this is not a §4.2 boundary; the rule is simply that a marker cannot precede
the thing it marks.

**Generation order is not runtime bootstrap order.** This section orders
*symbol availability at compile time*. The runtime start-up order (CE-CF resolved
before the server boots, CE-MG applied before the first repository call, CE-AU
establishing a principal before any CE-AZ evaluation) is a different sequence and
is not constrained here.

#### 4.4.3 The ordered slices

Seven slices. "Built on" names the `tom_core`-family classes the slice's parts
instantiate or extend (§4.1); "Gate" is §4.4.4.

| # | Slice | Parts emitted | Project (§4.2) | Built on (`tom_core`-family) |
|---|-------|---------------|----------------|------------------------------|
| **1** | **Shared const catalogues** | domain enums (`@CsEnum`); CE-AZ role + resource-key catalogues; **SCC-A** = CE-ER error codes + CE-TX message keys | `<app>_codespec_shared` | `TomTextResourceProvider` (`tom_core_kernel`); the CE-ER envelope + field-error types as plain annotated classes authored here (no framework counterpart); plain Dart `enum`s. The role/resource-key catalogues are plain const holders over `TomRoleAccess.roles` / `TomResourceKeyAccess.key` string spaces. |
| **2** | **Shared contract** | CE-API operation catalogue + request/response DTOs; shared CE-VA rules; CE-ID identity-extension declaration; CE-AU shared wire/token types; **CE-NT type + channel declarations** — cite slice 1 only (`CsMessageKey` copy) and the client renders the preference UI against the same catalogue the server dispatches from; **CE-RP result envelope + parameter shapes** — cite slice 1 (labels, domain enums) and are shared between the rendering client and the exporting server, so they must land with the contract whose operation returns them. The envelope is not itself a wire DTO — its rows stay streamable (§5.28), so what crosses the wire is the operation's own reflection-first response shape | `<app>_codespec_shared` | `TomApi` / `TomApiEndpoint<R,Q>` / `TomRemoteApis` (`tom_core_kernel`); `Validator<T>` / `ValidationResult` / `Validators` / `FormValidationError` (`tom_flutter_ui`); `TomUser` / `TomPrincipal`, `TomBearerAuthentication` / `TomClientJwtToken` / `TomAuthenticationMessage` / `TomAuthenticationResult` (`tom_core_kernel`); `TomNotificationType` / `TomNotificationChannelDeclaration` / `TomNotificationPreferences` / `TomNotificationCatalog`, `TomReportResult` / `TomReportResultSection` / `TomReportParameter` (`tom_core_codespecs`) |
| **3** | **Server persistence & configuration** | CE-DB entities/columns/repositories; CE-MG migration artifact tree; CE-CF; **CE-RP report definitions + their column/chart members** — cite CE-DB for the source entity (within-slice) and slices 1–2 for labels and result shape; a declaration *over* the persistence model rather than server behaviour, and cited by both slice 4 and slice 7, so it must precede them; **CE-LG on the CE-DB write path** — a marker rides the declaration it annotates | `<app>_codespec_server` | Tom persistence model + CRUD/MariaDB repositories + `TomQueryBuilder` (`tom_core_server`); `TomDbMigrations` / `TomDbMigrator` / `TomMigrationFileName` / `@TomDbMigrationAdaptor` / `MariadbMigrationAdaptor` (`tom_core_server`); `TomBaseServerConfiguration` + `TomServerConfigResourceProvider` (`tom_core_server`); `TomReportDefinition` / `TomReportColumn` / `TomReportChart` (`tom_core_codespecs`); `TomAuditTrail` / `TomAuditRecord` / `@TomAudited` (`tom_core_server` `audit`) |
| **4** | **Server behaviour** | CE-SU units **co-emitting** the CE-API handler methods; operation-level CE-AZ; CE-AU server flow + CE-ID attribute population; **CE-NT delivery** — channel routing and the outbox, citing the slice-2 declarations it dispatches from and slice-3 CE-CF for transport settings; it belongs here and not in 7 because the service units that raise a notification cite it, which is legal *within* a slice but would be a forward reference from 4 to 7; **CE-LG on the CE-API handler** — the second chokepoint, riding its host as in slice 3 | `<app>_codespec_server` | `@tomService` / `TomApiImplementation` / `TomEndpointHandler` / `TomEndpointRouting` / `TomServer` / `TomComponentReference` (`tom_core_server`); `TomAccessControl` family + `TomGradedAccess` + `TomPrincipal` (`tom_core_kernel`), `TomResourceGrant` / graded authorization (`tom_core_server`); `TomAuthenticationServer` + the app's `TomAuthenticationService`, `TomServerJwtToken` (`tom_core_server`); `TomMessage` / `TomMessageRouter` / `TomMessageOutbox` / `TomSmtpTransport` (`tom_core_server` `messaging`) |
| **5** | **Client interaction core** | **SCC-B** = CE-ST + CE-EL + CE-FM + CE-AC + CE-SC + CE-NV; field-level CE-AZ (`authorizer`); CE-TX copy; CE-AU client login flow | `<app>_codespec_client` | `TomObservable` / `TomObject<T>` / `TomClass` / `TomList` / `TomMap` (`tom_core_kernel`) + `TomObservingWidget` / `ValueListenableObserver` (`tom_core_flutter`); `TomScreenElementsProvider` + the `Tom*` element/widget family, `TomForm<T>` / `TomFormChildContainer` / `TomField<T>`, `TomAction` / `TomActionController` / `TomActionTrigger` / `TomActionTransaction` / `TomActionContext`, `TomPageRoute<T>` / `TomNavigationDestination`, `TomText` / `TomLabelBase`, `TomGradedAccess` (`tom_flutter_ui`); `TomServerEndpoint<T,R>` / `TomServerCallSpecs` / `TomServerChannel` (`tom_core_kernel`) |
| **6** | **Client presentation & shell** | CE-LO; CE-CL; CE-CC; CE-DS; CE-UP client shape | `<app>_codespec_client` | `AclContainer` / `AclRow` / `AclComponent` (`tom_flutter_ui`) rendered via `TomObservingWidget` (`tom_core_flutter`); `TomBaseClientConfiguration` / `TomSetting<T>` / `TomClientConfigurationStore` + the `TomProperty<T>` family (`tom_core_flutter`) over `TomConfigResourceProvider` (`tom_core_kernel`); `TomUserPreferencesClient` (`tom_core_flutter`) over `tomUserPreferencesApi` + `TomUserPreferenceDto` / `TomUserPreferenceCodec` (`tom_core_kernel`); `TomClientApplication` (`tom_core_codespecs`) for CE-CL. |
| **7** | **Server operational** | CE-UP server-side typed access; CE-JB job definitions + work-body skeletons | `<app>_codespec_server` | `TomCommand` / `TomExecutor` / `TomWorker` isolate-pooling substrate (`tom_core_kernel`); `TomUserPreferences` over `TomUserPreferenceRepository` (`tom_core_server`) for the user-preference store — the persistence is the framework's, so this half cites no slice-3 repository |

**Why this order (the across-slice edges it satisfies).** 1 has no outbound part
edges at all — every `Cs*Ref` catalogue bottoms out here. 2 cites only 1. 3 cites
1 (enums, `CsResourceKeyRef`) and 2 (the CE-RP definition's result envelope). 4
cites 1, 2, 3. 5 cites 1 and 2 **and never 3 or 4** — the client project depends
on shared only. 6 cites 5 (and 1). 7 cites 3 and 4. Slices 5–6 and 3–4–7 are two
independent chains hanging off 1–2; they may be generated in either interleaving,
but never before 2 completes.

**The slices cover the active parts exactly.** Recomputed against §4.1's
twenty-six active parts rather than read off either table: slice 1 emits the
domain enums, the CE-AZ role and resource-key catalogues, CE-ER and the CE-TX
message keys; 2 the CE-API contract, shared CE-VA, the CE-ID declaration, the
CE-AU wire types, the CE-NT declarations and the CE-RP shared shapes; 3 CE-DB,
CE-MG, CE-CF, the CE-RP definition and CE-LG over CE-DB; 4 CE-SU, the CE-API
handlers, operation-level CE-AZ, CE-AU server, CE-ID population, CE-NT delivery
and CE-LG over CE-API; 5 SCC-B, field-level CE-AZ, CE-TX copy and CE-AU client;
6 CE-LO, CE-CL, CE-CC, CE-DS and the CE-UP client shape; 7 CE-UP persistence and
CE-JB. That is all twenty-six, plus the member kind `domainEnum`, which is not a
part and rides slice 1 because everything else cites it.

**The invariant is per emission unit, not per part.** "Each part in exactly one
slice" is the wrong check and would fail on the table above by design: the eight
parts §4.4.2's corollary splits by locus, plus annotation-only CE-LG, each occupy
two or three slices. What must hold is that **every active part appears in at
least one slice, and every emission unit — a part, or one locus-half of a split
part, or a marker together with its host — appears in exactly one.** That is the
property anything walking this table needs, and it is what the recomputation
above verifies.

#### 4.4.4 The slice readiness gate

**Gate (as stated).** A slice is generatable **iff every part it emits is READY**
in the §4.1.1 matrix. A slice containing a NEEDS-EXTENSION or MISSING part is
blocked, and the gate names the part that blocks it.

**Refinement — four blocking modes.** Applied literally the gate is too coarse
to act on, because the §4.1.1 gaps do not all block the same thing. Each gap is
therefore classified:

- **E — emission-blocking.** The skeleton cannot be written at all (no class to
  extend, no annotation to apply). The slice is hard-blocked.
- **E(lossy) — emission is possible but drops declared detail.** The slice
  generates; a spec using the uncarried attribute renders without it.
- **R — runtime-blocking.** The skeleton emits and compiles (often as a §4.1.1
  form-3 body); the capability is missing at execution time.
  The slice is generatable; the *application* is not yet runnable.
- **V — verification-blocking.** Emission and runtime are fine; a named validator
  check cannot run.

| # | Slice | Non-READY parts | Mode | Unblocked by |
|---|-------|-----------------|------|--------------|
| **1** | Shared const catalogues | — (CE-ER, CE-TX and the CE-AZ catalogues are READY: the markers take their `CsErrorCode` / `CsMessageKey` / `CsRoleRef` / `CsResourceKeyRef` parameters) | — | — |
| **2** | Shared contract | — (CE-API, CE-VA and CE-ID are READY; the CE-NT declarations and the CE-RP result envelope emit against their shipped `tom_core_codespecs` gap classes). No untyped cross-part edge remains here: CE-RP's targets are settled (§5.28 — a `Type` literal, a recurrence expression, a `@CsAuthorize` beside the marker, and one locus-barred route id validator-checked by design). A CE-NT channel's fallback also emits as a string, but is **intra-part** and so was never in §5.23's scope — likewise settled and validator-checked | — | — |
| **3** | Server persistence & configuration | — (CE-DB, CE-MG, CE-RP's definition and CE-LG are all READY: the aggregation grammar and the schema-diff engine ship, a declared transaction scope resolves per flow through the zone-held current transaction (`tom_core_server` `transactions/transaction_manager.dart`), the grouped-projection gap class ships, the `audit` module is pure reuse, and the definition's outbound targets are settled (§5.28) — a `Type` literal for the source entity, a recurrence expression for the schedule, and a `@CsAuthorize` beside the marker for authorization) | — | — |
| **4** | Server behaviour | — (CE-SU, CE-AU, CE-NT delivery and CE-LG are all READY: **CE-AU's second factor is complete across the trio** — `Tom2FAPolicy` decides requirement level, mechanism preference order and grace, `Tom2FAEnrolmentSupport` enrols with `TomTotp2FAService` generating the secret and the `otpauth://` URI, `TomAuthenticationResult` carries the enrolment state and the method list, and `Tom2FAFlowPanel` runs the client half (§5.25); the `messaging` router, SMTP transport and durable outbox ship; and the audit trail records at a chokepoint no handler can opt out of) | — | — |
| **5** | Client interaction core | — (CE-SC / CE-AC / CE-FM take their ref parameters and CE-EL carries every per-kind attribute. A `choice` / `multiChoice` field's **per-value** copy resolves through the text-resource provider, because the slice emits a `TomEnumSelectableSource` / `TomEnumNameSelectableSource` rather than a literal option list (§5.18, `codespecs_derivation_contract.md` §3.5.2). The text-controller write path is guarded throughout — `_setControllerText` is the only write, `set()` routes through it and `reset()` has no override (`tom_flutter_ui` `forms/tom_form.dart`, `:1245`)) | — | — |
| **6** | Client presentation & shell | CE-CC is **READY** (one holder, `tom_core_flutter`'s `TomBaseClientConfiguration`) and CE-LO is unblocked. **CE-DS is READY too**: `TomDevicePreferences` (`tom_core_flutter` `tomclient/preferences/device_preferences.dart`) persists a typed value through a backend chosen per platform, and its scope is its store's `location` — so the user half of the key is an address the application supplies, not a capability the substrate lacks (§5.16). **CE-UP is READY as well**: the preferences round trip ships end to end — `tomUserPreferencesApi`'s four authenticated endpoints over `TomUserPreferenceDto`, implemented by `TomUserPreferencesServer` over `TomUserPreferences`, called by `TomUserPreferencesClient` — and both ends resolve their URIs from that one declaration | — | — |
| **7** | Server operational | CE-JB is **READY** on both sides — the declaration envelope, scheduler runtime, job queue, multi-node lease and declarative registration have all landed, §5.29 names the owning class for each of the four scope parts, both target kinds are compiler-checked (`Type` literals for CE-DB, `CsReportRef` consts for CE-RP), and the SOM per-job declaration list `SCJOB` supplies the authored surface | — | — |

**Critical-path consequence.** The `Cs*` annotation family with its constructors,
the §5.23 `Cs*Ref` types and the `tom_core_codespecs` gap classes have all
landed, so **every slice is emission-clear, with no exception**: each skeleton can be
written, and no declared attribute is dropped on the way. The last
lossy one — a `choice` / `multiChoice` element's per-value copy — resolves
through the text-resource provider now that slice 5 emits a bundle-labelled
source class instead of a literal option list (§5.18).

**No `tom_core`-side blocker remains, in any slice or any mode.** Every slice
emits, compiles, and runs against the substrate. The two user-scoped parts of
slice 6 were the last to clear, and they cleared for different reasons:
**CE-DS** persists through `TomDevicePreferences` on every platform, and the
(user, device) key it is defined by is completed by the store's location — an
address the generated client is given, not a behaviour it waits for; **CE-UP**
persists through the shipped preferences round trip, whose user half is bound
from the request zone, so the generated client is given no user to pass. **Slice
5 has no runtime blocker either**: a programmatic write to a generated text
field — the path a CE-ST binding and a CE-FM load both take — goes through the
field's guarded controller write and is not processed as a keystroke.

**No verification blocker stands besides.** Two edges emit as id strings rather
than as typed consts, and both are settled end states rather than deficits:

- A **CE-NT channel's fallback** at slice 2 points at a sibling channel, so it is
  intra-part, and §5.23 rules it a local coordinate the family never governed.
- A **CE-RP column's drill-through** at slice 3 points at a client-owned route
  from a server-owned definition, which §5.23's locus rule permanently forbids a
  typed ref for.

Each is validator-checked by design
([codespecs_derivation_contract.md](codespecs_derivation_contract.md) §6
checks 17 and 18) rather than by default. CE-RP's other three targets are not
references at all once shaped correctly (§5.28).

**No emission question is open besides.** What an *optional* SOM attribute emits
is settled per part: CE-ST takes the `TomN*` nullable observable arm keyed on the
attribute's requirement level (§5.4), CE-DB a plain nullable Dart field keyed on
its storage nullability (§5.13). Every slice therefore passes its readiness gate
in all four modes, which is what §10 records by holding no open work.

#### 4.4.5 Four placements a topic-first reading gets wrong

Slices are cut by **reference direction and locus**, not by topic. Four
placements therefore sit where a reading organised by subject matter would not
put them; each is decided by an authored edge, given below.

| The topic-first placement | Where the part actually sits | The edge that decides it |
|---------------------------|------------------------------|--------------------------|
| CE-DB in the **first** slice, with domain enums | CE-DB is in slice **3** | A CE-DB column's `authKey` is a `CsResourceKeyRef` from the CE-AZ catalogue (§5.13, §5.15) — a backward reference. CE-DB is also server-locus, and a slice may not span shared + server (§4.2 arrows). |
| Three ordered client slices: *state and calls* → *UI* → *navigation and shell* | The six parts are **one** slice (SCC-B) | Cycle 2 (CE-AC→CE-SC→CE-NV→CE-AC) and cycle 3 (CE-ST↔CE-FM, CE-EL↔CE-FM) admit no linear order. Any three-way cut has CE-SC citing `CsRouteRef` two slices later (§5.3 attr 3) and CE-ST citing its CE-EL/CE-FM binding target one slice later (§5.4 attr 3). |
| **Auth/identity** (CE-AU, CE-ID) as a **late** slice, after the client | CE-ID and CE-AU's shared types are in slice **2**; CE-AU's server flow in **4**; its client login flow in **5** | CE-ID's locus is shared + server (§5.24) and CE-AU's wire/token types are shared (§4.2). A shared part emitted after a client slice inverts the §4.2 dependency arrow. Neither part cites anything client-side. |
| **Operational** (CE-MG, CE-JB) as one final slice | CE-MG is in slice **3** beside CE-DB; only CE-JB (with CE-UP persistence) is last | CE-MG's only relationship is the CE-DB schema-convergence check (§5.27); separating them by four slices would defer the check for no reason. CE-JB genuinely depends on CE-DB and CE-SU (§5.29), so it is last. |

The **broad direction** — shared vocabulary → shared contract → server → client →
shell → operational — does follow the edges; it is the granularity that a
topic-first reading misjudges. The client tier does not decompose, and locus
overrides subject matter for the two shared-locus parts (CE-ID, CE-AU) and the
one server-locus part (CE-DB) above.

#### 4.4.6 The authoring order

§4.4.3 orders **emission**: it says what must already be in the compiler's world
for a slice's code to compile, and it is written for a producer that holds a
whole slice at once. §1.1.1 pillar (e) puts a second producer in front of that
one — an **authoring agent**, one prompt pass at a time, holding one area's
extract. That producer needs a **total order it can walk**, and the slice table
does not give it one: within a slice nothing is ordered, and within an SCC
nothing *can* be by construction (§4.4.2). This subsection supplies the total
order. It is **derived** from §4.4.3, not stated beside it — the two rules below
take the slice table and the §4.4.1 edge graph as their only inputs, so a change
to either changes the authoring order rather than silently disagreeing with it.

**The unit is the emission unit, and a component is one step.** §4.4.3 fixes that
the slice invariant holds *per emission unit* — a part, one locus-half of a split
part, or a marker together with its host. An **authoring step** is one emission
unit, with two collapses: an SCC is one step (its members cannot be ordered, so
they are authored together by §4.4.7), and units §4.4.3 records as **co-emitted**
are one step (CE-SU with the CE-API handler methods it carries). Steps are
numbered 1–31 across the whole run; the number is the ordinal §1.1.1's `csgen<n>`
carries.

**Rule 1 — the slices are serialised 1, 2, 3, 4, 7, 5, 6.** §4.4.3 leaves 3–4–7
and 5–6 free to interleave, both hanging off 1–2. They are serialised
server-chain-first for two reasons. Each project's work stays **contiguous**, so
a run can stop cleanly after step 22 with a complete shared + server pair and a
client project that has not been started, rather than with three half-projects.
And the shared contract is exercised by a real consumer (slice 4's handlers)
**before** the client is written against it, so a contract defect surfaces while
the cheaper half is in flight. Any other topological order of the slices is
legal by §4.4.2; this one is the fixed choice, so that the ordinals are stable.

**Rule 2 — within a slice, topological order tie-broken by §4.1 catalogue
position.** Repeatedly take the lowest-catalogue-position unit whose within-slice
predecessors are all already authored. The inputs:

- **Edges** are §4.4.1's authored edges restricted to units in the slice, plus
  the within-slice edges §4.4.3's own slice cells state (slice 4's *service units
  cite the notification delivery they raise*), plus §4.4.2's two structural
  edges: a marker follows its host, and a locus-half follows nothing but its own
  citations.
- **Position** is the row index of the part in §4.1's 26-row catalogue — the one
  ordering this document already fixes as authoritative and permanent (`CE` is
  never reused or renamed). A **component** takes the position of its
  earliest-listed member; the member kind `domainEnum` is not in the catalogue
  and takes position 0, which is what §4.4.3 means by "rides slice 1 because
  everything else cites it".

The tie-break is deliberately *not* a new ordering: §4.1's catalogue and
[codespecs_derivation_contract.md](codespecs_derivation_contract.md) §2.1 N8's
document order are the only two orders this design has, and this one reuses the
first because its elements are parts, not sections. §4.4.8 reuses the second
because its elements are sections.

**The 31 steps.**

| # | Authoring step (emission unit) | Slice | Placed by |
|---|--------------------------------|-------|-----------|
| **1** | Domain enums (`@CsEnum`) | 1 | position 0 |
| **2** | **SCC-A** — CE-ER codes + CE-TX message keys (§4.4.7) | 1 | CE-TX (4) |
| **3** | CE-AZ role + resource-key catalogues | 1 | CE-AZ (13) |
| **4** | CE-VA shared rules | 2 | CE-VA (5) |
| **5** | CE-API operation catalogue + request/response DTOs | 2 | CE-API (8) |
| **6** | CE-ID identity-extension declaration | 2 | CE-ID (21) |
| **7** | CE-AU shared wire/token types | 2 | edge: consumes the CE-ID declaration (§5.24) |
| **8** | CE-NT type + channel declarations | 2 | CE-NT (25) |
| **9** | CE-RP result envelope + parameter shapes | 2 | CE-RP (26) |
| **10** | CE-DB entities/columns/repositories | 3 | CE-DB (10) |
| **11** | CE-CF server configuration | 3 | CE-CF (15) |
| **12** | CE-MG migration artifact tree | 3 | CE-MG (22) |
| **13** | CE-LG over the CE-DB write path | 3 | marker follows host (step 10) |
| **14** | CE-RP report definitions + column/chart members | 3 | edge: source entity `Type` literal → CE-DB (§5.28) |
| **15** | CE-ID attribute population | 4 | CE-ID (21) |
| **16** | CE-AU server flow | 4 | edge: CE-AU → CE-ID (§5.24) |
| **17** | CE-NT delivery — routing + outbox | 4 | edge: the service units that raise it cite it (§4.4.3) |
| **18** | CE-SU units **co-emitting** the CE-API handler methods | 4 | CE-API (8), after step 17 |
| **19** | Operation-level CE-AZ | 4 | marker follows host (step 18) |
| **20** | CE-LG over the CE-API handler | 4 | marker follows host (step 18) |
| **21** | CE-UP server-side typed access | 7 | CE-UP (17) |
| **22** | CE-JB job definitions + work-body skeletons | 7 | CE-JB (23) |
| **23** | **SCC-B** — CE-ST + CE-EL + CE-FM + CE-AC + CE-SC + CE-NV (§4.4.7) | 5 | CE-EL (1) |
| **24** | CE-TX copy | 5 | CE-TX (4) |
| **25** | Field-level CE-AZ (`authorizer`) | 5 | marker follows host (CE-EL, step 23) |
| **26** | CE-AU client login flow | 5 | CE-AU (20) |
| **27** | CE-LO layout trees | 6 | CE-LO (3) |
| **28** | CE-CC client configuration | 6 | CE-CC (16) |
| **29** | CE-UP client shape | 6 | CE-UP (17) |
| **30** | CE-DS device settings | 6 | CE-DS (18) |
| **31** | CE-CL client application | 6 | CE-CL (19) |

**Coverage — all twenty-six active parts, recomputed against §4.1 rather than
read off the slice table.** Once: CE-LO (27), CE-VA (4), CE-SU (18), CE-DB (10),
CE-CF (11), CE-CC (28), CE-DS (30), CE-CL (31), CE-MG (12), CE-JB (22), and the
six SCC-B members CE-EL / CE-FM / CE-AC / CE-SC / CE-ST / CE-NV (23). Twice or
three times, per §4.4.2's locus and marker splits: CE-ER (2), CE-TX (2, 24),
CE-API (5, 18), CE-AZ (3, 19, 25), CE-UP (21, 29), CE-AU (7, 16, 26), CE-ID
(6, 15), CE-NT (8, 17), CE-RP (9, 14), CE-LG (13, 20). That is 26, plus step 1's
`domainEnum`, which is a member kind and not a part.

**Three steps a slice-only reading would place differently**, each decided by an
edge rather than by the tie-break:

- **17 before 18.** CE-NT delivery is authored before the service units, because
  a unit that raises a notification cites it — the same edge that keeps delivery
  out of slice 7 (§4.4.3). Catalogue position would have put CE-SU first.
- **6 before 7, and 15 before 16.** CE-ID precedes CE-AU in both loci, because
  CE-AU consumes the identity extension (§5.24). Catalogue position (CE-AU 20,
  CE-ID 21) would have inverted both.
- **14 last in slice 3.** The CE-RP definition follows CE-DB by a `Type`-literal
  citation, and follows CE-MG and CE-LG only by position — which is why its step
  moves if the catalogue does, and steps 10–14's *relative* correctness does not
  depend on that.

#### 4.4.7 Authoring a strongly connected component — declare, then wire

Two steps above are components rather than single units: **step 2 (SCC-A)** and
**step 23 (SCC-B)**. Inside a component there is no order — that is what makes it
a component — and §4.4.2 rejects the stub that would manufacture one. An emitter
resolves this implicitly by holding the whole component in memory and writing it
in one act; an authoring agent cannot. The procedure is that implicit act made
explicit, in **two passes over the component**:

- **Pass 1 — declare.** Emit every declaration in the component: its identity
  const in the owning catalogue class (§5.23), its `tom_core`-family superclass,
  and its members. Cross-part references **to earlier steps are written
  normally** — their referents exist — so a CE-SC operation citation
  (`CsOperationRef`, step 5), a label `CsMessageKey` (step 2) and a
  `CsRoleRef` / `CsResourceKeyRef` (step 3) are all filled in pass 1. Only
  **intra-component** reference slots are left unwritten.
- **Pass 2 — wire.** Fill the intra-component slots, now that every referent in
  the component has been declared exactly once.

What each component defers to pass 2:

| Component | Deferred to pass 2 |
|-----------|--------------------|
| **SCC-A** | `@CsError`'s `messageKey` (`CsMessageKey` → CE-TX) and the CE-TX error-copy entry's `errorCode` (`CsErrorCode` → CE-ER) |
| **SCC-B** | `CsCallRef` (CE-AC → CE-SC), `CsActionRef` (CE-NV screen flow → CE-AC), `CsRouteRef` (CE-SC response handling and CE-AC navigation outcome → CE-NV), `CsElementRef` (CE-ST binding target, `@CsTrigger` source element), `CsFormRef` (CE-EL *FormHost*, CE-ST binding target, CE-NV form→screen assignment) |

**Why this and not the alternatives.** It keeps §4.4.2 literally true rather than
approximately: at the end of pass 1 the component contains **no intra-component
references at all**, so no reference precedes its referent at any moment. And it
authors each referenceable identity **exactly once** — the invariant §5.23 and
§5.3 make load-bearing, and the one a forward-declaration stub breaks. Authoring
the component as a single undivided act is the other correct answer and is
rejected only on context budget: SCC-B is six parts and the largest step in the
run.

**Two consequences that bind the todo tree.** The component **does not compile
between the passes**, so the pass pair is **one** §1.1.1 `csgen<n>` todo, never
two — a step that ends between the passes ends in a state no gate can accept.
And pass 2 is **checkable rather than trusted**: after it, every `Cs*Ref` in the
component resolves to a generated declaration, which is
[codespecs_derivation_contract.md](codespecs_derivation_contract.md) §6 check 2
(`CsReferenceResolutionCheck`) — a check the trio already runs, applied to the
component instead of to the finished project.

#### 4.4.8 From authoring steps to section todos

§4.4.6 orders **steps**; §1.1.1's L3 orders **specification elements**. The two
are different granularities and the mapping between them has to be stated,
because `@CodeSpecKind` is list-valued (§9.1): one SOM section can feed several
areas, and those areas can sit in different steps.

**The L3 unit is an extract entry, and an extract entry is a (section, area)
pair.** Routing is per area, so a section routed to three areas contributes to
three extracts (§1.1.1) and yields three L3 todos — not one todo that spans three
areas. This is what makes the area prefix (`csfm*`, `csapi*`) name a coherent set
of work rather than an arbitrary slice of it.

**Within a step, entries run in SOM document order.** The order is
[codespecs_derivation_contract.md](codespecs_derivation_contract.md) §2.1 N8's —
the order the contributing sections appear in the document, depth-first — taken
across **all** of the step's parts together rather than per part, so a step that
reads two extracts (step 18: CE-SU and the CE-API handler half) interleaves them
by document position. Reusing N8 here is the point: the emitted members of a
class are already in that order, so a step's todos and its output run the same
way, and no second ordering has to be kept consistent with the first. Where two
entries share a document position — one section routed to two areas of the same
step — the tie-break is the areas' §4.1 catalogue position, the same tie-break
§4.4.6 uses.

**A split area's entries are split with it.** A section routed to an area whose
emission units sit in different steps yields **one L3 todo per unit that emits
something for it**: an operation section yields a catalogue todo in step 5 and a
handler todo in step 18. Neither todo is complete on its own, and neither is
blocked by the other beyond the step order that already separates them.

**Ordinals are allocated contiguously per step, in step order.** An area's `<n>`
therefore runs 1..k over the area's *first* step's entries, then continues over
its next step's — so `csapi*` iterates the contract half before the handler half
without the prefix having to know that CE-API is split, and no two todos of an
area collide. Nothing here is chosen at allocation time: given §4.4.6's step
table and the document, the whole L3 numbering is determined.

## 5. Gap analysis — taxonomy vs existing coverage

Per part: the existing `tom_core`-family coverage and the design that covers the
part (detailed in the referenced §5.x subsections).

| Code | Existing coverage | Gap & design |
|------|-------------------|--------------|
| CE-EL | UI Elements; semantic + widget-behaviour layers | **Reuse — no new class.** Two-step **"semantic type → concrete widget"**: `@CsElement` (semantic, over `TomField<T>`) + `@CsWidget` (concrete widget binding, over the `TomButtonBase` variants / `TomText` / inputs) in the client project; covered by `TomScreenElementsProvider` + the existing `Tom*` `tom_flutter_ui` element/widget family + the form semantic classes — a documented catalogue over reused classes, **not** a `tom_core_codespecs` class (§5.7.1). Attribute surface + closed catalogue contents: **§5.18** (field base + 11-kind catalogue + semantic→widget two-step). |
| CE-FM | `TomForm`; annotated fields | **Subforms** (nested/repeated) mirror the SOM `@Form` field-group structure: `@CsForm` (reuse, no gap class) over `TomForm<T>` + `TomFormChildContainer` (nested/repeated subform fan-out) + `TomField<T>`; SOM `@Form` field-group → nested `TomForm` / repeated `TomFormChildContainer`; client project (§5.7.2). |
| CE-LO | Layout, separated for manual override | An **override-separable layout-node** model: the §5.2 two-layer id-addressed node model grounded on the `tom_flutter_ui` ACL substrate — container node ← `AclRow`/`AclContainer` (kinds `row`/`column`) and `AclFlowContainer` (kinds `wrap`/`grid`), slot node ← `AclComponent` (native `id`/`referenceKey`/alignment-by-key + per-slot hints), reactive rebind via `TomObservingWidget` (`tom_core_flutter`); the override-separable node model lives in `tom_core_codespecs`; client project (§5.12). Attribute surface + override-delta grammar: **§5.22** (closed container-kind + slot attribute sets + closed 5-op id-addressed override deltas). |
| CE-TX | Texts implied in UI/RC | Placeholder/help derived **directly from SOM content** (`@ContentHelp`, `@Form` hint, doc-comments); error texts keyed by CE-ER codes. `@CsText` (reuse) over `TomText`/`TomLabelBase` (field `labelText`/`hintText`/`descriptionText`, `resolveErrorMessage`) bound to `TomTextResourceProvider`/`TomConfigResourceProvider` (kernel i18n backend, dot-notation keys); the CodeSpecs-only **message / i18n-key model** lives in `tom_core_codespecs`; spans shared (message keys) + client (copy) projects (§5.8). Attribute surface + error-copy keying: **§5.21** (message-key attribute set + locale model + error copy keyed by CE-ER codes). |
| CE-VA | Rules-from-RC | **No new class — provided as Dart code** (§3 first-level-implementation latitude). **Field rules vs form (cross-field) rules**, each traceable to a requirement: `@CsValidation` umbrella + `@CsFieldRule` (single-field, over `Validator<T>`/`ValidationResult`) + `@CsFormRule` (cross-field, over `FormValidationError`); realised as **standalone validator classes with validation methods, or validation methods on the `TomForm` subclass**, reusing `Validators`/`TomValidatorRegistry` (`tom_flutter_ui`); `ValidationError.errorKey` ties error copy to CE-TX/CE-ER; spans client + shared projects (§5.9). Attribute surface + declaration language: **§5.19** (closed 10-rule field catalogue + `TomValidatorRegistry` declaration grammar + form-rule scope/reference/error-key). |
| CE-AC | UI Actions | **Reuse — no new class.** Actions have a full implementation in `tom_flutter_ui`. **Trigger taxonomy** — one action, several triggers: `@CsAction` (reuse) over `TomAction<Ctx,Undo>` + `TomActionContext`/`TomActionController`/`TomActionTransaction`; `@CsTrigger` names one invocation, with `TomActionTrigger` the widget-gesture realization; a triggered action drives the §5.3 CE-AC→CE-SC edge; client project (§5.10). Attribute surface: **§5.20** (action set + closed 5-kind trigger attribute surface: user-gesture / in-form event / lifecycle / server-event / condition). |
| CE-SC | Kernel transport (`TomServerEndpoint` client side) | Explicit **action → endpoint** edge; client request assembly / response handling: two-hop typed-reference chain CE-AC→CE-SC→CE-API (§5.23); `@CsServerCall` over `TomServerEndpoint<T,R>`/`TomServerCallSpecs`/`TomServerChannel` (client) (§5.3). Attribute surface: **§5.14**. |
| CE-API | Server Interface | Narrowed to the §7 contract (POST-only, operation-named, 50x-only, structured error); first-class operation name + typed request/response: `@CsEndpoint` (reuse+narrow) over `TomApi`/`TomApiEndpoint`/`TomRemoteApis` (kernel) + `TomEndpoint`/`TomEndpointHandler`/`TomEndpointRouting`/`TomServer` (server), narrowed to POST + operation-name + typed `T`/`R` + CE-ER Result envelope; server project (§5.6.1). Attribute surface: **§5.14**. |
| CE-SU | `@tomService` class marker (`tom_core_server`) | **No new class.** **Logical grouping of operations within one server** = a named cohesive set of operations + owned entities/repositories, ideally an independent **closure**: modelled as ordinary **(abstract) classes** carrying the `@tomService` / `TomApiImplementation` server-API mapping annotations (`@CsServiceUnit` first-class marker over the `@tomService`/`TomApiImplementation`/`TomComponentReference`/`scanClasses` grouping); boundary = §5.1 (owned-aggregate primary), id `<RootAggregate>Service`; server project (§5.6.2). Attribute surface: **§5.17** (authored id/root-aggregate/process-adjust/context vs derived entities/repos/operations). |
| CE-DB | Rich SOM `DataModel`/entities/attributes | The **access object model** (repositories/DAOs + query/filter/transaction per service unit): `@CsTable`/`@CsColumn`/`@CsRepository` over the `tom_core_server` persistence model; attribute surface in §5.13. **Placement: server-only** — the persisted entity lives only in `<app>_codespec_server`; the client sees CE-API request/response shapes (shared, the DTO role) + the CE-ST view-model (§5.4), never a DB entity (§5.13). |
| CE-ST | UI Data Model | Typed view-model state distinct from the DB model: `@CsViewModel` (reuse, no gap class) over `TomObservable`/`TomObject<T>`/`TomClass`/`TomList`/`TomMap` (`tom_core_kernel`) bound via `TomObservingWidget`/`ValueListenableObserver` (`tom_core_flutter`), client project; CE-ST↔CE-DB separation drawn (§5.4). |
| CE-NV | `TomPageRoute` + destinations; route uniqueness assumed by the substrate | Route identifiers + a **screen-flow model**: `@CsRoute` (reuse) over `TomPageRoute<T>` + the `tom_navigation` destination widgets (`TomNavigationDestination`, `tomId`/`authorizer`) for the route ids; `@CsScreenFlow` combines the interaction scenarios into **screens** — which **form** is assigned to which screen, whether it **replaces** the current screen or **overlays** it as a **popup**, and which CE-AC action triggers navigation with a **conditional** target (success → confirmation or back to the previous screen; error / validation-error → error display). The stable route-id + screen-flow model is a CodeSpecs-only class in `tom_core_codespecs`, authored from the SOM screen route map (`SCRTMP`, D09 XDS); client project (§5.11). |
| CE-AZ | Auth/authz spec type | The requirement per operation from the SOM `AuthorizationRequirementSpec` (AZREQ) embedded at each modifier site, citing the `SecurityAccessSpecification` catalogues: `@CsAuthorize` (reuse, no gap class) — a **modifier** on `@CsEndpoint` carrying a `TomAccessControl` (role/group/entitlement/resource-key/custom/graded four-state), enforced by the pipeline's `checkAccess`; server project (§5.6.3). Attribute surface: **§5.15** (a ten-arm `@OneOf` — six attribute-bearing `@Case` kinds + four attribute-less presets — plus the depth-bounded graded level list AZGRD/AZLVL and field-level authKey). |
| CE-ER | **no framework counterpart** — authored in `<app>_codespec_shared` | The one canonical **success-or-error envelope** (§7): `@CsError` over a **gap class pair** authored per application — a result type (success/failure arms, explicit `success` wire discriminator) and an error type (`code` — the CE-TX↔CE-ER join key — plus `message`, field-level errors, retryability, severity); every CE-API operation returns it; shared project. |
| CE-CF | `TomBaseServerConfiguration` (`tom_core_server`) | **Server/system config only** — client-machine, device and user settings are CE-CC/CE-DS/CE-UP. `@CsServerConfig` (reuse, no gap class) over `TomBaseServerConfiguration`/`TomServerConfigResourceProvider` (`tom_core_server`), server project; one config-value concept realised as four owner-keyed parts (CE-CF/CE-CC/CE-DS/CE-UP) (§5.5). Attribute surface + precedence: **§5.16** (per-scope spec-authorable split + opt-in most-specific-owner-wins cross-scope precedence). |
| CE-CC | `TomBaseClientConfiguration` + `TomSetting<T>` (`tom_core_flutter`) | Model **per-machine client configuration** — settings scoped to the machine a client app runs on (endpoints, feature toggles, device options) (§5.16, §11). |
| CE-UP | `TomUserPreferences` (`tom_core_server`) / `TomUserPreferencesClient` (`tom_core_flutter`) over `tomUserPreferencesApi` (`tom_core_kernel`) | Model **user settings** — user-scoped, server-persisted preferences that follow the user (§11). Both faces carry the same six-method store surface, and neither takes a principal: the server binds the user from the request zone (§5.16). |
| CE-DS | `TomDevicePreferences` (`tom_core_flutter`) | Model **device settings** — user-specific settings of a user-owned device, persisted on the device (§11). The store is scoped by its `location`, so the signed-in user is one segment of the address rather than a parameter in the API, and separating accounts is the **application's** act (§5.16). |
| CE-CL | `TomClientApplication` (`tom_core_codespecs`) | Enumerate the **client applications** (Flutter app, CLI, other server) with their platform targets, entry route and screen set — each owns its CE-CC and hosts CE-DS/CE-UP. |
| CE-AU | `TomAuthenticationServer` + `TomAuthenticationService` contract (`tom_core_server`); `TomBearerAuthentication`, `TomClientJwtToken`, `TomAuthenticationMessage`/`TomAuthenticationResult` (`tom_core_kernel`) | **Pure reuse — no gap class.** The mechanics (two-token JWT model, login orchestration, stateless Bearer verification, wire attachment, token store) are framework-fixed; the spec-authorable surface is the service binding, enabled methods/flows, the second-factor policy binding, per-client login flow, and session/token/credential policies. The app's `TomAuthenticationService` implementation **is** the `@CsAuth` CodeSpec, and its `Tom2FAPolicy` binding is a second `@CsAuth` declaration (§5.25). |
| CE-ID | `TomUser` + `TomPrincipal` (`tom_core_kernel`); both token-payload extension carriers exist in the substrate (public `attributes`, encrypted context) | **Reuse — no new class.** **App-declared identity-attribute extensions** over the fixed principal core: `@CsIdentity` (declaration holder) + `@CsIdentityAttribute(placement: CsIdentityAttributePlacement.public)` / `…encrypted` per extension; the profile extension is modelled as an **ordinary class**, directly reusable and carried as **JSON via reflection** in the user profile; shared (declaration) + server (population in the CE-AU flow) (§5.24). |
| CE-MG | `TomDbMigrations` orchestrator + `TomDbMigrator` contract + `TomMigrationFileName` grammar + `@TomDbMigrationAdaptor` discovery + `MariadbMigrationAdaptor` (`tom_core_server`) | **Pure reuse — no gap class.** The engine (directory walk, filename grammar, numeric ordering, env filtering, applied-version verification) is framework-fixed; the spec-authorable surface is the SQL artifact set — initial DDL, base/seed data, iteration scripts — in the `<databaseMigrationsDirectory>/<datasource>/<schema>/` tree, `@CsMigration`-marked; the schema-convergence check against the CE-DB entity model is a named validator check (§5.27). |
| CE-RP | `TomGroupedSelect` / `TomAggregate` / `TomGroupedRow` (`object_persistence/grouped_query.dart`) over `TomQueryBuilder` + `TomQuerySentenceCompiler` + the crud repositories; `TomTabularResult` and the CSV/XLSX/PDF renderers (`export`); delivery via ordinary CE-API endpoints (`tom_core_server`) | **Two gap classes** in `tom_core_codespecs` (`report_model.dart`): `TomReportDefinition` — the **grouped projection** a specification authors (dimensions, measures, output columns, charts, parameters, delivery channels), which the substrate can execute but has nowhere to author because CE-DB's spec surface is row-shaped; and `TomReportResult` — the **shared** result envelope, authored here rather than extending the server-side `TomTabularResult` so the client can read it, and adapted one way onto the tabular shape when exporting (§5.28). |
| CE-JB | `TomCommand` / `TomExecutor` / `TomWorker` isolate-pooling substrate (`tom_core_kernel`) — the work-body engine that runs a unit of work off the request thread | **Job definitions over the operational model**: `@CsJob` names a trigger (`cron \| calendar \| event`) + a work definition + target refs (CE-DB entities / CE-RP reports the job acts on) + retry/backoff/timeout/failure-alerting, distinct from request-driven CE-API. The **work body is form 3b** over the `SCJOST` work-step list, falling back to 3a on the prose work intent where a job lists no steps (§5.29); server project. The job base class (`TomJobBase`), scheduler runtime, job queue, multi-node locking and the pluggable-execution seam (`TomJobDispatcher`) are all reused from `tom_core_kernel`'s `scheduling` module; `tom_core_codespecs` carries only the deployment/ownership envelope `TomJobDeclaration` (`job_declaration.dart`). `tom_process_monitor` is reference only, not a `tom_core`-family class (§5.29). |

### 5.1 CE-SU service-unit boundary criterion

**Decision.** A service unit's boundary is **owned-aggregate primary, process-cohesion
secondary, bounded-context as the outer bound** — a three-level *precedence*, not
three competing options.

1. **Primary — owned aggregate (D03 IMO).** A `@CsServiceUnit` owns exactly one
   *aggregate*: a root entity plus the entities that have no independent lifecycle
   outside it. It owns every CE-DB table and repository over those entities and
   every CE-API operation whose **primary written entity** is in the aggregate.
   The aggregate is **read, not judged**: every entity states its aggregate in
   `DAENT-CLAS.aggregateRoot`, which holds the root's `DAENT-IDEN.entityName`
   and which a root fills with its own name. "Is this a root?" is therefore the
   string equality `aggregateRoot == entityName`, and "which entities are in
   this aggregate?" is a group-by over one authored field.
2. **Secondary — process cohesion (D02 TOM).** Where two aggregates are always
   mutated inside one business transaction/process they may be **merged** into one
   unit; where one aggregate's operations divide into clearly independent processes
   the unit may be **split**. Process cohesion only *adjusts* the primary grouping,
   and the adjustment is authored, per entity, in
   `DAENT-CLAS.serviceUnitAggregate` — the root whose unit serves this entity when
   that is not its own. Several aggregates naming one root is a merge; one
   aggregate whose entities name different roots is a split. Empty means no
   adjustment, so the **effective aggregate** of an entity is
   `serviceUnitAggregate` where set and `aggregateRoot` otherwise.
3. **Outer bound — bounded context (D06 ATS).** A service unit never spans two
   architecture modules / bounded contexts. The context is the coarse container that
   caps any merge. Like the aggregate, the cap is **read, not judged**: the contexts
   are declared once, as `BoundedContextEntry` (`BCE`) entries in D06 ATS, and an
   entity names one of them in `DAENT-CLAS.boundedContext`, which carries
   `refersTo: ['BCE.contextName']`. So "same context?" is string equality against a
   registry key rather than a comparison of two free-text spellings, and a name that
   matches no declared context fails instance validation instead of silently
   producing a second cap that blocks a legitimate merge.

**Identification.** A unit's stable id is its root-aggregate name + `Service` (e.g.
`OrderService`, PascalCase). That id is the `@CsServiceUnit` identity and the
`<app>_codespec_server` grouping key (§4.2). The unit set is exactly the distinct
effective aggregates, so how many units exist is counted, not decided.

**Ownership & cross-unit access.** A unit owns {its aggregate entities (CE-DB),
their repositories (CE-DB), the operations that write them (CE-API + CE-AZ)} — an
entity belongs to the unit of its effective aggregate, and an operation to the unit
of `SVOPE.primaryDataEntity`'s entity. A read spanning units is assigned to the unit
owning its **primary** entity; a unit **never** reaches another unit's repository
directly — cross-unit data flows through the owning unit's CE-API. This keeps each
unit's persistence private and makes the boundary enforceable at generation time.
All three consumers — CE-SU, CE-DB, CE-API — resolve ownership through the same two
fields, so they cannot disagree about where an entity lives.

**SOM feed.** owned aggregate ← `DAENT-CLAS.aggregateRoot` (D03 IMO) ·
merges/splits ← `DAENT-CLAS.serviceUnitAggregate` (D03 IMO, authored from D02 TOM
process cohesion) · outer bound ← `DAENT-CLAS.boundedContext` (D03 IMO), resolving
against `BCE.contextName` (D06 ATS) ·
operation inventory ← D07 IFS, joined by `SVOPE.primaryDataEntity`. Join key is
the SOM `@SectionId` (§8).

### 5.2 CE-LO layout-node representation

**Decision.** `@CsLayout` is a **two-layer, id-addressed tree**: a *generated base
layout* deterministically derived from the SOM, plus a separate *override layer* of
id-keyed deltas that survives regeneration.

**Node model.** The layout is a tree of `LayoutNode`s of two kinds:

- **Container node** — a layout primitive of the closed kind set
  (`row`, `column`, `wrap`, `grid` — §5.22 derives the set from D09 XDS's
  `layoutDirection` enum) carrying only *layout* properties (main/cross-axis
  alignment, spacing, grid column count, padding, constraints) and an ordered
  list of children. It carries **no** semantics. Padding, alignment and fixed
  sizing are container/slot **properties**, not kinds of their own.
- **Slot node (leaf)** — a **reference by stable id** to the semantic element it
  positions: a CE-EL element id or a CE-FM (sub)form id. The slot holds only
  per-slot layout hints (flex, alignment). The element's definition and behaviour
  stay in CE-EL/CE-FM — the layout tree never embeds them. This is the clean
  semantics ↔ layout separation.

**Node identity.** Every node carries a **stable node id**: a slot id derives from
its referenced element/form id; container ids are stable synthetic ids preserved
across regeneration by structural matching.

**Override survival.** Two layers, never one hand-edited
tree:

1. **Generated base** — rebuilt from the SOM every build (default: a single
   `column` of the form's fields in SOM order). Never hand-edited.
2. **Override layer** — a separate, human-authored patch expressed as
   **id-addressed deltas** (reparent a slot, change a container's direction, set a
   flex, insert/remove a container), *not* a replacement tree. On regeneration the
   base is rebuilt and the deltas are re-applied by id. A **new** SOM element appears
   in the base and flows to its default slot until an override moves it; a delta
   whose target id **no longer exists** is surfaced as a reconcile warning, never
   silently dropped. Manual layout thus survives model changes non-destructively.

**SOM feed.** base structure ← D09 XDS screen/form layout (+ D05 ISC screen naming);
the override layer is authored, not derived. Join key = `@SectionId` (§8).

### 5.3 CE-SC server-call model + action→endpoint edge

**Decision.** CE-SC is the **client-side server call** an action issues. It is a
*reuse* part (no gap class): `@CsServerCall` is a thin annotation over the surveyed
kernel transport classes, and the action→endpoint coupling is an
**explicit two-hop reference edge**: CE-AC action → CE-SC server call → CE-API
operation. `@CsServerCall` lives in the **client** project (`<app>_codespec_client`,
§4.2); the operation contract it targets lives in the **shared** project (CE-API).

**Built on (client-side kernel transport).** `@CsServerCall` wraps the surveyed
`tom_core_kernel` classes (`server_connection.dart`) — the client half of the §7
contract:

| Surveyed class | Role for `@CsServerCall` |
|----------------|--------------------------|
| `TomServerEndpoint<T extends Object, R extends Object>` | The typed call itself: request type `T`, response type `R`, `send(T) → Future<(R, TomServerCallError?)>`. `T`/`R` are the CE-API operation's request/response DTOs (shared). |
| `TomServerCallSpecs` | The wire spec: `method` (**POST** per §7), `url` (the operation route), `headers`, `includeBearerAuthentication` (CE-AU token). One per call. |
| `TomServerChannel` | The transport channel (`prepareCall(specs)`), shared across calls to one server. |
| `TomServerCall` | The single prepared/in-flight call `channel.prepareCall(specs)` produces; not modelled directly — an implementation detail of `TomServerEndpoint.send`. |

The **transport identity** of a `@CsServerCall` is fully determined by
*(operation name → `TomServerCallSpecs` url + POST) + (request DTO `T`, response
DTO `R`) + (error → CE-ER)* — it adds **no** new transport type. The **call-site
surface** (request assembly, response handling, error surfacing, the trigger
edge, call options — attributes 2–5 below) is genuinely client-authored content
with no home in CE-API.

**Boundary (non-overlap rule).** **CE-API is the operation** — the contract
(operation name, typed request/response DTOs in the shared project, the CE-ER
envelope) plus the server handler; authored **once per operation** (shared +
server, §4.2). **CE-SC is a client call-site binding of an operation** —
authored **once per call site**; N call sites : 1 operation (client, §4.2). A
`@CsServerCall` may **never author or re-declare a contract member**
(operation-name semantics, `T`/`R` shapes, error codes) — it only *cites* them.
Anything both sides need is CE-API/shared; anything call-site-contextual is
CE-SC/client.

**Attribute surface (`@CsServerCall`).**

1. **`operation`** — the CE-API operation it targets (**the outbound edge**;
   §7 operation-name-carries-intent, all POST). A typed **`CsOperationRef`**
   const (§5.23) — the CE-API operation catalogue declares each operation's ref
   once (§5.14); CE-SC cites the const, so a dangling or renamed operation is a
   compile error.
2. **request assembly** — how the typed request `T` is built from client state: the
   CE-ST view-model / CE-FM form fields that populate each request field. Declared as
   a mapping (request field ← view-state/form source), not imperative code.
3. **response handling** — where the typed response `R` goes on success: the CE-ST
   view-model it updates and/or the CE-NV navigation it triggers (cited by its
   `CsRouteRef`, §5.23).
4. **error handling** — the structured error path: a `TomServerCallError` maps to the
   canonical CE-ER `Result`/`ErrorResult` envelope; error **codes** resolve to copy
   through the CE-TX message-key registry (MSGKR, §5.21), so client copy and server
   error codes share one source; and 5xx are transport failures, never application
   outcomes. All three are §7's server-contract decisions, which CE-SC obeys rather
   than restates.
5. **call options** — the `TomServerCallSpecs` knobs that are spec-authorable:
   `includeBearerAuthentication` (CE-AU), extra headers, timeout/redirect policy.
   Channel selection is deployment config (CE-CC), not per-call.

**Attributes 2–4 are the three handling roles, and they share one authoring
home** — the `ServerCallStepEntry` (`SVCST`) list on the ISC step that issues the
call. Each step states one thing that happens and carries a **required `role`** —
`assembleRequest`, `handleResponse`, `handleError` — saying which of the three it
belongs to, so a role's steps are an ordered list and each of the three emitted
methods is form 3b over its own (`codespecs_derivation_contract.md` §3.5.7).
Three attributes and one list, because they are three phases of one call: an
author writing "the customer's stored address fills the shipping fields" should
have to decide which of three *roles* it is, not which of three sections it lives
in. Before `SVCST` the three were a declared surface with no authoring home, and
the three bodies could only throw the issuing step's one sentence apiece.

**The action→endpoint reference edge (the core deliverable).** The edge is a
**two-hop, typed-reference chain**, each hop a typed const reference (§5.23 —
the stable id lives inside the const; never a string, never an embedded
definition), mirroring the CE-LO slot→element separation (§5.2):

```
CE-AC @CsAction ──triggers──▶ CE-SC @CsServerCall ──operation──▶ CE-API @CsEndpoint
     (client)                       (client)                           (shared)
```

- **Hop 1 — action → server call.** A CE-AC action (button / in-form event /
  condition trigger, §5.10) that "does something server-side" references the
  `@CsServerCall` it issues by its typed `CsCallRef` const (§5.23). An action may issue zero or one
  server call (pure-navigation / pure-UI actions issue none); a server call is issued
  by one or more actions. The action owns *when* (trigger); the server call owns
  *what* (operation + request/response). This keeps the CE-AC trigger taxonomy (§5.10)
  independent of transport.
- **Hop 2 — server call → API operation.** `@CsServerCall.operation` holds the CE-API
  operation's `CsOperationRef` (§5.6.1, §5.23). For an **internal** operation the
  compiler-checked contract (§4.2, shared project) guarantees the referenced operation
  exists and fixes `T`/`R`; a rename of the operation surfaces as a compile error at
  the CE-SC reference, not a silent runtime 404.
- **Outbound case.** An **outbound integration call** (the SOM `IOE`/`INTEG`
  sections, which carry `serverCall` only) targets an **external** operation whose
  contract is externally defined — there is no own CE-API for it; the external
  operation's DTOs are **mirrored in the shared project** and the CE-SC call site is
  authored exactly like the internal case.

**Directionality & why by-reference.** References point client→shared (§1.1 pillar (b):
dependency arrows point at the shared contract). The client `@CsServerCall` depends on
the shared CE-API operation; CE-API never depends back on any client. Modelling both
hops as typed const references (§5.23, not containment) means an action, its server call, and the
operation each have exactly one authoring home and can be reused (several actions → one
call; several calls → one operation) without duplication — the "author once, reference
everywhere" invariant CE-TX/CE-ER and domain enums already follow.

**SOM feed.** CE-SC is derived from the four **D05 ISC step entries** —
`MainScenarioStepEntry` MNSST, `AlternativeStepEntry` ALST, `ExtensionStepEntry`
EXTST and `ScenarioStepEntry` SCNST — each carrying
`@CodeSpecKind([CodeSpecPart.action, CodeSpecPart.serverCall, CodeSpecPart.navigation])`.
The three kinds sit on **one** section rather than on three because an interaction
step *is* at once the actor action, the call it issues and the transition it
causes; splitting them would ask an author to write the same step three times.
All four are reachable from `D13CodeSpecsProjection`, so they are the generation
input and not merely an authoring home (§8.5). Each of the four carries the
`ServerCallStepEntry` (`SVCST`) list that states the call's three handling roles;
the list hangs off the step rather than standing on its own because a call has no
identity apart from the step that issues it. UI actions
(`ScreenActionEntry` SCRAC, `ScreenElementAction` SCELAC, `ComponentActionEntry`
CMAC) carry `action` alone — they are the CE-AC trigger side of hop 1, and a
screen action that reaches the server does so through the step entry that
describes the interaction. The **outbound** case is authored outside the
projection: `InterfaceOperationEntry` IOE and `IntegrationPointEntry` INTEG carry
`serverCall` alone and describe a **foreign** contract, which is mirrored rather
than generated from (§8.5, CE-API row).

**The operation edge is authored, and it is what selects the part.** Each of the
four step entries carries a `serverOperation` form field citing
`SVOPE.operationName` — the same shape as the CE-NV edge beside it, where
`ScreenActionEntry.behavior.navigateTo` cites `SCRTEN.routeId`. Hop 2's
`CsOperationRef` is read off that member, so `codespecs_derivation_contract.md`
§3.5.7's **required** `operation` argument has an authored source and is not
recovered from a sentence. A step's prose (MNSST's `systemResponse` and its
siblings' equivalents) says what the system does *for a reader*; the member says
which operation it calls *for the generator*, and `codespecs_derivation_contract.md`
§2.4 **B8** is satisfied because nothing has to read the former to obtain the
latter.

The field is **optional**, and its absence is meaningful rather than a gap: a
step that names no operation reaches no server, so CE-SC is emitted **exactly
where the member is present**. That is what makes the routing decidable — the
question "does this step call the server?" is answered by a member's presence
instead of by classifying prose, and the two failure modes the prose reading had
are gone. Two steps whose wording differs can no longer resolve to two
operations or none, and renaming an operation in the SVOPR registry now breaks
the citation loudly (`refersTo` targets are resolved against the live model)
instead of silently unhooking every step that referred to it by wording.

`ServerOperationEntry.operationName` is the target that citation resolves to. It
is a form field rather than the entry's headline because an operation name is a
**token of the specified system** — the sole wire identifier under the §7
contract, which carries no method and no path — and so belongs with `routeId`,
`actionId` and `entityName` rather than with the documentation-only entries cited
by `@sectionId`. It is admissible beneath a list entry under
`tom_specs_model_rules.md` §8's rule-4 registry-key exemption precisely
*because* the step entries cite it.

### 5.4 CE-ST view-model model over TomObservable/TomObject

**Decision.** CE-ST is the **typed view-model state** a client screen observes and
binds to — distinct from the persisted entity model (CE-DB). It is a *reuse* part
(no gap class): `@CsViewModel` is a thin annotation over the surveyed kernel
observable classes plus their tom_core_flutter binding adaptors. `@CsViewModel`
lives in the **client** project (`<app>_codespec_client`, §4.2); it is a purely
client-side concern with **no** `tom_flutter_ui` dependency — its substrate
is `tom_core_kernel` (the observable model) + `tom_core_flutter` (the widget/
`ValueListenable` bridge).

**Built on (kernel observable model + tom_core_flutter bridge).** `@CsViewModel`
wraps the surveyed classes; every one is a `tom_core`-family class per §1.1:

| Surveyed class | Package | Role for `@CsViewModel` |
|----------------|---------|--------------------------|
| `TomObservable` | `tom_core_kernel` (`tom_observable.dart`) | The observer-pattern base: `addObserver`/`removeObserver` (weak-ref), `notifyObservers`, `mute`/`unmute` batch. Every view-model *is-a* `TomObservable`. |
| `TomObject<T>` | `tom_core_kernel` (`tom_observable_objects.dart`) | A single typed observable cell (`get`/`set(T)`, `~obj`/`obj \| v` operators) that notifies on change. The leaf field of a view-model. |
| `TomString`/`TomInt`/`TomDouble`/`TomBool` | `tom_core_kernel` | Scalar-typed `TomObject<T>` subclasses — the primitive view-model fields. |
| `TomNString`/`TomNInt`/`TomNDouble`/`TomNBool`/`TomNDateTime` | `tom_core_kernel` (`tom_observable_objects.dart`) | The **nullable arm** of the same family — `TomObject<T?>` subclasses. The cell an *optional* view-model field occupies (attr 1 below). |
| `TomClass` (`TomObject<Map<String,TomObject>>`) | `tom_core_kernel` | The **composite** view-model: a named bag of observable fields; the natural `@CsViewModel` root for a screen. |
| `TomList<E>` / `TomMap<K,V>` | `tom_core_kernel` | Observable collection fields (repeated / keyed sub-state) inside a view-model. |
| `TomObservingWidget<T>` | `tom_core_flutter` | The UI binding: a `StatefulWidget` that observes `subState` and rebuilds its `child` on every notification (lifecycle-correct: register/migrate/deregister). |
| `ValueListenableObserver<T>` | `tom_core_flutter` | Adapts a `TomObservable` to Flutter's `ValueListenable` for `ValueListenableBuilder`/`AnimatedBuilder` consumers. |

So a `@CsViewModel` is fully determined by *(a `TomClass`/`TomObject` field tree of
typed observable cells) + (the tom_core_flutter binding adaptor each field is bound
through)*. It adds **no** new observable type; it names an existing observable state
shape and the client-side bindings around it.

**Attribute surface (`@CsViewModel`).**

The view-model's **class name** derives from `SCRST.stateId` — the state's
machine symbol and `ScreenStateEntry`'s designated name field
(`codespecs_derivation_contract.md` §3.5.1 point 4). The entry headline names
the state for people; the extract carries only routed form-field values, so the
symbol the class name is built from is authored as a field.

1. **fields** — the typed observable cells of the view-model: each a
   `(name, T, kind)` where `kind` is scalar (`TomString`/`TomInt`/…), composite
   (`TomClass`), or collection (`TomList`/`TomMap`). Declared as a field tree, not
   imperative code. Initial values are authorable per field.
   **Optionality is the nullable arm of the same family.** A field whose
   requirement level is `Optional` or `ConditionallyRequired` emits
   `TomNString` / `TomNInt` / `TomNDouble` / `TomNBool` / `TomNDateTime`,
   initialised to `null`; `Required` emits the non-nullable type. There is no
   third spelling — "absent" and "the type's zero value" are different states,
   and a `TomString('')` cannot tell a screen which of the two it is holding.
   The signal is the attribute's own **`mandatory`** level (`BOAED.mandatory` on
   the business-object attribute the field mirrors), *not* CE-DB's
   `DATAA.nullable`: what a screen may leave blank is a requirement level, and
   a view-model field for an attribute the database happens to store as `NULL`
   may still be mandatory to fill in.
2. **derivation** — read-only fields computed from other fields (declared as a
   dependency + expression), realising the `notifyObservers` fan-out without
   hand-wiring observers.
3. **binding** — how each field reaches the UI: the CE-EL element / CE-FM form field
   it drives, via `TomObservingWidget`/`ValueListenableObserver`. Reference-by-id to
   the CE-EL/CE-FM target, not containment — an element authored once (§5.18) is
   cited here.
4. **lifecycle scope** — where the view-model lives (screen-scoped vs shared/app
   session-scoped). Screen-scoped is the default; shared view-models are named so
   several screens can reference the same instance.

**CE-ST relationships (boundaries).**

- **CE-ST ↔ CE-DB (the core distinction).** The view-model is *typed view state*,
  **not** the persisted entity. A screen editing a `Customer` DB entity (CE-DB) holds
  a `@CsViewModel` mirror of the fields being edited plus UI-only state (validation
  flashes, "dirty" flags, expansion toggles) that never persists. Load copies
  DB→view-model; save copies view-model→DB (CE-SC request assembly, §5.3 attr 2).
  The two never collapse into one type — the gap-row wording ("typed view-model state
  distinct from the DB model") is exactly this separation.
  **Optionality is spelled differently on each side, and deliberately so.** A
  view-model field uses the `TomN*` observable arm (attr 1); a CE-DB column uses
  a plain nullable Dart field (§5.13). Not a naming inconsistency but the same
  separation applied to one attribute: the entity is a plain annotated model
  class whose members the persistence layer reads by reflection, and
  `TomSqlDatasourceRepository.save` binds each column from
  `TomColumnInformation.getVariableValue` — the *field*, which on an observable
  member is the `TomNInt` object rather than the `int?` inside it. Observables
  read back from a query but have no write path, so the arm that is right for a
  screen is unavailable to a table.
- **CE-ST ↔ CE-EL / CE-FM (binding).** View-model fields are the *source* that CE-EL
  elements and CE-FM form fields bind to; the binding edge is owned here (attr 3) as a
  reference to the element/field, keeping CE-EL/CE-FM free of view-model wiring.
- **CE-ST ↔ CE-SC (server round-trip).** A `@CsServerCall` response updates the
  view-model (§5.3 attr 3 "response handling"), and its request is assembled from
  view-model fields (§5.3 attr 2). CE-ST is the client state the server call reads
  from and writes to.

**SOM feed.** CE-ST is derived from **D09 XDS** — `ScreenStateEntry` SCRST,
`ScreenElementDataDisplay` SEDD and `ComponentStateEntry` COMSTA, the three
`viewState`-marked screen sections — crossed with **D03 IMO** for the shape of
each field: `DisplayPropertyEntry` DISPL (how an attribute is presented) and
`BusinessObjectAttributeEntry` BIOBAT with its `BOAED` detail, whose `mandatory`
level chooses the nullable arm of attribute 1. All five are reachable from
`D13CodeSpecsProjection`. The IMO business-object catalogue above BIOBAT
(`BusinessObjectModel` BJOMD, `BusinessObjectEntry` BJOEN) carries the marker too
but stays **outside** the projection: it is the domain catalogue the fields are
read from, not a screen's state.

**There is no single "view-model" section, and that is the design.** A view model
is assembled from the screen sections that name its states and its data-bound
displays, plus the attribute entries that give each field its type and its
requirement level; the typed field tree is the *output* of that crossing rather
than a shape an author restates. `codespecs_derivation_contract.md` §3.5.1 fixes
the crossing, down to which extract token each field's `@DocSpec` back-link
names.

### 5.5 CE-CF server-configuration model + system-vs-user config scoping

**Decision.** CE-CF is the **server/system configuration** — deployment-time
settings that describe the running server as a whole. It is a *reuse* part (no gap
class): `@CsServerConfig` is a thin annotation over the surveyed `tom_core_server`
configuration classes. `@CsServerConfig` lives in the **server** project
(`<app>_codespec_server`, §4.2). System-vs-user configuration is **unified by
scoping, not by merging** — see the scoping design below.

**Built on (server configuration substrate).** `@CsServerConfig` wraps the
surveyed `tom_core_server` classes (`base_server_configuration.dart`); both are
`tom_core`-family classes per §1.1:

| Surveyed class | Package | Role for `@CsServerConfig` |
|----------------|---------|-----------------------------|
| `TomBaseServerConfiguration` | `tom_core_server` | The reflected config base: subclasses declare **typed fields** (port, TLS material, headers, JWT keys, handlers, logging). The reflection layer fills them by merging sources with a fixed precedence — config resources, then OS environment, then `.env`, then **command-line args (which win)**. A `@CsServerConfig` *is-a* `TomBaseServerConfiguration` subclass. |
| `TomServerConfigResourceProvider` | `tom_core_server` | The process-wide resolved configuration **tree**: a (possibly nested) map answering dotted-path lookups (`get`/`exists`), installed once at startup. It is the resource source `TomBaseServerConfiguration` merges from. |

So a `@CsServerConfig` is fully determined by *(a typed field set) + (per-field
source precedence: config-tree → env → `.env` → cmdline) + (a dotted-path key into
the `TomServerConfigResourceProvider` tree)*. It adds **no** new configuration
type; it names an existing `TomBaseServerConfiguration` field set and the
deployment-source resolution around it.

**Attribute surface (`@CsServerConfig`).**

1. **settings** — the typed configuration fields of the server: each a
   `(name, T, default?)`. Declared as a field set, not imperative code — the
   reflected `TomBaseServerConfiguration` subclass. Secret-bearing fields (TLS
   private key, JWT signing keys) are marked so production stripping (§12) and
   deployment tooling can treat them specially.
2. **source key** — the dotted `TomServerConfigResourceProvider` path a field
   resolves from (defaulting to the field name), plus the env-var / cmdline-flag
   alias. Reference-by-name (a `String`) — **exempt** from the §5.23
   typed-reference rule: the referent is a runtime resource-provider path into a
   deployment-supplied tree, not a Dart declaration; integrity is
   validator-checked (§12).
3. **precedence** — whether a field accepts the standard override chain
   (config-tree → env → `.env` → cmdline) or is fixed at one source; the base
   default is the standard chain (cmdline wins).
4. **feature flags (server scope)** — deployment-level boolean/enum toggles that
   gate server behaviour. A feature flag is an ordinary CE-CF **config value** —
   a flag field carries `@CodeSpecKind([serverConfiguration])` only. Distinct
   from feature *grants*: capabilities derived from authorization are
   server-level entitlements, not config values (§5.26).

**The system-vs-user config scoping (the core design).** One over-broad
"Configuration" concept is split into four owner-keyed scoped parts sharing one
conceptual model, not collapsed into one type (§11). The unification is
*conceptual* (one config-value model — typed key, default, source) realised as
**four owner-keyed, single-moded annotations**:

```
                     one "configuration value" concept
                        (typed key · default · source)
                                    │
        ┌──────────────────┬────────┴─────────┬───────────────────┐
   @CsServerConfig   @CsClientConfig   @CsDeviceSetting     @CsUserSetting
     (CE-CF)            (CE-CC)            (CE-DS)              (CE-UP)
   server/system     client app on a    a user's settings    a user's prefs,
   as a whole        specific machine   on one device        follow the user
   server project    client project     client project       client + server
```

The **discriminating axis** is the *scope key* — server/system (no user, no
machine) / (client app, machine) / (user, device) / (user) — and each part is
single-moded: the scope key alone decides where a value lives:

- **CE-CF ↔ CE-CC.** CE-CF is the server/system as a whole (DB connection, worker
  counts, TLS, JWT keys, server feature flags); CE-CC is a **client app on a
  specific machine** (API base URL, device options, per-install toggles), keyed by
  the (client app, machine) pair. A value about *how the server runs* is CE-CF; a
  value about *how one client install talks to it* is CE-CC. CE-CC's substrate is
  the `tom_core_flutter` `TomBaseClientConfiguration` holder (per §4.1); its
  attribute surface is §5.16.
- **CE-CC ↔ CE-DS.** The discriminator is **user identity in the key**: a value
  that is the same for every user of an install is CE-CC; a value that differs
  per signed-in user on the same install is CE-DS. CE-DS persists on the device
  and never leaves it; device binding is implicit-by-storage (the store lives on
  the device, keyed by the signed-in user) — no wire-level device identity exists.
- **CE-DS ↔ CE-UP.** Both are user-scoped; the discriminator is whether the value
  **follows the user**. Device-bound values (window layout, last-opened,
  machine-local cache preferences) are CE-DS; values restored on any device the
  user signs into (server-persisted, read back through the
  `tomUserPreferencesApi` round trip, `tom_core_kernel`)
  are CE-UP. A value that is the same for every user of a server is CE-CF; a
  value that differs per user is CE-DS or CE-UP. Attribute surfaces are §5.16.
- **CE-CF ↔ CE-AZ / CE-AU.** CE-CF may hold the JWT signing keys and TLS material
  the server uses, but *who may call an operation* is CE-AZ and *credential/session
  exchange* is CE-AU — config supplies the keys, it does not model the policy.

There is **one** configuration-value concept, deliberately realised as **four**
owner-keyed parts; CE-CF is the server-only realisation. System, client, device
and user configuration are not unified into one type because they have different
owners, lifetimes, and persistence loci; they are unified at the *concept* level
and kept separate at the *realisation* level.

**SOM feed.** CE-CF is derived from **42** `serverConfiguration`-marked sections,
across **D06 ATS** (what the server needs configured), **D08 SAS** (which config
carries keys and secrets) and **D09 XDS** (the print/export renderer settings).
They split by **who owns the setting's key**, and the split is what decides how
much of a setting is authorable at all:

- **Declared — the application owns the key.** `SystemConfigurationManagement`
  SYCOMA carries the marker over its open list `ServerConfigurationSettingEntry`
  SCSET: the author invents the key, so every property of the setting is
  authored, including the secret mark, which is expressible here and nowhere
  else. This is the **single** declared section.
- **Fixed — the model owns the key.** The other **41** are policy and layout
  bands whose form fields each name one setting the SOM already knows exists —
  `ConfigurationManagement` CM and the release-management feature-flag band under
  D06 ATS, the SAS encryption / key-management / API- and storage-security /
  audit-sink bands, and D09's `PrintAndExportLayout` PRLA with its export-format
  and template entries. The author supplies the value only, so nothing per-setting
  is authorable.

`codespecs_derivation_contract.md` §3.3.6 states the two paths as one contract:
both emit members of a single `TomBaseServerConfiguration` holder, because the
discriminator is about authoring, not about runtime. The cross-scope source
**precedence** — which source wins when the same logical key is expressible at
more than one scope — is §5.16.

**All 42 are inside `D13CodeSpecsProjection`**, so every section an author can
fill in is a section generation reads. Two of them are reached *past* a
`@FollowUpKind` root — the SAS encryption and key-management families (19
sections) under `SecurityOperationsFollowUp`, and D09's PRLA band (8) under
`ExperienceDesignFollowUp` — because each is a pure CE-CF band that was swept
into a follow-up root cut one level too high, not placed there on a criterion
(§8.3). §5.5's own substrate settles it: `TomBaseServerConfiguration` declares
TLS material and signing keys as typed fields, so a TLS minimum version or a key
rotation interval is a server-configuration value in exactly the sense
`@CsServerConfig` generates, and the projected siblings of these bands —
`StorageEncryptionPolicy` under `AccessControlModel`, `LogRetentionPolicy` under
`AuditAndLogging` — are fixed-key policy bands of identical shape that no
criterion separates from them.

### 5.6 CE-API / CE-SU / CE-AZ server API, service-unit & authorization model

**Decision.** Three **server-side** parts
form one operation together: `@CsEndpoint` (CE-API, the operation), `@CsServiceUnit`
(CE-SU, the grouping the operation lives in), and `@CsAuthorize` (CE-AZ, the access
modifier on the operation). All three are authored **server**-side
(`<app>_codespec_server`, §4.2) — the handler, the unit and the operation-level
access modifier. Their **citable identities** are shared: the request/response DTOs
and the `CsOperationRef` operation catalogue, and the `CsRoleRef` /
`CsResourceKeyRef` catalogues `@CsAuthorize` cites, all live in the **shared**
project (§4.2, §5.23), because the client cites them too. The CE-SU boundary
criterion is **§5.1** (owned-aggregate primary, process-cohesion secondary,
bounded-context outer bound).

#### 5.6.1 CE-API — `@CsEndpoint` (reuse + extend for the §7 contract)

**Built on (kernel API model + server endpoint pipeline).** `@CsEndpoint` wraps the
surveyed classes; every one is a `tom_core`-family class per §1.1:

| Surveyed class | Package | Role for `@CsEndpoint` |
|----------------|---------|------------------------|
| `TomApi` / `TomApiEndpoint<ReturnType, RequestType>` | `tom_core_kernel` (`endpoints_apis.dart`) | The registry-side API description: an endpoint's `uri`, `methods`/`method`, `consumes`/`produces`, `formFields`, `urlParameterMapping`, typed `ReturnType`/`RequestType`. The typed request/response the §7 contract needs already exists here. |
| `TomRemoteApis` | `tom_core_kernel` | The API registry (`tomRemoteApis[apiId][endpointId]`) — the operation catalogue key space CE-SC (§5.3) references by name. |
| `TomEndpoint<requestType, resultType>` | `tom_core_server` (`endpoint_annotation.dart`) | The method-level inline endpoint annotation: `methods`, `uri`, mime types, per-endpoint error handler, headers, CORS, `urlParameterMapping`. The concrete route the pipeline mounts. |
| `TomApiEndpointImplementation` | `tom_core_server` | Binds a service method to a registry endpoint (`apiId`+`endpointId`) with impl-side overrides; `convertToTomEndpoint` merges registry + overrides. |
| `TomEndpointHandler` / `TomEndpointRouting` / `TomServer` | `tom_core_server` (`endpoint_pipeline.dart`, `server.dart`) | The pipeline: scans annotated methods, materialises parameters, runs `checkAccess` (→ CE-AZ), routes and serves. |

**Extension for the §7 contract (the CE-API-specific work).** The pipeline substrate
is verb-general (defaults to `GET`, arbitrary URIs, exceptions → 500). `@CsEndpoint`
**narrows** it to the §7 contract without changing the runtime:

1. **operation name, not verb+path.** Every `@CsEndpoint` is **POST** per §7's
   first decision; its identity is a first-class **operation name** (the intent
   carrier), not the HTTP verb or a REST-shaped path. The name is the stable id
   CE-SC references (§5.3 hop 2) and the CE-SU grouping key.
2. **typed request/response.** Each operation names a request DTO `T` and response
   DTO `R` (the `TomApiEndpoint<R,T>` type args), both authored in the **shared**
   project so client (CE-SC) and server (CE-API handler) compile against one type.
3. **structured result, transport-clean.** The success payload is `R` inside the
   CE-ER `Result` envelope; application errors are `ErrorResult` in a **2xx**
   transport response; only 5xx is a transport failure. Both are §7's third and
   second decisions. Error **codes** resolve to copy via the CE-TX message-key
   registry (§5.21), so no `@CsEndpoint` embeds error text.

`@CsEndpoint` therefore adds **no** new transport type — it constrains
`TomEndpoint`/`TomApiEndpoint` to (POST + operation-name + typed `T`/`R` + Result
envelope). The full operation/request/response **attribute set** is §5.14.

#### 5.6.2 CE-SU — `@CsServiceUnit` (reuse; ordinary abstract classes, no new class)

**Built on (server service grouping) + the §5.1 boundary.** `@CsServiceUnit` is the
**first-class name** for a cohesive set of operations + owned entities, over the
surveyed grouping substrate:

| Surveyed class | Package | Role for `@CsServiceUnit` |
|----------------|---------|----------------------------|
| `TomService` (`@tomService`) | `tom_core_server` (`endpoint_annotation.dart`) | The existing "scan my endpoint methods" class marker. A `@CsServiceUnit` class *is-a* `@tomService`. |
| `TomApiImplementation` (`extends TomService`) | `tom_core_server` | The registry-API-bound service variant (`apiId` + API-wide error/log defaults). **Mutually exclusive** with `@tomService` — the endpoint pipeline rejects a class carrying both. |
| `TomComponentReference` | `tom_core_server` | Resolves a service's implementation bean by name or type — the unit's implementation binding. |
| `TomEndpointRouting.scanClasses` | `tom_core_server` (`endpoint_pipeline.dart`) | Discovers the annotated services/endpoints — the mechanism a unit's operations are gathered by. |

`@tomService` marks *a class to scan*; it does **not** express a **unit boundary**
(which operations + which owned entities/repositories form one cohesive service).
That boundary is supplied by the **`@CsServiceUnit` annotation** on an ordinary
**(abstract) class** that clusters the server API into a functional-group *closure*
— **no new `tom_core_codespecs` class** (decision (h)): the unit is a normal class
carrying **one** of the existing server-API mapping annotations — `@tomService`
or `TomApiImplementation`, which are exclusive alternatives — and `@CsServiceUnit`
(a `Cs*` annotation, not a base class) names its boundary. The derivation emits
`@tomService` (`codespecs_derivation_contract.md` §3.4.1: `TomApiImplementation`'s
required `apiId` has no authoring SOM field). This respects the §4.1
no-base-classes rule.

**Boundary criterion (§5.1).** A `@CsServiceUnit` owns exactly
one **aggregate** (root entity + lifecycle-dependent entities), every CE-DB table/
repository over that aggregate, and every CE-API operation whose primary written
entity is in it (§5.1 rule 1); process cohesion may merge/split (rule 2); a bounded
context caps any merge (rule 3). Its stable id is `<RootAggregate>Service`
(PascalCase, §5.1) — that id is both the `@CsServiceUnit` identity and the
`<app>_codespec_server` grouping key (§4.2). A unit **never** reaches another unit's
repository directly; cross-unit data flows through the owning unit's CE-API (§5.1
ownership rule). The CE-SU **attribute set** (owned entities, operations, repository
list) is §5.17.

#### 5.6.3 CE-AZ — `@CsAuthorize` (reuse; a modifier on `@CsEndpoint`)

**Built on (kernel access-control model + server graded auth).** `@CsAuthorize`
wraps the surveyed authorization classes; every one is a `tom_core`-family class:

| Surveyed class | Package | Role for `@CsAuthorize` |
|----------------|---------|--------------------------|
| `TomAccessControl` (abstract) | `tom_core_kernel` (`access_controls.dart`) | The access-check contract: `checkAccessibility(principal)` (binary) + `resolveAuthState(principal)` (four-state). The value a `@CsAuthorize` carries. |
| `TomRoleAccess`/`TomGroupAccess`/`TomEntitlementAccess`/`TomResourceKeyAccess`/`TomCustomAccess` | `tom_core_kernel` | The concrete binary controls (role / group / entitlement / resource-key / custom). |
| `TomGradedAccess` | `tom_core_kernel` | Composes binary controls into the four `TomAuthState` levels (full / read / disabled / none) — the field-level graded authorization. |
| `TomPrincipal` / `TomAccessControlInformation` / `TomAuthState` | `tom_core_kernel` (`user_principal_aci.dart`) | The caller identity, its ACI, and the four-state auth outcome. |
| `TomResourceGrant` / `TomGradedAccessControlInformation` / principal delegation | `tom_core_server` (`graded_authorization.dart`, `principal_*.dart`) | Server-side graded grants + delegation. |
| `TomEndpointHandler.checkAccess` (handler-side `TomAccessControl` annotation, C-12/G-API-3) | `tom_core_server` (`endpoint_pipeline.dart`) | The runtime check the pipeline already runs per endpoint — the exact hook `@CsAuthorize` feeds. |

**CE-AZ is a modifier, not a standalone part (§4.1 rule).** `@CsAuthorize` is applied
**as an attribute on the owning `@CsEndpoint`** (and, for field-level graded access,
on a CE-EL/CE-FM element via `TomGradedAccess`). It names the `TomAccessControl` the
pipeline's `checkAccess` enforces for that operation. Reuse only — no gap class; the
runtime already supports both binary and four-state graded checks. The **six
requirement kinds + graded levels + field-level authKey** attribute surface is
§5.15; the SOM `SecurityAccessSpecification` (D08 SAS) is the source (§8).

**SOM feed.** CE-API/CE-SU are derived from **D07 IFS** (operations +
request/response) + **D06 ATS** (module/context grouping) + **D05 ISC** (which
scenarios exercise which operations); CE-AZ from **D08 SAS** (roles/permissions per
operation), per §8. The attribute surfaces: CE-API operation/request/response —
§5.14; CE-AZ requirement kinds + graded levels + field-level authKey — §5.15;
CE-SU service-unit attribute set — §5.17.

### 5.7 CE-EL / CE-FM screen-element & form model over tom_flutter_ui

**Decision.** The two **client-side** UI-structure
parts: `@CsElement` + `@CsWidget` (CE-EL, the semantic element and its concrete
widget binding) and `@CsForm` (CE-FM, the field group / form). Both are *reuse*
parts whose substrate is **`tom_flutter_ui`** (§1.1 pillar (b)).
Both live in the **client** project (`<app>_codespec_client`, §4.2). **No new
class:** CE-EL introduces no `tom_core_codespecs` type — it is fully covered by
`TomScreenElementsProvider` + the existing `Tom*` `tom_flutter_ui` element/widget
family + the form semantic classes. The "formal element-type catalogue" (§5.18)
is therefore a **documented catalogue over reused classes**, not a new class.

**Boundary (authoring homes).** Forms and subforms are part of the screen-element
description: **CE-FM owns the form/subform tree *and its member input elements*** —
an input element is authored **within its owning form**. **CE-EL proper is the
standalone (non-form) screen elements**: static display, action-trigger elements
(buttons, menu entries), form-hosting containers. The CE-EL catalogue (§5.18)
stays the **single kind vocabulary** (kinds + per-kind attributes) for form
members too — one vocabulary, two authoring homes. The substrate mapping is
unchanged: `TomField<T>` remains the input-element base, `TomForm.fields` holds
them, `TomFormChildContainer` carries subforms (§5.7.2).

#### 5.7.1 CE-EL — `@CsElement` + `@CsWidget` (reuse + a catalogue extension)

**Built on (tom_flutter_ui element substrate).** The two-step "semantic type →
concrete widget" (§5 gap row) maps onto the surveyed classes:

| Surveyed class | Package | Role for CE-EL |
|----------------|---------|----------------|
| `TomField<T>` (`extends TomObject<T> implements TomAuthorizable`) | `tom_flutter_ui` (`forms/tom_form.dart`) | The **semantic element** base: an observable typed value (`TomObject<T>`, §5.4 CE-ST substrate) with a `tomId`, scope/`basePath`, validators, `authorizer` (→ CE-AZ field-level graded access), obscure/auto-validate. `@CsElement` is *is-a* `TomField<T>` element. |
| Concrete field/widget types — `TomTextField`, the `TomButtonBase` variants (`TomElevatedButton`, `TomFilledButton`, …), `TomText`, inputs / selects / toggles | `tom_flutter_ui` | The **concrete widgets** a semantic element binds to. `@CsWidget` names one. |
| `TomScreenElementsProvider` / `TomScreenElementsProviderBase` | `tom_flutter_ui` (`widget_base/tom_screen_elements_provider.dart`) | The **declarative screen = typed-fields catalogue**: a `@tomReflect` class whose `late final` `TomField`/widget members are reflection-discovered, scoped for resource/authorization lookups. The CE-EL container a screen's elements live in. |

**The two-step separation (the CE-EL-specific work).** `@CsElement` carries the
**semantic** type (what the field *means*: a text input, a choice, a toggle, a
button — plus its value type `T`, label/help text → CE-TX, validators → CE-VA,
authorizer → CE-AZ). `@CsWidget` carries the **concrete widget binding** (which
`tom_flutter_ui` widget renders it). One semantic element → one widget by default,
overridable — mirroring the CE-LO slot→element and CE-SC action→operation
reference separations (§5.2/§5.3): the *meaning* is authored once, the *rendering*
is a separable binding.

**Element-type catalogue (the exit deliverable).** A **formal
element-type catalogue** — the closed set of semantic element kinds and, per kind,
the default `tom_flutter_ui` widget + the extra attributes that kind needs — is a
**CodeSpecs-only documentation** framing of behaviour already present in
`TomScreenElementsProvider` (which discovers *instances*, not a *type catalogue*)
and the `Tom*` widget family. It is authored as a **documented catalogue over the
reused classes — no new `tom_core_codespecs` class** (decision (d)); the kinds
*are* the existing `Tom*` widgets. The catalogue's concrete **contents** (the
per-kind attribute set + the semantic→widget bindings) are in **§5.18** — this
section fixes the catalogue's *reuse basis and two-step shape*.

#### 5.7.2 CE-FM — `@CsForm` (reuse; mirrors the SOM `@Form` field-group)

**Built on (tom_flutter_ui form substrate).** `@CsForm` wraps the surveyed classes:

| Surveyed class | Package | Role for `@CsForm` |
|----------------|---------|--------------------|
| `TomForm<T extends TomClass>` (`extends TomClass implements TomScreenElementsProvider, TomActionController, TomFormEventSource`) | `tom_flutter_ui` (`forms/tom_form.dart`) | The form base: a `fields` map of `TomField`s, a bound data object `T` (`bind`/`unbind`/`save`/`discard`/`validate`/`isDirty`/`isValid`), form-tree parent/child wiring, event source. `@CsForm` *is-a* `TomForm<T>`. |
| `TomFormChildContainer` | `tom_flutter_ui` (`forms/tom_form_child_container.dart`) | The **nested/repeated-subform** marker: a non-`TomForm` child (e.g. `TomListForm`) whose `validate`/`save`/`discard`/`unbind`/`isDirty`/`isValid` the parent form fans out into. The substrate for CE-FM subforms. |
| `TomField<T>` | `tom_flutter_ui` | The form's leaf fields (= CE-EL elements, §5.7.1). |

**Subforms — substrate-backed.** Subforms (nested/repeated) mirror the SOM `@Form`
field-group structure: the SOM `@Form` field-group maps directly onto `TomForm` +
`TomFormChildContainer`: a SOM `@Form` with a nested form-typed field → a nested
`TomForm` (reflectively discovered, `nestedForms`); a SOM `@Form` with a repeated
form-typed field → a `TomFormChildContainer` (list form). `@CsForm` therefore
carries the **field group + subform tree** shape from the SOM `@Form` with **no**
new form type — the nested/repeated lifecycle fan-out already exists. The concrete
`@CsForm` **attribute set** (per-field wiring, subform cardinality, form-level
CE-VA cross-field rules) rides the form model; CE-VA form rules are §5.19.

**SOM feed.** CE-EL/CE-FM are derived from **D09 XDS** (screens /
elements / forms / layout) + **D05 ISC** (scenarios name the screens), per §8. The
SOM carries the `@Form` field-group structure (the driver of the CE-FM
subform tree) and `@ContentHelp`/`@Form` hints (→ CE-TX). The CE-EL field base +
per-kind extras + semantic→widget catalogue contents are §5.18; the CE-VA field vs
form (cross-field) rules the forms carry are §5.19.

### 5.8 CE-TX text / message-key / i18n model over tom_flutter_ui + kernel

**Decision.** `@CsText` (CE-TX) is a **reuse** part
over the surveyed `tom_flutter_ui` label substrate and the `tom_core_kernel`
resource-provider backend. **CE-TX is *not* the id catalogue for screen-element
texts** (decision (e)): a screen element's own placeholder / label / help / error
copy is **derived**, not catalogued — from the element's `tomId` + its **route
scope** (`TomScope.withScope(...)`) + its **form scope** (form nesting) →
**`basePath`** → resource keys (with the per-role suffixes), and **those same
resource keys are also the CE-AZ authorization resource keys** (§5.15). CE-TX
instead catalogues **all *other* texts** — server / error copy, notification and
email bodies, report copy, and any text not owned by a screen element. The one
CodeSpecs-only addition — a **message / i18n-key model** (the closed catalogue of
those message keys and their per-locale copy resolution) — lives in
**`tom_core_codespecs`** as `TomMessageKeyRegistry` over `TomMessageKey`
(`message_key.dart`; a concrete model class, **not** an abstract `Cs*` base;
§4.1 no-base-classes rule). CE-TX is the one part that **spans two projects**
(§4.2): the **message keys** live in `<app>_codespec_shared` (the same keys the
server uses for error copy), while the **copy** (the resolved per-locale strings)
is a **client** concern (`<app>_codespec_client`).

**Built on (label substrate + i18n backend).** The two roles — the *carrier* of a
text on a UI element and the *resolver* of a key to localized copy — map onto the
surveyed classes:

| Surveyed class | Package | Role for CE-TX |
|----------------|---------|----------------|
| `TomText` (`extends TomLabelBase`) | `tom_flutter_ui` (`widgets/labels/tom_labels.dart`) | The **text carrier** on a UI element: fields `labelText` / `hintText` / `descriptionText` are the placeholder / label / help texts a CE-EL element (§5.7.1) exposes. Each falls back to a **resource key** when the literal is absent (`_resolvedLabel = labelText ?? TomCtr.textOrFail(basePath, 'label')`) — the built-in literal-or-key duality `@CsText` formalises. |
| `resolveErrorMessage` (label/field error hook) | `tom_flutter_ui` | The **error-copy hook**: an element's error text. `@CsText` routes this through the CE-ER error code (below), not a free literal. |
| `TomTextResourceProvider` | `tom_core_kernel` (`tombase/resources/tom_resource_provider.dart`) | The **i18n backend**: a singleton text-resource provider — localized strings, UI labels, messages — with **hierarchical dot-notation key access** (`getText('app.title')`), initialised from JSON maps or loader functions, resolving keys tree-walk-first then flat-key. The store a message key resolves against. |
| `TomConfigResourceProvider` | `tom_core_kernel` (same file) | The sibling **config** provider (same dot-notation resolution). CE-TX reads copy from the text provider; CE-CF (§5.5) reads config from this one — the split keeps copy and config in distinct resource trees. |

**Two text sources — derived (element) vs catalogued (other).**

1. **Screen-element texts — derived from `basePath`, not catalogued.** A screen
   element's placeholder / label / help / error copy is resolved from its
   **`basePath`** — computed from the element's `tomId` + route scope
   (`TomScope.withScope(...)`) + form scope (nesting) — plus a per-role **suffix**
   (`label` / `hint` / `description` / error). `TomText`'s built-in literal-or-key
   duality (`_resolvedLabel = labelText ?? TomCtr.textOrFail(basePath, 'label')`)
   already does this; the SOM `@ContentHelp` / `@Form` hint / doc-comment content
   (§8) seeds the literals. **These `basePath`-derived keys are also the CE-AZ
   authorization resource keys** (§5.15), so text and access share one key space.
   No CE-TX catalogue entry is authored for them.
2. **Other texts — the CE-TX message / i18n-key model.** Every text **not** owned
   by a screen element (server / error copy, notification & email bodies, report
   copy) is a **message key** (`'app.error.amount.tooLarge'`) resolved at runtime
   by `TomTextResourceProvider`. The closed set of these keys + their per-locale
   copy is the **message / i18n-key model**, a `tom_core_codespecs` catalogue.
   Keys are **shared** (server error copy resolves the *same* keys, §7), copy is
   **client**.

**Error texts keyed by CE-ER codes (the cross-part relationship).** Error copy is
**not** a free literal: an element's `resolveErrorMessage` / a form's validation
failure resolves to copy via the **CE-TX message-key registry (MSGKR)**,
keyed by the structured **CE-ER error code** (§7). Client copy and server error
codes share one source (the CE-ER error-code registry ↔ the CE-TX MSGKR), so a
code authored once yields both the server's structured error and the client's
localized message.

**SOM feed.** CE-TX is derived from **D09 XDS** (screens / elements
/ forms) + SOM `@ContentHelp` / `@Form` hints / doc-comments, per §8 — the texts
are already in the SOM; error texts arrive via CE-ER codes. The message-key /
i18n attribute surface (per-key attribute set + locale model + error copy keyed
by CE-ER codes) is §5.21.

### 5.9 CE-VA validation — field-rule vs form-rule split over tom_flutter_ui

**Decision.** The CE-VA validation parts are a
**reuse** family: a `@CsValidation` umbrella plus the two-way
**field-rule vs form-rule** split — `@CsFieldRule` (single-field) and `@CsFormRule`
(cross-field / form-level). The substrate is **`tom_flutter_ui`** (§1.1 pillar (b)). **No new
class:** CE-VA is **provided as Dart code** — standalone validator classes with
validation methods, or validation methods on the `TomForm` subclass — exercising
the §3 first-level-implementation latitude (a CodeSpec need not be purely
declarative). CE-VA spans **client + shared** (§4.2): field/form rules the
client enforces are also part of the shared contract the server re-checks.

**Built on (tom_flutter_ui validation substrate).** The single-field and
cross-field roles map onto the surveyed classes:

| Surveyed class | Package | Role for CE-VA |
|----------------|---------|----------------|
| `Validator<T> = FutureOr<ValidationResult> Function(T)` | `tom_flutter_ui` (`forms/validation/validation_result.dart`) | The **single-field rule** signature (async-capable): a typed value → a `ValidationResult`. `@CsFieldRule` *is-a* `Validator<T>`. |
| `ValidationResult` (sealed: `ValidationPristine` / `ValidationSuccess` / `ValidationError(errorKey, {params})` / `ValidationPending`) | `tom_flutter_ui` (same file) | The **rule outcome**. `ValidationError.errorKey` is a **message key** — the CE-VA↔CE-TX/CE-ER tie (below). The `Pending` variant carries the async/`SlowValidator` case. |
| `Validators` | `tom_flutter_ui` (`forms/validation/validators.dart`) | The **built-in field-rule catalogue** (`required`/`email`/`minLength`/`maxLength`/`pattern`/`min`/`max`/`compose`). The reuse basis for the standard `@CsFieldRule` kinds. |
| `TomValidatorRegistry` (`resolve`/`resolveSpec`/`resolveDeclaration`/`parseSpec`) | `tom_flutter_ui` (`forms/validation/validator_registry.dart`) | The **validator declaration language**: name+args → `Validator`. The substrate for authoring rules declaratively — the declaration language is §5.19. |
| `FormValidationError` (`fields`, `tomIds`) | `tom_flutter_ui` (`forms/validation/form_validation_error.dart`) | The **cross-field / form-level** error carrying the offending fields. `@CsFormRule` *is-a* form-level rule producing this. |

**The field-vs-form split (Dart methods, no new class).** `@CsFieldRule` validates
one field in isolation (`Validator<T>` → `ValidationResult`); `@CsFormRule`
validates across fields (a cross-field invariant → `FormValidationError` over
several `tomIds`). The split is expressed **as Dart code** — a `@CsFieldRule` as a
standalone `Validator<T>` method or a registered `Validators` entry, a `@CsFormRule`
as a **validation method on the `TomForm` subclass** — so it needs **no
`tom_core_codespecs` class** (decision (f); the two validation scopes already exist
separately in `tom_flutter_ui`). `@CsValidation` is the umbrella that groups a
field's / form's rules; each rule is **traceable to a requirement** (the gap-row's
"each traceable to a requirement" clause) via the SOM feed below.

**Error copy — the CE-VA↔CE-TX/CE-ER tie.** A rule failure is **not** a free
literal: `ValidationError.errorKey` is a **message key** resolved through the CE-TX
message-key registry (MSGKR, §5.8), keyed where appropriate by a CE-ER error
code (§7). At spec level the key is a typed `CsMessageKey` / `CsErrorCode` const
(§5.23); the runtime `errorKey` string is the generated **lowered** form. So a
validation rule authored once yields a structured failure *and* its
localized message — the same author-copy-once discipline CE-TX/CE-ER share.

**SOM feed.** CE-VA is derived from **D04 RSP** (requirements) +
**D03 IMO** constraints, per §8 — **field rules** from attribute constraints,
**form rules** from cross-field requirements, each rule tracing back to the
requirement that mandates it. The field-rule vs form-rule attribute surface +
validator declaration language (over `TomValidatorRegistry`) is §5.19; the rule
keys resolve against the CE-VA/CE-ER/CE-TX error-code spine (§5.8, §7).

### 5.10 CE-AC action + trigger taxonomy over tom_flutter_ui

**Decision.** `@CsAction` (CE-AC) is a **reuse** part over the surveyed
`tom_flutter_ui` action substrate, plus a `@CsTrigger` marker and the CodeSpecs-only
**trigger taxonomy** (how an action is invoked). The substrate is
**`tom_flutter_ui`** (§1.1 pillar (b)). CE-AC lives in the **client** project (§4.2). **No new
class:** Actions have a **full implementation in `tom_flutter_ui`**
(`TomAction` / `TomActionController` / `TomActionTrigger`, decision (g)); the formal
**trigger taxonomy** is a **documented classification over those reused classes**,
not a `tom_core_codespecs` type.

**Built on (tom_flutter_ui action substrate).** The action and its invocation map
onto the surveyed classes:

| Surveyed class | Package | Role for CE-AC |
|----------------|---------|----------------|
| `TomAction<TContext, TUndo>` (`implements TomAuthorizable`) | `tom_flutter_ui` (`actions/tom_action.dart`) | The **action base**: a stateless, typed, authorized, optionally-undoable behaviour with an `actionId`, `canonicalPath` (`<controllerId>.<actionId>`), `canExecute`/`execute`/`undo`, and an `authorizer` (→ CE-AZ). `@CsAction` *is-a* `TomAction`. |
| `TomActionContext` | `tom_flutter_ui` (`actions/tom_action_context.dart`) | The **typed context requirement** an action declares via `TContext` (the domain data + `scope` an action needs to run). |
| `TomActionController` | `tom_flutter_ui` (`actions/tom_action_controller.dart`) | The **action registry / owner**: groups related actions, supplies the first canonical-path segment. The CE-AC container. |
| `TomActionTransaction` | `tom_flutter_ui` (`actions/tom_action_transaction.dart`) | The **atomic-undo unit** grouping sub-actions of one gesture — the undo/redo substrate. |
| `TomActionTrigger<TContext, TUndo>` | `tom_flutter_ui` (`actions/tom_action_trigger.dart`) | The **widget-gesture trigger** realization: binds an action to a widget callback (`onPressed`/`onTap`), does `canExecute`-gating, transaction creation, undo recording. The concrete *button/gesture* member of the trigger taxonomy. |

**The trigger taxonomy (the CodeSpecs-only work).** `@CsAction` names *what* the
behaviour is (over `TomAction`); `@CsTrigger` names *how* it is invoked. One action
may have **several triggers** — the gap-row's "one action, several triggers". The
taxonomy is the closed set of invocation kinds:

- **user-gesture** — a button press / tap / in-form widget event (`TomActionTrigger`
  is this kind's realization).
- **in-form event** — a form lifecycle event (field change / submit / validation).
- **lifecycle** — a screen/route enter/leave or app lifecycle hook.
- **server-event** — an inbound server push / notification.
- **condition** — a reactive predicate over observable (CE-ST) state.

**The trigger is the single authoring home of the element→action edge.** A
`@CsTrigger` *is* the (element/event → action) **join entity**: it carries **both
endpoints** — the source (element ref + gesture, or event) and the target action
ref — plus the guard. Element-side action hooks (a Button's or MenuEntry's
action, a field's inline action-icon) are **derived back-references**, never
authored (§5.18). One element may trigger different actions on different events
and one action may be triggered from several elements — N:M with the trigger as
the join, mirroring the CE-SC middle node of the CE-AC→CE-SC→CE-API chain (§5.3).

This is a **CodeSpecs-only** framing of invocation paths `tom_flutter_ui`
realises only partially (`TomActionTrigger` = the user-gesture case); it is
authored as a **documented classification over the reused action classes — no new
`tom_core_codespecs` class** (decision (g)), keeping `tom_flutter_ui` the single
implementation home.

**Action → server-call tie (§5.3).** A triggered CE-AC action frequently drives a
CE-SC server call — the **explicit two-hop CE-AC→CE-SC→CE-API reference edge** of
§5.3. `@CsAction` carries the *what* (the behaviour + its trigger); the
`@CsServerCall` it references carries the *how* (operation + request/response).

**SOM feed.** CE-AC is derived from **D05 ISC** (scenarios / processes
name the actions + their triggers + transitions) + **D02 TOM**, per §8. The
per-trigger attribute surface over `TomAction` is §5.20; the CE-AC→CE-SC→CE-API
edge a triggered action drives is §5.3.

### 5.11 CE-NV navigation — route-id + screen-flow model over tom_flutter_ui

**Decision.** `@CsRoute` (CE-NV) is a **reuse** part over the `tom_flutter_ui`
routing substrate, plus the CodeSpecs-only **route-id model** (stable route
identifiers) and a **screen-flow model** (`@CsScreenFlow`). The substrate is
**`tom_flutter_ui`** (a CodeSpecs code basis, §1.1 pillar (b)). CE-NV lives in the **client**
project (§4.2). The CodeSpecs-only additions — the **route-id model** and the
**screen-flow model** — live in **`tom_core_codespecs`** as `TomRouteRegistry` /
`TomRouteDefinition` / `TomFormScreenAssignment` / `TomScreenFlowEdge`
(`route_flow.dart`; concrete classes,
**not** abstract `Cs*` bases; §4.1 no-base-classes rule).

**The screen-flow model (decision (c)).** Beyond bare route ids, CE-NV models the
**screen flow** that results from combining the D05 ISC interaction scenarios into
**interactions with screens** (Flutter routes):

- **Form → screen assignment.** Each form (CE-FM) is assigned to a screen (route),
  either **replacing** the current screen (a normal route push/replace) or
  **overlaying** it as a **popup** (a dialog / modal over the current screen).
- **Action-triggered, conditional navigation.** Navigation is triggered by a
  CE-AC action (§5.10) and its **target is conditional on the action outcome**:
  on **success** → a confirmation screen or back to the previous screen; on
  **error / validation error** → an error display. `@CsScreenFlow` records the
  (source screen, triggering action, outcome → target screen, presentation mode)
  edges.

**The SOM authoring home.** The edges are authored in the **screen route map**
(`SCRTMP`), the third subsection of D09 XDS `ScreenFlowStructure` (10.3.3),
beside the navigation model and the screen-flow diagram. It carries three
registries, each mapping one-to-one onto the `tom_core_codespecs` model:

| SOM section | Authors | Code counterpart |
|-------------|---------|------------------|
| `SCRTEN` route entries | Stable **route id**, path, title, rendered screen, route parameters | `TomRouteDefinition` |
| `FMSCAS` form placement | form id → route id + presentation mode | `TomFormScreenAssignment` |
| `SCTREN` transitions | (source route, action, outcome) → target route + presentation mode | `TomScreenFlowEdge` |

Two closed vocabularies back them: `ScreenPresentationMode` (`replace` /
`popupOverlay` — the spec-side name for `TomScreenPresentation.popup`) and
`ScreenFlowOutcome` (`success` / `error` / `validationError`). The transition's
`outcomeReference` joins the outcome to the existing catalogues — the CE-ER
system error code (`SYERCO`) for `error`, the CE-VA validation message
template (`VMT`) for `validationError` — so no error vocabulary is duplicated.

Routes are referenced **by id, never by path**: the path is presentation and
changes, the id is the stable handle that form placement, transitions, screen
classification (`SCECL.routePattern`) and action outcomes (`SAEB.navigateTo`)
all point at.

**Built on (tom_flutter_ui navigation substrate).** The route and its navigable
targets map onto the surveyed classes:

| Surveyed class | Package | Role for CE-NV |
|----------------|---------|----------------|
| `TomPageRoute<T>` (`extends MaterialPageRoute<T>`) | `tom_flutter_ui` (`widgets/navigation/tom_page_route.dart`) | The **route base**: a scope-propagating page route (captures `TomScope.current` at push, re-enters it around `builder`) with a typed result `T`. `@CsRoute` *is-a* `TomPageRoute<T>` — a navigable screen with a typed return. |
| `TomNavigationDestination` (+ `TomNavigationRail`/`Bar`/`Drawer`) | `tom_flutter_ui` (`widgets/navigation/tom_navigation.dart`) | The **navigable target** widgets: a destination carries a `tomId`, `scope`, `authorizer` (→ CE-AZ) and resolves its label/tooltip from resources (→ CE-TX). The screen-to-screen transition endpoints. |

**The route-id model (the CodeSpecs-only work).** The substrate identifies a
destination by `tomId` but assumes **route uniqueness** without a formal registry
(the gap-row's "Route uniqueness assumed"). `@CsRoute` adds a **route-id model**: a
closed set of **stable route identifiers** (one per navigable screen). The
**screen-to-screen transition** edges between them (which route reaches which,
under what action + outcome, and in which presentation mode) live in the
**screen-flow model** above. Both are a **CodeSpecs-only** framing — they live as **concrete classes in
`tom_core_codespecs`** (`route_flow.dart`), keeping `tom_flutter_ui` free of the CodeSpecs-only registry.
Transitions are driven by CE-AC actions (§5.10): a triggered action's outcome may be
a navigation — the route it targets is cited by its typed `CsRouteRef` const
(§5.23); the stable route-id string lives inside the const.

**SOM feed.** CE-NV derives from **D05 ISC** (scenarios / processes define the
screens and their transitions) + **D02 TOM**, per §8 — grouped with CE-AC/CE-SC as
the "scenarios/processes define actions, triggers, transitions" feed. The
screen-flow edges (form→screen assignment, presentation mode, action-outcome
targets) are authored in the **screen route map** (`SCRTMP`, D09 XDS). The route-id a
CE-AC transition targets is the §5.10 action outcome; a route's destination
`authorizer` is CE-AZ; its label/tooltip is CE-TX.

### 5.12 CE-LO layout — CsLayout node model grounded on the ACL substrate

**Decision.** The **§5.2 two-layer, id-addressed `@CsLayout` node model** is
grounded on the concrete `tom_flutter_ui` **Advanced Container Layout (ACL)**
substrate + the `tom_core_flutter` observation binding. §5.2 fixes the design
(generated base + override delta layer; container node + slot node; stable node
ids; non-destructive override survival); this section fixes *which surveyed classes
realise each node kind* and where the CodeSpecs-only structure lives (the
`tom_flutter_ui` basis per §1.1 pillar (b)). The override-separable node model lives in
**`tom_core_codespecs`** as `TomLayoutModel` over the sealed `TomLayoutNode`
(`layout_node.dart`; a concrete class, **not** an abstract `Cs*` base; §4.1
no-base-classes rule). CE-LO lives in the **client** project (§4.2).

**Built on (ACL layout substrate + observation binding).** The §5.2 node kinds map
onto the surveyed classes:

| §5.2 node kind | Surveyed class | Package | Role |
|----------------|----------------|---------|------|
| **Container node** — kinds `row` / `column` (layout-only props + ordered children) | `AclRow` / `AclContainer` / `Acl`/`AclLayout` | `tom_flutter_ui` (`advanced_container_layout/acl_container.dart`) | The fluent row/column container: an `AclRow` **is** the `row` kind and an `AclContainer`'s row list **is** the `column` kind; `AclRow.components` (ordered children) + `alignment`; `AclFlags` carries the AWT-mirrored **layout-only** constraint flags. Realises the §5.2 container node's alignment/spacing + children. |
| **Container node** — kinds `wrap` / `grid` (flow a flat child list into rows) | `AclFlowKind` / `aclWrapRows` / `aclGridRows` / `AclFlowContainer` | `tom_flutter_ui` (`advanced_container_layout/acl_flow.dart`) | Carries the two D09 XDS `layoutDirection` values the row list cannot express. **Row-generating**, not a second engine: each computes an `AclRow` list from one flat child sequence (wrap breaks on fit, grid every *n* cells with breakpointed `columns`) and renders it through `AclContainer`, so ids, anchors, variants and the auth pass are inherited. Generated rows are addressable as `<containerId>.r<n>`. |
| **Slot node (leaf)** (reference-by-id to a CE-EL/CE-FM element + per-slot hints) | `AclComponent` | `tom_flutter_ui` (same file) | A layout component wrapping a `child` widget (= the CE-EL element it positions), already carrying a stable **`id`**, `referenceKey` / `alignXToKey` / `alignYToKey` (**id-addressed alignment**), `flags`, `gapBefore`, and preferred/min/max sizes — the per-slot layout hints. The substrate's native id-addressing is exactly what the §5.2 override layer keys against. |
| **Reactive rebind** (layout responds to CE-ST observable state) | `TomObservingWidget<T extends TomObservable>` | **`tom_core_flutter`** (`tomclient/observing/tom_observing_widget.dart`) | Bridges the kernel observation model to Flutter — rebuilds on every notification. Wires responsive/visibility layout to CE-ST state. |

**Why the substrate fits §5.2 cleanly.** `AclComponent` **already** separates the
*positioning* concern (id, alignment-by-key, flex/gap/sizes) from the *content* it
holds (`child`) — the exact semantics↔layout split §5.2 mandates, so the slot node is
a near-direct reuse. The `id` + `referenceKey` addressing means the §5.2 override
deltas (reparent a slot, change a container's direction, set a flex) can be expressed
as **id-keyed patches over `AclComponent`/`AclRow`** with no new addressing scheme.

**The override-separable node model (the CodeSpecs-only work).** ACL is a *rendering*
API — it draws a layout but has no notion of a *generated base + surviving override
layer*. That two-layer, regeneration-safe structure (§5.2) is the **CodeSpecs-only**
addition; it lives as a **concrete
override-separable-node-model class in `tom_core_codespecs`** (`TomLayoutModel` +
`TomLayoutOverrideDelta`, `layout_node.dart`), keeping `tom_flutter_ui`
free of the CodeSpecs-only build-time structure. It emits an ACL tree at render time.

> **Substrate location note.** `TomObservingWidget` lives in
> **`tom_core_flutter`**, not `tom_flutter_ui`; the CE-LO code basis groups it
> with the ACL classes under the "tom_flutter_ui" substrate heading. This is a precision on
> the survey — both are tom_core-family packages (§1.1 pillar (b)).

**SOM feed.** CE-LO base structure ← **D09 XDS** screen/form layout (+ **D05 ISC**
screen naming); the override layer is authored, not derived; join key `@SectionId`
(§5.2, §8). The concrete per-node attribute set and the override-delta grammar are
§5.22.

### 5.13 CE-DB entity/column/repository-query surface + entity-model placement

**Decision.** The CE-DB attribute inventory and the **entity-model placement**
(client DTO vs server-side entity). This section records both the placement
decision and the full CE-DB attribute surface. The `@CsTable`/`@CsColumn`/`@CsRepository`
code basis is the `tom_core_server` persistence model.

**Attribute surface (final).** The complete entity / column / repository-query
attribute set for CE-DB:

- **Entity level** — entity name, storage table, datasource, schema, identity
  attribute + identity column, row-scope rule.
- **Attribute level** (per persistent field) — attribute name, storage column,
  value type, **storage nullability**, column (storage) type, read-only,
  not-loaded, json-encoded, **column-access key** (field-level authorization,
  → CE-AZ), value converters, the **sensitivity classification**
  (`DAATT-SECU.sensitivityLevel` + `isPii` → `@CsColumn(sensitivityLevel:,
  isPii:)`, recorded for downstream consumers — encryption-at-rest policy,
  export redaction, audit scoping — while enforcement stays with the
  column-access key), and — for a file reference only — the
  **file-reference facet** below.
  Two of these are not free-standing settings but consequences of the attribute's
  logical kind, and §5.13.2 records where each is authored: **json-encoded** is
  the `json` kind itself, and an enumerated attribute's **value type** is the
  generated domain enum, which must therefore be *named*.
- **Access-object (repository)** — entity type + key type, named query, query
  predicate (`eq`/`like`/`between`/`isIn`/`and`/`or`/…), sort, row cap, distinct,
  transaction scope (unit of work).

**Optional columns — a plain nullable field, never an observable.** A column
whose storage nullability is `Yes` (`DATAA.nullable`) emits a plain nullable
Dart member (`String?`, `int?`, `DateTime?`, …); `No` emits the non-nullable
type. Storage nullability is read here rather than the requirement level:
`DATAA.mandatory` is CE-VA's (`DataAttributeConstraintEntry` carries
`@CodeSpecKind([CodeSpecPart.validation])`) and answers a different question —
an `Optional` attribute with a default is never `NULL` in the table, and a
`Required` one can still be `nullable: Yes` in a schema inherited from a
predecessor system.

The `TomN*` observable arm CE-ST uses (§5.4) is **not** available here, and the
reason is the write path, not a style preference. `TomSqlDatasourceRepository`
binds each column through `TomColumnInformation.getVariableValue`, which reads
the *field*; on an observable member that yields the `TomNInt` object rather
than the `int?` it holds. Reading is symmetric — `MariadbDatasource` normalises
a declared nullable element type onto its non-nullable form before dispatching
(`mariadb_datasource.dart`, `_setObservableMember`), which is exactly why the
choice looks free — but writing is not, so an observable-membered entity has no
save at all. `tom_core_server/test/optional_column_emission_db_test.dart` holds
both arms against a live MariaDB rather than asserting the asymmetry. The
shipped framework entities agree: `TomUserPreference` declares its own optional
column as a bare `DateTime? updatedAt`.

Framework-internal plumbing (SQL dialect, prepared-statement placeholders,
`TomTransactionParticipant` lifecycle, `TomColumnInformation`, …) is **not** spec
input, per that inventory.

**Substrate status — transaction scope is per flow, and the flow opens it.**
`TomTransactionManager` holds the current transaction in a **`Zone` value**
(`tom_core_server` `transactions/transaction_manager.dart`), so *current*
means current to this **flow of work**, not to this isolate:
`runInTransactionScope` forks a zone carrying its own scope cell, and `TomServer`
opens one per request (`tomserver/server/server.dart`). Two concurrently
served requests each run in their own unit of work, so a declared transaction
scope is honoured as declared.

`@CsRepository` carries nothing for it, and the ambient shape is the reason: the
scope is a property of the flow the call runs in, not a context threaded through
the call. A declared unit of work therefore adds no parameter to the access
object and no entry to the attribute surface above — the marker stays note-only.

**Outside a request, the flow must open its own scope.** Code running under no
scope shares one **process-wide fallback** scope — correct for a program with a
single flow of work, wrong for concurrent ones. A CE-JB job is exactly that case:
the scheduler starts each due run without awaiting it (`tom_core_kernel`
`tombase/scheduling/scheduler.dart`, `_dispatchDue`) and opens no scope, nor can
it — `tom_core_kernel` cannot reach `tom_core_server`. Under the production
`TomWorkerPoolJobDispatcher` the fallback is nonetheless safe by construction:
`TomWorkerPool.execute` holds a worker busy for the whole command, so one command
runs per isolate and a static is per-isolate. Under `TomInlineJobDispatcher`,
which runs the body in the calling isolate, two concurrent job bodies share it.

**CE-JB emission therefore opens the scope itself** — the generated work body is
wrapped in `TomTransactionManager.runInTransactionScope`
(`codespecs_derivation_contract.md` §3.7.1). It is wrapped **unconditionally**,
not only where a unit of work is declared: the job's work is specified as prose
intent rather than as persistence calls (§5.29), so the spec cannot see which
runs will open a transaction, and a scope that is opened and unused costs one
zone fork.

#### 5.13.1 File-reference columns

**Decision.** A column whose value is the **address of a stored file** rather
than a value is *one more column kind*, carried by an optional
`CsFileReference` facet on `@CsColumn` — not a second annotation and not a
`ColumnKind` tag. **The facet's presence is the kind.** A kind tag with no
payload would push the facet's four settings onto `@CsColumn` itself, where they
are meaningless for every other column; a second annotation would be the
parallel branch every other part avoids.

It is a distinct kind because a file-reference column is the one column not fully
described by its value type: rendering it means knowing where the file lives,
and specifying it means naming the group it is filed under and what may be put
there. Nothing in the ordinary attribute surface above answers any of that.

The substrate is `tom_core_server`'s file-storage module — `TomFileReference`
(the persistence-side column annotation), `TomFileReferenceKeys` (key generation
and store resolution) and `TomBlobStore` (the four-method streaming contract with
database / directory / S3 / memory backends selected from configuration). Per
§1.1 pillar (b) there is **no `tom_core_codespecs` gap class**: the facet mirrors
`TomFileReference` one-for-one, so a CodeSpec builds on the substrate class
directly. The repository resolves `saveFile` / `openFile` / `describeFile` /
`clearFile` plus cascade-on-delete under the same C-4 column grade as any other
column. See `tom_core_server/doc/file_storage.md`.

| Attribute | `tom_core` source | Req? | Neutral DocSpecs term |
|-----------|-------------------|------|------------------------|
| Storage group | `TomFileReference.keyPrefix` | Y | Storage group |
| File store | `TomFileReference.store` | N | File store |
| Delete with record | `TomFileReference.cascadeDelete` (default `true`) | N | File reference |
| Default content kind | `TomFileReference.mediaType` | N | Content kind |
| Accepted content kinds | *(none — enforced at the CE-API upload operation)* | N | Content kind |
| Stored address | `TomFileReferenceKeys` — generated `<group>/<yyyy>/<mm>/<uuid>` | D | File reference |

The address is **derived, never authored**: it is generated when the file is
stored and never taken from the client, so a specification chooses only the
group it is filed under.

**Boundaries drawn.** Three decisions that look like they belong on the facet are
elsewhere, each for a reason that would otherwise produce a duplicate rule:

- **Whether a file may be fetched** is the column's own authorization. The
  address is an ordinary column, so `@TomDbScope` (C-3) and the column's access
  key (C-4) already gate it, and `openFile` resolves through `findById` — a
  principal who cannot see the row cannot see its file *by construction*. A
  `downloadable` flag would be a second authorization rule that could disagree
  with the first.
- **Whether the cell shows a thumbnail, a link or a download** is presentation,
  therefore CE-EL. CE-DB is server-only (above), so a rendering attribute
  declared here would be unreachable by the client that has to honour it. The
  arm that receives it is the **FileInput** semantic kind and its `presentation`
  attribute (§5.18) — *link* / *dropzone* / *thumbnail*. The one refinement
  §5.18 makes on the way is that **download is not one of the three**: whether a
  download affordance appears follows from the field being wired for transfer
  and the file being stored, so authoring it would be a second rule of exactly
  the kind this list exists to prevent.
- **How a file is uploaded and served** is CE-API: `saveFile` / `describeFile` /
  `openFile` are called from an endpoint, which is where the accepted content
  kinds are enforced and where the transport-level refusals are raised.

**SOM feed.** `DataAttributeKind.fileReference` on `DataAttributeEntry` (D03 IMO
via the SBP information-and-data model), with the promoted `@OneOf` case
`fileReferenceOptions` (`DAATT-DTFR`) carrying the storage group, file store,
delete-with-record, accepted and default content kinds, and max file size. It is
a **kind of its own, not a storage mode of `binary`**: `binary` means the record
holds the bytes, so its options constrain their stored size, and a mode field
would restate the logical type and could then disagree with it.

**Placement — server-only.** CE-DB is
**server-only** (`<app>_codespec_server`, §4.2): the persisted entity and its
`@CsTable`/`@CsColumn`/`@CsRepository` live **only** on the server. The two roles the
"client DTO" alternative conflated are instead served by two *other* parts:

- **Across-the-wire shape** → the **CE-API request/response types** in
  `<app>_codespec_shared` (§4.2) — the DTOs both sides depend on. What crosses the
  wire is a CE-API shape, never a DB entity.
- **In-screen data** → the **CE-ST view-model** (§5.4, client) — typed view state
  hydrated from a CE-API response, distinct from the persisted entity (the CE-ST↔CE-DB
  separation, §5.4).

**Why server-only wins.** Keeping columns / datasource / SQL / row-scope /
transactions off the client (a) preserves the CE-ST↔CE-DB separation §5.4 already
mandates, (b) keeps the shared contract to only what crosses the wire (CE-API
shapes), and (c) matches the service-unit ownership model §5.1 — a service unit owns
its aggregate entities *and their repositories* server-side, exposing them only
through CE-API operations. A client "DB entity" would leak persistence structure past
the API boundary and duplicate the view-model's job.

**SOM feed.** CE-DB is derived from **D03 IMO** rich classes (tables, columns, DAOs),
per §8.

**CE-DB ↔ CE-MG.** The entity model and the migration artifacts describe the
same schema from two sides: `@CsTable`/`@CsColumn` declare the *target* shape,
the CE-MG migration chain (§5.27) produces it *cumulatively*. Their convergence
— cumulative DDL ≡ declared entity model — is the named CE-MG schema-convergence
validator check (§5.27); neither side is generated from the other.

#### 5.13.2 Enumerated columns, and the three kinds that really are attribute-free

**Decision.** An attribute typed by a **domain enum names the enum**; `boolean`,
`uuid` and `json` author nothing beyond their logical kind.

An enumerated column is not attribute-free, which is what its `@OneOf` constant
had assumed. The emitted column's **value type is the generated enum type** —
`TomDbColumn<DART_TYPE, COL_TYPE>` takes the Dart-side type as a parameter — so a
column whose attribute names no enum cannot be emitted at all. The SOM feed is
therefore the promoted case `enumerationTypeOptions` (`DAATT-DTEN`), one required
field naming a `DomainEnumEntry`.

The enum is **named, never restated**. `DomainEnumRegistry` (DOMEN) is the single
source for closed value sets and is what the `domainEnum` member kind (§4.1) is
generated from; a second list of the values on the attribute could disagree with
it. This is the same shape the model already uses everywhere else it types a
value by an enum — a CE-API request/response member (`SVOPM.domainEnum`) and a
CE-RP report parameter (`TomReportParameter.enumId`, required exactly when the
parameter's type is enumerated, §5.28) both name the entry.

Two neighbouring answers stay where they are, so that naming the enum adds no
second home for either:

- **How the value is stored** belongs to the enum (`DMENE.backingType`), not to
  each attribute typed by it — otherwise two columns of the same enum could store
  it differently.
- **Which of the enum's values this attribute permits** is a *narrowing*, so it
  is a constraint (`DATAA.allowedValues`, CE-VA) like every other per-attribute
  restriction. Declaring a set and narrowing a set are different acts; only the
  second is per-attribute.

The other three kinds were checked against the attribute surface above and author
nothing:

| Kind | Why it binds no case |
|------|----------------------|
| `boolean` | A truth value has no length, precision, range or value set. Its whole surface is its value type, which the discriminator already states. |
| `uuid` | Nothing about a generated identifier is *chosen* — the value is machine-generated, as a file reference's stored address is (§5.13.1). Whether it is the entity's key is the **entity**-level identity attribute, not a type option. |
| `json` | The surface carries the kind as a single flag (`TomDbColumn.isJson`) with no payload beside it, and the flag follows from the kind. Deliberately **no schema reference**: a JSON payload whose shape is *known* is modelled as nested data entities, and one whose shape is only *checked* is checked by a CE-VA constraint — a schema attribute here would be a second home for one of those two answers. |

### 5.14 CE-API + CE-SC operation/request/response attribute surface under §7

**Decision.** The **CE-API** (server operation surface) and **CE-SC** (client call
assembly + action edge) attribute inventories, aligned to the **§7 server contract**
. The code bases are **`@CsEndpoint`**
(§5.6.1) and **`@CsServerCall`** + the two-hop CE-AC→CE-SC→CE-API edge (§5.3); this
section fixes the *attribute surface* both carry. **Non-overlap rule:** a
`@CsServerCall` never authors or re-declares a contract member — operation name,
`T`/`R` shapes and error codes are CE-API-owned; CE-SC only cites them (§5.3).

**CE-API operation surface (final, §7-aligned).** Per the §7 contract:

- **Method is fixed POST** — dropped as a spec input. The **operation name** (not
  verb+path) carries intent and is the one required operation identifier.
- **Typed request shape** + **typed response shape**, where the response type **is**
  the CE-ER `Result<T>` envelope (success payload *or* structured error).
- **Error-response types narrow to 5xx transport errors only**
  (`statusCodeResponseTypes` = infrastructure failure); every **2xx** response is the
  `Result<T>` envelope, so an application error is never a status code.
- Description → CE-TX; authorization requirement → CE-AZ; base path / consumes /
  produces are transport defaults (JSON). Framework transport members
  (encoding, redirects, headers, CORS, bearer-auth plumbing) are **not** spec input.
- **Placement:** the CE-API server surface is **server** (`<app>_codespec_server`);
  the request/response **types** are **shared** (`<app>_codespec_shared`, §4.2) — the
  DTOs both sides depend on (the §5.13 "what crosses the wire" role).
- **Shape:** those types — the request shape, the CE-ER envelope and every payload
  inside it — are **reflection-first**. Each is generated as a `@tomReflectable`
  class of **plain non-`final` fields** with **no hand-written `toJson`/`fromJson`**,
  because both tiers serialize through the kernel's two reflection entry points and
  nothing else. A `final` member cannot be assigned after construction, so reflection
  can never restore it: the kernel refuses such a class rather than degrading
  quietly — inbound with
  `reflection.set.unexpected_condition_final_static_private`, outbound with
  `reflector.type.all_final`. An immutable envelope is therefore not a style choice
  the derivation may make.
- **Entity-typed members:** an operation member typed by a data entity
  (`SVOPM.dataEntity`) is typed by that entity's **wire DTO** — a shared,
  markerless, derived row shape (`codespecs_derivation_contract.md` §3.2.11) —
  never by the CE-DB entity class, which is server-only (§4.2). The entity facts
  reach the CE-API extract by dual routing: `DAENT` / `DAATT` / `DATAA` list
  `serverApi` beside `dataAccess` in their `@CodeSpecKind`, because the shared
  slice-2 emission may not forward-reference slice 3 (§4.4).

**CE-SC client-call surface (final, §7-aligned).** The client-side consumption of a
CE-API operation:

- **Target operation** — a typed `CsOperationRef` const to a CE-API operation
  (§5.23; the §5.3 hop-2 edge).
- **Request payload** — assembled from the **CE-ST view-model** (§5.4): save copies
  view-model → request shape.
- **Response handling** — `R` **is** the CE-ER `Result<T>` envelope (success updates
  the view-model, structured error resolves to CE-TX copy by CE-ER code);
  `TomServerCallError` captures **5xx transport failure only**.
- **Triggering action** — the CE-AC edge (the §5.3/§5.10 two-hop chain; typed
  const references per §5.23).
- **Local-vs-server** classification.
- **Placement:** **client** (`<app>_codespec_client`, §4.2). `TomServerCall` /
  `TomServerChannel` / `TomServerCallSpecs` transport plumbing stays
  framework-internal.

**SOM feed.** The application's **own** operations are authored in the
`ServerOperationRegistry` (`SVOPR`) — one `ServerOperationEntry` (`SVOPE`) per
operation, carrying the name, the primary written entity (§5.17), the CE-AZ
requirement, the returnable error codes and the request/response members
(`SVOPM`). The registry sits under `InformationAndDataModel` (→ **D03 IFM**),
beside the error-code, message-key and domain-enum registries the operation
surface references, and is projected by `D13CodeSpecsProjection`. The CE-SC
client call + action edge come from **D05 ISC** (the step entries), and the
request-payload and response-handling bullets above from the `SVCST` list each
step carries, routed by its required `role` (§5.3). **D07 IFS**
feeds the *external* interface inventory — foreign contracts the application
calls (CE-SC outbound), never its own operations; **D06 ATS** contributes the
technology selection.

### 5.15 CE-AZ authorization-requirement attribute surface

§5.6.3 fixes the `@CsAuthorize` **base** (a reuse modifier on `@CsEndpoint` carrying
a `TomAccessControl`); this section fixes the requirement **attribute surface**.

**Built on (grounded against source).** The kernel access-control model is a sealed
family: `TomAccessControl` (abstract, `access_controls.dart`) with
`checkAccessibility(principal)` (binary) + `resolveAuthState(principal)` (four-state,
default `full`/`none`). A spec expresses an authorization **requirement**; the concrete
subclass *is the shape* of that requirement. The requirement kind is therefore a
**closed discriminated choice** — exactly the `@OneOf`/`@Case` closed-choice
mechanism (§8.2): one
`@OneOf` requirement, one `@Case` per kind, each case with its own attribute set.

**The six attribute-bearing requirement kinds** (each a distinct `@Case` payload):

| # | Requirement kind | `@Case` payload attribute(s) | `tom_core` source |
|---|------------------|------------------------------|-------------------|
| 1 | **Role** | `roles: List<CsRoleRef>` — typed consts from the shared role catalogue (§5.23), lowered to `TomRoleAccess.roles` strings at generation | `TomRoleAccess.roles` (`:669`) |
| 2 | **Group** | `groups: List<String>` | `TomGroupAccess.groups` (`:702`) |
| 3 | **Entitlement** | `patterns: List<String>` (entitlement match patterns) | `TomEntitlementAccess.patterns` (`:589`) |
| 4 | **Resource-key** | `key: CsResourceKeyRef` — a typed const from the shared resource-key catalogue (§5.23), lowered to `TomResourceKeyAccess.key` at generation | `TomResourceKeyAccess.key` (`:729`) |
| 5 | **Custom** | `handler: String` + `resourceId: String` (registered handler ref + resource) | `TomCustomAccess.handler`/`resourceId` (`:532`/`:535`) |
| 6 | **Graded** | a **level list** — one entry per authored access state (`full` / `read` / `disabled`), each entry carrying a *non-graded* requirement (kinds 1–5 or a preset) | `TomGradedAccess.full`/`read`/`disabled: TomAccessControl` (`:334`–`:341`) |

Role and resource-key requirements cite **Dart-declared catalogues** and are
therefore typed refs (§5.23). Group names, entitlement match patterns and the
custom handler/resource ids reference **runtime principal data and runtime
handler registrations**, not Dart declarations — they stay strings under the
§5.23 exemption logic, validator-checked (§12).

**Attribute-less presets** (a kind selector with *no* payload — still valid discriminator
values so the choice is exhaustive): `TomNoAccess` (deny), `TomPublicAccess` (allow),
`TomAuthenticatedAccess` (any signed-in user), `TomGuestAccess`. These carry no
spec-authorable attributes — the kind *is* the whole requirement, so they get **no
`@Case` arm at all** and are listed in the group's `@OneOf(noCase: [...])`, which
is how the `tom_specs_model_rules.md` §10.2 validator tells this shape from a case nobody has written yet.

**The SOM sections.** The choice is authored **once**, in
`tom_specs_model/lib/src/common/authorization_requirement.dart`, and every modifier
site embeds that one section rather than restating a requirement of its own:

| Section id | Class | Role |
|------------|-------|------|
| **`AZREQ`** | `AuthorizationRequirementSpec` | The requirement itself — `@OneOf(discriminator: 'requirementKind')` over the ten-constant `AuthorizationRequirementKind`, with `@Case` arms `AZREQ-ROLE` / `-GRUP` / `-ENTL` / `-RKEY` / `-CUST` for kinds 1–5 and a `gradedRequirement` arm for kind 6 |
| **`AZGRD`** | `GradedAuthorizationRequirement` | The kind-6 payload — a `gradingRationale` plus the `AZLVL-LEVE-xxx` level list |
| **`AZLVL`** | `GradedAccessLevelEntry` | One graded rung — an `accessLevel` (`full`/`read`/`disabled`) plus a **non-graded** requirement over the nine-constant `BasicAuthorizationRequirementKind`, with the same five `@Case` arms |

`AZREQ` **names** a role or resource key by reference; it does not define what one
means. The authoring homes for those stay where §8.5 records them — `RoleMatrix` /
`ROLPER` / `ENT` in D08 SAS. Deny is spelled **`denied`**, not `none`: in an authored
document "None" reads as *no authorization needed*, the exact fail-open misreading the
§5.16 precedence rules guard against. One derivation row therefore carries the rename,
`denied → CsAuthRequirement.none`.

**The graded depth is bounded at one level, deliberately.** A level whose requirement
could itself be graded would make the SOM structurally cyclic, and
`tom_specs_model_rules.md` §5.7 makes a structural cycle a hard error — the outliner,
the serializers and the nine generated language runtimes all walk the class graph as a
tree. The bound is not a workaround for that constraint: a graded thing resolves to one
of four *terminal* access states, so a second grading nested inside a level has nothing
left to resolve to. The price is that `AZLVL` restates five of `AZREQ`'s case forms;
that duplication is deliberate, because the SOM composes by field and not by subtyping
(§8.2), and removing it by pointing the levels back at `AZREQ` reintroduces the cycle.
The code side is unbounded (`CsGradedAccess.full`/`read`/`disabled` are each a
`@CsAuthorize` that may itself be `graded`), so the bound is enforced there by
`codespecs_derivation_contract.md` §6 check 21 rather than by the type.

**Graded levels** (the outcome dimension). Binary kinds (1–5, presets) resolve to the
two-state `full`/`none` via the `resolveAuthState` default; **Graded** (kind 6) is the
only kind that reaches all four `TomAuthState` values — `none < disabled < read < full`
(`tom_authorization.dart`), with monotonic defaults **`read` ⇐ `full`** and
**`disabled` ⇐ `read`** so the common case authors only `full`. The four states carry
fixed UI semantics (`none` hidden · `disabled` visible-but-locked · `read` value-shown ·
`full` interactive), so the level→render mapping is framework-fixed, **not** a spec
attribute. `showsContent` = read|full is the accessibility predicate.

**Field-level authKey** (the cross-part attribute). A **resource-key requirement**
(kind 4) attached to a *field* rather than an operation — the same
`CsResourceKeyRef` consts (§5.23): `TomDbColumn.authKey` on a
CE-DB column (§5.13) and the `authorizer`
(→ `TomGradedAccess`) on a CE-EL/CE-FM `TomField` / CE-AC `TomAction` / CE-NV
destination. `@CsAuthorize` at field level therefore rides on those parts, not on an
endpoint. The `TomResourceKeyProtection` global-setting toggles
(`useAutomaticEndpointProtection`, `…FormFieldProtection`, `…DatabaseProtection`, …,
`access_controls.dart`) are **deployment configuration → CE-CF**, not per-requirement
spec input — they switch *whether* the automatic field/endpoint/db protection layer is
active, not *what* any single requirement demands.

**Framework-internal (not spec input).** `TomPrincipal` (~20 runtime identity fields),
`TomAccessControlInformation` collections, `TomResourceRoleRegistry` /
`TomPrincipalResourceGrant` persistence, `TomResourceGrant` /
`TomGradedAccessControlInformation` server-side grants + delegation, the
`TomAccessControl.checkAccessibility` / `resolveAuthState` evaluation entry
points and the `TomEndpointHandler.checkAccess` pipeline hook that calls them
(three distinct methods — the first two are the kernel's, the third the
server's) — these are the runtime that *evaluates* a requirement, never
authored per operation.

**Boundaries drawn.**
- **CE-AZ ↔ CE-AU.** CE-AZ is *what a caller must satisfy* (a requirement over the
  principal's roles/groups/keys); **CE-AU** is *how the principal is established*
  (credential exchange, token/claims, session). CE-AZ consumes the authenticated
  `TomPrincipal`; it does not model login.
- **CE-AZ ↔ CE-CF.** Per-requirement demands (roles/keys/graded tree) are CE-AZ; the
  global `TomResourceKeyProtection` on/off switches and the JWT/key material the check
  needs are **CE-CF** deployment config (already drawn in §5.5).
- **CE-AZ ↔ server-level grants.** A per-requirement demand (this operation needs
  role/key/entitlement X) is CE-AZ; which features the **server deployment
  itself** is granted is a server-level entitlement set carried by the server's
  own principal (§5.26). At CE-AZ evaluation the two meet: effective
  authorization = `min(user, server)` over the four-state levels, binary AND
  otherwise (§5.26).
- **CE-AZ is a modifier, not a standalone part** (§4.1 rule). It is authored **as an
  attribute** on the owning `@CsEndpoint` (operation-level) or on a CE-EL/CE-FM/CE-AC/
  CE-NV/CE-DB element (field-level graded/resource-key). Reuse only — no gap class.

**Placement.** Operation-level `@CsAuthorize` lives in `<app>_codespec_server` (on the
endpoint). Field-level graded/resource-key requirements ride their host part —
client for the CE-EL/CE-FM/CE-AC/CE-NV `authorizer`, server for the CE-DB column
`authKey`. The `TomAccessControl` requirement *type* itself is kernel, visible to both.

**SOM feed.** CE-AZ derives from the **`AZREQ` section embedded at each modifier
site** — `ServerOperationEntry.authorization` (D00 SBP IMO) for the operation-level
case, and the `access` member on the D00 SBP XDS screen / screen-element / navigation
group / navigation item / tab / utility-navigation / utility-menu / deep-link / report /
export-format / export-template sections for the element- and field-level cases. The
catalogues those requirements *cite* — roles, entitlements, resource keys — remain
**D08 SAS** (`RoleMatrix` / `ROLPER` / `ENT` / `RESKEY`), per §8. A site that carries
no `AZREQ` is a specification defect, not an implicit allow: the choice has no default
arm.

### 5.16 CE-CF / CE-CC / CE-DS / CE-UP config attribute surface + cross-scope source precedence

§5.5 fixes the CE-CF **model** and the four-scope split (CE-CF server / CE-CC
client-install / CE-DS user+device / CE-UP user); this section fixes the config
**attribute surface** (spec-authorable vs framework-internal, per scope) and the
**source precedence** — which source wins when the same logical key is
expressible at more than one scope.

**Config-surface split — what is spec-authorable, per scope.** A config *declaration*
(key · type · default · source) is spec-authorable; a config *value* (the deployed
secret, the user's chosen preference) is supplied at deploy/run time, never authored.

| Scope | Part | Spec-authorable (the declaration) | Value origin (not authored) | Framework-internal |
|-------|------|-----------------------------------|-----------------------------|--------------------|
| **Server / system** | CE-CF `@CsServerConfig` | typed setting fields (`appId`, `host`/`port`, `isolateCount`, `logLevel(s)`, `databaseMigrationsDirectory`, server feature flags); secret-bearing fields (`certificateChain`/`privateKey`, `jwtRsaPubKey`/`jwtRsaPrivKey`/`jwtSharedSecretKey`) declared **and marked secret**; per-field source key + precedence | deployment (config-tree/env/`.env`/cmdline) | middleware/handlers, `loggingMiddleware`, provider singletons, self-signed cert literals |
| **Client install** | CE-CC `@CsClientConfig` | setting `key` (dotted) · value type (`String`/`int`/`double`/`bool`) · declared default | client app config resources (`TomConfigResourceProvider`) **and** this install's persisted overrides (`TomClientConfigurationStore`) | `TomBaseClientConfiguration`'s declaration/baseline machinery, the coercion of loosely-typed external values, the store's write-then-rename |
| **User + device** | CE-DS `@CsDeviceSetting` | setting `key` · type · default | the user's persisted choice on this device, read through `TomDevicePreferences` (`tom_core_flutter`) | `TomStoredDevicePreferences` over a per-platform `TomDevicePreferenceStore`, and the store's `location` — which is where the user dimension lives |
| **User** | CE-UP `@CsUserSetting` | setting `key` · type · default | the user's persisted choice on the account, read through `TomUserPreferences` (`tom_core_server`) or `TomUserPreferencesClient` (`tom_core_flutter`) | `TomUserPreferenceRepository` behind `tomUserPreferencesApi`'s four endpoints over `TomUserPreferenceDto`, and the request-zone principal the store binds the user from |

The secret fields (TLS private key, JWT keys) are the exception to "declaration is
authored": their *presence and shape* are declared in CE-CF, but their **values are
never authored** — they are marked secret so §12 production-stripping and deployment
tooling supply them out-of-band.

**Source precedence — two orthogonal dimensions.**

1. **Intra-scope** (within one part, already fixed by the substrate):
   - CE-CF: `TomBaseServerConfiguration` merges **config-tree → OS env → `.env` →
     cmdline**, *cmdline wins* (§5.5). A field may opt to be pinned to one source.
   - CE-CC: `TomBaseClientConfiguration` resolves **this install's persisted
     override → the config-resources value → the declared default**. The lower
     two form the setting's *baseline*; a setting is *overridden* exactly when
     it differs from that baseline, and only overrides are persisted — so a
     default shipped in an app update still reaches installs that never touched
     the key.
   - CE-DS: **persisted device value → default**.
   - CE-UP: **persisted user value → default**.

2. **Cross-scope** (when *the same logical key* is declared at more than one scope):
   **most-specific-owner-wins**, but only for keys
   explicitly declared **overridable** at the narrower scope. Effective value =

   ```
   CE-DS (user+device, if declared device-overridable and set on this device)
     ▸ else CE-UP (user, if declared user-overridable and set)
       ▸ else CE-CC (client-install, if declared client-overridable and present)
         ▸ else CE-CF (server default)
   ```

   The precedence is **opt-in, not automatic**: a key is *scope-pinned* by default
   (visible only at its declaring scope, no cross-scope contest). A CE-CF key must
   explicitly declare itself client-overridable to be shadowable by CE-CC,
   user-overridable to be shadowable by CE-UP, and device-overridable to be
   shadowable by CE-DS. **Security / infrastructure config
   (TLS, JWT, DB migrations, worker counts, host/port) is CE-CF-only and declared
   non-overridable** — it can never be shadowed by a client install or a user, so no
   cross-scope contest arises for it. This makes the model **fail-safe**: broadening a
   value's blast radius is a deliberate authored act, never a default.

**The CE-DS ▸ CE-UP step is one shape with two implementations.** The two
user-scoped stores are not two unrelated mechanisms that the lattice happens to
order. `TomDevicePreferences` (C-14, `tom_core_flutter`) and `TomUserPreferences`
(C-13, `tom_core_server`) carry the **same method set** — `all` / `read` / `get`
/ `getOr` / `set` / `remove` — over the same `TomUserPreferenceKeys` vocabulary,
the same `TomUserPreferenceDto` and the same `TomUserPreferenceCodec`, all of
them the kernel's. So the two ends agree by construction rather than by
inspection, and a key that turns out to belong to the user rather than the device
**moves between the scopes without a call site changing** — which is what makes
re-scoping a setting a specification edit rather than a refactor.
`@CsUserSetting` resolves against `TomUserPreferences` itself, so the face a
re-scoped key lands on is the face it left.

**Neither API takes a principal**, and that is the same design decision twice:
each store binds the user from its context instead of from an argument — the
device store from the `location` it was opened at, the server store from the
principal in the request zone (`user_preferences_service.dart`, "the caller is
the zone, not an argument"). A parameter would invite a caller to pass a
principal it read off the request, in both places.

The step *between* them is likewise implemented once, in
`TomDevicePreferences.getPreferred`: the device value wins for as long as it
exists and the server value answers only a key this device has never written, so
the account value behaves as a cross-device default and the device value as this
machine's override. That is the §5.16 lattice's CE-DS ▸ CE-UP edge, resolved in
the substrate rather than re-derived per call site — and the server arm is passed
as a **callback**, so a device-only client is never made to carry an HTTP client
to read a local setting.

**Boundaries drawn.**
- **CE-CF ↔ CE-CC ↔ CE-DS ↔ CE-UP** are the same config-value concept at four
  owner-keyed scopes (§5.5); this section adds only the *precedence lattice*
  between them, it does not merge them.
- **CE-CF ↔ CE-AZ / CE-AU** (unchanged from §5.5): config supplies keys/material, not
  the access policy or the credential flow.
- The deeper CE-CC (`TomBaseClientConfiguration` + its store), CE-DS
  (`TomDevicePreferences` + its per-platform store) and CE-UP
  (`TomUserPreferences` + the `tomUserPreferencesApi` round trip)
  per-attribute surfaces are separate (§5.5); this
  section fixes the spec-authorable classification and the cross-scope precedence
  they operate within. The realisation annotations are `@CsServerConfig` /
  `@CsClientConfig` / `@CsDeviceSetting` / `@CsUserSetting` — one per scope.
- **CE-DS's resolver, and who supplies the user dimension.** The persisted arm of
  CE-DS's chain is **`TomDevicePreferences`** (`tom_core_flutter`
  `tomclient/preferences/device_preferences.dart`) — the interface, resolved
  as a bean, implemented by **`TomStoredDevicePreferences`**
  (`stored_device_preferences.dart`) over a **`TomDevicePreferenceStore`**
  (`device_preference_store.dart`) chosen per platform by dependency
  injection. That store is the only platform-specific part, which is what keeps a
  `@CsDeviceSetting` call site free of an `if (kIsWeb)`.

  **Its API carries no principal, deliberately**, and the user dimension is
  carried by the store's **address** instead: a store is scoped to its
  `location` and holds one flat key space, so an application on which more than
  one account can sign in gives the store a location naming the signed-in account
  and installs a new store when the account changes. The consequence to state
  plainly is that **the application supplies the user dimension, not the
  framework** — an install that gives every account one location gives them one
  set of settings, and nothing in the substrate detects it, because nothing in it
  is told a user changed.

  So CE-DS is **the same substrate as CE-CC at a different address**, not a
  framework-supplied principal key: at a fixed location the store occupies
  CE-CC's (client app, machine) scope, at a per-account location CE-DS's (user,
  device) — the user bound the same implicit-by-storage way §11 already binds the
  device. The account part of a location must be one path segment and stable for
  the life of the account (a surrogate id, or an address hashed or
  percent-encoded), since a value carrying a separator addresses a different
  store than the one intended, silently.
- **CE-UP's substrate, and who supplies the user dimension.** The persisted arm
  of CE-UP's chain is **`TomUserPreferences`** (`tom_core_server`
  `tomserver/preferences/user_preferences_service.dart`) over a
  **`TomUserPreferenceRepository`**, reached from a client through the kernel's
  **`tomUserPreferencesApi`** (`tombase/preferences/user_preferences_contract.dart`)
  — four authenticated endpoints (list keys, read, write, delete) carrying
  `TomUserPreferenceDto` — whose client end is **`TomUserPreferencesClient`**
  (`tom_core_flutter` `tomclient/preferences/user_preferences_client.dart`).
  Both ends resolve their URIs from that one `TomApi` declaration, so neither
  addresses a path of its own and the two cannot drift apart.

  **Here the framework supplies the user dimension**, which is the one structural
  difference from CE-DS: the server store binds the principal from the request
  zone rather than from an argument, so a `@CsUserSetting` call site cannot name
  a user, and signing in as another account changes every answer without
  anything being re-addressed.

**SOM feed.** CE-CF/CE-CC/CE-DS/CE-UP derive from **D06 ATS** (deployment
topology) + **D08 SAS** (which config carries secrets), per §8; the
user-facing settings scopes (CE-DS/CE-UP) additionally from **D09 XDS**
(preferences surfaced in UI).

**Authoring homes.** Each scope has exactly one repeating **declaration list**,
and the scope is expressed by *which list a setting is written in* — there is no
`scope` column and no persistence discriminator anywhere (§11). CE-CF has a
second authoring shape beside its list; the two are separated below.

| Scope | Declaration list (`@SectionId`) | Under | Authored per entry |
|-------|--------------------------------|-------|--------------------|
| CE-CF | `ServerConfigurationSettingEntry` (`SCSET`) | `SystemConfigurationManagement` (`SYCOMA`) | `settingKey` · `valueType` · `defaultValue` · `environmentVariable` · `commandLineOption` · `secret` · `overridableBy` |
| CE-CC | `ClientConfigurationSettingEntry` (`CCSET`) | `ClientConfiguration` (`CLICON`) | `settingKey` · `valueType` · `defaultValue` · `overridableBy` |
| CE-DS | `DeviceSettingEntry` (`DSSET`) | `DeviceSettings` (`DEVSET`) | `settingKey` · `valueType` · `defaultValue` |
| CE-UP | `UserSettingEntry` (`USSET`) | `UserSettings` (`USRSET`) | `settingKey` · `valueType` · `defaultValue` · `overridableBy` |

**The opt-in is authored once, at the wider scope.** `overridableBy` names the
**narrowest** scope allowed to shadow this key; since the lattice is a total
order, every scope in between is opened too, so a CE-CF key declared `device` may
be shadowed by CE-CC, CE-UP and CE-DS alike. The narrower scope's declaration of
the same key then does the shadowing, but never re-declares the permission.
There is deliberately **no** narrow-side counterpart field: stating one relation
from both ends would be two authored values that can disagree, and the
authoritative end is the one the fail-safe rule protects — the scope whose blast
radius is being broadened. CE-DS, the narrowest scope, therefore carries no
`overridableBy` at all: the lattice bottoms out there and "shadowable by
something narrower" is unsayable rather than merely wrong. CE-CF's is the one
that must stay `none` for security and infrastructure settings. **It has no
default** at either end — SOM field or `Cs*` argument: choosing a value's blast
radius by omission is precisely the failure the fail-safe rule prevents.

The `environmentVariable`, `commandLineOption` and `secret` fields are
CE-CF-only. The first two are the deployment sources the server scope reads a
value from, one-to-one with `@CsServerConfig`'s `envAlias` / `cmdlineAlias`; the
third marks a setting whose content is supplied out of band, so only its presence
and shape are authored.

**CE-CF's two authoring shapes, and the discriminator between them.** The
declaration list above is not CE-CF's only authoring home, and it is not even
its common one. **41 of the 42 CE-CF-mapped SOM sections** author settings as
**fixed-name form fields** — the audit sink (`EVATPO` / `LOSTPO` / `LOPRPO` /
`LOREPO`), encryption at rest and in transit (`ENATRE`, `ENDACA`, `DAENPO`,
`FSEP`, `BAENPO`, `ENINTR`, `TLPRPO`, `MUTLPO`, `COCHEN`), key management
(`KEGEPO`, `KESTPO`, `KEROPO`, `KEABP`, `KCRP`), API and file/storage security
(`APSE`, `APCOSE`, `APABPR`, `FASS`, `FUVP`, `STENPO`, `COSCPO`, `FDSP`), and
D09's print-and-export band (`PRLA`, `EFE`, `ETE`, `EXSISE`, `EXFIMA`).
`SCSET` is the **single** keyed list. The two shapes are kept apart, not merged,
because they answer different questions:

| | **Declared** (`SCSET`) | **Fixed** (the 41 policy/layout bands) |
|---|---|---|
| Who owns the setting's identity | the **application** — the author invents the key | the **model** — the SOM names the setting, one per form field |
| Key set | open; grows with the application | closed; one member per `Field` in the band |
| Author supplies | the whole declaration: key · type · default · sources · secret · overridability | the **value** only |
| Key | authored, verbatim (§5.23 exemption 1, N5) | derived `<band>.<field>` (N10) |
| `environmentVariable` / `commandLineOption` | authorable | absent — CE-CF-only *and* declared-only |
| `secret` | authorable | always `false` |
| `overridableBy` | authored, required, no default | always `none` |

The discriminator is **who owns the setting's identity**, and it decides which
of a setting's properties can be authored at all. This is why the fixed shape
cannot be collapsed into `SCSET`: doing so would require an author to invent a
key for every setting the model already names — 41 sections' worth of security
and deployment policy re-entered as free strings, with the model's own inventory
demoted to a hint. It is equally why `SCSET` cannot be collapsed into fixed
bands: an application's own settings are, by definition, not ones the model
knows in advance.

**Corollary — a secret is only ever declared.** A credential's identity is
application-specific, so `secret: true` is expressible in exactly one place: an
`SCSET` entry. `SCSET`'s own authoring help already names `tls.privateKey` and
`jwt.rsaPrivateKey` among its typical keys, and `AULOFO`'s says to never log
secrets at all — the model already answers this question, and this paragraph is
where the answer is written down. An audit sink needing credentials for a remote store authors them
as `SCSET` entries (`audit.sink.password`); `LOSTPO` names the storage *policy*,
never the credential to reach it. `codespecs_derivation_contract.md` §6 check 19
enforces this from the emitted code against the extracts: a `secret: true`
member's authored key must match a declared `SCSET` entry's `settingKey`, since
both shapes ride narrative-borne forms and emit the same back-link token — a key
no entry declares means the credential slot was invented in a policy section.

**Corollary — a fixed setting is never overridable.** Every fixed band is
security, infrastructure or environment-wide deployment policy, which the
fail-safe rule above already declares CE-CF-only and non-overridable. `none` is
therefore not a default chosen by omission but the only value the class admits.
A setting that genuinely should follow a user or a client install is not a fixed
band: it is CE-CC, CE-DS or CE-UP, authored in that scope's own list.

The surrounding sections keep their existing jobs: `SYCOMA` and
`ConfigurationManagement` (`CM`) author *how configuration is operated* (source,
format, vault, hot reload, versioning, audit), and `LanguageCountrySelection`
(`LACOSE`, D09 XDS) authors the language/country **picker** — the screen that
edits a CE-UP preference, not the declaration of it.

### 5.17 CE-SU service-unit attribute surface under the §5.1 boundary

**Decision.** The **CE-SU** service-unit attribute inventory under the §5.1 boundary
criterion. The code basis
(`@CsServiceUnit` first-class marker on ordinary **(abstract) classes** that cluster
the server API into functional-group closures, carrying the `tom_core_server`
server-API mapping annotations `@tomService` / `TomApiImplementation` — **no new
class**, decision (h)) and the boundary rule are §5.6.2; §5.1 fixes the three-level
precedence. This section fixes *which attributes the spec author writes* versus
*which the ownership rule derives* — the distinction the boundary criterion makes
possible.

**Authored vs derived (the boundary's key consequence).** The §5.1 rule "a unit owns
exactly one aggregate, and thereby every CE-DB table/repository over it and every
CE-API operation whose primary written entity is in it" means membership is
**derived, not independently listed**. So the CE-SU attribute surface splits:

- **Authored (the spec input):** the *unit identity* and the *aggregate root* the
  author picks, plus the explicit *process-cohesion adjustments* and the *bounded
  context* that cap it. Everything the boundary needs and nothing more. All of it
  is authored **on the entity**, in `DAENT-CLAS` — there is no separate service-unit
  registry to keep in step with the entity list, and no unit exists that no entity
  named.
- **Derived (computed by the ownership rule at generation time):** the owned entity
  set, the owned repositories, and the owned operations — all follow from the root
  aggregate + the CE-DB placement (§5.13) + the CE-API primary-written-entity rule
  (§5.14). Listing them by hand would let the spec contradict the boundary; deriving
  them makes the boundary enforceable. The derived sets are materialised as **typed
  references** — entity/repository `Type` literals and CE-API `CsOperationRef`
  consts (§5.23) — never name strings; the unit itself is citable server-side by
  its `CsServiceUnitRef` const.

**CE-SU attribute surface (final, §5.1-grounded).**

| Attribute | Authored / Derived | Req? | Source rule | Neutral DocSpecs term |
|-----------|--------------------|------|-------------|-----------------------|
| **Unit id** (`<RootAggregate>Service`, PascalCase) | Authored | Y | §5.1 identification, over `DAENT-CLAS.aggregateRoot` | Service unit (identity) |
| **Root aggregate** (root entity + lifecycle-dependent entities) | Authored | Y | §5.1 rule 1 · `DAENT-CLAS.aggregateRoot` (D03 IMO) | Data entity (aggregate root) |
| **Process-cohesion adjustment** (merge two aggregates in one transaction / split one into independent processes) | Authored | D | §5.1 rule 2 · `DAENT-CLAS.serviceUnitAggregate` (D03 IMO, from D02 TOM) | Business process (grouping adjust) |
| **Bounded context** (outer cap — the architecture module the unit sits in) | Authored | Y | §5.1 rule 3 · `DAENT-CLAS.boundedContext` (D03 IMO) → `BCE.contextName` (D06 ATS) | Architecture module (outer bound) |
| **Owned entities** (aggregate members) | Derived | — | §5.1 rule 1 | Data entity (ownership) |
| **Owned repositories** (CE-DB repos over the aggregate, §5.13) | Derived | — | §5.1 rule 1 | Query/Filter (ownership) |
| **Owned operations** (CE-API ops whose primary written entity ∈ aggregate, §5.14) | Derived | — | §5.1 rule 1 | Operation (membership) |
| **Component reference** (implementation binding) | Framework-internal | — | `TomComponentReference` | (not spec input) |

The `TomComponentReference(componentName/referencedType)` bean-wiring that the §2
inventory tentatively listed as a "D" attribute is **framework-internal** — how the
runtime resolves a service's implementation, not a boundary the author declares. It
drops from the spec surface (consistent with §5.14 dropping transport plumbing and
§5.16 dropping framework-internal config members).

**Cross-unit access (no new attribute).** A read spanning units is assigned to the
unit owning its **primary** entity, and a unit never reaches another unit's repository
directly — cross-unit data flows through the owning unit's CE-API (§5.1 ownership
rule). This is a *derivation constraint*, already fixed by §5.1; it adds no authored
attribute here.

**Boundaries drawn.**
- **CE-SU ↔ CE-DB** (§5.13): the unit *owns* the entities/repositories; CE-DB defines
  their shape. Ownership is by-aggregate (derived), not a duplicate entity list on the
  unit.
- **CE-SU ↔ CE-API** (§5.14): the unit *groups* operations; CE-API defines each
  operation's request/response. Membership is by primary-written-entity (derived).
- **CE-SU ↔ CE-AZ** (§5.15): authorization is a per-operation modifier (`@CsAuthorize`
  on `@CsEndpoint`), never a unit-level attribute — a unit is a grouping, not an
  access boundary.
- **Placement:** **server-only** (`<app>_codespec_server`, §4.2). The unit id is the
  server project's grouping key; clients see only the CE-API contract + CE-ST
  view-model, never the service-unit grouping.

**SOM feed.** CE-SU derives from **D07 IFS** (operations to group, joined by
`SVOPE.primaryDataEntity`) + **D03 IMO** — `DAENT-CLAS.aggregateRoot` anchors the
boundary, `DAENT-CLAS.serviceUnitAggregate` carries the **D02 TOM** process-cohesion
adjustment, and `DAENT-CLAS.boundedContext` names the cap, resolving against the
**D06 ATS** `BCE.contextName` registry. All four inputs reach the derivation as named
fields on the entity, per §8.

### 5.18 CE-EL field-base + per-kind extras + the closed semantic→widget catalogue

**Decision.** The **CE-EL** screen-element attribute surface — the catalogue
*contents* over the two-step shape and `tom_core_codespecs` placement of §5.7.1
(on the `tom_flutter_ui` code basis, §1.1 pillar (b)). Three things are fixed: the **field-base** spec-authorable set, the **closed
semantic-kind catalogue** (each kind's default widget + per-kind extras), and the
**semantic→widget** two-step contents.

**Field-base attribute set (spec-authorable, every CE-EL element).** Over
`TomField<T>` (`tom_flutter_ui/forms/tom_form.dart`):

| Attribute | `tom_flutter_ui` source | Req? | Neutral DocSpecs term |
|-----------|-------------------------|------|-----------------------|
| **Element id** | `TomField.tomId` | Y | Field (identity) |
| **Semantic kind** | (catalogue key, below) | Y | Field kind |
| **Value type `T`** | `TomField<T>` | Y | Field (data type) |
| **Initial value** | `TomField` constructor argument (positional `_initialValue`, `tom_form.dart`; no public getter) | N | Field |
| **Label / hint / description** | copy overrides → **CE-TX** | N | Copy (→ text) |
| **Validators** | `TomField.validators` → **CE-VA** | N | Validation rule (attached) |
| **Authorization** | `TomField.authorizer` → **CE-AZ** field-level graded | N | Authorization requirement |
| **Auto-validate** | `TomField.autoValidate` | N | Field |
| **Owning form** | `TomField.form` → **CE-FM** membership | D | Form (membership) |

Framework-internal (never spec input): `uiStateController`, `focusNode`, `autofocus`,
`clipBehavior`, prefix/suffix icon widgets, styling (`ButtonStyle`/`TextStyle`/
`StrutStyle`), `scope`/`basePath` resolution, listenables, the `widget` getter.

**Derived back-references (never authored).** The field's inline action hook
(`actionIcon`/`actionIconTooltip`/`onActionIconPressed`) and a Button's or
MenuEntry's action edge are **derived** from the §5.20 triggers that cite the
element — the trigger, whose endpoints are typed references (§5.20, §5.23), is
the **single authoring home** of the element→action edge (§5.10); the element
side only *renders* it.

**Closed semantic-kind catalogue.** The element-type catalogue
(a **documented catalogue over the reused `Tom*` widgets — no new class**, §5.7.1)
has this **closed** entry set. A spec
names the *semantic* kind; the catalogue supplies the default widget; the per-kind
column is the extra spec-authorable attributes that kind adds to the base:

| Semantic kind | Authoring home | Value `T` | Default `tom_flutter_ui` widget | Per-kind spec attributes | Neutral term |
|---------------|----------------|-----------|--------------------------------|--------------------------|--------------|
| **TextInput** | form-member | `String` | `TomTextField` | `maxLength`, `keyboardType`, `maxLines`, `obscureText` | Field kind (text) |
| **Number** | form-member | `int`/`double` | numeric `TomTextField` | `minValue`, `maxValue`, `decimals` (double only) | Field kind (numeric) + Validation rule |
| **Toggle** | form-member | `bool` (`bool?` when `tristate`) | switch/checkbox | `tristate` | Field kind (boolean) |
| **DateInput** | form-member | `DateTime` | date picker | `firstDate`, `lastDate` (bounds) | Field kind (date) + Validation rule |
| **Choice** | form-member | `enum`/object | dropdown/select | `source` (option provider, required — **derived, not authored**, for an enum-valued choice: see below) | Field kind (single choice source) |
| **MultiChoice** | form-member | `List<…>` | multi-select | `source` (required, same derivation), `minSelections`/`maxSelections` (→ CE-VA `minItems`/`maxItems`) | Field kind (multi choice source) |
| **FileInput** | form-member | `FileRef?` | `TomFormFileUpload` (`FormFieldFamily.fileUpload`; Cupertino `TomCupertinoFormFileUpload`) | `contentKinds` (accepted — `pickKind` family + `allowedExtensions`), `maxSizeBytes`, `presentation` (selects the concrete), `uploadOnPick` | Field kind (file reference) |
| **Label** | standalone | — (read-only) | `TomText` | `text` (→ CE-TX) | Copy display |
| **Button** | standalone (also in-form, e.g. submit) | — (interactive) | a `TomButtonBase` variant (`TomElevatedButton` / `TomFilledButton` / `TomTextButton` / `TomOutlinedButton` / `TomIconButton`) | `variant` (primary/secondary/… — selects the concrete class; tokens in `TomButtonVariants`), `icon` | Action element |
| **MenuEntry** | standalone | — (interactive) | menu-entry widget | owning menu/surface ref, `position` | Action element (menu) |
| **FormHost** | standalone | — (container) | form-hosting container | **CE-FM** form reference | Form placement |

The **seven input kinds** (TextInput, Number, Toggle, DateInput, Choice,
MultiChoice, FileInput) are **form-member kinds** — authored inside their owning
CE-FM form (§5.7); Label, Button, MenuEntry and FormHost are **standalone**
kinds. A
Button's or MenuEntry's action edge is not a per-kind attribute — it rides the
§5.20 trigger (derived back-reference, above). A **purely navigational** menu
entry stays CE-NV (`TomNavigationDestination`, §5.11) — MenuEntry covers
**action-triggering** entries. **FormHost** mirrors the CE-LO slot→element
separation (§5.2): the layout slot references the FormHost element; the FormHost
references the CE-FM form it places on the screen.

**A colour value is a desugaring, not a twelfth kind.** A specification may name
a **colour value** as a field's kind, and that is a useful thing to say — but it
does not add an entry to this catalogue. It **lowers onto two existing kinds**,
chosen by whether the acceptable colours are a closed set:

- **Free colour entry** lowers onto **TextInput**, whose value is the colour's
  textual form, plus a **CE-VA** `pattern` rule admitting that form (with or
  without an alpha component). The swatch that previews the entered value is a
  field decoration, not a kind: it rides the element's prefix resource.
- **Palette / design-token colour** lowers onto **Choice**, whose `source` is
  the token catalogue. This is the better realisation of a named-token
  constraint than any free chooser would be: a brand palette is a closed set,
  and Choice is the kind that cannot be left.

The lowering follows the catalogue's own three-part test for a distinct kind —
distinct value type, distinct control, distinct extras — which a colour fails on
all three. Its value type is the textual form (there is no colour value type in
the observable family, and every colour the specification model itself authors
is already a text field with a colour-notation hint); no colour control ships in
the widget substrate; and its candidate extras — palette-versus-free,
alpha-permitted, design-token-constrained — are all constraints on *which values
are acceptable*, which is the definition of a **CE-VA** rule. This is the §5.18
desugaring boundary that also governs `minSelections`/`maxSelections`, and it is
stated for the same reason: the surface form is kept because it lets the
derivation emit the pattern rule and the swatch without the author restating
them, while the realisation stays inside the eleven kinds.

The **requirement-side** field vocabulary (D04 RSP, `ScreenFieldKind`) names no
colour, and deliberately so. That vocabulary names the *kind of value a user
supplies*; a colour arrives there as text or as a choice from a palette, which
it already offers. A colour constant on that side would be authoring a
**control** in a requirements document — the one split the two vocabularies
exist to keep.

**`tristate` widens the Toggle's value type.** A two-state `Toggle` is a
`TomFormBoolField` over `bool`; a tristate one is a `TomFormNullableBoolField`
over `bool?`, where `null` is the indeterminate state
(`TomFormNullableBoolCheckbox` / `TomCupertinoFormNullableBoolToggle`,
`FormFieldFamily.nullableBoolToggle`). The attribute therefore selects the
field class rather than merely configuring one — the only per-kind attribute
in this catalogue that does.

**A Choice's per-value copy rides its source class, never a literal.** The
option list a *Choice* or *MultiChoice* offers carries one label per value, and
that label is user-visible copy — so it resolves through
`TomTextResourceProvider` like every other label. The widgets themselves render
`SelectableItem.label` verbatim (`forms/fields/tom_form_enum_object_fields.dart`),
so where the label comes from is entirely the **source class's** concern, and the
substrate ships the two that resolve it:
**`TomEnumSelectableSource<E>`** when the bound member is enum-typed, and
**`TomEnumNameSelectableSource<E>`** when it stores `Enum.name` in a `TomString`
— the shape a reflected, JSON-carried domain class takes
(`forms/selection/tom_enum_selectable_source.dart`). The two differ only in what
a selected option is *worth*; both label identically. A CodeSpec therefore never
authors an option list: naming the enum is the authoring act, and the source is
derived from the bound member's type (`codespecs_derivation_contract.md` §3.5.2).

**The SOM carrier of the per-kind extras is the field spec itself.** Every
per-kind column above is authored on `ScreenElementFieldSpec` (`SEFS`): the
data type selects the promoted options subsection carrying that kind's extras,
and the select arm (`SEFSS`) carries the **option source** a non-enum *Choice*
/ *MultiChoice* names (`optionsSource` — static list, API endpoint, or entity
query; the enum-valued case stays derived, above). `SEFS` is dual-routed
`@CodeSpecKind([form, screenElement])`, so the CE-EL extract carries these
values alongside CE-FM's — they become the named constructor parameters of the
`@CsWidget` step (`codespecs_derivation_contract.md` §3.5.3) without a second
authoring home on the element entry.

**The resolution rule** is a key derived from the *value*, not a catalogued one:
`<scope path>.<enumType>.<value>`, tried **longest scope prefix first** and
falling back to the global scope
(`TomObservableEnum.resourceKeysFor`, `tom_core_kernel`
`tombase/observable/tom_observable_enum.dart`). A value with no key in the
bundle renders its raw enum name and logs the keys that were tried — the option
stays selectable, never blank. The source re-emits its items on
`TomTextResourceProvider.appResourcesRevision`, so a locale switch relabels a
bound picker with nothing on the widget side to change and no field rebuilt.

**FileInput is the element that produces and presents a file reference.** Its
value is a `FileRef` — name, size, content kind, and the server-generated
**storage key** once the file is stored (`forms/files/file_ref.dart`) — so it is
the client-side counterpart of the §5.13.1 file-reference column: CE-DB holds the
address, FileInput is what a user puts a file into and what shows the file that
is already there. Three of its four per-kind attributes narrow what may be
chosen, and each has a carrier: the accepted **content kinds** are the
`TomFilePickKind` family (*any / image / video / audio*, passed to the picker so
the native dialog offers only matching files) plus `allowedExtensions`; the size
bound is `maxSizeBytes`. Both auto-prepend a built-in `Validator<FileRef?>`, so a
programmatic `setValue` is refused on the same terms as a picked file — the
§5.18 desugaring boundary again, and the reason neither is restated as a CE-VA
rule. `uploadOnPick` (`TomFormFileField.autoUpload`, default on) chooses whether
picking uploads immediately or the form uploads on save; it is a client
interaction decision, distinct from *how* a file is uploaded and served, which
stays CE-API (§5.13.1).

**`presentation` selects the concrete, exactly as Button's `variant` does.** It
is the attribute §5.13.1 delegates here, and it is a closed three-value set:
*link* — the compact chooser showing the file's name with its affordances
(`TomFormFileUpload`); *dropzone* — the large drop surface
(`TomFormFileDropzone`); *thumbnail* — a square preview of the file's own
content (`TomFormFileThumbnail`, reachable through
`FormFieldFamily.fileThumbnail`), which falls back to the file-kind icon for
anything Flutter has no codec for, so a non-image file stays authorable under
that value too.
**Whether a download affordance appears is not one of the values**: it is derived
from whether the field is wired for transfer and the file is stored
(`canDownload`), so authoring it would be the second rule §5.13.1 warns against —
one that could disagree with the first.

**The storage group is authored on the column, not here.** A CE-DB
file-reference column already names the group its files are filed under
(`TomFileReference.keyPrefix`, §5.13.1), and `TomFormFileField.storageSlot` is
the same fact on the client. It is therefore **derived** from the column the
field binds to (§5.4), like the element's action edge is derived from its
trigger — one authoring home, no pair of group names that can disagree. The
transfer wiring itself (`picker`, `transferClient`, `onDownload`) is application
plumbing, never spec input.

**Cardinality is a kind here, not an attribute.** The catalogue already answers
"one value or several" by splitting *Choice* from *MultiChoice*, because the two
differ in value type (`enum`/object vs `List<…>`), in widget, and in attribute
set (only the multi arm carries selection bounds). Files differ on all three the
same way, so a multi-file element would be a **twelfth kind**, not a `multiple`
flag on this one. It is deliberately **not** added: the driving SOM offers only
the singular `ScreenElementFieldKind.file` / `ScreenFieldKind.file`, and
`TomFormFileField` is `TomField<FileRef?>`, so the kind would be authorable by
nothing and realisable by nothing — building it now would breach the bounded
CodeSpecs surface (§8.1). Adding it later is a catalogue edit plus a
`List<FileRef>` field family, and its count bounds would desugar to the CE-VA
`minItems`/`maxItems` rules that already exist.

Object/nested and repeated form-typed fields are **not** element kinds — they are
CE-FM subforms (§5.7.2). The catalogue is closed: a new semantic kind is a catalogue
edit, not a free-form spec attribute, which keeps every spec's element vocabulary
finite and enforceable.

**Semantic→widget two-step (contents).** The default-widget column above is the
*default* binding; `@CsWidget` may override it per element (a `Choice` rendered as a
radio group instead of a dropdown, etc.). The **meaning** (semantic kind + `T` +
copy + validators + authorization) is authored on `@CsElement` once; the **rendering**
is the separable `@CsWidget` binding — mirroring CE-LO slot→element and CE-SC
action→operation (§5.2/§5.3).

**Boundaries drawn.**
- **CE-EL ↔ CE-VA** (§5.9): validators are *attached* to the field; the rule shapes
  live in CE-VA. Per-kind numeric/date bounds (`minValue`/`firstDate`) and the
  MultiChoice selection counts (`minSelections`/`maxSelections` → `minItems`/
  `maxItems`) are convenience field attributes that *desugar* to CE-VA field
  rules — one authoring surface, no duplication.
- **CE-EL ↔ CE-TX** (§5.8): label/hint/description/`Label.text` are copy references,
  authored once in CE-TX. A Choice's **per-value** labels are copy too, but of the
  **derived** shape (§5.21): keyed off the value rather than off the element's
  `basePath`, so they carry no catalogue entry and no `CsMessageKey` citation.
- **CE-EL ↔ CE-AZ** (§5.15): `authorizer` is a field-level graded-access modifier, not
  an element attribute of its own.
- **CE-EL ↔ CE-AC** (§5.10, §5.20): the element→action edge is authored **once on
  the trigger**, which carries both endpoints; the element side (Button, MenuEntry,
  inline action-icon) is a derived back-reference, never authored.
- **CE-EL ↔ CE-ST** (§5.4): a field's value binds to the view-model; that binding is
  the CE-ST concern.
- **CE-EL ↔ CE-DB** (§5.13.1): for a FileInput the two parts hold the two halves
  of one file — CE-DB the **address** (storage group, file store, delete-with-
  record) server-side, CE-EL the **presentation and the accepted input**
  client-side. Neither restates the other: the storage group is authored on the
  column and derived here, and the rendering choice is authored here because
  CE-DB is server-only and could not reach the client that has to honour it.
- **Placement:** **client** (`<app>_codespec_client`, §4.2); no new class — the
  catalogue is documented over the reused `TomScreenElementsProvider` + `Tom*`
  widgets (§5.7.1).

**SOM feed.** CE-EL derives from **D09 XDS** (screens / elements / forms) +
**D05 ISC** (scenarios naming screens), per §8.

### 5.19 CE-VA field-rule / form-rule attribute surface + validator declaration language

**Decision.** The **CE-VA** validation attribute surface — the field-rule /
form-rule attribute sets and the **validator declaration language** — over the
`tom_flutter_ui` substrate mapped in §5.9. §5.9 fixes the bases
(`@CsValidation`/`@CsFieldRule`/`@CsFormRule`), the field-vs-form split, and the
CE-TX/CE-ER error-key tie; this section fixes *which attributes each rule carries*
and *how a rule is declared*.

**Field-rule attribute surface (final).** A `@CsFieldRule` validates one field in
isolation (`Validator<T> → ValidationResult`, §5.9):

| Attribute | `tom_flutter_ui` source | Req? | Neutral DocSpecs term |
|-----------|-------------------------|------|-----------------------|
| **Rule kind** | one of the closed built-in catalogue (below) or a registered custom name | Y | Validation rule (field rule kind) |
| **Rule arguments** | the factory args of the kind (e.g. `minLength(int)`, `pattern(RegExp)`, `min(num)`) | Y (per kind) | Validation rule (args) |
| **Error key on fail** | spec-level a typed `CsMessageKey`/`CsErrorCode` const (§5.23); the runtime `ValidationError.errorKey` string (+ `params`) is the generated lowered form → **CE-TX/CE-ER** | Y | Error code (→ text) |
| **Async / slow** | `SlowValidator<T>` → `ValidationPending` | N | Validation rule (async) |

**Closed built-in field-rule catalogue** (over `Validators`, §5.9): `required`,
`email`, `minLength`, `maxLength`, `pattern`, `min`, `max`, `minItems`,
`maxItems`, `compose`. This is the closed standard set; a project-specific rule
is a **registered custom name** (a `Validator<T>` added to
`TomValidatorRegistry`), not a free-form attribute — same
closed-catalogue-plus-registration discipline as the §5.18 element catalogue.
All ten are carried by `Validators` (verified, §4.1.2), but **`compose` is not
a declarable token**: `TomValidatorRegistry._registerBuiltins()` registers the
other nine, and composition is the implicit semantics of the comma list below —
a declaration never writes `compose:…`.

`minItems`/`maxItems` bound a collection's **size** rather than a value; they
are typed over `Iterable<Object?>` so, by function contravariance, one rule
serves `TomField<List<String>>`, `TomField<List<int>>` and any other
collection-valued field. They are the desugaring target of the §5.18
MultiChoice `minSelections`/`maxSelections` attributes.

**Validator declaration language (final).** Over
`TomValidatorRegistry` (`resolve`/`resolveSpec`/`resolveDeclaration`/`parseSpec`), a
field's rule set is authored as a **declaration string**:

- **Grammar:** a comma-separated list of rule tokens; each token is `<name>` or
  `<name>:<arg>` or `<name>:<arg1>:<arg2>…`. Whitespace around separators is
  insignificant. Example: `required, minLength:8, pattern:^[A-Z]`.
- **Resolution:** each `<name>` resolves through `TomValidatorRegistry` to a
  `Validator<T>`; args are parsed by the registered spec parser (int / string / regex
  literal per the rule kind). An unresolved name is a spec error at generation time —
  the registry is the closed vocabulary the declaration draws from.
- **Composition:** multiple tokens compose (all must pass, `Validators.compose`
  semantics); order is authoring order. The declaration string is the **field rule**
  authoring surface; it does not express cross-field rules.

**Form-rule attribute surface (final).** A `@CsFormRule` validates across fields (a
cross-field invariant → `FormValidationError`, §5.9):

| Attribute | `tom_flutter_ui` source | Req? | Neutral DocSpecs term |
|-----------|-------------------------|------|-----------------------|
| **Involved fields** | `FormValidationError.fields` / `tomIds` — the CE-EL element ids the rule spans | Y | Validation rule (form rule scope) |
| **Rule reference** | a named cross-field predicate (registered like a field rule, but over the form's field set) | Y | Validation rule (form rule kind) |
| **Cross-field error key** | spec-level a typed `CsMessageKey`/`CsErrorCode` const (§5.23); the runtime `FormValidationError.errorKey` string is the generated lowered form → **CE-TX/CE-ER** | Y | Error code (→ text) |
| **Per-field error keys** | `FormValidationError.fieldErrorKeys` (which field each cross-field failure marks) | N | Field-level error |

A form rule is **not** part of the per-field declaration string — it is authored on
the `@CsForm` (§5.7.2) as {involved field ids + rule reference + error key}, because it
spans fields the string grammar cannot name.

**Boundaries drawn.**
- **CE-VA ↔ CE-TX / CE-ER** (§5.8, §5.9): every error key is a message key resolved
  through the CE-TX registry, keyed where appropriate by a CE-ER code — author-copy-once.
  CE-VA never carries a literal message.
- **CE-VA ↔ CE-EL** (§5.18): field rules attach to a CE-EL element; the §5.18 per-kind
  numeric/date bounds (`minValue`/`firstDate`) **desugar** to `min`/`max` field rules,
  and the MultiChoice selection counts (`minSelections`/`maxSelections`) to
  `minItems`/`maxItems` — one authoring surface, no duplication.
- **CE-VA ↔ CE-FM** (§5.7.2): form rules live on the form; the subform tree fans out
  validation (already substrate-backed).
- **Placement:** **client + shared** (§4.2) — the rules the client enforces are part of
  the shared contract the server re-checks; **no new class** — the field/form rules are
  Dart validation methods (standalone validators or methods on the `TomForm` subclass,
  §5.9).

**SOM feed.** CE-VA derives from **D04 RSP** (requirements) + **D03 IMO** (attribute
constraints), per §8 — field rules from attribute constraints, form rules from
cross-field requirements, each rule tracing back to the requirement that mandates it.

### 5.20 CE-AC action + trigger-taxonomy attribute surface over TomAction

**Decision.** The **CE-AC** attribute surface — the `@CsAction` attribute set and
the per-kind **trigger** attributes — over the `tom_flutter_ui` action substrate
mapped in §5.10. §5.10 fixes the
bases (`@CsAction` + `@CsTrigger`) and the closed **5-kind** trigger taxonomy as a
**documented classification over the reused action classes — no new class**; this
section fixes *which attributes the action and each trigger kind carries* — the
trigger taxonomy is a **documented framing** (`TomAction` has no trigger concept),
so this surface is authored, not read off a framework field.

**`@CsAction` attribute surface (final).** Over `TomAction<TContext, TUndo>` (§5.10):

| Attribute | `tom_flutter_ui` source | Req? | Neutral DocSpecs term |
|-----------|-------------------------|------|-----------------------|
| **Action id** | `TomAction.actionId` | Y | Action (identity) |
| **Owning controller** | `TomAction.controller` → canonical path `<controllerId>.<actionId>` | Y | Action (membership) |
| **Context requirement** | `TContext extends TomActionContext` (domain data + scope the action needs) | Y | Action (input) |
| **Undoable + undo state** | `isUndoable` / `TUndo` / `undo()` | N | Action (reversibility) |
| **Transaction grouping** | `TomActionTransaction` (atomic-undo unit) | N | Action (atomic group) |
| **Authorization** | `authorizer` → **CE-AZ** | N | Authorization requirement |
| **Copy** | label / tooltip / icon → **CE-TX** | N | Copy (→ text) |
| **Server-bound edge** | a typed `CsCallRef` const to a `@CsServerCall` → **CE-SC** (§5.3 two-hop, §5.23) | N | Server interaction |

Framework-internal (never spec input): `scope`/`tomGroup`, `authState`/
`effectiveAuthState`, `TomActionController._actions`, event plumbing. The
`canExecute(context)` guard is not an authored *action* attribute — it surfaces as the
**condition** trigger kind (below).

**SOM carriers of the required head.** On the screen-action entry
(`ScreenActionEntry`, `SCRAC`): **Action id** ← `SCRAC.actionId`, **Owning
controller** ← `SCRAC.owningController` (the controller-class name source,
`codespecs_derivation_contract.md` §3.5.5 naming), **Context requirement** ←
`SCRAC.contextType` (the `TContext` view-model type). `SCRAC.description`
carries the stated behaviour the form-3a fallback quotes when no scenario step
contributes to the action's body.

**Trigger attribute surface (designed gap).** A
`@CsTrigger` names *how* an action is invoked; one `@CsAction` may carry **several**
triggers (§5.10 "one action, several triggers"). The trigger is the **single
authoring home** of the element→action edge (§5.10): it carries a **common**
head — {target action ref; trigger kind (one of the closed 5); an optional guard
predicate over CE-ST state} — plus the **per-kind** attributes:

| Trigger kind | Per-kind spec attributes | `tom_flutter_ui` realization | Neutral term |
|--------------|--------------------------|------------------------------|--------------|
| **user-gesture** | source **CE-EL** element ref (Button / MenuEntry / inline action-icon, §5.18) + gesture (tap / press / long-press) | `TomActionTrigger` (`onPressed`/`onTap`) | Trigger (user gesture) |
| **in-form event** | owning **CE-FM** form ref + form-event {field-change / submit / validation-pass / validation-fail} + optional field ref | `TomForm` event source | Trigger (form event) |
| **lifecycle** | scope {screen / route / app} + phase {enter / leave / init / dispose} | route / app lifecycle hook | Trigger (lifecycle) |
| **server-event** | inbound event / channel ref + event type | server push / notification | Trigger (server event) |
| **condition** | reactive predicate over **CE-ST** observable state (the `canExecute` case) + re-evaluation source | `canExecute` over observable state | Trigger (condition) |

The taxonomy is **closed**: a new invocation path is an edit to the documented
trigger classification (over the reused `tom_flutter_ui` action classes), not a
free-form attribute — the same closed-catalogue discipline as §5.18 (elements) and
§5.19 (validation rules).

**Typed endpoints (compiler-checked).** A trigger's endpoints are **typed
references to the generated declarations** (the §5.23 typed-reference model —
this edge is its canonical instance): the generated `@CsTrigger` cites the
source element's generated class/member and the target action's `CsActionRef` /
`TomAction` subclass (const/type reference), never an id String. Phase-4 output
is compilable Dart, so endpoint existence and `TContext` type compatibility are
**compiler-enforced** — a rename is a compile break, not a silently dangling id.

**Boundaries drawn.**
- **CE-AC ↔ CE-SC** (§5.3): a triggered action drives a server call through the
  explicit two-hop CE-AC→CE-SC→CE-API edge. `@CsAction` carries the *what* + trigger;
  `@CsServerCall` carries the *how* (operation + request/response).
- **CE-AC ↔ CE-EL** (§5.18): the trigger carries **both endpoints** (source
  element + gesture, target action); the element's action edge is **derived**,
  never authored — single authoring home, no duplication.
- **CE-AC ↔ CE-FM** (§5.7.2): in-form-event triggers ride the form event source.
- **CE-AC ↔ CE-ST** (§5.4): the condition trigger and the common guard are predicates
  over observable view-model state.
- **CE-AC ↔ CE-AZ / CE-TX** (§5.15, §5.8): authorization and copy are the action's
  modifiers, authored once in their own parts.
- **Placement:** **client** (`<app>_codespec_client`, §4.2); no new class — the
  trigger classification is documented over the reused `tom_flutter_ui` action
  classes (§5.10).

**SOM feed.** CE-AC derives from **D05 ISC** (scenarios / processes name the actions
+ their triggers + transitions) + **D02 TOM**, per §8.

### 5.21 CE-TX message-key / i18n attribute surface + error copy keyed by CE-ER codes

**Decision.** The **CE-TX** attribute surface — the per-message-key attribute set,
the locale model, and the error-copy keying — over the substrate mapped in §5.8
(with the CE-ER error-code source of §5.14 and the `tom_flutter_ui` basis). §5.8 fixes the `@CsText` reuse basis, the
**derived-vs-catalogued** two-source model, the `tom_core_codespecs` message/i18n-key
catalogue placement, and the shared(keys)+client(copy) split; this section fixes
*which attributes a catalogued message key carries* and *how error copy binds to
CE-ER codes*.

**Two-source recap (§5.8).** A text is either **derived** (a *screen element*'s
placeholder / label / help / error copy, resolved from the element's `basePath` —
`tomId` + route scope + form scope — plus a per-role suffix, per decision (e); the
`basePath` keys are also the CE-AZ authorization keys, §5.15) or **catalogued** (a
message key in the CE-TX message/i18n-key registry, resolved by
`TomTextResourceProvider`). This attribute surface applies to the **catalogued**
shape — the **all-*other*-texts** namespace (server / error copy, notification &
email bodies, report copy). Derived element texts carry **no** CE-TX catalogue
entry: their `basePath` + suffix *is* the key, and the SOM content is the copy.

**The derived source has two key shapes.** Element-slot copy is keyed off the
**element** (`basePath` + role suffix, above). A *Choice* / *MultiChoice*
**option label** is keyed off the **value**: `<scope path>.<enumType>.<value>`,
longest scope prefix first with a global-scope fallback, resolved by
`TomObservableEnum.resolveText` through the same provider and carried by the
element's `TomEnumSelectableSource<E>` / `TomEnumNameSelectableSource<E>`
(§5.18). Both shapes are derived for the same reason: the key is computable from
what the element or the value already *is*, so a catalogue entry would be a
second name for one thing — and a second name is a thing that can disagree.
Neither shape carries a message-key entry, and neither is cited as a
`CsMessageKey`.

**Message-key attribute surface (final).** Over `TomTextResourceProvider` +
`TomText`/`TomLabelBase` (§5.8):

| Attribute | source | Req? | Neutral DocSpecs term |
|-----------|--------|------|-----------------------|
| **Message key** | dotted key (`app.form.amount.label`), resolved tree-walk-first then flat | Y | Message key (identity) |
| **Base copy** | the base-locale string (`texts` map / MSGKR default) | Y | Copy (base) |
| **Role** | one of {error, notification, email, report, generic} — the catalogued copy's kind (element-slot copy is `basePath`-derived, §5.8, not catalogued here) | Y | Copy (by role) |
| **Category** | **UI copy** vs **error copy** (the latter is CE-ER-keyed, below) | Y | Message key (category) |
| **Parameters** | named placeholders (`ValidationError.params` / `ErrorResult` field details) interpolated into the copy | N | Copy (params) |

Framework-internal (never spec input): provider singletons, the dotted-path resolution
algorithm, style objects, loader wiring.

**Declaration vs citation (§5.23).** The MSGKR declares each **catalogued** key
**once** as a `CsMessageKey` const (error copy: the `CsErrorCode` const) carrying the
dotted string; citing parts — CE-AC copy (§5.20), CE-VA error keys (§5.19) — hold the
const. The dotted string form exists only inside the declaration and in the generated
runtime lookup. (Derived element copy, §5.18, cites no MSGKR const — its `basePath` +
role suffix resolves directly against `TomTextResourceProvider`.)

**Locale model (final).** The i18n surface over `TomTextResourceProvider`:

- **Per-locale copy map** — for each message key, a base-locale string plus optional
  per-locale overrides (the provider's `texts` map keyed by locale).
- **Base / fallback locale** — one base locale is required (the authored default); a
  missing per-locale entry **falls back** to the base, never to the raw key.
- **Resolution** — tree-walk-first then flat-key (the provider's existing algorithm);
  an unresolved key is a **generation-time spec error** (the MSGKR is the closed key
  vocabulary), not a silent raw-key render.

**Error copy keyed by CE-ER codes (the cross-part tie).** Error copy is
**not** a free literal and **not** an ad-hoc UI key — it is keyed by the structured
**CE-ER error code** (§2 CE-ER, §7):

- Each CE-ER code has **exactly one** copy entry in the CE-TX message-key registry
  (MSGKR, §5.8) — the error-copy namespace *is* the CE-ER code namespace. Authoring
  the code (server) and its copy (client) is author-copy-once across both sides (§5.8).
- A CE-EL element's `resolveErrorMessage` and a CE-VA rule's `ValidationError.errorKey`
  (§5.19) both resolve through the **same** CE-ER-keyed MSGKR entry; the
  `ErrorResult` field-level details supply the copy **parameters**.
- The error-copy **keys are shared** (`<app>_codespec_shared` — the server emits the
  code, the client resolves it), the **copy strings are client** (`<app>_codespec_client`).

**Boundaries drawn.**
- **CE-TX ↔ CE-ER** (§7): error copy keys = CE-ER codes; CE-TX owns the copy,
  CE-ER owns the code + structured details. One source.
- **CE-TX ↔ CE-EL** (§5.18): a screen element's labels/hints/descriptions/error copy
  are **`basePath`-derived, not catalogued** (decision (e)) — CE-TX owns no key for
  them; the element's `basePath` + role suffix *is* the key (also the CE-AZ key, §5.15).
  A Choice's **option labels** are derived too, off the value instead of the
  element, and resolved by the element's bundle-labelled source class (above).
- **CE-TX ↔ CE-AC** (§5.20): action copy that is not element-owned is a catalogued
  message-key *reference*; CE-TX owns the key + copy.
- **CE-TX ↔ CE-VA** (§5.19): validation error keys route through the CE-ER-keyed MSGKR.
- **CE-TX ↔ CE-CF** (§5.5): copy lives in `TomTextResourceProvider`, config in
  `TomConfigResourceProvider` — distinct resource trees, no overlap.
- **Placement:** **keys shared** + **copy client** (§4.2) — the one part that spans two
  projects; the message/i18n-key catalogue class lives in `tom_core_codespecs` (§5.8).

**SOM feed.** CE-TX derives from **D09 XDS** (screens / elements / forms) + SOM
`@ContentHelp`/`@Form` hints / doc-comments (literal copy) + **CE-ER codes** (error
copy), per §8.

### 5.22 CE-LO layout-node attribute surface + override-delta grammar

**Decision.** The **CE-LO** attribute surface — the per-node attribute set
(container + slot) and the **manual-override delta grammar** — over the two-layer,
id-addressed model of §5.2, grounded on the ACL substrate in §5.12. §5.12 fixes the node kinds' substrate; this
section fixes *which attributes each node kind carries* and *the closed set of
override deltas*.

**Container-node attribute surface (final, layout-only).** Over `AclRow`/`AclContainer`
(§5.12):

| Attribute | ACL source | Req? | Neutral DocSpecs term |
|-----------|-----------|------|-----------------------|
| **Container kind** | closed set {row, column, wrap, grid} → `AclRow` / `AclContainer.rows` / `AclFlowContainer` with `AclFlowKind.wrap` / `.grid` | Y | Layout node (container kind) |
| **Ordered children** | `AclRow.components` / `AclContainer.rows` | Y | Layout node (children) |
| **Main / cross alignment** | `AclRow.alignment` + cross-alignment | N | Layout node (alignment) |
| **Spacing / gaps** | `gapBefore` / `defaultAppendGap` / `isGapRow`; `gutterWidth` / `runSpacing` for the flow kinds | N | Layout node (spacing) |
| **Columns** (`grid` only) | `AclFlowContainer.columns` + `columnsBpOverrides` (D09 `brenla-form.columns`) | N | Layout node (column count) |
| **Padding / constraints** | `padding` + `AclFlags` (expandX/Y, sizing) | N | Layout node (box) |
| **Presentation** | `scrollableX/Y`, `borderStyle`, `backgroundColor` | N | Layout node (presentation) |

A container carries **only** layout properties — no semantics (§5.2). The kind set is
**closed**: a new primitive is a node-model edit, not a
free-form attribute — same discipline as §5.18/§5.19/§5.20.

**Why these four kinds.** The set is drawn from what a **driving SOM actually
authors**, not from Flutter's primitive catalogue. D09 XDS states section
layout in `ssel-form.layoutDirection`, a closed enum of **Horizontal /
Vertical / Wrap / Grid**, with the grid's per-breakpoint column count in
`brenla-form.columns`. Those four map one-to-one onto the kinds above —
*Horizontal* → `row`, *Vertical* → `column`, *Wrap* → `wrap`, *Grid* → `grid` —
so the vocabulary is exactly as wide as the specifications that feed it.

Three plausible-looking entries are **properties, not kinds**: *padding*, *align*
and *sizedBox* are container/slot properties, already carried by the "Padding /
constraints" and "Main / cross alignment" rows above and the slot-sizing row
below, so admitting them as node kinds would express the same thing twice. Two
are **neither**: *stack* and *flex* appear nowhere in XDS's enum — no driving
specification can request them — and neither has an ACL counterpart.
Overlaying is a *shell* concern (D09's `Modal-Overlay` navigation mode, CE-CC),
not a form-layout one. Should a future SOM genuinely require stacking, adding
it is a node-model edit plus a substrate kind — the same shape of change the four
current kinds rest on.

**Substrate — all four render today.** *row* is an `AclRow` and *column* is an
`AclContainer`'s row list, so those two are native. *wrap* and *grid* live
in `tom_flutter_ui` (`acl_flow.dart`:
`AclFlowKind`, `aclWrapRows`, `aclGridRows`, `AclFlowContainer`; one widget
test per kind in `test/advanced_container_layout/acl_flow_test.dart`). They are
**row-generating** containers: they flow one flat child sequence into ordinary
`AclRow`s and hand those to the existing `AclContainer` engine, so they add a
row-assignment *rule* rather than a second layout engine — id addressing,
alignment anchors, gap rows, responsive variants and the hide-unauthorized pass
all keep working unchanged. Generated rows stay addressable as
`<containerId>.r<n>`, which is what the delta grammar below needs in order to
target a row no author wrote by hand. `AclContainer.direction` remains
`AclDirection.ltr`/`rtl` — **text** direction, not a main-axis switch; the main
axis is the kind.

One honest limitation: the wrap pass runs *before* layout, so it cannot measure
a child's natural width the way the engine's pre-calculation pass can. It
resolves widths as preferred → minimum → `kAclDefaultFlowItemWidth`, so a
`wrap` section whose children declare no size breaks on the assumed width
rather than the rendered one.

**Slot-node attribute surface (final, reference + hints).** Over `AclComponent`
(§5.12) — the leaf that *references* a semantic element and holds only per-slot hints:

| Attribute | ACL source | Req? | Neutral DocSpecs term |
|-----------|-----------|------|-----------------------|
| **Referenced element** | `AclComponent.child` → **CE-EL** element id / **CE-FM** (sub)form id | Y | Layout node (references field/form) |
| **Flex / sizing** | `preferredSize` / `minimumSize` / `maximumSize` + expand flags | N | Layout node (per-slot sizing) |
| **Alignment anchors** | `alignXToKey` / `alignYToKey` + axis points (id-addressed) | N | Layout node (anchored alignment) |
| **Gap** | `gapBefore` | N | Layout node (spacing) |

The slot holds a **reference by stable id**, never the element definition — the CE-EL/
CE-FM part owns the content and behaviour (§5.2 semantics↔layout split).

**Node identity + responsive (final).** Every node carries a **stable node id** — a
slot id derives from its referenced element/form id; a container id is a stable
synthetic id preserved across regeneration by structural matching (§5.2). Responsive
variants (`variants`/`breakpoints`) are a node attribute; the layout rebinds to CE-ST
state via `TomObservingWidget` (§5.12) — responsive/visibility is a CE-ST-driven
rebind, not a static attribute.

**Override-delta grammar (manual-override separation).**
The two layers are never one hand-edited tree (§5.2): a **generated base** (rebuilt
from the SOM every build, never hand-edited) plus a separate **authored override
layer** of id-addressed deltas. The override layer is a **closed set of delta
operations**, each targeting a **node id**:

| Delta op | Effect | Target |
|----------|--------|--------|
| **reparent** | move a slot/container under a different container | node id |
| **set-container-prop** | change a container's kind (`row`/`column`/`wrap`/`grid`) / alignment / spacing / grid columns / padding | container id |
| **set-slot-hint** | change a slot's flex / sizing / alignment anchor / gap | slot id |
| **insert-container** | add a new container node | parent id + position |
| **remove-container** | drop a container (children reflow to parent) | container id |

- A delta is a **patch**, not a replacement tree; on regeneration the base is rebuilt
  and the deltas are re-applied by id (§5.2).
- A **new** SOM element appears in the base and flows to its **default slot** (default
  base = a single `column` of the form's fields in SOM order) until an override moves it.
- A delta whose target id **no longer exists** is surfaced as a **reconcile warning**,
  never silently dropped — manual layout survives model changes non-destructively.

**Boundaries drawn.**
- **CE-LO ↔ CE-EL / CE-FM** (§5.18, §5.7.2): a slot *references* an element/form by id;
  the layout tree never embeds the definition.
- **CE-LO ↔ CE-ST** (§5.4, §5.12): responsive/visibility rebind is CE-ST-driven; the
  layout carries the variant breakpoints, CE-ST carries the state.
- **CE-LO ↔ SOM** (§8): the base structure is derived from D09 XDS; the override layer
  is **authored, not derived** (join key `@SectionId`).
- **Placement:** **client** (`<app>_codespec_client`, §4.2); the override-separable
  node-model class lives in `tom_core_codespecs` (§5.12), emitting an ACL tree at
  render time.

**SOM feed.** CE-LO base structure derives from **D09 XDS** (screen/form layout) +
**D05 ISC** (screen naming), per §8; the override layer is authored.

### 5.23 Typed cross-part references — the `Cs*Ref` const family

**Decision.** Every cross-part reference edge **inside CodeSpecs code** is a
**Dart const reference or `Type` literal — never a string literal**. The part
that owns a referenceable element declares its identity **exactly once** as a
`static const` on that part's generated catalogue class; every citing annotation
holds the typed const. A dangling or renamed reference is a **compile error** —
the Dart compiler is the §4.2 cross-part integrity checker. This *strengthens*
(does not replace) the "reference, never containment" semantics of §5.2/§5.3:
the **stable string id still exists**, authored once **inside** the const — it
is what §9.2/§9.3 serialization and SOM `codeSpec` tracing carry — but
citations hold the const, never a copy of the string.

**The ref family.** A **closed** set of **thirteen** const value types, in
`tom_code_specs/lib/src/annotations/cross_part_refs.dart` beside `DocRef`
(annotation-parameter vocabulary — Dart annotations may hold const objects, so
the family respects the annotations-only rule, §4.1):

| Ref type | Owner part | Locus (§4.2) | Cited by |
|----------|-----------|--------------|----------|
| `CsOperationRef` | CE-API | shared | CE-SC `operation` (§5.3/§5.14); CE-SU derived operation sets (§5.17) |
| `CsMessageKey` | CE-TX | shared | CE-EL/CE-AC copy references (§5.18/§5.20); CE-VA error keys (§5.19) |
| `CsErrorCode` | CE-ER | shared | CE-TX error-copy entries (§5.21); CE-VA rule failures (§5.19) |
| `CsRoleRef` | CE-AZ (role catalogue) | shared | `@CsAuthorize` role requirements (§5.15) |
| `CsResourceKeyRef` | CE-AZ (resource-key catalogue) | shared | `@CsAuthorize` resource-key requirements; field-level `authKey` (§5.15, §5.24) |
| `CsCallRef` | CE-SC | client | CE-AC server-bound edge (§5.3 hop 1, §5.20) |
| `CsActionRef` | CE-AC | client | `@CsTrigger` target (§5.20); CE-EL derived back-references (§5.18) |
| `CsRouteRef` | CE-NV | client | CE-AC navigation outcomes (§5.11); CE-SC response handling (§5.3) |
| `CsElementRef` | CE-EL | client | `@CsTrigger` gesture source and form-field endpoint (§5.10/§5.20) |
| `CsFormRef` | CE-FM | client | `@CsTrigger` owning-form endpoint of an in-form event (§5.20) |
| `CsServiceUnitRef` | CE-SU | server | server-side grouping references (§5.17) |
| `CsReportRef` | CE-RP | server (definition holder) | CE-JB scheduled work references (§5.28) |
| `CsJobRef` | CE-JB | server | job citations (§5.29) |
| — (entities / DTOs) | CE-DB / CE-API | per §4.2 | **`Type` literals** — entities and request/response DTOs are already Dart types; no ref const is needed |

Every part's definition holder is **typed from the start** — there is no
string-reference interim form for any part.

**Distinct types, no shared supertype.** Passing a route ref where an operation
ref is expected must itself be a compile error — cross-*kind* misuse is
type-checked, not convention-checked. That rules out a common base as well as a
generic `CsRef`: a parameter typed as the base would accept every kind, so the
base's only effect would be to make the mistake expressible again. The
generation-time validator that resolves each ref string to a declaration works
over the source, so it does not need one either.

**`CsElementRef` is the one qualifiable ref.** CE-EL's closed catalogue (§5.18)
holds both standalone kinds (*Button*, *MenuEntry*, *Label*, *FormHost*), which
are class-level targets, and form-member kinds (*TextInput*, *Number*, *Toggle*,
*DateInput*, *Choice*, *MultiChoice*, *FileInput*), which are members of the
`@CsForm` class.
One type carries both, with an optional owning-form qualifier — `@CsTrigger`
takes a `CsElementRef` in *both* its gesture-source and form-field slots
([codespecs_derivation_contract.md](codespecs_derivation_contract.md) §5.1), and
two types could not fill one parameter. Its N9 const-string form is the
element's own name when standalone and the dotted `<form>.<element>` path when
it is a form member — the canonical-path convention CE-AC already uses for
`<controllerId>.<actionId>` (§5.20).

**Where the parameters live.** The ref types are the annotation *parameter*
vocabulary; the `Cs*` markers that take them carry those parameters together
with their other constructor arguments, in the shape the single per-marker table
in [codespecs_derivation_contract.md](codespecs_derivation_contract.md) §5.1
gives. Splitting a constructor by argument *type* would leave markers such as
`@CsTrigger`, `@CsAuthorize` and `@CsJob` holding their reference slots but
missing the `required` arms beside them — a surface that reads complete and is
not.

**Locus follows the §4.2 dependency arrows.** Shared-owned referents
(operations, error codes, message keys, roles/resource keys) are citable from
both sides; client-owned referents (routes, actions, calls) only client-side;
server-owned referents (service units, report/job definitions) only
server-side. The parts stay cleanly separated with **reference-only coupling**.

**Declaration vs citation.** The owning part's generated **catalogue class**
declares each referenceable identity once (e.g.
`static const login = CsOperationRef('login');`). The stable string id lives
inside the const and surfaces only in §9.2/§9.3 serialization, SOM `codeSpec`
tracing, and generated **lowered** runtime forms (`ValidationError.errorKey`,
`TomServerCallSpecs.url`, `TomRoleAccess.roles`, the dotted
`TomTextResourceProvider` keys). Spec-level code never repeats the string.

**Scope: cross-part edges only (normative).** The family governs edges that
**leave the part that authors them**. An edge whose target lies *inside the same
part declaration* is a **local coordinate**, not a reference — the family does
not reach it, and giving it a ref type would widen §5.23 from "how parts cite
each other" to "how any id is written". Two such coordinates exist, and both
stay id strings:

- **A CE-LO delta's node id** (§5.22): a delta targets a node within the same
  layout declaration (§4.1.1 CE-LO).
- **A CE-NT channel's fallback** (§4.3.2): a channel's fallback names a
  **sibling channel**, which the SOM authors on the channel entry, the substrate
  holds as `TomNotificationChannelDeclaration.fallbackChannelId`, and
  `TomNotificationCatalog.fallbackChainFrom` walks channel → channel. Two
  further facts reach the same answer independently: the edge lives on a
  `tom_core_codespecs` **gap-class field**, and that package declares no
  dependencies at all, so it can never hold a `Cs*Ref` — a typed ref could only
  ride an annotation argument, duplicating a field the substrate already carries
  ([codespecs_derivation_contract.md](codespecs_derivation_contract.md) §2.3
  test **b**); and `channelId` is an **open** `TomMessageChannel` name, so a
  fallback may legitimately name a channel no `@CsNotificationChannel` declares.

A local coordinate is not exempt *from* the family — it was never in scope — but
it carries the same obligation the exemptions do: integrity comes from a named
generation-time validator check
([codespecs_derivation_contract.md](codespecs_derivation_contract.md) §6
check 17 for the channel fallback).

**Exemptions (normative — these stay strings, validator-checked per §12).** A
**cross-part** reference is exempt exactly when the referent is **not a Dart
declaration**; integrity then comes from the analyzer/validator instead of the
compiler:

1. **CE-CF / CE-CC / CE-DS / CE-UP setting keys** — the dotted resource-provider paths —
   and their env-var / cmdline-flag aliases (§5.5, §5.16): runtime resource
   paths into deployment-supplied trees.
2. **Deployment-environment names** — the environment-tag vocabulary config
   values and migration artifacts are filtered by (§5.16): deployment
   vocabulary, not code.
3. **CE-MG migration artifact filenames**: SQL artifacts, not Dart; the named
   schema-convergence validator check is the integrity mechanism.
4. **Doc-side `codeSpec` locations and `@DocSpec` extract tokens**
   (§9.2/§9.3): documents are not compiled; already validator-checked.

The list is **closed at four**, and the clause above says why no fifth can be
added casually: a referent that *is* a Dart declaration is never exempt. One
edge nonetheless emits as a string without being on this list — a CE-RP column's
**drill-through route** (§5.28). It is not an exemption but a **locus
casualty**: the referent is a Dart declaration and would take a `CsRouteRef`,
except that the locus rule above forbids a server-owned definition from citing a
client-owned one. Because the guarantee is *lost* rather than *never available*,
it must be replaced rather than waived, by a named generation-time check
([codespecs_derivation_contract.md](codespecs_derivation_contract.md) §6
check 18).

### 5.24 CE-ID identity-attribute extensions over the fixed principal core

**Decision.** CE-ID models the **app-declared identity-attribute extensions**
riding on the framework-fixed principal: `@CsIdentity` marks the app's one
identity-extension declaration holder;
`@CsIdentityAttribute(placement: CsIdentityAttributePlacement.public)` — or
`…encrypted` — marks each declared extension attribute (the same
member-marker pattern as `@CsColumn`). Locus **shared + server**: the extension
declaration is contract — both sides read attributes from the token — while
population happens in the CE-AU server flow. Kind value: `identity`.

**Built-on survey — the public/encrypted split already exists in `tom_core`.**

1. **The principal core is framework-fixed.** `TomUser` (fixed identity fields:
   username, names, email, phone, address, timeZone) wrapped by `TomPrincipal`
   (authenticated session: user + ACI + CLI + tenant coordinates + 2FA +
   locale), both `tom_core_kernel` (`user_principal_aci.dart`). The ~20 runtime
   fields are **not spec input** — consistent with the §5.15
   framework-internal ruling.
2. **Public extension carrier: `TomUser.attributes`**
   (`user_principal_aci.dart`, `Map<String, Object?>`). It rides in the
   **public** token payload under `"attributes"`, guarded field-level by
   `tomProtect(…, "tom.user.attributes")` resource keys
   (`bearer_authentication.dart`).
3. **Encrypted extension carrier: `TomPrincipal.currentContext`.** The token
   projection `TomBearerAuthentication.convertPrincipalToTokenPayload`
   (`bearer_authentication.dart`) returns `(publicInfo, privateInfo)`;
   `privateInfo` = `{context, groups, roles, entitlements, resourceKeys,
   resourceRoles}` and rides **encrypted** in the authorization JWT
   (`TomServerJwtToken(publicInfo, encryptedData: privateInfo)`,
   `authentication_server.dart`).
4. **No new class — an ordinary class carried as JSON via reflection**
   (decision (i)). Both carriers are untyped `Map<String, Object?>`; the app
   models its profile extension as a **normal class** (naming each extension
   attribute, its type, its placement public|encrypted and its access guard),
   **directly reusable** and serialized **as JSON via reflection** into the
   user-profile carrier. No `tom_core_codespecs` gap class is introduced — the
   typing comes from an app-authored ordinary class, not a framework type.

**Spec-authorable surface.** Per declared extension attribute: **name · type ·
placement (public | encrypted) · access guard** (resource key for public
attributes — the `tomProtect` mechanism; encrypted attributes are readable
only by the token-decrypting layers) **· source** (system of record) **·
required**. The ACI *content* (which roles/groups exist per deployment) stays
admin/deployment data, not spec input (the §5.15 boundary). The SOM's
descriptive identity sections (user categories, lifecycle, service accounts)
remain authored documentation mapped to `identity`; they generate no code
beyond the extension surface.

**Boundaries.**

- **CE-ID ↔ CE-AU.** CE-ID declares *what the identity carries*; CE-AU is *how
  the principal is established* and performs the public/encrypted token
  projection. CE-AU consumes CE-ID. User-**profile** data is CE-ID identity
  attributes (mostly `placement: public`), surfaced through CE-AU.
- **CE-ID ↔ CE-AZ.** CE-AZ requirements evaluate against the principal's ACI,
  which stays framework-internal; CE-ID does not open ACI to spec authoring.
- **CE-ID ↔ CE-UP.** Identity attributes describe *who the user is* and travel
  in the token; user settings are *changeable preferences* and live in the
  settings store (CE-UP). Token-vs-settings-store transport is the practical
  discriminator.
- **CE-ID ↔ CE-DB.** Server-side persistence of user records is the identity
  provider's own CE-DB concern (tom_uam is the reference implementation), not
  CE-ID spec surface.

**SOM feed.** D08 SAS, the user-management family — the per-attribute
authoring form is `UserAttributeEntry` (USATE), which carries
name/dataType/placement/accessGuard/source/required, covering the full
spec-authorable surface. Join key is the SOM `@SectionId` (§8).

### 5.25 CE-AU authentication — framework-fixed mechanics, spec-authorable policy surface

CE-AU is **pure reuse of the `tom_core` authentication stack — no gap class**.
The authentication *mechanics* are framework-fixed; what a CodeSpec authors is
the *policy surface*: which service backs authentication, which methods and
flows are enabled, and which session/token/credential policies apply. The
single marker is `@CsAuth`; methods, flows, and policies are its attributes,
not separate parts.

**Framework-fixed mechanics** (not spec-authorable; the framework owns them):

1. **Two-token JWT model.** `TomAuthenticationServer` projects the
   authenticated principal via `convertPrincipalToTokenPayload` into a
   `TomServerJwtToken` with a public part (`publicInfo`) and an encrypted part
   (`encryptedData: privateInfo`) readable only by the token-decrypting layers.
2. **Login orchestration.** The guest/pass1/pass2 flow
   (`authenticateGuest` / `authenticatePass1` / `authenticatePass2`) with the
   fixed wire types `TomAuthenticationMessage` / `TomAuthenticationResult`.
3. **Stateless Bearer verification.** Every server call reconstructs the
   principal from the token (`convertTokenPayloadToPrincipal`, backed by
   `TomAuthorizationCache`) — no server-side session record.
4. **Client wire attachment.** `TomServerCallSpecs.includeBearerAuthentication`
   attaches the Bearer token to outgoing calls.
5. **Client token store.** `TomBearerAuthentication` holds the tokens
   (`setTokens` / `getPrincipal` / `clientJwtToken`) and reconstructs the
   client-side principal view.
6. **Extension-point shapes.** The `TomAuthenticationService` contract and the
   `Tom2FAAdaptor` shape are framework-defined. The two-pass 2FA flow is
   implemented: pass 1 issues a `Tom2FAChallenge` interim token carrying the
   access-control payload it already resolved, and `authenticatePass2` verifies
   the presented token statelessly through the mechanism's adaptor in
   `Tom2FARegistry`. A deployment supplies the *adaptor*; a spec names the
   *mechanism*.

**Spec-authorable surface** (what `@CsAuth` declares):

1. **Service binding.** The app's `TomAuthenticationService` implementation
   **is** the `@CsAuth` CodeSpec — an ordinary class on the framework
   contract, marked with the annotation.
2. **Enabled methods & flows, and the second-factor policy.** Which
   authentication methods (guest, password, …) and which flows the deployment
   enables — one marked declaration each. Where a second factor is in play, the
   deployment's **`Tom2FAPolicy` binding** is a further marked declaration, and
   it carries the second factor's three authored decisions: whether a factor is
   **required, optional or disabled** (`Tom2FARequirement`, per role where the
   obligation varies by role); **which mechanisms are offered, in preference
   order** — the first is what a login the user has expressed no choice about is
   challenged with; and how many **grace logins** soften a `required` obligation
   the user has not yet met. The SOM authors all three on `MfaConfiguration`
   (`MC`) as `mfaRequired` + `mfaEnforcementScope`, `defaultSecondFactor` +
   `allowedSecondFactors`, and `enrollmentGracePeriod`.

   **Whether declining an enrolment offer is allowed is *not* a fourth
   decision**, because the server derives it: an offer is skippable exactly when
   the requirement is `optional`, or when a `required` obligation still has grace
   left (`authentication_server.dart`). A spec that authored a skip flag
   beside the policy would be authoring a value the server recomputes and
   overwrites — the second, disagreeing source `codespecs_derivation_contract.md` §2.3 exists to prevent.
3. **Per-client login flow.** Each client's login sequence and its
   `TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>`
   endpoint triple (guest / pass1 / pass2).
4. **Session/token/credential policies.** Token lifetimes, refresh rules,
   credential requirements — realised as CE-CF configuration values plus
   obligations on the bound service implementation.
5. **User-profile attribute set.** Absorbed into CE-ID: profile data is
   CE-ID identity attributes (§5.24), populated by the CE-AU service.

**Built on** (per project of the §4.2 trio):

| Locus | Reused `tom_core` classes |
|-------|---------------------------|
| shared | `TomBearerAuthentication`, `TomClientJwtToken`, `TomAuthenticationMessage` / `TomAuthenticationResult` (incl. its enrolment arm), `Tom2FAMethodDescriptor`, the `TomPrincipal` projection (`tom_core_kernel`) |
| server | `TomAuthenticationServer` + the app's `TomAuthenticationService` implementation, `TomServerJwtToken`, and for a second factor `Tom2FAPolicy` / `TomRole2FAPolicy`, `Tom2FAService` + `Tom2FAEnrolmentSupport`, `Tom2FAEnrolmentStore`, `Tom2FARegistry` (`tom_core_server`) |
| client | Login `TomServerEndpoint` triple, `TomBearerAuthentication` token store, `TomServerCallSpecs.includeBearerAuthentication`, and for a second factor `Tom2FAFlowPanel` + the app's `Tom2FAFlowController`, `Tom2FAClientMechanism` in `Tom2FAClientRegistry` (`tom_core_flutter`) |

**Boundaries.**

- **CE-AU ↔ CE-CF.** CE-CF supplies the key material and token-policy
  configuration values; CE-AU consumes them.
- **CE-AU ↔ CE-AZ.** CE-AU establishes the principal; CE-AZ evaluates
  requirements against it. The handoff is the reconstructed principal.
- **CE-AU ↔ CE-ID.** CE-ID declares what the identity carries; CE-AU
  establishes it and performs the public/encrypted token projection (§5.24).

**Substrate status — the second factor decides, enrols, offers a choice and
challenges, end to end.** Item 2 is authorable in full, and it emits into all
three projects of the §4.2 trio.

- **Server — the decision.** `Tom2FAPolicy.decideFor` returns a `Tom2FADecision`
  carrying the requirement level, the permitted mechanisms *in preference order*
  and the grace count (`tom_core_server` `authentication/two_factor_policy.dart`).
  `TomRole2FAPolicy` is the shipped role-driven implementation — its constructor
  takes `requirementByRole`, `defaultRequirement`, the ordered `mechanisms` and
  `graceLogins` — and `TomPrincipalFlag2FAPolicy` is the const fallback that
  preserves the behaviour of a deployment that installs no policy bean.
  `Tom2FADecision.offerableMechanisms` intersects the permitted set with what is
  actually registered, once, so a policy naming an uninstalled mechanism surfaces
  at the branch that decides the login rather than as a null adaptor later.
- **Server — the enrolment.** `Tom2FAEnrolmentSupport` (`beginEnrolment` /
  `confirmEnrolment`) is implemented by `TomTotp2FAService`, which generates the
  secret and hands back the `otpauth://` provisioning URI, and by the
  delivered-code mechanism. `Tom2FAEnrolmentStore` persists what a user has set
  up; `Tom2FARegistry.enrollableMethods` is the describable subset of
  `availableMethods` that can actually be set up here.
- **Wire — the choice.** `TomAuthenticationResult` (`tom_core_kernel`
  `security/authentication_authorization.dart`) carries `requires2FAEnrolment` as
  a state distinct from `requires2FA`, `availableTwoFactorMethods` as a list of
  `Tom2FAMethodDescriptor`, and `twoFactorEnrolmentSkippable`. The original
  `requires2FA` / `twoFactorType` pair is unchanged beside them, so a client that
  understands only those two cannot mistake an enrolment offer for a challenge.
- **Client — the flow.** `Tom2FAFlowPanel` over the application-implemented
  `Tom2FAFlowController` (`tom_core_flutter`
  `tomclient/security/two_factor_flow.dart`) owns the invariant half: the
  mechanism chooser, the frame around a mechanism's panel, the attempt counter,
  the error line, and the skip affordance — which appears **only** when the
  server said the offer was skippable. What a mechanism shows and what counts as
  an answer sits behind `Tom2FAClientMechanism` in `Tom2FAClientRegistry`, one
  registration per mechanism (`TomTotp2FAClientMechanism` shipped, with
  `TomQrCodeView` rendering the provisioning URI).

### 5.26 Server authentication & feature grants

A deployed server is itself a **principal**. Which *features* a deployment may
exercise is not configuration (§5.5 item 4 — CE-CF flags are operator-set
toggles) but **authorization**: server-level entitlements granted to the
server's own identity and met against the user's grants at evaluation time.

**Server-as-principal (CE-AU flow).** The server authenticates against the
auth server with a **service credential**, exactly like any other client —
as a client application it is the CE-CL "other server" kind (§4.1). The §12
architecture applies unchanged: login yields a token, the token reconstructs
a `TomPrincipal` for the server itself (the *ambient server principal*).

**The grant carrier.** The server principal's access-control information
carries its feature grants as **entitlements** — dotted match patterns
(`TomEntitlementAccess.patterns`, the §5.15 requirement kind 3). A feature is
"granted to this deployment" iff the server principal's entitlement set
matches the feature's pattern. No new part and no new class shape: the grant
carrier is the existing entitlement mechanism applied to a server principal.

**Effective authorization = the meet.** When a CE-AZ requirement is evaluated
on an operation, the effective result is the **meet** of the user's and the
server's grant: `min(user, server)` over the graded four-state levels
(`none < disabled < read < full`), plain binary AND for two-state kinds. A
user's `full` on a feature the deployment is not entitled to evaluates to
`none` — the server's grants cap every user's grants.

**Wiring (CE-CF).** The server-auth wiring — auth-server URI and the
service-credential reference — is a pair of CE-CF values, secret-marked per
§5.16. The credential itself never appears in a spec.

**Grant issuance.** Issuing and revoking server-level entitlements is the
auth server ↔ `tom_sqm` (subscription/quota) boundary — named here as the
owning system pair; its contract is out of CodeSpecs scope.

**Framework locus (shipped).** Server self-login, the ambient server principal
and the meet are `tom_core` runtime work and are **implemented**:
`TomServerSelfLogin` / `TomServiceCredential` (`tom_core_server`,
`tomserver/authentication/server_self_login.dart`) log the deployment in
before `TomServer` binds its socket; `TomServerPrincipal` (`tom_core_kernel`,
`tombase/security/access_controls.dart`) is the ambient holder; and the meet
runs inside `TomAccessControl.checkAccessibility` / `resolveAuthState`, which
are `@nonVirtual` entry points delegating to the `resolvePrincipalAuthState` /
`resolveServerAuthState` hooks — so a subclass cannot bypass the cap. None of
this is a CodeSpecs gap: nothing here is spec-authored beyond the two CE-CF
wiring values and the ordinary CE-AZ requirements that the meet applies to.

**Degradation.** A deployment that configures no service credential installs
no server principal, and evaluation returns the user's grant untouched —
existing deployments are behaviourally unchanged. Note the asymmetry: *no*
server principal means *no cap*, whereas a server principal with an **empty**
entitlement set is entitled to nothing and denies everything.

### 5.27 CE-MG schema-migration artifacts over the `tom_core_server` migration engine

**Decision.** CE-MG models the **SQL migration artifact set** of an application
— `@CsMigration`-marked file assets in the server project (§4.2), driven by the
existing `tom_core_server` migration engine as **pure reuse, no gap class**:
`TomDbMigrations` (orchestrator), `TomDbMigrator` (per-database contract),
`TomMigrationFileName` (filename grammar), `@TomDbMigrationAdaptor` (reflection
discovery of migrators by data-source type), `MariadbMigrationAdaptor` (the
MariaDB implementation). Kind value: `schemaMigration`; SOM home:
`SchemaVersioningAndMigration` (`SCHMG`) under SBP.8 `InformationAndDataModel`;
locus **database** (artifacts ship with the server project).

`SCHMG` is projected into **D03 IFM** — it sits beside the entity model because
the artifact chain must converge on it (see *CE-DB convergence* below) — and
into **`D13CodeSpecsProjection`** at the **server** locus.

**Scope — three artifact kinds.** A CodeSpec authors:

1. **Initial DDL** — the baseline schema (tables, indexes, constraints) as the
   first migration(s) of each schema. SOM: `SCMST.artifactKind = initialDdl`,
   detailed by the `SCMST-BASE` baseline-schema subsection.
2. **Base/seed data** — the initial *reference* data of the **new** system
   (lookup tables, defaults, built-in roles). Explicitly **not**
   business-data migration from legacy systems — old→new data mapping and
   cutover stay in the SOM `MIGME` migration sections and are outside
   CodeSpecs. SOM: `SCMST.artifactKind = referenceData`, detailed by the
   `SCMST-REFD` subsection.
3. **Iteration scripts** — the append-only schema evolution steps as the data
   model changes. SOM: `SCMST.artifactKind = schemaChange`, detailed by the
   `SCMST-CHNG` subsection.

The three are a `@OneOf` group on `SCMST` discriminated by `artifactKind`
(§8.2), because each kind authors a genuinely different thing: a baseline has no
prior state to diff, backfill or roll back to; reference data inserts rows, not
schema; only an evolution step has affected entities, a backfill and
reversibility. All three constants bind a case.

**Filename grammar + environment tagging.** Every artifact basename must match
`[<numeric version>]-<description>[@<env>[,<env>…]].<ext>` in full
(`TomMigrationFileName`; description = letters/underscores, malformed names
throw). Artifacts apply in **ascending numeric version order** (`[2]` before
`[10]`). The optional `@<env>` tag (C-16) restricts an artifact to the named
environments; an **untagged** artifact applies everywhere. The active
environment resolves via `TomRuntime`, falling back to the **production-safe
default** when none is initialized — only untagged artifacts apply, so a
`@dev`/`@test` seed artifact can never leak into production. Skipping is pure
omission: applied-version bookkeeping is untouched, re-runs stay idempotent.

The version and the environment tag are authored per artifact:
`SCMST.version` orders the artifact and `SCMST.environments` names the
environments it is restricted to — left empty, the artifact applies everywhere.
The environment names are matched **verbatim** (§5.23 exemption 2), so the SOM
field is a plain string rather than a reference into a registry.

**Directory tree — multi-DB by construction.** Artifacts live under
`<databaseMigrationsDirectory>/<datasourceName>/<schemaName>/` — the datasource
level matches a registered `TomDataSourceInfo` name, the schema level one
schema within it. Several databases (and database *types*, via
`@TomDbMigrationAdaptor`) coexist without any extra spec surface.

The pair is authored once per target in the `SCHMG` migration-target list
(`MigrationTargetEntry`, `MIGTG`): a `targetName` identifier plus the
`dataSourceName` and `schemaName` that form the directory path. Each artifact
then names its target through `SCMST.migrationTarget`
(`refersTo: MIGTG.targetName`) instead of repeating the pair, which is what
keeps the two path segments un-defaultable per artifact
(`codespecs_derivation_contract.md` §3.3.5) without duplicating them across an
entire chain.

**Immutability — applied migrations are append-only.** The migrator records
each applied version and, on re-encounter, **verifies** (description/checksum)
and skips it; an applied artifact is never edited — schema change is always a
*new* numbered artifact. The migration chain is the schema's history; only the
chain's tip moves. This is engine-enforced, not an authoring decision, so it is
stated in the `SCMST` authoring help rather than carried by a member.

**CE-DB convergence — a named validator check.** The cumulative DDL of a
schema's chain must produce exactly the shape the `@CsTable`/`@CsColumn`
entity model declares (§5.13). This is a **named CodeSpecs validator check**
(it is also the §5.23 integrity mechanism for the string-exempt artifact
filenames). The schema-diff engine that mechanically proves it ships in
`tom_core_server`'s `db_migration` module — `schema_model.dart` (the compared
shape), `schema_ddl_reader.dart` (the shape the chain's cumulative DDL yields)
and `schema_convergence.dart` (the comparison). Being a mechanical check, it is
likewise stated in the `SCHMG` authoring help rather than carried by a member —
a divergence is a defect in one of the two models, never a decision the author
records.

**Wiring (CE-CF).** The tree root is the `databaseMigrationsDirectory` server
configuration value (§5.5, §5.16); `TomDbMigrations.migrateDatabases` runs from
it at server start. No further CE-MG-specific configuration exists.

**No tooling choice.** The engine is fixed by the pure-reuse decision above, so
`SCHMG` records no migration-tooling selection: there is nothing to select. The
section authors *what* to apply and *where*, never *with what*.

#### CE-MG attribute surface

| Attribute | Authored where | Consumed as |
| --- | --- | --- |
| Versioning strategy, forward-only, baseline version, zero-downtime approach | `SCHMG` form | Policy narrative; not a `@CsMigration` argument |
| Data source name | `MIGTG.dataSourceName` | `@CsMigration.datasource` + first path segment |
| Schema name | `MIGTG.schemaName` | `@CsMigration.schema` + second path segment |
| Artifact kind | `SCMST.artifactKind` | `@CsMigration.kind` (`CsMigrationKind`) |
| Artifact version | `SCMST.version` | The `[<numeric version>]` filename segment (authored, §5.23 exemption 3) |
| Environment restriction | `SCMST.environments` | The `@<env>[,<env>…]` filename tag (authored, §5.23 exemptions 2+3) |
| Artifact body (statements / value set / backfill) | `SCMST-BASE` / `SCMST-REFD` / `SCMST-CHNG` | The artifact's SQL content |

### 5.28 CE-RP report definitions over the domain model

A **report** is a *grouped projection over the domain model, delivered as a
rendered artifact*. That one sentence carries the whole part: the projection is
what a specification authors, and the rendering is what the framework does with
it.

Marked by `@CsReport` (with `@CsReportColumn`, `@CsReportChart` and
`@CsReportParameter` on its members), built on `TomReportDefinition` /
`TomReportResult` (`tom_core_codespecs`). SOM home: **D09 XDS**, the report
definition family under `ReportDefinitions` (`REDF`), with **D03 IMO** as the
source-data reference.

#### CE-RP is a part, not a composition

The obvious hypothesis is that a report is CE-API (an operation) over CE-DB (a
query) rendered as CE-EL/CE-FM (a table). It fails on the thing that makes a
report a report:

- **Dimensions and measures have no authoring home.** The runtime grammar
  exists — `tom_core_server`'s `TomGroupedSelect` carries `groupBy`,
  `TomAggregate` and `having` — but CE-DB's *spec-authorable* surface is
  row-shaped: entities, attributes, filters, sorts. "Revenue is the sum of order
  totals, by customer region and quarter" cannot be written in any active part.
- **The artifact has no identity holder.** CE-API's authored identity is an
  *operation*; a report has zero to three delivery channels and may have none
  that is an endpoint at all (a scheduled email report is never called).
- **A report column is not a form field.** It is an *output projection* carrying
  an aggregate reference, a display format and an optional drill-through target.
  CE-FM's field is an input the user edits.
- **A chart has no home anywhere** in the active catalogue.

Scheduled *execution* and *delivery* are genuinely not CE-RP's — they are
realised by CE-JB and CE-NT. The definition states **when** it runs and **on
what channels**, and those two facts are what the job and the notification are
built from; it never contains the job or the delivery mechanics. What is left
after that subtraction is still irreducible, so the verdict is **promote**, not
defer.

#### Scope boundary — spec-authorable vs implementation-owned

**Spec-authorable** (this is the complete list; anything absent is not authored):
report identity and title; the source entity; the grouping **dimensions**; the
aggregated **measures**; the projected **output columns** with their type,
format and drill-through; **chart** declarations; typed and bounded runtime
**parameters**; the **delivery channels**; the **schedule** it runs on, from
which the CE-JB job is realised; the CE-AZ **authorization requirement**.

**Implementation-owned** (a specification never authors these): the rendering
engine and per-format mechanics, pagination and streaming strategy, export file
naming and storage, scheduler infrastructure, and the query plan the dimensions
and measures compile to.

**And explicitly not CE-RP:** the environment-wide print and export settings —
print strategy, paper size, orientation, page setup, branding, watermark,
header/footer, archive policy. Those are deployment settings on the renderer and
belong to **CE-CF** — the same boundary CE-LG draws, where retention and log
format are CE-CF settings on the sink, not part of the audit declaration.

#### Attribute surface

| Attribute | `tom_core` source | Req? | Neutral DocSpecs term |
|-----------|-------------------|------|-----------------------|
| Report id | `TomReportDefinition.reportId` | Y | Report |
| Report title | `TomReportDefinition.displayName` | N | Message key |
| Source entity | `TomReportDefinition.sourceEntity` (a `Type`) | Y | Data entity |
| Grouping key | `TomReportDimension.key` / `.columnName` | N | Report dimension |
| Dimension type | `TomReportDimension.valueKind` | Y | Field kind |
| Aggregate | `TomReportMeasure.function` (`count`/`sum`/`avg`/`min`/`max`) | Y | Report measure |
| Aggregated column | `TomReportMeasure.columnName` | Y¹ | Data attribute |
| Distinct operand | `TomReportMeasure.distinct` | N | Report measure |
| Column name | `TomReportColumn.name` | Y | Report column |
| Column source | `TomReportColumn.sourceKey` | Y | Report column |
| Column type | `TomReportColumn.valueKind` | Y | Field kind |
| Column header | `TomReportColumn.label` | N | Message key |
| Display format | `TomReportColumn.formatPattern` | N | Report column |
| Drill-through | `TomReportColumn.drillThroughRouteId` | N | Navigation target |
| Chart form | `TomReportChart.kind` | Y | Chart |
| Chart axes/series | `TomReportChart.categoryColumn` / `.valueColumns` / `.seriesColumn` | Y | Chart |
| Parameter name/type | `TomReportParameter.name` / `.valueKind` | Y | Report parameter |
| Parameter bound | `TomReportParameter.enumId` / `.entityId` | Y² | Domain enum / Data entity |
| Parameter default | `TomReportParameter.defaultValue` / `.required` | N | Report parameter |
| Delivery channel | `TomReportDefinition.deliveryChannels` | N³ | Delivery channel |
| Schedule | `TomReportDefinition.scheduleExpression` | N | Report schedule |
| Authorization | `@CsAuthorize` beside `@CsReport` | N | Authorization requirement |
| Section columns/rows | `TomReportResultSection.columns` / `.rows` | D | Report section |
| Result metadata | `TomReportResult.metadata` | D | Report |

¹ Required for every aggregate except `count`, which may be the bare row count.
² Required exactly when the parameter's type is `enumeration` or `entityRef`.
³ Defaults to `apiResponse`.

#### Cross-part targets — where each one is carried

CE-RP points outward four times, and no two of them are carried the same way.
`tom_core_codespecs` declares **no dependencies**, so a gap class can never hold
a `Cs*Ref` const (§5.23 places that family in the annotation *parameter*
vocabulary); the question each target answers is what it should be instead.

| Target | Carrier | Why |
|--------|---------|-----|
| Source entity | `TomReportDefinition.sourceEntity`, a **`Type` literal** | An entity is already a Dart type, so §5.23 gives it no ref const by design — citing the class makes a renamed entity a compile error, which a string could never be. A `Type` needs only `dart:core`, so the gap package keeps its dependency-freedom. Same resolution as `TomJobDeclaration.readEntities` (§5.29). |
| Schedule | `TomReportDefinition.scheduleExpression`, a **verbatim recurrence expression** | **Not a reference at all.** The report-schedule section authors a cron-like expression, a time zone and a window — no job id anywhere — and §5.29 states the CE-JB job is *realised from* that schedule rather than named by a second entry. A job-id field would invite exactly that second source, and would point at a declaration nothing has written yet. The schedule's remaining authored detail lowers onto the derived job's own `TomJobDefinition`. |
| Authorization | **`@CsAuthorize` beside `@CsReport`** | §5.15 already carries authorization at field level on a CE-DB column, a CE-EL/CE-FM field, a CE-AC action and a CE-NV destination — riding its host part rather than becoming one. A report is the same case. The security section authors an access level and a permitted-role list, which are exactly `CsAuthRequirement` and a typed `CsRoleRef` list, so the edge is compile-checked and `@CsReport` stays note-only. |
| Drill-through | `TomReportColumn.drillThroughRouteId`, an **open id string** + validator check | §5.23's locus rule bars a **server**-owned definition from citing a **client**-owned route. This is the one target where a typed ref is genuinely unavailable — and it is *unlike* the four §5.23 exemptions, which are exempt because their referent is not a Dart declaration. A route is one, so the compile-time guarantee is lost to locus and has to be **replaced**: `codespecs_derivation_contract.md` §6 check 18, the same substitution check 17 makes for a notification channel's fallback. |

The consequence worth stating plainly: **no fifth §5.23 string exemption is
created, and no CE-RP marker gains an argument.** The exemption clause is
normative and reaches a referent "exactly when it is not a Dart declaration",
which none of these is; and three of the four turned out not to need the
exemption because they were not references.

#### Neutral vocabulary added

CE-RP adds **ten** terms to the §1.2 glossary: **Report · Report section ·
Report column · Report dimension · Report measure · Report parameter · Chart ·
Delivery channel · Report schedule · Report recipient**.

Each is checked against the existing set. *Chart series* and *chart axis* are
**not** terms of their own — they are a deeper level within **Chart**, not
peers of it. Six existing terms are reused unchanged rather than shadowed:
**Query/Filter** and **Sort** (a report's selection is an ordinary filter),
**Data entity** / **Data attribute** (the source), **Operation** (the endpoint
that returns it), **Message key** (every label), and **Navigation target**
(drill-through). **Field** deliberately stays input-only: *Report column* is its
output-side peer, and conflating them is exactly the composition error above.
**Authorization requirement** is reused per §1.2 consequence 3 — authorization
is an attribute, never a leaf — so report security authors as an attribute of
the report, not as a term of its own.

#### The two gap classes, and why the envelope is shared

`tom_core_codespecs` holds both (`report_model.dart`):

- **`TomReportDefinition`** (+ `TomReportDimension`, `TomReportMeasure`,
  `TomReportColumn`, `TomReportParameter`, `TomReportChart`) — the authored
  report. **Server locus:** the definition is where the report runs.
- **`TomReportResult`** (+ `TomReportResultSection`) — the result envelope.
  **Shared locus:** the client renders it and the server exports it.

The envelope deliberately does **not** extend `tom_core_server`'s
`TomTabularResult`, even though that is the shape the renderers consume. The
envelope's locus is *shared*, and a shared type cannot depend on a server type.
So the envelope is authored in the dependency-free gap package and the server
**adapts it one way** onto the tabular shape when exporting — the same placement
decision CE-DB records for entities (the field shape is authored once in the
shared project; the server persistence facet derives from it).

The adaptation constrains the envelope in exactly one way, inherited
deliberately: **rows stay streamable** (`Stream<List<Object?>>`). A report
exists for results too large to hold inline, and a materialised row list would
put the whole result in memory before the first rendered byte.

Three consistency checks run at **generation time**, because each is a
specification defect that would otherwise emit code referring to something that
does not exist: a column whose source key names neither a dimension nor a
measure; one key claimed by both a dimension and a measure; and a chart plotting
a column the report does not project.

#### Charts — declared here, rendered by whoever can

Charts are **spec-authorable**: the SOM authors chart type, axes and series as
structured fields, so the derivation has something to read. Chart *rendering* is
**implementation-owned** and, unlike the tabular output, is not universally
available — the client draws charts natively, CSV and XLSX cannot express one at
all, and only PDF among the export formats could.

The declaration therefore travels on **both** the definition and the envelope,
and an exporter with no way to draw a chart **omits it rather than failing**.
That is why the chart model sits beside `TomTabularResult` rather than inside
it: putting it in the tabular shape would add a field only one renderer of three
ever reads.

#### Relationships

| Part | Relationship |
|------|--------------|
| CE-API | Delivery — a report is returned by an ordinary endpoint (§7 contract); no special transport. |
| CE-DB | Source — entities and repositories; the dimensions and measures compile onto the CE-DB query substrate. |
| `domainEnum` | A parameter of type `enumeration` names a domain enum (the member kind, not a part), whose values bound the input. |
| CE-TX | Every title, header and label is a message key, never inline copy (§1.2 consequence 1). |
| CE-NV | A column's drill-through names a route; the route is CE-NV's. |
| CE-AZ | The authorization requirement a caller must satisfy to run the report. |
| CE-CF | The environment-wide print/export settings the renderer uses — *not* CE-RP. |
| CE-JB | Scheduled precalculation — the definition *names* its schedule (SOM `ReportScheduleEntry`); the CE-JB job realises it (§5.29). |
| CE-NT | Email delivery — the definition names the channel abstractly and CE-NT resolves it: a scheduled report is delivered as a declared notification type, through the channels `TomNotificationCatalog.deliveryChannelsFor` yields, over the `tom_core_server` `messaging` transport. |

The report identity is declared once as a `CsReportRef` const on the CE-RP
catalogue class (§5.23) — a citation of the report holds the typed const, never a
string. `CsReportRef` is server-owned, so **CE-JB scheduled work is its only
citer**, exactly as §5.23's table records. The drill-through is not a counterpart
running the other way: it is a *column* naming a route, and §5.23's locus rule
bars a server-side definition from holding a client-owned `CsRouteRef`, so that
target stays an open id string (§4.1.1 CE-RP).

#### Framework substrate

Everything below CE-RP's own two gap classes is reuse.

**Aggregation** — `tom_core_server`'s `object_persistence/grouped_query.dart`
carries `TomAggregateFunction` (`count` / `sum` / `avg` / `min` / `max`,
`distinct`-capable), `groupBy` key columns and a `having` group predicate,
compiled through the query builder and sentence compiler. `TomReportMeasure`'s
function set is **1:1 with `TomAggregateFunction`** by design: a measure the
query layer cannot compile is a measure that cannot run, so the authorable set is
exactly the compilable set.

**Rendering** — the `export` module (`TomTabularRenderer` over
`TomCsvRenderer` / `TomXlsxRenderer` / `TomPdfRenderer`, guide at
`tom_ai/core/tom_core_server/doc/export.md`) renders to all three formats through
one streaming abstraction. Both non-email channels are wired: `TomExportService`
`respondWith` is `apiResponse`, `storeAs` is `fileExport` — the latter over a
narrow `TomExportStore` seam that `TomBlobExportStore` backs with the
`file_storage` module's blob stores (database / directory / S3 / memory, chosen
in configuration; guide at
`tom_ai/core/tom_core_server/doc/file_storage.md`).

**Email** — the `messaging` module (`TomMessage` / `TomMessageRouter` /
`TomSmtpTransport` / `TomMessageOutbox`, guide at
`tom_ai/core/tom_core_server/doc/messaging.md`) delivers, queued on the CE-JB job
scheduler. SMTP credentials are secret-marked CE-CF fields per §5.16.

#### Projection membership

CE-RP's SOM home is **`ReportDefinitions`** (`REDF`, XDS) — a direct child of
`ExperienceAndInterfaceDesign` holding `List<ReportEntry> reports` and, below it,
the section, column, chart, filter, schedule, distribution and recipient entries.
It is a purely-CodeSpecs subtree and a `D13CodeSpecsProjection` root at the
**server** locus (`locus: server — CE-RP`); the container carries no
`@CodeSpecKind` of its own, since the part lives on `ReportEntry`.

The subtree needs no second entry at the shared locus. Its shared half — the
result envelope and the parameter shapes the client reads — is *derived from the
same report definitions* rather than authored in a second SOM section, and the
CE-ER contract it rides on is already projected as `ResultEnvelope`.

What stays outside it is `PrintAndExportLayout` (`PRLA`), now single-kind
**CE-CF**: the environment-wide print settings plus the export format, size and
template catalogue. `ExportFieldMappingEntry` (`EXFIMA`) belongs to that band
too — it is the column layout of one format-catalogue entry, reachable only
through `ExportFormatEntry`, not a projection a specification authors on its own.
The projection-side counterpart is `ReportColumnEntry`, under `ReportEntry`. The
split that produced this shape is recorded in §4.3.2.

### 5.29 CE-JB background-job definitions over the operational model

**Decision.** CE-JB models **background-job definitions** as first-class spec
elements — `@CsJob`-marked, **server-only** per §4.2. A job is work that runs
*off* the request thread: on a schedule, on a calendar date, or on an event,
distinct from the request-driven CE-API. Kind value: `backgroundJob`; SOM home:
**D06 ATS** (the architecture's operational model — `ScheduledJobEntry` SCJOB,
the per-job declaration list under `BatchJobManagement` BAJOMA, with
`ScheduledJobStepEntry` SCJOST carrying each job's ordered work steps).

**Scope — what one job definition names.** A CE-JB definition =

1. **Trigger** — `cron | calendar | event`: a cron/recurrence expression, a
   calendar date rule, or a named system event. This is the axis that separates
   CE-JB from request-driven CE-API. Time-zone handling is a **system-wide**
   choice, authored once on `BatchJobManagement` — the `TomSchedule` family
   takes no per-schedule zone, so a per-job zone would be a specification the
   substrate cannot honour.
2. **Work definition** — the unit of work, emitted as a **form-3b** body
   (`codespecs_derivation_contract.md` §2.4) over the `SCJOST` work-step list:
   one statement per step, in list order, on the job's abstract collaborator,
   with a step's stated condition becoming a B4 guard. `SCJOB-WORK.workSummary`
   states the *intent* the sequence realises, not the sequence itself. Where a
   job lists no steps — the common case, since most jobs are a single action —
   the `codespecs_derivation_contract.md` §2.4 fallback emits the **form-3a**
   body from that intent and the sequence is written in Phase 6. It runs off the
   request thread on the `tom_core_kernel` isolate-pooling substrate
   (`TomCommand` dispatched through `TomExecutor` / `TomWorker`).
3. **Target references** — the CE-DB entities and/or CE-RP reports the job acts
   on, held as typed const refs (§5.23 — `CsReportRef` for a scheduled report),
   never strings.
4. **Retry / backoff / timeout / failure-alerting** — the operational policy
   for a failed or long-running run.

**Owning class per scope part.** Every part of the scope above resolves to
exactly one class, and all but the envelope are **reused**, not built:

| Scope part | Owning class | Package | How a spec author states it |
|------------|--------------|---------|------------------------------|
| 1 Trigger | `TomSchedule` — `TomCronSchedule`, `TomCalendarSchedule`, `TomIntervalSchedule`, `TomOnceSchedule`, `TomEventSchedule` | `tom_core_kernel` `tombase/scheduling/schedule.dart` | `@CsJob(trigger:, cron:/calendar:/event:)`, lowered to the matching `TomSchedule` on `TomJobDefinition.schedule`. A `TomSchedule` is not a const, which is why the annotation carries per-kind string slots rather than an instance — the same reason `@TomScheduledJob` does. |
| 2 Work definition | `TomJobDefinition.body` (a `TomCommand Function(TomJobRun)` factory) over `TomJobBase`; dispatched by `TomJobDispatcher` / `TomWorkerPoolJobDispatcher` | `tom_core_kernel` `job_definition.dart`, `scheduled_job.dart` | The `@CsJob` class extends `TomJobBase` and carries its work body in `execute()` — form 3b over the `SCJOST` steps, form 3a over `workSummary` where a job lists none. `TomJobBase.run` gives the body its window, attempt number and event payload. The body is wrapped in `TomTransactionManager.runInTransactionScope` so the run is its own flow of work — nothing above a job opens a transaction scope for it (§5.13). |
| 3 Target references — CE-DB entities | `TomJobDeclaration.readEntities` / `.writtenEntities` (`List<Type>`), with `targetEntities` the deduplicated union | `tom_core_codespecs` | On the declaration's constructor, as **`Type` literals** — §5.23 gives entities no ref const by design, since they are already Dart types and citing the class makes a rename a compile error. Read and written stay **separate** because `SCJOB-WORK` authors them as two fields and a schema change breaks a writer differently from a reader. A `Type` needs only `dart:core`, so the package stays dependency-free. |
| 3 Target references — CE-RP reports | `@CsJob(targetReports:)` (`List<CsReportRef>`) | `tom_code_specs` | As **`CsReportRef` consts on the annotation**, because §5.23 makes the `Cs*Ref` family the annotation *parameter* vocabulary — the same place this annotation's `failureAlert` `CsMessageKey` already sits. A ref const on a `tom_core`-family class would be the outlier: those hold plain ids (`TomReportDefinition.reportId` is the string a `CsReportRef` wraps). Empty by default — most jobs produce no report. |
| 4 Retry / backoff / timeout / alerting | `TomRetryPolicy` (attempts, initial backoff, multiplier, ceiling, jitter); `TomJobDefinition.timeout`; `TomMissedWindowPolicy` + `catchUpLimit`; `TomPermanentFailure`; `TomJobAlert` / `TomJobAlertKind` / `TomJobAlertSink` | `tom_core_kernel` `job_definition.dart` | `@CsJob(maxRetries:, backoff:, timeout:, failureAlert:)`, the last a `CsMessageKey`. The alert *sink* is a deployment wiring on `TomScheduler.onAlert`, not a per-job spec field — a job names the message, the deployment names the destination. |
| Deployment envelope | `TomJobDeclaration` — `enabled`, `environments`, `serviceUnitId`, `runsIn()` | `tom_core_codespecs` | On the declaration's constructor. |

The reuse verdict therefore holds: of the four scope parts, three are covered by
`tom_core_kernel` classes reused whole, and the fourth — target references —
splits by kind across the declaration and the annotation, each in compiler-checked
form.

**SOM surface — two layers under `BatchJobManagement`.** BAJOMA separates
**policy** from **declaration**, and a job comes into existence only in the
second layer:

- **Policy (the default layer)** — `BJMJT` is a narrative *workload shape*, the
  orientation paragraph above the job list; `BJME` authors the execution
  defaults (concurrency, priority, retry, idempotency, timeout); `BJMM` authors
  default monitoring and failure alerting; the head form authors system-wide
  time-zone handling. All of it applies to every job.

  `BJMJT` is deliberately prose and not a form. A form of fixed
  category slots is an inventory grouped by category, so it would be a second
  place to state which jobs exist and could disagree with `SCJOB` — which is
  the layer the extract generator reads. `BJMJT` carries no `@CodeSpecKind` and
  generates nothing; it earns its place as orientation, not as data.
- **Declaration** — `SCJOB-JOB-LST`, a repeated `ScheduledJobEntry` (`SCJOB`),
  one entry per job. *A job that is not listed here does not exist*, however
  thoroughly the policy layer describes how jobs are run. `SCJOB` carries the
  `@CodeSpecKind([CodeSpecPart.backgroundJob])`; the container does not, because
  one entry — not the policy — is one `@CsJob` class.

`SCJOB`'s head form authors the job name, its purpose, `triggerKind`
(`ScheduledJobTrigger`, the `@OneOf` discriminator), the `primaryDataEntity` it
writes, `enabled` and `environments`. The trigger kind promotes exactly one
`@Case` subsection — `SCJOB-CRON` (recurrence expression), `SCJOB-CAL`
(calendar rule) or `SCJOB-EVNT` (event name and payload) — so each arm states
the rule it actually needs instead of a shared free-text field. `SCJOB-WORK`
carries the work *intent* and the read/written entities and target reports,
while the sibling `SCJOST-WORK-LST` list carries the **ordered steps** the work
runs in, one `SCJOST` entry each (`systemAction` plus an optional `condition`).
The split is deliberate: intent is one paragraph and belongs to the job, whereas
a sequence has to be addressable step by step to be conditioned, traced and
derived from — which is what makes the work body form 3b. The list is
**optional**, and empty is a real answer: a job whose work is a single action
lists no steps and its body falls back to 3a on the intent, so a one-action job
is not made multi-step by having to number its one step. A step carries no
number (list position *is* the order), no per-step entities (stated once on
`SCJOB-WORK`) and no per-step policy (stated once on `SCJOB-FAIL`).
`SCJOB-FAIL` carries the per-job **overrides** of the `BJME` defaults (max
retries, backoff, timeout, failure-alert message key), so the policy stays the
default and the entry states only the exception.

Two facts are **derived, not authored**, because authoring them would create a
second source that can drift:

- The **owning service unit** follows from `primaryDataEntity` per the §5.17
  derived-ownership rule — the same rule SVOPE follows.
- A **scheduled report** is declared once, on the CE-RP report definition
  (§5.28); the job that runs it is realised from that schedule, not from a
  second `SCJOB` entry.

**Gap (tom_core_codespecs concrete class) — narrow.** `tom_core_kernel`'s
`tombase/scheduling/` module carries the **whole runtime half** of a job:
`TomJobDefinition` (schedule, work body, retry policy, timeout, missed-window
policy, overlap rule), the `TomSchedule` family (cron / calendar / interval /
once / event), `TomScheduler`, the `TomJobStore` implementations, the
`TomLeaseLock` family, `TomJobBase` with `@TomScheduledJob` discovery, and
`TomJobDispatcher` — which is exactly the "pluggable into any scheduling system"
seam. All of it is **reused directly** per §1.1 pillar (b); re-declaring any of
it in `tom_core_codespecs` is the duplication that pillar forbids.

What the substrate has no home for is the **deployment-and-ownership envelope** a
specification authors *around* a job — `TomJobDefinition` is a runtime object, so
by the time it exists the decision to deploy has already been made. That envelope
is the gap class `TomJobDeclaration`: `enabled` (deployment gating is **opt-out** —
a specified job is meant to run), `environments` (**empty means every
environment**, keeping environment lists out of specs that do not need them),
`serviceUnitId` (owning unit), and `readEntities` / `writtenEntities` (the
entities the job touches, as `Type` literals, declared because
`TomJobDefinition.body` is an opaque closure and reveals nothing). A concrete job carries a `@CsJob`-marked `TomJobDeclaration` and
supplies its own `TomJobDefinition`, whose work body is a **form-3b** body
(decision (k)) over the `SCJOST` steps — or, where a job lists none, a form-3a
body carrying the prose work intent — so the skeleton compiles now and the work
is written at implementation time. The job identity is declared once as a `CsJobRef` const on
the CE-JB catalogue class (§5.23) — citations hold the typed const, never a
string.

**Relationships.**

| Part | Relationship |
|------|--------------|
| CE-SU | Ownership — a job belongs to the service unit that owns its target aggregate (§5.1); it runs under that unit's boundary. |
| CE-DB | Targets — the entities/repositories a job reads or mutates, on the CE-DB access model. |
| CE-RP | Scheduled reports — a CE-RP definition that *names* a schedule (§5.28) is **realised as** a CE-JB job whose work body runs the report projection and hands off to the report's delivery channel. |
| CE-AZ / CE-AU | Execution principal — a job runs under the server principal, not an interactive session; authorization on any CE-API it calls is checked against that principal (§5.6.3, §5.25). |

**Framework substrate (existing `tom_core` mechanics, NOT CodeSpecs gaps).** The
substrate is **complete**; every item below ships in
`tom_core_kernel/lib/src/tombase/scheduling/` and is reused as-is:

- **Scheduler runtime** — `TomScheduler` over the five-member `TomSchedule`
  family (`TomCronSchedule`, `TomCalendarSchedule`, `TomIntervalSchedule`,
  `TomOnceSchedule`, `TomEventSchedule`), so a trigger is a wired schedule rather
  than a name. `TomOnceSchedule` covers the one-shot absolute deadline ("fire
  once at an instant, then never"), and a schedule that can never fire again is
  reported as `TomJobAlertKind.neverFires` rather than staying silent.
- **Job queue** — `TomJobStore` with `TomMemoryJobStore` / `TomFileJobStore` for
  durable enqueue/dequeue of `TomJobRun`s.
- **Multi-node locking** — the `TomLeaseLock` family (`TomMemoryLeaseLock`,
  `TomFileLeaseLock`) for single-fire coordination across a server cluster.
  `tom_process_monitor` remains **reference only** (an existing process
  supervisor) — not a `tom_core`-family class the CodeSpec builds on.
- **Declarative registration** — `TomJobBase` (the `TomCommand` subclass a job
  body extends, carrying its `TomJobRun`), the `@TomScheduledJob` annotation and
  `TomScheduledJobs.discover` / `registerAll`, so a job class *is* its own
  registration and every malformed declaration is a start-up error naming the
  class. The job base class is `tom_core_kernel`'s, and `TomJobDispatcher` — not
  any CodeSpecs class — is the seam that makes execution pluggable.

## 6. Completion elements (recap)

CE-ST, CE-NV, CE-AZ and CE-ER complete the client→server→DB core
parts; CE-CC, CE-DS, CE-UP, CE-CL and CE-AU are their peers. **CE-CF is
server-only** — user settings are CE-UP; device settings are CE-DS;
client-machine settings are CE-CC (§11).

## 7. Server-contract decisions

Design constraints to encode in the CE-API / CE-ER derivation:

1. **All operations are POST.** The operation name (not HTTP verb + path) carries
   intent. CodeSpec models an **operation name** per endpoint.
2. **Only 5xx HTTP codes are transport errors** (infrastructure failure), never
   application outcomes.
3. **All application-level errors are a structured error result** in a normal
   (2xx-transport) response. CE-ER defines one canonical `Result`/`ErrorResult`
   envelope: success payload **or** structured error (code, message, field-level
   details).
4. **Error texts are keyed by the structured error codes** (CE-TX ↔ CE-ER), so
   client copy and server error codes share one source.

## 8. SOM → CodeSpecs derivation map

Generating an area of CodeSpecs code means **walking a SOM subtree**. Four
questions have to be answerable before the first line is emitted, and each has
exactly one home:

| Question | Answered in |
|----------|-------------|
| Which SOM documents does the part's specification live in? | the **document map** below |
| Where does the walk **enter** — which projection root, registry or declaration list? | **§8.5**, the "Authoring home" column |
| Which **repeating entry class** is iterated, and which of its fields and subsections are consumed? | `codespecs_derivation_contract.md` §3, point 1 (**Input**) of each entry named in **§8.5**'s "Derivation entries" column |
| In what **order**? | *Within* a part: `codespecs_derivation_contract.md` §2.1 rule **N8** — SOM document order, depth-first, so a regeneration over an unchanged spec is byte-identical. *Across* parts: **§4.4.3**'s seven topologically ordered slices for emission, and **§4.4.6**'s thirty-one authoring steps — the total order derived from them — for authoring |

The map is therefore two-layered. This section places each part in the document
landscape and names, per part, where its walk is written down; the walk itself is
stated once — in the derivation contract — and is not restated here. Where the
two appear to disagree about emitted code, the derivation contract wins.

Worked: *"I want to generate CE-DB."* → **D03 IMO** (the document map below) →
enter at the `DataModel` projection root (§8.5) → iterate `DataEntityEntry`
`DAENT`, with `DataAttributeEntry` `DAATT` and `EntityRelationshipEntry` `ENRLE`
supplying columns, consuming the fields each entry's Input row lists
(`@CsTable`, `@CsColumn`, the `CsFileReference` facet, `@CsRepository`) → in SOM
document order, in slice 3.

**Document map.**

| CodeSpec element | Primary SOM source document(s) | Notes |
|------------------|-------------------------------|-------|
| CE-EL, CE-FM, CE-LO | **D09 XDS**; **D05 ISC** | Screens/elements/forms/layout from experience design; scenarios name the screens. |
| CE-TX | **D09 XDS** + SOM `@ContentHelp`/`@Form` hints/doc-comments | Texts already in the SOM; error texts via CE-ER codes. |
| CE-VA | **D04 RSP**; **D03 IMO** constraints | Field rules from attribute constraints; form rules from requirements. |
| CE-AC, CE-SC, CE-NV | **D05 ISC**; **D02 TOM** | Scenarios/processes define actions, triggers, transitions; the CE-NV **screen-flow** (form→screen assignment, replace/popup, action-outcome targets) is authored in the **screen route map** (`SCRTMP`) under **D09 XDS**. |
| CE-API, CE-ER, CE-SU | **D07 IFS**; **D03 IMO**; **D06 ATS**; **D05 ISC** | Operations + request/response; service-unit grouping from the D03 entity aggregate fields, capped by the architecture module. |
| CE-AZ, CE-AU, CE-ID | **D08 SAS** | Roles/permissions per operation (CE-AZ); auth/credential/session flow (CE-AU); identity-attribute extensions from the USMGT family (CE-ID). |
| CE-DB, CE-ST | **D03 IMO** rich classes | Tables, columns, view-models, DAOs; domain enums are generated as member declarations of their owning part from DOMEN/DMENE + OBST (§4.1 member-kind rule). |
| CE-CF | **D06 ATS**; **D08 SAS**; **D09 XDS** | **Server/system** configuration only. ATS carries the declared list and the CM / feature-flag bands, SAS the security, audit-sink, encryption and key-management bands, XDS the `PrintAndExportLayout` renderer settings (§5.5). |
| CE-CC, CE-DS, CE-UP, CE-CL | **D06 ATS** (`ClientApplicationEntry` CLIAPP, under `ClientRequirementsSection` CLRESE, alongside the CE-CC / CE-DS / CE-UP declaration lists); **D09 XDS** (preferences surfaced in UI, and the routes and screens a client cites); **D02 TOM** (roles → whose settings) | Client apps + per-machine client config + device settings + user settings. |
| CE-RP | **D09 XDS** (report definition family, under `ReportDefinitions`); **D03 IMO** (source data) | Report definitions — the grouped projection, its output columns and charts, its parameters and its delivery channels (§5.28). The sibling print/export *settings* under `PrintAndExportLayout` are CE-CF, not CE-RP. |
| CE-JB | **D06 ATS** (`ScheduledJobEntry` SCJOB, under `BatchJobManagement` BAJOMA) | Background/scheduled jobs from the architecture's operational model, one entry per job; targets cite IMO entities and CE-RP reports (§5.29). |
| **Deferred (§4.3)** | per the §4.3 "SOM home section" column | **Mapping-only**: the SOM section carries `@CodeSpecKind` with the reserved kind; no CodeSpecs code until promoted. |

**Derivation principle:** the SOM's stable `@SectionId` is the join key — each
generated element's `@CodeSpec(source: [...])` cites the extract tokens it came
from as a flat set (§9.3), making gap analysis a set-difference over tokens,
and its `@DocSpec([DocRef(sectionId, …), …])` says what it took from each.

### 8.1 The CodeSpecs surface is bounded

The SOM has **~1240 classes across 14 roots**, and the CodeSpecs surface is
concentrated in a **minority** of them. The rest is business-facing descriptive
content that Phase 4 does **not** generate code from — it feeds the *other*
follow-up processes instead (§8.3).

| Root(s) / file | ≈classes | CodeSpecs-relevant? | Parts in play |
|----------------|---------:|---------------------|---------------|
| **D03 InformationModel** (`information_and_data_model.dart`) | 40 | **Yes — core** | dataAccess, viewState, validation, domainEnum, action, serviceUnit, authorization, serverApi, serverCall, errorResult, text, schemaMigration |
| **D09 ExperienceDesignSpecification** (`experience_and_interface_design.dart`) | 122 | **Yes — core** | screenElement, form, layout, text, viewState, navigation, validation, action, errorResult, configuration, reporting |
| **D08 SecurityAccessSpecification** (`security_and_access_model.dart`) | 151 | **Yes** | authorization, authentication, identity, serverConfiguration, auditLog, validation |
| **D06 ArchitectureTechnologySpecification** (`architecture_and_technology.dart`) | 249 | **Partly** | configuration, serverApi, serviceUnit, client, clientConfiguration, backgroundJob |
| **D07 IntegrationInterfaceSpecification** (aggregates XDS+ATS) | 27 | **Yes** | serverApi, serverCall, errorResult, serviceUnit |
| **D05 InteractionScenarios** + **D02 TargetOperatingModel** | 64 | **Partly** | action, serverCall, navigation, authorization, validation |
| **D04 RequirementsSpecification** (functional-requirement slice) | 8 | **Partly** | validation, dataAccess, form, action, serverCall, navigation — the L10N/IFU/training and technical/security NFRs are non-codespecs |
| `current_landscape.dart` (D01 CLA) | 83 | No | as-is analysis |
| `delivery_roadmap.dart` (D11) | 45 | No | staging plan |
| D10 QAP (`quality_model.dart`, `quality_and_acceptance_model.dart`, `delivery_scope_and_acceptance.dart`) | 66 | No | quality goals, UAT |
| `target_organization.dart`, `governance_administration.dart` | 115 | No | org/governance narrative |
| D12 TRP (`transition_and_rollout_plan.dart`, `delivery_transition_and_rollout.dart`) | 11 | No | rollout narrative |
| `components_and_dependencies.dart`, `solution_architecture_and_technology.dart` | 19 | No | build-vs-buy narrative |

**~410 classes across 8 documents are non-codespecs descriptive content.** That
is not a gap — it *bounds* the CodeSpecs surface, and it is the raw material for
the follow-up split (§8.3).

### 8.2 Closed-choice sections — the `@OneOf` / `@Case` discriminated group

**The problem.** A descriptive section often must resolve to **exactly one of a
closed set of typed alternatives**, each carrying only that kind's attributes.
Modelled naively, such a section carries a free-text kind discriminator plus the
**union** of every kind's attributes as always-optional members — a Date field
still carrying `decimalPlaces`, a Number field still carrying `optionsSource`,
`inputMask` sitting next to `minValue`/`maxValue`. Nothing forces a spec to a
single kind's attributes; nothing forbids two kinds at once.

**Why not subtype polymorphism.** The obvious OO answer — an abstract base with
`TextInputElement` / `DateInputElement` / … subclasses — **fights the SOM**. The
reader and validator resolve each `List<T>` to a *single* `listElementTypeName`
and require every class to reach `DocSpecsSection` by **field composition**, not
by polymorphic element lists. A polymorphic list has no single element type and
breaks section-id resolution. Subtyping is rejected.

**The mechanism.** Stay inside the existing `DocSpecsSection` / `@Form` /
complex-subsection shapes; add two annotations (declared in `tom_specs_core`,
exported losslessly like `@CodeSpecKind`) and one validator invariant:

1. **`@OneOf(discriminator: '<formFieldName>')`** on the container section —
   declares that a named group of complex-subsection fields is a *closed choice*
   and names the discriminator `@Form` field. **The discriminator must be a model
   enum**, which is why the domain-enum registry is a hard prerequisite.
2. **`@Case(<EnumConstant>)`** (repeatable) on each alternative
   complex-subsection field — binds that subsection to one or more discriminator
   values. A subsection with **no** `@Case` is *common*: it applies to every case
   (e.g. `resources` / `layout` / `visibility`).
3. **Modeling rule** — promote each kind to its **own** typed subsection carrying
   only that kind's attributes (Date → `firstDate`/`lastDate`; Number →
   `minValue`/`maxValue`/`decimalPlaces`; Select →
   `optionsSource`/`selectMode`/`displayMode`). This converts a
   union-of-`@Form`-fields into a discriminated subsection group — one mechanism
   at both granularities.

**Enforcement is two-tier**, because the SOM validator is *static* (it analyzes
the class graph, not documents):

- **Static** (`tom_specs_clitool/lib/src/validator.dart`, the "`tom_specs_model_rules.md` §10.2 one-of"
  invariant): (i) the `@OneOf` discriminator resolves to a `@Form` field whose
  type is a model enum; (ii) every `@Case` value is a constant of that enum;
  (iii) the `@Case` values across the group **cover** the enum, minus the
  constants the group declares `@OneOf(noCase: [...])` — an uncovered,
  undeclared case is a *warning*, not an error (a kind whose case has not been
  written yet still generates); (iv) the group's alternative fields are all
  complex subsections of the same container; (v) every `noCase` entry is a
  constant of the discriminator enum; (vi) no constant is both `noCase` and
  `@Case`-bound.
- **Instance** (DocSpecs document validator + editor strict mode): a concrete
  section instance carries **only** the subsections whose `@Case` matches the
  chosen discriminator value (plus the un-`@Case`d common ones), and **at most
  one** per case.

**The complete closed-choice inventory.** A whole-model structural scan
(discriminator + ≥2 complex members) surfaces ~311 sections. The qualifying test
is **(a)** a discriminator `@Form` field **and (b)** a union of ≥2
mutually-exclusive per-kind attribute groups. Two shapes are explicitly ruled
out: **enumerable scalars** (a `*Type`/`priority`/`severity` field whose values
are closed but which gates no divergent sibling attributes — that is a domain-enum
concern) and **composition discriminators** (a `*Type`/`*Strategy` field
alongside complex subsections that are *all* present, e.g. `ScreenActionEntry` →
`visual`/`conditions`/`behavior`; `ServerRoleEntry`; `ComponentEntry` — no mutual
exclusivity, so no one-of). Applying the test collapses ~311 candidates to **two
families**:

**Family 1 — element/field kind (CE-EL / CE-FM). Converted.**

| # | Section (member) | Discriminator enum | Cases |
|---|------------------|--------------------|-------|
| 1 | `ScreenElementEntry` (D09 XDS) | `ScreenElementKind` | action / input / display facet subsections, plus common `resources`/`layout`/`visibility` |
| 2 | `ScreenElementFieldSpec` (D09 XDS) | `ScreenElementFieldKind` | numeric / date / text / select case subsections |

The "display-vs-input-vs-action facet split" is **not** a separate locus — it is
the `@Case` grouping *within* site #1.

**Family 2 — typed-value data-type unions (CE-FM / CE-DB). Converted.** Each
site's `dataType`/`fieldType` discriminator is a **model enum** (per the
"discriminator must be a model enum" rule) over per-kind `@Case` subsections,
with only the type-independent attributes in the common subsection:

| # | Section (member) | Doc | Discriminator enum | Case subsections |
|---|------------------|-----|--------------------|------------------|
| 3 | `DataAttributeEntry.dataTypeSpec` | D03 IMO | `DataAttributeKind` | `textTypeOptions` / `numericTypeOptions` / `temporalTypeOptions` / `binaryTypeOptions` / `fileReferenceOptions` / `enumerationTypeOptions` |
| 4 | `ReportColumnEntry.formatting` | D09 XDS | `ReportColumnKind` | `numericFormat` / `currencyFormat` / `dateFormat` / `booleanFormat` / `textFormat` |
| 5 | `ExportFieldMappingEntry.formatting` | D09 XDS | `ExportFieldKind` | `numericOutput` / `temporalOutput` / `booleanOutput` / `enumerationOutput` / `textOutput` |
| 6 | `ReportFilterEntry.input` | D09 XDS | `ReportFilterValueKind` | `textFilterOptions` / `numericFilterOptions` / `dateFilterOptions` / `booleanFilterOptions` / `selectFilterOptions` / `entityFilterOptions` — each carrying its own kind-appropriate `inputType` |
| 7 | `ScreenFieldEntry` | D04 RSP (`introduction_and_scope.dart`) | `ScreenFieldKind` | `textConstraints` / `numericConstraints` / `temporalConstraints` / `choiceOptions` |

Site 3 is also the case that proves the discriminator need not sit on `content`:
`DataAttributeEntry` has no `content` member, so `dataType` lives in the `@Form`
of the `dataTypeSpec` subsection. Both the static validator (`_allFormFields`)
and the instance-tier check resolve a discriminator in either position.

A kind that carries no extra attributes binds no case, and the group says so in
`@OneOf(noCase: [...])` — e.g. `DataAttributeKind.boolean`/`uuid`/`json`, the
four `AuthorizationRequirementKind` presets, `ScreenFieldKind.boolean`, and
`FlowReturnPoint.endFlow`, where the attribute-free arm is not a value kind but
a control transfer: a branch that ends its scenario has no step to name, which
is precisely why the pair is a closed choice rather than one `String`. The
declaration is what makes the coverage warning meaningful: it separates a kind
that was *examined and found attribute-free* from one whose case simply has not
been written, so the remaining warnings are an inventory of unexamined kinds
rather than a permanent background hum every reader has to re-derive as benign.
The reason still belongs *at the constant* — the `noCase` list records the
verdict, the doc comment records why. Working through that inventory is what
found three catalogue gaps: the file kind (§5.13.1), the CE-EL colour (§5.18),
and the enumerated attribute kind — whose *value set* is declared in the domain
enum register, but nothing named **which** enum the attribute draws from, so it
now binds `enumerationTypeOptions` (`DAATT-DTEN`, §5.13).

**Ruled out after inspection:** `ObjectStateEntry.stateType` (`ObjectLifecycleKind`,
D03 IMO) — its discriminator gates **common** attributes (entry/exit conditions,
allowed/restricted operations, SLA — all apply to every lifecycle role), so it is
a domain-enum value set, not a subsection union.

### 8.3 The CodeSpecs / follow-up split and the generation projection

§8.1 bounds the surface by *document*; the structural question is sharper: can a
**whole subtree** be handed to generation end-to-end? A subtree that mixes
generated and non-generated content cannot, so every mixed boundary is a **split
point**. The model is therefore divided as high up as possible into

- **purely-CodeSpecs subtrees** — every reachable section maps to a
  `@CodeSpecKind` part and is realised as `Cs*`-annotated code; and
- **purely-follow-up subtrees** — every reachable section is delivered by a
  non-generation process.

**Two different questions, two different mechanisms.** *What generation walks* is
decided by projection membership: a subtree is CodeSpecs iff it is reachable from
`D13CodeSpecsProjection`, and the follow-up roots are the ones that are not.
*What each generated area is shown* is decided by the routing verdicts below: the
Phase-4 extract generator (§1.1.1) collects, per area, the sections routed to
that area by `@CodeSpecKind`. The first answers "does this subtree go to Phase 4
at all"; the second answers "which area's extract does this section land in". A
section can sit inside the projection and still be invisible to every area — that
is exactly the failure `ROUTE-TOTAL` below exists to make impossible. Inside
a follow-up subtree, individual sections **may still carry a `@CodeSpecKind`** —
that annotation records which part the section's *material* belongs to, and is
how the follow-up process knows what it is producing material for. The
annotation does not by itself make the section generated. It holds at scale: 64
of the model's `@CodeSpecKind`-bearing sections sit inside a follow-up subtree,
across 13 of the 45 follow-up roots.

**A `@CodeSpecKind` under a follow-up root resolves one of two ways, and which
one is a structural fact, not a judgement.** Either the projection reaches the
section anyway — 41 of the 64 — because the follow-up root is itself nested
inside a projected subtree, or because the projection reaches *past* the root to
a pure band beneath it (§4.3's ruling stated structurally: only a section that
must become a *projection root* has to be hoisted out, and a root cut one level
too high is reached past rather than re-cut). Or the projection does not reach
it — the other 23 — and then the material reaches generation through a
D13-reachable **bearer** of the same part: CE-TX help copy through the shared
`MessageKeyRegistry` is the pattern, and text is 10 of the 23. A bearer is a
projected section that *already carries the same material*, not merely one of
the same part; where no such section exists, reaching past the root is the
answer and a bearer is not.

**The three routing verdicts.** Every section is routed by exactly one of three
markers, and the trio is exhaustive by construction:

| Verdict | Marker | Means |
|---------|--------|-------|
| feeds code | `@CodeSpecKind(List<CodeSpecPart>)` | the section's content is shown to every named area's extract |
| feeds a process | `@FollowUpKind(List<FollowUpProcess>)` on a subtree root | the section is delivered by a non-generation process |
| feeds nothing | `@NoArtifact(NoArtifactReason)` | the section deliberately produces no downstream artifact |

`@NoArtifact` (`tom_specs_core`) is the marker that makes the absence of the
other two *readable as a decision* rather than as an omission. Its reason is a
closed three: `container` — a chapter node whose children are routed
individually; `overview` — prose introducing sections that carry the facts
themselves; `view` — a diagram or traceability rendering of content stated
elsewhere. It carries the same optional `note` as the other two, and rides in the
generic `extra` bag of the cross-language meta exactly as `@CodeSpecKind` does
(§8.4), so all nine runtimes carry it without a slot.

**Coverage is two-directional, and both directions are checked.** The
`tom_specs_model_rules.md` §10.2 invariants `KIND-EXCLUSIVE`, `PART-ROUTED` and
`ROUTE-TOTAL` hold the routing together, and the validator enforces all three:

- `KIND-EXCLUSIVE` — **no section carries more than one of the three verdicts.**
  A follow-up root is never itself generated, and a section that feeds nothing
  cannot also feed something.
- `PART-ROUTED` — **part → section:** every active part named by any
  `@CodeSpecKind` has at least one bearer reachable from D13, so a part named
  from inside a follow-up subtree is never a routing gap. The single permanently
  deferred part, CE-WF, is exempt by construction: it has no generated surface,
  so it has no bearer to reach.
- `ROUTE-TOTAL` — **section → part (the converse):** every class the **routing
  walk** reaches carries a verdict of its own — a `@CodeSpecKind`, a
  `@FollowUpKind` or a `@NoArtifact`. `PART-ROUTED` says nothing *claimed* goes
  ungenerated; `ROUTE-TOTAL` says nothing is *silently* left out. It is
  load-bearing for Phase 4: the extract generator walks `@CodeSpecKind` to decide
  what lands in which area's extract, so a section routed nowhere is a section
  the agent writing that area never sees. The `@Document` roots are exempt
  structurally — a root is the document, not a section of it, and has no content
  of its own to route.

**The routing walk.** `ROUTE-TOTAL`'s domain is a walk, not a type-reachability
set: it starts at **every** `@Document` root and **stops descending at a
`@FollowUpKind`**. A follow-up root is routed; its subtree belongs to that root's
processes, so nothing inside it needs a verdict of its own. Exemption is
therefore by *path* — a class is covered by a follow-up root only where the walk
passes through that root, never merely because some field chain from that root
reaches its type.

The distinction is load-bearing, in both directions. Reading it by type
**exempts too much**: `GradedAuthorizationRequirement` is type-reachable from
`ExperienceDesignFollowUp`, but its home is under a `@CodeSpecKind` parent in the
SBP's authorization subtree, so the type-level reading silently withheld
authorization material from every extract. And starting the walk at
`D00SolutionBlueprint` alone **sees too little**: all 45 follow-up roots live in
the SBP tree, while each Phase-3 detail document (D01–D12) re-uses the same
classes by its own paths, which the SBP walk never visits. Both tiers implement
the same walk — `validator.dart`'s `_routingWalk` statically, and
`CodeSpecsExtractor._walk` at runtime — and where they could differ the runtime
is the authority, because it is the walk the extraction run performs
(`codespecs_prompt.md` §4.3).

Before `@NoArtifact` existed the second direction was not expressible: "decided
to feed nothing" and "nobody got round to it" were written identically, so a
missing marker could not be read as a defect.

**Top-level verdict.** `D00SolutionBlueprint` has 15 top-level sections
(SBP.1–SBP.9, SBP.11–SBP.15; SBP.10 is unused). **Eight split cleanly at the top**
as whole follow-up subtrees: `documentControl`, `introductionAndScope`,
`glossaryAndAbbreviations`, `stakeholdersAndGovernance`, `currentLandscape`,
`assumptionsConstraintsDependencies`, `qualityAndAcceptanceModel`,
`deliveryTransitionAndRollout`. **None of the 15 is purely CodeSpecs at the top** —
the generation surface is always a subtree *inside* a mixed section. The six
mixed sections are exactly the CodeSpecs-bearing documents of §8.1: SBP.7 TOM,
SBP.8 IFM, SBP.9 RSP, SBP.11 ATS, SBP.12 SAS, SBP.13 XDS. QAP (SBP.14) is
*entirely* follow-up because acceptance-test derivation is a **separate TomSpecs
phase** (Phase 5), not Phase-4 code generation.

**Follow-up taxonomy.** Every follow-up subtree is tagged with the process that
delivers it, via `@FollowUpKind(List<FollowUpProcess>)` (`tom_specs_core`) —
list-valued and applied to subtree roots, mirroring `@CodeSpecKind`. Nine codes
cover the surface today; the enum is **extensible**:

| Code | Follow-up process | Typical content |
|------|-------------------|-----------------|
| **DOC** | Documentation authoring | scope, glossary, user docs, assessment writeups |
| **TRN** | Training / enablement | training deliverables, enablement plans |
| **ORG** | Organizational change | roles, org structure, governance, stakeholders |
| **OPS** | Operational routines | audit/logging ops, key management, monitoring, backups |
| **CAP** | Capacity / infra planning | volume metrics, technical characteristics |
| **CMP** | Compliance & regulatory | compliance framework, data-classification obligations |
| **MIG** | Migration & transition | data-migration mapping, rollout, cutover |
| **L10N** | Localization / translation | message translation, locale content authoring |
| **ACC** | Acceptance & audit evidence | end-to-end acceptance scenarios, security-audit evidence (Phase 5, not Phase 4) |

These are **process tags, not new model types**. Each follow-up subtree carries
one so the downstream process can select its slice.

**Split points per mixed section.** In each case the CodeSpecs-bearing children
are grouped into one subtree and the rest hoisted into tagged follow-up subtrees:

| Section | CodeSpecs subtree | Hoisted to follow-up |
|---------|-------------------|----------------------|
| SBP.7 TOM | `processStepsAndActorInteractions` (PSAAI, `@MapsTo` D05) | `organizationAndProcessConcept` (OAPC) grouping `organizationalFramework` + `businessProcessDescriptions` → ORG/OPS |
| SBP.8 IFM | `DataModel` (entity/attribute core) | per-entity facets: Volume→CAP, Compliance→CMP, Technical→CAP, Migration→MIG, erDiagram→DOC |
| SBP.9 RSP | functional requirements + the CE-VA/CE-ER-bearing NFRs (consumed as a *seed*) | L10N/DOC/TRN NFR sub-areas |
| SBP.11 ATS | `TechnicalFrameworkConcept` (CE-CF configuration facets) | architecture/component narrative → DOC |
| SBP.12 SAS | `AccessControlModel` (userMgmt / auth / resourceProtection / authorization / roleMatrix), `AuditAndLogging` (the CE-LG event declarations + the CE-CF sink settings) **and** `SensitiveDataEncryption` (encryption at rest / in transit + `KeyManagement`, reached past the OPS root) | audit reporting/review (`ComplianceReporting`) → OPS, compliance framework → CMP |
| SBP.13 XDS | `ExperienceCodeSpecs` (screens / screenFlow / errorHandling / responsive / uiComponents / dataStructureAlignment) **and** `PrintAndExportLayout` (the CE-CF renderer settings, reached past the DOC root) | design, doc and L10N children |

**Constraints any further re-homing must honour:**

- **Pure-projection invariant** — the D01–D12 projections reach only their SBP
  counterparts. Moving a section within SBP changes what each projection reaches,
  so every move cascades to the projection roots and must keep the outliner and
  the validator green from **all 14 roots**.
- **Section-id stability** — ids resolve root-independently; moves must preserve
  `@SectionId` global uniqueness and coverage (no orphaned `@SectionIdPattern`
  subtrees).
- **Downstream cascade** — each move cascades to the SOM meta, both committed
  `spec_model.json` assets (`tom_specs_reviewer/assets/` and
  `tom_forge/tom_specs_editor/assets/`, byte-identical modulo `generatedAt`) and
  the language facades. Make one discrete move at a time.
- **Traceability follows the section** — re-home `@MapsTo` / `@DetailedIn` with
  the sections they annotate; a hoisted follow-up subtree keeps its own `@MapsTo`
  targets.

**The generation projection.** Once the CodeSpecs subtrees are isolated, the
concrete input the Phase-4 extract generator consumes end-to-end is
**`D13CodeSpecsProjection`** (`@SectionId('CGP')`, in
`tom_specs_model/lib/src/codespecs_projection/codespecs_projection.dart`) — a
flat `@Document(basedOn: [D00SolutionBlueprint])` referencing the **sixteen
isolated subtree roots directly**, with no container classes, grouped into
shared → server → client locus bands by `@Comment('locus: …')`:

| Locus | Roots |
|-------|-------|
| shared | `DomainEnumRegistry`, `ErrorCodeRegistry`, `ResultEnvelope`, `MessageKeyRegistry`, `NotificationModel` |
| server | `DataModel`, `AccessControlModel`, `AuditAndLogging`, `SensitiveDataEncryption`, `ReportDefinitions`, `PrintAndExportLayout`, `SchemaVersioningAndMigration` |
| shared + server | `ServerOperationRegistry` |
| server + client | `TechnicalFrameworkConcept`, `ProcessStepsAndActorInteractions` |
| client | `ExperienceCodeSpecs` |

**Membership follows the part, not the parent.** A root is here because the
subtree it names is purely `@CodeSpecKind`-bearing — not because of where the
follow-up splits happened to cut. Two of them, `SensitiveDataEncryption` and
`PrintAndExportLayout`, are therefore reached *into* a `@FollowUpKind` root to
pick a pure CE-CF band out of it, leaving that root's genuinely
process-delivered siblings behind. That is the split rule applied, not weakened:
a subtree mixing generated and non-generated content is a split point, and
reaching past the root is how the projection expresses the split where the root
was cut one level too high.

It is `@CodeSpecKind`-driven rather than `@DetailedIn`-driven, so it carries the
`@CodeSpecsProjection()` marker (`tom_specs_core`), which exempts it from the
`tom_specs_model_rules.md` §10.2 **detail-count** check only — it still satisfies the pure-projection
invariant. The RSP `Requirements` seed is **deliberately excluded**: requirements
are *consumed* by generation, not generated from.

### 8.4 `@CodeSpecKind` in the cross-language meta

`@CodeSpecKind` is **not** a slotted annotation in the per-language SOM meta
emitters. All nine emitters (`dart`/`typescript`/`javascript`/`python`/`java`/
`go`/`rust`/`c`/`cpp`) share one 13-entry slot set — `SectionId`,
`SectionIdPattern`, `SerializationOrder`, `Min`, `Unused`, `ContentType`,
`ContentHelp`, `Headline`, `Comment`, `Form`, `Document`, `MapsTo`, `DetailedIn`
— and route every non-slotted annotation into the generic `extra` catch-all. So
`@CodeSpecKind` **already rides in `extra` losslessly in all nine languages**,
with both `kinds` (list) and `note` intact.

It gets **no dedicated slot**, deliberately. A slot is warranted only when a
cross-language meta *consumer* navigates the annotation **structurally** —
`mapsTo`/`detailedIn` are followed as cross-phase *references* into other nodes
by tooling and editors, so a consumer needs them resolved rather than spelled.
`@CodeSpecKind` has a consumer in all nine languages — the §1.1.1 extract
generator, `spec_codespecs_extract`, which is a runtime surface precisely so
that Phase 4 is not a Dart-only phase — but that consumer **reads it as a
value**, not as a reference: it matches a self-describing `CodeSpecPart.*` token
against the area catalogue. Reading a value by annotation name off `extra` is
the same one-line lookup in every runtime, and it is what all three verdicts
already share. Promoting it would touch all nine emitters, the shared
`SomMetaNode` runtime shape, the meta schema and the conformance goldens without
making that lookup simpler anywhere. The `extra` treatment is exactly the
intended design for annotations carried whole and consumed by value.

The same holds for the other two routing verdicts. `@FollowUpKind` and
`@NoArtifact` (§8.3) are likewise unslotted and ride in `extra` with their value
and `note` intact, so adding `@NoArtifact` to the model changed no emitter — it
required a regeneration and nothing more. All three verdicts are therefore
readable in all nine languages by the same `extra` lookup, which is what lets a
non-Dart runtime answer "what is this section routed to" without a slot per
verdict.

### 8.5 SOM coverage verdict — every part's authoring home

Every **active** part must have a place in the SOM where a spec author can
actually author it. A part without one is code with no specification source,
which breaks the derivation chain this section describes. The verdict below is
the standing record; re-derive it (not re-read it) whenever a part or a SOM
section changes shape.

**The verdict is two-dimensional**, because a part can fail in two independent
ways:

- **Authorable** — a `@CodeSpecKind`-carrying SOM section exists whose members
  can carry the part's §5 attribute surface. A section that names the part but
  cannot express its attributes is *not* an authoring home.
- **Generable** — that section is reachable from **`D13CodeSpecsProjection`**
  (§8.3), the concrete input Phase-4 generation consumes. An authorable section
  outside the projection is authored into a document the extract generator never reads.

A part is **COVERED** only when both hold.

**The table is also the per-part walk index (§8).** "Authoring home" is where the
walk **enters**; "Derivation entries" names the `codespecs_derivation_contract.md`
§3 entries whose point 1 (**Input**) states the repeating entry class and the
fields and subsections consumed. Entries are cited by **marker name**, which is
globally unique in that document, so `@CsTable` resolves without a section
number. Order is not per part and so is not a column: within a part it is SOM
document order (`codespecs_derivation_contract.md` §2.1 rule **N8**), across
parts §4.4.3's slices.

| CE | Kind | Authoring home (SOM class · section id) | Derivation entries (`codespecs_derivation_contract.md` §3) | Verdict |
|----|------|------------------------------------------|---------------------|---------|
| CE-EL | `screenElement` | `ScreenElementEntry` SCREL · `UiComponentEntry` UICOM · `ComponentVariantEntry` CVE | `@CsElement` · `@CsWidget` | COVERED |
| CE-FM | `form` | `ScreenElementFieldSpec` SEFS (per-field surface) inside `ScreenElementEntry`; the form container is the screen section | `@CsForm` | COVERED |
| CE-LO | `layout` | `ScreenSectionEntry` SCRSC · `ScreenResponsiveRuleEntry` SCRERU · `ComponentSlotEntry` CMSL | `@CsLayout` | COVERED |
| CE-TX | `text` | `MessageKeyEntry` MSGKE (the `MessageKeyRegistry` projection root) · `ValidationMessageTemplate` VMT | `@CsText` | COVERED |
| CE-VA | `validation` | `ElementValidationRuleEntry` ELVARU · `DataAttributeConstraintEntry` DATAA · `IntegrityConstraints` INCO | `@CsValidation` · `@CsFieldRule` · `@CsFormRule` | COVERED |
| CE-AC | `action` | `ScreenActionEntry` SCRAC · `ScreenElementAction` SCELAC · the ISC step entries MNSST/ALST/EXTST/SCNST | `@CsAction` · `@CsTrigger` | COVERED |
| CE-SC | `serverCall` | the ISC step entries MNSST/ALST/EXTST/SCNST, each under its own flow container (`MainSuccessScenario` MASUSC · `AlternativeFlowEntry` ALFL · `ExtensionEntry` EXTEN · `ScenarioEntry` SCNRY). All four step entries carry `action`+`serverCall`+`navigation` together, since one step is at once all three, and each carries the `ServerCallStepEntry` SVCST list whose required `role` routes a step to one of the call's three handling methods (§5.3). The operation the call targets is **authored** on the step: the optional `serverOperation` field cites `SVOPE.operationName`, and its presence is exactly what emits the call (§5.3) | `@CsServerCall` | COVERED |
| CE-API | `serverApi` | `ServerOperationEntry` SVOPE · `ServerOperationMemberEntry` SVOPM, under the `ServerOperationRegistry` SVOPR projection root (`operationName` · `primaryDataEntity` · `authorization` → the AZREQ closed choice (§5.15) · `descriptionKey` · `errorCodes` · request/response members). `DataEntityEntry` DAENT · `DataAttributeEntry` DAATT · `DataAttributeConstraintEntry` DATAA are **dual-routed** here beside their `dataAccess` home: they supply the shared entity wire DTO of an entity a member's `SVOPM.dataEntity` names (`codespecs_derivation_contract.md` §3.2.11), since the slice-2 shared emission may not forward-reference slice 3. The external-interface inventory `InterfaceOperationEntry` IOE and `IntegrationPointEntry` INTEG describe **foreign** contracts and carry `serverCall` only | `@CsEndpoint` (shared and server halves) · the markerless entity wire DTO of `codespecs_derivation_contract.md` §3.2.11 | COVERED |
| CE-SU | `serviceUnit` | `DataEntityEntry` DAENT — the `DAENT-CLAS` grouping fields `aggregateRoot` (the ownership key, a `refersTo` reference to `DAENT.entityName`, so a root names itself) · `serviceUnitAggregate` (the process-cohesion merge/split adjustment) · `boundedContext` (the outer cap, a `refersTo` reference to `BCE.contextName`, so the cap is a registry key rather than a spelling). The unit set is the distinct effective aggregates, so it is counted rather than authored. `ArchitectureComponentEntry` ARCM (identity · `boundaries.dataOwnership` · `content.domain` · `purpose.responsibilities`) supplies the component narrative only; `FunctionModel` FUMO / `FunctionEntry` FUNCT / `SubFunctionEntry` SUFN / `FunctionDataMatrixEntry` FNDMX supply the function×data view the operation inventory is checked against | `@CsServiceUnit` | COVERED |
| CE-DB | `dataAccess` | `DataEntityEntry` DAENT · `DataAttributeEntry` DAATT · `EntityRelationshipEntry` ENRLE (the `DataModel` projection root) · `DataAttributeConstraintEntry` DATAA, whose storage facts (nullable, length, format) the `@CsColumn` derivation consumes (`codespecs_derivation_contract.md` §3.3.2) beside its `validation` home | `@CsTable` · `@CsColumn` · `CsFileReference` · `@CsRepository` | COVERED |
| CE-ST | `viewState` | `ScreenStateEntry` SCRST · `ScreenElementDataDisplay` SEDD · `ComponentStateEntry` COMSTA (D09 XDS, the states and data-bound displays) · `DisplayPropertyEntry` DISPL · `BusinessObjectAttributeEntry` BIOBAT with its `BOAED` detail (D03 IMO, the per-field shape and requirement level). The IMO business-object catalogue above BIOBAT — `BusinessObjectModel` BJOMD, `BusinessObjectEntry` BJOEN — carries the kind but is **unprojected**: it is the domain catalogue fields are read from, not a screen's state | `@CsViewModel` | COVERED |
| CE-NV | `navigation` | `ScreenRouteEntry` SCRTEN · `FormScreenAssignmentEntry` FMSCAS · `ScreenTransitionEntry` SCTREN, under `ScreenRouteMap` SCRTMP | `@CsRoute` · `@CsScreenFlow` | COVERED (screen-flow half verified) |
| CE-AZ | `authorization` | The requirement itself is `AuthorizationRequirementSpec` AZREQ → `GradedAuthorizationRequirement` AZGRD → `GradedAccessLevelEntry` AZLVL — one reusable closed choice covering all ten §5.15 arms, embedded at each modifier site (`SVOPE.authorization`; the XDS `access` members on screen, screen element, navigation group/item, tab, utility navigation/menu, deep link, report, export format/template). The **catalogues** it cites stay `RoleMatrix` ROMA · `RolePermissionEntry` ROLPER · `EntitlementEntry` ENT (46 sections, all projected) | `@CsAuthorize` (the `CsGradedAccess` facet is filled within it, not by an entry of its own) | COVERED |
| CE-ER | `errorResult` | `ErrorCodeEntry` ERCEN (the `ErrorCodeRegistry` root) · `ResultEnvelope` RSLTE | `@CsError` | COVERED |
| CE-CF | `serverConfiguration` | 42 marked sections in two shapes (§5.5). **Declared** (1): `SystemConfigurationManagement` SYCOMA over its open list `ServerConfigurationSettingEntry` SCSET (`settingKey` · `valueType` · `defaultValue` · `environmentVariable` · `commandLineOption` · `secret` · `overridableBy`) — the only place a key is invented and the only place a secret is declarable, and both authorable and projected. **Fixed** (41): the bands whose form fields each name one setting the model already knows — `ConfigurationManagement` CM, the ATS feature-flag band, the SAS API-security / file-and-storage-security / audit-sink / encryption / key-management families, and D09's `PrintAndExportLayout` PRLA band. All 42 are projected; the encryption and PRLA bands are reached past a `@FollowUpKind` root that was cut one level too high (§5.5, §8.3) | `@CsServerConfig` | COVERED |
| CE-CC | `clientConfiguration` | `ClientConfigurationSettingEntry` CCSET — the declaration list under `ClientConfiguration` CLICON (`settingKey` · `valueType` · `defaultValue` · `overridableBy`) | `@CsClientConfig` | COVERED |
| CE-DS | `deviceSettings` | `DeviceSettingEntry` DSSET — the declaration list under `DeviceSettings` DEVSET (`settingKey` · `valueType` · `defaultValue`; no `overridableBy` — CE-DS is the narrowest scope, so it has nothing below it to open) | `@CsDeviceSetting` | COVERED |
| CE-UP | `userSettings` | `UserSettingEntry` USSET — the declaration list under `UserSettings` USRSET (`settingKey` · `valueType` · `defaultValue` · `overridableBy`). `LanguageCountrySelection` LACOSE stays the language/country **picker UX** and carries no `@CodeSpecKind`: the preference it edits is declared in USRSET | `@CsUserSetting` | COVERED |
| CE-CL | `client` | `ClientApplicationEntry` CLIAPP — the client-application list under `ClientRequirementsSection` CLRESE (`clientId` · `clientName` · `clientKind` · `purpose` · `platformTargets` · `entryRoute` · `includedScreens`), which keeps the minimum browser/OS/device requirements a client entry references | `@CsClient` | COVERED |
| CE-AU | `authentication` | `AuthenticationMethodEntry` ATME · `LoginFlowStepEntry` LGFLS · `MfaConfiguration` MC (the second-factor policy) · the 42-section policy set | `@CsAuth` (shared, server and client halves) | COVERED |
| CE-ID | `identity` | `UserAttributeEntry` USATE · `UserLifecycleTransitionEntry` ULTRE · `UserCategoryDefinition` USCDF | `@CsIdentity` · `@CsIdentityAttribute` | COVERED |
| CE-MG | `schemaMigration` | `SchemaVersioningAndMigration` SCHMG (projected into D03 IFM and into `D13CodeSpecsProjection` at the server locus) + `MigrationTargetEntry` MIGTG (datasource/schema placement) + `SchemaMigrationStepEntry` SCMST, a `@OneOf` over the three §5.27 artifact kinds, carrying the environment tag | `@CsMigration` | COVERED |
| CE-JB | `backgroundJob` | `ScheduledJobEntry` SCJOB — the per-job declaration list under `BatchJobManagement` BAJOMA, which keeps the system-wide policy defaults — with `ScheduledJobStepEntry` SCJOST, the job's ordered work steps, routed to the same part because a step is part of a job rather than a declaration of its own | `@CsJob` | COVERED |
| CE-LG | `auditLog` | `SecurityEventsDefinition` SEEVDE with its five policy forms and `SecurityEventEntry` SEVT (the `AuditAndLogging` AUANLO root) · `SessionLifecycleMonitoring` · `DataAccessAuditPolicy` · `ApiSecurityMonitoring` (under `AccessControlModel`) — 11 sections, all projected | `@CsAudited` | COVERED |
| CE-NT | `notification` | `NotificationModel` NM → `NotificationChannelEntry` NTFCH · `NotificationTypeEntry` NTFTY · `UserNotificationPreferences` UNP | `@CsNotification` · `@CsNotificationChannel` | COVERED |
| CE-RP | `reporting` | `ReportEntry` REPENT · `ReportColumnEntry` REPCOL · `ReportChartEntry` REPCHA, under the `ReportDefinitions` REDF projection root | `@CsReport` · `@CsReportColumn` · `@CsReportChart` · `@CsReportParameter` | COVERED |
| CE-EN | `domainEnum` *(member kind — extract home, not a part)* | `DomainEnumEntry` DMENE + `DomainEnumValueEntry` DMEVA, under the `DomainEnumRegistry` DOMEN projection root; `ObjectStateEntry` OBST cites the registry rather than being a second home (§4.1) | `@CsEnum` | COVERED |
| CE-WF | `workflow` *(deferred)* | `DetailedProcessWorkflow` DEPRWO — unprojected, as a deferred part should be | — *(deferred: no marker, so no entry)* | N/A (deferred, §4.3) |

**Neutral-vocabulary check (§1.1 pillar (c)).** The check applies to sections
that *carry* `@CodeSpecKind` — not to D06 ATS, whose job is technology
selection. The four members where a technology name would most easily creep in
carry neutral names — `libraryVariant`, `baseComponent`,
`sharedLibraryIntegration` and `displayKind`; none of them names Flutter, a
widget or `tom_flutter_ui`. Three further hits on the check are **not** leaks: `DomainEnumEntry.enumName`
uses the glossary's own term for a closed value set, and the transport-status
fields on `ErrorCodeEntry` / `SystemErrorCodeEntry` name the one place §7 admits
a transport status (5xx transport errors). `InterfaceOperationEntry.httpMethod`
and `.path` are likewise not leaks: they describe a **foreign** contract, which
genuinely has a verb and a route, and the section carries `serverCall` only. The
application's own operations are declared in `ServerOperationEntry`, which
authors neither — §7 fixes the transport shape and the operation name is the
sole identifier. `ClientApplicationEntry.clientKind` is where the rule bites
hardest and holds: its arms are `graphicalApplication` / `commandLine` /
`server`, deliberately **not** `CsClientKind`'s `flutterApp` / `cli` / `server`.
The two map arm-for-arm (`codespecs_derivation_contract.md` §3.6.2); naming the
framework is the deeper CodeSpecs level, not the specification's job.

**Persistence discriminators (§11).** No settings section may carry a
local/roaming-style flag; scope is expressed by *which* of CE-CF / CE-CC / CE-DS
/ CE-UP is used. `LanguageCountrySelection.persistence` is the section most
exposed to that rule, and it authors **retention behaviour**
(`guestRetention`, `signInCarryOver`, `reselectionPrompt`) rather than a
persistence method or a sync flag. The
`overridableBy` member on `SCSET` / `CCSET` / `USSET` is **not** a discriminator
either — it is the §5.16 opt-in cross-scope shadowing declaration, authored on
the *wider* scope only, which is why `DSSET` (the narrowest scope) has none.

## 9. Bidirectional DocSpecs ↔ CodeSpecs linking

The link between a Phase-3 DocSpecs section (typed by the SOM) and the Phase-4
CodeSpec code is **bidirectional**: two resolutions on the doc side (§9.1 by
section *type*, §9.2 by section *instance*) and two annotations on the code side
(§9.3 — identity and back-trace).

### 9.1 General mapping — section *type* → CodeSpec *kind(s)* (SOM annotation)

`@CodeSpecKind` on a SOM section class states which **kind(s)** of CodeSpec that
section type must be realised as.

- **Canonical signature: `@CodeSpecKind(List<CodeSpecPart> kinds, {String? note})`.**
  The value is a **list** — a section or form field may map to **more than one
  kind** (e.g. a field that is both a `screenElement` and a `dataAccess` column, or
  a setting that is both `clientConfiguration` and `userSettings`). Each value is a
  `CodeSpecPart` from §4.1; `note` explains the influence. ("CodeSpecsMapping" is
  the descriptive alias for this concept; the annotation type is `@CodeSpecKind`.)
- This is the **general half of the forward link**: every section of a mapped type
  must produce each named CodeSpec kind.

### 9.2 Concrete forward mapping — section *instance* → code *location(s)*

A **`codeSpec` member on `DocSpecsSection`** records the actual CodeSpec code
location(s) a concrete section maps to.

- **Type:** `List<String>` — the `codeSpec` member of `DocSpecsSection`.
- **Serialization:** the section id lives in **square brackets inside the headline
  HTML comment**, `<!--[id]-->` (`som_multiplatform_spec_model.md` §11.2). The `codeSpec` list rides in
  that **same comment as one comma-separated, quoted `key=value` field** alongside
  the bracketed id (the tom_doc_scanner parser already extracts the bracketed id
  into `explicitId` and remaining `key=value` pairs into a generic `fields` map —
  no grammar change needed). Example:

  ```md
  ### <!--[IMO-014] codeSpec="CsOrder,CsOrder.total,CsOrderRepository"--> Order entity
  ```

- This is the **concrete half of the forward link**.

### 9.3 The code side — identity and back-trace (`@CodeSpec` + `@DocSpec`)

Generated code carries **two** annotations, and they answer different questions.
They are also placed differently: `@CodeSpec` on the top-level declaration only,
`@DocSpec` on every declaration — class or member — that came from a section of
its own. `codespecs_derivation_contract.md` §2.5 is the rule; the two paragraphs
below say what each carries.

- **`@CodeSpec('<id>', source: [<tokens>], requirements: [<ids>])`** — the
  element's **identity**: a stable CodeSpec id, the **flat set** of extract
  tokens that fed it, and the requirement ids it satisfies. Because `source` is
  a set, §8's gap analysis is a set-difference over tokens, computable without
  reading a single description.
- **`@DocSpec([DocRef(sectionId, description), …])`** — the **back-trace**: one
  tuple per contributing extract token, each saying what the code took from the
  values behind that token and how. `sectionId` is the **extract token** of
  `codespecs_derivation_contract.md` §2.5 rule 2 — the `@SectionId` of the SOM
  *field* the extract routed the value from, or the field's own name where it
  carries none (a narrative field yields `content`); the description states the
  *edge*, not the section.

The extract's `instanceId` (§1.1.1) does **not** change this vocabulary: a
`DocRef.sectionId` names the extract token, never a stored instance id. The
instance id is partial — present only where the document stores an id — and a
partial key cannot carry a set-difference; it stays auxiliary trace data on the
extract entry.

They are kept separate because a set is what a tool reads and a sentence is what
a human reads, and merging them would force the gap analysis to parse prose.
`@CodeSpec.source` must equal the set of `sectionId`s in the `@DocSpec` beside
it — the derivation contract makes that a validator check, since drift between
them is otherwise undetectable and silently corrupts the set-difference. Because
the declaration carrying `@CodeSpec` is the emission unit, its `@DocSpec` also
repeats its members' tokens, so `source` accounts for the whole unit and §8's
set-difference never has to look inside a class.

### 9.4 Why both directions

`@CodeSpecKind` (type) + the `codeSpec` field (instance) give **doc → code**;
`@CodeSpec` + `@DocSpec` give **code → doc**. With `@SectionId` as the shared
join key, traceability and gap analysis become set operations in both directions.

### 9.5 Annotation placement

| Symbol | Package | Why |
|--------|---------|-----|
| `@CodeSpecKind(List<CodeSpecPart>, {note})` (§9.1) | **`tom_specs_core`** | Annotates SOM *model* classes; sits with `@MapsTo`/`@DetailedIn`. The model never depends on the CodeSpecs framework. |
| `CodeSpecPart` enum (§4.1) | **`tom_specs_core`** | The shared kind vocabulary; zero-dependency. |
| `codeSpec` `List<String>` member (§9.2) | **`tom_specs_model`** | A member on `DocSpecsSection`; mutating the SOM triggers the 9-runtime regeneration cascade. |
| `@CodeSpec(id, {source, requirements})` (§9.3) | **`tom_code_specs`** | Annotates CodeSpecs *code*; the identity + flat source set. |
| `@DocSpec([DocRef…])` / `DocRef` (§9.3) | **`tom_code_specs`** | Annotates CodeSpecs *code*; the per-section back-trace. |
| `Cs*` annotation family (§4.1) | **`tom_code_specs`** | The framework — **annotations only, no base classes**. |
| `Cs*Ref` typed-reference family (§5.23) | **`tom_code_specs`** | Annotation *parameter* vocabulary for those markers — the same role `DocRef` plays for `@DocSpec`. |
| Concrete gap classes (`gap` in §4.1) | **`tom_core_codespecs`** | The concrete classes `tom_core` lacks — never abstract `Cs*` bases. |

`tom_code_specs` depends on `tom_specs_core` and re-exports `CodeSpecKind` +
`CodeSpecPart`, so a CodeSpecs author has a single import.

### 9.6 Self-sufficiency — the trio carries what it was derived from

The link §9.1–§9.5 describes is a **trace**, not a channel: it says which section
a declaration came from, not what that section said. On its own it would leave
every downstream reader one dereference away from the code — open the document,
find `IMO-014`, read what the code does not carry. The rule below closes that
gap, and it is a requirement of Phase 4 in the same sense the §4.4.4 readiness
gate is, not a quality aspiration attached to it.

**The rule.** When Phase 4 completes, the generated trio (§4.2) carries **every
specification fact its parts were routed from**. Phases 5 and 6 read the code;
they do not reopen the Phase-3 documents. A test derived in Phase 5 is derived
from a declaration, its annotations and its doc comments; an implementation
written in Phase 6 fills a body whose behaviour is already stated above and
inside it.

**Why it is a requirement and not a nicety.** Phase 5 and Phase 6 are the two
phases with the widest fan-out — many test cases and many implementations per
declaration — and they are the two most often run by a party who did not attend
Phase 3. If either has to consult the document, three things follow: the
specification acquires a second reading with no gate over it, the code and the
document can disagree with nothing detecting it, and a declaration whose
description never made it into the trio looks exactly like one whose section had
nothing more to say. Requiring the trio to be closed under its own inputs turns
all three into one checkable question asked once, at G4
(`tom_specs_project_flow.md` §PF-GAT-G4), rather than into three silent failures
discovered late.

**What carries what.** The rule is discharged by carriers that already exist —
it adds no new construct, it states which existing ones are *obliged* to be
complete.

| Kind of specification content | Carrier | Fixed by |
|---|---|---|
| **A structured fact** — an enumerable, a scalar, an id, a reference to another part | An **annotation argument** on the marker | §5.23's typed `Cs*Ref` family; `codespecs_derivation_contract.md` §2.3, §2.6 |
| **Prose saying what a thing is** — a description of an entity, an attribute, a client | A **doc comment** at P1 (declaration) or P2 (member), verbatim from the section's designated description field and its `content` | `codespecs_derivation_contract.md` §2.8 C1, C2, C4 |
| **Prose that becomes behaviour** — a step, a rule, a flow | A **P3 method doc comment**, plus the body: form 3a's `throw UnsupportedError('<explication>')` renders that same text as a string; form 3b's statements *are* the text, with narrative on the abstract collaborator's P3 comments | `codespecs_derivation_contract.md` §2.4, §3.0.1, §2.8 C2/C6 |
| **An authored artifact** — DDL, SQL, a diagram | The construct the part's entry names in its point 1 | `codespecs_derivation_contract.md` §3 |
| **Provenance** — which section, and what was taken from it | `@CodeSpec` (identity + flat source set) and `@DocSpec` (per-section edge) | §9.3 |

Two properties of that table are what make the rule bite rather than restate
good intentions. First, **P3's absence is a generation error**: a method whose
behaviour text is missing does not compile into a silently empty specification,
it stops the run. Second, **nothing on it is composed** — C1's prohibitions mean
each carrier holds the author's text or an author's value, so "carries the fact"
and "carries the fact *faithfully*" are the same claim.

**The bound: routed, not all.** The rule ranges over exactly the sections
`@CodeSpecKind` routes to a part. A section carrying `@FollowUpKind` or
`@NoArtifact` (§8.3) is outside it by construction — there is no part for it to
be carried by, and demanding otherwise would ask the trio to hold organisational
and migration content it has no shape for. This bound is decidable rather than
argued: `tom_specs_model_rules.md` §10.2 invariant `ROUTE-TOTAL` makes the three
verdicts a total partition of the SOM, so "everything routed" names a computable
set and its complement is enumerable too. The bound is scoped once more by the
pass itself: the gate record (§1.1.1's `gate.verdicts.yaml`,
`codespecs_prompt.md` §6.3) names the areas the run actually authored, and the
rule ranges over the sections routed to *those* — a descoped or not-applicable
area's routed facts are owed by the pass that ships it, not by this one.

**How the rule is decided.** Three comparisons, none of them a reading:

1. **Nothing routed is missing.** The set of routed extract tokens
   (`codespecs_derivation_contract.md` §2.5 rule 2), set-differenced against the
   union of `@CodeSpec.source` over the trio, is the set of routed values that
   reached no code. §8.5's per-part verdict is this operation at part
   granularity; the rule needs it at token granularity against one project.
   `codespecs_derivation_contract.md` §6 check 35 is exactly this difference,
   with the extract standing for the routed set; its converse — a back-link
   naming a token no area routed, which is a defect of the trace rather than of
   the transfer — is check 36.
2. **Nothing carried is invented.** Every comment and every verbatim argument
   occurs character-for-character in its source section — the identical test
   §1.1.1 item 1 places on the extract, applied to the second artifact produced
   from it. `codespecs_derivation_contract.md` §6 checks 32 and 34.
3. **Nothing routed is empty.** A declaration whose section had a description
   but carries no comment has lost it; a method with no behaviour text was never
   specified at all.

**Two of the three need the extract, and that is a property of the rule, not an
implementation choice.** A pass over the generated trio alone cannot separate a
complete transfer from a partial one, because nothing in the output states what
was supposed to be in it — the code is the answer, and comparisons 1 and 2 need
the question. The extract is that second side: it enumerates, bounded and
verbatim, exactly what a step was given, so both comparisons become set and
string operations over two files instead of a search through a document set.
Comparison 3 is the exception — it is **output-local**, decidable from the trio
alone, and `codespecs_derivation_contract.md` §6 already mechanises its
behaviour half (a form-3a body with an empty description, and a method of a
form-3a, form-3b or collaborator class with no doc comment, both fail
generation).

What §9.6 owns is the **requirement**; `codespecs_derivation_contract.md` §6
owns what a program decides about it. The division matters because a validator
can only check completeness against a rule that says the trio is supposed to be
complete — the checks are not self-justifying, and this is the statement they
answer to. It is also why two rows of §6's table cite a section of *this*
document rather than of the contract: checks 35 and 36 are the only two whose
rule is stated here.

## 10. Open work

Anything outstanding against this document is tracked as a **quest todo** of the
TomSpecs quest — `csrb` and `csre` for the
CodeSpecs follow-up series, `qr` for findings raised by a quest-refresh pass,
`qrc` for the work one of those findings opened, `tscomp`/`tscompc`/`tscompd`
for a completeness pass and its two generations of follow-ups, and `tspuba` for
the findings of the Phase-4 dogfood run. Each todo is self-contained, so this
section is an index rather than a specification.

The `cs*` ids of §1.1.1 item 3 are **not** in that set and never appear here:
they belong to a Phase-4 run against a specified project, not to the quest that
builds CodeSpecs. Pillar (d) keeps the two families apart precisely so this
index cannot be confused with a run's execution list.

Every part passes §4.4.4's readiness gate in all four modes: no emission is
blocked, none is lossy, no skeleton compiles into an application that cannot
run, and no named validator check is unable to run. Nothing here waits on a
`tom_core` capability, so no mapping-side position is stated against a plan
rather than against shipped source.

**§8.5** carries the standing per-part coverage verdict, and it records every
active part COVERED. Nothing is currently open against this document's mapping
surfaces.

An open todo in those series whose subject is **not** a mapping question does
not belong here even when the index is non-empty — a SOM validator capability
belongs to `tom_specs_model_rules.md` §10.2, an editor defect to
`tom_specs_editor_specification.md`. Such todos are tracked in the quest todo
file like the rest; they simply have no open work *against this document*.

## 11. Configuration & settings — the four-scope owner-key split

Configuration and settings are four parts — one part per scope key, each
single-moded (no persistence discriminator anywhere; the scope key alone decides
where a value lives):

| Part | Scope key | Persisted where | Declared in (`@SectionId`) | Example |
|------|-----------|-----------------|----------------------------|---------|
| **CE-CF** ServerConfiguration | server/system — no user, no machine | Server (deployment) | `SCSET` under `SYCOMA`, **plus the 41 fixed-name policy/layout bands** (§5.16) | DB connection, worker counts, feature flags (config toggles); TLS/key/audit-sink policy |
| **CE-CC** ClientConfiguration | (client app, machine) — no user | Client machine | `CCSET` under `CLICON` | API base URL, device options, per-install toggles |
| **CE-DS** DeviceSettings | (user, device) | The device, per signed-in user | `DSSET` under `DEVSET` | window layout, last-opened, machine-local cache preferences |
| **CE-UP** UserSettings | (user) | Server (per user) | `USSET` under `USRSET` | theme, language, notification prefs — restored on any device |

The four declaration lists are the mechanism that makes "no persistence
discriminator" true rather than merely intended: the scope is carried by *which
list a setting is declared in*, so there is nothing on a setting for an author to
set wrongly, and no shared section on which a `scope` column could grow (§5.16).
CE-CF's fixed-name bands do not weaken this: a band's scope is carried by the
band's own `@CodeSpecKind`, which is again a placement rather than a field, and
§5.16 fixes their `overridableBy` at `none` so no scope decision is authorable
there at all.

- **CE-CF is server configuration only** — it never carries user or client-machine
  settings.
- **CE-CC** is keyed by the (client app, machine) pair; two installs of the same
  client on two machines have independent CE-CC. No user identity in the key.
  The client half of the key is authored **on the setting** — `CCSET`'s `client`
  names a `CLIAPP.clientId` — not as a settings list on the client entry. A
  setting belongs to one client and a client to many settings, so putting the
  edge on the many-side leaves one authored source; a list on each side would be
  two that could disagree.
- **CE-DS** is keyed by **(user, device)**: user-specific settings of a
  user-owned device, persisted on the device and never leaving it. The
  discriminator against CE-CC is **user identity in the key** — a value that is
  the same for every user of an install is CE-CC; a value that differs per
  signed-in user on the same install is CE-DS. **Both halves of the key are
  implicit-by-storage**: the store lives on the device, and it lives at a
  location naming the signed-in account. Neither is a wire-level identity and
  neither is a parameter — `TomDevicePreferences` takes no principal, so an
  application on which more than one account can sign in separates them by giving
  the store a per-account location and installing a new store when the account
  changes (§5.16). Server-side enumeration of "user-owned devices" is not
  modeled. The corollary is worth stating because it is the failure mode: a
  shared install that gives every account one location gives them **one** set of
  settings, and nothing in the substrate detects it, because nothing in it is
  told a user changed.
- **CE-UP** is keyed by the **user**: server-persisted preferences that follow
  the user, re-materialised on any device the user signs into through the
  `tomUserPreferencesApi` round trip. Unlike CE-DS, **the framework supplies the
  user half of the key** — the server store binds the principal from the request
  zone, so no call site and no generated accessor names a user, and no address
  has to be rebuilt when the account changes. A CE-UP setting has a client-side
  shape (CE-UP in `<app>_codespec_client`, over `TomUserPreferencesClient`) and a
  server-side one (in `<app>_codespec_server`, over `TomUserPreferences`) so that
  server code can read a user's preference too — both generated from the **same**
  `USSET` declarations, so the two halves cannot drift. Neither half implements
  persistence: the store, its table and its endpoints are the framework's.

## 12. The `code_spec` architecture principles

CodeSpecs is part of the `tom_specs` quest; the following architecture principles
are integral to it:

- **Target architecture.** Auth server (credentials) + stateless API server
  (POST-only, §7) + relational SQL database + clients (Flutter / CLI / other
  server). Simpler variants (Flutter-only, server-only, CLI-only) are supported.
  NoSQL is a future consideration.
- **Multi-project separation** (§4.2): a shared contract, plus client and server
  implementation projects that depend on it. The compiler enforces that
  implementations satisfy the contract; a spec field-type change surfaces as
  compile errors at every implementation site that must update.
- **Three-layer UI** (CE-EL/CE-FM/CE-LO): business/semantic structure, widget
  behaviour (`@CsWidget` → concrete `tom_flutter_ui` widget), and layout are kept
  separate so layout can be manually overridden non-destructively.
- **Validation beyond the compiler.** In-code cross-part references are
  compiler-checked (§5.23), so analyzer-driven validators narrow to what the
  compiler cannot see: required annotations, valid parameters, the §5.23-exempt
  string surfaces (config source keys + env-var/cmdline aliases,
  deployment-environment names, migration artifact filenames, doc-side
  `codeSpec` locations + `@DocSpec` extract tokens), route uniqueness, and
  well-known-class usage.
- **Production stripping.** A cleanup tool comments spec-only code with the `//$`
  marker (reversible) before a production build, leaving implementation code intact.
- **Test generation from specs** (Phase 5 test derivation): contract / schema /
  repository / DTO / authorization / widget-contract tests are derivable from the
  CodeSpecs — they verify *implementation matches specification*, not that the
  specification matches requirements.
- **Reference implementations.** TomApi (`tom_uam_shared/endpoints.dart`) and the
  UAM persistence model (`tom_uam_server`) demonstrate the endpoint and
  entity/repository patterns CE-API and CE-DB generalise. **Legacy `Cs*`/`Ca*`
  code in these or elsewhere is not part of the framework and is removed**; useful
  annotations are salvaged by renaming to the `Cs*` prefix and moving them into
  `tom_code_specs`.

> The full per-`Cs*`-annotation derivation contract (SOM class/field →
> generated annotated Dart) lives in its own document,
> [codespecs_derivation_contract.md](codespecs_derivation_contract.md), which is
> **the authority for what code comes out**. This document is the derivation
> *map* — which SOM section feeds which part; that one is the derivation
> *contract* — the exact Dart Phase 4 emits, the deterministic naming
> rules, each annotation's argument shape, and the validator checks. Where the
> two appear to disagree about emitted code, the derivation contract wins.
