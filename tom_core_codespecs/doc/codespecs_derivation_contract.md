# CodeSpecs Derivation Contract

**Quest:** tom_specs · **Status:** normative for both Phase-4 roles — the
extract generator and the authoring agent

**Authority for: what code comes out.** `codespecs_mapping.md` §8 gives the
derivation *map* — which SOM section feeds which CodeSpecs part. This document
gives the derivation *contract*: for every active `Cs*` annotation, the exact
Dart that lands in the trio, argument by argument, name by name, file by file.

It is the last specification piece before Phase 4 can be run. Phase 4 has two
producers — `codespecs_mapping.md` §1.1 pillar (e) — and this document is
normative for **both**: it fixes what the authoring agent must write and what the
generation-time validator must accept. §2.0 says which of the two owns what.
Being unmechanised makes no clause here advisory; a derivation an agent performs
by hand is bound by exactly the text a program would have been. Where this
document decides something `codespecs_mapping.md` had left open, that document
cites this one rather than restating it.

**Scope.** One contract entry per active `Cs*` part marker — **39 markers** —
plus one for `@CsCollaborator` (§3.0.1), the one marker that is **not** a part:
it marks no realisation of a SOM section, it marks the abstract collaborator a
form-3b body calls. With the two facet value classes a marker carries
(`CsFileReference` on `CsColumn`, `CsGradedAccess` on `CsAuthorize`) that is
**40 markers and 42 classes** in `tom_code_specs`. Deferred parts
(`codespecs_mapping.md` §4.3) have no marker and therefore no entry.

**What this document decides.** It **decides** each annotation's argument shape.
The shapes below are **authored** in `tom_code_specs` — the constructors, the
`Cs*Ref` typed-reference family the arguments consume
(`lib/src/annotations/cross_part_refs.dart`) and the 16 closed catalogues they
select from (`lib/src/annotations/vocabulary.dart`) — so every annotation call
written to this contract compiles.

**Citing.** This document follows the doc set's citation convention
(`index.md` "How to cite these documents") without exception: `SOM §N` for
`som_multiplatform_spec_model.md`, file name plus section for every other
document — `codespecs_mapping.md §5.13`, `tom_specs_model_rules.md §6.1` — and a
bare `§N` for a section of this document. Being the heaviest self-citer in the
set, it says so here; the rule is general.

---

## 1. How to read a contract entry

Every entry answers the same seven points, in the same order.

| # | Point | Answers |
|---|-------|---------|
| **1** | **Input** | Which SOM class (and `@SectionId`) feeds generation, selected by `@CodeSpecKind`, and which of its fields/subsections are consumed. |
| **2** | **Output shape** | The exact Dart emitted: the declaration, its `tom_core`-family superclass or instantiated type (`codespecs_mapping.md` §1.1 pillar b — always named), its members, and the `Cs*` annotation with every argument filled. |
| **3** | **Argument derivation** | Per annotation argument: which SOM field supplies it and how it is transformed — verbatim, slugified, enum-mapped or defaulted. |
| **4** | **Naming** | How the Dart identifier derives from the SOM headline or id, on top of the universal rules of §2. |
| **5** | **Locus** | Which of the three §4.2 projects the file lands in. |
| **6** | **Cross-references** | Which outgoing reference edges the element emits, and which `Cs*Ref` type carries each. |
| **7** | **Back-link** | The `@DocSpec([DocRef(sectionId, description), …])` emitted on the element (`codespecs_mapping.md` §9.3). |

Entries are grouped by **generation slice** (`codespecs_mapping.md` §4.4.3), so
reading top to bottom is reading the order the trio is written in: nothing in an
entry references a part that has not already been emitted by an earlier entry.

---

## 2. Universal rules

These hold for every entry. An entry states only what it adds or overrides.

### 2.0 Who produces this code

`codespecs_mapping.md` §1.1, §1.1.1 split Phase-4 production between two parties
(pillar (e)) and fix the boundary between them. This contract uses their names
throughout, and they are not interchangeable:

| Role | Does | Bound by |
|------|------|----------|
| **The extract generator** | Collects, per CodeSpecs area, every SOM field the `@CodeSpecKind` routing sends there into a bounded, cited **extract** — copying and indexing, never summarising, rephrasing, composing or naming | `codespecs_mapping.md` §1.1.1; the same §2.8 C1 prohibitions this document already states |
| **The authoring agent** | Writes the CodeSpecs Dart from that extract — every declaration, name, argument, comment and body in §3 | This whole document |

**The extract generator emits no Dart.** Every "emits", "writes" and "fails" in
§2–§5 is the authoring agent's, and every judgement §3 leaves open is the
agent's to take. That is why this contract is written as tightly as it is: an
author is the one producer that *can* invent, so each rule below says not only
what to write but what may not be reached for instead.

**Three defined terms**, used with these meanings and no other:

- **Generation** — the act of producing the trio, whichever role performs the
  step. "Generation slice", "generation order" and "regeneration" are about the
  work, not the worker.
- **A generation error** — the derivation has no admissible output. The agent
  **must not write the declaration**; it files a `csopen<n>` `decision-needed`
  todo naming the section id, which pauses the queue (`codespecs_mapping.md`
  §1.1.1 item 3). The validator independently rejects any trio containing one, so
  the failure is caught whether or not the agent noticed it.
- **The generation-time validator** — `validate_codespecs.dart` and the §6
  checks. It is a program, and it is the only mechanised half of the authoring
  side: it reads what the agent wrote and rejects what this contract forbids.

**Determinism is therefore an obligation, not a mechanism.** §2.1's naming rules
are pure functions of SOM content and §2.8's comments are verbatim copies
precisely so that the output *is* determined even though a judging author
produces it. §6 check 31 is how a departure is detected rather than trusted: two
runs over one model must be byte-identical. An agent that improved a name has
broken the contract in the one way no compiler would notice.

**Neither role owns a body form.** §2.4's 3a and 3b are both written by the
agent — the extract generator reaches neither. The seam 3a marks is a different
one: it is where **the agent stops and Phase 6 continues**, because the SOM
carried prose and prose states no statements. 3b is the complementary case — an
ordered step list makes the body derivable, so the agent writes it out and the
seam moves down to the abstract collaborator's methods, which is where Phase 6
picks it up instead. Which of the two an entry uses is fixed by §2.4 as a
structural test on the input; it is never the agent's choice, and this is the
one place that is said.

### 2.1 Identifier derivation (deterministic naming)

The same spec must produce the same code in every session, on every machine.
That requires the name to be a **pure function of the SOM content** — no
counters, no clocks, no dictionaries, no state carried between elements.

**N1 — the source string.** Each entry names a **designated name field**: the
SOM field whose value names the thing (`DataEntityEntry.entityName`,
`InterfaceOperationEntry.operationName`, …). If the section type has no
designated name field, the source is the section's **headline text** — carried
on every extract entry as `headline` (`codespecs_mapping.md` §1.1.1): the
enclosing section instance's stored headline, else its `@Headline` type
default. The headline is the source *string*; the naming judgement stays N2/N3
over it, never a fallback to PascalCase of the section id. If both are absent
or empty, generation **fails** naming the section id — an unnamed section is a
spec defect, not a naming problem.

**N2 — tokenisation.** The source string becomes a token list:

1. Fold to ASCII: NFD-decompose, drop combining marks, map `ß` → `ss`.
2. Split on every run of characters that is neither a letter nor a digit.
3. Split each remaining run at a lower→upper boundary, and before the final
   upper of an upper-run followed by a lower (`HTTPServer` → `HTTP`, `Server`).
4. Digits stay attached to the token they follow (`address2` → `address2`).
5. Drop tokens that fold to empty.

**N3 — casing.** Each token is **lowercased in full, then its first character
uppercased**. No acronym dictionary: `ID` → `Id`, `HTTP` → `Http`. A dictionary
would be a hidden, mutable input and would break N-determinism the
first time someone edited it.

- **PascalCase** = the cased tokens concatenated.
- **camelCase** = PascalCase with its first character lowercased.
- **snake_case** = the lowercased tokens joined by `_` (used for file names only).

**N4 — collisions fail.** If two sections produce the same identifier in the same
locus project, generation **fails** naming both section ids. It never
auto-suffixes: a silent `Customer2` hides the spec defect that produced it, and
§4.4 already rejects the analogous shortcut for stubs.

**N5 — authored keys are verbatim.** Message keys, error codes, setting keys,
route ids, notification type ids and operation names are **authored strings**
taken **character-for-character** from the SOM. They are not derived and not
normalised — they are the `codespecs_mapping.md` §5.23 string-reference exemptions plus the operation
name (`codespecs_mapping.md` §5.14: the one required identifier). An absent authored key is a
generation error. The Dart *const* holding such a key is named by applying N2/N3
to the key itself: `order.shipped` → `orderShipped`.

**N6 — reserved words and leading digits.** If the identifier is a Dart reserved
word, the part's **canonical id** (§4.1, PascalCase) is appended:
`class` as an entity → `ClassDataAccess`. If it begins with a digit, `N` (Pascal)
or `n` (camel) is prefixed: `3dView` → `N3dView`.

**N7 — file layout.** One file per top-level CodeSpec declaration:

```
lib/src/<canonical id, snake_case>/<identifier, snake_case>.dart
```

so a `DataEntityEntry` named *Customer* lands at
`lib/src/data_access/customer.dart`. Member markers are emitted in their owner's
file. Catalogue holders (error codes, message keys, roles, resource keys,
operation refs) get exactly one file per catalogue,
`lib/src/<canonical>/<canonical>_catalog.dart` — and **route definitions share
that rule**: though each `@CsRoute` is a top-level declaration rather than a
holder member (§3.5.8), all of a document's routes land together in
`lib/src/navigation/navigation_catalog.dart`, which is the one sanctioned
several-declarations-per-file case. Each project exports its files
from `lib/<project>.dart` in the same order §2.2 emits them.

**N8 — member order.** Members are emitted in **SOM document order** — the order
the contributing sections appear in the document, depth-first. A regeneration
over an unchanged spec is byte-identical; a diff therefore means the spec moved.

**N9 — reference const strings.** A `Cs*Ref` const's string argument is the
**camelCase declaration name of its target** (N2/N3 over the target's designated
name field), with two exceptions. Where the target is identified by an authored
key (N5) it is that key verbatim. Where the target is a **member** of another
declaration rather than a declaration in its own right, it is the dotted
`<owner>.<member>` path — the qualifiable `CsElementRef` of §2.6 is the one ref
in the family that has such targets, and `CsElementRef.path` composes it. A
generation-time validator resolves every ref string to a declaration; an
unresolved ref is a generation error, never a warning.

**N10 — derived setting keys.** N5 governs keys the *author* invents. A setting
whose identity is owned by the **model** instead — §3.3.6's fixed shape, where
the SOM names the setting and the author supplies only its value — has no
authored key, so its key is **derived**:

```
<band>.<field>                     fixed band
<band>.<entryName>.<field>         repeating fixed band
```

`<band>` is camelCase of the contributing section's class name with a trailing
`Policy`, `Settings`, `Selection` or `Entry` dropped (`LogRetentionPolicy` →
`logRetention`, `EncryptedDataCategoryEntry` → `encryptedDataCategory`);
`<field>` is the form field's name; `<entryName>` is N2/N3 over the repeating
entry's required name field. Exactly **one** segment comes from the band and
never its ancestor chain — a deployment key must not change because a section
moved in the document tree, and the band's class name is already globally unique.
Derived and authored keys share one namespace and one collision rule (N4). The
suffix drop makes the reduction non-injective (`LogRetentionPolicy` and a
hypothetical `LogRetentionSettings` reduce alike), and an `SCSET` author writes
free strings with no view of what the bands derived — so the generated trio is
the first place both key sets are visible, and **§6 check 20** is where the
collision is caught. Like N4's identifier rule it never auto-suffixes: a
deployment key is a contract with the operator, and silently renaming one
abandons whatever value was set against it.

### 2.2 Locus assignment

Locus is not per-entry judgement — it is read off `codespecs_mapping.md` §4.2 by
part, and an entry's point 5 cites it rather than re-deciding it. Three parts
span two projects (CE-UP shape/persistence, CE-ID declaration/population, CE-AU
wire types/client flow/server flow); each has one entry per locus half, and the
entry says which half it is.

The **shared → {client, server}** dependency arrow is absolute. An agent that
would have to emit a client-project reference from a shared file has hit a spec
defect; it fails naming the offending section rather than relaxing the arrow.

### 2.3 What becomes an annotation argument

The one rule that shapes all 40 constructors:

> A spec-authorable attribute becomes a **constructor argument of the `Cs*`
> annotation if and only if the generated Dart cannot already carry it.**

Applied as three tests, in order — the first that matches wins:

**(a) Carried by the declaration.** The Dart declaration itself already states
it: a column's value type, a form's field list, a view model's fields, a
repository's entity and key type, a service unit's methods, a validation
function's signature. Not an argument. Duplicating it would create two sources
that can disagree.

**(b) Carried by a substrate constructor.** The CodeSpec instantiates or extends
a `tom_core`-family class whose constructor already takes it —
`TomNotificationType(typeId:, urgency:, defaultChannelIds:)`,
`TomReportColumn(...)`, `TomActionTrigger(guard:)`, `@TomAudited(enabled:,
redact:)`. Not an argument; the marker only says *which part*
this is. This is pillar (b) doing its job: reuse means the substrate holds the
data.

**(c) Otherwise — an annotation argument.** What is left is exactly `codespecs_mapping.md` §4.1.1's
"beyond what simple code can express": element kinds, maximum lengths, format
restrictions, placement, schedules, grades, physical table and column names,
setting keys, operation names, closed-catalogue selections.

Three shaping rules on top:

- **Required vs. defaulted.** An argument is `required` iff omitting it cannot be
  given a **fail-safe** default (`codespecs_mapping.md` §5.16's rule: broadening a value's blast radius
  must be a deliberate authored act). Nineteen arguments across fifteen markers
  are required on that ground, in three groups: the **kind selectors**, where
  every arm is a different part and none is safer than the others
  (`CsElement.kind`, `CsTrigger.kind`, `CsClient.kind`, `CsMigration.kind`,
  `CsJob.trigger`, `CsAuthorize.requirement`, `CsIdentityAttribute.placement`);
  the three **scope openings** `overridableBy` (`CsServerConfig`,
  `CsClientConfig`, `CsUserSetting`), where the fail-safe value `none` is
  deliberately *not* a default so that widening a setting's scope is authored;
  and the **unshadowable payloads and keys**, which no substrate holds
  (`CsText.baseCopy`, `CsFieldRule.errorKey`, `CsFormRule.errorKey`,
  `CsTrigger.action`, `CsServiceUnit.rootAggregate` + `boundedContext`,
  `CsMigration.datasource` + `schema`, `CsNotification.body`). Everything else
  defaults to its safest arm.
- **`String? note` is last, always.** Every marker keeps the optional
  part-specific note it has today, as its final parameter.
- **First positional = the authored identifier.** Where a part has an authored
  external identifier (§2.1 N5), it is the annotation's **first positional
  required** argument: `@CsEndpoint('customer.save')`, `@CsTable('customer')`.
  Everything else is named.

**Closed catalogues are mirrored enums.** `tom_code_specs` is annotations-only
and does **not** depend on `tom_core` (`codespecs_mapping.md` §9.5). So a closed catalogue a marker
selects from is declared **in `tom_code_specs`**, mirroring its `tom_core`
counterpart one-for-one where one exists. A named validator check asserts each
such mirror is complete; a `tom_core` catalogue that grows without its mirror
growing is a build failure, not a silent divergence. No catalogue currently has
a declared `tom_core` counterpart — every row of the §5.3 table mirrors a
*document section* — so the check has an empty pair table and stands ready
rather than firing.

**Per-kind argument slots.** Three markers select a kind and then carry that
kind's own attributes: `CsTrigger` (its five `CsTriggerKind` arms), `CsAuthorize`
(its ten `CsAuthRequirement` arms) and `CsJob` (its three `CsJobTrigger` arms —
`cron` / `calendar` / `event`). Dart annotations have no sum types,
so each kind's attributes are **separate optional arguments**, and a validator
asserts that only the slots belonging to the declared kind are non-null. This is
the annotation-level rendering of `codespecs_mapping.md` §8.2's `@OneOf`/`@Case` closed-choice design.

### 2.4 Bodies — skeletal, not executable

Phase 4 output **compiles and does not execute**. Per `codespecs_mapping.md`
§4.1.1's coding-form spectrum:

- **Forms 1 and 2** (framework subclass/instantiation, plain annotated model
  class) emit **no bodies at all**. Fields are declarations; a non-nullable
  field with no authored default is **`late`**, and where reflection writes it,
  **`late` and never `late final`**.

  The distinction is who assigns the member. A **reflection-written** member —
  a wire DTO member filled by the kernel's `setValues`, a CE-DB column filled by
  the repository's `invokeSetter` — is written from outside by name, and that
  needs a setter, which a `final` field, `late final` included, does not have.
  The kernel does not paper over it either: a payload key naming a `final`
  member raises `reflection.set.unexpected_condition_final_static_private`, and
  a class whose wire members are *all* `final` is refused outbound with
  `reflector.type.all_final`. `late` alone keeps everything `late final` was
  wanted for — it compiles, and it throws if anything reads the field before
  Phase 6 fills it in — while leaving the field assignable, which is the whole
  point of emitting it. Emitting such a member `final` is therefore not a style
  choice the derivation may make.

  A **self-assigned** member is outside the rule, because nothing reflective
  writes it: it is bound once, by the declaration itself or by Phase 6, and
  reflection only ever *reads* it. That covers a **`static`** member of a
  catalogue or configuration holder (§3.1.2, §3.1.3, §3.6.1 — read through its
  resource provider, never through a field walk), §3.0.1's **collaborator
  seam**, which Phase 6 binds by hand, and a **holder member the declaration
  populates in its own declaring method** — a CE-CC `TomSetting` assigned in
  `declareSettings()`, a CE-FM field member assigned where the form declares its
  fields. Those keep `late final`: the field reference is bound once and the
  mutable state lives inside the object it points at.
- **Form 3** (compilable pseudo-code) emits a body. It has **two shapes**,
  **3a** and **3b**, defined below; every §3 entry that emits a body names which
  one it uses.
- **Form 4** (annotation-only modifier) emits no declaration of its own.

`UnsupportedError` — not `UnimplementedError` — is the thrown type throughout.
The Phase-4 artifact is a specification, and *executing* it is not an operation
it supports; `UnimplementedError` would read as a body someone forgot to write
rather than one that is deliberately not there yet.

Both shapes are written by the authoring agent; what separates them is where
Phase 6 picks the work up, not who produced them. §2.0 says that once and this
section does not restate it.

#### Form 3a — declared, not implemented

The entire body of the method is:

```dart
throw UnsupportedError('<explication>');
```

`<explication>` is the contributing SOM section's description text,
whitespace-collapsed to one line with `'` and `$` escaped. It is the **same
text** the method's doc comment carries, in its one-line rendering (§2.8 P3).
**An empty description is a generation error** — a body with no explication is
an empty spec, and emitting one would let a hollow method pass as a specified
one.

#### Form 3b — pseudo-implementation

3b is the form `codespecs_mapping.md` §3 describes when it grants CodeSpecs a
"first level of implementation": real Dart method bodies expressing the intended
behaviour, calling into an **abstract collaborator** whose methods are
implemented in Phase 6. Its body is a statement sequence, not a throw.

**Which form an entry uses is structural, not a judgement call.** An entry emits
3b when the SOM section its point 1 names carries an **ordered step list** (or
another structured behaviour surface the entry names explicitly); it emits 3a
otherwise. Prose alone — a `purpose`, a `description` — is never enough to
derive statements from, so a prose-only input is always 3a.

**Fallback.** An entry that names 3b emits 3a instead when its step source is
empty for the instance being generated: there are no statements to derive, so
the description carries the specification. An empty step source *and* an empty
description remains the generation error above.

**The fallback is per body, not per declaration.** Where an entry emits several
bodies from several step sources — §3.5.7's three, each reading the steps its
role routes to it — each body takes the fallback on its own source. A declaration
may therefore emit some bodies in 3b and others in 3a, which is what keeps a
step-list addition strictly additive: an instance that states no steps for a body
keeps exactly the 3a body it had.

**Permitted statements.** A 3b body admits exactly five kinds of statement, and
nothing else:

1. A **call on the abstract collaborator** the entry names.
2. A **call on the `tom_core`-family substrate the entry's own point 2 names** —
   `TomQueryBuilder` for §3.3.4. Never an unnamed framework class: if point 2
   does not name it, the body may not call it.
3. A `final` **local binding** of (1)'s or (2)'s result, named per N1–N3 over the
   step's **headline** — a step section carries no name field (§3.0.1 point 4).
4. **Control flow** — `if` / `for` / `switch` — derived from a condition the spec
   states. A condition the spec does not state may not be invented.
5. A **`return`** of a value produced by (1)–(3).

Excluded, therefore: a literal used as a value, arithmetic, string building, a
`try`/`catch` the spec does not state, and in-body comments (§2.8 C6 rules those
out and says where the narrative goes instead — on the collaborator method's
doc comment).

**Why 3b still does not execute.** A 3b body contains nothing of its own — only
calls and the control flow between them — so it cannot succeed by itself. Where
the calls go to the abstract collaborator, they have no Phase-4 binding: the body
type-checks, so the project compiles, and the first attempt to run it fails on
the unbound collaborator.

The **substrate-only** case is the exception that proves the shape rather than
breaking it. §3.3.4's query bodies call `TomQueryBuilder` and no collaborator, so
they do run — but all they do is build the declarative query object the spec
states, which is the whole of what the CodeSpec has to say about that query. No
behaviour is being executed that Phase 6 was going to author. Where an entry
permits a substrate call under statement kind 2, its point 2 must name a
substrate for which that holds.

**The collaborator is emitted, not assumed.** A 3b body may only call methods
that exist in the emitted trio, so where an entry names a collaborator it is part
of what the agent writes — an abstract class whose methods carry the behaviour narrative
on their doc comments (§2.8 P3) and no implementation. A 3b body that calls a
class the agent did not write is a generation error, not a forward
declaration. **§3.0.1 is its contract entry** — one collaborator per emitting
top-level declaration, its methods derived from that declaration's step list, and
the field its call sites resolve against. `codespecs_mapping.md` §4.4's
no-forward-reference rule applies to it exactly as to any other emitted
declaration, and §3.0 says how it is satisfied.

#### Behaviour-to-body derivation — steps to statements

3b says what a body **may** contain. This says what it **does** contain: the
input is an ordered list of SOM step sections, the output is the statement
sequence, and the mapping between them is structural throughout. Eight rules,
and nothing else — an agent that finds it needs a ninth has hit a gap in the
model, and the gap is filed against the model rather than closed by a heuristic.

**B1 — order is document order.** The statements follow the step list in **N8
document order**. A step section's own order field is **never read**:
`ALST.stepNumber`, `EXTST.stepNumber` and `LGFLS.stepOrder` are `String` (`3a1`
is a legal value), so ordering by them is a parse of authored text;
`MNSST.stepNumber` and `SCNST.stepNumber` are `int`, but they restate what the
list position already encodes, and where the two disagree there is no defensible
winner. The list is the order.

**B2 — one contributing step, one statement.** A step that supplies behaviour
text (§3.0.1 point 1) emits exactly one statement: a call on the collaborator
method that step contributes. A step that supplies none emits nothing. No step
ever emits two — a second statement needs a second method, and §3.0.1 point 4
derives a method name from the step's one headline, so there is no second name
to give it. The fields that **qualify** a step rather than adding to it are for
that reason not statement sources: `MNSST.dataInvolved`, `businessRuleApplied`,
`validationPerformed` and `uiElementUsed`, `SCNST`'s `SSEC` block, and
`ALST.expectedResult`.

**B3 — the last statement carries the result.** Every earlier step emits
`await collaborator.<m>(<the calling body's own parameters, by name>);`. The
**last** contributing step emits `return collaborator.<m>(…);` where the calling
body returns a value and `await collaborator.<m>(…);` where it returns `void` /
`Future<void>` — §3.0.1 point 2's return-type rule, seen from the call site. No
`final` local binding is emitted by this derivation: a collaborator method takes
the caller's parameters verbatim, so no step consumes another step's result, and
a binding nothing reads would be a use the agent invented. §2.4's statement
kind 3 stays available to entries that name a substrate whose calls do
compose — §3.3.4's query composition is the only one today.

**B4 — a stated condition becomes a guard method, never a parsed expression.**
The SOM states a branch condition as text: `EXTEN.condition`,
`AlternativeFlowEntry.triggerCondition`, `LGFLS`'s
`LFSEB.conditionalTrigger`, and `SCJOST.condition`. That text is **never parsed**. It becomes an
abstract **guard method** on the same collaborator, returning `bool` — or
`Future<bool>` where the calling body is asynchronous — carrying the stated
condition verbatim as its §2.8 P3 doc comment, so the branch reads

```dart
if (await collaborator.saveCustomerCustomerIsOnCreditHoldApplies()) {
  // the statements the condition governs
}
```

That is §2.4 statement kind 4 exactly: the condition is one the spec states,
reached through the same Phase-6 seam as every other statement, neither parsed
nor invented. Invariant 2 holds because the `bool` came out of a collaborator
call rather than out of a literal, and invariant 4 holds because reaching the
guard is already reaching an unimplemented method.

**Guard naming** extends §3.0.1 point 4 by one fixed token: camelCase of the
**calling body's identifier**, then PascalCase of the **condition owner's**
headline, then `Applies` — `saveCustomerCustomerIsOnCreditHoldApplies`. The
owner is the *flow* entry for `EXTEN` / `ALFL`, whose condition governs the whole
block its steps fill, and the *step* for `LGFLS` and `SCJOST`, where the
condition sits on the step itself. `Applies` comes from this contract rather than from spec text, so it
is identical for every instance, and it is what keeps a guard from colliding with
the behaviour method of the same headline. **A branch whose condition text is
empty fails generation**, naming the flow's section id: §2.8 C2 P3 is fatal when
absent, and an undocumented guard is a branch the agent would be inventing.

**Conditionality is read off the condition field and nothing else.** For the two
*flow* entries an empty condition is the fatal case just described — an `EXTEN`
or `ALFL` exists in order to be taken conditionally, so a flow that states no
condition states nothing. For the two *step* entries it is the ordinary case:
`LGFLS` and `SCJOST` steps are unconditional by default, and an empty
`LFSEB.conditionalTrigger` / `condition` simply emits no guard, which is what an
unconditional step means. No second field participates in either direction, and
none exists to.

The split between the two pairs is a model decision, not an accident of which
sections happened to get a condition field. The four **interaction** step
entries — `MNSST`, `SCNST`, `ALST`, `EXTST` — carry no condition of their own,
because the branch *flow* beside them already states one: an `EXTEN` / `ALFL`
names the step it diverges at (B5) and carries the condition that governs the
divergence, so a branch is stated in exactly one place and a reader never has to
reconcile two. `LGFLS` and `SCJOST` have no such flow — a logic block and a job
body are step sequences with nothing beside them — which is precisely why the
condition sits on their steps. Giving an interaction step a condition field too
would restate the branch a flow already owns, in free text, on the wrong entity;
where an interaction step really is conditional, the structure that says so is an
`EXTEN` / `ALFL` naming it.

A step is skippable *because* it is conditional, so a `Yes | No`
skippability flag beside the condition would be a second source for one fact —
§2.3's first test — and it would have exactly one authorable disagreement:
*skippable, condition empty*. That combination asserts the step is sometimes
skipped while giving this rule nothing to emit, so the step would be generated
**unconditionally**, the opposite of what the specification claims, and silently,
because an absent condition is not a missing value a checker can report. One
field cannot say that.

**B5 — a branch is emitted at the step it branches from.** `EXTEN.branchPoint`
and `ALFL.branchPoint` are **section-id references** — `MNSST.@sectionId` and
`SCNST.@sectionId` respectively — so the step a branch attaches to is *resolved*,
never matched: the extract already holds every step section by id, and the
reference either names one of them or fails the `tom_specs_model_rules.md` §10.2
invariant `REFERS-TO` before any code is emitted. The block is emitted **immediately before** the statement that
step contributes, because the branch is taken *instead of* that step and
everything after it.

Placement is therefore fully determined and needs no tie-break of its own:
several branches naming the same step keep the branch list's N8 order among
themselves, and a branch naming a step that contributes no statement — B2's
actor-only step — is emitted at the position that step would have occupied, so
the emitted order still follows the step list. A `LGFLS` or `SCJOST` step's own
condition raises no placement question at all: the step is wrapped where it
stands. `SCJOST` has no branch *flow*, only per-step conditions, so B5 and B6 do
not arise for a job body — every statement it emits sits in the one sequence.

