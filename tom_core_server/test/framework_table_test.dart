/// Unit tests for the framework-table descriptors themselves.
///
/// `framework_schema_test.dart` covers what the descriptors are *for*: that the
/// seven framework tables agree with the shipped migration chain, with the row
/// types the mapper materialises, and with the statements the stores issue. All
/// three read a descriptor and compare it with something else, so all three
/// stay green when the descriptor's own rendering is wrong in the same way on
/// both sides — and none of them constructs one to see what it does.
///
/// This file does. The DDL a store issues on first use, the padded column
/// lines, the index names that keep two stores over differently-named tables
/// from colliding, the two `ArgumentError` guards that catch a projection
/// outliving its column, and the `INSERT` shape are each a decision made here
/// and assertable here, without a database.
///
/// The fixture table is deliberately small and made up. A real descriptor would
/// tie these assertions to a table's current shape, so widening `actor` to
/// `VARCHAR(191)` would fail a test about padding — which is a test that reports
/// the wrong thing.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A table with one column of every shape the renderer distinguishes: an
/// auto-increment key, a plain `NOT NULL`, a nullable one, and one with a
/// `DEFAULT`.
TomFrameworkTable thingTable({String name = 'thing'}) => TomFrameworkTable(
  kind: TomTableKind.system,
  name: name,
  origin: 'thingTable',
  columns: const [
    TomFrameworkColumn('id', 'BIGINT', autoIncrement: true),
    TomFrameworkColumn('name', 'VARCHAR(191)'),
    TomFrameworkColumn('note', 'LONGTEXT', nullable: true),
    TomFrameworkColumn('created_at', 'DATETIME(6)', defaultValue: 'NOW(6)'),
  ],
  primaryKey: const ['id'],
  keys: [
    TomFrameworkKey.unique('name', const ['name']),
    const TomFrameworkKey('created', ['created_at']),
  ],
);

