/// The audit-report service: answers questions across the writers of the
/// trail, keeps auditors' saved questions, and delivers them on schedule as
/// exports by email.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/v4.dart';

import '../audit/audit_record.dart';
import '../audit/audit_trail.dart';
import '../export/export_email.dart';
import '../export/export_service.dart';
import '../export/tabular_result.dart';
import '../messaging/message.dart';
import '../resources/localized_text_resources.dart';
import 'audit_question.dart';
import 'audit_question_store.dart';
import 'audit_view.dart';

/// What one delivery did.
class TomAuditReportDelivery {
  /// The question delivered.
  final TomAuditQuestion question;

  /// How many records the export holds.
  final int recordCount;

  /// The stored export's key, or `null` when the delivery failed.
  final String? exportKey;

  /// Why it failed, or `null`.
  final Object? error;

  /// Creates a delivery record.
  const TomAuditReportDelivery({
    required this.question,
    required this.recordCount,
    this.exportKey,
    this.error,
  });

  /// Whether the export was stored and sent.
  bool get succeeded => error == null;
}

/// Answers, keeps and delivers audit questions.
///
/// Deliveries need [exports] (where the CSV, XLSX or PDF is stored) and
/// [email] (which sends it, attached or linked, through the messaging outbox);
/// a process that only answers questions — a server behind the
/// `tomAuditReportsApi` endpoints — leaves both out and marks a question for
/// delivery, which the process that has them delivers on its next pass
/// ([deliverDue], run by [registerOn]).
///
/// The delivery's subject and text come from resource keys, in the
/// deployment's default language: `audit_reports.delivery.subject` and
/// `audit_reports.delivery.text`, each given `{name}` (the question's name),
/// `{count}` (the records) and `{from}` / `{to}` (the window, when it has one).
class TomAuditReports {
  /// Where the trail is read.
  final TomAuditView view;

  /// Where questions are kept.
  final TomAuditQuestionStore questions;

  /// Where delivered exports are stored; `null` in a process that does not
  /// deliver.
  final TomExportService? exports;

  /// How a delivery is sent; `null` in a process that does not deliver.
  final TomExportEmailDelivery? email;

  final TomLocalizedTextResources? _texts;
  final DateTime Function() _clock;

  /// The job name [registerOn] registers.
  static const String jobName = 'audit_reports.deliver';

  /// Creates the service.
  TomAuditReports({
    required this.view,
    required this.questions,
    this.exports,
    this.email,
    TomLocalizedTextResources? texts,
    DateTime Function()? clock,
  }) : _texts = texts,
       _clock = clock ?? DateTime.now;

  /// The installed service, or `null`.
  static TomAuditReports? resolve() {
    final installed = TomBean.getBeanByType(TomAuditReports);
    return installed is TomAuditReports ? installed : null;
  }

  /// Installs this service as the process-wide bean.
  void install() => TomBean.overrideWithType<TomAuditReports>(this);

  /// The writers the trail holds records of.
  Future<List<String>> writers() => view.source.writers();

  /// [filter] asked now.
  Future<TomAuditViewResult> ask(TomAuditQuestionFilter filter) =>
      view.query(filter.toQuery(_clock()), writers: filter.writers);

  /// The questions [owner] saved.
  Future<List<TomAuditQuestion>> questionsOf(String owner) =>
      questions.ownedBy(owner);

  /// [owner]'s question [id]; refuses (`audit_reports.question.not_found`)
  /// one that does not exist or belongs to someone else — the two are not
  /// told apart.
  Future<TomAuditQuestion> questionOf(String owner, String id) async {
    final question = await questions.find(id);
    if (question == null || question.owner != owner) {
      throw TomAuditReportException(
        'audit_reports.question.not_found',
        'There is no such saved question.',
        parameters: {'id': id},
      );
    }
    return question;
  }

  /// Saves [question] as [owner]'s: a new question (with a new id) when its
  /// id is empty, else the replacement of [owner]'s question with that id.
  /// The next delivery is computed from the schedule; a question already
  /// marked for delivery keeps that mark.
  Future<TomAuditQuestion> save(String owner, TomAuditQuestion question) async {
    final existing = question.id.isEmpty
        ? null
        : await questionOf(owner, question.id);
    final now = _clock().toUtc();
    final scheduled = question.nextAfter(now);
    final marked = existing?.nextDeliveryAt;
    final next =
        marked != null && (scheduled == null || marked.isBefore(scheduled))
        ? marked
        : scheduled;
    final stored = question.copyWith(
      id: question.id.isEmpty ? const UuidV4().generate() : question.id,
      owner: owner,
      lastDeliveredAt: existing?.lastDeliveredAt,
      nextDeliveryAt: next,
      clearNextDelivery: next == null,
    );
    await questions.save(stored);
    return stored;
  }

  /// Removes [owner]'s question [id]; refuses one that is not theirs.
  Future<void> remove(String owner, String id) async {
    await questionOf(owner, id);
    await questions.remove(id);
  }

  /// Marks [owner]'s question [id] for delivery at the next pass; refuses
  /// (`audit_reports.question.no_recipients`) a question with nowhere to go.
  Future<TomAuditQuestion> deliverSoon(String owner, String id) async {
    final question = await questionOf(owner, id);
    if (question.recipients.isEmpty) {
      throw TomAuditReportException(
        'audit_reports.question.no_recipients',
        'The question has no recipients to deliver to.',
        parameters: {'id': id},
      );
    }
    final marked = question.copyWith(nextDeliveryAt: _clock().toUtc());
    await questions.save(marked);
    return marked;
  }

