/// Saved questions: an auditor's filter of the audit trail, kept under a name,
/// with the schedule and the recipients its deliveries go to.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_query.dart';
import '../audit/audit_record.dart';
import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';

/// Raised when a question cannot be read, saved, found or answered; [key]
/// names which (`audit_reports.question.invalid`,
/// `audit_reports.question.not_found`, …).
class TomAuditReportException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomAuditReportException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// The data source registered as [name], for the `.named` constructors of
/// this module; refuses (`audit_reports.<part>.unknown_datasource`) a name the
/// registry does not hold.
TomDataSource tomAuditReportsDatasource(String name, String part) {
  final info = TomDataSourceInfo.getBaseDataSourceInfo(name);
  if (info == null) {
    throw TomAuditReportException(
      'audit_reports.$part.unknown_datasource',
      'The audit reports refer to a data source that is not registered.',
      parameters: {'datasource': name},
    );
  }
  return info.datasource;
}

Never _invalid(String reason, [Map<String, Object?> parameters = const {}]) =>
    throw TomAuditReportException(
      'audit_reports.question.invalid',
      'The question cannot be read: $reason.',
      parameters: {'reason': reason, ...parameters},
    );

/// What a question asks: the record fields it narrows to and the window.
///
/// The window is either absolute ([from], [to]) or relative ([lastHours],
/// ending when the question is asked), never both — a saved question delivered
/// every Monday asks about the week before *that* Monday.
class TomAuditQuestionFilter {
  /// The acting user's name.
  final String? actor;

  /// The action.
  final TomAuditAction? action;

  /// What was acted on.
  final String? target;

  /// The key of what was acted on.
  final String? targetKey;

  /// The outcome.
  final TomAuditOutcome? outcome;

  /// One request's records.
  final String? requestId;

  /// The window's start (inclusive).
  final DateTime? from;

  /// The window's end (exclusive).
  final DateTime? to;

  /// A window of this many hours, ending when the question is asked.
  final int? lastHours;

  /// The writers to read; every writer when `null`.
  final List<String>? writers;

  /// At most this many records.
  final int limit;

  /// The most records a question may ask for.
  static const int maxLimit = 5000;

  /// Creates a filter; refuses (`audit_reports.question.invalid`) an absolute
  /// and a relative window together, a non-positive [lastHours], a window
  /// ending before it starts, and a [limit] outside 1..[maxLimit].
  TomAuditQuestionFilter({
    this.actor,
    this.action,
    this.target,
    this.targetKey,
    this.outcome,
    this.requestId,
    this.from,
    this.to,
    this.lastHours,
    List<String>? writers,
    this.limit = TomAuditQuery.defaultLimit,
  }) : writers = writers == null ? null : List.unmodifiable(writers) {
    if (lastHours != null && (from != null || to != null)) {
      _invalid('a window is either from/to or lastHours, not both');
    }
    if (lastHours != null && lastHours! <= 0) {
      _invalid('lastHours must be positive', {'lastHours': lastHours});
    }
    if (from != null && to != null && !to!.isAfter(from!)) {
      _invalid('the window ends before it starts');
    }
    if (limit < 1 || limit > maxLimit) {
      _invalid('limit must be 1 to $maxLimit', {'limit': limit});
    }
  }

  /// Reads the JSON form (the keys `tomAuditReportsApi` documents); refuses
  /// an unknown key or a value of the wrong kind.
  factory TomAuditQuestionFilter.fromJson(Map<String, Object?> json) {
    const known = {
      'actor',
      'action',
      'target',
      'targetKey',
      'outcome',
      'requestId',
      'from',
      'to',
      'lastHours',
      'writers',
      'limit',
    };
    final unknown = json.keys.where((k) => !known.contains(k)).toList();
    if (unknown.isNotEmpty) {
      _invalid('unknown filter keys ${unknown.join(', ')}', {'keys': unknown});
    }
    String? text(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) _invalid('$key must be a string');
      return value.trim().isEmpty ? null : value.trim();
    }

    T? named<T extends Enum>(String key, List<T> values) {
      final name = text(key);
      if (name == null) return null;
      for (final value in values) {
        if (value.name == name) return value;
      }
      _invalid("$key '$name' is not one of ${values.map((v) => v.name)}");
    }

    DateTime? instant(String key) {
      final value = text(key);
      if (value == null) return null;
      return DateTime.tryParse(value)?.toUtc() ??
          _invalid('$key is not an ISO-8601 instant');
    }

