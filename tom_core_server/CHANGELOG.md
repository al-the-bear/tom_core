## 1.3.0

### Behaviour Changes

- **`verifyAgainstAnchor` no longer lets a verifier's exception out, and the
  verifier contract says so (tcinc348).** `TomAuditAnchorVerifier` is an
  interface, and the library invites implementations that leave the process —
  "an HSM, a KMS and a PEM file are all legitimate answers". Those fail in ways
  a pure-Dart verifier does not: expired sessions, timeouts, key material that
  will not parse. `verifyAgainstAnchor` called `verifier.verify(anchor)` inside
  no guard of its own, so a function documented as returning one of eight
  statuses handed the caller a stack trace instead whenever the key store was
  briefly away.

  It now reports `signatureInvalid`, for the reason the unsigned case already
  used: a verifier that could not answer and an anchor that is genuinely forged
  are indistinguishable from here, and calling the ambiguity "fine" is how a
  check silently stops checking. The exception goes into
  `TomAuditAnchorVerification.detail`, so an operator reads an infrastructure
  fault as one rather than opening a forgery investigation. The guard wraps the
  signature check in place and does not disturb the writer check above it.

  `TomAuditAnchorVerifier.verify` now documents that implementations must not
  throw — the input is an anchor that may have been tampered with, so malformed
  key ids and signatures are ordinary traffic rather than programming errors,
  and the caller's only two useful answers are `true` and `false`.

  `TomRsaAuditAnchorVerifier.verify` widens its `on FormatException` to catch
  everything. This one is belt-and-braces and is labelled as such in the code:
  with pointycastle 3.9.1 nothing else actually escapes — `rsaVerify` catches
  `ArgumentError`, `RSASigner` catches it again around `processBlock`, and every
  throw in `PKCS1Encoding` and `RSAEngine` is an `ArgumentError`. Twenty-three
  malformed signatures (invalid base64, empty, one byte, half length, off by one
  either way, doubled, all-`0xFF`, against 2048-bit, 4096-bit and toy keys) all
  answered `false` before the change. But that totality was three layers of
  other people's internals — one of them commented with the version it was
  written for — holding up a guarantee this class owes its own callers, who may
  call it outside `verifyAgainstAnchor` and so outside the new guard.

- **`TomFileAuditSink` buckets by the UTC day, and actually starts a new file
  when the day turns over (tcinc346).** Two defects behind one claim. The file
  name came from the host's *local* calendar while every `TomAuditRecord`
  timestamp is UTC, so on a host two hours east of UTC a record stamped
  `2026-08-12T01:00Z` was filed in `audit-2026-08-11.jsonl` — a file whose name
  disagrees with its own contents, so the day an incident report names is not
  the file it is in, and at a month boundary is not even the right month. It
  also made the layout depend on where the process happened to run, which is
  exactly the dependency an audit trail may not have when several nodes write
  into one directory.

  The larger half: `_ensureOpen` returned early on nothing but the byte cap, so
  the day was consulted only when a file overflowed. A sink under the default
  16 MiB cap therefore appended to the file named after the day of its *first*
  write — for weeks. "One file per day" was true only of trails busy enough to
  rotate daily anyway. The target file is now recomputed on every write.

  A day boundary is **not** a rotation: the finished day keeps its plain name
  and spends no sequence number, because a day with rotated parts and no live
  file otherwise means "this day filled up". Both reasons to reopen now run
  through one rule — reopen when the file that should be open is not the one
  that is, rotate only when the file being opened is already too full — which
  removed a second `_rotate()` call that was redundant on overflow and wrong on
  a rollover, where it renamed a day that had not overflowed at all.

  New `clock` constructor parameter (defaults to `DateTime.now`), following the
  convention `TomSqlLeaseLock` and `TomMimeEncoder` already use. It drives both
  the day boundary and the retention age, so a caller who moves the clock to
  exercise a ten-year policy sees it apply rather than watching nothing expire.
  Retention's arithmetic is otherwise unchanged and was never zone-dependent:
  `DateTime.difference` compares instants, not calendar fields, so the window
  was always exact — a `// Why:` note now records that, so it is not "fixed"
  into a change that alters nothing.

  Existing files keep their names and are still read in write order; the reader
  sorts by the day *string*, which is why the zero-padding is load-bearing and
  now has a test that says so.

- **`TomAuditAnchorPublisher.close` no longer pretends to publish a final
  anchor; `publishAndClose` actually does (tcinc345).** `close()` fired
  `unawaited(_tick())` and the docs promised the result — "entries written
  since the last tick are not left unanchored by a graceful shutdown". It is
  `TomClosable`'s method, and that contract is synchronous: nothing awaits what
  it returns. So the append sat in a microtask that the shutdown it was called
  for never ran. Measured against a file-backed store, `close()` followed by
  `exit(0)` produced **one anchor on disk where two were claimed** — the final
  head silently unanchored. The old test only saw the anchor because it added
  `await Future<void>.delayed(Duration.zero)`, which is precisely the turn a
  departing process does not take.

  A guarantee that is absent at the only moment it is claimed for is worse than
  no guarantee: an operator reading that close pins the chain believes the tail
  is covered, and an unanchored tail nobody knows about is the gap an anchor
  exists to close. `close()` now cancels the schedule and publishes **nothing**,
  and says so. The awaitable `publishAndClose()` delivers the final anchor — the
  same split `TomAuditSink` already draws between `close()` and
  `flushAndClose()`, so the two classes shut down the same way.

  `publishNow()` gained the closed-publisher guard, as the single choke point
  every publication passes through: a closed publisher could previously still
  append through the direct route while the scheduled one was refused. New
  `isScheduled` getter — whether the periodic timer is armed is the one piece of
  lifecycle state with no other observable consequence until an interval has
  elapsed, and a live periodic timer holds the isolate open.

  In the samples, `advanced_ops_server`'s `OpsRuntime.close` took the anchor at
  step 2 but drained the sink at step 4, so even a working final anchor would
  have pinned the head as it stood *before* the records the drain went on to
  store — leaving them outside the anchored range, which is the one place a
  truncation is invisible. Draining now precedes anchoring.

