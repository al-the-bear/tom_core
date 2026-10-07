/// Pins the row mapper's error keys that only a reflected class of a particular
/// shape can reach: a result row that cannot be instantiated, a column whose
/// annotation the mapper cannot honour, and a `@TomReference` whose query
/// cannot be built or whose field refuses the loaded rows.
///
/// A key is the contract a caller, a log search or a translation table is
/// written against. One that no test names is a failure mode nobody checks:
/// its raise site can be deleted, reworded into a different key, or swallowed
/// by a broader catch, and every suite stays green. Each test reaches its raise
/// site through the smallest input that gets there and asserts the exact key.
///
/// **Why the reflection data is patched here.** Every one of these keys is a
/// decision `MariaDbDatasource.mapResultSet` takes about a class: its
/// constructor, a field's declared type, a field's annotations, a field's
/// setter. None of the shared fixture's entities has the faulty shape, and they
/// should not — every suite maps them. So this file installs a copy of the
/// generated reflection data in which single entries are swapped (see
/// `fixtures/scripted_reflection.dart`), each standing for a declaration a
/// person could write:
///
/// * four result types whose constructor succeeds once and then throws — one
///   per row shape, because each shape instantiates its rows under its own key;
/// * `FixtureTaskRecord` with `title` declared as a JSON column of
///   `FixtureDisplayPreference`, `priority` declared as a `Duration`, and
///   `done` converted from a column type the mapper has no reader for;
/// * `FixtureColumnTypeRecord` with a converter that refuses its value and a
///   reference to a class that maps to no table;
/// * `FixtureSecretRecord` and `FixtureDocumentRecord` with references whose
///   sentence names a column that does not exist — in the predicate, which the
///   compiler checks, and in the ordering, which only generation resolves;
/// * a `tags` setter that refuses the list it is handed.
///
/// The mapper, the column analyser, the sentence compiler and the dialect that
/// read those declarations are the real ones. No database is involved: the
/// mapper takes the driver's result set, which [OneTextRow] supplies, and a
/// reference reaches the database only through `executeQuery`, which a subclass
/// answers where a test gets that far.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:tom_reflection/generated.dart' as r;

import 'fixtures/reflection_fixture.dart'
    show
        FixtureAmountRecord,
        FixtureAmountSummary,
        FixtureColumnTypeRecord,
        FixtureDisplayPreference,
        FixtureDocumentRecord,
        FixtureNullableObservable,
        FixtureNullableRecord,
        FixtureSecretRecord,
        FixtureTag,
        FixtureTagLink,
        FixtureTagRepository,
        FixtureTaggedRecord,
        FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/scripted_reflection.dart';
import 'fixtures/text_result_set.dart';

/// Completes with a [TomServerException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// A data source whose reference reads return [rows].
class _ReferenceRows extends MariaDbDatasource {
  _ReferenceRows(this.rows);

  final List<Object> rows;

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async => rows.cast<T>();
}

/// A mirror over [real] whose constructor answers [probe] on every other call
/// and throws on the rest.
///
/// `mapResultSet` builds one probe instance to choose the row shape and then
/// one instance per row, so the probe succeeds and the first row fails — the
/// shape of a constructor that depends on state the first call changed.
///
/// [probe] is built before this mirror is installed, because a `TomClass`
/// reflects on itself while it is constructed, and the reflector answers that
/// lookup with whatever mirror is installed for the type.
ScriptedClassMirror _constructsOnce(r.ClassMirror real, Object probe) {
  var calls = 0;
  return ScriptedClassMirror.over(
    real,
    construct: () {
      if ((calls++).isEven) return probe;
      throw StateError('${real.simpleName} cannot be built twice');
    },
  );
}

/// A reference from [owner] to [target] through `FixtureTagLink`, whose
/// right-hand terms are [rightSideColumns].
TomReference _referenceVia(
  Type owner,
  Type target,
  List<String> rightSideColumns,
) => TomReference(
  targetEntity: target,
  keyType: int,
  repositoryType: FixtureTagRepository,
  joinEntity: FixtureTagLink,
  leftSideColumns: ['FixtureTagLink.taggedId=$owner.id'],
  rightSideColumns: rightSideColumns,
);

