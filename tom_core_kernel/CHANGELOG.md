## 1.1.16

The largest release since 1.0: four new modules (`scheduling/`, `preferences/`,
`result/`, and the file-transfer half of `http_connection/`), the second
authentication pass, the deployment's own principal, and a set of deliberate
API narrowings. Read the **Changed** section before upgrading — several public
members became read-only or non-overridable, which is a compile break for
anyone who was writing them.

### Added

- **`08_server_principal_meet_example.dart`.** The meet — every authorization
  decision's second operand — was the one central security concept with no
  runnable sample, and the prose's worked example for it was illustrative only.
  The sample holds the user fixed and varies nothing but the installed
  `TomServerPrincipal`, so each outcome is attributable: an uncapped resolution,
  the same grant refused by an unlicensed deployment, the same grant restored by
  a licensed one, a generous deployment failing to widen a user who never held
  the grant, `null` versus a principal entitled to nothing (opposites, not
  synonyms), and a `TomRoleAccess` abstaining with `full` because it has no
  opinion about which features a deployment licenses.

- **`TomScopeException`.** The scope module's own `TomException` subclass,
  keyed `scope_ids.<operation>.<condition>` — `init_scope.empty_id`,
  `init_scope.separator_in_id`, `use_scope.no_identity` — with `parameters`
  carrying the offending id or type.
- **Background scheduling (`scheduling/`, csex7 / csex8 / CSEXB6 / CSEXC1 /
  csexc2).** A complete job-scheduling substrate, previously absent from the
  kernel entirely. `TomScheduler` is the runtime, and the whole loop — window
  planning, catch-up, claiming, dispatch, timeout, retry and alerting — lives in
  one awaitable `tick()` driven by an injectable clock, so a year of scheduling
  is exercised in milliseconds rather than by waiting on a timer.
  `TomSchedule` covers five kinds (`TomCronSchedule`, `TomCalendarSchedule`,
  `TomIntervalSchedule`, `TomOnceSchedule`, `TomEventSchedule`);
  `TomJobDefinition` carries the policies (`TomRetryPolicy`,
  `TomMissedWindowPolicy`, overlap, timeout) and raises `TomJobAlert`s through a
  `TomJobAlertSink` — including when a schedule can never fire again. Runs are
  persisted through `TomJobStore` (`TomMemoryJobStore`, `TomFileJobStore`) and
  executed through a `TomJobDispatcher` (`TomWorkerPoolJobDispatcher` onto the
  existing isolate pool, or `TomInlineJobDispatcher`). The runtime never
  executes anything itself.
- **Cluster coordination for the scheduler (`TomLeaseLock`, csex8).** Two
  schedulers over one store both claim the same due run unless something
  arbitrates. Supplying a `TomLeaseLock` (`TomMemoryLeaseLock`,
  `TomFileLeaseLock`) gates every run on a lease that is renewed while the work
  runs and lapses when a node dies, with **fencing tokens** (`TomLease.token`,
  strictly increasing per resource) so a paused-then-resumed holder cannot write
  behind its successor's back. The lock is optional and `null` by default: left
  unset, the scheduler behaves exactly as the single-node runtime. The execution
  guarantee is **at-least-once** — job bodies must be idempotent.
- **Declarative jobs (`@TomScheduledJob`, CSEXC1).** A job class annotated with
  `@TomScheduledJob(cron: '0 3 * * *')` *is* its own registration; extend
  `TomJobBase` and start-up collapses to `TomScheduledJobs.registerAll(scheduler)`.
  This removes the failure mode where the class and a hand-written
  `TomJobDefinition` are joined only by a string typed twice, so a rename
  silently unpairs them.
- **`TomResult<T>` — the canonical success-or-error envelope (csmb4, CodeSpecs
  CE-ER).** The server contract treats only 5xx as a transport failure; every
  application outcome, success *or* structured error, comes back in a 2xx body
  as one envelope. `TomResult` is that envelope (explicit `success`
  discriminator, reflection-free `TomJsonSerializable` wire form), carrying
  either a value or a `TomErrorResult` (machine `code`, default message,
  `TomFieldError` list, `retryable`, `TomErrorSeverity` with forward-compatible
  `fromWire`). It lives in the kernel rather than a CodeSpecs-only package
  because both tiers read the same discriminator.
- **Second-factor authentication, end to end (`security/two_factor.dart`).**
  Login became a two-pass flow: pass 1 verifies the primary credential and, when
  the principal still owes a second factor, answers with a token that is a
  *challenge carrier* rather than a session; pass 2 takes that token plus the
  submitted factor and returns exactly the token pair a 2FA-free login would
  have produced. The challenge travels in the token's claims (`Tom2FAClaims`),
  not in a server-side pending-login record, so pass 2 stays stateless and any
  instance can complete a login started by any other. `Tom2FAChallenge` is the
  client-visible half (mechanism, hint, attempts remaining, expiry, an opaque
  `clientData` map); whatever the server needs to verify travels encrypted under
  `Tom2FAClaims.verificationData`. `Tom2FAPendingEnrolment` and
  `Tom2FAMethodDescriptor` let a login *enrol* the factor it demands rather than
  dead-ending a user who has none, and `TomTotp` supplies the RFC 4226 / 6238
  primitives. Neither the framework nor the wire types name a mechanism: adding
  SMS or WebAuthn needs no change here.
- **The ambient server principal (`TomServerPrincipal`, csex4).** A deployed
  server is itself a principal — it authenticates with a service credential and
  its entitlements are *this deployment's* feature grants. Access evaluation now
  has two operands and returns the meet: `min(user, server)` over the four-state
  ladder. A user's `TomAuthState.full` on a feature the deployment is not
  entitled to evaluates to `none`; deployment grants cap user grants and never
  widen them. A deployment that never logs itself in leaves the holder empty and
  evaluation degrades to the user's grant alone — the designed default, not a
  failure mode (`TomServerPrincipal.isConfigured` says which regime a process is
  in). It is a process-wide static rather than a zone value because the zone slot
  for `TomPrincipal` is already taken by the *user* inside a request.
- **Streaming file transfer (`file_transfer.dart` / `http_file_transfer.dart`,
  csfs2).** The client half of the framework's file storage. `TomServerCall`
  accumulates a whole response into a `BytesBuilder` — right for JSON, wrong for
  a 400 MB video — so this library reuses the same connection machinery
  (`TomServerChannel`, the bearer token, the client factory) without ever
  materialising the payload. `TomFileSource` to send, `TomFileMetadata` to
  describe what was stored, `TomFileTransferClient` (`TomHttpFileTransferClient`,
  `TomMemoryFileTransferClient`) to move the bytes, with `TomTransferProgress`
  and `TomTransferCancellation`. A transfer addresses an application-owned
  **slot** (`invoices/4711/scan`), never a storage key: keys are generated
  server-side and returned in `TomFileMetadata.key`, because a client that could
  name its own key would turn any upload endpoint into an open write surface on
  the blob store.
- **Server-stored user preferences (`preferences/`, TCCA10 / C-13, TCCB5).** The
  wire contract (`TomUserPreferenceDto`, `TomUserPreferenceWriteRequest`,
  `TomUserPreferenceKeyRequest`, `TomUserPreferencesApiService`, the
  `tomUserPreferencesApi` endpoint set), a typed `TomUserPreferenceCodec` for
  the stored values, and `TomUserPreferenceKeys` for the framework's own keys.
  `TomApiEndpoint.resolveUri` was added so a client can build the call URL from
  the DTO it already holds — path captures and query parameters both resolve
  through `urlParameterMapping`, and a missing capture is a named
  `TomEndpointException` rather than a malformed URL.
- **External identity as another authentication service
  (`security/oauth_contract.dart`).** `TomOAuthProviderDto`,
  `TomOAuthAuthorizationRequest`, `TomOAuthAuthorizationDto`,
  `TomOAuthCallbackRequest`, `TomOAuthApiService` and the `tomOAuthApi` endpoint
  set (list providers, begin authorization, complete authorization). OAuth 2.0 /
  OIDC is modelled as one more authentication service rather than a parallel
  login path.
- **`TomObservableEnum<E>` (tcca9 / C-8).** An observable enum cell whose
  *display text* comes from the text-resource bundle
  (`<scope>.<enumname>.<value>`, lower case) instead of a Dart-side label table.
  It notifies when *either* the value or the installed bundle changes, which is
  what makes a locale switch re-render a bound field without the caller
  rebuilding anything. `TomTextResourceProvider` gained the revision cell
  (`appResourcesRevision` / `notifyAppResourcesChanged`) that second trigger
  needs, and a `TomTextResourceProvider.from` constructor; assigning `resources`
  announces a change only on the *installed* provider, so populating a
  not-yet-installed one stays silent.
- `TomHeader.location` — the `Location` header name, which is what makes a 3xx a
  redirect rather than an empty body with an odd status.
- **`TomReflectionInfo(strictUnknownFields: true)` (tcinc196).** `setValues`
  silently dropped any key naming no declaration on the target, which is the
  right default on the wire but hides a typo in a config file. The new
  converter option raises `reflection.set.unknown_field` instead. It is a
  property of the converter, not of the call, so nested objects inherit it —
  the walk recurses through `createInstanceFromJson` on the same instance. The
  shared `tomReflectionInfo` stays lenient.

### Changed

