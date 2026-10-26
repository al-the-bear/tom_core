/// The register of stored exports, and what it makes possible: a per-owner
/// quota and a purge by age.
///
/// A store that keeps every export a deployment ever rendered fills up, and
/// [TomExportStore] cannot answer the question retention asks: it holds bytes
/// under keys and deliberately has no listing, and a listing would not say
/// *whose* an export is or *how old* anyway. The [TomExportRegister] is the
/// record that does — one [TomExportRecord] per export, written by
/// [TomExportService.storeAs] beside the bytes. A [TomExportQuota] is then a
/// sum over an owner's records, and [TomExportRetention] a query over their
/// ages that deletes key by key, so it runs on every backend.
///
/// The example uses [TomMemoryExportRegister]; a deployment uses
/// [TomSqlExportRegister], one row per export in `tom_export`, with the same
/// calls.
///
/// Run with `dart run example/export/export_retention.dart`. Every step checks
/// its own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

/// A day's worth of numbers, standing in for whatever the report queries.
TomTabularResult dailySales(String day) => TomTabularResult.single(
  title: 'Daily sales',
  metadata: {'Day': day},
  section: TomTabularSection.ofMaps(
    [
      TomTabularColumn('region', label: 'Region'),
      TomTabularColumn('total', label: 'Total', type: TomColumnType.decimal),
    ],
    Stream.fromIterable(const [
      {'region': 'North', 'total': 1200.5},
      {'region': 'South', 'total': 980.0},
    ]),
  ),
);

/// Three days of reports, two of them old enough to go by step 5's cutoff.
final _renderedOn = {
  'sales-08': DateTime.utc(2026, 7, 8),
  'sales-09': DateTime.utc(2026, 7, 9),
  'sales-15': DateTime.utc(2026, 7, 15),
};

/// Stores the three reports through [service] for `ada`, and answers their
/// keys in the order of [_renderedOn].
Future<List<String>> renderInto(TomExportService service) async => [
  for (final entry in _renderedOn.entries)
    (await service.storeAs(
      dailySales(entry.key),
      'csv',
      key: service.keyFor(entry.key, 'csv', partitionOn: entry.value),
      owner: 'ada',
    )).key,
];

/// Re-records [keys] as stored on the days their reports were rendered for.
///
/// A record is stamped with the moment of storing, which in a run of this
/// example is now. Re-recording is what lets a purge by age be shown without
/// waiting a week; `record` replaces the record under the same key.
Future<void> backdate(TomExportRegister register, List<String> keys) async {
  final days = _renderedOn.values.toList();
  for (var i = 0; i < keys.length; i++) {
    final record = (await register.find(keys[i]))!;
    await register.record(
      TomExportRecord(
        key: record.key,
        owner: record.owner,
        mediaType: record.mediaType,
        byteCount: record.byteCount,
        storedAt: days[i],
        title: record.title,
      ),
    );
  }
}

/// Runs [store] and answers the key of the [TomExportException] it throws, or
/// `''` when it throws none.
Future<String> refusalOf(Future<Object?> Function() store) async {
  try {
    await store();
  } on TomExportException catch (error) {
    return error.key;
  }
  return '';
}

