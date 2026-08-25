/// The audit trail itself: what gets audited, and how a record reaches a sink
/// (CE-LG).
///
/// ## Declared versus automatic — the design decision
///
/// CodeSpecs §4.3 says CE-LG "is not doable purely declaratively", which is the
/// same observation from the other side: if auditing were only what a
/// specification declared, then everything nobody thought to declare would be
/// unaudited, and an audit trail's value is precisely that it covers the cases
/// nobody anticipated. But auditing *everything* is equally useless — a trail
/// in which every row read is an entry is a trail no auditor can read, and it
/// costs more to store than the data it describes.
///
/// The split this module implements:
///
/// | | What | Why here |
/// | --- | --- | --- |
/// | **Automatic** | every repository mutation — create, update, delete | Mutations are finite in volume, are what an auditor asks about, and pass through one chokepoint. Nothing to declare and nothing to forget. |
/// | **Automatic** | every endpoint access **denial** | The one auditable event the repository cannot see, because the request never reached it. An attempted access is the entry an auditor scans for first. |
/// | **Declared** | endpoint invocations, via `@TomAudited()` on the method | An endpoint call is not inherently auditable — most are reads. Which ones matter is a domain judgement, so it is declared. |
/// | **Opt-out** | `@TomAudited(enabled: false)` on the entity | An escape hatch for high-volume machine-written tables (sessions, job runs) whose mutations are noise. Explicit, so its absence is auditable too. |
///
/// The asymmetry is deliberate. Mutation auditing is **on by default and
/// declared off**; invocation auditing is **off by default and declared on**.
/// Defaults should fail towards the safe answer, and for a mutation the safe
/// answer is "recorded".
///
/// ## Reads are not audited
///
/// No repository read produces a record, and no annotation makes one. The read
/// path — `findById`, `findAll`, `count` — reaches no audit code at all, and
/// [TomAuditPolicy.audits] answers `false` for [TomAuditAction.read] whatever
/// the entity declares.
///
/// That is a position, not an omission. A read chokepoint would have to choose
/// between one record per call and one per row, and neither answer is right:
/// per call loses which rows were seen, which is the only thing a read trail
/// is for; per row turns a thousand-row list into a thousand entries that say
/// less than an access log. Fail-closed then puts that write in front of every
/// read of the entity. Those are deployment decisions about latency and
/// volume, and a framework default cannot make them.
///
/// So a deployment that must record who looked has two honest routes.
/// Annotate the **endpoint** with `@TomAudited()`: that records the invocation
/// and its actor at the boundary where "who asked, for what" is unambiguous,
/// and it is the route to reach for first. Or call
/// [TomAuditTrail.recordAction] with [TomAuditAction.read] from the code that
/// knows which rows mattered — it consults no policy, so the caller who has
/// made the volume decision is the one who acts on it. Both are explicit at
/// the point of use. What this module will not do is imply it has already
/// decided on the deployment's behalf.
///
/// One consequence worth stating outright: an update that changes no value is
/// still recorded, with an empty diff. What is audited is the **action**, not
/// the delta — making the entry conditional on the data would mean that
/// rewriting a row with identical values left no trace, and completeness that
/// depends on content is not completeness.
///
/// ## Fail-closed
///
/// If the sink cannot store a record, the audited action **fails**. The
/// alternative — proceed and lose the entry — produces exactly the silent gap
/// that makes a trail unusable, and it does so at the moment things are already
/// going wrong, which is when the entries matter most. A deployment that would
/// rather stay available than stay auditable configures a sink that degrades on
/// its own terms; that is the sink's decision to make, not the trail's.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/request_id.dart';
import 'audit_record.dart';
import 'audit_sink.dart';

/// Declares how the annotated entity or endpoint method is audited (CE-LG).
///
/// On an **entity** (a `@TomDbTable` class) it tunes the automatic mutation
/// auditing every entity already gets. On an **endpoint method** it opts that
/// method's invocation into the trail, which is not automatic.
///
/// ```dart
/// // High-volume machine-written table: mutations are noise, not history.
/// @TomAudited(enabled: false)
/// @TomDbTable(table: 'session')
/// class Session { … }
///
/// // Regulated data: record every change, but never the token itself — not
/// // even in the trail.
/// @TomAudited(redact: ['accessToken'])
/// @TomDbTable(table: 'patient')
/// class Patient { … }
///
/// // An endpoint whose invocation is itself the auditable act.
/// @TomAudited()
/// Future<void> exportPayrollReport() async { … }
/// ```
class TomAudited {
  /// Whether the annotated target is audited at all.
  ///
  /// Only meaningful as `false` — the opt-out. An entity without the
  /// annotation is already audited for mutations.
  final bool enabled;