- **The security API mirror lists all six two-factor classes.** Its table of
  contents, class hierarchy and `two_factor.dart` overview each named three —
  `Tom2FAClaims`, `Tom2FAChallenge`, `TomTotp` — while the reference body
  documented six. `Tom2FAEnrolmentClaims`, `Tom2FAPendingEnrolment` and
  `Tom2FAMethodDescriptor` were therefore unreachable by anyone navigating from
  the top, which is the whole enrolment half of the two-pass login: a reader
  finding only the challenge pair concludes the framework cannot enrol a user
  who has no factor yet. All three lists now agree, and the omission was
  confirmed to be exactly these three by diffing every public type declared in
  `lib/src/tombase/security/` against the mirror.

- **The meet's worked example now declares the identifiers it turns on.** The
  security guide's central explanation of why a control the user satisfies can
  still resolve to `none` used `user` and `server` without binding either, and
  obtained the server principal on one line only to discard it and pass an
  undeclared `server` on the next. Both are now bound —
  `TomBearerAuthentication.getPrincipal()` and `TomServerPrincipal.current!` —
  and the per-resource-role adapter snippet nearby, which had the same defect on
  `principal`, is bound too. The values the blocks assert were already correct
  and are now verified by the new `08_server_principal_meet_example.dart`.

- **No documented `updatePrincipal` call silently wipes the principal's
  per-resource grants any more.** The method replaces the ACI rather than
  merging into it, and `resourceRoles` is its only optional parameter — so a
  four-argument call compiles and clears every per-resource grant the principal
  held. Best Practice 7 showed exactly that inside a `refreshPermissions()`
  running on a timer, which drops the grants on every tick; because
  `TomResourceRoleAdapter` resolves an ungranted resource to `none`, the symptom
  is UI disappearing a few seconds after login with nothing in the logs. Best
  Practice 7 now passes `resourceRoles` and explains the replace-not-merge
  semantics, the `updatePrincipal` dartdoc leads with them, and the printed
  "Example call" in `04_bearer_authentication_example.dart` — a fourth copy of
  the same four-argument shape — shows the fifth argument and the warning.
  `security_test.dart` now pins the contract: the existing "replaces the ACI"
  test asserts `resourceRoles` round-trips, and a new test asserts that omitting
  it clears a grant the principal was holding. Documentation and test coverage
  only; the behaviour is unchanged.

- **The resource-key protection docs no longer show a snippet that protects
  nothing.** `TomResourceKeyProtection.globalSettingProtectionDefault` defaults
  to `false`, and `isProtectedFor` returns `false` before consulting any key
  while it is off — so `tomProtect` serves the real value for every key and
  every principal. Best Practice 5 ("Protect Sensitive Fields") and the Quick
  Start both showed `tomProtect` calls with no mention of the switch, five
  hundred lines from the one place it appeared; copied as written they were
  no-ops on exactly the PII they claimed to guard. Both snippets now set the
  switch and link to the canonical subsection, which itself now states that the
  default is fail-*open*. Best Practice 5 additionally documents the
  fail-*closed* consequence of turning it on: `tomProtect` reads the principal
  from the ambient zone, so outside a request — start-up, a background isolate,
  a test — every protected field serves its fallback, and a serializer shared
  between a request and a job will behave differently in each. The same
  precondition is now stated on `protect`, `isProtectedFor`, `isProtected`,
  `tomProtect` and `tomProtected`, so it reaches IDE hover and not just the
  prose. Documentation only — the behaviour was already correct and covered by
  tests.

- **`TomGradedAccess` now appears in the security prose, including in the
  built-in access-control table it was missing from.** The table listed nine
  controls; `access_controls.dart` ships ten. The omitted one is the only
  control that overrides `resolvePrincipalAuthState` rather than the boolean
  `checkPrincipalAccess`, which makes it the only one able to resolve to
  `disabled` or `read` — every other row is two-valued and collapses to `full`
  or `none`. The doc therefore introduced a four-state model and then offered
  nine controls that between them could produce two of the states. Added: a
  tenth table row marking it as the composer, a `Graded Access (all four
  states)` subsection covering the ladder, the `read`→`full`/`disabled`→`read`
  defaulting, the `showsContent` collapse for binary consumers and the
  deployment-side grading, and a paragraph under `TomAuthState` naming all
  three sources of the middle states (graded access, per-resource roles, the
  meet). The previously undefined mention in the meet section and the
  `resolvePrincipalAuthState` row of the operand table now link to it, and
  Best Practice 5 contrasts it with all-or-nothing resource keys. The existing
  sample `06_graded_access_example.dart` is now linked from the prose.

- **The security documentation now covers per-resource roles, which it had
  never mentioned.** `resource_role_authorization.dart` is exported from the
  barrel, tested, and used throughout `tom_core_server` and the advanced
  samples — but `doc/security/security.md` introduced "these main files" and
  listed eight of the module's nine, omitting exactly that one. So
  `TomResourceRoleRegistry`, `TomResourceRoleAdapter` and the fifth ACI
  collection `resourceRoles` were absent from the module's prose, and with them
  an entire authorization paradigm: a role scoped to a *single* resource, so one
  principal can be `owner` of one project and `viewer` of another at the same
  time. The gap was compounded by the doc claiming, of the
  `TomAuthorizationAdapter` contract, that "a kernel-backed adapter maps
  resource-key protection to states" — a description of nothing that exists.
  `TomResourceRoleAdapter` is the only implementation the kernel ships, and it
  is what makes `TomAuthorization.resolveAuth` return anything other than
  `full`. The file table now lists all nine files, the ACI table and its
  constructor sample carry `resourceRoles`, Key Concepts defines the term,
  "Choose One Authorization Paradigm" lists it as the fifth (and warns that it
  deliberately ignores the global roles), and a new section documents the
  registry/adapter pair together with the no-fallback guarantee that governs
  both: an ungranted resource resolves to `none` rather than degrading to the
  global roles, and an unregistered role resolves to `none` rather than
  granting by default. The module readme and the package README key-type tables
  gained the pair as well. Also documented, because it is the trap this API
  makes easiest to fall into: `TomBearerAuthentication.updatePrincipal`
  *replaces* the ACI, so omitting its optional `resourceRoles` argument silently
  drops every per-resource grant the principal held — the Token Management
  sample now passes it.
- **`TomAuthorizationGroup`'s documentation stopped naming a parameter that
  does not exist.** The class dartdoc pointed at `[authorizationGroup]` — a
  member `TomAuthorizable` has never had, so the reference was dead — and both
  the dartdoc and `doc/security/security.md` carried a worked example reading
  `TomTextField(tomId: 'street', authorizationGroup: shipping, ...)`, which
  would not compile: Tom Flutter UI's input widgets take `tomGroup`. The
  prose doc contradicted itself fourteen lines apart, its own
  `TomAuthorizable` table having listed `tomGroup` correctly all along. Both
  samples now lead with the kernel-level `register(element)` form, which is
  what this package actually offers and what its compiled example asserts, and
  the widget snippet is marked as belonging to the UI package. The two live
  references are qualified (`[TomAuthorizable.tomId]` /
  `[TomAuthorizable.tomGroup]`) so they resolve from the group's scope rather
  than silently rendering as plain text.

  Worth knowing for anyone writing against either layer: Tom Flutter UI really
  does use both spellings — `tomGroup` on inputs and other `TomNodeBase`
  widgets, `authorizationGroup` on `TomForm`, `TomActionController` and
  `TomExpansionPanel`. That split is what made the error easy to write, and
  both doc sites now say so instead of leaving the next reader to rediscover
  it.

- **`TomAuthorizationGroup`'s inspection helpers now agree with each other
  about who is in the group.** `isUniform` and `mostRestrictive` skipped
  members whose `effectiveAuthState` is `none`; `members`, `memberCount`,
  `isEmpty` / `isNotEmpty` and `findMember` counted them. A group could
  therefore report members that `mostRestrictive` refused to see, and
  `findMember` would hand back an element the user is not allowed to know
  exists. `members` is now the single place the visibility filter is applied
  and every other helper is defined in terms of it, so the disagreement cannot
  reappear one helper at a time. Consequences worth knowing: a group whose
  members are *all* hidden now reports `isEmpty`, and `memberCount` /
  `findMember` resolve `effectiveAuthState` where they previously did not.
  `register` / `unregister` deliberately keep working on the raw
  registrations — a hidden member is still tracked, and still removable by
  whoever added it.

- **`Tom2FAChallenge.expiresAt` and `Tom2FAPendingEnrolment.expiresAt` are now
  actually normalised to UTC, as both types said they were.** The constructors
  assigned the parameter straight through, so a caller that passed a local
  instant got it back with its own zone attached while the dartdoc promised
  UTC. Nothing misbehaved internally — `isExpired` and `toClaims` each called
  `toUtc()` again on the way past — but that re-normalisation is exactly what
  hid the omission, and it did nothing for the one reader that mattered: an
  application rendering a countdown from the public field, or comparing the
  `toString()` of one challenge across two machines in different zones. The
  constructors now normalise (`null` stays `null` on the enrolment, whose
  choosing stop has no deadline to normalise) and the downstream `toUtc()`
  calls are gone, so the invariant is stated once, where it is established.
  `isExpired` likewise dropped its normalisation of `now`: `isBefore` compares
  instants, not wall clocks, so a caller may pass either zone. This brings the
  two kernel types in line with their server counterparts
  `Tom2FAEnrolmentState` and `TomOAuthTokenGrant`, which already normalised in
  the constructor and relied on it downstream — `Tom2FAEnrolmentState` carries
  the very sentence the kernel challenge had copied without the code.