- **Audit sinks report every `write` failure through the returned future
  (tcinc344).** `TomFileAuditSink.write` and `TomSqlAuditSink.write` both
  declared `Future<TomAuditEntry>` and both opened with a bare
  `if (_closed) throw _closedException()`, so a write to a closed sink threw
  **at the call site**, before a future existed — while the same method's other
  failure, `audit.sink.write_failed`, arrived through the future as documented.
  One method, two error channels, chosen by which failure occurred.

  The return type is what a caller protects against.
  `sink.write(r).catchError(...)`, `Future.wait([...])` and an unawaited write
  handed to a later `await` are all complete handling of a future's failure and
  none of them sits inside a `try`; each was silently the wrong protection for
  half of what `write` could do. The escaping refusal landed on whatever stack
  was running, which for a fail-closed trail replaces "your record was not
  stored, decide what to do" with an uncaught error inside the audited action.
  Both methods are now `async`, which puts the rule in the declaration so a
  guard added later inherits it; ordering is unchanged, since an `async` body
  runs synchronously up to its first `await` and the enqueue precedes any.
  `TomAuditSink.write` states the rule for custom sinks.

  Callers of `TomAuditTrail.record` were never affected: `record` is `async`
  and captured the synchronous throw. The blast radius was code holding a sink
  directly.

  Two related leaks out of the same channel, in `TomFileAuditSink`, both found
  by the tests written for the above. `File.openWrite` is lazy, so a path that
  cannot be opened failed the awaited flush — correctly becoming the caller's
  `write_failed` — *and* the file handle's own completion, which had no
  listener and surfaced as an unhandled asynchronous error in the calling zone:
  a caller who handled the failure exactly as documented still got an uncaught
  error for it. And the dead handle was kept, so `_ensureOpen`'s early return
  fed every later record to it — the sink failed for the life of the process
  with `Bad state: StreamSink is closed` in place of the filesystem error that
  said what was wrong, long after the directory was repaired. A failed write
  now closes and drops the handle, which consumes the duplicate and lets the
  sink resume recording once the path works again.

- **`TomAuditEntry.fromJson` defaults no field; a damaged entry is refused
  rather than reinterpreted (tcinc343).** The factory rejected a missing
  `index` — and explained at length why guessing a position was unacceptable —
  then read `hash` as `json['hash'] as String? ?? ''` and `previousHash` as
  `... ?? tomAuditGenesisHash`. The same reasoning was never applied to the two
  fields the chain is actually made of.

  Each default converted a *malformed* entry into a *specific accusation*. With
  no `hash`, the entry read back as one whose stored hash does not match its
  contents, which `verifyAuditChain` reports as **content changed after
  writing**: the signature of an edited record, on a record nobody touched.
  With no `previousHash`, the entry claimed to have begun a chain — mid-chain a
  **link mismatch**, and at the head no finding at all, since it was
  self-consistent against the link it had been handed. That last case is the
  one that costs the guarantee rather than merely misdirecting an
  investigation: damage verified as health.

  Two consequences beyond the read path. `parseAuditLines` documents that
  anything it cannot read is reported, and a line that parsed as JSON but had
  lost a hash slipped past that promise; it no longer does. And
  `TomFileAuditSink` head recovery adopted `''` as the chain head from such a
  final line, linking every subsequent entry onto a hash no entry has, so the
  break landed at the restart boundary and read as tampering — recovery now
  treats the line like a half-written one and falls back to the previous file.

  `hash` and `previousHash` are also refused when present but empty, since the
  empty string was the old default and an empty hash is an absent one rather
  than a short one. `record` was already refused, but as a `TypeError`; it now
  raises `audit.entry.missing_record`, so all four fields leave the factory by
  the same door. New keys: `audit.entry.missing_hash`,
  `audit.entry.missing_previous_hash`, `audit.entry.missing_record`. The
  relational sink needed no equivalent change — its DDL declares both hash
  columns `CHAR(64) NOT NULL`.

- **`TomFileAuditAnchorStore.read` returns only the requested writer's anchors
  (tcinc342).** The store names a file after the writer, sanitising the name so
  that a writer called `../../etc` produces a strange file name rather than a
  write outside the directory. The sanitisation is correct and stays; the
  defect was using a lossy mapping as if it were injective. `node/a` and
  `node_a` share one file, and `read` returned every line in it — so two chains
  came back as one, while `TomMemoryAuditAnchorStore` filtered and the two
  shipped stores disagreed about what `read(writer)` meant.

  `latest` is what makes this more than untidy: it is the anchor the documented
  routine check uses, so the check was handed a position belonging to a
  different trail. When the foreign position is ahead of the chain the verdict
  is `truncated` — tampering reported on a trail nobody touched, and truncation
  is precisely the finding an operator has been told to trust because a hash
  chain cannot detect it alone. When the foreign position is *behind* the
  retained window the verdict is `beforeRetention`: neither a match nor a
  finding, so the check quietly declines to check and a genuine rewrite passes
  it. The false alarm costs trust; the silent pass costs the guarantee.

  `read` now filters on the writer recorded in each anchor, matching the memory
  store. The filter runs after parsing, not as a text match on the raw line: a
  line too damaged to parse is too damaged to attribute, and skipping it
  because it does not look like ours would disable the archive's one integrity
  check for exactly the lines that failed it.

