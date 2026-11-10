# privacy

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

The data-protection operations a deployment owes the people whose data it
holds: **erasing** a person, **exporting** what is held about them (subject
access), keeping rows **no longer than declared** (retention), and
**crypto-shredding** their values in the audit trail.

An entity declares what it holds about whom: `@TomDataSubject` on the `int` or
`String` column naming the person — with what erasing them does to the row,
`delete`, `anonymize` or `unlink` — `@TomPersonal` on the columns holding their
data, and `@TomRetention` on the class. The application registers the entities'
repositories with `TomPrivacy`, and every operation runs through them: each row
it deletes or updates is audited, its files are cascaded, encrypted columns stay
encrypted and a tenant table stays in its tenant. The operations read
regardless of the caller's row scope, so who may ask for one is the caller's to
gate.

The audit trail is append-only and hash-chained, so a person's values cannot be
taken out of it afterwards. Instead they are never written in the clear: with
subject keys installed, every `@TomPersonal` value in a repository's audit
record is sealed under a key of that person alone, and erasing them deletes the
key. The entries stay, the chain still verifies, and the values can no longer be
read by anyone.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDataSubject` / `TomPersonal` / `TomRetention` / `TomErasure` | The declarations: the field naming the subject and what erasing them does (`delete`, `anonymize`, `unlink`), a field holding their data (cleared to `replacement` on anonymize, sealed in the trail), and how long rows are kept. |
| `TomPersonalDataModel` / `TomSubjectField` / `TomPersonalField` | An entity's declarations resolved through the reflector and checked once (`of`), refusing what the operations could not carry out with a `privacy.model.*` key; which fields of a row are sealed for whom (`sealingSubjects`), and clearing a row. |
| `TomPrivacy` | The isolate's operations. `register(repository)` (order = visiting order); `erase(subject, keepAuditKeys:)` answering a `TomErasureReport` of `TomErasureCount`s; `subjectAccess` / `exportSubject(format:)` answering a `TomSubjectAccess` or its CSV/XLSX/PDF bytes; `applyRetention` / `retentionJob` applying `TomRetentionPolicy`s and answering `TomRetentionCount`s; `installSubjectKeys` / `configure` and `reveal`. Each operation is audited. |
| `TomSubjectKeys` | Crypto-shredding: `seal` a value under a subject's key (created on first use, wrapped under key-encryption keys — by default the field-encryption keyring's), `open` it while the key exists, `shred` the key, `reveal` an audit record — `[erased]` where the key is gone. |
| `TomSubjectKeyStore` / `TomSqlSubjectKeyStore` / `TomMemorySubjectKeyStore` | Where the wrapped keys are kept, in the tenant in context: `tom_subject_key` (`subjectKeyTable`, `defaultSubjectKeyTable`) of a data source resolved by name per call, or memory. `TomSubjectKeyRecord` / `TomSubjectKeyRow` are a key as stored. |
| `TomPrivacyException` | Every failure of the module, keyed `privacy.*`; never client-visible. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final keys = TomSubjectKeys(
    store: TomMemorySubjectKeyStore(),
    keys: [TomAesKeyEncryptionKey('kek-1', List.filled(32, 7))],
  );
  final sealed = await keys.seal('7', 'email', 'ada@example.com');
  print(await keys.open(sealed, 'email')); // ada@example.com
  await keys.shred('7'); // what an erasure of subject 7 does last
  print(await keys.open(sealed, 'email')); // [erased]
}
```

That is the audit half on its own: what the trail holds for a personal value is
`sealed`, and after the shred no one can open it. In a deployment the keys are
installed once — `TomPrivacy.installSubjectKeys`, or the `privacy`
configuration key read by `TomServer.start` — and the repositories are
registered at startup:

```dart
TomPrivacy.register(workspaceRepository);   // deleted first: it cascades
TomPrivacy.register(commentRepository);
TomPrivacy.register(userRepository);        // the account itself last

final report = await TomPrivacy.erase(userId);
final xlsx = await TomPrivacy.exportSubject(userId);
```

See [`doc/privacy.md`](../../../../doc/privacy.md) for declaring personal
data, what each erasure does and in which order, the subject-access export,
retention runs and their job, crypto-shredding and what stays in the trail, the
configuration, tenancy and the framework entities that declare subjects; and
`example/privacy/privacy_example.dart` for a walkthrough that checks its own
results without a database. `test/privacy_test.dart` covers the module without
a database, `test/privacy_db_test.dart` runs erasure, export and retention
through real repositories, and `test/readme_quick_start_test.dart` runs the
snippet above.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
