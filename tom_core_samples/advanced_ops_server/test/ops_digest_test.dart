/// The digest, asserted on the seam it exists to demonstrate: composition and
/// delivery retry on *separate* budgets.
///
/// `messaging.md:308` says the outbox puts retries on the job queue.
/// `ops_jobs.dart` gives the digest job [TomRetryPolicy.none] on the strength of
/// that claim — one attempt, and a failure is final — which is only defensible
/// if the queue really does carry the redelivery. That is the assertion below:
/// a transport that refuses its first attempt, a message that is delivered on
/// the second, and an audience that was consulted **once**.
///
/// The audience call count is what makes the test about the seam rather than
/// about the outbox. Anybody can show a message arriving eventually; the claim
/// here is that the second attempt sent *the message the first attempt built*,
/// never a recomposed one. If the digest job carried its own retry, the counter
/// would read two and the whole reason for `TomRetryPolicy.none` would be gone.
///
/// The outbox is real — a genuine [TomMessageOutbox] over a [TomMemoryJobStore]
/// with an injected clock — because a fake queue would be a test of the fake.
/// Only the two ends are stand-ins: where the facts come from, and where the
/// bytes go.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A summary with an address, so it is queued rather than skipped.
OpsDigestSummary _summary(
  int userId, {
  String email = 'user@example.com',
  int open = 3,
  int overdue = 1,
  TomTextLocale? locale,
}) => OpsDigestSummary(
  userId: userId,
  displayName: 'User $userId',
  emailAddress: email,
  openCount: open,
  overdueCount: overdue,
  locale: locale,
);

/// A digest pass over [outbox], rendering from the shipped `assets/text_*.yaml`.
///
/// The real bundles rather than fixtures: the claim under test is that the
/// digest sends what this deployment actually ships, and a fixture bundle would
/// let a broken asset pass every test in the file.
OpsDigestService _service(
  OpsDigestAudience audience,
  TomMessageOutbox outbox,
) => OpsDigestService(
  audience: audience,
  email: TomEmailService(outbox: outbox, texts: OpsTexts.resources()),
);

/// An item due at [due], assigned to nobody in particular.
ItemRecord _item({DateTime? due}) => ItemRecord()
  ..id = 1
  ..status = 'todo'
  ..dueDate = due;