- **An audit sink that is closed no longer writes; `flushAndClose()` is the way
  to keep what was queued (tcinc341).** Both persistent sinks serialise writes
  through an internal queue and checked `_closed` only at enqueue time. A
  record submitted before `close()` and started after it therefore ran to
  completion on a closed sink: `TomFileAuditSink` found `_sink` nulled, called
  `openWrite` again and appended to the file it had just closed — while the
  unawaited close of the old handle was still in flight on the same path — and
  `TomSqlAuditSink` inserted its row. A write submitted *after* `close()`
  returned was correctly refused, so which answer a caller got depended on
  where the event loop happened to be.

  `close()` now refuses a queued record with `audit.sink.closed`, checked in
  the serialised body and again at the one point a file handle is opened —
  rotation awaits, so a close can land in the middle of `_ensureOpen`, and the
  same is true of the SQL sink's `open()`. Refusing is the only honest answer
  of the three available: writing it anyway is the reopen, and dropping it
  silently lets an audited action report success with no entry behind it, which
  is what a fail-closed trail exists to prevent.

  `TomAuditSink.flushAndClose()` is new and is the route that *stores* those
  records: it closes the sink to new writes, awaits the queue, then closes.
  Without it the fix would only have converted a silent reopen into a silent
  refusal at every graceful shutdown. `close()` keeps `TomClosable`'s
  synchronous contract — the shutdown calls it through a `void Function()` and
  cannot await it — so draining could not be folded into it. Applications
  should `await sink.flushAndClose()` in their own teardown and leave the
  `TomClosable` registration as the backstop; calling both is safe, as
  `flushAndClose()` after `close()` is a no-op rather than a second close.

- **`@TomAudited(includeReads:)` is removed; reads were never audited and now
  say so (tcinc340).** The parameter was documented in four places — the
  `audit_trail` library comment's coverage table, `doc/audit.md`,
  `api_summary_audit.md`, and the module's own `Patient` worked example — as
  the switch that turns read auditing on. Nothing produced such a record.
  `TomAuditAction.read` appeared exactly once in `lib/`, inside
  `TomAuditPolicy.audits`, deciding whether a read *would* be audited; the
  repository chokepoint calls `recordMutation` for create, update and delete
  only, and `findById` / `findAll` / `count` reach no audit code at all.

  It failed in the direction that matters. A deployment annotating its
  regulated entity saw the annotation accepted and `audits(read)` report
  `true`, and had no read trail. Withdrawing the parameter rather than
  implementing it is the honest correction, because the missing piece is not
  code: a read chokepoint must choose between one record per call and one per
  row — per call loses which rows were seen, per row buries the trail — and
  fail-closed then puts that write in front of every read of the entity. Those
  are deployment judgements about latency and volume, and no framework default
  can make them.

  `TomAuditAction.read` stays in the enum, and `TomAuditTrail.recordAction`
  still consults no policy, so an application that has made the decision can
  record exactly what it wants. `audits` now answers `false` for `read` under
  every annotation, with the branch written out rather than left to fall
  through to `true` — a policy that claimed a read *is* audited when the
  repository records none would be the same false promise reversed. The
  endpoint-level `@TomAudited()`, which records an `execute` with its actor at
  the boundary where "who asked" is unambiguous, is the route the docs now
  point at first.

- **`Tom2FAEnrolmentState.fromClaims` reads every boolean claim with
  `Tom2FAClaims.isTrue`, matching the kernel.** It read three claims three
  different ways relative to its client-side twin: `pendingEnrolment` by exact
  string equality, and `skippable` / `skipSpendsGrace` by exact *boolean*
  equality — while the kernel's `Tom2FAPendingEnrolment.fromClaims` accepted
  either encoding for the flags.

  The two decode the **same claims out of the same token**, one to render the
  enrolment UI and one to authorise the enrolment passes, so a disagreement
  about what `skippable` means surfaces as a skip button the client offers and
  the server then refuses. The `pendingEnrolment` difference is milder but the
  same shape: a token that genuinely carries an enrolment, encoded the other
  way, was refused with `login.error.2fa.no-enrolment`.

  Both now go through the kernel's shared rule, and the server's copy of the
  decoder gained direct test coverage, including a case that decodes one
  projected payload with both readers and asserts they agree.

### Features

- **repository paging and caller-controlled sorting.** The four finders
  (`findAll`, `findAllById`, `findByQuery`, `findByQuerySentence`) now take an
  optional `TomPageRequest`, so a caller asks for page N of size M instead of
  loading the whole table. Three holes closed at once: OFFSET was previously
  *unrepresentable* (`TomGeneratedQuery` rendered `LIMIT n` and nothing else),
  none of it was on the repository API, and ordering carried a single
  `bool ascending` for every column — `ORDER BY priority DESC, due_date ASC` could
  not be expressed at all.

  Ordering is now a list of `TomSortField`s, each with its own
  `TomSortDirection`. `TomSelect` / `TomCount` / `TomDelete` still accept the old
  `orderBy:` + `ascending:` pair as a *shorthand* that maps onto the list, so the
  generated `*.reflection.dart` files across the samples keep compiling
  unchanged; the stored field is the list.

  **Two requests are rejected rather than silently reinterpreted.** MariaDB's
  grammar is `LIMIT n [OFFSET m]` with no bare `OFFSET`, so a skip without a cap
  would be dropped on the floor — `TomPageRequest.assertWindow` and
  `TomGeneratedQuery.limitClause` both throw `TomQuerySyntaxException` for it, and
  for a negative bound. `TomCount` and `TomDelete` take no offset: a total does
  not depend on the page, and `DELETE … LIMIT n OFFSET m` is not MariaDB syntax.

  **An unsorted window is still made deterministic.** Rather than rejecting a
  page request with no `ORDER BY`, the repository appends the entity's primary key
  ascending as a tiebreaker, so consecutive pages partition the result instead of
  repeating and dropping rows at the database's discretion.

  **Paging composes with the security layers** because the window is applied
  *before* the scope: the row scope's bound `IN` predicate is still ANDed in and
  column-authorization masking still runs on the returned rows. The total beside
  a page comes from `count()`, which routes through the same scoping — so page
  metadata cannot leak a row count the principal may not read. Asserted live in
  `test/paging_db_test.dart` (three of five rows visible, count says three).

  The query sentence grew the matching vocabulary: `skip M` / `offset M` beside
  `top N` / `first N`, and a direction per field in the trailing `order by`. Each
  direction keyword applies back to the previous one, so `order by a b desc`
  sorts both descending (the historical whole-list reading) while
  `order by a desc b asc` mixes them, and an undirected field sorts ascending.

  *Design decisions.* (1) The result shape is `List<T>` plus the existing
  `count()`, not a `TomPage<T>`: it keeps every existing signature intact and
  avoids a mandatory second round-trip per page for callers that do not need the
  total. (2) The offset guard rejects the *unrepresentable* window but not the
  merely under-specified one — a missing `ORDER BY` is repaired with the primary
  key rather than refused, because refusing it would make the common
  "just give me a page" call an error.

