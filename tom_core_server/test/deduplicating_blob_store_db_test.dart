/// The SQL ledger behind the deduplicating blob store, and the orphan sweep
/// over a real repository's file columns, against a live database.
///
/// The content store is a directory on the file system, so the whole chain —
/// rows naming keys, the ledger naming contents, files holding bytes — is
/// real. `@Tags(['db'])`; skips itself when no server is reachable.
@Tags(['db'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomStorageException>().having((e) => e.key, 'key', key));

Stream<List<int>> _text(String text) => Stream.value(utf8.encode(text));

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('TomSqlBlobLedger', () {
    late TomDataSourceInfo dsi;
    late TomSqlBlobLedger ledger;
    late Directory root;
    late DateTime now;

    TomDeduplicatingBlobStore store({TomBlobQuota? quota, String owner = ''}) =>
        TomDeduplicatingBlobStore(
          content: TomDirectoryBlobStore(root),
          ledger: ledger,
          quota: quota,
          ownerOf: () => owner,
          reclaimGrace: const Duration(minutes: 10),
          clock: () => now,
        );

    Future<int> files() async => await root
        .list(recursive: true)
        .where(
          (e) => e is File && !e.path.contains(TomBlobStore.auxiliaryMarker),
        )
        .length;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    setUp(() async {
      await TestDatabase.execute(
        dsi.datasource,
        'DROP TABLE IF EXISTS $defaultBlobLedgerTable',
      );
      await TestDatabase.execute(
        dsi.datasource,
        'DROP TABLE IF EXISTS $defaultBlobContentTable',
      );
      ledger = TomSqlBlobLedger(dsi.datasource);
      root = await Directory(
        '${Directory.current.path}/../../../ztmp',
      ).createTemp('tom_core_dedup_db_test_');
      now = DateTime.utc(2026, 10, 27, 12);
    });

    tearDown(() => root.delete(recursive: true));

    tearDownAll(TestDatabase.reset);

    test('creates its tables, deduplicates, and reads back', () async {
      final dedup = store();
      final a = await dedup.put(
        key: 'docs/a_1.txt',
        bytes: _text('same'),
        mediaType: 'text/plain',
        fileName: 'a.txt',
      );
      await dedup.put(key: 'docs/b.txt', bytes: _text('same'));
      expect(await files(), 1);
      expect(await ledger.referencesTo(a.digest), 2);

      final entry = (await ledger.find('docs/a_1.txt'))!;
      expect(entry.digest, a.digest);
      expect(entry.mediaType, 'text/plain');
      expect(entry.fileName, 'a.txt');
      expect(entry.storedAt, now);
      expect(utf8.decode(await dedup.getBytes('docs/b.txt')), 'same');

      await dedup.copy('docs/a_1.txt', 'docs/c.txt');
      await dedup.move('docs/c.txt', 'docs/d.txt');
      expect(await dedup.exists('docs/c.txt'), isFalse);
      expect(await ledger.referencesTo(a.digest), 3);
      expect(await files(), 1);
    });

    test(
      'a prefix delete matches by segment, with _ taken literally',
      () async {
        final dedup = store();
        await dedup.put(key: 'p_1/x', bytes: _text('1'));
        await dedup.put(key: 'pa1/x', bytes: _text('2'));
        await dedup.put(key: 'p_1', bytes: _text('3'));
        expect(await dedup.deletePrefix('p_1'), 2);
        expect(await dedup.exists('pa1/x'), isTrue);
      },
    );

    test(
      'reclaim takes unnamed content after the grace, row before bytes',
      () async {
        final dedup = store();
        await dedup.put(key: 'a', bytes: _text('kept'));
        await dedup.put(key: 'b', bytes: _text('kept'));
        await dedup.put(key: 'c', bytes: _text('gone'));
        await dedup.delete('a');
        await dedup.delete('c');
        expect(
          await dedup.reclaim(now: now.add(const Duration(minutes: 5))),
          0,
        );
        expect(
          await dedup.reclaim(now: now.add(const Duration(minutes: 11))),
          1,
        );
        expect(await files(), 1);
        expect(utf8.decode(await dedup.getBytes('b')), 'kept');
      },
    );

    test('a claim keeps content from a reclaim that read it earlier', () async {
      final dedup = store();
      await dedup.put(key: 'a', bytes: _text('raced'));
      await dedup.delete('a');
      final cutoff = now.add(const Duration(minutes: 1));
      final candidates = await ledger.reclaimable(cutoff);
      expect(candidates, hasLength(1));
      // A write of the same bytes claims the content after the reclaim read it.
      await ledger.claimContent(
        candidates.single.digest,
        byteCount: 5,
        contentKey: 'unused',
        now: cutoff.add(const Duration(seconds: 1)),
      );
      expect(await ledger.dropContent(candidates.single, cutoff), isFalse);
      // Named content is never dropped, however old its claim.
      await dedup.put(key: 'b', bytes: _text('raced'));
      expect(
        await ledger.dropContent(
          candidates.single,
          now.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('the quota sums an owner\'s rows', () async {
      final dedup = store(
        quota: const TomBlobQuota(maxCount: 2, maxBytes: 8),
        owner: 'ada',
      );
      await dedup.put(key: 'a', bytes: _text('1234'));
      await expectLater(
        dedup.put(key: 'b', bytes: _text('12345')),
        _throwsKey('storage.quota.bytes_exceeded'),
      );
      await dedup.put(key: 'b', bytes: _text('1234'));
      await expectLater(
        dedup.put(key: 'c', bytes: _text('1')),
        _throwsKey('storage.quota.count_exceeded'),
      );
      final usage = await ledger.usageOf('ada');
      expect((usage.count, usage.bytes), (2, 8));
      expect(await files(), 1);
    });

    test('pages the stored keys in key order for the sweep', () async {
      final dedup = store();
      for (final key in ['c', 'a', 'b']) {
        await dedup.put(key: key, bytes: _text(key));
      }
      final later = now.add(const Duration(seconds: 1));
      final first = await ledger.storedBefore(later, limit: 2);
      expect(first.map((e) => e.key), ['a', 'b']);
      final rest = await ledger.storedBefore(later, after: 'b', limit: 2);
      expect(rest.map((e) => e.key), ['c']);
      expect(await ledger.storedBefore(now), isEmpty);
    });
  }, skip: skipReason);

  group('the orphan sweep over a repository', () {
    late TomDataSourceInfo dsi;
    late FixtureDocumentRepository repo;
    late TomDeduplicatingBlobStore dedup;
    late Directory root;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureDocumentTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureDocument(dsi);
      final ledger = TomSqlBlobLedger(dsi.datasource);
      await ledger.deleteAll();
      root = await Directory(
        '${Directory.current.path}/../../../ztmp',
      ).createTemp('tom_core_sweep_db_test_');
      dedup = TomDeduplicatingBlobStore(
        content: TomDirectoryBlobStore(root),
        ledger: ledger,
        reclaimGrace: const Duration(minutes: 1),
      );
      TomBlobStoreInfo.register('fixture', dedup, asDefault: true);
      repo = FixtureDocumentRepository();
    });

    tearDown(() async {
      await TomBlobStoreInfo.closeAll();
      await root.delete(recursive: true);
    });

    tearDownAll(TestDatabase.reset);

    test('keeps what a row names and deletes what none does', () async {
      final saved = await repo.saveFile(
        FixtureDocumentRecord()..title = 'kept',
        'attachment',
        _text('attached'),
      );
      final secret = await repo.saveFile(
        saved,
        'secretAttachment',
        _text('also attached'),
      );
      await dedup.put(
        key: 'fixture/attachment/abandoned.txt',
        bytes: _text('orphan'),
      );
      await dedup.put(key: 'elsewhere/x.txt', bytes: _text('not ours'));

      final sweep = TomBlobOrphanSweep(
        store: dedup,
        sources: [
          TomRepositoryBlobReferences<FixtureDocumentRecord, int>(repo),
        ],
        prefixes: const ['fixture'],
      );
      // Within the grace, nothing is considered.
      expect((await sweep.sweep()).scanned, 0);

      final report = await sweep.sweep(
        now: DateTime.now().add(const Duration(days: 2)),
      );
      expect(report.deleted, ['fixture/attachment/abandoned.txt']);
      expect(report.scanned, 3);
      expect(report.reclaimed, 1);
      expect(await dedup.exists(secret.attachment!), isTrue);
      expect(await dedup.exists(secret.secretAttachment!), isTrue);
      expect(await dedup.exists('elsewhere/x.txt'), isTrue);
      expect(utf8.decode(await dedup.getBytes(secret.attachment!)), 'attached');
    });
  }, skip: skipReason);
}
