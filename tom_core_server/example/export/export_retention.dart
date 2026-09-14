/// Reclaiming what stored exports accumulate, and who owns the enumeration.
///
/// A store that keeps every export a deployment ever rendered fills up. The
/// module answers half of that itself: [TomExportService.keyFor] partitions by
/// day, and [TomExportStore.deletePrefix] reclaims a partition in one call.
///
/// It does **not** answer the other half. The store contract has no listing —
/// no `list`, no `keysUnder`, nothing that walks the key space — and this file
/// is as much about that absence as about the call. The reason is that a
/// listing is the wrong question to ask storage: over an object store it is a
/// paginated call whose cost the caller has to understand, over a database
/// blob table it is a scan, and neither answers what retention actually needs
/// to know — *which* export, rendered for *whom*, is now old enough to go.
///
/// So the enumeration belongs to the deployment, in the record it almost
/// certainly keeps already: the descriptor [TomExportStore.store] returns
/// carries the key, the media type, the byte count and the time, which is a
/// row. The `_ExportRegister` below stands in for that table. It is deliberately
/// not a framework type — a real one has a tenant, a requesting user and a
/// report id on it, and none of those are storage's business.
///
/// That split is what makes retention work on *every* backend rather than the
/// ones that can enumerate. Step 6 runs the same pass against
/// `TomBlobExportStore`, which cannot prefix-delete at all, and it reclaims the
/// same partition.
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

/// The deployment's own record of what it stored — one row per export.
///
/// A row per export is what a system that lets a user re-download yesterday's
/// report already has; retention is then a query over it rather than a walk of
/// the storage. The framework does not ship this type because the columns that
/// matter are the application's: who asked, which report, which tenant.
class _ExportRegister {
  final List<({TomStoredExport export, DateTime renderedAt})> _rows = [];

  /// Records [export] as rendered at [renderedAt].
  void record(TomStoredExport export, DateTime renderedAt) =>
      _rows.add((export: export, renderedAt: renderedAt));

  /// How many exports are on the register.
  int get length => _rows.length;

  /// The keys recorded, oldest first.
  List<String> get keys => [for (final row in _rows) row.export.key];

  /// The day partitions holding exports rendered before [cutoff].
  ///
  /// A partition rather than a key, because that is the unit a prefix delete
  /// reclaims — one call per day instead of one per export.
  Set<String> partitionsBefore(DateTime cutoff) => {
    for (final row in _rows)
      if (row.renderedAt.isBefore(cutoff))
        row.export.key.split('/').take(3).join('/'),
  };

  /// The keys recorded under [partition].
  List<String> keysUnder(String partition) => [
    for (final row in _rows)
      if (row.export.key.startsWith('$partition/')) row.export.key,
  ];

  /// Drops every row under [partition], and answers how many went.
  int forget(String partition) {
    final before = _rows.length;
    _rows.removeWhere((row) => row.export.key.startsWith('$partition/'));
    return before - _rows.length;
  }
}

/// Renders [reports] into [service], recording each on [register].
Future<void> renderInto(
  TomExportService service,
  _ExportRegister register,
  Map<String, DateTime> reports,
) async {
  for (final entry in reports.entries) {
    final stored = await service.storeAs(
      dailySales(entry.key),
      'csv',
      key: service.keyFor(entry.key, 'csv', partitionOn: entry.value),
    );
    register.record(stored, entry.value);
  }
}

/// Three days of reports, two of them old enough to go by step 3's cutoff.
final _renderedOn = {
  'sales-08': DateTime.utc(2026, 7, 8),
  'sales-09': DateTime.utc(2026, 7, 9),
  'sales-15': DateTime.utc(2026, 7, 15),
};

