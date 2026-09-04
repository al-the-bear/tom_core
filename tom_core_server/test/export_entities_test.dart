import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureExportRecord, FixtureExportRecordV2;
import 'fixtures/reflection_fixture.reflection.dart';

/// Export columns derived from the reflected entity.
///
/// The suite exists to hold three claims that the explicit route cannot make:
///
/// 1. **There is one declaration.** The columns, their order and their types
///    come off `@TomDbColumn`, so a column added to the entity reaches the
///    export with no other edit. That is asserted by deriving from two entity
///    versions that differ by exactly one field.
/// 2. **The two properties the type was designed around survive.** Rows stay a
///    stream — nothing is read off an entity until a renderer subscribes — and
///    cells stay positional, one `List` per row parallel to the columns.
/// 3. **Two kinds of column are not exported naively.** A redacted field and a
///    file-reference field are absent by default, and naming either in
///    `include` is an error rather than a quiet override.
///
/// Format assertions are made on rendered bytes, matching `export_test.dart`:
/// the claim is that a reflected entity renders in all three formats, and that
/// is a property of the output, not of the model.

/// A row of [FixtureExportRecord] with every cell populated.
FixtureExportRecord _record({
  int id = 1,
  String title = 'Widget',
  double amount = 9.5,
  bool done = true,
  String secret = 'do-not-export',
  String attachment = 'fixture/export/1/report.pdf',
}) => FixtureExportRecord()
  ..id = id
  ..title = title
  ..amount = amount
  ..done = done
  ..createdAt = DateTime.utc(2026, 7, 28, 14, 30)
  ..tagDay = TomZonedDate(year: 2026, month: 7, day: 28)
  ..secret = secret
  ..attachment = attachment;

/// The declared field names of a section's columns, in output order.
List<String> _names(TomTabularSection section) => [
  for (final column in section.columns) column.name,
];

Future<Uint8List> _collect(Stream<List<int>> bytes) async {
  final out = <int>[];
  await for (final chunk in bytes) {
    out.addAll(chunk);
  }
  return Uint8List.fromList(out);
}

