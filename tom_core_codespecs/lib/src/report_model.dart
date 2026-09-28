/// CE-RP Reporting — the report definition and its result envelope.
///
/// The two classes `tom_core` has no home for (`codespecs_mapping.md` §5.28):
///
/// - [TomReportDefinition] — the **authored** report: what it selects, how it
///   groups and measures, which columns and charts it projects, which runtime
///   parameters it takes, and which channels it is delivered on. Server locus.
/// - [TomReportResult] — the **shared** result envelope a report operation
///   returns, so the client can render it and the server can export it.
///
/// ## Why this is a part and not a composition
///
/// A report *looks* like an endpoint (CE-API) over a query (CE-DB) rendered in
/// a table (CE-EL) — but none of those parts can hold it. CE-API's authored
/// identity is an operation, and one report is delivered on zero to three
/// channels; CE-DB authors entities, columns and row filters but has nowhere to
/// author a **grouping dimension** or a **measure**; and a report column is an
/// *output projection* carrying an aggregate and a format, not a CE-FM input
/// field. What CE-RP adds over all of them is the **grouped projection** — the
/// dimension/measure pair — and the artifact identity that holds it together.
///
/// ## Why the envelope does not extend `TomTabularResult`
///
/// `tom_core_server`'s export module already has a minimal tabular shape that
/// its CSV / XLSX / PDF renderers consume. That type is **server-side**, and
/// this envelope is **shared** — the client renders reports too, and must not
/// depend on a server type. So [TomReportResult] is authored here as the shared
/// shape and the server *adapts* it onto `TomTabularResult` when exporting: a
/// one-way projection, exactly the CE-DB pattern where the entity's field shape
/// is authored once in the shared project and the server persistence facet
/// derives from it.
///
/// The adaptation constrains this envelope in one way, and it is inherited
/// deliberately: **rows stay streamable**. A report exists precisely for the
/// results too large to hold inline, and a `List` of rows would put the whole
/// result in memory before the first rendered byte.
library;

/// The value types a report column or parameter may carry.
///
/// One closed vocabulary for both, rather than two overlapping ones. The SOM
/// authors the two sides from slightly different sets — a column is never an
/// `entityRef` and a parameter is never a `currency` — but they agree on the
/// seven kinds in between, and a single vocabulary means a generator has one
/// mapping table instead of two that must be kept in step.
enum TomReportValueKind {
  /// Free text.
  string,

  /// A whole number.
  integer,

  /// A fractional number.
  decimal,

  /// A monetary amount — a decimal that additionally carries a currency.
  ///
  /// Column-side only: a parameter takes the amount as a [decimal].
  currency,

  /// A calendar date with no time component.
  date,

  /// A point in time.
  dateTime,

  /// A truth value.
  boolean,

  /// A member of a `domainEnum` domain enum.
  enumeration,

  /// A reference to a CE-DB entity, carried as its identity.
  ///
  /// Parameter-side only: a column projects the entity's *label*, which is a
  /// [string].
  entityRef,
}

/// The aggregate a [TomReportMeasure] computes.
///
/// Deliberately **1:1 with `tom_core_server`'s `TomAggregateFunction`** rather
/// than a richer parallel vocabulary. A measure the query layer cannot compile
/// is a measure that cannot run, so the authorable set is exactly the compilable
/// set. The two modifiers SQL expresses as part of the call — `COUNT(*)` and
/// `COUNT(DISTINCT c)` — are fields on the measure ([TomReportMeasure.columnName]
/// and [TomReportMeasure.distinct]), not extra members here, for the same
/// reason: that is how the substrate models them.
enum TomReportMeasureFunction {
  /// The number of rows, or of non-null values of the measured column.
  count,

  /// The total of the measured column across the group.
  sum,

  /// The mean of the measured column across the group.
  avg,

  /// The smallest value of the measured column in the group.
  min,

  /// The largest value of the measured column in the group.
  max,
}

