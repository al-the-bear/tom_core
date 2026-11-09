/// What a client shares with a Tom server about audit reports: the questions
/// an auditor asks of the audit trail, the answers, and the API that serves
/// them.
///
/// `tom_core_server` implements the API (its `audit_reports` module); a client
/// calls it at the addresses [tomAuditReportsApi] declares. Every endpoint
/// requires [tomAuditorRole]. The API answers a question across every writer
/// of the trail (each server process keeps a hash chain of its own), keeps an
/// auditor's saved questions, and has a saved question delivered — on its
/// schedule, or at the next delivery pass when asked — as a CSV, XLSX or PDF
/// export by email.
///
/// A question's filter is a JSON map, the same one the server stores:
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `actor` | the acting user's name |
/// | `action` | `create`, `update`, `delete`, `read` or `execute` |
/// | `target` / `targetKey` | what was acted on |
/// | `outcome` | `succeeded`, `failed` or `denied` |
/// | `requestId` | one request's records |
/// | `from` / `to` | an absolute window, ISO-8601 instants |
/// | `lastHours` | a window of that many hours ending when the question is asked |
/// | `writers` | the chains to read; every writer when absent |
/// | `limit` | at most this many records (500 by default, 5000 at most) |
library;

import '../http_connection/endpoints_apis.dart';
import '../http_connection/httpmethods.dart';
import '../json/json_serializable.dart';
import '../reflection/reflection.dart';
import 'access_controls.dart';

/// The role the audit-report API requires.
const String tomAuditorRole = 'auditor';

/// The access every audit-report endpoint requires.
const TomRoleAccess tomAuditorAccess = TomRoleAccess([tomAuditorRole]);

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : <String, Object?>{};

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String) item,
];

/// The writers (hash chains) the audit trail holds records of.
@tomReflector
class TomAuditReportWritersDto implements TomJsonSerializable {
  /// The writers, by name.
  List<String> writers;

  /// Creates the list.
  TomAuditReportWritersDto({List<String>? writers}) : writers = writers ?? [];

  /// Reads [toJson]'s form.
  factory TomAuditReportWritersDto.fromJson(Map<String, Object?> json) =>
      TomAuditReportWritersDto(writers: _strings(json['writers']));

  @override
  Map<String, Object?> toJson() => {'writers': writers};
}

/// A question asked of the audit trail once, without saving it.
@tomReflector
class TomAuditReportQueryRequest implements TomJsonSerializable {
  /// The filter; see the library documentation for its keys.
  Map<String, Object?> filter;

  /// Creates a request.
  TomAuditReportQueryRequest({Map<String, Object?>? filter})
    : filter = filter ?? {};

  /// Reads [toJson]'s form.
  factory TomAuditReportQueryRequest.fromJson(Map<String, Object?> json) =>
      TomAuditReportQueryRequest(filter: _map(json['filter']));

  @override
  Map<String, Object?> toJson() => {'filter': filter};
}

/// One record of an answer: the writer whose chain holds it, its position in
/// that chain, its hash, and the record itself as JSON.
@tomReflector
class TomAuditReportEntryDto implements TomJsonSerializable {
  /// The writer (chain) the record belongs to.
  String writer;

  /// Its position within the writer's chain, counted from genesis.
  int index;

  /// Its hash in the chain.
  String hash;

  /// The record, in the server's `TomAuditRecord.toJson` form.
  Map<String, Object?> record;

  /// Creates an entry.
  TomAuditReportEntryDto({
    this.writer = '',
    this.index = 0,
    this.hash = '',
    Map<String, Object?>? record,
  }) : record = record ?? {};

  /// Reads [toJson]'s form.
  factory TomAuditReportEntryDto.fromJson(Map<String, Object?> json) =>
      TomAuditReportEntryDto(
        writer: json['writer'] as String? ?? '',
        index: json['index'] as int? ?? 0,
        hash: json['hash'] as String? ?? '',
        record: _map(json['record']),
      );

  @override
  Map<String, Object?> toJson() => {
    'writer': writer,
    'index': index,
    'hash': hash,
    'record': record,
  };
}

/// The answer to a question: the matching records across the writers asked,
/// newest first.
@tomReflector
class TomAuditReportResultDto implements TomJsonSerializable {
  /// The records.
  List<TomAuditReportEntryDto> entries;

  /// Whether more records matched than the answer carries.
  bool hasMore;

  /// The writers that were asked.
  List<String> writers;

  /// Creates a result.
  TomAuditReportResultDto({
    List<TomAuditReportEntryDto>? entries,
    this.hasMore = false,
    List<String>? writers,
  }) : entries = entries ?? [],
       writers = writers ?? [];

  /// Reads [toJson]'s form.
  factory TomAuditReportResultDto.fromJson(Map<String, Object?> json) =>
      TomAuditReportResultDto(
        entries: [
          for (final entry in json['entries'] as List? ?? const [])
            TomAuditReportEntryDto.fromJson(_map(entry)),
        ],
        hasMore: json['hasMore'] as bool? ?? false,
        writers: _strings(json['writers']),
      );