Future<void> run() async {
  // 1. A service with a register records every export it stores: the owner it
  //    counts against, its size, its media type, when, and the report's title.
  final store = TomMemoryExportStore();
  final register = TomMemoryExportRegister();
  final service = TomExportService(store: store, register: register);
  final keys = await renderInto(service);
  final usage = await register.usageOf('ada');
  print('1. recorded for ada          : $usage');
  check(usage.count == 3, 'the three stored exports were recorded');
  final first = (await register.find(keys.first))!;
  check(
    first.owner == 'ada' &&
        first.title == 'Daily sales' &&
        first.mediaType == 'text/csv; charset=utf-8',
    'a record names the owner, the title and the media type',
  );

  // 2. The register answers what the store cannot: which exports an owner
  //    holds. `TomExportStore` is store / open / exists / delete /
  //    deletePrefix, and none of them enumerates.
  final owned = await register.ownedBy('ada');
  print('2. ada holds                 : ${owned.length} exports');
  for (final record in owned) {
    print('   key                       : ${record.key}');
  }
  check(
    owned.map((r) => r.key).toSet().containsAll(keys),
    'the register lists every export stored for the owner',
  );

  // 3. A count quota. Ada holds three of three, so a fourth is refused before
  //    a row is rendered — a full owner costs no render. Storing over a key she
  //    already holds is a replacement, counted without the export it replaces,
  //    so it passes.
  final capped = TomExportService(
    store: store,
    register: register,
    quota: const TomExportQuota(maxCount: 3),
  );
  final fourthKey = capped.keyFor(
    'sales-16',
    'csv',
    partitionOn: DateTime.utc(2026, 7, 16),
  );
  final countRefusal = await refusalOf(
    () => capped.storeAs(
      dailySales('sales-16'),
      'csv',
      key: fourthKey,
      owner: 'ada',
    ),
  );
  print('3. a fourth export           : $countRefusal');
  check(
    countRefusal == 'export.quota.count_exceeded',
    'the count quota refuses a fourth export',
  );
  check(!await store.exists(fourthKey), 'and nothing was stored for it');
  final replaced = await capped.storeAs(
    dailySales('sales-15'),
    'csv',
    key: keys.last,
    owner: 'ada',
  );
  print('   replacing one she holds   : stored ${replaced.key}');
  check(
    (await register.usageOf('ada')).count == 3,
    'a replacement leaves the count where it was',
  );

  // 4. A byte quota. The size of an export is known only once it is stored,
  //    so a store that takes the owner past the limit is undone — the bytes
  //    deleted, the record removed — and refused.
  final held = await register.usageOf('ada');
  final tight = TomExportService(
    store: store,
    register: register,
    quota: TomExportQuota(maxBytes: held.bytes + 10),
  );
  final bytesKey = tight.keyFor(
    'sales-17',
    'csv',
    partitionOn: DateTime.utc(2026, 7, 17),
  );
  final bytesRefusal = await refusalOf(
    () => tight.storeAs(
      dailySales('sales-17'),
      'csv',
      key: bytesKey,
      owner: 'ada',
    ),
  );
  print('4. past the byte limit       : $bytesRefusal');
  check(
    bytesRefusal == 'export.quota.bytes_exceeded',
    'the byte quota refuses an export that does not fit',
  );
  check(
    !await store.exists(bytesKey) && await register.find(bytesKey) == null,
    'the refused export was deleted again and left no record',
  );

  // 5. The purge. Exports older than `maxAge` go — the bytes, then the record
  //    — found through the register, not by walking the store. With the
  //    records dated to their days and "now" on 16 July, a five-day age takes
  //    the 8th and the 9th and keeps the 15th.
  await backdate(register, keys);
  final retention = TomExportRetention(
    store: store,
    register: register,
    maxAge: const Duration(days: 5),
  );
  final purged = await retention.purge(now: DateTime.utc(2026, 7, 16));
  print('5. purged                    : $purged exports');
  check(purged == 2, 'the two exports older than five days went');
  check(
    !await store.exists(keys.first) && await register.find(keys.first) == null,
    'an expired export lost its bytes and its record',
  );
  check(
    await store.exists(keys.last) && (await register.usageOf('ada')).count == 1,
    'the current export survived, and the quota counts only it',
  );

  // 6. The same purge over a blob-backed store. It deletes key by key, so it
  //    needs no prefix delete and no listing from the backend — it runs on
  //    every store the service can write to.
  final blobStore = TomBlobExportStore(
    TomMemoryBlobStore(),
    keyPrefix: 'exports',
  );
  final blobRegister = TomMemoryExportRegister();
  final blobKeys = await renderInto(
    TomExportService(store: blobStore, register: blobRegister),
  );
  await backdate(blobRegister, blobKeys);
  final blobPurged = await TomExportRetention(
    store: blobStore,
    register: blobRegister,
    maxAge: const Duration(days: 5),
  ).purge(now: DateTime.utc(2026, 7, 16));
  print('6. purged from the blob store: $blobPurged exports');
  check(blobPurged == 2, 'the same two days went on the other backend');
  check(
    await blobStore.exists(blobKeys.last) &&
        !await blobStore.exists(blobKeys.first),
    'and the current export survived here too',
  );

  // 7. On a schedule. `jobDefinition` is the purge as a job — hourly unless
  //    told otherwise — and its body holds the retention object, so the
  //    scheduler runs it in its own isolate with the inline dispatcher. How
  //    long an export is kept stays the deployment's decision: `maxAge` has no
  //    default.
  await backdate(register, [keys.last]);
  var now = DateTime.utc(2026, 7, 21, 12);
  final scheduler = TomScheduler(
    store: TomMemoryJobStore(),
    dispatcher: const TomInlineJobDispatcher(),
    clock: () => now,
    onAlert: (_) {},
  );
  final job = retention.jobDefinition();
  scheduler.register(job);
  await scheduler.tick();
  now = now.add(const Duration(hours: 1, minutes: 1));
  await scheduler.tick();
  await scheduler.drain();
  await scheduler.close();
  print('7. job                       : ${job.name}');
  check(job.name == 'tom.export.purge', 'the job has its default name');
  check(
    !await store.exists(keys.last) &&
        (await register.usageOf('ada')).count == 0,
    'the scheduled purge removed the export once it was past its age',
  );

  print('\nExport retention example completed.');
}

void main() async {
  await run();
}
