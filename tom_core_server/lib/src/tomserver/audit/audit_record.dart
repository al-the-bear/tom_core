/// The audit record — what an auditable action leaves behind (CE-LG).
///
/// An audit trail answers one question: **who did what to which record, when,
/// and did it work?** That is a different question from the one diagnostic
/// logging answers ("why did this fail?"), and the difference is not stylistic:
///
/// | | Diagnostic log | Audit trail |
/// | --- | --- | --- |
/// | Reader | an operator debugging a failure | an auditor reconstructing history |
/// | Retention | days | years, often statutory |
/// | Integrity | best effort; rotation truncates freely | append-only, tamper-evident |
/// | Completeness | sampling and level filters are fine | a missing entry is a finding |
/// | Content | whatever helps diagnosis | a fixed, attributable schema |
///
/// Those columns conflict at every row, which is why this module does not
/// extend the kernel's logging subsystem: a trail that shares retention and
/// mutability with `tomLog` output is a trail nobody can rely on.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// What kind of action a [TomAuditRecord] describes.
///
/// Deliberately small. These are the categories an auditor reasons in; the
/// specific operation is carried by [TomAuditRecord.target] and
/// [TomAuditRecord.detail], which are free-form.
enum TomAuditAction {
  /// A new record was created (a repository `INSERT`).
  create,

  /// An existing record was modified (a repository `UPDATE`).
  update,

  /// A record was destroyed (a repository `DELETE`).
  delete,

  /// A record was read.
  ///
  /// The only action nothing in the framework produces. No repository read is
  /// audited and no annotation makes one audited — a record with this action
  /// exists because application code called `TomAuditTrail.recordAction` and
  /// said so. The value stays in the enum precisely so that call has a
  /// truthful category to use; see the `audit_trail` library comment for why
  /// the framework declines to make the choice itself.
  read,

  /// An action was invoked that is not itself a record mutation — an endpoint
  /// call, a job run, a report export.
  execute,
}

/// How the audited action ended.
enum TomAuditOutcome {
  /// The action completed.
  succeeded,

  /// The action was attempted and raised.
  failed,

  /// The action was refused before it ran — authentication, authorization,
  /// row scope or column grade.
  ///
  /// Distinct from [failed] on purpose. A failure is an operational event; a
  /// denial is a *security* event, and it is the one an auditor scans for
  /// first. Collapsing the two would bury attempted access in among timeouts.
  denied,
}

/// Who performed an audited action.
///
/// Attribution is the property an audit trail exists for, so it is never left
/// blank: an action performed with no principal in the zone is attributed to
/// [systemUsername] rather than to `null`. "The framework did this on its own
/// behalf" and "we failed to record who did this" must not look alike in the
/// trail, and an absent field cannot distinguish them.
class TomAuditActor {
  /// The username the action is attributed to, or [systemUsername].
  final String username;

  /// The principal's user id, or `null` for the system actor.
  final int? userId;

  /// Whether the principal had authenticated.
  ///
  /// An unauthenticated principal can still reach an endpoint (that is what a
  /// denial record describes), so this is recorded rather than assumed.
  final bool authenticated;

  /// The principal's organization id, or `null` for the system actor.
  final int? organizationId;

  /// The principal's application id, or `null` for the system actor.
  final int? applicationId;

  /// The username recorded when no principal is present in the zone.
  ///
  /// Bootstrap, migrations and scheduled jobs legitimately act with no user.
  static const String systemUsername = 'SYSTEM';

  /// Creates an actor from its parts.
  const TomAuditActor({
    required this.username,
    this.userId,
    this.authenticated = false,
    this.organizationId,
    this.applicationId,
  });

  /// The system actor, used when no principal is available.
  static const TomAuditActor system = TomAuditActor(username: systemUsername);

