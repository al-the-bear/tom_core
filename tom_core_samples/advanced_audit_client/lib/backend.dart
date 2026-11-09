/// What the audit application talks to: the live servers, or an in-memory
/// stand-in the widget tests drive.
library;

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A sign-in the application cannot complete: wrong credentials, a second
/// factor it does not offer, or an account without the auditor role.
class AuditSignInException implements Exception {
  /// What to tell the user.
  final String message;

  /// Creates the exception.
  const AuditSignInException(this.message);

  @override
  String toString() => message;
}

/// The operations the application performs.
abstract class AuditBackend {
  /// Signs in; answers the user's display name.
  Future<String> signIn(String username, String password);

  /// Signs out.
  Future<void> signOut();

  /// The writers of the trail.
  Future<List<String>> writers();

  /// [filter] answered once.
  Future<TomAuditReportResultDto> query(Map<String, Object?> filter);

  /// The user's saved questions.
  Future<List<TomAuditQuestionDto>> questions();

  /// Saves [question]; answers it as stored.
  Future<TomAuditQuestionDto> save(TomAuditQuestionDto question);

  /// Removes question [id].
  Future<void> delete(String id);

  /// Question [id], answered now.
  Future<TomAuditReportResultDto> answer(String id);

  /// Question [id], delivered at the next pass.
  Future<TomAuditQuestionDto> deliver(String id);
}

/// [AuditBackend] over the advanced sample's servers: sign-in at the auth
/// server, the audit-report API at the app server.
class LiveAuditBackend implements AuditBackend {
  final AuthClient _auth;
  final AuditReportsClient _reports;

  /// Creates the backend over an [AuthClient] and an [AuditReportsClient].
  LiveAuditBackend(this._auth, this._reports);

  /// The backend for the servers [AdvancedClientConfig] names.
  factory LiveAuditBackend.fromConfig() {
    final config = AdvancedClientConfig.resolve();
    final transport = HttpJsonTransport();
    final auth = AuthClient(
      Uri.parse(config.authServerUrl),
      transport: transport,
    );
    return LiveAuditBackend(
      auth,
      AuditReportsClient(
        Uri.parse(config.appServerUrl),
        AuthorizedHttp(transport, auth),
      ),
    );
  }

  @override
  Future<String> signIn(String username, String password) async {
    final LoginResult result;
    try {
      result = await _auth.login(
        LoginRequest(username: username, password: password),
      );
    } on TomException {
      throw const AuditSignInException('Wrong user name or password.');
    }
    if (result.requires2FA || result.requires2FAEnrolment) {
      await _auth.logout();
      throw const AuditSignInException(
        'This account signs in with a second factor, which this application '
        'does not offer.',
      );
    }
    try {
      await _reports.writers();
    } on AuditReportsException catch (error) {
      await _auth.logout();
      throw AuditSignInException(
        error.statusCode == 403 || error.statusCode == 404
            ? 'This account does not hold the auditor role.'
            : 'The audit reports could not be reached '
                  '(HTTP ${error.statusCode}).',
      );
    }
    return result.user.displayName.isEmpty
        ? result.user.username
        : result.user.displayName;
  }

  @override
  Future<void> signOut() => _auth.logout();

  @override
  Future<List<String>> writers() => _reports.writers();

  @override
  Future<TomAuditReportResultDto> query(Map<String, Object?> filter) =>
      _reports.query(filter);

  @override
  Future<List<TomAuditQuestionDto>> questions() => _reports.questions();

  @override
  Future<TomAuditQuestionDto> save(TomAuditQuestionDto question) =>
      _reports.save(question);

  @override
  Future<void> delete(String id) => _reports.delete(id);

  @override
  Future<TomAuditReportResultDto> answer(String id) => _reports.answer(id);

  @override
  Future<TomAuditQuestionDto> deliver(String id) => _reports.deliver(id);
}

/// [AuditBackend] in memory: a fixed trail of two writers and the questions
/// saved during the run.
class InMemoryAuditBackend implements AuditBackend {
  /// The records, newest first, each with its writer.
  final List<TomAuditReportEntryDto> trail;