- **`pendingTwoFactorChallenge` / `pendingTwoFactorEnrolment` are now `null` for
  a challenge or offer that has lapsed or burned its last attempt.** The
  security guide stated this as a kernel guarantee, but the getters delegated
  straight to `fromClaims`, which checks only that the claims are *decodable* —
  so a lapsed interim token round-tripped to a live-looking challenge. A client
  that slept, or sat in a background tab, prompted for a code the server was
  always going to refuse; on the enrolment side the documented `while
  (enrolment != null)` loop had nothing to terminate it. The freshness check
  sits on the getters rather than in `fromClaims`, which stays a clock-free
  decoder of the wire format: the server has its own authoritative clock and
  already runs the same checks in `authenticatePass2`, and a test needs to be
  able to build a lapsed challenge to assert against. One asymmetry on the
  enrolment getter — exhaustion disqualifies an offer only once `hasOffer` is
  true, because the choosing stop carries no attempt budget and so reads back
  as exhausted; a chooser owes no attempts because nothing has been generated
  to attempt yet. (The server's own `Tom2FAEnrolmentState.isExhausted` already
  encodes that rule as `hasOffer && attemptsRemaining <= 0`.)
- **Breaking: `TomClientLimitsInformation` is read-only, like its sibling.**
  `enabledModules` and `quotas` were plain reassignable public fields with
  `const []` / `const {}` defaults — which made the class mutable in the one way
  that skips the constructor and immutable in the one way a caller reaches for
  first. `TomClientLimitsInformation().enabledModules.add('reporting')` threw an
  `UnsupportedError` at runtime with no compile-time signal, because the default
  was a `const` literal, while the very same call on a *populated* instance
  succeeded and silently also mutated the list the caller had passed in. The
  class now follows `TomAccessControlInformation` exactly: private backing
  collections, copied in the constructor, exposed through `List.unmodifiable` /
  `Map.unmodifiable`. The two ACI-side classes finally read the same way, and
  neither can be edited behind the issuer's back — a subscription is decided by
  whatever minted it, not by the code reading it. Callers that assigned to
  either field must construct a new instance instead; nothing in the kernel did,
  and `bearer_authentication.dart` only ever read them.

- **Breaking: a scope id that is empty or contains `.` is now refused.** Ids
  are joined with `.` to build the scope path, and nothing looked at the string,
  so an id carrying the separator forged a segment boundary: `TomScopeBase(
  scopeId: 'a.b')` rendered as exactly the same path as the unrelated chain
  `'a'` → `'b'`, and an empty id rendered as `''`, the string consumers are told
  to read as *no scope at all*. The path is not cosmetic — it is the prefix that
  resource and authorization lookups are keyed on — so two structurally
  different trees producing byte-identical paths meant a scope could name
  another scope's resources. `initScope` now rejects both with a
  `TomScopeException`, which covers `TomScope.withScope` and the `TomScopeBase`
  constructor too, since both route through it; the check therefore runs once
  per scope rather than on every path build, and runs before any field is
  written, so a refused call leaves the instance still initialisable. Nothing
  else about the id is policed — spaces, slashes and non-ASCII are unambiguous
  and stay legal. Ids written as literals in source cannot trip this at all;
  the exposure it closes is the case the module exists for, one scope per detail
  row named from the row. What was Best Practice 3 in
  `doc/scope_ids/scope_ids.md` ("avoid embedding `.` in an id") is now a
  guarantee rather than advice.
- **Breaking: the scope guards now throw `TomScopeException` instead of
  `StateError`.** Adding id validation would otherwise have given a 300-line
  module two unrelated error families for the same kind of failure — "this
  scope is not usable". The kernel's own precedent is decisive (roughly 130
  `Tom*Exception` subclasses against five `StateError`s in all of
  `lib/src/tombase/`), so the existing identity guards were converted rather
  than a second family introduced. Keys are
  `scope_ids.<operation>.<condition>` and `parameters` carries the offending
  value, which makes the failures greppable and translatable like every other
  kernel error. Callers catching `StateError` around scope construction or
  installation must catch `TomScopeException`.
- **Breaking: a `TomScopeMixin` instance whose `initScope` never ran is now
  refused at the point of use, not at the point of consequence.** Because
  `initScope` may be called after construction — a documented pattern, for a
  scope whose parent is only known later — there is a window in which an
  instance exists and is not yet a scope. `runInScope` read neither `id` nor
  `parent`, so it installed the half-built object onto the zone without
  complaint: the body ran, every line of it saw `TomScope.current` return the
  broken instance, and the failure surfaced at whichever later call first asked
  for a path — a resource lookup, an authorization check — as a
  `LateInitializationError` naming a mangled private field and mentioning
  neither the class nor the missing call. Installation now throws a
  `TomScopeException` naming both, and so do `id`, `parent` and `getScopePath()`, which
  previously threw the same unhelpful `LateError`. `initScope` additionally
  refuses a `parentScope` that has no identity of its own, which closes the
  variant where a perfectly good child installs cleanly and the chain walk hits
  the broken parent later. Checking the parent there rather than during the
  path walk is what keeps both checks O(1): an initialised scope has a fully
  initialised chain by induction, since the identity is write-once and a parent
  cannot lose one afterwards. Together they buy one invariant — whatever
  `TomScope.current` returns is usable. Calling `initScope` twice is still
  rejected, unchanged. `InScopeBuilder` still captures an uninitialised scope
  without complaint and refuses at invocation; capture is not use, and a widget
  may legally be constructed with a scope identified before the first build.
- **Breaking: `convertMinutesToUtcOffset` rejects offsets outside ±14:00.** The
  hour field is two digits wide and the padding never truncates, so an
  unbounded offset rendered as `+100:00` — a string the function accepted
  happily and every ISO 8601 parser downstream rejected. Values outside ±840
  minutes now throw the new `TomFormattingException`
  (`formatting.utc_offset.out_of_range`), carrying the offending value in the
  message and in `parameters['totalMinutes']`. The bound is the reachable range
  of the packaged IANA data, measured across every location's transition table
  (−720 Pacific/Kanton through +840 Asia/Anadyr, nothing outside), so it never
  refuses a value the timezone API can produce; it is inclusive because
  Asia/Anadyr sits exactly on it. Offsets obtained from a `TomTimezone` are
  always in range, so `getUtcOffsetStringOn`, `toStringOn` and `toString`
  cannot throw — only the static `TomTimezone.convertMinutesToUtcOffset`, which
  takes an arbitrary `int`, can. This is the one function in `little_things`
  that raises: the trace formatters stay silent because they run while
  reporting some other failure, which formatting an offset does not.
- **Breaking: `TomAccessControl` subclasses must move their rule.**
  `checkAccessibility` and `resolveAuthState` are now `@nonVirtual` — they
  compute the user/deployment meet described above, and a cap any subclass could
  sidestep by overriding the method everybody already calls would not be a cap.
  Override `checkPrincipalAccess` / `resolvePrincipalAuthState` instead (the
  *user* operand; the rule is unchanged, only the method it belongs in), and
  `resolveServerAuthState` for the *deployment* operand. That last one defaults
  to `TomAuthState.full` — uncapped — because a control naming a role, a group
  or a resource key has no opinion about which features a deployment licenses,
  and a participant with no opinion must return the identity element.
  `TomEntitlementAccess` overrides it, since entitlement patterns are the grant
  carrier.
- **Breaking: several public members are no longer writable (TCCA16).** Each was
  a process-wide switch that a single caller could flip for everybody:
  `TomClientRemoteContext.current` is now a getter (use `setCurrent` once at
  startup, or the new zone-carried `runWithContext` for a scoped override, plus
  `resetCurrent` for tests); `TomWorker.workerCount` is a getter (writing it
  handed two live workers the same name) with `resetWorkerCount` for tests;
  `TomHttpMethod.methods` is an unmodifiable map; `TomScope.defaultScope` is
  `final`; `TomContentDisposition.attachment` is `const`.
- **Breaking: `TomWorker.executors` and `TomWorker.isMainIsolate` are no longer
  writable either (tcinc56).** The two statics TCCA16 left standing beside
  `workerCount`. `executors` now reads back an unmodifiable — but live — view;
  register through `addExecutor` / `removeExecutor` / `clearExecutors`. Every
  message handler dispatches off the one backing list, so a caller who replaced
  it wholesale silently detached dispatch from every later registration.
  `isMainIsolate` is a getter, and the one that mattered: it is load-bearing,
  since `sendToCreator`, `executeInCreator` and the server's authorization and
  cache layers all branch on it, so a caller who assigned it could make the main
  isolate act as a worker. The worker-side transition is internal; tests reach
  the other side through `simulateWorkerIsolate` / `resetIsMainIsolate`.
- **Breaking: three members were removed.** `TomNullInterface` is now private —
  it only ever existed to give the internal null-component marker a type, and no
  consumer could meaningfully implement it. `TomException.newField` was a
  never-used "reserved for future use" field. `TomScopeMixin`'s `id` and
  `parent` setters are gone; `initScope` is the single write-once entry point.
- **Ambiguous bean bindings now throw instead of warning (TCCA18).** When two
  implementations qualify equally within one selection tier, the locator raises
  `beanlocator.initialization.ambiguous_implementation` naming both candidates
  and pointing at `@TomEnvironment` / `@TomPlatform` to distinguish them.
  Previously the first candidate won and the second was logged as a warning —
  which binds a deployment to an arbitrary implementation, the failure mode
  where the code runs, the tests pass and production misbehaves.
