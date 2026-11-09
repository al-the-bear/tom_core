/// The audit_reports module without a database: the filter a question saves,
/// the view across writers, the service's saved questions and deliveries, and
/// the endpoints of the kernel's `tomAuditReportsApi`.
///
/// The SQL store's statements are covered by `framework_schema_test.dart` and
/// its behaviour, with the relational trail across writers, by
/// `audit_reports_db_test.dart`.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

TomAuditRecord _record(
  String id,
  DateTime at, {
  String actor = 'ada',
  TomAuditAction action = TomAuditAction.update,
  TomAuditOutcome outcome = TomAuditOutcome.succeeded,
  String target = 'Order',
}) => TomAuditRecord(
  id: id,
  timestamp: at,
  actor: TomAuditActor(username: actor, userId: actor),
  action: action,
  target: target,
  targetKey: id,
  outcome: outcome,
);

TomPrincipal _principal(String userId, {List<String> roles = const []}) =>
    TomPrincipal(
      authenticated: true,
      context: {},
      clientId: 0,
      organization: 'acme',
      organizationId: 0,
      application: 'audit',
      applicationId: 0,
      process: 'audit',
      processId: 0,
      language: 'en',
      country: 'US',
      clientCountry: 'US',
      clientLanguage: 'en',
      clientTimezone: 'UTC',
      user: TomUser(
        id: userId,
        username: userId,
        firstname: 'Test',
        lastname: 'User',
        attributes: {},
        timezone: 'utc',
      ),
      aci: TomAccessControlInformation(roles: roles),
    );

Future<R> _as<R>(String userId, Future<R> Function() body) => runZoned(
  body,
  zoneValues: {
    TomPrincipal: _principal(userId, roles: [tomAuditorRole]),
  },
);

Matcher _throwsKey(String key) =>
    throwsA(isA<TomException>().having((e) => e.key, 'key', key));

/// Two writers, `node-a` and `node-b`, with records interleaved in time.
Future<TomMemoryAuditTrailSource> _twoWriters() async {
  final a = TomMemoryAuditSink();
  final b = TomMemoryAuditSink();
  await a.write(_record('a1', DateTime.utc(2026, 11, 7, 9)));
  await b.write(_record('b1', DateTime.utc(2026, 11, 7, 10)));
  await a.write(
    _record(
      'a2',
      DateTime.utc(2026, 11, 7, 11),
      outcome: TomAuditOutcome.denied,
      actor: 'mallory',
    ),
  );
  await b.write(
    _record(
      'b2',
      DateTime.utc(2026, 11, 7, 12),
      outcome: TomAuditOutcome.denied,
    ),
  );
  return TomMemoryAuditTrailSource({'node-a': a, 'node-b': b});
}

TomLocalizedTextResources _texts() => TomLocalizedTextResources(
  defaultLocale: TomTextLocale('en'),
  bundles: const {
    'en': {
      'audit_reports': {
        'delivery': {
          'subject': 'Audit report: {name}',
          'text': '{count} record(s) for {name}.',
        },
      },
    },
  },
);