  /// Field names whose values must never appear in a record's `before`/`after`.
  ///
  /// The trail is privileged storage — a C-4 column grade masks a value from
  /// the *caller*, not from the auditor — so this list is for values that must
  /// not exist in a second place at all: password hashes, access tokens, keys.
  /// The record still shows that the field changed; only the values are
  /// withheld, replaced by [tomAuditRedactedPlaceholder].
  final List<String> redact;

  /// Declares the audit policy for the annotated entity or endpoint method.
  const TomAudited({this.enabled = true, this.redact = const []});
}

/// What a redacted value is recorded as.
///
/// A placeholder rather than an omission: "this field changed and you may not
/// see to what" and "this field did not change" are different statements, and
/// dropping the key would collapse them.
const String tomAuditRedactedPlaceholder = '***';

/// The resolved audit policy for a type — [TomAudited]'s values, with the
/// defaults already applied.
///
/// Resolution goes through the reflector, which is not free, so it is cached
/// per type the way `TomAnnotationAnalyzer` caches scope and column metadata.
class TomAuditPolicy {
  /// Whether the type is audited at all.
  final bool enabled;

  /// The field names whose values are withheld from records.
  final Set<String> redact;

  /// Creates a policy from its parts.
  const TomAuditPolicy({required this.enabled, required this.redact});

  /// The policy a type with no `@TomAudited` annotation gets: mutations are
  /// audited, reads are not, nothing is redacted.
  static const TomAuditPolicy defaultPolicy = TomAuditPolicy(
    enabled: true,
    redact: {},
  );

  /// Reads the policy off an annotation.
  factory TomAuditPolicy.from(TomAudited annotation) => TomAuditPolicy(
    enabled: annotation.enabled,
    redact: annotation.redact.toSet(),
  );

  /// Whether [action] is audited under this policy.
  ///
  /// [TomAuditAction.read] is always `false`, and no annotation changes that —
  /// see the library comment's *Reads are not audited*. The branch is written
  /// out rather than left to fall through the `true` below, because a policy
  /// that answered `true` for a read the repository never records would be the
  /// same false promise in the opposite direction.
  bool audits(TomAuditAction action) {
    if (!enabled) return false;
    if (action == TomAuditAction.read) return false;
    return true;
  }

  /// [values] with every redacted field's value replaced by
  /// [tomAuditRedactedPlaceholder].
  ///
  /// Returns [values] unchanged when nothing is redacted, so the common case
  /// costs no copy.
  Map<String, Object?> applyRedaction(Map<String, Object?> values) {
    if (redact.isEmpty || values.isEmpty) return values;
    return {
      for (final entry in values.entries)
        entry.key: redact.contains(entry.key)
            ? tomAuditRedactedPlaceholder
            : entry.value,
    };
  }
}

/// A zone marker that suppresses auditing for the actions performed inside it
/// (installed by [TomAuditTrail.runUnaudited]).
///
/// Mirrors `TomDataScopeBypass`, and exists for the same structural reason: the
/// audit trail may itself be persisted through a repository, and a repository
/// write that audits its own audit write does not terminate. The suppression is
/// *not* a general "skip auditing" switch for application code — an application
/// that wants a table unaudited declares `@TomAudited(enabled: false)`, which
/// is visible in the source rather than hidden in a call stack.
class TomAuditBypass {
  /// Creates the bypass marker (a plain sentinel; its presence is the signal).
  const TomAuditBypass();
}

/// The audit trail: resolves policy, builds records, and hands them to the
/// configured [sink].
///
/// A process-wide singleton rather than an injected collaborator, because the
/// chokepoints that must reach it — the endpoint pipeline and the repository
/// base class — are framework code constructed by the application, and
/// threading a trail through both would give every caller the chance to pass
/// `null`. An audit trail that a caller can decline is not one.
///
/// Auditing is **off until a sink is installed**. That is not a default-open
/// hole: with no sink there is no storage, and pretending to audit into nowhere
/// would be worse than plainly not auditing. A server that must audit installs
/// a sink at startup, and [isEnabled] makes the state inspectable.
class TomAuditTrail {
  TomAuditTrail._();

  static TomAuditSink? _sink;

  static final Map<Type, TomAuditPolicy> _policyCache = {};

