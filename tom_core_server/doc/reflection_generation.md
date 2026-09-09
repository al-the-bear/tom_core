# Reflection Generation

How this package's reflection metadata is produced, why regenerating it rewrites
thousands of lines that nobody edited, and how to tell a stale generated file
from a current one.

Reflection metadata is **generated and committed**. That combination is what
makes this document necessary: the file in git is the one the suite and the
examples load, nothing in Dart couples it to the sources it describes, and a
routine regeneration produces a diff large enough that a reader's first
assumption is that the generator is misbehaving. It is not — but the only way to
know that is to have been told.

## Table of Contents

- [The Two Roots](#the-two-roots)
- [Running It](#running-it)
- [Why the Diff Is Enormous](#why-the-diff-is-enormous)
- [Generation Is Deterministic](#generation-is-deterministic)
- [Telling Stale from Current](#telling-stale-from-current)
- [The Fast Check and What It Cannot See](#the-fast-check-and-what-it-cannot-see)
- [Adding Something the Generator Must Capture](#adding-something-the-generator-must-capture)
- [An Annotation Binds to the Next Declaration](#an-annotation-binds-to-the-next-declaration)
- [Verification](#verification)

---

## The Two Roots

`build.yaml` configures two reflection roots, and each produces one committed
output beside it:

| Root | Output | Consumed by |
| ---- | ------ | ----------- |
| `test/fixtures/reflection_fixture.dart` | `test/fixtures/reflection_fixture.reflection.dart` | the test suite |
| `example/example_reflection.dart` | `example/example_reflection.reflection.dart` | every example needing a reflector |

One root serves all the examples rather than one per example. An example cannot
borrow the test fixture's reflector — the two graphs capture different types —
and a second example root would generate a further ~1.7 MB capturing the same
package barrel a second time.

A root captures what its import graph reaches. `example_reflection.dart` also
states its intent directly, in a `const List<Type> exampleReflectedTypes`, which
is what the currency test holds the generated file against.

## Running It

From the package root:

```bash
./reflection_generation.sh
```

The script runs flag-free: the generator scans the current project only, so no
`--nested` and no workspace registry are needed. It resolves the SDK from
`$DART` or from `dart` on `PATH`, and fails with the remedy in the message
rather than a bare missing-path error, because the fleet's hosts install Dart in
different places.

A run takes **two to four minutes** against the whole package graph. That cost
is why the exact currency check is a script rather than a test — see below.

Without generated metadata, mirror construction throws *"Reflection has not been
initialized"*.

## Why the Diff Is Enormous

The generator numbers every captured member in **one dense global sequence**,
and writes those numbers into the output as index lists — 8,420 `const <int>[…]`
literals in the fixture output alone, across 89,555 lines and 1.8 MB.

Dense and global means the sequence has no gaps and no per-class origin. So
**adding one public member anywhere in `lib/` shifts every index after it by
one**, and every list containing any of those indices is rewritten. The source
change is one line; the generated change is tens of thousands.

A worked example. Commit `e43ade30` ("Give `TomMessageBody`'s defaults a single
home each") added exactly one public static member. Its diffstat:

```
example/example_reflection.reflection.dart    | 10339 ++++++++---------
test/fixtures/reflection_fixture.reflection.dart | 11139 ++++++++---------
7 files changed, 10885 insertions(+), 10737 deletions(-)
```

and the shape inside the diff is a uniform shift — a list front loses `838`, the
back gains `869`, and

```dart
const <int>[869, 870, 871, 872, 873]   // before
const <int>[870, 871, 872, 873, 874]   // after
```

Insertions and deletions being within ~1 % of each other is the signature: lines
are being *renumbered*, not added. A diff of that shape is a correct response to
a real source change. A diff whose insertions and deletions differ sharply
(`0febcbc0`: 35,457 / 34,427) means classes or members were genuinely added or
removed as well.

**This is a property of the index design, not a defect in a particular run.**
Making the numbering per-class, or sparse, would shrink these diffs — that is a
generator redesign, and it is not something this package can do downstream.

## Generation Is Deterministic

A second consecutive run on an unchanged tree leaves `git status` clean for both
generated files. This has been verified two ways:

- a **warm-cache** run — no change;
- a **cold** run with `--rebuild-cache` — no change.

The outputs were byte-identical across runs by `sha256sum`. So the large diffs
above are never churn; every one of them is the generator's response to a source
change that really happened.

The distinction matters because the two are easy to confuse in exactly one
situation: regenerating on top of a **stale** checked-in file. The first run then
produces thousands of changed lines, which looks like non-determinism and is
not — it is the accumulated effect of every source change since the file was last
generated. Run it twice. The second run is clean.

## Telling Stale from Current

The exact check regenerates and compares:

```bash
tool/check_reflection_current.sh
```

Exit `0` means the committed metadata is byte-identical to a fresh generation.
Exit `1` means it is stale, and the script prints the diffstat and then **reverts
the regenerated files**, so a failing check is never mistaken for the fix. Exit
`2` means the generated files already had uncommitted changes, so a difference
could not be attributed to staleness — commit or stash first.

Run it before publishing, and after any change to a reflected root.

## The Fast Check and What It Cannot See

`test/reflection_currency_test.dart` runs in milliseconds and buys most of the
same certainty. It reads the roots' hand-written sources, extracts every
`@tomReflector` class, every `exampleReflectedTypes` entry and every
`@TomDbColumn` field, and asserts each name appears in the generated file.

It cannot prove the generated file is *current* — only that it is not missing the
things most recently added. That is a deliberate trade, because the two things it
checks are the two a person adds by hand, and forgetting the slow script
after adding them is the failure that actually occurs. A missing class fails at
the mirror lookup with "Reflection has not been initialized"; a missing column is
worse, because the entity still reflects and the failure surfaces as a null
member from a test that names neither the column nor the file.

What it cannot see is the indices — which is precisely what the section above
says one added member rewrites. Only regenerating settles those.

The test also pins its own extractors against the fixture, in both directions: a
`@tomReflector` class is attributed to its own declaration, and an annotation
does **not** reach across a class body into the next one. The second guard is
there because an earlier character-gap regex did exactly that, and reported the
generated file stale for `FixtureTaskRepository` — a class documented as
deliberately carrying no `@tomReflector`.

## Adding Something the Generator Must Capture

1. Add the class or column to a source the root's import graph reaches.
2. If it is a new example type, add it to `exampleReflectedTypes` in
   `example/example_reflection.dart` — the root captures its import graph, and a
   type reached by nothing is captured by nothing.
3. Run `./reflection_generation.sh`.
4. Commit **both** generated files, even if only one root's sources changed. They
   share the package barrel, so a change in `lib/` renumbers both.

A fifth example entity file must also be added to `_roots` in
`test/reflection_currency_test.dart`. That list is written out rather than
globbed on purpose: a glob would silently cover a file that was never wired into
`example_reflection.dart` at all, which is the mistake worth catching. `lib/` is
walked rather than listed, for the opposite reason — the fixture root imports
the package barrel, so a reflected class the package exports is already in the
graph and needs no wiring, and naming them one by one would be a second
inventory of `lib/` that goes stale on its own.

## An Annotation Binds to the Next Declaration

Whatever that turns out to be. A class annotation is not attached to a class by
being written *near* it, so anything written in between takes it somewhere else
— and the class then leaves `tomReflector.annotatedClasses`, which is where
every discovery walk in the framework looks: services and components for the
endpoint pipeline and the bean locator, `@TomDatasourceDriver` for datasource
initialisation, `@TomScheduledJob` for the scheduler.

Nothing in Dart objects. The annotation is still valid, it is simply on
something else, so the tree compiles and analyzes clean and the class is
discovered by nobody — which surfaces as a start-up failure at a deployment and
as nothing at all in a suite.

`test/reflection_currency_test.dart` reports it, and reports it separately from
the staleness check above because the two are opposite halves of one question.
The staleness check names a class the generated file is missing; a detached
annotation takes the class *out of the declared set*, so nothing is missing and
nothing would be said.

## Verification

| Check | What it settles |
| ----- | --------------- |
| `tool/check_reflection_current.sh` | Exactly: the committed files match a fresh generation |
| `test/reflection_currency_test.dart` | Fast: every reflected class and column in `lib/`, the fixture and the example roots appears, and no class annotation has come loose from its class |
| `../tool/check_reflection_artifacts.py` | Every name a committed artifact writes still resolves |
| `./reflection_generation.sh` run twice | The second run is clean — generation is deterministic |