- **Reflection widens `int` onto `double` fields (tcca20).** JSON and
  command-line `key=value` arguments have no int/double distinction, so
  `{"rate": 2}` decodes to an `int` and a whole-number `double` was previously
  unrepresentable. The converse is deliberately absent: narrowing would need a
  rounding policy, and truncating `2.5` silently loses data.
- **Breaking: `makeCleanJsonMap` keeps null values and returns
  `Map<String, Object?>` (tcdocc1).** The sanitiser's helper used `null` to mean
  both "this *is* JSON's null" and "this has no JSON form", so a deliberate null
  was dropped alongside a `DateTime` — losing the distinction between an absent
  field and one that is present and null, which is exactly the distinction a
  PATCH-style update, a "explicitly cleared" setting, or a nullable-by-schema DTO
  is built on. It bit hardest through `TomJsonSerializable`, whose `toJson`
  returns `Map<String, Object?>` and is documented to carry nulls: converting a
  value object routes its map through the sanitiser automatically, so the
  interface promised the type could describe its own state and the sanitiser then
  edited the description. The two answers are now separated by a private
  sentinel; `null` passes through in maps and in lists (where dropping it also
  shifted every later index), and only genuinely unencodable values are filtered.
  Callers that stored the result in a `Map<String, Object>` need the wider type.
- **Registering the UTC singleton is no longer reported as an ERROR (tccc3).**
  The IANA database ships `Etc/UTC` and has no location keyed exactly `UTC`, so
  `TomTimezone` registers its documented `utc` singleton on every start of every
  process — an ERROR line that is always present is how a team learns to filter
  out ERROR. It is now DEBUG. A genuine ERROR was added for the case that
  actually is broken: the database loaded no locations at all, so only UTC is
  available and every other lookup will miss.
  `TomTimezone.populateFromLocations` is `@visibleForTesting` so that branch can
  be driven, since on a native platform the embedded database always loads.
- `TomTimezone.convertMinutesToUtcOffset` now delegates to the top-level
  `convertMinutesToUtcOffset` in `little_things/formatting.dart` so the two entry
  points cannot drift apart.
- **The `Authorization` header is omitted rather than sent as `Bearer null`**
  when nobody has signed in. An absent credential is a clean 401; a malformed one
  is the same rejection dressed up as a parse failure.
- **Stack-frame truncation kept the wrong frames (RCL1).** `_processStackFrames`
  iterated oldest-first, so a depth limit discarded the frames nearest the throw
  site — the useful ones — and kept the outermost `main`-side frames. It now
  iterates newest-first, as its own documentation already claimed.
- `TomAuthenticationResult` gained `requires2FAEnrolment`,
  `availableTwoFactorMethods` and `twoFactorEnrolmentSkippable`, so pass 1 can
  tell a client that the user must *enrol* a factor rather than merely present
  one.
- **Dependency floors were raised, and two dependencies added.** `tom_basics`
  `>=1.0.3` (`setCurrentEnvironment` now applies its fallback unconditionally;
  1.0.2 added `TomRuntime.reset()`); `tom_crypto` `>=1.1.0` (earlier versions
  drew secure random bytes with an exclusive bound of 255, so no byte could be
  `0xFF` — a bias inherited by every RSA key pair and every password salt this
  package re-exports); new `crypto ^3.0.0` for the `TomTotp` HMAC-SHA1
  primitives; new `meta ^1.9.0` for the `@nonVirtual` annotations that make the
  deployment cap load-bearing. Dev: `tom_reflection_generator` `>=1.3.1`
  (type-literal annotation arguments are now emitted import-prefixed).
- **Breaking: `TomResourceKeyAccess` now answers about the principal it is
  given.** `checkPrincipalAccess` dropped its argument and consulted the
  ambient zone instead, making it the one control in the family that did not
  answer the question the family's contract states — "whether *[principal]*
  satisfies this control". Outside a request zone the divergence was silent and
  fail-closed: `TomResourceKeyAccess('x').checkAccessibility(p)` returned
  `false` for a principal `p` whose `aci.resourceKeys` contained `'x'`, because
  the zone was empty. The rule is now stated once over an explicit operand,
  `TomResourceKeyProtection.isProtectedFor(principal, key)`, and reached two
  ways: the control passes the principal it was asked about, while
  `isProtected`, `tomProtect` and `tomProtected` keep their zone-reading
  behaviour unchanged and now delegate to it. The master switch
  `globalSettingProtectionDefault` is unaffected and still gates the whole rule
  — with it `false`, every principal is granted. Callers who relied on the zone
  being consulted *through an access control* must pass the principal instead,
  which is what every call site already looks like since `checkAccessibility`
  takes one. The suite's `should integrate with TomResourceKeyProtection` case
  asserted the old behaviour and was replaced.

### Tests

- **Every `TomAuthorizationGroup` inspection helper is pinned against a hidden
  member.** One case per helper — `members`, `memberCount`, `findMember`, and
  the `isEmpty` / `isNotEmpty` pair over an all-hidden group — each of which
  failed before the change. A fifth reveals a hidden member after the fact and
  asserts it returns to every helper, so the filter is proven to be evaluated
  per call rather than latched at registration. The sixth is the guard the
  other five need: unregistering a *hidden* member and then revealing it must
  not resurrect it, which is what fails if registration bookkeeping is routed
  through the visibility filter along with everything else.

- **The UTC normalisation of both 2FA expiries is pinned at the constructor.**
  One case per class builds a challenge / offer from a local `DateTime` and
  asserts the field reads back `isUtc` *and* on the same instant — normalising
  must re-label the instant, not shift it. A `toString()` case per class pins
  the printed form, which is where the drift was visible: the same challenge
  used to print two hours apart on two machines. Two guards cover what the
  cleanup must not break — the enrolment chooser's `null` deadline must stay
  `null` rather than acquire one, and `isExpired` must answer identically for a
  local `now` as for a UTC one, since the normalisation of its argument was
  dropped.
- **The 2FA freshness filter is pinned on both getters, in both directions.**
  Four cases assert that a lapsed or burned challenge / offer reads as nothing
  pending. Two more guard the boundaries the fix had to respect: `fromClaims`
  must *still* decode what the getter filters out (otherwise the filter has
  leaked into the wire decoder), and the enrolment chooser must survive the
  filter even though its absent attempt budget reads back as `isExhausted`
  (otherwise the filter deletes the choosing stop and the enrolment flow with
  it). Both of those pass before the fix as well as after — which is the point:
  they are the guards, not the demonstration.
- **The fail-closed attempt budget is pinned on both 2FA readers.** One case per
  class asserts that a payload whose `attemptsAllowed` is missing (or the wrong
  shape) still yields a *non-null* challenge / offer, but one that is already
  `isExhausted`. Written as a pair deliberately: whichever of the two siblings
  someone edits, the other's test still states the rule. Verified to bite by
  temporarily changing the fallback to the constructor's `3` — both fail with
  `Expected: <0> Actual: <3>`.
- **`TomClientLimitsInformation` has the immutability group its sibling always
  had.** Four new cases: unmodifiable `enabledModules`, unmodifiable `quotas`, a
  case asserting that an empty instance and a populated one refuse writes the
  *same* way — the asymmetry the `const` defaults created was visible only by
  comparing the two — and one proving the constructor copies rather than aliases,
  by editing the caller's own list and map afterwards and expecting the instance
  to be unmoved.
- **`TomResourceKeyAccess` is pinned to its argument.** The group grew from two
  cases to seven, covering both sides of the master switch, a `null` principal,
  and a principal that holds the key with **no zone installed** — the case that
  can only pass if the control reads what it was handed. One case sets the two
  operands against each other deliberately, running the check inside a zone
  holding a *different* principal, so a zone read cannot rescue an argument
  that lacks the key nor condemn one that holds it.
- **Scope ids are pinned at all three entry points.** A
  `scope ids are validated` group runs the five unusable ids (`a.b`, `.`, `a.`,
  `.a`, `''`) through `withScope`, the `TomScopeBase` constructor and
  `initScope` — one check covers all three, but all three are public, so all
  three are asserted — and matches on `parameters['scopeId']` so a test cannot
  pass on some *other* rejection. Three more cover what the check must not
  break: the deeper chain the dotted id used to forge still builds and still
  renders `a.b.c`; a refused id leaves the instance initialisable, so a caller
  that catches and retries with a clean id succeeds; and ids that cannot forge
  a boundary (slashes, spaces, hyphens, non-ASCII, a U+00B7 middle dot) stay
  legal, because the rule is about the ambiguity and not the alphabet. Deleting
  the guard turns all fifteen red.
- **The scope failure modes the suite stopped one case short of.** Seven tests
  close the gap between "every documented behaviour is covered" and "every way
  the module can be misused is covered". Scope identity is write-once, so a
  second `initScope` is refused and a refused call moves neither the id nor the
  parent; when an unusable id and the write-once field are violated by the same
  call the id diagnostic wins, because the check runs first and names the thing
  the caller can fix. `InScopeBuilder` is now exercised in the direction that
  distinguishes *installing* the captured scope from merely not disturbing the
  ambient one — a builder captured at the root and invoked inside
  `withScope('elsewhere')` must yield the root — and all six `wrapNn` wrappers
  are run with real callbacks rather than only `null`, since each is a separate
  hand-written forwarding body. Re-entering `withScope` with an id already on
  the zone nests and repeats the segment (`app.app`) where `runInScope` on the
  same instance does not, a contrast now pinned rather than assumed. Every one
  was proven fireable by mutating the implementation.