void main() {
  setUp(() {
    TomServerPrincipal.clear();
    installOpsDeploymentPrincipal();
  });
  tearDown(() {
    TomServerPrincipal.clear();
    TomAuditTrail.uninstall();
  });

  group('the pass hands messages to a queue, never to a transport', () {
    late _FakeClock clock;
    late TomMemoryMessageTransport transport;
    late TomMessageOutbox outbox;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2026, 8, 2, 6));
      transport = TomMemoryMessageTransport();
      outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        store: TomMemoryJobStore(),
        clock: clock.call,
      );
    });

    tearDown(() => outbox.close());

    test('queueDigests returns before anything is delivered', () async {
      final audience = _FakeAudience([_summary(1), _summary(2)]);
      final service = _service(audience, outbox);

      final report = await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );

      expect(report.queued, 2);
      // The pass is done and the transport has seen nothing. That is the whole
      // difference between an outbox and a `send()`: the job's duration is two
      // reads, not two SMTP conversations.
      expect(transport.count, 0);
    });

    test('a tick delivers what the pass queued', () async {
      final audience = _FakeAudience([_summary(1)]);
      final service = _service(audience, outbox);

      await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );
      await outbox.tick();
      await pumpEventQueue();

      expect(transport.count, 1);
      expect(transport.last?.subject, contains('3 open item(s)'));
    });

    test(
      'a transport that fails once redelivers without recomposing the digest',
      () async {
        final audience = _FakeAudience([_summary(1)]);
        final service = _service(audience, outbox);
        transport.failNext = TomDeliveryException.transient(
          'smtp',
          'greylisted',
        );

        await runAsOpsService(
          () => service.queueDigests(DateTime.utc(2026, 8, 2)),
        );
        await outbox.tick();
        await pumpEventQueue();
        // First attempt refused: nothing delivered, and the queue is holding the
        // message rather than the job having failed.
        expect(transport.count, 0);

        // The backoff belongs to the outbox's own retry policy, so advancing the
        // clock is what makes the queued run due again — no second pass, no
        // second composition.
        clock.advance(const Duration(minutes: 2));
        await outbox.tick();
        await pumpEventQueue();

        expect(transport.count, 1);
        // The heart of it: the audience was read once. A second read would mean
        // the digest had been rebuilt, and `TomRetryPolicy.none` on the job would
        // be a mistake rather than a decision.
        expect(audience.calls, 1);
      },
    );

    test(
      'the message the second attempt sends is the one the first built',
      () async {
        final audience = _FakeAudience([_summary(1)]);
        final service = _service(audience, outbox);
        transport.failNext = TomDeliveryException.transient('smtp', 'busy');

        await runAsOpsService(
          () => service.queueDigests(DateTime.utc(2026, 8, 2)),
        );
        await outbox.tick();
        await pumpEventQueue();
        clock.advance(const Duration(minutes: 2));
        await outbox.tick();
        await pumpEventQueue();

        // Identity, not equivalence: the id is the queue key, so a delivered
        // message carrying the composed id is the composed message.
        expect(
          transport.last?.id,
          OpsDigestService.messageIdFor(1, DateTime.utc(2026, 8, 2)),
        );
      },
    );

    test('recomposing the same window replaces the queued run rather than '
        'adding one', () async {
      final audience = _FakeAudience([_summary(1)]);
      final service = _service(audience, outbox);

      // Two passes over one window — what a recovery-triggered re-run does.
      await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );
      await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );
      await outbox.tick();
      await pumpEventQueue();

      // One delivery, because `'<job>:<message id>'` keys the queue row and the
      // id is day-granular. At-least-once delivery of a message that is its own
      // key is exactly-once delivery of a digest.
      expect(transport.count, 1);
    });

    test('a person without an address is skipped, not queued to fail', () async {
      final audience = _FakeAudience([_summary(1), _summary(2, email: '   ')]);
      final service = _service(audience, outbox);

      final report = await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );

      // Counted rather than logged: a directory with holes is a fact the
      // deployment should be able to see the size of. Queueing it instead would
      // buy five doomed attempts and an alert.
      expect(report.skippedWithoutAddress, 1);
      expect(report.queued, 1);
      expect(report.considered, 2);
      await outbox.tick();
      await pumpEventQueue();
      expect(transport.count, 1);
    });

    test('the pass records one trail entry, not one per message', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      final audience = _FakeAudience([_summary(1), _summary(2), _summary(3)]);
      final service = _service(audience, outbox);

      await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );

      // The per-message record already exists — in the outbox's own queue. The
      // trail's interest is that the ops server mailed three people.
      expect(sink.records, hasLength(1));
      expect(sink.records.single.target, 'OpsDigest');
      expect(sink.records.single.outcome, TomAuditOutcome.succeeded);
      expect(sink.records.single.actor.username, opsServiceUsername);
      expect(sink.records.single.detail, contains('3'));
    });

    test('a pass that queued nothing records nothing', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      final service = _service(_FakeAudience(const []), outbox);

      final report = await runAsOpsService(
        () => service.queueDigests(DateTime.utc(2026, 8, 2)),
      );

      expect(report.queued, 0);
      expect(sink.records, isEmpty);
    });

    test(
      'a deployment without the digest grant never reads the audience',
      () async {
        TomServerPrincipal.clear();
        TomServerPrincipal.install(
          TomPrincipal(
            user: TomUser(id: 7, username: 'unlicensed-deployment'),
            aci: TomAccessControlInformation(entitlements: const []),
            authenticated: true,
          ),
        );
        final audience = _FakeAudience([_summary(1)]);
        final service = _service(audience, outbox);

        await expectLater(
          runAsOpsService(() => service.queueDigests(DateTime.utc(2026, 8, 2))),
          throwsA(isA<TomPermanentJobFailure>()),
        );
        expect(audience.calls, 0);
      },
    );
  });

  group('the id is what makes a re-run idempotent', () {
    test('two runs of one day produce the same id', () {
      expect(
        OpsDigestService.messageIdFor(42, DateTime.utc(2026, 8, 2, 6)),
        OpsDigestService.messageIdFor(42, DateTime.utc(2026, 8, 2, 23, 59)),
      );
    });

    test('two days produce different ids', () {
      expect(
        OpsDigestService.messageIdFor(42, DateTime.utc(2026, 8, 2)),
        isNot(OpsDigestService.messageIdFor(42, DateTime.utc(2026, 8, 3))),
      );
    });

    test('two people on one day produce different ids', () {
      expect(
        OpsDigestService.messageIdFor(1, DateTime.utc(2026, 8, 2)),
        isNot(OpsDigestService.messageIdFor(2, DateTime.utc(2026, 8, 2))),
      );
    });

    test('the id is zero-padded, so it sorts as a date', () {
      // `digest-2026802-1` would sort before `digest-20261101-1`, which is the
      // kind of defect that only shows up in a support query nine months later.
      expect(
        OpsDigestService.messageIdFor(1, DateTime.utc(2026, 8, 2)),
        'digest-20260802-1',
      );
    });

    test('the id is derived from the UTC day, not the host zone', () {
      final local = DateTime.utc(2026, 8, 2, 12).toLocal();
      expect(OpsDigestService.messageIdFor(1, local), 'digest-20260802-1');
    });
  });

  group('the counting rules the digest reports', () {
    final now = DateTime.utc(2026, 8, 2, 6);

    test('open work is every status that is not terminal', () {
      // Derived rather than listed, so a status added to the domain is in the
      // digest by default: a digest that under-reports is worse than one that
      // over-reports, because nobody notices work that was never mentioned.
      expect(openStatuses.intersection(retainableTerminalStatuses), isEmpty);
      expect(
        openStatuses.union(retainableTerminalStatuses),
        TodoStatus.values.toSet(),
      );
    });

    test('an item past its due date is overdue', () {
      final summary = RepositoryDigestAudience.summarise(
        userId: 1,
        displayName: 'A',
        emailAddress: 'a@example.com',
        items: [_item(due: now.subtract(const Duration(days: 1)))],
        now: now,
      );
      expect(summary.overdueCount, 1);
      // An overdue item is not also "next due" — it has already fallen due, and
      // reporting it as upcoming would be the digest contradicting itself.
      expect(summary.nextDue, isNull);
    });

    test('the next due date is the earliest one still ahead', () {
      final summary = RepositoryDigestAudience.summarise(
        userId: 1,
        displayName: 'A',
        emailAddress: 'a@example.com',
        items: [
          _item(due: now.add(const Duration(days: 5))),
          _item(due: now.add(const Duration(days: 2))),
          _item(due: now.subtract(const Duration(days: 3))),
        ],
        now: now,
      );
      expect(summary.openCount, 3);
      expect(summary.overdueCount, 1);
      expect(summary.nextDue, now.add(const Duration(days: 2)));
    });

    test('undated items count as open and nothing else', () {
      final summary = RepositoryDigestAudience.summarise(
        userId: 1,
        displayName: 'A',
        emailAddress: 'a@example.com',
        items: [_item(), _item()],
        now: now,
      );
      expect(summary.openCount, 2);
      expect(summary.overdueCount, 0);
      expect(summary.nextDue, isNull);
    });
  });

  group('the composed message', () {
    final outbox = TomMessageOutbox(
      router: TomMessageRouter([TomMemoryMessageTransport()]),
      store: TomMemoryJobStore(),
    );
    final service = _service(_FakeAudience(const []), outbox);

    tearDownAll(outbox.close);

    test('is addressed to the person it summarises', () {
      final message = service.composeFor(
        _summary(1, email: 'someone@example.com'),
        DateTime.utc(2026, 8, 2),
      );
      expect(message.recipients.single.address, 'someone@example.com');
      expect(message.recipients.single.displayName, 'User 1');
    });

    test('mentions the overdue count only when there is one', () {
      final withOverdue = service.composeFor(
        _summary(1, overdue: 2),
        DateTime.utc(2026, 8, 2),
      );
      final withoutOverdue = service.composeFor(
        _summary(1, overdue: 0),
        DateTime.utc(2026, 8, 2),
      );
      expect(
        withOverdue.textBody?.content,
        contains('2 of them are past their due date'),
      );
      expect(
        withoutOverdue.textBody?.content,
        isNot(contains('past their due date')),
      );
    });

    test('says who sent it', () {
      final message = service.composeFor(_summary(1), DateTime.utc(2026, 8, 2));
      // Attribution in the body as well as the trail: the recipient of an
      // unexpected 06:00 mail should be able to tell what produced it.
      expect(message.textBody?.content, contains(opsServiceUsername));
    });

    test('mentions the next due date only when one is ahead', () {
      final withNext = service.composeFor(
        OpsDigestSummary(
          userId: 1,
          displayName: 'User 1',
          emailAddress: 'user@example.com',
          openCount: 3,
          overdueCount: 0,
          nextDue: DateTime.utc(2026, 8, 9),
        ),
        DateTime.utc(2026, 8, 2),
      );
      expect(withNext.textBody?.content, contains('falls due on 2026-08-09'));
      expect(
        service
            .composeFor(_summary(1), DateTime.utc(2026, 8, 2))
            .textBody
            ?.content,
        isNot(contains('falls due')),
      );
    });

    test('renders in the recipient\'s language, not the process\'s', () {
      // The point of routing through TomEmailService rather than composing a
      // TomMessage: one pass mails everybody, so there is no moment at which
      // this job could "switch to German". The locale rides on the summary.
      final german = service.composeFor(
        _summary(1, overdue: 2, locale: TomTextLocale('de')),
        DateTime.utc(2026, 8, 2),
      );
      final english = service.composeFor(
        _summary(2, overdue: 2),
        DateTime.utc(2026, 8, 2),
      );

      expect(german.subject, contains('offene Vorgänge'));
      expect(german.textBody?.content, contains('Guten Morgen'));
      // The conditional fragment is localised too — it is a resource key like
      // any other, not a sentence the Dart assembled.
      expect(german.textBody?.content, contains('2 davon sind überfällig'));

      expect(english.subject, contains('open item(s)'));
      expect(english.textBody?.content, contains('Good morning'));
    });

    test(
      'a template the bundles do not carry fails before it is queued',
      () async {
        final service = OpsDigestService(
          audience: _FakeAudience(const []),
          email: TomEmailService(
            outbox: outbox,
            // An empty bundle set: what a deployment that forgot its assets has.
            texts: TomLocalizedTextResources(
              bundles: const {'en': {}},
              defaultLocale: TomTextLocale('en'),
            ),
          ),
        );

        // Loudly, and with nothing on the queue — a digest with a blank subject
        // that was *delivered* cannot be taken back.
        expect(
          () => service.composeFor(_summary(1), DateTime.utc(2026, 8, 2)),
          throwsA(isA<TomMessagingException>()),
        );
      },
    );
  });

  group('the shipped text bundles', () {
    test('carry every key the digest resolves, in every locale', () {
      // The digest reads four keys; a bundle missing one fails a send rather
      // than a build, so this is the test that turns a translation gap into a
      // red suite instead of a blank line in somebody's mail.
      final texts = OpsTexts.load();
      for (final tag in OpsTexts.localeTags) {
        final locale = TomTextLocale.parse(tag);
        expect(texts.hasLocale(locale), isTrue, reason: 'no bundle for $tag');
        for (final subKey in [
          'subject',
          'text',
          opsDigestOverdueSubKey,
          opsDigestNextDueSubKey,
        ]) {
          // `isTranslated`, not `exists`: the latter follows the fallback
          // chain and would answer yes for an entirely empty German bundle.
          expect(
            texts.isTranslated('$opsDigestTemplateKey.$subKey', locale),
            isTrue,
            reason: '$tag is missing $opsDigestTemplateKey.$subKey',
          );
        }
      }
    });
  });
}

/// An [OpsDigestAudience] that returns a fixed list and counts its calls.
///
/// The counter is the point of the class: `calls == 1` after a redelivery is
/// the assertion that the retry belonged to the queue.
class _FakeAudience implements OpsDigestAudience {
  _FakeAudience(this.summaries);

  /// What every call returns.
  final List<OpsDigestSummary> summaries;

  /// How many times the digest has been composed from scratch.
  int calls = 0;

  @override
  Future<List<OpsDigestSummary>> summariesFor(DateTime now) async {
    calls++;
    return summaries;
  }
}

/// A clock the test moves, so a backoff is a line of code rather than a wait.
class _FakeClock {
  _FakeClock(this.now);

  /// The current instant.
  DateTime now;

  /// Usable as the outbox's `clock` argument.
  DateTime call() => now;

  /// Moves time forward past a backoff.
  void advance(Duration by) => now = now.add(by);
}
