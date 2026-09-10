/// DB-backed tests for `@TomReference` association loading.
///
/// The annotation has two halves. The *sentence* it produces is built by
/// `TomAnnotationAnalyzer.referenceQuery` and covered, without a connection, by
/// `reference_query_test.dart`. The half here is what the data source does with
/// that sentence: compile it, run it, and write the resulting rows back into
/// the owning entity through the field's mirror. It is reachable only behind a
/// live connection, which is why it had no test at all — the only entities in
/// the workspace declaring `@TomReference` live in `tom_uam_server`, whose suite
/// never reads one back.
///
/// Three properties, none of them previously asserted anywhere:
///
///  1. The rows come back and land in the entity's list.
///  2. The pending-reference stack is **per row**. It was once declared outside
///     the row loop and drained inside it, so row *k* re-resolved every earlier
///     row's associations — an owner would end up holding its own tags plus
///     every preceding owner's. Only a multi-row result with an association can
///     observe the repair, which is what makes this file the only place it can
///     be seen.
///  3. A reference field that is `null` is refused with the documented error
///     rather than silently leaving the association empty. The data source
///     fills the list the entity already holds, because reflection cannot
///     construct a `List<Target>` — a mirror of a generic type has no type
///     arguments to build with — so there is nothing to fall back to.
///
/// `@Tags(['db'])`, so the default `testkit :test` run stays green with no
/// server. Bring one up with `tool/run_db_tests.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTag, FixtureTaggedRecord, FixtureUntaggedRecord;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// Captures the data source's own `Executing SQL` trace lines.
///
/// The per-row property is about *work*, not about the answer: see the test
/// that uses this. Counting statements is the only way to see it, and the
/// driver already announces each one at trace level.
class _StatementLog extends TomLogOutput {
  final List<String> statements = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    final text = convertToString(message);
    if (text.contains('MariaDbDatasourceExecuting SQL:')) {
      statements.add(text);
    }
  }
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('@TomReference association loading (DB-backed)', () {
    late TomDataSourceInfo dsi;
    late MariaDbDatasource ds;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      ds = dsi.datasource as MariaDbDatasource;
      await TestDatabase.ensureFixtureAssociationTables(dsi);
    });

    setUp(() => TestDatabase.truncateFixtureAssociationTables(dsi));

    /// Inserts a tag and answers its generated id.
    Future<int> tag(String name) async {
      await ds.executeCommand('INSERT INTO fixture_tag (name) VALUES (:name)', {
        'name': name,
      });
      final rows = await ds.executeQuery<FixtureTag>(
        'SELECT id, name FROM fixture_tag WHERE name = :name',
        {'name': name},
      );
      return rows.single.id!;
    }

    /// Inserts an owner and answers its generated id.
    Future<int> owner(String label) async {
      await ds.executeCommand(
        'INSERT INTO fixture_tagged (label) VALUES (:label)',
        {'label': label},
      );
      final rows = await ds.executeQuery<FixtureTaggedRecord>(
        'SELECT id, label FROM fixture_tagged WHERE label = :label',
        {'label': label},
      );
      return rows.single.id!;
    }

    Future<void> link(int taggedId, int tagId) => ds.executeCommand(
      'INSERT INTO fixture_tag_link (tagged_id, tag_id) '
      'VALUES (:tagged, :tag)',
      {'tagged': taggedId, 'tag': tagId},
    );

    /// Every owner, in id order, with its association resolved.
    Future<List<FixtureTaggedRecord>> read() =>
        ds.executeQuery<FixtureTaggedRecord>(
          'SELECT id, label FROM fixture_tagged ORDER BY id',
        );

    /// The tag names an owner came back holding, sorted so the assertion is
    /// about membership rather than about the order a join happened to return.
    List<String> namesOf(FixtureTaggedRecord record) =>
        [for (final t in record.tags) t.name!]..sort();

    test('the referenced rows land in the entity list', () async {
      final red = await tag('red');
      final blue = await tag('blue');
      final one = await owner('one');
      await link(one, red);
      await link(one, blue);

      final records = await read();

      expect(records, hasLength(1));
      expect(namesOf(records.single), ['blue', 'red']);
    });

    test('an owner with no links comes back with an empty list', () async {
      // Not the same claim as the one above: the field starts empty, so a
      // reference that was never resolved at all is indistinguishable from one
      // resolved to nothing — except that the resolution *clears* the list
      // first, which is what makes a second read of a reused entity correct.
      await owner('lonely');

      final records = await read();

      expect(records.single.tags, isEmpty);
    });

    test('each row gets its own associations', () async {
      final red = await tag('red');
      final green = await tag('green');
      final blue = await tag('blue');
      final one = await owner('one');
      final two = await owner('two');
      final three = await owner('three');
      await link(one, red);
      await link(two, green);
      await link(three, blue);

      final records = await read();

      expect(records.map((r) => r.label), ['one', 'two', 'three']);
      expect(namesOf(records[0]), ['red']);
      expect(namesOf(records[1]), ['green']);
      expect(namesOf(records[2]), ['blue']);
    });

    test('an n-row read costs n reference queries, not n squared', () async {
      // The per-row stack, and the only assertion that can see it. With the
      // stack declared outside the row loop and drained inside it, row 2
      // resolves row 1's pending reference again before its own and row 3
      // resolves all three — so an n-row read issues n(n+1)/2 reference
      // queries instead of n.
      //
      // The *answer* is unaffected, which is why this is a statement count and
      // not a row assertion: the fill clears the list before adding, so
      // resolving an owner twice recomputes the same list. Measured with the
      // repair reverted — the rows came back correct and every assertion above
      // still passed. What the defect costs is work, quadratically, on exactly
      // the reads that return many rows.
      for (final name in ['a', 'b', 'c', 'd']) {
        final t = await tag(name);
        final o = await owner(name);
        await link(o, t);
      }

      final log = _StatementLog();
      final previousOutput = tomLog.logOutput;
      final previousLevel = tomLog.logLevel;
      addTearDown(() {
        tomLog.logOutput = previousOutput;
        tomLog.setLogLevel(previousLevel);
      });
      tomLog.logOutput = log;
      tomLog.setLogLevel(TomLogLevel.all);

      final records = await read();

      expect(records, hasLength(4));
      // One statement for the owners, then one reference query per owner.
      expect(
        log.statements,
        hasLength(5),
        reason:
            'four owners should cost four reference queries; '
            '${log.statements.length} means the pending stack outlived its row',
      );
    });

    test('a row is not given the same association twice', () async {
      // The other half of "once": the list is cleared before it is filled, so
      // resolving twice cannot accumulate. Asserted on a single owner with a
      // single tag, where a doubled resolution is a two-element list of one
      // repeated name rather than a wrong name.
      final red = await tag('red');
      final one = await owner('one');
      await link(one, red);

      final records = await read();

      expect(records.single.tags, hasLength(1));
    });

    test('a null reference field is refused, naming the field', () async {
      // The same row, read as the declaration that cannot receive it. The data
      // source fills the list the entity holds; there is none, and reflection
      // cannot build one — so the association must fail loudly rather than
      // arrive empty, which would read exactly like an owner with no links.
      final red = await tag('red');
      final one = await owner('one');
      await link(one, red);

      await expectLater(
        ds.executeQuery<FixtureUntaggedRecord>(
          'SELECT id, label FROM fixture_tagged ORDER BY id',
        ),
        throwsA(
          isA<MariadbDatasourceException>()
              .having(
                (e) => e.key,
                'key',
                'error.result_processing.'
                    'ref_reference_field_must_have_non-null_value',
              )
              .having((e) => e.parameters?['field'], 'field', 'tags'),
        ),
      );
    });
  }, skip: skipReason);
}
