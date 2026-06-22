/// Tests for the server-side four-state authorization model.
///
/// The kernel models per-resource-key authorization as a flat granted/denied
/// list; this suite pins the server extension that grades each key with a full
/// [TomAuthState] and round-trips it through a stored string value:
///   * [TomAuthStateCodec] — the column codec and the legacy-binary bridge.
///   * [TomResourceGrant] — the persistable grant row + its canonical DDL.
///   * [TomGradedAccessControlInformation] — the graded resolver, including the
///     binary fallback that keeps the model backward compatible.
///   * the reference db_migration SQL file shipped under `example/`.
///
/// Everything here is connection-free: no live MariaDB is touched, matching the
/// conventions of `authorization_test.dart` and `db_migration_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('TomAuthStateCodec', () {
    test('round-trips every state through toStored/fromStored', () {
      for (final state in TomAuthState.values) {
        final stored = TomAuthStateCodec.toStored(state);
        expect(stored, state.name);
        expect(TomAuthStateCodec.fromStored(stored), state,
            reason: '$state must survive a stored round-trip');
      }
    });

    test('fromStored degrades a null value to the closed default (none)', () {
      expect(TomAuthStateCodec.fromStored(null), TomAuthState.none);
    });

    test('fromStored degrades an unknown token to the closed default', () {
      expect(TomAuthStateCodec.fromStored('bogus'), TomAuthState.none);
    });

    test('fromStored honours an explicit orElse fallback', () {
      expect(
        TomAuthStateCodec.fromStored(null, orElse: TomAuthState.read),
        TomAuthState.read,
      );
    });

    test('fromLegacyGranted bridges the binary model', () {
      expect(TomAuthStateCodec.fromLegacyGranted(true), TomAuthState.full);
      expect(TomAuthStateCodec.fromLegacyGranted(false), TomAuthState.none);
    });

    test('db column converters round-trip a state', () {
      for (final state in TomAuthState.values) {
        final column = TomAuthStateCodec.toDbColumn(state);
        expect(column.get(), state.name);
        expect(TomAuthStateCodec.fromDbColumn(column), state);
      }
    });

    test('converters survive a generics-erased TomDbColumn read', () {
      // The MariaDB datasource reads fromDbConverter/toDbConverter off a raw
      // (generics-erased) TomDbColumn, which statically types them as
      // `dynamic Function(TomDbType<dynamic>)?` / `TomDbType<dynamic> Function(
      // dynamic)?`. A converter whose parameter is narrowed (e.g. TomDbString /
      // TomAuthState) fails the runtime function-subtype check on that read —
      // this reproduces the erased read without a live database.
      final TomDbColumn erased = TomDbColumn<TomAuthState, TomDbString>(
        columnName: 'access_level',
        fromDbConverter: TomAuthStateCodec.fromDbColumn,
        toDbConverter: TomAuthStateCodec.toDbColumn,
      );
      final read = erased.fromDbConverter; // must not throw a subtype error
      final write = erased.toDbConverter;
      expect(read, isNotNull);
      expect(write, isNotNull);
      expect(read!(TomDbString.of('full')), TomAuthState.full);
      expect((write!(TomAuthState.read) as TomDbString).get(), 'read');
    });
  });

  group('TomResourceGrant', () {
    test('defaults to an unpersisted, denied grant', () {
      final grant = TomResourceGrant(roleName: 'admin', resourceKey: 'orders');
      expect(grant.id, -1);
      expect(grant.roleName, 'admin');
      expect(grant.resourceKey, 'orders');
      expect(grant.accessLevel, TomAuthState.none);
    });

    test('is no-arg constructible (the repository load contract)', () {
      // TomSqlDatasourceRepository loads a row by instantiating a blank grant
      // (newInstance('', [])) then setting each @TomDbColumn field. A `required`
      // constructor parameter would make that throw, so the entity its own
      // persistence layer reads back must construct with no arguments.
      final blank = TomResourceGrant();
      expect(blank.id, -1);
      expect(blank.roleName, '');
      expect(blank.resourceKey, '');
      expect(blank.accessLevel, TomAuthState.none);
    });

    test('carries an explicit grade', () {
      final grant = TomResourceGrant(
        roleName: 'editor',
        resourceKey: 'invoice',
        accessLevel: TomAuthState.full,
      );
      expect(grant.accessLevel, TomAuthState.full);
    });

    test('createTableSql constrains access_level to the four state tokens', () {
      final sql = TomResourceGrant.createTableSql;
      expect(sql, contains('tom_resource_grant'));
      for (final state in TomAuthState.values) {
        expect(sql, contains("'${state.name}'"),
            reason: 'DDL enum must list ${state.name}');
      }
      expect(sql, contains('UNIQUE KEY'),
          reason: 'a (role, key) pair must be unique');
    });

    test('toString summarises the grade', () {
      final grant = TomResourceGrant(
        roleName: 'admin',
        resourceKey: 'orders',
        accessLevel: TomAuthState.read,
      );
      expect(grant.toString(), contains('orders -> read'));
    });
  });

  group('TomGradedAccessControlInformation', () {
    test('resolves an explicit grade ahead of any fallback', () {
      final aci = TomGradedAccessControlInformation(
        grades: {'orders': TomAuthState.read},
      );
      expect(aci.resolveState('orders'), TomAuthState.read);
    });

    test('falls back to the binary list (present → full, absent → none)', () {
      final aci = TomGradedAccessControlInformation(
        binary: TomAccessControlInformation(resourceKeys: ['orders']),
      );
      expect(aci.resolveState('orders'), TomAuthState.full,
          reason: 'a key present in the binary list resolves to full');
      expect(aci.resolveState('invoice'), TomAuthState.none,
          reason: 'an absent key resolves to none (closed default)');
    });

    test('fromGrants folds rows, widening on a duplicate key', () {
      final aci = TomGradedAccessControlInformation.fromGrants([
        TomResourceGrant(
          roleName: 'viewer',
          resourceKey: 'orders',
          accessLevel: TomAuthState.read,
        ),
        TomResourceGrant(
          roleName: 'editor',
          resourceKey: 'orders',
          accessLevel: TomAuthState.full,
        ),
      ]);
      expect(aci.resolveState('orders'), TomAuthState.full,
          reason: 'the most permissive grade wins across roles');
    });

    test('fromGrants keeps a binary fallback for ungranted keys', () {
      final aci = TomGradedAccessControlInformation.fromGrants(
        [
          TomResourceGrant(
            roleName: 'viewer',
            resourceKey: 'orders',
            accessLevel: TomAuthState.read,
          ),
        ],
        binary: TomAccessControlInformation(resourceKeys: ['invoice']),
      );
      expect(aci.resolveState('orders'), TomAuthState.read);
      expect(aci.resolveState('invoice'), TomAuthState.full);
      expect(aci.resolveState('shipping'), TomAuthState.none);
    });

    test('exposes an unmodifiable view of the grades', () {
      final aci = TomGradedAccessControlInformation(
        grades: {'orders': TomAuthState.read},
      );
      expect(() => aci.grades['orders'] = TomAuthState.full,
          throwsUnsupportedError);
    });

    test('toGrants materialises grades back into persistable rows', () {
      final aci = TomGradedAccessControlInformation(
        grades: {
          'orders': TomAuthState.full,
          'invoice': TomAuthState.read,
        },
      );
      final grants = aci.toGrants('editor');
      expect(grants, hasLength(2));
      expect(grants.every((g) => g.roleName == 'editor'), isTrue);
      final byKey = {for (final g in grants) g.resourceKey: g.accessLevel};
      expect(byKey['orders'], TomAuthState.full);
      expect(byKey['invoice'], TomAuthState.read);
    });

    test('fromGrants → toGrants is a stable round-trip', () {
      final original = [
        TomResourceGrant(
          roleName: 'editor',
          resourceKey: 'orders',
          accessLevel: TomAuthState.full,
        ),
        TomResourceGrant(
          roleName: 'editor',
          resourceKey: 'invoice',
          accessLevel: TomAuthState.disabled,
        ),
      ];
      final restored =
          TomGradedAccessControlInformation.fromGrants(original).toGrants('editor');
      final restoredByKey = {
        for (final g in restored) g.resourceKey: g.accessLevel,
      };
      expect(restoredByKey['orders'], TomAuthState.full);
      expect(restoredByKey['invoice'], TomAuthState.disabled);
    });
  });

  group('reference db_migration SQL', () {
    final file = File(
      'example/authorization/migrations/main/tomcore/'
      '[1]-create_tom_resource_grants.sql',
    );

    test('ships under the db_migration directory convention', () {
      expect(file.existsSync(), isTrue,
          reason: 'the reference migration must exist under example/');
    });

    test('filename matches the migration discovery regex', () {
      // Mirrors db_migration.dart: RegExp(r'\[([0-9]+)]-([a-zA-Z_]+)').
      final name = file.uri.pathSegments.last.replaceAll('.sql', '');
      final match = RegExp(r'\[([0-9]+)]-([a-zA-Z_]+)').firstMatch(name);
      expect(match, isNotNull,
          reason: 'the orchestrator must be able to parse the version + name');
      expect(match!.group(1), '1');
      expect(match.group(2), 'create_tom_resource_grants');
    });

    test('content matches the entity DDL and lists all four state tokens', () {
      final sql = file.readAsStringSync();
      expect(sql, contains('CREATE TABLE'));
      expect(sql, contains('tom_resource_grant'));
      for (final state in TomAuthState.values) {
        expect(sql, contains("'${state.name}'"));
      }
    });
  });
}