void main() {
  group('the filter', () {
    test('AR-1: reads its JSON form and writes back only what is set', () {
      final filter = TomAuditQuestionFilter.fromJson({
        'actor': 'ada',
        'action': 'delete',
        'outcome': 'denied',
        'lastHours': 24,
        'writers': ['node-a'],
        'limit': 50,
      });
      expect(filter.action, TomAuditAction.delete);
      expect(filter.outcome, TomAuditOutcome.denied);
      expect(filter.writers, ['node-a']);
      expect(filter.toJson(), {
        'actor': 'ada',
        'action': 'delete',
        'outcome': 'denied',
        'lastHours': 24,
        'writers': ['node-a'],
        'limit': 50,
      });
    });

    test('AR-2: a relative window ends when the question is asked', () {
      final query = TomAuditQuestionFilter(
        lastHours: 2,
      ).toQuery(DateTime.utc(2026, 11, 7, 12));
      expect(query.from, DateTime.utc(2026, 11, 7, 10));
      expect(query.to, DateTime.utc(2026, 11, 7, 12));
      expect(query.newestFirst, isTrue);
    });

    test('AR-3: refuses what it cannot use', () {
      for (final json in <Map<String, Object?>>[
        {'colour': 'red'},
        {'action': 'paint'},
        {'from': 'yesterday'},
        {'lastHours': 0},
        {'lastHours': 2, 'from': '2026-11-07T00:00:00Z'},
        {'from': '2026-11-07T00:00:00Z', 'to': '2026-11-06T00:00:00Z'},
        {'limit': 0},
        {'limit': 5001},
        {'writers': 'node-a'},
        {'actor': 7},
      ]) {
        expect(
          () => TomAuditQuestionFilter.fromJson(json),
          _throwsKey('audit_reports.question.invalid'),
          reason: '$json',
        );
      }
    });
  });

  group('the question', () {
    test('AR-4: refuses an empty name, an unknown format, a bad schedule, a '
        'bad address and a schedule with nowhere to go', () {
      TomAuditQuestion question({
        String name = 'q',
        String format = 'csv',
        String? schedule,
        List<String> recipients = const [],
      }) => TomAuditQuestion(
        id: '',
        name: name,
        owner: 'u',
        filter: TomAuditQuestionFilter(),
        format: format,
        schedule: schedule,
        recipients: recipients,
      );
      expect(
        () => question(name: ' '),
        _throwsKey('audit_reports.question.invalid'),
      );
      expect(
        () => question(format: 'doc'),
        _throwsKey('audit_reports.question.invalid'),
      );
      expect(
        () => question(schedule: 'every monday', recipients: ['a@b.de']),
        _throwsKey('audit_reports.question.invalid'),
      );
      expect(
        () => question(recipients: ['nobody']),
        _throwsKey('audit_reports.question.invalid'),
      );
      expect(
        () => question(schedule: '0 6 * * 1'),
        _throwsKey('audit_reports.question.invalid'),
      );
      final weekly = question(schedule: '0 6 * * 1', recipients: ['a@b.de']);
      // 2026-11-07 is a Saturday; the next Monday 06:00 UTC is the 9th.
      expect(
        weekly.nextAfter(DateTime.utc(2026, 11, 7, 12)),
        DateTime.utc(2026, 11, 9, 6),
      );
    });
  });

  group('the view across writers', () {
    test('AR-5: merges every writer newest first', () async {
      final view = TomAuditView(await _twoWriters());
      final answer = await view.query(const TomAuditQuery());
      expect(
        [for (final e in answer.entries) e.entry.record.id],
        ['b2', 'a2', 'b1', 'a1'],
      );
      expect(
        [for (final e in answer.entries) e.writer],
        ['node-b', 'node-a', 'node-b', 'node-a'],
      );
      expect(answer.writers, ['node-a', 'node-b']);
      expect(answer.hasMore, isFalse);
    });

    test(
      'AR-6: the limit applies to the merged list, and a cut says so',
      () async {
        final view = TomAuditView(await _twoWriters());
        final answer = await view.query(const TomAuditQuery(limit: 3));
        expect(
          [for (final e in answer.entries) e.entry.record.id],
          ['b2', 'a2', 'b1'],
        );
        expect(answer.hasMore, isTrue);
      },
    );

    test('AR-7: a question can name its writers', () async {
      final view = TomAuditView(await _twoWriters());
      final answer = await view.query(
        const TomAuditQuery(outcome: TomAuditOutcome.denied),
        writers: ['node-a'],
      );
      expect([for (final e in answer.entries) e.entry.record.id], ['a2']);
      expect(answer.writers, ['node-a']);
    });
  });

  group('the service', () {
    late TomMemoryAuditSink trail;
    late TomMemoryExportStore exportStore;
    late TomMemoryMessageTransport transport;
    late TomMessageOutbox outbox;
    late TomMemoryAuditQuestionStore questions;
    late DateTime now;
    late TomAuditReports reports;

    setUp(() async {
      trail = TomMemoryAuditSink();
      TomAuditTrail.install(trail);
      exportStore = TomMemoryExportStore();
      transport = TomMemoryMessageTransport();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        store: TomMemoryJobStore(),
      );
      questions = TomMemoryAuditQuestionStore();
      now = DateTime.utc(2026, 11, 9, 5, 59);
      reports = TomAuditReports(
        view: TomAuditView(await _twoWriters()),
        questions: questions,
        exports: TomExportService(store: exportStore),
        email: TomExportEmailDelivery(
          store: exportStore,
          outbox: outbox,
          from: TomRecipient('audit@example.com'),
        ),
        texts: _texts(),
        clock: () => now,
      );
    });

    tearDown(() async {
      TomAuditTrail.uninstall();
      await outbox.close();
    });

    TomAuditQuestion denied({String id = '', String? schedule}) =>
        TomAuditQuestion(
          id: id,
          name: 'Denied actions',
          owner: '',
          filter: TomAuditQuestionFilter(outcome: TomAuditOutcome.denied),
          schedule: schedule,
          recipients: const ['auditor@example.com'],
        );

    test('AR-8: saving gives a new question an id, its owner and its next '
        'delivery', () async {
      final saved = await reports.save(
        'u:audrey',
        denied(schedule: '0 6 * * 1'),
      );
      expect(saved.id, isNotEmpty);
      expect(saved.owner, 'u:audrey');
      expect(saved.nextDeliveryAt, DateTime.utc(2026, 11, 9, 6));
      expect(await reports.questionsOf('u:audrey'), hasLength(1));
      final unscheduled = await reports.save('u:audrey', denied());
      expect(unscheduled.nextDeliveryAt, isNull);
    });

    test("AR-9: another auditor's question is not found, and cannot be "
        'changed, answered, delivered or removed', () async {
      final saved = await reports.save('u:audrey', denied());
      await expectLater(
        reports.questionOf('u:mallory', saved.id),
        _throwsKey('audit_reports.question.not_found'),
      );
      await expectLater(
        reports.save('u:mallory', denied(id: saved.id)),
        _throwsKey('audit_reports.question.not_found'),
      );
      await expectLater(
        reports.deliverSoon('u:mallory', saved.id),
        _throwsKey('audit_reports.question.not_found'),
      );
      await expectLater(
        reports.remove('u:mallory', saved.id),
        _throwsKey('audit_reports.question.not_found'),
      );
      expect(await reports.questionsOf('u:audrey'), hasLength(1));
    });

    test('AR-10: a due question is delivered as an export by email, recorded '
        'in the trail, and moved to its next time', () async {
      final saved = await reports.save(
        'u:audrey',
        denied(schedule: '0 6 * * 1'),
      );
      expect(await reports.deliverDue(), isEmpty, reason: 'not due yet');

      now = DateTime.utc(2026, 11, 9, 6);
      final done = await reports.deliverDue();
      expect(done.single.succeeded, isTrue);
      expect(done.single.recordCount, 2);
      await outbox.tick();
      final mail = transport.sent.single;
      expect(mail.subject, 'Audit report: Denied actions');
      expect(mail.textBody!.content, '2 record(s) for Denied actions.');
      expect(mail.recipients.single.address, 'auditor@example.com');
      expect(mail.attachments.single.fileName, endsWith('.csv'));

      final audited = trail.entries.last.record;
      expect(audited.action, TomAuditAction.execute);
      expect(audited.target, 'TomAuditQuestion');
      expect(audited.targetKey, saved.id);
      expect(audited.outcome, TomAuditOutcome.succeeded);

      final after = await reports.questionOf('u:audrey', saved.id);
      expect(after.lastDeliveredAt, DateTime.utc(2026, 11, 9, 6));
      expect(after.nextDeliveryAt, DateTime.utc(2026, 11, 16, 6));
    });

    test(
      'AR-11: delivering now marks the question for the next pass, once',
      () async {
        final saved = await reports.save('u:audrey', denied());
        final marked = await reports.deliverSoon('u:audrey', saved.id);
        expect(marked.nextDeliveryAt, now);
        expect((await reports.deliverDue()).single.succeeded, isTrue);
        final after = await reports.questionOf('u:audrey', saved.id);
        expect(after.nextDeliveryAt, isNull, reason: 'no schedule: once only');
        expect(await reports.deliverDue(), isEmpty);
      },
    );

    test('AR-12: a question with nowhere to go is refused delivery', () async {
      final saved = await reports.save(
        'u:audrey',
        TomAuditQuestion(
          id: '',
          name: 'just looking',
          owner: '',
          filter: TomAuditQuestionFilter(),
        ),
      );
      await expectLater(
        reports.deliverSoon('u:audrey', saved.id),
        _throwsKey('audit_reports.question.no_recipients'),
      );
    });

    test('AR-13: a process without exports records a failed delivery and '
        'does not retry it every pass', () async {
      final answering = TomAuditReports(
        view: TomAuditView(await _twoWriters()),
        questions: questions,
        clock: () => now,
      );
      final saved = await answering.save('u:audrey', denied());
      await answering.deliverSoon('u:audrey', saved.id);
      final done = await answering.deliverDue();
      expect(done.single.succeeded, isFalse);
      expect(
        (done.single.error as TomException).key,
        'audit_reports.delivery.not_configured',
      );
      expect(trail.entries.last.record.outcome, TomAuditOutcome.failed);
      expect(await answering.deliverDue(), isEmpty);
    });

    test('AR-14: a delivery with no text resources fails, keyed', () async {
      final bare = TomAuditReports(
        view: TomAuditView(await _twoWriters()),
        questions: questions,
        exports: TomExportService(store: exportStore),
        email: TomExportEmailDelivery(store: exportStore, outbox: outbox),
        texts: TomLocalizedTextResources(
          defaultLocale: TomTextLocale('en'),
          bundles: const {'en': <String, Object?>{}},
        ),
        clock: () => now,
      );
      final saved = await bare.save('u:audrey', denied());
      await bare.deliverSoon('u:audrey', saved.id);
      final done = await bare.deliverDue();
      expect(
        (done.single.error as TomException).key,
        'audit_reports.delivery.text_missing',
      );
    });

    test('AR-15: the delivery pass registers on a scheduler', () async {
      final scheduler = TomScheduler(
        store: TomMemoryJobStore(),
        dispatcher: const TomInlineJobDispatcher(),
        onAlert: (_) {},
      );
      addTearDown(scheduler.close);
      final definition = reports.registerOn(scheduler);
      expect(definition.name, TomAuditReports.jobName);
      expect(definition.schedule, isA<TomIntervalSchedule>());
    });
  });

  group('the endpoints', () {
    late TomMemoryAuditQuestionStore questions;

    setUp(() async {
      questions = TomMemoryAuditQuestionStore();
      TomAuditReports(
        view: TomAuditView(await _twoWriters()),
        questions: questions,
        clock: () => DateTime.utc(2026, 11, 9, 5),
      ).install();
    });

    tearDown(TomBean.resetBeanContext);

    const server = TomAuditReportsServer();

    test('AR-16: every endpoint requires the auditor role', () {
      expect(tomAuditReportsApi.uri, '/audit-reports');
      for (final endpoint in tomAuditReportsApi.endpoints.values) {
        expect(endpoint.access, tomAuditorAccess, reason: endpoint.id);
      }
      expect(
        tomAuditorAccess.checkPrincipalAccess(
          _principal('u', roles: [tomAuditorRole]),
        ),
        isTrue,
      );
      expect(
        tomAuditorAccess.checkPrincipalAccess(_principal('u', roles: ['user'])),
        isFalse,
      );
    });

    test('AR-17: writers, a query, and a question saved, listed, answered, '
        'marked and removed as the caller', () async {
      expect((await server.auditReportWriters()).writers, ['node-a', 'node-b']);
      final answer = await server.auditReportQuery(
        TomAuditReportQueryRequest(filter: {'outcome': 'denied'}),
      );
      expect([for (final e in answer.entries) e.record['id']], ['b2', 'a2']);

      final saved = await _as(
        'audrey',
        () => server.auditReportSaveQuestion(
          TomAuditQuestionDto(
            name: 'Denied',
            filter: {'outcome': 'denied'},
            recipients: ['auditor@example.com'],
          ),
        ),
      );
      expect(saved.id, isNotEmpty);
      expect(saved.owner, 'audrey');
      final mine = await _as('audrey', server.auditReportQuestions);
      expect(mine.questions.single.name, 'Denied');
      expect(
        (await _as('mallory', server.auditReportQuestions)).questions,
        isEmpty,
      );

      final id = TomAuditQuestionIdRequest(id: saved.id);
      final answered = await _as('audrey', () => server.auditReportAnswer(id));
      expect(answered.entries, hasLength(2));
      final marked = await _as('audrey', () => server.auditReportDeliver(id));
      expect(marked.nextDeliveryAt, '2026-11-09T05:00:00.000Z');
      await expectLater(
        _as('mallory', () => server.auditReportAnswer(id)),
        _throwsKey('audit_reports.question.not_found'),
      );
      await _as('audrey', () => server.auditReportDeleteQuestion(id));
      expect(await questions.find(saved.id), isNull);
    });

    test('AR-18: the refusals answer with their statuses', () {
      const handler = TomAuditReportsErrorHandler();
      for (final entry in {
        'audit_reports.question.not_found': 404,
        'audit_reports.question.invalid': 400,
        'audit_reports.question.no_recipients': 409,
        'audit_reports.not_configured': 503,
        'audit_reports.no_principal': 401,
        'audit_reports.delivery.not_configured': 500,
      }.entries) {
        expect(
          handler.statusFor(TomAuditReportException(entry.key, 'x')),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('AR-19: without an installed service the API answers not '
        'configured', () async {
      TomBean.resetBeanContext();
      await expectLater(
        server.auditReportWriters(),
        _throwsKey('audit_reports.not_configured'),
      );
    });

    test('AR-20: the wire forms read back', () {
      final question = TomAuditQuestionDto(
        id: 'q',
        name: 'n',
        filter: {'lastHours': 24},
        schedule: '0 6 * * 1',
        recipients: ['a@b.de'],
        format: 'pdf',
      );
      expect(
        TomAuditQuestionDto.fromJson(question.toJson()).toJson(),
        question.toJson(),
      );
      final result = TomAuditReportResultDto(
        entries: [
          TomAuditReportEntryDto(
            writer: 'w',
            index: 3,
            hash: 'h',
            record: {'id': 'r'},
          ),
        ],
        hasMore: true,
        writers: ['w'],
      );
      expect(
        TomAuditReportResultDto.fromJson(result.toJson()).toJson(),
        result.toJson(),
      );
    });
  });

  test('AR-21: a .named store or view over an unregistered data source is '
      'refused at construction', () {
    expect(
      () => TomSqlAuditQuestionStore.named('no_such_datasource'),
      _throwsKey('audit_reports.store.unknown_datasource'),
    );
    expect(
      () => TomSqlAuditTrailSource.named('no_such_datasource'),
      _throwsKey('audit_reports.view.unknown_datasource'),
    );
  });
}
