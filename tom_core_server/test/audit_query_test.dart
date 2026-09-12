/// The storage-neutral half of trail querying: the filter, and what it does to
/// a list of entries somebody has already read back.
///
/// The module's analysis has always been a function over `List<TomAuditEntry>`
/// rather than a method on a sink — `verifyAuditChain` is the precedent — and
/// filtering follows it for the same reason. A memory or file trail is already
/// in memory, so narrowing it needs no database and no sink; only the
/// relational sink pushes the filter down, because only there is there an index
/// to push it into.
///
/// What is asserted here is the filter's own contract. The claim that pushing
/// it into SQL finds the same entries — including the one whose projection
/// column was truncated on the way in — needs a real server and lives in
/// `audit_sql_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

TomAuditRecord _record({
  String id = 'r1',
  DateTime? at,
  String actor = 'alice',
  TomAuditAction action = TomAuditAction.update,
  String target = 'Invoice',
  String? targetKey = '42',
  TomAuditOutcome outcome = TomAuditOutcome.succeeded,
  String? requestId,
}) => TomAuditRecord(
  id: id,
  timestamp: at ?? DateTime.utc(2026, 3, 4, 10),
  actor: TomAuditActor(username: actor),
  action: action,
  target: target,
  targetKey: targetKey,
  outcome: outcome,
  requestId: requestId,
);

List<TomAuditEntry> _chain(List<TomAuditRecord> records) {
  final entries = <TomAuditEntry>[];
  var previous = tomAuditGenesisHash;
  for (var i = 0; i < records.length; i++) {
    final entry = TomAuditEntry.chain(records[i], previous, index: i);
    entries.add(entry);
    previous = entry.hash;
  }
  return entries;
}

