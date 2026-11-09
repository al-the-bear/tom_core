/// A view of the audit trail across its writers.
///
/// Every process that records keeps a hash chain of its own (a *writer*), and
/// a query of one sink reads one chain. An auditor's question is about the
/// system, not about one node: the view asks every writer, merges the answers
/// by time and keeps the limit over the merged list.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../audit/audit_query.dart';
import '../audit/audit_sink.dart';
import '../audit/sql_audit_sink.dart';
import '../audit/sql_audit_sql.dart';
import '../datasources/datasource_initialization.dart';
import '../object_persistence/persistence_annotations.dart';
import 'audit_question.dart';

/// Where a view reads: the writers a trail holds, and one writer's answer.
abstract class TomAuditTrailSource {
  /// Creates a source.
  const TomAuditTrailSource();

  /// The writers the trail holds records of, by name.
  Future<List<String>> writers();

  /// [writer]'s answer to [query].
  Future<TomAuditQueryResult> query(String writer, TomAuditQuery query);
}

/// [TomAuditTrailSource] over the relational trail: one table, every writer's
/// rows.
///
/// Reads through one [TomSqlAuditSink] per writer, opened read-side
/// (`createSchema: false`) — it never writes.
class TomSqlAuditTrailSource extends TomAuditTrailSource {
  /// The data source holding [table].
  final TomDataSource datasource;

  /// The trail's table.
  final String table;

  final Map<String, TomSqlAuditSink> _readers = {};

  /// Reads [table] of [datasource].
  TomSqlAuditTrailSource(
    this.datasource, {
    this.table = defaultAuditTrailTable,
  });

  /// Reads the trail of the registered data source [datasourceName]; refuses
  /// (`audit_reports.view.unknown_datasource`) a name the registry does not
  /// hold.
  factory TomSqlAuditTrailSource.named(
    String datasourceName, {
    String table = defaultAuditTrailTable,
  }) => TomSqlAuditTrailSource(
    tomAuditReportsDatasource(datasourceName, 'view'),
    table: table,
  );

  @override
  Future<List<String>> writers() async {
    final rows = await datasource.executeQuery<TomAuditWriterRow>(
      'SELECT DISTINCT writer FROM $table ORDER BY writer',
    );
    return [for (final row in rows) row.writer];
  }

  @override
  Future<TomAuditQueryResult> query(String writer, TomAuditQuery query) =>
      (_readers[writer] ??= TomSqlAuditSink(
        datasource,
        writer: writer,
        table: table,
        createSchema: false,
      )).query(query);
}

/// [TomAuditTrailSource] over in-memory sinks, one per writer — for tests and
/// a single process.
class TomMemoryAuditTrailSource extends TomAuditTrailSource {
  /// The sinks, by writer.
  final Map<String, TomMemoryAuditSink> sinks;

  /// Reads [sinks].
  const TomMemoryAuditTrailSource(this.sinks);

  @override
  Future<List<String>> writers() async => sinks.keys.toList()..sort();

  @override
  Future<TomAuditQueryResult> query(String writer, TomAuditQuery query) async {
    final sink = sinks[writer];
    return sink == null
        ? TomAuditQueryResult.empty
        : filterAuditEntries(sink.entries, query);
  }
}

/// One record of a view's answer, with the writer whose chain holds it.
class TomAuditViewEntry {
  /// The writer.
  final String writer;

  /// The entry in that writer's chain.
  final TomAuditEntry entry;

  /// Creates an entry.
  const TomAuditViewEntry(this.writer, this.entry);
}

/// A view's answer.
class TomAuditViewResult {
  /// The matching records across the writers asked, ordered as the query
  /// asked (newest first by default), at most the query's limit.
  final List<TomAuditViewEntry> entries;

  /// Whether a writer held more matches than the answer carries.
  final bool hasMore;

  /// The writers that were asked.
  final List<String> writers;

  /// Creates an answer.
  TomAuditViewResult({
    required List<TomAuditViewEntry> entries,
    required this.hasMore,
    required List<String> writers,
  }) : entries = List.unmodifiable(entries),
       writers = List.unmodifiable(writers);
}

/// Answers a question across the writers of a trail.
class TomAuditView {
  /// Where the trail is read.
  final TomAuditTrailSource source;

  /// Creates a view over [source].
  const TomAuditView(this.source);

  /// [query] asked of [writers] (every writer of the trail when `null`).
  ///
  /// Each writer is asked with the query's limit, the answers are merged by
  /// record time — ties by writer, then by position in the chain, so the order
  /// is the same on every run — and the merged list is cut to the limit.
  /// [TomAuditViewResult.hasMore] is set when a writer had more, or when the
  /// cut dropped records.
  Future<TomAuditViewResult> query(
    TomAuditQuery query, {
    List<String>? writers,
  }) async {
    final asked = writers ?? await source.writers();
    final answers = await Future.wait([
      for (final writer in asked) source.query(writer, query),
    ]);
    final merged = <TomAuditViewEntry>[
      for (var i = 0; i < asked.length; i++)
        for (final entry in answers[i].entries)
          TomAuditViewEntry(asked[i], entry),
    ];
    int compare(TomAuditViewEntry a, TomAuditViewEntry b) {
      final byTime = a.entry.record.timestamp.compareTo(
        b.entry.record.timestamp,
      );
      if (byTime != 0) return query.newestFirst ? -byTime : byTime;
      final byWriter = a.writer.compareTo(b.writer);
      if (byWriter != 0) return byWriter;
      return query.newestFirst
          ? b.entry.index.compareTo(a.entry.index)
          : a.entry.index.compareTo(b.entry.index);
    }

    merged.sort(compare);
    final cut = merged.length > query.limit;
    return TomAuditViewResult(
      entries: cut ? merged.sublist(0, query.limit) : merged,
      hasMore: cut || answers.any((a) => a.hasMore),
      writers: asked,
    );
  }
}

/// The row `SELECT DISTINCT writer` answers.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomAuditWriterRow {
  /// The writer.
  @TomDbColumn(columnName: "writer")
  String writer = "";
}
