import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// C-3 (G-AUTHZ) row-level data-scope tests, verified connection-free.
///
/// The done-bar is "a query for principal P returns only P-scoped rows,
/// enforced in the repository". The repository needs a live data source, so the
/// enforcement is exercised here at the level the repository composes: the
/// [TomDataScope] predicate + its bound parameters. Two principals produce the
/// *same* parameterised SQL but *different* bound values — proving the scope is
/// resolved per principal and rides the prepared-statement protocol (no value
/// is concatenated into the SQL, C-7).

/// A trivial host for the [TomQueryBuilder] DSL the scope builder needs.
class _Builder with TomQueryBuilder {}

TomColumnInformation _column(String table, String column, Type declaredType) {
  return TomColumnInformation(
    TomDbTable(datasource: 'main', table: table, primaryKeyField: 'id'),
    Object,
    TomDbColumn(columnName: column),
    null,
    null,
    null,
    declaredType,
    column,
    column,
  );
}

TomPrincipal _principal(int id, {List<String> groups = const []}) {
  return TomPrincipal(
    user: TomUser(id: id, username: 'user$id'),
    aci: TomAccessControlInformation(groups: groups),
    authenticated: true,
  );
}

void main() {
  final b = _Builder();
  final dialect = MariadbSqlDialect();

  // Custom registrations must not leak between tests.
  tearDown(TomDataScopeRegistry.reset);

  group('TomDataScopeRegistry', () {
    test('provides the built-in owner and group resolvers', () {
      expect(TomDataScopeRegistry.resolverFor('owner'), isNotNull);
      expect(TomDataScopeRegistry.resolverFor('group'), isNotNull);
      expect(TomDataScopeRegistry.resolverFor('nope'), isNull);
    });

    test('owner resolver yields the principal id, group resolver the groups',
        () {
      final owner = TomDataScopeRegistry.resolverFor('owner')!;
      final group = TomDataScopeRegistry.resolverFor('group')!;
      expect(owner(_principal(7)), [7]);
      expect(group(_principal(7, groups: ['a', 'b'])), ['a', 'b']);
    });

    test('built-in resolvers deny a null (unauthenticated) principal', () {
      expect(TomDataScopeRegistry.resolverFor('owner')!(null), isEmpty);
      expect(TomDataScopeRegistry.resolverFor('group')!(null), isEmpty);
    });

    test('register adds a custom scope kind; reset restores the built-ins', () {
      TomDataScopeRegistry.register('tenant', (p) => const [42]);
      expect(TomDataScopeRegistry.resolverFor('tenant'), isNotNull);
      TomDataScopeRegistry.reset();
      expect(TomDataScopeRegistry.resolverFor('tenant'), isNull);
      expect(TomDataScopeRegistry.resolverFor('owner'), isNotNull);
    });
  });

  group('owner scope for two principals (C-3 done-bar)', () {
    const scope = TomDbScope(field: 'owner_id', scope: 'owner');
    final col = _column('tasks', 'owner_id', int);

    test('same parameterised SQL, different bound value per principal', () {
      final alice = TomDataScope.build(b, scope, col, _principal(1))!;
      final bob = TomDataScope.build(b, scope, col, _principal(2))!;

      // Identical predicate text — the value is a bound placeholder, not inline.
      expect(alice.predicate.generate(dialect), 'tasks.owner_id IN (:__tomscope_0)');
      expect(bob.predicate.generate(dialect), 'tasks.owner_id IN (:__tomscope_0)');

      // But the bound values differ: Alice sees id 1, Bob sees id 2.
      expect(alice.parameters, {'__tomscope_0': 1});
      expect(bob.parameters, {'__tomscope_0': 2});
    });

    test('the scope value never appears in the SQL text (C-7)', () {
      final alice = TomDataScope.build(b, scope, col, _principal(1))!;
      final sql = alice.predicate.generate(dialect);
      expect(sql, isNot(contains('1')));
      expect(alice.predicate.getParameters(dialect), ['__tomscope_0']);
    });
  });

  group('group scope binds one parameter per allowed value', () {
    const scope = TomDbScope(field: 'team', scope: 'group');
    final col = _column('projects', 'team', String);

    test('two groups render two bound placeholders', () {
      final p = TomDataScope.build(
        b,
        scope,
        col,
        _principal(1, groups: ['red', 'blue']),
      )!;
      expect(
        p.predicate.generate(dialect),
        'projects.team IN (:__tomscope_0,:__tomscope_1)',
      );
      expect(p.parameters, {'__tomscope_0': 'red', '__tomscope_1': 'blue'});
    });

    test('a principal with different groups binds different values', () {
      final p = TomDataScope.build(
        b,
        scope,
        col,
        _principal(2, groups: ['green']),
      )!;
      expect(p.predicate.generate(dialect), 'projects.team IN (:__tomscope_0)');
      expect(p.parameters, {'__tomscope_0': 'green'});
    });
  });

  group('empty and opt-out resolution', () {
    final col = _column('tasks', 'owner_id', int);

    test('no allowed values deny every row with a FALSE predicate', () {
      // A null principal resolves to empty allowed values under 'owner'.
      const scope = TomDbScope(field: 'owner_id', scope: 'owner');
      final p = TomDataScope.build(b, scope, col, null)!;
      expect(p.predicate.generate(dialect), b.boolOp(false).generate(dialect));
      expect(p.parameters, isEmpty);
    });

    test('a resolver returning null opts out of scoping entirely', () {
      TomDataScopeRegistry.register('unscoped', (p) => null);
      const scope = TomDbScope(field: 'owner_id', scope: 'unscoped');
      expect(TomDataScope.build(b, scope, col, _principal(1)), isNull);
    });

    test('an unregistered scope kind throws TomDataScopeException', () {
      const scope = TomDbScope(field: 'owner_id', scope: 'ghost');
      expect(
        () => TomDataScope.build(b, scope, col, _principal(1)),
        throwsA(
          isA<TomDataScopeException>().having(
            (e) => e.key,
            'key',
            'data_scope.build.unknown_scope',
          ),
        ),
      );
    });
  });

  // RCA5: the single per-element IN renderer every id-list repository method
  // (existsById / findAllById / deleteAllById) shares. N values render N bound
  // placeholders — never one `?` slot fed a whole Iterable, which the MySQL
  // driver does not expand.
  group('TomDataScope.inList (RCA5 IN-list renderer)', () {
    test('N values render N bound placeholders in one IN list', () {
      final col = _column('tasks', 'id', int);
      final p = TomDataScope.inList(b, col, [10, 20, 30]);
      expect(
        p.predicate.generate(dialect),
        'tasks.id IN (:__tomscope_0,:__tomscope_1,:__tomscope_2)',
      );
      expect(p.parameters, {
        '__tomscope_0': 10,
        '__tomscope_1': 20,
        '__tomscope_2': 30,
      });
    });

    test('the prefix namespaces the parameter names (no scope collision)', () {
      final col = _column('tasks', 'id', int);
      final p = TomDataScope.inList(b, col, [1, 2], prefix: '__idlist_');
      expect(
        p.predicate.generate(dialect),
        'tasks.id IN (:__idlist_0,:__idlist_1)',
      );
      expect(p.parameters, {'__idlist_0': 1, '__idlist_1': 2});
    });

    test('a string column dispatches to string placeholders', () {
      final col = _column('projects', 'code', String);
      final p = TomDataScope.inList(b, col, ['a', 'b'], prefix: '__idlist_');
      expect(
        p.predicate.generate(dialect),
        'projects.code IN (:__idlist_0,:__idlist_1)',
      );
      expect(p.parameters, {'__idlist_0': 'a', '__idlist_1': 'b'});
    });

    test('an empty value list denies every row with a FALSE predicate', () {
      final col = _column('tasks', 'id', int);
      final p = TomDataScope.inList(b, col, const <Object?>[]);
      expect(p.predicate.generate(dialect), b.boolOp(false).generate(dialect));
      expect(p.parameters, isEmpty);
    });

    test('the value never appears in the SQL text (C-7)', () {
      final col = _column('tasks', 'id', int);
      final p = TomDataScope.inList(b, col, [42], prefix: '__idlist_');
      final sql = p.predicate.generate(dialect);
      expect(sql, isNot(contains('42')));
      expect(p.predicate.getParameters(dialect), ['__idlist_0']);
    });
  });

  group('TomDbScope annotation defaults', () {
    test('scope defaults to owner', () {
      const scope = TomDbScope(field: 'owner_id');
      expect(scope.scope, 'owner');
      expect(scope.field, 'owner_id');
    });
  });

  // C-3 write/delete enforcement (RCA4). The repository rejects a write that
  // targets an out-of-scope row: an insert whose scope-field value the principal
  // is not allowed, and an update/delete of a row the principal could not read.
  // The reject *decision* is pure — `allowedValues` (per principal) composed
  // with `permits` (membership) — and is verified connection-free here, exactly
  // as the read-side predicate is; the live-DB round-trip (a second user's write
  // to another's row is rejected) is folded into the advanced-sample integration
  // once the sample adopts `@TomDbScope` (RCA13).
  group('write-scope membership (C-3 write done-bar)', () {
    const scope = TomDbScope(field: 'owner_id', scope: 'owner');

    test('a null allowed set opts out — every value is writable', () {
      // Mirrors a resolver returning null (no scoping): the write is unrestricted.
      expect(TomDataScope.permits(null, 999), isTrue);
    });

    test('an empty allowed set denies every write (deny-all)', () {
      expect(TomDataScope.permits(const <Object?>[], 1), isFalse);
    });

    test('the value must be one of the allowed scope values', () {
      expect(TomDataScope.permits(const [1, 2], 2), isTrue);
      expect(TomDataScope.permits(const [1, 2], 3), isFalse);
    });

    test('allowedValues resolves the owner scope to the principal id', () {
      expect(TomDataScope.allowedValues(scope, _principal(7)), [7]);
    });

    test('allowedValues denies a null (unauthenticated) principal', () {
      // Empty, not null: an unauthenticated caller writes nothing (secure
      // default), whereas a genuine opt-out returns null.
      expect(TomDataScope.allowedValues(scope, null), isEmpty);
    });

    test('a principal may write its own row but not another principal\'s', () {
      final aliceAllowed = TomDataScope.allowedValues(scope, _principal(1));
      expect(TomDataScope.permits(aliceAllowed, 1), isTrue); // Alice's own row
      expect(TomDataScope.permits(aliceAllowed, 2), isFalse); // Bob's row
    });

    test('allowedValues throws on an unregistered scope kind', () {
      const ghost = TomDbScope(field: 'owner_id', scope: 'ghost');
      expect(
        () => TomDataScope.allowedValues(ghost, _principal(1)),
        throwsA(
          isA<TomDataScopeException>().having(
            (e) => e.key,
            'key',
            'data_scope.build.unknown_scope',
          ),
        ),
      );
    });

    test('the write-authorization exception carries a client-safe contract', () {
      final e = TomDataScopeAuthorizationException(
        'data_scope.write.out_of_scope',
        'The requested row is not within your data scope.',
      );
      expect(e.key, 'data_scope.write.out_of_scope');
      expect(e.clientThrow, isTrue);
      expect(e, isA<TomServerException>());
    });
  });
}