  /// The sink records are written to, or `null` when auditing is off.
  static TomAuditSink? get sink => _sink;

  /// Installs [sink] as the destination for audit records.
  ///
  /// Closes nothing: the previous sink's lifetime belongs to whoever created
  /// it, and closing a sink that another component still holds would break it
  /// silently.
  static void install(TomAuditSink sink) {
    _sink = sink;
  }

  /// Removes the sink, turning auditing off.
  static void uninstall() {
    _sink = null;
  }

  /// Whether records are being written.
  static bool get isEnabled => _sink != null && !isBypassed;

  /// Whether the current zone suppresses auditing — i.e. we are inside a
  /// [runUnaudited] body.
  static bool get isBypassed => getFromCurrentZone<TomAuditBypass>() != null;

  /// Runs [body] with auditing suppressed for everything it does.
  ///
  /// For the trail's own persistence path only — see [TomAuditBypass].
  static Future<T> runUnaudited<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: const {TomAuditBypass: TomAuditBypass()});

  /// The audit policy for entity type [type], resolved from its `@TomAudited`
  /// annotation and cached.
  ///
  /// A type the reflector does not know gets [TomAuditPolicy.defaultPolicy]:
  /// being unreflectable is a reason to lack *metadata*, not a reason to escape
  /// the trail.
  static TomAuditPolicy policyFor(Type type) {
    final cached = _policyCache[type];
    if (cached != null) return cached;
    var policy = TomAuditPolicy.defaultPolicy;
    try {
      final mirror = tomReflector.reflectType(type) as ClassMirror;
      for (final md in mirror.metadata) {
        if (md is TomAudited) {
          policy = TomAuditPolicy.from(md);
          break;
        }
      }
    } catch (_) {
      // Not reflectable — keep the default policy. Deliberately silent: this
      // is a metadata lookup, not an operation, and a type with no mirror is
      // an ordinary case (a non-entity target name, a synthetic type).
    }
    _policyCache[type] = policy;
    return policy;
  }

  /// Clears the resolved-policy cache.
  ///
  /// Test-support only; annotations do not change at runtime in a server.
  static void resetPolicyCache() => _policyCache.clear();

  /// Writes [record] to the sink.
  ///
  /// A no-op when auditing is off or suppressed. Throws [TomAuditException]
  /// when the sink cannot store the record — the fail-closed contract, which
  /// the callers deliberately do not catch.
  static Future<void> record(TomAuditRecord record) async {
    final sink = _sink;
    if (sink == null || isBypassed) return;
    await sink.write(record);
  }

  /// Records a mutation of [entityType], applying the type's redaction policy
  /// and attributing the action to the current zone's principal.
  ///
  /// Returns without writing when the type's policy excludes [action], so
  /// callers do not have to consult the policy themselves — the check lives
  /// once, here, next to the write it guards.
  static Future<void> recordMutation({
    required Type entityType,
    required TomAuditAction action,
    required String target,
    String? targetKey,
    TomAuditOutcome outcome = TomAuditOutcome.succeeded,
    Map<String, Object?> before = const {},
    Map<String, Object?> after = const {},
    String? detail,
  }) async {
    if (!isEnabled) return;
    final policy = policyFor(entityType);
    if (!policy.audits(action)) return;
    await record(
      TomAuditRecord(
        id: newAuditRecordId(),
        timestamp: DateTime.now(),
        actor: TomAuditActor.fromCurrentZone(),
        action: action,
        target: target,
        targetKey: targetKey,
        outcome: outcome,
        requestId: currentRequestId(),
        before: policy.applyRedaction(before),
        after: policy.applyRedaction(after),
        detail: detail,
      ),
    );
  }

  /// Records an action that is not an entity mutation — an endpoint
  /// invocation, or an access denial.
  ///
  /// Unlike [recordMutation] there is no entity policy to consult: the
  /// decision to record has already been made by the caller (a `@TomAudited`
  /// method, or a denial, which is unconditional).
  static Future<void> recordAction({
    required TomAuditAction action,
    required String target,
    required TomAuditOutcome outcome,
    String? targetKey,
    String? detail,
    TomAuditActor? actor,
  }) async {
    if (!isEnabled) return;
    await record(
      TomAuditRecord(
        id: newAuditRecordId(),
        timestamp: DateTime.now(),
        actor: actor ?? TomAuditActor.fromCurrentZone(),
        action: action,
        target: target,
        targetKey: targetKey,
        outcome: outcome,
        requestId: currentRequestId(),
        detail: detail,
      ),
    );
  }

  /// The current request's id, or `null` outside a request.
  static String? currentRequestId() => getFromCurrentZone<TomRequestId>()?.uuid;

  static final TomAuditRecordIdGenerator _recordIds =
      TomAuditRecordIdGenerator();

  /// A unique id for a new audit record.
  ///
  /// Timestamp plus a counter rather than a UUID: audit ids are read by humans
  /// reconciling a trail, and an id that sorts in write order is worth more to
  /// them than one that is globally unique. Uniqueness across processes comes
  /// from the actor and timestamp already in the record — see
  /// [TomAuditRecordIdGenerator] for exactly what is and is not guaranteed.
  static String newAuditRecordId() => _recordIds.next();
}