- New suites for every new module: `scheduling_test.dart`,
  `scheduled_job_test.dart` (plus `test/contracts/scheduling_contract.dart`, the
  shared store/lock contract), `result_test.dart`, `file_transfer_test.dart`,
  `observable_enum_test.dart`, `server_principal_test.dart`.
- Bean selection is now covered end to end: `beanlocator_selection_test.dart`
  (the four tiers), `beanlocator_ambiguous_selection_test.dart` (the new throw)
  and `beanlocator_excluded_selection_test.dart`, over a shared
  `test/support/bean_selection_support.dart`.
- `timezones_logging_test.dart` and `timezones_empty_database_test.dart` pin the
  new log levels and drive the empty-database branch.
- `api_reference_coverage_test.dart` guards the doc tree against drifting from
  `lib/`.
- **`comments_read_as_is_test.dart` keeps shipped prose free of development
  history.** Roughly 170 comments across `lib/`, `test/`, `example/` and `doc/`
  pointed at internal work items (`bug §50`, `tests §34a`, quest todo ids) or
  narrated what the code used to do — both unresolvable for anyone reading the
  published package, and both easy to reintroduce while the work is fresh.
  Every site in this package has been restated as the rule that holds now,
  usually by turning the past tense into a conditional, and the new suite fails
  the build if one comes back. It distinguishes the three uses of `§` that look
  alike: citations of published standards (`RFC 4226 §5.3`, `CWE-117`) and
  specification sections (`§5.26`, `CE-ER §7`) are kept, only work-item
  pointers are refused. Traceability now runs todo → code through the todo's
  own `references` list, so the link outlives the work item without the code
  carrying its id.
- **`import_convention_test.dart` pins how the package refers to its own
  libraries, in both directions.** Inside `lib/` a sibling module is reached
  relatively; from `test/`, `example/` and `tool/` it is reached as
  `package:tom_core_kernel/…`. Each side has one correct form and the wrong one
  resolves anyway, so neither mistake announces itself. A `package:` URI into
  the package's own `src/` is what `implementation_imports` refuses for every
  other package — it passes only because the package is importing itself — and
  a relative `../lib/…` from outside gives the library a second identity, so
  the same class arrives under two types. `dart analyze` catches neither: the
  shared options enable four lint rules and neither of those two is among them.
  The barrel form inside `lib/` is deliberately not covered; it names a public
  entry point rather than reaching past one.
- **`scope_ids_test.dart` now pins the zone-elision branch it names.** The test
  called "is a no-op zone when the scope is already current" asserted only that
  `TomScope.current` was unchanged inside the body — which holds on *both*
  branches, because installing the identical scope on a child zone resolves to
  the same value. It therefore passed with the identity check deleted. It now
  compares `Zone.current`, which is what distinguishes the two paths, and also
  asserts the body ran and its result was returned; a companion test covers the
  other branch, where a different scope does get a child zone.
- **`scope_ids_test.dart` covers the window between construction and
  `initScope`.** A `before initScope has run` group asserts that installation
  is refused and the body never runs, that the instance cannot be another
  scope's parent, that `InScopeBuilder` refuses at invocation, and that `id`,
  `parent` and `getScopePath()` all name the class and the missing call. A
  fifth test holds the other side of the line — a scope identified after
  construction installs normally — so the guard cannot be tightened into
  breaking the pattern it is protecting.
- **`scope_ids_test.dart` pins the reason `buildScopePath` needs no cycle
  guard.** The walk is unguarded on the grounds that a scope built through this
  module cannot form a loop, which rests on `initScope` refusing an
  uninitialised parent and writing the link once. A
  `the parent chain cannot be made cyclic` group closes each of the three ways a
  link could be bent back — parenting to a scope that has no identity yet,
  self-parenting, and re-pointing an established parent — so relaxing either
  mechanism fails here rather than in whichever isolate later walks the loop.
  The loop itself is deliberately untested: a test that hangs until the VM dies
  takes the suite with it.

### Examples

- **New: `07_resource_role_authorization_example.dart`.** The kernel's only
  shipped `TomAuthorizationAdapter` had no runnable demonstration, which is part
  of why it went undocumented for so long. The sample declares a role
  vocabulary in `TomResourceRoleRegistry`, shows one principal holding `owner`
  on one project and `viewer` on another simultaneously, and asserts both halves
  of the no-fallback guarantee — the ungranted resource and the unregistered
  role each resolving to `none`, with the principal deliberately made a global
  `admin` to demonstrate that the global grant does not leak through. It then
  installs the adapter on `TomAuthorization`, contrasts the resolved states with
  the no-adapter `full` default, and covers `stateOf` and the unmodifiable
  registry snapshot. Every snippet in the new prose section is a shape this
  sample compiles and asserts, so the documentation cannot drift from the API
  without the sample failing.
- **The resource-key sample now exercises the control rather than the ACI.**
  Section four of `03_advanced_access_control_example.dart` built an
  `emailAccess` and a `salaryAccess` and then asserted on
  `principal.aci.resourceKeys.contains(...)` directly — demonstrating the
  collection, not the access control, and needing a file-level
  `unused_local_variable` waiver to do it. It now asks the controls
  themselves through `checkAccessibility(principal)`, the same call every other
  section makes, and ends by switching `globalSettingProtectionDefault` off and
  watching the principal who was just refused be let through — the one operand
  this control has that its siblings do not.
- **The `default`-named domain scope is now shown costing something.** Section
  seven of `01_scope_basics_example.dart` demonstrated the identity rule by
  constructing the chain by hand and asserting the resulting paths; it now also
  reaches it through `withScope`, which derives each parent from `current`
  rather than being handed one, so the rule visibly does not depend on how the
  chain was assembled. Two assertions replace what had been a claim in a
  comment: `app > default` must not render as `app`, because that is a
  different existing scope's path and the two would share a lookup key; and a
  root-level `default` must not render as the empty string, because that is how
  the module spells "no scope at all". Both fail under a by-name elision, which
  the earlier assertions also catch but only by their expected values.
- `example/samples/scope_ids/01_scope_basics_example.dart` gains an eighth
  section on unusable ids. It builds the `'a'` → `'b'` → `'c'` chain first, so
  the reader sees the path the dotted id used to be indistinguishable from
  before seeing the dotted id refused, and closes with an id full of spaces and
  slashes being *accepted* — the rule is about the separator, not about
  awkward characters.
- `example/samples/scheduling/` (memory substrate, declared jobs, the five
  schedule kinds, the at-least-once execution guarantee),
  `example/samples/result/` (envelope, error details, wire format),
  `example/samples/preferences/` (codec, contract), and
  `example/samples/observable/08_observable_enum.dart`.
- **Every sample now refuses to run without `--enable-asserts` (tcinc198).**
  The samples verify themselves with ~1800 `assert`s and nothing else, and
  `dart run` strips every one of them — so a flagless run printed its usual
  "✓ … passed" and exited 0 while checking nothing, which is worse than a
  crash because it is indistinguishable from success. Only the 37 entry points
  calling `bootstrapSamples()` were guarded; the other 77 were not, because the
  guard sat behind an import of the generated reflection registry that costs
  ~3 s of compile time and that they had no other reason to pay for. The check
  now lives in its own registry-free `example/sample_asserts.dart` as
  `requireAsserts()`, which every sample's `main()` calls (or reaches through
  `bootstrapSamples()`), and `tool/run_standalone_examples.sh` fails the sweep
  if a sample stops calling it.
- The reflection samples `01`–`06` document the command that runs them on their
  own (tcinc197); they were already standalone-runnable but said so nowhere.
- **`tool/run_standalone_examples.sh` now checks that every documented
  `dart run` command pointing into `example/` names a file that exists
  (tcinc261).** The
  sweep runs every sample, but it finds them with `find` rather than by reading
  the documentation, so it exercises the files that are there instead of the
  paths the headers claim are there. A command naming a moved, renamed or
  mistyped file was therefore invisible to the whole script and failed only for
  the reader who typed it. This was the shape of the original defect — a header
  advertising a command the file could not answer — and it is now the third
  static check, beside the `--enable-asserts` and `requireAsserts()` ones.
- `example/samples/scope_ids/03_scope_mixin_example.dart` gains a fifth section
  showing what the post-construction `initScope` pattern costs: until the call
  runs the instance is not yet a scope, and both installing it and passing it
  as a parent are refused. The example is where readers meet the pattern, so it
  is where the window it opens belongs.

### Documentation

- `Tom2FAChallenge.fromClaims` no longer promises it "never returns a
  half-built challenge". It does return one, on purpose: an unreadable
  `attemptsAllowed` claim falls back to `0` rather than to the constructor's
  `3`, so the challenge arrives already `isExhausted` and a malformed token
  cannot mint attempts. The dartdoc now says so and says why, and
  `Tom2FAPendingEnrolment.fromClaims` — which has always behaved identically —
  states the same rule instead of leaving it to the API mirror alone. The two
  mirror rows in `doc/api_reference/api_summary_security.md` were brought into
  line with each other. Behaviour is unchanged; the rule is now pinned by a
  test in each class, so the docs and the fallback can no longer drift apart.
