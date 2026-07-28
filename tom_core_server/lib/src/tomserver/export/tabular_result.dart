/// The tabular shape that export renderers consume.
///
/// This is the *input* half of the export capability: a title, one or more
/// [TomTabularSection]s, and — inside each section — typed [TomTabularColumn]s
/// over a **stream** of [TomTabularRow]s.
///
/// ## Why a stream of rows and not a list
///
/// An export exists precisely for the results too large to hand back inline. A
/// `List<TomTabularRow>` would put the whole result in memory before the first
/// byte of output was produced, which defeats the purpose: the caller would
/// need enough heap for the rows *and* the rendered document at once. So a
/// section carries `Stream<TomTabularRow>` and every renderer pulls it.
///
/// The stream is **single-subscription and consumed once**. A renderer reads it
/// exactly once, in order. Rendering the same result twice — or in two formats
/// — requires a result whose sections can produce a fresh stream; build one per
/// render rather than sharing.
///
/// ## Why cells are positional
///
/// Rows are the one thing there are many of, so their representation is the one
/// that matters. A `Map<String, Object?>` per row allocates a hash table and
/// re-stores every column name for every row; a `List<Object?>` parallel to the
/// section's columns allocates one list. At a million rows that difference is
/// the whole memory budget. [TomTabularRow.fromMap] exists for the callers who
/// naturally hold keyed values — a `TomGroupedRow`, a JSON map — and it does the
/// ordering once, against the section's declared columns.
///
/// ## Why this type and not the CE-RP envelope
///
/// The CodeSpecs report-result envelope (`codespecs_mapping.md` §5.28) is a
/// `tom_core_codespecs` gap class owned by the specification quest, and it is
/// not written. This type is deliberately the *minimal* tabular shape those
/// renderers actually need, so the rendering capability is useful now — any
/// endpoint returning rows can export — and so that when the envelope lands it
/// is adapted to this shape rather than the renderers being rewritten.
///
/// The one thing §5.28 names that is **not** here is **charts** (series and
/// axes). Two of the three output formats cannot express a chart at all, so a
/// chart model would be a field that only the PDF renderer ever read. When
/// charts are specified they belong beside this type, not inside it.
library;

import '../little_things/server_exception.dart';

/// Raised when a result cannot be built, rendered or stored.
///
/// Not client-visible by default: an export failure describes server-side
/// document generation, which tells a caller nothing it can act on.
class TomExportException extends TomServerException {
  /// Creates an export exception.
  TomExportException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
    super.clientThrow = false,
  });
}

/// The value types a tabular column may hold.
///
/// This set is not chosen freshly — it is the set the query layer already
/// produces. `TomGroupedRow` maps exactly `int`, `double`, `String`, `bool` and
/// `DateTime`, so an aggregate result adapts to a column type without a lossy
/// conversion, and a renderer never meets a value it has no rule for.
enum TomColumnType {
  /// A whole number; rendered unquoted, right-aligned, as an XLSX number.
  integer(int),

  /// A fractional number; rendered unquoted, right-aligned, as an XLSX number.
  decimal(double),

  /// Free text; the only type that needs quoting and escaping.
  text(String),

  /// A truth value; rendered as `true`/`false`, as an XLSX boolean.
  boolean(bool),

  /// A point in time; rendered ISO-8601, as an XLSX date serial.
  timestamp(DateTime);

  /// Creates a column type bound to the Dart type it accepts.
  const TomColumnType(this.dartType);

  /// The Dart type a cell of this column must hold (or `null`).
  final Type dartType;

  /// The column type for [value]'s runtime type, or `null` if it has none.
  ///
  /// Used by adapters that infer columns from data rather than being told.
  static TomColumnType? forValue(Object? value) => switch (value) {
        int() => TomColumnType.integer,
        double() => TomColumnType.decimal,
        String() => TomColumnType.text,
        bool() => TomColumnType.boolean,
        DateTime() => TomColumnType.timestamp,
        _ => null,
      };
}

/// One typed column of a [TomTabularSection].
class TomTabularColumn {
  /// Creates a column.
  ///
  /// [name] is the machine-facing key — the query alias, the JSON field. [label]
  /// is what a human reads in the header row; it defaults to [name] so that the
  /// common case stays a one-argument call.
  TomTabularColumn(
    this.name, {
    String? label,
    this.type = TomColumnType.text,
    this.width,
  }) : label = label ?? name {
    if (name.isEmpty) {
      throw TomExportException(
        'export.column.name_empty',
        'A tabular column must have a name.',
      );
    }
  }

  /// The machine-facing key: the query alias or map key this column reads.
  final String name;

  /// The human-facing header text.
  final String label;

  /// The value type every cell in this column must hold.
  final TomColumnType type;

  /// An optional presentation width hint, in characters.
  ///
  /// CSV ignores it; XLSX turns it into a column width; PDF turns it into a
  /// relative column flex. It is a *hint* — no renderer is required to honour
  /// it, and omitting it lets each renderer size the column itself.
  final int? width;

