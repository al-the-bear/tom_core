/// One copy per content, a quota per owner, and a sweep of files no row
/// refers to: [TomDeduplicatingBlobStore] in front of a directory.
///
/// The store is used like any [TomBlobStore]. Underneath it keeps a
/// [TomBlobLedger] — every logical key, whose it is and which content it
/// names — and the bytes once per SHA-256 in the content store. That ledger is
/// what makes the other two things possible: a [TomBlobQuota] is a sum over an
/// owner's entries, and a [TomBlobOrphanSweep] walks the entries and asks the
/// rows which ones they still name.
///
/// The example uses [TomMemoryBlobLedger] and a [TomBlobReferenceSource] over a
/// set of keys; a deployment uses [TomSqlBlobLedger] (the `tom_blob_ledger` and
/// `tom_blob_content` tables) and [TomRepositoryBlobReferences] over the
/// repositories whose entities carry `@TomFileReference` columns.
///
/// Run with `dart run example/file_storage/deduplicating_store_example.dart`.
/// Every step checks its own result and the run fails when one does not hold.
/// The same behaviour is covered by `test/deduplicating_blob_store_test.dart`
/// and `test/deduplicating_blob_store_db_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

/// The rows of an application, reduced to the file keys they hold.
class AttachedFiles extends TomBlobReferenceSource {
  /// Rows naming [keys].
  AttachedFiles(this.keys);

  /// The keys the rows hold.
  final Set<String> keys;

  @override
  Future<Set<String>> referenced(List<String> keys) async =>
      keys.where(this.keys.contains).toSet();
}

/// How many files the content store physically holds.
Future<int> filesIn(Directory root) => root
    .list(recursive: true)
    .where((e) => e is File && !e.path.contains(TomBlobStore.auxiliaryMarker))
    .length;

Future<void> run(Directory root) async {
  var now = DateTime.utc(2026, 10, 27, 9);
  final ledger = TomMemoryBlobLedger();
  final store = TomDeduplicatingBlobStore(
    content: TomDirectoryBlobStore(root),
    ledger: ledger,
    quota: const TomBlobQuota(maxCount: 3, maxBytes: 64),
    reclaimGrace: const Duration(minutes: 10),
    clock: () => now,
  );

  // 1. The same bytes under two keys are stored once.
  final logo = utf8.encode('<svg>logo</svg>');
  await TomDeduplicatingBlobStore.runAs('ada', () async {
    await store.putBytes(key: 'uploads/ada/logo.svg', bytes: logo);
    await store.putBytes(key: 'uploads/ada/logo-copy.svg', bytes: logo);
  });
  print('1. two keys, files on disk   : ${await filesIn(root)}');
  check(await filesIn(root) == 1, 'identical content is stored once');

  // 2. A copy is a ledger entry: no bytes move.
  await TomDeduplicatingBlobStore.runAs(
    'bob',
    () => store.copy('uploads/ada/logo.svg', 'uploads/bob/logo.svg'),
  );
  final digest = (await store.describe('uploads/bob/logo.svg'))!.digest;
  print('2. keys naming the content   : ${await ledger.referencesTo(digest)}');
  check(
    await ledger.referencesTo(digest) == 3 && await filesIn(root) == 1,
    'the copy names the same content and stores nothing',
  );

  // 3. Each owner is charged for what it holds — logical bytes, so a shared
  //    content still counts against everyone holding it.
  final usage = await ledger.usageOf('ada');
  print('3. ada holds                 : $usage');
  check(
    usage.count == 2 && usage.bytes == logo.length * 2,
    'ada is charged for both of her keys',
  );

  // 4. A write past the quota is refused, and leaves nothing behind.
  var refused = '';
  try {
    await TomDeduplicatingBlobStore.runAs(
      'ada',
      () =>
          store.putBytes(key: 'uploads/ada/big.bin', bytes: List.filled(40, 1)),
    );
  } on TomStorageException catch (e) {
    refused = e.key;
  }
  print('4. too large for ada         : $refused');
  check(
    refused == 'storage.quota.bytes_exceeded' &&
        !await store.exists('uploads/ada/big.bin') &&
        await filesIn(root) == 1,
    'the write past the quota was refused and left no file',
  );

  // 5. Two days on, the sweep deletes what no row refers to: the copy Ada
  //    uploaded and never attached. The rows name the other two keys.
  now = now.add(const Duration(days: 2));
  final sweep = TomBlobOrphanSweep(
    store: store,
    sources: [
      AttachedFiles({'uploads/ada/logo.svg', 'uploads/bob/logo.svg'}),
    ],
    prefixes: const ['uploads'],
  );
  final report = await sweep.sweep(now: now);
  print('5. sweep                     : $report');
  check(
    report.deleted.single == 'uploads/ada/logo-copy.svg' &&
        await filesIn(root) == 1,
    'the unattached key went, and its content stays for the attached ones',
  );

  // 6. Once no key names a content, the reclaim deletes its bytes — but only
  //    once nothing has claimed it for the grace. Ada uploads the logo again,
  //    which claims the content anew, and then deletes every key naming it.
  await TomDeduplicatingBlobStore.runAs(
    'ada',
    () => store.putBytes(key: 'uploads/ada/again.svg', bytes: logo),
  );
  for (final key in [
    'uploads/ada/logo.svg',
    'uploads/bob/logo.svg',
    'uploads/ada/again.svg',
  ]) {
    await store.delete(key);
  }
  final early = await store.reclaim(now: now.add(const Duration(minutes: 5)));
  final late = await store.reclaim(now: now.add(const Duration(minutes: 11)));
  print('6. reclaimed within / after  : $early / $late');
  check(
    early == 0 && late == 1 && await filesIn(root) == 0,
    'the content went only once the grace after its last claim had passed',
  );

  print('\nDeduplicating store example completed.');
}

void main() async {
  final root = await Directory.systemTemp.createTemp('tom_dedup_example_');
  try {
    await run(root);
  } finally {
    await root.delete(recursive: true);
  }
}