- `doc/scope_ids/scope_ids.md` gains an *Ids may not contain the separator*
  section under Scope Paths, showing the two chains that used to render
  identically and why the path being an authorization prefix makes that a
  security defect rather than a cosmetic one. Best Practice 3 was rewritten
  from advice the module did not enforce into a statement of what it now
  guarantees, and the `StateError` references throughout were updated to
  `TomScopeException`. `doc/api_reference/api_summary_scope_ids.md` gains a
  `TomScopeException` entry with its three keys, and the `initScope` and
  `withScope` rows now state the id contract.
- `doc/scheduling/scheduling.md` (including the execution guarantee in full),
  `doc/result/result.md`, `doc/preferences/preferences.md`, and the matching
  `doc/api_reference/api_summary_*.md` entries.
- `doc/scope_ids/scope_ids.md` no longer calls `runInScope` "a no-op wrapper"
  when the scope is already current. What is elided is the zone, not the call:
  the body runs and its result is returned on both branches. The old wording
  was one word away from saying the call does nothing, in a method almost
  always written as `scope.runInScope(() => …)` where the body is the point.
- `doc/scope_ids/scope_ids.md` documents the window between construction and
  `initScope` — which entry point refuses what, why the parent is checked at
  `initScope` rather than during the path walk, and the invariant the two
  checks buy: whatever `TomScope.current` returns is usable.
- **The acyclicity requirement `buildScopePath` relies on is now written down**
  — in its own dartdoc, in `initScope`'s, in `doc/scope_ids/scope_ids.md` and in
  the API summary. The walk up the parent chain is iterative and has no cycle
  guard, so a loop does not raise `StackOverflowError`: it spins silently,
  appending segments, until the heap is exhausted and the isolate dies. It is
  left unguarded because no scope built through this module can form a loop —
  `withScope` and the `TomScopeBase` constructor take a parent that already
  exists, and `initScope` refuses one that is not yet initialised and then
  writes the link once, so every parent is strictly older than its child and a
  chain that only moves backwards in time cannot return to itself. What the
  documentation adds is the part that argument does not cover: a hand-rolled
  `implements TomScope` supplies its own `parent` and carries the obligation
  itself.

## 1.1.15

### Added

- **Opt-in liveness supervision for `TomWorkerPool` (RCJ1).** A worker whose
  isolate dies (uncaught error, `Isolate.kill`, OOM) was previously neither
  detected nor replaced, and any command dispatched to it hung forever on its
  completer. `TomWorkerPool.withSize` now accepts an optional
  `healthCheckInterval` (default `null` = supervision off, existing behaviour
  unchanged) and `healthCheckTimeout`. When enabled, each worker is watched via
  `Isolate.addOnExitListener`: on an unexpected death every in-flight request is
  failed with a new `TomWorkerDiedException` (rather than re-dispatched — a
  command that already produced side effects must not run twice), and the pool
  respawns a replacement worker from its stored context to restore capacity. A
  periodic timer additionally pings **idle** workers to catch hangs that emit no
  exit signal; an unresponsive idle worker is force-killed, routing it through
  the same death/respawn path. `execute` on a closed pool now throws
  `TomWorkerException` instead of hanging. New `TomWorkerPool.isSupervised` /
  `workerCount` accessors, plus `TomWorker.superviseExit` / `ping` /
  `killUnresponsive`. Covered by tests that kill a worker isolate mid-command
  and assert recovery, and an example demonstrating recovery
  (`example/isolate_pooling/04_worker_pool_supervision_example.dart`). Closes
  the carve-out filed from RCK1.

## 1.1.14

### Added

- **Pluggable durable replay store for `TomRemoteLogOutput` (RCK9).** The
  replay queue's storage is now behind a `TomLogReplayStore` interface
  (`append` / `snapshot` / `oldest` / `removeOldest` / `trim` / `clear`). The
  default stays zero-config and entirely in process
  (`TomInMemoryLogReplayStore`, unchanged behaviour); a new file-backed
  `TomFileLogReplayStore` mirrors the queue to a JSON file on every mutation and
  reloads it on construction, so records buffered during an outage survive a
  process restart — the one edge the in-memory store cannot cover. Opt in by
  assigning `TomRemoteLogOutput.globalSettingReplayStore`; the existing
  `globalSettingReplayQueueMaxSize` gate/bound is unchanged. Record
  serialization lives in the file-store library (private
  `_encodeReplayRecord`/`_decodeReplayRecord`) so `TomRemoteLogMessage`'s
  reflected/bridged surface is untouched (no regen).
- Tests for the durable store: the full store contract on the file backend,
  persistence across a simulated restart (fresh instance at the same path
  reloads the queue), bounded trim persisting across a restart, and an
  end-to-end restart-during-outage recovery through `TomRemoteLogOutput`.
- Example 10 in `example/logging/04_isolate_and_remote_logging_example.dart`
  demonstrating the file-backed store surviving a simulated restart, assert-
  guarded under `--enable-asserts`.

### Changed

- `TomRemoteLogOutput`'s internal `_replayQueue` list is replaced by delegation
  through `globalSettingReplayStore`; `replayQueueLength` / `clearReplayQueue`
  and the enqueue/drain paths now route through the store. Default runtime
  behaviour is identical (in-memory, drop-oldest, oldest-first drain).

## 1.1.13

### Changed

- **`scope_ids/` per-module pass (RCK8).** Private-only DRY refactor with every
  public signature frozen. `TomScope.runInScope` and `TomScopeMixin.runInScope`
  had byte-identical bodies (the `identical(this, current)` no-op-zone check plus
  the `runZoned` install); the shared install policy now lives in one private
  top-level `_runScoped<T>(TomScope, body)` helper both delegate to, so a change
  to the scope-installation policy is a one-site edit. The per-arity
  `InScopeBuilder.wrapN`/`wrapNn` methods and the two trivial `getScopePath()`
  delegations (already routed through the shared `buildScopePath`) have no
  collapsible duplication and were left as-is.

### Added

- Example `example/scope_ids/03_scope_mixin_example.dart` (wired into the runner)
  covering the previously undemonstrated public surface: a custom class using
  `TomScopeMixin` directly (the real-world consumer pattern, as in the Flutter
  element providers), the custom instance participating fully as a scope
  (`current`, path, `runInScope`, `InScopeBuilder`), and the write-once
  `set id` / `set parent` setters — all assert-guarded under `--enable-asserts`.
- Tests for direct `TomScopeMixin` usage (custom mixin class + `initScope`,
  `runInScope`, `InScopeBuilder` integration) and the write-once identity
  setters. The `set id`/`set parent` setters are kept (not removed): they are
  registered by the tom_core_d4rt bridges for `TomScopeBase`.

## 1.1.12

### Changed

- **`little_things/` per-module pass (RCK7).** Private-only pass with every
  public signature frozen. The module was already DRY — the stack-trace frame
  processing shared by `tomGetStackTrace`/`tomGetStackTraceAsList`/
  `tomGetStackTraceAsTuple`/`tomPrintStackTrace` had already been extracted into
  the private `_processStackFrames` helper — so there was no further genuine
  duplication to remove.
- Removed two stale investigation `TODO` comments above the stack-trace
  utilities (design musings about `StackTrace.current` usage and the frame
  folding). The folding is deliberate and covered by tests; the comments were
  noise.

### Added

- Example `example/little_things/03_formatting_and_exceptions_example.dart`
  covering the previously undemonstrated public surface: UTC offset formatting
  (`convertMinutesToUtcOffset`), a truly-awaited `runChecked` (success and error
  paths), `tomPrintStackTrace`, `TomException.printStackTrace()`, auto-logging
  (`autoLog`), `serverCallError`, and `logRepresentation`. The runner
  (`00_run_all_examples.dart`) is now async and awaits it.
- Tests for `TomException.newField` (default-null and set/get), closing the last
  untested public member. `newField` is kept (not removed): it is referenced by
  generated reflection and the tom_core_server D4rt bridges (`LoginException`).

## 1.1.11

### Changed

- **`json/` per-module pass (RCK6).** Private-only DRY refactor of
  `map_merge_and_process.dart` with every public signature frozen. Two genuine,
  behaviour-preserving deduplications:
  - `getPathFromTree` and `getObjectFromTree` shared an identical dot-path walk
    (with identical resolution/throw messages), differing only in how they
    handle a terminal non-map value. `getPathFromTree` now delegates the walk to
    `getObjectFromTree` and only wraps the resolved value under `name` when it is
    not already a subtree — the warn/throw behaviour is unchanged.
  - `makeCleanJsonMap` and `_cleanList` repeated the same JSON-type dispatch
    (scalars pass through, maps/lists recurse, everything else is dropped). That
    dispatch now lives in one private `_cleanJsonValue(Object?)` helper both call.
- Removed a stale `TODO` on the `json/` library directive; its intent — showing
  configuration resolution via `traverseAndProcess`/`traverseAndCreate` — is now
  covered by the new example.

### Added

- **`json/` example + test coverage scaled to the full public API.** New
  `example/json/03_json_config_resolution_example.dart` demonstrates
  `substituteEnvVars`, `traverseAndCreate`, `processTree` (profile-based
  reference injection) and the `TomJsonSerializable` contract — the members that
  previously had no executable example. Added a `TomJsonSerializable` test group
  (round-trip, `makeCleanJsonMap` interop, nullable values), taking the kernel
  suite to 1695 tests.

