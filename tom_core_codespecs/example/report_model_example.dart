// CE-RP — the authorable grouped-projection shape, and its result envelope.
//
// A report is dimensions (what to group by), measures (what to aggregate) and
// columns (what to display), and the definition rejects six malformed shapes
// at CONSTRUCTION rather than producing a wrong report at run time. Seeing one
// well-formed definition whole is the fastest way to learn what the parts are
// for; seeing the refusals is the fastest way to learn what they guard.
//
// Run with:
//   dart run --enable-asserts example/report_model_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

/// Stand-in for the CE-DB entity a real report projects over.
class Order {}

void main() async {
  requireAsserts();
  print('== CE-RP: report definition ==');

  final salesByRegion = TomReportDefinition(
    reportId: 'sales_by_region',
    displayName: 'app.report.salesByRegion',
    sourceEntity: Order,
    dimensions: [
      TomReportDimension(
        key: 'region',
        columnName: 'customer_region',
        valueKind: TomReportValueKind.string,
        label: 'app.report.column.region',
      ),
    ],
    measures: [
      TomReportMeasure(
        key: 'revenue',
        function: TomReportMeasureFunction.sum,
        columnName: 'total',
        valueKind: TomReportValueKind.currency,
      ),
      TomReportMeasure(
        key: 'customers',
        function: TomReportMeasureFunction.count,
        columnName: 'customer_id',
        distinct: true,
        valueKind: TomReportValueKind.integer,
      ),
    ],
    columns: [
      TomReportColumn(
        name: 'region',
        sourceKey: 'region',
        valueKind: TomReportValueKind.string,
        drillThroughRouteId: 'regionDetail',
      ),
      TomReportColumn(
        name: 'revenue',
        sourceKey: 'revenue',
        valueKind: TomReportValueKind.currency,
        formatPattern: '#,##0.00',
      ),
      TomReportColumn(
        name: 'customers',
        sourceKey: 'customers',
        valueKind: TomReportValueKind.integer,
      ),
    ],
    parameters: [
      TomReportParameter(
        name: 'from',
        valueKind: TomReportValueKind.date,
        required: true,
      ),
      TomReportParameter(
        name: 'status',
        valueKind: TomReportValueKind.enumeration,
        enumId: 'order_status',
      ),
    ],
    charts: [
      TomReportChart(
        chartId: 'by_region',
        kind: TomReportChartKind.bar,
        categoryColumn: 'region',
        valueColumns: ['revenue'],
      ),
    ],
    deliveryChannels: [
      TomReportDeliveryChannel.apiResponse,
      TomReportDeliveryChannel.fileExport,
    ],
    scheduleExpression: '0 6 1 * *',
  );

  print('  $salesByRegion');
  print(
    '  aggregated=${salesByRegion.isAggregated} '
    'required parameters='
    '${salesByRegion.requiredParameters.map((p) => p.name).join(", ")}',
  );
  assert(salesByRegion.isAggregated, 'it has measures');
  assert(salesByRegion.requiredParameters.length == 1);

  // A listing is the same class with no measures; a single-row total is the
  // same class with no dimensions. Neither needs a different type.
  final totals = TomReportDefinition(
    reportId: 'totals',
    sourceEntity: Order,
    measures: [
      TomReportMeasure(key: 'orders', function: TomReportMeasureFunction.count),
    ],
    columns: [
      TomReportColumn(
        name: 'orders',
        sourceKey: 'orders',
        valueKind: TomReportValueKind.integer,
      ),
    ],
  );
  assert(totals.dimensions.isEmpty, 'one aggregated row over the whole set');
  assert(totals.isAggregated);
  print('  $totals — no dimensions, one aggregated row');

  _refusals();
  await _result(salesByRegion);
}