  /// Delivers every question due now; answers what each delivery did.
  ///
  /// A delivery that fails does not stop the others: it is recorded in the
  /// audit trail as failed, and the question moves on to its next scheduled
  /// delivery (a question marked for one delivery is unmarked) — a broken
  /// question must not be retried every pass for ever.
  Future<List<TomAuditReportDelivery>> deliverDue() async {
    final now = _clock().toUtc();
    final done = <TomAuditReportDelivery>[];
    for (final question in await questions.due(now)) {
      TomAuditReportDelivery delivery;
      try {
        delivery = await _deliver(question, now);
      } on Object catch (error) {
        delivery = TomAuditReportDelivery(
          question: question,
          recordCount: 0,
          error: error,
        );
      }
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: 'TomAuditQuestion',
        targetKey: question.id,
        outcome: delivery.succeeded
            ? TomAuditOutcome.succeeded
            : TomAuditOutcome.failed,
        detail: delivery.succeeded
            ? '${delivery.recordCount} record(s) to '
                  '${question.recipients.length} recipient(s) as '
                  '${delivery.exportKey}'
            : 'delivery failed: ${delivery.error}',
      );
      final next = question.nextAfter(now);
      await questions.save(
        question.copyWith(
          lastDeliveredAt: delivery.succeeded ? now : null,
          nextDeliveryAt: next,
          clearNextDelivery: next == null,
        ),
      );
      done.add(delivery);
    }
    return done;
  }

  Future<TomAuditReportDelivery> _deliver(
    TomAuditQuestion question,
    DateTime now,
  ) async {
    final exports = this.exports;
    final email = this.email;
    if (exports == null || email == null) {
      throw TomAuditReportException(
        'audit_reports.delivery.not_configured',
        'This process does not deliver audit reports: it has no export '
            'service or email delivery.',
        parameters: {'id': question.id},
      );
    }
    final query = question.filter.toQuery(now);
    final answer = await view.query(query, writers: question.filter.writers);
    final stored = await exports.storeAs(
      tabularOf(question.name, answer),
      question.format,
      key: exports.keyFor(
        'audit-${question.name}',
        question.format,
        partitionOn: now,
      ),
      owner: question.owner,
    );
    final parameters = {
      'name': question.name,
      'count': answer.entries.length,
      'from': ?query.from?.toIso8601String(),
      'to': ?query.to?.toIso8601String(),
    };
    await email.send(
      stored,
      to: [for (final address in question.recipients) TomRecipient(address)],
      subject: _text('subject', parameters),
      text: _text('text', parameters),
    );
    return TomAuditReportDelivery(
      question: question,
      recordCount: answer.entries.length,
      exportKey: stored.key,
    );
  }

  String _text(String part, Map<String, Object?> parameters) {
    final texts = _texts ?? TomLocalizedTextResources.resolve();
    final key = 'audit_reports.delivery.$part';
    final value = texts?.textOrNull(key, parameters: parameters);
    if (value == null) {
      throw TomAuditReportException(
        'audit_reports.delivery.text_missing',
        'The audit report delivery has no $part text.',
        parameters: {'resourceKey': key},
      );
    }
    return value;
  }

  /// The columns of an exported answer.
  static final List<TomTabularColumn> columns = [
    TomTabularColumn('timestamp', label: 'Time'),
    TomTabularColumn('writer', label: 'Writer'),
    TomTabularColumn('actor', label: 'Actor'),
    TomTabularColumn('action', label: 'Action'),
    TomTabularColumn('target', label: 'Target'),
    TomTabularColumn('targetKey', label: 'Key'),
    TomTabularColumn('outcome', label: 'Outcome'),
    TomTabularColumn('requestId', label: 'Request'),
    TomTabularColumn('detail', label: 'Detail'),
  ];

  /// [answer] as an export of one section, titled [title].
  static TomTabularResult tabularOf(String title, TomAuditViewResult answer) =>
      TomTabularResult.single(
        title: title,
        section: TomTabularSection.ofMaps(
          columns,
          Stream.fromIterable([
            for (final row in answer.entries)
              {
                'timestamp': row.entry.record.timestamp
                    .toUtc()
                    .toIso8601String(),
                'writer': row.writer,
                'actor': row.entry.record.actor.username,
                'action': row.entry.record.action.name,
                'target': row.entry.record.target,
                'targetKey': row.entry.record.targetKey ?? '',
                'outcome': row.entry.record.outcome.name,
                'requestId': row.entry.record.requestId ?? '',
                'detail': row.entry.record.detail ?? '',
              },
          ]),
        ),
        metadata: {
          'Writers': answer.writers.join(', '),
          'Records':
              '${answer.entries.length}'
              '${answer.hasMore ? ' (more matched)' : ''}',
        },
      );

  /// Registers the delivery pass on [scheduler]: [deliverDue] every
  /// [every]. In a cluster the scheduler's lease runs each pass on one node.
  TomJobDefinition registerOn(
    TomScheduler scheduler, {
    Duration every = const Duration(minutes: 1),
  }) {
    final definition = TomJobDefinition(
      name: jobName,
      schedule: TomIntervalSchedule(every),
      body: (run) => _TomAuditReportsCommand(this),
    );
    scheduler.register(definition);
    return definition;
  }
}

class _TomAuditReportsCommand extends TomCommand {
  final TomAuditReports _reports;

  _TomAuditReportsCommand(this._reports);

  @override
  Future<Object?> execute() async {
    final deliveries = await _reports.deliverDue();
    return {
      'delivered': deliveries.where((d) => d.succeeded).length,
      'failed': deliveries.where((d) => !d.succeeded).length,
    };
  }
}
