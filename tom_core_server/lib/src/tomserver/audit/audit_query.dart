/// Asking a stored trail a question.
///
/// The trail is written to be read back by an auditor, and an auditor's
/// questions are few and always the same shape: what did this person do, what
/// happened to this record, what happened in this window, what was refused.
/// [TomAuditQuery] is that question, and it is deliberately a **value** rather
/// than a method on anything — the same arrangement `verifyAuditChain` already
/// has, where the analysis is storage-neutral and only the reading is not.
///
/// ## Why the filter judges the record and not the row
///
/// The relational trail stores six **projection columns** — actor, action,
/// target, target key, outcome, request id — beside the authoritative record
/// JSON, and they are indexed. They are also *truncated to fit*, which makes
/// them a lossy copy: they can narrow a search and may never be treated as the
/// record.
///
/// That distinction cannot be left to documentation, because both ways of
/// getting it wrong are silent. Comparing a search term to a truncated column
/// with `=` misses the row whose value was shortened — a **false negative**, in
/// an audit query, which is the failure that matters. Trusting the column's
/// value as the answer reports a truncated actor name as the actor.
///
/// So the two halves are separated by construction. [auditProjectionPrefix]
/// cuts a value to what a column can hold, and it is what the writer stores
/// *and* what a search is narrowed by — one function at both ends, so they
/// cannot disagree about where the cut falls. What comes back is then judged by
/// [TomAuditQuery.matches] against the decoded record, which is never
/// truncated. The database narrows; the record decides.
library;

import 'audit_record.dart';
import 'audit_sink.dart';

/// A question about a stored audit trail.
///
/// Every field is optional and every field given is an **and**: a query naming
/// an actor and an action asks what that actor did *of that kind*, not
/// everything either is true of. An empty query matches the whole trail.
class TomAuditQuery {
  /// Asks for the entries matching every field given.
  const TomAuditQuery({
    this.from,
    this.to,
    this.actor,
    this.action,
    this.target,
    this.targetKey,
    this.outcome,
    this.requestId,
    this.tenant,
    this.limit = defaultLimit,
    this.newestFirst = true,
  });

  /// How many entries a query returns when it does not say.
  ///
  /// A number rather than "all of them", because the trail is the one table in
  /// the framework with no natural ceiling: it only grows, and a default of
  /// unbounded is a default that works on a development database and takes a
  /// production one down. A caller that wants more says so.
  static const int defaultLimit = 500;

  /// The earliest instant to include, or `null` for the start of the trail.
  ///
  /// **Inclusive**, where [to] is exclusive, so consecutive windows tile the
  /// trail and an entry on a boundary belongs to exactly one of them. A closed
  /// upper bound would put it in both, and a daily export would double-count
  /// every midnight.
  final DateTime? from;

  /// The first instant to exclude, or `null` for the end of the trail.
  final DateTime? to;

  /// The actor's username, matched in full.
  final String? actor;

  /// The kind of action.
  final TomAuditAction? action;

  /// The audited type's name.
  final String? target;

  /// The audited instance's key.
  final String? targetKey;

  /// Whether the action succeeded, failed, or was denied.
  final TomAuditOutcome? outcome;

  /// The request the action belonged to.
  final String? requestId;

  /// Only the entries recorded in this tenant.
  final String? tenant;

  /// The most entries to return.
  ///
  /// Counts **matches**, not rows looked at. That is the distinction a limit
  /// pushed carelessly into storage loses: applied before the filter, a limit
  /// of two over a trail whose two newest entries belong to somebody else
  /// answers "this actor did nothing".
  final int limit;

  /// Whether to answer newest first.
  ///
  /// The default, because an auditor's question is nearly always about what
  /// happened recently, and because a truncated result is then the part worth
  /// having. Oldest first is what a replay or an export of a closed window
  /// wants, where the order is the chain's own.
  final bool newestFirst;

  /// Whether [record] answers this query.
  ///
  /// The authoritative test, and the only one: it reads the record, so no
  /// truncated projection takes part. Instants are compared as instants, which
  /// is what `DateTime` comparison does — a record's timestamp is normalised to
  /// UTC when it is built, and a window given in another zone still names the
  /// same moments.
  bool matches(TomAuditRecord record) {
    if (from != null && record.timestamp.isBefore(from!)) return false;
    if (to != null && !record.timestamp.isBefore(to!)) return false;
    if (actor != null && record.actor.username != actor) return false;
    if (action != null && record.action != action) return false;
    if (target != null && record.target != target) return false;
    if (targetKey != null && record.targetKey != targetKey) return false;
    if (outcome != null && record.outcome != outcome) return false;
    if (requestId != null && record.requestId != requestId) return false;
    if (tenant != null && record.tenant != tenant) return false;
    return true;
  }