    int? whole(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num && value == value.roundToDouble()) return value.toInt();
      _invalid('$key must be a whole number');
    }

    final writers = json['writers'];
    if (writers != null &&
        (writers is! List || writers.any((w) => w is! String))) {
      _invalid('writers must be a list of names');
    }
    return TomAuditQuestionFilter(
      actor: text('actor'),
      action: named('action', TomAuditAction.values),
      target: text('target'),
      targetKey: text('targetKey'),
      outcome: named('outcome', TomAuditOutcome.values),
      requestId: text('requestId'),
      from: instant('from'),
      to: instant('to'),
      lastHours: whole('lastHours'),
      writers: writers == null ? null : (writers as List).cast<String>(),
      limit: whole('limit') ?? TomAuditQuery.defaultLimit,
    );
  }

  /// The JSON form; only the keys that are set.
  Map<String, Object?> toJson() => {
    'actor': ?actor,
    'action': ?action?.name,
    'target': ?target,
    'targetKey': ?targetKey,
    'outcome': ?outcome?.name,
    'requestId': ?requestId,
    'from': ?from?.toUtc().toIso8601String(),
    'to': ?to?.toUtc().toIso8601String(),
    'lastHours': ?lastHours,
    'writers': ?writers,
    if (limit != TomAuditQuery.defaultLimit) 'limit': limit,
  };

  /// The query this filter asks at [now], newest first — of [tenant]'s
  /// entries only when given.
  TomAuditQuery toQuery(DateTime now, {String? tenant}) => TomAuditQuery(
    from:
        from ??
        (lastHours == null
            ? null
            : now.toUtc().subtract(Duration(hours: lastHours!))),
    to: to ?? (lastHours == null ? null : now.toUtc()),
    actor: actor,
    action: action,
    target: target,
    targetKey: targetKey,
    outcome: outcome,
    requestId: requestId,
    tenant: tenant,
    limit: limit,
  );
}

/// The formats a delivery can take.
const List<String> tomAuditReportFormats = ['csv', 'xlsx', 'pdf'];

/// A saved question.
class TomAuditQuestion {
  /// Its id.
  final String id;

  /// What the auditor calls it.
  final String name;

  /// The principal that saved it ([TomPrincipal.qualifiedId]).
  final String owner;

  /// What it asks.
  final TomAuditQuestionFilter filter;

  /// When it is delivered (a five-field cron expression in UTC), or `null`.
  final String? schedule;

  /// Where its deliveries go.
  final List<String> recipients;

  /// The format of a delivery: one of [tomAuditReportFormats].
  final String format;

  /// When it was last delivered.
  final DateTime? lastDeliveredAt;

  /// When it is next delivered, or `null` for never.
  final DateTime? nextDeliveryAt;

  static final RegExp _address = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Creates a question; refuses (`audit_reports.question.invalid`) an empty
  /// name, an unknown format, a schedule that is not a cron expression, a
  /// recipient that is not an email address, and a schedule without
  /// recipients.
  TomAuditQuestion({
    required this.id,
    required this.name,
    required this.owner,
    required this.filter,
    String? schedule,
    List<String> recipients = const [],
    this.format = 'csv',
    this.lastDeliveredAt,
    this.nextDeliveryAt,
  }) : schedule = schedule == null || schedule.trim().isEmpty
           ? null
           : schedule.trim(),
       recipients = List.unmodifiable(recipients) {
    if (name.trim().isEmpty) _invalid('a question needs a name');
    if (!tomAuditReportFormats.contains(format)) {
      _invalid("format '$format' is not one of $tomAuditReportFormats");
    }
    for (final recipient in this.recipients) {
      if (!_address.hasMatch(recipient)) {
        _invalid("'$recipient' is not an email address");
      }
    }
    if (this.schedule != null) {
      cron;
      if (this.recipients.isEmpty) {
        _invalid('a scheduled question needs at least one recipient');
      }
    }
  }

  /// The schedule as a cron schedule, or `null`.
  TomCronSchedule? get cron {
    final expression = schedule;
    if (expression == null) return null;
    try {
      return TomCronSchedule(expression);
    } on TomScheduleException catch (error) {
      _invalid("the schedule '$expression' is not a cron expression", {
        'cause': error.key,
      });
    }
  }

  /// The first delivery its schedule makes after [after], or `null`.
  DateTime? nextAfter(DateTime after) => cron?.nextFireAfter(after.toUtc());

  /// A copy with the fields given replaced.
  TomAuditQuestion copyWith({
    String? id,
    String? owner,
    DateTime? lastDeliveredAt,
    DateTime? nextDeliveryAt,
    bool clearNextDelivery = false,
  }) => TomAuditQuestion(
    id: id ?? this.id,
    name: name,
    owner: owner ?? this.owner,
    filter: filter,
    schedule: schedule,
    recipients: recipients,
    format: format,
    lastDeliveredAt: lastDeliveredAt ?? this.lastDeliveredAt,
    nextDeliveryAt: clearNextDelivery
        ? null
        : nextDeliveryAt ?? this.nextDeliveryAt,
  );

  /// The stored definition: everything but the identity and the delivery
  /// times.
  Map<String, Object?> definitionJson() => {
    'filter': filter.toJson(),
    'recipients': recipients,
    'format': format,
  };

  /// Reads [definitionJson]'s form back.
  static ({
    TomAuditQuestionFilter filter,
    List<String> recipients,
    String format,
  })
  readDefinition(Map<String, Object?> json) => (
    filter: TomAuditQuestionFilter.fromJson(
      (json['filter'] as Map? ?? const {}).cast<String, Object?>(),
    ),
    recipients: [
      for (final recipient in json['recipients'] as List? ?? const [])
        recipient as String,
    ],
    format: json['format'] as String? ?? 'csv',
  );
}
