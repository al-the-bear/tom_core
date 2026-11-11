/// Moving a tenant and backing one up, against a real MariaDB or PostgreSQL:
/// a shared tenant moved into a schema of its own and back, a type change
/// into another type's shared schema, a type whose tree does not take the data
/// refused with the tenant left where it was, and a tenant's rows exported,
/// restored and carried through JSON with their types intact.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; `tool/run_db_tests.sh` and `tool/run_db_tests_postgres.sh` start
/// one.
@Tags(['db'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTenantNote, FixtureTenantNoteRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

const String _noteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_note (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32)  NULL,
  text      VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';
  final name = TestDatabase.datasourceName;

  group('moving and backing up a tenant', () {
    late TomDataSourceInfo base;
    late Directory root;
    late TomTenancy tenancy;
    late TomMemoryTenantRegistry registry;
    late FixtureTenantNoteRepository notes;
    final database = TestDatabase.databaseName;
    final schemas = ['${database}_mvacme', '${database}_standard'];
    final ownDatabase = '${database}_mvglobex';

    void file(String path, String sql) => File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(sql);

    Future<List<String>> textsOf(String tenant) async => [
      for (final note in await tenancy.runFor(tenant, notes.findAll))
        note.text!,
    ]..sort();

    Future<int> rowsIn(TomDataSourceInfo info, String tenant) =>
        TomTenantTables.count(
          info.datasource as TomSqlDatasource,
          'fixture_tenant_note',
          'tenant_id',
          tenant,
        );

    setUpAll(() async {
      if (!reachable) return;
      initializeReflection();
      base = await TestDatabase.register();
      notes = FixtureTenantNoteRepository();
      for (final schema in schemas) {
        await TestDatabase.dropSchema(base.datasource, schema);
      }
      await TestDatabase.execute(base.datasource, _noteDdl);
      // Registered after `register`'s, so it runs first: the tenants' schemas
      // go while the suite database is still there.
      addTearDown(() async {
        await TomTenancy.reset();
        for (final schema in schemas) {
          await TestDatabase.dropSchema(base.datasource, schema);
        }
        await TestDatabase.dropDatabase(base.datasource, ownDatabase);
        root.deleteSync(recursive: true);
      });
      root = Directory.systemTemp.createTempSync('tom_tenant_move_');
      for (final type in ['default', 'standard']) {
        file(
          'tenant/$type/$name/[1]-create_fixture_tenant_note.sql',
          // The tree in the database's own dialect, as a deployment ships it.
          '${(base.datasource as TomSqlDatasource).sqlDialect.translateCanonicalScript(_noteDdl)};',
        );
      }
      file(
        'tenant/narrow/$name/[1]-create_other.sql',
        'CREATE TABLE IF NOT EXISTS mv_other (id BIGINT);',
      );
      registry = TomMemoryTenantRegistry();
      tenancy = TomTenancy(
        types: [
          for (final type in ['default', 'standard', 'narrow'])
            TomTenantType(type, migrations: p.join(root.path, 'tenant', type)),
        ],
        tenants: [TomTenant('mvacme'), TomTenant('mvglobex')],
        datasources: {name},
        createSchemas: true,
        registry: registry,
      );
      await TomTenancy.install(tenancy);
      for (final (tenant, text) in [
        ('mvacme', 'a1'),
        ('mvacme', 'a2'),
        ('mvglobex', 'g1'),
      ]) {
        await tenancy.runFor(
          tenant,
          () => notes.save(FixtureTenantNote()..text = text),
        );
      }
    });

    tearDownAll(() async {
      if (reachable) await TestDatabase.reset();
    });

    test('MV-1: a shared tenant moves into a schema of its own: copied, '
        'counted, switched, its shared rows deleted, resumed', () async {
      final report = await tenancy.moveTenant(
        'mvacme',
        isolation: TomTenantIsolation.schema,
      );
      expect(report.copied, {'$name/fixture_tenant_note': 2});
      expect(report.deleted, {'fixture_tenant_note': 2});
      expect(report.to, 'default/schema');
      expect(await rowsIn(base, 'mvacme'), 0, reason: 'gone from the shared');
      expect(await textsOf('mvacme'), ['a1', 'a2']);
      expect(await textsOf('mvglobex'), ['g1'], reason: 'untouched');
      expect(tenancy.statusOf('mvacme'), TomTenantStatus.active);
      final record = (await registry.find('mvacme'))!;
      expect(record.isolation, TomTenantIsolation.schema);
      expect(
        (await tenancy.runFor(
          'mvacme',
          () async => TomDataSourceInfo.getDataSourceInfo(name)!,
        )).datasource.sqlDialect,
        isNotNull,
      );
    }, skip: skipReason);

    test('MV-2: a move onto its own placement is refused; and back to shared '
        'drops the schema', () async {
      await expectLater(
        tenancy.moveTenant('mvacme', isolation: TomTenantIsolation.schema),
        _throwsKey('tenancy.move.nothing_to_move'),
      );
      final report = await tenancy.moveTenant(
        'mvacme',
        isolation: TomTenantIsolation.shared,
      );
      expect(report.dropped, ['$name: schema ${database}_mvacme']);
      expect(await rowsIn(base, 'mvacme'), 2);
      expect(await textsOf('mvacme'), ['a1', 'a2']);
    }, skip: skipReason);

    test('MV-3: a type whose tree does not take the data is refused before '
        'anything is copied; the tenant stays and is resumed', () async {
      await expectLater(
        tenancy.moveTenant('mvacme', type: 'narrow'),
        _throwsKey('tenancy.move.target_rejects'),
      );
      expect(tenancy.statusOf('mvacme'), TomTenantStatus.active);
      expect(tenancy.tenants['mvacme']!.type, 'default');
      expect(await textsOf('mvacme'), ['a1', 'a2']);
    }, skip: skipReason);

    test('MV-4: a type change moves the rows into the type\'s shared '
        'schema, migrated by its tree', () async {
      final report = await tenancy.moveTenant('mvacme', type: 'standard');
      expect(report.to, 'standard/shared');
      expect(await rowsIn(base, 'mvacme'), 0);
      expect(await textsOf('mvacme'), ['a1', 'a2']);
      expect((await registry.find('mvacme'))!.type, 'standard');
    }, skip: skipReason);

    test('MV-5: a backup survives JSON and restores the tenant; a restore '
        'over rows is refused unless replacing', () async {
      final backup = await tenancy.exportTenant('mvacme');
      expect(backup.counts, {'$name/fixture_tenant_note': 2});
      final copy = TomTenantBackup.fromJson(
        (jsonDecode(jsonEncode(backup.toJson())) as Map).cast(),
      );
      await expectLater(
        tenancy.importTenant(copy),
        _throwsKey('tenancy.import.not_empty'),
      );
      expect(await tenancy.importTenant(copy, replace: true), {
        '$name/fixture_tenant_note': 2,
      });
      expect(await textsOf('mvacme'), ['a1', 'a2']);
      expect(
        () => TomTenantBackup.fromJson({'format': 'something'}),
        _throwsKey('tenancy.backup.invalid'),
      );
    }, skip: skipReason);

    test('MV-6: exported values keep their type — numbers, booleans, '
        'instants, decimals, bytes and NULL', () async {
      final datasource = base.datasource as TomSqlDatasource;
      await datasource.executeCommand('DROP TABLE IF EXISTS mv_types');
      await datasource.executeCommand(
        TestDatabase.isPostgres
            ? 'CREATE TABLE mv_types (id BIGINT, tenant VARCHAR(32), '
                  'flag BOOLEAN, at TIMESTAMP(6), amount DECIMAL(10,2), '
                  'data BYTEA, note TEXT)'
            : 'CREATE TABLE mv_types (id BIGINT, tenant VARCHAR(32), '
                  'flag BOOLEAN, at DATETIME(6), amount DECIMAL(10,2), '
                  'data BLOB, note TEXT)',
      );
      final insert = TestDatabase.isPostgres
          ? "INSERT INTO mv_types VALUES (7, 'mvacme', TRUE, "
                "'2026-11-10 12:34:56.123456', 12.50, "
                "decode('00ff10', 'hex'), NULL)"
          : "INSERT INTO mv_types VALUES (7, 'mvacme', TRUE, "
                "'2026-11-10 12:34:56.123456', 12.50, UNHEX('00FF10'), NULL)";
      await datasource.executeCommand(insert);
      final exported = await TomTenantTables.export(
        datasource,
        name,
        'mv_types',
        'tenant',
        'mvacme',
      );
      await TomTenantTables.delete(datasource, 'mv_types', 'tenant', 'mvacme');
      final restored = TomTenantTableBackup.fromJson(
        (jsonDecode(jsonEncode(exported.toJson())) as Map).cast(),
      );
      expect(await TomTenantTables.import(datasource, restored), 1);
      final again = await TomTenantTables.export(
        datasource,
        name,
        'mv_types',
        'tenant',
        'mvacme',
      );
      expect(again.rows, exported.rows);
      final row = again.rows.single;
      expect(row[0], '7');
      expect(row[5]!.toLowerCase(), '00ff10');
      expect(row[6], isNull);
      expect(row[3], startsWith('2026-11-10'));
      await datasource.executeCommand('DROP TABLE mv_types');
    }, skip: skipReason);

    test('MV-7: a move into a database of its own on the same server — on '
        'PostgreSQL out of reach of a qualified name, so copied through the '
        'backup\'s text form', () async {
      await TestDatabase.dropDatabase(base.datasource, ownDatabase);
      await TestDatabase.createDatabase(base.datasource, ownDatabase);
      final report = await tenancy.moveTenant(
        'mvglobex',
        isolation: TomTenantIsolation.database,
        datasources: {
          name: {
            ...(TestDatabase.datasourceConfig[name] as Map)
                .cast<String, Object>(),
            'databaseName': ownDatabase,
          },
        },
      );
      expect(report.copied, {'$name/fixture_tenant_note': 1});
      expect(report.to, 'default/database');
      expect(await rowsIn(base, 'mvglobex'), 0);
      expect(await textsOf('mvglobex'), ['g1']);
      expect(await textsOf('mvacme'), ['a1', 'a2'], reason: 'untouched');
    }, skip: skipReason);

    test('MV-8: a tenant that is not active or suspended, a move into its own '
        'database, and a target holding its rows are refused', () async {
      await tenancy.setStatus('mvacme', TomTenantStatus.migrationFailed);
      await expectLater(
        tenancy.moveTenant('mvacme', type: 'default'),
        _throwsKey('tenancy.move.not_movable'),
      );
      await tenancy.setStatus('mvacme', TomTenantStatus.active);

      await expectLater(
        tenancy.moveTenant(
          'mvglobex',
          datasources: tenancy.tenants['mvglobex']!.datasources,
        ),
        _throwsKey('tenancy.move.same_place'),
      );
      expect(tenancy.statusOf('mvglobex'), TomTenantStatus.active);

      final datasource = base.datasource as TomSqlDatasource;
      await datasource.executeCommand(
        "INSERT INTO fixture_tenant_note (tenant_id, text) "
        "VALUES ('mvacme', 'stray')",
      );
      await expectLater(
        tenancy.moveTenant('mvacme', type: 'default'),
        _throwsKey('tenancy.move.target_not_empty'),
      );
      await TomTenantTables.delete(
        datasource,
        'fixture_tenant_note',
        'tenant_id',
        'mvacme',
      );
      expect(tenancy.statusOf('mvacme'), TomTenantStatus.active);
      expect(await textsOf('mvacme'), ['a1', 'a2']);
    }, skip: skipReason);

    test(
      'MV-9: copied rows that do not arrive are refused and the copy rolled '
      'back — on PostgreSQL, through a trigger deleting what is inserted',
      () async {
        final datasource = base.datasource as TomSqlDatasource;
        await datasource.executeCommand(
          'CREATE OR REPLACE FUNCTION mv_drop_row() RETURNS trigger AS '
          r'$$ BEGIN DELETE FROM fixture_tenant_note WHERE id = NEW.id; '
          r'RETURN NULL; END $$ LANGUAGE plpgsql',
        );
        await datasource.executeCommand(
          'CREATE TRIGGER mv_drop AFTER INSERT ON fixture_tenant_note '
          'FOR EACH ROW EXECUTE FUNCTION mv_drop_row()',
        );
        try {
          await expectLater(
            tenancy.moveTenant('mvacme', type: 'default'),
            _throwsKey('tenancy.move.count_mismatch'),
          );
        } finally {
          await datasource.executeCommand(
            'DROP TRIGGER mv_drop ON fixture_tenant_note',
          );
          await datasource.executeCommand('DROP FUNCTION mv_drop_row()');
        }
        expect(tenancy.tenants['mvacme']!.type, 'standard');
        expect(tenancy.statusOf('mvacme'), TomTenantStatus.active);
        expect(await textsOf('mvacme'), ['a1', 'a2']);
      },
      skip:
          skipReason ??
          (TestDatabase.isPostgres
              ? null
              : 'a MariaDB trigger cannot change the table it fires on'),
    );

    test('MV-10: a backup the placement cannot take, or whose rows are not '
        "the tenant's, is refused and its restore rolled back", () async {
      final backup = await tenancy.exportTenant('mvacme');
      final table = backup.tables.single;
      TomTenantBackup with_(TomTenantTableBackup changed) => TomTenantBackup(
        tenant: backup.tenant,
        type: backup.type,
        isolation: backup.isolation,
        takenAt: backup.takenAt,
        tables: [changed],
      );
      final widened = TomTenantTableBackup(
        datasource: table.datasource,
        table: table.table,
        tenantColumn: table.tenantColumn,
        columns: [...table.columns, const TomTenantColumn('nope', 'text')],
        rows: [
          for (final row in table.rows) [...row, null],
        ],
      );
      await expectLater(
        tenancy.importTenant(with_(widened), replace: true),
        _throwsKey('tenancy.import.target_rejects'),
      );
      final at = table.columns.indexWhere(
        (c) => c.name.toLowerCase() == 'tenant_id',
      );
      final foreign = TomTenantTableBackup(
        datasource: table.datasource,
        table: table.table,
        tenantColumn: table.tenantColumn,
        columns: table.columns,
        rows: [
          for (final row in table.rows)
            [for (final (i, v) in row.indexed) i == at ? 'mvother' : v],
        ],
      );
      await expectLater(
        tenancy.importTenant(with_(foreign), replace: true),
        _throwsKey('tenancy.import.count_mismatch'),
      );
      expect(await textsOf('mvacme'), ['a1', 'a2'], reason: 'rolled back');
    }, skip: skipReason);
  }, skip: skipReason);
}