/// How a rendered report reaches its audience.
///
/// The definition names the channel; the transport is entirely reused —
/// `apiResponse` and `fileExport` by `tom_core_server`'s export service, `email`
/// by its messaging module through the CE-NT catalogue.
enum TomReportDeliveryChannel {
  /// Returned inline from the report's own CE-API operation.
  apiResponse,

  /// Rendered to a file and stored, for later download.
  fileExport,

  /// Rendered and mailed, resolved as a CE-NT notification type.
  email,
}

/// The chart forms a report may declare.
///
/// Closed, because a chart kind selects which axes and series are meaningful —
/// an open string would let a specification name a form no renderer has a rule
/// for, and the failure would surface at render time rather than at generation.
enum TomReportChartKind {
  /// Categorical comparison as bars.
  bar,

  /// A trend across an ordered axis.
  line,

  /// Part-to-whole as circular segments.
  pie,

  /// Part-to-whole with a hollow centre.
  donut,

  /// Two measures plotted against each other as points.
  scatter,

  /// A single measure against a target or range.
  gauge,

  /// A measure across two dimensions, encoded as colour intensity.
  heatmap,
}

/// One grouping key of a report — the "by what" of the grouped projection.
///
/// Compiles to a `groupBy` column on the CE-DB query.
class TomReportDimension {
  /// Creates a dimension over [columnName], projected under [key].
  TomReportDimension({
    required this.key,
    required this.columnName,
    required this.valueKind,
    this.label,
  }) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'A dimension must have a key.');
    }
    if (columnName.isEmpty) {
      throw ArgumentError.value(
        columnName,
        'columnName',
        'A dimension must name the entity column it groups by.',
      );
    }
  }

  /// The stable alias the dimension is projected under, and that a
  /// [TomReportColumn] names to display it.
  final String key;

  /// The CE-DB entity column being grouped by.
  final String columnName;

  /// The value type the grouped key carries.
  final TomReportValueKind valueKind;

  /// The CE-TX message key for the dimension's display name, if it has one.
  final String? label;

  @override
  String toString() => 'TomReportDimension($key over $columnName)';
}

/// One aggregated value of a report — the "how much" of the grouped projection.
///
/// Compiles to an aggregate projection on the CE-DB query.
class TomReportMeasure {
  /// Creates a measure applying [function] to [columnName], aliased as [key].
  ///
  /// [columnName] may be `null` only for [TomReportMeasureFunction.count],
  /// which is then the argument-less row count — every other function needs
  /// something to aggregate. Throws [ArgumentError] otherwise, because a `SUM`
  /// with no operand is a specification defect the generator cannot repair.
  TomReportMeasure({
    required this.key,
    required this.function,
    this.columnName,
    this.distinct = false,
    this.valueKind = TomReportValueKind.decimal,
    this.label,
  }) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'A measure must have a key.');
    }
    if (columnName == null && function != TomReportMeasureFunction.count) {
      throw ArgumentError.value(
        columnName,
        'columnName',
        'Only count may omit its column; ${function.name} must name one.',
      );
    }
  }

  /// The stable alias the aggregate is projected under.
  final String key;

  /// The aggregate applied.
  final TomReportMeasureFunction function;

  /// The CE-DB entity column aggregated, or `null` for a bare row count.
  final String? columnName;

  /// Whether the aggregate considers distinct operand values only.
  final bool distinct;

  /// The value type the aggregate yields.
  final TomReportValueKind valueKind;

  /// The CE-TX message key for the measure's display name, if it has one.
  final String? label;

  @override
  String toString() =>
      'TomReportMeasure($key = ${function.name}(${columnName ?? '*'}))';
}

