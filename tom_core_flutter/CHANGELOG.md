## 1.2.1

### Fixed

- **preferences: `TomStoredDevicePreferences` no longer modifies the list its
  store handed back (tcinc667).** `set` assigned into or appended to the list
  returned by `TomDevicePreferenceStore.read()`, and `remove` called `removeAt`
  on it. The three shipped backends survived that only incidentally — the memory
  one copies defensively, the file and web ones decode a fresh list per call —
  and nothing required either property, so the module worked by luck of its own
  implementations rather than by its contract. A conforming backend that returns
  its own list, or an unmodifiable view of one (the natural shape for a cache
  over `shared_preferences` or a keychain), failed instead: every `set` threw a
  raw `UnsupportedError` that no caller could map to a preference failure, and
  `remove` answered `false` for a key that was present. Both now copy before
  mutating — `remove` only on the path that actually writes, so a miss still
  allocates nothing. The asymmetry that made this visible is gone too: `all()`
  already returned `List.unmodifiable(...)`, so the module demanded of its
  backends exactly what it refused to promise its callers.

- **preferences: `TomPlatformDevicePreferenceStore`'s constructor is no longer
  `const` on any variant (tcinc665).** The same defect as `tcopen198` below, in
  the module with three variants instead of two: the `dart:io` and web
  implementations declared `const` constructors, and the neutral one cannot,
  because throwing `device_preferences.unsupported_platform` from its body is
  its entire purpose. So `const TomPlatformDevicePreferenceStore(location)`
  compiled on device and in the browser and broke the build on the one target
  whose intended behaviour was a *run-time* failure — converting a locatable
  startup diagnostic into a compile error at an unrelated call site, on the
  platform where the developer has the least context. That also contradicted the
  module's own promise that the store "takes one `location` on every platform …
  so the construction above is written once and never branches". The `const` is
  dropped from both variants that had it, each keeping a dartdoc paragraph
  recording why so it is not "restored" later, and
  `doc/api_reference/api_summary_preferences.md` now states the signature that
  is true everywhere. No call site anywhere in the package, its examples or its
  documentation wrote `const`, so nothing downstream changes.

- **configuration: `TomFileClientConfigurationStore`'s constructor is no longer
  `const` (tcopen198).** The store is chosen by conditional export, and the two
  variants disagreed: the `dart:io` variant declared a `const` constructor while
  the neutral one cannot — its whole purpose is to throw from its body. So
  `const TomFileClientConfigurationStore(path)` was legal Dart on desktop and
  mobile and a compile error on web, and the compiler only said so once someone
  built for the platform they were not working on. A conditional export is worth
  using only if one name means one signature on every target, so the `const` is
  dropped from the io variant; the constructor now carries a dartdoc paragraph
  recording why, so it is not "restored" later. The base class keeps
  `const TomClientConfigurationStore()` — it permits `const` implementations, it
  does not require them.

- **configuration: `save()` carries forward from the live store, not from a
  stale snapshot (tcinc649).** `TomBaseClientConfiguration.save()` seeded its
  carry-forward — the keys the running build does not declare, which must
  survive a write — from the in-memory `_persisted` snapshot taken at `load()`.
  That snapshot describes one store at one moment, and the two ways it diverges
  from reality both broke the promise it was meant to keep. A holder that loaded
  from store A and was then pointed at store B deposited **A's** foreign keys
  into B; and a key written by anyone else since `load()` was absent from the
  snapshot, so it was deleted rather than carried forward — precisely the loss
  the mechanism exists to prevent. `save()` now re-reads the store it is about
  to write. The `store` setter additionally discards the snapshot on a real
  change (re-assigning the same store is a no-op), so a setting declared after a
  swap no longer picks up the old store's override; the settings themselves keep
  their values, because a swap is not a load. This is the fix recommended under
  `tcopen200`; the residual, now documented under Limitations, is that
  read-then-write is not atomic, so two genuinely simultaneous saves can still
  lose one another's last write undetected — the exposure is one store
  round-trip rather than the whole session.

### Documentation

- **resources: the API summary documents what the module throws (tcinc670).**
  The summary was symbol-accurate and silent on failure, which is an expensive
  omission in this module specifically: both constructors resolve in their
  body, so the two throw sites are not error paths reached after a successful
  construction — they are the two ways construction fails, at whatever point in
  start-up the property is built. The constructor table said "throws if absent"
  and nothing about the type-mismatch path, so a reader got neither the
  exception type, nor the message shape, nor the fact that a wrong-typed
  *present* value fails as hard as a missing one. That also made `resources`
  the exception to the package's own pattern: of the eight API summaries, the
  three whose modules throw all document it. A new `## Exceptions` section now
  gives both failures with the message each produces verbatim, states that they
  are bare `Exception`s carrying no stable code and are therefore
  distinguishable only by `toString()`, and records that "absent" includes a
  key whose configured value is `null`. The constructor table now says
  resolution happens during construction, and that `withDefault` still throws
  on a wrong-typed present value — the default covers an absent key, not an
  unusable one.

- **resources: the recommendation to prefer a typed subclass now states the one
  case where it does not apply (tcinc669).** The class dartdoc, the module
  readme's key-types table, `doc/resources.md`'s overview table and the API
  summary's Overview each told the reader to use the typed subclasses rather
  than the generic, and none of the four admitted an exception. One exists, and
  it is not marginal: `TomStringProperty`, `TomIntProperty`,
  `TomDoubleProperty` and `TomBoolProperty` close over non-nullable `String`,
  `int`, `double` and `bool`, so an optional value — the
  `withDefault(key, null)` shape — cannot be written with any of them. The only
  form that expresses it is `TomProperty<String?>.withDefault('app.region',
  null)`, the very construction all four documents forbade, and the one the
  module's own suite has exercised since the explicit-`null` fix. A reader who
  needed an optional property was therefore told their sole correct option was
  against the module's contract, and either reached for it uneasily or wrote a
  sentinel default and a test for it. All four now scope the recommendation to
  the four non-nullable value types and name the nullable-`T` exception, and
  the three consumer-facing documents print the construction beside it.