  /// Reads the actor from [principal], or returns [system] when it is `null`.
  ///
  /// `TomPrincipal` spells "unset" as `-1` for its three ids. That sentinel is
  /// meaningful inside the principal and meaningless in a trail an auditor
  /// reads years later, so it is normalised to `null` here — and `null` is
  /// then omitted by [toJson] rather than recorded as a user who does not
  /// exist.
  factory TomAuditActor.fromPrincipal(TomPrincipal? principal) {
    if (principal == null) return system;
    int? set(int value) => value < 0 ? null : value;
    return TomAuditActor(
      username: principal.username,
      userId: set(principal.id),
      authenticated: principal.authenticated,
      organizationId: set(principal.organizationId),
      applicationId: set(principal.applicationId),
    );
  }

  /// Reads the actor from the current zone's [TomPrincipal].
  ///
  /// The zone is the framework's ambient principal carrier — the endpoints
  /// pipeline installs it per request — so both chokepoints resolve the actor
  /// the same way without threading it through their signatures. A repository
  /// write reached from a background job simply finds no principal and is
  /// attributed to [system].
  factory TomAuditActor.fromCurrentZone() =>
      TomAuditActor.fromPrincipal(getFromCurrentZone<TomPrincipal>());

  /// The actor as a JSON map, omitting the fields the system actor has none of.
  Map<String, Object?> toJson() => {
    'username': username,
    if (userId != null) 'userId': userId,
    'authenticated': authenticated,
    if (organizationId != null) 'organizationId': organizationId,
    if (applicationId != null) 'applicationId': applicationId,
  };

  /// Rebuilds an actor from [json] as written by [toJson].
  factory TomAuditActor.fromJson(Map<String, Object?> json) => TomAuditActor(
    username: json['username'] as String? ?? systemUsername,
    userId: json['userId'] as int?,
    authenticated: json['authenticated'] as bool? ?? false,
    organizationId: json['organizationId'] as int?,
    applicationId: json['applicationId'] as int?,
  );

  @override
  String toString() => userId == null ? username : '$username#$userId';
}

/// One entry in the audit trail: an attributable statement that an action
/// happened.
///
/// The record is **immutable**. Nothing downstream may adjust an entry after
/// the fact — that is half of what "tamper-evident" means, and the other half
/// (detecting a change made outside the API) is the sink's hash chain.
///
/// ### before / after
///
/// [before] and [after] carry only the fields that actually **changed**, in
/// their database representation. Two reasons for the narrowing:
///
/// - A full row image on every update multiplies the trail's size by the row
///   width, and the unchanged columns add nothing an auditor can use.
/// - Fields an entity marks as redacted never appear at all, so a password
///   hash or an access token cannot be exfiltrated by reading the trail.
///
/// Values that a C-4 column grade would mask from the *caller* are recorded
/// here in the clear. The trail is the authoritative record of what changed;
/// masking it would produce entries stating that something changed to `null`,
/// which is worse than useless. The trail is therefore privileged storage, and
/// an entity that must never expose a value even to an auditor redacts it.
class TomAuditRecord {
  /// Unique id of this entry.
  final String id;

  /// When the action happened, in UTC.
  ///
  /// UTC without exception: a trail whose entries are written by servers in
  /// different zones cannot be ordered otherwise, and ordering is the first
  /// thing an auditor needs.
  final DateTime timestamp;

  /// Who performed the action.
  final TomAuditActor actor;

  /// What kind of action it was.
  final TomAuditAction action;

  /// What it acted on — an entity type name, or an endpoint route.
  final String target;

  /// The key of the affected record, when the action names one.
  final String? targetKey;

  /// How the action ended.
  final TomAuditOutcome outcome;

  /// The id of the request the action was performed under, when there was one.
  ///
  /// This is what stitches an endpoint denial together with the repository
  /// writes of the same request, so a trail can be read as a sequence of user
  /// interactions rather than a flat list of events.
  final String? requestId;

  /// The changed fields' prior values; empty for a create.
  final Map<String, Object?> before;

  /// The changed fields' new values; empty for a delete.
  final Map<String, Object?> after;

  /// A human-readable note — the denial reason, the exception message.
  final String? detail;

