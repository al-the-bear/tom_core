/// Privacy against a live database: erasing a subject across entities through
/// their repositories, exporting what is held about one, applying retention —
/// each step audited — and crypto-shredding the erased subject's values in the
/// audit trail.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureMember,
        FixtureMemberRepository,
        FixturePost,
        FixturePostRepository,
        FixtureVisit,
        FixtureVisitRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _ddl = [
  '''
CREATE TABLE fixture_member (
  id      BIGINT       NOT NULL AUTO_INCREMENT,
  user_id BIGINT       NULL,
  email   VARCHAR(191) NULL,
  PRIMARY KEY (id)
)''',
  '''
CREATE TABLE fixture_post (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  author_id  BIGINT       NULL,
  editor_id  BIGINT       NULL,
  body       VARCHAR(500) NULL,
  title      VARCHAR(191) NULL,
  created_at DATETIME(6)  NULL,
  PRIMARY KEY (id)
)''',
  '''
CREATE TABLE fixture_visit (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  visitor_id BIGINT      NULL,
  at         DATETIME(6) NULL,
  PRIMARY KEY (id)
)''',
];

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSourceInfo info;
  late FixtureMemberRepository members;
  late FixturePostRepository posts;
  late FixtureVisitRepository visits;
  late TomMemoryAuditSink trail;
  late TomSubjectKeys keys;
  final now = DateTime.now().toUtc();

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    info = await TestDatabase.register();
  });

  tearDownAll(() async {
    if (!reachable) return;
    await TestDatabase.reset();
  });

  setUp(() async {
    if (!reachable) return;
    for (final table in ['fixture_member', 'fixture_post', 'fixture_visit']) {
      await info.datasource.executeCommand('DROP TABLE IF EXISTS $table');
    }
    for (final ddl in _ddl) {
      await TestDatabase.execute(info.datasource, ddl);
    }
    final store = TomSqlSubjectKeyStore(TestDatabase.datasourceName);
    await store.deleteAll();
    keys = TomSubjectKeys(
      store: store,
      keys: [TomAesKeyEncryptionKey('kek-1', List.filled(32, 5))],
    );
    TomPrivacy.installSubjectKeys(keys);
    trail = TomMemoryAuditSink();
    TomAuditTrail.install(trail);
    members = FixtureMemberRepository();
    posts = FixturePostRepository();
    visits = FixtureVisitRepository();
    TomPrivacy.register(members);
    TomPrivacy.register(posts);
    TomPrivacy.register(visits);
  });

  tearDown(() {
    TomPrivacy.reset();
    TomAuditTrail.uninstall();
  });

  Future<void> seed() async {
    for (final (user, email) in [(7, 'ada@x.org'), (8, 'bob@x.org')]) {
      await members.save(
        FixtureMember()
          ..userId = user
          ..email = email,
      );
    }
    await posts.save(
      FixturePost()
        ..authorId = 7
        ..editorId = 8
        ..body = "Ada's words"
        ..title = 'by Ada'
        ..createdAt = now,
    );
    await posts.save(
      FixturePost()
        ..authorId = 8
        ..editorId = 7
        ..body = "Bob's words"
        ..title = 'by Bob'
        ..createdAt = now,
    );
    await visits.save(
      FixtureVisit()
        ..visitorId = 7
        ..at = now,
    );
  }

  Iterable<TomAuditRecord> records(String target) =>
      trail.entries.map((e) => e.record).where((r) => r.target == target);

  test('an erasure reaches every entity, as each field declares', () async {
    await seed();
    final report = await TomPrivacy.erase(7);

    expect(report.countOf(FixtureMember).deleted, 1);
    expect(report.countOf(FixturePost).anonymized, 1);
    expect(report.countOf(FixturePost).unlinked, 1);
    expect(report.countOf(FixtureVisit).deleted, 1);
    expect(report.auditKeyShredded, isTrue);

    expect((await members.findAll()).map((m) => m.userId), [8]);
    expect(await visits.findAll(), isEmpty);
    final byTitle = {for (final p in await posts.findAll()) p.title: p};
    // Ada's post: kept for the thread, her name and words removed.
    expect(byTitle['by Ada']!.authorId, isNull);
    expect(byTitle['by Ada']!.body, '[removed]');
    expect(byTitle['by Ada']!.editorId, 8);
    // Bob's post, which Ada edited: only the link to her is gone.
    expect(byTitle['by Bob']!.editorId, isNull);
    expect(byTitle['by Bob']!.body, "Bob's words");
    expect(byTitle['by Bob']!.authorId, 8);
  }, skip: skip);

  test('every step is audited, and the erased subject\'s values are '
      'unreadable in the trail while the chain still verifies', () async {
    await seed();
    final created = records(
      'FixturePost',
    ).firstWhere((r) => r.action == TomAuditAction.create);
    // Ada's words were sealed for her when the post was written.
    expect(created.after['body'], startsWith(TomSubjectKeys.prefix));
    expect((await TomPrivacy.reveal(created)).after['body'], "Ada's words");

    await TomPrivacy.erase(7);

    final erasure = records(TomPrivacy.erasureTarget).single;
    expect(erasure.targetKey, '7');
    expect(erasure.action, TomAuditAction.delete);
    // The repositories audited each row they changed.
    expect(
      records('FixtureMember').where((r) => r.action == TomAuditAction.delete),
      hasLength(1),
    );
    expect(
      records('FixturePost').where((r) => r.action == TomAuditAction.update),
      hasLength(2),
    );

    expect(
      (await TomPrivacy.reveal(created)).after['body'],
      TomSubjectKeys.erasedPlaceholder,
    );
    final bobsPost = records('FixturePost').firstWhere(
      (r) =>
          r.action == TomAuditAction.create &&
          TomSubjectKeys.subjectOf(r.after['body']) == '8',
    );
    expect((await TomPrivacy.reveal(bobsPost)).after['body'], "Bob's words");
    expect(trail.verify().isValid, isTrue);
  }, skip: skip);

  test('an erasure under a legal hold keeps the audit key', () async {
    await seed();
    final created = records(
      'FixturePost',
    ).firstWhere((r) => r.action == TomAuditAction.create);
    final report = await TomPrivacy.erase(7, keepAuditKeys: true);
    expect(report.auditKeyShredded, isFalse);
    expect((await TomPrivacy.reveal(created)).after['body'], "Ada's words");
    expect(records(TomPrivacy.erasureTarget).single.detail, contains('kept'));
  }, skip: skip);

  test(
    'a subject-access export holds every row about the subject, once',
    () async {
      await seed();
      final access = await TomPrivacy.subjectAccess(8);
      expect(access.rowCounts, {
        FixtureMember: 1,
        // Bob wrote one post and edited the other: two rows, not three.
        FixturePost: 2,
        FixtureVisit: 0,
      });
      expect(access.result.sections.map((s) => s.title), [
        'FixtureMember',
        'FixturePost',
        'FixtureVisit',
      ]);

      final csv = utf8.decode(await TomPrivacy.exportSubject(8, format: 'csv'));
      expect(csv, contains('bob@x.org'));
      expect(csv, contains("Bob's words"));
      expect(csv, isNot(contains('ada@x.org')));
      final xlsx = await TomPrivacy.exportSubject(8);
      expect(xlsx.take(2), [0x50, 0x4b], reason: 'an XLSX is a zip');

      final exports = records(TomPrivacy.subjectAccessTarget).toList();
      expect(exports, hasLength(3));
      expect(exports.first.action, TomAuditAction.read);
      expect(exports.first.targetKey, '8');
    },
    skip: skip,
  );

  test('retention deletes and anonymizes what is past its time', () async {
    await seed();
    final old = now.subtract(const Duration(days: 40));
    await visits.save(
      FixtureVisit()
        ..visitorId = 8
        ..at = old,
    );
    await posts.save(
      FixturePost()
        ..authorId = 8
        ..body = 'long ago'
        ..title = 'old'
        ..createdAt = old,
    );
    final results = await TomPrivacy.applyRetention(now: now);
    expect(results.map((r) => r.affected), [1, 1]);

    expect((await visits.findAll()).map((v) => v.visitorId), [7]);
    final oldPost = (await posts.findAll()).firstWhere((p) => p.title == 'old');
    expect(oldPost.authorId, isNull);
    expect(oldPost.body, '[removed]');
    expect(
      (await posts.findAll()).where((p) => p.authorId != null),
      hasLength(2),
      reason: 'recent posts keep their authors',
    );
    expect(records(TomPrivacy.retentionTarget), hasLength(2));

    final again = await TomPrivacy.applyRetention(now: now);
    expect(again.map((r) => r.affected), [0, 0]);
  }, skip: skip);

  test('retention runs as a scheduler job', () async {
    await visits.save(
      FixtureVisit()
        ..visitorId = 9
        ..at = now.subtract(const Duration(days: 8)),
    );
    final jobs = TomMemoryJobStore();
    final scheduler = TomScheduler(
      store: jobs,
      dispatcher: const TomInlineJobDispatcher(),
    );
    addTearDown(scheduler.close);
    scheduler.register(
      TomPrivacy.retentionJob(
        schedule: const TomEventSchedule(Stream<Object?>.empty()),
        policies: [
          const TomRetentionPolicy(
            entity: FixtureVisit,
            field: 'at',
            keep: Duration(days: 7),
          ),
        ],
      ),
    );
    await jobs.enqueue(
      TomJobRun(
        id: 'retention-1',
        jobName: tomRetentionJobName,
        scheduledFor: now,
        runAt: now,
      ),
    );
    await scheduler.tick();
    await scheduler.drain();
    expect((await jobs.all()).single.state, TomJobRunState.succeeded);
    expect(await visits.findAll(), isEmpty);
  }, skip: skip);
}