**B6 — a branch block holds its own flow's steps and then states where control
goes.** The steps come from B1–B3. What follows them is `returnKind`, the
`FlowReturnPoint` closed choice, and it decides the block's last statement:

- **`endFlow`** — the branch is the end of the scenario, so the block ends
  `return;` where the calling body returns `void` / `Future<void>`, and
  `return collaborator.<last>(…);` where it returns a value, the last
  contributing step's call supplying it exactly as in B3. Control does not fall
  through into the main steps the branch replaced, which is what the spec says
  and what the old free-text field could not.
- **`resumeAtStep`** — control rejoins the main sequence at the step
  `EXTEN-RESU.resumeStep` / `ALFL-RESU.resumeStep` names, itself a resolved
  section-id reference. Where that step is the branch's own successor — the
  ordinary case, and the one a Cockburn extension usually states — the block
  simply ends and control falls through, so nothing is emitted for it. Where it
  names an **earlier** step, the resumption is a backward transfer the emitted
  body cannot express without a loop B7 forbids: that is a generation error
  naming both section ids, not a silently dropped statement.

`outcome` stays unemitted. It is prose describing the end state, not a control
transfer, and `returnKind` carries the control transfer, so the two are never
conflated.

**B7 — no repetition and no multi-way choice.** `for` and `switch`, which §2.4
statement kind 4 permits, are not produced by this derivation: no step section
states a repetition or a multi-way selection, and deriving one from a sentence is
the interpretation this section exists to prevent. They stay available to any
entry that names a structured surface stating one.

**B8 — prose is 3a, and a missing structure is a model change.** A behaviour
source that is a single prose field — §3.4.2's `SVOPE.purpose`, §3.7.1's
`SCJOB-WORK.workSummary` where a job lists no steps — is not an ordered step
list, so §2.4's selector puts it
in 3a and none of B1–B7 applies. Where the derivation *needs* a structure the SOM
does not carry, the honest outcome is a field on the model, never a heuristic
here. **`SCJOST` is what that outcome looks like**, and so are `branchPoint`,
`returnKind`, `SVCST.role` and the step's `serverOperation`. A job's work was
prose only, and the sentence
"what the job does, step by step" was an instruction to the author that the model
gave nowhere to obey; a branch's two attachment points were free text in which a
step reference and the word `"end"` were the same `String`; a server call's three
handling roles had one sentence between them and no field saying which of the
three it stated, so all three bodies could only throw the same text; and the
operation a call targets had no citation at all, so §3.5.7's **required**
`operation` could only be matched against the SVOPR registry by reading how a
step's `systemResponse` happened to be worded — two steps naming one operation
differently resolved to two operations or none. In each case
the resolution was to give the model the structure — a step list, a section-id
reference, a closed choice, a role discriminator, a registry citation — not to
teach this derivation to read sentences. B4 is the one case that resolves without one, and only
because a stated condition already has somewhere to go: a documented seam is
precisely what Phase 6 implements.

#### Frames

An entry may state that a body is emitted inside a **frame** — a call on a named
`tom_core`-family substrate that establishes an ambient scope around whatever the
body turns out to be. §3.7.1's unconditional
`TomTransactionManager.runInTransactionScope` wrap is the one such case today.

A frame is **not** a statement of either form. It comes from the entry, not from
the spec text; it is identical for every instance the entry generates; and it
neither produces nor consumes a value. So a framed body keeps its own form: a
framed 3a body is still 3a — the `throw` is still the whole of what the body
*says*, and it still propagates out through the frame — and a framed 3b body is
still 3b, its statements unchanged and merely enclosed. §3.7.1's job body is
emitted in both forms under the same frame, which is what makes the point
concrete: the frame is fixed by the entry while the form follows the instance's
step list. A frame that an entry's point 2 does not name may not be emitted.

#### Invariants

Four invariants make "compiles but does not execute" checkable rather than
aspirational. They hold for both shapes unless stated:

1. **Real signatures.** Return types, parameter types and generics are the
   specified ones. Nothing is `dynamic` because the agent did not know.
2. **No fabricated values.** No value in a body is one the agent invented —
   no `null`, no `''`, no `const []`, no literal standing in for a result. A 3a
   body's only exit is the `throw`; a 3b body may `return`, but only a value
   that came out of a collaborator or substrate call. The test is *could this
   value have been made up?*, not *does the body return?*.
3. **Async is declared, not faked.** An asynchronous operation declares
   `Future<T>` / `Stream<T>`. A 3a body still throws; a 3b body `await`s its
   collaborator calls. Neither is ever `async` with a synthetic completed
   future.
4. **Nothing runs to a specified result.** A 3a body throws on entry. A 3b body
   over an abstract collaborator reaches an unimplemented method before it can
   complete. The one 3b body that has no collaborator — §3.3.4's query
   composition — is complete by construction, because the whole of what it does
   is compose a declarative query object out of stated predicates; producing that
   object *is* the specification, and the framework repository it sits on runs
   it. No generated body invents behaviour a Phase-6 author would otherwise have
   written.

CE-ST observable fields are the sole exception to (1)–(2)'s "no initialiser"
reading: `final TomString name = TomString('');` *is* the declaration — the
observable's identity is what the spec states, and an uninitialised observable
would not compile at its use sites.

### 2.5 Back-links — `@DocSpec` and `@CodeSpec`

Two code-side annotations carry the back-link. They are not redundant; they
answer different questions, and they are **carried by different things**:

| Annotation | Carried by | Carries | Used for |
|------------|-----------|---------|----------|
| `@CodeSpec('<canonical id>.<identifier>', source: [<extract tokens>])` | the **emission unit** — the top-level declaration, never a member | The unit's stable CodeSpec id and the **flat set** of extract tokens that fed it | `codespecs_mapping.md` §8's gap analysis as a set-difference over extract tokens |
| `@DocSpec([DocRef('<sectionId>', '<description>'), …])` | **every** declaration that consumed a value of its own — the class *and* each such member | One tuple **per contributing extract token**, explaining what the code took from it | `codespecs_mapping.md` §9.3's reverse link, read by a human |

The asymmetry is the point. The gap analysis asks *"which routed values reached
the generated code?"*, and its unit of accounting is the emission unit — so
`source` is written once, where the unit is named. The reverse link asks *"why
does this line look like this?"*, and its unit is the declaration a reader has
in front of them — so a member states its own tokens next to itself.

**Emission rules.**