/// One projected output column of a report.
///
/// A column **displays** a dimension or a measure — it does not introduce data
/// of its own. That is the invariant [TomReportDefinition] checks: a column
/// whose [sourceKey] resolves to neither is a column with nothing behind it.
class TomReportColumn {
  /// Creates a column displaying the dimension or measure keyed [sourceKey].
  TomReportColumn({
    required this.name,
    required this.sourceKey,
    required this.valueKind,
    this.label,
    this.formatPattern,
    this.drillThroughRouteId,
  }) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A column must have a name.');
    }
    if (sourceKey.isEmpty) {
      throw ArgumentError.value(
        sourceKey,
        'sourceKey',
        'A column must name the dimension or measure it displays.',
      );
    }
  }

  /// The column's machine-facing name in the result envelope.
  final String name;

  /// The [TomReportDimension.key] or [TomReportMeasure.key] this column shows.
  final String sourceKey;

  /// The value type rendered.
  final TomReportValueKind valueKind;

  /// The CE-TX message key for the column header.
  final String? label;

  /// A presentation pattern for the value — a number or date format.
  ///
  /// Presentation only: it never changes what was selected, so a generator may
  /// apply it in the renderer without re-running the query.
  final String? formatPattern;

  /// The CE-NV route a click on a cell navigates to, if the column drills
  /// through.
  ///
  /// **An open id string, permanently** — the one CE-RP target that stays one.
  /// A `CsRouteRef` cannot carry it: `codespecs_mapping.md` §5.23's locus rule
  /// bars a **server**-owned declaration from citing a **client**-owned
  /// referent, and a report definition runs on the server while a route belongs
  /// to the client project.
  ///
  /// That makes it unlike the four `codespecs_mapping.md` §5.23 string
  /// exemptions, which are exempt
  /// *because their referent is not a Dart declaration*. A route **is** one, so
  /// the compile-time edge is lost to locus rather than absent by nature, and
  /// the lost guarantee is replaced by a named generation-time validator check
  /// (`codespecs_derivation_contract.md` §6 check 18) — the same substitution
  /// check 17 makes for a notification channel's fallback.
  final String? drillThroughRouteId;

  @override
  String toString() => 'TomReportColumn($name ← $sourceKey)';
}

/// A runtime input the caller supplies when the report is run.
///
/// Distinct from a CE-DB row filter authored into the query: a parameter is
/// **supplied per execution**, so it is part of the report's request shape and
/// needs a type, a bound and a presentation.
class TomReportParameter {
  /// Creates a parameter.
  ///
  /// A parameter that is [required] and has a [defaultValue] is accepted: the
  /// default is what a caller gets when it does not choose, and *required*
  /// means the value must be present when the query runs — not that the caller
  /// must type it.
  TomReportParameter({
    required this.name,
    required this.valueKind,
    this.required = false,
    this.defaultValue,
    this.label,
    this.enumId,
    this.entityId,
  }) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A parameter must have a name.');
    }
    if (valueKind == TomReportValueKind.enumeration && enumId == null) {
      throw ArgumentError.value(
        enumId,
        'enumId',
        'An enumeration parameter must name its domain enum.',
      );
    }
    if (valueKind == TomReportValueKind.entityRef && entityId == null) {
      throw ArgumentError.value(
        entityId,
        'entityId',
        'An entityRef parameter must name its CE-DB entity.',
      );
    }
  }

  /// The parameter's name in the report's request shape.
  final String name;

  /// The value type the caller supplies.
  final TomReportValueKind valueKind;

  /// Whether the query needs a value for this parameter.
  final bool required;

  /// The value used when the caller supplies none.
  final Object? defaultValue;

  /// The CE-TX message key for the input's label.
  final String? label;

  /// The `domainEnum` domain enum whose values are offered, for an enumeration.
  final String? enumId;

  /// The CE-DB entity whose instances are offered, for an entity reference.
  final String? entityId;

  @override
  String toString() => 'TomReportParameter($name: ${valueKind.name})';
}

/// A chart a report declares over its own projected columns.
///
/// **Declared here, rendered by whoever can.** A chart is authored input —
/// the SOM carries chart type, series and axes as structured fields — so it is
/// part of the specification surface. Rendering is not: the client draws charts
/// natively, while two of the three *export* formats cannot express one at all.
/// A chart therefore travels on the definition and the envelope, and an
/// exporter that has no way to draw it omits it rather than failing.
class TomReportChart {
  /// Creates a chart over the columns named by [categoryColumn] and [
  /// valueColumns].
  TomReportChart({
    required this.chartId,
    required this.kind,
    required this.categoryColumn,
    required this.valueColumns,
    this.title,
    this.seriesColumn,
  }) {
    if (chartId.isEmpty) {
      throw ArgumentError.value(chartId, 'chartId', 'A chart must have an id.');
    }
    if (valueColumns.isEmpty) {
      throw ArgumentError.value(
        valueColumns,
        'valueColumns',
        'A chart must plot at least one value column.',
      );
    }
  }