Future<void> run() async {
  // 1. Store three exports across three day partitions, recording each one as
  //    it is written. The descriptor `storeAs` returns is the row: key, media
  //    type, byte count. Recording it costs the line below and is what makes
  //    every later step possible.
  final store = TomMemoryExportStore();
  final service = TomExportService(store: store);
  final register = _ExportRegister();
  await renderInto(service, register, _renderedOn);
  print('1. stored                    : ${register.length} exports');
  for (final key in register.keys) {
    print('   key                       : $key');
  }
  check(register.length == 3, 'three exports were stored and recorded');
  check(
    register.keys.first == '2026/07/08/sales-08.csv',
    'keyFor partitions by the day the export was rendered for',
  );

  // 2. The store cannot answer "what is in here" — and that is the design, not
  //    a gap. `TomExportStore` is store / open / exists / delete /
  //    deletePrefix; none of them enumerates. What it *can* answer is whether
  //    one key it is given holds something, which is all a download needs.
  final present = await store.exists(register.keys.first);
  print('2. exists(a stored key)      : $present');
  check(present, 'the store answers for a key it is handed');
  check(
    !await store.exists('2026/07/08/never-rendered.csv'),
    'and answers no for one it was not',
  );

  // 3. The register answers it instead. Which partitions hold exports older
  //    than the cutoff is a query over rows, and it is the application's own
  //    columns — not the key space — that decide the answer.
  final cutoff = DateTime.utc(2026, 7, 10);
  final expired = register.partitionsBefore(cutoff);
  print('3. expired partitions       : ${expired.join(', ')}');
  check(
    expired.length == 2 && expired.contains('2026/07/08'),
    'the two days before the cutoff are named, and the later one is not',
  );

  // 4. Reclaim. One `deletePrefix` per partition, and the count it returns is
  //    checked against the rows the register expected — the two halves must
  //    agree, and a mismatch means something wrote to the store behind the
  //    register's back.
  var reclaimed = 0;
  for (final partition in expired) {
    final expectedKeys = register.keysUnder(partition);
    final removed = await store.deletePrefix(partition);
    check(
      removed == expectedKeys.length,
      'the store removed exactly the exports the register recorded under '
      '$partition',
    );
    register.forget(partition);
    reclaimed += removed;
  }
  print('4. reclaimed                 : $reclaimed exports');
  check(reclaimed == 2, 'both expired days went');
  check(
    register.length == 1,
    'the register kept the one that is still current',
  );

  // 5. Nothing else was touched. A prefix that reaches a sibling is an ordinary
  //    convenience everywhere except in a delete, so the match is by key
  //    segment: `2026/07/08` never reaches `2026/07/15`.
  final survivor = register.keys.single;
  print('5. still stored              : $survivor');
  check(await store.exists(survivor), 'the current export survived the purge');
  check(
    !await store.exists('2026/07/08/sales-08.csv'),
    'the expired one is gone',
  );

  // 6. The same pass against a backend that cannot prefix-delete at all.
  //    `TomBlobExportStore` says so through `supportsPrefixDelete`, because
  //    `TomBlobStore` has no enumeration to build one from. The register does
  //    not care: it already knows the keys, so the pass deletes them one at a
  //    time and reclaims the same partition. This is the point of keeping the
  //    record — retention that depends on a storage capability works on the
  //    backends that have it, and retention that depends on the deployment's
  //    own rows works everywhere.
  final blobStore = TomBlobExportStore(
    TomMemoryBlobStore(),
    keyPrefix: 'exports',
  );
  final blobService = TomExportService(store: blobStore);
  final blobRegister = _ExportRegister();
  await renderInto(blobService, blobRegister, _renderedOn);
  print('6. supportsPrefixDelete      : ${blobStore.supportsPrefixDelete}');
  check(
    !blobStore.supportsPrefixDelete,
    'the blob-backed store declares that it cannot reclaim by prefix',
  );

  var deleted = 0;
  for (final partition in blobRegister.partitionsBefore(cutoff)) {
    for (final key in blobRegister.keysUnder(partition)) {
      if (await blobStore.delete(key)) deleted++;
    }
    blobRegister.forget(partition);
  }
  print('   reclaimed key by key      : $deleted exports');
  check(deleted == 2, 'the same two days went, one key at a time');
  check(
    blobRegister.length == 1 &&
        await blobStore.exists(blobRegister.keys.single),
    'and the current export survived here too',
  );

  // 7. Two refusals worth knowing about, both of which turn a silent wrong
  //    answer into a loud one. Calling `deletePrefix` on the blob-backed store
  //    fails rather than answering 0 — "found nothing" and "cannot purge" are
  //    different facts, and a deployment that could not tell them apart would
  //    learn the difference from a disk filling up. An empty prefix is refused
  //    because it names every export there is, and a configuration value that
  //    turned out empty should not empty the store.
  var refusals = 0;
  for (final attempt in <(String, Future<int> Function())>[
    ('unsupported', () => blobStore.deletePrefix('exports/2026')),
    ('empty prefix', () => store.deletePrefix('')),
  ]) {
    try {
      await attempt.$2();
    } on TomExportException catch (error) {
      refusals++;
      print('7. ${attempt.$1.padRight(26)}: ${error.key}');
    }
  }
  check(refusals == 2, 'both refusals are exceptions rather than a zero count');
  check(
    await blobStore.exists(blobRegister.keys.single),
    'the refused prefix delete removed nothing',
  );

  print('\nExport retention example completed.');
}

void main() async {
  await run();
}