### Documentation

- **The source and the test suite state their rules instead of narrating past
  defects (tcinc351).** 85 lines across 27 files carried a bare `§N` — `(bug
  §75)` on the audit record's encodability pass, `Bug §22:` above the migration
  filename group, `Before §68 the Map<String,Object?> entry is not a
  Map<String,Object>`. The numbers index sections of a quest working document
  that ships with neither this package nor its tests, so a reader had no way to
  resolve them, and a reader who could would have found a build log rather than
  a rule. Test names were the sharpest case: a group called `non-encodable
  values in before/after (bug §75)` reports an index entry when it fails, not
  the contract that broke. Every site now states the current behaviour and its
  reason; the references that do name a document (``codespecs_mapping.md
  §5.16``, `RFC 7636 §1`) are unchanged, and three that named one implicitly now
  say so.

  A repository-wide check holds this: `tool/check_section_refs.py` reports any
  `§` reference in `lib/`, `test/` or `example/` whose sentence does not name
  what it indexes. `tom_core_server` is clean.

- **`doc/audit.md` installs a sink with a call that compiles (tcinc350).** The
  "install a sink at start-up" line read
  `TomAuditTrail.install(TomFileAuditSink(Directory('/var/audit/app')))`.
  `TomFileAuditSink` takes named parameters only, so the sample did not compile
  — and the same document's other sample of the class already wrote
  `directory:` correctly, which is what made this a slip rather than a stale
  API. It sat in the document's shortest and most copyable snippet, which is
  exactly the one a reader pastes. The two samples now agree.

  A repository-wide check now holds this: `tool/check_doc_samples.py` reports
  the two halves of the mistake — a named-only constructor called positionally,
  and a required-positional constructor called with a named argument first.
  Compiling all 1770 fences in the tree is not the guard, because most are
  fragments with no imports and no surrounding program; this takes the slice
  that is decidable from the text alone. See the repository README for the
  bounds, in particular why names resolve within a document's own package only.

- **`TomFileAuditSink.files` points at `_recoverHead`, a method that exists
  (tcinc349).** The paragraph explaining why the file order is computed rather
  than read off the names listed the readers that depend on it, and named one of
  them `[_recoverHeadHash]`. There is no such member. The square brackets make
  it a dartdoc reference, so it resolved to nothing and rendered as plain text
  — in the one paragraph covering the module's least obvious behaviour, that
  construction recovers both the head hash and the entry count from the newest
  existing file.

  A repository-wide check now holds this: `tool/check_dartdoc_refs.py` reports
  dartdoc references to private names that exist nowhere in their library, and
  it found two more of the same defect in `tom_flutter_ui`. Deliberately narrow
  — see the repository README for why the `comment_references` lint is not the
  tool for this, and what it would cost to satisfy.

- **`verifyAgainstAnchor`'s dartdoc describes the order the code actually runs,
  and tests now hold it there (tcinc347).** The comment said the checks are
  ordered "by which failure stops meaning anything: a chain that is not
  internally valid tells you nothing about an anchor" — chain first,
  authenticity second. The code runs the reverse: writer, then signature, then
  chain validity, then position. The implemented order is the better one and is
  what stays; the prose was the outlier, and it disagreed with `doc/audit.md`'s
  own account too.

  The reason is *most specific answer first*. These conditions usually fail
  together — an anchor for the wrong chain does not hash-match either — so
  reporting the most specific one names the mistake that was made rather than a
  consequence of it, and an operator told `writerMismatch` fixes the query
  instead of hunting a rewrite that never happened. The chain verification is
  still computed before any of the checks and is reported on
  `TomAuditAnchorVerification.chain` whichever status wins, so short-circuiting
  costs the caller precedence, never the chain result.

  Nothing tested the precedence, which is how the comment drifted in the first
  place: every existing test arranged for exactly one thing to be wrong. Four
  tests now fail writer, signature and chain simultaneously and withhold one
  argument at a time, fixing a total order rather than three isolated facts;
  reordering the guards fails them. `doc/audit.md` and the API summary state the
  order alongside the status table, where a reader meets the statuses without
  being told that only one of them comes back.

- **`doc/audit.md` gains a *Reads Are Not Audited* section, and the trail's
  library comment states the position outright (tcinc340).** Removing
  `includeReads` leaves a question the reader will still ask — "then how do I
  record who looked?" — and an absence answers it badly. Both documents now
  name the two honest routes and rank them: `@TomAudited()` on the endpoint,
  which is the usual answer, and `TomAuditTrail.recordAction`, for code that
  knows which rows mattered and has accepted the volume cost.

  The `read` enum member's dartdoc pointed at a declared-versus-automatic split
  that no longer mentions reads; it now says plainly that nothing in the
  framework produces the value and explains why it is kept. `tom_specs`'
  CE-LG mapping carried the same parameter in five places and is corrected in
  step: a SOM band saying reads count lands on the endpoint, not the entity.

- **`doc/scheduling.md`'s table of contents lists "Reporting an Outcome for a
  Run You May Have Lost".** The section was added after the contents were
  written and never listed, which is the failure mode a reader is least able to
  work around: the section is only reachable by scrolling past the list that
  claims to be a map of the file.

  The wider check that found it is now a committed tool rather than a script
  rebuilt each time — see `tool/check_doc_tocs.py` in the repository root. It
  audits every `## Table of Contents` in the tree for three faults: sections the
  contents omit, entries whose link resolves to no heading, and entries listed
  in an order the document does not follow. Across the repository's 118
  documents with a table of contents, this was the only defect outside the
  families already tracked for a deliberate decision.

## 1.2.0

### Features