- **resources: the documented dependency is the provider the module actually
  reads from (tcinc668).** `doc/resources.md` listed
  `TomConfigResourceProvider` / `TomTextResourceProvider` as "the resource
  providers the property reads from". Only the first is true: both of
  `TomProperty`'s hooks resolve through `TomConfigResourceProvider
  .getAppConfig()`, and the text provider is not referenced anywhere in the
  module. The line was left behind when the module's general-purpose `t()`
  translation lookup was removed, and it was not harmless — the two are
  separate provider families with separate installation calls
  (`setAppConfigProvider` vs `setAppResourceProvider`) over separate backing
  maps, so a reader who followed it installed the text provider and found that
  no property resolved at all. The section now names the config provider alone
  and says which call populates it, and states explicitly that installing the
  text family instead leaves every property unresolved.

- **preferences: the store contract says who owns each list (tcinc667).**
  `TomDevicePreferenceStore` is the whole backend contract — two methods — and
  its dartdoc said what `read()` returns without saying whether the caller may
  modify it, or what `write()` may do with what it is given. Both halves are now
  stated, on the methods themselves and in `doc/preferences.md`, which gains a
  **Writing a Backend** section for the reader the contract is actually
  addressed to: the list `read()` returns belongs to the store, so an
  implementation may hand out its own list, an unmodifiable view, or the same
  instance every time and needs no defensive copy per read; the list given to
  `write()` belongs to the caller, so an implementation must neither modify it
  nor retain it without copying — `clear()` passes `const []`, which no store
  could keep. The rule is repeated in the API summary's method table and as a
  clause in the module readme's type table, and a test now pins it in all four
  artefacts, so the sentences stay rewritable but the fact cannot quietly
  disappear from any of them.

- **preferences: the scope rule reaches the documents a reader actually starts
  from (tcinc666).** A device store has one user because its *location* has one
  user — not because anything here tracks one. That rule, the per-account
  `location` pattern and the shared-install failure mode were stated in the
  library dartdoc and the module `readme.md`, and in neither of the two
  consumer documents. Following the package documentation rather than the
  source tree therefore led to a multi-account application built on a single
  store, whose second sign-in reads the first user's last-used account,
  biometric flag and layout — with no warning, no log line and no assertion,
  because a store is never told a user changed. `doc/preferences.md` now
  carries a *Scope* section stating all three, and
  `api_summary_preferences.md` names the consequence on the `location` entry
  itself. The forward reference is placed on the `getFor` paragraph
  specifically: "a device store has one user by definition" is where the
  misreading forms, because it does not say what makes the definition true.
  The section also maps the choice onto the configuration scopes — fixed
  location is CE-CC `(client app, machine)`, per-account is CE-DS
  `(user, device)`, same class at a different address.

- **Four API summaries list their last section in their tables of contents
  (tcinc666).** `api_summary_little_things.md`, `api_summary_observing.md`,
  `api_summary_resources.md` and `api_summary_security.md` each ended with a
  `## Global Functions and Constants` section that their contents block did not
  mention, so the one place a reader looks to find out whether a module has
  top-level API said nothing either way. Found by the new structural guard
  rather than by reading, which is the point of having it.