  final Map<String, TomAuditQuestionDto> _questions = {};
  var _nextId = 1;

  /// Creates the backend over [trail] (a small sample trail by default).
  InMemoryAuditBackend({List<TomAuditReportEntryDto>? trail})
    : trail = trail ?? sampleTrail();

  /// Six records across the writers `app` and `ops`.
  static List<TomAuditReportEntryDto> sampleTrail() {
    TomAuditReportEntryDto entry(
      String writer,
      int index,
      String time,
      String actor,
      String action,
      String target,
      String outcome,
    ) => TomAuditReportEntryDto(
      writer: writer,
      index: index,
      hash: '$writer-$index',
      record: {
        'timestamp': time,
        'actor': {'username': actor},
        'action': action,
        'target': target,
        'outcome': outcome,
      },
    );
    return [
      entry(
        'app',
        2,
        '2026-10-27T10:30:00.000Z',
        'audrey',
        'read',
        'TomAuditQuestion',
        'succeeded',
      ),
      entry(
        'ops',
        3,
        '2026-10-27T06:00:00.000Z',
        'ops',
        'delete',
        'ItemRecord',
        'succeeded',
      ),
      entry(
        'app',
        1,
        '2026-10-26T15:00:00.000Z',
        'alice',
        'read',
        'TomAuditQuestion',
        'denied',
      ),
      entry(
        'ops',
        2,
        '2026-10-26T06:00:00.000Z',
        'ops',
        'execute',
        'ItemRecord',
        'succeeded',
      ),
      entry(
        'ops',
        1,
        '2026-10-25T06:00:00.000Z',
        'ops',
        'delete',
        'ItemRecord',
        'failed',
      ),
      entry(
        'app',
        0,
        '2026-10-24T09:00:00.000Z',
        'audrey',
        'create',
        'TomAuditQuestion',
        'succeeded',
      ),
    ];
  }

  @override
  Future<String> signIn(String username, String password) async {
    if (username != 'audrey' || password != 'audrey-pass') {
      throw const AuditSignInException('Wrong user name or password.');
    }
    return 'Audrey Auditor';
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<List<String>> writers() async =>
      {for (final e in trail) e.writer}.toList()..sort();

  @override
  Future<TomAuditReportResultDto> query(Map<String, Object?> filter) async {
    bool keep(TomAuditReportEntryDto e) {
      final record = e.record;
      final actor = (record['actor'] as Map?)?['username'];
      final writers = filter['writers'] as List?;
      return (filter['actor'] == null || filter['actor'] == actor) &&
          (filter['action'] == null || filter['action'] == record['action']) &&
          (filter['target'] == null || filter['target'] == record['target']) &&
          (filter['outcome'] == null ||
              filter['outcome'] == record['outcome']) &&
          (writers == null || writers.contains(e.writer));
    }

    final writers = (filter['writers'] as List?)?.cast<String>();
    return TomAuditReportResultDto(
      entries: trail.where(keep).toList(),
      writers: writers ?? await this.writers(),
    );
  }

  @override
  Future<List<TomAuditQuestionDto>> questions() async =>
      _questions.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<TomAuditQuestionDto> save(TomAuditQuestionDto question) async {
    final id = question.id.isEmpty ? 'q${_nextId++}' : question.id;
    final stored = TomAuditQuestionDto(
      id: id,
      name: question.name,
      owner: 'audrey',
      filter: question.filter,
      schedule: question.schedule,
      recipients: question.recipients,
      format: question.format,
      nextDeliveryAt: question.schedule.isEmpty ? '' : '2026-11-02T06:00:00Z',
    );
    _questions[id] = stored;
    return stored;
  }

  @override
  Future<void> delete(String id) async => _questions.remove(id);

  @override
  Future<TomAuditReportResultDto> answer(String id) =>
      query(_questions[id]!.filter.cast<String, Object?>());

  @override
  Future<TomAuditQuestionDto> deliver(String id) async {
    final question = _questions[id]!;
    question.nextDeliveryAt = '2026-10-27T11:00:00Z';
    return question;
  }
}