  /// Creates an audit record. [timestamp] is coerced to UTC.
  TomAuditRecord({
    required this.id,
    required DateTime timestamp,
    required this.actor,
    required this.action,
    required this.target,
    required this.outcome,
    this.targetKey,
    this.requestId,
    Map<String, Object?> before = const {},
    Map<String, Object?> after = const {},
    this.detail,
  }) : timestamp = timestamp.toUtc(),
       before = Map.unmodifiable(_encodableValues(before)),
       after = Map.unmodifiable(_encodableValues(after));

  /// [values] with every entry converted to something `jsonEncode` accepts
  /// (bug §75).
  ///
  /// The images are filled straight from an entity's fields, so whatever a
  /// column holds arrives here — and the record is JSON-encoded three times
  /// over: the chain hash, the file sink's line, the SQL sink's column. That
  /// makes encodability an invariant of the *record*, not of one writer, which
  /// is why it is established in the constructor beside [timestamp]'s coercion
  /// rather than in [toJson]. [TomAuditRecord.fromJson] builds through this
  /// constructor too, so the conversion has to be idempotent — it is, because
  /// everything it produces is already encodable and passes through untouched.
  ///
  /// Before this, an audited entity with a `DateTime` column could not be
  /// updated or deleted at all: the repository's `_audit` is deliberately
  /// uncaught, so a trail that could not encode the before-image did not lose
  /// the record, it failed the mutation.
  static Map<String, Object?> _encodableValues(Map<String, Object?> values) {
    if (values.isEmpty) return const {};
    return {
      for (final entry in values.entries) entry.key: _encodable(entry.value),
    };
  }

  /// One value, converted only if `jsonEncode` would refuse it.
  ///
  /// `DateTime` uses the same ISO-8601-in-UTC form as [timestamp], so a single
  /// record does not spell a moment two ways. Anything else unrecognised falls
  /// back to [Object.toString] rather than raising: the trail's job is to say
  /// *that* a field changed, and refusing here would make the framework cancel
  /// the operation instead of describing it approximately.
  static Object? _encodable(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Enum) return value.name;
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _encodable(entry.value),
      };
    }
    if (value is Iterable) return value.map(_encodable).toList();
    return value.toString();
  }

  /// The record as a JSON map.
  ///
  /// Key order is fixed and empty collections are omitted, so the encoding is
  /// canonical — the sink hashes this, and a hash over a map whose iteration
  /// order varied would break the chain for no reason.
  Map<String, Object?> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'actor': actor.toJson(),
    'action': action.name,
    'target': target,
    if (targetKey != null) 'targetKey': targetKey,
    'outcome': outcome.name,
    if (requestId != null) 'requestId': requestId,
    if (before.isNotEmpty) 'before': before,
    if (after.isNotEmpty) 'after': after,
    if (detail != null) 'detail': detail,
  };

  /// Rebuilds a record from [json] as written by [toJson].
  ///
  /// Unknown enum names fall back to [TomAuditAction.execute] /
  /// [TomAuditOutcome.failed] rather than throwing: a reader must be able to
  /// process an old trail written by a version that had a value this one does
  /// not, and refusing to parse would make the archive unreadable.
  factory TomAuditRecord.fromJson(Map<String, Object?> json) => TomAuditRecord(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    actor: TomAuditActor.fromJson(
      (json['actor'] as Map).cast<String, Object?>(),
    ),
    action: TomAuditAction.values.firstWhere(
      (a) => a.name == json['action'],
      orElse: () => TomAuditAction.execute,
    ),
    target: json['target'] as String,
    targetKey: json['targetKey'] as String?,
    outcome: TomAuditOutcome.values.firstWhere(
      (o) => o.name == json['outcome'],
      orElse: () => TomAuditOutcome.failed,
    ),
    requestId: json['requestId'] as String?,
    before: (json['before'] as Map?)?.cast<String, Object?>() ?? const {},
    after: (json['after'] as Map?)?.cast<String, Object?>() ?? const {},
    detail: json['detail'] as String?,
  );

  @override
  String toString() =>
      '${timestamp.toIso8601String()} $actor ${action.name} $target'
      '${targetKey == null ? '' : '[$targetKey]'} ${outcome.name}';
}
