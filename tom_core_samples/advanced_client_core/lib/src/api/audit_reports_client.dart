/// The typed client of the framework's audit-report API
/// (`tomAuditReportsApi`), which the app server serves to callers holding the
/// `auditor` role.
///
/// Every route and body comes from the kernel's contract: [registryRoute]
/// resolves the address from the declaration, and each answer is read by its
/// DTO's `fromJson`, so the client and the server cannot spell a route or a
/// field differently.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../http/authorized_http.dart';
import '../http/json_transport.dart';
import '../http/registry_route.dart';

/// A call to the audit-report API that did not succeed.
///
/// [key] is the server's error key (`audit_reports.question.not_found`, …), or
/// `audit_reports.request.failed` when the answer carried none — a caller
/// without the `auditor` role is answered `404` like a route that does not
/// exist.
class AuditReportsException extends TomException {
  /// The HTTP status of the answer.
  final int statusCode;

  /// Creates the exception.
  AuditReportsException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
  });
}

/// Calls the audit-report API with the caller's bearer token.
class AuditReportsClient {
  /// The server's base address (the app server).
  final Uri baseUri;

  final AuthorizedHttp _http;

  /// Creates a client calling [baseUri] through [http].
  AuditReportsClient(this.baseUri, AuthorizedHttp http) : _http = http {
    registerTomAuditReportsApi();
  }

  /// The writers (hash chains) the trail holds records of.
  Future<List<String>> writers() async => TomAuditReportWritersDto.fromJson(
    (await _call(tomAuditReportsWritersEndpointId)).jsonObject,
  ).writers;

  /// [filter] answered once; the keys are those `tomAuditReportsApi`
  /// documents.
  Future<TomAuditReportResultDto> query(Map<String, Object?> filter) async =>
      TomAuditReportResultDto.fromJson(
        (await _call(
          tomAuditReportsQueryEndpointId,
          body: TomAuditReportQueryRequest(filter: filter).toJson(),
        )).jsonObject,
      );

  /// The caller's saved questions, by name.
  Future<List<TomAuditQuestionDto>> questions() async =>
      TomAuditQuestionsDto.fromJson(
        (await _call(tomAuditReportsListQuestionsEndpointId)).jsonObject,
      ).questions;

  /// Saves [question] — a new one when its id is empty — and answers it as
  /// stored, with its next delivery.
  Future<TomAuditQuestionDto> save(TomAuditQuestionDto question) async =>
      TomAuditQuestionDto.fromJson(
        (await _call(
          tomAuditReportsSaveQuestionEndpointId,
          body: question.toJson(),
        )).jsonObject,
      );

  /// Removes the caller's question [id].
  Future<void> delete(String id) async {
    await _call(
      tomAuditReportsDeleteQuestionEndpointId,
      parameters: {'id': id},
    );
  }

  /// The caller's question [id], answered now.
  Future<TomAuditReportResultDto> answer(String id) async =>
      TomAuditReportResultDto.fromJson(
        (await _call(
          tomAuditReportsAnswerEndpointId,
          parameters: {'id': id},
        )).jsonObject,
      );

  /// Has the caller's question [id] delivered at the next delivery pass;
  /// answers the question with that delivery as its next one.
  Future<TomAuditQuestionDto> deliver(String id) async =>
      TomAuditQuestionDto.fromJson(
        (await _call(
          tomAuditReportsDeliverEndpointId,
          parameters: {'id': id},
        )).jsonObject,
      );

  Future<HttpJsonResponse> _call(
    String endpointId, {
    Map<String, Object?> parameters = const {},
    Map<String, Object?>? body,
  }) async {
    final route = registryRoute(
      tomAuditReportsApi,
      endpointId,
      baseUri,
      parameters: parameters,
    );
    final response = await _http.send(
      method: route.method,
      uri: route.uri,
      body: body == null ? null : jsonEncode(body),
    );

    if (!response.isSuccess) {
      throw AuditReportsException(
        _errorKey(response) ?? 'audit_reports.request.failed',
        'Audit reports $endpointId (${route.method} ${route.uri.path}) '
        'failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  String? _errorKey(HttpJsonResponse response) {
    try {
      final key = response.jsonObject['errorKey'];
      return key is String ? key : null;
    } on FormatException {
      return null;
    }
  }
}