  /// The chart's id, unique within its report.
  final String chartId;

  /// The chart form.
  final TomReportChartKind kind;

  /// The CE-TX message key for the chart title.
  final String? title;

  /// The [TomReportColumn.name] supplying the category (x) axis.
  final String categoryColumn;

  /// The [TomReportColumn.name]s supplying the plotted values.
  final List<String> valueColumns;

  /// The [TomReportColumn.name] that splits the data into series, if any.
  final String? seriesColumn;

  /// Every column name this chart refers to.
  Iterable<String> get referencedColumns => [
    categoryColumn,
    ...valueColumns,
    ?seriesColumn,
  ];

  @override
  String toString() => 'TomReportChart($chartId, ${kind.name})';
}

/// A complete authored report definition — the CE-RP CodeSpec's holder.
///
/// Server locus: the definition is where the report is executed. What crosses
/// to the client is the [TomReportResult] envelope and the parameter shape.
class TomReportDefinition {
  /// Creates a definition and checks its internal consistency.
  ///
  /// Throws [ArgumentError] on any of six defects, each a specification error
  /// that no generator can repair and that would otherwise emit code referring
  /// to something that does not exist:
  ///
  /// - an empty [reportId];
  /// - an empty [columns] list — a report that projects nothing;
  /// - a duplicate identifier within one namespace: dimension key, measure key,
  ///   column name, parameter name or chart id;
  /// - one key claimed by both a dimension and a measure, which would leave a
  ///   column's [TomReportColumn.sourceKey] ambiguous;
  /// - a column whose [TomReportColumn.sourceKey] names neither a dimension nor
  ///   a measure;
  /// - a chart plotting a column the report does not project.
  ///
  /// This is the normative list. Prose elsewhere points here rather than
  /// restating it, so there is one enumeration to keep in step with the code
  /// below — and it sits in the same file, so a seventh check is a diff a
  /// reviewer sees alongside it.
  TomReportDefinition({
    required this.reportId,
    required this.sourceEntity,
    required this.columns,
    this.displayName,
    this.dimensions = const [],
    this.measures = const [],
    this.parameters = const [],
    this.charts = const [],
    this.deliveryChannels = const [TomReportDeliveryChannel.apiResponse],
    this.scheduleExpression,
  }) {
    if (reportId.isEmpty) {
      throw ArgumentError.value(
        reportId,
        'reportId',
        'A report must have an id.',
      );
    }
    if (columns.isEmpty) {
      throw ArgumentError.value(
        columns,
        'columns',
        'Report "$reportId" projects no columns.',
      );
    }
    _rejectDuplicates(dimensions.map((d) => d.key), 'dimension key');
    _rejectDuplicates(measures.map((m) => m.key), 'measure key');
    _rejectDuplicates(columns.map((c) => c.name), 'column name');
    _rejectDuplicates(parameters.map((p) => p.name), 'parameter name');
    _rejectDuplicates(charts.map((c) => c.chartId), 'chart id');

    final sourceKeys = {
      ...dimensions.map((d) => d.key),
      ...measures.map((m) => m.key),
    };
    // A dimension and a measure sharing a key would make a column's sourceKey
    // ambiguous, and the two set-unions above cannot see across each other.
    if (sourceKeys.length != dimensions.length + measures.length) {
      throw ArgumentError.value(
        reportId,
        'reportId',
        'Report "$reportId" uses one key for both a dimension and a measure.',
      );
    }
    for (final column in columns) {
      if (!sourceKeys.contains(column.sourceKey)) {
        throw ArgumentError.value(
          column.sourceKey,
          'columns',
          'Column "${column.name}" of report "$reportId" displays '
              '"${column.sourceKey}", which is neither a dimension nor a '
              'measure.',
        );
      }
    }
    final columnNames = columns.map((c) => c.name).toSet();
    for (final chart in charts) {
      for (final referenced in chart.referencedColumns) {
        if (!columnNames.contains(referenced)) {
          throw ArgumentError.value(
            referenced,
            'charts',
            'Chart "${chart.chartId}" of report "$reportId" plots column '
                '"$referenced", which the report does not project.',
          );
        }
      }
    }
  }

