/// The export register, the per-owner quota, the retention purge and the email
/// channel, without a database: the in-memory register and store, and a memory
/// message transport. The SQL register runs in `export_register_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/sql_text.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomExportException>().having((e) => e.key, 'key', key));

/// A report of [rows] rows; its CSV size grows with them.
TomTabularResult _report(int rows, {String title = 'Sales'}) =>
    TomTabularResult.single(
      title: title,
      section: TomTabularSection.ofRows(
        [TomTabularColumn('line', label: 'Line')],
        [
          for (var i = 0; i < rows; i++) TomTabularRow(['row $i']),
        ],
      ),
    );

void main() {
  group('the register records what storeAs stores', () {
    test('owner, size, media type and title', () async {
      final register = TomMemoryExportRegister();
      final service = TomExportService(
        store: TomMemoryExportStore(),
        register: register,
      );
      final stored = await service.storeAs(
        _report(2),
        'csv',
        key: 'a.csv',
        owner: 'ada',
      );
      final record = (await register.find('a.csv'))!;
      expect(record.owner, 'ada');
      expect(record.byteCount, stored.byteCount);
      expect(record.mediaType, stored.mediaType);
      expect(record.title, 'Sales');
      expect(await register.usageOf('ada'), isA<TomExportUsage>());
      expect((await register.usageOf('ada')).count, 1);

      expect(await service.deleteStored('a.csv'), isTrue);
      expect(await register.find('a.csv'), isNull);
    });

    test('a quota needs a register', () {
      expect(
        () => TomExportService(
          store: TomMemoryExportStore(),
          quota: const TomExportQuota(maxCount: 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('the per-owner quota', () {
    late TomMemoryExportStore store;
    late TomMemoryExportRegister register;
    TomExportService service(TomExportQuota quota) =>
        TomExportService(store: store, register: register, quota: quota);

    setUp(() {
      store = TomMemoryExportStore();
      register = TomMemoryExportRegister();
    });

    test(
      'counts exports per owner, and replacing one is not another',
      () async {
        final limited = service(const TomExportQuota(maxCount: 2));
        await limited.storeAs(_report(1), 'csv', key: 'a.csv', owner: 'ada');
        await limited.storeAs(_report(1), 'csv', key: 'b.csv', owner: 'ada');
        await expectLater(
          limited.storeAs(_report(1), 'csv', key: 'c.csv', owner: 'ada'),
          _throwsKey('export.quota.count_exceeded'),
        );
        expect(
          await store.exists('c.csv'),
          isFalse,
          reason: 'nothing rendered',
        );
        // Another owner, and an export of no one, are counted apart.
        await limited.storeAs(_report(1), 'csv', key: 'd.csv', owner: 'bob');
        await limited.storeAs(_report(1), 'csv', key: 'e.csv');
        // Replacing a held key adds no export.
        await limited.storeAs(_report(3), 'csv', key: 'a.csv', owner: 'ada');
        expect((await register.usageOf('ada')).count, 2);
      },
    );

    test(
      'a store taking the owner past the bytes is undone and refused',
      () async {
        final small = (await service(
          const TomExportQuota(),
        ).storeAs(_report(1), 'csv', key: 'probe.csv', owner: 'x')).byteCount;
        final limited = service(TomExportQuota(maxBytes: small * 3));
        await limited.storeAs(_report(1), 'csv', key: 'a.csv', owner: 'ada');
        await expectLater(
          limited.storeAs(_report(50), 'csv', key: 'big.csv', owner: 'ada'),
          _throwsKey('export.quota.bytes_exceeded'),
        );
        expect(await store.exists('big.csv'), isFalse);
        expect(await register.find('big.csv'), isNull);
        expect((await register.usageOf('ada')).count, 1);

        // A full owner is refused before anything is rendered.
        await limited.storeAs(_report(1), 'csv', key: 'b.csv', owner: 'ada');
        await limited.storeAs(_report(1), 'csv', key: 'c.csv', owner: 'ada');
        await expectLater(
          limited.storeAs(_report(1), 'csv', key: 'd.csv', owner: 'ada'),
          _throwsKey('export.quota.bytes_exceeded'),
        );
      },
    );
  });

  group('the retention purge', () {
    test('deletes exports older than the age, bytes and record', () async {
      final store = TomMemoryExportStore();
      final register = TomMemoryExportRegister();
      final now = DateTime.utc(2026, 10, 26, 12);
      for (final (key, age) in [
        ('old1.csv', 40),
        ('old2.csv', 31),
        ('new.csv', 2),
      ]) {
        await store.store(
          key: key,
          bytes: Stream.value([1, 2, 3]),
          mediaType: 'text/csv',
        );
        await register.record(
          TomExportRecord(
            key: key,
            owner: 'ada',
            mediaType: 'text/csv',
            byteCount: 3,
            storedAt: now.subtract(Duration(days: age)),
          ),
        );
      }
      final retention = TomExportRetention(
        store: store,
        register: register,
        maxAge: const Duration(days: 30),
        batchSize: 1,
      );

      expect(await retention.purge(now: now), 2);
      expect(await store.exists('old1.csv'), isFalse);
      expect(await store.exists('old2.csv'), isFalse);
      expect(await store.exists('new.csv'), isTrue);
      expect((await register.ownedBy('ada')).map((r) => r.key), ['new.csv']);
      expect(await retention.purge(now: now), 0);
    });

    test('runs as a scheduled job', () async {
      final store = TomMemoryExportStore();
      final register = TomMemoryExportRegister();
      await store.store(
        key: 'old.csv',
        bytes: Stream.value([1]),
        mediaType: 'text/csv',
      );
      await register.record(
        TomExportRecord(
          key: 'old.csv',
          owner: '',
          mediaType: 'text/csv',
          byteCount: 1,
          storedAt: DateTime.utc(2020),
        ),
      );
      final retention = TomExportRetention(
        store: store,
        register: register,
        maxAge: const Duration(days: 1),
      );
      var now = DateTime.utc(2026, 10, 26, 12);
      final scheduler = TomScheduler(
        store: TomMemoryJobStore(),
        dispatcher: const TomInlineJobDispatcher(),
        clock: () => now,
        onAlert: (_) {},
      );
      addTearDown(scheduler.close);
      final job = retention.jobDefinition(
        schedule: TomIntervalSchedule(const Duration(minutes: 30)),
      );
      expect(job.name, 'tom.export.purge');
      scheduler.register(job);
      await scheduler.tick();
      now = now.add(const Duration(minutes: 31));
      await scheduler.tick();
      await scheduler.drain();
      expect(await store.exists('old.csv'), isFalse);
    });

    test('an empty age or batch is refused', () {
      expect(
        () => TomExportRetention(
          store: TomMemoryExportStore(),
          register: TomMemoryExportRegister(),
          maxAge: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });

  group('the email channel', () {
    late TomMemoryExportStore store;
    late TomMemoryMessageTransport transport;
    late TomMessageOutbox outbox;
    late TomStoredExport stored;

    setUp(() async {
      store = TomMemoryExportStore();
      transport = TomMemoryMessageTransport();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        store: TomMemoryJobStore(),
      );
      stored = await TomExportService(
        store: store,
      ).storeAs(_report(3), 'csv', key: '2026/10/26/sales.csv');
    });
    tearDown(() => outbox.close());

    final ada = TomRecipient('ada@example.com');

    test('attaches a small export, read back from the store', () async {
      final delivery = TomExportEmailDelivery(store: store, outbox: outbox);
      await delivery.send(stored, to: [ada], subject: 'Sales');
      await outbox.tick();
      final sent = transport.sent.single;
      expect(sent.subject, 'Sales');
      expect(sent.attachments.single.fileName, 'sales.csv');
      expect(sent.attachments.single.bytes.length, stored.byteCount);
      expect(sent.attachments.single.mediaType, stored.mediaType);
    });

    test('links an export beyond the attachment limit', () async {
      final delivery = TomExportEmailDelivery(
        store: store,
        outbox: outbox,
        maxAttachmentBytes: 1,
        linkFor: (export) =>
            Uri.parse('https://reports.example.com/${export.key}'),
      );
      final message = await delivery.send(
        stored,
        to: [ada],
        subject: 'Sales',
        text: 'Ready.',
      );
      expect(message.attachments, isEmpty);
      expect(
        message.bodies.single.content,
        'Ready.\n\nhttps://reports.example.com/2026/10/26/sales.csv',
      );
    });

    test('refuses what it cannot deliver, before queueing', () async {
      final noLink = TomExportEmailDelivery(
        store: store,
        outbox: outbox,
        maxAttachmentBytes: 1,
      );
      await expectLater(
        noLink.send(stored, to: [ada], subject: 's'),
        _throwsKey('export.email.too_large'),
      );
      await expectLater(
        noLink.send(
          stored,
          to: [ada],
          subject: 's',
          mode: TomExportEmailMode.link,
        ),
        _throwsKey('export.email.no_link'),
      );
      await expectLater(
        noLink.send(stored, to: const [], subject: 's'),
        _throwsKey('export.email.no_recipient'),
      );
      await outbox.tick();
      expect(transport.sent, isEmpty);
    });
  });

  test('the shipped migration is the DDL the register creates', () {
    expect(
      normaliseSql(readMigration('export', '[1]-create_tom_export.sql')),
      normaliseSql(exportRegisterTableDdl(defaultExportRegisterTable)),
    );
  });
}