## 1.1.10

### Changed

- **`shutdown_cleanup/` per-module pass (RCK5).** Private-only DRY refactor of
  `tom_shutdown_cleanup.dart` with every public signature frozen. Two genuine,
  behaviour-preserving deduplications:
  - `_executeCleanup` held three near-identical try/catch loops (over
    `_signalHandlers`, `_closables`, `_disposables`) that each isolated one
    callout and printed `Failed to call <noun> $item` when not `silent`. The
    per-entry isolate/report policy is now owned by a single private generic
    `_runPhase<T>(List<T> items, String label, void Function(T) action)`, and
    `_executeCleanup` is three one-line phase calls. A change to the isolation
    or diagnostic policy is now a one-site edit instead of three. The exact log
    wording (`Failed to call signalHandler/closable/disposable $item`) is
    preserved.
  - The constructor's two SIGHUP/SIGINT watcher registrations duplicated the
    exact `_signalSubscriptions.add(sig.watch().listen(_signalHandler))` body of
    `addSignal`; the constructor now calls `addSignal(...)`, so there is a
    single owner of how a signal is watched and how its subscription is retained
    for teardown (bug §53).

### Examples & Tests

- Added `example/shutdown_cleanup/02_shutdown_execution_example.dart`, wired into
  the module runner. The existing `01_*` example is descriptive and never
  actually triggers cleanup; the new example *executes* the runtime API end to
  end — phase order, once-only execution, fault isolation, `paused` (signal path
  skipped / manual path always runs), `silent`, `cancelAll`/`dispose` teardown,
  and `TomCloseAdaptor` resolving a custom-named teardown method via reflection —
  all guarded by `assert`s (run under `--enable-asserts`). Registered as a
  reflection entry point in `build.yaml`.
- Added a `test/shutdown_cleanup_test.dart` case pinning the manual-path
  contract: `performShutdown()` (the non-signal path) ignores `paused`, which
  was previously asserted only for the signal-driven path. Suite: 64 cases.

## 1.1.9

### Changed

- **`settings/` per-module pass (RCK4).** Audit of
  `settings_client_authorization.dart` (two serialization DTOs —
  `TomGetSettingsMessage`, `TomGetSettingsResult`). No genuine within-module
  duplication exists to extract: the classes are independent data holders and
  the constructor's `?? <T>{}` / `?? <T>[]` defaulting is idiomatic per-field
  initialization, not extractable logic. The one honest, signature-preserving
  cleanup: removed the dead `= ""` field initializers on `TomGetSettingsResult`'s
  eight nullable `String?` fields (`organization`, `process`, `application`,
  `country`, `language`, `clientCountry`, `clientLanguage`, `clientTimeZone`).
  Every one is an initializing formal (`this.x`) in the constructor, so the
  field-level `= ""` never took effect — the real default was already `null`
  (as the existing tests assert). The initializer was dead code that misled
  readers about the default; removing it changes no runtime behaviour and no
  public signature. `TomGetSettingsMessage.authorizationToken = ""` is
  deliberately left — it has no initializing formal, so its `= ""` is the live
  default (`''`). Constructor dartdoc corrected ("all string parameters default
  to null"). No consumer relied on a `""` default (verified across samples and
  tom_uam — they only write the fields), so no adaptation was needed.

### Examples & Tests

