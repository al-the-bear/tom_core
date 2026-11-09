/// TomRequestCache: values kept for one request, emptied by a write.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  group('TomRequestCache', () {
    test('RQC-1: within run a key is computed once, its lookups sharing the '
        'result', () async {
      var computed = 0;
      Future<int> lookup() =>
          TomRequestCache.memo(#key, () async => ++computed);
      await TomRequestCache.run(() async {
        expect(await Future.wait([lookup(), lookup()]), [1, 1]);
        expect(await lookup(), 1);
      });
      expect(computed, 1);
    });

    test('RQC-2: outside run nothing is kept', () async {
      var computed = 0;
      Future<int> lookup() =>
          TomRequestCache.memo(#key, () async => ++computed);
      expect(TomRequestCache.isActive, isFalse);
      await lookup();
      await lookup();
      expect(computed, 2);
    });

    test('RQC-3: invalidate empties the cache, and a failed lookup is not '
        'kept', () async {
      var computed = 0;
      await TomRequestCache.run(() async {
        await TomRequestCache.memo(#key, () async => ++computed);
        TomRequestCache.invalidate();
        await TomRequestCache.memo(#key, () async => ++computed);
        expect(computed, 2);

        await expectLater(
          TomRequestCache.memo(#failing, () async => throw StateError('no')),
          throwsStateError,
        );
        expect(
          await TomRequestCache.memo(#failing, () async => 'second try'),
          'second try',
        );
      });
    });

    test('RQC-4: two runs never share a cache', () async {
      var computed = 0;
      Future<int> lookup() =>
          TomRequestCache.memo(#key, () async => ++computed);
      await Future.wait([
        TomRequestCache.run(lookup),
        TomRequestCache.run(lookup),
      ]);
      expect(computed, 2);
    });

    test('RQC-5: a write to a bookkeeping table keeps the cache, any other '
        'write empties it', () async {
      var computed = 0;
      Future<int> lookup() =>
          TomRequestCache.memo(#key, () async => ++computed);
      await TomRequestCache.run(() async {
        await lookup();
        TomRequestCache.invalidateAfter(
          'INSERT INTO tom_blob_chunk (upload_id) VALUES (:id)',
        );
        TomRequestCache.invalidateAfter(
          'REPLACE INTO `tom_blob` (k) VALUES (1)',
        );
        TomRequestCache.invalidateAfter(
          'UPDATE app.tom_job_run SET state = :s WHERE id = :id',
        );
        await lookup();
        expect(computed, 1);
        TomRequestCache.invalidateAfter(
          'INSERT INTO tom_principal_resource_grant (principal_id) VALUES (?)',
        );
        await lookup();
        expect(computed, 2);
        TomRequestCache.invalidateAfter('ROLLBACK');
        await lookup();
        expect(computed, 3);
      });
    });

    test('RQC-6: the bookkeeping tables are the framework-owned tables', () {
      expect(TomRequestCache.bookkeepingTables, {
        for (final table in frameworkOwnedTables()) table.name,
      });
    });
  });
}