void main() {
  group('a column renders its own line', () {
    test('the three fixed fields are padded to the widths given', () {
      // The padding is the whole reason a width is passed in rather than
      // measured per column: the point is that a reader can scan the types in a
      // column, which only holds if every line uses the table's widths.
      const column = TomFrameworkColumn('id', 'BIGINT');
      expect(column.ddl(10, 12), 'id         BIGINT       NOT NULL');
      expect(column.ddl(2, 6), 'id BIGINT NOT NULL');
    });

    test('a name or type longer than its width is not truncated', () {
      // `padRight` leaves a longer value alone, so a width that is too small
      // misaligns the block rather than losing a character of the identifier.
      const column = TomFrameworkColumn('created_at', 'DATETIME(6)');
      expect(column.ddl(2, 2), 'created_at DATETIME(6) NOT NULL');
    });

    test('nullable renders NULL rather than omitting the clause', () {
      // MariaDB defaults a column to NULL, so omitting the clause would be
      // equivalent — but then the DDL reader the convergence check replays it
      // through would have to infer nullability, and the two sides would be
      // agreeing about something neither of them says.
      const column = TomFrameworkColumn('note', 'LONGTEXT', nullable: true);
      expect(column.ddl(4, 8), 'note LONGTEXT NULL');
    });

    test('a default follows the nullability and precedes auto-increment', () {
      // The order is SQL's, and both clauses on one column is a shape MariaDB
      // accepts, so the renderer has to get their order right rather than
      // merely emit both.
      const withDefault = TomFrameworkColumn(
        'created_at',
        'DATETIME(6)',
        defaultValue: 'NOW(6)',
      );
      expect(
        withDefault.ddl(10, 11),
        'created_at DATETIME(6) NOT NULL DEFAULT NOW(6)',
      );

      const both = TomFrameworkColumn(
        'id',
        'BIGINT',
        defaultValue: '0',
        autoIncrement: true,
      );
      expect(both.ddl(2, 6), 'id BIGINT NOT NULL DEFAULT 0 AUTO_INCREMENT');
    });

    test('toString names the column and its type', () {
      expect(
        const TomFrameworkColumn('name', 'VARCHAR(191)').toString(),
        'name VARCHAR(191)',
      );
    });
  });

  group('a column reports the character capacity its type declares', () {
    // A writer that trims a value to fit and a reader that has to trim a search
    // term the same way both read this number, so what matters is that a type
    // carrying no character capacity answers `null` rather than a precision
    // that would silently become a length.
    test('CHAR and VARCHAR answer with their length', () {
      expect(const TomFrameworkColumn('a', 'VARCHAR(191)').maxCharacters, 191);
      expect(const TomFrameworkColumn('a', 'CHAR(64)').maxCharacters, 64);
    });

    test('spelling and spacing do not change the answer', () {
      expect(const TomFrameworkColumn('a', 'varchar(40)').maxCharacters, 40);
      expect(const TomFrameworkColumn('a', 'VARCHAR ( 40 )').maxCharacters, 40);
    });

    test('a type without a character capacity answers null', () {
      for (final type in const [
        'BIGINT',
        'LONGTEXT',
        'DATETIME(6)',
        'INT(11)',
        'DECIMAL(10,2)',
        'VARBINARY(16)',
      ]) {
        expect(
          TomFrameworkColumn('a', type).maxCharacters,
          isNull,
          reason: '$type declares no character capacity',
        );
      }
    });
  });

  group('a key is named after the table it is on', () {
    test('the prefix says which kind of key it is', () {
      expect(
        const TomFrameworkKey('created', ['created_at']).nameOn('thing'),
        'ix_thing_created',
      );
      expect(
        TomFrameworkKey.unique('name', const ['name']).nameOn('thing'),
        'uq_thing_name',
      );
    });

    test('two tables with the same suffix get different key names', () {
      // The reason the name is built rather than given: a table name is a
      // per-instance argument, so two stores over differently-named tables in
      // one schema would collide on a literal index name and the second
      // `CREATE TABLE` would fail — at start-up, in the deployment least able
      // to repair it.
      const key = TomFrameworkKey('created', ['created_at']);
      expect(key.nameOn('job_run'), isNot(key.nameOn('audit_trail')));
    });

    test('the line names every column in key order', () {
      expect(
        const TomFrameworkKey('lookup', ['target', 'target_key']).ddl('trail'),
        'KEY ix_trail_lookup (target, target_key)',
      );
      expect(
        TomFrameworkKey.unique('pair', const ['blob_id', 'seq']).ddl('chunk'),
        'UNIQUE KEY uq_chunk_pair (blob_id, seq)',
      );
    });
  });

  group('a table refuses a declaration it cannot render', () {
    test('a primary key naming no column is refused on construction', () {
      // On construction because a descriptor is built once at start-up: the
      // alternative is a `CREATE TABLE` that fails against a live server, which
      // is the class of failure this type exists to remove.
      expect(
        () => TomFrameworkTable(
          kind: TomTableKind.system,
          name: 'thing',
          origin: 'thingTable',
          columns: const [TomFrameworkColumn('id', 'BIGINT')],
          primaryKey: const ['identifier'],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('identifier'), contains('thing')),
          ),
        ),
      );
    });

    test('an index naming no column is refused too', () {
      expect(
        () => TomFrameworkTable(
          kind: TomTableKind.system,
          name: 'thing',
          origin: 'thingTable',
          columns: const [TomFrameworkColumn('id', 'BIGINT')],
          keys: const [
            TomFrameworkKey('lookup', ['id', 'created_at']),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('created_at'),
          ),
        ),
      );
    });

    test('a key may spell its column in any case', () {
      // SQL identifiers are matched case-insensitively throughout this type, so
      // a descriptor that spells a key's column differently from the column is
      // not a typo the guard should reject.
      expect(
        () => TomFrameworkTable(
          kind: TomTableKind.system,
          name: 'thing',
          origin: 'thingTable',
          columns: const [TomFrameworkColumn('id', 'BIGINT')],
          primaryKey: const ['ID'],
        ),
        returnsNormally,
      );
    });

    test('a table with no columns is refused', () {
      // `createTableDdl` measures its padding by reducing over the columns, so
      // an empty descriptor fails there with "No element" — a message about the
      // renderer, arriving on the first `CREATE TABLE`, about a table that
      // could not have been valid SQL anyway.
      expect(
        () => TomFrameworkTable(
          kind: TomTableKind.system,
          name: 'thing',
          origin: 'thingTable',
          columns: const [],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('thing'), contains('thingTable')),
          ),
        ),
      );
    });
  });

  group('a table answers about its columns', () {
    final table = thingTable();

    test('the names are in declaration order', () {
      expect(table.columnNames, ['id', 'name', 'note', 'created_at']);
      expect(table.columnList, 'id, name, note, created_at');
    });

    test(
      'lookup is case-insensitive, and a miss is null rather than a throw',
      () {
        expect(table.has('NAME'), isTrue);
        expect(table.has('nickname'), isFalse);
        expect(table.column('Created_At')?.type, 'DATETIME(6)');
        expect(table.column('nickname'), isNull);
      },
    );

    test('columnsOf keeps the order it was given, not declaration order', () {
      // The caller's order is the projection's order, and a `SELECT` is read
      // back positionally by the row mapper, so re-sorting here would silently
      // permute every read.
      expect(table.columnsOf(const ['note', 'id']), 'note, id');
    });

    test('columnsOf names every unknown column and what the table has', () {
      // Both halves are the diagnosis: the names are what to fix, the column
      // list is what to fix them to.
      expect(
        () => table.columnsOf(const ['id', 'nickname', 'age']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('nickname'),
              contains('age'),
              contains('id, name, note, created_at'),
            ),
          ),
        ),
      );
    });

    test('toString names the table', () {
      expect(table.toString(), 'TomFrameworkTable(thing)');
    });
  });

  group('a table renders a row-writing statement', () {
    final table = thingTable();

    test('a conflict policy is rendered in each database\'s words', () {
      // The descriptor names the policy; the dialect names the statements.
      final maria = TomStandardSqlDialect();
      final postgres = PostgresSqlDialect();
      const values = {'id': ':id', 'name': ':name'};
      const insert = 'INSERT INTO thing (id, name) VALUES (:id, :name)';
      expect(table.insertRow(maria, values), insert);
      expect(table.insertRow(postgres, values), insert);
      expect(
        table.insertRow(maria, values, ignoreConflict: true),
        'INSERT IGNORE INTO thing (id, name) VALUES (:id, :name)',
      );
      expect(
        table.insertRow(postgres, values, ignoreConflict: true),
        '$insert ON CONFLICT DO NOTHING',
      );
      // A replace supersedes the row with the primary key and any colliding
      // on another unique key — `thing` keys `name` uniquely. One `REPLACE` on
      // MariaDB; on PostgreSQL the superseded rows are deleted first, because
      // a key is only free to a later statement.
      expect(table.replaceStatements(maria, values), [
        'REPLACE INTO thing (id, name) VALUES (:id, :name)',
      ]);
      expect(table.replaceStatements(postgres, values), [
        'DELETE FROM thing WHERE (id = :id) OR (name = :name)',
        '$insert ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name',
      ]);
    });

    test('columns and values stay paired in the order given', () {
      // Keyed by name rather than by position precisely so that inserting a
      // column in the descriptor cannot shift every value one place along —
      // a failure that would type-check.
      expect(
        table.insertRow(TomStandardSqlDialect(), const {
          'name': ':name',
          'note': ':note',
          'created_at': 'NOW(6)',
        }),
        'INSERT INTO thing (name, note, created_at) '
        'VALUES (:name, :note, NOW(6))',
      );
    });

    test('a value may be a literal as well as a bind', () {
      // The lease lock's first acquisition writes `token` and `version` as
      // literals in the same statement it binds the rest of.
      expect(
        table.insertRow(TomStandardSqlDialect(), const {
          'id': '1',
          'name': ':name',
        }),
        'INSERT INTO thing (id, name) VALUES (1, :name)',
      );
    });

    test('a value for a column the table does not have is refused', () {
      expect(
        () => table.insertRow(TomStandardSqlDialect(), const {
          'name': ':name',
          'age': ':age',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('age'), contains('id, name, note, created_at')),
          ),
        ),
      );
    });
  });

  group('a table renders its own CREATE TABLE', () {
    test('every part is there, in order, and the block is aligned', () {
      expect(thingTable().createTableDdl, '''
CREATE TABLE IF NOT EXISTS thing (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  name       VARCHAR(191) NOT NULL,
  note       LONGTEXT     NULL,
  created_at DATETIME(6)  NOT NULL DEFAULT NOW(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_thing_name (name),
  KEY ix_thing_created (created_at)
)''');
    });

    test('IF NOT EXISTS, because every store issues it on first use', () {
      // Two processes starting together both run it; the second must not fail
      // on a table the first created.
      expect(thingTable().createTableDdl, startsWith('CREATE TABLE IF NOT '));
    });

    test('the key names follow the table name', () {
      // The same descriptor under a second name renders a second set of index
      // names, which is what lets two stores share a schema.
      final ddl = thingTable(name: 'other_thing').createTableDdl;
      expect(ddl, contains('UNIQUE KEY uq_other_thing_name (name)'));
      expect(ddl, contains('KEY ix_other_thing_created (created_at)'));
      expect(ddl, isNot(contains('uq_thing_name')));
    });

    test('a table with neither primary key nor index renders neither line', () {
      expect(
        TomFrameworkTable(
          kind: TomTableKind.system,
          name: 'plain',
          origin: 'plainTable',
          columns: const [TomFrameworkColumn('value', 'BIGINT')],
        ).createTableDdl,
        'CREATE TABLE IF NOT EXISTS plain (\n  value BIGINT NOT NULL\n)',
      );
    });
  });

  group('the statement audit reports what is not a column', () {
    final tables = [thingTable()];

    test('a known column, an unknown one and a bind', () {
      // The three shapes the audit has to tell apart in one statement: a column
      // that exists is silent, one that does not is reported, and a `:bind` is
      // a value named after a Dart field rather than an identifier of the
      // schema.
      expect(
        unknownFrameworkColumns(
          'UPDATE thing SET note = :note WHERE nickname = :nickname',
          tables,
        ),
        ['nickname'],
      );
    });

    test('a statement naming only real columns is silent', () {
      expect(
        unknownFrameworkColumns(
          'SELECT id, name FROM thing WHERE created_at < :cutoff ORDER BY id',
          tables,
        ),
        isEmpty,
      );
    });

    test('string literals and numbers are values, not identifiers', () {
      // A literal can contain anything, including a word that looks like a
      // column, so it is removed before the scan rather than matched against
      // the vocabulary.
      expect(
        unknownFrameworkColumns(
          "UPDATE thing SET name = 'nickname' WHERE id = 42",
          tables,
        ),
        isEmpty,
      );
    });

    test('an index name is admitted, so DDL can be audited too', () {
      // Index names come from the same descriptor as the columns, so admitting
      // them widens nothing that is trusted — and it is what lets the audit be
      // pointed at a `CREATE TABLE` as well as at the statements that use it.
      expect(
        unknownFrameworkColumns(thingTable().createTableDdl, tables),
        isEmpty,
      );
    });

    test(
      'an unknown identifier is reported once, however often it appears',
      () {
        expect(
          unknownFrameworkColumns(
            'UPDATE thing SET nickname = :a WHERE nickname = :b OR NICKNAME IS '
            'NULL',
            tables,
          ),
          ['nickname'],
        );
      },
    );

    test('columns of any of the tables given are known', () {
      // The audit takes the whole set a store owns, because one statement may
      // join two of them.
      final other = TomFrameworkTable(
        kind: TomTableKind.system,
        name: 'thing_chunk',
        origin: 'thingChunkTable',
        columns: const [TomFrameworkColumn('seq', 'BIGINT')],
      );
      const sql =
          'SELECT seq FROM thing_chunk JOIN thing ON thing.id = thing_chunk.seq';
      expect(unknownFrameworkColumns(sql, tables), ['seq', 'thing_chunk']);
      expect(unknownFrameworkColumns(sql, [...tables, other]), isEmpty);
    });
  });

  group('a table is placed by its kind', () {
    final base = TomDataSourceInfo('main', const {});
    final acme = TomDataSourceInfo('main@acme', const {});
    final retail = TomDataSourceInfo('main@type.retail', const {});
    TomFrameworkTable table(TomTableKind kind) => TomFrameworkTable(
      kind: kind,
      name: 'thing',
      origin: 'thingTable',
      columns: const [TomFrameworkColumn('id', 'BIGINT')],
    );

    setUp(() {
      for (final info in [base, acme, retail]) {
        TomDataSourceInfo.datasources[info.name] = info;
      }
      // Routes `main` to acme's pool inside acme, as a tenancy would.
      TomDataSourceInfo.router = (info) =>
          TomTenantContext.currentId == 'acme' && info.name == 'main'
          ? acme
          : info;
      addTearDown(() {
        TomDataSourceInfo.router = null;
        for (final info in [base, acme, retail]) {
          TomDataSourceInfo.datasources.remove(info.name);
        }
      });
    });

    test(
      "a tenant's pool and a type's pool answer their system data source",
      () {
        expect(TomFrameworkTable.systemInfoOf(acme), same(base));
        expect(TomFrameworkTable.systemInfoOf(retail), same(base));
        expect(TomFrameworkTable.systemInfoOf(base), same(base));
      },
    );

    test('a pool whose base is not registered answers itself', () {
      final orphan = TomDataSourceInfo('gone@acme', const {});
      expect(TomFrameworkTable.systemInfoOf(orphan), same(orphan));
    });

    test('a system table is placed in the system data source, also inside a '
        'tenant and whichever pool it holds', () {
      final system = table(TomTableKind.system);
      TomTenantContext.run('acme', () {
        expect(system.placedInfo(base), same(base));
        expect(system.placedInfo(acme), same(base));
      });
      expect(system.placedInfo(retail), same(base));
    });

    test(
      "a tenant table is placed where the tenant in context's data lives",
      () {
        final tenant = table(TomTableKind.tenant);
        expect(tenant.placedInfo(base), same(base));
        TomTenantContext.run('acme', () {
          expect(tenant.placedInfo(base), same(acme));
          // A store holding acme's pool still routes from the system base.
          expect(tenant.placedInfo(acme), same(acme));
        });
      },
    );

    test('a data source registered under no name is used as it is', () {
      final unregistered = MariaDbDatasource();
      for (final kind in TomTableKind.values) {
        TomTenantContext.run('acme', () {
          expect(table(kind).placed(unregistered), same(unregistered));
        });
      }
      expect(TomFrameworkTable.systemOf(unregistered), same(unregistered));
    });

    test('every framework table declares its kind as the classification '
        'expects', () {
      const tenantTables = {
        'tom_message_inbox',
        'tom_idempotency_key',
        'tom_saga',
        'tom_encryption_key',
        'tom_subject_key',
        'tom_scim_resource',
        'tom_sync_change',
        'tom_sync_sequence',
      };
      for (final t in frameworkOwnedTables()) {
        expect(
          t.kind,
          tenantTables.contains(t.name)
              ? TomTableKind.tenant
              : TomTableKind.system,
          reason: t.name,
        );
      }
      expect(frameworkTenantTables().map((t) => t.name).toSet(), tenantTables);
      expect(
        frameworkSystemTables().length + frameworkTenantTables().length,
        frameworkOwnedTables().length,
      );
    });
  });
}