- No additions needed: `example/settings/01_client_authorization_example.dart`
  (15 scenarios) and `test/settings_test.dart` (72 cases) already cover the full
  public surface of both DTOs, including the null-default guard that pins the
  dead-initializer removal ("should create result with default null optional
  strings") and the reflection JSON round-trip. No reflection regen — field
  types and names unchanged. Suite: 1690 passing.

## 1.1.8

### Changed

- **`context/` per-module pass (RCK3).** Private-only DRY refactor of
  `execution_context.dart` with frozen public signatures. Two genuine
  duplications were extracted: (1) `runInContext` and `runInContextAsync` shared
  a byte-for-byte preamble that built the new `TomExecutionContext` + merged
  `TomZoneValues` and assembled the zone-values map — now a single file-private
  `_buildZoneValues`, so each run method is a one-line `runZoned` call and the
  superfluous `async` (no `await`) was dropped from `runInContextAsync`;
  (2) all nine `TomContextProviders` getters read the current zone's
  `TomPrincipal`, selected one field, and fell back to a default — that
  read-select-fallback now lives once in `_fromPrincipal`, each getter reduced to
  a one-line selector so a change to how the principal is resolved lands in one
  place.

### Examples

- **New `example/context/04_async_and_zonevalues_example.dart`** covering the
  surface examples 01–03 omit: `runInContextAsync` context propagation across an
  `await` boundary and through nested async runs (inherit-outer, inner-wins), and
  the full `TomZoneValues` mutation API (`addAll` chaining, `containsKey`,
  `remove`, `clear`) plus the `existingValues` merge constructor. Wired into
  `00_run_all_examples.dart` (now async); self-asserts under `--enable-asserts`.

### Tests

- Added the five missing principal-populated provider tests (`getProcess`,
  `getCountry`, `getTimezone`, `getClientLanguage`, `getClientCountry`) so each
  of the nine refactored one-line selectors is verified against a live principal,
  guarding against a mis-wired field selector. Suite: 1690 passing.

## 1.1.7

### Changed

- **`resources/` per-module pass (RCK2).** Private-only DRY refactor of
  `tom_resource_provider.dart` with frozen public signatures. Both providers
  resolved a key the same way — a dot-notation tree walk (`getObjectFromTree`)
  then a flat-key fallback — duplicated across eight accessor bodies
  (`TomTextResourceProvider.{exists, existsObject, getObject, getObjectOrNull,
  getText, getTextOrNull}` and `TomConfigResourceProvider.{exists, getText}`).
  That rule now lives once in two file-private helpers: `_resolveObjectOrNull`
  (any value type) backs the object family and `_resolveStringOrNull` (String
  only) backs the text family, each accessor reduced to a one-line expression
  differing solely in its missing-value fallback. The text/object split is kept
  deliberately: the text helper still consults the flat key when the tree walk
  lands on a non-String, so a literal dotted key resolves — a genuine semantic
  difference, not coincidental duplication.

### Examples

- **New `example/resources/03_app_singleton_example.dart`** covering the
  application-wide singleton surface that examples 01/02 omit: the static
  `loader` field, the loader-driven default constructor,
  `getAppResources`/`getAppConfig` lazy initialization, `setAppResourceProvider`/
  `setAppConfigProvider` replacement, singleton identity, and the independence of
  the text and config singletons. Wired into `00_run_all_examples.dart`;
  self-asserts under `--enable-asserts`.

### Tests

- **Added a `shared resolution contract` group to `test/resources_test.dart`**
  (98 → 102) pinning the extracted helpers: the flat-String fallback on a
  non-String tree hit (literal dotted key beside a nested value), object-family
  resolution at a hierarchical path, the object-vs-text divergence on a nested
  non-String, and config/text object-family parity.

## 1.1.6

### Changed

- **`isolate_pooling/` per-module pass (RCK1).** Private-only DRY refactor of
  `tom_worker.dart`: the two identical response-completion bodies (worker→creator
  and creator→worker) are now a single private `_completeFromResponse(completer,
  response)` helper that routes a `RemoteError` payload to `completeError` and any
  other payload to `complete`. Public signatures are unchanged. The stale
  `// TODO: add regular pings` note on `TomWorkerPool` is replaced by an
  explanatory comment; the liveness-supervision enhancement is tracked as quest
  todo **RCJ1**.

### Examples

- **New `example/isolate_pooling/03_creator_backchannel_example.dart`** covering
  the worker→creator back-channel that had zero example coverage:
  `TomWorker.canSendToCreator`, `executeInCreator` (request/response),
  `sendToCreator` (fire-and-forget into a creator-side `TomExecutor`), a custom
  `TomWorkerContext` with `initializeIsolate`/`initializeWorker` overrides, and
  error propagation as a `RemoteError`. Wired into `00_run_all_examples.dart`.
- **Fixed a latent bug** in `02_worker_pool_example.dart`: a missing `await` cast
  a `Future<Object?>` to `bool` and crashed the example under `--enable-asserts`.
  Also removed confusing `Future.value(pool.execute(...))` wrappers in favour of
  the plain `Future`s that `pool.execute` already returns.

### Tests

- **Scaled `test/isolate_pooling_test.dart`** (+5 tests) to the full public API:
  the base `TomCommand.execute` default (`"null"` sentinel), the
  `startRemoteIsolate` null-send-port guard (the last untested documented
  exception key), `canSendToCreator`/`sendToCreator` observed from inside a
  worker, an end-to-end `sendExecutorToIsolate` assertion, and the
  creator-thrown-exception-as-value branch of the shared response-completion
  helper.

## 1.1.5

### Added

- **`TomRemoteLogOutput` delivery resilience (RCI2).** The remote log output now
  never silently drops a record. A send is treated as *failed* both when the
  transport throws **and** when the server answers with an error result
  (`TomServerCallError.hasError`) — the previously `print()`-only returned-error
  path now routes through the fallback like the thrown path. Four new static
  knobs make resilience opt-in and predictable-by-default:
  - `globalSettingMaxSendRetries` (default `0`) — additional attempts after the
    first failure.
  - `globalSettingRetryBackoff` (default `Duration.zero`) — linear backoff; the
    wait before retry *k* is `backoff × k`.
  - `globalSettingReplayQueueMaxSize` (default `0`, disabled) — bounded
    in-memory replay queue; records that exhaust their retries are buffered and
    re-sent oldest-first on the next successful transmission, dropping the
    oldest on overflow.
  - `replayQueueLength` (read-only) and `clearReplayQueue()` — diagnostics and a
    way to discard records queued for a previous endpoint when reconfiguring.

  The defaults preserve the prior single-attempt-then-fallback behaviour, so no
  configuration is required and the path stays testable without a live server.

### Examples

- **Extended `example/logging/04_isolate_and_remote_logging_example.dart`** with
  an Example 9 that drives the resilience surface offline via a scripted
  endpoint: a flaky endpoint recovered by retry, a full outage buffering a
  record, and a recovery that drains the buffer oldest-first before the
  triggering record. Self-asserts under `--enable-asserts`.

### Tests

- **Added a `TomRemoteLogOutput` `resilience` group to `test/logging_test.dart`**
  (kernel suite 1667 → 1676): default knobs; returned-error routed to fallback;
  retry recovers a transient failure and gives up after the budget; backoff
  actually waits between retries; replay queue buffers a failed record and
  drains it in order on the next send, drops the oldest on overflow, and stops
  draining while the endpoint is still down. The `_MockLogEndpoint` test double
  gained a per-call outcome script (`ok` / throw / returned-error) and an
  `accepted` log for asserting drain ordering.

## 1.1.4

### Refactor

- **`http_connection/` per-module pass (RCI1).** Internal DRY refactor with
  frozen public signatures. The six `TomServerCall` response accessors
  (`getResponseHeaders`, `getResponseStatusCode`, `getResponseContentLength`,
  `getResponseIsRedirect`, `getResponseReasonPhrase`, `getResponseRequest`) each
  repeated the same "throw if nothing was sent yet, then await the response"
  guard with only the error key/message differing; extracted that into a private
  `_requireSentResponse(key, message)` helper so every accessor states only its
  own wording. The duplicated read-once guard in `read()`/`readAsString()` moved
  into a private `_ensureNotYetRead(key)` helper. `read()` keeps its original
  `_read = true`-before-await ordering to preserve concurrent-read semantics.

### Examples

- **Added `example/http_connection/04_auth_retry_example.dart`** exercising the
  real framework auth-retry coordinator — `tomRunWithAuthRetry`,
  `TomAuthRefresher`, `TomAuthRetryPolicy` (default, custom, and bean-resolved
  `active`), and `TomAuthExpiredException` — across the happy path, expiry
  recovery, declined refresh, persistent-expiry throw, non-expiry passthrough,
  and a custom multi-retry policy. Wired into `00_run_all_examples.dart` (now
  `async`). This closes the gap left by `03_retry_policies_example.dart`, which
  only demonstrated a hand-rolled pattern, not the kernel API.

### Tests

- **Added auth-retry coverage to `test/http_connection_test.dart`** (previously
  zero tests for `auth_retry.dart`): `TomAuthRetryPolicy` (defaults, custom
  tuning, `active` bean resolution and reset fallback), `TomAuthExpiredException`
  (status/key/message), and `tomRunWithAuthRetry` (no-refresh passthrough,
  one-refresh recovery, declined refresh, persistent-expiry throw with and
  without `errorKeyOf`, non-expiry passthrough, refresher error propagation,
  explicit-policy budget, active-bean policy resolution).

## 1.1.3

### Refactor

- **`logging/` per-module pass (RCH1).** Internal DRY refactor with frozen
  public signatures. `TomIsolateLogOutput.output` and
  `TomCreatorLogOutput.output` built the *identical* `TomInterIsolateLogMessage`
  record before dispatch (only the destination differs — worker pool vs. back
  to the creator); extracted that byte-for-byte construction into a private
  `_interIsolateMessage(...)` helper so the record's shape lives in one place.
  The two `output` bodies stay separate: their dispatch/fallback logic is a
  genuinely different concern, not coincidental duplication. Replaced the stale
  `// TODO: add error handling` note inside `TomRemoteLogOutput.output` with an
  explanatory comment; the resilience enhancement it hinted at (retry-with-
  backoff, bounded replay queue) is filed as **RCI2** in the tom_core quest
  todos rather than attempted inline in a signature-frozen pass.

### Examples

- **Added `example/logging/04_isolate_and_remote_logging_example.dart`** covering
  the kernel-owned isolate/remote logging surface, which previously had no
  runnable example (examples `01`–`03` only exercise the `tom_basics`
  `TomLogger` foundation). It drives — connection-free (zero-size worker pools,
  no configured endpoint) — `TomInterIsolateLogMessage`, `TomLoggingExecutor`,
  `TomIsolateLogOutput` (level gating), `TomCreatorLogOutput` (off-isolate
  fallback + gating), `TomLoggingWorkerContext`/`TomIsolateLogging`,
  `TomRemoteLogMessage`/`TomRemoteLogResult`/`TomLoggingContext`,
  `TomRemoteLogOutput` (no-endpoint fallback), and `TomRemoteLogServer`
  (receive, sender-prefixing, CWE-117 control-character sanitization). Wired
  into `00_run_all_examples.dart` (now async). Self-asserts under
  `dart run --enable-asserts`.

### Tests

- **Closed the `TomLoggingWorkerContext` test gap.** Added a group asserting it
  is a `TomWorkerContext` and that `initializeIsolate()` registers a
  `TomLoggingExecutor` on `TomWorker.executors` and returns `true` (with the
  global executor list snapshotted and restored). Kernel suite 1650 → 1652,
  all green; `dart analyze` clean.

## 1.1.2

### Refactor

- **`security/` per-module pass (RCG1).** Internal DRY refactor with frozen
  public signatures: `TomRoleAccess` and `TomGroupAccess` had byte-for-byte
  identical `checkAccessibility` bodies — extracted the shared rule into a
  private `_principalAciContainsAny` helper (each class supplies its ACI
  collection selector). `TomEntitlementAccess` is deliberately left separate:
  regex matching is a genuinely different rule, not coincidental duplication.

### Examples

- **Added `example/security/04_graded_access_example.dart`** covering the
  four-state `TomGradedAccess` / `TomAuthState` surface, which previously had no
  runnable example: full/read/disabled/none resolution, the `read`→`full` and
  `disabled`→`read` defaulting, `checkAccessibility`'s collapse to
  `showsContent`, the `TomAuthState` predicates, and the binary→four-state
  default bridge. Wired into `00_run_all_examples.dart`. Self-asserts under
  `dart run --enable-asserts`.

### Fixes

- **Fixed a latent stale assertion in `02_access_control_example.dart`.** Its
  Example-6 group assertions documented a since-fixed constructor bug ("groups
  populated from resourceKeys"); the `TomAccessControlInformation` constructor
  now correctly populates `_groups`, so the assertions failed under
  `--enable-asserts`. Corrected them to the real group-membership outcomes and
  removed the obsolete bug note.

### Tests

- **`security_test.dart`** +3 tests pinning the extracted helper's contract
  (empty candidate list denies; Role/Group parity for an empty ACI collection).
  Suite 1647 → 1650, all green (serial).

## 1.1.1

### Documentation

- **Added a per-module API reference under `doc/api_reference/`.** Fifteen
  hand-written summaries — one per barrel-exported `tombase` module
  (`beanlocator`, `context`, `http_connection`, `isolate_pooling`, `json`,
  `little_things`, `logging`, `observable`, `reflection`, `resources`,
  `scope_ids`, `security`, `settings`, `shutdown_cleanup`, `timezoned`) — plus a
  cross-module `api_summary_index.md`. Each summary follows the standard format
  (overview with source paths, class hierarchy, per-class constructors and
  static/instance members, enums, top-level functions/constants; public members
  only). Verified against the actual public declarations and the package barrel.
  This restores documentation symmetry with `tom_core_server`,
  `tom_core_flutter`, and `tom_core_d4rt`, which already carry `doc/api_reference/`
  sets, and linked the reference from the README. No source or behaviour change.

## 1.1.0

### Added

- **Scope IDs module** (`scope_ids`): hierarchical, zone-propagated `TomScope`
  identifiers (`TomScope`, `TomScopeBase`, `TomScopeMixin`) for namespacing
  resource and authorization lookups, plus `InScopeBuilder` for restoring a
  captured scope inside deferred framework callbacks.
- **UI authorization** (`security/tom_authorization.dart`): the four-state
  `TomAuthState` model with `narrow`/`widen` algebra, `TomAuthorizable`,
  `TomAuthorizationGroup` (with `AuthGroupMode`), the global `TomAuthorization`
  singleton and `TomAuthorizationAdapter`, `TomAuthorizer` (with
  `TomAuthorizerStrategy`), and `TomUIStateController`.
- **Observable**: `TomList.resetWith` for atomic batch replacement with a single
  notification, and `TomListLifecycleListener` (`onBeforeClear` / `onAfterReset`)
  for tearing down and recreating element-tied state around a reset.
- **Resources**: null-returning and object accessors on
  `TomTextResourceProvider` — `getTextOrNull`, `getObject`, `getObjectOrNull`,
  and `existsObject`.

### Changed

- Observable notification now snapshots its listener/observer lists before
  iterating, guarding against concurrent modification when a callback mutates
  the list during a reset.

### Documentation

- Customized the package README and updated module docs, executable examples,
  and tests for the modules above.

## 1.0.0

- Initial version.