  @override
  Map<String, Object?> toJson() => {
    'entries': [for (final entry in entries) entry.toJson()],
    'hasMore': hasMore,
    'writers': writers,
  };
}

/// A saved question.
@tomReflector
class TomAuditQuestionDto implements TomJsonSerializable {
  /// Its id; empty when saving a new question.
  String id;

  /// What the auditor calls it.
  String name;

  /// The principal that saved it; set by the server.
  String owner;

  /// The filter; see the library documentation for its keys.
  Map<String, Object?> filter;

  /// When it is delivered: a five-field cron expression in UTC
  /// (`0 6 * * 1` — Mondays at 06:00), or empty for never.
  String schedule;

  /// The email addresses a delivery goes to.
  List<String> recipients;

  /// The format of a delivery: `csv`, `xlsx` or `pdf`.
  String format;

  /// When it was last delivered (ISO-8601), or empty.
  String lastDeliveredAt;

  /// When it is next delivered (ISO-8601), or empty for never.
  String nextDeliveryAt;

  /// Creates a question.
  TomAuditQuestionDto({
    this.id = '',
    this.name = '',
    this.owner = '',
    Map<String, Object?>? filter,
    this.schedule = '',
    List<String>? recipients,
    this.format = 'csv',
    this.lastDeliveredAt = '',
    this.nextDeliveryAt = '',
  }) : filter = filter ?? {},
       recipients = recipients ?? [];

  /// Reads [toJson]'s form.
  factory TomAuditQuestionDto.fromJson(Map<String, Object?> json) =>
      TomAuditQuestionDto(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        owner: json['owner'] as String? ?? '',
        filter: _map(json['filter']),
        schedule: json['schedule'] as String? ?? '',
        recipients: _strings(json['recipients']),
        format: json['format'] as String? ?? 'csv',
        lastDeliveredAt: json['lastDeliveredAt'] as String? ?? '',
        nextDeliveryAt: json['nextDeliveryAt'] as String? ?? '',
      );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'owner': owner,
    'filter': filter,
    'schedule': schedule,
    'recipients': recipients,
    'format': format,
    'lastDeliveredAt': lastDeliveredAt,
    'nextDeliveryAt': nextDeliveryAt,
  };
}

/// The caller's saved questions, by name.
@tomReflector
class TomAuditQuestionsDto implements TomJsonSerializable {
  /// The questions.
  List<TomAuditQuestionDto> questions;

  /// Creates the list.
  TomAuditQuestionsDto({List<TomAuditQuestionDto>? questions})
    : questions = questions ?? [];

  /// Reads [toJson]'s form.
  factory TomAuditQuestionsDto.fromJson(Map<String, Object?> json) =>
      TomAuditQuestionsDto(
        questions: [
          for (final question in json['questions'] as List? ?? const [])
            TomAuditQuestionDto.fromJson(_map(question)),
        ],
      );

  @override
  Map<String, Object?> toJson() => {
    'questions': [for (final question in questions) question.toJson()],
  };
}

/// Names one saved question.
@tomReflector
class TomAuditQuestionIdRequest implements TomJsonSerializable {
  /// The question's id.
  String id;

  /// Creates a request.
  TomAuditQuestionIdRequest({this.id = ''});

  /// Reads [toJson]'s form.
  factory TomAuditQuestionIdRequest.fromJson(Map<String, Object?> json) =>
      TomAuditQuestionIdRequest(id: json['id'] as String? ?? '');

  @override
  Map<String, Object?> toJson() => {'id': id};
}

/// The id of the audit-report API in the remote-API registry.
const String tomAuditReportsApiId = 'tomAuditReports';

/// `GET /audit-reports/writers`.
const String tomAuditReportsWritersEndpointId = 'auditReportWriters';

/// `POST /audit-reports/query`.
const String tomAuditReportsQueryEndpointId = 'auditReportQuery';

/// `GET /audit-reports/questions`.
const String tomAuditReportsListQuestionsEndpointId = 'auditReportQuestions';

/// `PUT /audit-reports/questions`.
const String tomAuditReportsSaveQuestionEndpointId = 'auditReportSaveQuestion';

/// `DELETE /audit-reports/questions/{id}`.
const String tomAuditReportsDeleteQuestionEndpointId =
    'auditReportDeleteQuestion';

/// `GET /audit-reports/questions/{id}/answer`.
const String tomAuditReportsAnswerEndpointId = 'auditReportAnswer';

/// `POST /audit-reports/questions/{id}/deliver`.
const String tomAuditReportsDeliverEndpointId = 'auditReportDeliver';