void main() {
  setUpAll(() {
    initializeReflection();
    final instantiationProbes = {
      for (final type in [
        FixtureNullableObservable,
        FixtureNullableRecord,
        FixtureAmountSummary,
        FixtureAmountRecord,
      ])
        type: (tomReflector.reflectType(type) as r.ClassMirror).newInstance(
          '',
          const [],
        ),
    };

    final patch = PatchedReflection.install();
    for (final MapEntry(key: type, value: probe)
        in instantiationProbes.entries) {
      patch.replaceClass(type, _constructsOnce(patch.classMirror(type), probe));
    }

    patch
      ..replaceField(
        FixtureTaskRecord,
        'title',
        (real) => AnnotatedFieldMirror(real, [
          const TomDbColumn<FixtureDisplayPreference, TomDbString>(
            columnName: 'title',
            isJson: true,
          ),
        ], reflectedType: FixtureDisplayPreference),
      )
      ..replaceField(
        FixtureTaskRecord,
        'priority',
        (real) =>
            AnnotatedFieldMirror(real, real.metadata, reflectedType: Duration),
      )
      ..replaceField(
        FixtureTaskRecord,
        'done',
        (real) => AnnotatedFieldMirror(real, [
          TomDbColumn<Object?, TomDbType>(
            columnName: 'done',
            columnType: Duration,
            fromDbConverter: (value) => value,
          ),
        ], reflectedType: Duration),
      )
      ..replaceField(
        FixtureColumnTypeRecord,
        'label',
        (real) => AnnotatedFieldMirror(real, [
          TomDbColumn<Duration, TomDbString>(
            columnName: 'label',
            // Typed on the box's base type, as every converter has to be:
            // the mapper reads the converter off a generics-erased column.
            fromDbConverter: (TomDbType value) =>
                throw FormatException('not a duration', value.get()),
          ),
        ], reflectedType: Duration),
      )
      ..replaceField(
        FixtureColumnTypeRecord,
        'span',
        (real) => AnnotatedFieldMirror(real, [
          _referenceVia(FixtureColumnTypeRecord, FixtureAmountSummary, [
            'FixtureTagLink.tagId=FixtureAmountSummary.entries',
          ]),
        ]),
      )
      ..replaceField(
        FixtureSecretRecord,
        'label',
        (real) => AnnotatedFieldMirror(real, [
          _referenceVia(FixtureSecretRecord, FixtureTag, [
            'FixtureTagLink.noSuchColumn=FixtureTag.id',
          ]),
        ]),
      )
      ..replaceField(
        FixtureDocumentRecord,
        'title',
        (real) => AnnotatedFieldMirror(real, [
          _referenceVia(FixtureDocumentRecord, FixtureTag, [
            'FixtureTagLink.tagId=FixtureTag.id ORDER BY noSuchColumn',
          ]),
        ]),
      )
      ..replaceSetter(
        'tags',
        (instance, value) => throw StateError('tags cannot be replaced'),
      );
  });

  final datasource = MariaDbDatasource();

  group('a result row that cannot be instantiated', () {
    for (final (type, key, row) in <(Type, String, Map<String, String?>)>[
      (
        FixtureNullableObservable,
        'error.result_processing_tcp.failed_to_instantiate_row',
        {'name': 'table-less TomClass'},
      ),
      (
        FixtureNullableRecord,
        'error.result_processing_tc.failed_to_instantiate_row',
        {'name': 'annotated TomClass'},
      ),
      (
        FixtureAmountSummary,
        'error.result_processing_field.failed_to_instantiate_row',
        {'entries': '1'},
      ),
      (
        FixtureAmountRecord,
        'error.result_processing.failed_to_instantiate_row',
        {'label': 'annotated entity'},
      ),
    ]) {
      test('$type', () {
        expect(
          datasource.mapResultSet<Object>(OneTextRow(row), type),
          _throwsKey(key),
        );
      });
    }
  });

  group('an entity column the mapper cannot honour', () {
    test('a JSON column holding text that is not JSON', () {
      expect(
        datasource.mapResultSet<FixtureTaskRecord>(
          OneTextRow({'title': '{"theme": '}),
        ),
        _throwsKey('error.result_processing.failed_json_conversion'),
      );
    });

    test('a field of a type with no reader and no converter', () {
      expect(
        datasource.mapResultSet<FixtureTaskRecord>(
          OneTextRow({'priority': '5'}),
        ),
        _throwsKey('error.result_processing.unknown_type'),
      );
    });

    test('a converter that refuses the stored value', () {
      expect(
        datasource.mapResultSet<FixtureColumnTypeRecord>(
          OneTextRow({'label': 'three days'}),
        ),
        _throwsKey('error.result_processing.failed_custom_conversion'),
      );
    });

    test('a converter fed from a column type the mapper cannot read', () {
      // The column value is read before the converter runs, inside the
      // converter's guard, so the read's own key arrives as the root of the
      // conversion failure rather than on its own.
      expect(
        datasource.mapResultSet<FixtureTaskRecord>(OneTextRow({'done': '1'})),
        throwsA(
          isA<TomServerException>()
              .having(
                (e) => e.key,
                'key',
                'error.result_processing.failed_custom_conversion',
              )
              .having(
                (e) => (e.rootException as TomServerException?)?.key,
                'root key',
                'error.result_processing.unknown_type_dbtype_conversion',
              ),
        ),
      );
    });
  });

  group('a @TomReference that cannot be loaded', () {
    test('its target maps to no table', () {
      expect(
        datasource.mapResultSet<FixtureColumnTypeRecord>(
          OneTextRow({'id': '1'}),
        ),
        _throwsKey('error.result_processing.ref_qsc_creation_failed'),
      );
    });

    test('its sentence names a column the join entity does not have', () {
      expect(
        datasource.mapResultSet<FixtureSecretRecord>(OneTextRow({'id': '1'})),
        _throwsKey('error.result_processing.ref_query_compilation_failed'),
      );
    });

    test('its sentence orders by a column no entity has', () {
      expect(
        datasource.mapResultSet<FixtureDocumentRecord>(OneTextRow({'id': '1'})),
        _throwsKey('error.result_processing.ref_query_generation_failed'),
      );
    });

    test('its field refuses the loaded list', () {
      expect(
        _ReferenceRows([FixtureTag()]).mapResultSet<FixtureTaggedRecord>(
          OneTextRow({'id': '1', 'label': 'owner'}),
        ),
        _throwsKey('error.result_processing.ref_failed_invoke_setter'),
      );
    });
  });
}