/// Issues audit record ids that are distinct and sort in write order.
///
/// An id is `<microseconds since epoch>-<counter>`, the counter six lowercase
/// hex digits: `1700000000000000-00002a`. Both fields are fixed-width, because
/// sorting audit ids is a *string* sort — the suffix is padded, and the
/// microsecond field is sixteen digits of its own accord until the year 2286.
///
/// ## The counter counts within a microsecond, not since start-up
///
/// It resets every time the clock advances, and that is what makes six digits
/// enough. A counter that only ever climbed would wrap at 16 777 216 ids and
/// then reissue values that sort *before* their predecessors — a duplicate id
/// and a broken ordering, arriving after a process had been up long enough for
/// nobody to connect the two. Reset per microsecond, the suffix is bounded by
/// how many records one process can write in a single microsecond, so the
/// width is unreachable rather than merely generous.
///
/// ## A clock that steps backwards does not unsort the trail
///
/// [next] pins the highest microsecond it has seen and counts on from there, so
/// an NTP correction — much likelier than exhausting any counter — cannot make
/// a later id sort before an earlier one. The cost is that during such a
/// correction the id's leading field runs ahead of the wall clock. That is the
/// right trade because the id is an *ordering* token: the record's own
/// [TomAuditRecord.timestamp] is what states when the action happened, and it
/// is unaffected.
///
/// ## What is not claimed
///
/// Ids are unique **per generator**, which in practice means per process. Two
/// processes writing into one trail table can mint the same id in the same
/// microsecond, and nothing rejects that: `entry_id` carries no unique key, and
/// must not, because such a key would turn a legitimate collision between two
/// writers into a failed insert — and a failed insert here fails the audited
/// action closed. Cross-process identity is the record's actor and timestamp;
/// cross-process chain integrity is the sink's `writer` and its unique key on
/// `(writer, previous_hash)`.
class TomAuditRecordIdGenerator {
  /// Creates a generator reading [clock].
  TomAuditRecordIdGenerator({int Function()? clock})
    : clock = clock ?? _systemMicros;

  /// The clock this generator reads, in microseconds since the epoch.
  ///
  /// Injectable so a test can hold a microsecond still, or move it backwards,
  /// without waiting for either.
  final int Function() clock;

  static int _systemMicros() => DateTime.now().toUtc().microsecondsSinceEpoch;

  int _micros = 0;
  int _counter = 0;

  /// The next id.
  String next() {
    final now = clock();
    if (now > _micros) {
      _micros = now;
      _counter = 0;
    } else {
      // The same microsecond, or a clock that moved backwards. Either way the
      // pinned microsecond stands and the counter breaks the tie.
      _counter++;
    }
    return '$_micros-${_counter.toRadixString(16).padLeft(6, '0')}';
  }
}

/// The fields that actually changed between [before] and [after].
///
/// Returns the pair of narrowed maps a [TomAuditRecord] carries: only keys
/// whose value differs, `before` holding the prior value and `after` the new
/// one. A key present in only one of the two counts as changed.
///
/// Free-standing rather than a method on the record because it is the
/// repository's job to compute — it is the only layer holding both images —
/// and because it is a pure function worth testing without a database.
({Map<String, Object?> before, Map<String, Object?> after}) auditDiff(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final changedBefore = <String, Object?>{};
  final changedAfter = <String, Object?>{};
  for (final key in {...before.keys, ...after.keys}) {
    final oldValue = before[key];
    final newValue = after[key];
    if (oldValue == newValue &&
        before.containsKey(key) == after.containsKey(key)) {
      continue;
    }
    if (before.containsKey(key)) changedBefore[key] = oldValue;
    if (after.containsKey(key)) changedAfter[key] = newValue;
  }
  return (before: changedBefore, after: changedAfter);
}