void main() {
  group('a query judges a record, not a row', () {
    test('an empty query matches every record', () {
      expect(const TomAuditQuery().matches(_record()), isTrue);
    });

    test('each field narrows on its own', () {
      final record = _record(
        actor: 'alice',
        action: TomAuditAction.delete,
        target: 'Invoice',
        targetKey: '42',
        outcome: TomAuditOutcome.denied,
        requestId: 'req-7',
      );

      expect(const TomAuditQuery(actor: 'alice').matches(record), isTrue);
      expect(const TomAuditQuery(actor: 'bob').matches(record), isFalse);
      expect(
        const TomAuditQuery(action: TomAuditAction.delete).matches(record),
        isTrue,
      );
      expect(
        const TomAuditQuery(action: TomAuditAction.create).matches(record),
        isFalse,
      );
      expect(const TomAuditQuery(target: 'Invoice').matches(record), isTrue);
      expect(const TomAuditQuery(target: 'Payment').matches(record), isFalse);
      expect(const TomAuditQuery(targetKey: '42').matches(record), isTrue);
      expect(const TomAuditQuery(targetKey: '43').matches(record), isFalse);
      expect(
        const TomAuditQuery(outcome: TomAuditOutcome.denied).matches(record),
        isTrue,
      );
      expect(
        const TomAuditQuery(outcome: TomAuditOutcome.succeeded).matches(record),
        isFalse,
      );
      expect(const TomAuditQuery(requestId: 'req-7').matches(record), isTrue);
      expect(const TomAuditQuery(requestId: 'req-8').matches(record), isFalse);
    });

    test('several fields are an AND, not an OR', () {
      // The distinction a reporting filter gets wrong once and confusingly:
      // "what did alice delete" must not answer with everything alice did.
      final record = _record(actor: 'alice', action: TomAuditAction.update);

      expect(
        const TomAuditQuery(
          actor: 'alice',
          action: TomAuditAction.delete,
        ).matches(record),
        isFalse,
      );
    });

    test('the window takes its lower bound and leaves its upper', () {
      // Half-open, so consecutive windows tile the trail: an entry on the
      // boundary belongs to exactly one of them. A closed upper bound would
      // report it in both, and a daily export would double-count every
      // midnight.
      final boundary = DateTime.utc(2026, 3, 4, 10);
      final record = _record(at: boundary);

      expect(TomAuditQuery(from: boundary).matches(record), isTrue);
      expect(TomAuditQuery(to: boundary).matches(record), isFalse);
      expect(
        TomAuditQuery(
          from: boundary.subtract(const Duration(seconds: 1)),
          to: boundary.add(const Duration(seconds: 1)),
        ).matches(record),
        isTrue,
      );
    });

    test('the window compares instants, not calendar readings', () {
      // A record's timestamp need not be UTC; the column it is stored in is.
      // Comparing the two as wall-clock readings would place a Berlin-stamped
      // record an hour from where it belongs.
      final utcNoon = DateTime.utc(2026, 3, 4, 12);
      final record = _record(at: utcNoon.toLocal());

      expect(
        TomAuditQuery(
          from: utcNoon,
          to: utcNoon.add(const Duration(microseconds: 1)),
        ).matches(record),
        isTrue,
      );
    });
  });

  group('filtering a list of entries', () {
    final entries = _chain([
      _record(id: 'a', at: DateTime.utc(2026, 3, 1), actor: 'alice'),
      _record(id: 'b', at: DateTime.utc(2026, 3, 2), actor: 'bob'),
      _record(id: 'c', at: DateTime.utc(2026, 3, 3), actor: 'alice'),
      _record(id: 'd', at: DateTime.utc(2026, 3, 4), actor: 'alice'),
    ]);

    test('keeps the matching entries, newest first by default', () {
      final result = filterAuditEntries(
        entries,
        const TomAuditQuery(actor: 'alice'),
      );

      expect([
        for (final e in result.entries) e.record.id,
      ], equals(['d', 'c', 'a']));
      expect(result.examined, equals(4));
      expect(result.hasMore, isFalse);
    });

    test('reads oldest first when asked', () {
      final result = filterAuditEntries(
        entries,
        const TomAuditQuery(actor: 'alice', newestFirst: false),
      );

      expect([
        for (final e in result.entries) e.record.id,
      ], equals(['a', 'c', 'd']));
    });

    test('a limit truncates the result and says so', () {
      final result = filterAuditEntries(entries, const TomAuditQuery(limit: 2));

      expect(result.entries, hasLength(2));
      expect([for (final e in result.entries) e.record.id], equals(['d', 'c']));
      expect(
        result.hasMore,
        isTrue,
        reason:
            'a caller that cannot tell a full page from the last page will '
            'stop reading at whichever it met first',
      );
    });

    test('the limit counts matches, not rows looked at', () {
      // The trap in pushing a limit down to storage: applied before the
      // filter, `limit: 2` over a trail whose two newest entries are bob's
      // answers "alice did nothing".
      final result = filterAuditEntries(
        entries,
        const TomAuditQuery(actor: 'alice', limit: 2),
      );

      expect([for (final e in result.entries) e.record.id], equals(['d', 'c']));
      expect(result.hasMore, isTrue);
    });

    test('nothing matching is an empty result, not an error', () {
      final result = filterAuditEntries(
        entries,
        const TomAuditQuery(actor: 'nobody'),
      );

      expect(result.entries, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.rejectedByProjection, isZero);
    });
  });

  group('the projection prefix is what makes a lossy index safe to search', () {
    test('a value that fits is its own prefix', () {
      expect(auditProjectionPrefix('alice', 160), equals('alice'));
    });

    test('a longer value is cut to what the column holds', () {
      final long = 'a' * 200;

      expect(auditProjectionPrefix(long, 160), equals('a' * 160));
    });

    test('an absent value and an absent width pass through', () {
      expect(auditProjectionPrefix(null, 160), isNull);
      expect(auditProjectionPrefix('alice', null), equals('alice'));
    });

    test('the trail table declares the widths the writer cuts to', () {
      // The one function is used by the write and by the read, and the width
      // comes from the column declaration rather than from a literal beside
      // each call. That is what keeps a search from missing a row the write
      // shortened: both ends cut at the same place, by construction.
      final table = auditTrailTable(defaultAuditTrailTable);

      expect(table.column('actor')!.maxCharacters, equals(160));
      expect(table.column('target')!.maxCharacters, equals(160));
      expect(table.column('target_key')!.maxCharacters, equals(191));
      expect(table.column('request_id')!.maxCharacters, equals(191));
      expect(
        table.column('record')!.maxCharacters,
        isNull,
        reason:
            'the authoritative record is LONGTEXT and is never truncated — a '
            'width here would mean the record itself had become lossy',
      );
    });
  });

  group('a sink whose entries are already in memory is filtered directly', () {
    test('the memory sink', () async {
      final sink = TomMemoryAuditSink();
      await sink.write(_record(id: 'a', actor: 'alice'));
      await sink.write(_record(id: 'b', actor: 'bob'));

      final result = filterAuditEntries(
        sink.entries,
        const TomAuditQuery(actor: 'bob'),
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.record.id, equals('b'));
      await sink.close();
    });
  });
}
