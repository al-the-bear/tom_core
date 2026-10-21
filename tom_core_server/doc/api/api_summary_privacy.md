# Tom Core Server API Reference: Privacy Module

The data-protection operations: erasing a data subject, exporting what is held
about them, applying retention, and crypto-shredding their values in the audit
trail. Entities declare which column names the subject (`@TomDataSubject`),
which columns hold their data (`@TomPersonal`) and how long rows are kept
(`@TomRetention`); the application registers the entities' repositories with
[TomPrivacy](#tomprivacy), and every operation runs through them. See
[doc/privacy.md](../privacy.md) for the narrative guide.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomPrivacyException](#tomprivacyexception)
  - [TomDataSubject](#tomdatasubject)
  - [TomPersonal](#tompersonal)
  - [TomRetention](#tomretention)
  - [TomSubjectField](#tomsubjectfield)
  - [TomPersonalField](#tompersonalfield)
  - [TomPersonalDataModel](#tompersonaldatamodel)
  - [TomSubjectKeyRecord](#tomsubjectkeyrecord)
  - [TomSubjectKeyStore](#tomsubjectkeystore)
  - [TomMemorySubjectKeyStore](#tommemorysubjectkeystore)
  - [TomSqlSubjectKeyStore](#tomsqlsubjectkeystore)
  - [TomSubjectKeyRow](#tomsubjectkeyrow)
  - [TomSubjectKeys](#tomsubjectkeys)
  - [TomErasureCount](#tomerasurecount)
  - [TomErasureReport](#tomerasurereport)
  - [TomSubjectAccess](#tomsubjectaccess)
  - [TomRetentionPolicy](#tomretentionpolicy)
  - [TomRetentionCount](#tomretentioncount)
  - [TomPrivacy](#tomprivacy)
- [Enums](#enums)
  - [TomErasure](#tomerasure)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/privacy/personal_data.dart`,
`lib/src/tomserver/privacy/subject_keys.dart`,
`lib/src/tomserver/privacy/subject_keys_sql.dart`,
`lib/src/tomserver/privacy/privacy.dart`.

`personal_data.dart` holds the declarations — `TomDataSubject`, `TomPersonal`,
`TomRetention`, `TomErasure` — and `TomPersonalDataModel`, which resolves and
checks them per entity (`TomSubjectField`, `TomPersonalField`) and refuses a
declaration the operations could not carry out with a `privacy.model.*`
`TomPrivacyException`.

`privacy.dart` holds `TomPrivacy`, the isolate's operations. `register` enrols
a repository's entity; `erase` deletes, anonymizes or unlinks every row naming a
subject and shreds the subject's audit key (`TomErasureReport`,
`TomErasureCount`); `subjectAccess` and `exportSubject` collect those rows into
a tabular result rendered by the export module (`TomSubjectAccess`);
`applyRetention` and `retentionJob` apply retention (`TomRetentionPolicy`,
`TomRetentionCount`). The operations run unscoped and through the repositories,
and each is audited.

`subject_keys.dart` holds crypto-shredding: `TomSubjectKeys` seals a personal
value under a key per subject, wrapped under key-encryption keys and kept in a
`TomSubjectKeyStore` (`TomMemorySubjectKeyStore`, `TomSqlSubjectKeyStore` over
the `tom_subject_key` table `subject_keys_sql.dart` declares once). Installed
with `TomPrivacy.installSubjectKeys`, it is the audit trail's
`personalValueSealer`; shredding a subject's key makes their sealed values
unreadable without touching the hash chain.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomPrivacyException

TomSubjectKeyStore  (abstract)
    ├── TomMemorySubjectKeyStore  (implements)
    └── TomSqlSubjectKeyStore  (implements)

TomPrivacy  (abstract final, static-only)

TomDataSubject
TomPersonal
TomRetention
TomSubjectField
TomPersonalField
TomPersonalDataModel
TomSubjectKeyRecord
TomSubjectKeyRow
TomSubjectKeys
TomErasureCount
TomErasureReport
TomSubjectAccess
TomRetentionPolicy
TomRetentionCount
```

## Classes

### TomPrivacyException

A privacy declaration or operation that cannot proceed. Raised with
`clientThrow: false`: every key describes the deployment's declarations or keys,
not the caller's input.

| Key | Meaning |
| --- | ------- |
| `privacy.model.subject_type` | A `@TomDataSubject` field is not an `int` or a `String`, or is encrypted. |
| `privacy.model.subject_unknown` | A `@TomPersonal(subject:)` names a field that is not a `@TomDataSubject` field of the entity. |
| `privacy.model.subject_ambiguous` | A `@TomPersonal` field names no subject while the entity has more than one `@TomDataSubject` field, or none. |
| `privacy.model.structural_personal` | A `@TomPersonal` field is a key, version, reference or file column, which cannot be cleared. |
| `privacy.model.retention_field` | A `@TomRetention` names a field that is not a `DateTime` column of the entity, or keeps a row for less than a day. |
| `privacy.model.retention_anonymize` | A `@TomRetention` anonymizes an entity that has no `@TomDataSubject` field. |
| `privacy.not_registered` | An operation names an entity type with no repository registered, or a subject-access export finds no registered entity with a subject field. |
| `privacy.no_subject_keys` | Audit values are to be sealed, or a record revealed, with no subject keys installed — or no key-encryption keys to wrap a subject key under. |
| `privacy.seal.invalid` | A sealed audit value does not open under its subject's key: it was altered, or belongs to another field. |
| `privacy.no_datasource` | The data source a `TomSqlSubjectKeyStore` names is not registered. |
| `privacy.config.invalid` | The `privacy` configuration has the wrong shape. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomPrivacyException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
})
```

### TomDataSubject

Marks the field holding the id of the person a row belongs to or names — a data
subject — and what erasing them does to the row. The field is an `int` or
`String` column, not encrypted; every subject field of every registered entity
names subjects in the same id space, which is what lets one erasure reach all
of them.

#### Constructors

```dart
const TomDataSubject({TomErasure onErasure = TomErasure.delete})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `onErasure` | `TomErasure` | What erasing the subject does to the row (final). |

### TomPersonal

Marks a field holding personal data about the subject of a `@TomDataSubject`
field of the same entity. The field is exported with the row, cleared — set to
`replacement`, or `null` — when its subject is erased with `anonymize` or the
row is anonymized by retention, and its values in the audit trail are sealed
under the subject's key.

#### Constructors

```dart
const TomPersonal({String? subject, Object? replacement})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subject` | `String?` | The declared name of the `@TomDataSubject` field whose subject the data is about, or `null` for the entity's only one (final). |
| `replacement` | `Object?` | What the field is set to when cleared — for a column that may not be `NULL`; `null` clears it to `NULL` (final). |

### TomRetention

Declares how long the rows of an entity are kept: a row whose `field` lies more
than `days` in the past is deleted, or anonymized, by a retention run.

#### Constructors

```dart
const TomRetention({
  required String field,
  required int days,
  TomErasure action = TomErasure.delete,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `field` | `String` | The declared name of the `DateTime` field the age is measured from (final). |
| `days` | `int` | How many days a row is kept; at least one (final). |
| `action` | `TomErasure` | `delete`, or `anonymize` to clear every subject and personal field instead; `unlink` reads as anonymize (final). |

### TomSubjectField

One `@TomDataSubject` field, resolved.

#### Constructors

```dart
const TomSubjectField(TomColumnInformation column, TomDataSubject declaration)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `column` | `TomColumnInformation` | The column (final). |
| `declaration` | `TomDataSubject` | The annotation (final). |
| `onErasure` | `TomErasure` | *(getter)* What erasing the subject does to a row this field names them in. |
| `name` | `String` | *(getter)* The declared name of the field. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toColumnValue` | `Object toColumnValue(Object subject)` | `subject` as this column stores it: a `String` that parses as an integer binds as an `int` to an `int` column; anything else as given. |

### TomPersonalField

One `@TomPersonal` field, resolved to the subject field it belongs to.

#### Constructors

```dart
const TomPersonalField(
  TomColumnInformation column,
  TomSubjectField subject,
  TomPersonal declaration,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `column` | `TomColumnInformation` | The column (final). |
| `subject` | `TomSubjectField` | The subject field whose subject the data is about (final). |
| `declaration` | `TomPersonal` | The annotation (final). |
| `name` | `String` | *(getter)* The declared name of the field. |

### TomPersonalDataModel

The personal-data declarations of one entity, resolved through the reflector
and checked. Created by `of`, which caches per type; the constructor is private.

#### Constructors

None — the constructor is private; obtain instances via `of`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entity` | `Type` | The entity type (final). |
| `subjects` | `List<TomSubjectField>` | The `@TomDataSubject` fields, in declaration order; unmodifiable (final). |
| `personal` | `List<TomPersonalField>` | The `@TomPersonal` fields, in declaration order; unmodifiable (final). |
| `retention` | `TomRetention?` | The `@TomRetention` declaration, or `null` (final). |
| `keys` | `List<TomColumnInformation>` | The primary-key columns; unmodifiable (final). |
| `isEmpty` | `bool` | *(getter)* Whether the entity declares nothing about personal data. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static TomPersonalDataModel of(Type entity)` | The model of `entity`, resolved once. Throws a `privacy.model.*` `TomPrivacyException` for a declaration the operations could not carry out. |
| `clearCache` | `static void clearCache()` | Forgets every resolved model. For tests. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `personalOf` | `List<TomPersonalField> personalOf(TomSubjectField subject)` | The personal fields belonging to `subject`. |
| `sealingSubjects` | `Map<String, String> sealingSubjects(Object? row)` | For an audit record of `row`: each personal field's name mapped to the id of the subject its values are sealed for. A field whose subject field is empty in `row`, and an encrypted field (already redacted in the trail), are left out; `null` answers an empty map. |
| `clear` | `bool clear(Object row, TomSubjectField subject, {required bool anonymize})` | Clears in `row` the subject field `subject` and, when `anonymize`, its personal fields (to their `replacement`); answers whether anything changed. |
| `keyOf` | `List<Object?> keyOf(Object row)` | The primary key of `row`, as a list of its key values. |

### TomSubjectKeyRecord

One subject key as a store holds it: wrapped.

#### Constructors

```dart
const TomSubjectKeyRecord({
  required String subject,
  required String kekId,
  required String wrapped,
  required DateTime createdAt,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subject` | `String` | The subject's id (final). |
| `kekId` | `String` | The key-encryption key it is wrapped under (final). |
| `wrapped` | `String` | The wrapped key, base64 (final). |
| `createdAt` | `DateTime` | When it was created (final). |

### TomSubjectKeyStore

Where subject keys are kept. Every operation works in the tenant in context.

- **Abstract.** Implemented by `TomMemorySubjectKeyStore` and `TomSqlSubjectKeyStore`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `scope` | `Object` | *(getter, abstract)* What the current context's keys belong to — the key `TomSubjectKeys` caches unwrapped keys under, with the subject. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(abstract)* Makes the store ready — creates its table — for the data source the current context resolves. Called outside any transaction. |
| `find` | `Future<TomSubjectKeyRecord?> find(String subject)` | *(abstract)* The key of `subject`, or `null`. |
| `insert` | `Future<bool> insert(TomSubjectKeyRecord record)` | *(abstract)* Stores `record`; answers `false` when the subject has a key already. |
| `delete` | `Future<bool> delete(String subject)` | *(abstract)* Deletes the key of `subject`; answers whether there was one. |
| `all` | `Future<List<TomSubjectKeyRecord>> all()` | *(abstract)* Every key of the tenant in context. |
| `update` | `Future<void> update(TomSubjectKeyRecord record)` | *(abstract)* Replaces the stored key of `record`'s subject — a re-wrap. |

### TomMemorySubjectKeyStore

Subject keys in memory, keyed by tenant and subject: for tests.

- **Implements:** `TomSubjectKeyStore`

#### Constructors

```dart
TomMemorySubjectKeyStore()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `scope` | `Object` | *(getter, override)* The store itself. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(override)* Does nothing. |
| `find` | `Future<TomSubjectKeyRecord?> find(String subject)` | *(override)* The record kept for the tenant in context and `subject`. |
| `insert` | `Future<bool> insert(TomSubjectKeyRecord record)` | *(override)* Keeps `record` under the tenant in context; `false` when one is kept already. |
| `delete` | `Future<bool> delete(String subject)` | *(override)* Removes the tenant in context's record of `subject`. |
| `all` | `Future<List<TomSubjectKeyRecord>> all()` | *(override)* The tenant in context's records. |
| `update` | `Future<void> update(TomSubjectKeyRecord record)` | *(override)* Replaces the tenant in context's record. |

### TomSqlSubjectKeyStore

Subject keys in a SQL data source. Every statement derives from the single
`subjectKeyTable` declaration. The data source is resolved by name on every
call, through `TomDataSourceInfo.getDataSourceInfo`, which routes under
tenancy — so each tenant's data source holds its own subjects' keys.

- **Implements:** `TomSubjectKeyStore`

#### Constructors

```dart
TomSqlSubjectKeyStore(
  String this.datasourceName, {
  String table = defaultSubjectKeyTable,
  bool createSchema = true,
})

TomSqlSubjectKeyStore.over(
  TomDataSource datasource, {
  String table = defaultSubjectKeyTable,
  bool createSchema = true,
})
```

The unnamed constructor resolves the data source registered as
`datasourceName` per call; an unregistered name raises `privacy.no_datasource`.
`over` binds `datasource` itself, resolved once. With `createSchema` (the
default) the table is created on first use in each data source; a deployment
whose database user may not run DDL applies the shipped migration and passes
`false`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasourceName` | `String?` | The registered name of the data source, or `null` for a store built `over` one (final). |
| `table` | `String` | The table's name (final). |
| `createSchema` | `bool` | Whether the table is created on first use (final). |
| `scope` | `Object` | *(getter, override)* The data source the current context resolves. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(override)* Creates the table, once per data source, when `createSchema` is set. |
| `find` | `Future<TomSubjectKeyRecord?> find(String subject)` | *(override)* Reads the row of the tenant in context and `subject`. |
| `insert` | `Future<bool> insert(TomSubjectKeyRecord record)` | *(override)* Inserts the row, ignoring a conflict on `(tenant, subject_id)`; `false` when it conflicted. |
| `delete` | `Future<bool> delete(String subject)` | *(override)* Deletes the row of the tenant in context and `subject`. |
| `all` | `Future<List<TomSubjectKeyRecord>> all()` | *(override)* The rows of the tenant in context. |
| `update` | `Future<void> update(TomSubjectKeyRecord record)` | *(override)* Updates `kek_id` and `wrapped_key` of the tenant in context's row. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the table of the data source this context resolves. Not part of `TomSubjectKeyStore`; for tests. |

### TomSubjectKeyRow

One row of the subject-key table, as `TomSqlSubjectKeyStore` reads it.
Reflected (`@tomReflector`) and annotated `@TomDbTable` with placeholder values,
so the driver can map it; the real table name is a constructor argument of the
store.

#### Constructors

```dart
TomSubjectKeyRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subjectId` | `String` | `subject_id` — the subject's id. |
| `kekId` | `String` | `kek_id` — the wrapping key-encryption key. |
| `wrappedKey` | `String` | `wrapped_key` — the wrapped key, base64. |
| `createdAt` | `String` | `created_at` — when it was created, as stored UTC text. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toRecord` | `TomSubjectKeyRecord toRecord()` | The record this row stores. |

### TomSubjectKeys

The subject keys of crypto-shredding: sealing a personal value for one subject,
opening it while their key exists, and shredding the key. A key is 32 random
bytes, created on the first seal for its subject, kept wrapped (the wrapping
bound to `subject:<id>`) and cached unwrapped in memory per store scope and
subject. A sealed value reads `tomsubj:v1:<base64url subject>:<base64url
sealed>`: the value JSON-encoded and sealed with `TomAesGcm`, the subject and the
field authenticated with it.

#### Constructors

```dart
TomSubjectKeys({
  required TomSubjectKeyStore store,
  List<TomKeyEncryptionKey>? keys,
  DateTime Function()? clock,
})
```

`keys` wrap the subject keys — the first wraps new keys, every one may unwrap.
Without `keys`, the key-encryption keys of the installed field-encryption
keyring (`TomFieldEncryption.keyring`) are used, read when a key is needed;
with neither, sealing raises `privacy.no_subject_keys`. `clock` stamps
`createdAt`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomSubjectKeyStore` | Where the wrapped keys are kept (final). |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `prefix` | `String` | `'tomsubj:v1:'`, what every sealed value starts with (const). |
| `erasedPlaceholder` | `String` | `'[erased]'`, what `open` and `reveal` show for a value whose subject's key is gone (const). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isSealed` | `static bool isSealed(Object? value)` | Whether `value` is a sealed value. |
| `subjectOf` | `static String? subjectOf(Object? value)` | The subject a sealed `value` belongs to, read without a key, or `null`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `seal` | `Future<Object?> seal(String subject, String field, Object? value)` | `value` of `field`, sealed under `subject`'s key, which is created on first use. `null` stays `null`. Matches `TomAuditTrail.personalValueSealer`. |
| `open` | `Future<Object?> open(Object? sealed, String field)` | The value `sealed` holds for `field`, or `erasedPlaceholder` when its subject's key is gone — read from the store every time, never from the cache; a value that is not sealed is answered as it is. Throws `privacy.seal.invalid` when it does not open, `field_encryption.unknown_kek` when its key is wrapped under a key-encryption key not given. |
| `has` | `Future<bool> has(String subject)` | Whether `subject` has a key, as the store says now. |
| `shred` | `Future<bool> shred(String subject)` | Deletes `subject`'s key and drops it from the cache: every value sealed under it is unreadable from then on. Answers whether there was one. |
| `rewrap` | `Future<int> rewrap()` | Wraps every subject key of the tenant in context that is not wrapped under the primary key-encryption key under it; answers how many. The subject-key half of rotating a key-encryption key. |
| `reveal` | `Future<TomAuditRecord> reveal(TomAuditRecord record)` | `record` with its sealed `before` and `after` values opened — what an auditor reads. Every other field is copied as it is. |

### TomErasureCount

What an erasure did to one entity.

#### Constructors

```dart
const TomErasureCount({
  required Type entity,
  int deleted = 0,
  int anonymized = 0,
  int unlinked = 0,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entity` | `Type` | The entity type (final). |
| `deleted` | `int` | Rows deleted (final). |
| `anonymized` | `int` | Rows kept with the subject and their personal fields cleared (final). |
| `unlinked` | `int` | Rows kept with only the subject field cleared (final). |
| `isEmpty` | `bool` | *(getter)* Whether the entity held nothing about the subject. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `<entity>: <n> deleted, <n> anonymized, <n> unlinked`. |

### TomErasureReport

What `TomPrivacy.erase` did.

#### Constructors

```dart
const TomErasureReport({
  required String subject,
  required List<TomErasureCount> counts,
  required bool auditKeyShredded,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subject` | `String` | The erased subject (final). |
| `counts` | `List<TomErasureCount>` | One per visited entity with a `@TomDataSubject` field, in visiting order (final). |
| `auditKeyShredded` | `bool` | Whether the subject's audit key was deleted — `false` when it was kept on request, or there was none (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `countOf` | `TomErasureCount countOf(Type entity)` | The count of `entity`. |
| `toString` | `String toString()` | *(override)* The subject, every count and whether the audit key was shredded or kept. |

### TomSubjectAccess

A subject-access export: what is held about a subject, one section per
registered entity with a subject field.

#### Constructors

```dart
const TomSubjectAccess({
  required String subject,
  required TomTabularResult result,
  required Map<Type, int> rowCounts,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `subject` | `String` | The subject (final). |
| `result` | `TomTabularResult` | The tabular result — titled `Personal data of <subject>`, one section per entity titled by its type — ready for any export format (final). |
| `rowCounts` | `Map<Type, int>` | The rows exported, per entity; `0` for an entity holding nothing about the subject (final). |

### TomRetentionPolicy

One retention rule: rows of `entity` whose `field` lies more than `keep` in the
past are deleted, or anonymized.

#### Constructors

```dart
const TomRetentionPolicy({
  required Type entity,
  required String field,
  required Duration keep,
  TomErasure action = TomErasure.delete,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entity` | `Type` | The entity type, which must be registered (final). |
| `field` | `String` | The declared name of the `DateTime` field the age is measured from (final). |
| `keep` | `Duration` | How long a row is kept (final). |
| `action` | `TomErasure` | What happens to an expired row: `delete`, or anything else to anonymize (final). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `declared` | `static List<TomRetentionPolicy> declared()` | The policies the registered entities declare with `@TomRetention`, in registration order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `TomRetentionPolicy(<entity>.<field>, <days> days, <action>)`. |

### TomRetentionCount

The outcome of one retention policy.

#### Constructors

```dart
const TomRetentionCount(TomRetentionPolicy policy, DateTime cutoff, int affected)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `policy` | `TomRetentionPolicy` | The policy applied (final). |
| `cutoff` | `DateTime` | The instant rows had to be newer than (final). |
| `affected` | `int` | Rows deleted or anonymized (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `<policy>: <affected>`. |

### TomPrivacy

The isolate's privacy operations. Every operation works through the registered
repositories, inside `TomDataScope.runUnscoped` — so it reaches every row about
the subject, and checks no permission of its own; an endpoint offering an
erasure or an export gates it — and each is recorded in the audit trail.

- **Extends:** none (abstract final, static members only)

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configurationKey` | `String` | `'privacy'`, the configuration key `configure` reads (const). |
| `erasureTarget` | `String` | `'privacy.erasure'`, the audit target of an erasure (const). |
| `subjectAccessTarget` | `String` | `'privacy.subject_access'`, the audit target of a subject-access export (const). |
| `retentionTarget` | `String` | `'privacy.retention'`, the audit target of a retention run (const). |
| `retentionBatchSize` | `int` | Rows read per statement by a retention run; `200` (mutable). |
| `entities` | `List<Type>` | *(getter)* The registered entity types, in registration order; unmodifiable. |
| `subjectKeys` | `TomSubjectKeys?` | *(getter)* The installed subject keys, or `null`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `register` | `static void register<T extends Object>(TomRepository<T, dynamic> repository)` | Enrols `repository`'s entity in erasure, export and retention; registration order is visiting order, and registering an entity again replaces its repository. Resolves the entity's declarations at once, so a refused one (`privacy.model.*`) is refused here. |
| `installSubjectKeys` | `static void installSubjectKeys(TomSubjectKeys keys)` | Installs `keys` and sets `TomAuditTrail.personalValueSealer` to `keys.seal`, so the trail seals `@TomPersonal` values. |
| `reset` | `static void reset()` | Forgets the registrations and the subject keys, clears the sealer and restores `retentionBatchSize`. For tests. |
| `configure` | `static void configure(Object? settings)` | Installs subject keys over a `TomSqlSubjectKeyStore` from the `privacy` configuration map — `datasource` (required), `table` (default `tom_subject_key`), `createSchema` (default `true`) — wrapped under the installed field-encryption keyring's keys. Throws `privacy.config.invalid` for a value of the wrong shape. |
| `erase` | `static Future<TomErasureReport> erase(Object subject, {bool keepAuditKeys = false, Iterable<Type>? entities})` | Applies each `@TomDataSubject` field's `TomErasure` to every row naming `subject`, in every registered entity or those in `entities`, in order, through the repositories; then shreds the subject's audit key unless `keepAuditKeys`. Audited (`erasureTarget`, action `delete`, the subject as target key). |
| `subjectAccess` | `static Future<TomSubjectAccess> subjectAccess(Object subject, {Iterable<Type>? entities})` | Every row any subject field ties to `subject`, once each by primary key, one section per entity, every mapped column (redacted and file-reference columns excluded); encrypted columns decrypted. Audited (`subjectAccessTarget`, action `read`). Throws `privacy.not_registered` when no selected entity has a subject field. |
| `exportSubject` | `static Future<List<int>> exportSubject(Object subject, {String format = 'xlsx', TomExportFormats? formats, Iterable<Type>? entities})` | `subjectAccess`, rendered in `format` — `csv`, `xlsx`, `pdf`, or a format of `formats` — as bytes. |
| `applyRetention` | `static Future<List<TomRetentionCount>> applyRetention({Iterable<TomRetentionPolicy>? policies, DateTime? now})` | Applies `policies` — by default `TomRetentionPolicy.declared()` — at `now`, deleting or anonymizing the expired rows through the repositories, `retentionBatchSize` at a time. Each policy's run is audited (`retentionTarget`, action `delete` or `update`). |
| `retentionJob` | `static TomJobDefinition retentionJob({required TomSchedule schedule, Iterable<TomRetentionPolicy>? policies, String name = tomRetentionJobName, Duration timeout = const Duration(hours: 1)})` | A scheduler job applying `policies` (default: the declared ones) at each run's window instant, recovery requested, the counts as its result. Uses the isolate's registrations, so it belongs on a scheduler with a `TomInlineJobDispatcher`. |
| `reveal` | `static Future<TomAuditRecord> reveal(TomAuditRecord record)` | `record` with its sealed personal values opened, or `[erased]` where the subject's key was shredded. Throws `privacy.no_subject_keys` when none are installed. |

## Enums

### TomErasure

What erasing a data subject does to a row a `@TomDataSubject` field ties to
them.

| Value | Meaning |
| ----- | ------- |
| `delete` | The row is deleted — it is the subject's own. |
| `anonymize` | The row is kept, but no longer names the subject: this field is cleared, and so is every `@TomPersonal` field belonging to it. |
| `unlink` | The row is kept and only this field is cleared. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultSubjectKeyTable` | `String` | `'tom_subject_key'`, the subject-key table's name when nothing overrides it. |
| `tomRetentionJobName` | `String` | `'privacy.retention'`, the default name of the retention job. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `subjectKeyTable` | `TomFrameworkTable subjectKeyTable(String table)` | The one declaration of the subject-key table: primary key `(tenant, subject_id)`, `kek_id`, `wrapped_key` and `created_at`. Listed by `frameworkOwnedTables`. |
| `subjectKeyTableDdl` | `String subjectKeyTableDdl(String table)` | The `CREATE TABLE` statement for the subject-key table, derived from `subjectKeyTable`. |