  @override
  String toString() {
    final parts = [
      if (from != null) 'from=${from!.toIso8601String()}',
      if (to != null) 'to=${to!.toIso8601String()}',
      if (actor != null) 'actor=$actor',
      if (action != null) 'action=${action!.name}',
      if (target != null) 'target=$target',
      if (targetKey != null) 'targetKey=$targetKey',
      if (outcome != null) 'outcome=${outcome!.name}',
      if (requestId != null) 'requestId=$requestId',
      if (tenant != null) 'tenant=$tenant',
    ];
    return 'TomAuditQuery(${parts.isEmpty ? 'everything' : parts.join(', ')}, '
        'limit=$limit, ${newestFirst ? 'newest' : 'oldest'} first)';
  }
}

/// What a [TomAuditQuery] found.
///
/// Carries the counts as well as the entries, because a page of results on its
/// own cannot be read safely: a caller cannot tell a full page from the last
/// one, and cannot tell a narrow search from a lossy index doing its job.
class TomAuditQueryResult {
  /// Creates a result.
  const TomAuditQueryResult({
    required this.entries,
    required this.hasMore,
    required this.examined,
    required this.rejectedByProjection,
  });

  /// An empty result, examining nothing.
  static const TomAuditQueryResult empty = TomAuditQueryResult(
    entries: [],
    hasMore: false,
    examined: 0,
    rejectedByProjection: 0,
  );

  /// The matching entries, in the order the query asked for.
  final List<TomAuditEntry> entries;

  /// Whether the trail held further matches beyond [limit]'s worth.
  ///
  /// A caller that cannot tell a full page from the last page stops reading at
  /// whichever it meets first — which for an audit query means an answer that
  /// is quietly partial.
  final bool hasMore;

  /// How many stored entries were read and judged.
  ///
  /// Over a relational trail this is how many rows the index handed back, so
  /// the gap between it and `entries.length` is what the projection cost.
  final int examined;

  /// How many examined entries the projection matched and the record did not.
  ///
  /// The lossy index's false positives, counted rather than hidden. Over an
  /// in-memory trail it is always zero — there is no projection to be lossy —
  /// which is precisely why the field is on the result rather than assumed away
  /// by the caller.
  final int rejectedByProjection;

  @override
  String toString() =>
      'TomAuditQueryResult(${entries.length} of $examined examined'
      '${rejectedByProjection > 0 ? ', $rejectedByProjection rejected by '
                'projection' : ''}${hasMore ? ', more available' : ''})';
}

/// [value] cut to what a column holding [maxCharacters] characters can store.
///
/// Used by the relational sink at both ends: it trims the projection columns on
/// write, and it narrows a search term on read. One function rather than two
/// call sites doing the same arithmetic, because the two agreeing is the whole
/// reason a search over a truncated column finds anything — a reader comparing
/// the *full* term against a column the writer shortened matches nothing, and
/// says so as "no such entry".
///
/// A `null` width means the column has no character limit, and the value passes
/// through untouched.
String? auditProjectionPrefix(String? value, int? maxCharacters) {
  if (value == null || maxCharacters == null) return value;
  return value.length <= maxCharacters
      ? value
      : value.substring(0, maxCharacters);
}

/// Answers [query] from entries that have already been read back.
///
/// For the sinks whose trail is already in memory — [TomMemoryAuditSink.entries]
/// and [TomFileAuditSink.readAll], both synchronous because there is nothing to
/// wait for. `TomSqlAuditSink.query` exists separately rather than reading
/// everything and calling this: pushing the filter into the database is the
/// point of the indexes on that table, and reading ten million rows in order to
/// discard all but five is not a query.
///
/// [TomAuditQueryResult.rejectedByProjection] is always zero here. Nothing was
/// projected, so nothing can have been matched lossily.
TomAuditQueryResult filterAuditEntries(
  Iterable<TomAuditEntry> entries,
  TomAuditQuery query,
) {
  final all = entries.toList(growable: false);
  final ordered = query.newestFirst ? all.reversed : all;
  final matched = <TomAuditEntry>[];
  var examined = 0;
  var hasMore = false;

  for (final entry in ordered) {
    examined++;
    if (!query.matches(entry.record)) continue;
    if (matched.length == query.limit) {
      // The match that reveals there is more. Counted as examined — it was
      // judged — and not returned, because the caller asked for `limit`.
      hasMore = true;
      break;
    }
    matched.add(entry);
  }

  return TomAuditQueryResult(
    entries: List.unmodifiable(matched),
    hasMore: hasMore,
    examined: examined,
    rejectedByProjection: 0,
  );
}