- **grant-driven row scope (`resource`).** An entity carrying a `resource_key`
  column is now filtered — on reads *and* on writes — by the resource keys the
  current principal holds a grant on, with **no application-side resolver**. The
  C-5 grants and C-6 delegations already answered "which resources may this
  principal touch, and how strongly"; the new `TomResourceDataScope` (in the
  `authorization` module) simply asks them per query and binds the answer, and
  the new `TomResourceScopeSource` hook in `object_persistence` is the inversion
  that keeps `authorization → object_persistence` the only dependency direction.
  Wire it once at start-up with `TomResourceDataScope.install(delegationResolver)`.
  Delegations are folded in *through* `TomDelegationResolver` rather than around
  it, so the validity window, revocation, mode semantics and non-transitivity
  govern the row scope for free.

  The grades are the design: a row is admitted to a **query** at
  `TomAuthState.read` or wider and to a **write** only at `TomAuthState.full`, so
  a viewer's shared row is listed and opened while every attempt to modify it
  raises `TomDataScopeAuthorizationException` — the difference between "shared
  with me" and "mine". An unregistered role grades as nothing and grants nothing,
  so a typo in a grant row closes a door rather than opening one. Resolution is
  **live** (read per request, never from the token), so a revoked share stops
  granting at revocation rather than at token expiry;
  `TomResourceDataScope.runCached` amortises the several resolutions of one
  request into a single grant read without weakening that.

- **row scopes can distinguish read from write.** `TomDataScopeRegistry.register`
  and `registerAsync` now accept an optional `write:` resolver answering the
  narrower question "which values may this principal *modify*", threaded through
  `TomDataScope.build` / `buildAsync` / `allowedValues` / the new
  `allowedValuesAsync` by a `forWrite` flag and applied by the repository's three
  write guards. A kind that registers no write resolver writes exactly what it
  reads, so every pre-existing scope is unaffected. This is the general mechanism
  behind the `resource` kind's read/write grades; "may read every tenant, may
  write only my own" has the same shape.

### Behaviour Changes

- **grant scoping is now the default, not an opt-in.** `TomAnnotationAnalyzer`
  synthesises a `@TomDbScope(field: 'resource_key', scope: 'resource')` for any
  reflected entity exposing a `resource_key` column (or a `resourceKey` field),
  so forgetting the annotation can no longer silently publish every row. An
  entity that must stay global despite carrying such a column declares
  `@TomDbScope.unscoped()`.

  **Deployments that already have `resource_key` columns and no grant rows will
  see those entities return nothing** until the scope is installed and granted,
  which is the deny-by-default this change is for. The framework's own
  authorization tables are excluded twice over: they declare
  `@TomDbScope.unscoped()`, and they are additionally named in the constant
  `TomAnnotationAnalyzer.resourceScopeInputTables`. The constant is the
  load-bearing guard — it survives a stale generated `*.reflection.dart` whose
  class metadata predates the annotation, and a safety invariant must not depend
  on a deployment having re-run code generation before it upgrades. Scoping those
  tables would close the authorization layer against itself: a principal could
  reach its own grant rows only by already holding a grant on them, which no row
  can satisfy.

### Documentation

- `doc/object_persistence.md` gains a **Row Scopes** section covering the whole
  engine: the three built-in kinds, sync value lists versus async OR-unions and
  why the union is parenthesised, automatic scoping and its opt-out, the
  `runUnscoped` recursion guard, and the read-filters/write-rejects asymmetry.
- `doc/authorization.md` is brought up to date with the module it describes. It
  previously documented only the principal cache and opened by stating that
  nothing in the module grants or refuses anything, which the grant, delegation,
  grade and row-scope code has not been true of for some time.

## 1.1.4

### Bug Fixes

- **bare-flag bool coercion (RCJ2).** `TomArgs.fillFromArgs` recorded a bare
  flag (an argument with no `=`, e.g. `verbose`) as the String `"true"`, while
  its docstring claimed the reflection layer coerced it to the field's declared
  type. The reflection layer does **not** coerce a String into a `bool` field —
  it throws `reflection.set.unexpected_string_type` — so a bare bool flag could
  never fill a `bool` config field. Aligned `fillFromArgs` with
  `parseArgsToMap` by recording a bare flag as the boolean `true`, which
  matches how `key=true` already converts (`_convertString`) and keeps the
  reflection layer's strict String/typed contract intact. A bare flag now fills
  a reflected `bool` field directly; the pinned characterization test in
  `endpoints_pipeline_test.dart` was flipped from "throws" to assert success.
  Docstrings and `doc/cmdline.md` / `doc/api_reference/api_summary_cmdline.md`
  updated to describe the unified boolean encoding.

## 1.1.3

### Tests / Examples