  /// The report's stable id — the key a `CsReportRef` const carries.
  final String reportId;

  /// The CE-TX message key for the report's title.
  final String? displayName;

  /// The CE-DB entity the projection selects from, as a `Type` literal.
  ///
  /// **A `Type`, never a string** (`codespecs_mapping.md` §5.23, §4.4.1). An
  /// entity is already a Dart type, so `codespecs_mapping.md` §5.23's `Cs*Ref`
  /// family gives it no ref
  /// const **by design**: citing the class directly makes a renamed entity a
  /// compile error, which a string could never be. It also needs nothing but
  /// `dart:core`, so it keeps this package's `dependencies: {}` — the same
  /// property that decides `TomJobDeclaration.readEntities`.
  final Type sourceEntity;

  /// The grouping keys.
  ///
  /// May be empty, which aggregates over the whole filtered set and yields one
  /// row — the same meaning an empty `groupBy` has in the query substrate.
  final List<TomReportDimension> dimensions;

  /// The aggregated values.
  final List<TomReportMeasure> measures;

  /// The projected output columns, in output order.
  final List<TomReportColumn> columns;

  /// The runtime inputs the caller supplies.
  final List<TomReportParameter> parameters;

  /// The charts declared over the projected columns.
  final List<TomReportChart> charts;

  /// The channels this report is delivered on.
  final List<TomReportDeliveryChannel> deliveryChannels;

  /// When the report runs unattended — a recurrence expression, verbatim.
  ///
  /// `null` means the report is only ever run on demand.
  ///
  /// **A schedule, not a job id.** The specification authors a cron-like
  /// expression (`codespecs_mapping.md` §5.28's *Report schedule* row, from the
  /// report-schedule section's schedule-expression field); the CE-JB job that
  /// runs the projection is **realised from** it. `codespecs_mapping.md` §5.29
  /// makes that explicit —
  /// "a scheduled report is declared once, on the CE-RP report definition; the
  /// job that runs it is realised from that schedule, not from a second entry"
  /// — so a field holding a *job* id would invite exactly the second source
  /// that rule exists to prevent, and would point at a declaration the
  /// generator had not written yet.
  ///
  /// This is therefore not a cross-part reference at all: a recurrence
  /// expression names nothing declarable. The schedule's remaining authored
  /// detail — time zone, effective dates, generation window and timeout —
  /// lowers onto the derived job's own `TomJobDefinition`, where the substrate
  /// already carries it, rather than being restated here.
  ///
  /// Authorization is **not** a field here. It rides a `@CsAuthorize` beside
  /// the `@CsReport` marker, per `codespecs_mapping.md` §5.15's field-level
  /// rule: the report's access level and permitted roles are exactly that
  /// annotation's requirement kind and its typed `CsRoleRef` list, so the edge
  /// is compile-checked instead of being an id string here.
  final String? scheduleExpression;

  /// Whether the report aggregates rather than listing rows.
  bool get isAggregated => measures.isNotEmpty;

  /// The parameters a caller must supply a value for.
  Iterable<TomReportParameter> get requiredParameters =>
      parameters.where((p) => p.required);

  static void _rejectDuplicates(Iterable<String> values, String what) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw ArgumentError.value(value, what, 'Duplicate $what "$value".');
      }
    }
  }

  @override
  String toString() =>
      'TomReportDefinition($reportId, ${columns.length} columns)';
}

