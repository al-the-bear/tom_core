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

  group('TomDbScope annotation defaults', () {
    test('scope defaults to owner', () {
      const scope = TomDbScope(field: 'owner_id');
      expect(scope.scope, 'owner');
      expect(scope.field, 'owner_id');
    });
  });
}