void main() {
  setUpAll(initializeReflection);

  // ===========================================================================
  // THE DERIVED COLUMN SET
  // ===========================================================================

  group('TomTabularSection.ofEntities (derived columns)', () {
    test('derives every mapped column of the entity, in declaration order', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      expect(_names(section), [
        'id',
        'title',
        'amount',
        'done',
        'createdAt',
        'tagDay',
        'remindAt',
      ]);
    });

    test('names columns by declared field, not by database column', () {
      // `created_at` is the column; `createdAt` is the field. The audit trail
      // keys its image by the field name for the same reason — the column name
      // is a mapping detail a spec author should not have to know.
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      expect(_names(section), contains('createdAt'));
      expect(_names(section), isNot(contains('created_at')));
    });

    test('maps the declared type onto a column type', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      final types = {
        for (final column in section.columns) column.name: column.type,
      };
      expect(types['id'], TomColumnType.integer);
      expect(types['title'], TomColumnType.text);
      expect(types['amount'], TomColumnType.decimal);
      expect(types['done'], TomColumnType.boolean);
      expect(types['createdAt'], TomColumnType.timestamp);
    });

    test('falls back to text when the Dart value cannot inhabit the type', () {
      // `tagDay` is a TomZonedDate: its storage family is `date`, but the value
      // a renderer receives is not a DateTime, so declaring it `timestamp`
      // would describe a cell that can never occur.
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      final tagDay = section.columns.firstWhere(
        (column) => column.name == 'tagDay',
      );
      expect(tagDay.type, TomColumnType.text);
      // `remindAt` is the same case for the other half a timestamp splits
      // into, and it shows that the rule is *exact* type equality rather than
      // assignability: a TomZonedTime is a DateTime by inheritance, so a
      // subtype test would have let it through as a timestamp and promised
      // renderers a cell value none of them would ever receive.
      final remindAt = section.columns.firstWhere(
        (column) => column.name == 'remindAt',
      );
      expect(remindAt.type, TomColumnType.text);
    });

    test('labels default to the field name and are overridden by titles', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
        titles: {'createdAt': 'Created'},
      );
      final labels = {
        for (final column in section.columns) column.name: column.label,
      };
      expect(labels['createdAt'], 'Created');
      expect(labels['title'], 'title');
    });

    test('rejects an entity the reflector does not map', () {
      expect(
        () => TomTabularSection.ofEntities<Object>(const Stream.empty()),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.entities.not_reflected',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // DRIFT: THE COLUMN SET TRACKS THE ENTITY
  // ===========================================================================

  group('TomTabularSection.ofEntities (drift)', () {
    test('a column added to the entity appears in the export', () {
      // The two fixtures are the same entity before and after a field was
      // added. Nothing on the export side differs between these two calls, so
      // any difference in the result comes from the entity declaration alone.
      final before = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      final after = TomTabularSection.ofEntities<FixtureExportRecordV2>(
        const Stream.empty(),
      );
      expect(_names(after), [..._names(before), 'owner']);
    });

    test('a column added to the entity reaches the rendered output', () async {
      final csv = await _renderCsv(
        TomTabularResult.fromEntities<FixtureExportRecordV2>(
          Stream.value(FixtureExportRecordV2()..owner = 'alexis'),
          title: 'Records',
        ),
      );
      expect(csv.split('\r\n').first, endsWith(',owner'));
      expect(csv, contains('alexis'));
    });
  });

  // ===========================================================================
  // COLUMNS THAT MUST NOT BE EXPORTED NAIVELY
  // ===========================================================================

  group('TomTabularSection.ofEntities (redacted columns)', () {
    test('a redacted field is absent from the derived columns', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      expect(_names(section), isNot(contains('secret')));
    });

    test('a redacted value never reaches the rendered bytes', () async {
      final csv = await _renderCsv(
        TomTabularResult.fromEntities<FixtureExportRecord>(
          Stream.value(_record(secret: 'hunter2')),
          title: 'Records',
        ),
      );
      expect(csv, isNot(contains('hunter2')));
    });

    test('include cannot reach a redacted field', () {
      // The redaction declaration says the value must not exist in a second
      // place; an export is a second place, so `include` must not be able to
      // answer that question differently.
      expect(
        () => TomTabularSection.ofEntities<FixtureExportRecord>(
          const Stream.empty(),
          include: ['id', 'secret'],
        ),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.entities.redacted_column',
          ),
        ),
      );
    });
  });

  group('TomTabularSection.ofEntities (file-reference columns)', () {
    test('a file-reference column is excluded by default', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
      );
      expect(_names(section), isNot(contains('attachment')));
    });

    test('includeFileReferences exports the storage keys', () async {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        Stream.value(_record()),
        includeFileReferences: true,
      );
      expect(_names(section), contains('attachment'));
      final row = await section.rows.first;
      final at = _names(section).indexOf('attachment');
      expect(row.cell(at), 'fixture/export/1/report.pdf');
    });

    test('include cannot reach a file column without the flag', () {
      expect(
        () => TomTabularSection.ofEntities<FixtureExportRecord>(
          const Stream.empty(),
          include: ['id', 'attachment'],
        ),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.entities.file_reference_column',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // SELECTION
  // ===========================================================================

  group('TomTabularSection.ofEntities (selection)', () {
    test('include selects the columns and their order', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
        include: ['title', 'id'],
      );
      expect(_names(section), ['title', 'id']);
    });

    test('exclude removes a column', () {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        const Stream.empty(),
        exclude: {'tagDay', 'createdAt', 'remindAt'},
      );
      expect(_names(section), ['id', 'title', 'amount', 'done']);
    });

    test('an unknown name is an error, not a silent no-op', () {
      // A typo that quietly drops a column is exactly the drift this
      // constructor exists to remove, so each of the three keyed options is
      // validated against the entity's fields.
      for (final build in [
        () => TomTabularSection.ofEntities<FixtureExportRecord>(
          const Stream.empty(),
          include: ['nosuch'],
        ),
        () => TomTabularSection.ofEntities<FixtureExportRecord>(
          const Stream.empty(),
          exclude: {'nosuch'},
        ),
        () => TomTabularSection.ofEntities<FixtureExportRecord>(
          const Stream.empty(),
          titles: {'nosuch': 'No Such'},
        ),
      ]) {
        expect(
          build,
          throwsA(
            isA<TomExportException>().having(
              (e) => e.key,
              'key',
              'export.entities.unknown_column',
            ),
          ),
        );
      }
    });

    test('excluding everything is rejected at construction', () {
      expect(
        () => TomTabularSection.ofEntities<FixtureExportRecord>(
          const Stream.empty(),
          exclude: {
            'id',
            'title',
            'amount',
            'done',
            'createdAt',
            'tagDay',
            'remindAt',
          },
        ),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.entities.no_columns',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // THE TWO PROPERTIES THE TYPE WAS DESIGNED AROUND
  // ===========================================================================

  group('TomTabularSection.ofEntities (streaming and positional cells)', () {
    test(
      'nothing is pulled from the entity stream before a renderer runs',
      () async {
        var produced = 0;
        Stream<FixtureExportRecord> source() async* {
          for (var i = 0; i < 3; i++) {
            produced++;
            yield _record(id: i);
          }
        }

        final result = TomTabularResult.fromEntities<FixtureExportRecord>(
          source(),
          title: 'Records',
        );

        // Deriving the columns reads annotations, not rows: building the whole
        // result must not have touched the stream.
        expect(produced, 0);
        expect(result.sections.single.columns, isNotEmpty);

        await _renderCsv(result);
        expect(produced, 3);
      },
    );

    test('rows are pulled one at a time, not collected first', () async {
      // A renderer that materialised the stream would block until the
      // controller closed; a lazy one produces its first row while the source
      // is still open.
      final controller = StreamController<FixtureExportRecord>();
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        controller.stream,
      );
      final first = section.rows.first;

      controller.add(_record(id: 7, title: 'First'));
      final row = await first.timeout(const Duration(seconds: 5));
      expect(row.cell(0), 7);
      expect(controller.isClosed, isFalse);
      await controller.close();
    });

    test('cells are a positional list parallel to the columns', () async {
      final section = TomTabularSection.ofEntities<FixtureExportRecord>(
        Stream.value(
          _record(id: 3, title: 'Gadget', amount: 12.0, done: false),
        ),
      );
      final row = await section.rows.first;
      expect(row.cells, isA<List<Object?>>());
      expect(row.cells.length, section.columns.length);
      expect(row.cells.take(4), [3, 'Gadget', 12.0, false]);
    });
  });

  // ===========================================================================
  // ALL THREE FORMATS, WITH NO HAND-WRITTEN COLUMNS
  // ===========================================================================

  group('TomTabularResult.fromEntities (rendering)', () {
    TomTabularResult build() =>
        TomTabularResult.fromEntities<FixtureExportRecord>(
          Stream.fromIterable([
            _record(id: 1, title: 'Widget'),
            _record(id: 2, title: 'Gadget', amount: 12.0, done: false),
          ]),
          title: 'Records',
          metadata: {'Filter': 'all'},
          titles: {'title': 'Name'},
        );

    test('renders CSV', () async {
      final csv = await _renderCsv(build());
      final lines = csv.trimRight().split('\r\n');
      expect(lines.first, 'id,Name,amount,done,createdAt,tagDay,remindAt');
      expect(lines[1], startsWith('1,Widget,9.5,true,'));
      // 12.0 renders as `12`: a whole double loses its `.0` in the shared text
      // rule, which is `tomFormatCellAsText`'s decision, not this one's.
      expect(lines[2], startsWith('2,Gadget,12,false,'));
    });

    test('renders XLSX', () async {
      final bytes = await _collect(const TomXlsxRenderer().render(build()));
      // The ZIP local-file-header signature: the archive was produced at all.
      expect(bytes.take(4), [0x50, 0x4b, 0x03, 0x04]);
      expect(bytes.length, greaterThan(500));
    });

    test('renders PDF', () async {
      final bytes = await _collect(const TomPdfRenderer().render(build()));
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });
  });
}

Future<String> _renderCsv(TomTabularResult result) async {
  final bytes = await _collect(
    const TomCsvRenderer(byteOrderMark: false).render(result),
  );
  return utf8.decode(bytes);
}