  @override
  String toString() => 'TomTabularColumn($name: ${type.name})';
}

/// One row of a [TomTabularSection]: cell values positional to its columns.
class TomTabularRow {
  /// Creates a row from cell values in column order.
  ///
  /// The list is stored as given rather than copied — a renderer reads a row
  /// once and drops it, so the copy would buy nothing and cost an allocation
  /// per row. Callers must not mutate a list after handing it over.
  const TomTabularRow(this.cells);

  /// Creates a row by reading [values] in the order [columns] declares.
  ///
  /// A missing key yields `null` — an absent value and an explicit null render
  /// identically, so distinguishing them would be a difference no output can
  /// carry. A key in [values] that no column names is ignored: sections
  /// routinely project a subset of what a query returned.
  factory TomTabularRow.fromMap(
    List<TomTabularColumn> columns,
    Map<String, Object?> values,
  ) =>
      TomTabularRow(
        List<Object?>.generate(
          columns.length,
          (i) => values[columns[i].name],
          growable: false,
        ),
      );

  /// The cell values, parallel to the section's columns.
  final List<Object?> cells;

  /// The value in the column at [index], or `null` when the row is short.
  ///
  /// Tolerating a short row is deliberate: a row that ends early is a row whose
  /// trailing columns are empty, which every output format can express. Failing
  /// instead would turn a cosmetic gap into a failed export.
  Object? cell(int index) => index < cells.length ? cells[index] : null;

  @override
  String toString() => 'TomTabularRow(${cells.length} cells)';
}

/// One titled table: typed columns over a stream of rows.
class TomTabularSection {
  /// Creates a section.
  TomTabularSection({
    required this.columns,
    required this.rows,
    this.title,
  }) {
    if (columns.isEmpty) {
      throw TomExportException(
        'export.section.no_columns',
        'A tabular section must declare at least one column.',
      );
    }
    final seen = <String>{};
    for (final column in columns) {
      if (!seen.add(column.name)) {
        throw TomExportException(
          'export.section.duplicate_column',
          'A tabular section names the same column twice.',
          parameters: {'column': column.name},
        );
      }
    }
  }

  /// Creates a section over rows already in memory.
  ///
  /// The convenience for the small case — a summary table, a test fixture —
  /// where streaming buys nothing. Large results should build the stream
  /// directly so they are never fully resident.
  factory TomTabularSection.ofRows(
    List<TomTabularColumn> columns,
    Iterable<TomTabularRow> rows, {
    String? title,
  }) =>
      TomTabularSection(
        columns: columns,
        rows: Stream<TomTabularRow>.fromIterable(rows),
        title: title,
      );

  /// Creates a section over keyed maps, ordering each by [columns].
  ///
  /// The adapter for anything that hands back values by name — a
  /// `TomGroupedRow`'s values, decoded JSON, a driver's row map.
  factory TomTabularSection.ofMaps(
    List<TomTabularColumn> columns,
    Stream<Map<String, Object?>> rows, {
    String? title,
  }) =>
      TomTabularSection(
        columns: columns,
        rows: rows.map((values) => TomTabularRow.fromMap(columns, values)),
        title: title,
      );

  /// An optional table caption; becomes the XLSX sheet name and the PDF heading.
  final String? title;

  /// The section's typed columns, in output order.
  final List<TomTabularColumn> columns;

  /// The section's rows — pulled once, in order, by whichever renderer runs.
  final Stream<TomTabularRow> rows;

  @override
  String toString() =>
      'TomTabularSection(${title ?? 'untitled'}, ${columns.length} columns)';
}

/// A complete tabular result: a title and one or more sections.
class TomTabularResult {
  /// Creates a result.
  TomTabularResult({
    required this.title,
    required this.sections,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata) {
    if (sections.isEmpty) {
      throw TomExportException(
        'export.result.no_sections',
        'A tabular result must have at least one section.',
      );
    }
  }

  /// Creates a single-section result — by far the common case.
  factory TomTabularResult.single({
    required String title,
    required TomTabularSection section,
    Map<String, String> metadata = const {},
  }) =>
      TomTabularResult(
        title: title,
        sections: [section],
        metadata: metadata,
      );

  /// The document title: the PDF heading, the XLSX workbook title.
  final String title;

  /// The sections, in output order. One XLSX sheet each.
  final List<TomTabularSection> sections;

  /// Free-form name/value pairs describing how the result was produced.
  ///
  /// Rendered as a header block by the formats that have one (PDF), and
  /// ignored by the ones that do not (CSV). Typical entries: the filter that
  /// produced the rows, the account that ran it, the as-of timestamp — the
  /// context that makes a downloaded file interpretable months later.
  final Map<String, String> metadata;

  @override
  String toString() => 'TomTabularResult($title, ${sections.length} sections)';
}
