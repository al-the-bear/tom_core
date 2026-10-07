/// Pins every error key the export module raises to the input that raises it.
///
/// The keys are the export module's contract with whoever catches a
/// [TomExportException]: an endpoint maps them to statuses, a client branches
/// on them, an operator greps a log for them. A key that no test names is a
/// failure mode nobody checks — it can be renamed, misspelled or folded into a
/// neighbouring key without a single test noticing, and the first to find out
/// is the caller whose branch silently stopped matching.
///
/// So each case below builds the smallest input that reaches one raise site and
/// asserts the **exact** key, not merely the exception type. A type-only
/// assertion would pass just as well if the guard had been replaced by a
/// different one, which is the change this file exists to catch.
///
/// Behavioural coverage of the same guards — what the message says, which
/// parameters ride along, that the PDF limit counts across sections — lives in
/// `export_test.dart`; this file is only about the keys.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A one-column, one-row result: valid in every respect, so a case that uses
/// it varies exactly the one thing it is testing.
TomTabularResult _validResult() => TomTabularResult.single(
  title: 'pinned',
  section: TomTabularSection.ofRows(
    [TomTabularColumn('a')],
    [
      const TomTabularRow(['x']),
    ],
  ),
);

/// Matches a [TomExportException] carrying exactly [key].
Matcher _exportKey(String key) =>
    throwsA(isA<TomExportException>().having((e) => e.key, 'key', key));

/// Drains a renderer's byte stream, so an error raised while rendering surfaces
/// as the returned future's error.
Future<void> _drain(Stream<List<int>> bytes) => bytes.drain<void>();

void main() {
  group('the tabular envelope refuses a malformed shape', () {
    // Construction-time guards: each is a synchronous throw from a
    // constructor, so the cases share one shape and differ only in the input.
    final cases = <({String key, String input, void Function() build})>[
      (
        key: 'export.column.name_empty',
        input: 'a column with an empty name',
        build: () => TomTabularColumn(''),
      ),
      (
        key: 'export.section.no_columns',
        input: 'a section that declares no columns',
        build: () => TomTabularSection(
          columns: const [],
          rows: const Stream<TomTabularRow>.empty(),
        ),
      ),
      (
        key: 'export.section.duplicate_column',
        input: 'a section that names one column twice',
        build: () => TomTabularSection(
          columns: [TomTabularColumn('a'), TomTabularColumn('a')],
          rows: const Stream<TomTabularRow>.empty(),
        ),
      ),
      (
        key: 'export.result.no_sections',
        input: 'a result with no sections',
        build: () => TomTabularResult(title: 'empty', sections: const []),
      ),
    ];

    for (final c in cases) {
      test('${c.input} raises ${c.key}', () {
        expect(c.build, _exportKey(c.key));
      });
    }
  });

  group('the format registry', () {
    test('an unregistered format id raises export.format.unknown', () {
      expect(
        () => TomExportFormats.standard().rendererFor('docx'),
        _exportKey('export.format.unknown'),
      );
    });
  });

  group('the PDF renderer', () {
    test(
      'one row past the configured limit raises export.pdf.row_limit_exceeded',
      () {
        final result = TomTabularResult.single(
          title: 'over',
          section: TomTabularSection.ofRows(
            [TomTabularColumn('a')],
            [
              const TomTabularRow(['1']),
              const TomTabularRow(['2']),
            ],
          ),
        );
        // The error arrives on the stream, not from `render` itself: by the
        // time the limit is crossed the call has long returned.
        expect(
          _drain(const TomPdfRenderer(rowLimit: 1).render(result)),
          _exportKey('export.pdf.row_limit_exceeded'),
        );
      },
    );
  });

  group('the export service', () {
    test(
      'storing without a configured store raises export.service.no_store',
      () {
        // Thrown synchronously, before any rendering: a server with nowhere to
        // write should not spend a render discovering that.
        expect(
          () => TomExportService().storeAs(
            _validResult(),
            'csv',
            key: 'pinned.csv',
          ),
          _exportKey('export.service.no_store'),
        );
      },
    );
  });
}