- **cache direct-surface scaling (RCI4, one unblocked module).** Deepened
  `cache_test.dart` to the full connection-free public surface of the `cache`
  module (no public API change; 460 → 477 test cases). The prior suite covered
  the static `…NameCache`/`…TypeCache` helpers, LRU eviction, background-timer
  sweeps, worker-isolate forwarding, and the cross-isolate command objects — but
  the **direct `TomCache` instance surface** was only exercised transitively.
  This pass pins it directly:
  - **`getEntry`**: returns the stored entry object (unbounded), `null` for an
    absent key, promotes the read entry to MRU in a bounded cache, and — the
    distinctive contract — **does not check expiry** (an already-expired entry is
    still returned verbatim; expiry is `fromNameCache`'s job);
  - **`putEntry`**: unbounded store/overwrite, LRU eviction past the bound, and
    the single-entry update path (`cacheSize == 1` clear-and-re-insert);
  - **`removeEntry`**: no-op for an absent key, and middle-of-chain unlink that
    leaves a bounded cache's MRU chain coherent for later eviction;
  - **timer lifecycle**: the default one-hour `deletionIntervalSeconds` installs
    an active `deletionTimer` (and no `clearanceTimer`), both timers stay `null`
    when their intervals are `null`, a clear interval installs an active
    `clearanceTimer`, `stopTimers` cancels a running timer, and `createTimers`
    is idempotent (cancels and replaces the running timer);
  - **construction/properties**: `cacheName`/`deleteEntriesAfterSeconds`/
    `maximumEntries`/`clearIntervalSeconds` round-trip, `forType` names the cache
    `type.toString()`, and an unbounded cache reports a `null` `maximumEntries`.

  This is one module of the RCI4 unblocked residual; the remaining unblocked
  modules and the two blocked buckets (reflection-bootstrap and MariaDB fixtures)
  are filed as RCJ4 for later iteration.

## 1.1.2

### Tests / Examples

- **object_persistence full-surface scaling (RCF4, module 1 of 13).** Closed the
  connection-free public-surface gaps in the `object_persistence` query DSL and
  the SQL dialect (no public API change; 422 → 443 test cases). The prior
  `object_persistence_test.dart` covered `eq`/`gte`/`like`/`isNull`/`isIn`/
  `between` plus the save/annotation/injection paths; this pass added the
  remaining `TomQueryBuilder` builders and the dialect's value dispatch:
  - **comparisons**: `neq` (`<>`), `lt` (`<`), `lte` (`<=`), `gt` (`>`);
  - **string / null predicates**: `isNotNull`, `notLike`, `regexp`;
  - **literal builders**: `doubleOp`, `boolOp`, `dateTimeOp` (quoted ISO-8601),
    `dateOp` (unpadded `YYYY-M-D` — pinned so the non-padding is intentional);
  - **typed column references**: `doubleF`, `boolF`, `dateTimeF`, `dateF` (each
    renders the qualified `table.column` and collects itself as a field);
  - **dialect `objectOp` dispatch**: the runtime-type literal table
    (null→`NULL`, String→quoted+escaped, int/double/bool→bare, DateTime→quoted
    ISO-8601, Iterable→comma list) plus `nullOp`/`iterableOp`.

  The example gained matching steps 6–9. This is the first module of the RCF4
  per-module surface-scaling residual; the remaining 12 modules are filed as
  RCG1 for later iteration.

## 1.1.1

### Documentation

- **API reference (OT7).** Added a per-module API summary set under
  `doc/api_reference/` following
  `_copilot_guidelines/dart/api_summary_creation.md` — one
  `api_summary_{module}.md` for each of the 13 real modules (`authentication`,
  `authorization`, `cache`, `cmdline`, `configuration`, `datasources`,
  `db_migration`, `endpoints`, `healthcheck`, `little_things`,
  `object_persistence`, `server`, `transactions`) plus an
  `api_summary_index.md` with quick navigation, per-module type tables, and an
  alphabetical type index (~110 public types). Each summary lists only the
  public surface (constructors, properties, methods, operators, enums, and
  top-level functions/constants) cross-checked against the actual source and
  the package barrel. Placed under `doc/api_reference/` because this repo
  gitignores `**/doc/api/` (reserved for generated `dart doc` HTML). This
  delivers the "optional API summaries" deferred from the 1.1.0 OT3 pass
  (quest todo RCE4). No source or public API change.

## 1.1.0

> **OT3 verification (2026-07-15).** Re-confirmed the whole-package gates —
> `dart analyze` clean and `testkit :test` 422/422 green — and that all 13 real
> modules carry a one-to-one `doc/<module>.md`, `example/<module>/`, and
> `test/<module>_test.dart`. No code change; deeper per-module surface coverage
> and optional API summaries are tracked as quest todo RCE4.

This release is a documentation, test, and example pass over every module of
`tom_core_server` — adding dartdoc to all public symbols, a `doc/<module>.md`
guide, an executable example, and a test suite per module — plus a handful of
genuine bug fixes pinned by regression tests. No public API was added or
removed (the deletions below were unexported placeholders).

### Documentation

- Replaced the default package-template `README.md` with a customized one: a
  description of the package, a path-dependency getting-started section, correct
  usage snippets (`TomServer`, `TomArgs.fillFromArgs`, `TomEnvFile.read`,
  repository CRUD), and a Modules table covering all 13 exported modules. No
  code or public API change.
- **Final-review accuracy pass**: the README Server-module summary and the
  intro no longer advertise the unimplemented WebSocket / diagnostics /
  monitoring / form-handling capabilities (those were empty placeholders,
  removed below). The Server description now reflects the actual surface — the
  shelf middleware pipeline around the endpoint router — matching
  `doc/server.md`'s "Not Yet Implemented" section. Verified that all 13 modules
  have a one-to-one `doc/<module>.md`, an `example/<module>/`, and a
  `test/<module>_test.dart`; reflection/DB/socket-dependent surfaces are
  documented and integration-tested, the connection-free surfaces are
  unit-tested (196 tests, all green).
- **Authentication module**: added dartdoc to all public symbols
  (`TomAuthenticationServer`, `TomAuthenticationService`,
  `TomAuthenticationData`, `TomAuthenticationInfo`,
  `TomDummyAuthenticationService`, `LoginException`, `TomAuthenticationAdaptor`,
  `Tom2FAAdaptor`, `Tom2FAService`); a module guide at `doc/authentication.md`;
  an executable example at `example/authentication/`; and a test suite at
  `test/authentication_test.dart`. No public API change — removed only stray
  `// TODO:` comments (the deferred 2FA work is now recorded in the module
  dartdoc and the quest completion steps).
- **Authorization module**: added dartdoc to all public symbols
  (`TomAuthorizationCache`, `TomAuthorizationCacheEntry`,
  `TomAuthorizationCacheException`, `TomAuthorizationCacheStoreMessage`,
  `TomAuthorizationCacheRetrieveMessage`, `TomAuthorizationCacheExecutor`),
  including a corrected/relocated class doc and the main-isolate cache /
  cross-isolate forwarding model; a module guide at `doc/authorization.md`; an
  executable example at `example/authorization/`; and a test suite at
  `test/authorization_test.dart`. No public API change — removed only one stray
  `// TODO:` comment (its intent is now captured in the
  `TomAuthorizationCacheException` dartdoc).
- **Cache module**: added dartdoc to all public symbols (`TomCache`,
  `TomCacheEntry`, `TomCacheManager`, `TomCacheException`,
  `TomCacheStoreMessage`, `TomCacheRemoveMessage`, `TomCacheRetrieveMessage`),
  documenting the main-isolate cache / worker-forwarding model, the LRU bound,
  per-entry expiry, and the retrievable-entry-requires-a-deletion-time
  invariant; a module guide at `doc/cache.md`; an executable example at
  `example/cache/`; and a test suite at `test/cache_test.dart`. Removed a dead
  embedded `main()` test scaffold from `server_cache.dart` (its LRU coverage is
  now expressed through observable behaviour in the test suite).
- **Command-line module**: added dartdoc to `TomArgs` and its members
  (`fillFromArgs`, `parseArgsToMap`, `convertToObjectMap`, `intPattern`,
  `doublePattern`), documenting the shared value-conversion table and the
  flag-encoding difference between `fillFromArgs` (string `"true"`) and
  `parseArgsToMap` (boolean `true`); a module guide at `doc/cmdline.md`; an
  executable example at `example/cmdline/`; and a test suite at
  `test/cmdline_test.dart`. `TomEnvFile` was already documented. No public API
  change.
- **Configuration module**: added dartdoc to all public symbols
  (`TomServerConfigResourceProvider`, `TomConfig` and its `TomStringConfig` /
  `TomIntConfig` / `TomDoubleConfig` / `TomBoolConfig` specialisations,
  `TomBaseServerConfiguration`, `tomAppId`), documenting the resource-provider
  lookup model, `TomConfig`'s construction-time resolution, and the
  resources → environment → `.env` → args source precedence; a module guide at
  `doc/configuration.md`; an executable example at `example/configuration/`; and
  a test suite at `test/configuration_test.dart`. `TomYaml` was already
  documented. No public API change — removed only a stray `// TODO:` comment
  (the deferred JWT-settings work is now recorded in the class dartdoc and the
  quest completion steps).

- **Datasources module**: added dartdoc to all public symbols across the six
  files — the SQL-typed values (`TomDbType` and `TomDbInt` / `TomDbDouble` /
  `TomDbString` / `TomDbDateTime` / `TomDbDate` / `TomDbTime` / `TomDbBool`), the
  operator tree (`TomOperator`, `SqlString`), the dialect (`TomStandardSqlDialect`
  and every fragment method, `TomSqlDialect`, `MariadbSqlDialect`), the query
  objects (`TomTypePersistenceInfo`, `TomTypedPersistenceBase`, `TomQuery`,
  `TomGeneratedQuery`, `TomSelect`, `TomLiteralSelect`, `TomCount`, `TomDelete`),
  and the data-source/driver layer (`TomDatasourceInitException`,
  `TomDatasourceDriver`, `TomPreparedStatement`, `TomDataSource`,
  `TomDataSourceInfo`, `MariadbDatasourceException`,
  `MariadbPreparedStatementException`, `MariadbPreparedStatement`,
  `MariaDbDatasource`, `MariaDbXADatasource`); a module guide at
  `doc/datasources.md`; an executable example at `example/datasources/`; and a
  test suite at `test/datasources_test.dart` covering the connection-independent
  surface (dialect SQL-fragment generation and `TomDbType` `.of()` conversions).
  No public API change — removed several stray `// TODO:` comments (the
  SQL-injection-escaping of directly-interpolated literals and the
  result-set access-control work are now recorded in the quest completion
  steps; the architectural "should be in SqlDialect" notes are captured in the
  module dartdoc).
- **Database-migration module**: added dartdoc to all public symbols across the
  two files — the orchestrator and its contract (`TomDbMigrations`,
  `TomDbMigrator`, `TomDbMigrationAdaptor`, `TomDbMigrationException`) and the
  MariaDB implementation (`MariadbMigrationAdaptor`, `MariadbMigrationException`,
  `TomDbVersion`), documenting the keyed directory layout
  (`<datasourceName>/<schemaName>/[<version>]-<description>.<ext>`), reflection
  adaptor discovery, and the versioning-table idempotency/checksum-stability
  model; a module guide at `doc/db_migration.md`; an executable example at
  `example/db_migration/`; and a test suite at `test/db_migration_test.dart`
  covering the connection-free surface (`TomDbVersion`, the
  `TomDbMigrationAdaptor` type binding, and the exception types). No public API
  change — the literal-escaping of directly-interpolated migration scripts is
  noted in the module doc and tracked with the datasources follow-up.
- **Endpoints module**: added dartdoc to all public symbols across the two files
  — the annotations (`TomEndpoint`, `TomApiEndpointImplementation`,
  `TomService` / `tomService`, `TomApiImplementation`, `TomComponentReference`,
  `TomTransactional`, `TomErrorHandler` / `TomDefaultErrorHandler`, the
  `TomEndpointBase` contract) and the pipeline (`TomEndpointRouting`,
  `TomEndpointHandler`, `TomMethodMetadata`, `TomClassScanResult`,
  `TomEndpointRoutingInfo`, `TomEndpointHandlerException`,
  `TomEndpointPipelineException`), documenting the annotation-driven routing
  model, the per-request pipeline (access → parameter binding → transaction →
  invoke → result/error conversion), and the default opaque-`500` error handler;
  a module guide at `doc/endpoints.md`; an executable example at
  `example/endpoints/`; and a test suite at `test/endpoints_test.dart` covering
  the reflection-free surface (the annotations and the default error handler).
  No public API change — removed several stray `// TODO:` comments (the
  unimplemented form-field/file-upload/redirect, streaming/file response,
  WebSocket, and richer-authorization work is now recorded in the quest
  completion steps and folded into the relevant dartdoc).

- **Health-check module**: the module was already dartdoc-documented; added a
  doc comment to the `TomHealthService.health` endpoint method, a module guide at
  `doc/healthcheck.md`, an executable example at `example/healthcheck/`, and a
  test suite at `test/healthcheck_test.dart` covering the server-free surface
  (the `HealthAnalyzer` contract and `TomHealthServer.health`'s delegation to the
  global analyzer). The `/health` route itself is mounted by the reflection
  pipeline and is documented, not unit-tested. No public API change.

- **Little-things module**: added dartdoc to the sole public symbol
  `TomServerException` and its members (`isolateName`, `clientThrow`, the
  constructor, and the `toString` override), documenting its role as the base
  class for every server-raised exception and its two server-specific concerns —
  isolate attribution (`Isolate.current.debugName`) and zone-based request
  correlation (copying the current `TomRequestId`'s UUID into the inherited
  `requestUuid`); a module guide at `doc/little_things.md`; an executable example
  at `example/little_things/`; and a test suite at `test/little_things_test.dart`
  covering construction, defaults, the `TomException` inheritance, isolate
  attribution, the `toString` format, and request correlation via a `runZoned`
  carrying a `TomRequestId`. No public API change.
- **Object-persistence module**: added dartdoc to all public symbols across the
  seven module files — the persistence annotations (`TomDartType`, `TomDbTable`,
  `TomDbColumn`, `TomEntityId`, `TomJoinTable`, `TomReference`,
  `TomPersistenceEventHandler`) and `TomColumnInformation`; the operator tree
  (`TomUnaryOperator` / `TomBinaryOperator` and every concrete operator —
  literals, `Parameter`, the `*Col` references, `And`/`Or`, the comparisons,
  `Like`/`In`/`Between`/`Group`/`Regexp`, …) and `TomQuerySyntaxException`; the
  `TomQueryBuilder` DSL mixin and every factory; the `TomAnnotationAnalyzer`
  mixin and its exceptions; the repository contract (`TomRepository`,
  `TomSqlDatasourceRepository`, `MariadbRepository`, `TomCountResult`,
  `TomRepositoryType`); and the `TomQuerySentenceCompiler`. Added a module guide
  at `doc/object_persistence.md`, an executable example at
  `example/object_persistence/`, and a test suite at
  `test/object_persistence_test.dart` covering the connection-free surface (the
  `TomQueryBuilder` DSL / operator-tree SQL rendering through `MariadbSqlDialect`,
  BETWEEN arity validation, and the plain-data annotations /
  `TomColumnInformation`). No public API change — removed only stray `// TODO:`
  comments (the deferred work — `@TomJoinTable` / `@TomPersistenceEventHandler`
  detection, pageable / limit / slicing / sort result options, additional
  query-method keywords, and a `deleteById` prepared-statement bug — is now
  recorded in the quest completion steps).
- **Server module**: added dartdoc to every public symbol in `server.dart`
  (`TomServer` and its members, `TomRequestId`, `TomRequestLogInfo`,
  `contextSetupMiddleware`, `extractAuthentication`,
  `tomDefaultAuthenticationMiddleware`, `tomLoggingMiddleware`, `noopHandler`),
  documenting the shelf pipeline composition, the request-context / request-zone
  channels, and the JSON error mapping. Added a module guide at `doc/server.md`,
  an executable example at `example/server/`, and a test suite at
  `test/server_test.dart` (17 tests) covering the socket-free surface — the
  per-request value objects, `extractAuthentication`, and the
  `contextSetupMiddleware` / `tomLoggingMiddleware` /
  `tomDefaultAuthenticationMiddleware` / `noopHandler` middlewares; `TomServer`
  binds a real socket and needs a reflected configuration, so it is documented,
  not unit-tested. No public API change — removed only a stray `// TODO:`
  comment (the GZIP/autoCompress note).
- **Transactions module**: added dartdoc to all public symbols
  (`TomTransactionParticipant` and its hooks, `TomTransaction` +
  `isReadOnly`/`isRunning`/`registerParticipant`/`commitTransaction`/
  `rollbackTransaction`, `TomTransactionManager` +
  `startTransaction`/`getCurrentTransaction`/`transactional`, and
  `TomTransactionException`), documenting the participant contract, the
  commit-veto → rollback drive, the new-vs-existing return of `startTransaction`,
  and the single-static (per-isolate) current-transaction model. Added a module
  guide at `doc/transactions.md`, an executable example at
  `example/transactions/`, and a test suite at `test/transactions_test.dart`
  (11 tests) exercising the full self-contained surface with a recording fake
  participant. No public API change.

### Removed

- **Removed the empty `externalapis/` placeholder module.** It contained no
  Dart code — only a `readme.md` holding a single bookmark URL
  (`https://dart.dev/guides/google-apis`) — and was not exported, referenced, or
  depended on anywhere. Implementing it would have been speculative (no contract
  or consumer existed), so the placeholder was deleted. The workspace metadata
  still lists an `externalapis` module entry (no sources) until the next
  metadata regeneration.
- **Removed four empty placeholder files from the `server/` module**
  (`diagnostics.dart`, `forms.dart`, `monitoring.dart`, `websocket.dart`). They
  held only `// TODO:` markers (or were empty), were not exported, referenced, or
  depended on anywhere, and carried no contract — so they were deleted. The
  intended capabilities (diagnostics, monitoring, WebSocket support, server-side
  forms) are recorded in the quest completion steps and the `doc/server.md`
  "Not Yet Implemented" section.

### Fixed

- **`HealthAnalyzer` dartdoc example now overrides the right method.** The
  class-doc example overrode a non-existent `analyze()` method; corrected to the
  actual abstract method `analyzeHealth()` so the snippet matches the contract.
- **`TomStandardSqlDialect.iterableOp` now comma-joins correctly.** The
  separator was emitted only on the first element (`result.isEmpty ? "," : ""`),
  so `[1, 2, 3]` rendered as `"1,23"` instead of `"1,2,3"` — corrupting any
  `IN (...)` / list literal built through `objectOp`. Pinned by regression tests
  for multi-, single-, and empty-element iterables.
- **Cache `removeFromNameCache` no longer fails to forward / throw correctly in
  worker isolates.** The isolate-routing guard used `useInThisIsolate` without
  the negation present in its `toNameCache` / `fromNameCache` siblings, so the
  forward-or-throw decision was inverted. Pinned by a regression test asserting
  a missing cache in the main isolate throws `TomCacheException`.
- **Cache LRU promotion no longer corrupts the tail pointer.** When `getEntry`
  promoted the most-recently-used *tail* entry to the front, it failed to
  advance `_last` to the predecessor, leaving a stale tail that could evict the
  wrong (recently read) entry. Pinned by a test that reads an entry to promote
  it and asserts it survives the next eviction.

## 1.0.0

- Initial version.