/// The audit-report API, for a caller holding [tomAuditorRole].
///
/// ```text
/// GET    /audit-reports/writers                → TomAuditReportWritersDto
/// POST   /audit-reports/query                  TomAuditReportQueryRequest → TomAuditReportResultDto
/// GET    /audit-reports/questions              → TomAuditQuestionsDto
/// PUT    /audit-reports/questions              TomAuditQuestionDto → TomAuditQuestionDto
/// DELETE /audit-reports/questions/{id}
/// GET    /audit-reports/questions/{id}/answer  → TomAuditReportResultDto
/// POST   /audit-reports/questions/{id}/deliver → TomAuditQuestionDto
/// ```
final TomApi tomAuditReportsApi = TomApi(
  id: tomAuditReportsApiId,
  name: 'Audit Reports API',
  description:
      'Questions asked of the audit trail across its writers, saved questions '
      'and their scheduled deliveries.',
  uri: '/audit-reports',
  endpoints: [
    TomApiEndpoint<TomAuditReportWritersDto, Object?>(
      id: tomAuditReportsWritersEndpointId,
      uri: '/writers',
      method: TomHttpMethod.get,
      description: 'The writers (chains) the trail holds records of.',
      requestTypes: const [],
      access: tomAuditorAccess,
    ),
    TomApiEndpoint<TomAuditReportResultDto, TomAuditReportQueryRequest>(
      id: tomAuditReportsQueryEndpointId,
      uri: '/query',
      method: TomHttpMethod.post,
      description: 'Answers a question once, across the writers it names.',
      access: tomAuditorAccess,
    ),
    TomApiEndpoint<TomAuditQuestionsDto, Object?>(
      id: tomAuditReportsListQuestionsEndpointId,
      uri: '/questions',
      method: TomHttpMethod.get,
      description: 'The questions the caller saved, by name.',
      requestTypes: const [],
      access: tomAuditorAccess,
    ),
    TomApiEndpoint<TomAuditQuestionDto, TomAuditQuestionDto>(
      id: tomAuditReportsSaveQuestionEndpointId,
      uri: '/questions',
      method: TomHttpMethod.put,
      description:
          'Saves a question of the caller — a new one when its id is empty — '
          'and answers it as stored, with its next delivery.',
      access: tomAuditorAccess,
    ),
    TomApiEndpoint<void, TomAuditQuestionIdRequest>(
      id: tomAuditReportsDeleteQuestionEndpointId,
      uri: '/questions/{id}',
      method: TomHttpMethod.delete,
      description: 'Removes one of the caller\'s questions.',
      urlParameterMapping: const {'id': 'id'},
      access: tomAuditorAccess,
    ),
    TomApiEndpoint<TomAuditReportResultDto, TomAuditQuestionIdRequest>(
      id: tomAuditReportsAnswerEndpointId,
      uri: '/questions/{id}/answer',
      method: TomHttpMethod.get,
      urlParameterMapping: const {'id': 'id'},
      description: 'Answers one of the caller\'s questions now.',
      access: tomAuditorAccess,
    ),
    TomApiEndpoint<TomAuditQuestionDto, TomAuditQuestionIdRequest>(
      id: tomAuditReportsDeliverEndpointId,
      uri: '/questions/{id}/deliver',
      method: TomHttpMethod.post,
      urlParameterMapping: const {'id': 'id'},
      description:
          'Has one of the caller\'s questions delivered at the next delivery '
          'pass rather than at its scheduled time; answers the question with '
          'that delivery as its next one.',
      access: tomAuditorAccess,
    ),
  ],
);

/// Registers [tomAuditReportsApi] in the remote-API registry; idempotent.
void registerTomAuditReportsApi() {
  tomRemoteApis.register(tomAuditReportsApi);
}

/// The typed service interface behind [tomAuditReportsApi]; the server
/// implements it.
abstract class TomAuditReportsApiService {
  /// [tomAuditReportsWritersEndpointId] — the writers of the trail.
  Future<TomAuditReportWritersDto> auditReportWriters();

  /// [tomAuditReportsQueryEndpointId] — [request]'s filter answered once.
  Future<TomAuditReportResultDto> auditReportQuery(
    TomAuditReportQueryRequest request,
  );

  /// [tomAuditReportsListQuestionsEndpointId] — the caller's questions.
  Future<TomAuditQuestionsDto> auditReportQuestions();

  /// [tomAuditReportsSaveQuestionEndpointId] — saves [request] as the
  /// caller's.
  Future<TomAuditQuestionDto> auditReportSaveQuestion(
    TomAuditQuestionDto request,
  );

  /// [tomAuditReportsDeleteQuestionEndpointId] — removes the caller's
  /// question [request] names.
  Future<void> auditReportDeleteQuestion(TomAuditQuestionIdRequest request);

  /// [tomAuditReportsAnswerEndpointId] — the caller's question answered now.
  Future<TomAuditReportResultDto> auditReportAnswer(
    TomAuditQuestionIdRequest request,
  );

  /// [tomAuditReportsDeliverEndpointId] — the caller's question marked for
  /// delivery at the next pass.
  Future<TomAuditQuestionDto> auditReportDeliver(
    TomAuditQuestionIdRequest request,
  );
}