/// One titled block of a [TomReportResult]: columns over a stream of rows.
///
/// Cells are **positional**, parallel to [columns], for the reason the export
/// module's row type gives: rows are the one thing there are many of, and a
/// keyed map re-stores every column name for every row.
class TomReportResultSection {
  /// Creates a section over [openRows], a factory that opens a fresh row
  /// stream.
  ///
  /// A factory rather than a stream because a section is read more than once:
  /// `deliveryChannels` is a list, and a report declaring `apiResponse` and
  /// `fileExport` is one run delivered two ways. Handed a stream, the second
  /// delivery of a *large* result throws — a large result is a
  /// single-subscription stream, and that is exactly the case the streaming
  /// shape exists for.
  ///
  /// **[openRows] must return a new stream on every call.** The type calls it
  /// once per read of [rows] and can guarantee no more than that; a factory
  /// closing over one `StreamController` returns the same already-listened
  /// stream and reintroduces the defect this shape removes. Open the query, or
  /// the file, inside the closure.
  TomReportResultSection({
    required this.columns,
    required Stream<List<Object?>> Function() openRows,
    this.title,
  }) : _openRows = openRows {
    if (columns.isEmpty) {
      throw ArgumentError.value(
        columns,
        'columns',
        'A result section must declare at least one column.',
      );
    }
    final seen = <String>{};
    for (final column in columns) {
      if (!seen.add(column.name)) {
        throw ArgumentError.value(
          column.name,
          'columns',
          'A result section names column "${column.name}" twice.',
        );
      }
    }
  }

  /// An optional caption for the block.
  final String? title;

  /// The section's columns, in output order.
  final List<TomReportColumn> columns;

  /// A **fresh** stream of the section's rows — pulled once, in order.
  ///
  /// A stream and not a list because a report exists for results too large to
  /// hold inline. Each read calls the factory the section was built with, so
  /// two renderings of one result are two independent passes rather than a
  /// second listen on a spent stream.
  ///
  /// Reading this twice therefore *starts* two streams. That is the point, and
  /// it is worth knowing before writing `section.rows` in a condition and
  /// again in the loop beneath it.
  Stream<List<Object?>> get rows => _openRows();

  /// Opens one pass over the rows. See the constructor for its obligation.
  final Stream<List<Object?>> Function() _openRows;

  @override
  String toString() =>
      'TomReportResultSection(${title ?? 'untitled'}, '
      '${columns.length} columns)';
}

/// The shared result envelope a CE-RP report operation returns.
///
/// Shared locus: the client renders it and the server adapts it onto
/// `tom_core_server`'s `TomTabularResult` to export it. It carries the charts
/// the definition declared, so a client that can draw them has what it needs
/// and an exporter that cannot simply ignores them.
class TomReportResult {
  /// Creates a result.
  TomReportResult({
    required this.reportId,
    required this.title,
    required this.sections,
    this.charts = const [],
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata) {
    if (sections.isEmpty) {
      throw ArgumentError.value(
        sections,
        'sections',
        'Report result "$reportId" has no sections.',
      );
    }
  }

  /// Creates a single-section result — the common case.
  factory TomReportResult.single({
    required String reportId,
    required String title,
    required TomReportResultSection section,
    List<TomReportChart> charts = const [],
    Map<String, String> metadata = const {},
  }) => TomReportResult(
    reportId: reportId,
    title: title,
    sections: [section],
    charts: charts,
    metadata: metadata,
  );

  /// The [TomReportDefinition.reportId] this result came from.
  final String reportId;

  /// The rendered document title.
  final String title;

  /// The result's sections, in output order.
  final List<TomReportResultSection> sections;

  /// The charts declared for this result.
  final List<TomReportChart> charts;

  /// Name/value pairs describing how the result was produced.
  ///
  /// The parameter values that produced it, who ran it, the as-of timestamp —
  /// the context that keeps a downloaded file interpretable months later.
  final Map<String, String> metadata;

  @override
  String toString() =>
      'TomReportResult($reportId, ${sections.length} sections)';
}
