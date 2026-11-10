# Privacy Module

The data-protection operations a deployment owes the people whose data it holds:
**erasing** a person, **exporting** what is held about them, keeping rows **no
longer than declared**, and making the person's values in the append-only audit
trail unreadable once they are erased — **crypto-shredding**, so the trail's
hash chain is never rewritten and still verifies.

An entity says what it holds about whom with three annotations —
`@TomDataSubject` on the column naming the person, `@TomPersonal` on the
columns holding their data, `@TomRetention` on the class — and the application
registers the repositories of those entities with `TomPrivacy`. Every operation
then runs through the repositories, so it is the ordinary write path that
deletes and updates: each row it touches is audited, its files are cascaded,
encrypted columns stay encrypted and a tenant table stays in its tenant.

## Table of Contents

- [Overview](#overview)
- [The Data Subject](#the-data-subject)
- [Declaring Personal Data](#declaring-personal-data)
  - [The subject field](#the-subject-field)
  - [Personal fields](#personal-fields)
  - [Retention](#retention)
  - [What a declaration may not say](#what-a-declaration-may-not-say)
- [Registering Entities](#registering-entities)
- [Erasure](#erasure)
  - [Delete, anonymize, unlink](#delete-anonymize-unlink)
  - [The order an erasure visits rows in](#the-order-an-erasure-visits-rows-in)
  - [Row scopes are bypassed, so the caller gates](#row-scopes-are-bypassed-so-the-caller-gates)
  - [The erasure report](#the-erasure-report)
- [Subject-Access Export](#subject-access-export)
  - [Sections, and each row once](#sections-and-each-row-once)
  - [Formats](#formats)
  - [What the export holds](#what-the-export-holds)
- [Retention Runs](#retention-runs)
  - [Policies](#policies)
  - [A run, a batch at a time](#a-run-a-batch-at-a-time)
  - [The retention job](#the-retention-job)
- [Crypto-Shredding in the Audit Trail](#crypto-shredding-in-the-audit-trail)
  - [Sealing](#sealing)
  - [The subject keys](#the-subject-keys)
  - [Shredding a key](#shredding-a-key)
  - [Rotating a key-encryption key](#rotating-a-key-encryption-key)
  - [A legal hold](#a-legal-hold)
  - [Revealing a record](#revealing-a-record)
  - [The chain stays verifiable](#the-chain-stays-verifiable)
- [What Stays As It Is](#what-stays-as-it-is)
- [Configuration](#configuration)
- [Tenancy](#tenancy)
- [Framework Entities That Declare Subjects](#framework-entities-that-declare-subjects)
- [Error Keys](#error-keys)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDataSubject` | class | Marks the `int` or `String` field holding the id of the person a row belongs to or names, and what erasing them does to the row |
| `TomErasure` | enum | What erasing a subject does to a row: `delete`, `anonymize`, `unlink` |
| `TomPersonal` | class | Marks a field holding personal data about the subject of a `@TomDataSubject` field of the same entity: exported, cleared on erasure, sealed in the audit trail |
| `TomRetention` | class | Declares how long an entity's rows are kept, measured from a `DateTime` field, and whether an expired row is deleted or anonymized |
| `TomPersonalDataModel` | class | An entity's declarations, resolved once and checked: its subject fields, personal fields, retention and primary key |
| `TomSubjectField` | class | One resolved `@TomDataSubject` field |
| `TomPersonalField` | class | One resolved `@TomPersonal` field, with the subject field it belongs to |
| `TomPrivacy` | abstract final class | The isolate's privacy operations: registration, erasure, subject-access export, retention, the subject keys and revealing an audit record. Statics only |
| `TomErasureReport` | class | What an erasure did: per entity, and whether the subject's audit key was shredded |
| `TomErasureCount` | class | What an erasure did to one entity: rows deleted, anonymized, unlinked |
| `TomSubjectAccess` | class | A subject-access export: one tabular section per entity, and the rows per entity |
| `TomRetentionPolicy` | class | One retention rule: an entity, the field its age is measured from, how long a row is kept, what happens to it then |
| `TomRetentionCount` | class | What one policy of a retention run did: its cutoff and the rows it affected |
| `TomSubjectKeys` | class | Crypto-shredding: seals a personal value under a key per subject, opens it while the key exists, shreds the key |
| `TomSubjectKeyStore` | abstract class | Where the wrapped subject keys are kept, in the tenant in context |
| `TomMemorySubjectKeyStore` | class | Subject keys in memory, for tests |
| `TomSqlSubjectKeyStore` | class | Subject keys in the `tom_subject_key` table of a SQL data source, resolved by name per call |
| `TomSubjectKeyRecord` | class | One subject key as a store holds it: wrapped, with the key-encryption key that wraps it |
| `TomSubjectKeyRow` | class | One row of the subject-key table, as `TomSqlSubjectKeyStore` reads it |
| `TomPrivacyException` | class | A privacy declaration or operation that cannot proceed, keyed `privacy.*` |
| `subjectKeyTable` / `subjectKeyTableDdl` | function | The subject-key table's one declaration, and the DDL derived from it |
| `defaultSubjectKeyTable` / `tomRetentionJobName` | const String | `tom_subject_key`, the subject-key table's default name / `privacy.retention`, the retention job's default name |

## The Data Subject

The GDPR's unit is the **data subject**: the person the data is about. A
database does not hold people; it holds rows, and a row is *about* someone
because one of its columns holds that someone's id — an order's `customer_id`,
a comment's `author_id`, a task's `assignee_id`. The module makes that column
the declaration: the field marked `@TomDataSubject` names the subject, and every
operation finds a person's rows by looking for their id in those fields.

**One id space.** Every `@TomDataSubject` field of every registered entity is
read as holding ids from the same space — a user id, as a rule — which is what
lets one call reach all of a person's rows. A subject given as `'7'` binds as `7`
to an `int` column (`TomSubjectField.toColumnValue`), and that is the only
translation there is: an erasure does not map one id space onto another. A
deployment whose entities name people by different keys (a user id here, a
username there) registers only the entities of one space, or erases once per
key.

A row may name several subjects — an item's assignee and its reporter, a
delegation's delegator and delegate — and each `@TomDataSubject` field decides
for itself what erasing its subject does to the row.

## Declaring Personal Data

### The subject field

```dart
@TomDataSubject(onErasure: TomErasure.anonymize)
@TomDbColumn(columnName: 'author_id')
int? authorId;
```

The field is an `int` or `String` column, not encrypted; its value is the
subject's id. `onErasure` (default `TomErasure.delete`) is what erasing that
subject does to the row — see [Delete, anonymize,
unlink](#delete-anonymize-unlink). A field set to `null` names no one, and an
erasure that anonymizes or unlinks the row sets it to `null`, so the column must
accept `NULL` for those two.

### Personal fields

```dart
@TomPersonal(subject: 'authorId', replacement: '[removed]')
@TomDbColumn(columnName: 'body')
String? body;
```

A `@TomPersonal` field holds data about the subject of one `@TomDataSubject`
field of the same entity — `subject` names that field by its declared name, and
can be left out when the entity has exactly one. A personal field is:

- **exported** with the rest of the row in a subject-access export (every mapped
  column is; the annotation adds nothing there);
- **cleared** when its subject is erased with `anonymize`, or when a retention
  run anonymizes the row: set to `replacement`, or to `NULL` when none is given
  — `replacement` exists for a column that may not be `NULL`;
- **sealed in the audit trail** under its subject's key, so erasing the subject
  makes its before and after values unreadable there — see
  [Crypto-Shredding in the Audit Trail](#crypto-shredding-in-the-audit-trail).

A row's own subject field needs no `@TomPersonal`: it is the id, cleared by
anonymize and unlink alike.

### Retention

```dart
@TomRetention(field: 'createdAt', days: 365, action: TomErasure.anonymize)
@TomDbTable(datasource: 'main', table: 'post', primaryKeyFields: ['id'])
class Post { ... }
```

On the class: a row whose `field` — a `DateTime` column, by declared name — lies
more than `days` in the past is deleted (`action: TomErasure.delete`, the
default) or anonymized (`TomErasure.anonymize`: every subject field and its
personal fields cleared) by a [retention run](#retention-runs).
`TomErasure.unlink` reads as anonymize here. Declaring it changes nothing by
itself; a retention run applies it.

### What a declaration may not say

`TomPersonalDataModel.of(entity)` resolves an entity's declarations once and
refuses one the operations could not carry out. `TomPrivacy.register` resolves
it at once, so the refusal arrives at startup rather than in the middle of an
erasure:

| Key | Refused declaration |
| --- | ------------------- |
| `privacy.model.subject_type` | A `@TomDataSubject` field that is not an `int` or `String`, or is `@TomEncrypted` — an id is looked up by value, and an encrypted column cannot be. |
| `privacy.model.subject_unknown` | `@TomPersonal(subject:)` names a field that is not a `@TomDataSubject` field of the entity. |
| `privacy.model.subject_ambiguous` | A `@TomPersonal` field names no subject while the entity has more than one `@TomDataSubject` field, or none. |
| `privacy.model.structural_personal` | A `@TomPersonal` field that is a key, version, reference or file column: those cannot be cleared. |
| `privacy.model.retention_field` | `@TomRetention` names a field that is not a `DateTime` column of the entity, or keeps rows for less than a day. |
| `privacy.model.retention_anonymize` | `@TomRetention` anonymizes an entity that has no `@TomDataSubject` field to clear. |

An entity without any of the three annotations resolves to an empty model
(`TomPersonalDataModel.isEmpty`): it can be registered, and no operation does
anything to it.

## Registering Entities

```dart
TomPrivacy.register(workspaceRepository);
TomPrivacy.register(commentRepository);
TomPrivacy.register(userRepository);
```

`TomPrivacy.register(repository)` enrols the repository's entity in erasure,
export and retention. Registration is per isolate and per entity type:
registering an entity again replaces its repository. **The order of
registration is the order the operations visit the entities in**, and it
matters for erasure — see [The order an erasure visits rows
in](#the-order-an-erasure-visits-rows-in). `TomPrivacy.entities` answers the
registered types in that order; `reset()` forgets the registrations and the
subject keys (for tests).

Only registered entities are reached. An entity whose rows name people but
whose repository is never registered is invisible to an erasure and missing from
an export, and nothing reports it: registration is the deployment's census of
where personal data lives.

## Erasure

```dart
final report = await TomPrivacy.erase(7);
// TomErasureReport(7: Member: 1 deleted, 0 anonymized, 0 unlinked; Post: …; audit key shredded)
```

`erase(subject)` visits every registered entity with a `@TomDataSubject`
field — or the entities given in `entities:`, in that order — and, for each
subject field in declaration order, finds the rows naming the subject (`find by
<field> = :subject`) and applies the field's `TomErasure` to each. Then it
shreds the subject's audit key, unless `keepAuditKeys` is set, and records the
erasure in the audit trail.

### Delete, anonymize, unlink

| `TomErasure` | The row | Through |
| ------------ | ------- | ------- |
| `delete` | Deleted — it is the subject's own: their account, their membership, their workspace. | `repository.delete(row)` |
| `anonymize` | Kept, no longer naming the subject: the subject field is set to `NULL`, and so is every `@TomPersonal` field belonging to it (or its `replacement`). A comment kept for its thread, its author and its text removed. | `repository.save(row)` |
| `unlink` | Kept, only the subject field set to `NULL`. The assignee of a task in someone else's workspace: the task is not theirs, only the link to them is. | `repository.save(row)` |

Because the work goes through the repository, its write path runs in full: a
delete removes the blobs the row's `@TomFileReference` columns name, a versioned
entity's version is checked and advanced, an encrypted column is written
encrypted, a tenant table's (`@TomTenantTable`) rows are only those of the
tenant in context, and **every row deleted or updated is audited by its repository** —
the trail shows each row the erasure touched, under the caller's actor.

An erasure opens no transaction of its own; each repository write commits the
way that repository's writes do — or joins a transaction the caller runs it in.
One that fails half-way leaves the rows it reached erased, and running it again
finishes the job: a row already erased no longer names the subject, so it is not
found a second time.

### The order an erasure visits rows in

Entities are visited in registration order, and rows the database removes on its
own are rows no repository sees. Register an entity whose deletion cascades
first: in the advanced samples a user's workspaces are deleted before anything
else, and the schema's `ON DELETE CASCADE` takes their projects, lists, items
and comments with them — those rows are not visited again, and are neither
counted nor audited by a repository. Register the subject's own account last, so
the rows that refer to it are dealt with while it still exists.

### Row scopes are bypassed, so the caller gates

`erase`, `subjectAccess` and `applyRetention` run inside
`TomDataScope.runUnscoped`: erasing a person must reach every row about them,
not the rows the caller happens to be allowed to see, and an export that showed
only some of them would not be the export the law requires. **The operations
therefore check no permission of their own.** Who may ask for an erasure or an
export — the person themselves, a data-protection officer, an administrator — is
the caller's decision, and an endpoint that offers either gates it. A
tenant table (`@TomTenantTable`) stays within the tenant in context all the
same; the bypass is of row scopes, not of tenancy.

### The erasure report

`erase` answers a `TomErasureReport`: the subject, one `TomErasureCount` per
visited entity with a subject field (`deleted`, `anonymized`, `unlinked`;
`countOf(type)` finds one) and `auditKeyShredded` — `false` under
`keepAuditKeys`, or when the subject had no key. The erasure itself is recorded
in the audit trail: action `delete`, target `privacy.erasure`
(`TomPrivacy.erasureTarget`), the subject as the target key, and the non-empty
counts and the key's fate as the detail. So the trail says that a person was
erased, when and by whom, without saying anything more about them.

## Subject-Access Export

```dart
final access = await TomPrivacy.subjectAccess(8);
final xlsx = await TomPrivacy.exportSubject(8);              // XLSX bytes
final csv = await TomPrivacy.exportSubject(8, format: 'csv');
```

### Sections, and each row once

`subjectAccess(subject)` collects, for every registered entity with a
`@TomDataSubject` field (or those in `entities:`), the rows any of its subject
fields ties to the subject, and builds a `TomTabularResult` titled `Personal
data of <subject>` with one section per entity, titled by the type's name. A row
naming the subject in two fields — a post they wrote and edited — appears once:
rows are kept by primary key. An entity holding nothing about them still has its
section, empty, and `rowCounts` says `0` for it, so the export shows what was
looked at as well as what was found. A registration without a single subject
field to export is refused with `privacy.not_registered`.

The export is audited: action `read`, target `privacy.subject_access`
(`TomPrivacy.subjectAccessTarget`), the subject as the target key and the rows
per entity as the detail.

### Formats

`exportSubject(subject, format:)` renders the result through the export module's
format registry — `xlsx` by default, `csv` or `pdf`, or any format of a
`TomExportFormats` passed as `formats:` — and answers the bytes. Each call is a
`subjectAccess`, audited as one. An unknown format raises the export module's
`export.format.unknown`. See [export.md](export.md) for the renderers and their
limits (an XLSX sheet per section, the PDF built in memory).

### What the export holds

Each section's columns are derived from the entity with
`TomTabularSection.ofEntities`: every `@TomDbColumn` field, by declared name, in
declaration order. Two kinds of column are left out, as in every export of
entities — a field named in `@TomAudited(redact: …)`, and a `@TomFileReference`
column, which holds a storage key rather than content (see [export.md § Two
Kinds of Column That Are Not
Exported](export.md#two-kinds-of-column-that-are-not-exported)). Files the
subject uploaded are therefore not part of the export; a deployment owing them
delivers them alongside.

**Encrypted columns are exported decrypted.** The rows are read through the
repository, which decrypts `@TomEncrypted` columns, and the export is the
subject's own data: handing them their e-mail address as ciphertext would answer
the request with nothing.

## Retention Runs

### Policies

A `TomRetentionPolicy` is one rule: `entity`, the `DateTime` `field` its age is
measured from, `keep` — how long a row is kept — and `action`, `delete` or
`anonymize`. `TomRetentionPolicy.declared()` builds one per registered entity
that declares `@TomRetention`, in registration order, and is what a run applies
when it is given none. A policy written in code covers an entity that declares
nothing, or keeps rows for a period a deployment sets rather than the entity —
its entity must be registered all the same (`privacy.not_registered`).

### A run, a batch at a time

```dart
final results = await TomPrivacy.applyRetention();
// [TomRetentionPolicy(Post.createdAt, 30 days, anonymize): 12, …]
```

`applyRetention(policies:, now:)` computes each policy's cutoff — `now` (the
clock by default) minus `keep` — and reads the rows older than it (`find by
<field> < :cutoff`) through the repository, `TomPrivacy.retentionBatchSize`
(200) rows per statement in primary-key order. A delete always reads the first
page, because the deleted rows leave the result; an anonymizing run pages on,
because anonymized rows stay. A row anonymized already is passed over and not
counted, so a second run over the same rows affects nothing. Each row goes
through the repository exactly as in an erasure — audited, files cascaded —
and each policy's run is recorded once: action `delete` or `update`, target
`privacy.retention` (`TomPrivacy.retentionTarget`), the entity as the target
key and `<n> rows older than <cutoff>` as the detail. The answer is one
`TomRetentionCount` per policy: the policy, the cutoff and the rows affected.

### The retention job

```dart
final scheduler = TomScheduler(
  store: jobs,
  dispatcher: const TomInlineJobDispatcher(),
);
scheduler.register(
  TomPrivacy.retentionJob(schedule: TomCronSchedule('30 2 * * *')),
);
```

`retentionJob(schedule:)` is a scheduler job named `privacy.retention`
(`tomRetentionJobName`) unless given another name, planned — on a clock-driven
schedule — once per active tenant and once for the system (`TomJobTenants`; see
[Tenancy](#tenancy) below), with a one-hour timeout and recovery requested — a run deletes what is expired at its window, and running it
again finds nothing more to do. Each run applies the policies — the declared
ones unless `policies:` is given — at the run's **window instant**, so a run
recovered later cuts off where it was scheduled to, and answers the counts as
its result. The job uses the isolate's registrations, so it is registered on a
scheduler with a `TomInlineJobDispatcher`; a worker isolate has none.

## Crypto-Shredding in the Audit Trail

The audit trail is append-only and hash-chained: an entry cannot be changed
without the chain showing it, which is the point of it (see
[audit.md](audit.md#tamper-evidence)). Erasing a person's data from it by
rewriting their entries would break the chain or require rebuilding it — and a
rebuilt chain proves nothing. So their values are never written in the clear in
the first place.

### Sealing

When subject keys are installed, a repository's audit record of a create, an
update or a delete seals the before and after values of every `@TomPersonal`
field under the key of the subject the row names, and the chain hashes the
sealed text. The repository passes `TomAuditTrail.recordMutation` the subjects
alongside the values (`beforeSubjects` / `afterSubjects`, field to subject id,
from `TomPersonalDataModel.sealingSubjects`), and the trail calls
`TomAuditTrail.personalValueSealer`, which `TomPrivacy.installSubjectKeys` sets
to `TomSubjectKeys.seal`. Left out of sealing are:

- a value that is `null`, or redacted already — `***` by `@TomAudited(redact:)`,
  or `[encrypted]` for an encrypted column, whose value the trail never held;
- a personal field whose subject field is `null` in the row — there is no one
  to seal it for. An anonymized row's after image is such a row: its values are
  the replacements, which are no one's data. (An empty string is an id like any
  other: a non-nullable `String` subject field left `''` seals for the subject
  `''`.)

A sealed value reads `tomsubj:v1:<subject>:<sealed>`: the subject's id
(base64url) and the value, JSON-encoded and sealed with AES-256-GCM
(`TomAesGcm`, the field-encryption cipher), the subject and the field name
authenticated with it. A value moved to another field does not open
(`privacy.seal.invalid`). `TomSubjectKeys.isSealed(value)` and
`TomSubjectKeys.subjectOf(value)` read the envelope without a key.

Without subject keys installed, `personalValueSealer` is `null` and personal
values are recorded as they are — an erasure cannot reach them in the trail.
With them installed, a value that cannot be sealed fails the audit, and the
trail is fail-closed (see [audit.md](audit.md#failure-behaviour)): the write it
was auditing fails rather than recording the value in the clear.

### The subject keys

```dart
TomPrivacy.installSubjectKeys(
  TomSubjectKeys(store: TomSqlSubjectKeyStore('main')),
);
```

A subject's key is 32 random bytes, created the first time a value is sealed
for them and kept in a `TomSubjectKeyStore` **wrapped**, like a data key of
field encryption: encrypted under a key-encryption key that never touches the
database, the wrapping bound to the subject's id. The table never holds a usable
key, so a database dump opens nothing.

`TomSubjectKeys(store:, keys:)` wraps under `keys` — the first wraps new keys,
every one may unwrap — and, without `keys`, under the key-encryption keys of the
installed field-encryption keyring (`TomFieldEncryption.keyring`), read when a
key is needed. A deployment therefore configures `fieldEncryption` alongside
`privacy`; with neither `keys` nor a keyring, sealing raises
`privacy.no_subject_keys`. A key wrapped under a key-encryption key that is no
longer given raises `field_encryption.unknown_kek`. Each record notes the
key-encryption key it is wrapped under (`TomSubjectKeyRecord.kekId`).

| Column | Holds |
| ------ | ----- |
| `tenant` | The tenant in context, `''` outside tenancy |
| `subject_id` | The subject's id, as text |
| `kek_id` | The key-encryption key the key is wrapped under |
| `wrapped_key` | The wrapped key, base64 |
| `created_at` | When the key was created |

The primary key is `(tenant, subject_id)`. `TomSqlSubjectKeyStore('main')`
resolves the data source by name on every call and creates the table on first
use in each data source; with `createSchema: false` the deployment applies the
reference migration
`example/privacy/migrations/tenant/default/main/[1]-create_tom_subject_key.sql` (or its
`migrations_postgresql` form). `TomSqlSubjectKeyStore.over(datasource)` binds
one data source once; an unregistered name raises `privacy.no_datasource`.
`TomMemorySubjectKeyStore` keeps them in memory, for tests. Two writers creating
one subject's key at once insert one row — the insert ignores the conflict and
both read back the row that won. Unwrapped keys are cached in memory per data
source, tenant and subject — for sealing, which happens on every audited write.
Opening a sealed value, `has` and `reveal` never use the cache: they read the
store every time, so a key shredded on another node stops opening on this one at
once.

### Shredding a key

`TomSubjectKeys.shred(subject)` deletes the subject's key and drops it from the
cache, and answers whether there was one. Every value ever sealed under it is
unreadable from then on, by anyone: the entries stay where they are, holding
ciphertext whose key no longer exists. `erase` shreds as its last step, after
the rows; `has(subject)` answers whether a subject has a key.

### Rotating a key-encryption key

Subject keys are wrapped under the same key-encryption keys as the data keys of
field encryption, so rotating one takes both halves: `TomFieldKeyring.rewrap()`
re-wraps the data keys and `TomSubjectKeys.rewrap()` the subject keys of the
tenant in context, each answering how many it re-wrapped. Neither touches a
stored value. Once both have run in every data source that holds keys, the old
key-encryption key can leave the list.

### A legal hold

`erase(subject, keepAuditKeys: true)` erases the rows and keeps the audit key.
A trail under a legal hold — evidence for a dispute, a regulator's request — has
to stay readable, and an erasure would otherwise defeat it; the GDPR's right to
erasure yields to the establishment or defence of legal claims. The report says
`auditKeyShredded: false` and the erasure's audit record says `audit key kept`.
Shredding later, once the hold ends, is `TomPrivacy.subjectKeys!.shred(id)`.

### Revealing a record

```dart
final readable = await TomPrivacy.reveal(entry.record);
```

`TomPrivacy.reveal(record)` answers the record with its sealed values opened —
what an auditor reads — and `[erased]` (`TomSubjectKeys.erasedPlaceholder`)
where the subject's key was shredded; every other field is as stored, and a
value that was never sealed is answered as it is. It raises
`privacy.no_subject_keys` when no subject keys are installed. `reveal` is a
read of the sink's records, not of the chain: it returns a new
`TomAuditRecord` and changes nothing stored. Who may reveal is, like who may
query the trail, the deployment's decision.

### The chain stays verifiable

Nothing about the trail changes when a key is shredded: every entry, its hash
and the chain are exactly as written, so `verify()` on the sink — and an
[anchor](audit.md#anchoring-the-chain-head) published before the erasure — still
holds. That is the whole design: the erasure deletes one row of the subject-key
table, and the values become unreadable without an entry being touched.

## What Stays As It Is

An erasure removes what the declarations reach; some data stays, on purpose or
because nothing declares it:

- **Audit entries written before subject keys were installed.** Their personal
  values were recorded in the clear, and no key exists to shred. They leave the
  trail when its retention removes them (see
  [audit.md](audit.md#retention-is-an-operator-action)).
- **Who acted.** An entry's actor — the username and user id of whoever made the
  change, the erased person included when they acted themselves — is kept. The
  trail exists to say who did what, and the controller keeps that record under
  its legal obligation of accountability; an erasure that removed the actor
  would remove the reason the trail is kept.
- **The shape of the entries.** Target, target key (the row's primary key),
  action, outcome, field names and the values of fields not declared
  `@TomPersonal` stay readable, and so does the subject's id inside each sealed
  value: the trail still shows that subject `7`'s comment was changed, not what
  it said.
- **Records that are not entity mutations.** `TomAuditTrail.recordAction`
  records — an endpoint invocation, an access denial, the privacy operations'
  own records — carry no per-field subjects and are not sealed; their `detail`
  text is stored as written.
- **What no registered entity holds.** Rows of entities that are not registered,
  framework tables that are not entities with a subject column (the message
  outbox, the external identity links — see [Not Yet
  Implemented](#not-yet-implemented)), logs and backups are not reached.

## Configuration

The `privacy` key of the configuration resources (`TomPrivacy.configurationKey`)
installs subject keys over a SQL store when the server starts:
`TomServer.start` hands it to `TomPrivacy.configure` through
`TomServer.configurePrivacy`, right after `configureFieldEncryption`, whose
key-encryption keys wrap the subject keys. Without the key no subject keys are
installed and personal values are recorded in the trail as they are.

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `datasource` | `String` | required | The registered data source the subject-key table is in: a `TomSqlSubjectKeyStore` over it, resolved by name on every call. |
| `table` | `String` | `tom_subject_key` | The table's name. |
| `createSchema` | `bool` | `true` | Whether the store creates the table on first use in each data source; `false` when the deployment applies the reference migration. |

```yaml
# assets/config-resources_default.yaml
fieldEncryption:
  datasource: main
  keys:
    - id: kek-2026
      key: "secret:vault:secret/data/billing#fieldKek"
privacy:
  datasource: main
  createSchema: false
```

A value of the wrong shape — not a map, no `datasource`, a `table` that is not a
string, a `createSchema` that is not a boolean — stops the start with
`privacy.config.invalid`, and so does a `privacy` section with no
field-encryption keyring installed to wrap the subject keys. Registration and the retention job are code, not
configuration: the deployment registers its repositories and its job at startup.
See [configuration.md](configuration.md#privacy).

## Tenancy

Everything runs in the tenant in context. A tenant table's (`@TomTenantTable`)
repository reaches the tenant's rows only, so an erasure in tenant `acme` erases
`acme`'s user `7` and leaves `globex`'s alone; a deployment erasing a person
known to several tenants erases them in each. With no tenant in context under an
installed tenancy a tenant table's repository is refused
(`tenancy.context.missing`). `applyRetention` applies the policies of its place:
in a tenant's context the tenant tables' policies, to that tenant's rows;
outside any tenant the system tables' policies; without a tenancy every policy.
The retention job is planned once per active tenant and once for the system
(`TomJobTenants(system: true)`), so its runs together apply every policy
everywhere — each tenant's run in its own tenant, a suspended tenant's after it
is resumed.

The subject keys follow the data: `tom_subject_key` is a tenant table, and
`TomSqlSubjectKeyStore` places its data source on every call, so under `schema`
or `database` isolation each tenant's subject keys are kept in the tenant's own
schema or database — created there on first use or, with `createSchema: false`,
by the migration in the tenant tree — and under `shared` isolation in its type's
shared schema, told apart by its `tenant` column. See
[tenancy.md](tenancy.md#framework-tables).

## Framework Entities That Declare Subjects

The framework's own per-user entities carry the declarations, so a deployment
that registers their repositories has them erased and exported with its own:

| Entity | Subject field(s) | Erasure | Personal |
| ------ | ---------------- | ------- | -------- |
| `TomUserPreference` ([preferences](preferences.md)) | `principalId` | delete | `valueJson` |
| `TomUserTwoFactorEnrolment` ([authentication](authentication.md)) | `principalId` | delete | `hint` |
| `TomPrincipalResourceGrant` ([authorization](authorization.md)) | `principalId` | delete | — |
| `TomPrincipalDelegation` ([authorization](authorization.md)) | `delegatorId`, `delegateId` | delete | — |

```dart
TomPrivacy.register(TomUserPreferenceRepository());
TomPrivacy.register(TomUserTwoFactorEnrolmentRepository());
TomPrivacy.register(grantStore.repository);       // a RepositoryPrincipalResourceGrantStore
TomPrivacy.register(delegationStore.repository);  // a RepositoryPrincipalDelegationStore
```

The preference and enrolment repositories are shipped; the authorization
tables' repositories are the deployment's, the ones its stores are built over.
Their subject ids are principal ids — tenant-qualified where the entity says so —
so an erasure of these entities is called with the principal id as they store
it. `TomExternalIdentityLink` declares nothing: it is keyed by the local
username, not by a subject id, and is listed under [Not Yet
Implemented](#not-yet-implemented).

## Error Keys

`TomPrivacyException` (extends `TomServerException`) carries every failure of
the module; none is client-visible (`clientThrow: false`), because each
describes the deployment's declarations or keys rather than the caller's input.

| Key | Raised when |
| --- | ----------- |
| `privacy.model.subject_type` | A `@TomDataSubject` field is not an `int` or a `String`, or is encrypted. |
| `privacy.model.subject_unknown` | A `@TomPersonal(subject:)` names a field that is not a `@TomDataSubject` field of the entity. |
| `privacy.model.subject_ambiguous` | A `@TomPersonal` field names no subject while the entity has more than one `@TomDataSubject` field, or none. |
| `privacy.model.structural_personal` | A `@TomPersonal` field is a key, version, reference or file column. |
| `privacy.model.retention_field` | A `@TomRetention` names a field that is not a `DateTime` column of the entity, or keeps a row for less than a day. |
| `privacy.model.retention_anonymize` | A `@TomRetention` anonymizes an entity that has no `@TomDataSubject` field. |
| `privacy.not_registered` | An operation names an entity type with no repository registered, or a subject-access export finds no registered entity with a subject field. |
| `privacy.no_subject_keys` | A value is to be sealed with no key-encryption keys given or installed, or a record revealed with no subject keys installed. |
| `privacy.seal.invalid` | A sealed audit value does not open under its subject's key: it was altered, or belongs to another field. |
| `privacy.no_datasource` | The data source a `TomSqlSubjectKeyStore` names is not registered. |
| `privacy.config.invalid` | The `privacy` configuration has the wrong shape, or no field-encryption keyring is installed to wrap the subject keys. |

A subject key wrapped under a key-encryption key that is no longer given raises
`field_encryption.unknown_kek` (a `TomFieldEncryptionException`), as a data key
does — the one key of that family this module raises. The family is field
encryption's, raised in `field_encryption.dart` and documented in
[object_persistence.md](object_persistence.md#how-field-encryption-fails):
`field_encryption.not_configured`, `field_encryption.unknown_key`,
`field_encryption.decrypt_failed`, `field_encryption.plaintext_refused`,
`field_encryption.unknown_kek`, `field_encryption.invalid_kek`,
`field_encryption.config.invalid` and `field_encryption.no_datasource`. Of
those, a deployment configuring `privacy` meets the configuration keys of
`fieldEncryption` too, because the subject keys are wrapped under its keyring.

## Not Yet Implemented

- **A row is tied to a subject only by a column it holds.** There are no
  join-based subjects: a project row that belongs to a person only through its
  workspace's owner is not found by an erasure of that person. Such rows are
  reached by the database's `ON DELETE CASCADE` from a row that is deleted, or
  by giving them a subject column of their own.
  <!-- unpinned: absence — subjects are declared on columns only -->
- **`TomExternalIdentityLink` is not covered.** The link between an external
  identity and a local account is keyed by the local username, not by a subject
  id, so it declares no `@TomDataSubject`; a deployment erasing a user removes
  their links with `TomExternalIdentityStore` itself.
  <!-- unpinned: decision — the link is keyed by username, not by a subject id -->
- **Nothing schedules retention by itself.** `@TomRetention` is applied by a
  retention run; a deployment registers `TomPrivacy.retentionJob` on its
  scheduler, or calls `applyRetention` itself.
  <!-- unpinned: absence — no retention job is registered by the framework -->
- **Rectification and restriction of processing are not offered.** Correcting a
  person's data is an ordinary repository write; marking their rows as not to be
  processed is not modelled.
  <!-- unpinned: absence — no restriction flag exists -->

## Verification

`test/privacy_test.dart` covers the module without a database: the
personal-data model of the fixtures and of the framework's per-user entities,
which fields are sealed for whom, anonymize against unlink, the subject id bound
as its column stores it, and the refused declarations
(`privacy.model.subject_ambiguous`, `…subject_type`, `…retention_field`, at
`TomPrivacy.register` too); the subject keys — a value opening while the key
exists and reading `[erased]` after the shred, a value sealed for one field not
opening as another (`privacy.seal.invalid`), a key per subject, one subject id in two tenants kept
apart, a key shredded by another node no longer opening, a key-encryption-key
rotation re-wrapping the subject keys, values that are not sealed, no
key-encryption keys (`privacy.no_subject_keys`); the audit trail
sealing a personal value, revealing it, and still verifying after the shred, and
recording values as they are without subject keys; the configuration
(`privacy.config.invalid`), unregistered entities (`privacy.not_registered`),
an unregistered data source (`privacy.no_datasource`) and the declared
retention policies.

`test/privacy_db_test.dart` runs the operations through real repositories
against a live database: an erasure deleting, anonymizing and unlinking across
three entities as each field declares; every step audited, the erased subject's
values unreadable in the trail while another subject's still read and the chain
verifies; an erasure under a legal hold keeping the key; a subject-access export
holding every row once, rendered as CSV and XLSX and audited; retention deleting
and anonymizing what is past its time, and doing nothing the second time; and
the retention job run by an inline scheduler. It is tagged `db` and skips
without a server. `test/framework_schema_test.dart` converges the reference
migration against `subjectKeyTable` and drives `TomSqlSubjectKeyStore`'s
statements, and `test/reference_migrations_test.dart` accounts for the
migration.

```bash
dart run example/privacy/privacy_example.dart
```

`example/privacy/privacy_example.dart` shows the parts that need no database:
the models of the framework's entities, sealing and opening under subject keys,
a value refused under another field, the audit trail sealing a personal value
into a memory sink, revealing it, shredding the subject and the chain still
verifying, and a malformed configuration refused. An erasure goes through
repositories, so it is the live suite's.

## Core Components

- **`TomDataSubject`**, **`TomPersonal`**, **`TomRetention`**, **`TomErasure`**
  (`personal_data.dart`) — the declarations.
- **`TomPersonalDataModel`**, **`TomSubjectField`**, **`TomPersonalField`**
  (`personal_data.dart`) — the declarations resolved and checked, which fields
  a row seals for whom, and clearing a row.
- **`TomPrivacy`** (`privacy.dart`) — registration, `erase`, `subjectAccess` /
  `exportSubject`, `applyRetention` / `retentionJob`, the installed subject keys
  and `reveal`; with `TomErasureReport`, `TomErasureCount`, `TomSubjectAccess`,
  `TomRetentionPolicy` and `TomRetentionCount`.
- **`TomSubjectKeys`** (`subject_keys.dart`) — sealing, opening, shredding and
  revealing; **`TomSubjectKeyStore`**, **`TomMemorySubjectKeyStore`**,
  **`TomSqlSubjectKeyStore`** keep the wrapped keys, and `subjectKeyTable`
  (`subject_keys_sql.dart`) declares their table.
- **`TomPrivacyException`** (`personal_data.dart`) — the `privacy.*` keys.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `privacy.dart` | `Future`, `FutureOr` |
| `dart:convert` | dart | `subject_keys.dart` | `utf8`, `base64`, `base64Url` and `jsonEncode` / `jsonDecode`, for the sealed envelope and the wrapped key |
| `dart:math` | dart | `subject_keys.dart` | `Random.secure`, for a subject key's bytes |
| `dart:typed_data` | dart | `subject_keys.dart` | `Uint8List`, for key material |
| `tom_core_kernel` | package | `privacy.dart`, `subject_keys.dart` | `TomTenantContext`, the tenant a key belongs to; `tomReflector`; and the scheduling the retention job runs on — `TomJobDefinition`, `TomSchedule`, `TomCommand` |
| [audit](audit.md) | module | `privacy.dart`, `subject_keys.dart` | `TomAuditTrail` — the operations' own records, and `personalValueSealer`, which installing subject keys sets — and `TomAuditRecord`, which `reveal` opens |
| [datasources](datasources.md) | module | `subject_keys.dart`, `subject_keys_sql.dart` | `TomFrameworkTable`, the subject-key table's single declaration; `TomDataSource`, `TomDataSourceInfo` and `TomSchemaProvisioning`, to resolve and provision the store's data source; `sqlInstant` / `parseSqlInstant` |
| [export](export.md) | module | `privacy.dart` | `TomTabularResult` / `TomTabularSection.ofEntities`, the subject-access export's shape, and `TomExportFormats`, its renderers |
| [little_things](little_things.md) | module | `personal_data.dart` | `TomServerException`, the base of `TomPrivacyException` |
| [object_persistence](object_persistence.md) | module | `personal_data.dart`, `privacy.dart`, `subject_keys.dart` | `TomAnnotationAnalyzer` and `TomColumnInformation`, to resolve the declarations; `TomRepository`, `TomPageRequest` / `TomSortField` and `TomDataScope.runUnscoped`, to run the operations; `TomAesGcm`, `TomKeyEncryptionKey` and `TomFieldEncryption.keyring`, to seal values and wrap keys; `TomDbTable` / `TomDbColumn` on `TomSubjectKeyRow` |
| [tenancy](tenancy.md) | module | `privacy.dart` | `TomTenancy.current` and `forEachTenant`, which a retention run with no tenant applies a tenant table's policy in |

- The object_persistence module — `TomSqlDatasourceRepository` passes the
  subjects of a row's personal fields to the audit trail, so their values are
  sealed.
- The server module — `TomServer.configurePrivacy` applies the `privacy`
  configuration on start.
- The db_migration module — `frameworkOwnedTables` lists the subject-key table.
- The authentication, authorization and preferences modules — their per-user
  entities carry `@TomDataSubject` and `@TomPersonal`.