1. One `DocRef` per contributing **extract token**, in the order the tokens
   were first consumed (which is N8's order). Two values sharing one token
   contribute one `DocRef`, not two — the token is the unit of accounting, and
   the description widens to cover both edges.
2. `sectionId` is the **extract token** of the consumed value, verbatim: the
   `@SectionId` of the SOM *field* the extract routed the value from
   (`DAENT-IDEN`, `DAATT-DTFR`), or the field's own name where it carries none —
   which for a section's narrative field, and for any form riding it, is the
   token `content`. This is one vocabulary with three carriers — the extract
   keys its entries by it, `source` lists it, `DocRef` names it — so checks 35
   and 36 compare sets over the same alphabet. A section class's own id appears
   only where a routed field itself carries it, and a document instance id (the
   `<!--[…]-->` headline id) never appears in a back-link: instance ids live in
   the document and in its `codeSpec` forward link. The token is deliberately
   coarser than an instance id — every section's narrative field yields the
   same `content` — and the per-edge description is what keeps two same-token
   edges legible.
3. `description` is one sentence stating *what the code takes from the values
   behind that token*, generated from the per-entry template in each entry's
   point 7. It describes the **edge**, not the section — "supplies the operation
   name and request type", not "the interface operation entry".
4. **`@CodeSpec.source` must equal the set of `sectionId`s in the `@DocSpec` on
   the same declaration.** A named validator check enforces it; drift between the
   two is otherwise undetectable and would silently corrupt the set-difference
   gap analysis.
5. **The emission unit's `@DocSpec` enumerates every token the unit consumed,
   its members' included.** A member's own tokens therefore appear twice — once
   on the member, once on the unit — and rules 4 and 5 together make the unit's
   `source` the *union* across the class and its members. That union is a
   **consequence** of these two rules, not a third rule: everywhere else this
   document mentions it, it cites here.
6. A declaration that adds no token of its own (a derived back-reference, a
   materialised ownership list) carries neither annotation — it is covered by its
   owner's.

Restated as the three things the validator checks: `@CodeSpec` appears on the
emission unit and nowhere below it; an emission unit carries both annotations or
neither; and where both appear, their token sets are equal.

### 2.6 Cross-references — which type carries which edge

Reference edges use the typed `Cs*Ref` family of `codespecs_mapping.md` §5.23 —
never id strings. The thirteen types and their edges:

| Ref type | Points at | Declared in |
|----------|-----------|-------------|
| `CsOperationRef` | a CE-API operation | shared |
| `CsMessageKey` | a CE-TX message key | shared |
| `CsErrorCode` | a CE-ER error code | shared |
| `CsRoleRef` | a CE-AZ role | shared |
| `CsResourceKeyRef` | a CE-AZ resource key | shared |
| `CsCallRef` | a CE-SC server call | client |
| `CsActionRef` | a CE-AC action | client |
| `CsRouteRef` | a CE-NV route | client |
| `CsElementRef` | a CE-EL screen element | client |
| `CsFormRef` | a CE-FM form | client |
| `CsServiceUnitRef` | a CE-SU unit | server |
| `CsReportRef` | a CE-RP report | server |
| `CsJobRef` | a CE-JB job | server |

**Entities and request/response DTOs are already Dart types** — they are
referenced by `Type` literal (`rootAggregate: Customer`), with no ref const, per
`codespecs_mapping.md` §5.23.

**`CsElementRef` is the one qualifiable ref.** CE-EL's closed catalogue has both
standalone kinds (*Button*, *MenuEntry*, *Label*, *FormHost*), which are
class-level targets, and form-member kinds (*TextInput*, *Number*, *Toggle*,
*DateInput*, *Choice*, *MultiChoice*, *FileInput*), which are members of the
`@CsForm` class.
One type covers both, carrying an optional `form` qualifier, because §5.1's
`@CsTrigger` takes a `CsElementRef` in **both** its element and its form-field
slot — two types could not fill one parameter. Its N9 const-string form is the
bare declaration name when standalone and the dotted `<form>.<element>` path
when it is a form member.

Declaration pattern for every ref const, unchanged from `codespecs_mapping.md` §5.23:

```dart
static const login = CsOperationRef('login');
```

### 2.7 What a generated file looks like

Every emitted file has the same five-part shape, in this order:

1. A generated-file banner — three `//` lines naming the phase that produced the
   file, the source document and the spec-model version, and **no timestamp** (a timestamp would
   defeat N8's byte-identical regeneration). This is the **only** `//` comment in
   the file; §2.8 C6 rules out every other one.
2. Imports: `package:tom_code_specs/tom_code_specs.dart`, the `tom_core`-family
   packages the declarations are built on, and — in client/server projects only —
   `<app>_codespec_shared`. **Each import beyond the first must be used**: a file
   imports exactly the packages whose symbols its declarations reference, never
   its locus's habitual set — an unused import is dead weight the analyzer flags,
   and a server file whose declaration is pure `tom_core_kernel` imports no
   `tom_core_server`.
3. The declaration's **doc comment** (§2.8 P1), derived from the contributing
   SOM section.
4. The declaration, annotated `@CodeSpec` then `@DocSpec` then its `Cs*` marker,
   in that order (`codespecs_mapping.md` §9.5's placement, outermost-provenance-first) — its members
   each preceded by their own doc comment (§2.8 P2) and its methods by theirs
   (§2.8 P3).
5. Nothing else. One top-level declaration per file (N7) — parts 3–4 repeating
   per declaration in the two catalogue-file cases N7 sanctions.

**No file carries a `library;` directive.** A library-level doc comment would be
a second rendering of the same SOM text the file's declarations already
carry — N7 puts exactly one top-level declaration in a file (and in the
catalogue-file cases, one catalogue), so there is never
a second thing for a library comment to describe, and two comments from one
source is §2.3 test (a) applied to prose.

### 2.8 Comments — which SOM text becomes which comment

A specification reaches code three ways: as **constructs** (each entry's point
2), as **annotation arguments** (§2.3), and as **comments**. The third is as much
a derivation as the other two. A comment the agent composes for itself is prose
no author of the specification wrote and no `@DocSpec` back-link covers — it reads
like specification and is not, which is worse than no comment at all. It is also
the derivation where an authoring agent is most tempted and least detectable,
which is why C1 states its prohibitions as a closed list rather than as taste. So
the rules below are
universal, and an entry may name *which* SOM field is a comment's source, exactly
as it names a designated name field for N1 — never *whether* a comment is emitted
or how it is shaped.

**C1 — the source text.** A comment's text comes from the **contributing SOM
section**, in dartdoc's own two-part shape:

| Part | Source |
|------|--------|
| **Summary** — the first paragraph | The section's **designated description field**: the form field that says what the thing *is* — `DataEntityEntry.description`, `DataAttributeEntry.description`, `ClientApplicationEntry.purpose`. Where it is not obvious, an entry names it in point 1 beside the designated name field. |
| **Body** — the paragraphs below | The section's own `content` (`tom_specs_model_rules.md` §5.2). For a `@Form` section that is the prose *before* the field lines, which is the only part of a form section's content that is not already an argument. |

Either half may be absent; a section with neither yields no comment. What is
**never** a source:

- **`@ContentHelp` text and `@Form` field hints.** They tell an *author* what to
  write in a slot; they describe the slot, not the specified thing
  (`tom_specs_model_rules.md` §5.6). An agent reaching for them ships
  authoring instructions as documentation. `codespecs_mapping.md` §8's document
  map does list them as a CE-TX source — that is model-authored *copy* feeding a
  message key, a different consumer, and it is not licence to read them here.
- **A form's field lines.** They are already the declaration and the annotation
  arguments — §2.3 test (a), applied to prose.
- **Non-`Form` `@ContentType` content** (`DDL`, `SQL`, `Dart`, `Mermaid`, …).
  That content is an artifact, not a description of one; where an entry consumes
  it, its point 1 says what it becomes.
- **Anything the agent composes.** No summarising, no rephrasing, no
  sentence assembled from field values, no model. C3's one template is the only
  generated prose in the entire output.

These four prohibitions bind the **extract generator** as well, word for word:
`codespecs_mapping.md` §1.1.1 names it as C1's second subject rather than
restating it. An extract and a comment are the same kind of artifact — text that
reads as specification and must therefore *be* specification — and one rule with
two subjects cannot drift the way two rules would.

**C2 — the four positions.**

| # | Position | Emitted on | Source section | If the text is absent |
|---|----------|------------|----------------|-----------------------|
| **P1** | Declaration doc | Every top-level declaration — class, enum, catalogue holder | The section named first in the entry's point 1 | No comment (C3 covers the holder that has no section) |
| **P2** | Member doc | Every generated member that has a contributing section of its own | That member's section(s), in N8 order | No comment |
| **P3** | Method doc | Every method of a form-3a or form-3b declaration, and every method of the abstract collaborator a 3b body calls | The section — or promoted step subsection — whose behaviour the method states | **Generation error** |
| **P4** | In-body comment | Nothing — see C6 | — | — |

**P2 turns on the same test as `@DocSpec`, not on a judgement.** §2.5 rule 6
withholds a back-link from a member that adds no section of its own — a derived
back-reference, a materialised ownership list — and P2 withholds the comment from
exactly those members, for the same reason: there is no author text to render.
The two are one statement in two audiences, `@DocSpec` for the tool and `///` for
the reader.

They part company **only where an entry says so and names what carries the trace
instead**. There is one such case: §3.1.1 emits no per-constant `@DocSpec` on a
domain enum, because N8 order plus the constant's own P2 comment already
identifies each `DMEVA`. That is a decision about the *back-link*, taken because
the comment is present — it does not license withholding the comment.

**P3 shares its text with a form-3a body.** §2.4 emits `throw
UnsupportedError('<explication>')` as the whole body of a form-3a method; the
explication is *this same text*, whitespace-collapsed to one line with `'` and
`$` escaped. One source, two renderings — which is why an empty description is
fatal here and merely silent everywhere else: a method with no behaviour text
has neither a doc comment nor an explication, and would pass as specified while
saying nothing. A form-3b method has no explication to share — its statements
are the specification — but P3 still applies to it and to every collaborator
method it calls, and is still fatal when absent. `codespecs_mapping.md` §3
requires the abstract collaborator's methods to carry detailed behaviour
doc-comments; P3 is where that requirement is discharged, from the collaborator
method's own contributing section.

**C3 — declarations that have no section.** A holder the agent creates by
*grouping* — a catalogue file (N7), a per-client config holder — has no section
of its own only when the grouping key is not itself a section. Usually it is:
the list container is a real section with its own id and content
(`tom_specs_model_rules.md` §7.5), so C1 applies to the holder unchanged. Where
it genuinely is not, and only there, P1 emits the single permitted template:

```
/// <Part name, from `codespecs_mapping.md` §4.1> for <document root name>.
```

— `/// Error codes for Ordering.` No other generated sentence exists anywhere in
the output.

**C4 — shape and escaping.**

1. Each line of the source text becomes one comment line: `/// ` plus the line,
   or `///` alone where the line is empty. No emitted line carries trailing
   whitespace.
2. **No re-wrapping and no truncation.** The source's line structure is preserved
   exactly. A wrap width would be a constant this contract does not state, and the first time anyone
   tuned it every file in the tree would re-diff with no spec change; worse, a
   naive wrap destroys the markdown the text is written in — lists, tables and
   fenced blocks do not survive it.
3. Summary and body are separated by exactly one `///` line. The block's last
   line sits immediately above the first annotation, with no blank line between.
4. The text is markdown and stays markdown — dartdoc renders it. Exactly two
   constructs are escaped, because dartdoc reinterprets them:
   - `[` → `\[` and `]` → `\]`. Dartdoc reads `[Name]` as a code reference; the
     SOM is technology-neutral (`codespecs_mapping.md` §1.2) and names no Dart
     element, so a bracketed word in a description is always text.
   - `<` → `&lt;`. Dartdoc passes inline HTML straight through.

   Escaping is **skipped inside fenced code blocks**: a line whose first
   non-space characters are ```` ``` ```` toggles the fence, and lines inside one
   are copied verbatim. Escaping a fence's contents would show the escape.
5. Nothing else is normalised — no capitalisation, no added full stop, no ASCII
   folding. N2 folds because an identifier must be an identifier; a comment is
   text, and silently editing an author's sentence is invisible authorship.

**C5 — determinism.** A comment block is a pure function of the SOM text, on the
same footing as N1–N3: no clock, no counter, no wrap width, no dictionary, no
summariser. Regenerating over an unchanged document reproduces every comment
byte-for-byte, so N8's guarantee covers the comments as well as the code and a
diff in a generated tree still means the spec moved.

**C6 — in-body comments: none.** The only `//` in a generated file is §2.7's
banner; every other comment is a `///` at P1, P2 or P3. A step worth explaining
is a **call to a named method on the abstract collaborator**, and the narrative
lives on that method's P3 doc comment — a declaration the compiler and the
validator can both see, rather than a comment neither can. This is the rule
`codespecs_mapping.md` §3's first-level-implementation latitude needs: it is what
keeps a form-3b body a specification rather than an essay, and it is why a body
has exactly the two shapes §2.4 defines — 3b's statements, or 3a's `throw`.

### 2.9 The authoring prompt

§2.0 says who writes the code; `codespecs_mapping.md` §1.1.2 says in what order a
run reaches them. This section is what an **authoring step** is actually handed:
the text that carries one `csgen<n>` pass. It lives here rather than in the
mapping document by the same split that put the procedure there — a procedure is
grounding, and the text that produces code is derivation.

**This is one of Phase 4's two prompts, and the other one is not here.**
[`codespecs_prompt.md`](../../../ai_build/tom_specs_model/doc/codespecs_prompt.md) holds the *starting* prompt, which
gates the run and creates its todo tree. The two partition the phase without
overlap: that one produces todos and no code, this one produces code and no
todos. A `csgen<n>` todo exists because the starting prompt created it; this
prompt is what that todo is then handed.

**One prompt, thirty-one instantiations — not thirty-one prompts.** The steps
differ only in their *inputs*: which extracts, which entries, which project,
whether the step is a component. Everything else — the naming rules, the locus
rule, the argument tests, the body forms, the comment rules, the file shape, the
stop condition — is universal, and §2 already states it once. Thirty-one hand
written prompts would be thirty-one copies of §2 that drift apart silently, and
the drift would show up as inconsistent *generated code*, which is the most
expensive place to discover it. The same argument rules out a prompt per
contract entry: §1's seven points already **are** an entry's per-element inputs,
so a per-entry prompt would restate §3 rather than add to it.

**The instantiation is mechanical.** Every placeholder is read off a table this
design already fixes; none is composed.

| Placeholder | Bound from | Which is |
|---|---|---|
| `<TODO>` | the step's `csgen<n>` id | `codespecs_mapping.md` §1.1.1 item 3 |
| `<STEP>` | the step's number and emission-unit name | `codespecs_mapping.md` §4.4.6, one row |
| `<PARTS>` | the `CE-*` codes that row's emission unit covers | same row |
| `<EXTRACTS>` | one extract path per part in `<PARTS>` | `codespecs_mapping.md` §1.1.1 item 1 fixes name and location |
| `<ENTRIES>` | the §3 entry numbers for the markers those parts emit | §3, via `codespecs_mapping.md` §8.5's walk index |
| `<LOCUS>` | the project(s) of `codespecs_mapping.md` §4.2 the step writes into | §2.2 |
| `<COMPONENT>` | the component's pass-2 deferral row — **present only for steps 2 and 23** | `codespecs_mapping.md` §4.4.7 |

A step that is not a component omits the `<COMPONENT>` block entirely; it is the
prompt's only conditional part. An instantiation that adds a sentence of its own
has created a second contract, and §6 check 31 will not catch it — so the
instantiation is a substitution and nothing else.

**The prompt.**

```text
You are the authoring agent for CodeSpecs step <STEP>, todo <TODO>.

READ — and read nothing else:
  - The extracts for this step: <EXTRACTS>. They contain, verbatim, every
    specification fact routed to <PARTS>. They are your only source of
    specification content.
  - codespecs_derivation_contract.md §2 (universal rules) and entries <ENTRIES>.
  - The files earlier steps generated, to resolve cross-references and to reuse
    the names they already fixed.
  Do NOT open the Phase-3 specification documents. If a fact you need is not in
  an extract, it was not routed here, and reaching for it would write into
  <PARTS> something another step owns.

WRITE into <LOCUS>:
  - Walk this step's extract entries in the order codespecs_mapping.md §4.4.8
    fixes — SOM document order (§2.1 N8) across all of this step's parts
    together, not one part after another. One entry is one L3 todo.
  - For each entry, follow its §3 contract entry's seven points: input, output
    shape, argument derivation, naming, locus, cross-references, back-link.
  - Names come from §2.1 N1–N10. They are computed from the specification text,
    never chosen.
  - Annotation arguments are decided by §2.3's three tests, from the closed
    catalogues and the typed reference family (§2.6, §5.4).
  - Bodies take exactly one of the two shapes §2.4 defines — form 3a's
    `throw UnsupportedError(<explication>)`, or form 3b's statements plus the
    abstract collaborator §3.0.1 requires. §2.4 decides which from the input;
    you do not.
  - The top-level declaration carries @CodeSpec then @DocSpec then its Cs*
    marker; a member that consumed a section of its own carries @DocSpec and no
    @CodeSpec, and the top-level @DocSpec repeats those members' sections
    (§2.5). Every file has §2.7's five-part shape.
  - Comments are governed by §2.8: C1's sources, C2's four positions, C4's
    shape. Copy the specification's text; do not write a sentence of your own.

<COMPONENT>
This step is a strongly connected component. Author it in the two passes
codespecs_mapping.md §4.4.7 fixes, inside this one todo:
  Pass 1 — declare every member of the component, filling every reference to an
           earlier step but leaving intra-component reference slots unwritten.
  Pass 2 — fill those slots: <COMPONENT>.
The component does not compile between the passes. Do not end the step in
between.
</COMPONENT>

STOP when a derivation has no admissible output (§2.0's "generation error"):
  Do NOT write the declaration, and do not substitute a placeholder for the
  missing fact. File a csopen<n> quest todo with status decision-needed, naming
  the section id and what the derivation required, then continue with the next
  entry. A paused step is recoverable; an invented fact is not.

NEVER:
  - Summarise, rephrase, compose a sentence from field values, or choose a name
    (§2.8 C1). These four are the whole of what you may not do with text.
  - "Improve" a derived name, key or ordering. §6 check 31 compares two runs;
    a better name breaks the contract in the one way no compiler notices.
  - Write a reference to a declaration a later step will emit (the
    no-forward-reference rule of codespecs_mapping.md §4.4.3) — except an
    intra-component slot in pass 1 above,
    which is left empty rather than forward-referenced.
  - Leave a TODO, TBD or FIXME anywhere in the output. The mechanism for
    "unresolved" is a csopen<n> todo, not a comment.

HAND BACK:
  - The list of files written, by locus project.
  - The csopen<n> todos filed, if any, with their section ids.
  - The L3 todos of this step, each marked completed or left open against a
    csopen<n>.
```

**What the prompt deliberately does not carry.** It states no naming rule, no
catalogue and no body shape inline — it cites them. A prompt that inlined §2
would be a fourth place the rules live (this contract, the validator, the
generated code, the prompt), and the validator would then be checking the
contract while the agent followed the prompt. Citing keeps one authority per
rule, which is the property §6 depends on to be a check rather than a second
opinion.

---

## 3. The contract entries

Thirty-nine part markers plus one of the two facet value classes, grouped by
generation slice (`codespecs_mapping.md` §4.4.3), preceded by the one entry that
belongs to no slice (§3.0). `CsFileReference` has an entry of its own (§3.3.3)
because it is filled from a SOM subsection the annotated column does not name;
`CsGradedAccess` has none because it is filled entirely inside `@CsAuthorize`'s
graded arm, and is contracted there (§3.4.3). Slice 1–2 emit into `<app>_codespec_shared`, 3–4 and 7 into
`<app>_codespec_server`, 5–6 into `<app>_codespec_client`.

**Where an entry sits.** At the slice of the declaration its marker is attached
to — not at the slice of every symbol the part emits. Two cases need the
distinction. A marker may ride hosts in two slices (`@CsAudited`, over both the
CE-DB write path and the CE-API handler); it is entered once, at the earlier, and
its Locus point names the other. And a part may emit an unmarked half in a later
slice (CE-NT delivery, CE-UP server persistence); that half has no marker, so it
has no entry, and again the Locus point carries it.

**How a point-7 row names its sections.** A row writes the class-level id of the
*routing* section type — `DocRef('DAENT', …)` reads "the edge this description
fixes comes from the entity's section". The row thereby fixes the description
and the routing, not the emitted id: what is emitted is §2.5 rule 2's extract
token routed from that section (`DAENT-IDEN` for the entity head's form,
`content` for a narrative field or a form riding it), one `DocRef` per token.
Where a section's values split across several tokens, the row's phrasing splits
with them — each token's `DocRef` carries the clause covering what that token
supplied. The converse holds for multiplicity: a row that says "one `DocRef`
per contributing step" enumerates **edges**, and §2.5 rule 1 merges the edges
that share a token into one `DocRef` with a widened description. A class-level
id is not an extract key, and a back-link check 36 cannot resolve against an
extract is a defect, so the row's id never reaches the code verbatim unless a
routed field happens to carry it.

### 3.0 Across every slice — the abstract collaborator

`@CsCollaborator` has **no slice of its own**. Every form-3b body calls into an
abstract collaborator (§2.4), and the agent emits that collaborator **in the
same emission unit as the declaration whose bodies call it**, immediately before
it — so `codespecs_mapping.md` §4.4's no-forward-reference rule is satisfied
without a slice edge, and `codespecs_mapping.md` §4.4.3's partition invariant, which is *per emission
unit*, is undisturbed.

Five entries name a collaborator today: §3.4.4 and §3.7.1 (server), §3.5.5,
§3.5.7 and §3.5.10 (client). §3.3.4 names none — `TomQueryBuilder` is the whole
vocabulary its query bodies need — and a declaration whose 3b bodies all take
§2.4's fallback to 3a emits none either, because there are then no calls for one
to receive. Two entries make that fallback ordinary rather than exceptional:
§3.7.1, where a single-action job lists no steps and its `@CsJob` class emits no
collaborator at all, and §3.5.7, where a call whose issuing step states no
`SVCST` steps does the same for the same reason.

It is also the one marker in this contract that is **not a part**. It has no
`CE-*` code, no canonical id and no `CodeSpecPart` value, and
`codespecs_mapping.md` §4.1's parts catalogue gains no row for it: a part is what
a SOM section is realised *as*, and a collaborator is what a realisation's body
needs in order to compile. It is a marker all the same, for two reasons that are
not stylistic — §2.7 part 4 requires a `Cs*` marker on every generated top-level
declaration, and §6's checks have to *find* collaborators, which a `Collaborator`
name suffix would turn into load-bearing convention.

#### 3.0.1 `@CsCollaborator` — the abstract collaborator a form-3b body calls

| Point | Contract |
|-------|----------|
| **1 Input** | No section of its own: the **ordered step list** the calling entry's point 1 already names — or, where the entry emits several bodies from several sources, all of them (§3.5.7's three role-routed sublists of one `SVCST` list are one collaborator's methods, not three collaborators). One method per step that supplies **behaviour text** — what the *system* does. Per step section: `MNSST` → `systemResponse`, `SCNST` → `systemResponse`, `ALST` → `response`, `EXTST` → `response`, `LGFLS` → `LFSEP.description`, `SCJOST` → `systemAction`, `SVCST` → `systemAction`. `LGFLS`'s is a subsection field and not the step's own `content` because that `content` is a `@Form` — `stepOrder`, `stepType`, `actor` — and so carries no prose at all; `LFSEP.description` is the one field of the step that states what happens in it. The **actor-side** fields (`MNSST.actorAction`, `SCNST.actor`/`action`, `ALST.action`, `EXTST.action`, `LGFLS.actor`) are never a behaviour source: they state what the user does, which is the step's trigger, not work the collaborator performs. `SCJOST` and `SVCST` have no such field to exclude, and that is the point of their shape: a job runs off the request thread and a server call's three roles are assembling, applying and surfacing, so in neither does anything outside the system act within a step — which is why their one behaviour field is `required` where every other step section's is optional, and why a `SCJOST` or `SVCST` step never yields "no method". A step with no behaviour text yields **no method and no statement** — it is an actor-only step, and there is nothing for Phase 6 to implement. That is also what §2.4's "empty step source" means concretely: a body all of whose steps are actor-only falls back to 3a, and a declaration all of whose bodies do emits no collaborator. The class's own contributing section is the step list's **container** section (`tom_specs_model_rules.md` §7.5), which is what §2.8 C2 P1 selects anyway. |
| **2 Output** | An `abstract class` with **no superclass and no substrate** — one of only two declarations in this contract built on nothing (§5.2's `@CsEnum` is the other), and deliberately: `codespecs_mapping.md` §1.1 pillar (b) governs the classes a CodeSpec *instantiates*, and a collaborator is never instantiated in Phase 4. It holds one abstract method per contributing step and **nothing else** — no fields, no constructor, no statics, no implemented member. Coding **form 2**: an abstract method has no body at all, so §2.4's 3a/3b distinction does not reach it and "compiles, does not execute" is structural here rather than stated.<br>**Signatures.** *Parameters* — the calling body's own parameter list, repeated name-for-name and type-for-type. A step operates on what its caller was given; which parameters a given step reads is authored nowhere (`MNSST.dataInvolved` is prose), and an agent that guessed a subset would be inventing signature, which invariant 1 forbids. *Return type* — the calling body's return type on the **last** contributing step in N8 order, `void` (or `Future<void>`) on every earlier one; the last step is what the caller `return`s, which is how invariant 2 holds without a fabricated value. Where the calling body returns `void` / `Future<void>`, every method does and the body has no `return`. *Asynchrony* — `Future`-returning exactly when the calling body is (invariant 3); the caller `await`s each earlier call and `return`s the last one un-awaited, its future *being* the caller's result.<br>**Injection** — one field on the calling declaration:<br>`late final <Name>Collaborator collaborator;`<br>The name is the fixed word `collaborator`, not derived: there is exactly one per declaration, so there is nothing to distinguish, and deriving it would make the caller's call sites depend on the collaborator's name twice over. `late final` is the one place this contract keeps `final` where §2.4 otherwise emits a bare `late`: the seam is plumbing Phase 6 binds exactly once and no reflection ever writes, so the setter §2.4 preserves for reflected members buys nothing here. It is also what makes the "does not execute" claim land at the earliest possible point — the first 3b body to run throws on the unset field *before* it dispatches to an abstract method. The field carries **no doc comment and no `@DocSpec`** (§2.8 P2, §2.5 rule 5): it adds no section of its own.<br>**Not a constructor parameter, and not a locator.** The five declarations that carry 3b bodies sit on different `tom_core`-family substrates whose constructors Phase 4 does not own (§3.4.4's `TomAuthenticationService`, §3.5.5's action controller, §3.7.1's `TomJobBase`), so a constructor parameter would have to thread through a superclass signature it cannot change, and a service locator would be a Phase-4 runtime the artifact is not allowed to have. A settable field is the one shape that works identically on all five; Phase 6 binds it wherever it builds the declaration. |
| **3 Arguments** | None; `@CsCollaborator({String? note})`. §2.3 test **a**: the method set *is* the declaration. There is no substrate, so test **b** does not arise, and nothing reaches test **c**. It carries nothing and is emitted anyway, for the two reasons §3.0 gives. |
| **4 Naming** | **Class** = the owning declaration's identifier + `Collaborator` (`CustomerActionControllerCollaborator`). Unique by construction — the owner's name is already unique in its locus under N4, and the suffix is fixed.<br>**Method** = camelCase of the **calling body's identifier**, then PascalCase of the **step's headline**, both through N2/N3: `saveCustomerCheckTheEditedValues`. N1 is unchanged and supplies each half. No step section carries a designated name field — `stepNumber` / `stepOrder` are *order*, and `tom_specs_model_rules.md` §10.2's entry-name restatement rule is precisely why a list entry has no name field beside its headline — so N1's second clause applies and the source is the step's **headline**. An unheadlined step therefore **fails** generation naming its section id, exactly as N1 already says of an unnamed section. The order token is deliberately not the source: it names nothing, and the behaviour text cannot be one either, since shortening a sentence to an identifier needs a truncation width, the unstated constant §2.8 C4 rule 2 rules out for the same reason.<br>**The calling body's identifier is always present, not only on collision.** One collaborator serves *every* 3b body of its declaration — §3.5.5's is the clearest case, where one action controller carries a `@CsAction` body per screen action and all of them share it — so two bodies' steps can carry the same headline; and a qualifier applied only when a collision occurs would make an identifier a function of the rest of the document, which N1's pure-function rule forbids. §2.4's B4 adds the one further method kind, a **guard**, under the same two-part name plus a fixed `Applies`.<br>**N4 applies per collaborator class** for these methods rather than per project: two steps of one calling body that produce the same identifier fail generation, naming both step section ids.<br>**File** = N7 unchanged, under the **owning part's** canonical id so it lands beside its caller: `lib/src/action/customer_action_controller_collaborator.dart`. |
| **5 Locus** | Always the owning declaration's project, **never `shared`**. A collaborator is not a contract between the two sides — it is the Phase-6 seam of one declaration's bodies — and a shared one would put a client's steps in the server's compile unit. §3.4.4's and §3.7.1's are `server`; §3.5.5's and §3.5.10's are `client`. |
| **6 Cross-refs** | None, in either direction. It emits no `Cs*Ref` — nothing outside its owning declaration ever names a collaborator, so there is no edge for one to carry — and it cites none: its methods carry only the caller's own parameters, whose types it references exactly as the caller does (§2.6). §2.6's table gains no row. |
| **7 Back-link** | Class: `@CodeSpec('<owning part canonical id>.<Name>', source: [...])` and a `@DocSpec` opening with `DocRef('<step-list container section id>', 'supplies the step list this collaborator carries')` and continuing with one `DocRef` per method section, per §2.5 rule 5. Each method: `@DocSpec([DocRef('<step section id>', 'supplies the behaviour this step states')])`. The class is the emission unit, so it alone carries `@CodeSpec`, and §2.5 rule 4 equates its `source` with its own `@DocSpec` set. |

**A step section is consumed twice, by two declarations, and each says what it
took.** The calling entry back-links the step from its own body (§3.5.5,
§3.5.7 and §3.7.1 point 7) because it took the step's **position in the sequence**; the
collaborator method back-links it because it took the step's **behaviour**. Two
edges out of one section is exactly what §2.5 rule 3's "describe the edge, not
the section" exists to keep distinguishable — it is not two copies of one edge.
The caller and the collaborator are two separate emission units, so §2.5 rule 4
holds independently within each, and the step section appears in both `source`
sets.

**Comments follow §2.8 unchanged.** P1 on the class comes from the container
section through C1; P3 on each method comes from that step's behaviour field and
is **fatal when absent** — which is the second reason a step with no behaviour
text yields no method at all, rather than an undocumented one.

**Guards are the collaborator's second method kind.** §2.4's B4 reifies a stated
branch condition as a `bool`-returning abstract method on this same class, so a
collaborator holds one method per contributing step **and** one per branch
condition its calling bodies guard on. Everything in the table above carries over
unchanged — the parameter list is still the calling body's, the class is still
the caller's identifier plus `Collaborator`, the file is still N7 — with three
points where a guard differs, all of them stated by B4: its return type is
`bool` / `Future<bool>` rather than the calling body's, since it produces the
condition rather than the result; its name carries the fixed `Applies` token; and
its P3 doc comment is the condition text rather than a behaviour text, and is
fatal when absent for the same reason. Its back-link is
`@DocSpec([DocRef('<flow or step section id>', 'supplies the condition this branch is taken under')])`,
and the class's `@DocSpec` — and so its `@CodeSpec.source` (§2.5 rules 4–5) —
carries it like any other.

### 3.1 Slice 1 — shared const catalogues

Nothing here references another part; every `Cs*Ref` catalogue bottoms out in
this slice. One pair inside it does reference each other: `codespecs_mapping.md`
§4.4.1, §4.4.7 make CE-ER and the CE-TX message keys **SCC-A** and author it in
two passes — the codes and the keys first, the `messageKey` and `errorCode`
consts that join them second.

#### 3.1.1 `@CsEnum` — domain enum (member kind, not a part)

| Point | Contract |
|-------|----------|
| **1 Input** | `DomainEnumEntry` (`DMENE`) under `DOMEN`, with its child `DomainEnumValueEntry` (`DMEVA`) list, delivered in the **CE-EN extract** — the member kind's extract home (`codespecs_mapping.md` §4.1), an areas-catalogue entry rather than a part. Consumed: the enum's designated name field, its description (the §2.8 P1 summary source), and each value's name + description (P2). **Value *labels* are not consumed here** — display copy for a domain-enum value is CE-TX, resolved through `TomTextResourceProvider` like every other label (`codespecs_mapping.md` §1.2 consequence 1). It is of `codespecs_mapping.md` §5.21's **derived** shape, not the catalogued one: the key `<scope path>.<enumType>.<value>` is computable from the value, so it gets no message-key entry and no `@CsText` (§3.1.3), exactly as element-slot copy gets none. The carrier is the **option source** the consuming element emits (§3.5.2), so the label reaches code there and not through this entry. |
| **2 Output** | A **plain Dart `enum`** — no superclass, no `tom_core` basis; §4.1 records `domainEnum` as a *member kind*, so there is nothing to build on. Doc comments carry the descriptions per §2.8 — the enum's at P1, each constant's at P2. **No enhanced-enum members are emitted**: the constant's identifier *is* the value token, the display label is bundle-resolved copy (see point 1) and a default belongs to the enum-typed member, so the enum has no field to hold (`codespecs_mapping.md` §4.1). Emitted only into `shared` **iff** a shared contract type references it (§4.1); otherwise into the single project that does. |
| **3 Arguments** | None. `@CsEnum({String? note})` is unchanged: the enum's name and its complete value list are the declaration (test **a**). |
| **4 Naming** | Enum type = PascalCase of `DMENE`'s name field; each constant = camelCase of `DMEVA`'s name field. N6 applies per constant (`default` → `defaultDomainEnum`). |
| **5 Locus** | `shared` when any shared contract type (CE-API DTO, CE-ER, CE-RP envelope) names it; otherwise the referencing project. A domain enum referenced from **both** client and server is shared by that rule, never duplicated. |
| **6 Cross-refs** | None outgoing. Incoming edges are plain Dart type references. |
| **7 Back-link** | `@DocSpec([DocRef('content', 'supplies the enum name, its backing type and default, and each value id and description')])` on the enum — `content` is the form token of both `DMENE` and `DMEVA` per §2.5 rule 2, so the two carriers contribute **one** `DocRef` with a widened description per §2.5 rule 1; per-constant refs are not emitted — N8 order plus the doc comment already identifies each `DMEVA`. |

#### 3.1.2 `@CsError` — CE-ER error code

| Point | Contract |
|-------|----------|
| **1 Input** | `ErrorCodeEntry` (`ERCEN`); the envelope shape comes from `ResultEnvelope` (`RSLTE`). Consumed per entry: the authored error code, the severity, the description. |
| **2 Output** | One **error-code catalogue holder** per document, marked `@CsError()` plain, holding one `static const CsErrorCode` member per `ERCEN`, each marked with its own `@CsError(severity: …)`. The holder is form 2, a plain annotated model class, authored in `<app>_codespec_shared` alongside the CE-ER envelope + field-error types it references — none of which has a framework counterpart to build on. |
| **3 Arguments** | `severity` ← `ERCEN`'s severity field, **enum-mapped** onto the closed `CsErrorSeverity {info, warning, error, fatal}` catalogue (§2.3, §5.3); defaults to `error`. The **code itself is not an argument** — it is already the `CsErrorCode` const's string (test **a**). No `messageKey` argument: `codespecs_mapping.md` §5.21 keys error copy *by the error code*, so the message key is derived, not authored. |
| **4 Naming** | Holder = `<Document>ErrorCodes` (PascalCase of the document root's name + `ErrorCodes`). Member = N5 over the authored code: `order.not_found` → `orderNotFound`. |
| **5 Locus** | `shared` — §4.2 lists the error result **and** the error-code catalogue as shared. |
| **6 Cross-refs** | None outgoing. `CsErrorCode` is the incoming ref type, cited by CE-VA rules, CE-API operations and CE-NV `outcomeReference`. |
| **7 Back-link** | Per member: `@DocSpec([DocRef('ERCEN', 'supplies the error code and its severity')])`. On the holder: one `DocRef('RSLTE', 'fixes the result-envelope shape the codes are returned in')`. |

#### 3.1.3 `@CsText` — CE-TX message key

| Point | Contract |
|-------|----------|
| **1 Input** | `MessageKeyEntry` (`MSGKE`) and `ValidationMessageTemplate` (`VMT`). Consumed: message key, base copy, role, category. **Derived text is not input** — `codespecs_mapping.md` §5.21's derived source (element `basePath` + role suffix) produces **no** catalogue entry and **no** `@CsText`; only the catalogued source reaches this entry. |
| **2 Output** | One **message-key catalogue holder** per document, `@CsText`-marked members of type `CsMessageKey`. Built on `TomTextResourceProvider` (`tom_core_kernel`), which resolves the keys at runtime; the catalogue itself is form 2. |
| **3 Arguments** | `baseCopy` (**required**) ← `MSGKE`'s base copy, verbatim. `role` ← enum-mapped onto `CsTextRole {error, notification, email, report, generic}`, default `generic`. `category` ← `CsTextCategory {uiCopy, errorCopy}`, default `uiCopy`. Key not an argument (test **a** — it is the `CsMessageKey` const's string). Parameters are **not** an argument: `codespecs_mapping.md` §5.21 marks them derived, read out of the base copy's placeholders. A validator asserts `role == error ⇒ category == errorCopy`. |
| **4 Naming** | Holder = `<Document>Messages`. Member = N5 over the dotted key: `checkout.title` → `checkoutTitle`. |
| **5 Locus** | `shared` for the keys; the **copy** half (`codespecs_mapping.md` §4.4.3 slice 5) is client, and is the same catalogue read through the client's resource provider — one declaration, not two. |
| **6 Cross-refs** | None outgoing. `CsMessageKey` is the incoming ref type, cited by CE-VA error keys, CE-NT bodies, CE-RP labels and CE-JB failure alerts. |
| **7 Back-link** | `@DocSpec([DocRef('MSGKE', 'supplies the message key, its base copy and its role')])`, plus `DocRef('VMT', …)` where the key came from a validation-message template. |

#### 3.1.4 Role and resource-key catalogues — CE-AZ consts, deliberately markerless

| Point | Contract |
|-------|----------|
| **1 Input** | `AuthorizationRoleEntry` (`AZRO`) with its scope subsection (`ARES`) for the role catalogue; `ResourceKeyEntry` (`RESKEY`) for the resource-key catalogue. Both route to CE-AZ, so both reach the CE-AZ extract; this entry is authored in slice 1 because §3.4.3 point 2 places the catalogues there — every `CsRoleRef` / `CsResourceKeyRef` in the trio bottoms out here. Consumed per role: the role name, its description (§2.8 P2), its scope/inheritance metadata as doc-comment context. Per resource key: the key, its resource type and description. The permission-set detail (`ROMA` / `ROLPER` / `ENT`) is **not** consumed — it defines what a role means at runtime, which `TomRoleAccess` resolves; the catalogue only names the role. |
| **2 Output** | One holder per document and catalogue — form 2, a plain class of `static const` members: `static const CsRoleRef orderClerk = CsRoleRef('orderClerk');`, `static const CsResourceKeyRef orderArchive = CsResourceKeyRef('order.archive');`. The strings live in the `TomRoleAccess.roles` / `TomResourceKeyAccess.key` string spaces (`tom_core_kernel`), which is the substrate relationship — there is no framework holder class to build on. **Holder and members carry no `Cs*` marker, and that is a rule, not an omission**: CE-AZ's one annotation, `@CsAuthorize`, marks a *gate* — its required `requirement` argument names which arm gates a thing — and a catalogue const gates nothing, so a marker here would either invent a fake requirement or need a second, argument-less marker whose only content is what the member's own const type (`CsRoleRef` / `CsResourceKeyRef`, `codespecs_mapping.md` §5.23) already states. §2.3 has no argument to carry (the name is the const's string — test **a**; the meaning is the runtime's — test **b**), and a marker carrying nothing that a type already declares fails the §3.0 emptiness bar that `@CsAuthorize()` plain would set. `@CodeSpec` and `@DocSpec` remain **mandatory** as on every emission unit (§2.5) — markerless means no `Cs*` marker, never no back-link. |
| **3 Arguments** | None — there is no marker to carry them (point 2). |
| **4 Naming** | Holders = `<Document>Roles` / `<Document>ResourceKeys` (PascalCase of the document root's name token, as §3.1.2's `<Document>ErrorCodes`). Members by **N9**: camelCase of the role's name field; a resource key is an authored dotted key, kept verbatim per N9's authored-key exception, with the const named by N5 over it. Files by **N7's catalogue-holder rule**: `lib/src/authorization/authorization_catalog.dart` holds both holders — they are one catalogue file per N7, two holders because roles and resource keys are two ref types. |
| **5 Locus** | `shared` — §4.2 and §3.4.3 point 5: both sides cite the catalogues. |
| **6 Cross-refs** | None outgoing. `CsRoleRef` / `CsResourceKeyRef` are the incoming ref types, cited by `@CsAuthorize` slots (§3.4.3), CE-NV route access and anything else that names a role. |
| **7 Back-link** | Per role member: `@DocSpec([DocRef('content', 'supplies the role, its scope and its permission set'), DocRef('ARES', 'supplies the role scope, inheritance and permission set')])` — `content` is `AZRO`'s form token per §2.5 rule 2. Per resource-key member: `@DocSpec([DocRef('content', 'supplies the resource key, its type and its protection level')])` from `RESKEY`. The holders aggregate their members' refs per §2.5 rule 4. |

### 3.2 Slice 2 — shared contract

Cites slice 1 only.

#### 3.2.1 `@CsEndpoint` — CE-API, shared half (operation catalogue + DTOs)

| Point | Contract |
|-------|----------|
| **1 Input** | `ServerOperationEntry` (`SVOPE`) under the `ServerOperationRegistry` (`SVOPR`) — the application's own operation surface. Consumed: `operationName`, and the `ServerOperationMemberEntry` (`SVOPM`) lists that make up the request and response shapes. `InterfaceOperationEntry` (`IOE`) is **not** an input here: it describes a foreign contract and carries `serverCall` only (`codespecs_mapping.md` §8.5). |
| **2 Output** | Three things in shared: (i) the **operation-ref catalogue** — one `static const CsOperationRef` per operation; (ii) the **request/response DTOs** — form-2 plain annotated model classes; (iii) where an operation member is typed by a data entity (`SVOPM.dataEntity`), the **entity wire DTO** that types it (§3.2.11). The endpoint declaration itself is built on `TomApiEndpoint<R,Q>` within a `TomApi` (`tom_core_kernel`), with `R` the response type and `Q` the request type. The response type **is** the shared CE-ER result envelope `Result<T>` (§3.1.2, `codespecs_mapping.md` §7); an agent that emits a bare `T` has violated the server contract. |
| **3 Arguments** | `operation` — **first positional, required** ← `SVOPE.operationName`, **verbatim** (N5). `codespecs_mapping.md` §5.14 drops the HTTP method (fixed POST) and the error-response type (5xx only) as spec inputs, and `SVOPE` authors neither, so neither is an argument. `descriptionKey` → CE-TX (not an argument); `SVOPE.authorization` — the embedded `AZREQ` choice — → the `@CsAuthorize` modifier (§3.4.3). |
| **4 Naming** | Catalogue = `<Document>Operations`; member = N5 over the operation name. DTOs = PascalCase of the operation name + `Request` / `Response`. |
| **5 Locus** | `shared` (§4.2: request/response types **and** the operation-ref catalogue). The handler half is §3.4.2, server. |
| **6 Cross-refs** | Emits `CsOperationRef` consts (the edge everything else cites). A member typed by a domain enum (`SVOPM.domainEnum`) references that enum by plain type rather than restating it. A member typed by a data entity (`SVOPM.dataEntity`) is typed by that entity's **wire DTO** (§3.2.11) — never by the §3.3.1 entity class, which is server-only (§4.2) and would invert the locus split if a shared DTO named it. |
| **7 Back-link** | `@DocSpec([DocRef('SVOPE', 'supplies the operation name')])`, plus one `DocRef('SVOPM', …)` per member of the shape the DTO realises. |

#### 3.2.2 `@CsValidation` — CE-VA, the declaration string

| Point | Contract |
|-------|----------|
| **1 Input** | `ElementValidationRuleEntry` (`ELVARU`), `DataAttributeConstraintEntry` (`DATAA`), `IntegrityConstraints` (`INCO`). Consumed: which of the ten standard rules apply, and each rule's arguments. |
| **2 Output** | **No declaration of its own** for the standard rules — the marker rides the field it constrains, carrying the `codespecs_mapping.md` §5.19 declaration string. Built on `Validators` (`tom_flutter_ui`), whose named rules the string selects. A shared rule *library* class also carries a plain `@CsValidation()`. |
| **3 Arguments** | `rules` — **first positional, optional** (`''`), the `codespecs_mapping.md` §5.19 comma-separated grammar: `<name>` / `<name>:<arg>` / `<name>:<arg1>:<arg2>`, e.g. `'required, minLength:8, pattern:^[A-Z]'`. Rule names are the nine declarable tokens; `compose` is **not** declarable (`codespecs_mapping.md` §5.19) and an agent that emits it has produced an invalid string. Argument values are verbatim from the SOM constraint. Empty on a library holder. |
| **4 Naming** | No identifier — the marker sits on an existing field. A shared rule library is named `<Document>Rules`. |
| **5 Locus** | `shared` where the same rule constrains a shared DTO; otherwise `client` with the field it rides (§4.2 lists "shared CE-VA rules"). |
| **6 Cross-refs** | None from the string itself; the error key of a standard rule is derived per `codespecs_mapping.md` §5.21. |
| **7 Back-link** | `@DocSpec([DocRef('ELVARU', 'supplies the rule set and its arguments')])` — `DATAA` / `INCO` substituted when the constraint came from the data model. |

#### 3.2.3 `@CsFieldRule` — CE-VA, project-specific single-field rule

| Point | Contract |
|-------|----------|
| **1 Input** | `ElementValidationRuleEntry` (`ELVARU`) whose rule is **not** one of the ten standard rules. Consumed: the rule's description (which becomes the stub explication) and its error key. |
| **2 Output** | A standalone `Validator<T>` — `FutureOr<ValidationResult> Function(T)` (`tom_flutter_ui`) — as a **form-3a** function whose entire body is `throw UnsupportedError('<description>')` (§2.4) — the rule's input is prose, so there are no steps to derive statements from — or a registered entry in `TomValidatorRegistry`. The typed value in / `ValidationResult` out signature is what makes it composable into a declaration string. |
| **3 Arguments** | `errorKey` (**required**) ← the SOM rule's error key, resolved to a `CsMessageKey` const by N9. Rule kind and rule arguments are **not** arguments — the function signature and body are the rule (test **a**). "Async/slow" is marked N in `codespecs_mapping.md` §5.19 and is read off the declared `Future` return type. |
| **4 Naming** | camelCase of `ELVARU`'s name field, suffixed `Rule` where N6 would otherwise collide with the field it validates. |
| **5 Locus** | Follows §3.2.2 — `shared` when it constrains a shared DTO, else `client`. |
| **6 Cross-refs** | `CsMessageKey` (its error key). |
| **7 Back-link** | `@DocSpec([DocRef('ELVARU', 'supplies the rule semantics and its error key')])`. |

#### 3.2.4 `@CsFormRule` — CE-VA, cross-field rule

| Point | Contract |
|-------|----------|
| **1 Input** | `ElementValidationRuleEntry` (`ELVARU`) naming **two or more** fields — the discriminator against §3.2.3. Consumed: the involved fields, the rule description, the cross-field error key. |
| **2 Output** | A **method on the `TomForm` subclass** (`tom_flutter_ui`) returning `FormValidationError?`, **form 3a**: body `throw UnsupportedError('<description>')` — like §3.2.3, the input is prose. It is deliberately not expressible in the per-field declaration string — the grammar cannot name a second field — which is why the rule is authored on the form. |
| **3 Arguments** | `errorKey` (**required**) ← the cross-field error key as a `CsMessageKey`. Involved fields are **not** an argument: the method reads them, so the declaration carries them (test **a**). Per-field error keys are marked N in `codespecs_mapping.md` §5.19 — they are derived from `FormValidationError.fieldErrorKeys` at implementation time. |
| **4 Naming** | camelCase of `ELVARU`'s name field, prefixed `validate` when the name is not already a verb phrase — determined by N2 producing a leading token that is not in the closed verb set `{validate, check, ensure, require}`. |
| **5 Locus** | `client` — a form rule lives on the form. |
| **6 Cross-refs** | `CsMessageKey`. |
| **7 Back-link** | `@DocSpec([DocRef('ELVARU', 'supplies the cross-field invariant and its error key')])`. |

#### 3.2.5 `@CsIdentity` — CE-ID, the extension declaration holder

| Point | Contract |
|-------|----------|
| **1 Input** | `UserCategoryDefinition` (`USCDF`) for the holder; its `UserAttributeEntry` (`USATE`) children become members (§3.2.6). `UserLifecycleTransitionEntry` (`ULTRE`) contributes to CE-AU, not here. |
| **2 Output** | An **ordinary class** (form 2) whose members are `@CsIdentityAttribute`-marked. It is **not** a `TomUser` subclass: the principal core — `TomUser` wrapped by `TomPrincipal` (`tom_core_kernel`) — is framework-fixed and not spec input. The extension is carried as JSON via reflection into the user-profile carrier, so the typing comes from this app-authored class. |
| **3 Arguments** | None; `@CsIdentity({String? note})` unchanged. The attribute set is the class's members (test **a**). |
| **4 Naming** | PascalCase of `USCDF`'s name field + `Identity` (`Employee` → `EmployeeIdentity`). |
| **5 Locus** | `shared` — the declaration is contract, read by both sides from the token. Population is server (§3.4.4). |
| **6 Cross-refs** | None outgoing from the holder. |
| **7 Back-link** | `@DocSpec([DocRef('USCDF', 'delimits the user category whose identity extension this declares')])`. |

#### 3.2.6 `@CsIdentityAttribute` — CE-ID, one declared attribute (member marker)

| Point | Contract |
|-------|----------|
| **1 Input** | `UserAttributeEntry` (`USATE`). Consumed: name, type, placement, access guard, system of record, required. |
| **2 Output** | One **member** of the §3.2.5 holder, typed by the SOM attribute's type. Same member-marker pattern as `@CsColumn`. Carried at runtime by `TomUser.attributes` (public) or `TomPrincipal.currentContext` (encrypted) — the two carriers `tom_core`'s principal already has, so this is a placement decision, not a new mechanism. |
| **3 Arguments** | `placement` (**required**, unchanged) ← `USATE`'s placement, enum-mapped onto `CsIdentityAttributePlacement {public, encrypted}`; required because `codespecs_mapping.md` §5.16's fail-safe rule forbids broadening a value's blast radius by omission. **Added by this contract:** `accessKey` ← the access guard, as a `CsResourceKeyRef`; `systemOfRecord` ← the source field, verbatim; `required` ← the required flag, default `false`. The attribute's **type** stays on the member declaration (test **a**). |
| **4 Naming** | camelCase of `USATE`'s name field. |
| **5 Locus** | `shared` with its holder. |
| **6 Cross-refs** | `CsResourceKeyRef` (its access guard). |
| **7 Back-link** | `@DocSpec([DocRef('USATE', 'supplies the attribute, its placement and its access guard')])`. |

#### 3.2.7 `@CsAuth` — CE-AU, shared wire/token half

| Point | Contract |
|-------|----------|
| **1 Input** | `AuthenticationMethodEntry` (`ATME`) — **one marked declaration per entry**, which is why the marker needs no method list. `LoginFlowStepEntry` (`LGFLS`) feeds the client and server flow halves (§3.5.10, §3.4.4). |
| **2 Output** | The reused kernel wire types, declared as the app's binding: `TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>` plus `TomBearerAuthentication` / `TomClientJwtToken` (`tom_core_kernel`). Form 1. `codespecs_mapping.md` §5.25's six framework-fixed mechanics are **not** emitted — they are not spec input. `TomAuthenticationResult`'s enrolment arm (`requires2FAEnrolment`, `availableTwoFactorMethods`, `twoFactorEnrolmentSkippable`) is part of the reused type, so it too is inherited rather than emitted. |
| **3 Arguments** | None; `@CsAuth({String? note})` unchanged. One declaration per `ATME` means the enabled-method set is the set of declarations (test **a**), which avoids inventing a closed method catalogue the SOM does not carry. Session / token / credential policies are values on the CE-CF holder, not annotation arguments. |
| **4 Naming** | PascalCase of `ATME`'s name field + `Authentication`. |
| **5 Locus** | `shared` here; `client` for the login flow (§3.5.10); `server` for the flow and the CE-ID population (§3.4.4). |
| **6 Cross-refs** | `CsOperationRef` for the login operation. Consumes the §3.2.5 identity declaration by plain type. |
| **7 Back-link** | `@DocSpec([DocRef('ATME', 'supplies the authentication method this binding realises')])`. |

#### 3.2.8 `@CsNotification` — CE-NT notification type

| Point | Contract |
|-------|----------|
| **1 Input** | `NotificationModel` (`NM`) → `NTFTY` for types, `UNP` for user preferences. Consumed: which types exist, their urgency, their default channels, their body copy. |
| **2 Output** | A `TomNotificationType` (`tom_core_codespecs` **gap class**) const, form 1 — e.g. `TomNotificationType(typeId: 'order.shipped', urgency: high, defaultChannelIds: ['email'])`. Delivery is `TomMessage` / `TomMessageRouter` / `TomMessageOutbox` (`tom_core_server` `messaging`) and is pure reuse; the gap this marker names is *which types exist and how preferences narrow them*. |
| **3 Arguments** | `body` (**required**) ← the body copy as a `CsMessageKey` — **never inline text**, and required because a notification with no body is not a notification. Type id, urgency and default channels are all `TomNotificationType`'s own constructor parameters (test **b**), and `TomNotificationPreferences` / `TomNotificationCatalog` carry the preference narrowing. |
| **4 Naming** | camelCase of `NTFTY`'s type-id field (N5: `order.shipped` → `orderShipped`). |
| **5 Locus** | **Declaration `shared`**, this slice — the client renders the preference UI against the same catalogue the server dispatches from. **Delivery is `server` at slice 4**: channel routing and the outbox emit no marked declaration of their own, so they have no entry here, and they sit in 4 rather than 7 because the service units that raise a notification cite them. |
| **6 Cross-refs** | `CsMessageKey` (body) — the only slice-1 citation, which is why this entry sits in slice 2 with the rest of the shared contract. Channels are cited by `channelId` **string**, per §3.2.9. |
| **7 Back-link** | `@DocSpec([DocRef('NTFTY', 'supplies the notification type, its urgency and its default channels')])`, plus `UNP` where preferences narrow it. |

#### 3.2.9 `@CsNotificationChannel` — CE-NT channel

| Point | Contract |
|-------|----------|
| **1 Input** | `NotificationModel` (`NM`) → `NTFCH`. Consumed: which delivery routes the deployment declares. |
| **2 Output** | A `TomNotificationChannelDeclaration` (`tom_core_codespecs` **gap class**) const, form 1. Kept separate from §3.2.8 because the two are authored independently: the channel catalogue is a property of the *deployment*, the type catalogue a property of the *domain*. |
| **3 Arguments** | None; `@CsNotificationChannel({String? note})` unchanged. `channelId` rides the gap class's constructor (test **b**) and is the name of a `TomMessageChannel` — an **open** named value, so a deployment can declare a channel the framework never anticipated. That openness is also why no `CsChannelRef` type exists and why a type references channels by id string. |
| **4 Naming** | camelCase of the channel id. |
| **5 Locus** | Declaration `shared`, delivery `server` at slice 4 (as §3.2.8). |
| **6 Cross-refs** | None typed. The channel's **fallback edge** points at a **sibling channel** — `NTFCH` authors it as "Alternative channel if delivery fails" beside its retry policy, the two being different mechanisms: retry re-attempts *this* channel, the fallback substitutes another. It is therefore **intra-part**, which `codespecs_mapping.md` §5.23 rules a local coordinate outside the `Cs*Ref` family rather than a reference lacking a type; it stays an id string on `TomNotificationChannelDeclaration.fallbackChannelId`, and check 17 resolves it. A `Cs*Ref` could not hold it in any case: the field is on a `tom_core_codespecs` gap class, which declares no dependencies, so a typed ref could only ride an annotation argument and would duplicate a field the substrate already carries (test **b**). |
| **7 Back-link** | `@DocSpec([DocRef('NTFCH', 'supplies the delivery channel this declaration registers')])`. |

#### 3.2.10 `@CsReportParameter` — CE-RP runtime parameter

| Point | Contract |
|-------|----------|
| **1 Input** | The parameter subsections of `ReportEntry` (`REPENT`). Consumed: the parameter's type, bound and presentation. |
| **2 Output** | A `TomReportParameter` member, form 1. Distinct from a CE-DB row filter authored into the query — a parameter is **supplied per execution**, so it is part of the report's request shape; and distinct from a CE-FM field for the same reason a report column is: a form field belongs to a form the user submits, a parameter to the report's own request contract. |
| **3 Arguments** | None; unchanged. Type, bound and presentation are `TomReportParameter`'s parameters (test **b**). |
| **4 Naming** | camelCase of the parameter-name field. |
| **5 Locus** | **`shared`** — the parameter shape crosses to the client with the result envelope, even though the definition stays server-side at slice 3 (§3.3.8). It is emitted here, with the `TomReportResult` envelope that carries it, because both travel as a CE-API response DTO. |
| **6 Cross-refs** | `CsMessageKey` (its label); domain enums by plain type. |
| **7 Back-link** | `@DocSpec([DocRef('REPENT', 'supplies the runtime parameter and its bound')])`. |

#### 3.2.11 Entity wire DTO — CE-API, derived shared row shape (markerless)

A server-operation member typed by a data entity (`SVOPM.dataEntity`) needs a
shared type to be typed by, but the entity class itself (§3.3.1) is server-only
(§4.2): the store is server-side, and what has to live in shared is only the
part the two halves must agree on — the shape on the wire. The framework's own
precedent is `TomUserPreference` (server entity, `tom_core_server`) beside
`TomUserPreferenceDto` (kernel wire shape): the entity carries storage, the DTO
carries the agreed row shape. Phase 4 follows that split.

| Point | Contract |
|-------|----------|
| **1 Input** | `DataEntityEntry` (`DAENT`) + its `DataAttributeEntry` (`DAATT`) children, with `DataAttributeConstraintEntry` (`DATAA`) supplying nullability and `DAATT`'s enum typing (`DAATT-DTEN`) supplying enum members — all delivered **in the CE-API extract** by dual routing (`@CodeSpecKind` lists `serverApi` beside `dataAccess` on all three section types), because the slice-2 shared emission may not forward-reference slice 3 (§4.4). The DTO is **derived, not authored**: one DTO exists for exactly the distinct entities named by an in-scope operation member's `SVOPM.dataEntity`; an entity no wire member names gets none. |
| **2 Output** | A **form-2 markerless shared class** — `@CodeSpec` + `@DocSpec`, no `Cs*` marker, like the §3.2.1 request/response DTOs — with one member per stored attribute, typed exactly as the §3.3.2 entity member is typed (SOM value type; enumeration-kind → the §3.1.1 enum, never `String`; `DATAA.nullable` `Yes` → `T?`, `No` → `late T`), and **no storage arguments**: no `@CsColumn`, no column names or types, no sensitivity/PII marking — those are the entity's, not the wire's. |
| **3 Arguments** | None — there is no marker to argue with. |
| **4 Naming** | PascalCase of `DAENT`'s entity name + `Dto` (`Order` → `OrderDto`). The consuming operation member is typed `OrderDto` or `List<OrderDto>` per `SVOPM.multiValued`, nullable per `SVOPM.required`. |
| **5 Locus** | `shared` — which is what the §3.1.1 enum-locus rule then keys on: a domain enum the DTO names becomes shared by that rule. |
| **6 Cross-refs** | Domain enums by plain type (§3.1.1). Never the §3.3.1 entity class, and no relationship navigation — `ENRLE` edges are storage structure, not wire shape; a related entity crosses the wire only if a member's `SVOPM.dataEntity` names it in its own right. |
| **7 Back-link** | `@DocSpec` from `DAENT-IDEN` (the entity), `DAATT-IDEN` (the attributes), `DAATT-DATA` (their types), plus `DAATT-DTEN` / `DATAA` where they supplied a member's typing. No `DAATT-SECU` and no `ENRLE-*` — the facts they carry are not emitted here. |

### 3.3 Slice 3 — server persistence & configuration

Cites slice 1 (domain enums, `CsResourceKeyRef`) and slice 2 — the report
definition's result envelope and parameter shapes are emitted there (§3.2.10).
Never cites the client.

#### 3.3.1 `@CsTable` — CE-DB entity

| Point | Contract |
|-------|----------|
| **1 Input** | `DataEntityEntry` (`DAENT`), with `EntityRelationshipEntry` (`ENRLE`) supplying relationship columns. Consumed at entity level (`codespecs_mapping.md` §5.13): entity name, table, datasource, schema, identity attribute, row-scope rule. |
| **2 Output** | A **persistent entity class** built on the Tom persistence model (`tom_core_server`), form 1. Its stored fields are `@CsColumn`-marked members (§3.3.2). The row-scope rule is emitted as the framework's own `@TomDbScope`, carried alongside — the same "framework annotation beside the marker" pattern CE-LG and CE-SU use. |
| **3 Arguments** | `table` — **first positional, required** ← `DAENT`'s table field, **verbatim** (a physical table name is not derived; an agent that slugified it could rename a table under a running system). `datasource` / `schema` ← the corresponding `DAENT` fields, verbatim, `null` meaning the deployment default. The identity attribute is **not** an argument — it is the member carrying the framework's identity annotation (test **a**). |
| **4 Naming** | Class = PascalCase of `DAENT`'s entity-name field — **not** of the table name; the table is a storage fact and the class is the domain name. N6 applies. |
| **5 Locus** | `server` — CE-DB is server-only (§4.2), which is also why a rendering attribute cannot be declared on a column (`codespecs_mapping.md` §5.13.1). |
| **6 Cross-refs** | Relationship columns reference other entities by **`Type` literal**, never a ref const (`codespecs_mapping.md` §5.23). Domain enums by plain type. |
| **7 Back-link** | `@DocSpec([DocRef('DAENT', 'supplies the entity, its table and its storage placement')])`, plus one `DocRef('ENRLE', …)` per relationship the entity carries. |

#### 3.3.2 `@CsColumn` — CE-DB column (member marker)

| Point | Contract |
|-------|----------|
| **1 Input** | `DataAttributeEntry` (`DAATT`), with `DataAttributeConstraintEntry` (`DATAA`) supplying length, format and **storage nullability**, the `DAATT-SECU` data-security subform supplying the sensitivity classification, and the `DAATT-DTEN` enumeration-type case supplying the domain enum an enumeration-kind attribute is typed by. Consumed (`codespecs_mapping.md` §5.13 attribute level): name, column, value type, column type, read-only, not-loaded, json-encoded, column-access key, converters, `DATAA.nullable`, `DAATT-SECU.sensitivityLevel`, `DAATT-SECU.isPii`, `DAATT-DTEN.domainEnum`, and the `DataAttributeKind.fileReference` facet. **`DATAA.mandatory` is not read here** — it is already claimed by CE-VA (`DataAttributeConstraintEntry` carries `@CodeSpecKind([CodeSpecPart.validation])`), and it answers a different question. |
| **2 Output** | One **member** of the §3.3.1 entity, typed by the SOM value type. **An enumeration-kind attribute is typed by its domain enum:** `DAATT-DTEN.domainEnum` names the `DMENE` entry, and the member's Dart type is the §3.1.1 `@CsEnum` enum generated from that entry — never `String`. The SOM makes `domainEnum` **required** on the case precisely because a stringly-typed column would reopen the closed set the registry exists to close; an enumeration-kind attribute that names no authored enum is a **gate rejection** (`codespecs_prompt.md` §4, A4), never a `String` fallback. The `columnType` argument still carries the SOM column type verbatim — how the enum is *stored* is the enum's own `DMENE.backingType` fact, and the two travel independently. **Optionality is the member's own nullability, keyed on `DATAA.nullable`:** `Yes` emits a plain nullable field `T?`; `No` emits `late T` per §2.4 — `late`, never `late final`, since the repository fills the column through the member's setter. It is **never** a `TomN*` observable — `tom_core_kernel`'s nullable observable family belongs to CE-ST (§3.5.1), and an entity is a plain annotated model class. `read-only`, `not-loaded`, `json-encoded` and converters are emitted as the framework's own persistence annotations beside the marker (test **b**), not as marker arguments. |
| **3 Arguments** | `column` ← `DAATT`'s column field, verbatim; `null` means "same as the member name". `columnType` ← the SOM column type, verbatim. `length` ← the maximum length from `DATAA` — `codespecs_mapping.md` §4.1.1 names maximum lengths as exactly the kind of thing simple code cannot express. `accessKey` ← the column-access key as a `CsResourceKeyRef`. `fileReference` ← a `CsFileReference` value **iff** `DAATT`'s kind is `fileReference` (§3.3.3); its **presence is the column kind**. `sensitivityLevel` ← `DAATT-SECU.sensitivityLevel`, constant-for-constant onto `CsSensitivityLevel {public, internal, confidential, restricted, pii, phi}`; `isPii` ← `DAATT-SECU.isPii` (`Yes`/`No` → `true`/`false`). Both are omitted — `null`, never defaulted — when the attribute authors no `DAATT-SECU` subform: an unauthored classification is not a `public` one. The Dart **value type** is never an argument (test **a**). |
| **4 Naming** | camelCase of `DAATT`'s attribute-name field. |
| **5 Locus** | `server`, with its entity. |
| **6 Cross-refs** | `CsResourceKeyRef`; `Type` literals for relationship targets. |
| **7 Back-link** | `@DocSpec([DocRef('DAATT', 'supplies the stored attribute, its column and its storage type')])`, plus `DocRef('DATAA', …)` where a constraint supplied the length, format or nullability, plus `DocRef('DAATT-SECU', …)` where the data-security subform supplied the sensitivity level or PII marking, plus `DocRef('DAATT-DTEN', …)` where the enumeration-type case supplied the member's enum type. |

**Why `nullable` and not `mandatory`.** `DATAA` carries both, and they are not two
spellings of one fact. `mandatory` (`Required | Optional | ConditionallyRequired`)
is a *business* requirement level and is already mapped — its section is
`@CodeSpecKind([CodeSpecPart.validation])`, so it becomes a CE-VA field rule.
`nullable` (`Yes | No`) is a *storage* fact. They come apart in both directions:
an `Optional` attribute with a `defaultValue` is never `NULL` in the table, and a
`Required` attribute can still be `nullable: Yes` in a schema inherited from a
predecessor system. Deriving the Dart type from `mandatory` would give one SOM
field two unrelated emissions and would get both of those cases wrong.

**Why not the `TomN*` family.** `tom_core_kernel` ships nullable observables
(`TomNString`, `TomNInt`, `TomNDouble`, `TomNBool`, `TomNDateTime`, plus a zoned
arm), and they *read* from a query — `MariadbDatasource` normalises a declared
`String?` onto `String` before dispatching, so an observable-membered result
holder maps correctly. That symmetry on the read side is exactly what makes the
choice look free. It is not: `TomSqlDatasourceRepository.save` binds each column
from `TomColumnInformation.getVariableValue`, which is `invokeGetter(declaredName)`
— the field itself, which on an observable member is the `TomNInt` object rather
than the `int?` it holds. The observable arm therefore has no write path at all.
`tom_core_server/test/optional_column_emission_db_test.dart` pins both halves
against a live MariaDB: the plain-field arm round-trips all five value types with
values, with `NULL`, and across an update that clears a populated column; the
observable arm fails its first `save` with `type 'TomNInt' is not a subtype of
type 'int?'`. The shipped framework entity agrees — `TomUserPreference` declares
its own optional column as a bare `DateTime? updatedAt`.

#### 3.3.3 `CsFileReference` — CE-DB file-reference facet (value class)

| Point | Contract |
|-------|----------|
| **1 Input** | `DataAttributeEntry` (`DAATT`) whose kind is `DataAttributeKind.fileReference`, with the `@OneOf` case `fileReferenceOptions` (`DAATT-DTFR`) supplying the facet fields. |
| **2 Output** | Not a declaration — a **const value** passed to `@CsColumn(fileReference:)`. Built on `TomFileReference` (`tom_core_server`, `object_persistence`), whose four settings it mirrors one-for-one; storage is `TomBlobStore` and key generation `TomFileReferenceKeys`. Per pillar (b) there is no CodeSpecs-local file-reference type. |
| **3 Arguments** | **Unchanged — already fully shaped by `codespecs_mapping.md` §5.13.1.** `keyPrefix` (**required**) ← the storage group, verbatim; there is no default because a shared prefix would put unrelated retention classes in one partition. `store` ← the file store, `null` = the deployment default. `cascadeDelete` ← *delete with record*, default `true` (the file belongs to the row). `defaultMediaType` ← the default content kind. `acceptedMediaTypes` ← the permitted content kinds, `const []` = unrestricted; it has no `TomFileReference` counterpart by design and is enforced at the CE-API upload endpoint. The **stored address** is derived (`<keyPrefix>/<yyyy>/<mm>/<uuid>`) and never authored. |
| **4 Naming** | None — the facet has no identifier of its own. |
| **5 Locus** | `server`, with its column. |
| **6 Cross-refs** | None. Downloadability is the column's own authorization (`accessKey`); rendering is CE-EL; upload/serve is CE-API. |
| **7 Back-link** | Covered by its column's `@DocSpec`; `DocRef('DAATT-DTFR', 'supplies the file-reference facet settings')` is appended to it. |

#### 3.3.4 `@CsRepository` — CE-DB repository

| Point | Contract |
|-------|----------|
| **1 Input** | `DataEntityEntry` (`DAENT`) for the entity and key type; the named queries come from the operations that read the entity (`SVOPE`, matched by `primaryDataEntity` and by the members typed by the entity). Consumed (`codespecs_mapping.md` §5.13 repository level): entity + key type, named queries, predicates, sort, row cap, distinct, transaction scope. |
| **2 Output** | A repository over the `tom_core_server` CRUD / MariaDB repositories, form 1, with one method per named query. Each is **form 3b**, and its structured behaviour surface is the query itself: `TomQueryBuilder` is the named substrate (§2.4 statement kind 2), and the `codespecs_mapping.md` §5.13 predicate vocabulary (`eq`, `like`, `between`, `isIn`, `and`, `or`), sort, row cap and distinct are that builder's own surface (test **b**), not annotation arguments — so the body composes the builder and returns its result. A query stated as description only, with no predicates, sort or cap, falls back to **form 3a** (`throw UnsupportedError('<query description>')`). This entry emits no abstract collaborator: `TomQueryBuilder` is the whole vocabulary its bodies need. |
| **3 Arguments** | None; `@CsRepository({String? note})` unchanged. Entity and key type are the class's generics (test **a**); transaction scope is **ambient** rather than threaded through the call — `TomTransactionManager` holds the current transaction in a `Zone` value, and the flow the repository runs in is what opens it: `@TomTransactional` on the calling CE-API endpoint, or the `runInTransactionScope` wrap CE-JB emits around a job body (§3.7.1). A declared unit of work therefore adds no parameter here (test **b**; `codespecs_mapping.md` §5.13). |
| **4 Naming** | PascalCase of the entity name + `Repository`. |
| **5 Locus** | `server`. |
| **6 Cross-refs** | `Type` literals for the entity; `CsOperationRef` where a named query realises a declared operation. |
| **7 Back-link** | `@DocSpec([DocRef('DAENT', 'supplies the entity and key this repository reads')])`, plus one `DocRef('SVOPE', …)` per named query. |

#### 3.3.5 `@CsMigration` — CE-MG schema-migration artifacts

| Point | Contract |
|-------|----------|
| **1 Input** | `SCHMG` — its `MIGTG` migration-target list (the datasource/schema placement) and its `SCMST` artifact list (kind, version, environment restriction, and the kind-specific body in `SCMST-BASE` / `SCMST-REFD` / `SCMST-CHNG`). Additional input: the §3.3.1/§3.3.2 entity model, which the cumulative DDL must converge on. |
| **2 Output** | Two things: (i) **numbered SQL file assets**, not Dart — under `<databaseMigrationsDirectory>/<datasource>/<schema>/`, named `[<version>]-<description>[@<env>[,<env>…]].<ext>` per `codespecs_mapping.md` §5.27's grammar, applied in ascending version order; (ii) the **spec-side declaration** carrying this marker, over the reused `TomDbMigrations` / `TomDbMigrator` / `TomMigrationFileName` / `@TomDbMigrationAdaptor` / `MariadbMigrationAdaptor` engine (`tom_core_server`) — no gap class. |
| **3 Arguments** | `datasource` and `schema` (**both required**) ← the `MIGTG` entry that `SCMST.migrationTarget` names, verbatim — they are the directory path and cannot be defaulted without silently retargeting a database. Authoring them once per target and referencing the target per artifact is what keeps them required without repeating the pair down a whole chain. `kind` (**required**) ← `CsMigrationKind {initialDdl, baseData, iteration}` from `SCMST.artifactKind`, one-to-one over `codespecs_mapping.md` §5.27's three artifact kinds (`initialDdl` → `initialDdl`, `referenceData` → `baseData`, `schemaChange` → `iteration`; the SOM names stay neutral per `codespecs_mapping.md` §1.2, the marker keeps the CodeSpecs vocabulary). No arm is a safe default, since generating an initial DDL where an iteration was meant would rewrite a live schema. Filenames are **not** arguments — they are file-system facts and one of the four `codespecs_mapping.md` §5.23 string exemptions. |
| **4 Naming** | Declaration = `<Datasource><Schema>Migrations`, PascalCase, one per `MIGTG` entry. **Artifact filenames are authored, never derived** (N5): the version is the author's ordering decision and a derived one would renumber on every spec edit. `SCMST.version` and `SCMST.environments` are the author's `[<version>]` and `@<env>` filename segments, carried through unchanged. |
| **5 Locus** | `server` — the migrations tree ships with the server project as file assets. |
| **6 Cross-refs** | None typed. `SCMST.migrationTarget` → `MIGTG.targetName` is a *doc-side* reference resolved during derivation, not a `Cs*Ref`: it selects the two path strings before generation, so nothing survives into the emitted code to point at. The convergence obligation — cumulative DDL vs. the `@CsTable`/`@CsColumn` model — is a **named generation-time validator check**, precisely because the filename exemption means it cannot be a compile-time edge. |
| **7 Back-link** | `@DocSpec([DocRef('SCHMG', 'supplies the migration artifact set this declaration ships')])`. Applied artifacts are immutable; a schema change is a new numbered artifact, never an edit to an existing one. |

#### 3.3.6 `@CsServerConfig` — CE-CF server configuration

| Point | Contract |
|-------|----------|
CE-CF has **two derivation paths**, discriminated by **who owns the setting's
identity** (`codespecs_mapping.md` §5.16). They are not two spellings of one
input: the two answer different questions, and the discriminator decides which
of a setting's properties can be authored at all.

- **Declared** — the *application* owns the key. `SCSET`'s open list; the author
  invents the key, so every property of the setting must be authored.
- **Fixed** — the *model* owns the key. The 41 policy and layout bands whose
  form fields each name one setting the SOM already knows exists; the author
  supplies only the value, so nothing per-setting is authorable.

| Point | Contract |
|-------|----------|
| **1 Input** | **Declared:** `ServerConfigurationSettingEntry` (`SCSET`), the declaration list under `SystemConfigurationManagement` (`SYCOMA`) — one entry per application-owned server setting. **Fixed:** the CE-CF-mapped policy and layout bands — the audit sink (`EVATPO` / `LOSTPO` / `LOPRPO` / `LOREPO` under `AULOFO`), encryption at rest and in transit, key management, API and file/storage security, and D09's print-and-export band — one setting per form field. The fixed shape is the **majority**: 41 of the 42 CE-CF-mapped sections are fixed, `SCSET` is the single declared one. |
| **2 Output** | A **configuration holder** (form 2) built on `TomBaseServerConfiguration` with `TomServerConfigResourceProvider` (`tom_core_server`), one `@CsServerConfig`-marked member per setting — **one holder for both paths**, since the discriminator is about authoring, not about runtime. Feature flags take the same shape — `codespecs_mapping.md` §5.5 lists them as a settings sub-case, not a separate mechanism. |
| **3 Arguments** | **Declared:** `key` — **first positional, required** ← `SCSET`'s setting key, **verbatim** (`codespecs_mapping.md` §5.23 exemption 1). `envAlias` / `cmdlineAlias` ← `SCSET`'s environment variable and command-line option, verbatim (same exemption). `secret` ← the secret mark, default `false` — the safe arm: a setting wrongly marked secret is merely stripped, one wrongly left unmarked ships its value. `overridableBy` (**required**, `CsOverridableBy {none, client, user, device}`) ← `SCSET`'s overridability opt-in; no default, because choosing a value's blast radius by omission is the exact failure `codespecs_mapping.md` §5.16's fail-safe rule prevents. **Fixed:** `key` ← **derived** per N10; `envAlias` / `cmdlineAlias` **absent** — `codespecs_mapping.md` §5.16 already makes them `SCSET`-only; `secret` **always `false`** and `overridableBy` **always `none`**, both by the `codespecs_mapping.md` §5.16 rules below, neither authorable. For both paths the setting's **type** is the member type and its **default** the member initialiser (test **a**). *Precedence* is not an argument — `codespecs_mapping.md` §5.16 fixes intra- and cross-scope precedence for everyone; `overridableBy` grants the **permission** to contest, it does not order the contest. |
| **4 Naming** | Holder = `<App>ServerConfig`. Member = **N5** over the authored key (declared) or **N2/N3 over the N10-derived key** (fixed) — both paths converge on the same member-naming rule, applied to a key that is authored in one and derived in the other. |
| **5 Locus** | `server`. Deployment-environment names appearing in values are `codespecs_mapping.md` §5.23 exemption 2 — verbatim strings, not refs. |
| **6 Cross-refs** | None typed. Log format, storage, protection and retention land here rather than on CE-LG — they are sink deployment settings. The compliance *report* lands on neither: reviewing and reporting from the log is a follow-up process, not generated code (`codespecs_mapping.md` §4.3.2). |
| **7 Back-link** | **Declared:** `@DocSpec([DocRef('SCSET', 'supplies the setting key, type, default, sources, secret mark and overridability')])`. **Fixed:** `@DocSpec([DocRef('<band section>', 'supplies the value of this model-named setting')])`. Both shapes ride narrative-borne forms, so both emit §2.5 rule 2's token and the back-link cannot tell them apart — which is why check 19 decides the declared shape by the **key** instead: a secret member's authored key must match a declared entry's `settingKey` in the extracts. |

**Why a secret is only ever declared.** A credential's *identity* is
application-specific — no model can name a particular sink's password in
advance — so `secret: true` is expressible on the declared path and nowhere
else. An audit sink that needs credentials to reach a remote store authors them
as `SCSET` entries (`audit.sink.password`); `LOSTPO` names the storage
*policy*, never the credential to reach it. This is the model's own existing
answer, not a new one: `SCSET`'s authoring help already lists `tls.privateKey`
and `jwt.rsaPrivateKey` among its typical keys, and `AULOFO`'s says to never log
secrets at all. **Check 19** enforces it from the emitted code.

**Why a fixed setting is never overridable.** Every fixed band is security,
infrastructure or environment-wide deployment policy — TLS, keys, encryption,
the audit sink, print and export defaults. `codespecs_mapping.md` §5.16 already declares that class of
setting CE-CF-only and non-overridable, so `none` is not a default chosen by
omission but the only value the class admits. A setting that genuinely should
follow a user or a client install is not a fixed band at all: it is CE-CC,
CE-DS or CE-UP, authored in that scope's own list.

#### 3.3.7 `@CsAudited` — CE-LG audited element

| Point | Contract |
|-------|----------|
| **1 Input** | The `SecurityEventsDefinition` (`SEEVDE`) band under `AuditAndLogging` (`AUANLO`): `SecurityEventLoggingPolicy` (`SELP`), the four per-category event policies, and `SecurityEventEntry` (`SEVT`). Consumed: which invocations are auditable, whether the type is audited at all, which fields must never appear. A band that says reads count maps to endpoint-level `@TomAudited()` — the substrate audits no repository read. The sibling `AuditLogFormat` (`AULOFO`) band is **not** an input here — it is CE-CF (§3.3.6). |
| **2 Output** | **No declaration of its own** — a marker on an entity or endpoint, carrying the framework's own `@TomAudited(enabled:, redact:)` beside it. Pure reuse of `tom_core_server`'s `audit` module (`TomAuditTrail` / `TomAuditRecord` / `TomAuditSink`); recording happens automatically at two chokepoints no handler can opt out of — `TomEndpointHandler.handleMethodCall` and `TomSqlDatasourceRepository`'s write path. Repository reads are **never** audited and no annotation turns them on; an invocation-level `@TomAudited()` on the endpoint is the substrate's answer for "record who looked". |
| **3 Arguments** | None; `@CsAudited({String? note})` unchanged. The authored decisions are **exactly** `@TomAudited`'s parameters (test **b**) — the same pattern CE-SU uses with `@tomService`. Retention and log format are **not** CE-LG: they are sink deployment settings and belong to `@CsServerConfig` (§3.3.6). The compliance report is not CodeSpecs at all — it is an ops/compliance follow-up. |
| **4 Naming** | None — the marker rides an existing declaration. |
| **5 Locus** | `server` — the trail is a server chokepoint. It emits in **two slices**, because it is annotation-only and a marker cannot precede the thing it marks: with the CE-DB write path here, and with the CE-API handler at slice 4. Entered once, at the earlier, per §3's placement rule. |
| **6 Cross-refs** | None typed. Nothing outbound at all, which is why the two-slice split costs no ordering. |
| **7 Back-link** | Appended to the audited element's own `@DocSpec`: `DocRef('SEVT', 'marks this element auditable and fixes its redaction set')`. |

#### 3.3.8 `@CsReport` — CE-RP report definition

| Point | Contract |
|-------|----------|
| **1 Input** | `ReportEntry` (`REPENT`) under the `ReportDefinitions` (`REDF`) projection root. Consumed: `codespecs_mapping.md` §5.28's 22-row attribute surface — the grouped projection, dimension by dimension and measure by measure. |
| **2 Output** | A `TomReportDefinition` with `TomReportDimension` / `TomReportMeasure` members (`tom_core_codespecs` **gap classes**), form 1. Query execution (`TomGroupedSelect`, `TomAggregate`) and rendering (`TomTabularResult` + its CSV / XLSX / PDF renderers) are pure `tom_core_server` reuse. CE-RP is a part and **not** a composition of CE-API + CE-DB + CE-FM: none of those can hold a dimension or a measure. |
| **3 Arguments** | None; `@CsReport({String? note})` unchanged. The whole 22-row surface maps onto `TomReportDefinition`'s constructor and its dimension/measure members (test **b**) — the gap was the *classes*, and `codespecs_mapping.md` §5.28 closed it, so nothing is left for the annotation to carry. Its outbound references do not change that: the source entity is a `Type` literal and the schedule a recurrence expression, both constructor parameters; authorization rides a separate `@CsAuthorize` beside this marker (point 6). `codespecs_mapping.md` §5.28's three generation-time consistency checks are validator checks, not arguments. |
| **4 Naming** | PascalCase of `REPENT`'s report-name field + `Report`. |
| **5 Locus** | **Definition `server`**, this slice — that is where the report runs, and it sits with CE-DB because it is a declaration *over* the persistence model rather than server behaviour. **Result envelope and parameter shapes are `shared` at slice 2** (§3.2.10). Emitting the definition here also puts it ahead of both its citers: the slice-4 endpoint that returns it and the slice-7 job that schedules it. |
| **6 Cross-refs** | Emits `CsReportRef` — and CE-JB is its **only** citer, since the ref is server-owned. Every label is a `CsMessageKey`, never inline text. Its four outbound targets each land differently (`codespecs_mapping.md` §5.28): **source entity** ← the source-entity field, as a **`Type` literal** on `TomReportDefinition.sourceEntity` — an entity is already a Dart type, `codespecs_mapping.md` §5.23 gives it no ref const, and a `Type` costs the gap package no dependency; **schedule** ← the report-schedule section's schedule-expression field, **verbatim** onto `.scheduleExpression`, which is not a reference at all (`codespecs_mapping.md` §5.29 realises the CE-JB job *from* the schedule, so a job id here would be the second source that rule forbids, and the schedule's time zone, effective dates and window lower onto the derived `TomJobDefinition`); **authorization** ← `REPENT.access`, the embedded `AZREQ` choice, emitted as a **`@CsAuthorize` beside this marker** by the §3.4.3 rules; the report's own security section keeps only `dataLevelSecurity`, the row-filtering dimension, which is not a requirement kind; **drill-through** stays an open route id string on the column (§3.3.9). |
| **7 Back-link** | `@DocSpec([DocRef('REPENT', 'supplies the grouped projection this report defines')])`. |

#### 3.3.9 `@CsReportColumn` — CE-RP output column

| Point | Contract |
|-------|----------|
| **1 Input** | `ReportColumnEntry` (`REPCOL`). Consumed: which declared dimension or measure the column displays, its aggregate and its format. |
| **2 Output** | A `TomReportColumn` member of the §3.3.8 definition, form 1. A column **displays** a declared dimension or measure and never introduces data of its own — which is why it names a source key rather than an entity column, and why it is not `@CsColumn` (a stored attribute, a different level entirely). |
| **3 Arguments** | None; unchanged. Source key, aggregate and format are `TomReportColumn`'s parameters (test **b**). |
| **4 Naming** | camelCase of `REPCOL`'s column-name field. |
| **5 Locus** | `server` with its definition. The `TomReportColumn` *class* is also reachable from the shared `TomReportResult` envelope, but that is a gap-package type in `tom_core_codespecs` — which is not one of the three generated projects — so it fixes no locus for the authored declaration. |
| **6 Cross-refs** | `CsMessageKey` (its label). Its **drill-through** target is an open route id string on `TomReportColumn.drillThroughRouteId` — the one CE-RP edge a typed ref can never carry, because `codespecs_mapping.md` §5.23's locus rule bars a server-owned definition from citing a client-owned route. Unlike the four `codespecs_mapping.md` §5.23 string exemptions, whose referents are not Dart declarations, a route **is** one, so the compile-time guarantee is lost to locus rather than absent by nature and is **replaced** by check 18 (§6) — the same substitution check 17 makes for a CE-NT fallback. |
| **7 Back-link** | `@DocSpec([DocRef('REPCOL', 'supplies the projected column and its aggregate')])`. |

#### 3.3.10 `@CsReportChart` — CE-RP chart

| Point | Contract |
|-------|----------|
| **1 Input** | `ReportChartEntry` (`REPCHA`). Consumed: chart type, series, axes — the SOM carries all three as structured fields. |
| **2 Output** | A `TomReportChart` member, form 1. **Declared here, rendered by whoever can:** the declaration is authored input, while rendering is implementation-owned — a client draws charts natively, and an export format that cannot express one **omits it rather than failing**. A chart plots columns the report already projects, so it never adds a second query. |
| **3 Arguments** | None; unchanged. Type, series and axes are `TomReportChart`'s parameters (test **b**). |
| **4 Naming** | camelCase of `REPCHA`'s chart-name field + `Chart`. |
| **5 Locus** | `server` with its definition. |
| **6 Cross-refs** | References the report's own columns by member, not by ref const — they are siblings in one declaration. |
| **7 Back-link** | `@DocSpec([DocRef('REPCHA', 'supplies the chart type, series and axes')])`. |

### 3.4 Slice 4 — server behaviour

Cites slices 1, 2 and 3. CE-NT **delivery** — channel routing and the outbox —
emits here too, but authors no marked declaration, so it has no entry of its own
(§3.2.8); `@CsAudited` reappears here over the CE-API handler chokepoint
(§3.3.7).

#### 3.4.1 `@CsServiceUnit` — CE-SU service unit

| Point | Contract |
|-------|----------|
| **1 Input** | `DataEntityEntry` (`DAENT`) — the unit set and its boundary. Consumed (`codespecs_mapping.md` §5.17): `DAENT-CLAS.aggregateRoot`, `DAENT-CLAS.serviceUnitAggregate`, `DAENT-CLAS.boundedContext`, and `DAENT-IDEN.entityName` as the value the first two resolve against. `BoundedContextEntry` (`BCE`) is the registry the third resolves against: `boundedContext` carries `refersTo: ['BCE.contextName']`, so the cap is a declared context and not a spelling. `ArchitectureComponentEntry` (`ARCM`) is a **secondary** input supplying the component narrative only — `codespecs_mapping.md` §8.5 records it as COVERED but **weak**, and nothing in this entry is derived from it. |
| **2 Output** | An **ordinary abstract class** carrying the framework's own service annotation beside the marker (test **b**). `tom_core_server` offers **two mutually exclusive** forms — `@tomService` and `@TomApiImplementation(apiId: …)` — and its endpoint pipeline rejects a class carrying both, so they are alternatives, never a pair. **The derivation emits `@tomService`**: `TomApiImplementation` is the registry-API-bound variant and its required `apiId` has no authoring SOM field, so emitting it would invent an argument (§2.8 C1). `codespecs_mapping.md` §5.6.2 records CE-SU as reuse with *no new class*. It **co-emits the CE-API handler methods** (§3.4.2), which is why slice 4 emits both together. **One class per distinct effective aggregate**, where an entity's effective aggregate is `DAENT-CLAS.serviceUnitAggregate` if set and `DAENT-CLAS.aggregateRoot` otherwise (`codespecs_mapping.md` §5.1) — so the unit set is a group-by over authored strings, and nothing in Phase 4 decides how many units exist. Its derived ownership lists — owned entities, repositories, operations — are materialised as `Type` literals and `CsOperationRef` consts, never re-authored: an entity is owned by the unit of its effective aggregate, and an operation by the unit of `SVOPE.primaryDataEntity`'s entity. |
| **3 Arguments** | `rootAggregate` (**required**) ← the unit's effective aggregate, as a **`Type` literal** — the CE-DB entity class (§3.3.1) generated for the `DAENT` whose `entityName` equals it. `boundedContext` (**required**) ← `DAENT-CLAS.boundedContext` of that root entity, verbatim — the `BCE.contextName` it references, copied character-for-character rather than re-cased, so two units in one context carry the identical string. Both are read off named fields, and both are *checked* references (`refersTo`): neither is inferred from lifecycle prose or relationship cardinality, per §2.4 **B8**. The unit id is **not** an argument — it is the class name (test **a**), fixed by §5.1 as `<RootAggregate>Service`. The process-cohesion adjustment is marked **D** (derived) in `codespecs_mapping.md` §5.17: it is authored in the SOM but reaches the code as *which* unit an entity landed in, not as a field on the marker. |
| **4 Naming** | PascalCase of the root aggregate's `DAENT-IDEN.entityName` + `Service`, per §5.1 — **not** of `ARCM`'s headline, so two documents naming the same aggregate cannot produce two unit names. N6 applies. |
| **5 Locus** | `server`. |
| **6 Cross-refs** | Emits `CsServiceUnitRef` (its own citable const). References entities and repositories by `Type`, operations by `CsOperationRef`. |
| **7 Back-link** | `@DocSpec([DocRef('DAENT', 'supplies the aggregate this service unit owns and names the bounded context that caps it'), DocRef('BCE', 'declares the bounded context that caps this service unit'), DocRef('ARCM', 'supplies the component narrative this service unit realises')])`. |

#### 3.4.2 `@CsEndpoint` — CE-API, server handler half

| Point | Contract |
|-------|----------|
| **1 Input** | The same `ServerOperationEntry` (`SVOPE`) as §3.2.1 — one section, two loci. Consumed here: `purpose` (the operation's behaviour, which becomes the stub explication), `primaryDataEntity` (which service unit the handler lands on — it names a `DAENT-IDEN.entityName`, and that entity's effective aggregate *is* the unit, §3.4.1, so the placement is two field reads and no judgment) and `errorCodes` (the `CsErrorCode` cross-refs below). |
| **2 Output** | A **handler method on the §3.4.1 service unit**, **form 3a**: real signature `Future<Result<T>> <op>(<Request> request)` over the shared CE-ER envelope (§3.1.2), body `throw UnsupportedError('<behaviour description>')`. 3a and not 3b because `SVOPE.purpose` is prose — the operation states *what* it does, and the SOM gives no ordered steps for *how*; the flow that reaches this handler is authored in ISC, on the client side (§3.5.5, §3.5.7). Routed by `TomEndpoint` / `TomEndpointHandler` / `TomEndpointRouting` / `TomServer` (`tom_core_server`). All operations are POST and only 5xx are transport errors (`codespecs_mapping.md` §7); an agent emitting a non-POST verb or a 4xx contract has violated it. |
| **3 Arguments** | `operation` — first positional, required, **the identical verbatim string** as the shared half's `CsOperationRef` (§3.2.1). A validator asserts the two match; they are one operation named once. |
| **4 Naming** | Method = camelCase of the operation name's last dotted segment (`customer.save` → `save`) — the unit already supplies the `customer` half, and repeating it would give `CustomerService.customerSave`. |
| **5 Locus** | `server` (§4.2: handlers). |
| **6 Cross-refs** | `CsOperationRef` (the shared const it realises); `Type` literals for the shared DTOs; one `CsErrorCode` per code in `SVOPE.errorCodes`. |
| **7 Back-link** | `@DocSpec([DocRef('SVOPE', 'supplies the operation behaviour this handler implements')])`. |

#### 3.4.3 `@CsAuthorize` — CE-AZ authorization requirement (modifier)

| Point | Contract |
|-------|----------|
| **1 Input** | `AuthorizationRequirementSpec` (`AZREQ`) — the one reusable closed choice, read from wherever the gated thing embeds it: `ServerOperationEntry.authorization` (`SVOPE`) for the operation-level case, the `access` member on the XDS screen / screen-element / navigation / tab / utility / deep-link / report / export sections for the field- and element-level cases. Consumed: `requirementKind` (which of the ten arms) plus that arm's payload subsection, and for the graded arm `GradedAuthorizationRequirement` (`AZGRD`) → its `GradedAccessLevelEntry` (`AZLVL`) level list. `RoleMatrix` (`ROMA`), `RolePermissionEntry` (`ROLPER`) and `EntitlementEntry` (`ENT`) are the **catalogues** the payload cites, not the requirement itself — they define what a role or entitlement *means*; `AZREQ` only names one. |
| **2 Output** | **No declaration of its own** — coding form 4, a modifier on the `@CsEndpoint` it gates (`codespecs_mapping.md` §5.6.3), or on a field for the field-level `authorizer` (slice 5). It feeds `TomEndpointHandler.checkAccess`, over the `TomAccessControl` family + `TomGradedAccess` + `TomPrincipal` (`tom_core_kernel`) and `TomResourceGrant` (`tom_core_server`). Slice 1 separately emits the **role and resource-key catalogues** into shared, since both sides cite them — §3.1.4 is their entry, including why holder and members are deliberately markerless. |
| **3 Arguments** | `requirement` (**required**) ← `AZREQ.requirementKind`, constant-for-constant onto `CsAuthRequirement {role, group, entitlement, resourceKey, custom, graded, none, public, authenticated, guest}` — `codespecs_mapping.md` §5.15's six requirement kinds plus its four attribute-less presets (`TomNoAccess`, `TomPublicAccess`, `TomAuthenticatedAccess`, `TomGuestAccess`) folded into one closed enum. **One constant is renamed across the boundary: SOM `denied` → `CsAuthRequirement.none`.** The SOM spells the deny preset `denied` because in an authored document "None" reads as *no authorization needed*, the exact fail-open misreading `codespecs_mapping.md` §5.16's fail-safe rule exists to prevent; the code side keeps `none` to match `TomNoAccess`. Required, and no arm is a default, on either side. Per-kind slots, only the declared kind's being non-null (§2.3), each read from that kind's `@Case` subsection: `roles: List<CsRoleRef>` ← `AZREQ-ROLE.roles` (→ `TomRoleAccess.roles`), `groups: List<String>` ← `AZREQ-GRUP.groups`, `entitlements: List<String>` ← `AZREQ-ENTL.patterns`, `resourceKey: CsResourceKeyRef` ← `AZREQ-RKEY.resourceKey`, `handler` + `resourceId: String` ← `AZREQ-CUST`, and `graded: CsGradedAccess` ← `AZGRD`. The graded slot is a nested facet value class holding the three slots `full` / `read` / `disabled`, filled by matching each `AZLVL` entry's `accessLevel` to its slot and lowering that entry's own kind + payload into a nested `@CsAuthorize` by the same rules. Because `AZLVL` ranges over the nine-constant `BasicAuthorizationRequirementKind`, **a nested slot's `requirement` is never `graded`** — the SOM bounds the depth structurally (`codespecs_mapping.md` §5.15) and §6 check 21 holds the code side to the same bound. An omitted level is not an omitted requirement: the four states `none < disabled < read < full` and the monotonic defaults `read ⇐ full`, `disabled ⇐ read` are **derived**, not authored, so authoring only `full` is the common and correct case. |
| **4 Naming** | None — the modifier has no identifier. Catalogue consts are named by N9 over the role / resource-key name. |
| **5 Locus** | `server` for operation-level; `client` for the field-level `authorizer` (slice 5); the **catalogues** are `shared` (§4.2). |
| **6 Cross-refs** | `CsRoleRef`, `CsResourceKeyRef`. Groups and entitlement patterns stay strings — they name external directory objects, not generated declarations. |
| **7 Back-link** | `@DocSpec([DocRef('AZREQ', 'supplies the requirement this operation is gated by')])` — the section that *authored* the requirement, always `AZREQ` regardless of arm, since that is the one editable place a reader must reach to change the gate. The graded arm adds `DocRef('AZGRD', 'supplies the per-level requirements')`. The catalogues (`ROMA` / `ROLPER` / `ENT`) are not back-linked from here: they are reached through the `CsRoleRef` / `CsResourceKeyRef` consts, which carry their own back-links. |

#### 3.4.4 `@CsAuth` — CE-AU server flow + CE-ID population

| Point | Contract |
|-------|----------|
| **1 Input** | `LoginFlowStepEntry` (`LGFLS`) for the flow; `UserAttributeEntry` (`USATE`) for which attributes are populated into which token half; `UserLifecycleTransitionEntry` (`ULTRE`) for the account state transitions; `MfaConfiguration` (`MC`) for the second-factor policy. |
| **2 Output** | The app's `TomAuthenticationService` bound into `TomAuthenticationServer`, issuing `TomServerJwtToken` (`tom_core_server`), **form 1 + form 3b** — `LGFLS` is an ordered step list, which is 3b's trigger (§2.4): the flow method's body is a statement sequence derived by **§2.4's B1–B6** over those steps. B1 orders it by the list rather than by `stepOrder`; each step with behaviour text contributes one call (B2, B3); a step whose `LFSEB.conditionalTrigger` states a condition is wrapped in place in its own guard `if` (B4, B5's last sentence). Its abstract collaborator is emitted per §3.0.1, and the flow method resolves its calls against the `collaborator` field that entry injects. A flow whose `LGFLS` is empty falls back to form 3a. The **CE-ID population** is part of this flow: it projects the §3.2.5 identity declaration into the public (`TomUser.attributes`) and encrypted (`TomPrincipal.currentContext`) halves, per each attribute's `placement`. CE-AU consumes CE-ID; it never redeclares it.<br>**`MC` emits a second marked declaration**: the deployment's `Tom2FAPolicy` binding, as a `TomRole2FAPolicy` instantiation. `mfaRequired` + `mfaEnforcementScope` become `requirementByRole` / `defaultRequirement` over `Tom2FARequirement {disabled, optional, required}`; `defaultSecondFactor` + `allowedSecondFactors` become the ordered `mechanisms` list, the default first; `enrollmentGracePeriod` becomes `graceLogins`. Form 1 — the constructor call is the whole declaration, so there is no stub body. `mfaRequired: No` emits no policy declaration at all: the framework default is `TomPrincipalFlag2FAPolicy`. |
| **3 Arguments** | None — `@CsAuth` stays note-only, on a different §2.3 ground per group. The **method/flow set** is test **a**: one marked declaration each, so the set of declarations *is* the enabled set. The **second-factor policy** is test **b**: requirement level, mechanism preference order and grace count are `TomRole2FAPolicy`'s own constructor parameters, which is why `MC` emits a further declaration rather than arguments on the first. Whether declining an enrolment offer is allowed is authorable **nowhere**: `TomAuthenticationServer` derives `twoFactorEnrolmentSkippable` as *optional-or-on-grace*, so a spec-authored flag would be recomputed and overwritten. |
| **4 Naming** | PascalCase of `ATME`'s name field + `AuthenticationService`; the policy declaration is the app name + `TwoFactorPolicy`. |
| **5 Locus** | `server`. |
| **6 Cross-refs** | `CsOperationRef` (the login operation); `Type` literal for the identity declaration; `CsRoleRef` where a flow step grants a role, and for each key of the policy's `requirementByRole`. |
| **7 Back-link** | `@DocSpec([DocRef('LGFLS', 'supplies the flow step this method performs'), DocRef('USATE', 'supplies the attribute projected into the token')])`; the policy declaration carries `@DocSpec([DocRef('MC', 'supplies the second-factor requirement, the offered mechanisms in preference order and the enrolment grace')])`. |

### 3.5 Slice 5 — client interaction core

Cites slices 1 and 2 **and never 3 or 4**: the client project depends on shared
only. The six parts CE-ST, CE-EL, CE-FM, CE-AC, CE-SC, CE-NV form `codespecs_mapping.md` §4.4.1's
**SCC-B** — they reference each other cyclically and are therefore emitted as one
unit, which is why they share a slice rather than an order. An agent authoring
them writes the component in the two passes of `codespecs_mapping.md` §4.4.7 —
every declaration first, the intra-component `Cs*Ref` consts second — because a
component admits no order in which each reference follows its referent.

#### 3.5.1 `@CsViewModel` — CE-ST view state

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenStateEntry` (`SCRST`), `ScreenElementDataDisplay` (`SEDD`), `ComponentStateEntry` (`COMSTA`), plus `BusinessObjectAttributeEntry` (`BIOBAT`, itself `@CodeSpecKind([viewState])`) with its detail `BOAED` for the attribute a field mirrors. Consumed (§5.4): the fields as `(name, T, kind)`, their derivation, their binding, the lifecycle scope, and `BOAED.mandatory` for the field's requirement level. |
| **2 Output** | A view-model class holding `TomObservable` / `TomObject<T>` members — `TomString`, `TomInt`, `TomDouble`, `TomBool`, `TomClass`, `TomList`, `TomMap` (`tom_core_kernel`) — bound in the UI by `TomObservingWidget` / `ValueListenableObserver` (`tom_core_flutter`). Form 1. **An optional field emits the nullable arm of the same family** — `TomNString`, `TomNInt`, `TomNDouble`, `TomNBool`, `TomNDateTime`, initialised to `null` — keyed on `BOAED.mandatory` (`Optional` / `ConditionallyRequired` → nullable, `Required` → the non-nullable type). **Not** on CE-DB's `DATAA.nullable`: what a screen may leave blank is a requirement level, and a field over an attribute the table happens to store as `NULL` may still be mandatory to fill in. **Observable fields are initialised declarations** (`final TomString name = TomString('');`, `final TomNString note = TomNString(null);`) — §2.4's sole exception, because an uninitialised observable would not compile at its use sites. Derived fields are **form-3a** getters that throw — a derivation is stated as prose, so there are no steps to sequence. |
| **3 Arguments** | `scope` ← the lifecycle scope, enum-mapped onto `CsLifecycleScope {screen, route, app}`, default `screen` — the narrowest arm, so widening a view model's lifetime is a deliberate act. Fields, their types and their binding are the declaration (test **a**); binding to a widget is `TomObservingWidget`'s own surface (test **b**). |
| **4 Naming** | PascalCase of `SCRST.stateId` (its designated name field — the machine symbol; the entry headline names the state for people) + `ViewModel`; members camelCase of their own name field. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | Referenced **by** `CsTrigger`'s condition kind (its predicate reads these fields). Emits none. |
| **7 Back-link** | `@DocSpec([DocRef('SCRST', 'supplies the view state this model holds')])`, plus `SEDD` / `COMSTA` per contributing field, and `DocRef('BOAED', …)` on a field whose requirement level chose its nullable arm. |

#### 3.5.2 `@CsElement` — CE-EL semantic element

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenElementEntry` (`SCREL`), `UiComponentEntry` (`UICOM`), `ComponentVariantEntry` (`CVE`). Consumed (`codespecs_mapping.md` §5.18 field base): element id, semantic kind, value type; the N-marked rows (initial value, label/hint, validators, authorization, auto-validate) come from other parts and are **not** consumed here. |
| **2 Output** | A **standalone element declaration** built on the `Tom*` element family through `TomScreenElementsProvider` (`tom_flutter_ui`), form 1. The element id rides `TomField.tomId` (test **b**). Elements that are *members of a form* are emitted by CE-FM instead (`codespecs_mapping.md` §5.7.2): `@CsElement` proper covers standalone elements.<br>**A `choice` / `multiChoice` element additionally emits its option source**, never a literal `TomSelectableSource`: `TomEnumSelectableSource<E>` when the bound member is enum-typed, `TomEnumNameSelectableSource<E>` when it stores `Enum.name` in a `TomString` — the shape a reflected, JSON-carried domain class takes (`tom_flutter_ui` `forms/selection/tom_enum_selectable_source.dart`). This is what makes each option label resolve through `TomTextResourceProvider` (`codespecs_mapping.md` §5.18) and what makes §2.3 test **b** hold for value labels: the substrate carries the resolution, so no annotation argument does.<br>**It is constructed in the element's own field initializer** — inside the owning `@CsForm` class for a form member, at the element declaration for a standalone one. The source captures `TomScope.current` **at construction** and resolves labels later, inside Flutter builder callbacks that run outside the zone which installed the scope; initializing it with the element puts the capture in the same ambient scope the element's `basePath` resolves in, whereas building it lazily inside a builder would capture whatever scope is current *then*. Where the bound member is a `TomObservableEnum`, `TomEnumSelectableSource.of(cell)` is emitted instead, so cell and picker resolve in one scope by construction rather than by coincidence. |
| **3 Arguments** | `kind` (**required**) ← the semantic kind, enum-mapped onto `CsElementKind {textInput, number, toggle, dateInput, choice, multiChoice, fileInput, label, button, menuEntry, formHost}` — `codespecs_mapping.md` §5.18's closed eleven-kind catalogue, by the **stated total disposition below this table**, never by resemblance. Required because it selects the per-kind attribute set and the default widget; no kind is a sensible default. The value type `T` is the declaration's generic (test **a**); every per-kind extra (`maxLength`, `keyboardType`, `maxLines`, `obscureText`, `variant`, `icon`, `allowedExtensions`, `maxSizeBytes`, `pickKind`, `autoUpload`, …) maps onto a named `tom_flutter_ui` widget property and is therefore carried by the `@CsWidget` instantiation (test **b**), never duplicated here — `fileInput`'s `presentation` included, since like `button`'s `variant` it selects the concrete (`TomFormFileUpload` / `TomFormFileDropzone` / `TomFormFileThumbnail`) rather than configuring one. A SOM field kind with no arm in the catalogue is **not** an error — a **colour value** is resolved *before* this mapping runs (`codespecs_mapping.md` §5.18): free entry becomes `textInput` plus a CE-VA pattern rule, a closed palette becomes `choice` whose source is the token catalogue, so `kind` never sees a colour. |
| **4 Naming** | camelCase of `SCREL`'s element-id field. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsMessageKey` for catalogued label/hint copy; `CsResourceKeyRef` via its field-level `@CsAuthorize`. A `choice`'s **option labels are cited by nothing** — they are derived copy resolved by the emitted source (point 2), so no `CsMessageKey` names them. Its **action edge is a derived back-reference** (`codespecs_mapping.md` §5.18) — read off the triggers, never authored here. Emits `CsElementRef` (§2.6). |
| **7 Back-link** | `@DocSpec([DocRef('SCREL', 'supplies the element, its semantic kind and its value type')])`. |

**The kind mapping is total and stated.** "Enum-mapped" in point 3 is this
disposition, not a judgment call: every constant of the SOM's two closed source
enums has exactly one stated outcome, so two agents mapping the same
specification emit the same kind — or the same *absence* of one, since three
dispositions route a constant away from `@CsElement` entirely, the same
pre-mapping resolution the colour rule already performs.

For a **standalone element**, `SCREL.elementType` (`ScreenElementKind`, 19
constants) disposes as:

| `ScreenElementKind` | Disposition |
|---------------------|-------------|
| `textField` | `CsElementKind.textInput` |
| `numberField` | `CsElementKind.number` |
| `dateField` | `CsElementKind.dateInput` |
| `selectField` | `CsElementKind.choice`; `CsElementKind.multiChoice` when its field spec's select options state `Multi` (`SEFSS.selectMode`) |
| `checkbox`, `toggle` | `CsElementKind.toggle` — one semantic kind, two presentations; the widget (§3.5.3) carries the difference |
| `actionButton` | `CsElementKind.button` |
| `link` | `CsElementKind.button` — a link is an action affordance; the link presentation is the widget's variant (§3.5.3), the same pattern as `button`'s other variants |
| `label` | `CsElementKind.label` |
| `dataDisplay`, `dataTable`, `card`, `chart`, `statusIndicator`, `icon`, `image`, `badge` | **No `@CsElement`.** A display-kind element carries no value — its `SEDD` data-display case is routed to `CodeSpecPart.viewState` by the model itself, so its state lands on the §3.5.1 view model and its rendering on the §3.5.3 widget bound to it. |
| `divider`, `spacer`, `tabBar` | **No `@CsElement`.** The structural kinds are the `@OneOf`'s `noCase` list — they carry no case payload at all and are layout nodes, emitted by CE-LO (§3.5.9). |

For a **form member** (emitted by CE-FM, §3.5.4), `SEFS.dataType`
(`ScreenElementFieldKind`, 16 constants) disposes as:

| `ScreenElementFieldKind` | Disposition |
|--------------------------|-------------|
| `string`, `richText` | `CsElementKind.textInput` — the rich-text editor is a widget choice (§3.5.3) |
| `email`, `phone`, `url`, `password` | `CsElementKind.textInput` **plus** a CE-VA format rule for the first three — the format is validation, not a kind; `password`'s obscuring is the widget's `obscureText` (test **b**) |
| `integer`, `decimal`, `currency` | `CsElementKind.number` |
| `date`, `dateTime`, `time` | `CsElementKind.dateInput` |
| `boolean` | `CsElementKind.toggle` |
| `enumeration` | `CsElementKind.choice`; `CsElementKind.multiChoice` when `SEFSS.selectMode` states `Multi` |
| `file` | `CsElementKind.fileInput` |
| `color` | resolved **before** the mapping runs (point 3's colour rule): free entry → `textInput` + CE-VA pattern rule, closed palette → `choice` over the token catalogue |

`formHost` and `menuEntry` have no source constant here by design: a form host
is emitted where a screen embeds a `@CsForm`, and a menu entry where a
navigation or utility section authors an action in a menu — both arrive from
their owning structures, not from an element kind an author picks.

#### 3.5.3 `@CsWidget` — CE-EL concrete widget

| Point | Contract |
|-------|----------|
| **1 Input** | The same `SCREL` / `UICOM` / `CVE` sections as §3.5.2, plus `ComponentVariantEntry` (`CVE`) for a non-default widget choice. |
| **2 Output** | The **concrete `tom_flutter_ui` widget instantiation** realising the semantic kind — `TomTextField` for `textInput`, a `TomButtonBase` variant for `button`, and so on down `codespecs_mapping.md` §5.18's per-kind table. Form 1. This is step two of `codespecs_mapping.md` §5.7.1's two-step semantic → widget derivation: the kind is the spec, the widget is the realisation. |
| **3 Arguments** | None; `@CsWidget({String? note})` unchanged. Every per-kind attribute is a named parameter of the widget constructor (test **b**) — which is the whole reason the two-step split exists: it lets the spec stay at the semantic level while the code stays typed. |
| **4 Naming** | None of its own — the marker sits on the element's widget member. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsMessageKey` for its copy. |
| **7 Back-link** | Covered by the element's `@DocSpec`; `DocRef('CVE', 'selects the widget variant')` is appended when a variant entry chose a non-default widget. |

#### 3.5.4 `@CsForm` — CE-FM form

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenElementFieldSpec` (`SEFS`). Consumed: the form/subform tree **and its member input elements** — `codespecs_mapping.md` §5.7.2 gives CE-FM ownership of both, which is what distinguishes it from §3.5.2. |
| **2 Output** | A `TomForm<T>` subclass with `TomFormChildContainer` for subforms and `TomField<T>` members (`tom_flutter_ui`), form 1. It mirrors the SOM `@Form` field-group one-for-one — a form section and a form class are the same shape at two resolutions. Member fields carry their own `@CsElement` + `@CsWidget` markers, their kind fixed by §3.5.2's form-member disposition over `SEFS.dataType`.<br>**The value type `T` is emitted with the form.** `TomForm<T extends TomClass>` requires a value class, and no authored section supplies one — the CE-DB entity cannot serve: it is server-locus (§4.2), and a client form may not reference it. So the derivation emits a companion `TomClass` subclass beside the form, one field per form member, each typed by the same §3.5.2 form-member disposition over `SEFS.dataType` that fixed the member's element kind — the one field list read twice, once as input elements and once as values, so the two cannot disagree. The companion is form 1 with no marker of its own: it is part of CE-FM's output, not a separate part. |
| **3 Arguments** | None; `@CsForm({String? note})` unchanged. The field list, the subform tree and the form's value type are the declaration (test **a**); everything else `TomForm` takes is its own constructor (test **b**). |
| **4 Naming** | PascalCase of `SEFS`'s name field + `Form`; the companion value type is the same PascalCase name + `Value`, so the pair reads as what it is (`OrderCaptureForm` / `OrderCaptureValue`) and neither collides with the other under N4. |
| **5 Locus** | `client` — the companion value type included. |
| **6 Cross-refs** | Emits `CsFormRef` (§2.6). Cites `CsMessageKey` for copy and its `@CsFormRule` methods for cross-field invariants. |
| **7 Back-link** | `@DocSpec([DocRef('SEFS', 'supplies the form, its subform tree and its fields')])`. The companion value type carries the same back-link — it is derived from the same field list, and a reader tracing either class lands on the same section. |

#### 3.5.5 `@CsAction` — CE-AC action

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenActionEntry` (`SCRAC`), `ScreenElementAction` (`SCELAC`), and the ISC step entries `MNSST` / `ALST` / `EXTST` / `SCNST`. Consumed (`codespecs_mapping.md` §5.20): action id, owning controller, context requirement `TContext`. |
| **2 Output** | A `TomAction` on a `TomActionController`, with `TomActionTransaction` / `TomActionContext` as needed (`tom_flutter_ui`) — **form 1 for the declaration, form 3b for `perform`**. The ISC step entries in point 1 are an ordered step list, so the action's body is a statement sequence derived by **§2.4's B1–B6** over them: the `MNSST` / `SCNST` steps in list order, one call each (B1–B3), then one guarded block per `EXTEN` / `ALFL` branch flow holding that flow's `EXTST` / `ALST` steps (B4–B6). The calls go to the abstract collaborator of §3.0.1, which the owning controller injects as its one `collaborator` field — one collaborator for every action the controller carries. An action with no contributing ISC step falls back to **form 3a** over `SCRAC`'s description. Declared as a named member, since N9 makes the **declaration name** the action's identity. |
| **3 Arguments** | None; `@CsAction({String? note})` unchanged. The action id is the declaration name (test **a**, and what `CsActionRef` resolves against); the owning controller is the declaration site; `TContext` is the generic. `codespecs_mapping.md` §5.20 marks undoable/`TUndo`, transaction grouping, authorization, copy and the server-bound edge as **N** — the first three are `TomAction`'s own surface, copy is CE-TX, and the server edge is derived from the trigger. |
| **4 Naming** | camelCase of `SCRAC`'s action-id field; the owning declaration is PascalCase of `SCRAC`'s owning-controller field + `ActionController`. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | Emits `CsActionRef`. Cites `CsCallRef` where the action is server-bound — **derived from the trigger**, never authored twice. |
| **7 Back-link** | `@DocSpec([DocRef('SCRAC', 'supplies the action and its context requirement')])`, plus one `DocRef` per contributing ISC step and one per branch flow the body guards on. |

#### 3.5.6 `@CsTrigger` — CE-AC trigger

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenElementAction` (`SCELAC`) and the ISC step entries. The trigger is the **single authoring home of the element→action edge** (`codespecs_mapping.md` §5.10): it names both endpoints, and the element's action edge is derived from it. |
| **2 Output** | A `TomActionTrigger` (`tom_flutter_ui`) instantiation, form 1. One action may carry several triggers of different kinds. |
| **3 Arguments** | `kind` (**required**, unchanged) ← `CsTriggerKind {userGesture, inFormEvent, lifecycle, serverEvent, condition}`; it selects which per-kind attribute set applies, so it cannot be inferred and no arm is a default. **Added by this contract:** `action: CsActionRef` (**required**) — the common head's target endpoint; then one optional slot per kind (§2.3), validated so only the declared kind's are non-null: `element: CsElementRef` + `gesture: CsGesture {tap, press, longPress}` for `userGesture`; `form: CsFormRef` + `formEvent: CsFormEvent {fieldChange, submit, validationPass, validationFail}` + `formField: CsElementRef` for `inFormEvent`; `scope: CsLifecycleScope` + `phase: CsLifecyclePhase {enter, leave, init, dispose}` for `lifecycle`; `channel` + `eventType: String` for `serverEvent`. The `condition` kind carries **no** slot: its predicate over CE-ST state is real Dart, so it is a closure the `TomActionTrigger` constructor takes (test **b**) — as is the optional guard on every kind. |
| **4 Naming** | camelCase of the action name + the kind (`saveOnTap`, `saveOnSubmit`), so several triggers on one action cannot collide under N4. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsActionRef`, `CsElementRef`, `CsFormRef`. Endpoints are typed references to the generated declarations, never id strings (`codespecs_mapping.md` §5.10) — which is why the `codespecs_mapping.md` §5.23 family carries `CsElementRef` / `CsFormRef` at all. |
| **7 Back-link** | `@DocSpec([DocRef('SCELAC', 'supplies the invocation path and the action it fires')])`. |

#### 3.5.7 `@CsServerCall` — CE-SC server call

| Point | Contract |
|-------|----------|
| **1 Input** | The ISC step entries `MNSST` / `ALST` / `EXTST` / `SCNST`, and the `ServerCallStepEntry` (`SVCST`) list each of them carries. Consumed (`codespecs_mapping.md` §5.3): the step's `serverOperation` field — the authored citation of `SVOPE.operationName` that names the operation called — plus request assembly, response handling, error handling and call options. **`serverOperation` is also the emission condition:** it is optional, and a step that leaves it empty reaches no server, so `@CsServerCall` is emitted for exactly the steps that carry it. Which steps call the server is therefore read off a member rather than classified from `systemResponse` wording. |
| **2 Output** | A `TomServerEndpoint<T, R>` call over `TomServerCallSpecs` / `TomServerChannel` (`tom_core_kernel`), **form 1 + form 3b**. Request assembly, response handling and error handling are three methods, and each derives from the steps routed to it.<br>**3b on §2.4's structural selector, because the roles are three ordered step lists.** A `@CsServerCall` is derived from the **one** ISC step whose behaviour states the call — which is what point 7's first back-link says — but the call's *handling* is stated by that step's `SVCST` list, whose **required** `role` field (`ServerCallRole {assembleRequest, handleResponse, handleError}`) says which of the three bodies each step belongs to. Each body reads its own role's steps in document order (B1), emits one statement per step (B2) with the last carrying the result (B3), and reifies a stated `condition` as a guard (B4). The routing is read off a field, so nothing here splits one sentence three ways — which is what B8 forbids.<br>**The three values of `ServerCallRole` are spelled as the three method names of point 4.** The routing word and the emitted identifier are the same token, so renaming one is renaming the other and they cannot drift.<br>**§2.4's fallback applies per body.** A role with no `SVCST` steps has an empty step source and emits 3a over the issuing step's own behaviour text. A call whose issuing step lists no steps at all therefore emits 3a in all three bodies, and no collaborator (§3.0).<br>This is the middle hop of §5.3's chain: `@CsAction ──triggers──▶ @CsServerCall ──operation──▶ @CsEndpoint` (client / client / shared). |
| **3 Arguments** | `operation` — **first positional, required** ← the `CsOperationRef` const of the shared operation it calls, taken from the issuing step's `serverOperation` field (point 1) and resolved to the `@CsEndpoint` that `SVOPE.operationName` names. It is the one edge the code cannot carry itself: the call site is client, the operation is shared, and nothing in the Dart declaration names the link — so it is required here, and it has an authored source rather than being recovered from the step's prose (§2.4 **B8**). Call options are `TomServerCallSpecs`'s own surface (test **b**); the three handling steps are the methods (test **a**). |
| **4 Naming** | camelCase of the operation name's last segment + `Call`; its three bodies are `assembleRequest`, `handleResponse` and `handleError`, fixed names since the three roles are the entry's, not the spec's — and `SVCST.role`'s three values are those same three words, so a step names its body rather than describing it. The collaborator §3.0.1 names takes that identifier **PascalCased**, plus `Collaborator` (`SubmitOrderCallCollaborator`): this declaration's identifier is camelCase where §3.0.1's other four owners are already PascalCase, and a class name is PascalCase in every locus. Its methods follow §3.0.1 unchanged — the calling body's identifier, then the step's headline (`handleErrorSurfaceTheRejectionToTheUser`), so two steps of different roles cannot collide however alike their headlines. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsOperationRef` outbound; emits `CsCallRef` for the action edge. Cites `CsErrorCode` for each error it handles. |
| **7 Back-link** | `@DocSpec([DocRef('MNSST', 'supplies the interaction step this call performs')])` — `ALST` / `EXTST` / `SCNST` substituted when the issuing step is of that kind. Each 3b body additionally carries `DocRef('SVCST', 'supplies a step of this call\'s <role>')` for the steps it took statements from — the calling entry back-links a step for its **position**, the collaborator method for its **behaviour**, which is the two-edges-out-of-one-source case §3.0.1 states. |

#### 3.5.8 `@CsRoute` — CE-NV route

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenRouteEntry` (`SCRTEN`) under `SCRTMP` (D09 XDS). `codespecs_mapping.md` §5.11 maps the three registries 1:1, and this is the first: route entries → `TomRouteDefinition`. |
| **2 Output** | A route declaration built on `TomPageRoute<T>` with `TomNavigationDestination` (`tom_flutter_ui`), registered in the route-id registry `TomRouteDefinition` — a `tom_core_codespecs` **gap class**, because the substrate has no stable route id of its own. Form 1, and the declaration shape is a **top-level `final` variable**:<br>`final TomRouteDefinition orderWorkListRoute = TomRouteDefinition(routeId: 'order-work-list', path: '/orders');`<br>`final` and not `const` because `TomRouteDefinition` is deliberately mutable (non-final fields, non-const constructor — Phase 6 wires builders onto it), so `const` is unavailable; and a top-level variable rather than a holder member because a route is a *declaration in its own right* — it carries its own `@CodeSpec` / `@DocSpec` / `@CsRoute`, which a `static const`-style member of a holder could not do per emission unit. All of a document's routes share one file (point 4). |
| **3 Arguments** | None; `@CsRoute({String? note})` unchanged. The route id and its parameters ride `TomRouteDefinition`'s constructor (test **b**), and the route id itself is an authored key taken verbatim (N5). |
| **4 Naming** | camelCase of `SCRTEN`'s route-id field + `Route`. File: N7's catalogue-file rule — every route of a document lands in `lib/src/navigation/navigation_catalog.dart`, the CE-NV catalogue file, each route a separate top-level declaration within it. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | Emits `CsRouteRef`. Cites the form it presents by `CsFormRef`. |
| **7 Back-link** | `@DocSpec([DocRef('SCRTEN', 'supplies the route and its stable id')])`. |

#### 3.5.9 `@CsScreenFlow` — CE-NV screen flow

| Point | Contract |
|-------|----------|
| **1 Input** | `FormScreenAssignmentEntry` (`FMSCAS`) and `ScreenTransitionEntry` (`SCTREN`), both under `SCRTMP` — `codespecs_mapping.md` §5.11's second and third 1:1 mappings. Consumed: which form a screen presents and whether it replaces or overlays; which action fires an edge and which outcome selects its target. |
| **2 Output** | `TomFormScreenAssignment` and `TomScreenFlowEdge` instantiations (`tom_core_codespecs` **gap classes**, §4.1), form 1. Where `@CsRoute` names *a* screen, this records the edges that combine the D05 ISC scenarios into interactions with screens. |
| **3 Arguments** | None; `@CsScreenFlow({String? note})` unchanged. Both gap classes carry the full surface on their constructors (test **b**): `ScreenPresentationMode {replace, popupOverlay}`, `ScreenFlowOutcome {success, error, validationError}`, and the `outcomeReference` that joins to `SYERCO` (CE-ER) or `VMT` (CE-VA). Adding the same values as marker arguments would create the second, disagreeing source §2.3 exists to prevent. |
| **4 Naming** | Assignment = camelCase of the route name + `FormAssignment`; edge = camelCase of the action name + the outcome (`saveOnSuccess`). |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsRouteRef` (both endpoints), `CsFormRef` (the presented form), `CsActionRef` (the firing action), and `CsErrorCode` / `CsMessageKey` for the `outcomeReference`. |
| **7 Back-link** | `@DocSpec([DocRef('FMSCAS', 'assigns the form to the screen and its presentation mode')])` or `DocRef('SCTREN', 'supplies the transition, its firing action and its outcome')`. |

#### 3.5.10 `@CsAuth` — CE-AU, client login flow half

| Point | Contract |
|-------|----------|
| **1 Input** | `LoginFlowStepEntry` (`LGFLS`), read **per client** — `codespecs_mapping.md` §5.25 makes the login flow a per-client decision, so one client's flow is not another's. `MfaConfiguration` (`MC`) where the client must run a second factor. |
| **2 Output** | The client's login flow over the `TomServerEndpoint<TomAuthenticationMessage, TomAuthenticationResult>` triple (`tom_core_kernel`), **form 3b** — `LGFLS` is an ordered step list, so the flow body is a statement sequence over this client's steps derived by **§2.4's B1–B6**, exactly as §3.4.4's server half derives its own, calling the abstract collaborator §3.0.1 emits for this declaration. The two halves read the same step list and produce different bodies only because they run different clients' steps. A client whose `LGFLS` is empty falls back to **form 3a**.<br>Where `MC` enables a second factor, a **`Tom2FAFlowController` implementation** (`tom_core_flutter`) is emitted beside it, **form 3a** — its five moves (choose, confirm, skip, answer, cancel) over the client's own auth calls. 3a and not 3b: `MC` is a policy, not a step list, so the moves are declared and their behaviour stated, not sequenced. The panel itself is not emitted: `Tom2FAFlowPanel` owns the chooser, attempt counter, error line and skip affordance invariantly, and the skip affordance renders off `twoFactorEnrolmentSkippable` rather than off anything the spec declares. Per-mechanism UI is one `Tom2FAClientMechanism` registration each, emitted only for a mechanism `allowedSecondFactors` names that the framework does not already ship (`TomTotp2FAClientMechanism` is shipped). |
| **3 Arguments** | None (as §3.2.7 and §3.4.4). The controller carries no marker arguments either: its five moves are its method signatures (test **a**), and which mechanisms it may offer arrives on the wire in `availableTwoFactorMethods` rather than being authored a second time here. |
| **4 Naming** | PascalCase of the client name + `LoginFlow`; the controller is the client name + `TwoFactorFlowController`. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsOperationRef` (the login operation), `CsRouteRef` (where the flow lands), `CsErrorCode` (failure outcomes). |
| **7 Back-link** | `@DocSpec([DocRef('LGFLS', 'supplies the login step this method performs')])`; the controller carries `@DocSpec([DocRef('MC', 'supplies the second-factor mechanisms this client offers')])`. |

### 3.6 Slice 6 — client presentation & shell

Cites slice 5 (and 1). Nothing here is referenced by an earlier slice.

#### 3.6.1 `@CsLayout` — CE-LO layout node

| Point | Contract |
|-------|----------|
| **1 Input** | `ScreenSectionEntry` (`SCRSC`), `ScreenResponsiveRuleEntry` (`SCRERU`), `ComponentSlotEntry` (`CMSL`). Consumed (§5.2, `codespecs_mapping.md` §5.22): the container tree, its kinds, the slot hints, and the override deltas. |
| **2 Output** | Two layers, both id-addressed. The **base** is an `AclContainer` / `AclRow` / `AclFlowContainer` / `AclComponent` tree (`tom_flutter_ui`) rendered through `TomObservingWidget`; when the SOM authors no explicit layout, the default base is **a single `column` of the form's fields in SOM order** — never an empty tree. The **override layer** is a delta list over `codespecs_mapping.md` §5.22's closed five-op grammar: `reparent`, `set-container-prop`, `set-slot-hint`, `insert-container`, `remove-container`. Generated rows are addressable as `<containerId>.r<n>`. |
| **3 Arguments** | `nodeId` — **first positional, required** ← the section's node id, verbatim. It is the one thing the substrate genuinely lacks: §4.1 records the layout **node model** as a gap, the ACL classes carry no id, and the whole override-delta grammar addresses nodes by id. Container kind is **not** an argument — it is which Acl class is instantiated (test **b**); slot hints are `AclComponent` properties (test **b**). |
| **4 Naming** | Node ids are authored (N5). The generated Dart holder is PascalCase of `SCRSC`'s name field + `Layout`. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | `CsElementRef` / `CsFormRef` for the elements a slot hosts. Deltas address nodes by **id string**, which is not a `codespecs_mapping.md` §5.23 violation: a delta targets a node *within the same layout declaration*, so the id is a local coordinate, not a cross-part reference. |
| **7 Back-link** | `@DocSpec([DocRef('SCRSC', 'supplies the container tree this layout arranges')])`, plus `SCRERU` per responsive delta and `CMSL` per slot. |

#### 3.6.2 `@CsClient` — CE-CL client application

| Point | Contract |
|-------|----------|
| **1 Input** | One `ClientApplicationEntry` **CLIAPP** — an entry of the client-application list under `ClientRequirementsSection` CLRESE (D06 ATS). `clientId` and `clientName` give the identity, `clientKind` the kind, `platformTargets` / `entryRoute` / `includedScreens` the three reference-by-id sets. `purpose` is the reason the client exists: it is CLIAPP's designated description field, so it is the §2.8 P1 summary and not a member. |
| **2 Output** | A **client descriptor** — a class extending `TomClientApplication` (`tom_core_codespecs`, `client_application.dart`), setting `clientId` / `displayName` / `platforms` / `entryRoute` / `screenIds` in its constructor. `serverBaseUrl` is **not** emitted: the descriptor's own doc records it as wired by CE-CC at runtime, so a generated literal would be a second, staler source. |
| **3 Arguments** | `clientId` ← CLIAPP `clientId`, **first positional, required**, verbatim (N5). `kind` (**required**) ← CLIAPP `clientKind`, mapped arm-for-arm onto `CsClientKind`: `graphicalApplication → flutterApp`, `commandLine → cli`, `server → server`. The names differ **by design** — the SOM keeps `codespecs_mapping.md` §1.2's neutral vocabulary and names no framework, and the technology choice is exactly the deeper CodeSpecs level the mapping adds. Required because the kind decides which other parts the client can carry (a CLI has no CE-EL) and defaulting it would silently admit impossible combinations. Platforms, entry route and screens are members of the descriptor (test **a**). |
| **4 Naming** | PascalCase of the client id + `Client`. |
| **5 Locus** | `client`. A multi-client system generates one client project per `@CsClient`; the descriptor names which. |
| **6 Cross-refs** | `CsRouteRef` for its entry route, from CLIAPP `entryRoute` (a `SCRTEN.routeId`). `includedScreens` lowers onto `screenIds` as plain screen ids — `codespecs_mapping.md` §5.23 has no screen ref type, and the ids are already resolved against `SCREN.@sectionId` at authoring time. `platformTargets` lowers onto `platforms` verbatim; the ids resolve against the three requirement registries (`BROREQ.browserName`, `DEOSRE.osName`, `MODERE.platform`) in the same section, so the minimum a platform must meet is stated once and referenced, never restated. Referenced **by** CE-CC (a `CCSET` setting names its owning client) and CE-AU (per-client login flow). |
| **7 Back-link** | `@DocSpec([DocRef('CLIAPP', 'supplies the client application, its kind, platform targets, entry route and screens')])`. |

#### 3.6.3 `@CsClientConfig` — CE-CC client configuration

| Point | Contract |
|-------|----------|
| **1 Input** | `ClientConfigurationSettingEntry` (`CCSET`), the declaration list under `ClientConfiguration` (`CLICON`) — keyed by **(client app, machine)**, no user in the key, which is the discriminator against CE-DS (`codespecs_mapping.md` §5.16). The client half of that key is `CCSET`'s `client`, a `CLIAPP.clientId`; it groups the settings into one holder per client, and is the reason the owning client is stated on the **setting** rather than listed on the client (a setting belongs to one client, a client to many settings). Empty where the system has a single client. |
| **2 Output** | A configuration holder built on `TomBaseClientConfiguration` + `TomSetting<T>` + `TomClientConfigurationStore` (`tom_core_flutter`) over `TomConfigResourceProvider` (`tom_core_kernel`), form 2, one marked member per setting. |
| **3 Arguments** | `key` — **first positional, required**, verbatim (`codespecs_mapping.md` §5.23 exemption 1). `envAlias` ← the environment alias, verbatim. `overridableBy` (**required**, undefaulted) ← `CCSET`'s opt-in, naming which narrower scope may shadow the key — see §3.3.6 for why it has no default. Type and default are the member (test **a**). |
| **4 Naming** | Holder = `<Client>Config`; member = N5 over the key. |
| **5 Locus** | `client`. |
| **6 Cross-refs** | Cites its client by `Type`. |
| **7 Back-link** | `@DocSpec([DocRef('CCSET', 'supplies the per-install setting key, type, default and overridability')])`. |

#### 3.6.4 `@CsDeviceSetting` — CE-DS device setting

| Point | Contract |
|-------|----------|
| **1 Input** | `DeviceSettingEntry` (`DSSET`), the declaration list under `DeviceSettings` (`DEVSET`) — keyed by **(user, device)** and persisted on the device (`codespecs_mapping.md` §5.16). |
| **2 Output** | A settings holder over `TomDevicePreferences` (`tom_core_flutter` `tomclient/preferences/device_preferences.dart`), resolved as a bean and reached through its `get` / `getOr` / `set`, form 2, one marked member per setting — §4.1 records CE-DS as reuse with **no new class**. Members are asynchronous, because every operation reaches the store: `TomStoredDevicePreferences` keeps no cache, which is what makes a store swapped at sign-in take effect from the next call with no invalidation step to forget. **Both halves of the scope key are implicit-by-storage.** The device half is the store's presence on the machine; the user half is the store's `location` — the API takes no principal, so the generated holder neither passes nor receives one. Which means the emitted code is correct under both addressings, and **the application, not the CodeSpec, decides which scope it is in** by the location it installs the store at (`codespecs_mapping.md` §5.16, §11). No wire-level device identity exists. |
| **3 Arguments** | `key` — **first positional, required**, verbatim. Nothing else: type and default are the member. There is **no persistence mode argument** — `codespecs_mapping.md` §11 splits the four scopes by owner key, so the choice is *which marker you use*, never a mode on one of them. There is also **no `overridableBy`**, and `DSSET` authors none: the opt-in is granted by the *wider* scope, and CE-DS is the narrowest, so the lattice bottoms out here and "shadowable by something narrower" is unsayable rather than merely wrong. |
| **4 Naming** | Holder = `<App>DeviceSettings`; member = N5 over the key. |
| **5 Locus** | `client` — a device setting never leaves the device. |
| **6 Cross-refs** | None. |
| **7 Back-link** | `@DocSpec([DocRef('DSSET', 'supplies the per-user-per-device setting key, type and default')])`. |

#### 3.6.5 `@CsUserSetting` — CE-UP user setting (both loci)

| Point | Contract |
|-------|----------|
| **1 Input** | `UserSettingEntry` (`USSET`), the declaration list under `UserSettings` (`USRSET`) — keyed by the **user** alone, so the value follows the user onto any device (`codespecs_mapping.md` §5.16). `LanguageCountrySelection` (`LACOSE`, D09 XDS) is **not** an input: it is the language/country picker screen that *edits* a CE-UP preference, and the preference itself is declared in `USSET`. |
| **2 Output** | Two halves from one declaration, and **neither implements persistence** — the store, its table and its endpoints are the framework's. **Client:** a typed accessor holder over `TomUserPreferencesClient` (`tom_core_flutter`), which reaches the server through `tomUserPreferencesApi`'s four authenticated endpoints carrying `TomUserPreferenceDto` (`tom_core_kernel`). **Server:** the same accessor holder over `TomUserPreferences` (`tom_core_server`), so server code that needs a user's preference reads it through the identical six-method face. Neither half takes a principal: the server binds the user from the request zone (`codespecs_mapping.md` §5.16). Form 2 both sides. |
| **3 Arguments** | `key` — **first positional, required**, verbatim. `overridableBy` (**required**, undefaulted) ← `USSET`'s opt-in; the only narrower scope it can name is `device`. Single-moded, for the same `codespecs_mapping.md` §11 reason as §3.6.4: a setting that must stay on the machine is `@CsDeviceSetting`, not this marker with a flag. |
| **4 Naming** | Holder = `<App>UserSettings`; member = N5 over the key. Both halves use the **same** member names, so the wire mapping is identity. |
| **5 Locus** | `client` for the shape (slice 6) **and** `server` for the accessor (slice 7). The other parts whose halves are both marked declarations take **one entry per half** — CE-API at §3.2.1/§3.4.2, CE-AU at §3.2.7/§3.4.4/§3.5.10. This one contracts both in a single entry because both derive from one `USSET` declaration and the wire mapping between them is identity, so splitting the entry would state the same derivation twice. |
| **6 Cross-refs** | None. The server half cites no repository: it reads through `TomUserPreferences`, whose `TomUserPreferenceRepository` is the framework's own and is resolved as a bean rather than named by the spec. |
| **7 Back-link** | `@DocSpec([DocRef('USSET', 'supplies the per-user setting key, type, default and overridability')])` on both halves. |

### 3.7 Slice 7 — server operational

Cites slices 3 and 4. One entry: CE-UP's server-side accessor is the other half
of this slice, contracted with its client shape at §3.6.5.

#### 3.7.1 `@CsJob` — CE-JB background job

| Point | Contract |
|-------|----------|
| **1 Input** | One `ScheduledJobEntry` (`SCJOB`) from the per-job declaration list under `BatchJobManagement` (`BAJOMA`). Consumed (`codespecs_mapping.md` §5.29): the head form (`jobName`, `purpose`, `triggerKind`, `primaryDataEntity`, `enabled`, `environments`); the promoted trigger case subsection — `SCJOB-CRON`, `SCJOB-CAL` or `SCJOB-EVNT`; `SCJOB-WORK` (work intent, read/written entities, target reports); the `SCJOST-WORK-LST` step list (`ScheduledJobStepEntry`, `SCJOST`), which is the ordered behaviour surface point 2's body is derived from; `SCJOB-FAIL` (the per-job overrides of the `BJME` defaults). `BAJOMA`'s own policy sections supply the **defaults** an entry may override, never a job. |
| **2 Output** | A `TomJobDeclaration` (`tom_core_codespecs` **narrow gap class** — the deployment-and-ownership envelope only) on a class that also extends `tom_core_kernel`'s `TomJobBase`, whose work body is **form 3b** over the `SCJOST` step list, dispatched by `TomJobDispatcher` on the `TomCommand` / `TomExecutor` / `TomWorker` isolate-pooling substrate. `TomJobDeclaration` carries `enabled` (opt-out), `environments` (empty = every environment), `serviceUnitId` and its entity targets — `readEntities` / `writtenEntities` as `List<Type>`, with `targetEntities` the deduplicated union — on its constructor (test **b**); everything a job needs to *run* is reused from `tom_core_kernel` `tombase/scheduling/` (`codespecs_mapping.md` §5.29). The work body is wrapped in `TomTransactionManager.runInTransactionScope` (`tom_core_server`), **unconditionally** — a job runs off the request path, so nothing opens a transaction scope for it the way `TomServer` does per request, and under `TomInlineJobDispatcher` two concurrent job bodies would otherwise share the process-wide fallback scope (`codespecs_mapping.md` §5.13). It is a §2.4 **frame**, not a statement, so it wraps the body unchanged — and unchanged in *either* form, since a frame is a property of the entry rather than of the body it encloses. It is not conditioned on a declared unit of work: a step states behaviour rather than persistence calls, so the spec cannot see which runs open a transaction.<br>**Where the body comes from:** the `SCJOST` step list, through the §2.4 behaviour-to-body derivation B1–B8 — one statement per step with `systemAction`, in list order, on the collaborator §3.0.1 emits for this class; a step's `condition` becomes a B4 guard. **The 3a fallback is the common case here, not an edge one:** most jobs are a single action and list no steps, and §2.4's fallback then emits `throw UnsupportedError(<SCJOB-WORK's description>)` and no collaborator at all. The list is optional in the SOM for exactly that reason — a one-action job is not made multi-step by having to number its one step. |
| **3 Arguments** | `trigger` (**required**) ← `SCJOB.triggerKind` (`ScheduledJobTrigger`) onto `CsJobTrigger {cron, calendar, event}`, `codespecs_mapping.md` §5.29's three trigger kinds; required because a job with no declared trigger is a job that never runs. Per-kind slots (§2.3): `cron` ← `SCJOB-CRON.cronExpression`, `calendar` ← `SCJOB-CAL.calendarRule`, `event` ← `SCJOB-EVNT.eventName` — each a verbatim authored string, and each meaningless for the other two kinds; the SOM guarantees only one is present by promoting exactly the `@Case` subsection the discriminator selects. Policy ← `SCJOB-FAIL`, falling back to the `BJME` / `BJMM` defaults where the entry is silent: `maxRetries` (default `0` — a job retries only when the spec says so), `backoff` and `timeout` as `Duration` consts, `failureAlert` ← `SCJOB-FAIL.failureAlertMessage` as a `CsMessageKey`. `targetReports` ← `SCJOB-WORK.targetReports` as `CsReportRef` consts (default `const []` — most jobs produce no report); the CE-DB half of the same SOM form goes to the declaration, not here, since entities are `Type` literals and need no ref const (`codespecs_mapping.md` §5.23). Each lowers onto a reused `tom_core_kernel` class: the trigger onto the matching `TomSchedule` (`TomCronSchedule` / `TomCalendarSchedule` / `TomEventSchedule`) on `TomJobDefinition.schedule`, the policy onto `TomRetryPolicy` + `TomJobDefinition.timeout`, and `failureAlert` onto the message `TomJobAlert` carries to the deployment's `TomScheduler.onAlert` sink. The trigger is a **wired** schedule, not a name. |
| **4 Naming** | PascalCase of `SCJOB.jobName` + `Job` (N1). |
| **5 Locus** | `server` — work that runs *off* the request thread is the axis separating CE-JB from CE-API. |
| **6 Cross-refs** | Emits `CsJobRef`. Cites `CsServiceUnitRef` — **derived** from `SCJOB.primaryDataEntity` per the `codespecs_mapping.md` §5.17 rule, never hand-listed — plus `CsReportRef` (`SCJOB-WORK.targetReports`), `CsMessageKey`, and its target entities by `Type` (`SCJOB-WORK.readEntities` / `writtenEntities`) — typed const refs, never strings (`codespecs_mapping.md` §5.29). The two target kinds sit in different holders: reports as `@CsJob(targetReports:)`, because `codespecs_mapping.md` §5.23 makes the `Cs*Ref` family the annotation *parameter* vocabulary (where `failureAlert`'s `CsMessageKey` already sits); entities on `TomJobDeclaration`, because a `Type` literal needs nothing but `dart:core` and so leaves `tom_core_codespecs` dependency-free. |
| **7 Back-link** | `@DocSpec([DocRef('SCJOB', 'supplies the job, its trigger and its target set'), DocRef('BJME', 'supplies the execution defaults this job inherits or overrides')])`, plus one `DocRef('SCJOST', 'supplies the step this statement stands for')` per contributing step where the body is 3b — the position half of §3.0.1's "consumed twice", the behaviour half being the collaborator method's own back-link. |

---

## 4. Worked example — one SOM section to one generated file

The acceptance illustration for §2 and §3.3: a CE-DB entity, chosen because
`codespecs_mapping.md` §5.13 has the most fully verified attribute surface of any part and exercises
every universal rule at once — designated name fields, verbatim keys, member
markers, a facet value, a `Cs*Ref`, both back-link annotations, both comment
positions a declarative part can carry, and the no-fabricated-values stub rule.

### 4.1 The input

Two SOM sections in the D06 information model. Shown as the outliner renders
them, with the field values the derivation reads:

```
DataEntityEntry <!--[IMO-014]--> Customer
  entityName ......... "Customer"
  table .............. "customer"
  datasource ......... "core"
  schema ............. null            → deployment default
  description ........ "A person or organisation that places orders."
  content ............ "Customers are never deleted — a closed account keeps
                        its orders."

  DataAttributeEntry <!--[IMO-014-a]--> Customer name
    attributeName .... "name"
    column ........... "cust_name"
    valueType ........ String
    columnType ....... "VARCHAR"
    accessKey ........ "customer.pii"        → a CE-AZ resource key
    kind ............. value
    description ...... "The name the customer trades under."
    → DataAttributeConstraintEntry [DATAA] maxLength = 80

  DataAttributeEntry <!--[IMO-014-b]--> Signed contract
    attributeName .... "signedContract"
    column ........... "signed_contract"
    valueType ........ String
    kind ............. fileReference
    description ...... null                  → no member doc comment
    → fileReferenceOptions [DAATT-DTFR]
        keyPrefix .......... "contracts"
        cascadeDelete ...... true
        acceptedMediaTypes . ["application/pdf"]
```

### 4.2 The derivation, rule by rule

| Decision | Rule | Result |
|----------|------|--------|
| Class name | N1 designated name field `entityName`, N2/N3 | `Customer` — **not** `Cust` or `CustomerEntity`; the SOM name is the domain name |
| Table argument | §3.3.1, verbatim | `'customer'` — never re-derived from the class name |
| File path | N7 | `lib/src/data_access/customer.dart` |
| Member order | N8 | `name`, then `signedContract` — SOM document order |
| `length: 80` | §3.3.2 test **(c)** | a maximum length is not expressible in Dart, so it is an argument |
| `String` type | test **(a)** | carried by the member declaration, never repeated in `@CsColumn` |
| `accessKey` | §2.6 | `CsResourceKeyRef`, resolved by N9 against the shared CE-AZ catalogue |
| File facet | §3.3.3 | its **presence** is the column kind; `store` and `defaultMediaType` omitted → deployment defaults |
| Back-link tokens | §2.5 rule 2 | the entity head's form routes as `DAENT-IDEN` and its narrative as `content`; the attributes split across `DAATT-IDEN` (name, column), `DAATT-DATA` (types, kind) and `DAATT-SECU` (access key); the constraint's `maxLength` rides the constraint entry's narrative field, so it is `content` **too** — the instance ids in the rendering above never reach the code |
| `@CodeSpec.source` | §2.5 rules 4–5 | the class is the emission unit, so its `@DocSpec` enumerates its members' tokens too and `source` equals that set: `{DAENT-IDEN, content, DAATT-IDEN, DAATT-DATA, DAATT-SECU, DAATT-DTFR}` |
| Class doc comment | §2.8 P1 + C1 | `description` becomes the summary, `content` the body, separated by one `///` line — and the `—` stays as authored (C4 rule 5 normalises nothing) |
| `name`'s doc comment | §2.8 P2 | `IMO-014-a` has a `description`, so the member gets one |
| `signedContract`'s doc comment | §2.8 P2 | `IMO-014-b` has none, so the member gets none — the `@DocSpec` is still emitted, because the section *was* consumed |
| No `//` in the body | §2.8 C6 | the three banner lines are the file's only `//` |
| Locus | §3.3.1 point 5 | `<app>_codespec_server` — CE-DB is server-only |

### 4.3 The output

`<app>_codespec_server/lib/src/data_access/customer.dart`:

```dart
// GENERATED by TomSpecs Phase 4 (CodeSpecs) — do not edit.
// Source document: information_model.md (D06)
// Spec model version: 1.4.0

import 'package:tom_code_specs/tom_code_specs.dart';
import 'package:<app>_codespec_shared/<app>_codespec_shared.dart';

/// A person or organisation that places orders.
///
/// Customers are never deleted — a closed account keeps its orders.
@CodeSpec(
  'dataAccess.Customer',
  source: [
    'DAENT-IDEN',
    'content',
    'DAATT-IDEN',
    'DAATT-DATA',
    'DAATT-SECU',
    'DAATT-DTFR',
  ],
)
@DocSpec([
  DocRef('DAENT-IDEN', 'supplies the entity, its table and its storage placement'),
  DocRef('content', 'supplies the entity narrative and the maximum length'),
  DocRef('DAATT-IDEN', 'supplies the stored attribute and its column'),
  DocRef('DAATT-DATA', 'supplies the storage type'),
  DocRef('DAATT-SECU', 'supplies the column-access key'),
  DocRef('DAATT-DTFR', 'supplies the file-reference facet settings'),
])
@CsTable('customer', datasource: 'core')
class Customer {
  /// The name the customer trades under.
  @DocSpec([
    DocRef('DAATT-IDEN', 'supplies the stored attribute and its column'),
    DocRef('DAATT-DATA', 'supplies the storage type'),
    DocRef('DAATT-SECU', 'supplies the column-access key'),
    DocRef('content', 'supplies the maximum length'),
  ])
  @CsColumn(
    column: 'cust_name',
    columnType: 'VARCHAR',
    length: 80,
    accessKey: SbpResourceKeys.customerPii,
  )
  late String name;

  @DocSpec([
    DocRef('DAATT-IDEN', 'supplies the stored attribute and its column'),
    DocRef('DAATT-DATA', 'supplies the storage type'),
    DocRef('DAATT-DTFR', 'supplies the file-reference facet settings'),
  ])
  @CsColumn(
    column: 'signed_contract',
    fileReference: CsFileReference(
      keyPrefix: 'contracts',
      acceptedMediaTypes: ['application/pdf'],
    ),
  )
  late String signedContract;
}
```

### 4.4 What the example demonstrates

- **Determinism.** Every identifier traces to a named SOM field through N1–N3.
  Re-running Phase 4 over an unchanged document reproduces this file
  byte-for-byte — there is no timestamp in the banner and no counter anywhere.
- **No duplication.** `String` appears once (the declaration), `'customer'`
  appears once (the annotation), `'contracts'` appears once (the facet). Each of
  the three §2.3 tests is visible doing its job.
- **Compiles, does not execute.** There are no method bodies to stub here — a
  CE-DB entity is coding form 1/2. `late` — not `late final` — is §2.4's shape
  for a non-nullable field with no authored default: it compiles, it throws if
  anything reads it before Phase 6 fills it in, and it still has the setter the
  repository writes the column through.
- **Both back-links agree.** The class is the emission unit, so it alone carries
  `@CodeSpec`; the two members carry `@DocSpec` only. Its `@DocSpec` lists all
  six tokens and `source` equals that set — §2.5 rules 4–5, which a validator
  check enforces. `content` is on both the class and `name` because the
  constraint's maximum length rides the constraint entry's narrative field —
  the token is coarse there by design (§2.5 rule 2), and the two descriptions
  say which edge is which. A token the code took something from is a token the
  gap analysis has to see.
- **Every comment is derived.** The three `//` banner lines are §2.7 part 1; the
  class doc comment is §2.8 P1 over `IMO-014`'s `description` + `content`;
  `name`'s is P2 over `IMO-014-a`'s `description`. `signedContract` has no
  comment because its section supplies no text, and the body has none because C6
  allows none. No sentence here was composed rather than copied.
- **The one ref const.** `SbpResourceKeys.customerPii` is a `CsResourceKeyRef`
  imported from the shared package's §3.1.4 catalogue. A rename in the CE-AZ
  catalogue is a compile break here, which is the entire point of
  `codespecs_mapping.md` §5.23's typed references.
- **Exactly two imports.** `tom_code_specs` carries the annotations and the
  shared package carries the ref const — and nothing else is imported, per
  §2.7 point 2: the class references no `tom_core_server` symbol in this
  emission, so the server package earns no import line, its being the locus's
  habitual dependency notwithstanding.

### 4.5 Second example — a form-3b body and its collaborator

§4.1–§4.4 exercise the declarative rules on a part with no bodies at all. Form
3b needs an illustration of its own, because it is the one place Phase 4
emits a **second declaration in order to make the first one compile**.

#### The input

An ISC main scenario and the screen action that realises it, as the outliner
renders them:

```
MainScenarioEntry <!--[ISC-021]--> Save an edited customer
  content ............ "The clerk corrects a customer record and saves it."

  MainScenarioStepEntry <!--[ISC-021-1]--> Clerk presses save
    stepNumber ....... 1
    actorAction ...... "Clerk presses Save."
    systemResponse ... null      → actor-only step: no method, no statement
  MainScenarioStepEntry <!--[ISC-021-2]--> Check the edited values
    stepNumber ....... 2
    systemResponse ... "The edited values are checked against the customer rules."
  MainScenarioStepEntry <!--[ISC-021-3]--> Store the record
    stepNumber ....... 3
    systemResponse ... "The customer record is stored and the list is reloaded."

  UseCaseExtensions <!--[ISC-021-X]-->
    ExtensionEntry <!--[ISC-021-X1]--> Customer is on credit hold
      branchPoint .... "ISC-021-2"      → the step this is taken instead of
      condition ...... "The customer is on credit hold."
      extensionType .. "exception"
      returnKind ..... endFlow          → no resume subsection: the use case ends

      ExtensionStepEntry <!--[ISC-021-X1-1]--> Refuse the save
        stepNumber ... "2a1"
        action ....... "Clerk is shown the refusal."
        response ..... "The save is refused and the hold reason is shown."

ScreenActionEntry <!--[XDS-104]--> Save customer
  actionId ........... "saveCustomer"
  owningController ... "Customer"
  description ........ "Saves the edited customer record."
  contextType ........ CustomerViewModel
```

#### The derivation, rule by rule

| Decision | Rule | Result |
|----------|------|--------|
| Which steps yield methods | §3.0.1 point 1, B2 | steps 2 and 3, and the extension's step. Step 1 states an actor action only, and an actor action is the step's trigger, not work the system performs |
| Collaborator class name | §3.0.1 point 4 | `CustomerActionControllerCollaborator` — the owning declaration's identifier plus the fixed suffix |
| Method names | §3.0.1 point 4, N1 | `saveCustomerCheckTheEditedValues`, `saveCustomerStoreTheRecord`, `saveCustomerRefuseTheSave` — the calling body's identifier, then the step's **headline**; `stepNumber` is order, not name |
| Method signatures | §3.0.1 point 2 | the calling body's own parameter list; `Future<void>` on all three, because `saveCustomer` returns `Future<void>` and so no step returns a value |
| Injection | §3.0.1 point 2 | `late final CustomerActionControllerCollaborator collaborator;` — no doc comment and no `@DocSpec`, per §2.8 P2 and §2.5 rule 6 |
| Statement order | B1 | the step list's document order. `stepNumber` is not read — it agrees here, and `2a1` on the extension step shows why it could not be relied on |
| Body statements | B2, B3 | one awaited collaborator call per contributing step; no `return`, because the body returns `Future<void>` |
| The branch | B4 | `ISC-021-X1`'s `condition` becomes the guard `saveCustomerCustomerIsOnCreditHoldApplies` — the calling body's identifier, the **flow entry's** headline, the fixed `Applies` — returning `Future<bool>` because `saveCustomer` is asynchronous. The condition text is its doc comment, not an expression anyone parsed |
| Where the branch sits | B5 | immediately before step 2's statement. `branchPoint: "ISC-021-2"` is a `MNSST.@sectionId` reference, so the step is resolved rather than matched — and the branch is taken *instead of* that step, so it precedes it |
| How the branch ends | B6 | `returnKind: endFlow` ends the block `return;` — `saveCustomer` returns `Future<void>`, so there is no value to carry out. Control does not fall through into the two steps the branch replaced, which is what the extension states |
| Method doc comments | §2.8 P3 | `systemResponse` / `response` / `condition` verbatim — and fatal when absent, which is the second reason step 1 yields no method rather than an undocumented one |
| Back-link tokens | §2.5 rule 2 | every contributing value here — the scenario narrative, each step's `systemResponse`, the extension's `condition` and `response`, the screen action's fields — rides a narrative-borne form, so every edge carries the one token `content`. The instance ids in the rendering above never reach the code; the descriptions and the doc comments are what tell the edges apart |
| Back-links | §3.0.1 point 7, §2.5 rules 1 and 4–5 | each declaration cites `content` **once** — rule 1's dedupe — with a description widened over its edges: the caller for the steps' position and the branch it placed, the collaborator for the steps' behaviour and the branch's condition. `@CodeSpec` sits on the two classes only — `saveCustomer` and the four abstract methods carry `@DocSpec` alone, and each class's `@DocSpec` covers its members' tokens so that `source` accounts for them |
| Locus and files | §3.0.1 point 5, N7 | `<app>_codespec_client/lib/src/action/customer_action_controller.dart` and `…_collaborator.dart` |

#### The output

`<app>_codespec_client/lib/src/action/customer_action_controller_collaborator.dart`,
in full:

```dart
// GENERATED by TomSpecs Phase 4 (CodeSpecs) — do not edit.
// Source document: interaction_scenarios.md (D05)
// Spec model version: 1.4.0

import 'package:tom_code_specs/tom_code_specs.dart';

import '../view_state/customer_view_model.dart';

/// The clerk corrects a customer record and saves it.
@CodeSpec(
  'action.CustomerActionControllerCollaborator',
  source: ['content'],
)
@DocSpec([
  DocRef(
    'content',
    'supplies the step list this collaborator carries, the behaviour each '
    'step states and the condition the branch is taken under',
  ),
])
@CsCollaborator()
abstract class CustomerActionControllerCollaborator {
  /// The edited values are checked against the customer rules.
  @DocSpec([
    DocRef('content', 'supplies the behaviour this step states'),
  ])
  Future<void> saveCustomerCheckTheEditedValues(CustomerViewModel context);

  /// The customer record is stored and the list is reloaded.
  @DocSpec([
    DocRef('content', 'supplies the behaviour this step states'),
  ])
  Future<void> saveCustomerStoreTheRecord(CustomerViewModel context);

  /// The customer is on credit hold.
  @DocSpec([
    DocRef('content', 'supplies the condition this branch is taken under'),
  ])
  Future<bool> saveCustomerCustomerIsOnCreditHoldApplies(
    CustomerViewModel context,
  );

  /// The save is refused and the hold reason is shown.
  @DocSpec([
    DocRef('content', 'supplies the behaviour this step states'),
  ])
  Future<void> saveCustomerRefuseTheSave(CustomerViewModel context);
}
```

and, from `customer_action_controller.dart`, the injected field and the one
form-3b body — the controller's `tom_flutter_ui` substrate members are §3.5.5's
business and are left out here:

```dart
  late final CustomerActionControllerCollaborator collaborator;

  /// Saves the edited customer record.
  @DocSpec([
    DocRef(
      'content',
      'supplies the action and its context requirement, the steps this body '
      'performs in sequence and the branch it guards',
    ),
  ])
  @CsAction()
  Future<void> saveCustomer(CustomerViewModel context) async {
    if (await collaborator.saveCustomerCustomerIsOnCreditHoldApplies(context)) {
      await collaborator.saveCustomerRefuseTheSave(context);
      return;
    }
    await collaborator.saveCustomerCheckTheEditedValues(context);
    await collaborator.saveCustomerStoreTheRecord(context);
  }
```

### 4.6 What the second example demonstrates

- **The body resolves.** Every call names a method the same run emitted, in a
  file the same project exports, through a field the same declaration holds.
  Nothing is a forward declaration and nothing is assumed to exist — which is
  the whole of what §2.4 asks of a 3b body.
- **It compiles and still does not execute.** Two independent stops, in order:
  the `late final` field is unset, so the first call throws before it dispatches;
  and the method it would dispatch to is abstract. §2.4 invariant 4 holds
  structurally here rather than by assertion.
- **No fabricated value.** `saveCustomer` returns `Future<void>`, so the body
  returns nothing and invariant 2 has nothing to catch. Where a calling body
  *does* return a value, B3 gives the last contributing step's method that return
  type and ends the body `return collaborator.<last>(…);`, un-awaited, because its
  future *is* the caller's result. The `if` condition is the same rule seen once
  more: the `bool` came out of a call, not out of a literal, so there is nothing
  in this body that could have been made up.
- **The branch is the spec's, not the author's — and so is where it sits.**
  `saveCustomer` branches because `ISC-021-X1` states a condition, and the
  condition itself was never read as an expression: B4 turned it into one more
  method with one more doc comment. Its *attachment* comes from the spec by the
  same discipline. `branchPoint` resolves to `ISC-021-2` and puts the block
  before that step's statement (B5); `returnKind: endFlow` ends it `return;`
  (B6). Neither is parsed, and neither is a default the agent chose — the
  emitted control flow is the one the extension states, which is exactly what
  a section-id reference and a closed choice buy over two free-text fields.
- **The narrative moved; it did not disappear.** Step 2's sentence is the
  collaborator method's P3 doc comment, not an in-body comment (§2.8 C6). A
  reader asking what the step does reads a declaration — and so does the
  validator.
- **One token, many edges.** Every contributing value here rides a
  narrative-borne form — the scenario's steps, the extension, the screen action —
  so every back-link carries the single token `content`: §2.5 rule 2's accepted
  coarseness at its extreme. Rule 1's dedupe keeps each declaration to one
  `DocRef`, and the descriptions are what keep the edges apart — each
  collaborator method says what its step states, while the caller's one widened
  description covers the action, the sequence and the guard. §2.5 rule 3's
  "describe the edge, not the section" is what keeps same-token edges legible.
  The caller and the collaborator are two emission units, so the token lands in
  two `@CodeSpec.source` sets and the gap analysis sees the consumption from
  both.
- **`@CodeSpec` marks units, `@DocSpec` marks declarations.** The collaborator
  class carries both; its four abstract methods carry `@DocSpec` only, as does
  `saveCustomer` on the controller. That split is §2.5's, and it is why a
  method's own token still reaches `source` — the class repeats it (rule 5).

---

## 5. Constructor-shape summary

The 39 part markers and `@CsCollaborator`, with the shape §3 decides for each —
the shape each constructor in `tom_ai/ai_build/tom_code_specs/lib/src/annotations/` carries. The `Cs*Ref` types
they consume ship in `cross_part_refs.dart` and the closed catalogues in
`vocabulary.dart`. Every marker keeps `String? note` as its final parameter and
it is omitted below.

### 5.1 Markers that gain arguments (24)

| Marker | Shape decided by §3 |
|--------|---------------------|
| `@CsError` | `{CsErrorSeverity severity = CsErrorSeverity.error}` |
| `@CsText` | `{required String baseCopy, CsTextRole role = CsTextRole.generic, CsTextCategory category = CsTextCategory.uiCopy}` |
| `@CsValidation` | `({String rules = ''})` — named, not positional: Dart forbids one signature carrying both optional-positional and named parameters, and every marker keeps a named `note` |
| `@CsFieldRule` | `{required CsMessageKey errorKey}` |
| `@CsFormRule` | `{required CsMessageKey errorKey}` |
| `@CsElement` | `{required CsElementKind kind}` |
| `@CsTrigger` | `{required CsTriggerKind kind, required CsActionRef action, CsElementRef? element, CsGesture? gesture, CsFormRef? form, CsFormEvent? formEvent, CsElementRef? formField, CsLifecycleScope? scope, CsLifecyclePhase? phase, String? channel, String? eventType}` |
| `@CsServerCall` | `(CsOperationRef operation)` |
| `@CsViewModel` | `{CsLifecycleScope scope = CsLifecycleScope.screen}` |
| `@CsLayout` | `(String nodeId)` |
| `@CsEndpoint` | `(String operation)` |
| `@CsServiceUnit` | `{required Type rootAggregate, required String boundedContext}` |
| `@CsTable` | `(String table, {String? datasource, String? schema})` |
| `@CsColumn` | `{String? column, String? columnType, int? length, CsResourceKeyRef? accessKey, CsFileReference? fileReference, CsSensitivityLevel? sensitivityLevel, bool? isPii}` |
| `@CsAuthorize` | `{required CsAuthRequirement requirement, List<CsRoleRef> roles = const [], List<String> groups = const [], List<String> entitlements = const [], CsResourceKeyRef? resourceKey, String? handler, String? resourceId, CsGradedAccess? graded}` |
| `@CsServerConfig` | `(String key, {required CsOverridableBy overridableBy, String? envAlias, String? cmdlineAlias, bool secret = false})` |
| `@CsClientConfig` | `(String key, {required CsOverridableBy overridableBy, String? envAlias})` |
| `@CsDeviceSetting` | `(String key)` — the narrowest scope, so no `overridableBy` |
| `@CsUserSetting` | `(String key, {required CsOverridableBy overridableBy})` |
| `@CsClient` | `(String clientId, {required CsClientKind kind})` |
| `@CsIdentityAttribute` | `{required CsIdentityAttributePlacement placement, CsResourceKeyRef? accessKey, String? systemOfRecord, bool required = false}` — `required` is the attribute's own field name here, not the Dart modifier |
| `@CsMigration` | `{required String datasource, required String schema, required CsMigrationKind kind}` |
| `@CsJob` | `{required CsJobTrigger trigger, String? cron, String? calendar, String? event, int maxRetries = 0, Duration? backoff, Duration? timeout, CsMessageKey? failureAlert, List<CsReportRef> targetReports = const []}` |
| `@CsNotification` | `{required CsMessageKey body}` |

### 5.2 Markers that stay note-only (16)

`@CsEnum`, `@CsWidget`, `@CsForm`, `@CsAction`, `@CsRoute`, `@CsScreenFlow`,
`@CsRepository`, `@CsIdentity`, `@CsAuth`, `@CsAudited`,
`@CsNotificationChannel`, `@CsReport`, `@CsReportColumn`, `@CsReportChart`,
`@CsReportParameter`, `@CsCollaborator`.

Each is note-only for a stated reason, not by omission: every attribute it might
have carried is already held by the declaration (test **a**) or by a substrate
constructor (test **b**). `@CsReport` is the clearest case —
`codespecs_mapping.md` §5.28's 22-row surface is large, and *all* of it landed on
`TomReportDefinition` and its dimension/measure members, leaving the marker
nothing to hold.

`@CsEnum` and `@CsCollaborator` are the opposite extreme, and the only two
markers with **no substrate at all**: there is nothing on either side of the
test. A domain enum has no authored attribute of its own (§3.1.1,
`codespecs_mapping.md` §4.1) and a collaborator is a set of abstract methods and
nothing else (§3.0.1), so both are note-only *and* generate a bare Dart
declaration — a plain `enum`, a plain `abstract class` — for the same reason.

### 5.3 Value classes and closed enums `tom_code_specs` must add

`tom_code_specs` is annotations-only and must not depend on `tom_core` (`codespecs_mapping.md` §9.5), so
every closed catalogue a marker selects from is declared locally, mirroring its
`tom_core` counterpart where one exists. **Sixteen catalogues and two facet value
classes**, which is the whole of `vocabulary.dart` plus the two structured
arguments — a marker selects from nothing that is not in this table.

| Type | Values | Mirrors |
|------|--------|---------|
| `CsErrorSeverity` | `info, warning, error, fatal` | `codespecs_mapping.md` §7's CE-ER severity |
| `CsTextRole` | `error, notification, email, report, generic` | `codespecs_mapping.md` §5.21 |
| `CsTextCategory` | `uiCopy, errorCopy` | `codespecs_mapping.md` §5.21 |
| `CsElementKind` | `textInput, number, toggle, dateInput, choice, multiChoice, fileInput, label, button, menuEntry, formHost` | `codespecs_mapping.md` §5.18's eleven-kind catalogue |
| `CsGesture` | `tap, press, longPress` | `codespecs_mapping.md` §5.20 |
| `CsFormEvent` | `fieldChange, submit, validationPass, validationFail` | `codespecs_mapping.md` §5.20 |
| `CsLifecycleScope` | `screen, route, app` | `codespecs_mapping.md` §5.20, §5.4 |
| `CsLifecyclePhase` | `enter, leave, init, dispose` | `codespecs_mapping.md` §5.20 |
| `CsAuthRequirement` | `role, group, entitlement, resourceKey, custom, graded, none, public, authenticated, guest` | `codespecs_mapping.md` §5.15's six kinds + four presets |
| `CsGradedAccess` | value class `{full, read, disabled}` | `codespecs_mapping.md` §5.15's three-slot tree |
| `CsClientKind` | `flutterApp, cli, server` | §4.1 |
| `CsMigrationKind` | `initialDdl, baseData, iteration` | `codespecs_mapping.md` §5.27's three artifact kinds; SOM `MigrationArtifactKind` `{initialDdl, referenceData, schemaChange}` maps one-to-one (§3.3.5) |
| `CsJobTrigger` | `cron, calendar, event` | `codespecs_mapping.md` §5.29 |
| `CsTriggerKind` | `userGesture, inFormEvent, lifecycle, serverEvent, condition` | `codespecs_mapping.md` §5.20's closed 5-kind trigger taxonomy — **no `tom_core` counterpart**: `TomAction` has no trigger concept, so this is a documented framing over the reused action classes (`codespecs_mapping.md` §5.10) |
| `CsIdentityAttributePlacement` | `public, encrypted` | `codespecs_mapping.md` §5.24's two token carriers — `TomUser.attributes` and `TomPrincipal.currentContext`, so the arms are a placement choice over carriers that already exist |
| `CsOverridableBy` | `none, client, user, device` | `codespecs_mapping.md` §5.16's opt-in cross-scope lattice `CE-DS ▸ CE-UP ▸ CE-CC ▸ CE-CF` |
| `CsSensitivityLevel` | `public, internal, confidential, restricted, pii, phi` | the SOM's `DAATT-SECU.sensitivityLevel` vocabulary, constant-for-constant — **no `tom_core` counterpart**: the level is recorded on the column for downstream consumers; the framework enforces field-level access through `accessKey` (§3.3.2) |
| `CsFileReference` | value class `{keyPrefix, store, cascadeDelete, defaultMediaType, acceptedMediaTypes}` | `TomFileReference`, except `acceptedMediaTypes`, which has no counterpart by design — the substrate stores what it is handed and the restriction is enforced at the CE-API upload endpoint (§3.3.3) |

**All sixteen carry the `Cs` prefix**, without exception. The prefix is what
makes the catalogues legible as one family at a consumer's import site, where
they sit unprefixed alongside `tom_core` — a generic name like `TriggerKind`
denotes something else entirely elsewhere in the workspace (a SOM
`ScheduledJobEntryContentForm` accessor), which is exactly the collision the
convention exists to prevent.

A named validator check (§6 check 9) asserts each mirror is complete: a
`tom_core` catalogue that grows without its mirror growing is a build failure,
not a silent divergence. The check ranges over the rows whose Mirrors cell names
a `tom_core` type. A row whose Mirrors cell names a `codespecs_mapping.md`
section instead has nothing to mirror — its completeness is held by the SOM
section it lowers from, and generation fails on an unmapped SOM constant
rather than on a missing enum value.

### 5.4 Reference types this contract consumes

All thirteen of `codespecs_mapping.md` §5.23, enumerated with their edges in §2.6. Two of them serve
this contract alone: `CsElementRef` and `CsFormRef`, both client-declared,
carrying the `codespecs_mapping.md` §5.20 trigger endpoints that `codespecs_mapping.md` §5.10 mandates be typed references
rather than id strings.

---

## 6. Validator checks this contract creates

Each is named here so the toolchain implements it as a check rather than as a
convention. They are the mechanised half of the authoring side (§2.0): the agent
writes the trio, and this program decides whether what it wrote is admissible.

**Where they run.** All thirty-seven are implemented in
`tom_ai/ai_build/tom_specs_clitool/lib/src/codespecs/` (`cs_reader` reads the generated trio via
the analyzer, `cs_model` resolves it, `cs_extract` reads the per-area extracts,
`cs_checks` holds the checks, `codespecs_validator` drives them) and are invoked
by
`dart run bin/validate_codespecs.dart --shared … --client … --server … [--extracts …]`,
which exits non-zero on any violation. The fourth column names each check's class
in `cs_checks.dart`, so the correspondence is stated rather than inferred: a
check numbered below with no class, or a class in the registry with no row, is a
defect in one of the two.

**The trio is the pass's subject, not its only input.** Most checks read the
trio alone and ask whether it is internally coherent. Four questions cannot be
answered that way, and each brings its own corroborating input: the CE-MG
migrations (check 13), the `tom_core` catalogues a marker's vocabulary mirrors
(check 9), a second generation run (check 31), and the **extracts** — what the
agent was *given* (`codespecs_mapping.md` §1.1.1), which is what checks 19 and
32–36 read. A comment claims to carry specification text, and only the extract
holds that text; no reading of the output alone can tell a copied sentence from
a composed one, nor a complete transfer from a partial one — and only the
extract holds the declared setting keys a secret must resolve against, since
both CE-CF shapes emit the same back-link token. Every corroborating
input is optional at the CLI, and when one is absent its checks raise nothing
and `validate_codespecs.dart` **writes that on stdout**, for the reason spelled
out under check 31: a silent pass would read as a verified one.

**The extract is given whole or not at all.** The other three corroborating
inputs are each self-describing — a migration set, a catalogue pair, a second
trio — and a partial one is either obviously partial or refused outright, which
is why check 31 takes all three regenerated packages or none. The extract tree
is not: a directory holding four of a run's twenty-seven extracts parses
perfectly and simply describes a smaller run. That matters for check 35 alone,
whose left-hand set *is* the extract tree — understate it and the check passes
over a gap it could not see. So the trio and the extract tree are compared as
the two artifacts of one run, which is what they are (`codespecs_mapping.md`
§1.1.1): `--extracts` is given the run's whole `codespecs_extracts` directory,
or it is omitted and the five checks announce themselves unrun.

**A partial pass is recorded, not truncated.** A run may legitimately author
fewer areas than the extract tree names: `codespecs_prompt.md` §6.2 admits
*not applicable* areas, and an *insufficient* area whose L0 decision resolved
to descoping. The scope of such a pass is carried by the gate record —
`gate.verdicts.yaml` beside the extracts (`codespecs_prompt.md` §6.3) — and the
extract reader applies it at the boundary: an area is in the obligation set
**iff** its recorded verdict is `sufficient`. Checks 35 and 36 then neither
hold the trio to an excluded area's routed facts (35) nor accept a citation of
a token only that area's extract carries (36) — the authoring agent never read
it. The reader refuses a record that is silent about a supplied extract, an
*insufficient* entry without `resolution: descoped`, or a *not applicable*
entry whose extract has routed entries, and the driver announces every excluded
area on stdout — the same discipline as an absent corroborating input: a
scoped-out area must never read as a covered one. Without a gate record the
whole extract tree is the obligation set, exactly as above. Deleting extracts
from the tree remains inadmissible either way — the record states the scope; a
missing file merely hides it.

**Why none of them is a const-constructor `assert`.** Checks 8, 10, 14, 15, 16 and
21 are per-instance constraints on a single annotation's arguments, so the obvious
home looks like an `assert` in the marker's const constructor. It does not work:
Dart const-evaluates a const *expression* and reports a failing assert as a
compile-time error, but it does **not** const-evaluate an **annotation**. A
violating `@CsTrigger(kind: userGesture, form: …)` therefore passes `dart
analyze` untouched — and the annotation is the only site these markers are ever
written at. An assert there would enforce nothing while reading as if it did,
which is worse than no guard, so the enforcement point is the generation-time
validator's pass over the resolved annotation for **all** thirty-seven.

| # | Check | Defined in | Implemented by |
|---|-------|------------|----------------|
| 1 | Identifier collisions within a locus project **fail** generation, naming both section ids | §2.1 N4 | `CsIdentifierCollisionCheck` |
| 2 | Every `Cs*Ref` string resolves to a generated declaration | §2.1 N9 | `CsReferenceResolutionCheck` |
| 3 | A missing designated name field / headline **fails**, naming the section | §2.1 N1 | `CsMissingNameCheck` |
| 4 | A missing authored key (message key, error code, setting key, operation name, route id) **fails** | §2.1 N5 | `CsMissingAuthoredKeyCheck` |
| 5 | A form-3a body with an empty SOM description **fails** | §2.4 | `CsEmptyExplicationCheck` |
| 6 | No generated body returns a fabricated value — a 3b `return` is admissible only where the returned value came out of a collaborator or substrate call | §2.4 invariant 2 | `CsFabricatedValueCheck` |
| 7 | `@CodeSpec` sits on the emission unit, which carries `@DocSpec` too, and the two token sets are equal | §2.5 rules 4–5 | `CsBackLinkAgreementCheck` |
| 8 | Only the slots of a marker's declared kind are non-null (`@CsTrigger`, `@CsAuthorize`, `@CsJob`) | §2.3 | `CsSlotExclusivityCheck` |
| 9 | Every mirrored enum matches its `tom_core` counterpart value-for-value | §5.3 | `CsMirroredCatalogueCheck` |
| 10 | `@CsText` with `role == error` has `category == errorCopy` | §3.1.3 | `CsErrorCopyCategoryCheck` |
| 11 | The shared → {client, server} dependency arrow is never inverted | §2.2 | `CsLocusArrowCheck` |
| 12 | A server handler's operation string equals its shared `CsOperationRef` | §3.4.2 | `CsOperationAgreementCheck` |
| 13 | Cumulative CE-MG DDL converges on the `@CsTable` / `@CsColumn` model | §3.3.5 | `CsMigrationConvergenceCheck` |
| 14 | `@CsValidation` never emits the non-declarable `compose` token | §3.2.2 | `CsComposeTokenCheck` |
| 15 | `overridableBy` names a scope **strictly narrower** than the marker's own — `@CsUserSetting` may open only `device`, `@CsClientConfig` only `user`/`device`, `@CsServerConfig` any; `none` is always valid | §3.3.6, §5.3 | `CsOverridableScopeCheck` |
| 16 | A `@CsServerConfig(secret: true)` member has **no initialiser** — a secret declares presence and shape only, so a default is a credential in the source tree | §3.3.6 | `CsSecretInitialiserCheck` |
| 17 | Every `TomNotificationChannelDeclaration.fallbackChannelId` resolves to a channel declared in the same catalogue | §3.2.9 | `CsFallbackChannelCheck` |
| 18 | Every `TomReportColumn.drillThroughRouteId` resolves to a CE-NV route declared in the **client** project | §3.3.9 | `CsDrillThroughRouteCheck` |
| 19 | A `@CsServerConfig(secret: true)` member's key matches a declared `SCSET` entry's `settingKey` in the extracts — a secret is only ever authored on the declared path, so a key no entry declares means a credential slot was invented in a policy section | §3.3.6 | `CsSecretIsDeclaredCheck` |
| 20 | Two `@CsServerConfig` members never claim the same setting key — derived and authored keys share one namespace, and neither shape can see the other while it is authored | §2.1 N10 | `CsSettingKeyCollisionCheck` |
| 21 | A `CsGradedAccess` slot's `@CsAuthorize` is never itself `graded` — the graded depth is exactly one level | §3.4.3 | `CsGradedDepthCheck` |
| 22 | A `@CsColumn` member is **never** a `TomN*` or any other observable, which the shipped repository can read but cannot write | §3.3.2 | `CsColumnNotObservableCheck` |
| 23 | Every call in a form-3b body resolves — to a method of the declaration's own `@CsCollaborator` class reached through its `collaborator` field, or to the substrate its entry's point 2 names — and every collaborator method is called by at least one body of its owning declaration | §2.4, §3.0.1 | `CsCollaboratorCallResolutionCheck` |
| 24 | A `@CsCollaborator` class is `abstract`, declares only abstract methods, and has no field, constructor or static member | §3.0.1 | `CsCollaboratorShapeCheck` |
| 25 | Every method of a form-3a or form-3b declaration, and every method of a `@CsCollaborator` class, carries a doc comment — C2 calls its absence a **generation error**, not a lapse of style | §2.8 C2 P3, §3.0.1 | `CsMethodCommentCheck` |
| 26 | No generated file holds a non-documentation comment other than §2.7's three-line banner | §2.8 C6, §2.7 | `CsNoInBodyCommentCheck` |
| 27 | A doc comment carries no trailing whitespace, sits immediately above the first annotation with no blank line, and escapes `[`, `]` and `<` outside fenced code blocks | §2.8 C4 | `CsDocCommentShapeCheck` |
| 28 | A form-3b body contains only the five §2.4 statement kinds; every local binding is `final` and initialised from a call, and none binds a collaborator result | §2.4, §2.4 B3 | `CsBodyStatementShapeCheck` |
| 29 | Every branch in a generated body is an `if` on a `…Applies` collaborator guard call, never a composed expression, and no body repeats (`for`, `while`) or selects multi-way (`switch`) | §2.4 B4, §2.4 B7 | `CsBranchConditionCheck` |
| 30 | A collaborator method repeats its calling body's parameters name-for-name and type-for-type, and its return type follows the call's position — the body's own on a `return`, `void`/`Future<void>` on an earlier step, `bool`/`Future<bool>` on a guard | §3.0.1, §2.4 B3, §2.4 B4 | `CsCollaboratorSignatureCheck` |
| 31 | Two generation runs over one model produce the same file set and byte-identical contents | §2.8 C5, §2.1 N1 | `CsDeterminismCheck` |
| 32 | Every doc-comment line occurs in the extract of a section the declaration traces to — a line that occurs in no extract is prose the agent composed | §2.8 C1 | `CsCommentSourceCheck` |
| 33 | A grouped holder — a top-level declaration with no `@DocSpec` — carries C3's one-line template and no other generated prose | §2.8 C3 | `CsGroupedHolderCommentCheck` |
| 34 | A doc-comment line is its source line entire — not a re-wrap of it, and not a value the comment stopped rendering part-way | §2.8 C4.2 | `CsCommentFidelityCheck` |
| 35 | Every token the extracts hold a value for is cited by a back-link in the trio — an uncited token is a specification fact that reached no code | §9.6 of `codespecs_mapping.md` | `CsExtractCoverageCheck` |
| 36 | Every token a back-link names exists in the extracts — a trace to a token no area routed is stale or invented | §9.6 of `codespecs_mapping.md` | `CsBackLinkExtractedCheck` |
| 37 | A member reflection writes — a `@CsColumn` attribute, a CE-API DTO field — is a plain field, `late` where it is non-nullable and **never `final`**, because reflection assigns through a setter a final field does not have. A `static` holder, the `collaborator` seam, and a member the declaration assigns in its own method body are §2.4's carve-outs | §2.4 | `CsReflectionWrittenNotFinalCheck` |

**Check 23 is the one that makes "compiles" checkable before a compiler sees
it.** Its two halves fail in opposite directions and neither implies the other.
A call that resolves to nothing is a body §2.4 forbade — the agent emitted a
statement against a declaration it never wrote. A collaborator method nothing
calls is the reverse defect: a step's behaviour was lifted out of the body and
then dropped, so the specification is present in the output but no longer reached
by it, and Phase 6 would implement a method that runs nowhere. Both are silent
otherwise — the first only when the trio is compiled, the second never.

**What it can see, and what it leaves to the compiler.** The validator is a
*syntax* pass over a tree that has never been through `pub get` (`cs_reader`), so
it enforces the **collaborator** half of the rule in both directions: a
`collaborator.<m>(…)` call whose declaration carries no `collaborator` field, a
field whose type names no emitted `@CsCollaborator` class, a call to a method
that class does not declare, and a method of it no body calls. The **substrate**
half — a call on the `tom_core`-family class an entry's point 2 names — needs the
resolved element model, and a wrong one is a compile error in the emitted trio
rather than a silent defect, so it is left where it is already caught. The
division is deliberate: the check exists for the failures a compiler would only
find later or not at all.

**Check 21 is where the SOM's structural bound is re-imposed on the code.** On the
SOM side a graded level takes a `GradedAccessLevelEntry`, whose kind enum has no
`graded` constant, so nesting a second grading is **unauthorable** — the type forbids
it. On the code side `CsGradedAccess`'s three slots are each a `@CsAuthorize`, which
*does* have a `graded` arm, so the same nesting is expressible in hand-written
CodeSpecs even though no Phase-4 run can produce it. Without this check the two
sides would diverge exactly where the SOM was deliberately made strict, and the
divergence would surface as a runtime access decision rather than a generation error.
The bound is not arbitrary: a graded requirement resolves to one of four **terminal**
access states, so a grading nested inside a level has nothing left to resolve to.

**Check 22 catches the one defect that reads clean and fails only on save.**
An observable column *round-trips inward*: `MariadbDatasource` normalises a
`String?` onto `String` before dispatching to the observable's setter, so a
`TomNString` member selects correctly and any read-only test passes. There is no
write path at all. `TomSqlDatasourceRepository.save` binds each column from
`TomColumnInformation.getVariableValue`, which is `invokeGetter(declaredName)` —
on an observable member that yields the `TomNString` **object**, not the `String?`
it holds, and the save comes apart in a `TypeError` deep inside the repository.
Both arms are pinned by `tom_core_server/test/optional_column_emission_db_test.dart`
against a live database, so if the repository ever learns to unwrap an observable
the rule is revisited deliberately rather than becoming quietly wrong.

The check reads a **closed list** of the observable family rather than a `Tom`
prefix: `TomZonedDate`, `TomZonedTime` and `TomZonedDateTime` are plain value
types and perfectly legal column types, and a prefix rule would reject them.
It also reads both spellings of an observable member — the declared type
(`TomNString name;`) and the commoner inferred one
(`final name = TomNString(null);`), which names no type for a type rule to see.

**Checks 17 and 18 each carry a whole edge on its own.** Checks 2 and 13 back up
a compile-time or structural guarantee; these two replace one. The fallback is a
`codespecs_mapping.md` §5.23 **local coordinate**, so no `Cs*Ref` will ever make
it a compile error, and the substrate is deliberately forgiving at delivery
time — `TomNotificationCatalog.fallbackChainFrom` returns an empty chain for an
unknown id rather than throwing, on the stated grounds that a dangling fallback
is a specification defect to *report*, not a crash to suffer. This check is where
it gets reported.

A declaration **cycle** is not a violation. `fallbackChainFrom` stops at the
first channel already visited, so `a → b → a` terminates by construction; a
deployment that genuinely wants two channels to cover for each other is
expressing something coherent, and the runtime already handles it.

**Check 18 is the reverse case, and that is why it is a separate check.** The
drill-through is not a local coordinate: it is a genuine cross-part edge whose
referent *is* a Dart declaration, and `codespecs_mapping.md` §5.23 would give it a `CsRouteRef` were it
not for the **locus** rule — a server-owned report definition may not cite a
client-owned route. So the check has to look **across projects**, in the one
direction the generated dependency arrow forbids code from taking (§2.2 check
11): it resolves the id against the client project's CE-NV routes without the
server project ever depending on them. A dangling drill-through is likewise a
defect to report rather than a failure to suffer — a column whose target does
not resolve simply does not drill through.

**Checks 25–27 and 32–34 guard the only place the specification's words
survive.** A
form-3 body says nothing — it throws, or it delegates — so the doc comment is
where the SOM description reaches the code Phase 6 implements. That is why C2
calls a missing method comment a **generation error** and not a lapse of style
(check 25), and why C6 gives the in-body position the value *nothing* (check
26): an in-body comment is either already in the doc comment or is authorial
commentary no section said, which C1 forbids as a source. §2.7 makes the
three-line banner the sole `//` an emitted file may hold, so check 26 counts the
banner out rather than filtering by position — a fourth `//` above the imports
has crept in beside the banner and is as forbidden as one inside a body.

**How the six comment rules divide across the checks.** Check 27 takes the three
C4 rules a reader of the emitted file alone can see: C4.1's trailing whitespace,
C4.3's blank line, and C4.4's escapes, which decide whether dartdoc renders the
specification's own words or silently eats them — an unescaped `[Order]` becomes
a broken reference, an unescaped `<name>` an HTML tag that renders as nothing.
C1's source rules, C3's template and C4.2 (no re-wrapping, no truncation) each
hold the emitted text against the SOM text it came from, which the trio does not
contain — so they are checks 32, 33 and 34, against the **extract**. C5's
determinism is check 31 and C6's silence is check 26. C2's four positions are
carried by check 25 (P3's missing method comment, a generation error) and by
check 7 (P2 turns on the same test as `@DocSpec`, so the back-link agreement
carries it).

**The extract moves the division; it does not remove it.** Two residues stay on
the SOM side, and each is a place where the extract is silent rather than a place
nothing was checked:

- **C1's *designated* description field.** Check 32 decides whether a line is in
  the specification at all — C1's fourth prohibition, *anything the agent
  composes*, which is the one §2.8 calls hardest to detect. It cannot decide
  whether the line came from the *right* field of the right section, because
  which field is designated is stated in an entry's point 1, in prose, and the
  extract carries values rather than that verdict. A comment built from a
  section's wrong field passes check 32.
- **C3's two slots.** Check 33 decides the template's shape — one line, `<part>
  for <root>.` — which is what makes "no other generated sentence exists anywhere
  in the output" enforceable. It does not decide the slots' content: §4.1 gives
  each part a canonical id (`ErrorResult`) where C3's own illustration renders
  one as prose (`Error codes`), and the extract's document root is the model's
  root section segment rather than the document's name. Deciding either would
  mean inventing a mapping this contract does not state.

Checks 32 and 34 also **partition** their reports rather than both firing on one
fault: a line that is a fragment of a source line is a re-wrap or a truncation
and belongs to 34, so 32 reports only lines that appear nowhere. One fault, one
message, one rule cited.

The division is the same one check 23 draws for the substrate half: a check reads
what its input can show.

**Checks 35 and 36 are the same input answering a different question.** Checks
32–34 ask whether what the trio *says* came from the specification; 35 and 36
ask whether what the specification *said* reached the trio at all. Both belong
to the fourth corroborating-input category above — the extract — and neither is
a comment rule: they compare **token sets**, not text, so they are the only
two checks that read the extract without reading a single character of a value.
The rule they enforce is the self-sufficiency requirement of
`codespecs_mapping.md` §9.6, which is why their **Defined in** cell leaves this
document. That section owns the requirement — after Phase 4 the trio carries
every fact its parts were routed from, so Phases 5 and 6 read code rather than
reopening Phase-3 documents — and §6 owns what a program decides about it. It
states three comparisons: check 35 is comparison 1, check 36 is its converse (the
requirement is stated in one direction there because a dangling trace is a defect
of the *trace*, not of the transfer), and comparison 2 is checks 32 and 34,
already above. Comparison 3 stays output-local, where that section puts it, in
checks 5 and 25. Both directions run over the **in-scope** extract set: when a
gate record marks an area out of the pass (see *A partial pass is recorded, not
truncated* above), 35 stops demanding its facts and 36 stops resolving against
its tokens — the obligation and the vocabulary are the same set, scoped once at
the reader.

**What the pair still cannot see.** Two residues, both of the same shape as the
comment checks' — a place the extract is silent, not a place nothing is checked:

- **A routed section that produced no value.** The extract enumerates values, so
  a section routed to an area and carrying nothing appears in neither artifact
  and is absent from both sides of check 35's difference. That failure is
  comparison 3 of §9.6 of `codespecs_mapping.md`, not comparison 1, and it is
  caught where a missing value
  actually bites: check 3 on a missing name, check 4 on a missing key, check 5
  on an empty explication, check 25 on a missing method comment.
- **Which declaration should have carried it.** Check 35 decides that a section
  reached *some* code, not that it reached the right code. A back-link written
  on a neighbouring declaration satisfies it. Deciding otherwise would mean
  re-deriving each part's own §3 entry inside the validator, which is the
  authoring step's judgement rather than a property of its output.

**Check 29 carries §2.4 B7's bound, and states when it moves.** B4's guard is
the point: an agent that emitted `if (order.total > limit)` would have parsed
English into Dart and guessed at both operands and operator, where one that
emits `if (await collaborator.chargeOverLimitApplies(…))` has moved the same
sentence into a named seam for Phase 6 to implement. A guess that compiles is
the worst kind. The repetition and multi-way arms are narrower than §2.4 kind 4,
which permits `for` and `switch` in principle: B7 states that **no §3 entry**
names a structured surface stating repetition or a multi-way selection, so this
derivation produces neither, and one in a generated body came from somewhere
other than the specification. The check moves when an entry names such a
surface — the same stated bound as checks 21 and 23.

**Check 31 needs two runs, and says so when it has one.** Determinism is a
property of the *production*, not of a trio, so the check takes a second trio via
`--regenerated-shared/--regenerated-client/--regenerated-server` and compares
file sets then bytes per locus. C5 promises byte-identical output, so whitespace
counts; N1's naming derivations mean a file that changed name is a derivation
that is not one. §2.4's B-rules are the first in this contract where a
non-deterministic producer would still emit *plausible* output — a
different statement order or a differently spelled guard name compiles and reads
correctly — which is exactly the class of defect no other check can see. When
no second run is supplied the check raises nothing and
`validate_codespecs.dart` **writes that on stdout**: a silent pass would read as
a verified one.
