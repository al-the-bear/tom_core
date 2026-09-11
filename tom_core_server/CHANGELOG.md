## 1.3.0

### Changed

- **Pattern grants reach the graded view and automatic endpoint protection
  (tcopen74).** `TomGradedAccessControlInformation.resolveState` reads its
  binary fallback through the kernel's new
  `TomAccessControlInformation.holdsResourceKey`, so `*` and `prefix.*` grants
  count there as they do in resource-key protection. The endpoint pipeline's
  automatic protection accepts `*` and `<api>.*` for its container and member
  keys, and a `*` never covers a `-<member>` revocation, so a principal granted
  everything is not refused everything.

- **`TomSqlLeaseLock.forget` takes a `TomOneShotResource` (tcopen68)**, the
  kernel's new type for a resource name that is never acquired again, rather
  than any `String` — see the kernel's CHANGELOG. `forget` destroys the fencing
  counter, so only a name declared single-use may reach it.

- **The preference store enforces the contract's ceilings (tcopen54).** A
  write that would add a key beyond `tomUserPreferencesMaxPerPrincipal` (256)
  throws `TomUserPreferenceException('preferences.limit.exceeded')`; replacing a
  held key is never refused for the count. An oversized value is refused by the
  codec before a statement is built, well inside `value_json`'s 64 KiB.

  `TomUserPreferencesErrorHandler` maps the ceiling to a `409` and — a fix —
  every write-boundary refusal (`preferences.encoded.*`: too large, not JSON,
  not the declared type, an instant with no zone) to a `400`. Those were opaque
  `500`s, telling a client its own malformed body was a server fault worth
  retrying. They are matched by prefix, so a refusal added to the codec needs no
  handler change. Covered by the handler suite, the DB suite (ceiling, exact
  boundary, replacement, per-principal) and the live round trip.

- **The preferences read raises the kernel's absence key (tcopen53).**
  `readPreference` throws `tomUserPreferencesNotFoundErrorKey` and
  `TomUserPreferencesErrorHandler` maps that constant, so the key the client
  recognises and the key the server raises are one declaration. The wire is
  unchanged — still `preferences.not_found` in the envelope of a `404`.
  `TomUserPreferencesErrorHandler.notFoundKey` is removed: it restated the
  kernel's constant under a second name.

  `test/preferences_roundtrip_db_test.dart` asserts the convention against the
  served pipeline — a signed-in miss and an anonymous refusal both answer `404`,
  and only the miss carries the envelope — and its caller no longer reads a
  bare `404` as absence.

- **`TomHttpServiceLoginTransport` derives its channel through
  `TomServerChannel.forUri` (tcopen14).** The scheme-aware port derivation lived
  in three places, one of which had it wrong; it is now a named constructor in
  the kernel, and this transport's private copy is gone. The port it dials is
  unchanged.

### Added

- **`example/resources/resources_example.dart`** — the module had no example at
  all, which is what the readme convention exposed: a readme must name something
  under `example/<module>/`, and there was nothing to name. Seven steps in
  memory (bundles are maps, so nothing opens a file or a connection), ending on
  the two properties a reader most needs to have seen happen rather than read
  about: a half-translated bundle serving what it has and falling through for
  the rest, and a placeholder with no value left standing where a proof-reader
  can see it.

### Fixed

- **An XA transaction could never commit (tcincb158).**
  `MariaDbXADatasource` issued `XA END` + `XA PREPARE` from `endTransaction()`
  and `XA COMMIT` from `commit()`, but `TomTransaction.commitTransaction`
  drains its `commit()` loop *first* — so the prepare ran after the commit it is
  a precondition of. Against a real server that commit is rejected, because the
  branch was never ended; `commit()` catches and returns `false`; a `false` is a
  veto, so the coordinator turns the whole transaction into a rollback. The
  branch is left ACTIVE holding its locks, and nothing issues `XA RECOVER`, so
  nothing reclaims it. The rollback path only appeared to work: `XA ROLLBACK` is
  legal on an active branch, but the trailing `XA END null; XA PREPARE null`
  still failed, and the `null` is the branch id the successful rollback had
  already cleared.

  Both statements now live in `commit()`, issued as two round trips so a refused
  prepare stops short of the commit, and `endTransaction()` is the no-op that
  reports success its one-phase sibling already was. A failing `commit()` now
  *keeps* the branch id rather than clearing it — the rollback the coordinator
  runs next has to name the branch, and clearing would send `XA ROLLBACK null`
  and leave the real branch behind; `rollback()` clears it in its `finally`, and
  issues nothing at all when there is no branch, which is the state a
  participant is in when it committed before someone else vetoed.

  The reason a suite this size held the defect is worth stating: every XA test
  called `startTransaction` / `commit` / `endTransaction` in the order the
  *test* chose, and every test chose the XA-correct one. Nothing drove a
  participant through `TomTransaction`. Six tests now do, reading the recorded
  SQL — which is the only place the fault is visible, the branch id having no
  accessor.

  The contract was right and the driver was wrong:
  `TomTransactionParticipant` already said that a participant which cannot undo
  its commit "should do the work that can fail inside `commit` itself". It now
  names this driver as the case, and `endTransaction` says outright that it runs
  after every participant has committed, so nothing the outcome depends on
  belongs in it.

- **`XA ROLLBACK` was refused on every branch it was sent to (tcincb158).**
  Found by the live suite added for the defect above, which is the point of
  adding it: a recording data source cannot object to a statement, and a server
  can. `rollback()` issued `XA ROLLBACK` against a branch that had never been
  `XA END`ed, and MariaDB answers `XAER_RMFAIL: The command cannot be executed
  when global transaction is in the ACTIVE state`. So the rollback path did not
  work either — the branch stayed ACTIVE holding its locks, and the next
  statement on any other connection waited for it until the lock timeout.

  `XA END` is legal exactly once and on an ACTIVE branch only, and the two
  statements that finish a branch each require the opposite state: `XA ROLLBACK`
  refuses an active branch, `XA END` refuses a prepared one. A rollback can
  arrive in either — before `commit` ran at all, or after its prepare succeeded
  and its commit did not — so the driver now tracks which, and issues
  `XA END` + `XA ROLLBACK` for an active branch and `XA ROLLBACK` alone for a
  prepared one, rather than sending a statement and ignoring the failure.

- **`test/datasources_xa_db_test.dart`** — the XA lifecycle against a real
  server, driven by the real coordinator. Commits through a `TomTransaction` and
  reads the row back on a *separate* connection, because the connection that
  wrote can see its own uncommitted work and would report success either way;
  rolls one back and finds nothing; and runs two transactions in succession,
  which is the cheapest assertion that no branch was left stranded.

- **A malformed query sentence was reported as a missing column (tcincb156).**
  `find by title is`, `find by title is not` and `find by title not null` are
  all refused, and none of them was refused by the parser. Having declined to
  read the dangling keyword as an operator — every one of them becomes an
  operator only in company, `IS NULL`, `IS NOT IN`, `NOT LIKE` — the compiler
  fell through and read it as the name of the column being compared, then handed
  it to `TomAnnotationAnalyzer.determineColumn`. The author was told "No column
  match field [is] found. Must be a variable and must have `@TomDbColumn`
  annotation" and went looking for a field they never wrote, about a sentence
  that merely stops one token early. The sentence was rejected either way, which
  is why nothing caught this: it was rejected with the wrong reason, by a
  component that does not know it is parsing.

  `is`, `not`, `null`, `like`, `regexp`, `in`, `and`, `or` are now reserved in
  operand position, the same construction the `TRUE`/`FALSE` branches and the
  separator characters already use, and refused as
  `query_sentence_compiler.build_expression.keyword_in_operand_position` — which
  names the keyword, quotes the sentence, and says the sentence stopped early
  when the keyword is its last token. `AND` and `OR` are in the set although the
  outer loop joins predicates, because the expression parser is entered per
  operand: `find by title = and` presents one without the outer loop ever seeing
  it. The cost is the same as for the boolean literals — a column named `is` or
  `and` no longer resolves, and `@TomDbColumn(name: ...)` is how such a field is
  renamed.

- **Both annotation-analyzer exceptions were client-visible (tcincb156).**
  Neither `TomAnnotationAnalyzerException` nor
  `TomAnnotationAnalyzerSyntaxException` set `clientThrow`, so both inherited
  the base default of `true`. Every diagnosis they carry describes the
  deployment — a type absent from the reflector, an entity without
  `@TomDbTable`, the `@TomDbColumn` a field was expected to have — and a caller
  can act on none of it, so a sentence compiled inside a served request returned
  the entity's shape to whoever made that request. Both now pass
  `clientThrow: false` to `super` and neither takes it as a parameter, so it is
  an invariant of the type rather than a default a raise site could override —
  the construction `TomResourceLocaleException` was declared for.
  `TomQuerySyntaxException` stays visible for the opposite reason: it names the
  token that broke the sentence, which is the caller's own input.

- **Five data-source guards raised the bare base exception, and nothing said
  why (tcincb155).** The `.named(...)` constructors of the audit sink, the OAuth
  state store, the job store, the lease lock and the scheduler roll call each
  throw `TomServerException` itself rather than a subtype. They still do, and
  that is now a decision with an argument attached rather than an omission: all
  five refuse at construction, before a connection is opened and before any
  request is served, so a deployment meets them as a failed start-up and no
  `catch` clause is running for a subtype to serve. The key and the
  `datasource` parameter already carry what the operator acts on — one name in
  one configuration file. Four declarations differing only in spelling would
  add nothing.

  What was missing is that the exemption was undeclared, and an undeclared
  exemption widens. `TomServerException`'s dartdoc now states where it is
  raised directly and why, each of the five constructors names the key it
  throws (one of them documented no throw at all), and
  `test/server_exception_family_test.dart` pins the set by file and key, checks
  every key ends `.unknown_datasource` and reads three segments, and checks each
  site names the data source it could not resolve. A sixth direct raise now has
  to make the same argument rather than inherit it.

- **The `little_things` guide taught the pattern it should warn against
  (tcincb155).** Its `TomServerException` example threw the base class directly,
  with the key `'PAYMENT_FAILED'` — which is also the wrong shape, since
  `TomException` fixes keys as dotted-lowercase
  `<area>.<operation>.<condition>`. So the one worked example in the module's
  documentation broke both rules the module has about raising an exception. It
  now declares a subtype and keys it `payment.capture.declined`, and the two
  rules are stated beneath it with what checks each.

- **The `preferences` module had no suite carrying its name (tcincb154).** Its
  six were named after the types they exercise — `user_preference_dto_test.dart`,
  `user_preference_key_test.dart`, `user_preferences_service_test.dart`,
  `user_preferences_endpoints_test.dart`, `user_preferences_db_test.dart` and
  `user_preferences_roundtrip_db_test.dart` — so every inventory that matches on
  a filename reported the module as untested, which it emphatically was not. A
  filename is the only signal such a sweep can read without running anything,
  and the quieter cost is that a suite filed under another module's name is
  carried off by any change to *that* module with nothing making the loss
  visible. All six are renamed to `preferences_*_test.dart`; the accuracy given
  up is real, since the types genuinely are `TomUserPreference*`, and it buys a
  rule with no exceptions. The quarantine that had been suppressing the check
  for this one module is gone with it, so `every module has a suite that carries
  its name` now runs over all twenty.

- **`doc/preferences.md` had no `## Verification` section (tcincb154).** Twenty
  of the twenty-one module guides have one, and this was the exception: the
  guide named no suite of its own at all, so a reader asking what backs it had
  nowhere to go. The omission was invisible while the module's suites were named
  for something else — the check that a guide names every one of its
  name-matched suites had nothing to match — and the rename above exposed it.
  The new section describes all six, including why the DTO conversion needs a
  file of its own (a value loaded from the column is already UTC-flagged, so the
  round trip cannot see the normalisation) and why the round-trip suite exists
  at all (a preference following its user is a claim about two clients and one
  server, which neither half can make by agreeing with itself).

- **`scheduling`'s readme quick start was classified by nothing
  (tcincb154).** The readme carries a `## Quick start` and the blockquote saying
  the snippet needs generated reflection and a live database, but
  `test/readme_quick_start_test.dart`'s table had no row for it — and that
  table is what decides whether a snippet is run as a program or held to its
  disclaimer. Registered as `needsReflection`.

- **A denied caller's status was asserted as `500` in a `db`-tagged suite
  (tcincb154).** `preferences_roundtrip_db_test.dart` still described a
  pre-invocation denial as an opaque `500` distinguished from a handler failure
  only by its error envelope. A denial answers a bare `404` — the endpoint is
  rendered indistinguishable from one that does not exist — so the status is now
  the discriminator, and a stronger one: removing `access:` from the contract
  makes the same request answer `500`, which the test catches.

- **The `## Status` block claimed a test count nothing checked (tcincb153).**
  It stated "3633 test cases across 95 module suites … 408 of them live in the
  20 suites tagged `db`" against a tree holding 103 suite files and 24
  `db`-tagged ones — and those figures were themselves a correction, made days
  earlier, of a count that had reached less than half the truth. The mechanism
  is structural, not careless: every added test is a README edit nothing asks
  for. The block now describes how the suite is run and what the `db` tag gates,
  and gives no number. Two new tests in
  `test/api_reference_coverage_test.dart` hold it there — one pinning the
  stated version to `pubspec.yaml`, the claim in the block a reader actually
  acts on, and one failing if a count comes back.

- **The `scheduling` module readme was the only one of twenty missing three of
  the four elements they all share (tcincb152).** No attribution blockquote, no
  `## Key types` heading, no `## Quick start`. It was not a thin readme — it is
  the third-longest in the package and has the most substantive sections of any
  — it was a complete one written to a different shape, most likely before the
  convention settled. A convention that settles without being written is one a
  document can miss entirely while reading as finished work, which is how this
  survived every review the module had.

  The `## Key types` heading is the clearest of the three: the table was already
  there, unheaded, so it appeared in no document outline and a reader scanning
  headings — the only navigation a 150-line readme has — did not find it.

  The quick start states its preconditions as numbered steps, and its third step
  is that there is no third step: `createSchema` defaults to `true`, so the
  stores issue their own `CREATE TABLE IF NOT EXISTS` and need no migration
  applied first — unlike the entity-backed modules, whose quick starts have to
  say the opposite. Its output was verified by running the sequence against a
  live MariaDB, which is what the stated `// nightly` is worth.

  `tool/check_module_readme_shape.py` holds all 53 module readmes across four
  packages to the four elements, and
  `_copilot_guidelines/component_module_readme_example.md` gains the level that
  describes them. The heading is matched on its opening words: two kernel
  modules ship functions beside their types and head the table
  `## Key types & functions`, which is the same undertaking more accurately
  titled.

- **A pre-invocation access denial reached the client as an opaque 500
  (tcincb149).** The check runs before the invocation, so its throw was outside
  the per-endpoint `try`, escaped the endpoint's own `errorHandler`, and was
  rendered by the server-level layer as `Response.internalServerError`. The
  framework's out-of-the-box answer to "you are not allowed to do this" was the
  same status as "the server broke": a client stack retrying `5xx` with backoff
  would hammer an endpoint it will never be allowed to call, and both samples
  carried a **copy of the framework's key** purely to map it to something else.

  **A denial answers a bare `404` now** — no body beyond `Not found`, no
  `tomErrorEnvelope`, no error key, and the same response a route that does not
  exist would give. The WebSocket handshake is refused the same way.

  `403` was the obvious answer and is the wrong one. It says "this exists and
  you may not have it", which is a working oracle for the caller who was refused
  the data precisely so they could not learn that: walk the id space against a
  resource-key-protected endpoint and the ids answering `403` are the rows that
  exist. The contract arm leaks the same way one level up — a `403` on
  `/admin/users` tells an anonymous prober that this deployment has an admin API
  and how it is spelled. The body carries no key for the same reason: an
  envelope naming `access_denied` on a `404` undoes the whole of it in one
  field.

  This is the rule the samples had already reached for themselves. The app
  sample's `itemNotFound` reports an unreachable row as missing "so no endpoint
  leaks its existence"; the framework now applies that one layer up, to the
  endpoint itself, instead of leaving each deployment to rediscover it.

  The diagnosis is not lost, it moves: the denial is audited unconditionally
  with the principal, the endpoint and the outcome, and the message reaches the
  server log. An operator asking why a caller got a 404 has a record; the caller
  does not. Deliberately **not** routed through `TomEndpoint.errorHandler` —
  those hooks are for errors *of the invocation*, and one written to map a
  domain exception to a `409` would be handed a security decision it was not
  written for.

  `tomEndpointAccessDeniedErrorKey` is exported. It names the audited event
  rather than a wire status, and having no name here is what got it hand-copied
  into two sample servers.

  In the samples: `advanced_auth_server`'s `forbiddenOnAccessDenied` and its key
  are deleted (the handler is unreachable now), `advanced_app_server` drops its
  key and its 403 mapping, `advanced_client_core`'s admin exception documents
  that a pre-invocation denial is not one of the errors it carries, and five
  README documents are corrected. Four framework tests moved from asserting a
  thrown exception to asserting the served response — including the socket one,
  whose discriminator was "throw versus 404" and is now the audit record, which
  was always the stronger of the two.

- **A documented test pointer was only checked in the guides, and only if it
  was spelled as a suite (tcincb148).** `a guide names the suite that covers
  what it describes` swept `doc/*.md` and matched `*_test.dart` or `*.sh`. The
  package writes pointers in five places and cites more than suites, so most of
  them were unread: 434 citations across the guides, the api summaries, the
  module readmes, the suite headers and the example dartdoc, of which the sweep
  saw 145.

  All five surfaces are swept now, `.dart` files by their comment lines only —
  code is full of paths that are not citations. The pattern also reads any
  `.dart` under a `test/` directory, not only a suite:
  `test/contracts/scheduling_contract.dart` is the shared contract three stores
  are held to, two documents name it, and it went unread for as long as the
  pattern asked for a suite's spelling.

  **Naming a sibling package now resolves a reference instead of excusing it.**
  `test/ops_anchor_test.dart` in a paragraph that says `advanced_ops_server` was
  waved through unread — an excused pointer is exactly as unchecked as an
  unwritten rule. It is resolved against that package now, in either spelling
  (the package named in the sentence, or as the path's own first segment), and
  the exemption is deleted. One citation was conformed to make this work:
  `file_endpoint_test.dart` said "the kernel's own", which named no directory.

  A flaw found while proving it: the "anywhere under this package" fallback
  walked `.` recursively, which reaches `.dart_tool` and its copies of every
  dependency — so a citation could resolve against a package this repository
  does not author. It walks `lib`, `test`, `example`, `tool` and `doc` now.

- **A cited test *group* was checked by nothing (tcincb148).** A coverage
  pointer names the group rather than a line number, because a line number rots
  silently while the file around it is edited — the pointer that started this
  had drifted some seven hundred lines. That trade is only safe if something
  reads the name, and nothing did.

  Every `group named `X`` citation is now resolved against the suite named in
  the same paragraph. The spelling is the guard: measured over every surface,
  the looser forms produced twenty citations of which seven were not groups at
  all — `groups `X` exposes` names three getters, `their `title` group value` is
  a SQL `GROUP BY` column, and ``object_persistence` group classes` uses the
  word as a verb. So the citation got one spelling and the corpus was made to
  conform, in nine places. A convention costs one word per citation; the
  alternative is a list of exempt phrases, which is the quarantine this
  repository refuses elsewhere.

  8 new tests (509 → 517), verified by mutation: a readme naming a suite that
  does not exist, a header citing a renamed group, a cross-package pointer
  losing its package name in either direction, and the shared contract renamed.

- **Three more suite headers deferred coverage to a document and to an
  integration suite this package does not have (tcincb147).** The template —
  "covered by `doc/<module>.md` and integration tests, not here" — was in
  `server_test.dart`, `endpoints_test.dart` and `object_persistence_test.dart`,
  and in an in-file comment of the endpoints suite that cited the header as its
  authority. Neither clause located anything: a document covers no code path,
  and there is no integration directory, no such file, and
  `tool/run_db_tests.sh` only starts the database the `@Tags(['db'])` suites
  already need. Each now names where the coverage is, established by looking
  rather than assumed, and each answer was different:

  * **endpoints** — `endpoints_pipeline_test.dart`, which builds a router over
    the reflected fixture and serves requests through it. The header's premise
    was half wrong: the split is generated reflection, *not* a socket. That
    suite binds no port and needs no database.
  * **object persistence** — the sentence grammar has five dedicated
    connection-free suites (`query_sentence_is_in_test.dart` and its three
    siblings, plus `query_sentence_rejection_test.dart`), the repositories two
    (`crud_repository_exceptions_test.dart`,
    `crud_repository_delete_counts_test.dart`), and only the round trip needs a
    database. A scripted datasource is what makes the failure paths reachable at
    all — a real database will not produce a broken row set on request.
  * **server** — nothing in this package calls `TomServer.start()`; no suite
    binds a port. Its coverage is the *source-order* guard in
    `api_reference_coverage_test.dart` (the self-login must precede the bind, a
    window a passing integration run would not notice) and the sample scripts
    `core_server_sample/tool/run_integration.sh` and
    `advanced_client_core/tool/run_cross_tier_integration.sh`, whose servers end
    their `main` with `TomServer(configuration).start()`. Saying "a sample's
    script" rather than "integration tests" is the point.

  A phrase guard now sweeps every suite in `test/` for the template, flattening
  wrapped comments first because the original spanned three lines. It is honest
  about its reach: it cannot tell a true pointer from a false one, only that the
  phrase four headers reached for is gone. The stronger rule — that a named
  group exists — was measured and refused, on the same finding as the
  documentation guards: a backticked span in a comment means "a literal token",
  not "a group name". Of 150 multi-word backticked spans in `test/`, nine name a
  group; restricting to paragraphs that also name a suite leaves 26, of which 19
  still do not. Enforcing it would need a list of exempt phrases.

  4 new tests (506 → 509). `api_reference_coverage_test.dart` excludes itself
  from its own sweep — by name, with a test asserting the exclusion is still
  exactly one file, so the rule cannot be escaped by moving a claim next door.

- **The reflection-currency guard never read `lib/`, which is where the defect
  it exists for happened (tcincb146).** `test/reflection_currency_test.dart`
  compared the committed artifacts against the fixture and example roots only.
  `MariaDbDatasource`'s `@tomReflector` and `@TomDatasourceDriver('mariadb')`
  were separated from their class by two private helpers written between them,
  so the `mariadb` driver left the runtime registry and every server configured
  for that type would have failed at start-up — and the guard was looking
  elsewhere. The fixture root imports the package barrel, so `lib/` is walked
  now: 44 more reflected classes, and a test that pins the widened scope by
  name, because narrowing it back leaves every other assertion passing over the
  fixture's own dozen.

- **A class annotation that had come loose was reported by nothing
  (tcincb146).** The staleness check is one-directional — it names a class the
  generated file is missing — and a detached annotation takes its class *out of
  the declared set*, so nothing is missing and nothing is said. The class simply
  stops being discoverable, in the source and the artifact alike, and Dart does
  not object: the annotation is still valid, it is just on something else.

  `_looseClassAnnotations` reports the other half, over `lib/` and the fixtures,
  for the six annotations a `tomReflector.annotatedClasses` walk reads
  (`@TomEndpoint` is excluded — it belongs on a method). It shares the
  line-based attribution `_reflectorClasses` already used, so the two agree by
  construction about what "attached" means, and it accepts the shapes the
  package actually writes: a wrapped argument list, a named-constructor
  annotation (`@TomDbScope.unscoped()`), a comment between the run and the class.

  5 new tests (7 → 12). Verified by mutation on real source: reinstating the
  detachment fails the new group while `datasources_test.dart` still passes,
  which is the whole of why it went unseen; adding a class to `lib/` without
  regenerating fails the widened staleness check; and narrowing the scope back
  fails the test that pins it.

  `doc/reflection_generation.md` gains the rule and its consequence, and its
  verification table now names all four checks and what each settles.

- **Nothing checked that a summary referring the reader elsewhere referred them
  somewhere (tcincb145).** `api_summary_file_storage.md` and
  `api_summary_endpoints.md` each hand the row-side file contract
  (`TomFileRepository`, `@TomFileReference`) to
  `api_summary_object_persistence.md`. Both referrals were broken at once and
  for months: that summary documented neither, and `TomFileRepository` — the
  type `TomFileSlots.register` takes in its own published signature — had no
  entry anywhere in the reference.

  The sections themselves arrived with tcinc597, which reconciled the
  object-persistence Source list and found `file_reference.dart` documented
  nowhere. So the referrals resolve today by side effect of a different repair,
  and nothing stops them breaking again — a section renamed, or a sentence
  repointed at the wrong tier, and the reader finds out by opening the document.

  `api_reference_coverage_test.dart` now reads every paragraph that links to
  another summary and requires each framework name it hands over to be
  documented **here or in one of the summaries that paragraph links to**. Both
  halves of that rule are load-bearing: a referring paragraph routinely names
  types belonging to two tiers — "the bytes live in a `TomBlobStore` … and the
  row-side contract (`TomFileRepository`) is Object Persistence's" is one
  sentence with two destinations — so demanding every name in every linked
  summary would report the corpus's own idiom.

  Documented means *has a section*, not *is mentioned*: `TomFileReference` spent
  those months appearing as the type of a field in another class's table, and a
  referral pointed at that appearance. Contents lists, tables and fenced blocks
  are not referrals — the first two are full of links and neither promises
  anything about where a type is described.

  The corpus refers across summaries in exactly two places, both about file
  transfer, which is the one feature split across three tiers — and both were
  broken. 6 new tests (500 → 506), verified by mutation: deleting the
  `TomFileRepository` section reproduces the reported state, naming both
  referrals with file and line, and repointing one referral at the wrong summary
  fails on its own.

- **Backend-specific storage keys reached the callers the translation exists to
  protect (tcincb144).** `TomBlobStore._translating` and `get` both passed a
  `TomStorageException` through with a bare `on TomStorageException { rethrow; }`
  — but that catches the **type**, and the type is also what every backend
  raises its *own* failures as. So `storage.s3.request_failed`,
  `storage.s3.no_upload_id`, `storage.s3.part_without_etag` and whatever an
  application backend raises rode through the translation with the module's own
  answers, and a caller switching on `error.key` saw one key when the deployment
  was configured with S3 and another when it was configured with the directory
  backend, for the same fault. That is the coupling `doc/file_storage.md` says
  twice that the module removes.

  The match is on the key now: `TomBlobStore.passThroughErrorKeys` is the closed
  list of what reaches a caller as it was raised, and everything else is wrapped
  under the operation's key with the original kept as `rootException` — the S3
  status and code are still in the log, no longer part of the contract code is
  written against.

  The list turned out to be four, not the three the dartdoc named.
  `storage.blob.invalid_key_prefix` is the deliberate sibling of `invalid_key`
  ("a bad key is a caller's mistake, a bad prefix is a deployment's"), is
  asserted uniformly across every method by the suite's own `_refusesEverywhere`
  sweep, and is backend-independent for the reason that decides membership: the
  limit it enforces inside the S3 backend is `maxKeyLength`, the rule every
  backend obeys, not S3's own, which is twice as large.

  `get` carries its own copy of the rule rather than routing through
  `_translating`, because an `async*` body owns its `try` and handing the stream
  to a helper would put the helper's `await` between backend and consumer —
  which is the buffering the partial-delivery contract forbids. A test holds the
  two in step and asserts the partial delivery alongside.

  Six tests (108 → 114) plus five rewritten to state the new contract, and a
  `_ThrowingBlobStore` fixture, because no shipped backend can be made to raise
  an arbitrary `TomStorageException` on demand. Verified by mutation: restoring
  either bare rethrow, dropping `invalid_key_prefix` from the list, and
  admitting an operation key to it each fail.

- **`oauthStateTableDdl` was the last DDL helper nothing exercised, and the
  OAuth-state migration the last one with no spelling guard (tcincb143).** The
  function had zero references in `lib/`, `test/` or `example/` while its six
  live siblings carry between five and eleven each — documented, exported public
  API that no test would have noticed breaking.

  `framework_schema_test.dart` was not covering it. That suite replays the
  shipped chain and compares the schema it *arrives at*, which is the stronger
  check and is deliberately blind to how a statement is spelled. Measured rather
  than assumed: narrowing `state` from `VARCHAR(191)` to `VARCHAR(64)`, making
  `client_language` nullable, deleting the `expires_at` index the sweep rides,
  and coarsening `created_at` to a plain `DATETIME` **all four converge green**
  and all four now fail. A spelling is what a deployment copies into its own
  migration, and for a store constructed with `table:` set to a non-default name
  there is no shipped file at all — the helper is the only source of its DDL.

  `oauth_state_store_test.dart` gains the comparison the scheduling, audit and
  file-storage suites already had (7 tests, 5 → 12), reusing `normaliseSql` and
  `readMigration` from `test/fixtures/sql_text.dart` rather than a fourth copy
  of the judgement about what "the same statement" means. Beyond the file
  comparison it pins what the store relies on: the handle is the identity with
  no surrogate key beside it, the sweep has an index to ride, the PKCE pair are
  the only nullable columns — the login-context columns hold `''` for "not
  supplied", so a nullable one would be a second spelling of absence — and both
  instants are `DATETIME(6)`, the width `sqlInstant` writes.

  `reference_migrations_test.dart`'s `_guardedElsewhere` now reads the same way
  for every module: the authentication entry names the suite that compares the
  file, not only the convergence chain.

- **`toString()` on an unopened `TomBlobStoreInfo` threw
  `LateInitializationError` (tcincb142).** `_store` was a `late` field with no
  initializer and `toString()` interpolated it directly, so an entry that had
  been constructed but not opened could not be rendered at all — and neither
  could `store` be read. Every configured entry passes through that interval,
  and an `open()` that throws (an unregistered backend, a missing setting)
  leaves one behind, so the two places it bites are a debugger's variable pane
  and the error report about the very failure being diagnosed. A `toString` that
  throws is a hazard out of all proportion to its purpose.

  The field is nullable now rather than `late`, because the entry genuinely
  spends an interval without a store and a `LateError` names the private field
  instead of the mistake. `toString()` renders `TomBlobStoreInfo files directory
  <unopened>` — the same three segments either way, since a rendering that
  dropped the field would be the short form in exactly the case a reader is
  trying to understand. `store` raises the named
  `storage.registry.store_not_opened`, carrying the store's name and its
  configured type, and the new `isOpen` asks the same question without throwing.

  Six tests in `file_storage_test.dart` (102 → 108), including the way an
  unopened entry is actually met: after a failed `open()`, where the entry must
  still render, still refuse `store` by name, and still be absent from the
  registry. Verified by mutation — restoring the raw interpolation, replacing
  the guard with `_store!`, dropping the exception's parameters, and registering
  the entry before building its store each fail.

- **The checked-in reflection artifacts were the one file nothing read
  (tcincb140).** `analysis_options.yaml` excludes `**/*.reflection.dart`, for a
  good reason — a mirror reflects whatever its source declares, including
  deprecated and `@visibleForTesting` members, and a generated file that trips
  several lints per package teaches everyone to ignore the analyzer. The cost
  was invisibility: not analyzed, not formatted, not reviewed, so a *reference*
  in one could rot in silence. `advanced_ops_server` carried one —
  `MariadbMigrationAdaptor` lost `splitSqlStatements` to the SQL-lexer
  extraction, its mirror went on naming it, and `dart analyze lib test` reported
  "No issues found!" while every test file in the package failed to load with
  `Member not found`.

  `tool/check_reflection_artifacts.py` analyzes the 35 artifacts across 18
  packages by explicit path — which the analyzer honours whether or not the
  options exclude them — and faults only on `error` severity, because a warning
  in generated code is the generator's style and faulting on it would recreate
  the noise the exclusion suppresses. About four seconds per package.

  It is deliberately the *cheap* half. `reflection_generation.sh --check`
  answers the stronger question — is this file what the generator would emit
  today — at some ninety seconds per package, twenty-odd minutes for the
  repository, which belongs before a release rather than in a gate pass. An
  artifact can pass the new gate and still be stale, because a mirror merely
  *missing* a class the source has added names nothing that does not exist.
  What it cannot do is pass and fail to compile, which is the failure that takes
  a suite down.

- **A limitations bullet could name a class that no longer exists and nothing
  disagreed (tcincb139).** The sweep over `## Not Yet Implemented` checked that
  a guide *has* the section and that claims of unfinished work live only inside
  it. It never read the bullets. A section nobody re-reads is the one place in a
  guide where staleness is invisible — a bullet naming a renamed class reads
  exactly like one naming a class that is still there — so the names are now
  checked against `lib/`.

  The rule is the case hump, and it was chosen by measurement rather than
  assumed. Backticks in these guides mark *any* literal token: 192 of the 365
  backticked spans in these twenty sections are a JWT claim (`exp`, `iat`), a
  SQL keyword (`DATE`, `LIMIT`), a locale tag (`de_AT`), an HTTP header
  (`Range`), a shell fragment or a value. "A backticked identifier must exist"
  would therefore be a rule about vocabulary, enforceable only with a list of
  exempt words that grows whenever a guide names a new protocol. A
  lowercase-then-uppercase transition is Dart's naming convention and no other
  vocabulary's here, so it selects the 173 spans this package could have
  declared — `TomFileSlots`, `MariadbMigrationAdaptor`,
  `coercePrimitiveParameter`, `globalSettingMaxFilePartBytes` — and nothing
  else, with no exempt list at all.

- **`doc/object_persistence.md` set the query keywords it has and the ones it
  has not in the same typography (tcincb139).** Both lists were code spans, so
  the only way to tell which sentence the grammar accepts was to read the prose
  between them — and two of the absent keywords (`isEmpty`, `isNotEmpty`)
  happen to be real Dart members, which made the collision invisible. The absent
  ones are now italic and the supported ones stay as code, with the guide saying
  which register means which.

  24 new tests in `test/api_reference_coverage_test.dart` (476 → 500), verified
  by mutation on the real documents: a renamed class, a renamed member inside a
  dotted name, and the keyword bullet restored to its old typography each fail
  their own module's test, and twenty-one non-Dart tokens are asserted *not* to
  be judged.

- **Four documented signatures gave a parameter a type the source does not, and
  nothing could have said so (tcincb138).** `api_summary_messaging.md` typed
  `TomDeliveryException.permanent`'s and `.transient`'s `stack` as `Object?`
  where both factories declare `StackTrace?`, and `api_summary_cache.md` typed
  `TomCacheEntry`'s and `TomCacheStoreMessage`'s `value` as `Object?` where both
  fields are a non-nullable `Object` — a nullability the source dartdoc spells
  out ("Never `null`") and the summary's own `toNameCache` row already
  contradicted. Both are the same mistake in the same direction: a parameter
  documented from the *field* it eventually reaches rather than from the
  *constructor* it is passed to. A reader copying either signature writes a
  parameter wider than the one it forwards to, and hears about it from the
  analyzer.

  The reason a hand sweep could not close this is that a signature is the one
  part of a summary nothing was reading. `test/api_reference_coverage_test.dart`
  parsed constructor listings for *presence* — that every declared parameter is
  named — and deliberately read names only, because a name sits at a fixed place
  in every declaration shape and a type does not. It now reads types as well,
  and resolves the two shapes that state none: `this.x` from the field it names,
  and `super.x` from the superclass constructor — walking into `tom_core_kernel`,
  because `TomException` is where `stack` is finally spelled and every exception
  in this package reaches it through a chain of `super.stack`. Where the chain
  leaves both packages, or ends on an unsubstituted type parameter
  (`TomConfig<T>.withDefault(T value)`, which the summaries correctly write as
  `String`), the parameter is skipped rather than guessed at.

  Member tables are read too, not only fenced blocks: the two messaging faults
  are rows under `Static Methods`, because a static factory has no constructor
  block to live in — so a check that read only fenced listings could never have
  seen the two it was written for. 32 new tests in
  `api_reference_coverage_test.dart` (444 → 476), the census verified by
  mutation in both directions — a widened type, a narrowed one, an agreeing one,
  and the sibling package removed, which is the failure the guard could not
  otherwise report about itself.

- **`doc/endpoints.md`'s first worked example showed a service that mounts
  nothing (tcincb137).** `@tomService class GreetingService` — one concrete
  class carrying both the annotation and its own method bodies — is well-formed
  Dart that resolves to no instance: `findServiceInstance` matches an
  implementation to its service by *supertype*, and a class is not its own
  supertype, so `initializeRouter` refuses it at start-up with
  `endpoint_pipeline.initialize_router.no_service_instance`. The compiler cannot
  warn about it, because it checks neither the annotation set nor the instance
  resolution — which is why the guide's first snippet went a long time being
  the one shape that cannot work.

  The example is now the two-type pair the module readme already shows, and it
  is **anchored in compiled code rather than corrected in prose**:
  `GreetingService` / `GreetingServer` and their two DTOs are declared in
  `test/fixtures/reflection_fixture.dart`, and `endpoints_pipeline_test.dart`
  mounts the route, posts a body and reads the greeting back, resolves the
  `@tomComponent` as the service instance, and asserts the pair is **verbatim
  identical** to the snippet in the document. For a scanned pipeline "it
  compiles" is only half the claim.

  The prose no longer implies one class suffices — it states the supertype rule
  and what start-up does about it — and `@TomPublicAccess()` is shown, because
  the pipeline's default is to protect a route and the reader's first endpoint
  would otherwise answer 403 the moment they hardened their server.

  The sweep for other occurrences found none: the WebSocket example in the same
  document was already the two-type shape.

- **An accepted WebSocket upgrade was never logged (tcincb136).** The pipeline's
  handshake line stood after `await handler(req)` — and `handler` is
  `shelf_web_socket`'s, which for a valid upgrade calls `Request.hijack` and so
  throws `HijackException` by contract, letting shelf take the socket over. The
  `await` therefore never returns on the path that matters, and the statement
  after it was live only for **refused** upgrades. The one event an operator
  wants in a socket access log was the one the pipeline could not record.

  Both outcomes are logged now, from the two places they leave by: a refused
  upgrade returns a response and is logged with its status as
  `[WebSocket handshake refused]`; an accepted one is logged from a `catch` on
  `HijackException` as `[WebSocket handshake]`, reporting `upgraded` rather than
  a status code shelf writes itself. The exception is **rethrown** — catching it
  would leave shelf writing an ordinary reply over a socket the handshake has
  already claimed, which the mutation confirms: swallowing it breaks the two
  pre-existing live socket tests as well as the new one.

  The todo's open question — whether `tomLoggingMiddleware` writes its generic
  fallback for a hijacked request — is answered and asserted: it does not, and
  not only because `hasBeenLogged` is now set. The middleware reads the response
  through `.then`, and a hijack arrives as an *error*, so its success callback
  never runs at all.

  Asserted over a loopback server with a real connection, which is the only
  place an accepted upgrade exists — the connection-free suite reaches the
  handshake site through a plain `GET`, and that is a refusal. Both suites now
  say which outcome they are about.

- **Every example transcript is now pinned to the steps it prints (tcincb134).**
  The `assert`-to-`check` conversion this todo was raised for is complete —
  no example holds an `assert`, every one states its expectations through the
  shared throwing helper, and `examples_test.dart` refuses a private `check`, a
  check inside a `catch` a handler would swallow, and an example nothing spawns.
  What was left is the other half of the guarantee: a `check` that throws
  catches an expectation that is *violated*, and says nothing about a step
  **removed** — the run stays green with one fewer demonstration — or a step
  **added** without anyone deciding it belonged, which is a surface nothing
  checks.

  Two module suites already recorded their step lists; the other twenty-three
  examples did not. A manifest in `examples_test.dart` now records the count for
  all twenty-five and asserts the transcript against a real `dart run`, in both
  directions: an example with no entry fails rather than running unmeasured, and
  an entry left behind after a deletion fails rather than describing a file that
  is gone.

  The unit is the step **number**, not the printed line. `export`'s step 2
  prints a line per renderer and `messaging`'s step 8 one per delivery outcome,
  which reads exactly as intended and would fail a rule counting lines. `0`
  records a transcript that is not numbered — the four authentication programs
  narrate a flow in prose — so a transcript that starts being numbered has to be
  registered rather than arriving unmeasured.

  It found one transcript already wrong:
  `example/authorization/resource_data_scope_example.dart` printed 1, 3, 4 … 10.
  Step 2 installs the scope over four grants and printed nothing, so a reader
  following the transcript met a gap where a step should be. It reports what it
  installed now.


- **A migration that failed was recorded as failed and then treated as applied
  forever (tcincb133).** `applyMigration` writes the outcome row on both paths —
  `success = 0` when the script threw — and rethrows, so the run aborts. Nothing
  read the column back. On the next run the failed version was *present* in the
  history, and its description and checksum agreed because both were written
  from the same script, so the idempotency rule found it applied and skipped it,
  silently, from then on. The column recording the failure was written by this
  module and read by nobody in it.

  `initializeMigration` now refuses to bind to a schema whose history holds such
  a row, raising
  `mariadb_migration_adapter.initialize.failed_migration_recorded` and naming
  the version, the description, the schema and the repair.

  **Refusing rather than retrying, because MariaDB does not roll DDL back.** A
  script that failed halfway left statements behind and the schema is in a state
  nothing describes; a blind re-run meets its own `CREATE TABLE` on a table that
  now exists and fails again, every time. So the run stops before any script is
  offered — which also stops the migrations *after* the failed one, and stops on
  a node whose environment tags mean it would never have run that script. Both
  follow from where the damage is: in the database the node is about to use, not
  in the tree it would have applied.

  Repair is a human's, and the message says so: finish or undo what the script
  left, then set `success = 1` to record it as applied, or delete the row to
  have it run again. Both repairs are asserted, as is that a refused adaptor is
  left unbound — so a caller that swallowed the exception cannot go on to apply
  migrations judged against a history that never loaded.

- **Fourteen guides' contents lists omitted every one of their sub-sections; 146
  entries were missing (tcincb132).** The check stopped at `##` by construction,
  so a reader deciding whether a document answers their question saw a fraction
  of what it does — `authentication.md` has fifty sub-sections behind sixteen
  chapters. That is the same failure the top-level check exists to prevent, one
  level down.

  Every guide now lists its `###` and `####` headings, indented two spaces per
  level under the chapter they belong to, which is the shape one guide already
  used at four levels. The check reads all three through one walk: the existing
  completeness, dangling-anchor and document-order rules apply unchanged, and a
  fourth was added for the indent — the only thing saying which chapter a
  sub-entry belongs to, and without which a structured list of sixty becomes a
  flat one nobody reads.

  **The anchor rule was wrong in a way only sub-sections could reveal.** It
  dropped every character but letters, digits, spaces and hyphens, so
  `### tom_job_run` yielded `tom-job-run` — while GitHub keeps the underscore and
  `scheduling.md` already links to `#tom_job_run`. The first mechanical pass
  rewrote those three live links to the broken form and was reverted; applied to
  sub-sections unchanged, the check would have reported three working links as
  dangling and invited someone to repair them into links that go nowhere.
  Underscores now survive, and the rule is pinned on those fragments.

  Repeated headings are disambiguated as GitHub does it — `authentication.md`
  heads two sections `Failure keys`, and the second is reachable only as
  `#failure-keys-1`. The ordinal is counted over *every* heading in the file,
  `#` to `######`, because that is the sequence GitHub counts through: reading
  only the levels the check cares about would shift every suffix after a skipped
  heading.

  `tool/check_doc_tocs.py`, which polices the same rule across 117 documents in
  the corpus, had the same gap and reported that guide as carrying two faults it
  does not have: the correct `#failure-keys-1` entry as stale, and the section it
  points at as out of document order. It now disambiguates too, through one
  `anchors_of` walk over the whole document.

- **Nine module readmes did not reach every file their module exports; four had
  no readme at all (tcincb131).** A `Key types` table may select — a per-name
  rule would force an 83-row table on `object_persistence` and make the worst
  readme worse — but a file mentioned nowhere is not a selection. It is a
  capability the reader has no way to learn exists, so they conclude the module
  is what the readme shows.

  `audit`, `export`, `file_storage` and `resources` now have one. That was the
  larger half and the worse failure: an incomplete table under-describes a
  module, while a missing readme is invisible to every check that reads a table,
  there being no table to read. `authentication`, `datasources`, `endpoints`,
  `object_persistence` and `scheduling` gained rows for the files they had never
  reached — and the omissions are not scattered, which is what the rule
  predicts. They cluster on whichever half of a module arrived after its readme
  was written: all four of `endpoints`' transports, `object_persistence`'s
  column authorization, file references and the whole of grouping,
  `datasources`' framework tables, failure classification and placeholder scan.

  Writing them made three other suites speak up, each having held a stale list:
  the readme-pointer suite's map of modules without one, and the quick-start
  suite's classification table — which then compiled all four new snippets and
  ran them, catching four API errors in prose I had written from memory
  (`TomTabularColumn`'s positional name, `put`'s named arguments,
  `TomStoredBlob.byteCount`, and a `const` on a non-const constructor). A quick
  start nothing compiles is a suggestion.

  `_moduleReadmesPendingReconciliation` and `_modulesWithoutReadme` are gone
  with their `skip:` and their staleness meta-test.


- **The API-coverage census lost every declaration after a `/*` written inside a
  dartdoc (tcincb130).** It built its idea of "not code" by deleting
  `/\*[\s\S]*?\*/`, so a line reading ``/// … `--`, `#` or `/*`.`` opened a
  block comment that ran forward to the next `*/` anywhere in the file and took
  every declaration between with it.

  Both directions of the damage were silent in different ways. A swallowed
  member is absent from the census, so the ownership check reports its perfectly
  correct summary row as documenting something the package does not declare — a
  loud failure with a false cause. And the reverse checks read the same census,
  so the member also stops being *required* to be documented: a documentation
  hole that reports nothing. The module where `/*` is likeliest to appear in
  prose is the one whose subject is SQL comments.

  `_withoutBlockComments` replaces the expression with a scanner that opens a
  comment only where Dart would: not inside a `//` or `///` line, and not inside
  a string literal — `sql_lexer` holds the literal `'*/'`, so markers reach this
  package's code as data. A `*/` *inside* a comment still closes it, quotes and
  all, because a block comment contains no string literals; that asymmetry is
  the language's, verified against the analyzer, and matching it is the point.
  Newlines inside a removed comment are preserved, so a position read off the
  blanked text still names its line.

  The same expression had a **second copy** in `_classBody`, which feeds the
  Properties census — so the fix would have landed once and stayed broken twice.
  Both now call the one helper. `TomSqlLexer.commentOpensAt`'s dartdoc, which
  had been rephrased to keep the marker balanced, is written the natural way
  again, and a test pins that it can be.

  `tom_core_flutter`'s `sourceWithoutComments` had the same defect, with two
  live `` `/preferences/*` `` dartdocs in reach of it. Its line filter now runs
  before its block-comment removal, which needs no scanner and closes both.


- **Nothing could read a `DATE` or a `TIME` column, and what was written into
  one was the wrong day (tcincb127).** Three defects, each hidden by the next.

  An entity declaring a `TomZonedDate` or `TomZonedTime` field could be written
  and never read: `_processResult`'s switch on the declared member type has
  cases for `int`, `double`, `String`, `bool` and `DateTime`, and both temporal
  types are `DateTime` *subclasses*, so neither matched the `DateTime` arm and
  both fell to `error.result_processing.unknown_type`. Both now have their own
  case.

  `TomDbDate.of` and `TomDbTime.of` parsed with `TomZonedDate.parseFromString` /
  `TomZonedTime.parseFromString`, which read Tom's `@D@…` / `@T@…` serialization
  and nothing else — a form no `DATE` or `TIME` column contains, because
  `dateOp` and `timeOp` write `'2026-07-15'` and `'14:30:05'`. They now read
  through **`parseSqlDate`** and **`parseSqlTimeOfDay`**, new and exported: the
  reading halves of `sqlDate` and `sqlTimeOfDay`, living beside them because a
  writer and a reader are only correct as a pair. Both still accept the `@D@…` /
  `@T@…` form, for a value that reached a text column through `toString()`.

  And `sqlDate` / `sqlTimeOfDay` did not render the components they promise.
  Their contract is "as labelled" — the 5th is written as the 5th — but a
  `TomTimezoned` stores UTC and answers `year`/`hour` in UTC, so a
  `TomZonedDate` naming the 5th in `Pacific/Kiritimati` was written as the
  **4th**, and a `TomZonedTime` naming 14:30 in `Asia/Tokyo` as **05:30**. Both
  now read the value in its own frame, which is the rule the kernel already
  applies when it classifies one of these values by its components.

  What a `DATE` or `TIME` column still cannot carry is the zone, so a value read
  back from one is anchored in UTC: the reading survives the round trip and the
  anchoring does not. That is now stated in the guide's limitations section,
  along with the refusal of a `TIME` past 23 hours — MariaDB's `TIME` spans 838
  hours because it doubles as a duration type, and wrapping a duration into the
  next day would turn a modelling mistake into a plausible wrong answer.

  **Only a live server could have shown any of this.** Each direction had its
  own tests and all of them passed: the renderers were asserted against each
  other, the readers against strings a test wrote by hand. Nothing completed the
  circle, and the circle is where they disagreed — including one fact no
  hand-built string would have produced, that the driver materialises a `DATE`
  into `2026-07-15 00:00:00.0`. `test/temporal_columns_db_test.dart` writes a
  row and reads that row back.


- **Seven module guides had nowhere to record an edge, so they recorded none
  (tcincb126).** A guide with no `## Not Yet Implemented` section has nowhere
  legal to say what the module has not done — the placement rule requires the
  claim to live there — so the pressure is to leave the edge out rather than
  write it down, and silence reads as "no edges". `authorization`,
  `healthcheck`, `little_things`, `preferences`, `resources`, `scheduling` and
  `transactions` now each carry one, established from source.

  None of the seven modules lacked edges, which is the point. The transaction
  coordinator catches a `startTransaction` that throws and **does not** catch a
  throwing `commit()` or `rollback()`, so an exception there leaves the
  participants behind it neither concluded nor ended; `isReadOnly` is recorded
  and read by nothing. The health endpoint answers HTTP 200 for every verdict
  and awaits its analyzer with no deadline, so a hanging database probe reads to
  an orchestrator as a dead process. The preference upsert reads and then
  writes, and a client may rewrite a key with a different type, after which
  every other device's typed read throws. The scheduler claims `ORDER BY seq`
  with no priority, cannot pause a job, and renders MariaDB SQL directly rather
  than through a dialect. The authorization cache has no invalidation at all, so
  a revoked grant binds only when the token expires — and its eviction sweep is
  opt-in, so a token never read again occupies the map for the life of the
  process. Each was legible in the source to anyone who looked; what was missing
  was the place to write it down.

  Writing them found one violation of a sibling rule: the scheduling section
  named `TomSqlDialect`, a type removed with its annotation, which the
  datasources suite's precedent guard rejects wherever it appears under `lib/`
  or `doc/`. The type is `TomStandardSqlDialect`.

  `_limitationsPendingSection` is gone with its `skip:` and its staleness
  meta-test.


- **Ten module guides named neither the suite nor the example that verifies
  them; all twenty now do (tcincb125).** A guide is where a reader goes to find
  out what backs the claims in it, and an example nobody points at is an example
  nobody runs — which is how `example/datasources/datasources_example.dart` came
  to spend a year with nine expectations written as `assert`, inert under the
  `dart run` its own header documents, printing a plausible transcript and
  exiting 0 with every one of them violated.

  `audit`, `authentication`, `authorization`, `endpoints`, `file_storage`,
  `healthcheck`, `little_things`, `object_persistence`, `server` and
  `transactions` each gained a `## Verification` section on the shape
  `doc/datasources.md` and `doc/scheduling.md` established: what each suite
  settles, which suites are `db`-tagged and skip without a server, and the
  command that runs the example. The suites named after a type rather than the
  module — `two_factor_*`, `oauth_*`, `crud_repository_*`, `data_scope_*` and
  the rest — are named too, beside the section that describes what they cover.

  **Writing the sections found seven suite names that do not exist**, invented
  by pattern from a module's other filenames (`oauth_flow_test.dart` for what is
  really `oauth_test.dart`, and six more). The neighbouring "every suite and
  script a guide names exists" check caught all seven, which is the reason
  attribution is worth demanding rather than encouraging: an attribution nothing
  verifies is a sentence, not a pointer.

  The examples themselves needed no repair — every one already states its
  expectations through the package's throwing `check` helper, and
  `test/examples_test.dart` already spawns each one not spawned by a module
  suite.

  `_verificationPendingAttribution` is gone with its `skip:` and its staleness
  meta-test. Two neighbouring meta-tests were pinned to the modules that
  happened to be failing — `transactions` for a missing suite, `audit` for a
  missing example, `authorization` for naming somebody else's — so paying the
  debt off broke them. `_unnamedVerificationIn(module, text)` now takes the
  guide text, and both are pinned against fixtures: a guard that has to be
  rewritten every time the package improves is one that gets weakened rather
  than understood.


- **Two authentication entities were documented by their column names, which no
  caller can write (tcincb123).** `TomUserTwoFactorEnrolment` and
  `TomOAuthStateRow` each had a section that read as a complete account of the
  row — it listed every column — while naming none of the identifiers a reader
  came for. `principal_id` is what the table holds; `principalId` is what a
  caller writes, and only the second is a member. Twelve of the thirteen missing
  members were that: `enrolledAt`, `enrolmentId`, `isPrimary`, `principalId`,
  and `clientCountry`, `clientLanguage`, `clientTimezone`, `createdAt`,
  `expiresAt`, `pkceChallenge`, `pkceVerifier`, `providerId`. The three that
  happened to be spelled the same in both worlds — `id`, `mechanism`, `hint` —
  are why the omission was invisible to a reader skimming the section.

  Both classes now carry a Properties table giving the Dart name, the type, the
  column it maps to, and what it is for, taken from the declaration rather than
  inferred from the name: `enrolledAt` is documented as UTC and as `DATETIME(6)`
  (the width the instant convention writes), and `TomOAuthStateRow`'s two
  instants are documented as `String` with the reason — the driver decodes
  `DATETIME` as local time, and `parseSqlInstant` is what turns them back.

  The thirteenth was `TomMemoryOAuthTokenStore.clear`, the affordance a suite
  calls between cases. Its sibling `TomMemory2FAEnrolmentStore.clear` was
  documented; this one was not.

  `_memberListsPendingReconciliation` is gone with its `skip:` and its staleness
  meta-test — the last quarantine on this check.


- **The API index omitted 19 exported names, and three whole feature areas of
  `object_persistence` with them (tcincb122).** `api_summary_index.md` is the
  only place in the package where a reader can conclude that a name does not
  exist without opening a file, which is exactly why that conclusion must not be
  drawable wrongly. It named neither `Tom2FAPrerequisite` nor `verifyBearerToken`
  from `authentication`, and from `object_persistence` none of `TomAggregate`,
  the six aggregate nodes (`Avg`, `Count`, `CountAll`, `Max`, `Min`, `Sum`),
  `TomGroupedSelect`, `TomGroupedRow`, `TomPageRequest`, `TomSortField`,
  `TomSortDirection`, `TomResourceScopeSource`, `TomFileReference`,
  `TomFileReferenceKeys`, `TomFileRepository` or `TomRepositoryException`.

  Counted as names that is nineteen; read as capability it is three feature
  areas — grouped queries and their aggregates, paging and sorting, and
  file-reference columns — of which the module's index table said nothing
  whatever. The table looked complete because it listed twenty-odd other types.
  The Quick Navigation blurb for the module said nothing about them either, and
  now does.

  A further thirteen `object_persistence` types were named only inside a
  *description* cell — `TomOperator`'s expression-tree row listed
  `TomUnaryOperator`, `TomBinaryOperator` and `Parameter` in its prose — which
  reads to a person and is invisible to the column an index is looked up by.
  They are in the Type column now.

  34 rows were added to the Alphabetical Type Index, which is 493 rows and
  case-insensitively sorted. **Nothing checked that it was sorted**: every check
  around it asks whether a row exists, and a row in the wrong place exists, so
  the reader is the one who finds out — by looking where the name should be and
  concluding it is not there. A test now reads the table in document order and
  names the first five rows out of place.

  `_indexPendingReconciliation` is gone with both its `skip:`s and its staleness
  meta-test.


- **The Source-list check reported four documented files as undocumented, and a
  quarantine held that reading open (tcincb121).** `api_reference_coverage_test`
  compares each `api_summary_<module>.md` opening `Source:` list against the
  files the barrel exports for that module. `authorization` named all five of
  its files; it wrote four of them in the abbreviated form the list allows — one
  full path, then bare file names carrying the module over — and the parser read
  only full paths. So the check reported four *missing* files, the module was
  quarantined as documentation debt, and the debt did not exist: every one of
  those files has an Overview paragraph, sections for each of its types, and
  table-of-contents entries.

  A parser that cannot see an entry reports its absence as an omission, which is
  the failure this file's own header warns about in another form. The parser now
  resolves a bare name against the module of the preceding full path — what the
  line says to a reader, and the only thing it could say — and the abbreviation
  is checked separately, as a matter of form: nineteen of the twenty summaries
  write every entry in full, a bare name is not a path anyone can follow, and
  the authorization summary now writes its five in full too. The two rules then
  name two different defects instead of one cause raising two alarms, which the
  mutations confirm: abbreviating the list fails only the form test, dropping a
  file from it fails only the completeness test.

  `_sourceListsPendingReconciliation` is gone with its `skip:` and its staleness
  meta-test, rather than left empty — an empty quarantine keeps a skip that can
  never fire and a meta-test that can never fail, and the next reader has no way
  to tell that from a live rule.

### Changed

- **A datasource settings key that binds nothing now fails the start-up, naming
  the key and the data source (tcincb119).** `TomDataSourceInfo.initialize`
  handed the whole configuration block to the driver, which bound it with the
  shared, deliberately tolerant `tomReflectionInfo`. A key naming no field was
  dropped without a throw and without a log the caller sees — and what the
  operator eventually got was a connection error that named neither the schema
  nor the credentials the driver was never given, and never mentioned the key
  that caused it, because nothing ever looked at it.

  ```
  Datasource 'app_db' (type 'mariadb') is configured with a setting 'database'
  that names no field of MariaDbDatasource. Check the spelling in the datasource
  configuration for 'app_db'.
  ```

  Tolerance is right on the wire, where the sender may be newer than the
  receiver; a datasource block is a file the operator wrote against a driver
  whose field set is fixed and shipped. Every offending key is listed, so a
  block with two typos in it takes one restart to correct.

  **The check is the registry's, not each driver's**, for two reasons. The name
  of the data source lives at the registry — it is the half of the message that
  says which block to open, and a driver never learns it. And a check here
  covers every driver including one the framework never saw: the field set is
  read off *that* driver through reflection, so a deployment's own driver is
  checked against its own settings rather than confined to MariaDB's vocabulary.
  The suite asserts that asymmetry in both directions with a fixture driver
  declaring a field MariaDB does not.

  `type` and `delegateTo` are the registry's own keys and are **stripped** from
  the block before the driver sees it, rather than excused by an allowlist
  inside the check — so the boundary says the same thing twice over: a driver is
  handed only what is addressed to it, and every key it is handed has to bind.
  They are published as `TomDataSourceInfo.registryKeys`.

  No shipped configuration changes: every datasource block in the samples and in
  `tom_uam` already binds. The behaviour that changes is what a *misspelled* one
  does.

### Removed

- **`TomRepositoryType` is gone, and no shipped source or guide describes a
  repository lookup by data-source type any more (tcincb118).** The annotation
  bound a `TomSqlDatasourceRepository` subclass to a data-source type name
  (`@TomRepositoryType("mariadb")` on `MariadbRepository`) for a reflection scan
  that was never written. Nothing read it. `MariadbRepository` is reached
  because callers construct that exact class, as every guide and every sample
  already shows them doing.

  A lookup keyed on a data-source type name could not work here even in
  principle: a repository is generic in its entity and key, and those type
  arguments are what make it the repository *for an entity*. A string cannot
  supply them, so a registry could only ever hand back a raw type the caller has
  to re-specialise — which is the construction it was meant to replace.

  Three documents nevertheless described the scan as the mechanism
  (`doc/object_persistence.md`, `doc/api_reference/api_summary_object_persistence.md`,
  `doc/api_reference/api_summary_index.md`); all three now describe direct
  construction. A guard in `object_persistence_test.dart` — modelled on the one
  the sibling `@TomSqlDialect` removal left behind — fails if the name reappears
  anywhere under `lib/` or `doc/`, so re-introducing the lookup has to be argued
  there. Alongside it, the first test that constructs a `MariadbRepository` at
  all, asserting the one thing the subclass adds: it renders through
  `MariadbSqlDialect`.

### Added

- **`@TomReference` association loading has a DB-backed test, and the framework
  has its first reflected fixture that declares one (tcincb117).** The
  annotation's *sentence* was covered by `reference_query_test.dart`; what the
  driver does with the rows — compile, run, write them back through the field's
  mirror — was reachable only behind a live connection and asserted nowhere. The
  only entities in the workspace declaring `@TomReference` live in
  `tom_uam_server`, whose suite never reads one back either.

  Three fixture entities (`FixtureTagged`/`FixtureTag`/`FixtureTagLink`), their
  three tables, and `reference_association_db_test.dart`, which asserts that the
  rows land in the entity's list, that an owner with no links comes back empty,
  that a row is not given the same association twice, and that a `null`
  reference field is refused naming the field rather than leaving the
  association silently empty.

  **The per-row property turned out not to be observable in the rows**, which is
  the finding worth recording. The report expected a multi-row read to show it:
  with the pending-reference stack declared outside the row loop, row *k*
  re-resolves every earlier row's association. Reverting the repair and running
  the new tests, the rows came back *correct* — each fill clears the list before
  adding, so resolving an owner twice recomputes the same list. What the defect
  costs is work, quadratically: an *n*-row read issues *n(n+1)/2* reference
  queries instead of *n*. So the assertion counts statements, off the driver's
  own `Executing SQL` trace, and the reverted repair fails it with 11 where 5 is
  right.

  `doc/object_persistence.md` states both contracts — the refusal and the
  one-query-per-row rule — and says why the cost is the only observable.

### Fixed

- **The date and time bind arms were right and unchecked — deleting either left
  the suite green (tcincb115).** `TomZonedDate` and `TomZonedTime` are
  `DateTime` subtypes, so without their own arms `_toBindValue`'s general arm
  claims them and binds a whole instant into a column that holds half of one: a
  `DATE` gaining a time nobody named, and — for a `TIME` — a datetime-shaped
  string the server refuses outright. Both arms exist and are correct. Neither
  was pinned, which was measured rather than assumed: removing the date arm and
  running `datasources_test.dart` and `object_persistence_test.dart` reported no
  failure.

  The calendar-date rule this todo was filed to settle is already the one both
  paths follow — `dateOp` and the bind boundary reach the same `sqlDate`, and
  `sql_instant.dart` states why a date is taken as labelled where an instant is
  normalised. What was missing is the assertion that they *agree*, so the tests
  compare the bound value with the inlined literal rather than each against a
  string of its own: a change to the date spelling now moves both or fails.

  The value they compare is anchored fourteen hours east, because on a
  UTC-anchored date every rule agrees by accident — which is exactly what hides
  a zone defect.

  The third caller the report flagged, `dateOp(DateTime.parse(token))` in the
  query-sentence compiler, turns out to be settled by the grammar rather than by
  the renderer: the date pattern is `YYYY-MM-DD` and admits no zone, so the
  `Z`-suffixed token that would make `DateTime.parse` answer UTC is refused as a
  date and claimed by the datetime rule instead. Pinned against the parse as
  well as the output, so the claim rests on something visible.

  Four entries added to the mutation catalogue — the two arms, the unwrapping
  that precedes them, and `sqlDate` converting to UTC — all killed.

### Added

- **`TomDatabaseBlobStore` takes a `clock`, so its write time is checkable
  without a database (tcincb114).** The store's `storedAt` defect — a local
  reading formatted by the store itself and read back as though it were UTC,
  wrong by the writing node's offset and by a *different* amount per node — was
  repaired earlier, but its only assertion lives in the `db`-tagged suite, which
  is skipped on every machine without a MariaDB. A rule nothing checks on an
  ordinary run is a rule that returns.

  The seam is the house pattern: `TomSqlLeaseLock` and `TomSqlOAuthStateStore`
  each take one, and `named` forwards it. `file_storage_test.dart` now injects a
  fixed *local* instant against a recording data source and asserts what the
  store hands the bind boundary — a `DateTime`, not text — because that is the
  shape of the defect rather than its wording. A store that formats its own
  instant is wrong whatever the text says, so the bound value's **type** is what
  fails when it comes back; the descriptor is checked to name the same moment,
  labelled UTC.

  A second test pins the seam itself, since a store that ignored it would pass
  the first on any host whose wall clock is close enough. Three entries added to
  the mutation catalogue — formatting the instant in the store, dropping the
  descriptor's `toUtc()`, and reading `DateTime.now()` past the seam — all
  killed.

  No migration. Rows already written carry the old skew, and the column is
  human-facing metadata that nothing orders by; the only databases holding any
  are the samples' and `tom_uam`'s, which are recreated from the DDL rather than
  migrated.

### Fixed

- **`registerParticipant` enlisted a participant whose `startTransaction`
  failed (tcincb113).** It recorded the participant in the map and *then*
  called `startTransaction()`, discarding the `bool` that came back. Both
  halves were wrong the same way: enlistment was recorded before the start was
  known to have succeeded.

  A participant that returned `false` was enlisted anyway, so
  `commitTransaction` later committed a resource that had never opened a
  transaction — for `MariaDbXADatasource`, `XA COMMIT null;` against the branch
  its failed start had just cleared, which MariaDB rejects. The failure
  therefore surfaced as a *commit-time* error naming the wrong operation, at the
  moment the coordinator is deciding whether to roll everyone back. A
  participant that *threw* was worse: the map insert had already happened, so
  the exception left the transaction holding it.

  Enlistment is now all or nothing. The participant is recorded only after a
  `true`; a `false` or a throw leaves it unenlisted and raises
  `TomTransactionException` naming it —
  `transaction_manager.register_participant.start_failed` and `…start_threw`,
  the latter carrying the participant's own failure as `rootException`.

  The two are reported alike deliberately. They are one event to the
  coordinator, and the data sources that can fail here return `false` rather
  than throwing — so the class's previous claim that *"a failure thrown by
  `startTransaction()` surfaces through the returned future"* documented the
  path that does not occur. A failed enlistment does not conclude the
  transaction: the participants that did enlist are unaffected, and because the
  failed id was never recorded, a later attempt with a participant that can
  start is a first enlistment rather than a deduplicated no-op.

  `doc/transactions.md` gains the *Failure keys* section it had never had —
  documenting `transaction_not_running` alongside the two new keys — which
  lowers `check_doc_error_keys` from 328 to 327.

### Documentation

- **The two inert `object_persistence` annotations point at the section that
  lists them, and a guard keeps such pointers honest (tcincb112).**
  `@TomJoinTable` and `@TomPersistenceEventHandler` each state their own
  limitation in full, which is right, but neither said the package documents it
  — with the third, the missing query-sentence keywords — in one place. Both
  now name `doc/object_persistence.md`'s *Not Yet Implemented* section, which
  is where a reader meets the three together rather than one annotation at a
  time.

  A path inside a comment is compiled by nothing, and a document is renamed by
  someone reading the document rather than the source that names it — so a
  pointer added to fix a dangling pointer is worth guarding.
  `api_reference_coverage_test.dart` now checks that every `` `doc/…md` ``
  named in a `lib/` source is a file that exists. Six distinct documents are
  named across the package and all six are present, so this is a recurrence
  guard rather than a backlog.

  It is the counterpart of the group it joins: *shipped text stands on its own*
  catches a comment pointing at something **outside** the package, and this
  catches one pointing at something **inside** it that is not there.

### Added

- **`tool/mutation_sweep.py`, and the catalogue that records what has been
  asked (tcincb111).** A green test that *names* a behaviour is not the same as
  one that pins it, and reading the test cannot tell them apart — the assertion
  may be about something the mutation does not touch, or about a value the code
  would produce either way. The only way to know is to break the behaviour in
  `lib/` and watch.

  The committed half is `tool/mutations.yaml`, not the script: it names one
  behaviour per entry, the smallest edit that removes it, and the tests expected
  to notice, so **a module absent from it has not been swept**. Sixteen of the
  twenty are in it — 71 entries, four of them `requires: db`. Seventeen
  survived; thirteen are now pinned by new tests, and the four in `endpoints`
  are recorded in the follow-up, needing a pipeline fixture that declares a
  `urlParameterMapping` and `formFields`.

  What the survivors were. `healthcheck`'s four route facts — its path, its
  public access, its plain-text media type, its `logRequests: false` — were
  asserted only through *generated reflection*, so changing the annotation in
  `lib/` left every route test green until somebody regenerated; they are now
  read from the declaration. A concluded transaction could wipe a *successor*
  from its scope, which the guard's own dartdoc argues against and nothing
  tested. An expired cache entry was reported as a miss without being dropped,
  which for a cache with no sweep timer means it is held for the life of the
  process. A commented-out `.env` assignment (`# DB_HOST=parked`) was covered
  only by a bare `# a comment`, which the no-separator rule drops anyway. A
  stored language of blanks beat a real device locale. `TomAuditActor.fromJson`
  read a missing username as nobody and a missing flag as authenticated —
  neither reachable by a round trip, because `toJson` always writes both.
  `registryStrength`'s tie-break, which decides the role name a fold reports.
  The datasource and schema case-insensitivity in schema convergence, where
  every fixture had been spelled the same way on both sides. A blob-store entry
  with no type rendering as the word `null`, and an entry with its own builder
  deferring to a backend. And the access line's app-id prefix, whose *absent*
  half would have printed `[] ` for every deployment that never named itself.

  Two things the harness had to learn, both from getting them wrong. It runs
  the suite once unmutated first, because a red suite calls every mutation
  killed — a test file that stopped compiling is red in exactly the way that
  looks like success, and reported six of six killed on a suite that never ran.
  And an entry whose only coverage is a `db`-tagged suite carries `requires:
  db`: those suites self-skip without a MariaDB and a skipped suite passes, so
  without the marker they report as surviving on every machine with no
  database. An equivalent mutant — rewriting an expression as a synonym — is
  removed rather than recorded, its survival saying nothing about coverage.

### Fixed

- **A server's remote log records now say which server they came from
  (tcincb110).** `TomRemoteLogMessage`'s sender defaulted to the kernel's
  placeholder and no application ever set it, so a collector aggregating
  several servers filed them all into one stream set distinguished only by
  isolate name. `TomBaseServerConfiguration`'s constructor now installs
  `TomRemoteLogMessage.globalSettingSenderIdResolver = () => tomAppId`,
  alongside the line that registers the instance as the isolate's active
  configuration — the one place that already says "this isolate's application
  is me".

  A *resolver* rather than a copy of `tomAppId`, for the reason `tomAppId` is
  itself a getter: a configuration is named in its **subclass** constructor
  body, which runs after the base constructor doing the installing, so a copy
  taken there is the empty string. Every server in this workspace once made
  that mistake with `tomAppId` itself. Pinned by a test that names the
  application only in the subclass body and asserts the record still reports
  it — and verified by planting the copy, which reds exactly that test.

### Documentation

- **Every field of `TomBaseServerConfiguration` now carries a dartdoc, and a
  test keeps it that way (tcincb108).** This is the single object a deployment
  fills in to stand a server up, so each field is a knob somebody has to set
  correctly without being able to read the code that consumes it. Seventeen of
  its forty-eight carried no comment at all.

  The filing expected a mirroring job — the API summary already had a line for
  every field — and that turned out to be the wrong premise for most of them.
  The existing lines restated the name, and three restated it *wrongly*:
  `logLevelExceptions` was described as "log level for exceptions" when it is a
  per-logger override list whose "exception" is to the global `logLevel`;
  `postExecutionHandler` as "runs after execution" when it is a `Cascade`
  fallback reached only if the router answers 404, and which never sees the
  router's response; `listenToAnyIP` as "binds to any IP" when it is read
  *after* `host` and so discards a configured address rather than adding one.
  Each field was read at its consumer, and the API summary and the completion
  document were corrected alongside the source.

  Four of the fields turned out to be settings the framework never reads —
  `logLevel`, `logLevelExceptions`, `isolateLogging` and
  `databaseMigrationsDirectory` are applied by the application's boot. That is
  worth a deployment knowing, because it decides *when* a value takes effect:
  everything logged before the boot reaches `setLogLevelByName` is emitted at
  the previous level.

  `privateKey` says it is a credential without using the words **secret-bearing**
  — that phrase is a controlled marker tying a field to a row in the guide's
  *Deployment Settings* tables, which cover the four out-of-band blocks and not
  TLS material. The dartdoc says so, so the next reader does not conclude the
  marker was forgotten.

  The guard is all-or-nothing rather than a count: a field is the smallest thing
  a document can omit and the easiest, since adding one is a single line and
  nothing about writing it prompts for a comment. It reads the same class body
  the secret-marker check does, and is pinned on the two TLS fields, whose
  multi-line string default is the declaration shape a field reader is most
  likely to skip — skipping them would report the class fully documented while
  leaving the credential pair uncommented.

### Added

- **`TomYaml.loadYamlFileIfPresent` and `TomYaml.mergeInYamlFileIfPresent`, the
  tolerant half of the loader pair (tcincb106).** Both strict entry points
  throw `PathNotFoundException` for an absent file, while the layered-overlay
  pattern the module documents is exactly the case where absence is normal — a
  per-environment or per-locale file of which only one candidate is ever
  present. The sibling loader in the same pipeline is tolerant
  (`TomEnvFile.read` returns `{}` for an absent `.env`), which is where the
  reasonable and wrong expectation comes from.

  The cost was already being paid twice, in two incompatible ways. Four sample
  servers each carried a private `if (!File(path).existsSync()) return;`, and
  `tom_uam` took the other route: nineteen bare `catch (exception)` blocks that
  logged "not found", plus three more in a commented-out block. A bare catch
  cannot tell an absent file from a malformed one, so a YAML syntax error in a
  locale overlay was reported as that locale simply having no overrides, and the
  settings in it silently stopped applying.

  The new pair forgives `PathNotFoundException` and nothing else, so a file that
  is there and does not parse still throws. Each reports whether the file was
  there — `null` versus a map, `false` versus `true` — because an overlay that
  never applied is precisely what an operator hunting an ineffective setting
  needs to be told, and none of the previous call sites could say it. Caught
  rather than pre-empted with `existsSync`, which asks the question a moment
  before the answer is used.

  Every consumer moved onto it. The samples' `mergeOptionalYaml` is now one line
  over `mergeInYamlFileIfPresent` and returns its answer, which their
  `boot_assets_test.dart` asserts in both directions; `tom_uam`'s nineteen
  catches became `if (!TomYaml.mergeInYamlFileIfPresent(...))`, and the two that
  logged on success as well became `if (...) { … } else { … }`. The
  commented-out block went with them — dead code carrying three more copies of
  the shape this change exists to remove — leaving the question it recorded as
  prose. The
  configuration guide's *"`TomYaml` has no optional load"* limitation is
  retired, and step 8 of the configuration example now runs the tolerant merge
  beside the strict one.

### Fixed

- **All 219 `#### Properties` tables in `doc/api_reference/` are censused
  against the classes they document; one was censused before (tcincb105).** A
  table headed `Property` claims to be the class's property surface, and a
  reader who finds eight of ten has no signal that two are missing. Only
  `TomBaseServerConfiguration` was held to that claim, because it was the one
  class cheap to check: all plain fields, one class in its file, so the census
  could assume both.

  Generalising meant removing both assumptions and settling what a property is.
  A type now carries the file that declares it, so a section names its class
  and the census finds the source; a class body stops at the `}` that closes it
  rather than running to the end of the file, which is what a file declaring
  eighty classes requires; and a property is a public *instance* field or
  getter, which is what the tables list — a getter row is marked `*(getter)*`
  and sits among the fields, while statics have a table of their own.

  Eleven tables disagreed with their class. Six omitted properties: the getter
  carrying a deployment's whole request-logging decision and the key pair every
  unannotated endpoint is protected under (`TomEndpointHandler`), the encrypted
  claims an enrolment offer contributes to its token (`Tom2FAEnrolmentState`),
  the operand edge the whole operator tree is walked along
  (`TomUnaryOperator`, `TomBinaryOperator`), and the eight settings the email
  and SMS second-factor services each surface from their statics. Three were
  complete but reordered, so the table could not be read beside the class. One
  table had no heading at all — `TomAggregateFunction.sqlName`, a `Property`
  column floating under the enum's values — and one more was a defect in the
  reader rather than in a document: a row sharing its cell with a sibling
  (`` `errorCodePath` / `errorMessagePath` ``) counted as one property, so the
  siblings read as undocumented. All are repaired, and the group carries no
  quarantine: an empty one reads as debt that is not there.

  Two guards keep new tables in. The census length is held to the number of
  `Properties` headings the summaries carry, so a class renamed in the source
  and not in its section title takes its table out of the census loudly; and
  every `| Property |` column must sit under a heading the census reads or one
  of the three spellings named as deliberately unread (`Static Properties`,
  `Properties (DbCol)`, `Properties and Methods`), checked in both directions
  so a spelling that stops being used stops being exempt.

- **`TomMemoryAuditSink` accepted records after `close()`; it refuses them now
  (tcincb89).** Its `close` was `void close() {}` with no flag behind it, so
  `write` kept chaining, storing and advancing `headHash` for as long as
  anything held the sink. Measured rather than inferred: a probe closed a memory
  sink, wrote to it, and found the entry stored, while `TomFileAuditSink` and
  `TomSqlAuditSink` both refused the same probe with `audit.sink.closed`.

  What makes that a defect rather than a harmless simplification is that the
  refusal is `TomAuditSink.close`'s promise, not either persistent
  implementation's — its dartdoc argues it at length, and `doc/audit.md` states
  it as a two-row contract table covering both methods without distinguishing
  sinks. A caller holding the interface cannot ask which sink it got. And the
  disagreement ran the awkward way round: the *test* sink was the lenient one,
  so a suite exercising shutdown against it would pass while the production
  sinks refused.

  `write` now refuses with the same key, nothing is stored and the chain does
  not move; `close` is idempotent and `flushAndClose` still closes, there being
  no queue to drain. Closing ends the writing, not the reading — `entries`,
  `records`, `verify()`, `headHash` and `entryCount` keep answering — and
  `clear()` is untouched, being test support for the contents rather than part
  of the lifecycle.

  Nothing was relying on the leniency: the server suite and the
  `advanced_ops_server` suite are green without a change to either.


- **`TomAuditEntry.toString()` threw `RangeError` on a hash shorter than eight
  characters (tcincb88).** It ended in `hash.substring(0, 8)`, so the one method
  whose job is to describe an object crashed instead — and crashed in exactly
  the situation that calls it, a diagnostic trying to show a suspect entry. It
  is also what the test framework calls to build a failure message, which is
  how this was found: an assertion failed and the reporter threw
  `RangeError (end): Invalid value: Only valid value is 0: 8` instead of
  reporting.

  The unnamed constructor is `const` and public, so it cannot validate:
  `fromJson` refuses an empty hash, but `TomAuditEntry(hash: 'h', …)` is
  reachable and the anchor tests already build entries with placeholder hashes.
  Both `toString`s in the module now abbreviate rather than slice — a shorter
  hash is shown whole and an absent one reads `no hash` rather than as empty
  brackets, which look like a hash that rendered as nothing.

  `TomAuditAnchor.toString` was already guarded but spelled its guard as an
  inline conditional; it uses the same shape and the same eight-character width,
  so an anchor and the entry it anchors read alike side by side. They live in
  different libraries and cannot share the constant, so
  `audit_anchor_test.dart` asserts they agree instead.

  Every other fixed-width `substring` in the package was checked and none is
  reachable with a short input: the two in the audit module are guarded by a
  length test and by the file filter that precedes them, and outside it the
  SMTP reply parser guards on `line.length < 4`, the XLSX sheet-name cap
  truncates first, and the AWS date stamp is cut from a string the signer
  formats itself.


- **The readme quick-start guard timed compilation and called the result a
  hang; it now times the two separately
  (tcincb5_ahwq_tom_core_server_cache_readme-quick-start-test-is-flaky).**
  `readme_quick_start_test.dart` ran each snippet with `dart run snippet.dart`
  under a single 25s deadline. That deadline covered compiling the whole
  `package:tom_core_server` graph *and* executing the snippet, and the two are
  wildly asymmetric: measured here, ~2.5s to compile against ~0.35s to run. So
  seven-eighths of the budget was spent on the part the test does not ask
  about — and only that part is load-sensitive. With the machine saturated,
  compilation stretched to 14.5s while execution stayed at 0.63s, and
  `dart run` on the source took 26.7s, past the deadline, failing with a
  message that said the snippet "did not terminate" about a program that
  terminates in half a second.

  The damage was not the wasted run. It was that a false failure and the real
  regression — a snippet that genuinely never returns — produced the identical
  message, so the test taught its reader to discount exactly the signal it
  exists to raise. Raising the number would have bought a slower false failure
  and left the two causes indistinguishable.

  The snippet is now compiled to a kernel snapshot first, with its own 60s
  budget and its own message, and only the snapshot is run — under 15s, which
  is *tighter* than the deadline it replaces and still more than twenty times
  the worst execution measured. A breach of the run deadline can now only mean
  the snippet did not return, and the failure text says so. Verified both ways:
  the whole file passes with the machine oversubscribed eighteen-fold, and a
  snippet given a leaked `Timer.periodic` still fails, in 18s, naming the
  timer.

- **Two exception classes bypassed `TomServerException`, and the claim that none
  do is now enforced rather than restated
  (tcincb4_ahzb_tom_core_server_little_things-two-exception-classes-bypass-tomserverexception).**
  `TomServerException`'s dartdoc says every server exception subtypes it, "so a
  single `on TomServerException catch (e)` clause reaches all of them".
  `TomDatasourceInitException` and `TomAuthorizationCacheException` extended the
  kernel's `TomException` directly and falsified it. Both now extend
  `TomServerException`.

  What the two were missing is what that base class adds: the `isolateName` of
  the worker that raised the error, the `clientThrow` flag `tomErrorEnvelope`
  writes for a server exception and nothing else, and the zone-read request
  UUID. Both are exactly the kind of failure someone reads a log to attribute,
  and both arrived naming neither the isolate nor the request. They also escaped
  every `on TomServerException catch` — including the endpoints pipeline's
  classification, which decides what a client sees, so each reached the caller
  as an unclassified error.

  The two `clientThrow` decisions go opposite ways, deliberately. A
  datasource-init failure is infrastructure: its messages name driver classes,
  datasource types and raw driver errors, so `clientThrow` is not a constructor
  parameter at all but hard-fixed `false` — an invariant of the type rather than
  a default a raise site could forget. An authorization-cache failure is the
  opposite: all three of its conditions are about the token the caller
  presented, and two of them tell the caller what to do next (re-authorize; send
  a well-formed `validUntil`), so it defaults to `true`. Having decided that
  message may be read by the caller, the `expired_principal` raise site — which
  interpolated the whole token into its user message while its two siblings in
  the same method truncate to 100 characters — was made one worth sending.

  Nine error keys were malformed and are renamed. `TomException` fixes the shape
  as `<area>.<operation>.<condition>`; six datasource-init keys carried only two
  segments, which collided `driver_instantiation_failed` and
  `invalid_driver_not_implementing_datasource` across the reflection scan and a
  later `createDatasourceOf` — the two failures that most need telling apart.
  The three cache keys began `tomclient.`, claiming an origin in the client
  package for a class that is server-side and unreachable from a client, which
  is precisely the cross-package collision the first segment exists to prevent;
  they are now `authorization.cache.*`.

  The claim itself is now a test. `test/server_exception_family_test.dart` reads
  every class declaration under `lib/src/tomserver/`, walks each `extends`
  chain, and fails on any class reaching `TomException` without passing through
  `TomServerException` — naming the offender's file. A source scan rather than a
  runtime check, because a runtime check can only examine the types someone
  remembered to list, which is the property that failed here; the scan covers a
  new exception class the moment it is written. It is the package-wide form of
  the per-file guard in `crud_repository_exceptions_test.dart`.

- **`TRUE` and `FALSE` were the only case-sensitive tokens in a query sentence,
  so `find by done = true` did not compile
  (tcincb3_ahzb-tom_core_server-object_persistence-boolean-literals-are-the-only-case-sensitive-tokens-in-a-query-sentence).**
  The two boolean branches matched with a raw `==`, where `and`, `or`, `not`,
  `is`, `null`, `in`, `like`, `regexp`, `by`, `order`, `asc`, `desc`, the six
  comparison operators and every column name go through `toUpperCase()`. The
  inconsistency was easy to hit precisely because it was invisible: nothing in
  an otherwise entirely case-free sentence suggests one of its words has to be
  shouted, and `doc/object_persistence.md` wrote the literal uppercase in its
  one example without saying the case was load-bearing.

  It also did not fail as a *syntax* error. A lowercase `true` declined every
  literal rule and was handed on as an identifier, so the compiler answered from
  the annotation analyzer with `annotation_analyzer.determine_column
  .no_column_match, No column match field [true]` — outside the
  `TomQuerySyntaxException` family this compiler documents as covering every
  rejection, and naming a column the author never wrote. That is the same
  failure shape already removed for unterminated string literals and for a
  bracket in operand position; the boolean literal was the last token producing
  it.

  Both branches now match case-insensitively, which makes the language uniform:
  every keyword, both boolean literals and every column name are case-free, and
  only the inside of a `'…'` string literal is taken as written. The two
  branches stay separate rather than folding into one, because their rejection
  keys differ by value (`…_expected_true` / `…_expected_false`) so a caller
  reading the key can tell which literal the sentence used without re-parsing
  it; and the boolean stays out of the `_scalarLiterals` table because it is the
  one literal whose type *is* the type of a predicate, so it is the only one
  that may legally stand in negation position — the table refuses that for the
  five kinds that cannot.

  This reserves `true` and `false` in operand position: a field whose sentence
  name is one of them is now read as the literal. Reaching the clash takes
  deliberate effort, since Dart will not let a field be *declared* `true` or
  `false` and a sentence names a field by its declaration unless an explicit
  `@TomDbColumn(name: ...)` overrides it — so the only way in is to write that
  name on purpose, and the way out is to write a different one. The alternative —
  resolve the column first and fall back to the literal — would make which node
  you get depend on the entity's field list, which is far worse to debug than a
  name clash. Documented where the reservation bites, under *Writing a value
  inline*.

- **Every guide's Overview table is now checked against the module's exports,
  and eight guides that were exempt from that check have been reconciled
  (tcincb3_ahwn-tom_core_server-reconcile-remaining-overview-tables).** The
  Overview table is the first thing a guide shows, so a reader takes it for the
  module's surface and concludes an unlisted name does not exist. Eight modules
  sat in a `_tablesPendingReconciliation` quarantine that skipped the check for
  them; `authentication` was missing fifteen rows — the whole OAuth and external
  identity surface — `object_persistence` about twenty, including the entire
  public expression tree, and `endpoints` the three transports above the plain
  handler. All eight are reconciled and the quarantine is gone, so the check is
  now unconditional.

  Three further guides were not quarantined and were not checked either. The
  extractor recognised an Overview table by the literal heading `| Type |`,
  which `audit` (`| Layer | Type | Kind | Purpose |`), `server` and
  `transactions` (`| Symbol | Kind | Purpose |`) do not use, so those three fell
  out of the sweep in silence — the exact failure mode the check exists to
  break. The heading rule now keys on the `Kind` column and takes the names from
  the column to its left, falling back to a leading `Type` / `Symbol` column for
  the module readmes and the API index, which have no `Kind`. A heading cell
  that quotes an identifier disqualifies the table, which keeps the export
  guide's `` | Type | `naturalWidth` | Because | `` out — its first column holds
  `TomColumnType` *values*, and reading it as types produced five phantom
  missing exports. `server` and `transactions` passed on the widened extractor
  with no edit; `audit` needed one row.

  Replacing the quarantine's stale-entry guard is a test that every module's
  guide *has* an Overview table, because a guide without one still generates no
  test rather than a failing one.

  Guides that legitimately name a sibling module's type — `scheduling` citing
  `classifySqlFailure`, `file_storage` the whole file stack above the blob
  contract — now carry those names in a companion `| Name | Module | Purpose |`
  table that the extractor does not read. The Overview keeps its claim precise
  without the guide losing the reader's route.

- **Every module readme's quick start is now either run by the suite or
  documented as a snippet that cannot be
  (tcincb2_ahwp-module-readme-quick-starts).** Fifteen modules open with a
  "Quick start" containing a complete `main()`, and one of them — the cache —
  was guarded by a test that extracted and ran it. The other fourteen were the
  first code a reader of the module saw and nothing had ever executed them.

  Two were broken. The **endpoints** quick start threw
  `Reflection has not been initialized` at its last line: the scan reads both
  classes' annotations through their class mirrors, and the snippet never called
  `initializeReflection()`. Its own comments numbered the remaining steps `2.`
  and `3.` with no `1.`, which is where the missing line used to be. The
  **datasources** quick start connected to MariaDB and returned without closing,
  so it leaked the socket and — a live socket holding the isolate open — did not
  terminate.

  `test/readme_quick_start_test.dart` replaces the cache-only guard with a
  package-wide one. It carries the triage as a table: ten snippets are programs,
  extracted, run under a watchdog, required to exit 0 *and* to print what their
  own `// comment` annotations promise; five cannot be run, and each must carry
  a blockquote under its code saying which of the four reasons applies —
  `authorization` and `server` name identifiers the reader supplies,
  `endpoints` and `preferences` import the reader's generated
  `main.reflection.dart`, `datasources` and `preferences` open a real socket,
  and `server` is a listener that is correct never to return. The table is
  checked against the modules on disk, so a new module cannot arrive with an
  unclassified snippet, and a snippet cannot be deleted while its row stays.

  The endpoints readme also claimed its `TodoApi` / `TodoApiServer` pair was
  "verbatim identical" to the fixture `endpoints_pipeline_test.dart` mounts and
  serves — the claim that lets an unrunnable snippet still be a checked one.
  Nothing had been checking it; the same test now reads both files and requires
  the two copies to match.

- **The cache example's worked walkthrough now ships with the package
  (tcincb2_ahwp).** `example/cache/cache_example.dart` said its steps
  corresponded one for one with the snippets in the cache module's *completion
  document* — quest material, which a reader holding the package cannot reach.
  tcinc639 had already taken that pointer out of the header, leaving the
  correspondence anchored nowhere at all.

  The snippets are now a `## Walkthrough` section of `doc/cache.md`, ten
  numbered subsections matching the example's ten numbered steps, and the
  header points there. The invariant stopped being a promise: `cache_test.dart`
  reads the step numbers out of the example and the `### <n>.` headings out of
  the guide and requires the sequences to be equal and gap-free, so a step added
  on one side and not the other is a red test rather than a quietly wrong guide.

  The unguarded copy had already rotted, which is the argument for the guard. It
  was missing a section for the example's step 7 — the refusal of a `null`,
  added after the correspondence was written — so its own claim to describe
  "nine steps" was false. And its "Stopping the timers" snippet still showed
  `clearanceTimer?.isActive` answering `false` after a stop, with prose saying
  the fields "do not become `null`" — the behaviour that same document records,
  further down, as having been changed to null them. The example had been right
  throughout, because something ran it.

  The overlap the move created was reconciled: the `TomCacheEntry`-verbatim
  snippet under "Reading, Storing, Removing" became a link to step 8, which
  shows the same thing against a past instant that makes it observable, and
  "Registering a Cache" now names the steps that demonstrate each constructor
  knob rather than restating them.

- **`@TomDbColumn(columnType: ...)` is now honoured by the whole predicate, and
  refused when it names nothing storable (tcincb1_ahzf).** The annotation exists
  so an entity can say that a column is stored as something other than its Dart
  declaration implies — a flag held as `0`/`1` in an `int`, a rank carried as
  text and stored as a number. No entity in this package, its examples or the
  sample servers had ever written it, so neither of the two things it does had
  ever run, and both were wrong.

  The column node read the annotation and the bind parameter did not. A
  parameter is cast to the type the column gave the comparison, so any entity
  that actually used the hatch produced a column of one type and a parameter of
  another and died on a bare `TypeError` — outside the exception family this
  module documents, naming neither the column nor the annotation. The two now
  resolve the family **once**, through one map, and dispatch on the result as
  exhaustiveness-checked `switch` expressions: a family added to one no longer
  compiles until it is added to the other.

  An unrecognised `columnType:` fell *through* into the declared-type inference
  rather than being refused, because the explicit switch had no terminal arm. So
  an entity naming an unstorable type had its statement silently discarded and
  the column built from the declaration instead — failing open, with the first
  symptom a value written to a column of the wrong kind. It now raises
  `query_sentence_compiler.create_column.failed`, naming the type.

  `create_parameter.failed` is gone with the second switch; the parameter cannot
  fail to type a column the column node already typed.

  `FixtureColumnTypeRecord` in `test/fixtures/reflection_fixture.dart` is the
  reflected fixture that made any of this reachable — an override spelled with a
  `TomDb…` box, one spelled with a plain Dart type, an unstorable one, and a
  column with no override at all to show the fallback is still per column.

### Added

- **Every module readme now names its doc page, its example and its tests, and a
  test holds it to that (tcincb4_ahwq).** A module readme is where a reader
  arrives from the source, and its closing pointer is their only route from
  there to the prose that explains the module and the programs that demonstrate
  it. Sixteen of the twenty modules carry a readme; eleven of those sixteen
  closed at the quick start and the package backlink, and three of the five that
  did point somewhere pointed incompletely — `authorization`, the shape the
  others were written from, named one of its two examples and no test at all.
  All fifteen are now uniform, and `scheduling/readme.md` also gained the
  `---` / "Part of `tom_core_server`" footer it was missing.

  `test/module_readme_pointers_test.dart` is what stops the split reopening. Per
  readme it requires the doc page to be *linked*, something under
  `example/<module>/` to be named, at least one `test/` path to be named, and
  every backticked `doc/`, `example/` or `test/` path to resolve on disk —
  against this package or the sibling `tom_core_kernel`, which `scheduling`
  legitimately points into for the kernel's parameterised contract suite. The
  path half is the part nothing else covered: the workspace's `check_doc_links`
  gate reads the markdown link and `check_doc_source_paths` reads `**Source:**`
  pointers, and neither sees the backticked example and test paths that make up
  most of a pointer.

  Three readmes claimed their own module suite runs the quick-start snippet.
  Only `cmdline_test.dart` does; the rest run the example, and
  `readme_quick_start_test.dart` runs the snippet. Corrected in `cache`,
  `configuration` and `transactions`.

  The four modules with no readme at all — `audit`, `export`, `file_storage`,
  `resources` — are named in the same test's `_withoutReadme` map rather than
  skipped, so that set can shrink but cannot silently grow.

- **The committed reflection metadata can now be told current from stale
  (tcincb1_ahze).** `*.reflection.dart` is generated and committed, and nothing
  in Dart couples it to the sources it describes: adding a reflected class or an
  entity column and not regenerating leaves a tree that compiles and analyzes
  clean, and fails only later at a mirror lookup — with "Reflection has not been
  initialized" or a null member, from a place that names neither the class nor
  the file. Two checks now answer the question at two costs.
  `tool/check_reflection_current.sh` regenerates and compares exactly (two to
  four minutes, and it reverts its own output so a red run cannot be mistaken
  for the fix). `test/reflection_currency_test.dart` runs in milliseconds: it
  extracts every `@tomReflector` class, `exampleReflectedTypes` entry and
  `@TomDbColumn` field from the roots' hand-written sources and asserts each name
  appears in the generated file — which cannot prove currency, but does catch the
  mistake people make, since both are things a person adds by hand.

  This was filed as non-determinism — "a no-op run rewrites ~6,400 lines". It is
  not: a second consecutive run leaves `git status` clean, verified both
  warm-cache and with `--rebuild-cache`, with byte-identical outputs. The churn
  is **index renumbering**. The generator numbers every captured member in one
  dense global sequence and writes those numbers into 8,420 `const <int>[…]`
  literals per file, so adding one public member anywhere in `lib/` shifts every
  later index and rewrites tens of thousands of lines. Commit `e43ade30` added
  exactly one public static member and moved 10,885 lines. Insertions and
  deletions within ~1 % of each other is that signature. The report's most likely
  origin is regenerating on top of an already-stale file, where the first run
  legitimately changes everything and looks like churn.
  [`doc/reflection_generation.md`](doc/reflection_generation.md) records all of
  this, so the next enormous-but-correct diff is not re-diagnosed from scratch.

### Changed

- **The four `TomCache` mutators return `Future<void>` (tcincb4_ahwl).**
  `toNameCache`, `toTypeCache`, `removeFromNameCache` and `removeFromTypeCache`
  were each declared `Future<int>` and each ended with `return 0` on every path.
  Two of them spent a dartdoc sentence saying so, as did two rows of
  `doc/api_reference/api_summary_cache.md` and two passages of `doc/cache.md`;
  the other two inherited the meaningless type without documenting it, which is
  worse, since a reader had to go and find out that the value said nothing.

  A store or a removal either happens or throws, so completion and failure are
  the whole answer and the futures now carry only those. An insert is still not
  distinguished from a replacement, nor a removal of a present key from a
  removal of an absent one — that is the contract rather than a gap, so
  `doc/cache.md` states it where the mutators are described instead of listing
  it under "Not Yet Implemented", and the test that pins it moved out of "The
  limits the documentation records" into the store/read/remove group beside the
  other contract tests.

  The executor-chain caveat recorded for the same change in `authorization`
  (tcinc393) does not arise here. The cross-isolate commands
  `TomCacheStoreMessage` and `TomCacheRemoveMessage` are `TomCommand`s that
  `await` the mutator and `return true` of their own, so the `0` never reached
  the transport and what the command settles to is independent of the mutator's
  return type; `TomExecutor.noResult` appears in the module on the read path
  only. The existing round-trip tests against a real spawned `TomWorker` already
  exercise the crossing, so no new pin was added.

  The API summary rows also lost a second, unrelated drift in passing:
  `toNameCache` and `toTypeCache` were written there as taking `Object? value`,
  where the code has taken a non-nullable `Object` since a `null` stopped being
  a storable value.

- **Claiming a run is a compare-and-set, and every transition out of it is
  fenced on the claim (tcincb2_ahtl).** `tom_job_run` gains `claim_token BIGINT
  NOT NULL DEFAULT 0`, the queue's counterpart of `token` on the lease table:
  it rises on every claim of a run and never repeats, so two claims of the same
  run are orderable. Neither of the columns already there could do the job —
  `claimed_at` is the heartbeat and moves during an attempt, and `claimed_by`
  cannot separate a node's two claims of the same run. Without it the queue and
  the coordination lock could disagree about who holds a run, which is the one
  disagreement neither can resolve. See the kernel changelog for the contract
  this implements and the failure it closes.

  `_claim` now issues the ticket from a compare-and-set — `UPDATE … SET
  claim_token = :next WHERE id = :id AND state = 'pending' AND claim_token =
  :current` — so the token a `TomJobClaim` carries is provably the token in the
  row, rather than a value read a moment earlier and hoped to still hold.

  The five transitions (`release`, `markStarted`, `renewClaim`, `complete`,
  `fail`) take a `TomJobClaim` and share one guard, `_heldByClaim` + `_fence`,
  instead of five hand-written copies of the same `WHERE`: `id`, `state =
  'running'`, `claimed_by` and `claim_token` must all match the ticket. Written
  five times it was a matter of when, not whether, one would lose a conjunct —
  and a lost conjunct only ever *widens* what a statement matches, so it fails
  nothing until two nodes race. `release`, `complete` and `fail` deliberately
  leave `claim_token` where it is; it is a counter, not a lock, and resetting it
  would let a superseded ticket match again.

  `_resolveAmbiguousClaim` — the recheck after a write whose outcome is unknown
  — now requires owner, token **and** `claimed_at` to match before it concludes
  the claim landed. The token alone is not enough: two overlapping passes of the
  *same* node scan the same `pending` row and so compute the same next token,
  and only the instant separates them, since two passes of one node do not share
  a tick.

  `test/scheduling_cluster_test.dart` asserts the conditions are in the SQL and
  bound to the ticket — the thing a fake can check and a green contract run
  would not notice. The behaviour itself is asserted against a real server by
  the shared kernel contract through `scheduling_db_test.dart`.

- **A time-of-day column is now addressable in a query sentence
  (tcincb1_ahzb).** `TomZonedTime` appeared in the migration type map and
  nowhere in the query compiler, so a `TIME` column a migration could create
  could be named by no sentence at all — not compared, not bound, not tested
  for null, not aggregated. It is now a column family like the other six:
  `TimeCol` and `TimeLiteral` join `DateCol`/`DateLiteral` in the expression
  tree, `TomQueryBuilder` gains `timeOp` / `timeF` / `minTime` / `maxTime` (and
  `minDate` / `maxDate`, which were missing beside them), `TomStandardSqlDialect`
  gains `timeOp` / `timeF`, and all six of the compiler's type dispatches carry
  an arm for it.

  The literal form is `HH:MM:SS` — `find by remind_at >= 09:30:00`. All three
  fields are required and the hour is two digits, because a bound parameter is
  recognised by its leading `:` and a leading digit is what tells the two apart
  with no lookahead.

  Two symmetric holes were closed on the way, both of which would have made
  "end to end" false. `MariadbDatasource` could not read a `TIME` column back
  at all, and its bind boundary rendered *every* `DateTime` as a UTC
  `DATETIME(6)` — including both kernel half-instants, since `TomZonedDate` and
  `TomZonedTime` extend `DateTime`. A bound time therefore reached a `TIME`
  column as a datetime-shaped string the server refuses outright, and a bound
  date reached a `DATE` column as a whole instant. Both are now decided by type
  before the general arm, through the same two new renderers — `sqlDate` and
  `sqlTimeOfDay` in `sql_instant.dart` — that the dialect's literals also quote,
  so the inlined and the bound route to a column cannot spell a value
  differently. `dateOp`, which had its own copy of the padding, now delegates
  to `sqlDate`.

- **A zero-padded number no longer converts, so it no longer fills an `int`
  field.** `TomArgs.intPattern` is now `0|[1-9][0-9]*` and `doublePattern`'s
  integer part matches it, so `port=08080` reaches `setValues` as a `String`
  and is refused with `TomReflectorException` instead of silently binding
  8080 — the same outcome a negative number already had, and for the same
  reason. Write the number unpadded when the target is an `int` field. Nothing
  in the workspace passed a padded value to a numeric field.

- **A `null` is no longer a storable cache value.** `TomCache.toNameCache`,
  `TomCache.toTypeCache` and `TomCacheStoreMessage.value` now take a
  non-nullable `Object`, and `TomCacheEntry.value` is non-nullable — so both
  entrances to the cache refuse one, the analyzer at an ordinary call site and
  a `TypeError` at a dynamic or reflective call. No caller in the workspace
  stored a `null`, so nothing needed changing; a caller holding a nullable
  value now decides what absence means to it, by skipping the store or by
  storing a sentinel of its own that a read can hand back.

### Fixed

- **A digit run with leading zeros lost them on the way into a field, with
  nothing reporting it.** `007` arrived as `7`, and a phone number written with
  its international prefix, `004917612345678901`, arrived as
  `4917612345678901` — a different number in a `String` field that no cast and
  no exception objected to. The magnitude limit did not cover this: the phone
  number fits 64 bits comfortably, so it converted happily and the digits were
  simply gone. The values that carry leading zeros are the ones this module
  ingests most — phone numbers, zero-padded account and article numbers,
  postcodes, country codes — and for all of them the zeros are part of the
  identifier.
  A padded run now stays a `String`, which is the rule the magnitude limit
  already followed: a type is produced only when it can carry the value
  faithfully, and `007` -> `7` is not faithful. A lone `0` is not padding and
  still converts. The rule reaches the integer part of a decimal (`00.5` stays
  a `String`) but deliberately not the fractional part, since `1.50` and `1.5`
  are one quantity while `007` and `7` are two identifiers.

- **A cached `null` read back as three different answers, none of them the one
  the caller asked for.** It was storable, and stored like any other value.
  `fromNameCache<String>` then failed its cast and reported
  `Cached value of type Null is not of type String` — a value the cache had
  been explicitly asked to hold, blamed on the storage; `fromNameCache<String?>`
  returned `null`, which the caller cannot tell from a miss or an expiry, since
  those are exactly what `null` already means; and a *forwarded* read answered
  "miss", because a creator-side `null` crosses as the `TomExecutor.noResult`
  sentinel and is translated back. The entry meanwhile occupied a slot and
  counted against a bounded cache's `maximumEntries`, so it could evict a live
  value to hold one nothing would ever read.
  It is refused at the store instead, for the reason the constructor already
  refuses a non-positive `maximumEntries`: a write that reports success while
  every read misses is a black hole, and the store is the earliest place that
  can say so. `null` from a read now has exactly one meaning — the cache does
  not hold the key — on both the local and the forwarded path.

- **Thirteen examples verified nothing: 227 expectations written as `assert`,
  all compiled out by the `dart run` each file's own header documented.**
  `dart run` leaves assertions *disabled* — that is what its `--enable-asserts`
  flag is for — so each of those files executed every line, printed a plausible
  transcript, exited 0, and evaluated not one of its stated expectations. That
  is worse than having no checks, because it is indistinguishable from success
  to everyone including the author. That is not left as prose: `test/fixtures/`
  holds two example-shaped programs identical but for the one line that states
  their (deliberately violated) expectation, and the suite runs both under the
  documented command. The one written as a `check` exits non-zero and stops
  before its next step; the one written as an `assert` exits **0** and runs to
  the end, and only `--enable-asserts` makes it fail.
  All 227 are now `check(bool, String)` calls that throw however the file is
  invoked, and each states a *named* expectation rather than echoing its
  condition back as text — the message a reader gets when an example breaks is
  now what was supposed to be true, which is the part a stack trace cannot
  supply. Turning them on found no failures: every expectation had in fact
  held.
- **`example/_support/check.dart` replaces twenty-three private copies of the
  helper.** Each example previously declared its own, and carried its own copy
  of the paragraph explaining why it is not an `assert`. That reasoning had
  already drifted into three wordings and the throw messages into ten, which is
  the predictable failure of duplicated *reasoning*: a reader who improves one
  copy cannot know the others exist. There is now one definition and one
  explanation.

### Testing

- **The formatting guard checked three directories by name, so a Dart file
  anywhere else was unguarded and nothing said so.** `test/formatting_test.dart`
  listed `lib/`, `example/` and `test/`. That list was complete, but complete by
  coincidence: a script added under `tool/`, or a `build.dart` at the package
  root, would have drifted silently — which is the failure the suite exists to
  end, one level up. A guard against "nobody remembers to check this" should not
  itself rely on somebody remembering to widen it. The scope is now *every* Dart
  file in the package, derived by walking it, with two stated exclusions:
  dot-directories the package does not author (`.dart_tool`, `.git`), and
  generated `.reflection.dart` output. The three directories survive only as
  landmarks the walk must reach, which is what keeps a walk that finds nothing
  from passing. Verified by putting a misformatted file under `tool/`: the suite
  fails and names it, where before it saw nothing at all.

- **`test/examples_test.dart` holds for the set of examples what no module
  suite can hold about its own.** It requires that no file under `example/`
  contains `assert(`, that none re-declares a local `check`, that none makes a
  check inside a handler that would catch it, and that the shared helper
  *throws* rather than narrating — the last two being defects the first two
  cannot see, since a `check` that merely printed, or one whose `StateError` is
  taken by a bare `catch`, would satisfy both. The handler scan draws a line
  rather than banning a keyword: four of the five checks made inside a `try`
  today are legitimate (`finally` reraises, and a `StateError` is not an
  `Exception`), so a fixture shows the scan one of each shape and pins which it
  reports. Beyond the file properties, the suite settles end to end what none of
  them can: that a throw raised at a check site, in a `Future<void> main()`
  spawned the way every header documents, actually reaches the *exit code* —
  every real example passes, so only a program that fails on purpose can answer
  it.
  It also requires every example program to be accounted for: spawned by its
  module suite, spawned there, or excluded with a stated reason, checked by set
  equality against the directory. An example added later therefore fails the
  suite rather than sitting unrun, which is how the inert asserts survived —
  nothing spawned those files, so nothing could notice their checks had stopped
  running.
  This supersedes the per-file sweep in `test/api_reference_coverage_test.dart`,
  which is removed along with its thirteen-entry quarantine. That list is now
  empty of purpose, and an exemption set with nothing left to suppress turns a
  passing example back into an unchecked one.

### Documentation

- **`TomStoredUserPreferences.all()` records that its key order is the
  contract's, not its own (tcincb1_ahzg).** The `order by` was already there and
  already reasoned about, but as this store's choice — which read as something a
  second implementation was free to make differently, and
  `tom_core_flutter`'s device store did. The order is now stated once on
  `TomUserPreferencesApiService.listPreferences` in the kernel, and this dartdoc
  points at it: both faces of the preference store answer in the same sequence,
  so an application holding either one reads the same list.

- **75 `Kind` cells across 13 documents named a role instead of a declaration.**
  The column's whole purpose is to say what a reader may *do* with the symbol —
  `abstract class` invites an `extends`, `abstract interface class` forbids it,
  `final class` forbids both — so `exception`, `annotation`, `entity`,
  `row type` and bare `abstract` answer a different question, however accurately
  they describe the thing. `doc/authentication.md` alone carried 31, and there
  the substitution actively misled: `Tom2FAService` and `Tom2FAPrerequisite`
  both read `abstract`, which is not something Dart declares, so nothing in the
  cell distinguished a type you subclass from one you implement.

  Every cell now reads the declaration verbatim. The annotations that were
  parenthesised into the `Kind` cell — `@tomReflector`, `@Tom2FAAdaptor('totp')`
  and its siblings, `@TomDbTable`, `@TomApiImplementation` — moved into
  `Purpose`, as did the `statics only` and `const` notes, so no fact was lost in
  the narrowing; they are simply back in the column that carries what a symbol
  is *for*.

- **The transactions module advertised two-phase commit, which it does not
  implement (tcinc648).** "Two-phase" names a specific protocol, and its whole
  point is a prepare step: a participant may veto while nothing has been
  committed yet, so aborting costs nothing. `TomTransactionParticipant` declares
  `getParticipantId`, `startTransaction`, `endTransaction`, `commit` and
  `rollback` — no prepare, and no method that could carry one. Here `commit()`
  *is* the commit and participants are committed in registration order, so a
  veto from the third arrives after the first two have committed for real and
  the coordinator's only answer is to roll all of them back. A reader who took
  the phrase at face value would have built a participant on exactly the
  guarantee the module does not offer. Three documents asserted it flatly — the
  API summary's opening line, the module readme's first sentence, and
  `doc/transactions.md`'s "the two-phase hooks" — while the source and the API
  summary hedged it as "(two-phase style)" and the completion document's open
  list said outright that it was not true. All four texts now state the absence
  and, more usefully, its consequence, which none of them had previously drawn:
  `rollback()` is reachable *after* your own `commit()` has returned `true`, so
  a participant whose commit cannot be undone must do the work that can fail
  inside `commit()` itself. The four XA-related mentions under `datasources` are
  untouched — XA genuinely is a two-phase protocol, and whether the coordinator
  should grow a prepare phase to match remains an open decision.
- **Seven class-hierarchy diagrams sent readers to a module that does not
  document the type they were looking up (tcinc647).** A diagram shows a
  borrowed type without describing it, and the parenthetical after the name is
  the whole of its promise about where the description lives. Six diagrams
  pointed at `little_things`, where `TomServerException` is declared
  (`lib/src/tomserver/little_things/server_exception.dart`) and documented;
  five pointed at `server`, which documents it nowhere, and one at
  `tom_core_server`, which names no summary at all. A seventh sent a reader to
  `server` for `TomTransactionParticipant`, which lives in `transactions`. The
  cost is worse than an absent pointer: a reader who opens the named summary
  and does not find the type cannot tell whether they misread the diagram or
  the type is undocumented, and the true answer — documented, one module over —
  is the one their evidence rules out. All seven now name the module whose
  summary carries the entry, agreeing with the imports, the prose guides and
  `api_summary_little_things.md`'s own "root of the server's exception
  hierarchy" heading. `api_summary_datasources.md` also regained the blank line
  between two root trees that had run together.

- **`doc/server.md` listed three non-goals as pending work, and left the
  module's real limitations where no user could read them (tcinc643).** Its
  "Not Yet Implemented" section named diagnostics, monitoring and server-side
  forms — capabilities this module has no surface for and never had; the four
  files that once suggested otherwise contained a `TODO` comment each and were
  deleted. The two readings recommend opposite actions, which is what made the
  drift expensive rather than untidy: on the guide's, an application needing
  introspection endpoints waits for the framework to ship them; in fact it
  writes them today as ordinary endpoints, because that is where they belong
  and nothing is coming. They now sit under "What this module does not do at
  all", each pointing at the endpoints module, alongside WebSocket — which had
  already been argued exactly that way in the same section, and the argument
  applies unchanged to the other three.
  What the section had *not* recorded is the module's four genuine limitations,
  every one of them observable by a caller: the default `errorHandler` answers
  `500` for everything, anything answered above `loggingMiddleware` leaves no
  access-log line, `extractAuthentication` cannot report a bad token, and
  `start()` can neither be awaited nor hand back the bound `HttpServer`. A
  limitation a user cannot read is one they meet in production instead, so the
  section now carries all four with the consequence spelled out — the shape
  `doc/cache.md` and `doc/endpoints.md` already use.
- **`TomServer.securityContext` was documented as holding the TLS context and
  was never assigned (tcinc642, tcopen183).** `start()` declared a *local* of
  the same name and built the context into that, so the public field read
  `null` for the life of the server whether or not TLS was on — while its
  dartdoc said "the TLS security context, built from the configuration when SSL
  is on" and the API summary mirrored that sentence verbatim. The invited
  misuse is `if (server.securityContext != null)` as a TLS test: it compiles,
  reads naturally, and reports plaintext for a server serving over TLS.

  Fixed by deleting the shadowing local, so `start()` assigns the field — which
  makes the dartdoc true rather than weakening it to describe a dead field, and
  leaves the class with the same post-`start()` handle shape it already has for
  `router`. The dartdoc and the summary row now also say *when*: both name it a
  post-`start()` handle that reads `null` on a server which has not been
  started, and point a caller asking beforehand at `configuration.noSsl`.
  Assigning the field without saying that would have moved the trap rather than
  removed it, since `null` before `start()` is wrong in the same unsafe
  direction.
- **No shipped document mentioned the server self-login, the first thing
  `start()` does and the only thing that can stop it (tcinc641).** `start()`
  opens with `TomServerSelfLogin.loginAndInstall`, and a deployment that
  configured a service credential and cannot log in has the error rethrown with
  **no socket bound**. All three server documents described `start()` as though
  binding were all it did — the guide enumerated every configuration field
  `start()` reads without reaching the credential, the summary listed the steps
  from "initialises the router" onward, and the module readme's two-line quick
  start ended "The server is now listening". The reader who hit a refused
  credential saw an unhandled asynchronous error at boot and had nothing in the
  package to search for; the reader who trusted the summary concluded the
  deployment had no identity of its own and reimplemented the grant capping in
  application code. The guide now has a "The Deployment Logs Itself In First"
  section stating the three outcomes and why the ordering is load-bearing (the
  server principal caps every user's grants at `min(user, server)`, so binding
  first would serve requests uncapped), and the summary, the module readme and
  `start()`'s own dartdoc each say that the login precedes the bind and that a
  failed one binds nothing.

  Documenting it exposed three shipped claims that `start()` had falsified:
  `server_self_login.dart`, `doc/authentication.md` and
  `api_summary_authentication.md` each told the reader to call
  `loginAndInstall` "during application startup, before `TomServer.start()`" —
  advice that now installs the principal twice. All three say instead that
  `start()` does it, and that a direct call is for a process with no
  `TomServer`. The authentication module readme's key-types table, which the
  new links point at, gained the four rows it never had:
  `TomServerSelfLogin`, `TomServiceCredential`, `TomServiceLoginTransport` and
  `TomServerSelfLoginException`.
- **No shipped document mentioned the per-request transaction scope
  (tcinc640).** `tomDefaultAuthenticationMiddleware` wraps every request in
  `TomTransactionManager.runInTransactionScope`, so the transaction repository
  code finds as "current" belongs to the one request. A grep for "transaction"
  returned zero hits in `doc/server.md`, in
  `doc/api_reference/api_summary_server.md` and in
  `lib/src/tomserver/server/readme.md`. The omission carried a concrete hazard:
  the guide told a reader to replace the middleware without qualification, and a
  substitute that omits the wrapper produces no compile error — only
  repository code falling back to the per-isolate current transaction, which
  is the cross-request leakage the wrapper exists to remove. The guide's "Request
  Context and Zone Values" section now describes three channels of per-request
  state rather than two, its "Extending the Pipeline" entry states what a
  substitute is responsible for, the summary's middleware row and module
  overview name the scope, and the module readme says what each request gets.
- **Three shipped dartdoc comments pointed at workspace-internal material
  (tcinc639).** `example/scheduling/cluster/cluster_verify.dart` described its
  job as making "the four claims csexd15 asks for" — naming a todo instead of
  naming the claims, to a reader who has no way to look it up;
  `example/cache/cache_example.dart` said its nine steps corresponded to a
  *completion document*, which is quest material and not shipped;
  `lib/src/tomserver/datasources/mariadb_datasource.dart` closed its
  `NEWDECIMAL` explanation with "which is how the gap was first found
  (CSEXD1)". All three now state the thing itself.

  The last two are the interesting ones. The example was never checked at all
  (see below), but the `mariadb_datasource.dart` line sat on a surface the
  guard *did* sweep, and passed every run: the marker's pattern knew only the
  `tcinc`/`tcopen` prefixes, so an id from another prefix read as ordinary
  prose. A guard that names its own vocabulary is only as wide as that
  vocabulary.

- **The cluster demo readme headed a five-row table "The three programs"
  (tcinc638).** `example/scheduling/cluster/readme.md` listed
  `cluster_provision.dart`, `cluster_node.dart`, `cluster_verify.dart`,
  `cluster_support.dart` and `cluster_reflection.dart` under a heading that
  named three. The count had been true of the *invoked* programs — the three
  `run_cluster_demo.sh` starts — but the table drew no such line, so the
  heading contradicted what the reader could see.

  The heading now names five, and a `Kind` column marks each row *invoked* or
  *imported*, with a note under the table saying which the runner starts. Both
  facts are now stated where the reader is rather than left to be inferred.
  Splitting the table into two sections would have made the same distinction,
  but at the cost of pushing `cluster_reflection.dart` into a "supporting
  files" section that is easy to skim past — and that row is the one that
  records why a demo run without a regenerated reflection root throws at its
  first query.

  The defect survived because nothing read the file: `_handWrittenDocuments()`
  in `test/api_reference_coverage_test.dart` covered `README.md`, `doc/`,
  `doc/api_reference/` and the lib module readmes, but no example readme. It
  now walks `example/` too, which subjects those readmes to the whole
  "shipped text stands on its own" family of guards as well as the new
  counting check below.

- **`doc/scheduling.md` attributed the provisioned schema comparison to the one
  file that cannot make it (tcinc637).** The guide described
  `test/framework_schema_test.dart` and then added that "its `db`-tagged half"
  compares a descriptor against a live `information_schema`. That file has no
  `db`-tagged half — no `@Tags`, no skip, and its own header says so three lines
  from the top. The comparison lives in `test/framework_schema_db_test.dart`,
  which is where the tag and the skip are.

  The split is the package's convention rather than an accident: every suite
  needing a provisioned server is a `_db_test.dart` sibling of a connection-free
  one, which is exactly why `testkit :test` runs green on a machine with no
  MariaDB. So the sentence described a structure the package deliberately does
  not use, and the cost fell on the reader who wanted to *run* the provisioned
  half — they opened the named file, looked for a tag to enable, found nothing
  and concluded the check was unimplemented. Both guides that made the claim now
  name the sibling: `doc/scheduling.md` describes the two as the connection-free
  / provisioned pair, and `doc/file_storage.md` names the file it had only
  called "the `db`-tagged variant".

  `api_reference_coverage_test.dart` now requires any guide paragraph claiming a
  `db` tag to name a suite that actually carries one, so the attribution cannot
  drift back into prose nobody re-reads.

- **`doc/scheduling.md` advertised three cluster questions for a suite that
  asks six (tcinc636).** The paragraph enumerated the ambiguous commit, the
  failure formula and opt-in recovery, and stopped — omitting the broken roll
  call, the wiring guards, and the lease-acquire branches added the day before.
  The omission was not cosmetic: the broken-roll-call group is what
  substantiates the module's central safety claim, that the roll call is a
  strict accelerator over lease expiry and never the only thing standing
  between two nodes and the same run. A reader auditing "what happens when the
  accelerator breaks" was told the question was uncovered when it was the
  best-covered claim in the unit.

  The paragraph now enumerates all six as a numbered list matching the suite's
  own sections. The count is no longer a number anyone has to remember to
  update: `api_reference_coverage_test.dart` ties the guide's count word, the
  suite header's count word, the number of `GAP` sections and the number of
  list items together, so adding a section without touching the prose fails.
  A count is a fact about source, and prose is where facts go to rot — the same
  reasoning that pinned the relationship lines (tcinc634) and the lease-lock
  guards (tcinc635).

- **Two comments in `TomSqlLeaseLock` described behaviour the code does not
  perform (tcinc635).** The comment beside `acquire`'s vanished-row `return`
  said "retrying once is honest" in the same breath as ruling out looping, so a
  reader took the retry for the implemented policy and the loop for the
  discarded one — and a caller who believed `acquire` had already retried would
  not add a retry of its own. There is no second attempt. The behaviour is
  right, so the prose changed: the acquisition is reported as not taken, and
  retrying belongs to `TomScheduler`, which hands the claim back through
  `TomJobStore.release` — deliberately without charging an attempt — so the run
  is offered again on the next tick at no cost to its retry budget.

  Sweeping the rest of the module for the same defect class found a second
  instance: the library doc quoted the live-holder extension `UPDATE` as guarded
  on `... AND expires_at > :now`, a clause that statement has never carried.
  It belongs to `renew`. That one claimed a guarantee the code does not enforce,
  which is the more dangerous of the two — the guard is the token, and it is
  sufficient precisely because a lease taken over in between carries a higher
  one. Both are now pinned by tests rather than by prose:
  `scheduling_cluster_test.dart` counts the statements the vanished-row path
  issues (one insert, one read, nothing after) and asserts the expiry predicate
  is absent from the extension guard and present in `renew`'s. `doc/scheduling.md`
  gained the extension row its arbitration table was missing.

### Testing

- **Nothing held the transactions documents to the participant contract
  (tcinc648).** Four texts describe the module's commit protocol and all four
  had drifted from a contract that never had a prepare step. `transactions_test.dart`
  now reads `TomTransactionParticipant` from the source, and asks two things of
  every text: that none claims two-phase commit while the contract has no
  prepare (the claim is matched across normalised whitespace, so a line break
  between a denial and the phrase cannot hide it), and that each states the
  absence rather than merely omitting the phrase — deleting the word would have
  satisfied the first check while leaving a reader to discover the module's most
  consequential property from the source. Both tests are *conditioned* on the
  contract rather than hard-coding today's answer, so if a prepare phase is ever
  added they stop policing the denial and a third test fails instead, pointing
  at the four texts that would then need rewriting. The documents follow the
  code in either direction.
- **Nothing compared a hierarchy diagram's module pointer against the summary
  it names (tcinc647).** Twelve diagrams named a module for
  `TomServerException` and five disagreed with the other seven; the majority
  were right by coincidence, because no check existed and a line that is
  correct only until someone edits it is not an invariant.
  `api_reference_coverage_test.dart` now sweeps every `Type  (module)` line in
  the summaries' fenced diagrams and requires the named module's summary to
  document that type. A parenthetical is read as a module claim exactly when
  the word names a directory under `lib/src/tomserver`, so the rule is anchored
  to the code: `(abstract)`, `(enum)` and `(kernel)` are excluded without a
  list of kind-words anyone has to remember to extend, and a new module is
  policed the day it is created. A second test pins what the sweep reaches —
  it caught its own first draft skipping the deepest branch of every tree,
  whose lines carry a `│` continuation bar the pattern had not allowed.

- **Nothing ran the transactions example, and the read-only flag's nesting rule
  was documented but uncovered (tcinc646).** The example was the module's
  worked demonstration and the source of its documented snippets, and no test
  executed it — so it could drift from the module without anything going red,
  which is how it came to be missing two of the behaviours its document
  credited it with. `transactions_test.dart` now runs it under plain
  `dart run`, requires exit 0, and requires each of the seven numbered steps to
  have reported, so a step that crashes into a swallowed exit cannot pass as a
  clean run. A companion guard rejects a reintroduced `assert(` and requires
  the `check` helper, because the run test cannot tell an example that checks
  nothing from one that passes.
  Separately, "a get-or-create that finds an existing transaction ignores the
  argument" was stated in the module's document and covered nowhere: the two
  existing `isReadOnly` tests both created a transaction, which is the only
  case where the flag *is* consulted. A nested read-only request that silently
  downgraded an open read-write transaction would have relabelled writes
  already made in it, and no test would have moved.

- **The transaction suite now asserts what happens to the participants *behind*
  a failing one (tcinc645).** Twenty-eight tests covered the conclusion paths
  and none of them caught the `&&` short-circuit, because every failure case
  used a single participant — with one, "the loop stopped early" and "the loop
  ran to the end" are the same observation. The two new tests register three,
  fail only the *first* one's `endTransaction()`, and assert that all three
  recorded `end` and that the overall result is still `false`, once per
  conclusion path.
  That shape is chosen to fail two different wrong implementations, not one. On
  the unfixed code participants two and three are never ended, so the call-order
  assertions fail. Against the obvious careless repair — `ok = ended;` — every
  participant *is* ended but the last success overwrites the first failure, so
  the result assertion fails instead. Failing only the first participant is what
  separates them; failing the last would have let both pass.

- **The server guide's limitations section is now checked against the module
  (tcinc643).** "Non-goal, not gap" is a judgement no test can make, so the new
  group pins the two facts it rests on. A capability the guide disowns must
  leave no trace in `lib/src/tomserver/server/` — deleting the four placeholder
  files did not stop one coming back, and this is the direction that was left
  open. And each of the four limitations must still be the module's behaviour,
  read from the one construct that decides it: the status the default handler
  builds, the order the two middlewares are added to the pipeline, the return
  type `start()` declares, and the pair of empty catches in
  `extractAuthentication`. Closing one now turns the suite red instead of
  leaving the guide advertising a defect somebody already fixed.
  The disowned capabilities are read *from the guide*, not listed in the test,
  so the guide stays the input and the test the judge. Bridging a prose bullet
  to a file name is a judgement, though, so the map is written down and a bullet
  it has no entry for fails loudly — renaming "WebSocket" during a live mutation
  duly reported both the roster and the mutation case, which is exactly the
  silent narrowing that would otherwise have gone unnoticed.
- **A documented field is now checked against the class rather than against its
  own dartdoc (tcinc642).** The `securityContext` defect survived because the
  API summary had been checked against the dartdoc, and the dartdoc was what
  lied — so the new group in `api_reference_coverage_test.dart` reads
  `TomServer` itself: no local anywhere in the class re-declares a field name,
  and every field is assigned somewhere. The two checks are ordered rather than
  independent, and the group says so: an assignment check cannot tell a write to
  the field from a write to a local wearing its name, so it is worth something
  only while the shadowing check holds. The synthetic shadowed class asserts
  exactly that asymmetry — it passes the assignment check and fails the
  shadowing one. Mutation-tested live from both ends: reinstating the local in
  `start()`, and removing the `router` assignment, are each reported by name.

  Writing the parser's own synthetic cases caught two parser bugs before either
  could produce a false clean: reading the name from the end of the line made
  `bool ready = false;` a field called `false`, and treating every member-level
  line as a declaration made fields called `log` and `address` out of two
  dartdoc lines that happen to end a clause with a semicolon.
- **The order of `start()`'s two steps is now a checked property, not a
  convention (tcinc641).** A new group in `api_reference_coverage_test.dart`
  parses `start()`'s own body — cut at its closing brace, because
  `_installServerPrincipal` sits further down the same class and a full-file
  scan would find *its* `loginAndInstall` call and pronounce any rewritten
  `start()` correct — and requires the self-login to precede the bind. Two
  separate complaint functions then check the three server mirrors, because the
  two facts rot separately: naming the self-login is the easy half, and saying
  that a failed one leaves the socket unbound is the half a reader hitting it at
  boot actually needs. Both match against the flattened document rather than
  line by line, so a reflow that breaks a phrase across lines cannot make a
  correct document look silent — a marker prose wrapping can defeat teaches
  the next author to reword around the guard. Mutation-tested from both ends:
  removing the login call from `start()`, swapping the two steps, and renaming
  the type and the abort phrase in a mirror are each reported.
- **The documented request scope is now checked against the middleware that
  opens it (tcinc640).** A new group in `api_reference_coverage_test.dart` reads
  the `TomZoneValues` literal and the transaction wrapper out of
  `server.dart` and requires the guide's "Request Context and Zone Values"
  section to name every zone value the middleware publishes, and all three
  mirrors to agree with source about the scope — in both directions, since a
  document that keeps claiming a scope the middleware no longer opens is the
  likelier drift. Mutation-tested: renaming a zone value in the guide, and
  removing the wrapper from source, are each reported.
- **`example/` is now a swept surface for the shipped-text markers
  (tcinc639).** The `shipped text stands on its own` group ran its five markers
  over the library sources and the hand-written documents; an example's dartdoc
  is read by exactly the reader those markers protect — someone outside the
  workspace looking for the shortest complete thing that runs — and is the text
  most likely to have been written with the quest material open alongside. It
  found two defects on its first run. `test/` is deliberately excluded: its
  allowlists cite todo ids on purpose, because a skip that cannot name what
  would lift it is a skip nobody removes.

  The `todo ids` marker also learned the `csexd` prefix, which is what turned
  up the third defect — on the library surface it had been sweeping all along.

- **A heading that counts is now checked against the table it heads
  (tcinc638).** `_miscountedTableHeadings` reads the number word out of every
  heading in every hand-written document and compares it to the rows of the
  table directly beneath. Immediacy is the rule that makes this precise rather
  than noisy: a heading with nothing between it and a table is that table's
  caption, so the number is a claim about those rows. Once prose intervenes the
  claim changes — `doc/export.md` heads "The Two Delivery Channels" over three
  rows whose third is `*(neither)*`, and `doc/resources.md` heads "Two Ways to
  Read a Principal's Locale" over a matrix counting two *columns*. Both are
  correct, and both explain themselves in a paragraph first.

  A number word flanked by a hyphen is a name, not a count — the *two-node*
  cluster demonstration, *Two-Factor* Authentication — and is skipped.

  A companion group ties the cluster readme's table to the directory it
  describes and its `invoked` rows to the `dart run` lines in
  `run_cluster_demo.sh`, so a sixth file or a fourth invocation fails rather
  than silently falsifying the heading. The counting guard's own reach is
  asserted too, because the first draft of the fix put a lead-in paragraph
  between the heading and the table and thereby exempted the one document the
  guard was written for — silently, and only caught by mutating the live file.

- **Nothing checked whether an `**Extends:**` line named the clause the source
  wrote (tcinc634).** The API summaries carry 143 relationship lines across the
  module set, and every one of them was prose: a class could be documented as
  extending a contract it merely implements, and the doc guard would not notice.
  The distinction is not stylistic — it tells a reader writing a second
  implementation whether the contract hands over any behaviour or none — and it
  had already drifted in narrative text describing `TomSqlJobStore`.

  `_Declaration` flattened `extends`, `implements` and `with` into one
  `supertypes` set, which is the right shape for every check that asks whether a
  name is *reachable* from a class and the wrong one for the single check that
  asks under which keyword. It now also records `superclass` and `interfaces`,
  and `every relationship line names the clause the source wrote` compares each
  documented claim against the matching half. `none` is checked as a claim too.

  The reach test pins the claim count *exactly* against the lines on disk rather
  than flooring it: a heading the parser fails to recognise files its class's
  lines under nothing and is then checked against nothing, which is the one way
  this sweep can go quiet while still reporting success. Two summary conventions
  had to be accommodated to get there — headings escape their generics
  (`&lt;…&gt;`), and a relationship line may backtick a module or a file name
  beside the supertype, so names are filtered to those shaped like a type.

  One line did not survive the first run: `api_summary_configuration.md` filled
  `TomBaseServerConfiguration`'s `Extends:` slot with `annotated with
  @tomReflector (abstract)` — an annotation fact in the slot reserved for a
  supertype. It now reads `none (abstract). Annotated @tomReflector.`, matching
  the twenty-four other classes that extend nothing.

- **`TomResourceLocaleException` was asserted nowhere, and `clientThrow` was a
  default rather than a guarantee (tcinc632).** The type adds no field and no
  behaviour; it is declared solely to make `clientThrow` false, because the value
  it complains about came from a config file, a file name or a user record, and
  echoing it to a browser describes the deployment. That single property was
  pinned by no test, and five assertions in `resources_test.dart` named the base
  `TomServerException` — which every exception in the package satisfies, so they
  would have passed unchanged had the constructor thrown something else entirely.

  The flag was also written `super.clientThrow = false`: a re-default a caller
  could override, not an invariant, while both the api summary and
  `doc/resources.md` claimed the stronger property. The constructor now drops the
  parameter and passes `super(clientThrow: false)`, matching the hard-wire idiom
  `Tom2FAException` and `TomServerSelfLoginException` already use, so the
  documented claim is true of the type rather than of the instances this package
  happens to raise. A new `TomResourceLocaleException` group pins that, both keys
  (`resources.locale.empty_language`, `resources.locale.invalid_country`), the
  `country` parameter, and that a clause written for the base type still catches
  it.

- **Nine query-sentence assertions named the base class, and four of them were
  hiding which component does the refusing (tcinc632).** The sweep behind the
  item above found twenty-six `isA<TomServerException>()` sites across `test/`.
  Fourteen are deliberate — they assert subtype membership, which is the point of
  the test. Three cannot be more specific because the code throws the bare base
  class, now tracked as tcincb155. The other nine were simply loose, and
  tightening them to `TomQuerySyntaxException` turned four red.

  Those four do not raise a syntax exception at all. `find by title is`,
  `find by title is not`, `find by title not null` and `find by nosuch = :x` are
  refused by `TomAnnotationAnalyzer.determineColumn`, because the compiler reads
  the dangling keyword as a column name and asks the entity's annotations about
  it. The tests now assert that type and say so; the group covering truncated
  sentences is split, since three of its five sentences are refused by the parser
  and two are not. For `find by nosuch` the delegation is the right answer; for
  the other three the developer is told to add a `@TomDbColumn` to a field they
  never wrote, which is tracked as tcincb156 together with that exception's
  `clientThrow: true`.

- **The resources module's twenty-nine tests lived inside the messaging
  module's suite, so every inventory reported it as untested (tcinc628).**
  `group('TomTextLocale')` and `group('TomLocalizedTextResources')` sat in
  `test/email_service_test.dart`, under a header describing "the templating
  layer above the message transport". A coverage sweep matches on the filename —
  it is the only signal available without running anything — and there was no
  filename to match, so the sweep said "no tests found" and was believed.

  Both groups now live in `test/resources_test.dart`, unchanged. The bundle set
  and principal they share with the email suite moved to
  `test/fixtures/localized_texts.dart` rather than being copied: the fixture's
  value is that it is *half* translated, no assertion in either suite states
  that, and against a fully translated set an implementation ignoring the locale
  entirely would pass everything. Two copies would have been two things to keep
  true, and the day they drifted both suites would still be green while testing
  different chains.

  The quieter cost is what made this worth a standing check rather than a move.
  Tests filed under another module's name are carried off by any change to
  *that* module — a rewrite, a split, a deletion — and the loss is silent in
  both directions, because a suite nobody counted cannot make a total drop.
  `api_reference_coverage_test.dart` now asserts that every directory under
  `lib/src/tomserver/` has at least one `<module>*_test.dart`. Nineteen modules
  satisfy it; `preferences` is quarantined behind tcincb154, its six
  `user_preferences*` suites being named after the types rather than the
  directory — a judgement to make rather than a gap to close.

  `doc/resources.md` gains the Verification section it previously had no suite
  to name, and `doc/messaging.md` no longer claims the email suite covers locale
  *fallback*, which is the resources module's rule and is pinned where it
  belongs.

- **Three documented preferences behaviours that need no database were behind
  the `db` tag by proximity, and one of them was untestable where it sat
  (tcinc622).** `TomUserPreferences.resolve()`'s deliberate `null` for an
  unwired deployment had no test at all; `preferences.not_configured` appeared
  in the endpoint suite only as a hand-written string, so nothing tied the
  handler's silence about it to the key the endpoints actually raise; and
  `toDto()`'s UTC normalisation was covered solely by
  `user_preferences_db_test.dart`. That last one is the sharp case: the entity's
  own comment says the conversion is a *no-op* for a value read from the column,
  because the datasource has already UTC-flagged it — so asserting `isUtc` on a
  round-tripped value passes whether the normalisation happens or not. It is the
  one path that cannot observe the behaviour, and it was the only path testing
  it. Thirteen tests now run in the default pass. `user_preference_dto_test.dart`
  is new and reaches the normalisation the only way anything can, from an
  in-memory local-flagged instant, asserting both halves separately — that the
  flag changed and that the moment did not, since re-labelling the wall clock as
  UTC would satisfy the first and shift every timestamp by the server's offset.
  The endpoint suite gains a `_missingStoreFailure` helper mirroring its existing
  `_keyRefusal`, and its opaque-500 test now takes the real error instead of a
  copy. All four endpoints are asserted, not one: `_store()` is a private helper
  each calls separately, so an unwired deployment could answer three named faults
  and one null dereference.
- **The preferences round trip lets the pipeline build the handler, as the
  module document says a deployment can (tcinc616).** `doc/preferences.md`
  promises two things a deployment need not do — register the API ("the pipeline
  registers it itself, so a deployment gets these endpoints without adding a
  line") and register the handler ("needs no bean ... the pipeline instantiates
  it") — and the one suite that mounts the real router did both by hand in
  `setUp`, so it exercised neither. The bean registration was the load-bearing
  one: `initializeRouter`'s `??=` chain reaches `instantiateComponent` only when
  the lookup came back empty, so pre-registering did not duplicate the
  construction, it replaced it. `instantiateComponent` could have regressed to
  returning `null` — the very path whose dartdoc names `TomUserPreferencesServer`
  as the case it was written for — and this suite would have stayed green while
  every deployment that followed the document lost its preference endpoints.
  Both registrations are gone, plus a third for `TomHealthServer`, which is
  framework-shipped for the same reason. The fixture services stay: they stand
  in for an *application's* components, which nothing claims are auto-built.
  A new test then covers the half that removal cannot reach — dropping only the
  `TomBean.withType` inside `instantiateComponent` leaves the router mounting
  the returned instance, so every other test passes while the dartdoc's promise
  that "the router and any later `TomBean.getBeanByType` see the same object" is
  silently broken. It asserts the bean was absent before routing and present
  after. Verified by mutation in both directions.
- **The preferences round trip asserts *which* refusal an anonymous caller gets,
  and serves it through the framework's error layer to have one (tcinc615).**
  The anonymous-caller test asserted `isNot(200)`, which the state it exists to
  exclude also satisfies: with the contract's `access:` removed the handler runs,
  reaches `TomUserPreferences.all()` and fails in `_requirePrincipal`, and the
  answer is a `500` either way. Tightening the status to `500` would not have
  helped — the two differed in the body by the case of one letter. What the
  test lacked was the layer that makes them distinguishable. `TomServer.start`
  always installs `_handleError(errorHandler, "InnerErrorHandler")` between the
  authentication middleware and the router, and this test's hand-built pipeline
  did not, so the denial — which is thrown *before* invocation and therefore
  escapes the endpoint's own `TomEndpoint.errorHandler` — reached shelf uncaught
  and was served as shelf's bare `500 Internal Server Error`. The pipeline now
  installs that layer, delegating to the shipped `TomServer.errorHandler` rather
  than a copy of it, and the test asserts the `x-tom-error` header and the
  envelope's `errorKey` (`endpoint_handler.handle_method_call.access_denied`) —
  evidence only the gate produces. Verified by mutation: removing
  `access: const TomAuthenticatedAccess()` from the list endpoint now fails the
  test, and fails it at the envelope rather than at the status.
- **The preferences "endpoint wiring" test asks the router which handler an
  endpoint is served under, instead of asking an annotation (tcinc614).** It
  read `@TomApiEndpointImplementation.errorHandler` off the method's own
  metadata, which is one step short of the binding that matters: the pipeline
  reads `metadata.endpoint.errorHandler`, a *merged* value that
  `convertToTomEndpoint` produces from the endpoint's own handler, the
  class-level `@TomApiImplementation`'s API-wide one, and the framework default.
  A declared handler the merge dropped would have left the annotation intact and
  the test green while every preference miss answered `500`. The group now
  builds its metadata with `TomEndpointRouting().getClassMethodMetadata` — the
  same call `initializeRouter` makes — and reads the handler from there, which
  subsumes the annotation check, since the merge cannot yield the preferences
  handler unless the annotation declared it. Verified by removing `errorHandler:`
  from `readPreference` and regenerating reflection: the test fails, naming the
  method and reporting the `TomDefaultErrorHandler` it fell back to. Two
  consequences: `registerTomUserPreferencesApi()` in the group's `setUpAll` is
  now load-bearing rather than decorative, because the metadata build resolves
  each endpoint against `tomRemoteApis` and throws without it; and the list
  endpoint is asserted to route to `TomDefaultErrorHandler` rather than to have
  no handler at all — declaring no override is not the same as being served by
  nothing, and the old wording described a pipeline that does not exist.

- **`object_persistence_example.dart` demonstrates the module instead of the
  query-builder DSL alone (tcinc610).** It was nine steps, all of them
  `TomQueryBuilder` calls, with a header that deferred everything else to
  `doc/object_persistence.md`. It is now sixteen, and covers the surface that
  appeared in *no* example anywhere in the package: mapping through
  `TomAnnotationAnalyzer`, the four sentence kinds compiled by
  `TomQuerySentenceCompiler`, `TomGroupedSelect`, `TomPageRequest` and
  `TomColumnAuthorization` — each with the refusal that bounds it, since a
  query the module accepts is one you would have written anyway and what is
  worth showing is where it stops you.

  Two of those steps say *when* as well as *what*. A `HAVING` on an ungrouped
  column is refused by `generateQuery`, not by the compiler, because whether a
  column is grouped is a question about the rendered statement; the example
  therefore compiles the sentence successfully and then renders it to be
  refused. And `decideWrites` is driven off `@TomDbColumn(authKey:)` rather
  than off hand-written tokens, so the step shows how the feature is actually
  reached.

  That needed a reflected entity, `ExampleClaimRecord`, added to the existing
  `example/example_reflection.dart` root rather than to a second one — a
  further root costs ~1.7 MB of generated source capturing the same framework
  surface. Its two graded columns carry *different* grades on purpose:
  `reimbursement_account` resolves as `read`, so editing it is a named
  violation, while `fraud_score` resolves as `none`, so it is masked out and
  silently overlaid on the way back in. One graded column would show that
  grading happens but not that the two failure modes differ.

  The header now defers only what genuinely needs a live data source — the
  repository round trip — and points row scopes and file-reference keys at
  `resource_data_scope_example.dart` and `file_storage_example.dart`, which
  already cover them, rather than repeating them.

- **The six least-covered files of `object_persistence` now have their
  rejections and success paths asserted (tcinc609).** Measured as line
  coverage, the module moved: `column_authorization` 67.5 % → 95.0 %,
  `data_scope` 90.9 % → 98.3 %, `grouped_query` 84.9 % → 99.4 %, `paging`
  85.7 % → 100 %, `query_sentence_compiler` 78.1 % → 86.5 %. What is left in
  the first four is private constructors, which no test can reach.

  The gaps were behavioural, not cosmetic. `column_authorization_test.dart`
  now covers `applyReadMask` — the entry point the repository actually calls,
  which nulls a withheld column *in place* through the reflected column mirror
  — including the rule that a column with a per-row resolver is exempt from
  column-wide masking, because the value that would be blanked out is the blob
  key the per-row gate needs in order to decide. The same file pins the
  default resolver, i.e. what an unconfigured deployment does with a graded
  column: it grants, so a server that has not wired up authorization does not
  silently blank out its own data.

  `data_scope_test.dart` covers `columnEqualsParam`, the second of the two
  renderers that must agree on a key column's SQL type when a scope predicate
  is ANDed onto a primary-key lookup. `grouped_query_test.dart` covers the
  driver-representation coercions (a textual boolean read by content rather
  than truthiness, an exact-numeric truncated to `int`, a non-numeric refused
  as both `int` and `double`), the aggregate/row/select `toString` and
  introspection surface, three grouped-sentence rejections, and the temporal
  arms of the min/max dispatch — which needed a second fixture, as
  `FixtureTaskRecord` has no date column.

  `query_sentence_rejection_test.dart` is new: the compiler is the one place
  in the module that reads a string a developer wrote by hand, so its
  complaints are an API that callers discriminate by `TomServerException.key`.
  It pins ~26 of them — `LIKE` and `REGEXP` (rendering, plus the missing-column
  and wrong-column-type refusals), the operators that need a column in front
  of them, the structural refusals of the parser (an empty bracket, a leading
  `AND`/`OR`, an order clause naming no field), and the literal/column type
  agreement checks together with the success boundary each one bounds.

- **The invariant behind the auto-scope guard is now pinned, not assumed
  (tcinc608).** `persistence_metadata_sharing_test.dart` asserts that every
  column of a resolved entity names one table — the property that lets
  `autoScopeFor` decide the grant-table exclusion for a column list as a whole.
  It is a one-line change in `_getColumnInfo` (resolving the table per
  declaration rather than per type) that would break it, and the consequence
  would surface not there but in the authorization layer.

  `resource_data_scope_test.dart` asserts the guard reaches a grant table's
  column wherever it sits in the list, and `data_scope_test.dart` pins the empty
  list, which `findDataScope` really does pass for a type whose columns cannot
  be resolved.

- **`null` is now pinned as an answer of the analyzer's lookups, not a failure
  of them (tcinc607).** `annotation_analyzer_null_memo_test.dart` covers the four
  lookups that may answer `null` — `findMirror`, `findTable`, `findDataScope`,
  `getPersistentColumns` — from two directions. At runtime it asks each one
  twice for a type it cannot resolve and requires the second answer to be `null`
  as well: the memo stores the miss, so `containsKey` is true with a `null`
  value, and a cache read written as `cache[t]!` would pass the first call and
  crash on the second.

  The five sites that had done exactly that were not reachable from a
  connection-free test, so the file also scans `lib/` for the shape itself and
  fails naming file and line. Two self-tests pin the scanner: that it finds a
  planted assertion, and that it ignores comment lines — these method names
  appear throughout their own dartdoc, including in the sentences warning
  against asserting them.

  `queries_test.dart` gained the assertion that a `TomDelete` renders the table
  of the entity it was constructed over; the existing paging tests only matched
  the tail of the statement, leaving the table name — the thing the fix
  re-sourced — unpinned.

- **The mirror lookup swallowed every reflection failure (tcinc605).**
  `TomAnnotationAnalyzer.findMirror` wrapped `tomReflector.reflectType` in an
  empty `catch` and answered `null`. `null` has a meaning there — the type is
  not registered — so all three outcomes arrived as one, and two real faults
  were reported as the third. The lookup now absorbs only the
  `NoSuchCapabilityError` that actually means "unregistered" and throws
  everything else as `TomAnnotationAnalyzerException` with the original as
  `rootException`, memoising nothing for a thrown lookup. The two it used to
  hide: reflection that was never initialized — which makes *every* type look
  unregistered, and whose `StateError` names the missing
  `initializeReflection()` call — and a name that is not a class (`dynamic`,
  `void`, an erased generic parameter). `analysePersistentType` lost its two
  catch-alls in the same pass; each of its three lookups now yields a message
  naming the missing thing, and a `TomAnnotationAnalyzerSyntaxException` from
  `getPersistentColumns` travels out unchanged instead of being flattened into
  the registration error, which is what the mixin's other callers already did.
  `test/annotation_analyzer_mirror_lookup_test.dart` pins all three outcomes,
  reproducing the uninitialized case in a fresh `Isolate.run` because the
  reflection state is per-isolate.

- **`object_persistence_test.dart` ran with reflection uninitialized
  (tcinc605).** It never called `initializeReflection()`, so its
  "non-reflectable type resolves to `null`" assertion held because *nothing*
  was reflectable — the exact misdiagnosis the change above removes, which is
  how it surfaced. The file now has a `setUpAll(initializeReflection)` and the
  assertion holds for its stated reason.

- **The analyzer's six memos could not be discarded (tcinc604).**
  `TomAnnotationAnalyzer` memoises six derived resolutions per entity type —
  mirror, table, columns, row scope, column-authorized columns, file columns —
  and, once they were made private, nothing could clear them. A test that
  re-registers a fixture type it has already analysed, under a different
  mapping, would read the first answer back and fail as though the mapping were
  wrong; nothing about that failure points at a cache.

  `reset()` now empties all six, and only all six. They are derived from one
  another, so a caller emptying the ones it happened to know about would leave
  the rest describing an entity that no longer exists. It sits beside the
  declarations rather than at the end of the class, because the failure worth
  designing against is a seventh memo added later and not added to `reset()`.

  `persistence_metadata_sharing_test.dart` asserts the rebuild by identity and
  then asserts the same thing structurally: it reads the mixin's own source,
  counts the declared caches and checks each is cleared inside `reset()`'s body.
  Identity checks cannot cover the seventh-memo case — a memo nobody thought to
  test is a memo nobody thought to clear — so the declaration is compared with
  the body directly. The guard was verified by deleting one `clear()` call and
  confirming it fails.

- **Resolved persistence metadata was shared by everyone and writable by anyone
  (tcinc603).** `TomAnnotationAnalyzer` resolves an entity's columns once and
  hands the same `TomColumnInformation` objects to every repository, query
  compiler and datasource for the life of the isolate. All ten of their fields
  were public and assignable, the memoised list was a plain growable `List`, and
  the six memo maps were public statics. Any holder could therefore change a
  column's mapped name — or add, drop or reorder the columns, or replace an
  entity's whole answer — and every query compiled afterwards would follow the
  edit, with nothing failing at the point of the mistake.

  Nothing needed the mutability: the analyzer knows all ten values before it
  constructs the instance and never writes one afterwards. The fields are now
  `final`, `getPersistentColumns` / `findAuthColumns` / `findFileColumns` hand
  out unmodifiable lists, and the six memos are private — closing the third
  route, by which a caller could substitute a different answer for a type
  outright.

  `persistence_metadata_sharing_test.dart` pins both halves: the runtime shape
  of what callers receive (same list, same objects, every mutation refused) and
  the structural property that guarantees it — a reader over the declaration
  asserting no field of `TomColumnInformation` is writable. That second test
  exists because the first cannot reach it: assigning to a `final` field is a
  compile error, so a test that tried would not build, and a field added later
  would inherit the sharing without inheriting the discipline. The reader's own
  cases pin what nearly made it cry wolf — a `return x;` in a method body and
  the `});` closing a wrapped constructor both end in a semicolon at the class's
  left margin, and are excluded by brace depth rather than by punctuation.

  The constructor signature is unchanged, so the generated `*.reflection.dart`
  registrations across the samples and `tom_uam_server` continue to build; all
  five analyze clean.

- **The rule that shipped text must stand on its own was enforced in one module
  and broken in four (tcinc602).** `configuration_test.dart` guarded exactly two
  files — the configuration dartdoc and `doc/configuration.md` — against
  gesturing at "the quest completion steps". The rule was never specific to
  configuration; it was only *discovered* there, and meanwhile eight other
  places across object_persistence, export, server and endpoints carried a quest
  reference, a todo id or an internal bug number.

  So the guard was generalised instead of copied. `api_reference_coverage_test`
  gains **'shipped text stands on its own'**, which sweeps every source under
  `lib/` and every hand-written document in the package — the README, `doc/`,
  `doc/api_reference/` and the module readmes — for five markers: a `quest`
  word, a completion-steps pointer, a todo id (`tcinc…` / `tcopen…`), an
  internal bug number (`bug §…`, `RCK…`), and the unnamed "a tracked follow-up".
  The per-module group in `configuration_test.dart` is strictly subsumed and was
  removed rather than left to be maintained twice.

  Text is flattened into paragraphs before matching, so a phrase merely
  rewrapped across two lines does not read as fixed. A paragraph ends at a blank
  line *or* where the comment marker changes — a dartdoc block is not separated
  from its declaration by a blank line, and without that break the failure
  message quoted a whole class body and named nothing in particular. The word
  boundary on `quest` is what keeps the package's several hundred uses of
  `request` and `question` out of the report; both that and the paragraph break
  are pinned by cases in a parser test rather than left to be rediscovered.

  What is deliberately *not* guarded is history narration — "used to be",
  "previously", "before the refactoring". It breaks the same rule, but no
  pattern separates it from legitimate present-tense prose ("the key is no
  longer referenced") without crying wolf, and a guard that cries wolf gets
  turned off. Those sites were fixed by reading.

- **Nothing stopped a document from teaching an unsavable primary key
  (tcinc601).** The shape that prompted this — `int id = 0` under
  `@TomEntityId` — is legal Dart the analyzer is silent about, and the failure
  it causes is a save that writes nothing rather than one that raises, so
  neither of the gates this package runs could ever have caught it. Only a
  document can teach it, and only a document sweep can find it. The new group in
  `api_reference_coverage_test.dart` parses every `@TomEntityId` field declared
  inside a Dart fence of a hand-written document — the module readmes, the
  guides, the API summaries and the package README — and fails on a
  non-nullable numeric key initialised to zero, naming the file, the line and
  the two acceptable shapes. Nullable keys and constructor-assigned keys are
  recorded as "nothing to judge" rather than filtered away, so the sweep's own
  reach stays measurable; non-numeric keys are skipped because `isUnsavedKey`
  never calls a natural key unsaved, so the zero-versus-negative question does
  not arise for one. Two meta-tests keep it honest — one that the sweep found
  declarations at all and reached the module readme in particular, since an
  emptiness assertion over an empty sweep passes in silence; one that pins the
  parser against the layouts the documents actually use (annotations on their
  own lines and inline with the field, type arguments carrying a comma,
  argument lists carrying a nested paren, and the same text outside a fence,
  where it is prose about the annotation rather than a declaration).

- **The only `Date:` header test used the one offset that cannot show a padding
  bug (tcinc580).** `formatRfc5322Date` was asserted against
  `DateTime.utc(...)`, whose offset is `+0000` — where the hour is `0`, the
  minute is `0`, and `0 % 60` is `0`, so a dropped `padLeft` and a dropped
  `% 60` produce a wrong string only in ways that all three zero values happen
  to share. A second test formats a *local* `DateTime` and asserts the shape
  (`[+-]\d{4}`, four digits always) and then parses the offset back out and
  compares it to `timeZoneOffset` — read back rather than recomputed the way the
  encoder computes it, so the test disagrees with a wrong implementation instead
  of copying it. It exercises whatever zone the machine runs in, which is a
  single-digit hour on most of them and a non-zero `% 60` in India, Iran and
  Nepal.

- **Nothing checked that the package was formatted, and it had already drifted
  twice (tcinc572).** `dart analyze` — the gate this workspace mandates and the
  one everybody actually runs — reports nothing about line wrapping, so a file
  can be analyzer-clean, test-green and merged while being unformatted. The
  package paid for that twice: 127 files carried the pre-3.7 short style until
  they were reformatted wholesale, a 6,000-line commit that could not be
  deferred because every later change would otherwise drag an arbitrary slice
  of it into its own diff; and four days after that cleanup the package drifted
  again, ten hunks in `messaging_example.dart`, added under a todo whose stated
  gate was `dart analyze`. The new `formatting_test.dart` closes the hole: it
  walks `lib/`, `example/` and `test/`, runs the SDK formatter over every
  hand-written file via `Platform.resolvedExecutable` (so the guard and the
  developer's fix use the same formatter on a machine with several SDKs), and
  fails naming the offending files. Two meta-tests keep it honest — one that
  the walk actually reached each directory, since a walk that finds nothing
  formats nothing and passes; one that the `.reflection.dart` exclusion still
  matches something, since an exclusion that excludes nothing is a dead rule
  the next reader cannot recognise as dead. Generated output is excluded on the
  same reasoning the example sweep in `api_reference_coverage_test.dart` uses:
  a generator emitting unformatted code is that generator's defect, and failing
  here would point the reader at the wrong package. The header states that a
  failure on an untouched machine means the SDK formatter changed, and that the
  answer is to reformat the package rather than relax the test.

- **`LoginException` had no coverage in the module that declares it
  (tcinc562).** It is thrown from thirty-three sites across the authentication
  and 2FA code, but `little_things_test.dart` never named it and the module's
  example never constructed one. Its only direct assertions lived in
  `authentication_test.dart`, filed under the module that raises it — which
  covers the login flow, not the declaration. A `LoginException` group now pins
  the inherited surface from this side (`isA<TomServerException>()` and
  `isA<TomException>()`, `key`/`defaultUserMessage`/`parameters` forwarding,
  isolate attribution, zone-based `requestUuid` correlation both inside and
  outside a request zone) and a fifth example step throws one and catches it
  with `on TomServerException catch (e)`, which is the pattern the api summary
  advertises and nothing demonstrated.

- **The `clientThrow` claim the documents made about `LoginException` was wrong
  twice over (tcinc562).** Four artefacts said it was "the one type in the
  package that does not offer the choice" and that "a caller cannot mask one".
  Classifying all twenty-eight `TomServerException` subtypes refutes the first:
  fifteen of them — the largest group, `LoginException` among them — inherit
  the `true` default by omitting the parameter exactly the same way, so the
  omission is the norm rather than an exception to it. The true claim is
  narrower and more useful: within the *authentication* subsystem it is the
  outlier, because `Tom2FAException` and `TomServerSelfLoginException`
  hard-wire `clientThrow: false` and `TomOAuthException` re-defaults it to
  `false` — a login failure's message is written for the person who mistyped a
  password, so it is the one that may reach them. The second claim fails on the
  declaration: `clientThrow` is a plain mutable `bool` on the base, not a
  `final`, so a catch site can flip it before rethrowing. What the omitted
  constructor parameter fixes is the default, not the value; the type
  guarantees no invariant, and code needing "never shown to a client" must
  enforce it at the handler. Both facts are now asserted rather than asserted
  about, and the guide, the module readme, the api summary and the test comment
  say the accurate thing.

- **The health-check test and example pointed at coverage that does not exist
  (tcinc560).** Both headers said the `GET /health` route was "covered by
  `doc/healthcheck.md` and integration tests, not here". A document covers no
  route, and this package has no integration suite — while the route is in fact
  covered in the same package, by `endpoints_pipeline_test.dart`'s group
  `healthcheck GET /health route`, which neither header named. Coverage nobody
  can find gets written a second time by the next person to add a route
  assertion, and deleted by the next person who reads the group's name as
  belonging to another module.

  Both headers, and `doc/healthcheck.md`'s endpoint section, now name that
  group. They name it by *group name* rather than line number so the pointer
  survives edits to the file it points into — this todo's own stored reference
  had already gone stale by ~700 lines. The example's header also claimed the
  route "needs a running server"; it does not, and that claim was the reason
  the in-package coverage looked impossible.

  Writing the pointer turned up a hole in what it pointed at.
  `@TomPublicAccess` was **not** in fact pinned: `checkAccess` falls back to
  `!globalSettingProtectionDefault` when an endpoint declares no access
  control, which under the suites' permissive default is `true` — the same
  answer the annotation gives. Deleting the annotation and regenerating
  reflection left the whole group green. The group now also asserts that
  `/health` serves anonymously with
  `TomResourceKeyProtection.globalSettingProtectionDefault` turned **on**,
  which is the only setting under which the annotation is observable, and the
  deployment the endpoint actually has to survive: a hardened server still owes
  its orchestrator a liveness probe, and a probe holds no token.

- **Two of the `/health` endpoint's three deliberate choices were documented as
  load-bearing and asserted nowhere (tcinc559).** `doc/healthcheck.md` presents
  `@TomPublicAccess`, `produces: TomMimeType.plainText` and
  `logRequests: false` as decisions "a deployment might otherwise try to undo".
  The public access appeared to be covered by an unauthenticated call returning
  200; tcinc560 established that it was not covered at all, and closed that
  third gap.

  Both gaps regress silently in production, which is why they are worth
  assertions rather than review. `produces` defaults to `TomMimeType.json`, so
  deleting the argument does not drop the Content-Type header — it turns the
  body into an `application/json` one, and a probe matching the body for `OK`
  still finds those two characters inside the JSON. And a probe log flooding at
  orchestrator frequency breaks nothing anyone reports; it is noticed days
  later by whoever next reads the log.

  The `healthcheck GET /health route` group now asserts that the response
  Content-Type starts with `text/plain` (matched by prefix, since the charset
  parameter is the serializer's business), and that a `GET /health` produces no
  pipeline log line. The logging test sets
  `globalSettingLogRequestsDefault = true` first, so silence can only come from
  the endpoint's own annotation — without that, removing `logRequests: false`
  leaves the flag null and the test would pass on the fallback. It then asserts
  that `/fixture/health`, which carries `logRequests: true`, *is* logged: an
  assertion that nothing was logged passes equally well against a capture that
  was never wired up.

  Each mutation is caught by its own test with the other left green. The
  existing 200 assertion also now names what it pins, so all three choices read
  as deliberate at the point they are checked.

- **An interrupted download was believed to leak a `package:http` exception; it
  does not, and what was actually untested was the bytes it delivers first
  (tcinc546).** The reported defect was `TomS3BlobStore.doGet`'s
  `yield* response.stream` — a socket that dies mid-transfer reaching the caller
  as a `ClientException` rather than a named storage error. Read on its own that
  is exactly what the line does. It is not what the module does: `doGet` is
  consumed by `TomBlobStore.get`, which uses `await for` inside its translating
  `try` precisely so that inner-stream errors cannot bypass it, and the failure
  arrives as `storage.blob.read_failed` carrying the caller's key with the
  transport error kept as `rootException`. The premise predated that wrapper.

  The test the report asked for was still missing, and writing it found a
  different gap. Every existing mid-stream test fails on the *first* byte — a
  data source that throws, a file the filesystem refuses — so nothing measured
  what happens to bytes that already arrived. Making `get` drain its backend
  before yielding leaves the entire suite green: the translation still fires,
  and a broken download silently becomes an empty one. A consumer that has
  written the first megabytes to a file can truncate; one handed nothing cannot
  tell a failed transfer from an empty object.

  So `get` and `TomExportStore.open` now *state* the partial-delivery guarantee
  rather than merely having it, and two tests in `file_storage_test.dart` pin
  it: a `MockClient.streaming` response that yields bytes and then raises a
  `ClientException` must produce the named error, and must produce it *after*
  handing over what arrived. Four mutations, each naming the test that has to
  catch it. The buffering mutant is the one that matters — it is caught by the
  new partial-delivery test and by nothing else, which is why the two tests are
  two rather than one.

  `s3_blob_store.dart` and `directory_blob_store.dart` now say at their `yield*`
  why forwarding is correct there and where the translation lives. That comment
  is the actual fix this report earned: the line was right, and reading it in
  isolation reasonably suggested otherwise.

- **`blobManifestTableDdl` and `blobChunkTableDdl` were documented public API
  with no callers anywhere (tcinc543).** Both were exported, both were in the
  api reference, and nothing in `lib/`, `test/` or `example/` called either, so
  the reference described a surface no test would notice breaking. The obvious
  reading was that they were dead and should go — and the evidence says the
  opposite. There are nine such helpers across four modules and six are live
  and heavily used (11, 9, 7, 7, 5 and 5 references); removing the file-storage
  pair would have left one module unable to answer a question the other three
  answer. That question is a real one: a store constructed with `manifestTable:`
  or `chunkTable:` set to something else ships no reference migration, so a
  deployment whose credential may not run DDL has nowhere but these two
  functions to get its schema from. What file storage was missing was the
  *guard* its siblings have, not the surface.

  `test/file_storage_schema_test.dart` adds it: each shipped migration compared
  against the text the corresponding function renders, plus what the schema
  claims — `storage_key` exactly as wide as `TomBlobStore.maxKeyLength`,
  `file_name` as the one nullable column, `stored_at`'s width, chunks keyed on
  the upload rather
  than the blob, and `chunk_data` as text because the driver decodes every
  column into a `String`.

  This does not duplicate `framework_schema_test.dart`, which replays the chain
  and compares the schema it *arrives at*. That check is deliberately blind to
  how a statement is spelled, and the mutation run made the gap concrete:
  narrowing `storage_key` to `VARCHAR(255)` and dropping `file_name`'s
  nullability both leave convergence green. A spelling is what a deployment
  copies, and nothing had been measuring it.

  Six mutations confirm the guard bites. Each helper rendering the *other*
  table's DDL is killed separately, because a suite comparing only one file
  would catch one and pass the other. Deleting the new suite is the control: it
  leaves everything else green, which is what "no callers anywhere" means when
  it is measured rather than asserted.

  `normaliseSql` and `readMigration` moved into `test/fixtures/sql_text.dart`;
  they had been written out twice and were about to be written a third time.
  The extraction has its own cost — one function now decides what "the same
  statement" means for three modules, and a version returning the empty string
  would turn nine assertions into `'' == ''` with every suite still green — so
  `test/sql_text_test.dart` guards it, the load-bearing case being that two
  different statements stay different.

- **No test had ever read an `Access-Control` header off a response
  (tcinc519).** The one test touching the preflight path sent an `OPTIONS` and
  asserted `inInclusiveRange(200, 299)`, which did not check what its caption
  claimed: it read "returns without invoking", but `/fixture/health` answers
  200 when it *is* invoked, so the assertion held either way. Neither the three
  shipped defaults nor a per-endpoint override was pinned anywhere. CORS is the
  one boundary whose failures are invisible to every test the package has —
  `curl` ignores these headers, the router-level tests get their answer
  regardless, and the integration suites speak Dart — so a regression reaches
  production intact and surfaces only as "the web app cannot call the API".
  Eight tests now assert the headers as a browser sees them: the three
  defaults, their shipped values stated once so a change of posture is a
  deliberate edit, the empty preflight body that distinguishes answering from
  invoking, an origin-only override leaving methods and headers at their
  defaults, an all-three override, a default changed *after* the routes were
  mounted still reaching them, a role-gated endpoint answering preflight with
  no principal in the zone, and a socket route answering it like any other. Two
  fixture endpoints were added to make the override paths reachable at all —
  with no endpoint stating `corsAllowedMethods` or `corsAllowedHeaders`,
  dropping their fallback entirely would have left the suite green. Seven
  mutations confirm each bites: ignoring each of the three overrides, running
  preflight after access control, not mounting `OPTIONS` on a socket route,
  changing the shipped default, and hard-coding the default instead of reading
  the setting each fail exactly the tests that claim them. No production change
  was needed — the behaviour was correct and unasserted.

- **`injectQueryParameters` was pinned in OAuth's suite, not in the endpoints
  suite beside its two siblings (tcinc518).** The three folds are applied in a
  fixed order by one pipeline — `injectFormFields`, then
  `injectQueryParameters`, then `injectPathParameters` — but only two of them
  were tested where that order is legible. The query fold's group lived in
  `oauth_test.dart`, because the callback was the first endpoint to need it,
  and every case in it was about the helper rather than about OAuth: a
  synthetic `/callback` endpoint, never `tomOAuthApi`, whose real mapping is
  declared in the kernel. The group moved to `endpoints_test.dart` rather than
  being copied, and gained the two cases the sibling groups already had and it
  did not: that a query parameter overrides a same-named *body* field — a
  `putIfAbsent` here would reverse the precedence with every other ordering
  test still green — and that a mapped parameter the caller simply omitted is
  not manufactured as a null. Four mutations confirm the group bites: an
  identity fallback, `putIfAbsent`, binding under the wire name instead of the
  DTO field name, and dropping the per-parameter null guard each fail exactly
  the test that claims them. The two early returns are not among them, and
  cannot be: with an empty mapping the loop iterates nothing and with an empty
  query every lookup is null, so both are optimisations rather than behaviour.
  The silent drop of an unmapped query parameter — the module's most
  mistakable rule — comes from the *absence* of an identity fallback, which is
  what the first mutation pins. That asymmetry against the path fold is
  deliberate: a route is the endpoint's own declaration, so binding a capture
  by its own name is safe, while a query string is whatever a caller chose to
  append.

- **Nothing had ever switched automatic endpoint protection on (tcinc516).**
  `tcinc504` established which keys protect an endpoint, but every one of its
  ten tests called `checkAutomaticAccess` directly.
  `globalSettingUseAutomaticEndpointProtection` — the switch `enforceAccess`
  consults before it will consider a resource key at all — was assigned `true`
  nowhere in the package: not in a test, not in a sample, not in a default. So
  the keys were pinned against a rule no request had been shown to reach, and
  the question an operator actually asks, "I minted a key for this API, does it
  open the endpoint?", had no answer in the suite. Six tests now ask it through
  `enforceAccess`: that the key is inert while the gate is off and admits while
  it is on, that the implementation class name opens nothing, that a
  `-<apiId>.<endpointId>` exception shuts one endpoint and spares its sibling,
  that the second chance cannot lower a grant the ordinary check already made,
  and that a denial surviving it is audited even though the endpoint carries no
  `@TomAudited`. Five mutations confirm each bites: removing the gate, running
  the rule unconditionally, ignoring the revocation, keying on the class name,
  and dropping the denial audit each fail exactly the tests that claim them.

### Fixed

- **`TomCache` accepted a zero or negative timer interval, installing a
  busy-loop periodic timer (tcincb1_ahwo).** `deletionIntervalSeconds` and
  `clearIntervalSeconds` went straight to `Duration(seconds: …)` in
  `createDeletionTimer` / `createClearanceTimer` with no check. `Timer.periodic`
  does not read a zero period as "never" — it reads it as *as fast as the event
  loop will run it*, and treats a negative period the same way. Measured, a
  zero-period timer ticked ~73,000 times in 50 ms and a negative-period one
  ~86,000: a cache configured that way burnt a core sweeping a map and reported
  nothing anywhere.

  The fix generalises tcinc408's `maximumEntries` check rather than adding a
  second one beside it. All four of the constructor's numbers are now positive
  or `null`, validated through one routine and reported as an `ArgumentError`
  naming the parameter — four numbers share one constructor, so an error that
  gave only the value would leave the caller guessing which of its own settings
  produced it. `deleteEntriesAfterSeconds` is included because it was the
  remaining unchecked number and fails the same way `maximumEntries` did: a
  non-positive lifetime stores every entry already expired, so the cache accepts
  every store and misses every read. `null` still switches each feature off, and
  `1` upwards is unchanged.

  All four checks run before `createTimers()`. That ordering is load-bearing for
  the intervals in a way it was not for the bound: `createTimers` builds the
  clearance timer *first*, so a check made inside the builders would install a
  good clearance timer and only then refuse the bad deletion interval beside it,
  stranding a live periodic timer that no caller holds a reference to. A test
  drives exactly that construction. No call site in the workspace passed a
  non-positive value, so nothing downstream changes.

- **The endpoint pipeline serialized differently from the HTTP client, so a
  type could round-trip on one side and fail on the other (tcinc1118).** The
  pipeline ran its own five-way chain on the way out — `String`, `TomClass`,
  `TomJsonSerializable`, `Map<String, Object>`, `List` with a bespoke
  per-element encoder, then reflection — while the kernel's `TomServerEndpoint`
  called `convertToJsonString`. Two transports restating one policy is two
  policies, and they had already diverged: a DTO carrying a plain `toJson()`
  was honoured by the pipeline and not by the client, and the pipeline's `Map`
  arm was wrong twice over — it named `Map<String, Object>`, which the
  `Map<String, dynamic>` a handler actually returns is not, so such a result
  fell through to a converter that then refused it; and had it matched, its
  bare `jsonEncode` would have thrown `JsonUnsupportedObjectError` on any DTO
  value inside. The chain is not shortened but **removed**: with
  `convertToJsonString` now taking the JSON containers (see the kernel's
  tcinc1118), every result but a `String` goes through the one outbound entry
  point, and `_encodeResultElement` is gone. The `String` passthrough stays
  because it is not serialization — a handler returning one has already written
  the body, and encoding it again would wrap it in quotes. Inbound was already
  the shared entry point on both sides. A new round-trip suite
  (`endpoints_serialization_roundtrip_test.dart`) drives one DTO per hook shape
  through a live loopback server using the shipped client, which exercises all
  four legs — client encode, server decode, server encode, client decode — in a
  single call; each DTO renames its field on the wire, so a hook skipped on any
  one leg loses the value rather than merely spelling it differently. It also
  asserts the claim directly: for the same object, the string the client
  produces and the string the server produces are identical.

- **A `.env` file could not reach a `${VAR:default}` placeholder, so three
  documents describing `core_server_sample` were describing something that did
  not happen (tcinc1078).** `TomYaml.loadYamlFile` expanded placeholders from
  `Platform.environment`, and Dart's process environment is read-only — so no
  amount of reading a `.env` put its values where the expansion looked. Nothing
  errored; the values were simply absent and every placeholder fell back to its
  `:default`. The failure that surfaces from that is the confusing kind: the
  sample's `.env` also drives its `docker-compose.yaml`, which *does* read it
  natively, so editing `TODO_DB_PORT` moved the database while the server kept
  dialling `3306`. The configuration keys behaved correctly throughout
  (`TomBaseServerConfiguration` merges a `.env` itself), which is what made the
  gap hard to see: the running server *reported* the `.env` values it was not
  connecting with. The same silence covered the `env` overlay selector — a
  `.env` saying `env=dev` selected the prod overlay.

  `TomYaml.loadYamlFile` and `mergeInYamlFile` now take an optional
  `environment` map, which **replaces** `Platform.environment` for the
  substitution rather than layering over it, so a caller states exactly what a
  file may see. `TomEnvFile.resolveEnvironment({path, processEnvironment})`
  builds the usual map: the process environment with the `.env` layered on top,
  stringified because an expansion is substituted as text. A key whose `.env`
  value is empty is dropped rather than contributed as `''`, so it leaves any
  process value standing instead of blanking it.

  The `.env` winning over the OS environment is deliberate and matches
  `getDefaultValues`, which already layered it that way for config keys — a boot
  reads both, and the two disagreeing about the same file would be worse than
  either rule. It is the **opposite** of Docker Compose, where the shell wins;
  that divergence is now stated in `doc/cmdline.md`, `doc/configuration.md` and
  the sample's `.env.example`, since the two commonly read one file.

  Proving this needed a non-default `.env`: every value in the sample's
  `.env.example` equals its own placeholder default, so a server ignoring the
  file entirely reached the same database and passed. `tool/run_integration.sh`
  now writes its own with `TODO_DB_PORT=3307` and `env=dev`, publishes MariaDB
  on 3307 alone, and greps the boot log for the resolved environment — two
  independent guards, each failing by name. (It refuses to overwrite an existing
  `.env` and removes only one it wrote.) The boot's start-up line now names the
  resolved environment as well as the port, which is what that second guard
  reads and the first thing anyone asks when a server behaves like the wrong one.

- **The transactions example demonstrated five of the module's seven documented
  behaviours, and checked none of them under its own command (tcinc646).** Two
  capabilities had no step at all — `hasTransactionScope`, and opening a
  read-only transaction — so a reader who went to the example for either found
  nothing, and the completion document's snippets for them quoted a file they
  were not in. Both are now numbered steps 6 and 7, in the style the file
  already used.
  The file also stated every expectation as `assert`, which `dart run` compiles
  out — so under the one command its own header documents, the example printed
  a plausible transcript, exited 0, and evaluated nothing. It now uses the
  throwing `check(bool, String)` helper this package settled on for exactly
  this reason, which holds however the file is run — including the case that
  matters most for an example, a reader lifting a line into a server where an
  `assert` vanishes in release mode. That drops the last quarantine entry
  standing between `example/transactions/` and the package-wide rule.
  Converting turned two checks from weaker to stronger on the way: steps 2 and
  3 asserted that the recorded calls *contained* `commit` and `rollback`, which
  a participant ended out of order or not at all would still satisfy. They now
  pin the whole sequence — `start,commit,end` and `start,commit,rollback,end` —
  which is the property the surrounding prose actually claims.

- **One participant reporting a failed `endTransaction()` stopped every
  participant behind it from being ended at all (tcinc645).** Both
  `commitTransaction()` and `rollbackTransaction()` concluded with
  `ok = ok && await p.endTransaction();`. Dart's `&&` short-circuits, so the
  first `false` made the right operand dead for the rest of the loop: the
  remaining participants were committed or rolled back and then abandoned
  mid-lifecycle. `endTransaction()` is the call documented as releasing
  per-transaction resources, and for the module's only production participant —
  a data source — that means returning its connection to the pool. Nothing
  comes back later to release it; the transaction is over. So the cost of one
  participant failing was a leaked connection for each participant registered
  after it, on the rollback path most of all, which is the path a failure
  arrives on.
  Both loops now evaluate the call before combining its result
  (`final ended = await p.endTransaction(); ok = ok && ended;`), so every
  participant is ended regardless of what an earlier one returned and the
  boolean stays the conjunction of all of them. The code was contradicting its
  own contract rather than the contract being wrong: the source dartdoc, the
  prose guide, the API summary and the completion document all already said
  "every participant", and `MariaDbDatasource.endTransaction()`'s own dartdoc
  argues from the same premise — "the coordinator ands every participant's
  result into the outcome". The documents did not move; the code moved to meet
  them. Throw-safety was deliberately *not* added alongside: both production
  `endTransaction()` implementations catch internally and return `false`, so a
  guard there would be handling a case that cannot arise.

- **`TomTextLocale` accepted `XX` as a country, so every user who signed in
  from a device naming no region got the unreachable bundle key `en_XX`
  (tcinc629).** The country invariant checked *shape* — two letters — which
  admits exactly the codes ISO 3166-1 permanently withholds from assignment so
  that applications can use them to mean "none": `AA`, `QM`-`QZ`, `XA`-`XZ`,
  `ZZ`. This stack uses `XX`, and not occasionally: `TomLoginMessage`
  **defaults** `clientCountry` to it, so clients send it verbatim and it reaches
  `TomPrincipal.clientCountry` through an ordinary sign-in. `fromPrincipal`,
  which reads that field, was therefore building `en_XX` on the commonest path
  of all — a key no bundle carries, which the chain then resolved through bare
  `en` while reporting nothing. The text came out right, which is why this could
  sit unnoticed: a deployment could not learn that its regional bundles were
  unreachable. `_isCountry` now rejects the user-assigned range, so the strict
  constructor throws and `lenient` — the path `fromPrincipal` uses — drops the
  sentinel and lands on the bundle that exists.

  This also closes the composition the kernel's accessors invite. Reaching for
  the context providers a caller already knows and writing
  `TomTextLocale(getLanguage(), getCountry())` yields `en_XX` for a principal
  that names nothing, because the kernel substitutes sentinels where
  `fromPrincipal` deliberately answers `null`. That now fails loudly instead of
  resolving quietly through the default locale.

- **`TomLocalizedTextResources.substitute` rendered a null parameter value as
  the literal word `null`, so a subject line read "Hi null!" (tcinc626).** Every
  parameter was interpolated with `'${entry.value}'`, and `parameters` is
  `Map<String, Object?>` — so a null is admitted by the signature, and the
  documented way to call it hands one over: `TomEmailRequest`'s own example
  passes `principal.user.firstname`, which is `String?` on `TomUser`. A caller
  writing the obvious thing got `Reset your password, null`.

  What makes that the wrong output rather than merely an ugly one is the
  module's stated reasoning. An unmatched placeholder is deliberately left as
  written because "a visible `{firstname}` in a proof-read mail is caught by the
  person proof-reading it, which an empty gap is not" — an argument that turns
  entirely on the result being conspicuous. `Hi null!` reads as finished text, so
  it was the one outcome that reasoning was there to rule out.

  A null value is now skipped, which makes it behave exactly like a parameter
  that was never passed: the placeholder stays visible and lands in the case the
  documentation already reasons about. Of the three defensible answers — empty
  string, leave the placeholder, reject the value — this is the one consistent
  with the existing prose, and it means a caller needs no `?? ''` at the call
  site to stay safe.

- **`TomTextLocale.parse` read a BCP 47 script subtag as a country, so
  `zh-Hans-CN` became the bundle key `zh_HANS` (tcinc625).** The parse took the
  second segment as the country unconditionally, but BCP 47 only puts the region
  second for the languages that have one script; where there are several, the
  script comes first and the region is third. `HANS` is not a country, so the key
  named a locale that does not exist and no deployment's `zh_CN` bundle could
  ever match it. Worse, the failure was silent: the chain still reached the bare
  `zh` bundle, so a deployment saw Chinese text and never learnt that its
  regional bundle was unreachable — the exact class of miss the type exists to
  prevent.

  `parse` now finds the region by **shape rather than position**: the first
  subtag that could be an ISO 3166-1 alpha-2 code, skipping scripts, extlangs and
  variants, and stopping at a singleton because a one-character subtag opens an
  extension sequence whose contents are not subtags of the language. So
  `zh-Hans-CN` is `zh_CN`, `zh-Hans` is `zh`, `sr-Latn-RS` is `sr_RS` and
  `en-US-x-private` is `en_US`. A subtag that cannot be alpha-2 — `es-419`'s UN
  M.49 number among them — leaves a bare language rather than becoming a country
  it is not; accepting numeric regions would widen the documented `country`
  invariant rather than enforce it, which is a separate decision.

  The invariant is now enforced rather than described. `country` was documented
  as "ISO 3166-1 alpha-2" in the dartdoc and the API summary while the
  constructor validated nothing, which is how a four-letter value came to sit
  there; it raises `resources.locale.invalid_country` instead. Because that
  strictness must not be reachable from client data — `TomPrincipal.country` and
  `Tom2FAContext.country` are free-form strings filled from a request, and a
  client sending `XYZ` would otherwise throw inside message delivery — a new
  `TomTextLocale.lenient` factory **drops** an unusable country, and both
  `fromPrincipal` and `Tom2FADeliveredCode.localeFor` read through it. Degrading
  to the bare language reaches a bundle that exists; the refused key never could.

- **`TomUserPreferences.all()` promised an order its query did not ask for
  (tcinc613).** The sentence was `FIND BY principal_id = :principalId` with no
  `order by`, while the method's dartdoc, `api_summary_preferences.md` and the
  completion document all described the answer as being "in storage order" —
  which is not an order SQL offers. What a caller actually got was whatever the
  engine found convenient, and that changes as the table is rewritten, as rows
  are deleted and reinserted, or as the planner picks a different index. The
  round-trip test had already worked around the gap, asserting `containsAll` and
  `unorderedEquals` where it meant to assert a list.

  The query now carries `ORDER BY preference_key` and the four documents name
  that order instead. The key is the ordering column because it is the one
  column unique per caller that never changes while the preference exists, so
  rewriting a value does not move it in the list — and because
  `uq_tom_user_preference (principal_id, preference_key)` already covers
  `WHERE principal_id = ? ORDER BY preference_key`, the guarantee costs no sort.
  Two DB-backed tests pin it: one writes four keys in an order that is neither
  alphabetical nor its reverse and asserts the listed sequence exactly, the
  other rewrites a value and asserts the sequence is unchanged. The round-trip
  test's unordered matchers were replaced with the list both clients now see.

- **The framework error envelope was hand-built in two places, and the two had
  already drifted (tcinc612).** `TomServer.errorHandler` and
  `TomUserPreferencesErrorHandler` each assembled the wire error body from
  scratch, the second documented as following the first. The preferences `404`
  reported no `clientThrow` — yet every error it translates under that key is a
  `TomEndpointHandlerException` and therefore a `TomServerException`, so the
  flag was always part of what the framework reported and never part of the
  `404`. A wire shape with two authors has no shape.

  There is now one definition, `tomErrorEnvelope(error)` in `little_things`, and
  both handlers render it. A handler that translates a status now chooses the
  *status* and nothing else.

  It lives in `little_things` because `TomServerException` — declared there —
  decides the envelope's one conditional field, and because that is the module
  every other one already depends on, so both handlers reach the builder without
  either reaching the other.

  The asymmetry the extraction exposed is kept rather than smoothed over: the
  preferences `400` arrives from the kernel as a plain `TomException` and so
  still carries no `clientThrow`. A field is absent rather than null when the
  error does not carry it, which is what lets a client tell a failure raised
  inside this package from one relayed out of the kernel. Both directions are
  now pinned — the `404` asserts the flag is read from the error rather than
  assumed, and the `400` asserts its absence — alongside a full-body comparison
  of the translated `404` against what `TomServer.errorHandler` produces for the
  same error, which is the assertion that notices when the two stop agreeing.

- **Both JSON error envelopes went out with no `content-type` at all
  (tcinc611).** The preferences miss (`TomUserPreferencesErrorHandler`, a `404`
  or a `400`) and the framework's own `TomServer.errorHandler` (a `500`) each
  set exactly one header, `x-tom-error: true`, and shelf adds no default media
  type — so the body a client is told to decode arrived undeclared. Both now
  send `application/json;charset=UTF-8`, written the way
  `file_endpoint.dart` already writes it:
  `{TomHeader.contentType: TomMimeType.json.toHeaderValue()}`.

  The whole design argument for the preferences `404` is that a client branches
  on the body's `errorKey` rather than on the status alone. A client stack that
  decides whether to parse by media type had nothing to decide on, and an
  intermediary was free to sniff the body as anything it liked. The framework
  envelope is fixed with it because it is the shape the preferences handler is
  documented as following — leaving the reference wrong would have made the two
  disagree in the one respect this changed.

  The opaque fallback keeps `text/plain`: it carries no envelope, so declaring
  JSON there would promise a body that is not one. That is now pinned too, so
  the two are not quietly unified later.

- **`autoScopeFor` decided the grant-table exclusion per column, so which
  answer it gave depended on column order (tcinc608).** The guard that keeps the
  framework's own authorization tables out of automatic scoping was evaluated
  inside the loop over the entity's columns, before each column's resource-key
  test. It is a fact about the entity — every column the analyzer resolves
  carries the one `@TomDbTable` of its type — so for a real entity the position
  made no difference, and the code read as though it might.

  Where it *would* have differed is the case that matters: a list holding
  another table's resource key ahead of a grant table's column returned a scope,
  because the loop reached the key first and never got to the guard. Auto-scoping
  one of those three tables closes the authorization layer against itself — a
  principal reaches its own grant rows only by already holding a grant on them,
  which no row can satisfy — so the guard cannot be one whose reach depends on
  where in a list a column sits.

  The exclusion is now settled for the whole column list before any column is
  examined: a list naming one of the three tables anywhere synthesises nothing.
  The loop body tests only the resource key, which is the thing that varies per
  column.

- **A schema-convergence guard tested a nullable table for the wrong thing, then
  null-asserted it (tcinc607).** `TomSchemaConvergence.verify` skipped entities
  with `if (TomAnnotationAnalyzer.findTable(type)?.schema != null) continue;` and
  read the same lookup back as `findTable(type)!` on the next line. The guard
  reads as though it established a table, but `?.schema != null` is equally false
  for a *missing* table and for an unschemed one — so a type that maps to no
  table falls through the `continue` and reaches the assertion. The lookup is now
  made once and tested for what the branch actually needs
  (`if (table == null || table.schema != null) continue;`).

  Not reachable today: `verify` selects through `selectFor`, whose `_belongsTo`
  filter drops types with no table. But that invariant lives some 440 lines from
  the assertion that depends on it, which is precisely why it was written as a
  guard in the first place.

  Four further sites asserted the same nullable lookups rather than reading the
  value they already had, or re-reading it through the non-nullable route.
  `TomSqlDatasourceRepository.save` re-derived `getPersistentColumns(T)!` for
  columns its constructor had already resolved; `TomDelete.generateQuery`
  re-looked-up the table it holds in `persistenceInfo`; and
  `MariadbDatasource._processResult` did both halves of the anti-pattern — one
  branch asserted after a sibling branch had established the table, the other
  tested `getPersistentColumns(rType) != null` and then re-read it with `!`
  seventeen lines later. Each now uses the value in hand, or
  `analysePersistentType`, which cannot answer `null` and names the type it
  could not resolve.

- **`delete(entity)` cast the primary key with `as K`, so deleting an unsaved
  entity threw a raw `TypeError` — or silently deleted nothing (tcinc595).**
  `TomSqlDatasourceRepository.delete` read the entity's key with a bare
  `as K` cast. `save` reads the same value through `readPrimaryKey<K>`, which is
  null-tolerant precisely because an entity that has never been persisted
  carries a null or negative key, and `isUnsavedKey` is the check that gates
  INSERT against UPDATE on exactly those two conventions.

  The two conventions failed differently in `delete`, and neither failed
  usefully. A nullable surrogate key still `null` failed the cast with
  `type 'Null' is not a subtype of type 'int' in type cast` — a `TypeError`,
  which is outside the server exception family, so it carries no key to match
  on, is not auto-logged, and reaches the endpoints pipeline unclassified. It
  names `Null` and `int`, two types the caller never wrote, and does not say
  that the entity was never saved. A negative sentinel key was worse: it passed
  the cast, ran a `DELETE` that matched no row, wrote an audit record for the
  deletion, and returned normally — reporting success for a deletion that never
  happened.

  `delete` now reads the key through `readPrimaryKey<K>` like `save` does, and
  refuses a key `isUnsavedKey` accepts with a keyed
  `crud_repository.delete.unsaved_entity`. It is the one `TomRepositoryException`
  raised for something the caller did rather than something the deployment did,
  so it sets `clientThrow: true` against the type's `false` default: its message
  describes the caller's own argument and names nothing about the server, and
  masking it would leave a caller facing a generic internal error for the one
  repository failure it is the only party able to fix. The three further raw
  reads of the key inside the method — the file-cascade `_selectById`, the bind
  parameter and the audit key — now use the one guarded value, so the method
  reads the key once rather than four times.

- **The repository's delete methods returned a hardcoded count and contradicted
  their own contract (tcinc594).** `TomRepository` declared `deleteById`,
  `deleteByQuerySentence` and `deleteByQuery` as `Future<void>`, while
  `TomSqlDatasourceRepository` implemented all three as `Future<int>` — a return
  value no caller holding the interface could reach. The numbers were literals:
  `deleteById` answered `1` whether or not a row had been there, and both query
  deletes answered `0` however many rows they removed. A caller reading them was
  reading a constant.

  The four deletes that address an *unknown* number of rows — `deleteById`,
  `deleteAllById`, `deleteByQuerySentence`, `deleteByQuery` — now declare and
  return `Future<int>`, carrying the count the database reported.
  `deleteAllById` is included although it was never `Future<int>` in the
  implementation either: it deletes an arbitrary number of rows and reported
  nothing at all, and leaving it `void` beside three siblings that count would
  restore the inconsistency this removes. `delete(entity)` stays `Future<void>`:
  it addresses one row the caller already holds.

  The count had no route out of the driver. `TomPreparedStatement` declared no
  row-count member — only `MariaDbDatasource.executeCommand`, a different and
  non-prepared path, ever read `IResultSet.affectedRows` — so the contract gains
  `lastAffectedRows`. It is abstract and non-nullable, unlike `lastGeneratedId`,
  because a driver that ran a write knows how many rows it touched and a default
  would let silence read as a real count. `MariadbPreparedStatement` captures it
  alongside the generated key in one place, so the reconnect-and-retry branch of
  `execute` cannot pick up one and drop the other. The repository reads it while
  the statement is still allocated — for the query deletes through a new
  `_runPreparedAffecting`, the write counterpart of `_runPrepared`, which
  returns rows and so cannot answer "how many did that touch".

  Because the scope predicate is ANDed in before the statement runs, the number
  is the *scoped* count: a delete never reports rows the principal may not see,
  and `deleteAllById` can legitimately answer lower than the number of ids it
  was given.

- **The CRUD repository threw ten errors a caller could not identify
  (tcinc593).** Seven were bare `throw Exception(...)`: the constructor's
  datasource lookup, `findById`'s duplicate-primary-key guard, the read-back
  guards in both halves of `save`, and the "a `COUNT(*)` returned other than one
  row" guard, which appeared three times verbatim. A bare `Exception` carries no
  key, so no handler can match it, no catalogue can localise it, it falls
  outside the family the framework auto-logs, and the endpoints pipeline — which
  classifies by type — sees an unclassified error. They were the only failures
  in the module that reached a caller with nothing to match on, and the module's
  API summary stated as a fact that all of its exceptions extend
  `TomServerException`.

  All seven now raise the new `TomRepositoryException` under
  `crud_repository.<method>.<condition>` keys. It defaults `clientThrow` to
  `false`: every one of its causes is a server fault — a broken deployment, a
  table contradicting its own key, a driver that reported a write it then could
  not read — and every message names internals, so the key travels and the
  message does not. The triplicated count guard became one `_singleCount`
  helper that takes its key as a literal argument, so each method's key stays
  greppable at its own call site.

  The other three had the same shape without being `throw` statements:
  `findByQuerySentence`, `deleteByQuerySentence` and `countByQuerySentence` each
  cast the compiled sentence to the kind they need (`as TomSelect` /
  `as TomDelete` / `as TomCount`). The sentence is caller-supplied and its
  *verb* decides what the compiler produces, so `countByQuerySentence('find by
  …')` surfaced a raw `TypeError` — "type 'TomSelect' is not a subtype of type
  'TomCount' in type cast" — naming two internal classes the caller never wrote
  and not saying which of its own words was wrong. They now go through a checked
  `_compileSentenceAs<Q>` that raises `TomQuerySyntaxException` under
  `crud_repository.<method>.sentence_verb_mismatch` and names the verb the
  method expects. `TomQuerySyntaxException` rather than a repository error
  because this one *is* the caller's to correct. The two `as TomDelete` casts on
  internally-built literal sentences are left alone — those operands are the
  repository's own.

  All ten are covered connection-free: the repository is driven against a
  scripted `TomDataSource` registered through a `TomDataSourceInfo` whose
  `datasource` getter is overridden. A database would contribute nothing but the
  ability to produce the answers, and two of them (two rows for one primary key;
  a `COUNT(*)` returning no row) are states a correct server will not produce on
  request. Three further guards scan the source itself: no `throw Exception(`
  remains, every `crud_repository.*` key has exactly three dotted segments, and
  every raise site in the file names a `Tom*Exception`.

- **A boolean comparison read past its own operand, and past its own closing
  bracket (tcinc592).** The six comparison builders share one dispatch, but the
  dispatch took a flag: `=` and `<>` parsed a *boolean* right-hand side with
  `_buildQuery`, the statement-level entry point, while the four ordering
  comparisons used `_buildExpression`, the operand-level one. `_buildQuery`
  reads `and`, `or` and `)` as its own, so a boolean operand did not stop at the
  comparison.

  Two consequences, and the second is the dangerous one:

  - `find by done = TRUE and priority > 3` was **refused**. The conjunction was
    pulled into the operand, `priority` was then read as a second boolean
    column, and the failure named a cast rather than the sentence. The same
    sentence with the boolean predicate *last* worked, which is why every suite
    missed it — every boolean predicate they contained happened to be final.
    Binding made no difference: `done = :flag and …` failed identically,
    although binding is the style the documentation recommends.
  - `find by not ( done = TRUE ) and priority > 3` was **mis-compiled** to
    `NOT ( done = true AND priority > 3 )`. The closing bracket was consumed by
    the `=`, so the group closed one conjunct too late and the negation covered
    both. `NOT (A AND B)` is not `NOT (A) AND B` — that sentence returned rows
    it excluded, with no error anywhere.

  The comment on the flag justified it by `done = ( a > 1 or b > 2 )`, a
  comparison against a whole bracketed predicate. That form has never compiled:
  `_buildQuery` threads the boolean column into the bracket, so the first column
  inside is read as a second operand of *that* column's type and refused. There
  was nothing to preserve, and the flag is gone — all six builders now parse a
  boolean operand exactly as they parse the other five types, and the `TomDbBool`
  arm of the switch is one line like its neighbours.

  A bracket standing where an operand is expected is now refused as
  `query_sentence_compiler.build_expression.separator_in_operand_position`. It
  previously reached the column resolver as a field name and was answered by the
  *annotation analyzer* — outside the exception family this compiler documents —
  naming a column the author never wrote. That was already true for every other
  column type (`find by id = ( 2 )`), so this closes the case for all six rather
  than only for the boolean one it would otherwise have moved there.

- **The query-sentence tokeniser tore quoted string literals apart
  (tcinc591).** `_splitQuerySentence` inserted spaces around every `,()=<>`,
  collapsed runs of whitespace and split the result — with no notion of a
  quoted region. A literal was therefore only writable if it happened to
  contain none of those characters and no space:
  `find by title = 'in progress, phase (2)'` became eight tokens, the first of
  them `'in`, and the failure that came back named a column `['in]` — a
  fragment the author never wrote, raised by the annotation analyzer as
  `TomAnnotationAnalyzerSyntaxException` rather than as a query-syntax error.

  The quieter half of the same defect was the escape. `'O''Brien'` had no space
  to split on and so *did* compile, but the sentence-level doubling was never
  decoded: the parser passed both characters through and the dialect escaped
  them a second time, so the value reached SQL as `'O''''Brien'` — an
  apostrophe richer than what was written. A mis-compilation rather than a
  rejection, and the reason this is a `### Fixed` entry rather than a
  limitation lifted.

  The tokeniser is now a character scan that returns a quoted region as one
  token, quotes still attached, whatever it contains — spaces, commas,
  brackets, comparison signs, or a word that would otherwise read as the `by`,
  `order` or `and` keyword. An apostrophe inside a literal is written the SQL
  way, by doubling it; the parser decodes `''` back to `'` and leaves the
  re-escaping to the dialect, which is the layer that owns it. An unterminated
  literal is now refused during tokenising, as
  `query_sentence_compiler.split_query_sentence.unterminated_string_literal`,
  while the position of the opening quote is still known.

  Two-character operator pairing is restricted to exactly `<=`, `<>` and `>=`
  — the vocabulary `_buildExpression` actually recognises. The regex it
  replaced matched `[,()=<>][=>]?`, which would also have made `(=` and `,>` a
  single token apiece.

- **An `IS IN` list silently dropped the predicate that followed it
  (tcinc589).** `_createIsIn` reported one token more than it consumed. The
  index contract in this parser is *the last token I consumed* — the `IS NULL`
  branch returns the index of `null`, and the caller resumes with `i = index`
  and then increments — but the `IN` builder added one to the closing bracket.
  Whatever stood after the list was therefore skipped, and when that was `and`
  the conjunction was never seen at all:
  `find by id is in ( 1 , 2 ) and done = TRUE` compiled to
  `WHERE done = true`, with the `IN` filter gone. The statement stayed
  *plausible*, so nothing downstream could notice; a query simply returned rows
  its sentence excluded. Sentences with the list on the right of the `AND`, or
  parenthesised, were unaffected — the overshoot ran into the end of the
  sentence or into a bracket that absorbed it, which is why the defect survived
  the existing tests.

  Two more failures at the same boundary, both found while confirming the
  first:

  - The scan for the closing bracket had no upper bound, so an unclosed list
    (`find by id is in ( 1 , 2`) walked past the end of the token list and threw
    a raw `RangeError` — outside the `TomQuerySyntaxException` family this
    module documents as covering every rejection, and reaching the caller as an
    internal error rather than a bad-request one, which matters because a
    sentence can arrive in a request parameter. It now raises
    `get_in_options.unterminated_list`.
  - An empty list was accepted and rendered as `IN ()`, which no SQL dialect
    parses. The rejection happened at the database instead, one layer too late
    and phrased as a complaint about SQL the author never wrote. It now raises
    `get_in_options.empty_list`.

  The new tests assert the *whole* rendered predicate rather than a
  containment, since a dropped conjunct is invisible to a `contains` check on
  the half that survived.

- **A window option the compiler could not read was guessed at as `1`
  (tcinc588).** `_countOption` wrapped `int.parse` in a bare `catch` that
  returned `1`, and its own dartdoc defended the fallback as "the behaviour
  `top`/`first` has always had". Four different mistakes therefore produced a
  silently different result set instead of an error, which is the one failure
  mode a query language cannot afford:

  - `find first x by …` — a mistyped count capped at one row (the reported
    symptom);
  - `find first by …` — the keyword with *no* argument capped at one row too,
    because `options[index + 1]` threw `RangeError` inside the same `try`;
  - `find first 5 skip x by …` — `skip`/`offset` shared the fallback, so a
    mistyped page position silently skipped exactly one row. The dartdoc's
    excuse did not even cover these two keywords;
  - `find first -5 by …` — a negative argument parsed cleanly, then failed the
    `> 0` test gating the clause, so the cap vanished and every row came back.

  All four keywords now take exactly one whole, non-negative number. Missing,
  non-numeric and negative arguments each raise `TomQuerySyntaxException` under
  a key naming the keyword the author actually wrote — `compile.first_not_numeric`,
  `compile.skip_missing_argument`, `compile.offset_negative` — since `top` and
  `first` are one option internally and quoting the other one sends the reader
  looking for a word their sentence does not contain.

  `0` is accepted and means *unpaged*. That is not a new rule but the existing
  one: `TomPageRequest.assertWindow` rejects only negative bounds and
  `isUnpaged` reads `limit <= 0`, so a sentence and a programmatic window now
  agree about what a zero means. A test asserts the agreement from both sides
  rather than restating it. Refusing a negative also protects the compiler's
  own `-1` "option absent" sentinel, which an accepted `first -1` would have
  been indistinguishable from.

- **A query sentence that stopped on a keyword escaped as `RangeError` or
  `TypeError` instead of a syntax error (tcinc587).** `_lookAhead` bounded its
  read with `<` where the token it is asked about sits at `start + ahead`, so a
  list of exactly that length does not contain it. Every sentence ending on a
  keyword that looks ahead — `find by title not`, `find by not`,
  `find by title is` — therefore read one past the end and threw `RangeError`
  out of the compiler: outside the `TomServerException` family every caller of
  this library catches on, and carrying no indication of which sentence was at
  fault. The bound is now `<=`.

  Fixing the bound exposed the second half of the same defect. A sentence
  ending after `not` or `not like` leaves `_buildExpression` with nothing
  built, and the tail then cast a null operand (`not(null as
  TomOperator<TomDbBool>)`) or dereferenced it (`currentOperation!`) —
  `TypeError`, the same user-visible failure by another route. Both sites are
  replaced by an explicit
  `…build_expression.sentence_ended_early` exception that says whether the
  sentence stopped after a `NOT` or simply short.

  The duplicated conjunct that prompted the investigation is **deleted, not
  repointed.** The standalone-`NOT` branch tested `!_lookAhead(…, "NULL")`
  twice; the report read the second one as a `LIKE` test that had been
  miscopied, and concluded that `not like` inside an expression was being
  routed into the general negation path. It is not — compiling
  `title not like :p` at the top level, inside parentheses, after `AND`, and
  parenthesised after `AND` all render `NOT LIKE`. The reason is structural:
  `_buildExpression`'s `NOT LIKE` branch sits *above* the general `NOT` in the
  same `else if` chain, so reaching the general branch already proves `LIKE`
  did not follow. The parallel branch in `_buildQuery` needs its `LIKE`
  conjunct because that parser has no `NOT LIKE` branch of its own and must let
  the phrase fall through to this one. Adding the test the report asked for
  would have made a dead guard look load-bearing; the asymmetry between the two
  parsers is now stated at the branch instead.

- **An unanchored integer test made every other literal — and every
  digit-bearing identifier — unwritable in a query sentence (tcinc586).** The
  scanner in `_buildExpression` recognised an integer with `RegExp(r"[0-9]+")`,
  which matches a token that merely *contains* a digit, and tried it before the
  double, date and datetime rules. So each of those tokens was claimed as an
  integer and then rejected for not being one: `find by amount > 1.5`,
  `find by tag_day = 2026-07-05` and `find by created_at >= 2026-07-05T10:00:00Z`
  all failed with `…build_expression.int_literal_invalid_type_expected`. Only
  the integer could be written inline; the double, date and datetime branches
  below it were unreachable, and the ordering hid it — the datetime rule sat
  last although a datetime literal contains a date, which contains digits.

  The reach was wider than the literals. An identifier is resolved only *after*
  every literal rule declines the token, so any name carrying a digit —
  `line1`, or a `having` alias called `total1` — was read as an integer literal
  and never reached column resolution. That symptom was not in the report and
  is the most user-visible of the four.

  The four hand-written branches are replaced by one table, `_scalarLiterals`,
  holding each kind's anchored pattern, SQL type, exception noun and node
  factory, tried most-specific-first (datetime, date, double, integer). Both
  properties are load-bearing and now stated where the table is defined:
  anchoring means a token matches a kind by *being* it rather than by
  containing it, and the ordering keeps a kind from being swallowed by the
  broader one that encloses it. The signed forms `-5` and `+5` — which worked
  before and would have been lost to a naive anchoring — are kept, and pinned
  by tests. The exception key now names the kind the token actually spells
  rather than whichever rule happened to claim it.

  The comma decimal form the old rule nominally accepted (`1,5`) is gone
  deliberately: `_splitQuerySentence` puts spaces around every `,` so an
  `IS IN ( a , b )` list separates, which tore `1,5` into three tokens before
  any literal rule saw it. It never worked, and a comma that could be either a
  decimal point or a list separator is ambiguous in exactly the place `IS IN`
  needs it not to be. Decimals are written with a point.

- **A `double` column could not be used in a query sentence at all
  (tcinc585).** `TomQuerySentenceCompiler` types a predicate through three
  independent switches — the column node, the bind parameter, and the
  comparison joining them — and `double` was in none of them. Any sentence
  naming a decimal column failed with
  `query_sentence_compiler.create_column.failed`, so an entity with a money or
  measurement field had no query-sentence access to it. The damage reached
  further than the predicate: `DoubleCol` and `_createAggregate`'s
  `case DoubleCol()` arm both existed and looked handled, but nothing in the
  compiler could construct a `DoubleCol`, so `min`/`max` over a decimal column
  was unreachable code that read as supported.

  The fix does not add nine more copies of the missing arm. The five-way type
  switch was written out nine times — once per comparison operator, once for
  `IS IN`, once each for `IS NULL` / `IS NOT NULL` — which is why a type could
  be handled by one and forgotten by the rest, and adding `double` nine times
  over would preserve exactly that. The six comparison builders now share one
  `_createComparison` dispatch parameterised by the node factory, `IS IN` uses
  one generic local, and the two null tests share `_createNullTest`; the
  `double` arm is added once in each of the three. The one asymmetry between
  the operators is preserved deliberately and named in the code: `=` and `<>`
  parse a boolean right-hand side through `_buildQuery` (so
  `done = ( a > 1 or b > 2 )` compares against a whole predicate) where the
  four ordering comparisons parse a plain expression. ~610 lines became ~250.

  `IS IN`'s failure message said `>=`, a copy-paste artefact; it now says
  `IS IN`. The exception key is unchanged.

  **Decimal literals are still refused** — `find by amount > 1.5` reads `1.5`
  as an integer literal, because the lexer's `[0-9]+` test is unanchored and
  precedes the decimal test. That is a separate defect in the literal scanner
  (tcinc586) and is documented as a current limitation in
  `doc/object_persistence.md`; binding the value works.

- **`TomMessageOutbox.tick()` documented a completed pass and delivered a
  started one (tcinc584).** It was a one-line forward to `TomScheduler.tick()`,
  and a scheduler pass *starts* the runs it claims — deliberately, so that one
  slow relay handshake cannot hold up the next window. So `await outbox.tick()`
  returned with the deliveries still pending as microtasks, and its own dartdoc
  ("completing when the pass has finished") was false. `messaging_example.dart`
  believed the dartdoc, asserted a delivered count of 1 and observed 0; the four
  messaging suites did not, and compensated with 23 `await pumpEventQueue()`
  calls — encoding the workaround so thoroughly that nothing was left to report
  the gap.

  Fixed where it belongs, in the kernel: `TomScheduler` gained `drain()`, which
  completes once every run in flight has finished and recorded its outcome, and
  `tick()` keeps its fire-and-forget semantics unchanged. The outbox now
  composes the two, so it gets both properties at once — the pass still returns
  promptly for the timer, and the *outbox's* tick means what it says. `sendNow`
  goes through it rather than calling `scheduler.tick()` directly, so the caller
  that reached for it over `send` gets a resolved first attempt rather than a
  started one. Every `pumpEventQueue()` the gap forced is gone; the one that
  remains, in the receipt-stream test, is annotated with the reason it is not
  the same thing — a broadcast stream notifies its listeners on a later
  microtask whatever the delivery did. Both examples now assert the count on the
  line after the tick instead of subscribing to `receipts` to find out, and
  `doc/messaging.md` states what "the pass has finished" covers and what it does
  not (a pass claims at most `maxRunsPerTick` messages, so a backlog still takes
  several).

- **A `close` that threw could un-deliver an accepted message, and a socket
  teardown discarded its errors into a comment (tcinc575).**
  `TomSocketSmtpConnection.close` swallowed failures in a `catch (_)` whose body
  was a comment, while thirty lines up `TomSmtpTransport._quietly` handled the
  same "an error after the work is done does not undo the work" case *and*
  logged it. One policy, two spellings, one of them silent — and a relay that
  consistently errors on `QUIT`, or a TLS socket that never shuts down cleanly,
  was invisible short of a packet capture.

  `_quietly` is now a top-level helper taking the stage that failed, so the
  policy has one implementation and its log lines say which teardown produced
  them (`QUIT after delivery`, `connection close`, `socket teardown`).

  Routing the socket close through it needed the helper promoted out of
  `TomSmtpTransport` — it was a private *instance* method there, and `close`
  belongs to the unrelated `TomSocketSmtpConnection` — and that promotion
  exposed a third site with the same policy and no protection at all:
  `TomSmtpTransport.send` hangs up in a `finally`, where an exception replaces
  whatever the body produced. Only the socket connection's internal swallow was
  keeping that safe, and `TomSmtpConnection` is a public injectable interface,
  so any other implementation whose `close` threw would have turned a message
  the relay accepted on the `250` into a reported failure — and the retry would
  have delivered a second copy. That call site is now best-effort too, which is
  what `doc/messaging.md` already claimed for it.

  `close` on the interface is documented as unable to signal a delivery
  problem, since the transport will not propagate it.

  Four tests. A scripted connection whose `close` throws pins that the receipt
  survives it; the exhausted-script case pins that the swallowed error is
  written down under its stage name (asserting the *logger's* phrasing, because
  the discarded error's own text ends in the command list and would satisfy a
  looser match on its own). Two more open a real loopback socket against a relay
  that greets and drops, because what the todo names is the teardown of a real
  socket: closing a dead one and closing twice both complete rather than throw.
  Neither forces the catch — `Socket.close` does not fail on either path, which
  is why the throwing case has to be scripted — so they stand as regression
  guards over the site rather than as coverage of its catch.

- **A delivery failure could call itself permanent and be retried forever
  (tcinc574).** `TomDeliveryException` stored `isPermanent` as a constructor
  parameter *and* signalled permanence by mixing in the kernel's
  `TomPermanentFailure`. Two representations of one fact, agreeing only because
  the `permanent` / `transient` builders happened to write both — and the public
  general constructor bypassed the builders. `TomDeliveryException('k', 'm',
  isPermanent: true)` produced an exception whose `toString` ended `(permanent)`
  while carrying no marker, and `TomScheduler._failAttempt` branches on
  `error is TomPermanentFailure`, so it would have retried that failure to the
  end of its budget. The inverse was equally reachable. Nothing in `lib/` used
  the general constructor, so the defect was latent rather than live — but it
  was reachable by any caller, and `messaging_example.dart` was *asserting* the
  invariant that the flag and the marker agree, which the type system did not
  provide.

  `isPermanent` is now a getter — `this is TomPermanentFailure` — so the
  description and the scheduler's decision are the same expression and cannot
  drift. With no flag left to pass, the classification is no longer a
  constructor argument at all; `TomDeliveryException` becomes abstract, and
  mixing in the marker is the only way to be permanent.

  That change also settles the asymmetry this todo was filed for. `permanent`
  returned `TomPermanentDeliveryException` while `transient` returned the base,
  because the base *was* the transient case — nothing about the design meant
  that, and it left `on ... catch` usable on only one half of a deliberately
  symmetric pair. An abstract base cannot be the transient case, so
  `TomTransientDeliveryException` now exists and `transient` returns it. The
  analyzer's verdict on the example is the neatest evidence the symmetry is
  real: `deferred is TomTransientDeliveryException` is now rejected as always
  true, because the builder's *static* type already says so.

  Retryability remains the absence of the marker, not membership of one class —
  a transport may subclass `TomDeliveryException` directly to carry vendor
  fields — so callers deciding whether to retry are told to ask `isPermanent`
  rather than test for `TomTransientDeliveryException`. Two tests declare
  exactly such subclasses, passing no classification anywhere, to pin that their
  answers come from the marker alone.

  The example loses its `isPermanent == (failure is TomPermanentFailure)`
  check, which the fix turns into a tautology; a check that cannot fail is the
  same dead weight this package's meta-tests exist to prevent. It now pins what
  a caller acts on: each builder yields the classification it names.

- **`TomMessage.textBody` missed a body spelled `Text/Plain`, and the SMS
  transport then sent the HTML one instead (tcinc573).** The two kind checks on
  `TomMessageBody` disagreed about case: `isHtml` lowercased its media type
  before comparing, while the plain-text check was a bare `== 'text/plain'`
  inlined in the `textBody` selector. IANA media types are case-insensitive by
  specification, so `Text/HTML` was found and `Text/Plain` was not. The
  convenience constructors `.text` and `.html` always write lower case, which is
  why the defect stayed invisible — it is only reachable through the general
  `TomMessageBody(mediaType, content)` constructor, i.e. exactly the callers who
  supply their own media type from a database column, a config file or an
  upstream API, none of which is obliged to normalise it.

  The consequence was worse than a getter returning `null`. `TomSmsTransport`
  picks `message.textBody ?? message.preferredBody`, and `bodies` is documented
  as least-preferred-first, so `preferredBody` is the *last* body — the HTML
  alternative in a text+html message. An unrecognised plain-text part therefore
  did not fail, it fell through to the markup: a subscriber to a text+html
  message whose text part was spelled `Text/Plain` received
  `<p>Your code is <b>123456</b>.</p>` as an SMS. Nothing threw and nothing
  logged, so the only way to observe it was to read the delivered message.

  Both predicates now route through one private `_mediaTypeIs(String)` helper,
  and `textBody` asks `isPlainText` rather than comparing inline. Two call sites
  do not normally justify an extraction; this one is justified by the defect
  itself — the two comparisons were written independently and drifted apart, and
  a predicate that shares its sibling's implementation cannot disagree with it.
  `isPlainText` is new public surface, added because the selector needed it and
  a caller inspecting a body had only the HTML half of the pair. Matching is
  case-insensitive; storage is not — `mediaType` keeps whatever spelling the
  caller gave, and that is what the MIME encoder puts on the wire, which is
  pinned by a test so a later "normalise on construction" cannot quietly rewrite
  a caller's header.

  Parameter-bearing media types (`text/plain; charset=utf-8`) are deliberately
  still not matched. The field is documented as the media type alone, `charset`
  is a separate field on the same class, and both convenience constructors
  populate them that way; accepting parameters here would invent a requirement
  no caller has asked for and blur where the charset lives.

- **The messaging example verified nothing under the command its own header
  documents; its sixteen expectations are now checked (tcinc571).** `dart run`
  leaves assertions disabled — that is what `--enable-asserts` is for — so
  every `assert` in the file was compiled out under the one command the header
  gave. The example printed a plausible transcript, exited 0, and evaluated
  none of its claims. That is how the false step-9 delivery count (tcinc570)
  survived: it was wrong, and nothing could notice.

  The header is *not* changed to `--enable-asserts`. This package had already
  settled the question the other way — `cache`, `cmdline`, `configuration`,
  `datasources` and `db_migration` state expectations through a throwing
  `check(bool, String)` helper, and `api_reference_coverage_test.dart` enforces
  the rule with a quarantine set that expires itself. A helper that throws
  holds however the file is run: under `dart run`, under `--enable-asserts`,
  compiled to a binary, and — the case that matters most for an example — when
  a reader lifts the line into a server, where an `assert` would silently
  vanish in release mode. Flagging the invocation would have fixed one command;
  this fixes the file.

  Each converted expectation gains the sentence an `assert` could not carry, so
  a failure now names what was supposed to be true rather than printing a line
  number. Step 7 additionally moves its check *out* of the `catch` block that
  contained it: a check that only runs inside a handler cannot fail when the
  handler never runs, so a router that quietly accepted an unrouted channel
  would have left the step green.

  `messaging_test.dart` gains the two guards the converted examples carry — one
  running the file under plain `dart run` and requiring exit 0 with all twelve
  numbered steps reported, one rejecting a reintroduced `assert(`. The step
  check is anchored to line starts rather than matched as a substring, which is
  where it differs from `cache_test.dart`'s otherwise identical guard: that
  example has nine steps, this one has twelve, and `1. ` occurs inside `11. `.
  `example/messaging/messaging_example.dart` is removed from the quarantine
  set, leaving fifteen examples for tcincb134_ahyc.

- **The messaging example's step 9 asserted a delivery that had not happened
  yet, and observed `0` where its narration claimed `1` (tcinc570).** The step
  sent a message through a `TomMessageOutbox`, called `await outbox.tick()`,
  and asserted `memory.count == 1`. Run with `dart run --enable-asserts` it
  failed at that line, having printed `delivered after a tick : 0` immediately
  above — the example's own output contradicting the claim beside it.

  The cause is not a bug in the outbox. `TomScheduler._dispatchDue` starts each
  claimed run with `unawaited(...)` on purpose, so that one slow transport
  cannot hold up the next window of a fast one; `tick()` therefore returns with
  the deliveries still pending. The example was reading the tick's future as a
  completion signal, which it is not and was never meant to be.

  The fix uses the API's own answer to "has it been delivered?" —
  `TomMessageOutbox.receipts` — rather than the `await pumpEventQueue()` the
  test suite uses, which is a `package:test` helper and has no place in an
  example a reader may copy into a server. The subscription is taken *before*
  the tick, because `receipts` is a broadcast stream and a listener attached
  afterwards would miss the receipt it is waiting for and wait forever; the
  added comment says so, since that ordering is the one part of the pattern
  that is not self-evident.

  Only the example changed. Whether `tick()` should instead be made to await
  its own pass is a live question tracked separately (tcinc584) and
  deliberately not pre-empted here.

- **`MariaDbDatasource` had lost both its annotations, so the `"mariadb"`
  driver was not discoverable (tcinc558).** `@tomReflector` and
  `@TomDatasourceDriver("mariadb")` were written above the class, but two
  private helpers — `_toBindValue` and `_toBindParams` — were later inserted
  *between* the annotations and `class MariaDbDatasource`. Dart binds an
  annotation to the declaration that follows it, so both attached to
  `_toBindValue`, a private function. The helpers are moved above the class's
  dartdoc; nothing else changed.

  The consequence was not confined to reflection. `TomDataSource`'s driver scan
  walks `tomReflector.annotatedClasses` and reads `@TomDatasourceDriver` off
  each one, so an unannotated class is absent from the registry entirely and
  `createDatasourceOf("mariadb")` throws `no_driver_found` — every server
  configured for the type failing at startup. `MariaDbXADatasource` was
  unaffected and would still have registered `"mariadb_xa"`, which is the
  shape of failure that is hardest to read: one driver of two missing, from a
  file whose source still visibly carries the annotation.

  Two things had to be true at once for this to stay hidden, and both were.
  The suite that exercises driver discovery is `@Tags(['db'])` and skips itself
  without a reachable MariaDB, so it is skipped on every default run. And the
  checked-in `.reflection.dart` artifacts predated the insertion, so they still
  carried the correct metadata — the generated code disagreed with the source
  it was generated from, and the tests believed the generated code. The defect
  surfaced only when an unrelated change caused the artifacts to be
  regenerated.

  The regression test is in `datasource_config_test.dart`, which needs no
  database: every `type:` name in a shipped configuration block is now resolved
  through `createDatasourceOf`, the same call server startup makes. It fails on
  the un-fixed source with the same `no_driver_found` a deployment would have
  seen.

- **`TomAwsV4Signer.canonicalQuery` signed only the last value of a repeated
  query parameter (tcinc548).** It read `uri.queryParameters`, a
  `Map<String, String>`, which keeps one value per name. SigV4 canonicalises
  every parameter sorted by name and then by value, so `?x=2&x=1` was signed
  over `x=1` alone while both were sent — the store answers
  `SignatureDoesNotMatch` and nothing in this module can explain why. Now reads
  `queryParametersAll`.

  Latent rather than live, and it stays fixed for a reason worth stating: no
  request `TomS3BlobStore` issues repeats a name — `_objectUri` takes a
  `Map<String, String>` and so structurally cannot build one. But
  `canonicalQuery` is a public static, and both its dartdoc and
  `doc/file_storage.md` present the signer as a SigV4 implementation rather than
  as a helper for the four requests this store happens to make. The caller who
  first repeats a parameter will be signing a request this module never sends.

  The rewrite has one trap, and the existing suite already guarded it:
  `queryParametersAll` yields `['']` — a one-element list — for `?uploads`, so
  the empty value survives the expansion. Had it yielded an empty list the
  parameter would have vanished from the canonical form, breaking every
  multipart upload, whose initiate call is `?uploads` and nothing else. Verified
  against the actual `Uri` behaviour rather than assumed; `['']` and `[]` print
  identically, which is how one would assume wrongly.

  Four assertions pin the rule — all values kept, sorted by value rather than
  left in written order, the empty value kept and sorting first, and encoding
  applied before the comparison. Four mutants, each naming the assertion that
  must catch it, and each required to leave the published-vector tests green:
  if changing the query canonicalisation breaks AWS's own documented
  signatures, the fix is wrong whatever the new assertions say.

  Two of those assertions turn out to be the only thing pinning their rule.
  Sorting by value is invisible to the first case, because for `?x=2&x=1` the
  sorted order and the arrival order coincide — hence the separate
  `?b=1&a=2&a=1`. And nothing in the suite covered encode-before-sort at all:
  every query value in the pre-existing tests is unreserved (`uploadId=7`,
  `partNumber=2`, `uploads=`) and neither AWS vector carries a query. That was
  established by the harness rejecting a wrong prediction about which test
  would catch the mutant, not by reading the tests.

- **Every S3 request failure reported the full bucket-and-prefix path in the
  parameter named `key` (tcinc547).** `TomS3BlobStore._send` built each failure
  with the request's `uri.path`, so a `storage.s3.request_failed` raised for
  caller key `a.txt` reported `/examplebucket/tenant-7/a.txt`. Two things were
  wrong with that. `key` is a contract rather than a label — every other error
  in this module and in `TomBlobStore` puts the caller's key there, so a handler
  logging or rendering `parameters['key']` printed a value the caller never
  supplied and could not look up. And in a multi-tenant deployment the prefix
  *is* the tenant while the bucket is infrastructure detail, both travelling
  inside an error a server may surface. The class already disagreed with itself:
  the two paths that build their own failure — `doGet` and the multipart
  completion — passed the caller's key, and one of them had a test asserting it.

  `_send` now takes `key` and `operation` alongside `method` and `uri`, and the
  failure reports the caller's key under `key` with the request path preserved
  under `objectPath`. The path is worth keeping: these errors carry
  `autoLog: true`, and which bucket and prefix refused a request is exactly what
  the operator reading that log needs. Naming it separately is what makes the
  difference — code rendering parameters wholesale now visibly opts into
  infrastructure detail instead of being handed it by a field called `key`.

  `operation` was the same defect in the same function and is fixed with it. It
  carried the HTTP verb, so a failed part upload and a failed single `PUT` both
  said `PUT` and a `describe` said `HEAD`, while the two hand-built failures said
  `get` and `complete`. One parameter, two vocabularies, and which one you got
  depended on the code path that raised. Every site now names the store
  operation: `put`, `get`, `describe`, `delete`, `uploadPart`,
  `createMultipartUpload`, `completeMultipartUpload`, `abortMultipartUpload`.

  Three tests pin it. The first drives `put`, `get`, `describe`, `exists` and
  `delete` against a store with a `keyPrefix` and compares the collected
  `parameters['key']` as one map rather than asserting per iteration — which
  methods leak was the whole diagnosis, and a per-iteration expectation stops at
  the first. That test is also why it covers the whole surface: `get` was
  already correct, so a test of a single method would have passed or failed
  depending on which one it picked. Four mutations, each naming the test that
  must catch it; the two that restore a half-fix — dropping `objectPath`, and
  reverting `operation` to the verb — are held apart by `must_not_catch`, so the
  three tests are provably three rather than one written thrice.

- **A blob's `storedAt` was a local `DateTime`, and the database backend wrote
  that local reading into a column everything else reads as UTC (tcinc545).**
  Two separate defects met in one field. `TomDatabaseBlobStore` rendered
  `stored_at` itself, through a private `_sqlDateTime` that formatted
  `DateTime.now()` to whole seconds and bound the result as text — so the column
  held the *writing host's wall clock*, while the read path appended `Z` and
  called it UTC. A server at UTC+2 wrote 14:00 local and read back 14:00 UTC,
  wrong by the offset; on a UTC host it was accidentally right, which is why
  nothing caught it. Independently, all four backends handed back a zoneless
  `DateTime` (`DateTime.now()` on three, the filesystem's `stat.modified` on the
  fourth), and since `DateTime.==` compares `isUtc` as well as the instant, a
  descriptor did not compare equal to itself across a round trip even on one
  host.

  `stored_at` is now bound as a `DateTime` and `_sqlDateTime` is gone: the
  MariaDB bind boundary renders every instant through `sqlInstant`, so the
  module uses the convention the rest of the server uses instead of a
  file-storage spelling of it. The zone is fixed one level up, in
  `TomStoredBlob`'s constructor, which normalises whatever it is given —
  making UTC a property of the *type*, so a backend added later cannot forget
  it, exactly as `TomAuditAnchor` and `TomOAuthTokens` already do it. That
  single change fixes all four backends at once.

  `TomStoredExport` got the same treatment, where the need was sharper: its
  directory and memory backends stamp `DateTime.now()` while `TomBlobExportStore`
  forwards the blob's stamp, so normalising blobs alone would have left the three
  backends of one interface disagreeing with each other about the zone.

  The manifest column widened from `DATETIME` to `DATETIME(6)`, in the
  descriptor and in the reference migration. This is not a precision
  preference: `sqlInstant` always emits six fractional digits and MariaDB does
  not reject the excess on a narrower column, it silently *rounds* it — so a
  plain `DATETIME` stored a different moment, up to half a second away, and made
  the value `put` returned unequal to the one `describe` read back. The
  file-storage schema test previously asserted the opposite on the grounds that
  a blob's write time is metadata for a human rather than an ordering the code
  depends on. That reasoning was about whether the precision is *useful* and
  asked the wrong question; the column does not get to choose its width
  independently of what is written into it. **The test's premise was rewritten
  deliberately, not loosened.**

  Seven connection-free tests pin the contract across all four blob backends
  and all three export backends, and a db-tagged test writes a blob, reads its
  descriptor back and asserts both halves: `isUtc`, and equality with the value
  written. Both halves are needed — `isUtc` alone would pass for a store that
  mislabelled a local reading as UTC, which is precisely the old defect, while
  equality reaches into the column because the two sides are derived
  independently (one from the descriptor's own normalisation, one from the text
  MariaDB holds) and so disagree by exactly the host's offset if local time ever
  reaches the column again.

  **That db-tagged test then failed, and found something bigger.** Binding the
  `DateTime` was supposed to be enough, because `MariadbPreparedStatement`
  marshals every bound value through `_toBindValue` — which renders an instant
  with `sqlInstant`. But `executeQuery` and `executeCommand` do not go through
  the prepared-statement path: they handed their named-parameter map to the
  driver **untouched**. So for any hand-built statement, a bound `DateTime`
  reached the driver raw and was encoded as the writing node's wall clock, and a
  bound `bool` was serialised as the string `'true'`/`'false'` that MariaDB
  rejects for an integer column. The marshalling was documented as living at
  "the single data-source boundary" and in fact lived on one of the two paths
  through it.

  This also explains, retroactively, why the scheduling, audit and OAuth-state
  stores call `sqlInstant` at every seam by hand: they were not being explicit
  by preference, they were routing around this hole — which is why the pattern
  looked like a convention and behaved like a workaround, and why file storage
  omitting it was a live bug rather than a style difference. `_toBindValue` is
  now a library-level function applied by both paths, so the boundary is one
  boundary; the existing explicit calls are unaffected (a pre-rendered `String`
  passes through) and are now belt-and-braces rather than load-bearing.

- **A blob chunk size of zero was accepted, and turned the first upload into a
  loop that never ends (tcinc544).** `TomDatabaseBlobStore` validated nothing
  about `chunkSize`, which the registry reads straight out of YAML, so a
  `chunkSize: 0` in a configuration file reached the store intact. The result
  is worse than a bad setting. `doPut` slices each incoming event with
  `(chunkSize - buffer.length).clamp(0, ...)`, which is `0` on every iteration
  for a non-positive size: `offset` never advances, the loop cannot terminate,
  and the upload hangs. There is no exception to log and nothing for the caller
  to catch, so the deployment sees a request that never returns and no
  indication of why. A negative size clamps to the same `0` and hangs
  identically.

  The constructor now refuses it with
  `storage.database.chunk_size_not_positive`, which is where the module already
  keeps this kind of check: `TomS3BlobStore` rejects a part size below the
  protocol minimum at construction rather than on first use, for the weaker
  version of the same reason — a store that cannot work should not be built.
  The check sits in the generative constructor alone, so `.named` and the
  registry reach it by delegating rather than by restating it. Four tests pin
  the two refusals, the timing (an `_UntouchableDataSource` fails the test if
  the store touches its data source, so the refusal is provably before any I/O)
  and the boundary — one byte per row is a terrible configuration and a working
  one, without which "refuses everything" would pass. A db-tagged test asserts
  the same refusal arriving out of `initializeBlobStores`, which is the route a
  misconfigured deployment actually takes.

  The upper bound is left unchecked, deliberately. A chunk is stored as base64,
  so its wire size is ~4/3 of `chunkSize` and has to fit inside MariaDB's
  `max_allowed_packet` — but that is a server variable a deployment may raise,
  not a protocol constant like S3's minimum part size, and a constructor
  guessing its value would refuse configurations that work. It is documented as
  a sizing note in `doc/file_storage.md` and on the property, where a caller
  choosing a value will read it, rather than enforced against an assumption.

- **A store handed over as an instance was recorded with a backend type
  nothing could build (tcinc542).** `register` stored `{'type': 'provided'}`,
  but no factory was registered under that name — `backendTypes` held only
  `memory`, `directory`, `database` and `s3` — so the entry described itself
  with a type its own `open()` could not resolve. Two things followed:
  `getBlobStoreInfo(name)!.type` returned a string a caller could not act on,
  and `open()` on such an entry raised `storage.registry.unknown_backend`,
  which is the registry refusing to build a store it was already holding. The
  entry now carries its own factory, closing over the instance it was handed,
  and `open()` prefers it to the backend table. That is the argument the module
  doc already makes for explicit backend registration — a factory is a closure,
  so it can capture what no settings map could carry — taken to its limit;
  nothing about an instance-registered entry is special-cased. Reopening one
  after a `closeAll` hands back the store it was given, which is the only
  honest answer, since the registry cannot rebuild an instance it did not
  build and `close()` is idempotent by contract. The type is now the exported
  `TomBlobStoreInfo.providedType` and remains deliberately absent from the
  backend table: it names how the store arrived rather than a way to build one,
  and there is no instance in a YAML file to hand over, so a configuration
  naming it still fails like any other unknown type. Three tests pin the entry
  describing itself buildably, that boundary, and the reopen returning the same
  usable store. Five mutations confirm each bites, including the two shortcuts
  that would have made `open()` succeed while advertising a backend that cannot
  be configured, and one that returns a fresh store instead of the one given —
  which passes any test asserting only that reopening does not throw.

- **The implicit single-store default was decided over every store in the
  process rather than over the stores the configuration named (tcinc541).**
  `initializeBlobStores` promises that a configuration naming exactly one store
  gets it as the default without having to say `default: true`, because a
  server with one place to put files has no ambiguity to resolve. It decided
  that with `stores.length == 1` and then `stores.keys.first` — both over the
  static, process-wide registry rather than over the entries the call had just
  built. So an application that registers a store in code before reading its
  configuration, which is the ordinary shape for a scratch area or a test
  double, saw two stores and got no default at all; `defaultStore` then raised
  `storage.registry.no_default_store` for a deployment that names exactly one
  place to put files. The second half was worse than the first: had the count
  been corrected alone, insertion order would have handed the default to the
  code-registered store, and writes meant for the configured one would have
  gone silently into a scratch area instead of failing. The rule now reads over
  the names this call registered, and the dartdoc, the module doc and the API
  summary say so. Four tests pin it: a store registered in code no longer
  suppresses the implicit default (and the code-registered one is *not* the
  store chosen, which the old rule's insertion order would have made it); a
  default nominated with `asDefault` in code survives, because the single-store
  rule is an inference drawn when nothing was stated and an inference must not
  overturn a statement; a `default: true` in the configuration still displaces
  a code default, being a statement of its own and a later one; and a non-map
  entry beside the stores is neither counted nor allowed to take the default
  away — previously untested, and newly load-bearing now that the same count
  decides the default rather than only the return value. Six mutations confirm
  each bites, including one that reverts the rule wholesale and comes back with
  every pre-existing test green, which is what made the defect invisible: the
  one test covering it ran against an empty registry, where "the stores this
  call made" and "every store in the process" are the same collection.

- **The blob store registry restated all four file-storage defaults as
  literals, defeating the single-declaration rule `database_blob_sql.dart`
  exists to enforce (tcinc540).** That file's own doc says a table name should
  "exist in the code in exactly one place", and the store's constructors
  honoured it — but `_databaseBackend` passed `'tom_blob'`, `'tom_blob_chunk'`
  and `256 * 1024` explicitly, so on the *configured* path, the one every
  deployment takes, the declarations were dead and three copies three files
  away were live. `_s3Backend` did the same with `8 * 1024 * 1024`. The
  fixtures had drifted too: `dropBlobTables` spelled both names out directly
  above a `dropSchedulingTables` that already used its constants, and two
  statements in the DB suite hardcoded the chunk table. Nothing could catch any
  of it, because every copy agreed with its original — the divergence only
  arrives with a rename, and by then it is a silent read from a table that no
  longer exists. All four now resolve from the declarations, the two sizes
  having gained ones: `TomDatabaseBlobStore.defaultChunkSize` and
  `TomS3BlobStore.defaultPartSize`, which also give the numbers somewhere to
  carry their rationale. Because no value-based assertion can distinguish a
  copy from its original, the expectation is written against the declaration
  count instead: two source scans over `lib/` and `test/` fail on any
  re-spelling. The registry's database backend also had no test whatsoever —
  it is the only backend that cannot be built without a registered data source,
  so the suite covering the other two stopped at its door, which is how the
  drift went unremarked. Three DB-backed tests now pin what a store with no
  settings comes out as, that settings still override each default, and that
  the tables the defaults name are the ones it really provisions and reads.
  Eight mutations confirm the whole set bites: each of the four literals
  reinstated is caught by the scans and by nothing else (they are
  value-identical, so any other failure would mean a test coupled to spelling),
  each of two defaults made unoverridable is caught by the configured-path
  tests, swapping the two table names is caught only by the store being used,
  and re-spelling the fixtures shows why the scans cover `test/` and not just
  `lib/`.

- **`TomS3BlobStore` joined its `keyPrefix` below the boundary that checks key
  length, so a prefix and a key that each fit could reach a signed request
  together (tcinc539).** The prefix was already held to the key grammar at
  construction, which caught a `..` before it became a traversal segment in a
  request path. But `_objectUri` joined it to the caller's key *after* the
  public methods had validated that key, and measured nothing: two parts each
  inside `maxKeyLength` (512) join past it, S3 accepts the result because its own
  limit is 1024, and this one backend then held keys every other backend
  refuses. `maxKeyLength` meant something different depending on where a blob
  happened to be stored. The join now runs through a `_prefixed` helper — the
  single point at which a key becomes an address on this backend, as `_fileFor`
  is on the directory one — which raises `storage.blob.invalid_key_prefix`
  naming both halves. It names the *prefix* because the caller's key is valid
  and unchangeable from the deployment's side, while a prefix that leaves no
  room for this key leaves none for any other. This closes the clause
  `isValidKeyPrefix` cannot settle alone: length depends on a key that has not
  arrived yet, so it belongs to whoever performs the join. `TomBlobExportStore`
  and `@TomFileReference` join *above* a store and get it from `validateKey`;
  S3 was the one site joining below, and now discharges it itself. Two tests
  pin the boundary from both sides — an over-long join refused on all five
  methods by a store whose client fails the test on any request, and a join of
  exactly 512 going out unmolested — and six mutations confirm each bites:
  dropping the check, measuring the key instead of the join, moving the
  boundary by one, blaming the caller's key, bypassing the helper in
  `_objectUri`, and dropping the constructor's grammar check each fail exactly
  the tests that claim them, and nothing else.

- **Three of the four blob backends validated the key on `put` alone, so the
  same rejected key answered differently depending on which backend was
  configured (tcinc538).** `TomBlobStore.validateKey` was called at the top of
  each backend's `put` and nowhere else on the memory, database and S3 stores.
  `get('../escape')` therefore raised `storage.blob.invalid_key` on a directory
  store and `storage.blob.not_found` on a memory one — the wrong error, and for
  a caller branching on the two, the wrong branch. The directory store was
  right only by accident: its `_fileFor` happened to be the single point at
  which a key became a path. The guide claimed the check ran on all five
  methods; it ran on one. The cause was structural — an abstract contract makes
  a cross-cutting obligation a per-backend convention, and each backend honoured
  a different subset of it — so the fix is the one `TomExportStore` in this same
  package already uses: `put`, `get`, `describe`, `exists` and `delete` are
  `TomBlobStore`'s own methods and wrap `doPut`, `doGet`, `doDescribe`,
  `doExists` and `doDelete`. The wrapper validates the key and names the
  operation, so both obligations hold for a backend written later or by an
  application, and a directory traversal cannot be handed to one. Two
  consequences worth stating: `translating` and `operationFailed` became
  private, a helper a backend *may* call being a helper a backend may forget;
  and the memory backend stopped leaking a producer's raw error from `put`,
  which now arrives as `write_failed` with the original as `rootException`, as
  the directory backend's equivalent test already required. The tcinc537
  limitation is preserved verbatim — the directory `exists` still means
  "visible to this process", because `File.exists` hands the wrapper nothing to
  translate. Five tests walk every method of every backend against a traversal
  key and an over-long one, with each store built so that *acting* on the key is
  observable (an S3 client that fails the test on any request, a data source
  that fails it on any statement, a root directory that does not exist), so they
  pin the documented property and not merely the error key. Two more take the
  infrastructure away instead — a data source and an HTTP client that fail every
  call — and assert that the database and S3 backends name the operation the
  caller asked for rather than leaking a `SocketException`. Neither had ever
  been asserted; tcinc537 had fixed the identical defect on the directory
  backend, and the other two were never audited for it. Nine mutations confirm
  each expectation bites: dropping the check from each of the five methods in
  turn, dropping the translation from three, and restoring the `yield*` that
  forwards a read failure past the catch.

- **The directory backend's commit and read steps sat outside its failure
  path, so they raised `FileSystemException` and left the partial behind
  (tcinc537).** `put`'s rollback guarded the stream copy alone: `close`,
  `rename` and the sidecar write were each one line past the `try` that deletes
  the partial. That was backwards. The copy fails on the *producer's* terms,
  while those three are the steps with filesystem failure modes of their own —
  `close` is where the buffer is actually flushed, so a full disk surfaces
  there; `rename` fails on a cross-device root, a read-only mount or a target
  occupied by a directory — and every one of them fails *after* the partial
  exists. So the two faults the staging design was built for were exactly the
  two it did not cover: the caller got a raw `FileSystemException` that no
  `on TomServerException` in the pipeline caught, and a `<key>~part` file
  survived to be found by whoever looked at the directory next. `get`,
  `describe` and `delete` leaked the same exception type for anything that was
  not plain absence. All four now report `TomBlobStoreOperation`'s keys —
  `storage.blob.write_failed`, `read_failed`, `probe_failed`,
  `delete_failed` — keeping the original as `rootException`, while the module's
  own answers (`not_found`, `invalid_key`, `missing_chunk`) pass through
  untranslated because callers branch on them. The rollback became
  residue-aware rather than simply wider: `_writeMetadata` runs after the
  rename, so the leftover after a commit is the *blob*, but deleting it
  unconditionally would destroy the previous content on a failed overwrite — a
  case the suite already pinned. It deletes the partial before the rename and
  the new blob after it, which is the honest guarantee a rename-based commit
  can offer, the rename being itself the destructive step. A sidecar failure
  now fails the `put` loudly instead of being tolerated, because the descriptor
  about to be returned names a media type a later `describe` would contradict.
  Seven tests cover it, and seven mutations confirm each bites — including the
  pre-fix `put` restored verbatim. One of them reported a fact rather than a
  gap: `exists` had been wrapped too, but `File.exists` answers from a `stat`
  and maps every failure of it — unreadable parent, symlink loop, over-long
  name, all three probed — to plain `false`, so the wrapper guarded a call that
  cannot throw. It was removed rather than left as untestable defence, and the
  limitation it hid is now documented and pinned: on this backend `exists`
  means "visible to this process", and `describe` is what distinguishes an
  unreadable blob from an absent one.

- **A directory-backed store named its bookkeeping with suffixes a caller
  could spell, so two callers with ordinary keys destroyed each other's data
  (tcinc536).** `TomDirectoryBlobStore` kept a `<key>.meta` sidecar and staged
  writes in `<key>.part`; `TomDirectoryExportStore` staged in `<key>.part` too.
  All three are valid keys — `.` is an ordinary key character and the grammar
  reserves only the segments `.` and `..` — so the bookkeeping sat *inside* the
  key space. `put('a')` then `put('a.meta')` overwrote the first blob's sidecar
  with the second blob's bytes and `a` silently lost its media type and file
  name; `delete('a')` then removed `a.meta` unconditionally, destroying a blob
  its caller had never named and returning `true`; `get('a.meta')` served the
  store's own JSON as a blob; and `put('a')` overwrote and then renamed away
  whatever `a.part` held. Every one of them was a legitimate key meeting a
  legitimate key, with neither caller doing anything wrong. Both backends now
  hang their suffixes off `TomBlobStore.auxiliaryMarker` (`~`), a character
  `isValidKey` cannot produce, so the bookkeeping is unaddressable rather than
  merely unlikely to be hit — `<key>~meta` and `<key>~part`. The marker sits on
  the contract because it is a fact about the shared grammar, which
  `TomExportStore.validateKey` also uses; the suffixes stay with each backend
  because they are its storage layout. The keys themselves are *not*
  restricted: `a.meta` remains a perfectly good key holding a perfectly
  ordinary blob, because refusing it would have made the accepted key space
  depend on which backend was configured and stopped the stores being drop-in
  replacements for one another. Seven tests: the four destructive scenarios,
  two invariants asserting each suffix is unspellable, and a delete of a
  sidecar-less blob that a mutation run found unguarded. No migration — a
  pre-existing `.meta` file becomes an ordinary blob and its former owner falls
  back to `stat()` plus the generic media type, which is the hand-placed-file
  case `describe` already documents.

- **Nothing recorded that the PDF renderer's base-14 default prints a library
  diagnostic, or that it cannot reach a deployment (tcinc535).** Every render
  emits `Helvetica has no Unicode support …` and the same for `Helvetica-Bold`
  — twice per document, because a bold header draws on a second face — and all
  three places that documented the default as deliberate said nothing about it.
  It reads like a framework leaking into a server's log stream. The renderer's
  library documentation, `doc/export.md`'s PDF section and the `theme` row of
  the API summary now state what it is, why it is not suppressed, and how to
  stop it in the runs where it does appear.
- The investigation overturned the premise the report was written on. The line
  is emitted from a bare `print` **inside an `assert`** in `package:pdf`'s
  `PdfType1Font.create`, so it is compiled out of a `dart compile exe` binary
  and of `dart run` without `--enable-asserts` — measured at zero occurrences
  under the example's own documented command and two under `--enable-asserts`.
  A deployment never sees it; the noise is confined to test runs, where the
  export suites emit fourteen lines. There is also no logger to silence, as had
  been supposed: no level, no scope, and the only interception point is the
  enclosing zone's `print` handler, which would mean string-matching another
  package's message text and swallowing every print the render makes.
- Suppression is additionally easy to get wrong in a way that looks right, which
  the mutation run established rather than assumed. A zone around
  `document.save()` — the natural place for it — suppresses nothing, because the
  base-14 font is created while the page is laid out inside `addPage`. A working
  suppression has to enclose the whole build, widening precisely the blast
  radius that made it a bad idea. The supported answer is the knob that already
  exists: a `theme` carrying an embedded font creates no base-14 face, so
  nothing warns.
- Because those paragraphs are claims about a third-party library, they are
  pinned rather than asserted in prose. `test/export_test.dart` now captures the
  render's `print` output and requires the diagnostic once per face under
  assertions, and separately runs the example as a subprocess under plain
  `dart run` and requires silence from a run that demonstrably rendered a PDF.
  Neither half means anything alone: the first would pass if the line escaped
  into production, the second if the renderer had silently stopped warning. Four
  mutants — bold removed, the example's PDF step switched to CSV, a working zone
  suppression, and the diagnostic escaping its assert — were each required to
  kill a *declared* subset of the two tests, and all four did.
- The same fact about `dart run` underlies two opposite conclusions now recorded
  in one file: assertions being developer-only is what makes an `assert` in an
  example a silent bug (tcinc533) and what makes this diagnostic harmless.
- **The export module's blob adaptor was tested in the `file_storage` suite, so
  the export module read as though it had none (tcinc534).**
  `TomBlobExportStore` is declared in `lib/src/tomserver/export/` and is the
  export module's class — `doc/export.md` states the arrow explicitly, that the
  `file_storage` module is *"used only by `TomBlobExportStore`; the rest of the
  module does not know it exists"* — yet its fourteen tests lived in
  `test/file_storage_test.dart`, and neither export suite mentioned it. A reader
  auditing the export module's coverage concluded the adaptor was untested. The
  group and its failing-backend fixture now sit in `test/export_test.dart`,
  beside the two backends the adaptor is interchangeable with and immediately
  before the contract group that drives all three.
- Nothing was holding the group next door but the fixture: `_FailingBlobStore`
  happened to be declared in the neighbour's file, and the tests followed it.
  That is convenience, not a design reason — the group covers one class's own
  four methods, its prefix validation and its error translation, none of which
  is a claim about two modules agreeing. The one claim that *is* stays put: an
  export key and a blob key are one grammar in two vocabularies, and
  `test/file_storage_test.dart` still pins `TomExportStore.validateKey` against
  `TomBlobStore.validateKey`, where the grammar is defined. After the move that
  suite covers no export class at all, which is what the module's own
  documentation already said was true.
- A mirror-image placement was found and deliberately left alone.
  `TomBlobStore.sanitiseKeySegment` is a `file_storage` symbol tested in
  `export_test.dart`, and it belongs there for the opposite reason: the property
  it pins is one the *export* module depends on — `TomExportService.keyFor`
  applies it and hands the result to `validateKey` — so it is tested where it
  would break. The rule reconciling all three cases is now written into both
  suite headers rather than left to be re-derived: a class's own tests live in
  its module's suite; a test pinning a neighbour's contract stays with the
  dependant; a claim about two modules agreeing stays where the grammar is
  defined. `doc/export.md`'s Verification section and `doc/file_storage.md`'s
  export section record the same thing for readers who never open a test file.
- Seven mutants of `blob_export_store.dart` — a dropped prefix, the prefixed key
  recorded instead of the caller's, an untranslated `not_found`, an unchecked
  `keyPrefix`, unprefixed `exists` and `delete`, and the `yield*` trap the source
  warns about — were each required to turn `test/export_test.dart` red **and**
  leave `test/file_storage_test.dart` green. All seven did, which is the
  difference between a move and a copy: had the group been spliced in without
  being cut, both suites would have failed.
- The todo's secondary complaint, that the adaptor's coverage was narrower than
  the class, was already stale. tcinc523 and tcinc525 had closed both gaps; the
  group is fourteen tests, not the five the todo recorded, and includes the
  `keyPrefix` edge cases and the translation of every backend failure, not just
  `not_found`. Nothing was added.
- **The export example demonstrated the route `doc/export.md` argues *against*
  for entity exports, and the recommended one only in a test file (tcinc533).**
  Every one of the example's steps built its columns from a hand-written
  `TomTabularColumn` list, so the module's executable documentation showed the
  second declaration the guide's longest section exists to remove, and a reader
  looking for `ofEntities` was sent to `test/export_entities_test.dart` — which
  is a suite, not a worked example. A new **step 5** renders the sales report of
  step 4 a second time from a stream of `ExampleSaleRecord` and compares the two
  files **byte for byte**, which is the guide's claim stated as something that
  can fail rather than as a paragraph: the entity is field for field the
  hand-written projection, so a type or an order changed in one place and not
  the other breaks the run. The comparison is made in two beats — the data rows
  match immediately, the whole file only once `titles` is supplied — because the
  entity declares the schema and not the presentation, and showing exactly which
  of the two the derivation removes is more honest than an equality that hides
  it. The derived names and types are compared against `columns()` rather than
  against a written-out list, since a list would be the third declaration.

  The step also shows the two default-excluded kinds of column as the asymmetry
  they are rather than as two identical throws: naming a redacted field in
  `include` **fails** with `export.entities.redacted_column`, while a
  `@TomFileReference` merely opens on request — and opening it leaves the
  redaction rule shut. What no single run can show is the drift itself, since an
  entity cannot grow a field mid-run; the step says so and points at the suite
  that derives from two versions of one entity.

  `ExampleSaleRecord` lives in a new `example/export/export_entities.dart`,
  because a type the reflection generator captures cannot also live in a file
  that imports the generator's output, and is registered in the existing shared
  `example/example_reflection.dart` root as that file's own header instructs — a
  second root would capture the same framework surface again for ~1.7 MB of
  generated source. Inserting the step at 5 rather than at the end renumbered
  the nine steps after it, which surfaced a pre-existing transcript defect: the
  two-digit step labels had always printed their colon one column left of the
  single-digit ones. All fourteen are now aligned. Seven mutations confirm the
  new expectations bite: dropping the `id` exclusion, dropping `titles`,
  diverging one entity value from its hand-written twin, not asking for the
  redacted field, not opening the file rule, reverting a check to an `assert`,
  and swapping two fields of the entity.

  `doc/export.md` gains a **Verification** section naming both suites and both
  example files, so the guard in `api_reference_coverage_test.dart` no longer
  needs to skip the module; `export` leaves `_verificationPendingAttribution`,
  which its meta-test requires once nothing is left to suppress. Eleven modules
  remain in it (`tcincb125_ahxt`).

- **The export example's header promised the blob adaptor and the run never
  constructed one — and the twenty-six checks it did make were compiled out
  (tcinc532).** The library dartdoc advertised "the storage seam and its adaptor
  onto the framework's blob store", but every step ran against
  `TomMemoryExportStore`; `TomBlobExportStore` and `TomDirectoryExportStore`
  appeared nowhere, although the latter is the backend `doc/export.md` wires into
  its server example. A new step 10 sends **one rendered report under one key
  through all three backends** — the service constructed identically each time,
  nothing above the loop changing — which is what the module's indifference claim
  actually asserts, and prints `exports/2026/07/28/Q3_sales.csv` reaching the
  blob store while the returned `TomStoredExport` keeps the caller's unprefixed
  key, since reporting the prefixed one would hand back something `open` does not
  accept. The directory store is handed a root that does not yet exist and the
  run checks it into being, so the "configured before it is a directory" property
  is exercised rather than described; the temp tree is removed in a `finally`,
  which is what finally earns the header's "or a filesystem the run does not
  clean up".

  Writing that step surfaced the larger defect. All twenty-six of the example's
  expectations were `assert`s, and `dart run` — the command the file's own header
  gives — leaves assertions **disabled**. The example therefore printed a
  plausible transcript and exited 0 with every expectation in it unevaluated, the
  same failure the datasources example carried for a year. They are now the
  package's throwing `check(condition, expectation)` helper, with the four
  expected-throw blocks reshaped so that *not* throwing fails too, and a
  three-test "The example runs green" group in `test/export_test.dart`: the
  example is executed under exactly `dart run` with each numbered step required
  to report (matched at line start, because `contains('1. ')` is satisfied by
  `11. `), the source is required to carry the helper and no `assert(`, and the
  helper itself is **imported and called**, because a `check` that printed would
  satisfy both source-shape tests while leaving the run green and every
  expectation violated. Seven mutations confirm the checks bite: dropping the
  prefix, pointing the directory store at an existing root, collapsing the loop
  back to the memory store, returning the prefixed key from the adaptor,
  reverting one check to an `assert`, emptying the helper, and renaming it.

  `api_reference_coverage_test.dart`'s `_examplesAssertingExpectations`
  quarantine loses the export entry as a result, which its own meta-test
  required: an exemption with nothing left to suppress turns a checked example
  back into an unchecked one. Fifteen examples remain in it (`tcincb134_ahyc`).

- **`TomColumnType.forValue` was documented as used by adapters that do not
  exist, in a module that argues against ever writing one (tcinc531).** Its
  dartdoc read "used by adapters that infer columns from data rather than being
  told"; nothing in the workspace called it, and the only thing that ever had
  was the test asserting its own mapping. It was the enum's one member without a
  consumer — `dartType` is read by `_TomEntityProjection.columnTypeOf` and
  `naturalWidth` by `_derivedWidth`.

  It has been **removed** rather than given a caller or a softer sentence. The
  caller the todo suggested — an `ofMaps` variant deriving columns from the
  first row — is the wrong shape for this family twice over: a section's columns
  must exist before its stream is subscribed, so inference would make it the one
  constructor here that has to be awaited, and a first row is the worst
  available witness, since a `null` cell declares nothing and every later row
  would be formatted under whichever row happened to arrive first. The module
  already takes that position for widths — `TomTabularColumn`'s width comes from
  the schema and never from the rows, because XLSX is written a row at a time
  and cannot measure them either — and already answers the "derive my columns"
  request with `ofEntities`, which reads `@TomDbColumn`: a declaration, ordered
  and named and typed, rather than a sample. Keeping the method and describing
  it as "offered for callers that need it" would have been the speculative API
  the guidelines rule out, left standing as a signpost toward a design the
  module rejects. The inverse is a six-line switch on the day a real caller
  appears.

  The knowledge is now written where someone looking for the missing method will
  be: `ofMaps`'s dartdoc, the API mirror's factory prose and `doc/export.md` all
  state that **columns are declared or derived from a schema, never inferred
  from the rows**, with the reason and the pointer to `ofEntities`.

  The deleted test's value was kept by repointing it at `dartType` — the binding
  that has a consumer, and one whose failure mode is silent: `columnTypeOf`
  keeps its family-derived candidate only when the declared Dart type can
  inhabit it, so a wrong entry demotes that family's columns to `text` and the
  export formats its dates as strings with nothing reported anywhere. Eight
  mutations confirm the rewritten test pins that table: each of the five
  `dartType` entries falsified in turn, the inhabitability guard dropped, the
  guard inverted, and a sixth column type appended.

- **`TomDirectoryExportStore`'s constructor dartdoc described a filesystem
  effect the constructor does not have (tcinc530).** It read "a store rooted at
  `root`, which is created if it does not exist"; the constructor assigns the
  field and nothing else. The directory *is* created — lazily, by the
  `create(recursive: true)` in `doStore` — so the behaviour was defensible and
  only the prose was wrong, but the two disagreed about whether configuring a
  store had an effect on disk, and `api_summary_export.md` already carried the
  accurate wording, so the package documented itself two ways.

  The dartdoc now states when the root is created (the first `store`, together
  with whatever directories that call's key names), what the read paths do
  without it (`open` is `export.store.not_found`; `exists` and `delete` answer
  `false`, and neither creates anything — asking a store whether it holds
  something is a question), and why the creation is deferred rather than done
  once: a constructor cannot await, so doing it there means a blocking
  `createSync` on a possibly slow mount thrown from a field initialiser, on a
  store the application may never write to — and a root created once is just as
  gone when a volume is remounted or a tmpfs reaped, where the lazy one comes
  back. `doc/export.md` and the API mirror now say the same.

  Every existing test in the suite handed the store a directory that already
  existed, which is how the claim survived: nothing ever ran against a missing
  root. Four tests now do — construction leaving the filesystem untouched, the
  first write creating root and key directories together, the three read paths
  reporting absence without creating anything, and a root deleted after
  construction coming back on the next write. Seven mutations confirm each
  sentence of the new dartdoc is held by one of them: creating the root eagerly
  in the constructor, creating only the root and not the key's directories,
  creating nothing, creating non-recursively, and each of `exists`, `delete` and
  `open` creating the root before answering. No production change was needed.

- **A report name that downloaded fine could not be stored (tcinc529).**
  `TomExportService.respondWith` sanitised the `baseName` it was given;
  `keyFor` — which takes the *same* report name — only validated one against the
  key grammar. So `Q3 sales`, which is what report names actually look like,
  served a file on the `apiResponse` channel and threw
  `export.store.invalid_key` on the `fileExport` channel. The module's own
  example stepped over the asymmetry by passing `sales` to one call and
  `Q3 sales` to the other, so nothing ever put one name through both.

  `keyFor` now sanitises. Its contract is stated where it was previously only
  implied: **it takes a report name, not a path**, and the only path structure in
  its result is the partition, which it owns. A `/` in a name is therefore
  replaced rather than honoured — `Sales / Returns` is one file, and
  `../etc/passwd` is *neutralised* by having nothing left to traverse with rather
  than refused. That reverses one previous test deliberately: refusing a name
  the other channel serves happily was the asymmetry itself.
  `TomExportStore.validateKey` still refuses, and the difference is the point —
  a key is assembled by code, so a malformed one is a bug worth surfacing; a
  name comes from a person, so mangling beats rejecting.

  Two things are deliberately *not* unified. The character sets still differ,
  because the grammars do: a `Content-Disposition` filename is a Latin-1 quoted
  string and a storage key is a relative path of unreserved characters, so
  `Q3 sales` downloads as `Q3 sales.csv` and stores as `Q3_sales.csv`. What is
  symmetric is the *accepted set*, which is the property a caller can act on.
  And length is not repaired: a name too long to be a key still throws, because
  truncating would silently give two different reports one key and let the
  second export overwrite the first with nothing reported anywhere.

  The sanitiser itself is new API — `TomBlobStore.sanitiseKeySegment`, placed
  beside `isValidKey` and the pattern it negates rather than in the export
  module, because a sanitiser and its validator are one grammar spelled twice
  and the worst output available is something refused by the check it exists to
  satisfy. A test over the code-unit range asserts the agreement mechanically
  instead of a comment asking that the two be kept in step. Ten tests were added
  and one removed; eight mutations confirm each bites — skipping the sanitiser,
  sanitising the whole file name instead of the untrusted half, the two channels
  disagreeing about what to call an unnamed export, the sanitiser letting the
  separator or the reserved segments through, dropping the trim, and truncating
  instead of refusing an over-long name.

- **`TomExportService.render` was documented as the primitive both channels are
  built on, and neither channel called it (tcinc528).** `respondWith` and
  `storeAs` each reached past it to `formats.rendererFor(format).render(result)`,
  so the two-step lookup appeared three times and `render` was on no other
  method's path. The cost is not the duplication: it is that a subclass
  overriding `render` to add a metric, a trace or a row limit saw only the
  callers who invoked it explicitly — which the same documentation calls the
  rarest of the three cases.

  Both channels now deliver the stream `render` returns, making it the only
  place in the class where a format id becomes bytes. What the channels still
  resolve for themselves is the format's *description* — its media type and file
  extension. That split is deliberate and is now stated: the registry is asked
  what a format **is**, `render` only what it **produces**, so an override may
  wrap, meter or refuse a stream without being able to silently relabel it, and
  an unknown format still fails before a `Response` object exists rather than as
  an error on a body already being written.

  The test that claimed this was true asserted only that `render` produced CSV
  bytes — it would have passed had neither channel ever touched the method,
  which was the actual state. It is now four tests over a metering subclass, and
  they assert being *called* and being *on the path* separately: the format each
  channel asked for, and the byte count the override could only have if the
  channel carried the stream it returned. Six mutations confirm each bites —
  either channel bypassing `render`, either channel rendering a format other
  than the one it labels, `storeAs` calling `render` for the metric but storing
  a second rendering, and dropping the response content type. A seventh, calling
  `render` twice and delivering the second, is an equivalent mutant: a stream
  from an `async*` body that nothing listens to never runs, which is exactly why
  the byte-count assertion rather than the call count is the load-bearing one.

- **A column width meant two different things, and the module's own example
  showed the damage (tcinc527).** `TomTabularColumn.width` was documented as "a
  hint": XLSX wrote it as an absolute character count, PDF read it as a flex
  proportion. The two readings disagree on the *unhinted* case rather than the
  hinted one, and that is where it hurt — PDF gave a column with no width a flex
  of 1 against hints in the twenties, XLSX left it at Excel's 8.43 default, which
  shows an ISO timestamp as `#####`. Rendering `example/export/export_example.dart`
  printed `product` across seven eighths of the table and sent `Amount` down the
  remaining strip as `A`, `m`, `ou`, `nt`, with twenty rows over four pages.

  The unit is now **a character, in every format**, stated once on the column and
  read by both renderers. A proportion was the other candidate and is not
  expressible: a sheet has no total width to be a proportion *of*, and OOXML's
  `<col width>` unit is itself a character count. A page does have a fixed total,
  so PDF keeps the *ratio* between the widths — the most of an absolute request a
  page can hold. The characters are deliberately not converted to points first;
  `pw.FlexColumnWidth` is scale invariant, so a single conversion factor cancels
  exactly across every column, and doing the arithmetic would only imply a
  precision the estimate cannot deliver.

  A column that states no width now has one anyway. `TomColumnType` carries a
  `naturalWidth` — 23 for `timestamp` because `2026-07-01T00:00:00.000` is 23
  characters, 5 for `boolean` because `false` is — as a constructor argument, so
  adding a type means deciding its width; `TomTabularColumn.effectiveWidth`
  returns the stated width, or the larger of that natural width and the label's
  length, capped at `maxDerivedWidth` (40) so one long heading cannot squeeze the
  rest of the table off the page. An explicit width is never capped. The derived
  width comes from the schema and never from the rows, because XLSX must emit
  `<cols>` before a row has been seen — the same constraint that stops the PDF
  streaming, met from the other end. XLSX now writes a `<col>` for every column
  rather than only the hinted ones. A width below 1 is rejected at construction
  (`export.column.invalid_width`): 0 hides the column in a spreadsheet and
  collapses it on a page.

  The same example now renders on one page with its headers and timestamps
  intact, which is what the two renderer tests assert — one reading the emitted
  `<col>` elements, one reading the PDF content stream for whole tokens and a
  single `/Type /Page`. Five unit tests pin `effectiveWidth` itself. Seven
  mutations confirm they bite: restoring either renderer's old fallback, dropping
  the label floor, dropping the cap, dropping the width guard, changing a
  `naturalWidth`, and ignoring an explicit hint each fail exactly the tests that
  claim them.

- **The two in-memory stores shared their buffers with callers, in both
  directions (tcinc526).** `TomMemoryExportStore.doOpen` ended in `yield bytes`,
  where `bytes` is the list held in its map — so a consumer that writes into the
  chunk it received, which is what decoding in place means, edited the stored
  export. `TomMemoryBlobStore.get` did the same, and because
  `TomBlobStore.getBytes` collects with a non-copying builder that returns a
  lone chunk untouched, the aliasing reached the buffered convenience too — the
  method that exists precisely for the blobs small enough to decode whole.

  The survey that found the sibling found the mirror image as well.
  `TomMemoryBlobStore.put` collected with `BytesBuilder(copy: false)`, which
  *retains* the lists it is given, so a producer refilling one fixed-size
  scratch buffer per chunk — the ordinary shape of an encoder — had its buffer's
  last state stored once per chunk: `'ccc'` for a stream of `'a'`, `'b'`, `'c'`.
  `putBytes` was the one-shot form of the same fault, adopting the caller's list
  outright. The export store was already correct here, copying each chunk with
  `addAll` as it arrived, which nothing said was load-bearing.

  Both directions are now stated on the interfaces rather than left to each
  backend: a chunk from `get`/`doOpen` **belongs to the caller**, and a chunk
  handed to `put`/`doStore` is **borrowed for the duration of the `await`**. The
  backends that read and write elsewhere satisfy both without trying — a chunk
  off a file, a row or a socket is fresh, and one written to it is gone — so the
  two memory backends are the only ones that had to choose, and they copy.

  A copy, deliberately, and not the cheaper unmodifiable view: an unmodifiable
  chunk would make that same in-place consumer throw on the backend the tests
  run on and succeed on every backend they deploy to. That is the tcinc524
  principle in the other direction — the development backend must not diverge
  from production by being *stricter* about what it hands back any more than by
  being laxer about what it accepts. Six tests pin both halves at both stores
  and through `getBytes` and `putBytes`; five mutations confirm they bite,
  including one that swaps the copy for an unmodifiable view, so the choice is
  asserted rather than merely commented.

- **Three components joined an unchecked key prefix to a checked key
  (tcinc525).** A prefix is not a separate notion from a key — it is joined as
  `"$keyPrefix/$key"` — so every clause a key must satisfy the prefix must
  satisfy too, or the join produces something no backend accepts. Each of the
  three places that build such a join validated only the half the *caller*
  supplied. `TomBlobExportStore` took its prefix as a plain constructor
  argument from a deployment setting and prefixed after validating, so a
  misconfigured `..` failed on the first `store` as a `TomStorageException`
  from whichever backend was underneath, naming the prefixed key rather than
  the setting. `TomS3BlobStore` was worse and had no error at all: its prefix
  is joined in `_objectUri` and split straight into
  `Uri.replace(pathSegments:)`, so an unchecked `..` became a literal traversal
  segment in a *signed* request path. `@TomFileReference(keyPrefix:)` was
  caught — `TomFileReferenceKeys.generate` ends in `validateKey` on the joined
  key — but reported as an invalid key that is mostly a UUID nobody chose,
  rather than as the annotation a developer can go and correct.

  Because three independent components each forgot, the rule went where
  `isValidKey` already lives: `TomBlobStore.isValidKeyPrefix` as the predicate
  and `validateKeyPrefix` as the throwing form, so a fourth prefix site gets
  the check by construction. Each site enforces it in its own vocabulary and at
  its earliest point — `storage.blob.invalid_key_prefix` from the two storage
  components at construction and at key-mint time respectively (the annotation
  is a `const` constructor and cannot refuse a value), and
  `export.store.invalid_key` from the export store, whose callers should not
  have to catch a storage error to learn their own setting is wrong. Every one
  of them names the parameter `keyPrefix` carrying the prefix itself, because
  the derived key it would otherwise report is one nobody wrote.

  Two decisions the fix had to settle. A trailing slash is **not** a second
  accepted spelling of a prefix: the join supplies the separator, so `exports/`
  yields `exports//sales.csv`, which the grammar rejects for the doubled slash
  — pinned by an explicit test at each of the three sites. And length is the
  one clause a valid prefix cannot settle on its own: two individually valid
  parts can join past `maxKeyLength`, which depends on the caller's key, so
  `validateKey` on the joined key remains the backstop and says so in its
  dartdoc. Seven tests cover the predicate, the empty and null prefix, the
  error's parameter, and refusal at construction in each component; five
  mutations confirm they bite.

- **`TomMemoryExportStore`'s two inspection accessors accepted keys every other
  door rejected (tcinc524).** The interface owns key validation so that "every
  backend gets the check, including ones written later"; making the four store
  methods final (tcinc523) delivered that for `store`, `open`, `exists` and
  `delete` on every backend at once, but `textOf` and `descriptorFor` are this
  backend's own and stayed outside it. They are the accessors a *test* reads an
  export through, on the backend a development server runs, which is precisely
  where a key too lax for production must not pass: a key built from a report
  title could be asserted on all the way through a green suite and fail on
  deployment. The wrong answer was also the misleading one — `textOf('../x')`
  reported `export.store.not_found` and `descriptorFor('../x')` answered `null`,
  both of which say *nothing was written here* about a string that is not a key
  at all, sending the reader after a missing write. Both now validate;
  `not_found` and `null` keep their real meaning, which a second test pins so a
  fix that makes every unhappy path throw the same thing cannot pass.

  The test that was supposed to cover this was named
  `validates keys exactly as the filesystem backend does` and exercised `store`
  alone — the five other entry points could each have accepted `../escape` with
  it still green. It now walks all six. Three mutations confirm the pair bites:
  dropping validation from either accessor, and conflating absence with
  invalidity.

- **An export store's error contract depended on which backend was configured
  (tcinc523).** The module documented one promise — every failure is a
  `TomExportException` carrying a documented key — and seven sites broke it.
  `TomDirectoryExportStore` closed its sink and renamed the `.part` file
  *outside* the guarded region, so a full disk or a cross-device destination
  surfaced a raw `FileSystemException` *and* left the partial behind; its
  `open`, `exists` and `delete` never translated at all. `TomMemoryExportStore`
  let a failing source stream propagate untouched where the directory backend
  wrapped the same failure as `export.store.write_failed`. `TomBlobExportStore`
  named only `storage.blob.not_found` and rethrew every other
  `TomStorageException`, and translated nothing in `store`, `exists` or
  `delete`, so a permission error or an object-store timeout reached a caller
  in the storage module's vocabulary. An eighth defect, in the same family and
  not in the report: `TomMemoryExportStore` never called `validateKey` on
  `open`, `exists` or `delete`, so the memory backend accepted `../escape`
  where the other two refused it — falsifying the documented claim that
  validating centrally means every backend gets the check.

  **The fix is structural, because three backends independently forgot the same
  two things.** `store`, `open`, `exists` and `delete` are now final on
  `TomExportStore` and wrap new `doStore`, `doOpen`, `doExists` and `doDelete`
  hooks. Each public method validates the key, dispatches, and converts whatever
  the hook raises into the key for that operation, keeping the original in
  `rootException`; the module's own exceptions pass through, so a caller
  catching `export.store.invalid_key` still catches it rather than meeting the
  name of whichever operation refused the key. A new exported enum,
  `TomExportStoreOperation`, names the four keys once. Both guarantees now hold
  by construction rather than by convention, and a backend written later gets
  them without knowing they exist.

  Three error keys are new — `export.store.read_failed`,
  `export.store.probe_failed`, `export.store.delete_failed` — joining
  `write_failed`, which now applies to every backend rather than only the
  directory one. `not_found` remains the one storage error a backend raises
  itself, because only it knows absent from unreadable.

  Thirteen tests assert the boundary, including one that runs the same failing
  source stream through all three backends and expects a single key from each.
  Seven mutations confirm they bite: dropping the `TomExportException`
  passthrough, moving the rename back outside the try, removing the translation
  entirely, dropping `validateKey` from one dispatch site, giving `probe` the
  wrong key, making the blob adaptor rethrow `not_found`, and restoring the
  `yield*` in `open` — which forwards inner-stream errors past the enclosing
  `try`, and is why reading is the one operation that cannot share the
  `_translating` helper.

- **The CSV formula guard tab-prefixed every negative number, so a numeric
  column arrived in a spreadsheet as text (tcinc522).** `TomCsvRenderer` ran its
  injection guard on the formatted text of every cell with no knowledge of what
  the value was, and `-` is one of the four characters that make a spreadsheet
  read a field as a formula. A section with a decimal and an integer column
  holding `-1234.5` and `-7` rendered as `"\t-1234.5","\t-7"`; Excel and every
  other spreadsheet read a tab-prefixed quoted field as text, so a financial
  export silently lost each negative figure as a number — totals stopped
  summing, sorting turned lexical, and the value still looked right on screen.
  The guard now applies only where a formula can actually originate.

  **The rule is the value's runtime type, not the column's declared type.**
  `tomFormatCellAsText` formats `null`, `num`, `bool` and `DateTime` into
  literals — a `-` in front of a number is a minus sign, never an operator — so
  those four are exempt. Everything else falls through to `toString()`, whose
  output is whatever the object chose to return, and stays guarded. Testing the
  column type instead would have been a regression in the other direction: a
  `String` landing in a numeric column is a mismatch the renderers tolerate
  rather than reject, so `=1+1` in an integer column would have been emitted
  unguarded — the exact payload the guard exists to stop. Section titles and
  column labels remain guarded unconditionally; they are caller-supplied
  strings, as untrusted as any cell.

  Four mutations confirm the tests bite: guarding unconditionally, inverting
  the exemption, dropping the guard, and gating on `TomColumnType.text` each
  fail exactly the tests that claim them — the last one failing the
  numeric-column injection test, which is what rules that approach out.
  `doc/export.md` and `doc/api_reference/api_summary_export.md` now say which
  fields the guard covers and what a guarded field costs, and the export
  example demonstrates both halves in one row.

- **The XLSX renderer wrote neither the result title nor its metadata, which
  four documents said it did (tcinc521).** `TomTabularResult.title` was
  documented as "the PDF heading, the XLSX workbook title" and `metadata` as
  the context "that makes a downloaded file interpretable months later", but
  the workbook carried no `docProps` part at all: rendering a result titled
  `Ledger Title 2026` with metadata `{Filter: x}` at `compressionLevel: 0` and
  searching the uncompressed archive found neither string. The api-summary
  mirror compounded it by naming CSV as the format that ignores metadata and
  leaving XLSX unmentioned, so a reader concluded XLSX rendered it.

  The renderer now emits `docProps/core.xml` carrying the title as `dc:title`,
  and — when the result has metadata — `docProps/custom.xml` carrying each
  entry as a user-defined property, both declared in `[Content_Types].xml` and
  related from `_rels/.rels`. That makes XLSX do for the title exactly what the
  PDF renderer already did by passing it to the document info dictionary.

  **The metadata goes to the document properties, not to cells.** A header
  block above the table was the alternative and would push the header row down
  by however many metadata entries there happened to be, so a consumer reading
  the sheet as a table would find its columns at a row number that varies with
  the metadata — and being machine-readable is the reason to ask for a
  spreadsheet rather than a PDF. Two smaller decisions follow the module's
  existing habits: `core.xml` carries no `dcterms:created`/`modified`, because
  a timestamp would break the byte-determinism the zeroed MS-DOS ZIP fields
  exist to preserve; and a metadata name that escapes to nothing (empty, or
  only control characters XML cannot carry) is dropped rather than written,
  since a custom property with an empty `name` is what makes Excel declare the
  file corrupt — the same trade `_escapeXml` already makes for cell text. A
  result whose metadata is entirely unusable gets no custom-properties part.

  Nine tests assert it, seven mutations kill (title constant, title unescaped,
  `core.xml` omitted, `custom.xml` emitted unconditionally, unnameable entries
  kept, ids numbered from 0, the content-type override dropped). All four
  documents — the two dartdocs, `doc/export.md` and `api_summary_export.md` —
  now describe per format where the title and the metadata actually land.
- **`doc/endpoints.md` named three open ends where the internal list named
  eight (tcinc515).** The user-facing "Not Yet Implemented" section carried the
  three limitations of the *form* module and none of the five a caller is most
  likely to meet: that an unmapped query parameter is dropped without a warning,
  that `coercePrimitiveParameter` cannot tell "not a primitive" from "would not
  parse" so `?count=abc` falls through instead of becoming a 400, that `bool`
  coercion accepts only the exact string `true`, that `TomFileSlots` is a
  process-wide static registry, and that a socket is audited at its ends only. A
  sixth, that `TomErrorHandler` hands `handleErrorDefault` an `Object`
  stacktrace, is user-visible for the same reason — it is the one method a
  concrete handler must write. All six are now in the section, each verified
  against the source, and the section opens by saying what it does and does not
  cover, so its silence no longer reads as "no edges". The one genuinely
  internal item — the public mutable route table on `TomEndpointRouting` — stays
  in the internal list, which now states the relationship between the two.

  No guard ships with this. The rival list lives in the `_ai` quest repo, so a
  test that compared them would skip in any standalone clone and protect nothing
  where it matters; the in-package half of the idea — checking that a bullet
  still names code that exists — is quest todo `tcincb139_ahyh` and wants a
  measurement across all twelve guides before it is built.
- **The mirror described `urlParameterMapping` as path-only, hiding that it is
  the query-binding opt-in (tcinc514).** It said "Binds URL path parameters to
  typed request-DTO field names", which is close to the reverse of the contract:
  a path capture the map does not name binds under its own name, so an *empty*
  map already binds every path parameter, whereas a query parameter binds only
  when the map names it — `injectQueryParameters` returns immediately on an
  empty map. A reader following the mirror would leave the map empty and find
  their query parameters silently dropped. Both entries now state the two roles
  and the asymmetry between them, and the sibling on
  `TomWebSocketEndpoint` says what the asymmetry costs there: a handshake is a
  `GET` with no body, so the URL is the only thing a socket's request DTO can
  be built from.

  The document had in fact contradicted itself for some time — the
  `injectQueryParameters` method row 120 lines further down said "only those
  the endpoint explicitly maps" — and the property row is the one a reader
  consults. Two tests are added for the socket side, which nothing covered:
  the forwarding test proved the map reaches the converted endpoint and the
  oauth suite proved the injector honours a map, but neither said that a
  handshake's query string is therefore bindable, which is the only question a
  socket author has. No guard ships with this: three candidate checks were
  measured against the package and all were rejected on precision — a
  row-length ratio fires on 19 rows of which most are legitimate abbreviation,
  and an emphasis-preservation check scored one true positive against three
  rows that carry their content and merely drop the bold.

- **The API index's Endpoints table described two of the unit's six sources
  (tcinc513).** It listed eighteen types, all of them annotations and pipeline
  machinery, and none of the three transports the unit gained — form binding,
  redirects and WebSockets — nor the HTTP surface of file columns. A reader
  arriving at the index to discover what endpoints can do was told the unit
  answers with objects, and could not learn from it that
  `TomMultipartForm`, `TomRedirect`, `TomWebSocketEndpoint` or `TomFileEndpoint`
  exist at all. Sixteen rows are added to the module table and sixteen to the
  Alphabetical Type Index, and the module's navigation line now names the
  transports. Four smaller omissions found by the same sweep are fixed with it:
  `TomAuditRecordIdGenerator`, `TomResourceDataScope`, `TomConfigurationException`
  and the six `preferences` types that had a module row and no alphabetical one.

  The index guard could not see any of this. It asks whether the index names a
  type *anywhere*, so a type in the alphabetical table alone — or under the wrong
  module — satisfies it, and the missing endpoints names were suppressed
  wholesale by a module-level quarantine. `test/api_reference_coverage_test.dart`
  now also slices the index by heading and asserts that every type a per-module
  summary gives a section to appears under **that** module's table *and* in the
  alphabetical table. The summary, not the source directory, is the source of
  truth: `LoginException` is declared in `little_things` and documented under
  Authentication because that is where a reader meets it, and a
  directory-driven check would report that agreement as a defect. Both checks
  share one quarantine set, so a module leaves it only when it satisfies both;
  giving the new check a set of its own would deadlock the pair.

- **Nothing checked that a documented constructor listing named every parameter
  the constructor takes (tcinc512).** A signature is the one part of a summary a
  reader copies rather than reads, so an omitted parameter is not a thin
  description — it is a parameter the reader will not know exists. Two guards
  looked as though they covered this and did not. The member guard is satisfied
  by an identifier appearing anywhere in a class section *including inside a
  fenced listing*, so a listing could vouch for itself; and a constructor
  parameter that is not also a field — `super.stack` — is a member of no class,
  so no member list could ever see it. `test/api_reference_coverage_test.dart`
  now parses the source constructors of every declared type and every listing
  under a `Constructors` heading, and asserts that each listing names every
  parameter its constructor declares.

  The sweep found two: `TomOAuthException`, whose one-line listing hid all six
  parameters including the `clientThrow` that decides whether a provider
  misconfiguration reaches the browser, and `TomColumnInformation`, which had
  gained a `fileReference` parameter — and a `fileReference` property row —
  without either reaching the summary. Both are fixed, so the guard ships with
  **no quarantine set**: all twenty modules are checked from the first run.
  `TomMethodMetadata`'s `audited`, the omission that prompted this work, had
  already been restored by tcinc471; the check is what makes that repair stick.
  A related but distinct defect — twenty-two listings typing the inherited
  `stack` as `Object?` where `TomException` declares `StackTrace?` — is a type
  question rather than a presence question and is tracked separately.

- **`file_endpoint.dart` and the seven types it exports were mirrored in no API
  summary at all (tcinc511).** The endpoints summary listed five of its unit's
  six sources; the sixth — the 663-line file that serves and stores uploads —
  was absent, and with it `TomFileSlotException`, `TomFileSlot`, `TomFileSlots`,
  `TomFileEndpoint`, `TomFileService`, `TomFileServer` and the
  `TomFormFileStorage` extension on `TomFormFile`. The neighbouring file-storage
  summary did not cover them either: its `Source:` list is the blob-store
  directory, a different tier. A publicly exported surface therefore had prose
  coverage in `doc/file_storage.md` and `doc/endpoints.md` but no entry anywhere
  under `doc/api_reference/`. `api_summary_endpoints.md` now names
  `file_endpoint.dart` on its `Source:` list and carries a section per type with
  constructors, properties and methods.

  Which summary *owns* the types was not a judgement call: the coverage sweep
  derives a file's module from its source directory, so only the endpoints
  summary can satisfy the guard for a file under `endpoints/`. The split that
  made it feel ambiguous is real, though, and now says so — the file-storage
  summary states that it is the storage half only and stops at the key, and each
  of the three file-related summaries names the other two. One existing pointer
  turned out to be dangling: the endpoints summary already said "see
  `TomFormFile.storeIn` in the File Storage summary", a document that mentions
  neither `storeIn` nor any file-endpoint type; it now resolves in-document.
  `endpoints` leaves `_sourceListsPendingReconciliation` and
  `_apiNamesPendingReconciliation`, both of which guard in the other direction
  and would have failed had it stayed.

- **The Access Control document omitted contract-declared authorization — the
  path most registry endpoints take (tcinc510).** `doc/endpoints.md` described
  access resolution as "the method's annotation, otherwise the global protection
  default", which is only the inline half. `getClassMethodMetadata` resolves
  `tea ?? ae?.access`: the handler-side annotation is an **override**, and a
  registry-backed endpoint otherwise inherits the `TomApiEndpoint.access`
  declared on its contract. A reader following the document would have concluded
  that a handler with no annotation is governed only by the global default —
  which is `false` by default, i.e. open — and would have restated inline the
  policies the contract already carries. The section now gives both sources,
  says which one wins and that an override *replaces* rather than merges, and
  shows a contract-gated handler carrying no inline annotation.

  Correcting the prose exposed a gap underneath it. The contract path was pinned
  at the metadata level (which control object lands in `metadata.access`) and
  the protection default was pinned by calling `checkAutomaticAccess` directly —
  but **no test issued a request against a contract-gated endpoint**. "Declare
  it on the contract and it is enforced" was therefore an inference composed
  from two separately-true facts, and the composition is precisely what a reader
  relies on when they omit the annotation. `endpoints_pipeline_test.dart` now
  asserts the outcome in both directions for both branches: the contract role is
  served and a caller without it is refused with
  `endpoint_handler.handle_method_call.access_denied`, while an overriding
  handler is checked against *its* role and not the contract's. Dropping the
  contract operand, swapping the two, and short-circuiting `checkAccess` were
  each confirmed to fail these tests.

- **Two documented socket snippets annotated the *abstract* access control, and
  the mistake analyzes clean (tcinc509).** `doc/endpoints.md`'s WebSocket
  example and `web_socket_endpoint.dart`'s library dartdoc both wrote
  `@TomAccessControl(resourceKey: 'ticker')`. `TomAccessControl` is abstract and
  its only constructor takes no arguments; the pipeline names that type because
  it is what the scan *matches* (`tag is TomAccessControl`), never what a
  declaration writes. The concrete control for the intent is
  `TomResourceKeyAccess`, and it takes its key **positionally**. The same
  snippets also read `who.userName`, where the member is `username`.

  What makes this worth more than a correction is where the error hides: Dart
  reports `instantiate_abstract_class` for a `const` variable and for an
  expression, but **not** for metadata. `@TomAccessControl()` therefore passes
  analysis and gates nothing — the reader's compiler agrees with the document
  and the endpoint is still wrong. The security annotation is the one part of an
  endpoint declaration nobody should be guessing at, so the corrected snippet is
  no longer prose: it is declared verbatim as `FixtureApiService.ticker` and
  `test/endpoints_pipeline_test.dart` asserts that the scan resolves
  `TomResourceKeyAccess('ticker')`, that the key is enforced once
  `TomResourceKeyProtection.globalSettingProtectionDefault` is on (and grants
  everyone while it is off), and that a denied caller is refused *before* the
  upgrade rather than through a socket that opens and dies.

  `doc/endpoints.md` gained a **Which control to annotate with** table naming the
  concrete subclass per intent, including the two traps a reader would otherwise
  hit by trying: `TomGradedAccess` cannot be an annotation at all (its
  constructor is not `const`), and `TomCustomAccess.handler` is the *name* of a
  handler registered with `registerHandler`, not the function. Both snippets were
  additionally made two-type (`abstract class TickerService` +
  `@tomComponent class TickerServer implements TickerService`), since a snippet
  that is correct on the security line and mounts nothing on the next is no
  better than the one it replaced.

- **The endpoints module readme's Quick start did not compile, and would not
  have mounted if it had (tcinc508).** The snippet showed
  `class TodoApi extends TomApiImplementation` — but `TomService` and
  `TomApiImplementation` are *annotations*, not base classes, and
  `TomApiImplementation`'s only constructor requires `apiId`, so the first code
  a reader of this module copies failed `no_default_super_constructor`. The
  Key types table said the same thing one row earlier ("Base classes whose
  annotated methods become endpoints"), which is where the snippet got it.

  The quieter half is that compiling would not have been enough. `scanClasses`
  partitions on a class's own `metadata` and never walks the supertype chain, so
  a subclass of an annotation is invisible to `initializeRouter`; and
  `findServiceInstance` matches an implementation to its service by *supertype*,
  so a single self-referential `@tomService @tomComponent` class resolves to no
  instance. A service is two types because it has to be.

  The Quick start is now the real recipe — `@tomReflector @tomService abstract
  class TodoApi` plus `@tomReflector @tomComponent class TodoApiServer
  implements TodoApi`, the bean registration and the `initializeRouter` call —
  and the table calls the two annotations annotations. It is no longer prose: the
  same pair is declared verbatim in `test/fixtures/reflection_fixture.dart`, and
  `test/endpoints_pipeline_test.dart` asserts that it mounts `GET /todos`, serves
  the body the snippet returns, resolves the `@tomComponent` as the service
  instance, and — because the snippet declares `@TomPublicAccess()` — still
  answers anonymously once a deployment turns automatic protection on.

- **A registry endpoint's `requestHeaders` were emitted as its *response*
  headers (tcinc507).** `TomApiEndpointImplementation.convertToTomEndpoint`
  passed `endpoint.requestHeaders` into `TomEndpoint.headers` — the field the
  pipeline copies onto every response it builds. The contract distinguishes the
  two directions (`requestHeaders` is what a *client* is told to send, and is
  read by `TomServerConnection`; `responseHeaders` is what the server is told to
  answer with), so a registry-backed endpoint declaring required request headers
  had them re-emitted back at the caller, while an inline endpoint declaring the
  same thing did not. The mapping now reads `responseHeaders`.

  Nothing failed loudly, which is why it survived: a response that echoes the
  caller's own obligations back at it is well-formed and reads like a deliberate
  acknowledgement. The other half of the same defect is that
  `TomApiEndpoint.responseHeaders` — the field that *is* the server's business —
  had no consumer anywhere in the workspace, so a contract's response-header
  declaration was simply inert. It is now served.

  `TomEndpoint.headers` states its direction in its own dartdoc: outbound only,
  with no field for headers an endpoint requires of a request, and a pointer to
  which of the contract's two fields fills it. `doc/endpoints.md` gains a
  *Declared Response Headers* section carrying the same table.

  Coverage was nil in both directions. No fixture declared `TomEndpoint.headers`
  at all, so the pipeline's response-header copy was unreached — deleting that
  block outright passed the whole suite — and no registry entry declared either
  header field, so the conversion's reading of the contract was unasserted. Three
  fixtures were added: an inline endpoint declaring headers (the baseline the
  registry style has to agree with), and a registry entry declaring **both**
  directions with distinguishable values, which is the only shape that can show
  *which* one the server picked up. Four mutations, all killed: restoring
  `requestHeaders` (5 tests), dropping the mapping (3), mapping **both**
  directions (4 — the case a loosely-written test would wave through), and
  deleting the pipeline's header copy (3).

- **The routing table was keyed by URI alone, so several methods on one route
  collapsed to one entry (tcinc506).** `createRoutesForEndpoint` wrote
  `routingInfo[tep.uri]` *inside* its loop over `tep.methods`, and again on the
  socket path. An endpoint declaring `[get, put, delete]` therefore overwrote
  its own entry twice, and — the case that actually loses information — two
  endpoints splitting one path between them kept only whichever was mounted
  last. The router was never wrong: each method was registered on the shelf
  `Router` before the overwrite, so nothing 404s and no request-level assertion
  could see any of it. What was wrong is the *diagnostic*, which reported one
  handler where several were mounted, and reported it to exactly the tooling
  that exists to enumerate the served surface.

  `routingInfo` is now keyed by `TomEndpointRouteKey` — a record
  `({String uri, String method})` naming the declared route and the uppercase
  HTTP method name. The method is a `String` rather than a `TomHttpMethod`
  because `TomHttpMethod` defines no value equality, and a diagnostic API should
  not require its callers to hold the canonical constants. Each
  `TomEndpointRoutingInfo` also carries the single `method` it stands for, so
  enumerating `.values` is a complete picture without consulting the keys. Only
  *declared* methods are listed; the automatic `OPTIONS` preflight is mounted for
  every route and recording it would add one entry per route saying what already
  holds for all of them.

  Fixed alongside it, in the same loop: the `router.options` preflight
  registration was also per-method, mounting one unreachable copy per declared
  method after the first. It is now registered once per route.

  Three fixture endpoints were added, because none existed to see this with —
  every fixture declared exactly one method, so the loop had nothing to iterate.
  One declares three methods; two split a single path. Eight tests cover the
  shape, and six mutations were run against them: reverting the key to the
  last-declared method, collapsing the method to a constant (the original
  defect), recording the wrong method on the value, keying the socket entry off
  the handshake GET, listing the preflight as an endpoint, and dropping the
  preflight registration — each killed, most by a single test.

- **`globalSettingLogRequestsDefault` governed nothing, because every log site
  re-tested the raw annotation (tcinc505).** The pipeline computed the effective
  decision — `logRequests ?? globalSettingLogRequestsDefault` — stored it on the
  request log info, and then ignored it: all five log statements asked
  `metadata.endpoint.logRequests == true` instead. `logRequests` is `bool?` and
  documented as "`null` = use the global default", so `null == true` collapsed
  the third state into `false` and the setting reached exactly none of the
  endpoints it exists for — the ones that say nothing. The socket path repeated
  the same computation and the same mistake.

  The decision is now read once, through the new
  `TomEndpointHandler.shouldLogRequests`, which every log statement and both
  computation sites consult. `TomEndpoint.logRequests` behaves as documented:
  `true` logs, `false` does not, `null` follows the global setting.

  The defect was invisible because the request was still logged — by the wrong
  component. The pipeline declined, left `hasBeenLogged` false while
  `shouldBeLogged` was true, and `tomLoggingMiddleware` emitted its generic
  fallback line. The *count* of log lines was unchanged; what was lost was the
  per-exit detail only the pipeline's line carries (which exit produced the
  response, the produced mime type, the encoding). No request counter could see
  it, so the tests assert on the emitted text rather than on the flags.

  Also folded in: in the conversion-error branch `logInfo.hasBeenLogged = true`
  sat *outside* its `if` while its four siblings set it inside. It is now inside
  like the others — one of four differing invites a reader to hunt for a reason
  that is not there.

  No fixture endpoint had omitted `logRequests`, so the global default had no
  coverage at all. Three unannotated fixture endpoints were added, one per
  reachable exit (conversion, handler-supplied response, error handler), and
  the socket path is covered through a refused upgrade — an accepted one cannot
  reach the line at all, which is a separate defect (tcincb136).

- **Automatic endpoint protection keyed registry-backed endpoints on the wrong
  name, composed member keys nobody could author, and inverted its own
  revocation (tcinc504).** `checkAutomaticAccess` grants a denied request a
  second chance when it holds the right resource key. Three independent defects
  meant it granted almost nothing and protected almost nothing under the names
  it documented. All three survived because the feature is gated behind
  `globalSettingUseAutomaticEndpointProtection`, which is off by default, so
  nothing in the workspace had ever evaluated the rule.

  1. *The API branch was dead code.* The method branched on `interface != null`
     and fell back to `metadata.apiEndpoint` for registry-backed endpoints, but
     the single construction site always passed a non-null `interface` holding
     the **implementation** class. A registry-backed endpoint was therefore
     protected under its Dart class name — `TomOAuthServer` rather than
     `tomOAuth` — so an operator who granted a key by the API id the contract
     declares and the client calls granted nothing.
  2. *The member key was unusable.* `methodName` was populated with the mirror's
     **qualified** name, so the composed key read
     `FixtureApiService..FixtureApiService.contractGated` instead of the
     documented `<Interface>.<method>`.
  3. *The revocation was backwards.* The `-<member>` exception denied when the
     principal **lacked** the revocation key and allowed when it held it. Since
     holding a container key always fell into that branch, holding a container
     key denied every endpoint under it.

  Endpoints now key on the identity their contract declares where they have one
  (`<apiId>` / `<apiId>.<endpointId>`) and on the type they are routed through
  otherwise (`<Type>.<method>`) — chosen per *method*, since a
  `@TomApiImplementation` class may also carry plain `@TomEndpoint` methods with
  no contract entry. The pair is exposed as the new
  `TomEndpointHandler.automaticProtectionKeys`, which is non-nullable so that
  "every endpoint has a pair" holds by construction rather than by an
  unreachable guard. `interface` is now null exactly when the method has a
  contract, matching what its documentation always claimed.

  One further trap is now handled: `TomResourceKeyProtection.isProtected`
  answers "held" for *every* key once protection is globally off, so the
  `-<member>` revocation is consulted only while protection is actually on.
  Asking it unconditionally reported every conceivable revocation as issued and
  turned the open default into a blanket denial. See `doc/endpoints.md` §
  Automatic endpoint protection for the full rule.

- **A parameter that cannot be bound no longer shifts every later argument one
  place to the left (tcinc503).** `TomEndpointHandler.bindParameters` builds a
  *positional* argument list, and a positional list has no way to say "this one
  is absent" — when no strategy matched, the loop logged a warning and appended
  nothing, which did not leave the parameter unset but shortened the list and
  moved every argument after it into the preceding parameter's slot. The usual
  outcome was a wrong-argument-count error from `invoke` pointing at neither the
  parameter nor the request; the dangerous outcome was that where the shifted
  value happened to fit the earlier parameter's type, the method was invoked
  **successfully with the wrong argument in it** and nothing anywhere reported
  that a value had been misplaced. `doc/endpoints.md` described this as "logged
  and left unset", an outcome the code could not produce.

  Binding now fills one slot per declared parameter, marking the ones it could
  not resolve, and decides the shape of the call afterwards — because whether an
  unfilled slot may be dropped at all is a question about the parameters that
  come *after* it, which is not yet knowable at the moment the parameter fails
  to bind. Exactly one shortening survives: dropping **trailing optional**
  parameters, which is how Dart applies their defaults. Everything else fails
  the request with a `TomEndpointHandlerException` naming the parameter at
  fault, so the diagnosis points at the declaration that cannot be satisfied
  rather than at a generated call site:

  | Key (under `endpoint_pipeline.bind_parameters.`) | Raised when |
  | ------------------------------------------------ | ----------- |
  | `unbindable_parameter` | A **required** parameter no strategy could supply. |
  | `unbindable_optional_parameter` | An **optional** parameter was not bound but one *after* it was — omitting it would slide the later value into its slot. |
  | `named_parameter_not_supported` | A **named** parameter was bound. Endpoint methods are invoked with positional arguments only, so appending it would have put it in the next positional parameter's slot — the same corruption arriving from the opposite direction, and previously silent. Declare it positionally instead. |

  A named parameter that is *not* bound remains simply absent and its default
  applies; it holds no positional slot, so it can shift nothing.

- **A request body that cannot become the endpoint's DTO is now reported to the
  client instead of being logged and discarded (tcinc502).** The JSON branch of
  `TomEndpointHandler.bindParameters` wrapped its whole body in
  `catch (ex) { tomLog.error(...) }`. That catch sat *outside* the site that
  throws `parameter_instantiation_failed`, so the named exception never left the
  method: the parameter was simply never added to `positionalArguments`, binding
  fell through to the "Setting parameter … failed" warning, and the request died
  much later inside `invoke` with a wrong-argument-count error naming neither
  the parameter nor the body that could not be decoded. That is the one
  diagnosis a client cannot act on, produced from the one situation where the
  client is the party who can fix it — and the error key existed the whole time,
  reachable by nobody.

  The catch is **removed** rather than narrowed. Every failure it stood over is
  a statement about the request: `req.readAsString`, the JSON decode, and
  `createInstanceFromJson`, the last of which already wraps itself. The three
  `inject*` helpers it also covered do not throw at all. So it had nothing
  legitimate left to absorb, and a catch with nothing to absorb is not
  protection, it is a hole.

  Body decoding gets its own key,
  `endpoint_pipeline.handle_method_call.request_body_not_json`, via the new
  `decodeJsonObjectBody`. It covers both the bytes that are not JSON and the
  JSON that is not an object — previously a raw `FormatException` and a bare
  `TypeError` from `jsonDecode(body) as Map<String, dynamic>`. Keeping it
  distinct from `parameter_instantiation_failed` is the point of naming either:
  one says the bytes never were a field map, the other says they were and the
  DTO refused a value inside them, and a client does different things about
  each.

  What deliberately did **not** change: an *empty* body is still not an error.
  It remains a warning and a fallthrough, because that is how a body-less
  request reaches a DTO built from path and query values alone, or reaches the
  context branch below. Only a body that is present and wrong now throws. A test
  pins that boundary alongside one per throw site.

- **Two migration files claiming the same version are refused (tcinc495).**
  `collectMigrationFiles` rejected two files that stripped to the same
  *basename*, and the orchestrator's own comment claimed a directory holding two
  files that claim the same *version* aborted the schema — but nothing checked
  that, anywhere. `orderMigrationNames` now throws
  `db_migration.migration.duplicate_migration_version` naming the version and
  both basenames.

  The two ambiguities are different: files sharing a basename cannot be told
  apart as *files*; files sharing a version cannot be told apart once *applied*,
  because the versioning table records the version and nothing else identifying.
  The damage therefore outlives the run that causes it, in three stages. Both
  scripts apply in the first pass — a migrator's applied-version list is a
  snapshot taken at initialisation, so the second call cannot see the first — in
  an order the sort does not define, since equal keys have no defined order (a
  `[1]-seed` observed running before its `[1]-schema`, inserting into a table
  that did not exist yet). The table is left with two rows for one version. The
  *next* run then meets the first row while being offered the second's script and
  reports a description or checksum mismatch, accusing someone of editing a past
  migration when nobody did.

  Two placement decisions are deliberate. The check compares the **parsed
  integer**, so `[1]` and `[001]` collide as they should rather than passing a
  text comparison. And it runs **before environment selection**, so a tagged and
  an untagged file cannot share a version either: the tag does not make the pair
  safe, it only decides which of them runs *here*, while the row they collide
  over goes into a history that a box switched between environments reads back.
  A tree valid on some machines and broken on others is the failure this module
  exists to prevent, so the answer cannot depend on the active environment — and
  that holds for `TomSchemaConvergenceCheck.readChain` too, which shares this
  helper and filters by an environment of its own (defaulted to the active
  name). Had the check run after selection, one tree would be pronounced sound
  under `prod` and unsound under `dev`.

  No existing fixture tree contained a duplicate version, so nothing that was
  passing stops.

- **`TomSchemaConvergenceCheck.checkAll` and `checkSchema` are synchronous
  (tcinc488).** Both were `async` while doing only synchronous file I/O, so the
  returned future was already complete before the first `await`. The signature
  therefore told callers the migration-tree walk was off the event loop while it
  blocked the loop entirely — a mis-signalled cost precisely where these run, at
  server startup.

  The stronger reason is correctness, not honesty. An `async` signature made the
  missing-directory refusal *ignorable*: a caller who omitted the `await` got a
  value that reads as success, and the `TomDbMigrationException` arrived later as
  an unhandled rejection nothing was watching — which is exactly the vacuous
  "every pair converged" pass that `requireMigrationsDirectory` exists to
  prevent. Thrown from the call itself, it cannot be dropped.

  This also settles a module-wide rule that the two methods were the only
  violators of: **a `Future` in `db_migration` means a database is involved**
  (`migrateDatabases`, `migrateDataSource`, `applyMigration`,
  `initializeMigration`, `verifyLive`) and nothing else does. `verify`,
  `readChain`, `verifyChain`, `verifyRowTypes` and `collectMigrationFiles` were
  already synchronous.

  The guard test deliberately catches around the bare call rather than using
  `throwsA` over a closure: that matcher awaits a future the closure returns and
  reports its rejection as a throw, so it passes for both forms and cannot pin
  synchronicity. Note that re-`await`ing the results is still legal Dart, so the
  compiler alone does not prevent the drift — the test does.

  **Breaking for callers**: drop the `await`. There are no production call sites
  in the workspace.

- **`TomSchemaDdlReader` derives structure from tokens, not from searching the
  statement text (tcinc487).** `_alterTable` located its action list by
  `statement.indexOf(tableName)`, which finds the *first* occurrence of those
  characters — inside the leading `ALTER TABLE` keywords whenever the name is a
  substring of them. The symptom was the bad kind: not a parse error but a false
  divergence, reporting an unsupported action named after a fragment of a
  keyword while the column was silently never added.

  The todo framed this as an exotic case (a table named `ABLE`). Running the
  tests corrected the premise in both directions. Quoted forms (`` `TABLE` ``,
  `` `ALTER` ``) were **never** broken — the backticks make the token unique in
  the text. But ordinary lowercase DDL on a two-letter table is broken:
  `alter table ab add column b int` finds the `ab` inside `table`. Uppercase DDL
  escapes only because `indexOf` is case-sensitive. The actions now come from
  `words.sublist(3)`, and `_indexAfterWord` is deleted — nothing else used it.

  Mutation testing then found two pre-existing defects of the same shape, both
  fixed here rather than deferred, because each produces the same false-
  divergence symptom:

  - `_primaryKeyColumns` matched `PRIMARY` and `KEY` as whole words. The
    tokenizer keeps a parenthesised group attached to the word before it, so in
    `PRIMARY KEY(a, b)` — no space, which MariaDB accepts — the second token is
    the whole `KEY(a, b)` and matched nothing. The clause was skipped and the
    table came out with no primary key. Keywords are now compared by their head.
  - `_createTable` found its column list with a plain `indexOf('(')`. A bracket
    inside a quoted identifier is a character of a name, not structure, so
    ``CREATE TABLE `w(1)` (id BIGINT)`` split inside the name: the table
    registered as `w` and `1` was read as its column list. Bracket-finding is now
    the single quote-aware `_firstBracket`, shared with `_primaryKeyColumns`.

  Nine tests cover the three paths. See *Structure comes from tokens, never from
  `indexOf`* in `doc/db_migration.md` for the durable rule.

- **`TomDbMigrator.initializeMigration` returns `Future<void>`, and the loaded
  history is ordered in SQL (tcinc486).** The method was declared `Future<int>`
  and documented as returning "the earliest recorded version". It returned
  neither: the value was `versions[0].version` after a client-side sort by
  `installedRank`, which is the version of the row *installed first* — a
  different row from the lowest version the moment migrations are applied out of
  numeric order, which environment tags (C-16) make ordinary. A test written
  against the documented promise, run against a real server with install order
  `3, 1, 2`, reported `Expected: <1>  Actual: <3>`.

  No caller read the value — not `migrateDataSource`, not any test — so the
  choice was between inventing a meaning for a number nobody wants and dropping
  it. It is dropped. `MariadbMigrationAdaptor.versions` already publishes the
  whole applied-version history, which strictly dominates any single int, and
  the interface now says so rather than promising a number it cannot define.
  `versions` is deliberately *not* promoted onto `TomDbMigrator`: there is one
  implementation, and the orchestrator does not read it.

  Mutation testing then found the ordering guarantee was untested for a second
  reason: the `SELECT` carried no `ORDER BY`, and removing the client-side sort
  changed nothing, because InnoDB happens to return this table in
  `installedRank` order — it is the clustered primary key. An accident of the
  storage engine is not a guarantee, so the ordering moved into the statement as
  `ORDER BY installedRank` and the redundant sort was deleted. `versions` is now
  documented as **installation order, oldest first**, and asserted to be so.

- **A missing migrations directory is now the same failure in both tools, and a
  `TomDbMigrationException` in the engine (tcinc485).** The two entry points over
  one tree disagreed about whether the tree being absent was an error at all.
  `TomSchemaConvergenceCheck.checkAll` returned an empty report list — which no
  call site can distinguish from "every pair converged", so a CI gate written as
  `reports.every((r) => r.converged)` passed vacuously on a path that was never
  read. `TomDbMigrations.migrateDatabases` did the opposite and listed the
  directory with no existence check at all, surfacing `PathNotFoundException`: a
  `dart:io` type from outside this module's exception family, carrying no key
  and no mention of migrations, so a caller matching on
  `TomDbMigrationException` saw a mistyped path as an unrelated crash.

  A migrations tree a tool is *told* to walk is an input, not content. Absent,
  it means the configured path is wrong — and tolerating it is the worst
  available answer, because both tools then succeed having done nothing: the
  engine walks zero data sources and returns normally, so the server boots
  reporting migrations complete against a database it never touched.

  Both now abort with `db_migration.migration.migrations_directory_not_found`
  through one shared guard, `TomDbMigrations.requireMigrationsDirectory`, joining
  `collectMigrationFiles` and the name parser as functions the engine and the
  check share so they cannot drift. `migrateDataSource` and `checkSchema` are
  guarded the same way. A **relative** path is reported with what it resolved to
  as well, since its usual cause is the right path read from the wrong working
  directory; an absolute one is already unambiguous and is not repeated. The
  engine checks the path *before* scanning for adaptors, so a wrong path is
  answered by naming the path rather than by "reflection has not been
  initialized".

  Three cases stay deliberately tolerant: an existing but empty root, a
  datasource directory with no schema sub-directories, and a
  `<datasource>/<schema>` pair absent below an existing root. The last is the
  interesting one — `readChain` still yields an empty chain there, because that
  lets the report localise the problem as *every entity missing from the
  migrations*, which is a finding, and producing findings is what the check
  exists for.

  **Breaking, deliberately:** the earlier bar asserting that `checkAll` yields no
  reports for an absent directory has been replaced by one asserting the abort.
  No existing caller is affected — all five servers that call `migrateDatabases`
  read `configuration.databaseMigrationsDirectory`, none overrides the
  `./database_migrations` default, and every one of those directories is
  committed.

- **Two migration files that differ only in extension abort the run instead of
  silently dropping one (tcinc484).** Both halves of the module collected a
  schema directory into a map keyed by basename-without-extension — the engine
  in `migrateDataSource`, the convergence check in `readChain` — so
  `[3]-add_index.sql` and `[3]-add_index.ddl` claimed the same key and whichever
  the directory listing happened to yield last overwrote the other. The run then
  continued as though the tree had always held one file: no record of which of
  the two ran, and no guarantee that a machine enumerating the directory
  differently would make the same choice.

  The sharp edge is the name shape that produces it in practice. An editor or a
  merge leaves `[3]-add_index.orig` beside the real `[3]-add_index.sql`, and
  `.orig` strips to the same basename — so the *backup* could win and the
  migration it backed up never run, with version 3 recorded as applied and the
  backup's checksum stored against it.

  Collection now goes through one shared `TomDbMigrations.collectMigrationFiles`,
  used by the engine and the check alike, which throws
  `db_migration.migration.duplicate_migration_basename` naming both paths in a
  stable (sorted, not listing) order so the same broken tree reports identically
  on every host. This restores the rule the module already applied to every other
  surprise in a migrations directory: an unparseable name aborts rather than
  being skipped, because a stray file there is more likely a migration nobody
  noticed was not running than deliberate clutter. Sharing the collector also
  keeps the check from accepting a tree the engine refuses. No migrations
  directory in the workspace — 45 artifacts across 16 schema directories — is
  affected.

- **`CREATE TABLE … AS SELECT` no longer commits a half-parsed table to the
  replayed schema (tcinc483).** `_createTable` located the column list by the
  first `(` in the statement, which for a `SELECT`-driven create belongs to the
  SELECT rather than to a column list. `CREATE TABLE copy AS SELECT id, name
  FROM src WHERE x = COALESCE(a, b)` therefore read `a, b` as the columns:
  two "unreadable column definition" errors *and* a table `copy` committed with
  no columns at all. `CREATE TABLE copy AS (SELECT id FROM src)` was worse — the
  parenthesised SELECT parses cleanly as a one-entry list, so the reader
  reported nothing and invented a column named `select`, in direct contradiction
  of its own dartdoc promise that such statements "surface as replay errors
  rather than being silently mis-parsed".

  The bogus table did not stay local. It reached the convergence diff, where
  every column the entity model declares on that table became a `missingColumn`
  divergence — a second wave of findings caused by the parse failure and
  pointing away from it.

  Only `CREATE TABLE <name> (<column list>)` is modelled now. Any header
  carrying something between the table name and the column list — `AS SELECT`,
  `AS (SELECT …)`, `LIKE other`, or a vendor extension — is rejected as an
  unsupported form **before the builder is touched**, so an unmodelled statement
  leaves no trace in the schema. Testing for what a supported header *lacks*,
  rather than listing keywords to reject, means the next unknown form fails
  loudly instead of being half-read. Within a genuine column list the opposite
  rule still applies deliberately: an unreadable entry is reported on its own
  and the rest of the table survives, since discarding it would manufacture the
  same derived noise for the sake of one bad entry.

- **An unguarded `DROP TABLE` of a table the chain never created is now
  reported (tcinc482).** `TomSchemaDdlReader` reported an `ALTER TABLE` on a
  table no earlier artifact creates, but `_dropTable` looked the name up and
  dropped it only if present, so the same mistake in a `DROP` replayed clean.
  The two are the same defect — both would fail against a live server — and the
  silence was not local: a mistyped name meant the table the artifact was meant
  to remove stayed standing in the replayed model, and the mistake resurfaced
  much later as a table the entity model has no entity for, a finding that
  points at the entities rather than at the artifact that is actually wrong.

  The reader now applies one rule in every direction: a statement that would
  fail against a real server is a chain defect, and the `IF [NOT] EXISTS` guard
  is what marks it deliberately conditional. `DROP TABLE IF EXISTS` on an
  unknown table stays a silent no-op, exactly as `CREATE TABLE IF NOT EXISTS`
  on a known one does; the unguarded form is reported. `DROP TABLE` also takes
  a list (`DROP TABLE a, b`), and every name in it is now read and dropped —
  previously only the first was, leaving the rest standing in the model to be
  reported downstream as tables with no entity.

- **Two entities that key one table differently are now a reported
  contradiction (tcinc481).** `TomEntitySchemaReader.read` merges the columns of
  several entities mapping the same table — legitimate, since a table is often
  read through more than one projection — but it also called `setPrimaryKey` for
  every one of them, so the *last* entity in the caller's iteration order
  silently replaced the key of every earlier one. A table has exactly one
  primary key, so two projections declaring different keys means one of the two
  declarations is wrong; the check quietly adopted whichever it happened to read
  last and compared *that* against the migration chain. The outcome therefore
  depended on iteration order: the same code base could converge or report a
  `primaryKeyMismatch` naming a key no one was looking at, and in the converging
  order a genuinely wrong entity passed the guard whose entire purpose is to
  catch it.

  The first entity to declare a table now fixes both its reported origin and its
  key; a later entity whose key differs yields the new
  `TomSchemaDivergenceKind.conflictingEntityPrimaryKey`. It is a separate kind
  from `primaryKeyMismatch` because the culprit and the fix differ — that one
  says the entity model and the chain disagree and sends the reader to the
  migration scripts, this one says the entity model disagrees with itself before
  the chain is consulted at all. Keeping the *first* key rather than the last is
  what makes the reported origin and the reported key describe the same entity;
  a union of the two would put a key in the model that neither entity declares
  and provoke a second, invented mismatch against DDL that is correct. The
  verdict is order-independent — both orders report the contradiction — while
  which key survives follows the origin by design.

  `read` consequently returns `({schema, divergences})` rather than a bare
  `TomSchemaModel`, since a self-contradicting entity model is a finding with no
  migration chain involved. The key comparison is now the single `_sameKey`
  used by both this check and the entity-against-DDL diff, so one tolerance
  policy governs every primary-key comparison in the module; its dead
  `isEmpty && isEmpty` early return went with the extraction.

- **A migrator that fails to construct now reports why (tcinc480).** The adaptor
  scan wrapped the reflective `newInstance` call in `catch (error)`, bound the
  error to a variable, and never used it — the raised exception named only the
  candidate class. So the one thing the operator already knew (*which* class)
  was reported and the one thing only the machine knew (*why*) was discarded: a
  missing zero-argument constructor, a throwing field initialiser and a failed
  dependency lookup produced byte-identical messages. This is a startup failure
  on a reflective code path, which is the worst position from which to
  reconstruct a cause by hand. The error is now named in the message and
  forwarded as the exception's root cause, along with the trace from where it
  was thrown — captured at the catch site instead, the trace describes the scan,
  from which the constructor has already unwound. The sibling failure, a
  candidate that is not a `TomDbMigrator`, named nothing at all and now names
  the candidate too.

  The step is extracted as `TomDbMigrations.instantiateMigrator(candidate,
  construct)`, taking the constructor as a callback rather than the reflected
  class: the scan reads a global registry no test can populate, and populating
  it would be worse than untestable — a fixture whose constructor throws would
  break the scan for every real caller.

- **The measured migration duration is no longer discarded (tcinc479).** The
  `<schema>_versioning` table has always had an `executionTimeMs` column,
  `applyMigration` measured the script and wrote it, and
  `initializeMigration`'s SELECT read it back — but `TomDbVersion`, the row type
  the results are mapped onto, had no field for it. The one piece of operational
  data the module goes out of its way to collect was written, selected, and then
  dropped on the floor by the mapper, invisibly: an unmapped column is silently
  ignored, so nothing failed. `TomDbVersion.executionTimeMs` now carries it.

  A second defect on the same value: the stopwatch was read *inside* the `try`,
  after the statement loop, so only a successful script recorded a duration.
  Every failed migration stored a flat `0` — losing the number in exactly the
  case where "how long did it run before it broke?" is the question being asked.
  The clock is now read on both paths.

- **An unreadable stored checksum is reported as its own fact, not as an edited
  migration (tcinc478).** Verifying an already-applied migration compared the
  stored checksum against the script's digest and, when they differed, reported
  `checksum_mismatch` — "the script was edited after it was applied". That is the
  wrong accusation for a value that is not a digest at all, and such values are
  reachable by ordinary means: the versioning DDL declares
  `checksum VARCHAR(200) NOT NULL DEFAULT ''`, so any row inserted by anything
  other than `applyMigration` (a hand-written repair, a partially applied insert,
  an older schema) carries the empty string, and a database written before the
  previous entry's change carries a decimal `String.hashCode`. Every one of those
  sent the operator hunting for an edit that never happened. Before that, the
  same rows escaped the module as a bare `FormatException` from `int.parse`,
  naming neither the schema nor the migration.

  `MariadbMigrationAdaptor.isWellFormedChecksum` — the counterpart of
  `checksumOf`, accepting exactly 64 lowercase hex characters, anchored — now
  gates the comparison. A value that fails it throws with a key of its own,
  `mariadb_migration.apply_migration.checksum_unreadable`, and a message saying
  the row was not written by `applyMigration` and should be recomputed from its
  stored `script`. The two keys carry opposite instructions: `checksum_mismatch`
  means "find the edit", `checksum_unreadable` means "recompute the row".

  All three stability messages (`description_mismatch`, `checksum_unreadable`,
  `checksum_mismatch`) now name the **data source and schema** alongside the
  version. One adaptor instance walks every schema of every data source, so
  "version 0 has changed" was true of a different table in each of them and could
  not be acted on.

- **The migration checksum is a content digest, not `String.hashCode`
  (tcinc477).** `MariadbMigrationAdaptor` recorded each applied migration's
  checksum as the Dart string hash and verified it by parsing the stored value
  back with `int.parse`. Dart guarantees `String.hashCode` only within a single
  run — it may differ across SDK releases, platforms and isolate hash seeds — and
  the value is read back on *every* later startup. Had it ever changed, every row
  already recorded in every deployed database would have become a mismatch at the
  same moment, hard-failing startup with `checksum_mismatch`: a total outage that
  presents as "someone edited a migration", pointing the operator at an edit that
  never happened.

  The checksum is now `MariadbMigrationAdaptor.checksumOf(sql)` — the lowercase
  hex SHA-256 of the script's UTF-8 bytes — and the stability check is a string
  comparison. A digest can be written down, so a test pins a known script to a
  known constant and a change of algorithm fails the suite instead of a fleet of
  databases; it is also reproducible outside Dart (`shasum -a 256`), so an
  operator can compute what the adaptor expects. Dropping `int.parse` fixed a
  second failure on the same line: a stored value that is not a number — an older
  row, a hand-edited one — escaped the module as an unhandled `FormatException`.
  Such rows are now reported as `checksum_unreadable`, per the entry above.

  **Breaking for existing databases.** A `<schema>_versioning` table still
  holding hash-code checksums will fail its stability check on the next run; no
  upgrade shim is provided. Repair by recomputing each row's `checksum` from its
  stored `script`.

- **One SQL lexer, agreeing with the server (tcinc476).** Migration text was
  walked by **five** hand-rolled quote scanners — one in the migration applier,
  four in the DDL reader (`splitStatements`, `stripComments`, `splitTopLevel`,
  `_words`) — and they disagreed with each other and with MariaDB. Each was
  wrong exactly where the other was right: the applier treated a backslash as an
  escape inside *no* quote character, so `'it\'s'` ended the literal early and a
  following semicolon cut the statement in half; the reader treated it as an
  escape inside *every* quote character, so ``CREATE TABLE `bs\` `` swallowed
  its closing backtick and welded the next statement onto it. Neither failure is
  loud — one sends a syntactically broken fragment, the other sends two
  statements as one.

  The scan now lives once, in `TomSqlLexer`, and implements the rules the server
  actually has (verified against a running MariaDB under the default
  `sql_mode`): `''` doubling escapes in all three quote characters, `\'`
  backslash escaping applies to `'` and `"` string literals but **not** to
  backtick identifiers, where a backslash is an ordinary character. There is now
  exactly one statement splitter, `TomSqlLexer.splitStatements`, used by the
  applier directly and by the reader through
  `TomSchemaDdlReader.splitStatements`;
  `MariadbMigrationAdaptor.splitSqlStatements` is gone.

  The splitter **preserves comments**, because a MariaDB executable comment
  (`/*!40101 SET NAMES utf8 */`) is version-gated SQL and dropping it would
  silently discard a statement the migration author wrote. Comment removal stays
  a separate, opt-in step (`TomSchemaDdlReader.stripComments`) taken only by the
  reader, which compares declared structure rather than executing anything.

  All six cells of the escape matrix are pinned by `test/sql_lexer_test.dart`,
  along with comment preservation and `endOfQuotedRun`'s unterminated-run
  contract; the reader keeps its own regression tests for the backtick case it
  used to get wrong. Two reader assertions that had been counting statements
  rather than reading them — and so passed with comment-stripping removed — were
  rewritten to assert exact text.

- **A data source with more than one schema migrates (tcinc475).** The
  migration orchestrator called `reset()` once per *data source* but
  `initializeMigration` once per *schema*, and the MariaDB adaptor refused a
  second initialisation outright — so the second schema aborted the whole run
  with `initialize.initialized_twice`. This is the shape the module's own guide
  and `TomSchemaConvergenceCheck.checkAll` both assume works.

  Removing only that guard would have left the quieter half. A migrator's
  applied-version history belongs to a `(data source, schema)` **pair**: each
  schema keeps its own `<schema>_versioning` table, so two schemas may
  legitimately both be at version 1. The adaptor appended each schema's history
  to the previous one's, so the second schema's version 1 read as already
  applied — its migration silently skipped while the run reported success. Both
  halves are fixed: `reset()` now runs per schema, `initializeMigration`
  rebinds and **replaces** the loaded history rather than adding to it, and
  `applyMigration` refuses
  (`mariadb_migration.apply_migration.not_initialized_for_schema`) to judge a
  migration against a pair it is not bound to. The `_initialized` bool is gone,
  replaced by the pair the instance is bound to — the same check now catches
  the real defect instead of failing a legal use.

  `TomDbMigrations.migrateDataSource` was split out of `migrateDatabases` to
  create a test seam: the reflection-scanned migrator registry is private and
  not injectable, which is why this lifecycle had only ever been exercised
  against a live server and how the defect survived. The per-schema sequence is
  now asserted connection-free against a recording migrator, with a meta-test
  pinning that the fixture tree really holds two schemas so the assertions
  cannot go vacuous; a second fixture schema (deliberately also at version 0)
  covers the cross-contamination end-to-end. Verified by mutation: hoisting
  `reset()` out of the loop, restoring the appending version list, and deleting
  the binding guard each fail the tests that name them.

- **The datasources example's expectations run again (tcinc472).** All nine
  were written as `assert`, and `dart run` leaves assertions disabled — that is
  what its `--enable-asserts` flag is for — so every one of them compiled out
  under the exact command the file's own header documents. The example printed
  a plausible four-step transcript and exited 0 whether or not `TomDbInt.of`
  parsed an int or `p` rendered a placeholder; falsifying a check by hand
  changed nothing. They are now a local `check(bool, String)` that throws, the
  helper's dartdoc records why it is not an `assert`, and
  `test/datasources_test.dart` runs the file under `dart run` requiring exit 0
  with all four steps reported, plus a second test that fails if `assert(`
  reappears. Verified by mutation: falsifying a check now fails the run, and
  restoring the `assert` form fails the guard.

- **A failed `XA START` no longer wedges the data source permanently
  (tcinc450).** `MariaDbXADatasource.startTransaction` mints the branch id
  *before* issuing the command, and the branch id is also the guard the same
  method refuses a second transaction on. When `XA START` failed, the catch path
  logged and returned `false` but left the id set — so every later
  `startTransaction` on that data source threw "There is already an active
  transaction", for a branch the database never opened. The caller had no way
  out: it had just been told the transaction did not begin, so there was nothing
  to roll back. Bug 66 had removed exactly this wedge from `endTransaction` and
  `rollback`; the start path was missed. It now clears the id on failure.

  The lifecycle tests were rebuilt in the same pass, because they were pinning
  the defect rather than the contract. Both drove `rollback` and
  `endTransaction` from a *failed* start, relying on the id it left behind — the
  behaviour being removed. After the fix they still passed while asserting
  against a branch id that was already `null`. They now run against a scripted
  `executeCommand` that can make a start succeed, so the exits are exercised
  with a branch id that genuinely exists. All four exits are covered, the fifth
  test pins that a *successful* `endTransaction` keeps the id (a cleared one
  reaches the driver as the literal `XA COMMIT null;`, which no return-value
  assertion would catch), and a sixth records that the non-XA sibling reaches
  the same contract by raising its flag only after the command succeeds.

- **`tomAppId` is now produced and consumed by the library (tcinc446).** The
  global was documented as "the process-wide application id, set from
  configuration at startup" and was neither. Nothing in `tom_core_server`
  assigned it and nothing read it; instead five applications — `tom_uam_server`
  and the four sample servers — each carried a hand-written `tomAppId = appId;`
  in a `setValues` override, and the library never consulted the value it
  exported.

  All five were also broken, silently and identically. The base constructor
  calls `setValues` first, then assigns `args`; the *subclass* constructor body
  — where an application names itself, `appId = 'auth';` — runs after both. So a
  line inside `setValues` sampled `appId` before it was set, and every one of
  those five servers published the empty string. The write-only global had never
  held a value, which is exactly why nothing reading it was ever missed.

  `tomAppId` is now a **getter** over the configuration this isolate built:

  ```dart
  String get tomAppId => _activeConfiguration?.appId ?? "";
  ```

  The base constructor registers the instance (not its `appId` — at that point
  the subclass body has not run, so there is no value to take a copy of).
  Resolving the field on each read is what makes it correct: a read-at-use
  getter cannot be early. Having no setter is what keeps it that way — an
  application states its name once, in `TomBaseServerConfiguration.appId`, which
  the merge can also supply, so there is no second place to say it and therefore
  no second answer.

  The library reads it in `tomLoggingMiddleware`, whose access line now opens
  with the application id:

  ```text
  [billing] HTTP/1.1 [GET] /tasks http://localhost:8080/tasks 200 null
  ```

  That is the motivating use: the advanced sample runs three servers side by
  side, two with `isolateLogging = false`, and their access lines were
  indistinguishable once collected anywhere in common. The prefix is omitted
  entirely when no `appId` is configured, so a single-server deployment sees the
  line unchanged. `server/server.dart` already imported the configuration
  module, so reading it there adds no dependency edge.

  The five `tomAppId = appId;` lines are gone (each `setValues` override existed
  for that line alone and now holds only its reflection call). Their
  `appId = '…';` assignments were also unconditional, which contradicted the
  `tom_uam_server` comment promising "can be overwritten with
  environment/commandline args"; all five now guard the assignment the way
  `port` is guarded — `if (appId.isEmpty) appId = 'auth';` — so the default
  yields to a configured value instead of overwriting it. `appId` itself gained
  the dartdoc it never had.

- **A failed configuration cast now carries the `TypeError` it caught
  (tcinc443).** `TomConfig._getValue` caught the failed cast, built a fresh
  `Exception` from the key, the type and the value, and dropped the caught
  object and its stack trace. The replacement message is adequate for a scalar
  mismatch and actively misleading for a generic one: a YAML `hosts: [a, b]`
  decodes as `List<dynamic>`, so reading it as `List<String>` fails on the
  *element* type — and the message reported `with value [a, b]`, which is
  exactly what the operator wrote and looks perfectly valid. The only statement
  of the real problem, `List<dynamic> is not a subtype of List<String>`, was
  discarded.

  The path now throws a **`TomConfigurationException`** (new;
  `TomServerException` → `TomException`, so it is a real `Exception` and carries
  the isolate name and request UUID like every other server error). Its `key` is
  `configuration.tom_config.property_type_mismatch`, `parameters` holds the
  `key`, `type` and `value` separately, and the caught `TypeError` is chained as
  `rootException` with its trace in `stack` — the same shape the datasources and
  the endpoints pipeline already used.

  The catch is also narrowed from a bare `catch` to `on TypeError`. Both arms
  assume a failed cast — the widening reads it as "aimed at a `double`", the
  throw reports it as a type mismatch — so a bare catch would apply that reading
  to anything else that ever came to be thrown there. Catching an `Error` is
  deliberate and is why the clause cannot be `on Exception`: a `TypeError`
  normally signals a bug, but this one is raised by data the operator wrote.

- **`TomConfig` now widens a whole number to a `double` (tcinc436).** A YAML
  `rate: 2` or a JSON `"rate": 2` decodes to an `int`, and `_getValue` cast with
  a bare `as T` — so `TomDoubleConfig('rate')` threw "Could not set property of
  type double … with value 2" for a file that is perfectly well formed. A
  configuration file has no way to say "double"; only writing the decimal point
  by hand avoided it, and nothing told the operator that.

  The asymmetry was the real defect: the *reflected* path that fills a
  configuration object's fields already widened an `int` onto a declared
  `double` field (`reflection.dart`'s `_trySetWidenedNumericValue`), so one and
  the same file could fill `FixtureServerConfig.rate` and fail the matching
  `TomDoubleConfig` lookup on the same key. `TomConfig` now widens the same way,
  for `double` and `double?` alike.

  The widening sits **after** the failed cast rather than as a check in front of
  it, which is what keeps it from doing damage elsewhere: `0.0 is T` is also
  true for `num`, `Object` and `dynamic`, where `2 as T` already succeeds and
  the `int` must survive as an `int`. Only a cast that has actually failed can
  have been aimed at a `double`. The converse widening is deliberately absent,
  for the reason the reflector gives for not having it either — narrowing needs
  a rounding policy, and truncating `2.5` discards what the operator wrote, so a
  decimal is still refused for an `int`.

- **`TomBaseServerConfiguration.args` now holds the command line it claims to
  (tcinc435).** The field was declared, documented in two places as "the
  command-line arguments the configuration was built from", and never assigned:
  the constructor forwarded its parameter to `getDefaultValues` and dropped it.
  Every configuration ever built reported an empty invocation, so a caller
  reading `config.args` got a silently empty list rather than an error.

  The constructor now assigns it — **after** `setValues`, which is the half that
  is not obvious. `args` is declared like every other field and is therefore
  reflected, so the generated `setValues` will assign it from a merged key
  spelled `args`, whether that key came from a YAML resource, the environment, a
  `.env` line or an `args=…` argument. That value is a different thing from the
  invocation, and the invocation is the meaning the field promises, so the
  constructor's assignment goes last. The key is still merged and still visible
  in `getDefaultValues`'s result; it simply no longer lands in the field.

  Two consequences are now documented rather than left to be discovered. `args`
  is the one **derived** field on the class — every other field answers "what
  was I told", this one answers "how was I invoked" — so it is not configurable
  and its row in the API mirror says so. And it may hold a **secret**: the
  command line is one of the out-of-band channels a deployment uses to supply
  `smtpPassword`, `smsApiKey` and the rest, so the invocation recorded here can
  contain them verbatim. Log individual fields, never this list.

- **The environment/`TomConfig` boundary is now stated, and the configuration
  example's checks no longer compile out (tcinc433).** The documentation
  described two things separately and never joined them: `getDefaultValues`
  merges the OS environment, `.env` and the command line, and `TomConfig` reads
  the active provider. The natural inference — that a `TomConfig` lookup
  therefore sees an environment variable — is false, and nothing said so. It
  cannot see one: the merge runs over a **copy** of the provider's resources and
  the result populates a configuration object's *fields*, never the provider.
  The isolation is deliberate (it is the bug 62 fix), so the two ways of reading
  such a value are not interchangeable. The dangerous shape is the quiet one:
  `TomConfig.withDefault('DB_PORT', 3306)` does not throw against an unmerged
  key, it answers `3306` as though the environment had said nothing, because an
  unmerged key is indistinguishable from an absent one.

  The boundary is now stated where each reader meets it — the `TomConfig` class
  doc, and `doc/configuration.md` under both *Typed Property Access* and *Source
  Precedence* — each with the one line that joins the two stores, installing the
  merged map as the provider. `example/configuration/configuration_example.dart`
  demonstrates both halves as steps 7 and 8: `PATH`, which every platform sets,
  failing to resolve, then resolving after the install.

  The example carried the same defect as the cmdline one below: all six of its
  checks were `assert`, and its header tells the reader to run it with
  `dart run`, which leaves assertions **disabled**. Every check was inert. They
  now run through the same throwing `check(ok, expectation)` helper, and
  `test/configuration_test.dart` runs the example under exactly the documented
  command, requires exit 0, derives the numbered-step count from the source
  rather than a literal, and fails if an `assert(` reappears.

- **The cmdline example's checks no longer compile out under the command it
  documents (tcinc426).** `example/cmdline/cmdline_example.dart` stated all
  eight of its expectations with `assert`, and its own header tells the reader
  to run it with `dart run` — which leaves assertions **disabled**. Every check
  in the file was inert: the example printed a plausible five-step transcript
  and exited 0 whether or not a single one of them held, so it demonstrated the
  module without establishing anything about it.

  The expectations now run through a throwing `check(ok, expectation)` helper,
  which holds however the file is invoked and names the expectation that failed.
  Nothing ran the example either, so `test/cmdline_test.dart` now executes it
  under exactly the documented command and requires exit 0, asserts that all
  five numbered steps reported, and fails if an `assert(` reappears in the
  source — the regression that would silently hollow it out again. A third test
  extracts the `dart` block under the module readme's "Quick start" heading and
  runs that as well, pinning the four values its trailing comments promise.

- **An argument with an empty key is now skipped, as in a `.env` file
  (tcinc424).** `TomEnvFile.parse` has always dropped a line whose key is empty,
  but `TomArgs` had no equivalent guard: `parseArgsToMap([''])` returned
  `{'': true}` and `parseArgsToMap(['=orphan'])` returned `{'': 'orphan'}`,
  using the empty string as a name. The two sources are documented as one
  syntax, so the same text meant different things depending on where it arrived
  from, and nothing recorded the difference.

  `_parseArgs` — through which both `fillFromArgs` and `parseArgsToMap` run —
  now skips an entry whose key is empty. The reflection path decides which way
  round the two should agree: an empty key can never match a Dart field, so such
  an entry only ever reached `tomReflectionInfo.setValues` to be ignored there.
  The entry is dropped on its own, not fatally, so
  `['name=svc', '=orphan', 'port=8080']` still yields `{'name': 'svc', 'port':
  8080}`. "Empty" means literally empty: a whitespace-only key remains a key to
  `TomArgs` and an empty line to `TomEnvFile`, which is the separate
  whitespace-trimming difference between the two parsers.

- **A digit run too large for an `int` no longer aborts the parse (tcinc420).**
  `TomArgs` decided a value was an integer from its shape (`[0-9]+`) and then
  called `int.parse` with no guard. The pattern constrains shape, not magnitude,
  and Dart's `int` is 64-bit, so the two part company at `9223372036854775807`:
  above it `int.parse` threw `FormatException: Positive input exceeds the limit
  of integer`, naming neither the key nor the source. Because every entry point
  funnels through one converter, the whole parse went down with it — a single
  account number in a `.env` file cost every other line, and one in `argv` cost
  every other argument. None of the four conversion tables mentioned a limit, so
  a reader had no reason to expect one.

  An oversized run now stays a `String`, which is the answer the table already
  gives `-5`, `12px` and `1.2.3`: not an error, just a value the converter
  cannot represent as a number. It is also what the caller wanted, since the
  values that overflow are labels spelled in digits — an account number, a
  device identifier, a phone number written without punctuation. The limit is
  stated in all four conversion tables. The `double` branch was checked and
  needs no equivalent guard: `double.parse` saturates to `Infinity` rather than
  throwing. Six tests pin it across all three entry points, including both sides
  of the boundary.

- **An unbalanced quote no longer crashes or truncates a value (tcinc418,
  tcinc419).** Both parsers unquoted by dropping the first and last character
  on the strength of the *opening* quote alone. For the one-character value
  `"` that asks for `substring(1, 0)`, so `TomArgs.parseArgsToMap(['K="'])` and
  `TomEnvFile.parse(['K="'])` each raised an unhandled `RangeError (end):
  Invalid value: Only valid value is 1: 0` — a stray quote on a launch command
  or in a `.env` file aborted server start-up with a `dart:core` error naming
  neither the key nor the file, and on the `.env` path it took every line after
  it down as well.

  The crash was hiding a quieter defect of the same origin: with no closing
  quote there is nothing to strip, but the last character was dropped anyway,
  so `K="hello` silently became `hell`, `K="abc` became `ab`, and a mismatched
  `K="hello'` became `hello`. A truncated password or host name is worse than a
  crash, because nothing reports it — and `K="a b` became `a `, corruption that
  ends in whitespace and so survives a visual check of a log line.

  The `.env` parser had the right test locally, requiring *both* ends to match,
  and was corrupted anyway: a value its own check correctly declined fell
  through to the shared converter, which unquoted on the opening character
  alone. Getting the rule right in one of the two places it lived was not
  enough.

  Quotes are now stripped only as a **matched pair** — at least two characters,
  opening with `"` or `'` and closing with that same character. Everything else
  is data, not a syntax error, and passes through verbatim; `""` still unquotes
  to the empty string. The rule lives in one new public method,
  `TomArgs.unquote`, which `TomEnvFile.parse` also decides through, so the two
  sources cannot disagree about what counts as quoted — the same
  extract-the-shared-rule treatment that tcinc415 gave the `=` split. Thirteen
  tests pin it across all three entry points, and they were checked against the
  old rule to confirm they fail on it rather than merely passing on the new one.

- **A command-line argument value containing a second `=` is no longer
  truncated (tcinc415).** `TomArgs.fillFromArgs` and `TomArgs.parseArgsToMap`
  both split on every `=` and kept the second segment, so a value was cut at its
  second `=` and the remainder dropped without a diagnostic:
  `parseArgsToMap(['url=mysql://h/db?user=root'])` yielded
  `{url: mysql://h/db?user}`, and `secret=YWJjZA==` lost its base64 padding. The
  values affected are exactly those a server is configured with — connection
  strings, URLs with a query, encoded keys.

  It was also asymmetric: `TomEnvFile.parse` has always split on the first `=`
  and kept such a value whole, so the same text meant different things on the
  command line and in a `.env` file, though the two are documented as one
  syntax. `TomArgs` now splits at the first `=` as well.

  The two entry points held byte-identical parsing loops — the same defect in
  two places — so the loop was extracted into one private helper that both use,
  which is what keeps them from drifting apart again. Five tests pin the
  behaviour, including a differential check that the argument parser and the
  `.env` parser agree on where the key ends.

### Documentation

- **`TomTextLocale.toString` returns the bundle key, and the summary did not say
  so (tcinc633).** The methods table listed `fromPrincipal` and the
  `operator ==` / `hashCode` pair but not `toString`, which returns the tag. A
  reader who assumes the default `Instance of 'TomTextLocale'` either writes
  `.tag` at every interpolation or stops interpolating and loses the diagnostic —
  and `'$locale'` in a log line or an exception message names the exact bundle
  key that was looked up.

  The omission turned out to be **policy, not oversight**: `_universalMembers` in
  `api_reference_coverage_test.dart` exempts `toString`, `hashCode`,
  `noSuchMethod` and `runtimeType` from being demanded of a class section, on the
  argument that an override of one adds nothing a caller could not already assume
  — thirty-five classes in this package override `toString` with no row. That
  argument holds where the override is a debug rendering and fails here, because
  the *value* is the API rather than the member. The row is added, the exemption's
  dartdoc now records that it exempts rather than forbids and says which class is
  the exception, and a test pins the row so that a later consistency pass against
  `_universalMembers` does not delete it in good faith.

- **Constructing a bundle set validates its keys, and nothing said so
  (tcinc631).** Both `TomLocalizedTextResources` constructors normalise keys
  through `TomTextLocale.parse`, which reaches the empty-language check — so a
  bundle map with a blank key throws `TomResourceLocaleException` at
  construction. The dartdoc for both, the API summary and the guide all
  described the normalisation and stopped there, leaving the throw to be met
  rather than expected.

  Documented on both constructors, in `api_summary_resources.md` and in
  `doc/resources.md`, and stated precisely rather than loosely: the *only*
  unparseable key is one naming no language — `''`, `'   '`, or a leading empty
  subtag such as `_AT`. Everything else parses, because `parse` finds the region
  by shape and drops what cannot be one; `es-419` and `en_XX` normalise to `es`
  and `en` rather than being refused. Saying "an invalid tag throws" would have
  been wrong in the commoner direction and sent a reader looking for validation
  that is not there.

  It matters because of where keys come from: the documented pattern derives
  them from file names, so a stray `text_.yaml` is a **bootstrap** failure whose
  message names a locale and not the file. The exception table now attributes
  the throw to the bundle-set constructors as well as to `TomTextLocale`, since
  a deployment can meet `resources.locale.empty_language` having never mentioned
  `TomTextLocale`.

  Normalising into a map has a second, quieter consequence now documented
  alongside: two keys can name one locale and the last wins silently
  (`{'en': …, 'en_XX': …}` is a single `en` bundle). Left as behaviour rather
  than made an error — `de-AT` and `de_AT` collapsing *is* the intent — but it
  is invisible when the second key was believed to be a separate variant.

  Four tests pin all of it, including `ofProviders` directly: the factory
  delegates to it, so a deployment loading bundles from a database reaches only
  that path and was relying on an untested one.

  The class dartdoc's own example built bundles with `loadYaml(...)`, the same
  fault tcinc630 fixed in `doc/resources.md` and in the same example — that
  sweep covered `doc/*.md` and the README, not dartdoc fences in `lib/`. Now
  corrected to `TomYaml.loadYamlFile`, and the sweep extended: 35 `dart` fences
  in library dartdoc, 34 distinct bare names, 2 unresolved and both legitimate
  (Shelf's real `logRequests()`, and `MyDirectory()`, plainly the reader's own
  class). Worth recording that this sweep would *not* have caught `loadYaml`:
  it is a real function in `package:yaml`, merely the wrong one for the argument.
  Name resolution finds invented names, not misused real ones.

- **The resources guide installed bundles with `loadYamlMap`, a function that
  exists nowhere in the workspace (tcinc630).** `doc/resources.md`'s "Installing
  a Bundle Set" example read `'en': loadYamlMap('resources/text_en.yaml')`. The
  real function is `TomYaml.loadYamlFile`, which is what the only real
  deployment uses (`advanced_ops_server`'s `ops_texts.dart`). The example is the
  one place a reader copies verbatim, so an invented name there fails at compile
  time on the first thing anyone tries.

  It could not be corrected from the page either: the guide's own Dependencies
  section listed four modules and did not name **configuration**, the module the
  loader comes from, so a reader had nothing to look it up against. Both are
  fixed — the fence calls `TomYaml.loadYamlFile`, and Dependencies names the
  configuration module as the source, with the reason the tier's usual loader is
  worth preferring over any other: it expands `${VAR}` and `${VAR:default}` from
  the environment, so a bundle can carry a deployment-specific support address
  without a second mechanism. That expansion requires the `$` sigil, so the
  module's own bare `{name}` parameters pass through it untouched. The paragraph
  also points at `ops_texts.dart`'s `existsSync` check, because `loadYamlFile`
  throws a bare `PathNotFoundException` and a bundle missing from a container
  image deserves a message naming the path.

  An invented name rarely travels alone, so every `dart` fence in the package's
  twenty module guides and README was swept — 98 distinct bare calls resolved
  against the workspace. Seven did not resolve and six of those are legitimate:
  three are defined inside their own fence (`salesCsv`, `mergeYamlIfPresent`,
  `listReports`) and three are plainly the reader's application code
  (`buildSalesResult`, `gradeForTask`, `promptForCode`). `loadYamlMap` was the
  only name in the position where the framework supplies the value. No standing
  guard was added for this: one defect in 98 is too thin to carry an allowlist,
  and the discriminator that matters — framework API versus the reader's own
  code — is a judgement no filename-matching test can make.

- **`resources` was the only one of the twenty server modules with no mention at
  all in the package README (tcinc627).** The platform-services heading named
  thirteen of the fourteen modules that belong to it and the table beneath it
  carried a row for each of those thirteen, so a reader counting modules got
  nineteen where there are twenty — and got no signal that they had. The module
  is exported from the barrel, has a guide, has an API summary, and has four
  in-library consumers; only the front door did not know it existed. It now has
  a place in the heading and a row naming `TomTextLocale`,
  `TomLocalizedTextResources` and `TomResourceLocaleException`, and the Overview
  mentions per-recipient localized text beside the messaging it serves.

  The recount is now a test rather than a chore.
  `api_reference_coverage_test.dart` checks both directions — every module
  directory is named in the README's Features section, and every row in the
  module table names a directory that exists — following the same reasoning as
  the summary checks it sits beside: a stale row is worse than a missing one,
  because a reader cannot tell it from a current one. The check is scoped to the
  Features section deliberately. Module names are ordinary English words and the
  rest of the README uses them as such: `resources` occurs four times elsewhere
  in the file, every one of them "YAML resources" or the kernel's, so a check
  counting occurrences file-wide would have reported the one genuinely missing
  module as present.

  The `## Status` block's version, test count, suite count and `db`-tagged count
  had all drifted (1.1.4/1726/56/243 against an actual 1.3.0/3491/91/421) and
  were corrected in passing. Whether an unchecked precise number belongs there
  at all is tracked separately as tcincb153.

- **`resolveLocale` answering `null` was documented as "the set carries nothing
  at all", which is false for every non-empty set whose chain misses
  (tcinc624).** `null` means no bundle in the *chain* exists. A set built with
  `bundles: {'fr': ...}` and a default of `en` reports `locales == ['fr']` and
  still answers `null` for `de`, because the chain for `de` is `[de, en]` and
  neither is carried. The behaviour is right; three artefacts described it
  wrongly and a fourth never described it at all — while `textOrNull`, two
  methods below in the same class, had it correct ("`null` when no bundle in the
  chain has the key"), so the class disagreed with itself. All four now state
  the chain rule, and each goes one step further than the correction: because
  every chain ends with `defaultLocale`'s own tags, `null` says *precisely* that
  the set carries no bundle for its default locale. That is the sentence worth
  having. The documented `resolveLocale(requested) ?? defaultLocale` for a
  `Content-Language` header reads as dead code to anyone who took `null` for
  "empty set", when it is the branch that fires on exactly that wiring fault and
  declares a language nothing was rendered in. Two tests now pin the method,
  which previously had none of its own: the chain's first landing (`de_AT`
  exact, `de_CH` to bare `de`, no locale to the default) and the non-empty-set
  miss.
- **The localized-resources fallback chain was documented as ending in English,
  which is a language the class has no notion of (tcinc623).** The library
  dartdoc and `doc/resources.md` both said a half-translated bundle "falls
  through to English for the rest"; `defaultLocale` is a required constructor
  argument with no framework-supplied value, and `_chain` appends whatever the
  deployment named — so a server whose default is `fr` falls through to French.
  Each of the two passages contradicted itself two lines away, the dartdoc in
  its own numbered step 3 ("the default locale's tag") and the module document
  in its own code comment ("else the default locale"). The same paragraph exists
  in four artefacts and two of them were already right, so this was a doc-vs-doc
  split rather than a shared misunderstanding. Both now name the default locale,
  and each gains a paragraph stating that the destination is a required argument
  — a bare word swap would leave the stated harm untouched, which is that a
  reader takes the sentence at face value and never passes a `defaultLocale`
  they actually want. The executable half of the same defect is also closed: all
  eleven `TomLocalizedTextResources` tests ran against an `en`-defaulted fixture
  and asserted English strings, so an implementation with English built into it
  would have passed every one of them. A twelfth test builds a French-defaulted
  set carrying no English bundle at all, which is the only arrangement in which
  "the configured default" and "English" give different answers.
- **The `preferences` module readme's quick start printed a value it could not
  reach (tcinc620).** The snippet was a complete `main()` ending
  `print(timezone); // Europe/Berlin`, but three preconditions were missing and
  every one of them failed at the *bootstrap* line rather than at the call the
  reader was reading it for: without `initializeReflection()` the repository
  constructor throws `annotation_analyzer.analyse_persistent_type.mirror_not_found`,
  because it reads the entity's annotations through its class mirror; without a
  datasource registered under the name the entity declares (`main`) it throws
  `crud_repository.constructor.datasource_not_registered`, since
  `TomSqlDatasourceRepository` resolves the datasource in its constructor and
  not on first query; and outside a zone carrying a `TomPrincipal` both `set`
  and `getOr` throw `preferences.no_principal`. The last was the sharpest,
  because the snippet's own comment said "the caller is the zone's principal"
  while establishing no zone. The quick start now shows all three as numbered
  steps and wraps the calls in `runZoned`, so the printed value is truthful for
  a reader who has the database this module inherently needs — the standard the
  `datasources` quick start already sets. Requiring a database was never the
  defect; claiming output without saying what the output depends on was.
  Verified by analyzing the snippet as written (clean) and formatted with
  `dart format`, so it does not drift from house style.

- **`doc/preferences.md` named the module's public types twice and both lists
  were short (tcinc619).** The Overview table carried five of six, omitting
  `TomUserPreferencesErrorHandler`; Core Components carried four, omitting that
  and `TomUserPreferenceException`. The error handler is the odd one to lose,
  because the document spends its longest section on it — the argument that
  `preferences.not_found` is a `404`, `preferences.key.invalid` a `400`, and
  nothing else is either — so a reader scanning for "what is in this module"
  did not find the type its most-discussed behaviour lives in. The module
  readme, `api_summary_preferences.md` and the completion document all listed
  six; `doc/preferences.md` was the only one of the four that did not. Both
  lists now name all six, in the order the siblings use, and the two new Core
  Components entries give the reason each type exists rather than restating its
  name.

- **Twenty-two documented constructors typed an exception's `stack` parameter
  as `Object?` where it is `StackTrace?` (tcinc617).** The mistake is a natural
  one, and the summaries were split roughly evenly between the two spellings,
  so neither side looked obviously wrong. `TomBaseException` — in `tom_basics`,
  two classes above anything documented here — declares the *field* as
  `Object?`, and every exception in this package reaches it by forwarding
  `super.stack`. What the forwarding chain passes through, though, is
  `TomException`, whose own constructor narrows the parameter to `StackTrace?`;
  a `super.stack` therefore inherits `StackTrace?`, not the field's type.
  Reading the field's declaration rather than the constructor's is what
  produced the wider spelling.

  It was not a harmless imprecision. `Object?` invites a reader to believe the
  API takes any error payload an isolate or a bridged frame might hand it, and
  the code that would follow from that belief does not compile — the analyzer
  rejects a non-`StackTrace` argument at every one of these constructors. It
  also points the reader at `TomBaseException._getStackTrace`, which casts with
  a bare `s as StackTrace?` and would throw on precisely the value the wider
  type appeared to permit.

  Corrected across `endpoints`, `messaging`, `datasources`, `authentication`,
  `db_migration`, `transactions`, `cache`, `audit`, `export`, `file_storage`,
  `authorization`, `resources` and `little_things` (and, in `tom_core_kernel`,
  `reflection`). `preferences` already had it right and now says why, together
  with the related point that omitting `stack` does not leave the exception
  without a trace: `TomException` substitutes `StackTrace.current` for a
  missing or null argument, in its own constructor, so the trace still reaches
  the `throw` site.

- **`findMirror`'s `null` was documented as "unregistered" without saying it
  meant only that (tcinc605).** `object_persistence.md` and the API summary
  described the answer but not the boundary, so a reader had no way to know
  which failures were folded into it. Both now carry the three-outcome rule —
  the one tolerated cause, and the two faults that are reported instead of
  disguised as it — with the reason the distinction is worth the words: a
  swallowed reflection error reappears as "it is not in `tomReflector`", which
  sends the reader to the entity's annotations and its generated file, neither
  of which is at fault. The exceptions table and the `analysePersistentType`
  entry say which exception now travels out of which lookup.

- **The documented way to discard a resolution was to reach into the memos
  (tcinc604).** `object_persistence.md` and the API summary said the memos are
  private and cannot be cleared at all; with `reset()` that second half stopped
  being true. Both now describe `reset()` as the single, all-or-nothing route,
  and say why it is all-or-nothing: the six memos are
  derived from one another, so clearing a subset leaves the rest describing an
  entity that no longer exists. Both also name the caller it exists for — a test
  re-registering an already-analysed fixture type — so nobody reads it as
  something a server should do between requests.

- **The metadata caches were documented as storage rather than as a contract
  (tcinc603).** `object_persistence.md` and the API summary listed the six memo
  maps by name and type and said they hold resolved results — true, and beside
  the point. What a reader needs is the consequence: the answers are shared, so
  the metadata is free after the first use *and* nothing about it may be edited.
  Both documents now state that, and say what enforces it — `final` fields,
  unmodifiable lists, private memos — instead of enumerating six maps a caller
  can no longer reach. `TomColumnInformation`'s summary gains the same reason on
  its properties, and its constructor note explains why `fileReference` is the
  one named parameter in terms of what it is, not of when it arrived.

- **Shipped text pointed at things only this workspace can open (tcinc602).**
  Eight places in `lib/` and `doc/` sent the reader after something that does
  not exist outside the repository that produced it: a todo id (`RCK13` in the
  `TomCountResult` dartdoc), a quest reference (`TomJoinTable`, the
  `TomTabularResult` rationale, three `## Not Yet Implemented` sections), or an
  unnamed follow-up (`TomQuerySentenceCompiler`). A dartdoc reaches the IDE and
  the generated API pages; `doc/` is published documentation. Such a pointer is
  worse than silence — it costs a lookup and then leaves the reader unable to
  tell whether the thing is planned, abandoned, or already done elsewhere.

  Each site now states the current behaviour and why, which in every case turned
  out to be the more useful sentence:

  - `TomCountResult` says that the field *name* is the entire binding and is
    checked nowhere, so renaming it makes every count report an empty table
    instead of failing.
  - `TomJoinTable` says that nothing outside its own declaration reads the type,
    so annotating an entity has no effect at all — not a partial one, and not a
    failure either — and a many-to-many association has to be traversed by
    querying the join table. The API summary was brought into line.
  - `TomQuerySentenceCompiler` says which options each kind actually accepts (a
    find and a group take cap, skip and sort; a delete takes cap and sort but no
    skip, because `DELETE` has no `OFFSET`; a count takes none, because it
    returns one row regardless) and that an unaccepted combination is refused
    with a reason rather than accepted and ignored.
  - `TomTabularResult` says the CE-RP envelope is a `tom_core_codespecs` gap
    class named by the mapping and not written, dropping who owns the writing.
  - The `## Not Yet Implemented` sections of `object_persistence.md`,
    `server.md` and `endpoints.md` say what the reader can observe: which
    entries are declared and therefore *look* available, and that the server
    module ships no type, export or placeholder for the capabilities it lists.

  Two long comments in `query_sentence_compiler.dart` narrated a former defect
  in the past tense. Both now argue the current design forward — why a boolean
  operand is parsed at operand level rather than statement level, and why the
  early-end sentence is refused explicitly rather than left to raise a
  `TypeError` outside this library's exception family. The counterfactual says
  everything the history did, and stays true as the file changes.

- **The object-persistence quick start taught a primary key that can never be
  inserted (tcinc601).** The entity in
  `lib/src/tomserver/object_persistence/readme.md` declared `int id = 0;` under
  `@TomEntityId`. `save` picks `INSERT` over `UPDATE` by asking `isUnsavedKey`,
  which accepts a `null` key or a negative one and nothing else — `0` is
  deliberately not a sentinel, because it is a legitimate key in a table that
  assigns its own ids and treating it as "unsaved" would make the row with id
  `0` unsavable. So an entity copied from this readme took the *update* arm on
  its very first save, issued an `UPDATE` matching no row, and persisted
  nothing. It raised nothing and the analyzer said nothing. A module readme is
  the shortest thing a newcomer reads and the thing they paste, so this was the
  worst place in the package for the shape to be.

  The entity now declares `int? id;`, with the reasoning inline where the field
  is — a reader who copies the block copies the explanation with it. The guide
  gained the matching paragraph in **Mapping an Entity**, immediately after its
  own entity example, stating the `isUnsavedKey` rule and the `int id = -1;`
  alternative for a key that must be non-nullable. Both say plainly that the
  failure is silent, because that is what makes the shape worth a paragraph
  rather than a footnote. A sweep of every `*.md` and `*.dart` in the workspace
  found no second occurrence: the documented entities already declare `int?
  id;`, and the framework's own non-nullable keys default to `-1`.

- **The object-persistence guide described one of the module's two authorization
  controls and neither of its file columns (tcinc600).**
  `doc/object_persistence.md` had a full treatment of row scopes (C-3) and, of
  column grades (C-4), one incidental clause inside the Grouping section — where
  the *exception* is documented (a grouped query is refused rather than masked)
  without the rule it is an exception to. `@TomFileReference` appeared nowhere at
  all: not the annotation, not `cascadeDelete`, not `exposed`, not the key
  scheme, not the four repository methods. A reader following this guide would
  map an entity, scope its rows, and have no way to learn that a column can be
  graded or that a column can hold a file.

  Two new sections close it. **Column Authorization** covers the four-state
  grade (`none < disabled < read < full`), read masking and the nullability it
  forces on graded fields, and the write partition — including why a refused
  change to a *visible* column is named while a refused change to a *masked* one
  is silently overlaid from the stored value: a masked column reads back `null`,
  so rejecting it would fail every ordinary round trip on a column the caller
  cannot know exists. It ends on `TomRowColumnAuthorization`, why only the file
  operations consult it, and why `applyReadMask` skips a per-row column rather
  than guessing. **File-Reference Columns** covers the five annotation fields
  with their defaults, the `<keyPrefix>/<yyyy>/<mm>/<uuid><.ext>` key scheme and
  the reason for each part, the `TomFileRepository` contract, the
  upload-then-save ordering (an orphaned blob is collectable; a dangling
  reference is repairable only by hand), the by-construction authorization story,
  and the three details that keep `cascadeDelete` from deleting a live blob. Both
  are in the table of contents, the Overview table and Core Components, and the
  Grouping section's column-rights clause now links back to the rule.

- **`TomSortDirection` was named in three places and its values written down in
  none (tcinc599).** The summary's Enums section had already stopped claiming
  the module declares none, but what replaced the claim was a pointer, and what
  it pointed at was two sentences of prose. An enum is the one kind of type
  whose values *are* its whole contract, so a reader arriving at either place
  still could not learn what `ascending` and `descending` render as without
  opening `paging.dart`. It now has the table every other documented enum in
  this package has, giving each value its `sqlKeyword`, plus a Properties row
  stating that the getter is the only rendering — a dialect never spells
  `ASC`/`DESC` itself.

  It stays filed beside the `TomSortField` that carries it rather than moving
  under `## Enums`, because a direction is only ever met as one term's
  direction; the Enums section carries a one-row index instead. The distinction
  is deliberate and stated in the document: the row is an index, the linked
  section is the documentation, and the values are written once.

- **The `object_persistence` summary documented row scoping as something you
  annotate, having omitted every member that makes it automatic (tcinc598).**
  Three class sections were short, and the gaps were one omission seen three
  times. `TomAnnotationAnalyzer` was missing `autoScopeFor` — the method that
  synthesizes a `@TomDbScope` for any entity carrying a resource key — along
  with the three constants it decides by (`resourceKeyColumn`,
  `resourceKeyField`, `resourceScopeInputTables`); `TomDbScope` was missing
  `resourceScope`, `noScope`, the `unscoped()` constructor and `isOptOut`, which
  is the entire opt-out half of the mechanism; and `TomDataScope` was missing
  `allowedValuesAsync`, the async resolver path the grant scope actually runs
  on. A reader could follow all three sections and conclude that an entity
  without `@TomDbScope` is unscoped — the opposite of what the analyzer does,
  and the wrong direction to be wrong in for a rule about who sees which rows.

  `resourceScopeInputTables` now carries its reason rather than just its value:
  the three authorization tables it excludes each hold a resource key, so
  without the guard each would scope itself, and a principal could reach its own
  grant rows only by already holding a grant on them. The summary also states
  why the set duplicates names the entities already declare — it is the half
  that survives a stale generated `*.reflection.dart`, and an invariant of this
  kind must not depend on a deployment having re-run code generation first.

  The analyzer's Properties table listed five caches while the prose implied
  six; `fileColumnCache` is now there, and `TomAnnotationAnalyzer` gained the
  `findFileColumns`, `familyOf` and `describeDeclaredType` methods it also
  lacked. With that, `object_persistence` leaves
  `_memberListsPendingReconciliation` and its class sections are checked.

- **The `object_persistence` API summary documented ten of its twelve source
  files, and with them omitted the whole file-slot feature (tcinc597).**
  `file_reference.dart` and `paging.dart` were missing from the `Source:` list,
  and the first omission was not cosmetic: `TomFileReferenceKeys`,
  `TomFileRepository` and `TomResourceScopeSource` had no section anywhere, and
  `TomFileReference` appeared only incidentally as a field's type inside another
  class's table, which is a mention rather than documentation. A reader looking
  for how to attach a blob to an entity found nothing, and the `Paging &
  Sorting` types were absent from the table of contents besides. The summary now
  carries a `File References` section covering all four types — including why
  the split is three (a declaration, a key scheme, a repository mixin) and the
  four-part key shape `TomFileReferenceKeys.generate` produces — plus a
  `TomResourceScopeSource` section stating the dependency inversion that lets
  persistence offer a grant-driven row scope without depending on the
  authorization layer.

  Reconciling the list closed the last debt in one of the coverage suite's
  quarantines, so `_apiNamesPendingReconciliation` and the `skip:` consulting it
  are **deleted** rather than left empty: an empty quarantine keeps a `skip:`
  that can never fire and a staleness meta-test that can never fail, which is a
  dead rule the next reader cannot recognise as dead. `no summary omits a name
  its module exports` now runs unquarantined across every module.

  `api_summary_authorization.md` attributed `TomResourceScopeSource` to
  `tom_core_kernel` in three places; the kernel has no type of that name — it is
  declared in this package, in `object_persistence/data_scope.dart`. Adjacent
  errors fixed while there: `TomDataScopeRegistry`'s prose named two of its three
  built-in resolvers, its static table omitted `writeResolverFor` and
  `asyncWriteResolverFor`, its `register`/`registerAsync` signatures dropped the
  `write:` parameter, and the static `resourceScopeSource` property was
  undocumented.

- **`TomPersistenceEventHandler`'s dartdoc said the annotation was undetected
  when it is detected (tcinc596).** It read "declared for future use — the
  persistence layer does not yet detect or invoke these callbacks", but
  `TomAnnotationAnalyzer` does resolve the annotation, onto
  `TomColumnInformation.eventHandler`. That is the wrong direction to be wrong
  in: a reader concludes the annotation is inert metadata when it is in fact
  live and reachable, and stops looking for the property that already carries
  it. The dartdoc now states the true position — resolved, stored, and then
  read by nothing, so none of `prePersist`, `postPersist`, `preLoad` or
  `postLoad` ever fires — and adds a fact neither the old text nor
  `doc/object_persistence.md` mentioned: resolution is *field-level*. The
  analyzer reads metadata off a `VariableMirror`, so although the callbacks
  take the whole entity, an annotation placed on a class declaration is not
  seen at all. `TomColumnInformation.eventHandler` and the API summary say the
  same.

  Prose cannot be kept true by remembering to update it — this pair drifted
  apart exactly once already, when the analyzer began resolving the annotation
  and the dartdoc did not follow. Three source guards in
  `object_persistence_test.dart` now pin both halves against `lib/`: that the
  analyzer still resolves it, that no library file invokes a callback, and that
  nothing reads the resolved handler back. Implementing the callbacks fails
  these tests, and the failure names the prose that then has to change.

- **The messaging example demonstrated none of the layer applications actually
  use (tcinc583).** `example/messaging/messaging_example.dart` composes a
  `TomMessage` by hand throughout — that is the substrate, and it is the part
  most application code should not touch, for the same reason most application
  code does not write SQL strings. Neither `TomEmailService` nor `TomSmsService`
  appeared anywhere in it, so the module's whole templated layer, and the SMS
  channel with it, had no runnable demonstration: a reader who wanted to send an
  application email had the one file that shows how not to.

  A second example, `example/messaging/messaging_templated_example.dart`, now
  covers that layer in twelve steps. A request carries a template key rather
  than a body, and the type enforces it — `TomEmailRequest` has no `subject`
  field, so a user-facing string cannot be passed even by accident. Rendering
  resolves the three sub-keys, in the recipient's locale, with a key the second
  bundle lacks falling back to the default rather than rendering blank, and a
  missing sub-key throwing at render — before the outbox is touched — while
  naming the exact resource key that is absent. `toPrincipal` derives the
  address, display name and locale that every send site would otherwise
  re-derive. SMS is the same rule with one sub-key plus the concern email has no
  equivalent of: a single accented character moves a message from GSM-7 to
  UCS-2 and halves the room in a segment, so a *parameter* can change what a
  message costs while its template did not, and the service cap refuses the
  over-long message at render rather than on next month's invoice. The last
  four steps are the seam: both services queue on one outbox, one tick delivers
  both, and only then does a vendor appear — a `TomSmsTransport` with a
  `TomFieldMappedSmsProtocol`, driven over a scripted channel so that one dead
  number among two can be shown to be a partial delivery rather than a failure,
  and a rate limit to be thrown for retry rather than recorded as a rejection.
  A real gateway will produce neither on demand, which is why the seam exists.

  `doc/messaging.md` gained the `Verification` section it lacked, naming the
  four suites that cover the module and both examples with what each step shows,
  so a reader asking what substantiates the document has an answer in it. That
  settles messaging's entry in `api_reference_coverage_test.dart`'s attribution
  quarantine, which is now dropped — the module is checked rather than skipped.
  The "runs green" guard in `test/messaging_test.dart` was made a function taking
  the example path and its step count, since there are now two examples needing
  the identical pair of tests; both are run under plain `dart run`, both must
  exit 0 with every numbered step reported, and both must state their
  expectations through a throwing `check` rather than `assert`, which `dart run`
  compiles out.

- **A messaging completion-document sample claimed output `toString()` does not
  emit (tcinc579).** The segmentation passage printed the object —
  `print(TomSmsSegmentation.of('Your code is 123456.'))` — and annotated it
  `// gsm7, units=20, segments=1, singleCapacity=160`, listing `partCapacity`
  and `isMultipart` in the neighbouring samples. Every number was right and
  every name was a real property, but none of the three capacities is part of
  the string: `TomSmsSegmentation.toString()` emits the encoding, the units and
  the segment count only, so no `print` of the object has ever produced the
  documented line. A reader running the sample saw different output and could
  not tell whether the document or their build was wrong. The samples now read
  the properties they narrate, which is also the more useful shape — the
  capacities are the interesting part of that passage — and a sample that prints
  what it claims stays true if `toString()` changes. The block is followed by
  what `toString()` actually gives, so the difference is stated rather than left
  to be discovered. Sweeping the rest of the document for the same defect found
  none: the five other object-printing samples (`TomRecipient`,
  `TomAttachment`, `TomDeliveryReceipt`, `TomSmtpSettings`,
  `TomSmsGatewaySettings`) and the three deterministic `TomMimeEncoder` claims
  all reproduce their annotations exactly.

- **`messaging` source dartdoc narrated its own development (tcinc578).** Three
  comments described the code's history rather than the code: the
  `sms_transport.dart` library header opened with a `## Why this file exists at
  all` section arguing that `TomMessageTransport` "had exactly one
  implementation" and that the second channel proved the shape held;
  `TomSmsGatewayProtocol` justified its boundary as "the boundary the todo
  behind this file asked for"; and `TomDeliveryException` explained
  `isPermanent` by recounting a superseded design in which a stored flag and a
  mixin were set independently. A reader arriving at the file today cannot
  verify any of it and does not need to: all three now state the current
  invariant on its own authority — what SMS needs from the shared shape, where
  the vendor boundary is drawn, and why one fact has one representation. The
  classification-rule and no-vendor-presets sections of the library header were
  already AS-IS and are unchanged. Comments only; no behavioural change.

- **The `messaging` source directory had no `readme.md` (tcinc577).** Fifteen of
  the twenty modules under `lib/src/tomserver/` carried one; the module that did
  not was the one whose structure is least recoverable from its file names.
  Nothing in the directory said that `message_transport.dart` holds the router
  and all three network-free transports as well as the contract, that the two
  real transports each hide their wire behind an injectable seam, or that
  `templated_message_service.dart` is the base the two services share — so a
  developer arriving at nine files had to read them to find out which four
  layers they formed.

  `lib/src/tomserver/messaging/readme.md` now follows the reconciled sibling
  shape: what the module is for, the four layers named file by file, `Key types`
  tables grouped per source file, a `Quick start` that composes a message and
  sends it through the stand-in transport, and pointers to the guide, example
  and suite. `messaging` accordingly leaves the `_modulesWithoutReadme`
  quarantine in `test/api_reference_coverage_test.dart`, so
  `each module readme reaches every exported file` now *runs* for it rather than
  skipping — one test moved from skipped to passing — and every one of the nine
  exported files is held to having a representative in the table.

  Two things the writing corrected, both found by checking rather than
  recalling: the `Quick start` snippet was compiled and run before being
  committed, which caught it printing `sent` where `TomDeliveryOutcome` says
  `delivered`; and the `TomDeliveryReceipt` row described a per-recipient
  outcome, when the receipt is per-message and carries `rejectedRecipients` for
  the partial case. The todo pointed at `scheduling/readme.md` as the model to
  follow, but that readme is itself quarantined as non-conforming — it has no
  `| Type |` table — so `db_migration/readme.md` was used instead.

- **`doc/messaging.md` never named `TomMessage.sms`, the factory every
  application SMS is composed through (tcinc576).** The guide showed
  `TomMessage.email` when it introduced the message shape, described what SMS
  needed from that shape, and explained the templated SMS path — without once
  naming the constructor that all of it goes through. A reader following the
  guide end to end learned the channel's rules and not how to compose for it.

  The SMS section gains a `### Composing one` subsection with a worked snippet
  and the two decisions behind the signature: it accepts no `subject`, `html` or
  `attachments` because none survive the trip, so offering them would move the
  discovery to delivery time in another isolate; and `senderId` is a parameter
  landing in `metadata` rather than a `from` recipient, because a short code is
  not an addressee and modelling it as one would offer a `displayName` and a
  `TomRecipientKind` that mean nothing here. The Message Shape notes gain a
  "two factories, one type" bullet — they differ in what they accept and not at
  all in what they produce, which is why one transport contract and one outbox
  carry both — and Application SMS now says what `TomSmsService.render` hands
  back, since a templated SMS being indistinguishable from a hand-composed one
  past that point is why the outbox needs to know nothing about templates.

  The API summary half of this finding was already closed under tcinc471; the
  omission was confined to the guide. Worth recording is what the investigation
  ruled out: the coverage guard was suspected of being structurally blind to
  named constructors, and it is not — `_parseDeclarations` collects them as
  members, so removing `TomMessage.sms` from the summary turns
  `every class section names the members its class declares` red. The earlier
  probe that suggested otherwise had left a `.bak` copy of the summary inside
  `doc/api_reference/`, where the parser read it as a second summary and found
  the symbol there. No new guard was added, because one that duplicates a check
  already in the file is dead weight.

- **Four `little_things` artefacts said the module contributes "a single type"
  when it ships two (tcinc561).** `LoginException` is declared in
  `little_things/server_exception.dart`, exported from the barrel, and thrown 33
  times across five files of the authentication and 2FA subsystems — and the
  module guide, the directory readme, the API summary and the example between
  them mentioned it once, in a parenthetical list of subtypes. A reader who went
  to the module to find out what it contains was told, by every document written
  to answer that question, that the second type does not exist.

  All four now describe both: `doc/little_things.md` gains an Overview row and a
  Core Components entry saying what `LoginException` is (a login that cannot
  succeed) and what it adds over the base (nothing); the directory readme gains
  a Key types row; the example's header says two types and explains why only one
  of them is demonstrated. Each also records *why* the type sits here rather
  than in `authentication` — so the 2FA subsystem can throw it without importing
  the server that catches it — because that placement is the whole reason the
  omission was easy to make. `authentication/readme.md`, which documents the
  type from the consumer side, now names its declaring module so the two agree.

  One correction to the type's own surface came out of reading it: its
  constructor forwards the base payload *minus* `clientThrow`, so every
  `LoginException` carries the default `true` and a caller cannot mask one.
  `doc/little_things.md`'s `clientThrow` section says so, since a flag that one
  type in the package silently opts out of is exactly what a reader of that
  section is trying to learn.

  The API summary is the one artefact that does **not** gain a class section.
  `LoginException` is documented under `api_summary_authentication.md`, where a
  reader meets it, and `api_reference_coverage_test.dart` measures the index
  against the summaries' sections — a second section here would demand a second
  index attribution and leave two constructor listings to drift apart. It gains
  the hierarchy line, and prose saying where the section is. With the Overview
  row added, `little_things` also leaves the Overview-table quarantine
  (`tcincb3_ahwn`), and that guard now runs against it.

- **`endpoints_example.dart` built a form by hand and never decoded one, and
  never registered the file slot it described (tcinc520).** Step 7 constructed a
  `TomMultipartForm` with its own constructor and read a file back out, which
  demonstrates the value type but not the operation a reader needs: turning a
  request into a form. Both decoders — `TomMultipartForm.readForm` and
  `readUrlEncodedForm` — take a shelf `Request` and need no server, so the
  example's own header was wrong to file them with the pipeline. Step 7 now
  decodes a literal `multipart/form-data` body, written out as a browser sends
  it (boundary delimiters, one part per field, a `filename` on the file part and
  none on the text parts — the envelope's own distinction, which is what the
  decoder reads), and shows that a JSON request answers `null` rather than
  throwing. A new step 8 decodes a url-encoded body, including its
  percent-escapes and its structural inability to carry a file.

  The file surface gained the half that was missing. `TomFileSlots.register` is
  now *called*, so the example shows exposure positively as well as negatively:
  one registration over an entity with two `@TomFileReference` columns produces
  exactly one slot, and the route it serves —
  `/files/example_document/{id}/attachment` — is derived and printed rather than
  asserted about. The closed column still resolves to nothing, and step 7's own
  decoded form part aimed at it still reports `file_endpoint.unknown_slot`, the
  key the HTTP surface renders as a 404. New expectations use a `check()`
  helper (`if`/`throw`) rather than `assert`, which `dart run` compiles out; the
  older steps' conversion remains quest todo `tcincb134_ahyc`. Five mutations
  confirm the new steps bite — renaming the file part, removing the
  registration, pointing the closed-column check at the exposed one, expecting
  an escape to survive undecoded, and making the not-a-form request a form each
  fail the expectation that names them.

  Registering a slot needs a reflector, and the example suite now has **one
  reflection root** for all of it: `example/example_reflection.dart`, which
  captures the cluster demonstration's `ClusterFenceRow` and the endpoints
  example's `ExampleDocumentRecord` in a single generated file. Adding a second
  root would have been the obvious move and the expensive one — every root
  reaches the package barrel, so each costs a further ~1.7 MB of generated
  source capturing the same framework surface, a cost the previous root's own
  doc comment had already flagged. `cluster_reflection.dart` keeps its row type
  and stops being a root; `build.yaml` and `reflection_generation.sh` name the
  shared one.

- **`endpoints_example.dart` had nine facets and none was a file slot
  (tcinc517).** The example showed the endpoint-defining annotations and the
  default error handler, so a reader met `TomFormFile` in step 7 and was never
  shown where such a part goes. A tenth step now closes that: it reads the
  derived route (`/files/{entity}/{id}/{column}`), shows the default-closed rule
  from the outside — nothing resolves before a repository is registered, and
  then only for a column whose `@TomFileReference` says `exposed: true` — and
  hands step 7's own form part to `TomFormFile.storeIn`, which meets that closed
  door and reports it as `file_endpoint.unknown_slot`, the key the HTTP surface
  renders as a 404. Registration needs generated reflection and stays out, in
  keeping with the file's reflection-free scope; what registration *decides* is
  visible without it. The step's expectations are written as `if`/`throw` rather
  than the `assert` the nine steps above still use, because `dart run` — the
  command this file's own header documents — compiles an assert out, so those
  nine print their transcript unevaluated (their conversion is quest todo
  `tcincb134_ahyc`). Three mutations confirm the new step bites: shortening
  `routeUri`, renaming the `unknown_slot` key, and seeding the slot registry
  each fail it.

- **The API-reference guard now asks whether a summary names a type at all, not
  only whether it presents it in the expected shape (tcinc500).** Every existing
  group in `api_reference_coverage_test.dart` polices one *presentation* — an
  Overview-table row, an enum block, a class section's member list. Each is
  right about the shape it owns, and together they left a gap that none of them
  could see: an exported class that appears in *no* presentation is omitted from
  no list, so every check passes and the type is simply absent. Eleven were —
  the entire file-slot upload API (`TomFileEndpoint`, `TomFileServer`,
  `TomFileSlots` and four companions in `endpoints`; `TomFileRepository`,
  `TomFileReference`, `TomFileReferenceKeys` and `TomResourceScopeSource` in
  `object_persistence`) has zero occurrences in its module's summary. The new
  `no summary omits a name its module exports` group compares each barrel's
  exported names against every name the summary puts in front of a reader, and
  is deliberately neutral about how: a heading and an identifier inside an
  inline code span both count, because the package legitimately uses both and a
  rule demanding headings would condemn the thirty query operators of
  `object_persistence`, correctly presented as one table row each. A mention
  inside a fenced block does not count — a sample that uses a type does not
  document it. Renaming a documented class heading was, before this, caught by
  nothing in the file. The two modules holding the eleven are quarantined
  against quest todo `tcincb135_ahyc`, with a meta-test that fails once either
  is reconciled, so the exemption cannot outlive the debt.

- **The `db_migration` example demonstrates the module's connection-free
  surface, and its expectations are now actually evaluated (tcinc499).** The
  example reached three of the module's public types and printed a transcript
  that looked like a demonstration of the rest. Ordering, environment
  selection, the schema accumulator, statement splitting, the DDL replay, the
  type-family comparison and the convergence check — everything the module can
  do without a database — were absent. It is now ten numbered steps covering
  all of them, ending on a convergence report that genuinely diverges: the
  chain contains an `ALTER TABLE` against a table no earlier artifact creates,
  so the replay reports one error, and no entity types are offered, so the one
  table the chain does create reads as unmapped. Both are printed. The two
  halves that need more than a Dart VM — the orchestrator and the entity side,
  which reads `@TomDbTable` types out of `tomReflector` — are named in the
  header with the reason they are described in `doc/db_migration.md` instead of
  run here, rather than quietly omitted.

  The more consequential half of this is that **the example's expectations were
  not being checked at all.** Its seven `assert`s were compiled out by the
  `dart run` command its own header documents — that is what `--enable-asserts`
  is for — so the file printed a plausible transcript and exited 0 whether or
  not anything it claimed was true. They are now a plain `if`/`throw` helper
  whose dartdoc records why, matching `example/datasources`. Measuring the rest
  of the package found the same defect in **16 of 28 example programs**; those
  are quarantined by name in `api_reference_coverage_test.dart` under quest todo
  `tcincb134_ahyc`, with a per-file rule that fails the moment a new example
  ships an `assert` and three meta-tests that stop the quarantine outliving its
  cause — one fails when a quarantined file no longer has an assert to suppress,
  one when it names a file that no longer exists, and one when the directory
  sweep stops finding examples at all, which would otherwise report a clean pass
  over an empty set. `db_migration_test.dart` runs the example under exactly the
  command its header gives and pins the printed step list, the header's own list
  of surfaces, and the fourteen types it must reach. Four of those fourteen are
  *returned* values whose types inference would reach without ever spelling —
  `TomDdlReplayResult`, `TomDdlReplayError`, `TomSchemaConvergenceReport`,
  `TomSchemaTable` — so the example writes those declarations out in full,
  giving a reader a name to look up.

- **The `db_migration` guide names the suites that cover it, and the gaps it
  still has (tcinc498).** The guide named five test files — among them
  `framework_schema_test.dart`, `framework_schema_db_test.dart` and
  `reference_migrations_test.dart` — and not one was its own. A reader checking
  whether the module was covered found filenames, and stopped looking. The
  guide now carries
  a **Verification** section that names the three suites which always run
  (`db_migration_test.dart` for the connection-free surface,
  `schema_convergence_test.dart` for the reading half,
  `db_migration_db_test.dart` for what only a live server can substantiate),
  says what each one establishes, keeps the cross-references to the two
  framework-schema suites, and names `tool/run_db_tests.sh` and
  `example/db_migration/db_migration_example.dart` — the latter with the reason
  it is worth citing: the example *parses* the names it shows rather than
  printing them, so a name the parser rejects throws instead of misinforming
  its reader. The file-name grammar is stated in three places (source, guide,
  example) and `db_migration_test.dart` holds all three to what
  `parseMigrationFileName` accepts, reading the canonical form out of the
  parser's own refusal message.

  A **Not Yet Implemented** section came with it, five gaps each read out of the
  source rather than inferred: a failed migration writes `success = 0` and
  nothing ever reads the column back, so the next run finds the version, agrees
  on description and checksum, and returns as though it had succeeded;
  migrations are forward-only (`TomDbMigrator` is `initializeMigration` /
  `applyMigration` / `reset`); nothing arbitrates between two processes
  migrating at once; `MariadbMigrationAdaptor` is the only implementation, so
  the discovery seam is real but never exercised by a second; and
  `TomSchemaConvergenceCheck` has no `verifyLive` counterpart to
  `TomFrameworkSchemaCheck`'s, so a hand-edited application table is invisible
  to it. The first of those is a defect, not merely an undocumented limit, and
  is tracked as `tcincb133` — what the next run *should* do with a `success = 0`
  row is a genuine choice, because MariaDB does not roll DDL back and the failed
  script may be half-applied.

  The guard that should have caught this already existed and was too weak.
  `_unnamedVerification` demanded that a guide name *a* suite, and this guide
  named five; naming one suite reads exactly like naming them all. It now
  demands every suite whose **filename** identifies it as the module's — a lower
  bound on coverage and deliberately so, since `schema_convergence_test.dart`
  exercises nothing but `db_migration` and no filename rule will find it, while
  inferring ownership from imports would claim every suite that touches a module
  in passing and produce a guard people switch off. Strengthening it cost
  exactly one net quarantine entry: `db_migration` leaves both
  `_verificationPendingAttribution` and `_limitationsPendingSection` — the
  designed expiry, not an exemption removed by hand — and `authorization`, which
  names several suites and not its own, is newly caught. Two fixtures pin the
  distinction the change turns on: that naming one suite is not naming the
  module's suites, and that a module with *no* name-matched suite
  (`preferences`) still has to satisfy the fallback clause.

- **The `db_migration` guide groups its Overview by half, and names the whole
  environment-tag surface (tcinc497).** The Overview was one flat list of 26
  rows. It was complete — `a1d38e52` had already grown it from the original
  seven — but a flat list says nothing about the thing worth knowing first:
  which types run against a live server and which answer *does this chain build
  the shape the code expects* with no database at all. The Overview is now three
  tables, **the migration engine** (8), **the convergence checks** (8) and **the
  shared schema model and DDL replay** (10), the same grouping and the same
  headings the module readme uses, so the two documents about one module do not
  cut it two different ways. All 26 rows are preserved and the three headings
  are listed in the contents.

  The environment-tag section named the tag grammar but not the surface that
  implements it. It now names both halves of the rule — `appliesInEnvironment`
  as the whole per-file predicate, `selectForEnvironment` applying it across an
  already-ordered chain — states that selection is the **last** step so nothing
  is reordered by being tagged, and states that skipping is a pure omission: a
  skipped migration is not recorded as anything, so re-running skips it again
  and switching environments later finds it still pending rather than spent.

  One claim was **wrong**, and it was mine: the guide (and the tcinc495 entry
  above) said the convergence check "has no active environment to filter by in
  the first place". `TomSchemaConvergenceCheck` takes an environment and
  defaults it to the active name, and `readChain` filters with it. Both places
  now carry the argument that is actually true, and is the stronger one — the
  check filters by an environment *too*, so had the duplicate-version check run
  after selection, the same tree would be pronounced sound under `prod` and
  unsound under `dev`.

  Two guards came with it. `no Overview table lists a name twice`: splitting a
  table into groups is what makes a repeat possible, and the existing
  completeness check unions every row before comparing, so it accepts a name
  listed twice exactly as happily as once. A name in two groups contradicts the
  claim a grouped table makes while looking tidy in both. All twenty guides pass
  today, so nothing is quarantined. And `the sweep reads every table a grouped
  Overview splits into`, which fails if the grouping is ever flattened back —
  without it, a flattening regression leaves every other check green on a
  document that has quietly lost its structure.

- **The `db_migration` module readme describes the module that exists
  (tcinc496).** Its "Key types" table listed five types drawn from two of the
  module's seven files, so the entire convergence half — `TomSchemaDdlReader`,
  `TomSchemaConvergenceCheck`, `TomFrameworkSchemaCheck`, the shared
  `TomSchemaModel` vocabulary and `TomSqlLexer` — was absent from the page a
  reader meets on arriving at the directory, and the module read as what it had
  been before five of its files existed. The readme now covers all 25 public
  types across three tables (the engine, the checks, and the shared schema model
  and DDL replay), states what each type *is* rather than what it is used for,
  and points at `doc/db_migration.md` naming the example and the three test
  files.

  A guard came with it, because the fault was not confined to this module.
  `test/api_reference_coverage_test.dart` gained `each module readme reaches
  every exported file`: for every file the barrel exports, at least one of that
  file's public names must appear in its module's readme. The measure is **per
  file, not per name** — a table headed "Key types" makes no exhaustiveness
  claim, and `object_persistence` exports 83 types, so a per-name rule would
  force an 83-row table and make the worst readme worse. What the heading cannot
  excuse is a whole file with no representative at all: that is not selection,
  it is a capability the reader has no way to learn exists. And it is measured
  over the whole document rather than the table, because `scheduling` exports a
  file of nothing but free functions and a `| Type |` table has nowhere to put
  `jobRunTableDdl` — a rule that cannot be complied with gets suppressed rather
  than met.

  `db_migration` was the worst module in the package at 2 of 7 files reached.
  Ten of the twenty modules still fail — five with an incomplete readme, five
  with none at all — and are quarantined by name under quest todo `tcincb131`,
  with a meta-test that fails when a quarantined module starts passing so the
  exemptions expire by themselves.

- **The type-family tolerance is no longer described as symmetric (tcinc494).**
  The completion document summarised `TomSqlTypeFamilyCompatibility.accepts` as
  "symmetric where it exists, so which side is asked does not change the answer"
  — directly beneath its own table, which listed `decimal` accepting `integer`
  with no reverse row while giving the two genuinely bidirectional pairs a row
  each way. Exactly one ordered pair breaks symmetry, and the sentence invited a
  reader to call `accepts` on whichever side was to hand. The relation is now
  stated as directional, with `decimal`/`integer` named and both truth values
  given. Two guards keep the descriptions honest: the whole
  `TomSqlTypeFamily` matrix is swept so a second asymmetric pair fails
  immediately, and the API summary's prose claims about `accepts` are now
  arbitrated by `accepts` itself rather than by review.

- **`TomSchemaBuilder`'s class dartdoc no longer states the opposite of every
  method below it (tcinc493).** The class doc called each method a "no-op-free
  primitive" that assumed the caller had already established the operation was
  legal via `hasTable` / `hasColumn`. Every member documented the reverse — "does
  nothing when the table is absent" — as did the API summary's own method table,
  directly beneath the same false paragraph. The first sentence a reader met was
  the wrong one, and it told them to trust a precondition nothing enforced.

  The old rationale had a kernel of truth and drew the opposite conclusion from
  it. Only the caller *can* tell a benign collision from a defect, because that
  turns on whether the statement carried `IF NOT EXISTS` / `IF EXISTS` and the
  builder is handed parsed names, never the SQL. But that is why the *reporting*
  belongs to `TomSchemaDdlReader` — not why the builder would refuse the call.
  The rewritten doc says so, and adds the two reasons the check is not moved
  down: the reader collects errors and keeps replaying, so one run reports every
  divergence rather than only the first, and the entity side builds from
  `information_schema` rows where there is no chain to contradict at all.

  Six tests close the gap, all mutation-verified. Nothing in the suite pinned the
  no-op either way, so a builder rewritten to throw would have made the retired
  doc true and passed; two tests now decide it for every mutator, against both an
  unknown table and an unknown column. Four more check each of the two sites that
  carried the sentence, asking both questions: that the no-op contract is stated,
  and that the retired precondition is gone. Either alone is insufficient —
  stating it is not enough while the wrong sentence still sits above it, and
  absence is not enough because that is how prose gets deleted without a
  replacement, leaving the contract undocumented rather than misdocumented.

- **The migration guide now states that the outcome row is written with bound
  parameters (tcinc492).** The guide used to carry a block quote describing a
  string-interpolated `INSERT` and a follow-up to fix the escaping in
  `datasources`; the adaptor moved to named parameters and the quote was deleted
  — but nothing was put in its place, so the guide said nothing at all about how
  the row is written. A new **The outcome row is written with bound parameters**
  section says it, and says why it matters where it matters: the `script` column
  stores the migration's full body, quote characters in a migration body are
  routine, and an interpolated `INSERT` therefore fails *after* the migration has
  already changed the schema — a migration that happened and left no trace, which
  is the one state the versioning table exists to prevent. It also names the one
  part that genuinely is interpolated, the `<schema>_versioning` table name,
  because an identifier cannot be a bound parameter; a reader who greps for
  `schemaName` finds it either way, and should find it explained rather than
  contradicted. Two DB-backed tests pin the property with deliberately hostile
  content — nested quote styles, a backslash, and a semicolon inside a quoted run
  — one asserting the migration runs *and* records, the other that the stored
  script equals the literal byte-for-byte. That second assertion is the one no
  existing test made: the pre-existing checksum test compares a row's checksum
  against that row's own script, which detects a later edit but cannot detect
  both having been mangled on the way in.

- **The migration file-name grammar is documented in full, and the parser now
  arbitrates what the prose may say (tcinc491).** The `TomDbMigrations` class
  dartdoc claimed migrations run in "ascending name order" long after the sort
  had moved onto the parsed integer — where `[2]` precedes `[10]` and name order
  says the opposite. The module guide's ordering claim had already been
  corrected, which is what makes the second finding the larger one: *every* text
  stating the grammar gave it as `[<version>]-<description>`, omitting the
  optional `@<env>` tag, and the guide documented environment tags nowhere at
  all. C-16 was live, production-safety-relevant behaviour a reader could not
  learn existed. The guide gains an **Environment Tags** section — untagged as
  the safe default, no hierarchy walk, the `defaultTomEnvironment` fallback, and
  the rule that a tagged migration still occupies its version slot, so
  `[1]@dev` beside an untagged `[1]` is a collision rather than an addition.

  The durable half is a guard that reads the module's texts and judges them
  against the parser: every grammar they state must normalise to the one
  `parseMigrationFileName` quotes when it refuses a name, every file name they
  exhibit must actually parse, and none may claim name order. Normalisation
  accepts spelling variants of the same slot (`<numeric version>`/`<version>`,
  the extension spelled out, abbreviated or left to prose) so the guard does not
  dictate wording — but no variant can hide a missing `@<env>`. It scans the
  three texts that state the grammar in full; `doc/scheduling.md` describes only
  the shape its own shipped files take and now links here for the rest, so it
  states no grammar to keep honest.

- **A summary can no longer say a module has no enums while it exports one
  (tcinc490).** `## Global Functions and Constants` has been guarded against a
  false "None" since the `frameworkOwnedTables` repair; `## Enums` had no guard
  at all, so `db_migration`'s fix was hand-made and nothing prevented the next
  one. The new sweep asks two questions, because an enum — unlike a free
  function — has more than one legitimate home: every exported enum must have a
  section *somewhere* in the summary, and the `## Enums` section must **account
  for** each of them, by documenting it or by saying where it is documented. It
  found one live falsehood, `object_persistence`'s "None — this module declares
  no enums", written while the module exported `TomSortDirection` and documented
  it under Paging & Sorting; that section now points there instead. Twenty
  modules pass with no quarantine. `db_migration`'s Global Functions section
  also now spells out the seven default table names `frameworkOwnedTables`
  covers — the signature names the defaulting *constants*, which are declared
  across four other modules, so a reader previously had to chase seven
  identifiers to learn which tables the check actually looks at.

- **The `db_migration` API summary covers all seven of its files, not three
  (tcinc489).** Its `Source:` line named `db_migration.dart`,
  `mariadb_migration_adapter.dart` and `sql_lexer.dart`, and its class sections
  matched — so sixteen exported names had no entry at all: the schema vocabulary
  (`TomSchemaModel`, `TomSchemaTable`, `TomSchemaColumn`, `TomSchemaBuilder`),
  the DDL reader and its results (`TomSchemaDdlReader`, `TomMigrationArtifact`,
  `TomDdlReplayResult`, `TomDdlReplayError`), the comparison
  (`TomEntitySchemaReader`, `TomSchemaConvergenceCheck`,
  `TomSchemaConvergenceReport`, `TomSchemaDivergence`,
  `TomSchemaDivergenceKind`), the framework variant (`TomFrameworkSchemaCheck`,
  `TomInformationSchemaColumnRow`) and `TomSqlTypeFamilyCompatibility`. A
  summary that names its sources and omits two thirds of them reads as complete,
  which is the failure the coverage guard exists to prevent.

  `## Enums` said "None — this module exposes no public enums", which
  `TomSchemaDivergenceKind` had made false; it now documents all nine kinds with
  which are errors and which are warnings.
  `TomSqlTypeFamilyCompatibility` is the package's first documented extension
  and introduces an `## Extensions` section with an `- **On:**` line, the
  counterpart of the existing `- **Extends:**` / `- **Implements:**`.

  The omission was not confined to the summary: `api_summary_index.md` and
  `doc/db_migration.md`'s Overview table listed the same seven names, so the
  types were unfindable from either entry point. Both now list all twenty-five,
  and `db_migration` is lifted from the guard's `_tablesPendingReconciliation`,
  `_sourceListsPendingReconciliation` and `_indexPendingReconciliation`
  quarantines — each of which has a paired staleness test, so the entries could
  not have been left behind.

- **The datasources example runs nine surfaces, not four (tcinc474).** It
  demonstrated typed-value boxing, literals, `objectOp` dispatch and the `:name`
  placeholder, and its header told the reader the rest needed a live database
  and annotated entity types. That was true of the drivers and of rendering a
  whole `TomSelect`, and false of five more surfaces that need neither: the
  `DATETIME(6)` instant encoding, `TomGeneratedQuery`'s static clause builders,
  the quote-aware `SqlPlaceholderScan`, `classifySqlFailure`, and
  `TomFrameworkTable`'s DDL, column lists and inserts. All five now run, with
  the header corrected to name only what genuinely needs a server.

  The step check went with it. `test/datasources_test.dart` looked for steps 1
  to 4 in the transcript, which catches a step that stopped printing but not a
  step added and left unchecked — the failure that was actually live. It now
  compares the whole printed sequence against exactly `1..9`, so both
  directions fail.

- **`doc/datasources.md` now says what the module has not done (tcinc473).** It
  described a module that ships exactly one database driver, declares a
  `TomDbType` nothing produces, holds one connection per data source with no
  pool, degrades a second driver's generated-key read to a session-scoped
  `SELECT LAST_INSERT_ID()`, and runs XA with no recovery path — and mentioned
  none of it. A new `## Not Yet Implemented` section names all five, each with
  what a caller does instead. Silence about an edge reads as "there is no edge",
  which is a stronger claim than this module can make.

  Two of the edges the todo listed had already closed and were deliberately not
  written: the dialect lookup by type no longer exists (a guard test forbids the
  name in `doc/`), and `TomCount` no longer discards ordering and window
  arguments — it declines to accept them, with the reasoning in its dartdoc.

  The omission was not local, and it was the mirror of the attribution gap fixed
  in tcinc472: `test/api_reference_coverage_test.dart` enforced *where* a claim
  of unfinished work must live, which says nothing about a document that makes
  none — and a guide with no such section has nowhere legal to put one, so the
  pressure is to leave the edge out. A per-module test now requires the section
  to exist. Eight guides fail it today and are quarantined as visible skips
  under quest todo `tcincb126_ahxt`, with a meta-test that fails when a
  quarantined guide has gained one. The unwired `TomDbTime` is tracked
  separately as `tcincb127_ahxt`: it is a feature spanning five files with an
  unmade wire-format decision, not a documentation defect.

- **A guide now has to name the artefacts that verify it (tcinc472).**
  `doc/datasources.md`'s `## Verification` section already named both suites and
  the `tool/run_db_tests.sh` runner, but not
  `example/datasources/datasources_example.dart` — the one artefact a reader can
  run in a second with no database. It now does, with the command, what the
  example demonstrates, and where it deliberately stops.

  The gap was not local. `test/api_reference_coverage_test.dart` previously
  checked only that references a guide *writes* resolve, which says nothing
  about a guide that writes none — the state datasources was in when it prompted
  that check. A per-module test now requires each guide to name at least one
  `*_test.dart` and, when the module ships one, at least one runnable artefact
  under `example/<module>/`. Both, because an example nobody points at is an
  example nobody runs, which is how the inert asserts above survived a year.
  Reference migrations under `example/<module>/migrations/` do not count: that
  is data a reader reads, not a program a reader runs. Twelve modules fail it
  today and are quarantined as visible skips under quest todo `tcincb125_ahxt`,
  with a meta-test that fails when a quarantined module has nothing left to
  attribute.

- **`TomLiteralSelect` states what its empty field set means (tcinc461).** The
  class overrode `getParameters` to return the list its caller declares, but
  left `getFields` to the inherited default. The value that default produces is
  right — `TomLiteralSelect` extends `TomQuery`, whose `getFields` is `{}`, not
  `TomGeneratedQuery`, whose implementation walks a predicate a literal query
  does not have — so nothing was miscomputed. What was missing is the reason.

  Two different claims share the value `{}`: *"this statement references no
  fields"*, which the base says on behalf of statements where it is true, and
  *"this statement cannot say which fields it references"*, which is the case
  for hand-written SQL that nothing here parses. A literal select usually does
  read several columns. `getFields` is now an explicit override whose dartdoc
  says which of the two it means, so a caller weighing the answer — to choose a
  projection, to audit a statement, or to gate access — is told that empty means
  *unknown* and must not be read as permission. `TomQuery.getFields` points at
  it, `doc/datasources.md` gains a section contrasting the two forms, and the
  new `test/queries_test.dart` pins the pair against the three answers a wrong
  implementation would give (the entity's columns, the declared parameter names,
  tokens scraped from the SQL text).

- **The JWT paragraph says what is absent instead of pointing at a list that
  never had it (tcinc449).** `TomBaseServerConfiguration`'s dartdoc deferred
  "richer JWT-creation settings" to the quest completion steps, which contain no
  such entry — a reader following it could not tell whether the work was
  planned, abandoned, or done elsewhere, and paid a lookup to learn nothing.
  There is no scheduled work to name, so the sentence now states the fact: all
  three JWT fields are carried and read by nothing in this library, and the
  algorithm, issuer, audience and expiry have no configuration keys at all, so
  an application that signs tokens assembles that part itself. The same
  deferral in `doc/configuration.md` is gone, and two tests pin that neither
  file gestures at an unnamed follow-up again.

- **The configuration example now runs the three lines a startup actually
  begins with (tcinc448).** It demonstrated reading properties thoroughly and
  assembling the tree they are read from barely at all — the reader's first
  question was answered by snippets in the completion document that nothing
  executed. `TomYaml.mergeInYamlFile`, the static `loader` hook and the `.load`
  constructor are now steps of the example, each with a check, taking it from
  nine steps to twelve.

  Writing them as *runnable* steps is what surfaced the rule the prose had not
  stated: **the loader hook is reachable only before a provider exists.** It
  fires when `getServerConfig()` creates the process provider, so after any
  `setServerConfigProvider` call it can never run and `.load` is the form left.
  The example could not have demonstrated the two in the other order, which is
  why the hook is step 1 and `.load` is step 9 — and why a snippet showing them
  side by side, as an unexecuted one did, reads as a free choice when it is not.

  Layering is shown with both halves an overlay needs, since either alone
  misleads: the overwrite is per *leaf*, so a sibling the overlay omits
  survives, and an overlay that is **absent throws** rather than being skipped
  — the case that matters precisely because the usual reason to write the
  pattern is a set of per-environment files of which only one is ever present.

  Each new step was verified by mutation rather than by reading it: breaking
  the loader call, the recursive merge, the missing-file throw and `.load`'s
  callback each turn the example red. A step that prints a plausible line while
  pinning nothing is the failure mode an example is most prone to.

- **Two configuration rules that only tests knew are now written down
  (tcinc447).** Both were found by mutation: breaking them left the suite
  green, which is how an undocumented rule and an untested one turn out to be
  the same defect seen from two sides.

  *A dotted key is tried as a path first.* `server.port` resolves whether the
  operator wrote it nested under `server:` or flat as `server.port:` — the tree
  walk answers the first, the top-level fallback the second. The two spellings
  are only equivalent while one of them is present: where a file carries both,
  the path wins and the flat key becomes unreachable, neither merged nor
  reported. Adding a `server:` block to a file that already carried a flat
  `server.port` is therefore a silent way to lose it. Documented on the
  provider, in `doc/configuration.md`, and in the API summary.

  *An overlay is a patch, not a replacement.* `TomYaml.mergeInYamlFile` recurses
  into subtrees, so its one-sided overwrite is per *leaf* rather than per
  branch: a file naming `db.host` alone replaces that key and leaves `db.port`
  and `db.pool` standing. This is what lets a per-environment file state only
  its differences instead of restating every sibling setting to avoid losing
  it — and it would invert silently if the merge ever stopped recursing. The
  existing tests used disjoint keys throughout, so nothing had ever exercised a
  collision in either direction.

- **The commented-out logging middleware is now documented rather than
  commented out (tcinc444).** `TomBaseServerConfiguration.loggingMiddleware`
  was initialised to `tomLoggingMiddleware()` and immediately followed by a
  block comment holding a disabled `logRequests(logger: …)` call. Commented-out
  code in an exported library file reads as one of three things — the shape the
  live default replaced, an alternative a deployment might want, or a leftover
  — and nothing distinguished them.

  It is the second: activating the block compiles and runs, because `shelf` is
  already imported and `logRequests` is a `Middleware` of exactly the same
  shape. So deleting it silently would have discarded a real choice. The field
  now carries dartdoc that names the alternative, shows it as a code sample,
  and states the cost. Shelf's middleware adds request timing, which the
  default does not report, but it reads nothing from the request context and so
  honours neither guard the default exists for: `shouldBeLogged` — which the
  endpoint pipeline sets from each endpoint's `logRequests` flag, and which is
  how `TomHealthService` keeps a `/health` probe arriving every few seconds out
  of the log — and `hasBeenLogged`, without which a retried request logs once
  per pass. A third difference is not about the context at all: shelf's version
  also logs the error path and rethrows, while this layer sits inside
  `_handleError`, which already logs the error and its stack trace, so every
  failed request would be reported twice. The same trade-off is now in
  `doc/server.md` under *Extending the Pipeline* and in both API summaries.

  A test pins the half that was unasserted: `shouldBeLogged: false` emits
  nothing. The two pre-existing `tomLoggingMiddleware` tests covered the
  one-shot guard but never the opt-out, so the property that makes shelf's
  middleware unusable as a drop-in was the one property nothing checked.
  Verified by removing the `shouldBeLogged` clause, which turns the new test
  red while both old ones stay green. No behaviour changed.

- **`TomYaml`'s throw on a missing file is now documented (tcinc441).** Both
  entry points read the file with no existence check, so an absent path
  surfaces as a `PathNotFoundException` — and nothing said so, while the
  surrounding text ("Loads the file, normalises it…") read as though the call
  always succeeds. The sibling loader in the same pipeline does the opposite:
  `TomEnvFile.read` returns an empty map for an absent `.env`, and its dartdoc
  says so, so a reader who had met one had a reasonable and wrong expectation
  of the other. That matters most for the layered overlay the module itself
  documents, where the per-environment file is genuinely optional.

  The throw and the contrast are now stated in the dartdoc of both methods, in
  `doc/configuration.md` (a new *A missing file throws* subsection with the
  guard to use, plus a *Not Yet Implemented* entry), in the API summary —
  whose method table gained a Throws column — and in the module readme. Two
  tests pin it: one asserts both entry points throw and `TomEnvFile.read` does
  not, so the
  documented asymmetry cannot quietly change on either side; the other asserts
  that a failed merge leaves the target map untouched, which is what makes
  catching a sound remedy rather than a half-applied overlay. No behaviour
  changed.

- **The configuration guide now names how to check it (tcinc440).**
  `doc/configuration.md` had no `## Verification` section and never mentioned
  `example/configuration/configuration_example.dart` or
  `test/configuration_test.dart`, although both exist and are green — the
  pointer ran only the other way, from the example's header to the document.
  A reader who wanted to run the module before adopting it had to go looking.
  The section now names the example with its exact `dart run` command line and
  what its eight steps demonstrate, says why its checks are a throwing helper
  rather than `assert` (`dart run` compiles asserts out, so an asserted example
  would exit 0 with every expectation violated), names the suite with its
  command line, and says what its fifty-eight tests in eight groups carry.

- **The configuration guide now states what it does not do (tcinc439).**
  `doc/configuration.md` read as though the module were complete, while the
  completion record carried seven verified limitations — so a consumer met
  each of them as a surprise at the point of being bitten. Nine sibling module docs
  already carry a `## Not Yet Implemented` section; this one now does too, in
  the same shape and the same position, listing all seven with the remedy where
  there is one: a misspelled setting is silently ignored, an unknown key reads
  back as its own name, a `TomConfig` resolves once at construction, an
  obligatory miss throws a bare `String`, a substituted YAML value is text, the
  default TLS material is a checked-in self-signed pair, and
  `jwtSharedSecretKey` defaults to a published passphrase.

  Each is pinned by a test, which is the half that keeps the section honest in
  the other direction: a stale warning costs a reader the same working-around as
  a missing one, so the four with nowhere else to live got a *the documented
  limitations hold* group, and the bare-`String` throw — asserted with
  `throwsA(anything)`, which would have accepted an `Exception` just as happily
  — was tightened to assert the type the warning names.

- **YAML substitution named as the one untyped configuration source
  (tcinc438).** The completion record's open-end list said values from the
  environment, a `.env` file, the command line *or* a YAML substitution arrive
  as strings and fail `TomConfig`'s cast. Three of those four have not behaved
  that way for some time — each passes through a converting reader
  (`TomArgs.convertToObjectMap`, `TomEnvFile.parse`, `TomArgs.parseArgsToMap`),
  which the same document says 240 lines earlier. Probing all four confirmed it:
  only substitution delivers text.

  The reason it does is worth stating rather than merely recording, because it
  is the trap: substitution runs *after* the YAML parser has assigned types and
  writes its expansion back as text, so `port: 3306` is an `int` while
  `port: ${DB_PORT:3306}` is the `String` `'3306'` — the same number, in the
  form `TomYaml`'s own dartdoc example shows, and true even with `DB_PORT`
  unset. Now stated in the guide (*A substituted value is a string*, with the
  literal-vs-placeholder table and the parse-it-yourself remedy), in the API
  mirror's `TomYaml` entry, in `TomYaml`'s class dartdoc, and in a rewritten
  open end. A test pins both legs from one file, so the two forms cannot drift
  into agreeing.

- **A cleared configuration key is documented as a setting, not an omission
  (tcinc437).** Writing `smtpHost:` with no value in YAML is how a deployment
  clears a setting, and it means something different from omitting the key.
  Both are answered differently — `exists` reports the cleared key as present,
  so `TomConfig` takes the provider branch and a `withDefault` default does not
  apply — but neither document said so, which left the one question a deployer
  has about the syntax ("does writing an empty key clear the setting or is it
  ignored?") answerable only by reading `exists`.

  Now stated in the guide (a worked example under *The Resource Provider*, and
  *A cleared key takes step 1, not step 2* under *Typed Property Access*), in
  the API mirror's `exists` / `get` / `TomConfig<T>` entries, and in the
  completion record. The rule that matters to a deployer is the type split: a
  nullable `T` resolves to `null` and the setting is cleared, a non-nullable `T`
  throws naming the key — which is why every optional deployment setting is
  declared `String?`.

  Two things were corrected in passing. `get` was documented in two places as
  returning `Object`; it returns `Object?`, and has since a present `null` began
  resolving rather than being reported missing. And the two "no value" answers
  are now described as the distinguishable pair they are: `null` means cleared,
  the key-string fallback means unknown.

  A test was added for the case a deployment actually writes — an explicit
  `null` beating a *non-null* default on a nullable `T`. The existing pair
  covered a nullable `null` default and a non-nullable throw, but not this one.
  All five explicit-null tests were confirmed to fail against the previous
  `resources[s] != null` semantics, so the guard is load-bearing rather than
  merely green.

- **The configuration guide explains the 23 deployment settings it used to skip
  (tcinc434).** `tcinc431` below gave the same 23 fields a row in the API
  mirror; the prose guide still did not mention them. It described the base
  class as declaring "`port`, `host`, `noSsl`, … and various other settings" and
  moved on, so the guide a deployer actually reads to learn *how to configure a
  server* named none of the settings that decide who the server logs in as, how
  it sends mail, or how it sends SMS. A mirror answers "what is the type of
  `smsMaxSegments`" for someone who already knows the field exists; nothing
  answered "what can I configure" for someone who does not.

  `doc/configuration.md` gains a **Deployment Settings** section between the
  base-class description and *Source Precedence*, with one table per block —
  seven self-login settings, nine `smtp*`, seven `sms*` — each row saying what
  the setting *decides* rather than restating its type. The two rules that
  precede them are the ones no single row can carry: the switch that enables
  each block and what leaving it unset means (*disabled*, not misconfigured),
  and the four secret-bearing settings — `serviceAccountCredential`,
  `smtpPassword`, `smsApiKey`, `smsApiSecret` — whose value is supplied out of
  band through the precedence chain and must never be written into a spec or a
  checked-in configuration tree.

  `test/api_reference_coverage_test.dart` guards the section the way it already
  guards the mirror: both directions, in source order, with block membership
  matched by name prefix so a tenth `smtp*` setting is covered the day it is
  declared. The secret markings are checked against the source rather than a
  list — the four are exactly the fields whose dartdoc says *secret-bearing* —
  so the guide cannot quietly stop marking one.

- **The configuration mirror lists all 48 settings, not 25 (tcinc431).**
  `TomBaseServerConfiguration` declares 48 fields; the Properties table in
  `doc/api_reference/api_summary_configuration.md` listed 25. The 23 absent ones
  were not scattered — they were three whole blocks: server self-login
  (`authServerLoginUri` and the six `serviceAccount*` fields), outbound mail
  (the nine `smtp*` fields) and outbound SMS (the seven `sms*` fields). Each
  block had been added to the class with its dartdoc and never mirrored, so the
  page a deployer reads to find out what can be configured omitted every
  messaging and self-login setting the server has, four of them secret-bearing.

  All 23 now have a row, in declaration order, with type, default and a
  one-line description. Two rules that no single row can carry follow the
  table: the three fields that switch a whole subsystem on
  (`authServerLoginUri` / `serviceAccountName`, `smtpHost`, `smsEndpoint`) and
  what leaving each unset means — *disabled*, not misconfigured, since a test
  run wants a server that composes messages and never delivers them — and the
  four secret-bearing fields, whose declaration belongs here and whose value is
  never authored.

  `test/api_reference_coverage_test.dart` now censuses the table against the
  class in both directions and in source order, so the next field added to
  `base_server_configuration.dart` fails a test until it has a row. The same
  check for the other Properties tables in `doc/api_reference/` is quest todo
  `tcincb105_ahxi`.

- **The API mirror now states what `TomEnvFile`'s `.env` features do
  (tcinc427).** `doc/api_reference/api_summary_cmdline.md` reproduced all five
  signatures and said the class supports "comments, empty lines, quoted values,
  and inline comments" — without saying what a single one of them *does*. A
  reader with only the mirror could call every method and still not predict the
  type of any value, which is the one thing this module decides.

  Three rules now follow the method table, each the behaviour behind one of the
  named features. A quoted value skips conversion entirely, which is the only
  way to keep a numeric-looking string a `String` (`NUM="123"`); an empty value
  becomes `null` rather than the empty `String`, with the key still present; and
  an unquoted value is truncated at its first `#`, no preceding whitespace
  required. A six-row table shows each against its unquoted counterpart, and a
  preceding paragraph states which lines `parse` skips and that it trims where
  `TomArgs` does not.

  The overview paragraph was overclaiming and is corrected: the two classes are
  *not* consistent, and the empty-value rule is named as the single documented
  exception. The quoting rule, contrary to how it is often described, is
  **shared** — `K="123"` yields the `String` `123` from an argument too — so it
  is stated as a shared rule, not a `.env` peculiarity. Only `#`-truncation and
  the empty-value rule are genuinely `.env`-only.

  One test was added: nothing pinned the divergence itself, only the two sides
  separately, so a differential test now requires `EMPTY=` to yield `''` from
  `TomArgs.parseArgsToMap` and `null` from `TomEnvFile.parse`, with the key
  present either way.

- **`doc/cmdline.md` now names its example and its suite (tcinc426).** The doc
  mentioned neither `example/cmdline/cmdline_example.dart` nor
  `test/cmdline_test.dart`, so a reader who wanted to *run* the module had no
  route from the documentation to either artefact. The pointer only went the
  other way — the example's header names the doc.

  A `## Verification` section closes the loop, in the shape `doc/cache.md` and
  `doc/scheduling.md` use: what the example walks and the `dart run` command
  that runs it, what the suite's seven behavioural groups cover and the
  `dart test` command that runs them, and the note that the suite is untagged
  and so runs in the default `testkit :test`. It also records that the two are
  linked in both directions, the suite now running the example and the readme's
  quick start.

- **`doc/cmdline.md` now states the module's limitations (tcinc425).** The doc
  described everything the module does and nothing it does not, so read on its
  own it said "nothing is open" — of a unit with seven known limitations, and
  to exactly the reader who has only the package documentation. Eight sibling
  module docs in this package carry a `## Not Yet Implemented` section, so the
  absence read as a gap in the writing rather than a property of the module.

  The section now names all seven, each with what to do instead: a dashed key
  cannot reach a reflected field (`--port=8080` binds nothing), a negative
  number cannot be typed and is refused by the reflector at an `int` field,
  leading zeros are dropped (`007` becomes `7`), no entry point reports a
  setting no source supplied, `load` does not load, a `#` anywhere in an
  unquoted `.env` value truncates it (`K=pa#ss` yields `pa`), and the two
  parsers still differ on surrounding whitespace.

  Six tests were added so the section cannot quietly go stale — every
  limitation it names is pinned, including two differential tests over the
  whitespace and `#` divergences between `TomArgs` and `TomEnvFile`.

- **The composition diagram in `doc/cmdline.md` now shows the resource base
  layer (tcinc422).** It drew three inputs — `Platform.environment`, the `.env`
  file and the command line — and called them "all three sources".
  `getDefaultValues` starts from a deep copy of the active
  `TomServerConfigResourceProvider`'s resources and merges those three on top,
  so the YAML tree is a fourth, lowest-precedence layer. It is also the only
  layer that supplies a value when none of the others does, which made the
  omission the expensive kind: a reader of `doc/cmdline.md` could not work out
  where a setting they never passed had come from.

  The diagram now has four inputs and the prose says the three sources are
  layered *on top of the configuration resources*, matching the diagram
  `doc/configuration.md` already carried. The `merge` snippet beneath it is
  labelled as reproducing the three upper layers only, since a hand-rolled
  stack has no resource tree beneath it. A test pins the base layer on its own
  — a resource value no other source supplies reaches the configuration.

- **The `doublePattern` shorthand no longer understates the pattern
  (tcinc421).** `TomArgs.doublePattern` is `[0-9]+[.][0-9]*`, but its own
  dartdoc and the API-reference mirror both described it as
  `digits . digits?` — a `?` reads as *one optional digit*, which would forbid
  the ordinary `3.14`. The shorthand is now `digits . digits*` in both places,
  and the completion notes, which had quoted the real pattern all along, no
  longer disagree with them.

  The consequence of "zero" is the one a reader is least likely to predict, so
  it is now stated wherever the conversion table appears: a value ending in a
  bare `.` converts rather than staying a `String`, so `5.` becomes the
  `double` `5.0`. An integer part is still required, so `.5` stays a `String`.
  Two tests pin the zero / one / many fractional-digit range; the `5.5678` case
  is what proves the pattern is `*` rather than `?`. No behaviour changed —
  only the descriptions of it.

- **`TomEnvFile.merge` now says that it converts nothing (tcinc417).** The
  documented way to layer configuration is to `merge` the process environment,
  a `.env` file and the parsed arguments, then hand the result to
  `setValues`. Only the last two arrive typed: `read` and `parseArgsToMap`
  convert on the way out, `merge` merely `addAll`s, and `Platform.environment`
  is a `Map<String, String>` that Dart's covariance lets `merge` accept as a
  `Map<String, Object?>` in silence. An unwrapped environment therefore merges
  cleanly and contributes every value as a `String`, and the first `int` or
  `bool` field fails at `setValues` with `TomReflectorException: Unexpected
  type int set using String`.

  The package's own composition (`getDefaultValues`) has always wrapped the
  environment in `TomArgs.convertToObjectMap`; nothing but the documentation
  was wrong. `merge`'s dartdoc, `doc/cmdline.md` and the API-reference mirror
  now each state that the wrap is required and why, and `doc/cmdline.md` gained
  the layering snippet itself so the idiom can be pasted rather than
  reconstructed. Four tests pin it, including one asserting that the unwrapped
  form is *rejected* — the failure is the documentation's evidence.

- **The cache module's prose now names the artefacts that verify it
  (tcinc414).** `doc/cache.md` had seven sections and mentioned
  `example/cache/cache_example.dart` nowhere and `test/cache_test.dart` only
  once, in passing, at the foot of "Not Yet Implemented". Its siblings do point
  at theirs — `authorization.md` names its example and its end-to-end test in a
  sentence, `scheduling.md` carries a whole `## Verification` section — and the
  pointers matter more here than usual, because the example and the suite are
  the only executable statements of what the module does, while the prose is the
  one artefact a consumer is likely to read. The link was also one-directional:
  the example's header already names the test.

  `doc/cache.md` gains a `## Verification` section saying what each covers — the
  example's nine steps and why its checks are a plain `throw` rather than an
  `assert`; the suite's areas, including the differential check against a naive
  LRU and the forwarding tests running against a real spawned `TomWorker`, and
  that it needs no server and so runs in the default `testkit :test` — and
  records that the suite runs both the example and the readme's quick start, so
  each of the module's prose artefacts is falsifiable from it.

  Two things were fixed in passing. The module's own `readme.md` pointed at
  neither `doc/cache.md` nor the example, where every sibling readme points at
  both; it now carries the same "See …" paragraph in the same position. And six
  type references in `doc/cache.md` were bracketed as shortcut reference links
  with no definition anywhere in the file, so they rendered with literal square
  brackets around the type name. Every other module document uses plain code
  spans; these now do too.

- **The cache API summary was verified against the source rather than trusted
  (tcinc411).** The mirror in `doc/api_reference/` is last in precedence, so it
  was checked symbol by symbol against `server_cache.dart`. Nothing was
  missing — every public type and member was present — but five descriptions
  were thinner than the dartdoc they mirror, each in the same way: read alone,
  the row implied something the source contradicts. `TomCacheManager`'s
  constructor showed a default of `false` without saying the body forces `true`
  in the main isolate; `fromNameCache` reported the `null` on expiry but not
  that the expired entry is removed in passing; `putEntry` described insertion
  and eviction but not replacement; `toNameCache` named the
  `TomCacheEntry`-as-value branch but not that such an entry is linked into the
  LRU chain like any other; and
  `TomCacheEntry` omitted the MRU pointers, its `deletionTime` row stopping at
  "does not expire on its own" without the source's qualifier that a bound or a
  clear may still evict it.

  `putEntry`'s dartdoc gained the replacement rule first, since the mirror had
  been faithful to a dartdoc that was itself silent on it and stating it only in
  the mirror would invert the precedence. A test now pins that rule for the one
  path it lacked one — a bounded cache holding more than one entry, where the
  replacement routes through `removeEntry`. The failure it guards is invisible
  when it happens: a skipped unlink still answers every read correctly, and only
  surfaces two stores later, when the superseded entry has become the chain's
  tail and the eviction follows its key, dropping the live replacement instead.

- **The cache module readme's quick start is now a program that returns
  (tcinc410).** It was a complete `main()` that registered a cache, stored, read
  and printed — and then hung. `TomCache.forType` defaults
  `deletionIntervalSeconds` to 3600 and the constructor installs the timer, so
  the isolate stayed alive with nothing left to do; run verbatim it printed
  `hello` and had to be killed. It was the first thing a reader of the module
  saw, and the only artefact of the five that got the rule wrong — the example
  already ends with `exit(0)` and the tests pass `deletionIntervalSeconds: null`
  or tear the timers down.

  The snippet now keeps a reference to the cache it registers and ends with
  `stopTimers()`, so the program terminates on its own instead of being forced
  out. A new test extracts the `dart` block under the readme's "Quick start"
  heading, runs it, and requires exit 0 with `hello` on stdout — with a
  20-second watchdog that kills the child, since the regression it guards is a
  program that never exits and a hung suite is a poor error message. The
  example was already pinned this way; the quick start was not, which is why it
  drifted. `doc/cache.md` also gained the rule it was missing: a live timer
  keeps the isolate alive, the deletion sweep is on by default, and a script
  has to stop its caches to return.

### Internal

- **`TomMessageBody` spelled its own defaults five times, so changing one meant
  finding five (tcincb1).** The `'utf-8'` charset default appeared in the
  primary constructor, in both named constructors, in `fromJson`'s fallback,
  and once more in `TomMimeEncoder._writeAlternatives`, which hand-wrote
  `text/plain; charset=utf-8` for a message with no body at all. The media
  types were spelled twice each — once by the constructor that builds them and
  once by the predicate that recognises them. Everything agreed, so nothing was
  broken; the cost was that agreement rested on nobody having edited any single
  site. That is the failure `_mediaTypeIs` already exists to record having
  suffered once, in this same class.

  Each default now has one home: the new public
  `TomMessageBody.defaultCharset`, and private `_plainTextMediaType` /
  `_htmlMediaType`. The charset constant is public because the duplication does
  not stop at the class boundary — a caller deciding whether a part needs
  converting had no way to ask what the default *is*, so it would restate
  `'utf-8'` and become another site. The media types stay private: no caller
  was restating those, and two more documented constants would be surface
  nobody asked for.

  The named constructors now redirect to the primary
  (`: this(_plainTextMediaType, content)`) rather than initialising fields
  themselves, so they cannot hold a stale opinion about any default the primary
  applies — including one added later. `TomMimeEncoder`'s empty branch writes
  `_writePart(out, const TomMessageBody.text(''))`, which is byte-identical
  because `wrapBase64('')` is `''`.

  Behaviour is unchanged: `charset` still defaults to `utf-8`, only its
  spelling moved. Two tests in `messaging_test.dart` pin the properties rather
  than the values: one asserts that the four ways of building a part yield a
  *set of size one* of charsets (spelling `'utf-8'` a fifth time would have
  been a fifth site), the other that a part built by name is recognised by the
  predicate for it. Both were verified by mutation, the defect being latent and
  so not showable red.

- **`TomUserPreferences` read the zone twice for every write (tcinc621).**
  `_write` resolved the principal for itself — it needs one, because the row it
  may be *inserting* has no id to copy one from — and then called `_rowFor`,
  which resolved it again. The second lookup could no longer fail once the first
  had succeeded, so it was a guard against a state the method had already
  excluded, and it made the invariant implicit: nothing in `_rowFor` said
  whether its own lookup was load-bearing or a leftover, so any change to either
  method had to re-derive that.

  `_rowFor` now takes the principal as a parameter, which leaves exactly one
  `_requirePrincipal()` per entry point — `all`, `read`, `remove`, and `_write`
  on behalf of `set` and `setEncoded`. The two options are not symmetric: having
  `_write` take its principal from the row `_rowFor` returned cannot work,
  because on the insert path there is no such row.

  Behaviour is unchanged, and is now pinned rather than argued. The new
  `test/user_preferences_service_test.dart` asserts that all seven public
  operations refuse with `preferences.no_principal` outside a zone *and* refuse
  before reaching the repository — the ordering half coming from a repository
  fixture that fails the test when touched. Only `read` was covered before, so
  the placement of the lookup could have moved off any of the other six
  unnoticed. Those assertions were written and shown green against the old shape
  first, so they characterise the behaviour rather than describe the new code.
  The fixture moved to `test/fixtures/unreachable_repository.dart`, now shared
  with the key-ordering suite that first needed it.

- **`TomColumnInformation`'s nine positional parameters included two
  interchangeable pairs (tcinc606).** `declaredName` and `field` are both
  `String` and adjacent; passing them the wrong way round type-checks, maps the
  entity's field name to itself as a column and the column name to itself as a
  field, and surfaces as wrong SQL somewhere else entirely. `declaredType` and
  `tableType` are both `Type` and fail the same way, reporting every column of
  an entity as being of the entity's own type. The constructor is now all-named,
  with the five parameters every mapped field has marked `required` and the five
  annotation-shaped ones optional. Its dartdoc describes what the parameters mean
  instead of why one of them used to be named.

  All eleven construction sites are updated: the analyzer, two examples, four
  test files, and the eight generated `*.reflection.dart` bridges across
  `tom_core_server`, `tom_core_kernel`, the four sample servers and
  `tom_uam_server`, each regenerated from the new signature.

- **Six constructor initialisers read as no-op self-assignments (tcinc582).**
  `TomMessageBody.text` and `.html` each took a `String content` parameter and
  then wrote `content = content` in the initialiser list, and
  `TomSmsGatewayAnswer.accepted` and `.rejected` did the same for `remoteId`,
  `detail` and `providerCode`. Every one of them was correct — in an initialiser
  list the right-hand side resolves to the parameter, not the field — but
  reading them as correct requires knowing that scoping rule, and a line that
  looks like a mistake costs every reader the moment it takes to prove it isn't
  one. All six are now initialising formals (`this.content`, `this.remoteId`,
  and so on), which state the same thing without the ambiguity and drop the
  redundant line. `TomSmsGatewayAnswer.rejected` keeps `permanent` as an
  ordinary parameter, because it deliberately differs from the field it feeds
  (`isPermanent`) and reads better at the call site; a comment now says so, so
  the asymmetry is not mistaken for an oversight.

  These were the only instances in the package: a sweep of `lib` for the shape
  now reports none. The two constructors in `TomMessageBody` are the ones almost
  every caller uses, so this was the first thing a reader of the class met.
  Behaviour and signatures are unchanged — the parameter names, their types and
  their `const`-ness are all as before, so no call site and no documented
  signature moves.

- **Two SMTP reply checks were `async` without awaiting anything (tcinc581).**
  `_expectAuth` and `_expect` each inspect a reply that has already been read
  and either return it or throw, but both were declared `async`, so both
  returned a `Future` and every one of their ten call sites paid an `await` for
  it. The signatures overstated what the functions did — an `await` is a reader's
  signal that control can leave the method here, and control never did — and
  each added a microtask to a step of the SMTP conversation, which is the one
  path in the module that runs per protocol round trip. `_failureFor`, the
  neighbour doing comparable work, was already synchronous, so the two markers
  were inconsistent with the file's own convention rather than with an external
  one. Both are now `void _expectAuth(TomSmtpReply)` and `TomSmtpReply
  _expect(TomSmtpReply, int, String)`, and the call sites keep only the inner
  `await connection.readReply()`, which is the one that genuinely suspends.
  Behaviour is unchanged: every caller is an `async` method, where a synchronous
  throw becomes the same rejected future it did before, and the failure paths of
  both helpers are asserted through the public `send` — `535` for the credential
  check, `451` and `552` for the reply check.

  Sweeping the module for the same shape found four more `async` bodies without
  an `await`, all of them left alone: three are `@override`s of an asynchronous
  contract and the fourth is that contract's own no-op default, where `async` is
  the idiomatic way to hand back an already-completed future. The distinction is
  the point — those satisfy a signature they do not choose, while these two were
  private helpers free to be synchronous and simply were not.

- **The RFC 5322 date helper is a nested function, and now the only zero-padder
  in its method (tcinc580).** `TomMimeEncoder.formatRfc5322Date` bound its
  two-digit padder to a final local — `final two = (int n) => ...` — which is
  the idiom for a closure that gets passed somewhere or reassigned, and this one
  is neither. It was the only lambda-in-a-local in the whole of `lib`, so it read
  as an oversight rather than a house style; `sqlInstant` in `datasources` does
  the identical job as a nested function declaration. The helper is now declared
  the same way, at the top of the method rather than four lines into it, and the
  numeric-offset fields use it instead of spelling `padLeft(2, '0')` inline a
  second and third time. Behaviour is unchanged — the substitution is the same
  expression under a different name.

- **`TomRequestId` moved from `server` to `little_things`, breaking the cycle
  between them (tcinc563).** `little_things` holds `TomServerException`, the base
  every other server exception extends, so it is the module every other one
  depends on. Its constructor recovers the ambient `TomRequestId` to stamp
  `requestUuid` — and that type was declared in `server`, the largest and most
  concrete module in the package. The most depended-upon module therefore
  imported the least depended-upon one, and `server` imported it back for
  `TomServerException`: a genuine two-way edge, not merely an awkward one.

  The id is now `little_things/request_id.dart`, in its own file because a
  correlation id is not an exception. `server` still *produces* it —
  `tomDefaultAuthenticationMiddleware` seeds a fresh one into every request zone
  — but no longer declares it, so `little_things` imports no other module of the
  package at all, which is what its position in the graph requires.

  Two consumers benefit beyond the cycle itself. `audit_trail.dart` imported
  `server/server.dart` for `TomRequestId` and nothing else, so the audit module
  is now off the server module entirely; `endpoint_pipeline.dart` genuinely
  needs both and gains an import rather than swapping one. The three
  `TomRequestId` tests moved from `server_test.dart` to `little_things_test.dart`
  to follow the declaration, and the example step moved the same way — the
  middleware test that asserts the *seeding* stays in `server_test.dart`, where
  the producer lives.

- **The SQL escape matrix is now one shared table, asserted against all three
  consumers of the lexer rather than one (tcinc501).** `TomSqlLexer` exists
  because five hand-rolled scanners each had their own idea of MariaDB's
  escaping rules, their own tests, and so stayed green while disagreeing with
  each other (tcinc476). The consolidation fixed the implementations but left
  the tests in the older shape: nine hand-written cases exercising
  `TomSqlLexer.splitStatements` alone. The other two consumers each walk the
  text a second time with their own loop, and neither walk was covered — a
  `TomSchemaDdlReader.stripComments` rewritten to scan naively passed the entire
  package, and so did a naive `splitTopLevel`.

  The cases are now a table — three quote characters times the two escape forms,
  `''` doubling and `\'` backslash — and every splitter is run against it. Two
  further guards keep it honest. The table's *shape* is asserted, so a cell
  dropped during a refactor fails rather than silently taking its coverage with
  it. And because `stripComments` copies quoted text through verbatim, running a
  case against it is not the same as testing it: a misparse only becomes
  observable when it moves a *comment marker* across a quoted-run boundary, so a
  meta-test requires a marker-bearing case per quote character. The first draft
  of the table lacked exactly that and was vacuous for the reader in all nine
  cases.

  The backtick row is where the two directions separate, and both are now
  pinned: ``CREATE TABLE `bs\` (id INT)`` creates a table genuinely named
  ``bs\``, so a scanner that honours the backslash there swallows the closing
  backtick (over-escaping, welding two statements into one), while one that
  ignores it inside a string literal ends `'it\'s'` early (under-escaping,
  cutting a statement in half). Where the reader and the lexer legitimately
  disagree — the reader strips a comment the lexer is required to keep verbatim,
  since `/*!40101 … */` is executable SQL — the table records both expectations
  rather than weakening the assertion to accommodate the difference.

- **`TomOperator` is documented as the tree it is, and every summary's class
  sections are now checked member by member against source (tcinc471).** The
  datasources summary described `TomOperator` at length and never mentioned
  `children` — the single edge along which the operator tree is walked, and the
  member `getParameters`, `getFields` and the `HAVING` rewrite are all defined
  in terms of — nor the static `operandChildren` an implementation builds it
  with. Both now have rows with their signatures, and the section says how they
  differ: `children` is what a node *has*, `operandChildren` is how an
  implementation *builds* it. `defaultDialect` says it is mutable, `generate`
  and `getFields` are marked abstract, and the remaining descriptions were
  rewritten against source.

  The omission was not specific to that class, so the check is not either. A new
  group compares each `#### <ClassName>` section against the public members the
  class declares, in the direction the existing attribution check does not: that
  one asks whether a documented row is filed under the right class, this asks
  whether a declared member is documented at all. A mention anywhere in the
  section counts — a row, a fenced constructor listing, prose — because a
  factory constructor has a row nowhere in this package; an override is
  satisfied by the ancestor that declares it, and the `Object` members are
  excused. Three summaries were completed in passing: `TomMessage.sms`,
  `TomUserPreferencesErrorHandler.invalidKeyKey` (whose section also claimed
  only one error key was translated when the source translates two), and
  `TomEndpointRouting.registerFrameworkApis`, `instantiateComponent` and
  `TomMethodMetadata.audited`. `authentication` and `object_persistence` carry
  34 members between them and are quarantined under `tcincb123_ahxt` and
  `tcincb124_ahxt`.

  Measuring it turned up four defects in the file's own reader, each of which
  had been quietly weakening the attribution check too. An annotation carrying
  arguments survived the modifier strip and was read as a declaration, so every
  entity class gained a phantom member named after its annotation; the wrapped
  tail of a constructor (`  }) : id = …`) is indented exactly like a member and
  contributed the vocabulary of its initialiser expressions; a member heading
  split by subject (`##### Methods — aggregates`, `##### Properties (DbCol)`)
  matched neither class nor member section, which closed the class and orphaned
  every row beneath it — seven dialect methods were invisible to every check
  that reads member rows; and `Static Constants` was not in the set of member
  headings at all. The heading walk the three checks now share is pinned by a
  fixture rather than by whatever the summaries happen to contain.

- **The summaries' one list of free functions is checked, and the scanner that
  reads it could not see two of them (tcinc470).** Every check in the coverage
  suite finds a member by finding its class, because a summary is organised as
  `#### <ClassName>` sections — and a free function has no class. Its only
  possible home is the module's `## Global Functions and Constants` section, so
  that section is not a convenience list but the sole place a top-level function
  can appear at all, and a section reading "None — this module exposes no
  top-level functions or constants" is a claim that can be false.
  `api_summary_db_migration.md`'s said exactly that while the module exported
  `frameworkOwnedTables`, the function from which a deployment learns which
  tables the framework owns; it now has a row with its full signature.

  The new group checks both directions across all twenty modules — a function
  absent from the section is undocumented, and a row naming something the module
  does not declare is worse, since a reader cannot tell it from a current one —
  and needs no quarantine, all twenty satisfying both.

  The scanner defect it exposed is the more serious half. `_functionDeclaration`
  required a return type starting with a letter, and a **record** type starts
  with `(`, so `extractAuthentication` — returning
  `(TomPrincipal?, TomClientJwtToken?)` — and `auditDiff` — returning
  `({Map<String, Object?> before, …})` — appeared in none of the sets the suite
  derives from source. Every check reading one had been excusing two documents
  from mentioning two exported functions, and reporting the result as agreement.
  That is the failure a guard is worst at surfacing, being indistinguishable
  from success: a parser blind to a declaration reads its absence from a
  document as a match. Both spellings are now pinned by fixtures rather than by
  whatever the package happens to contain, along with the getter, the private
  and indented cases, and the boundary between a function and a constant.

- **`api_summary_datasources.md` mirrors two source files it had never noticed,
  and two checks now make "never noticed" a failure (tcinc469).** The summary
  ran to 1116 lines about a unit of ten source files while naming eight of them
  in its `Source:` list, and the two it omitted were `framework_table.dart` and
  `sql_instant.dart` — the declaration from which every framework-owned table's
  DDL, column list, inserts and schema model are derived, and the one encoding
  of an instant in a `DATETIME(6)` column. Four public types and four public
  functions that the package barrel exports were absent from the document whose
  only purpose is to mirror the public surface. The summary now has a
  `### Framework-Owned Tables` section covering `TomFrameworkColumn`,
  `TomFrameworkKey` and `TomFrameworkTable` member by member, its Global
  Functions table lists all seven free functions rather than two, and the
  contents list, the class hierarchy and the Source list are extended to match.

  One row was not missing but wrong, which is the more expensive of the two.
  `TomDbDateTime.of` was documented as parsing its argument "via
  `DateTime.parse` (or `null` when `s` is `null`)" — the behaviour before the
  UTC convention landed. A reader who believed it would expect a local
  `DateTime` back and an empty column to throw; it returns UTC and treats `''`
  as absent. A stale row is indistinguishable from a current one, which is why
  a mirror is checked rather than trusted.

  The first of the two new guards asks a blunter question than anything already
  in `api_reference_coverage_test.dart`: not whether a documented thing is
  documented correctly, but whether the document knows the file exists. Every
  existing check — the Overview table, the Properties table, attribution,
  contract listings — measures what a summary already mentions, so a file it
  never mentions is invisible to all of them, and the more thorough the page
  looks the more completely the omission hides. Each summary's `Source:` list is
  now compared against the barrel's exports for that module, in both directions:
  an exported file missing from the list is undocumented, and a listed file that
  is no longer exported is worse, because it sends the reader to a page
  describing something they cannot import.

  The second asks the same question of `api_summary_index.md`, where the answer
  carries further. The index is the only place in the package where a reader can
  conclude that a name does not exist without opening a file — which is exactly
  why that conclusion must not be drawable wrongly there. Its two tables gain
  the thirteen datasources names they lacked, and the check pins every exported
  name against them.

  Both guards were measured across all twenty modules before being enforced and
  both found debt older than the module that exposed them: four modules'
  Source lists are short by eleven files, and 53 exported names across seven
  modules are in neither of the index's tables. Those are quarantined as visible
  skips naming their quest todos, each backed by a meta-test that fails when an
  entry has nothing left to suppress, so the exemption expires by itself rather
  than by being remembered.

- **`doc/datasources.md` documents three source files it had never mentioned,
  and the completeness check that lets it (tcinc468).** The guide contained no
  occurrence of `sqlInstant`, `parseSqlInstant` or `SqlPlaceholderScan`, and one
  bare mention of `TomFrameworkTable` in a bullet list. Three of the module's
  ten source files were therefore invisible to the document that is a
  consumer's entry point — including the instant helpers, which encode the
  module's UTC storage convention and were the one place a reader could have
  learned it. The guide now has a section for each, with a contents entry:
  `## Instants Are UTC`, `## Finding Placeholders in Quoted SQL` and
  `## Framework-Owned Tables`.

  The convention the first of those states is the substantive part. A MariaDB
  `DATETIME` carries no zone and the driver materialises one with
  `DateTime.parse`, which yields a *local* value — so a cluster's nodes write
  different characters for the same moment and read each other's rows off by
  the difference in their offsets. Both ways this server writes SQL now settle
  it identically, and the second is why the rule belongs in the guide rather
  than in each caller: a hand-written statement calls the helpers at each seam
  explicitly, whereas a `@TomDbColumn<DateTime?, TomDbDateTime>` field names no
  conversion at all and has one applied on its behalf at the bind boundary, in
  `TomDbDateTime.of`, and in `dateTimeOp`. An entity stores UTC and reads UTC
  without saying so, which is only discoverable if it is written down.

  The guard is the durable half. The Overview-table check already compared each
  guide's table against its module's exported *types*, but `datasources` was one
  of eleven modules quarantined from it, and could never have left: its table
  carries three `function` rows, which a types-only reading reports as naming
  things the module does not export. So `_exportedTypes` became `_exportedApi`
  and now reads top-level functions and getters as well — `function` is a value
  the guides' Kind column already takes, eleven times across the set. Top-level
  *variables* are deliberately excluded, because `messaging`'s two exported
  constants have no row in any guide and adding them would fail a module that
  passes today. With the table reconciled — thirteen rows added — `datasources`
  leaves the quarantine, which drops from eleven modules to ten.

  Two smaller readings had to be fixed to get there, and both were the check
  being wrong rather than the document. A generic written as
  `` `TomDbType<T>` `` is the type's name and reads better than the bare one, so
  the table read now drops the argument list instead of the guide dropping the
  type parameter. And a
  `CREATE TABLE tom_resource_grant (` line inside a multi-line DDL constant has
  the exact shape of a top-level function, so multi-line strings are stripped
  before the scan; comments are deliberately *not* stripped, every pattern being
  anchored at column zero where a `///` line cannot match one.

  A second check comes with it, one level up and with no quarantine at all: a
  guide's `## Table of Contents` must list every section, link only to sections
  that exist, and be in document order. That is the same completeness failure as
  an unlisted type — a section the contents list omits is a section most readers
  never learn exists — and adding a section is precisely when it happens,
  because the section is the part being thought about. All twenty guides satisfy
  all three conditions today.

  Finally, `sqlInstant` and its two companions had no direct test — only
  incidental exercise through the scheduling suites. A stated rule that nothing
  pins is the shape of claim tcinc466 and tcinc467 were both about, so stating
  the convention in the guide came with nine tests that hold it, including the
  local-reading trap itself.

- **`doc/datasources.md` gains a Verification section, and a named suite is
  made load-bearing (tcinc467).** The MariaDB driver chapter ended with a
  blockquote saying the unit tests covered "the connection-independent surface"
  — the dialect, the typed values, the transaction state machine — and named no
  suite. Two suites cover the driver. `test/datasources_test.dart` reaches much
  further than the blockquote allowed: the positional-parameter rewriting, the
  placeholder scan shared with `crud_repository`, `normalizeGeneratedId`,
  `parsePort` / `normalizePort`, the `initializeDatasourceInfo` guard,
  `isLostConnectionFailure`, and the connection lifecycle asserted state by
  state against every execution entry point. `test/datasources_db_test.dart`
  drives connect, `executeCommand`, row mapping, prepared statements and the
  transaction lifecycle against a live server. The reader was told about
  neither, and given no pointer to `tool/run_db_tests.sh`, which brings a
  throwaway MariaDB up on 3309 and runs the gated suite against it.

  The blockquote is replaced by a `## Verification` section in the shape the
  other guides use — `doc/cache.md`, `doc/cmdline.md`, `doc/configuration.md`
  and `doc/scheduling.md` each have one, always immediately before
  `## Core Components`, which is exactly where the blockquote was sitting. It
  states what each suite covers, why a connection-free suite can assert
  connection behaviour at all (the lifecycle table and the scripted
  `executeCommand`), and how to run the gated one — via the script, or against
  your own server through `TOM_CORE_SERVER_TEST_DB_*`.

  Why it went stale is again the durable half, and it is the same lesson as
  tcinc466 in a new domain: an unattributed claim is an uncheckable one. There
  was no suite name in the sentence, so nothing could falsify it and a second
  suite arriving changed nothing about it.
  `test/api_reference_coverage_test.dart` now requires every `…_test.dart` and
  `….sh` a guide names to be a file that exists — 36 references across the
  guides today — so moving a suite fails the build and puts whoever moved it in
  front of the prose. A path in a sibling sample package is excused when the
  paragraph names that package, which is the same information a reader needs to
  make sense of it. The paragraph walk the tcinc466 check introduced is now
  shared by both.

- **A claim of unfinished work has to live where it gets swept (tcinc466).**
  `doc/datasources.md` told the reader that escaping of directly-interpolated
  literals was "a tracked follow-up — see the completion steps". It is not: the
  escaping is in `TomStandardSqlDialect.text`, and had been for as long as the
  sentence was wrong about it. So the one document a consumer reads first was
  warning them off a facility that works and pointing them at a follow-up that
  is closed.

  The sentence is replaced by a statement of what the escaping does — an
  embedded single quote is doubled and a backslash escaped, so a value cannot
  terminate its own literal, and `objectOp` routes strings and anything it does
  not recognise through `text`, so the path the expression tree takes on its
  own is covered. The advice to prefer `p(name)` for untrusted input stands
  unchanged: binding out-of-band means nothing has to escape correctly for the
  value to be safe. That behaviour was also entirely unpinned — the only
  assertion on `text` was `d.text('abc')` — so `test/datasources_test.dart`
  gained the injection shape, the backslash, and the three routes through
  `objectOp` including the `toString()` fallback an unforeseen type arrives on.

  Why it went stale is the more useful half. A claim that something is *not
  finished* cannot be checked against the source, because the absence it
  asserts looks exactly like an absence that is intended. What can be checked
  is where it was written. Ten guides collect what they have not done under
  `## Not Yet Implemented` and `doc/authentication.md` under `## Status and
  Limitations`; those sections get re-read when work completes. This one claim
  sat in the middle of a chapter, where no sweep would ever pass over it.
  `test/api_reference_coverage_test.dart` now enforces the placement, and the
  staleness follows from it. The unit of judgement is the paragraph rather than
  the line, because these guides wrap at eighty columns and a claim and the
  signpost that excuses it routinely land on different lines — a guard whose
  first report is a false alarm gets deleted rather than heeded. A heading is
  read as ordinary prose, so a rival `### … not yet implemented` heading
  outside the section is reported too: a second place collecting unfinished
  work is the arrangement the check exists to prevent.

- **Contract listings are checked against source for what is abstract
  (tcinc465).** In an `abstract class X { … }` listing a bare declaration is a
  demand on the reader and a declaration with a body is a gift, and nothing
  checked which one the source meant. `TomDataSource.isOperational` returns
  `true` and was shown bare, so a driver author implemented a method they
  already had — and the override displaces a default that a `extends`-based
  driver was relying on. `doc/messaging.md` had three of the same slip:
  `TomMessageTransport.supportsCopies`, `supportsAttachments` and `close` all
  carry defaults, and the two `supports…` ones default to `false` precisely so
  a transport that has never considered attachments cannot be handed one.
  Presenting a safe default as a chore invites a careless `true`.

  `test/api_reference_coverage_test.dart` now compares every member of every
  contract listing in `doc/*.md` against the declaration in `lib/`. The
  comparison is symmetric — both sides are measured by whether the declaration
  ends at a `;` or at a body — with `static`s and constructors excluded, since
  neither is ever abstract however it is written. Fixing it turned up a parser
  blind spot with the same shape: a trailing `//` comment was read as the
  member name, and it is the *bodiless* members that carry one, so exactly the
  members worth checking were being skipped. `doc/messaging.md` also gained the
  `checkSupported` method its surrounding prose already described, and a
  sentence stating the bare-versus-bodied convention rather than leaving a
  reader to infer it.

- **Every documented member is checked against the class that declares it
  (tcinc464).** An API summary is organised as `#### <ClassName>` sections, so a
  row's position is itself a claim of ownership — and that claim was unchecked.
  The existing coverage guard asks whether a member is documented *somewhere*;
  it is equally satisfied by a correct row filed under the wrong heading. The
  datasources completion document listed `mapGroupedRow` under
  `MariadbPreparedStatement`, the class it is *about* (being the reading half of
  a grouped query), rather than `MariaDbDatasource`, the class it is *on*. The
  summary mirror had it right, so the two documents contradicted each other
  about where a public static lives, and a reader trusting the wrong one writes
  `MariadbPreparedStatement.mapGroupedRow(...)` and gets a compile error naming
  a class they were told to use.

  `test/api_reference_coverage_test.dart` now derives ownership from the source
  instead of reviewing it, resolving each documented row against the declaring
  class and its supertypes. The resolution is deliberately three-valued —
  *declared*, *absent*, or **undecidable**, the last when a class inherits from
  a type this package does not declare (as `TomConfigurationException` does from
  the kernel's exception base). Only *absent* fails: reporting a member missing
  because the parser could not see the class that declares it would be a false
  alarm, and a guard that cries wolf is turned off. The census covers 420
  classes and 1644 rows with 4 undecidable, and the undecidable share is itself
  asserted below 2% so the blind spot cannot grow in silence.

- **Documented data-source settings keys are checked against the driver's
  fields (tcinc463).** A settings key is a field name: `initialize` hands the
  whole configuration block to `tomReflectionInfo.setValues`, which assigns
  through the setter the key names. The shared converter tolerates unknown
  fields by design, so a key naming no field is dropped in silence — a block
  written with `database` and `user` (what most database documentation calls
  them) produces a data source pointed at no schema with no credentials, and a
  connection error that names neither. The module's completion document had
  exactly that block, contradicting both `doc/datasources.md` and its own field
  listing eight pages earlier.

  `test/datasource_config_test.dart` now sweeps `lib`, `doc`, `example` and
  `test` for configuration blocks — anchored on `type: mariadb`, in YAML and
  Dart, inline and multi-line, inside dartdoc as well as code — and fails on
  any key outside the bindable set. That set is *derived from reflection*
  rather than listed, so renaming a field on `MariaDbDatasource` fails the
  suite too instead of quietly invalidating every documented example. A
  companion assertion pins the sweep against reaching nothing, since a guard
  mistaken for coverage is worse than none.

- **`TomSqlDialect` is removed; a driver owns its dialect (tcinc462).** The
  annotation bound a `TomStandardSqlDialect` subclass to a data-source type
  name, for a reflection scan nobody ever wrote: `dataSourceType` had exactly
  one occurrence in `lib`, its own field declaration. `MariaDbDatasource`
  returns a `MariadbSqlDialect` directly, so the annotation on that class
  decided nothing, and a dialect registered for a second database would never
  have been found.

  Four documents nevertheless described the lookup as the mechanism — the
  dialect's class dartdoc, the annotation's own dartdoc, `doc/datasources.md`,
  and the module's completion document — which made the one thing
  `MariadbSqlDialect` actually contributes (classifying `TINYINT(1)` as a truth
  value) look like it arrived by registration when it arrives by construction.

  Implementing the scan was the alternative, and it would have been a second
  answer to a settled question. Reflection already resolves one thing by
  data-source type name: the *driver*, through `@TomDatasourceDriver`. A driver
  arrives knowing its dialect and hands it out through `TomDataSource
  .sqlDialect`, so a registry keyed on the same string could only restate that
  or contradict it — at the cost of turning a statically checked constructor
  call into a runtime lookup with a duplicate-registration failure mode. The
  annotation and the `@tomReflector` that existed only to feed it are gone,
  and a dialect for another database now ships as part of that database's
  driver.

  Five tests pin the route that replaces it: both MariaDB drivers render
  through `MariadbSqlDialect`, a driver hands out one dialect rather than one
  per call, the `TINYINT(1)` rule is reached *through* `sqlDialect` rather than
  a hand-built dialect, and no file under `lib/` or `doc/` mentions a dialect
  lookup by type name again.

- **The plain `endTransaction` says what it is instead of looking unfinished
  (tcinc451).** `MariaDbDatasource.endTransaction` was a `try` block whose only
  live statement was `return true`, wrapped around a commented-out `await
  executeCommand("XA END $_txId; XA PREPARE $_txId;")`, with a catch that could
  never run. The commented line was not merely disabled: `_txId` is a field of
  the `MariaDbXADatasource` subclass, so restoring it would not have compiled.
  The whole shape read like a half-finished port from the XA variant, and left
  the next reader to work out whether something was missing.

  Nothing was missing — the body is now `async => true` with a dartdoc giving
  the reason. A one-phase `COMMIT` has no prepare step to issue, and there is no
  per-transaction state left to release either, because `commit` and `rollback`
  lower the in-transaction flag themselves and the coordinator always calls one
  of them first. Reporting `true` is load-bearing rather than a formality: the
  coordinator ands every participant's result into the outcome, so a `false`
  would fail a transaction that had in fact completed.

  Two tests were added first, as characterization: they passed against the old
  body, which is what established that the reduction changed no behaviour. Their
  value is in the assertion on the recorded command list — a return value alone
  cannot distinguish an intentional no-op from a forgotten body, whereas a
  statement reappearing here shows up at once.

- **`lib/src` no longer imports its own package (tcinc445).**
  `base_server_configuration.dart` imported
  `package:tom_core_server/tom_core_server.dart` — the barrel that exports it.
  It reached seven symbols that way and received the entire package, plus
  `mysql_client` and `tom_core_kernel`, in exchange. It now imports the kernel,
  `../cmdline/args.dart`, `../cmdline/env_file.dart`, `../server/server.dart`
  and `tom_config.dart`, which is the whole of what it uses.

  The cost was never compile time. Through the barrel, `configuration` appeared
  to depend on every module in the package, which is indistinguishable from
  depending on none: the import list is where a reader learns whether a module
  can be lifted out and what an edit here can reach, and it said nothing. Two
  facts were hidden by it and are now legible — that `configuration` depends on
  `cmdline`, because `getDefaultValues` parses the environment and the command
  line rather than only reading a tree, and that `configuration` and `server`
  import each other, since the class supplies a pipeline default that lives in
  `server`. That cycle is not new and is legal Dart; it was simply invisible.

  A guard test, `test/library_structure_test.dart`, now fails on any file under
  `lib/` that imports `package:tom_core_server/`. Writing it first was what
  found the rest: a grep for the barrel path caught two files, and the test
  caught a third — `little_things/server_exception.dart` reached into
  `package:tom_core_server/src/tomserver/server/server.dart`, an absolute path
  into the package's own private tree, which is the same defect in the spelling
  that no grep for the barrel would ever match. All three now use relative
  imports.

  The recurrence is structural rather than careless, which is why it is checked
  rather than remembered: every module readme opens its quick start with the
  barrel import, because that is the correct import for a consumer. Copying
  that line into a source file is the obvious mistake to make.

  One dartdoc link changed as a consequence. `[TomHealthService]` on
  `loggingMiddleware` became a plain code span: it is a `healthcheck` type, and
  `healthcheck` depends on `configuration`, so importing it to keep the link
  live would have added a second cycle for the sake of a hyperlink.

- **`TomYaml.mergeInYamlFile` now delegates to `loadYamlFile` (tcinc442).** The
  two methods shared four of their five lines — read, `loadYaml`,
  `makeCleanJsonMap`, `substituteEnvVars` — and differed only in whether the
  tree was returned or merged. `mergeInYamlFile` is now
  `mergeMapsOneSided(result, loadYamlFile(filename))`, and `loadYamlFile` is
  declared first as the class's only loader.

  The duplication had already cost documentation once: `loadYamlFile` carried
  the `${VAR_NAME}` / `${VAR_NAME:default}` syntax with a worked example and
  `mergeInYamlFile` carried a single summary line, though it performed exactly
  the same substitution. Its dartdoc now points at `loadYamlFile` for the
  placeholder syntax instead of restating it, so there is one place to keep
  current.

  A test was added first, and deliberately not a restatement of an expected
  tree: it loads one file through both entry points and requires the results to
  be equal. That is the invariant the duplication put at risk and the one thing
  nothing checked — dropping `substituteEnvVars` from the `mergeInYamlFile`
  copy alone left every pre-existing `TomYaml` test green. The
  throw-before-touching guarantee also survives the change, now because the
  load is an argument to the merge rather than a statement before it.

- **The cmdline example reaches every `TomEnvFile` method it should
  (tcinc430).** It ran five steps and demonstrated two of the five methods:
  `parse`, `readAsync` and `load` appeared nowhere, though the API mirror lists
  all five and the prose document shows `readAsync` in a snippet of its own. The
  header explained one omission — `fillFromArgs`, which needs a reflected type —
  and the other three had neither a demonstration nor a mention.

  Two steps were added. `parse` now takes a blob that arrived from a secret
  store and never touched disk, which is the case the method exists for and also
  what `read` is built on; it doubles as the example's statement of the
  first-`=` rule, since the blob carries a URL with a query parameter.
  `readAsync` reads the same file as the sync step and is required to return
  what `read` returned, and the missing-file step now exercises both variants,
  so neither needs an existence check first.

  `load` keeps its omission and now has a stated reason: it calls `read` and
  returns the result, and `doc/cmdline.md` already lists it as a limitation
  advising `read` instead. An example is a recommendation, so demonstrating it
  would contradict that advice. What becomes of the method is a separate open
  question and is not settled here.

  Two guards were added or repaired, because fixing the instance does not fix
  the class. A test now reads the public method list off `env_file.dart` and
  requires each name to be either demonstrated by the example or named in its
  header, so a method added later cannot go unmentioned unnoticed; adding an
  unreferenced method to the class fails it, naming that method. The existing
  step-count check was hard-coded to five and so would have kept passing while
  covering neither new step — it now derives the numbers from the example and
  additionally requires them to run `1..n` without a gap.

- **The `.env` first-`=` rule is now tested on the `.env` side (tcinc429).** The
  headline claim for `TomEnvFile.parse` is that it splits on the *first* `=`, so
  a value carrying more of them survives whole; the module documentation makes
  the point with `DB_URL=mysql://host/db?user=root`, whose query parameter is
  data rather than a second pair. The behaviour was correct, and untested. The
  `TomEnvFile.parse` group covered pairs, comments, quoting, inline comments,
  empty values and malformed lines, but no value containing a second `=` — the
  same gap that let the equivalent `TomArgs` defect survive until tcinc415.

  Three tests now mirror, on the `.env` side, the set the command-line group
  already carried: the documented URL (asserting both that the single key is
  `DB_URL` and that the value is whole), a padded base64 blob, and a value that
  is nothing but `=` characters. A line with one `=` cannot put the question at
  all — first and last pick the same key — so each case carries a second one
  that is data.

  The cross-source test that appeared to cover this was strengthened in the same
  pass. It compared `TomArgs.parseArgsToMap` to `TomEnvFile.parse` on a URL and
  asserted only that the two agreed, which a regression in both at once — the
  likely shape, given how much of the rule the two state in common — would
  satisfy while agreeing about the wrong answer. Reverting both parsers to
  `lastIndexOf` confirmed it: they returned identical, identically wrong maps.
  The test now names the map it expects, so it pins the rule as well as the
  agreement.

- **The single argument parse is now enforced, not just present (tcinc428).**
  `fillFromArgs` and `parseArgsToMap` once carried byte-identical parse loops,
  which is why the first-`=` split and the bare-flag rule each had to be
  corrected in two places. The duplication itself was already gone — extracting
  `_parseArgs` removed it as a side effect of the first-`=` fix — but nothing
  held it gone, and `_parseArgs`'s own dartdoc claims the two "cannot disagree".

  Two tests now pin that claim, guarding failure modes that do not overlap. A
  behavioural one runs a fifteen-case corpus of the argument syntax through both
  entry points and requires every reflected field to equal the map entry for its
  key — including the case no argument supplies, where the map's silence and the
  field's initialiser must agree. A source-level one requires `args.dart` to
  walk the argument list exactly once.

  The second is not redundant: re-duplication does not announce itself as
  disagreement. A fresh copy of the loop starts out agreeing perfectly — which
  is precisely why the original pair went unnoticed — so the behavioural test
  passes on the day the duplicate lands and only fails later, once the copies
  drift. Verified by falsification: an identical duplicate fails the source test
  alone, while one reverted to `lastIndexOf` fails both, the corpus naming the
  case and field that disagree.

- **A cmdline test named for first-`=` splitting now asserts it (tcinc423).**
  The test titled "keeps only the text before the first `=` as the key" parsed
  `key=value` — one `=`, where splitting on the first and splitting on the last
  give the same answer, so the question its title raised was never put. It was
  a guard in name only: reverting `_parseArgs` to `lastIndexOf` left it passing.

  It now parses `key=a=b` and asserts the key set is exactly `['key']` — not
  `key=a`, and no second entry — which is the key side of the split. The four
  tests below it assert the value side, so the rule is covered from both
  directions; under the same reverted implementation the renamed test fails.
  Its comment, which described an implementation of `split`/join that no longer
  existed, was already removed with the fix in tcinc415; the new one names what
  `_parseArgs` actually does.

- **The cache registry is declared `Map<String, TomCache>` (tcinc412).**
  `TomCacheManager` held it as `Map<Object, TomCache>`, but the only write is
  `_caches[cache.cacheName] = cache` with a `String` `cacheName`, and the only
  read is `getCache(String name)` — so the key type was wider than anything that
  could be put in or taken out. It admitted a key `getCache` could never reach,
  and cost a reader the moment it takes to work out whether a cache can be
  registered under something other than its name. It cannot. The narrowing is a
  no-op the analyzer proves: if any site had needed the wider type it would no
  longer compile, and every suite is unchanged.

- **`removeEntry` is now `TomCache`'s only chain-unlink routine (tcinc409).**
  `putEntry` held two further copies of it — one for replacing an existing key,
  one for evicting the least-recently-used entry — and the eviction copy had
  drifted: it reassigned `_last` inside `if (oldLast._before != null)` but
  removed from the map outside the guard, so the guard's false branch would
  have left the chain's tail pointing at an entry no longer in the map. That is
  the same shape as the three chain defects fixed earlier in this release.

  The branch is unreachable as the module stands — eviction runs only after a
  fresh head has been linked, so the tail always has a predecessor — and
  planting a `throw` in it leaves the whole suite green. It is therefore a
  latent hazard rather than an observable bug, and reverting the change leaves
  the suite green too. Both copies now call `removeEntry`, which repairs head
  and tail on every branch and is already what the deletion sweep uses; having
  one routine is what stops a fourth copy from drifting. A new differential
  test checks a bounded cache against a naive LRU of the same bound across a
  randomised operation mix, and turns red if either of `removeEntry`'s repairs
  is dropped.

### Behaviour Changes

- **`TomServerException.isolateName` and `TomServerException.clientThrow` are
  now `final` (tcinc568).** Both were plain mutable fields, which put the
  `isolateName` dartdoc at odds with its own declaration: it promised the name
  was "resolved at construction time" while the field let any holder overwrite
  it afterwards, so nothing about a logged attribution could be relied upon.
  `clientThrow` had the matching problem one level up — a subtype that omits
  the parameter (fifteen of the twenty-eight do) was documented as fixing a
  behaviour it only fixed as a default.

  An exception is a value describing something that has already happened, and
  both fields record a fact about the moment it was raised: which worker
  produced it, and whether the party that wrote the message intended it for a
  client. Neither is a decision for a later frame to revise. A catch site that
  must not surface a particular failure masks it in the response it builds
  instead of rewriting the error's account of itself.

  Nothing in `lib/` ever assigned to either field: the seven `clientThrow`
  overrides all pass through `super.clientThrow`, and `server.dart`'s
  `body["clientThrow"]` is a read. The only mutation anywhere was one test
  asserting the mutability itself, which is deleted; the sibling test now
  states the invariant rather than the starting value. Generated reflection
  code is unaffected — the `isolateName=` setters in `*.reflection.dart` belong
  to the kernel's `TomLogMessage`, and no generated file mentions `clientThrow`
  at all.

- **`TomLoginException` and `TomCacheException` name their second constructor
  argument `defaultUserMessage`, as every other exception type does
  (tcinc567).** Both declared it as `super.userMessage`. Dart allows that — a
  positional super-parameter need not reuse the super constructor's parameter
  name, which is why the analyzer was silent — but it gave one argument two
  public names: the IDE hint at a `TomLoginException(...)` call site read
  `userMessage`, while the field the caller then reads off the caught object is
  `defaultUserMessage`, because that is the base field name and the subclass
  spelling never existed as anything but a label.

  No call site changes: the argument is positional, so the name was never
  written at a raise site. The scan that produced this finding named only
  `TomLoginException`; a sweep of `super.userMessage` across the workspace
  found `TomCacheException` as a second instance, and both are fixed here.

- **`LoginException` is renamed to `TomLoginException` (tcinc566).** It was the
  only exported exception type in the package without the `Tom` prefix, and it
  is declared in `little_things` directly beside `TomServerException`, the base
  it extends — so the inconsistency was visible within a single file.
  `LoginException` is also a plausible name for an application's *own* type,
  and the barrel was occupying it in every consumer's namespace.

  The rename is mechanical but carries one trap: `TomServerSelfLoginException`
  contains `LoginException` as a substring, so a plain search-and-replace turns
  it into `TomServerSelfTomLoginException`. The rename was applied with a
  negative lookbehind on the preceding identifier character, and the
  `TomServerSelfLoginException` occurrence count was verified unchanged
  afterwards.

- **`TomServerException.toString()` labels the request UUID and omits it when
  there is no request (tcinc565).** The rendering ended
  `client-throw: $clientThrow $requestUuid`, interpolating the correlation id
  bare. Outside a request that produced a trailing `null` — indistinguishable
  from the three other nulls the base contributes, and reading as a stray value
  or a formatting fault rather than as data. It is now
  `client-throw: $clientThrow` plus a ` request: <uuid>` segment that is present
  only when the exception was raised inside a request zone.

  The labelled copy is not redundant with the base string. `TomException` leads
  with the composite token `<exception-uuid>-<request-uuid>`, and because v4
  UUIDs contain hyphens themselves that token cannot be split back into its two
  ids by eye or by a simple pattern — the trailing segment is the only greppable
  form of the correlation, which is why it is labelled rather than dropped.

- **The health-check module's three off-convention names are renamed
  (tcinc558).** `HealthAnalyzer` → `TomHealthAnalyzer`,
  `DefaultHealthAnalyzer` → `TomDefaultHealthAnalyzer`, and the static field
  `TomHealthServer.globalSettingsHealthAnalyzer` → `TomHealthServer.healthAnalyzer`.

  The two types were the module's only unprefixed ones, sitting beside
  `TomHealthService` and `TomHealthServer`. The package does export other
  unprefixed types, but each belongs to a group with a reason — the query DSL
  (`And`, `Eq`, `Gt`), terse on purpose, and the driver classes
  (`MariaDbDatasource`), named after what they wrap. A general-purpose
  extension point is neither, and `HealthAnalyzer` is a plausible name for an
  application's *own* type, which the barrel was occupying in every consumer's
  namespace.

  The field name was worse than merely inconsistent: `globalSettings*` matched
  no other identifier in `lib/src`, and none of it was true — the field is not
  a settings object and is not read from settings. What the prefix was
  gesturing at is that the field is `static`, and that is now stated in its
  dartdoc, where a reader can act on it: one assignment applies process-wide,
  to every request and every `TomHealthServer` instance, with no per-instance
  or per-request override. Dropping `global` from the identifier is only safe
  because the comment picks the fact up.

- **The nested-transaction guard throws the module's own exception type
  (tcinc460).** Both `startTransaction` implementations signalled a second
  concurrent transaction with a bare `Exception` carrying a message. `Exception`
  is the supertype of every failure there is, so a caller could not write a
  `catch` narrow enough to act on the one case it is able to fix, and the
  DB-backed test could assert nothing stronger than `isA<Exception>()` — which
  would have passed just as happily on a driver that had fallen over.

  The distinction the type has to carry is real and already load-bearing in this
  code. A `START TRANSACTION` the database refuses comes back as `false`: the
  caller may retry, route around it, or give up. A start on a data source
  already in a transaction is the caller's own mistake, and no retry fixes it —
  which is why the guard sits in front of the `try` rather than inside it, where
  the catch-all that turns a failed statement into `false` would swallow it and
  hand back the wrong one of those two answers.

  Both guards now route through one private helper, `_refuseNestedTransaction`,
  raising `MariadbDatasourceException` keyed `error.transaction.already_active`
  with the participant in `parameters` and — for XA, which mints one — the open
  branch in `transactionId`. Sharing the helper is not just tidiness: the two
  messages had already drifted apart (one ended in a full stop, the other in an
  interpolated id), and one refusal reported one way is what stops them drifting
  again. `MariadbDatasourceException` *is* an `Exception`, so nothing that
  catches broadly breaks; what changes is that something narrower can now be
  written. The DB-backed test asserts the specific type and key.

- **`MariaDbDatasource.close` lets go of the connection, so a closed data source
  is closed (tcinc459).** `close` released the socket but left `connection`
  pointing at the dead object. Everything that reports state reads that field,
  so the data source went on describing itself in terms of a connection that was
  gone; and the `else` branch — reached whenever the link had already dropped —
  logged that it was not closing anything and left the handle in place too.

  The reporting was the visible half. The consequential half is that
  `_openConnection` repairs a *dropped* link by testing exactly that field, so a
  statement arriving after `close` found a link there, decided it had merely
  dropped, and quietly dialled a new one. Deliberate teardown is not a dropped
  link: re-opening resurrects a data source the application let go, and on the
  shutdown path (`TomDataSourceInfo.closeAll`, which leaves its entries in the
  registry) opens a socket nothing is left to close. This was predicted rather
  than discovered — it is the production reachability tcinc458's M10 mutation
  note said would arrive once this todo was fixed.

  `close` now clears `connection` in a `finally`, so it releases the link
  whatever state it was in and even when closing it throws — a failed close
  still means the caller is done with the handle, and the failure is still
  reported. A closed data source therefore refuses statements exactly as one
  that was never opened does, with the same `error.datasource.not_opened`.

  Which of the two not-open states it is now rides in the exception's `state`
  parameter (`"closed"` / `"never_opened"`) and in `toString` (`closed` /
  `never opened`, in place of the old `no connection`), rather than in the key:
  a caller matching "this data source has no connection" should not have to
  match twice, but a reader diagnosing it needs the distinction, because the two
  point at different faults — configuration or start-up ordering versus shutdown
  ordering. Closing a data source that was never opened releases nothing and
  leaves it reading as never opened. Seven tests; twelve mutations of the rule
  each killed.

- **Every `MariaDbDatasource` entry point follows one connection-lifecycle rule
  (tcinc458).** The three execution entry points disagreed about what to do when
  no connection was open: `prepareStatement` connected on demand, while
  `executeQuery` and `executeCommand` threw. The same data source was therefore
  usable or unusable depending on which method a caller reached for first, and a
  caller that prepared before it queried never saw the error the other two
  raised. Nothing in the class dartdoc or in `doc/datasources.md` said which was
  intended.

  The rule now stated in both, and implemented once: **a data source is opened
  explicitly — by `initialize(settings)`, or by setting the connection fields
  and calling `connect()` — and never by the statement that wants to run.**
  Connecting on demand was not adopted, because it could not work: `connect()`
  binds `host`, `port` and the credentials, which arrive only from `initialize`
  or a direct assignment, so before either it would dial `:-1`. That turns
  "never opened" into "the database is unreachable" and sends an operator to the
  network for a configuration bug. The interface's own contract agrees
  (`TomDataSource.initialize` is documented as opening the connection,
  `TomDataSourceInfo` exposes a data source only after it succeeded, and both
  documented quick-starts call `connect()` explicitly), and two of the three
  entry points already behaved this way.

  A single private helper, `_openConnection(operation)`, is now the only
  implementation of the rule, and the four sites that need a link all go through
  it — the three entry points plus the reconnect-and-retry inside
  `MariadbPreparedStatement.execute`. A never-opened data source is refused with
  `error.datasource.not_opened`, naming the calling entry point in the
  exception's `operation` parameter; a link that *was* opened and has since
  dropped is still re-opened automatically, which is the half that had to
  survive. The two old keys it replaces
  (`error.result_processing.executequery_no_connection` and
  `…executecommand_no_connection`) had no other user.

  Discovering that `mysql_client`'s connection and statement classes are plain
  (implementable) closed a gap tcinc457 had recorded as unclosable: with fake
  link, statement and result-set doubles the reconnect half, the retry loop and
  its refusal on a torn-down data source are all now covered without a database.
  Eight tests assert each entry point on a never-opened source, that all three
  refuse with the same key, that a dropped link is re-opened and the statement
  runs on the *new* link, that a live link is used as it stands, and both retry
  cases. Eleven mutations of the rule were each killed by the suite.

  In passing, `executeQuery`'s failure mapper now attaches `rootException` and
  `stack` as `executeCommand`'s always did — the same severed chain tcinc457
  repaired in `_execute`, in a method being rewritten anyway. Without it
  `classifySqlFailure` cannot reach the server's own verdict.

- **A dropped connection is recognised by the link's state, not by the wording
  of an exception (tcinc457).** `MariadbPreparedStatement._execute` decided
  whether a failure was worth one reconnect-and-retry with
  `"$e".contains("connection closed")` — it stringified a third-party
  exception and searched for a phrase. Nothing holds that wording still; a
  dependency bump could turn the retry off silently, with no compile error and
  no failing test.

  The obvious replacement — match the driver's exception type — would have
  been a regression, and the new tests say so. `mysql_client` reports a link it
  already knows is gone as a bare `MySQLClientException` carrying **no error
  code**, and raises that *same type* for a protocol desync, a second `BEGIN`
  and a failed handshake. Retrying those re-runs a statement that a second
  attempt cannot fix.

  What actually distinguishes them is the link, and the driver publishes it:
  every "connection closed" it throws sits behind its own `!connected` guard,
  so `MySQLConnection.connected` recognises exactly those cases by documented
  API. The new `isLostConnectionFailure(error, connected:)` in
  `sql_failure_mode.dart` requires that *and*
  `classifySqlFailure(error) == ambiguous`, because a `MySQLServerException`
  beneath the failure means the server received the statement and rejected
  it — a verdict that stands however the link looks afterwards. The same
  file's existing classifier is asked rather than repeated. `MariaDbDatasource`
  already used `connection.connected` for this question in two other places
  (`executeQuery`, `isOperational`); the prepared-statement path was the one
  that read prose instead.

  Two consequences worth naming. The check is now marginally *broader* — a
  failure of any type raised while the link is down is retried, where before
  only one phrase was — and that is the correct direction: reconnect-and-retry
  is exactly the right response to a statement that had no live link. And both
  branches of the mapper now attach the driver exception as `rootException`
  with its stack, which they did not before. That was its own defect:
  `sqlFailureCauses` and `classifySqlFailure` are documented to walk that
  chain, so a chain ending at this layer made every prepared-statement failure
  look `ambiguous` to a caller that asked. `executeCommand` had always attached
  it; this path had not.

- **`@TomReference` resolution is separated from the connection, and is now
  tested (tcinc456).** Two private helpers in `mariadb_datasource.dart` were the
  largest block in the file and read like abandoned scaffolding.
  `_referenceValueStack` was a six-parameter `async void` wrapper around a
  single `list.add`, called without `await`. `_referenceValuesGet` declared a
  type parameter `TBLTYPE` its body never used, carried a commented-out line in
  the middle of a 257-line body, and returned the constant `1` regardless of
  what happened. Neither was exercised by any test.

  Neither was dead, either. `_referenceValuesGet` is the *whole*
  implementation of `@TomReference` — the second query that fills an
  association after its owning row has been mapped — and `tom_uam_server`
  depends on it for five associations. It was untested because reaching it
  required a live database, which is also why the scaffolding around it could
  decay unnoticed.

  The construction of the reference query is now
  `TomAnnotationAnalyzer.referenceQuery`, a pure function returning the
  `FIND BY` sentence and the parameters it binds. It needs no connection, no
  reflector and no entity — the mapped row is represented by a field-read
  callback — so the sixteen behaviours it implements are now asserted directly,
  including seven rejections that previously existed but could not be reached.
  What remains in the data source is the part that genuinely needs a
  connection: compile, run, write back.

  Three behaviour changes fall out of the split. **The rejection exceptions
  moved** from `MariadbDatasourceException` with `error.result_processing.ref_*`
  keys to `TomAnnotationAnalyzerSyntaxException` (a malformed expression is an
  authoring error in the annotation, not a MariaDB failure) and
  `TomAnnotationAnalyzerException` (a context entry the running zone cannot
  supply), under `annotation_analyzer.reference_query.*` keys. **Two new
  rejections** close gaps: an expression without exactly one `=` used to fail as
  an unhandled pattern-match error, and a reference declaring no columns at all
  used to emit the sentence `FIND BY ` — it constrains nothing, so it would have
  loaded every join row for every owner row. **Syntax is now checked before the
  context is read**, so a typo is reported as a typo rather than as a missing
  context value it never worked out how to ask for.

  A separate defect surfaced under the same reading. The pending-reference stack
  was declared *outside* the row loop and drained *inside* it, and never
  cleared — so row *k* re-resolved every earlier row's associations, turning one
  query per association into a quadratic number of them. The stack is now
  per row.

- **A delete's `ORDER BY` names the column instead of the Dart field
  (tcinc455).** `TomDelete.generateQuery` passed its `sort` list straight to
  `TomGeneratedQuery.orderByClause`, which — as its own dartdoc says — emits
  every term verbatim and expects callers to have resolved them. `TomSelect`
  does exactly that, mapping each term through `determineColumn` before
  rendering; `TomDelete` did not. So `delete by … order by createdAt` rendered
  `ORDER BY createdAt` against a column named `created_at`: invalid SQL for any
  entity whose Dart field name and column name differ, which is every entity
  using the customary camelCase-to-snake_case mapping.

  A sort term may legitimately be *written* with either name — the lookup
  matches the column name, the qualified `table.column`, the `Type.field` form
  and the declared field name alike — which is why the defect hid: every sort
  in the existing suite happened to name a field whose column spelling is
  identical (`amount`, `title`), so nothing rendered a name that differed.

  The second half of the defect was a missing guard rather than a wrong name.
  Sort names routinely arrive from outside (an HTTP `sort=` parameter, a query
  sentence) and an `ORDER BY` cannot bind them as parameters, so the column
  lookup is what keeps an arbitrary string out of the statement text. A delete
  had no lookup at all: at HEAD, `delete by … order by nosuchfield` compiled and
  rendered `ORDER BY nosuchfield ASC` rather than throwing.

  Rather than give `TomDelete` a third copy of the resolution loop, the loop
  moved to `TomGeneratedQuery.resolveSortColumns`, beside the `orderByClause`
  whose contract requires it — so the step and the requirement are now read
  together. `TomSelect`, `TomDelete` and `CrudRepository.findAll`'s windowed
  literal select all call it; `CrudRepository._resolveSortColumns`, the second
  copy, is gone. Its `qualified` parameter picks the rendering and never the
  lookup: a select may span tables and so emits `table.column`, while MariaDB's
  single-table `DELETE` has nothing to disambiguate and emits the column bare.

  `TomGroupedSelect` deliberately does *not* resolve, and now has a test saying
  so. A grouped result orders over what it projects — an aggregate alias has no
  column, and a group column is projected `AS <declaredName>` — so resolving
  would break both; its guard is instead that a term the query does not project
  is refused outright. Seven mutations were run against the new behaviour (the
  delete un-resolved again, the resolver keeping the written name, the
  qualification inverted and each form given the other's rendering, the
  direction dropped during substitution, and the grouped select made to resolve
  too); all seven were killed.

- **A count no longer accepts a window or an ordering it cannot honour
  (tcinc454).** `TomCount` took `orderBy`, `ascending`, `sort` and `top` through
  its constructor and its `generateQuery` read none of them: it rendered the
  projection, the `FROM` and the `WHERE` and stopped. `TomCount(top: 5)`
  returned the count of the whole filtered set, with no error and no warning,
  and the sibling `TomSelect` renders both clauses from the same fields — so
  the API shape promised something the class never did. The class dartdoc
  already said a count has no row window; the constructor contradicted it.

  The four parameters are removed rather than rendered, because rendering them
  cannot fix the reported symptom. `LIMIT` caps the rows *returned*, and a count
  returns one row whatever the cap, so `SELECT COUNT(*) … LIMIT 5` would still
  count every matching row — the caller would get the same wrong answer, now
  with extra SQL to explain it. An `ORDER BY` beside a bare `COUNT(*)` likewise
  has a single row to order. The question `top: 5` is reaching for — "are there
  at least five?" — is a different statement (a `COUNT(*)` over a capped
  subquery), not this one with a clause bolted on.

  The query-sentence grammar moves with the constructor: `count first 5 by …`
  and `count … order by x` now raise `TomQuerySyntaxException`
  (`top_unsupported_for_count`, `order_by_unsupported_for_count`) instead of
  compiling into a query that ignores them. This extends a rule the compiler
  already had — a count has rejected `skip`/`offset` explicitly for some time —
  to the other two thirds of the same idea. A side-effect worth naming: because
  a skip requires a cap and a count may no longer have one, no count sentence
  can reach the skip rule any more, so that rule is now a `DELETE` rule and its
  message no longer claims otherwise. `TomDelete` is unaffected and keeps both
  clauses: `DELETE … ORDER BY x LIMIT n` picks *which* rows go.

  `_scopedCount` in the CRUD repository stops forwarding the two dead fields,
  and its dartdoc stops claiming to preserve "every shaping option" when a
  count's shaping options are the projection ones only. Six mutations of the two
  new rules — each disabled, the cap boundary moved, each aimed at the wrong
  kind, and the sort rule made unconditional — are all killed. The constructor
  removal is a compile-time guarantee instead, proved by `dart analyze` over the
  six projects whose generated reflection code constructs a `TomCount`; their
  `*.reflection.dart` files were regenerated, and being stale since before the
  scheduling module existed, brought current at the same time.

- **`dateOp` renders a fixed-width `YYYY-MM-DD` instead of a ragged one
  (tcinc453).** `TomStandardSqlDialect.dateOp` interpolated the components
  directly, so 2 January 2026 came out as `'2026-1-2'` while `dateTimeOp`, four
  lines above it, produced a zero-padded `'2026-01-02 …'`. The module emitted
  two date spellings and its dartdoc named the odd one out (`YYYY-M-D`) without
  saying why. MariaDB accepts the ragged form, so nothing was unstorable — the
  cost was that generated SQL could not be compared as text, and that a reader
  meeting both renderers had no way to tell whether the difference was
  deliberate. All three components are now padded, the year included, so the
  documented `YYYY-MM-DD` holds without qualification rather than only for
  dates after the year 999.

  The dartdoc also now states the *other* difference from `dateTimeOp`, which
  was the more surprising one: `dateOp` takes the components **as labelled** and
  applies no UTC conversion, so a value naming the 5th renders as the 5th in
  every zone. That was already the behaviour; it simply sat unexplained
  immediately beneath four lines explaining why an instant *is* converted.

  The padding was previously pinned as intentional (`'2026-7-5'`, in both the
  query-builder test and the object-persistence example). This reverses that
  choice deliberately, and both pins move with it. A new dialect-level test
  pins the rule itself, including the year; six mutations of the renderer —
  each component unpadded in turn, padded with spaces, reverted to raw
  interpolation, and month/day transposed — are each killed by it.

- **A cache type mismatch now carries the cast error that caused it
  (tcinc413).** `fromNameCache` wrapped `entry.value as T` in a try/catch,
  bound the caught object and then threw a `TomCacheException` built from a key
  and a message only — so the module's one failure with a genuine underlying
  cause was also the one that discarded it. A caller debugging a mismatch saw
  "Cached value of type String is not of type int" and nothing behind it. The
  other three raise sites decide by inspection and have nothing to attach; they
  are unchanged.

  The exception is now constructed with `rootException` and with the `stack`
  the catch was handed, which is the trace of the cast rather than of the catch
  block a few lines below it — a wrapper that keeps its cause should report
  where the cause arose. The `TypeError` is worth keeping because it says
  something the message cannot: it names the target type as the runtime
  resolved it, generics and nullability included, where `$T` is only ever as
  specific as the type argument the caller wrote.

  The catch was also narrowed from a bare `catch` to `on TypeError`. The
  `return` is the only statement in the `try`, so a failed cast is the only
  thing it can raise; the bare form promised to relabel anything else as a type
  mismatch, which is the one diagnosis this site is certain of.

  Attaching a cause widens an existing guarantee, so it is now pinned by a
  test. `TomBaseException.toString()` renders `rootException`, so from here on
  the cause's wording appears in every logged form of the exception — and the
  module's rule is that a mismatch names the type it found and never the value,
  because a cache holds whatever a caller put in it. That a `TypeError` reports
  types and never the value is a property of the runtime rather than of this
  code, so it is asserted rather than assumed.

- **`TomCache` now rejects a non-positive `maximumEntries` (tcinc408).**
  `putEntry`'s bounded path splits on whether the cache is empty, and the empty
  branch inserted unconditionally — it never reached the eviction check, which
  only runs on the non-empty side. A cache built with `maximumEntries: 0` (or a
  negative value) therefore accepted its first entry and held exactly one entry
  forever, silently contradicting the only capacity number the module takes.

  Honouring a zero bound literally would have been worse than the defect: the
  cache would accept every store with the same success `0` and miss on every
  read, so a caller whose computed bound evaluated to zero would get a working
  cache that never remembers anything. Both constructors now throw an
  `ArgumentError` for `maximumEntries <= 0` instead — `null` still means
  unbounded, and `1` and above are unchanged. The check runs before
  `createTimers()`, so a rejected construction leaves no periodic timer behind;
  that ordering has its own test. No call site in the workspace passed a
  computed bound, so nothing downstream changes.

- **`TomCache.stopTimers` now clears `deletionTimer` and `clearanceTimer`
  (tcinc407).** Both fields are documented — in the source dartdoc, in
  `doc/api_reference/api_summary_cache.md` and in the module's completion
  record — as the *running* timer or `null`. That held only until the first
  stop: `stopTimers` called `cancel()` and left the field pointing at the
  cancelled timer, so it held two different meanings depending on the cache's
  history and `deletionTimer != null` — the reading the documentation invites —
  answered "yes, sweeping" for the whole life of a stopped cache.

  The code was the outlier rather than the documentation: four independent
  descriptions all stated the null-when-not-running contract, so the intent was
  not in doubt. `stopTimers` now nulls both fields after cancelling, which
  leaves one correct predicate instead of two of which only one worked. The
  intervals are untouched, so the pair remains a stop/start and `createTimers`
  restarts a stopped cache — pinned by its own test. Callers that already used
  `timer?.isActive ?? false` are unaffected; a caller holding the `Timer` itself
  must capture it before the stop.

- **Cache failures are internal, and a type mismatch no longer renders the
  cached value (tcinc404).** `TomServerException` carries a `clientThrow` flag
  whose dartdoc says to set it `false` for errors that must not leak to the
  client. `TomCacheException`'s constructor forwarded `parameters`, `stack`,
  `rootException` and `autoLog` and stopped there, so the flag always took its
  `true` default: every cache failure was client-throwable and no caller could
  mark one internal. That was an omission rather than a decision — nothing in
  the module documentation mentioned the flag at all.

  It now defaults to `false`, matching `TomAuditException`,
  `TomMessagingException` and `TomOAuthException`, which each made the same call
  for the same reason. Neither cache failure is actionable by a caller. "No
  cache with name X found" names an entry in a server-side registry, and the
  caller never addressed the cache in the first place — it asked for a resource,
  and whether the server answers it from a cache is an implementation choice the
  error has no business disclosing. A type mismatch says the server stored
  something other than what it now reads back, which is the operator's problem.
  The flag remains a parameter, so a raise site with genuinely public cache
  names can pass `clientThrow: true`.

  **The type-mismatch message changed too**, and independently of the flag: it
  named the stored value (`"Cached value $value is not of type $T"`) in a message
  that is logged. A cache holds whatever a caller put in it — a session token as
  readily as a greeting — and the contents never explain why the cast failed,
  while the runtime type always does. The message now names the type, which is a
  better diagnosis *and* renders no payload.

  The four cross-isolate probes now report `clientThrow` alongside the error key,
  which confirms the flag survives the isolate boundary: a forwarded failure is
  internal exactly as a local one is.

- **A `DateTime` column is an instant, not the writing node's wall clock
  (tcinc396).** `datasources/sql_instant.dart` declared itself "a **data source**
  concern, not a feature of any one module … every table that stores an instant
  has the same problem and must have the same answer", and the hand-written
  stores (scheduling, OAuth state, audit, file storage) followed it. Reflected
  entity columns did not. A `@TomDbColumn<DateTime?, TomDbDateTime>` field names
  no conversion, so the data source decided for it — and decided *local*: bound
  through `toLocal()`, read back through a bare `DateTime.parse`.

  That round-trips on the node that wrote the row, which is why it stood. It
  does not round-trip *between* nodes: the characters in the column are the
  writer's wall clock, so each node reads the other's rows off by the difference
  in their offsets. `TomPrincipalDelegation.validFrom` / `validTo` are the case
  that made it matter — a validity window decides whether a delegate holds a
  role, and a cluster whose members disagree about when the window opens has one
  member honouring a delegation outside the bounds its owner set.

  The convention is now applied by the data source on the entity's behalf, in
  one place for all of them. Every bound `DateTime` is rendered by `sqlInstant`
  (UTC `DATETIME(6)` text, identical on every node); every `DateTime` column is
  read through `parseOptionalSqlInstant` — the boxed `TomDbDateTime.of` path,
  the two entity row-mappers, the observable-member mapper and the grouped-row
  mapper, which were five copies of the same decision and are now one. The
  inline-literal path (`TomStandardSqlDialect.dateTimeOp`) renders the same
  text; it previously emitted ISO-8601, which MariaDB rejects for a UTC value
  outright ("Incorrect datetime value", error 1292), so that path could not
  carry a UTC instant at all.

  **This changes what callers observe.** A `DateTime` read from a column now
  arrives **UTC-flagged**; it used to arrive local-flagged, naming the same
  moment. `DateTime.==` compares the flag, so a caller comparing a read value
  against a locally-constructed `DateTime` must now construct it with
  `DateTime.utc(...)`. Two related fixes ride along: the entity row-mappers
  skipped the assignment for a `NULL` `DateTime` column, leaving the field
  holding its initialiser value as if it had been read (the observable mapper
  had already been fixed; the other two now match), and `TomDbDateTime.of`
  treats an empty column string as absent rather than throwing.

  **Every framework instant column widens to `DATETIME(6)`** — the width the
  convention writes — in each entity's `createTableSql`, in the reference
  migration that reproduces it, and in the `tom_uam` / `advanced_auth_server`
  schema migrations that ship the same tables: `tom_principal_delegation`
  (`valid_from`, `valid_to`), `tom_external_identity_token` (`obtained_at`,
  `expires_at`), `tom_external_identity` (`linked_at`, `last_login_at`),
  `tom_user_two_factor_enrolment` (`enrolled_at`) and `tom_user_preference`
  (`updated_at`). A plain `DATETIME` rounds to the second, which for a validity
  window or a token expiry puts the edge up to half a second from the one that
  was set — and for the rest simply loses part of what was written. The
  corollary is now stated with the convention: a column holding an instant is
  `DATETIME(6)`.

- **The delegation query selects only live rows (tcinc395).** The store read
  *every* delegation targeting the delegate and threw the dead ones away in
  Dart. Revocation is a flag rather than a delete, so a delegate accumulates
  rows for the lifetime of the deployment and every request paid for that whole
  history — to use, typically, a handful of them.

  The read seam now takes the instant —
  `PrincipalDelegationStore.activeDelegationsForDelegate(delegateId, at)`
  (was `delegationsForDelegate(delegateId)`) — so an implementation can answer
  the question where the rows are.
  `RepositoryPrincipalDelegationStore` compiles it into the query: `revoked`
  and both window bounds are tested in SQL, each bound written to admit `NULL`
  (`valid_from IS NULL OR valid_from <= :at`) because SQL answers `NULL <= :at`
  with *unknown*, and a bare comparison would silently drop every open-ended
  delegation. The delegate index widens to `(delegate_id, revoked)` to cover the
  selective part of the new predicate; the window columns stay out of it,
  because the `OR … IS NULL` shape is not usable as an index range. The DDL
  change lands in `TomPrincipalDelegation.createTableSql`, its reference
  migration, and the `tom_uam` / `advanced_auth_server` schema migrations.

  `TomPrincipalDelegation.isActiveAt` is unchanged and remains the in-memory
  statement of the same predicate — what `InMemoryPrincipalDelegationStore`
  filters on, what the resolver still re-checks, and what the tests share.

- **Delegation resolution reads each delegator's grants once, not once per
  delegation row (tcinc394).** `TomDelegationResolver.resolveDelegatedRoles`
  looped over the active rows and, for every `absence`/`intentional` one, asked
  the direct resolver for that row's delegator — so a delegator naming four rows
  was read four times, and each read is a query against
  `tom_principal_resource_grant`.

  The multiplicity is not a corner case: `resourceKey` narrows a delegation to
  *one* resource, so lending four projects is idiomatically four rows with one
  delegator, and the cost grew with exactly the thing the model encourages.
  Resolution now memoises the delegator reads for the duration of the single
  `resolveDelegatedRoles` call, keyed on the delegator id.

  It is deliberately not a cache. Resolution is live — a revoked grant must stop
  granting access at revocation rather than at token expiry — so the memo holds
  nothing once the call returns, and two resolutions still read twice; a test
  pins that. Amortising across a whole request remains
  `TomResourceDataScope.runCached`'s job, which the resolver sits underneath.
  `share` rows and inactive rows still cost no grant read at all, since neither
  ever consults the delegator.

- **`TomAuthorizationCache.storePrincipal` returns `Future<void>` (tcinc393).**
  It was declared `Future<int>` and ended with `return 0` on every path, which
  cost a sentence in the source dartdoc, the completion doc and the API summary
  — three places documenting a value a caller could not branch on, and a caller
  that tried would have been testing a constant. Nothing in the module supports
  the obvious reading that the `int` was once a count or a status code.

  A store either happens or throws, so completion and failure are the whole
  answer and the future now carries only those. The one place the constant was
  load-bearing was inside the module's own reasoning: the cross-isolate executor
  returned the store's future partly because `0` "is not null, so
  `executeInCreator` does not mistake it for an unclaimed command". A
  `Future<void>` settles to `null` instead, and the creator's executor chain
  compares against `TomExecutor.noResult` rather than against null, so the
  command is still claimed — now asserted by a test that watches a trailing
  executor never be offered the store.

- **`TomAuthorizationCacheEntry` requires its deletion time, and neither field
  can be moved afterwards (tcinc392).** The constructor's second argument was
  optional and fell back to `DateTime.now().add(Duration(days: 1))`. An entry's
  lifetime is not its own — it is the lifetime of the token the principal was
  authorized under, which is why `storePrincipal` reads the instant off the
  token's `validUntil` claim and refuses to cache a token it cannot read one
  from. The one-day default contradicted that refusal at the only door it left
  open: a caller with no token expiry in hand got an invented one, a day long,
  for a principal whose authorization may have ended minutes later.

  The argument is now required, so the wrong answer is unreachable rather than
  merely undocumented; `deletionTime` and `authorizedPrincipal` are `final` for
  the same reason, since a settable expiry would let the entry be moved to an
  instant the token never granted — the same hole with a later entrance. The
  test that pinned the one-day arithmetic is gone, and a behavioural test in its
  place watches a short-lived token's principal go from hit to expiry with no
  interval of its own in between.

- **A read that rejects an expired entry also removes it, so the second read of
  the same dead token is a miss (tcinc391).** `getPrincipal` reported the expiry
  and left the dead row in the map, so every request bearing that token repeated
  the lookup, the throw and the stack until the hourly sweep happened to come
  round. The rejecting frame holds the map and the key and has just established
  the entry is dead, so it is the cheapest place there is to remove it.

  What a caller sees changes only on the second read, and only for the better: a
  caller that wants to know a session died still learns it, from the first
  exception, while a caller retrying with the dead token is told there is
  nothing there — which is by then the truth. Anything that reads twice and
  expected `expired_principal` both times gets `expired_principal` and then
  `null`.

  It also decides the map's high-water mark, which is the half that does not
  show up in one request's behaviour: one entry per live session with the
  removal, one per successful login per sweep interval without it. Read and
  sweep now cover the map between them — the read sheds the dead tokens somebody
  presents, the sweep sheds the ones nobody comes back for.

- **`TomAuthorizationCache` has a sweep lifecycle and a shutdown contract, and
  its constructor is private (tcinc389).** New public surface: `instance`,
  `startEviction({interval})`, `stopEviction()`, `isEvicting`,
  `evictionInterval`, and `dispose()` by way of `TomDisposable`. Gone: the
  public unnamed constructor.

  The constructor started a one-hour periodic timer, kept no reference to it,
  and the class offered no way to stop it. Two things followed. The timer held
  the isolate open for the life of the process, so the module's own example had
  to end in `exit(0)` and said so in a comment — a workaround for a lifecycle
  the type did not offer, and one a server wanting an orderly shutdown has no
  equivalent of. And the constructor was public while the only instance the
  static API touches is the singleton, so any caller writing
  `TomAuthorizationCache()` got a second uncancellable timer sweeping a map
  nothing could ever populate.

  `tomShutdownCleanup.addDisposable(TomAuthorizationCache.instance)` now stops
  the sweep and drops the cached principals together — the same
  explicit-registration seam the rest of the module already uses, since
  `TomResourceDataScope` has `install`/`uninstall`/`isInstalled`, rather than a
  new one. `dispose()` is synchronous, as `TomDisposable` requires: the cleanup
  discards a returned future rather than awaiting it, and cancelling a timer
  needs nothing more.

  The sweep starts with the first principal `storePrincipal` caches rather than
  with the first touch of the singleton. It exists to bound the map, so it runs
  from the moment there is something in it to bound, and a process that only
  ever reads the cache never starts a timer at all. `startEviction` replaces a
  running sweep instead of orphaning it, which is what makes "a sweep is running
  at this interval" true whenever it returns; the automatic start is a separate
  path so it cannot silently reset an interval a server or a test chose
  deliberately.

  The timer is created in `Zone.root` whichever path starts it. The caller that
  happens to store the first principal is normally a single request — the
  endpoint pipeline runs each one in its own zone to carry the principal — and
  process-lifetime work parented there answers to that request's error handling
  and teardown long after the request is gone, with the first arrival deciding
  the zone. Root rather than a zone the server installs at boot, because the
  sweep wants nothing a zone can give it: it walks a plain map, needs no
  principal and no transaction, and a failure in it belongs to the process.

- **`storePrincipal` refuses a token whose `validUntil` claim is unreadable
  instead of caching under an invented expiry (db8e5f22).** A call that used to
  succeed now throws `TomAuthorizationCacheException`, and nothing is cached;
  the caller keeps resolving the principal per request.

  The expiry came from a bare `DateTime.parse(payload["validUntil"])`. The
  subscript is a dynamic map read, so a token omitting the claim passed `null`
  into a `String` parameter and failed with a `TypeError`, and a non-ISO value
  failed with a `FormatException`. Either way the failure surfaced from inside a
  cache write naming neither the claim nor the token that caused it — and the
  token comes from a client, so this is a boundary rather than internal data.

  Two keys, because the conditions call for different reading:
  `tomclient.authorization_cache.missing_valid_until` when the claim is absent
  or not a string, and `tomclient.authorization_cache.invalid_valid_until` when
  it is a string that is not an ISO 8601 instant. Each carries the claim name,
  the value seen and a token excerpt in `parameters`, so the diagnosis does not
  depend on the stack.

  There is deliberately no fallback lifetime. The entry's lifetime *is* the
  token's — that is the whole reason the claim is read — so a default invented
  here would keep a principal cached after the token authorizing it had expired,
  and every later request bearing that token would be served from the cache
  instead of being re-authorized. A fallback trades a loud failure for a quiet
  authorization hole. The `TomAuthorizationCacheEntry` constructor's one-day
  default was the other door into that same hole, and is required now for the
  same reason (tcinc392).

  Off the main isolate the refusal only means anything because
  `TomAuthorizationCacheExecutor` returns the store's future rather than
  discarding it, as the retrieve branch always did: a worker storing a malformed
  token used to read success for a store the creator had refused.

- **`TomAuditPolicy.disabled` is removed (tcinc352).** The constant was public
  and documented, and nothing built a policy from it: the reflector's
  `policyFor` resolves `@TomAudited(enabled: false)` through
  `TomAuditPolicy.from`, so the one place a reader would expect the constant to
  appear used something else. Its only Dart reference was a redundant entry in
  a test's list of policies, two lines above the `from(TomAudited(enabled:
  false))` that produces the identical policy.

  It is removed rather than wired in, because the module's position is that
  opting out should be explicit in source so its absence is auditable too. A
  named off-switch invites the opt-out that leaves no annotation behind, and
  `TomAuditBypass` already covers the one legitimate case — the trail's own
  persistence path. Nothing accepts a caller-supplied `TomAuditPolicy`, so no
  reachable behaviour changes; what goes is the affordance.

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

### Bug Fixes

- **A forwarded cache read answers as a local one does (tcinc400).** Carrying a
  creator-side failure across the isolate hop as a failure — the kernel change
  that made `executeInCreator` complete with an error rather than hand the
  exception back as a value — fixed the *reported* half of this: a forwarded
  store into a cache that exists nowhere raises instead of returning the `0`
  that means success, and a forwarded read raises instead of reporting an empty
  cache. Round-trip tests through a real worker now cover the third helper too,
  `removeFromNameCache`, which had the same contract and no evidence behind it.

  Two of a read's outcomes are not failures, though, and no exception marker in
  the transport reaches them. A value that crossed intact and then failed to
  convert to `T` was answered as `null` — telling a caller holding the wrong
  type that the cache is empty, where the local path throws
  `error.cache_retrieve.types_dont_match`. And a miss arrives as
  `TomExecutor.noResult`, because `executeInCreator` never resolves to `null`;
  a read whose `T` admits any object (`Object`, or the `dynamic` of an
  uninstantiated call) therefore accepted that sentinel *as the cached value*
  and returned an object no caller has a type for. A read for `String` could not
  see either defect, which is why neither had surfaced.

  `fromNameCache` now settles both at the call site: the sentinel is translated
  back into the `null` that means a miss, and a value that is not a `T` throws
  the same `TomCacheException` the local path throws.

- **A cache store forwarded from a worker isolate keeps its expiry
  (tcinc399).** `TomCacheStoreMessage` carries a `deletionTime` across the
  isolate boundary, and `TomCache.toNameCache` populated it when forwarding —
  but the message's `execute` called the three-argument form of `toNameCache`
  and dropped it on arrival. The field was therefore dead: it travelled and was
  discarded.

  Nothing failed when it was. The receiving side treats a missing
  `deletionTime` as "no explicit expiry" and substitutes the target cache's
  `deleteEntriesAfterSeconds`, so the store reported success and the entry
  simply outlived the lifetime the worker asked for — permanently, when that
  default was unset. A worker requesting a 30-second lifetime got the cache
  default instead, and the substitution was only observable at some later read
  that returned a value it should not have.

  `execute` now forwards the fourth argument. Two tests pin it: a store through
  the message with an already-past instant must read back `null`, and a store
  with an explicit future instant must land with *that* instant rather than the
  cache default — the first proves an expiry is applied, the second proves it is
  the caller's. The other cross-isolate commands in the package were audited for
  the same shape and consume every field they carry.

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

- **A forwarded store is now tested with the one argument whose loss is silent
  (tcinc406).** The cache module's cross-isolate forwarding was covered from two
  directions, neither of which crossed an isolate boundary with a full argument
  list: one group asserted only *which branch* was taken (the helpers throw a
  `TomWorkerException` because the test process has no back channel), and the
  other called the command objects' `execute()` directly in the main isolate,
  which is the local path with an extra object around it. A real round-trip
  group already existed and covered a store, a read and a removal — but its
  store passes no `deletionTime`, so the four-argument forwarding path was
  exercised only with `null`.

  That is the one argument whose loss cannot surface as a failure: the receiving
  side fills the expiry in from the target cache's `deleteEntriesAfterSeconds`
  and reports the same success, so the write looks fine and the entry outlives
  its intended lifetime until some later read. Two tests now store through a
  real spawned `TomWorker` with an explicit instant — one asserting the entry
  landed with the instant the worker asked for rather than the cache's default,
  one asserting an already-expired store reads back as a miss through the public
  API. Both were checked against the defect they guard: reverting
  `TomCacheStoreMessage.execute` to drop its `deletionTime` turns them red,
  showing the substituted default in place of the requested expiry.

- **`doc/cache.md` records the module's limits, and the limits are pinned
  (tcinc405).** The cache module's five known limits lived only in an internal
  completion document; the package-facing prose carried none of them and had no
  section in which to, though seven sibling module documents already use a
  `## Not Yet Implemented` section for exactly this. The gap was not abstract —
  the LRU bound was presented without saying that an *unbounded* cache has no
  bound at all, and the three mutators were shown without saying their
  `Future<int>` result is always `0`. Both are now qualified where the claim is
  made, and the section states all five: the raw `getEntry` accessor skipping
  expiry, the unbounded default, the constant mutator result, unbatched
  cross-isolate forwarding, and `setCurrent` orphaning the timers of the caches
  it discards.

  Three of the five are now pinned by tests, because a prose list of limits
  cannot go red when one of its items is closed — which is not a hypothetical:
  re-verifying the list against the source found a **sixth** item that had been
  fixed and was still being read as live. Closing one of the pinned limits now
  fails a test that names the section, rather than leaving the document quietly
  wrong.

- **The cache example's expectations actually run, and the suite runs the
  example (tcinc403).** The completion document said the example "runs with
  `dart run example/cache/cache_example.dart` and asserts each result". It did
  not. `dart run` leaves assertions **disabled** — that is what its
  `--enable-asserts` flag is for — so every `assert` in the file was compiled
  out under precisely the command being documented. Proven rather than argued:
  a copy of the example with a deliberately false assertion, run under that
  exact command, **exited 0**. The example was a printer that produced a
  plausible transcript while every expectation in it went unchecked, which is
  worse than having no checks, because the transcript is what a reader trusts.

  The twelve asserts are now calls to a local `check(bool, String)` that throws
  a named `StateError`, so the expectations hold however the file is invoked and
  a violated one exits non-zero. Two tests were added, and the pair is the
  point: one runs the example under the documented command and requires exit 0
  plus all nine numbered steps in its output; the other requires the source to
  contain no `assert(`. The second is not redundant — under the assert-based
  version the *first* test passes, because an example that checks nothing exits
  0 too. Only the source check distinguishes a green run from a silent one.

  The completion document and the example's header no longer describe the test
  as covering "the same behaviour"; the test is what verifies the example, and
  both now say so.

  The other twenty example files in this package still assert (~300 statements,
  all inert under `dart run`) and are tracked separately — enabling their checks
  is expected to surface genuinely failing examples, so it is not a rename.

- **The cache example demonstrates all nine documented behaviours, and two of
  them are now tested (tcinc402).** The module's completion document introduced
  its nine "Using it" snippets with "the snippets below are taken from
  `example/cache/cache_example.dart` … and asserts each result". The example had
  six steps. Three snippets were taken from nowhere: a `TomCacheEntry` stored
  verbatim to carry its own lifetime, `stopTimers`, and replacing the current
  `TomCacheManager`. A reader who followed the sentence to the example — which
  is what the sentence is for — found two thirds of what it promised, and the
  three unbacked snippets were exactly the unverified prose that running the
  example is supposed to settle.

  All three are now steps 7–9, and the nine sections correspond one-for-one and
  in order with the nine steps, so a snippet that stops matching is visibly a
  snippet whose step moved. Two of the three were also *asserted nowhere*:

  - **A `TomCacheEntry` passed as the value keeps its own `deletionTime`**
    rather than taking the cache's default. The existing test dated every entry
    to 2999, which pins the routing (through `putEntry`, into the MRU chain) but
    not whose deletion time survives — a far-future entry reads back under
    either rule. The new test stores an entry whose instant has already passed
    into a cache whose 300-second default would have kept it readable; the miss
    is the only observation that separates the two.
  - **`setCurrent` discards the caches the replaced manager held.** The registry
    is an instance field, so the swap drops every registration with it — which
    is the whole reason the swap is useful between tests, and was the half the
    existing test did not cover.

  The example also records what `setCurrent` does *not* discard: a dropped
  cache's timers stay installed and keep firing, so they must be stopped while
  a handle to them still exists.

- **The cache example and test fixture state the expiry rule the module
  actually has (tcinc401).** Two comments still described the rule as it stood
  *before* it was fixed: the example's first step claimed "a retrievable entry
  must carry a deletion time, so `deleteEntriesAfterSeconds` supplies one
  automatically on store", and `test/cache_test.dart`'s shared `_cache` helper
  repeated it as "a readable entry must carry a future deletion time". The
  module has not worked that way since the expiry gate was corrected — an entry
  expires only once it carries a deletion time that *has passed*, and an entry
  with no deletion time at all is kept forever. `doc/cache.md` had already been
  brought in line, which is what left these two contradicting it.

  A stale comment on a *fixture* is the more expensive of the two: it is read by
  everyone adding a test, and it justifies the fixture's 300-second default with
  a reason that is not the real one. The default stays — but for what it in fact
  buys, which the comment now says: because the cache would otherwise supply its
  own instant, an entry that expires on the *caller's* proves the caller's was
  carried through rather than silently replaced, and that is the whole substance
  of the two `TomCacheStoreMessage` expiry tests.

  The example gains the step that would have caught this: a cache with no
  default lifetime, whose stored entry reads back. The "cache forever" half of
  the rule was asserted in the suite and demonstrated nowhere, and a rule stated
  only in prose is exactly the kind that drifts out of date unnoticed.

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