/// What the definition refuses, and when: at construction, every time.
void _refusals() {
  print('  -- refusals --');
  var refused = 0;

  void expectRefusal(String what, void Function() build) {
    try {
      build();
      throw StateError('$what was accepted and should not have been');
    } on ArgumentError catch (error) {
      refused++;
      print('    $what: ${error.message}');
    }
  }

  expectRefusal('a column displaying nothing', () {
    TomReportDefinition(
      reportId: 'bad_column',
      sourceEntity: Order,
      dimensions: [
        TomReportDimension(
          key: 'region',
          columnName: 'customer_region',
          valueKind: TomReportValueKind.string,
        ),
      ],
      columns: [
        TomReportColumn(
          name: 'margin',
          sourceKey: 'margin',
          valueKind: TomReportValueKind.currency,
        ),
      ],
    );
  });

  expectRefusal('a chart plotting an unprojected column', () {
    TomReportDefinition(
      reportId: 'bad_chart',
      sourceEntity: Order,
      dimensions: [
        TomReportDimension(
          key: 'region',
          columnName: 'customer_region',
          valueKind: TomReportValueKind.string,
        ),
      ],
      columns: [
        TomReportColumn(
          name: 'region',
          sourceKey: 'region',
          valueKind: TomReportValueKind.string,
        ),
      ],
      charts: [
        TomReportChart(
          chartId: 'c',
          kind: TomReportChartKind.pie,
          categoryColumn: 'region',
          valueColumns: ['revenue'],
        ),
      ],
    );
  });

  expectRefusal('one key for both a dimension and a measure', () {
    TomReportDefinition(
      reportId: 'ambiguous',
      sourceEntity: Order,
      dimensions: [
        TomReportDimension(
          key: 'total',
          columnName: 'total',
          valueKind: TomReportValueKind.currency,
        ),
      ],
      measures: [
        TomReportMeasure(
          key: 'total',
          function: TomReportMeasureFunction.sum,
          columnName: 'total',
        ),
      ],
      columns: [
        TomReportColumn(
          name: 'total',
          sourceKey: 'total',
          valueKind: TomReportValueKind.currency,
        ),
      ],
    );
  });

  expectRefusal('a report projecting no columns', () {
    TomReportDefinition(
      reportId: 'empty',
      sourceEntity: Order,
      columns: const [],
    );
  });

  expectRefusal('a non-count measure with no column', () {
    TomReportMeasure(key: 'revenue', function: TomReportMeasureFunction.sum);
  });

  expectRefusal('an enumeration parameter naming no enum', () {
    TomReportParameter(
      name: 'status',
      valueKind: TomReportValueKind.enumeration,
    );
  });

  assert(refused == 6, 'all six malformed shapes must be refused');
}

/// The result envelope: rows stream in the column order the section declares.
Future<void> _result(TomReportDefinition definition) async {
  print('  -- result --');
  final result = TomReportResult.single(
    reportId: definition.reportId,
    title: 'Sales by region',
    section: TomReportResultSection(
      columns: definition.columns,
      // A factory, not a stream: the section is read once per delivery, and
      // this definition declares two (`apiResponse` and `fileExport`). Each
      // read calls this closure, so each delivery gets its own pass.
      openRows: () => Stream<List<Object?>>.fromIterable([
        ['North', 128400.55, 312],
        ['South', 94100.00, 221],
      ]),
    ),
    charts: definition.charts,
    metadata: {'asOf': '2026-09-23T00:00:00Z', 'from': '2026-01-01'},
  );

  // The consumer reads cells positionally against the section's columns.
  var rows = 0;
  await for (final row in result.sections.single.rows) {
    print('    ${row[0]}: ${row[1]} over ${row[2]} customers');
    rows++;
  }
  assert(rows == 2);

  // And again, which is what `deliveryChannels: [apiResponse, fileExport]`
  // means: one run delivered twice. Against a section built from a stream
  // rather than a factory this second pass would throw on any result large
  // enough to be single-subscription — which is every result the streaming
  // shape exists for.
  final exported = await result.sections.single.rows.length;
  assert(exported == 2, 'a second delivery reads the same rows again');
  print('    second delivery re-read all $exported rows');

  // `metadata` is unmodifiable, so a renderer cannot relabel the run it was
  // handed — the provenance of a result belongs to whoever produced it.
  var frozen = false;
  try {
    result.metadata['ranBy'] = 'someone else';
  } on UnsupportedError {
    frozen = true;
  }
  assert(frozen);
  print('    metadata is unmodifiable by the consumer');
}
