/// The blob store's orphan sweep, asserted where the leak would be.
///
/// `TomDatabaseBlobStore.purgeOrphanedChunks` deletes the chunk rows no
/// manifest refers to — the residue a cleanup that failed between the two
/// deletes leaves behind. The framework shipped it and nothing outside its own
/// tests called it, which makes a documented maintenance operation a slow leak:
/// no read finds the rows, no count reports them, and the first symptom is a
/// table larger than the blobs it holds.
///
/// What is asserted here is the *wiring*, since the sweep itself belongs to
/// `tom_core_server` and is covered there against a live database: that the
/// service calls it and reports the count, and that a store which cannot sweep
/// is refused at wire-up rather than becoming a scheduled no-op. No database, no
/// scheduler.
library;

import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A database blob store whose sweep answers [removed] without a database.
class _CountingBlobStore extends TomDatabaseBlobStore {
  _CountingBlobStore(this.removed)
    : super(_UnreachableDataSource(), createSchema: false);

  /// What the sweep reports.
  final int removed;

  /// How many times the sweep ran.
  int sweeps = 0;

  @override
  Future<int> purgeOrphanedChunks() async {
    sweeps++;
    return removed;
  }
}

/// A data source that fails the test if a statement reaches it.
class _UnreachableDataSource implements TomDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('the sweep reached its data source');
}

void main() {
  group('OpsBlobSweepService', () {
    test('it runs the store\'s sweep and reports what went', () async {
      final store = _CountingBlobStore(7);
      final report = await OpsBlobSweepService(store: store).sweep();

      expect(store.sweeps, 1);
      expect(report.chunksRemoved, 7);
      expect(report.toString(), contains('7'));
    });

    test('zero is the expected reading, and is reported as one', () async {
      // The number a healthy deployment sees every week, and the one worth
      // having in a log: it says every cleanup since the last sweep completed.
      // A service that only reported non-zero results would make "nothing to do"
      // and "the job did not run" the same entry.
      final report = await OpsBlobSweepService(
        store: _CountingBlobStore(0),
      ).sweep();
      expect(report.chunksRemoved, 0);
    });

    test('a backend with no sweep is refused at wire-up', () {
      // The refusal that matters. The sweep is a property of the database
      // backend — a directory store has no chunk rows and an object store has
      // no manifest — so repointing this deployment's `files` store elsewhere
      // does not make the job harmless, it makes it a scheduled no-op that
      // reports success every week. Failing here is the difference between
      // learning that at boot and never learning it.
      TomBlobStoreInfo.stores.clear();
      addTearDown(TomBlobStoreInfo.stores.clear);
      TomBlobStoreInfo.register('files', TomMemoryBlobStore(), asDefault: true);

      expect(
        OpsBlobSweepService.configured,
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'ops.blob_sweep.unsupported_backend')
              .having(
                (e) => e.parameters?['store'],
                'store',
                contains('TomMemoryBlobStore'),
              ),
        ),
      );
    });

    test('a database backend is accepted, by name or by default', () {
      TomBlobStoreInfo.stores.clear();
      addTearDown(TomBlobStoreInfo.stores.clear);
      final store = _CountingBlobStore(0);
      TomBlobStoreInfo.register('files', store, asDefault: true);

      expect(OpsBlobSweepService.configured().store, same(store));
      expect(OpsBlobSweepService.configured('files').store, same(store));
    });
  });
}
