/// The audit-report contract a client and a Tom server share: the routes, the
/// role every route requires, and the wire forms of the bodies.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  group('the audit-report API', () {
    final base = Uri.parse('https://api.example.com');

    test('ARC-1: the seven routes, under /audit-reports', () {
      String route(String id) {
        final endpoint = tomAuditReportsApi[id];
        return '${endpoint.method.name.toUpperCase()} '
            '${endpoint.resolveUri(base, parameters: {'id': 'q1'}).path}';
      }

      expect(
        route(tomAuditReportsWritersEndpointId),
        'GET /audit-reports/writers',
      );
      expect(
        route(tomAuditReportsQueryEndpointId),
        'POST /audit-reports/query',
      );
      expect(
        route(tomAuditReportsListQuestionsEndpointId),
        'GET /audit-reports/questions',
      );
      expect(
        route(tomAuditReportsSaveQuestionEndpointId),
        'PUT /audit-reports/questions',
      );
      expect(
        route(tomAuditReportsDeleteQuestionEndpointId),
        'DELETE /audit-reports/questions/q1',
      );
      expect(
        route(tomAuditReportsAnswerEndpointId),
        'GET /audit-reports/questions/q1/answer',
      );
      expect(
        route(tomAuditReportsDeliverEndpointId),
        'POST /audit-reports/questions/q1/deliver',
      );
      expect(tomAuditReportsApi.endpoints, hasLength(7));
    });

    test('ARC-2: every route requires the auditor role', () {
      for (final endpoint in tomAuditReportsApi.endpoints.values) {
        expect(endpoint.access, same(tomAuditorAccess), reason: endpoint.id);
      }
      expect(tomAuditorAccess.roles, [tomAuditorRole]);
      expect(tomAuditorRole, 'auditor');
    });

    test('ARC-3: registering is idempotent', () {
      registerTomAuditReportsApi();
      registerTomAuditReportsApi();
      expect(tomRemoteApis[tomAuditReportsApiId], same(tomAuditReportsApi));
    });
  });

  group('the wire forms', () {
    test('ARC-4: every body reads back from its JSON form', () {
      final question = TomAuditQuestionDto(
        id: 'q1',
        name: 'Denied this week',
        owner: 'audrey',
        filter: {'outcome': 'denied', 'lastHours': 168},
        schedule: '0 6 * * 1',
        recipients: ['auditor@example.com'],
        format: 'xlsx',
        lastDeliveredAt: '2026-11-02T06:00:00.000Z',
        nextDeliveryAt: '2026-11-09T06:00:00.000Z',
      );
      final forms =
          <
            Map<String, Object?>,
            Map<String, Object?> Function(Map<String, Object?>)
          >{
            question.toJson(): (j) => TomAuditQuestionDto.fromJson(j).toJson(),
            TomAuditQuestionsDto(questions: [question]).toJson(): (j) =>
                TomAuditQuestionsDto.fromJson(j).toJson(),
            TomAuditReportWritersDto(writers: ['node-a']).toJson(): (j) =>
                TomAuditReportWritersDto.fromJson(j).toJson(),
            TomAuditReportQueryRequest(
              filter: {'actor': 'ada'},
            ).toJson(): (j) =>
                TomAuditReportQueryRequest.fromJson(j).toJson(),
            TomAuditQuestionIdRequest(id: 'q1').toJson(): (j) =>
                TomAuditQuestionIdRequest.fromJson(j).toJson(),
            TomAuditReportResultDto(
              entries: [
                TomAuditReportEntryDto(
                  writer: 'node-a',
                  index: 4,
                  hash: 'ab',
                  record: {'id': 'r1'},
                ),
              ],
              hasMore: true,
              writers: ['node-a'],
            ).toJson(): (j) =>
                TomAuditReportResultDto.fromJson(j).toJson(),
          };
      forms.forEach((json, roundTrip) => expect(roundTrip(json), json));
    });

    test('ARC-5: an empty or partial body reads as the defaults', () {
      final question = TomAuditQuestionDto.fromJson({'name': 'n'});
      expect(question.id, '');
      expect(question.format, 'csv');
      expect(question.filter, isEmpty);
      expect(question.recipients, isEmpty);
      expect(TomAuditReportResultDto.fromJson({}).entries, isEmpty);
    });
  });
}