- **preferences / configuration: the exception constructor blocks show
  `autoLog`'s inherited default, and say where their types come from
  (tcinc664).** Both preferences blocks documented `bool autoLog` with the
  `= false` default dropped, and `api_summary_configuration.md` documented
  `bool? autoLog`, which no call site can pass — `autoLog` is non-nullable, so
  omitting it and passing `null` are not the same thing and the second does not
  compile. All three now show `bool autoLog = false`.

  The `stack` parameter in the same blocks was **not** wrong and is unchanged.
  `StackTrace? stack` has now been reported as a mistype three times (tcinc617
  for the server's summary, tcinc654 for `little_things`, tcinc664 here),
  always on the same reasoning: the field on `TomBaseException` is `Object?`,
  so the parameter "should" be too. It should not. These classes declare no
  types of their own — every parameter arrives by `super.x`, and a
  super-parameter resolves against the *immediate superclass constructor*.
  `TomException`'s constructor declares `StackTrace? stack` outright and
  forwards `stack ?? StackTrace.current`, so `StackTrace?` is what a caller may
  pass; documenting the parameter from the field declaration is the
  plausible-looking wrong answer, which is why it keeps being filed. Both
  summaries now carry the paragraph that says so, joining the one
  `api_summary_little_things.md` already had.

- **observing: `ValueListenableObserver`'s contract deviation is documented at
  both ends, not one (tcinc662).** The adaptor departs from the
  `ValueListenable` contract in two independent ways — `addListener` replaces
  the single slot instead of appending, and `removeListener` ignores its
  argument and clears the slot regardless. Every consumer-facing artefact stated
  the first and none stated the second: `doc/observing.md`, the API summary's
  callout and its `removeListener` row ("Clears the registered listener" —
  wording a reader takes to mean *that* listener), the class dartdoc and the
  module readme. The asymmetry left the module's own example unexplainable, in
  that it clears the adaptor by passing a closure it never registered, and a
  half-stated deviation is worse than an unstated one because the half that is
  written implies the other half behaves normally. All five now state both
  halves and say why — there is one slot rather than a list, so there is nothing
  to match the argument against.

- **observing: the weak-reference contract is stated the right way round
  (tcinc661).** `doc/observing.md` closed its lifecycle section by claiming that
  because the `State` deregisters in `dispose`, "a long-lived observable that
  outlives the widget is therefore not retained" — an inversion in both
  directions it could be read. `TomObservable` holds its observers by
  `WeakReference` and prunes dead ones on notification, so the registration
  never kept the `State` alive and removing it is not what releases it; and the
  strong reference runs the other way, through `TomObservingWidget.subState`, so
  the widget keeps the *observable* alive and `dispose` does nothing about that
  either. The claim had been copied into the widget's dartdoc and
  `doc/api_reference/api_summary_observing.md`, and its inverse was even written
  into the comment on the test that pins the correct half, so all four are
  corrected together: the section now names which side holds which, links to the
  kernel's own memory-management rule, and says what deregistration actually
  buys — a known moment for notifications to stop, rather than leak prevention.
  The corollary is the part worth carrying away: an observer that is still
  reachable but no longer wanted keeps firing for as long as something else
  holds it, so collection is not a substitute for removing it.

- **configuration: validation is described instead of deflected (tcinc651).**
  Both the `TomBaseClientConfiguration` dartdoc and `doc/configuration.md` said
  per-field validation was "not the holder's job" because "constraints ride on
  the field declaration (the `Cs*` annotations)". `CsClientConfig` — the marker
  for this exact scope — carries `key`, `envAlias`, `overridableBy` and `note`,
  and no constraint of any kind; no `Cs*` annotation anywhere carries a range, a
  pattern or an enum. `tom_code_specs` is also not a dependency of this package,
  so nothing here could reference them even if they did, and neither artefact
  said where `Cs*` lived. The sentence sent the reader somewhere that does not
  have what it promised. Both now state what is true: the **type** is checked
  (`client_configuration.value.type_mismatch`) and the **value** never is, a
  `TomSetting<int>` stores and serves `-1` as a refresh interval, there is no
  hook to add a check because `TomSetting`'s constructor is private, and range,
  format and enum constraints are the **caller's**. `doc/configuration.md` also
  gained the matching **Limitations** bullet — the section is the document's own
  inventory of gaps, and a reader who scans it was previously left to conclude
  that validation was covered. No API change.

- **configuration API summary completed and guarded (tcinc650).** The mirror at
  `doc/api_reference/api_summary_configuration.md` was accurate in everything it
  listed but silently omitted six public members the sources declare:
  `TomSetting.toString()`, `TomBaseClientConfiguration.toString()`,
  `TomClientConfigurationStore`'s `const` constructor (with its "allows `const`
  implementations" note), `TomFileClientConfigurationStore.path`, that store's
  non-`const` constructor rationale, and — found while verifying rather than
  trusting the mirror — `TomClientConfigurationException`'s constructor, which
  the sibling summaries document under `#### Constructors`. All six are now
  listed. The completion document's class sketch was corrected to match the
  source's non-`const` constructor, so the two mirrors agree.

- **configuration: the completion document's provenance claim is true again
  (tcinc652).** Its "Using it" part opened by saying everything below came from
  `example/configuration/configuration_example.dart` and
  `test/configuration_test.dart`; three of its twelve subsections were in
  neither. Rather than narrowing the sentence, two were made real — the
  `TomObservingWidget` snippet and the `unsupported_platform` failure are now
  executed by the suite (see below) — and the third, the
  `getApplicationSupportDirectory()` path expression, is marked in place as the
  document's single unexecuted line, because quoting it truthfully would mean
  taking a `path_provider` dependency the package does not otherwise need and a
  doc snippet is not a reason to acquire one. The provenance sentence now also
  records that the suite runs the example, so these are executed snippets rather
  than transcribed ones. No API change.

- **little_things: the API summary types `autoLog` correctly, and the hierarchy
  goes as deep as the classes do (tcinc654).** Both constructor blocks in
  `doc/api_reference/api_summary_little_things.md` declared `bool? autoLog`,
  which no call site can satisfy — the kernel's `TomException` declares
  `this.autoLog = false`, so passing `null` is a compile error and the default
  is inherited through the super-parameter chain. Both now read
  `bool autoLog = false`. The `stack` parameter, filed alongside it as an
  identical error, turned out to be **right as it stood**: a `super.x`
  parameter takes its type from the *immediate* superclass constructor, and
  although `TomBaseException` declares the field `Object?`, `TomException`'s
  constructor already narrows it to `StackTrace?` — so `StackTrace?` is what a
  client call site may pass, and changing it to `Object?` would have introduced
  the error the report set out to remove. The summary now states that rule
  where the two types meet, rather than leaving the next reader to re-derive
  it. The class hierarchy, which stopped at `TomException (kernel)`, names
  `TomBaseException (tom_basics)` above it — most of the inherited payload is
  declared there — and the Overview records the three kernel arguments
  (`requestUuid`, `uuid`, `serverCallError`) the client constructors do not
  surface. The completion document's payload table types `stack` as `Object?`
  and stays that way: it tabulates *fields*, and the field really is `Object?`;
  it now says so explicitly so the two artefacts are not read as contradicting
  each other again. No API change.

- **little_things: the prose document's one outbound link goes where it says
  (tcinc656).** `doc/little_things.md` rendered the base type as
  `[TomException](../../tom_core_kernel/doc/security/security.md)`. The path
  resolved, so nothing flagged it — but the target contains the string
  `TomException` zero times, and the link sits on the sentence enumerating the
  payload the client types inherit (`key`, `defaultUserMessage`, `parameters`,
  `stack`, `rootException`, `autoLog`), so a reader who followed it to learn
  what those mean arrived in the authorization documentation. It now points at
  `../../tom_core_kernel/doc/little_things/little_things.md`, which has a
  `### TomException` section and covers every one of the six terms. A sweep of
  all 48 repository-relative links in the package found this to be the only
  wrong target and, in `_copilot_guidelines/index.md`, two dead ones — the
  sibling-package links `../tom_core_kernel/` and `../tom_core_server/` were
  one level short of the sibling directory and are now `../../`.

### Tests / Examples

- **the documented failures are held to the ones the module throws
  (tcinc670).** Two guards in `resources_test.dart`. The first extracts the
  message literal of every `throw Exception(...)` in the source and requires
  the API summary to carry the fixed fragments *around* each interpolation —
  so the summary stays free to write the holes however reads best (`<key>`,
  `<T>`) while the words a reader would grep a log for stay tied to the
  source. The second compares the number of throw sites with the number of
  rows in the `## Exceptions` table, which is what catches a third failure
  being added to `_getValue` and left undocumented. Rewording a throw,
  deleting a table row and adding a third throw site each fail them; a
  vacuity pin on the fragment count fires if the throw sites ever stop being
  recognised, verified by making them unrecognisable.

  Documenting the failures also required asserting two behaviours that had
  none. `withDefault` does **not** rescue a wrong-typed *present* value — the
  cast branch runs before the default is consulted — which is the asymmetry a
  reader is most likely to get wrong, and it was untested. And a key whose
  configured value is `null` counts as absent, because
  `TomConfigResourceProvider.exists` is "resolves to a non-null object"; in a
  YAML config `app.region:` with no value does not satisfy an obligatory
  property. The test helper's parameter widened to `Map<String, Object?>` so
  the null case is expressible at all. 272 → 276.

- **a recommendation stated in four places cannot lose its exception in one of
  them (tcinc669).** The subclass advice had drifted out of step with the code
  in every artefact at once, which is what a rule repeated four times does when
  nothing checks it. A guard in `resources_test.dart` now holds all four — the
  source, the module readme, `doc/resources.md` and the API summary — to both
  halves: each must still recommend the subclasses, and each must name the
  nullable-`T` exception. A third test requires the three consumer-facing
  documents to *show* the construction, then runs it against the key those
  documents print, so the link is the snippet executing rather than a text
  match between documents. That third test was rewritten during verification:
  as first written it also searched this suite's own source for the
  construction, which the guard's own string literal satisfied — an assertion
  that could never fail. Deleting the behaviour group exposed it, and the
  executable form replaced it. One boundary is deliberate and was verified by
  breaking it: only the three consumer documents must print the construction,
  not the source, so the dartdoc example stays free to change. Removing the
  qualification, removing the recommendation, removing the construction and
  breaking the `_hasDefault` gate each fail exactly the intended test.
  269 → 272.

- **a module document cannot name a dependency the module has no relationship
  with (tcinc668).** A `## Dependencies` section is the one part of a module
  document that describes the *code* rather than the behaviour, so it goes
  stale in a way prose does not: delete the code that used a type and the line
  naming it survives, still telling the reader to install it. A guard in
  `documentation_links_test.dart` now walks all seven module documents and
  requires every framework symbol named in the dependency *bullets* to appear
  somewhere in that module.
  Two boundaries are deliberate, and each was verified by breaking it. The
  check reads the bullet list only, because the prose that follows describes
  what an *application* must do and legitimately names types the module never
  touches — widening it to the whole section reports `doc/preferences.md`'s
  correct instruction to register a platform with `TomPlatformUtils` as a
  defect. And it matches against the module's full text, dartdoc included,
  rather than code alone, because a dependency is legitimately indirect:
  `configuration` names `TomException` as the base its exceptions inherit,
  `preferences` names `TomBearerAuthentication` for a token its channel
  attaches and `TomRuntime` for the platform its bean locator selects on, and
  none appears in an expression. The weaker claim — *referred to somewhere* —
  is the one with no false positives, and it still catches the failure it
  exists for, since a line left behind by deleted code is mentioned nowhere at
  all. 268 → 269.

- **the shared store suite runs against a backend that keeps its promises and
  nothing more, and cross-document anchors are checked (tcinc667).**
  `preferences_test.dart` gained a third instantiation of the shared suite,
  behind a store whose `read()` returns its own unmodifiable list — everything
  the contract permits and nothing it does not. Running the existing 13 contract
  tests against it, rather than adding two bespoke assertions, is what did the
  work: with the `remove` defect reintroduced the two original backends still
  reported *all tests passed*, so the suite had been blind to it by
  construction. Two further guards pin the ownership rule in the four artefacts
  that state it. Separately, `documentation_links_test.dart` now checks that a
  link naming a heading in *another* document finds it — the existing link guard
  drops the fragment and checks only the path, which is the half that rarely
  breaks, so a renamed heading left the link silently landing at the top of the
  right file. Its first run exposed a bug in the anchor helper written under
  `tcinc666`: `github-slugger` replaces each space individually, not each run of
  whitespace, so stripping an em dash out of `A — B` leaves both surrounding
  spaces and therefore two hyphens. No link had ever been wrong; the helper was.
  It could not have been caught by the table-of-contents guard, which applies
  the same function to both sides of its comparison. 252 → 268.

- **every document's anchors and table of contents are checked, and the
  preferences scope rule is pinned in all three places it must appear
  (tcinc666).** `documentation_links_test.dart` gained a `document structure`
  group with two package-wide guards: every same-document anchor link resolves
  to a heading that exists, and every module document's contents block lists
  every one of its `##` sections, in order. Both had to derive GitHub's anchors,
  which means decoding HTML entities *before* stripping punctuation — skipping
  that step reports five live links in this package as dead, so the helper does
  it and says why. The contents guard found four genuine omissions on its first
  run (above). Three further guards in `preferences_test.dart` check that the
  module readme and both consumer documents each show the per-account
  `location` pattern and each state what the account segment must be, and that
  `doc/preferences.md` carries the rule as a section of its own. They assert the
  two load-bearing *facts* rather than any sentence, so the prose stays free to
  be rewritten. 247 → 252.

- **the conditional-export variants of a store are checked as a set, and the
  checks read declarations rather than the prose about them (tcinc665).** The
  guard that `configuration` gained under `tcopen198` — its two file-store
  variants must agree about `const` and declare the same public members — moved
  to `test/support/conditional_export_variants.dart` and now serves
  `preferences`' three platform-store variants as well. Two bugs surfaced in
  the move, both the same mistake at different layers: the checks matched raw
  text, so the dartdoc explaining *why* a constructor is not `const`, and the
  API summary's paragraph explaining the same thing, each read as a `const`
  declaration — a guard that fails on correct code precisely because the code
  was documented. Sources are now read with comments stripped and summaries only
  within their ` ```dart ` fences. The `configuration` copy had been carrying
  this latently and passed only because its explaining sentence happened to wrap
  between `const` and the class name; rewrapping that sentence to read better
  turned it red, which is how it was found. Because "all variants agree about
  `const`" could otherwise be satisfied by *deleting* the neutral variant's
  throw, `preferences` also gained the two tests pinning that it still fails
  loudly and still names the location — its neutral variant previously had no
  test at all, on the one code path whose whole purpose is to be reached.
  Five new tests in `preferences_test.dart`; 242 → 247.

- **the API-summary constructor mirror is one shared check over three modules
  (tcinc664).** `little_things_test.dart` carried a parser that reads a
  constructor's parameters out of a source file, resolves the kernel's
  `this.x` forms to their field types and compares the result against the
  summary's code fence. `preferences` and `configuration` needed exactly the
  same check, so rather than a second and third copy the parser moved to
  `test/support/exception_constructor_mirror.dart` and all three modules call
  it; `little_things`' four tests are unchanged in name and in what they
  assert. The class list each module checks is now *derived* from its sources
  (`exceptionClassesIn`), so an exception added to a module is covered without
  anyone extending a hand-written list — and a guard cannot be quietly
  satisfied by shortening one. Four new tests, three in `preferences_test.dart`
  and one in `configuration_test.dart`. Verified by mutation: dropping
  `autoLog`'s default, restoring `bool?`, deleting a constructor block, and
  making the summary say `Object? stack` each fail exactly the intended test.

- **observing: two lifecycle test comments describe the contract instead of the
  TDD phase they were written in (tcinc663).** Both comments in
  `test/observing_test.dart` ended by declaring the test red against an
  implementation that lacked `dispose` and lacked `didUpdateWidget` migration —
  the strongest possible claim about a module whose entire contract is those two
  hooks, made directly above two passing tests, while
  `tom_observing_widget.dart` defined both. They were accurate red-first markers
  that the change turning them green did not remove. Each now names the hook it
  pins and explains why both assertions are needed: adding the new registration
  without dropping the old renders correctly and is visible only as a rebuild
  the old observable should no longer be able to cause. Both comments also
  opened by citing a numbered section of a document that is nowhere in the
  workspace; the citations are dropped rather than resolved, matching the
  direction tcinc672 takes for the same defect in the resources tests. A
  three-test guard keeps the file free of phase markers and section citations
  while requiring the comments to keep naming their hook, so it cannot be
  satisfied by deleting the prose it checks.

- **observing: the example demonstrates the deviation it used to rely on
  (tcinc662).** `example/observing/observing_example.dart` called
  `adaptor.removeListener(() {})` with a closure it had never registered and
  said only "removeListener stops further notifications", so the one line that
  proved the undocumented half read as an oversight. It now says why that works
  and adds the mirror case, two `addListener` calls where the first is replaced
  before it ever fires. `test/observing_test.dart` gains the matching pin — the
  existing removal test hands back the listener it registered, so it passes
  whether or not the argument is consulted and cannot stand in for it — plus a
  three-test guard requiring every file that carries the single-listener callout
  to state both halves. The API summary's `removeListener` row is checked
  separately, because the file-wide check passes as soon as the callout
  paragraph mentions the argument while the table still says otherwise.

- **observing: the reference directions are pinned, without depending on the
  collector (tcinc661).** `test/observing_test.dart` gains two behavioural
  tests and a documentation guard. The behavioural pair states the two
  directions the prose now distinguishes: an observer held by a local keeps
  receiving notifications until `removeObserver` is called — removal, not
  collection, is what ends them — and a mounted `TomObservingWidget` still holds
  the very observable instance it was given. Neither waits on a garbage
  collection, so neither is flaky. The guard checks every file in the module
  that tells a reader what `dispose` does: each must exist, must still describe
  the deregistration, must say which side holds which, and must not carry the
  retired claim again.

- **little_things: the catch-clause order is executed rather than only stated
  (tcinc660).** The module exists so that `on X catch` clauses can separate a
  presentable client failure from one that must not be shown, and the single
  rule a consumer can get wrong is that `TomClientUIException`'s clause has to
  come before `TomClientException`'s. That rule was written in the class
  dartdoc, the module readme and the completion document, and demonstrated
  nowhere: neither the example nor the suite contained a single `on` or
  `catch`, both expressing the discrimination with an `is` check instead — a
  mechanism that has no order and so cannot show the mistake. The example now
  runs the correct handler and the swallowing one side by side and prints what
  each returns for the same failure, and the suite asserts which clause ran in
  each, that a kernel failure walks past both client clauses, and that the
  boundary wrap catches `TomException` while keeping the cause in
  `rootException`. The mistake is spelled as a *missing* specific clause rather
  than a reversed pair, because a reversed pair is rejected by the analyzer as
  `dead_code_on_catch_subtype` and therefore cannot ship; a handler that only
  ever grew the general clause can, and has the same effect. A guard holds the
  example to the shape — it fails if the `on` clauses disappear, if the
  boundary wrap narrows to the client type, or if the general clause is shown
  first.

- **every example now names a command that succeeds (tcinc659).** All seven
  examples told the reader to run `flutter test example/<m>/<m>_example.dart`.
  That command does run the example — `main()` executes at load time, every
  print appears, every assert is evaluated — and then exits 79, "No tests were
  found", because an example declares no `test()`. So the documented invocation
  was a failing command: anything reading the exit code saw a broken example
  that had in fact done exactly what it should. And it exited 79 whether the
  assertions held or not, so the code said nothing about the example either
  way. Each header now names `flutter test test/<m>_test.dart` instead — the
  suite that calls the example's `run()` — which exits 0 on success and
  non-zero when an assertion fails. The premise the old text gave is kept,
  because it is true and explains why: the barrel import pulls in
  `flutter/material`, so bare `dart run` genuinely cannot work.
- **the remaining five examples are executed by their suites.** `configuration`
  and `little_things` already were; `observing`, `security`, `resources`,
  `runtime` and `preferences` claimed only that their behaviour was "covered
  by" a test file, which is not the same as being run by it. Each module suite
  now ends with a `the shipped example runs` group calling `run()`, so the
  command the header names is a real one. `resources` restores the app config
  provider its example installs process-wide, rather than leaving it to the
  next `setUp`.
- **`test/example_instructions_test.dart` guards the instruction.** Four checks:
  every shipped example is discovered, every example names a suite that exists,
  that suite imports and calls the example, and no example names the exit-79
  form. The first exists because the last three are otherwise satisfiable by
  deleting the example.
- **the little_things example demonstrates `autoLog` (tcinc657).** The example
  introduced the forwarded kernel payload as "`parameters`, `stack`, and
  `autoLog`" and then passed only the first two — `autoLog` appeared exactly
  once in the file, in that sentence. It is now shown rather than described,
  which is the branch the guidelines require (`_copilot_guidelines/dart/`
  `examples.md` uses narrate-instead-of-demonstrate as its BAD specimen), and
  the only one of the three that *can* be shown: the other two are inert data,
  while `autoLog` has an observable side effect. A recording log output stands
  in for the configured one, an exception is built without the flag and one
  with it, and the two records the constructor wrote are printed.
- **the little_things example is wired into the suite.** `run()` is now called
  from `test/little_things_test.dart`, so the example's own assertions — the
  ones that make its `autoLog` demonstration mean anything — actually execute.
  Two guards accompany it: the example may not name a forwarded argument it
  never passes (the forwarded set is read out of `client_exceptions.dart`, so a
  seventh parameter added tomorrow is covered without anyone extending the
  test), and, because that guard is satisfiable by deleting the mention rather
  than fixing it, a second pins that `autoLog: true` still appears in the code.
- **`autoLog` is tested for its effect, not just its field.** The two existing
  tests asserted `ex.autoLog == true` and stopped there; both would have kept
  passing if the kernel stopped logging altogether, and both dumped a pair of
  multi-line stack traces into every green run. They now capture the log, and a
  new test pins the effect directly: silent by default, two records with the
  flag, `EXCEPTION:` then `EXCEPTION_STACKTRACE:`, both carrying the
  exception's uuid so a trace can be joined back to the failure it came from.
- **documentation links (tcinc656).** A new `test/documentation_links_test.dart`
  checks every markdown link the package ships. Two properties, because a link
  fails in two ways and only one of them is a path problem: every
  repository-relative target resolves on disk, and every link whose label is a
  single code-span identifier lands on a document that actually mentions that
  identifier. The second is what catches a link that resolves cleanly onto the
  wrong document — the defect above passed a path check and would have gone on
  passing one. Targets rooted at `/` are skipped and documented as such: they
  are workspace-root-relative by convention, and the workspace root sits above
  this repository. A third test pins that the scan still sees the corpus it was
  written against (files, relative links, identifier-labelled links), because
  both guards report success on an empty scan; a fourth pins the specific link
  the suite was written for, including that it has not simply been deleted.

- **little_things (tcinc655).** Two tests pinning the module readme's framing:
  that it still describes `little_things` by the **role** the directory plays
  (a landing place for small cross-cutting helpers), and that the paragraph
  introducing the exception family marks it as the module's *present* contents
  rather than its definition. The second accepts any temporal qualifier rather
  than one sentence — forbidding a phrasing is satisfied by deleting it, and
  requiring one freezes it — and is paired with a check that the paragraph it
  watches still exists. The wording is load-bearing: this directory is the same
  one in all three tom_core packages, and the server's went from two exception
  classes to also holding a request-id type and a wire-envelope helper inside a
  fortnight. A readme that reads as "the exceptions folder" is how the next
  client-side helper ends up parked somewhere more specific. All three failure
  modes were mutation-checked.

- **little_things (tcinc654).** Four tests in a new `the API summary mirrors
  the little_things sources` group. These classes declare no types of their own
  — every parameter arrives by `super.x` — so the summary's types are only
  checkable against the kernel constructor they resolve to, and reading the
  field declaration instead gives a wrong answer that looks right. The tests
  therefore parse `TomException`'s constructor out of the kernel source
  (resolving `this.x` forms to the field's type and default) and compare it
  with the summary's blocks: one checks the parameter names and their order
  against what `client_exceptions.dart` forwards, one checks every type and
  default, one is a meta-test pinning that the kernel parser still reports
  `StackTrace?`, `bool = false` and `Map<String, Object?>?` — without it the
  first two pass just as happily on an empty parse — and one walks the
  `extends` chain out of the sources and requires every base it finds to appear
  in the hierarchy diagram. Each was mutation-checked by reintroducing the
  defect it guards.

- **configuration (tcinc653).** One test pinning the order `save()` writes:
  carried-forward undeclared keys first, then the overridden settings in
  declaration order. Nothing depends on that order — a JSON object is unordered
  either way — but the completion document quotes the printed map literally, and
  a reader compares their own run against it, so an order that drifts silently
  turns the quotation into a false report. The test overrides its two settings
  in the reverse of declaration order, so passing cannot be an accident of the
  order the test wrote them in.

- **configuration (tcinc652).** Five tests closing three coverage gaps that a
  documentation claim had been standing in for. Two `testWidgets` cases bind a
  `TomSetting<bool>` straight to a `TomObservingWidget` — one taps the `Switch`,
  the other changes the setting from outside and pumps — which turns "a
  `TomSetting` is a legal `subState` with nothing adapting it" from a claim
  about a type bound into an assertion. Two cover the neutral file store: it is
  selected by conditional *export*, not conditional compilation, so its source
  can be imported directly under a prefix and its constructor exercised on any
  target; the module's one deliberate fail-fast path was previously a promise no
  test checked. The fifth runs the example itself, so its snippets are executed
  documentation rather than transcribed documentation.

  The example gained an eighth step: a real `TomFileClientConfigurationStore`
  round trip over a temporary directory, reopening the same path with a second
  holder to assert it adopts the first's override while still re-resolving the
  untouched setting from the shipped config resources — the cross-holder round
  trip an in-memory store cannot demonstrate. Two "a real client would use
  `TomFileClientConfigurationStore` instead" comments are gone, replaced by the
  thing they described.

- **configuration (tcinc651).** Four tests in a new `the module documents
  validation truthfully` group. Two are documentation guards: no artefact defers
  validation to `Cs*` while `tom_code_specs` is absent from the pubspec
  (conditioned on the pubspec, so adding the dependency would make the pointer
  legitimate and the guard stops objecting), and the paragraph that discusses
  validation must name the caller — a guard that only forbade the old wording
  would be satisfied by deleting the paragraph. The check is paragraph-scoped
  rather than file-scoped because both artefacts use "caller" in unrelated
  passages, so a whole-file `contains` passed however the paragraph read. A
  meta-test pins that the splitter returns something non-empty, short and
  on-topic, since one that returned the whole file would pass forever — and it
  earned its keep immediately, catching that a markdown bullet list has no blank
  lines and so came back as one 21-line block; a top-level `- ` now starts a
  paragraph, because in a list the unit a reader takes as one statement is the
  bullet. The
  fourth asserts the behaviour the prose now claims: a setting accepts `-1` as a
  refresh interval and `''` as a URL, while a non-numeric raw value still throws
  `client_configuration.value.type_mismatch`.

- **configuration (tcinc650).** Six guard tests, in two groups. `the two
  file-store variants present one signature` asserts that the io and neutral
  variants agree about `const` and declare the same public member names — both
  conditioned on the sources rather than hard-coding an answer, so they stay
  true whichever way a future decision goes. `the API summary mirrors the
  configuration sources` parses the three module sources for public members and
  fails on any the summary omits, checks the file-store constructor line
  reproduces the source's `const`-ness exactly, and checks every class with a
  public constructor actually shows one (a name-level check cannot see a missing
  constructor when the class name is already a heading). A companion meta-test
  pins that the parser still finds real members, because a coverage test that
  silently stopped parsing would pass forever.

- **configuration (tcinc649).** Six tests: carry-forward of a key written by
  another writer after `load()`, and a new `swapping the store` group covering
  that the previous store's keys are not deposited into the new one, that the
  new store's own undeclared keys survive (the case that rules out the narrow
  "just clear the snapshot in the setter" fix), that the previous store is left
  untouched, that a setting declared after the swap resolves to its baseline
  rather than the old override, and that re-assigning the same store keeps the
  loaded snapshot. The executable example gained the carry-forward and
  store-swap steps.

- **Full-surface scaling (RCF3).** Closed the remaining public-surface gaps in
  the per-module test and example coverage (no public API change; 39 → 47 test
  cases across the 5 module suites).
  - **little_things**: added forwarding tests for the two constructor arguments
    that were previously unexercised — `stack` (the raw trace object, plus the
    derived `stackTrace` string) and `autoLog` — on both `TomClientException`
    and `TomClientUIException`; extended the example to show `parameters` +
    `stack` forwarding.
  - **resources**: added coverage for the `withDefault` named constructor of all
    four typed subclasses (`TomStringProperty`, `TomIntProperty`,
    `TomDoubleProperty`, `TomBoolProperty`) across both the present-key and
    absent-key branches (previously only `Int`/`String` were exercised);
    extended the example with `TomDoubleProperty` and a present-wins-over-default
    case.
  - **runtime**: added tests for the previously-uncovered
    `TomFlutterPlatformUtils` surface — `getBrowserLocation()` (null on the
    native branch), `toString()` (identifies the IO variant), and `out` /
    `outError` (side-effect-only, no throw); extended the example accordingly.
  - **observing** and **security** already covered their full public surface
    (no additions needed).

## 1.2.0

### Removed

- **Legacy forms module (RCF2).** Removed the back-compat `forms` module
  (`TomFieldOld`, `TomEmailField`, `TomPasswordField`, `TomFormOld`) — its two
  source files, both barrel exports, the executable example (`example/forms/`),
  the test suite (`test/forms_test.dart`), and the module docs (`doc/forms.md`,
  `doc/api_reference/api_summary_forms.md`). These primitives were superseded by
  the declarative forms framework in `tom_flutter_ui` (`TomForm` +
  `TomFormStringInput` et al.); per the no-back-compat policy the old surface is
  deleted rather than deprecated. The sole in-workspace consumer, the
  `tom_uam_client` sample app, was migrated onto `tom_flutter_ui`'s `TomForm` in
  the same pass. README, CHANGELOG, and the API summary index were updated to
  drop the module.

## 1.1.1

### Documentation

- **API reference (OT6).** Added a per-module API summary set under
  `doc/api_reference/` following
  `_copilot_guidelines/dart/api_summary_creation.md` — one
  `api_summary_{module}.md` per module (`forms`, `little_things`, `observing`,
  `resources`, `runtime`, `security`) plus an `api_summary_index.md` with quick
  navigation, per-module type tables, and an alphabetical type index. Each
  summary lists only the public surface (constructors, properties, methods,
  operators, and top-level functions) cross-checked against the actual source
  and the package barrel. The runtime summary documents the single exported
  getter `clientPlatformUtils` and the three compile-time `TomFlutterPlatformUtils`
  variants (io / web / neutral). No source or public API change.

## 1.1.0

### Verified

- **OT2 refactoring pass (2026-07-15)**: confirmed the whole-package gates —
  `dart analyze` clean and `flutter test --concurrency=1` 59/59 green — and that
  every review finding is resolved (see `doc/review_findings.md`). No code
  change; deeper per-module surface coverage tracked as quest todo RCE3.

### Documentation

- **Forms module**: added dartdoc to `TomFieldOld`, `TomEmailField`,
  `TomPasswordField`, and `TomFormOld`; a module guide at `doc/forms.md`; an
  executable example at `example/forms/`; and the first test suite at
  `test/forms_test.dart`. No public API change (removed only dead comments).
- **Little Things module**: added dartdoc to `TomClientException` and
  `TomClientUIException`; a module guide at `doc/little_things.md`; an executable
  example at `example/little_things/`; and tests at
  `test/little_things_test.dart`. No public API change.
- **Observing module**: added dartdoc to `TomObservingWidget`,
  `TomObservingWidgetState`, and `ValueListenableObserver`; a module guide at
  `doc/observing.md`; an executable example at `example/observing/`; and tests
  at `test/observing_test.dart`. Corrected the README usage snippet (the
  `subState:`/`child:` API; the old snippet referenced non-existent
  `observable:`/`builder:` parameters). No public API change.
- **Resources module**: added dartdoc to `TomProperty` and its typed subclasses
  (`TomStringProperty`, `TomIntProperty`, `TomDoubleProperty`,
  `TomBoolProperty`); a module guide at `doc/resources.md`; an executable
  example at `example/resources/`; and tests at `test/resources_test.dart`. No
  public API change.
- **Runtime module**: added dartdoc to `clientPlatformUtils` and the three
  conditional-import `TomFlutterPlatformUtils` variants (native IO, web,
  neutral); a module guide at `doc/runtime.md`; an executable example at
  `example/runtime/`; and tests at `test/runtime_test.dart`. No public API
  change.
- **Security module**: added dartdoc to the `TomClient2FAAdaptor` marker
  annotation; a module guide at `doc/security.md`; an executable example at
  `example/security/`; and tests at `test/security_test.dart`. Confirmed the
  module is exported from the package barrel. No public API change.

### Changed

- **Runtime module cleanup**: removed dead code in
  `platform_detection_flutter_io.dart` — an orphaned `@override` annotation, a
  commented-out `_maxCacheSize` constant, and a commented-out CupertinoClient
  block with two vague TODOs, replaced by a single concise note recording the
  deferred native-client intent. No behavior change.

### Removed

- **`camera/` placeholder module**: the folder contained only an aspirational
  `readme.md` with no implementation and was referenced by nothing. Removed
  rather than implemented — camera capture is a substantial feature (plugin,
  platform channels, capture/switch/video) outside the scope of this pass.
- **`localstorage/` placeholder module**: contained only a `readme.md` of
  research links (shared prefs / secure storage / hive / sqflite / objectbox)
  with no implementation and no references. Removed rather than implemented — a
  storage abstraction is a substantial feature with no current consumer.
- **`preferences/` placeholder module**: contained only a `readme.md` of
  research links (local-storage / database-adapter options) with no
  implementation and no references. Removed rather than implemented — user
  preferences would be a thin layer over a not-yet-chosen storage backend, with
  no current consumer.
- **`qrcode/` placeholder module**: contained only a three-line aspirational
  `readme.md` (generate/scan QR, camera integration) with no implementation and
  no references. Removed rather than implemented — QR generation and scanning
  require a plugin and camera/image-decode integration (a substantial feature),
  with no current consumer.

## 1.0.0

- Initial version.
