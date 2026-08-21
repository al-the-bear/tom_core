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
/// ## Why there are two ways to build a section
///
/// [TomTabularSection.ofRows] / [TomTabularSection.ofMaps] make the caller
/// declare its columns and project each row onto them. For an export **of
/// entities** that projection restates what `@TomDbColumn` already declares,
/// and the two then drift in both directions: a column added to the entity
/// never reaches the export, and a type changed on the entity leaves cells
/// being formatted under a stale [TomColumnType].
///
/// [TomTabularSection.ofEntities] / [TomTabularResult.fromEntities] derive the
/// columns from the reflected entity instead, so there is one declaration and
/// nothing to keep in step. They are bounded on purpose — see
/// [TomTabularSection.ofEntities] — and the explicit route remains for
/// everything they cannot express.
library;

import '../audit/audit_trail.dart';
import '../datasources/sql_dialects.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/persistence_annotations.dart';

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
  ) => TomTabularRow(
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
  TomTabularSection({required this.columns, required this.rows, this.title}) {
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
  }) => TomTabularSection(
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
  }) => TomTabularSection(
    columns: columns,
    rows: rows.map((values) => TomTabularRow.fromMap(columns, values)),
    title: title,
  );

  /// Creates a section whose columns are **derived from the reflected entity**
  /// [T], and whose rows are read off each entity by reflection.
  ///
  /// The "these entities, these columns" case — the majority of exports, and
  /// the one a declarative report definition can express without a hand-written
  /// projection. Every `@TomDbColumn` field of [T] becomes a column, named by
  /// its **declared field name**, typed by [TomColumnType] derived from its
  /// declared type, and labelled by [titles] or by the field name.
  ///
  /// ```dart
  /// TomTabularSection.ofEntities<Task>(taskStream, title: 'Open tasks')
  /// ```
  ///
  /// ## What this is not for
  ///
  /// An export of a **join** or of an **aggregate** is not one entity: its
  /// columns come from several types or from expressions no type declares.
  /// Those keep the explicit route ([ofRows] / [ofMaps]), and so does anything
  /// needing a computed or reformatted column — a storage key turned into a
  /// download URL, say, which this cannot produce because the public URL of a
  /// file is a routing decision the export module does not know.
  ///
  /// ## Two kinds of column that are not exported
  ///
  /// - **Redacted fields.** `@TomAudited(redact: …)` names the fields whose
  ///   values must not exist in a second place at all. An export is a second
  ///   place, and answering that question differently here would defeat the
  ///   declaration; they are dropped, and naming one in [include] throws.
  /// - **File references.** A `@TomFileReference` column holds an internal
  ///   *storage key*, not content — a spreadsheet of them is a small leak and
  ///   is useless to the reader either way. Dropped by default; pass
  ///   [includeFileReferences] to export the keys to an audience that has a use
  ///   for them.
  ///
  /// ## Selecting and naming
  ///
  /// [include], when given, selects the columns **and their order**; [exclude]
  /// removes columns; both are keyed by *declared field name*, matching how the
  /// audit trail keys its own image — the database column name is a mapping
  /// detail a spec author should not have to know. A name in [include],
  /// [exclude] or [titles] that no field carries throws rather than being
  /// ignored: a typo that silently drops a column is exactly the drift this
  /// constructor exists to remove. [include] narrows the exportable set and
  /// never widens it, so it cannot be used to reach a redacted or (unless
  /// [includeFileReferences] is set) a file-reference column.
  static TomTabularSection ofEntities<T>(
    Stream<T> rows, {
    String? title,
    List<String>? include,
    Set<String> exclude = const {},
    Map<String, String> titles = const {},
    bool includeFileReferences = false,
  }) {
    final projection = _TomEntityProjection.of(
      T,
      include: include,
      exclude: exclude,
      titles: titles,
      includeFileReferences: includeFileReferences,
    );
    final sources = projection.sources;
    return TomTabularSection(
      columns: projection.columns,
      // `map` is lazy: nothing is read off an entity — and nothing is pulled
      // from `rows` — until a renderer subscribes, and only one row is live at
      // a time. Cells stay positional to the columns, one list per row.
      rows: rows.map(
        (entity) => TomTabularRow(
          List<Object?>.generate(
            sources.length,
            (index) => sources[index].getVariableValue(entity as Object),
            growable: false,
          ),
        ),
      ),
      title: title,
    );
  }

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
  }) => TomTabularResult(title: title, sections: [section], metadata: metadata);

  /// Creates a single-section result whose columns are derived from the
  /// reflected entity [T].
  ///
  /// The declarative counterpart of [TomTabularResult.single] over
  /// [TomTabularSection.ofRows]: what to export is stated as a type and a row
  /// stream, and the column set is read off `@TomDbColumn`. See
  /// [TomTabularSection.ofEntities] for what is derived, what is excluded, and
  /// what keeps the explicit route.
  ///
  /// ```dart
  /// final result = TomTabularResult.fromEntities<Task>(
  ///   repository.streamAll(),
  ///   title: 'Open tasks',
  ///   metadata: {'Filter': 'state = open'},
  ///   exclude: {'internalRank'},
  ///   titles: {'dueAt': 'Due'},
  /// );
  /// ```
  static TomTabularResult fromEntities<T>(
    Stream<T> rows, {
    required String title,
    String? sectionTitle,
    Map<String, String> metadata = const {},
    List<String>? include,
    Set<String> exclude = const {},
    Map<String, String> titles = const {},
    bool includeFileReferences = false,
  }) => TomTabularResult(
    title: title,
    metadata: metadata,
    sections: [
      TomTabularSection.ofEntities<T>(
        rows,
        title: sectionTitle,
        include: include,
        exclude: exclude,
        titles: titles,
        includeFileReferences: includeFileReferences,
      ),
    ],
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

/// The columns derived from one reflected entity type, and the metadata each
/// was derived from — kept parallel so a row can be projected positionally.
class _TomEntityProjection {
  _TomEntityProjection(this.columns, this.sources);

  /// The derived columns, in output order.
  final List<TomTabularColumn> columns;

  /// The reflected field behind each column, at the same index.
  final List<TomColumnInformation> sources;

  /// Derives the exportable columns of [entityType].
  static _TomEntityProjection of(
    Type entityType, {
    required List<String>? include,
    required Set<String> exclude,
    required Map<String, String> titles,
    required bool includeFileReferences,
  }) {
    final declared = TomAnnotationAnalyzer.getPersistentColumns(entityType);
    if (declared == null || declared.isEmpty) {
      throw TomExportException(
        'export.entities.not_reflected',
        'Cannot derive export columns: the entity declares none, or is not '
            'registered with the reflector.',
        parameters: {'entity': '$entityType'},
      );
    }

    // An association is resolved through a join entity rather than a column of
    // this table, so there is no cell to read for it.
    final mapped = {
      for (final column in declared)
        if (column.reference == null) column.declaredName: column,
    };
    final redacted = TomAuditTrail.policyFor(entityType).redact;

    void requireKnown(String name, String where) {
      if (mapped.containsKey(name)) return;
      throw TomExportException(
        'export.entities.unknown_column',
        'The export names a field the entity does not declare.',
        parameters: {
          'entity': '$entityType',
          'field': name,
          'where': where,
          'declared': mapped.keys.join(', '),
        },
      );
    }

    for (final name in exclude) {
      requireKnown(name, 'exclude');
    }
    for (final name in titles.keys) {
      requireKnown(name, 'titles');
    }

    final ordered = <TomColumnInformation>[];
    if (include == null) {
      for (final entry in mapped.entries) {
        if (exclude.contains(entry.key)) continue;
        if (redacted.contains(entry.key)) continue;
        if (!includeFileReferences && entry.value.fileReference != null) {
          continue;
        }
        ordered.add(entry.value);
      }
    } else {
      for (final name in include) {
        requireKnown(name, 'include');
        if (exclude.contains(name)) continue;
        // `include` selects from what is exportable; it does not grant access
        // to what is not. Silently dropping the name would make the two rules
        // depend on which was written last.
        if (redacted.contains(name)) {
          throw TomExportException(
            'export.entities.redacted_column',
            'The export names a redacted field. A value declared out of the '
                'audit trail must not be exported either.',
            parameters: {'entity': '$entityType', 'field': name},
          );
        }
        final column = mapped[name]!;
        if (!includeFileReferences && column.fileReference != null) {
          throw TomExportException(
            'export.entities.file_reference_column',
            'The export names a file-reference field, which holds an internal '
                'storage key. Pass includeFileReferences to export the keys.',
            parameters: {'entity': '$entityType', 'field': name},
          );
        }
        ordered.add(column);
      }
    }

    if (ordered.isEmpty) {
      throw TomExportException(
        'export.entities.no_columns',
        'Nothing is left to export: every field of the entity is excluded, '
            'redacted or a file reference.',
        parameters: {'entity': '$entityType'},
      );
    }

    return _TomEntityProjection([
      for (final column in ordered)
        TomTabularColumn(
          column.declaredName,
          label: titles[column.declaredName],
          type: columnTypeOf(column),
        ),
    ], ordered);
  }

  /// The cell type for [column], from the type family its annotations declare.
  ///
  /// [TomAnnotationAnalyzer.familyOf] describes how the value is **stored**; a
  /// cell holds the **Dart** value the getter returns, and the two diverge — a
  /// JSON column is text in the database and a `Map` in Dart, and an explicit
  /// `TomDbType` box can disagree with the field it annotates. So a family maps
  /// to a column type only when the declared Dart type can actually inhabit it;
  /// otherwise the column is [TomColumnType.text], which every renderer formats
  /// through `tomFormatCellAsText`.
  ///
  /// Reusing [TomColumnType.dartType] for that test is what keeps this a rule
  /// rather than a second type table to maintain beside the first.
  static TomColumnType columnTypeOf(TomColumnInformation column) {
    final candidate = switch (TomAnnotationAnalyzer.familyOf(column)) {
      TomSqlTypeFamily.integer => TomColumnType.integer,
      TomSqlTypeFamily.decimal => TomColumnType.decimal,
      TomSqlTypeFamily.boolean => TomColumnType.boolean,
      TomSqlTypeFamily.dateTime ||
      TomSqlTypeFamily.date ||
      TomSqlTypeFamily.time => TomColumnType.timestamp,
      TomSqlTypeFamily.text ||
      TomSqlTypeFamily.binary ||
      TomSqlTypeFamily.unknown => TomColumnType.text,
    };
    final dartType = column.column?.declaredDartType() ?? column.declaredType;
    return candidate.dartType == dartType ? candidate : TomColumnType.text;
  }
}
