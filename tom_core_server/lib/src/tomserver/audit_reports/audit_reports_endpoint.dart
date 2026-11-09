/// The endpoints of `tomAuditReportsApi`: what an auditor's application talks
/// to.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'audit_question.dart';
import 'audit_reports_service.dart';
import 'audit_view.dart';

/// Maps the audit-report refusals to their statuses: a question that is not
/// the caller's (or not there) is a `404`, one that cannot be read a `400`,
/// one with nowhere to deliver to a `409`, a server that is not set up for
/// audit reports a `503`.
class TomAuditReportsErrorHandler extends TomStatusMappingErrorHandler {
  /// Creates the handler.
  const TomAuditReportsErrorHandler();

  @override
  Map<String, int> get statusByErrorKey => const {
    'audit_reports.question.not_found': 404,
    'audit_reports.question.invalid': 400,
    'audit_reports.question.no_recipients': 409,
    'audit_reports.not_configured': 503,
    'audit_reports.no_principal': 401,
  };
}

/// The implementation of `tomAuditReportsApi`, over the installed
/// [TomAuditReports].
///
/// Every endpoint is the caller's: saved questions are listed, answered,
/// changed and delivered only for the principal that saved them.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: tomAuditReportsApiId)
class TomAuditReportsServer implements TomAuditReportsApiService {
  /// Const constructor: the endpoint keeps no state of its own.
  const TomAuditReportsServer();

  static TomAuditReports _reports() =>
      TomAuditReports.resolve() ??
      (throw TomAuditReportException(
        'audit_reports.not_configured',
        'This server does not serve audit reports.',
      ));

  static String _caller() {
    final principal = getFromCurrentZone<TomPrincipal>();
    if (principal == null) {
      throw TomAuditReportException(
        'audit_reports.no_principal',
        'Audit reports are served to an authenticated caller.',
      );
    }
    return principal.qualifiedId;
  }

  /// The writers of the trail.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsWritersEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<TomAuditReportWritersDto> auditReportWriters() async =>
      TomAuditReportWritersDto(writers: await _reports().writers());

  /// A question answered once.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsQueryEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<TomAuditReportResultDto> auditReportQuery(
    TomAuditReportQueryRequest request,
  ) async => resultDto(
    await _reports().ask(TomAuditQuestionFilter.fromJson(request.filter)),
  );

  /// The caller's saved questions.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsListQuestionsEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<TomAuditQuestionsDto> auditReportQuestions() async =>
      TomAuditQuestionsDto(
        questions: [
          for (final question in await _reports().questionsOf(_caller()))
            questionDto(question),
        ],
      );

  /// Saves one of the caller's questions.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsSaveQuestionEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<TomAuditQuestionDto> auditReportSaveQuestion(
    TomAuditQuestionDto request,
  ) async => questionDto(await _reports().save(_caller(), questionOf(request)));

  /// Removes one of the caller's questions.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsDeleteQuestionEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<void> auditReportDeleteQuestion(TomAuditQuestionIdRequest request) =>
      _reports().remove(_caller(), request.id);

  /// One of the caller's questions, answered now.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsAnswerEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<TomAuditReportResultDto> auditReportAnswer(
    TomAuditQuestionIdRequest request,
  ) async {
    final reports = _reports();
    final question = await reports.questionOf(_caller(), request.id);
    return resultDto(await reports.ask(question.filter));
  }

  /// One of the caller's questions, marked for delivery at the next pass.
  @TomApiEndpointImplementation(
    apiId: tomAuditReportsApiId,
    endpointId: tomAuditReportsDeliverEndpointId,
    errorHandler: TomAuditReportsErrorHandler(),
  )
  @override
  Future<TomAuditQuestionDto> auditReportDeliver(
    TomAuditQuestionIdRequest request,
  ) async => questionDto(await _reports().deliverSoon(_caller(), request.id));

  /// [result] for the wire.
  static TomAuditReportResultDto resultDto(TomAuditViewResult result) =>
      TomAuditReportResultDto(
        entries: [
          for (final row in result.entries)
            TomAuditReportEntryDto(
              writer: row.writer,
              index: row.entry.index,
              hash: row.entry.hash,
              record: row.entry.record.toJson(),
            ),
        ],
        hasMore: result.hasMore,
        writers: result.writers,
      );

  /// [question] for the wire.
  static TomAuditQuestionDto questionDto(
    TomAuditQuestion question,
  ) => TomAuditQuestionDto(
    id: question.id,
    name: question.name,
    owner: question.owner,
    filter: question.filter.toJson(),
    schedule: question.schedule ?? '',
    recipients: question.recipients,
    format: question.format,
    lastDeliveredAt: question.lastDeliveredAt?.toUtc().toIso8601String() ?? '',
    nextDeliveryAt: question.nextDeliveryAt?.toUtc().toIso8601String() ?? '',
  );

  /// The question [dto] describes; its owner and delivery times are the
  /// server's to set.
  static TomAuditQuestion questionOf(TomAuditQuestionDto dto) =>
      TomAuditQuestion(
        id: dto.id,
        name: dto.name,
        owner: '',
        filter: TomAuditQuestionFilter.fromJson(dto.filter),
        schedule: dto.schedule,
        recipients: dto.recipients,
        format: dto.format,
      );
}
