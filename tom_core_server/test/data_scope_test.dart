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
    tableType: Object,
    table: TomDbTable(datasource: 'main', table: table, primaryKeyField: 'id'),
    declaredType: declaredType,
    declaredName: column,
    field: column,
    column: TomDbColumn(columnName: column),
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

    test(
      'owner resolver yields the principal id, group resolver the groups',
      () {
        final owner = TomDataScopeRegistry.resolverFor('owner')!;
        final group = TomDataScopeRegistry.resolverFor('group')!;
        expect(owner(_principal(7)), [7]);
        expect(group(_principal(7, groups: ['a', 'b'])), ['a', 'b']);
      },
    );

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
      expect(
        alice.predicate.generate(dialect),
        'tasks.owner_id IN (:__tomscope_0)',
      );
      expect(
        bob.predicate.generate(dialect),
        'tasks.owner_id IN (:__tomscope_0)',
      );

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

    test(
      'the write-authorization exception carries a client-safe contract',
      () {
        final e = TomDataScopeAuthorizationException(
          'data_scope.write.out_of_scope',
          'The requested row is not within your data scope.',
        );
        expect(e.key, 'data_scope.write.out_of_scope');
        expect(e.clientThrow, isTrue);
        expect(e, isA<TomServerException>());
      },
    );
  });

  // RCB8: the async, union/OR data scope. Where the synchronous resolver renders
  // one `<col> IN (…)` AND-predicate, an async resolver contributes an OR of one
  // `IN` list per id-set, so a row scope can be the *union* of independently
  // computed sets (owned ids ∪ shared-via-containment ids) resolved from another
  // database. Verified connection-free at the predicate level, exactly as the
  // synchronous scope is.
  group('async union scope registry (RCB8)', () {
    test(
      'registerAsync registers an async kind; isAsync/asyncResolverFor see it',
      () {
        expect(TomDataScopeRegistry.isAsync('visible'), isFalse);
        TomDataScopeRegistry.registerAsync(
          'visible',
          (p) async => [
            [1],
          ],
        );
        expect(TomDataScopeRegistry.isAsync('visible'), isTrue);
        expect(TomDataScopeRegistry.asyncResolverFor('visible'), isNotNull);
      },
    );

    test('reset clears async registrations too', () {
      TomDataScopeRegistry.registerAsync('visible', (p) async => const [[]]);
      TomDataScopeRegistry.reset();
      expect(TomDataScopeRegistry.isAsync('visible'), isFalse);
      expect(TomDataScopeRegistry.asyncResolverFor('visible'), isNull);
    });

    test('the sync and async seams are disjoint per kind', () {
      // A kind registered async is not visible to the sync resolver lookup, and
      // the built-in sync kinds are not async.
      expect(TomDataScopeRegistry.isAsync('owner'), isFalse);
      TomDataScopeRegistry.registerAsync(
        'visible',
        (p) async => const [
          [1],
        ],
      );
      expect(TomDataScopeRegistry.resolverFor('visible'), isNull);
      expect(TomDataScopeRegistry.isAsync('visible'), isTrue);
    });
  });

  group('async union predicate (TomDataScope.anyOf, RCB8)', () {
    final col = _column('projects', 'id', int);

    test('two id-sets render an OR of two IN lists, values bound (C-7)', () {
      final p = TomDataScope.anyOf(b, col, [
        [1, 2],
        [3],
      ]);
      final sql = p.predicate.generate(dialect);
      expect(sql, contains('projects.id IN (:__tomscope_0_0,:__tomscope_0_1)'));
      expect(sql, contains('projects.id IN (:__tomscope_1_0)'));
      expect(sql, contains(' OR '));
      // Grouped, so it survives AND-composition (see the leak-guard test below).
      expect(sql.trim(), startsWith('('));
      expect(p.parameters, {
        '__tomscope_0_0': 1,
        '__tomscope_0_1': 2,
        '__tomscope_1_0': 3,
      });
      // The shared id 3 is bound, never inlined (its placeholder index is 1_0).
      expect(sql, isNot(contains('3')));
    });

    test('a single id-set renders the plain IN list (no OR wrapper)', () {
      final p = TomDataScope.anyOf(b, col, [
        [1, 2],
      ]);
      expect(
        p.predicate.generate(dialect),
        'projects.id IN (:__tomscope_0_0,:__tomscope_0_1)',
      );
      expect(p.parameters, {'__tomscope_0_0': 1, '__tomscope_0_1': 2});
    });

    test('an empty group contributes a FALSE disjunct (owned ∪ ∅ = owned)', () {
      final p = TomDataScope.anyOf(b, col, [
        [1],
        <Object?>[],
      ]);
      final sql = p.predicate.generate(dialect);
      expect(sql, contains('projects.id IN (:__tomscope_0_0)'));
      expect(sql, contains(b.boolOp(false).generate(dialect)));
      expect(sql, contains(' OR '));
      expect(p.parameters, {'__tomscope_0_0': 1});
    });

    test('no id-sets deny every row with a FALSE predicate (deny-all)', () {
      final p = TomDataScope.anyOf(b, col, const []);
      expect(p.predicate.generate(dialect), b.boolOp(false).generate(dialect));
      expect(p.parameters, isEmpty);
    });

    test('the union is parenthesised so AND-composition cannot leak rows', () {
      // The repository ANDs the scope into the base WHERE: `base AND <scope>`.
      // An unparenthesised `a OR b` binds as `(base AND a) OR b`, letting the
      // second id-set escape the base filter (a row leak). Grouping makes it
      // `base AND (a OR b)` — a single intersecting AND-operand.
      final base = TomDataScope.inList(
        b,
        _column('projects', 'workspace_id', int),
        [9],
        prefix: '__idlist_',
      );
      final union = TomDataScope.anyOf(b, col, [
        [1],
        [3],
      ]);
      final combined = b
          .and([base.predicate, union.predicate])
          .generate(dialect);
      expect(combined, matches(RegExp(r'AND\s*\(.*OR.*\)')));
    });
  });

  group('async union build + opt-out (TomDataScope.buildAsync, RCB8)', () {
    final col = _column('projects', 'id', int);

    test(
      'resolves the registered async resolver into the union predicate',
      () async {
        TomDataScopeRegistry.registerAsync(
          'visible',
          (p) async => [
            [p!.user.id], // owned
            [3], // shared
          ],
        );
        const scope = TomDbScope(field: 'id', scope: 'visible');
        final p = await TomDataScope.buildAsync(b, scope, col, _principal(1));
        expect(p, isNotNull);
        expect(p!.parameters.values, containsAll(<Object?>[1, 3]));
        expect(p.predicate.generate(dialect), contains(' OR '));
      },
    );

    test('a resolver returning null opts out of scoping entirely', () async {
      TomDataScopeRegistry.registerAsync('visible', (p) async => null);
      const scope = TomDbScope(field: 'id', scope: 'visible');
      expect(
        await TomDataScope.buildAsync(b, scope, col, _principal(1)),
        isNull,
      );
    });

    test(
      'a resolver returning no id-sets denies every row (deny-all)',
      () async {
        TomDataScopeRegistry.registerAsync('visible', (p) async => const []);
        const scope = TomDbScope(field: 'id', scope: 'visible');
        final p = await TomDataScope.buildAsync(b, scope, col, _principal(1));
        expect(
          p!.predicate.generate(dialect),
          b.boolOp(false).generate(dialect),
        );
      },
    );

    test(
      'an unregistered async scope kind throws TomDataScopeException',
      () async {
        const scope = TomDbScope(field: 'id', scope: 'ghost-async');
        expect(
          () => TomDataScope.buildAsync(b, scope, col, _principal(1)),
          throwsA(
            isA<TomDataScopeException>().having(
              (e) => e.key,
              'key',
              'data_scope.build.unknown_async_scope',
            ),
          ),
        );
      },
    );
  });

  group('runUnscoped re-entrancy guard (RCB8)', () {
    test(
      'isBypassed is false outside, true inside a runUnscoped body',
      () async {
        expect(TomDataScope.isBypassed, isFalse);
        await TomDataScope.runUnscoped(() async {
          expect(TomDataScope.isBypassed, isTrue);
        });
        expect(TomDataScope.isBypassed, isFalse);
      },
    );

    test('a null-returning body still restores the unscoped state', () async {
      await TomDataScope.runUnscoped(() async => null);
      expect(TomDataScope.isBypassed, isFalse);
    });
  });

  // RCC5: a scope kind may admit a *narrower* value set for writes than for
  // reads. The `resource` scope needs this — a `read` grant admits a row to
  // queries but must reject any write to it — and the seam is generic, so an
  // application scope ("may read every tenant, may write only my own") gets the
  // same behaviour by registering a second resolver.
  group('write-scope resolvers (RCC5)', () {
    final col = _column('tasks', 'owner_id', int);

    test('without a write resolver the write set is the read set', () {
      TomDataScopeRegistry.register('tenant', (p) => const [1, 2]);
      expect(TomDataScopeRegistry.writeResolverFor('tenant'), isNull);
      const scope = TomDbScope(field: 'owner_id', scope: 'tenant');
      expect(TomDataScope.allowedValues(scope, _principal(1)), [1, 2]);
      expect(TomDataScope.allowedValues(scope, _principal(1), forWrite: true), [
        1,
        2,
      ]);
    });

    test('a registered write resolver narrows the writable set', () {
      TomDataScopeRegistry.register(
        'tenant',
        (p) => const [1, 2],
        write: (p) => const [1],
      );
      expect(TomDataScopeRegistry.writeResolverFor('tenant'), isNotNull);
      const scope = TomDbScope(field: 'owner_id', scope: 'tenant');
      expect(TomDataScope.allowedValues(scope, _principal(1)), [1, 2]);
      final writable = TomDataScope.allowedValues(
        scope,
        _principal(1),
        forWrite: true,
      );
      expect(writable, [1]);
      // The membership check the repository applies on insert: readable but not
      // writable is rejected.
      expect(TomDataScope.permits(writable, 1), isTrue);
      expect(TomDataScope.permits(writable, 2), isFalse);
    });

    test('build(forWrite:) binds the write set, not the read set', () {
      TomDataScopeRegistry.register(
        'tenant',
        (p) => const [1, 2],
        write: (p) => const [1],
      );
      const scope = TomDbScope(field: 'owner_id', scope: 'tenant');
      final read = TomDataScope.build(b, scope, col, _principal(1))!;
      final write = TomDataScope.build(
        b,
        scope,
        col,
        _principal(1),
        forWrite: true,
      )!;
      expect(read.parameters, {'__tomscope_0': 1, '__tomscope_1': 2});
      expect(write.parameters, {'__tomscope_0': 1});
    });

    test('registerAsync accepts a write resolver too', () async {
      TomDataScopeRegistry.registerAsync(
        'visible',
        (p) async => const [
          [1, 2],
        ],
        write: (p) async => const [
          [1],
        ],
      );
      expect(TomDataScopeRegistry.asyncWriteResolverFor('visible'), isNotNull);
      const scope = TomDbScope(field: 'id', scope: 'visible');
      final idCol = _column('projects', 'id', int);
      final read = (await TomDataScope.buildAsync(
        b,
        scope,
        idCol,
        _principal(1),
      ))!;
      final write = (await TomDataScope.buildAsync(
        b,
        scope,
        idCol,
        _principal(1),
        forWrite: true,
      ))!;
      expect(read.parameters.values, containsAll(<Object?>[1, 2]));
      expect(write.parameters.values, [1]);
    });

    test(
      'allowedValuesAsync flattens the groups for a membership check',
      () async {
        TomDataScopeRegistry.registerAsync(
          'visible',
          (p) async => const [
            [1],
            [2, 3],
          ],
        );
        const scope = TomDbScope(field: 'id', scope: 'visible');
        expect(await TomDataScope.allowedValuesAsync(scope, _principal(1)), [
          1,
          2,
          3,
        ]);
      },
    );

    test('reset clears write registrations with the rest', () {
      TomDataScopeRegistry.register(
        'tenant',
        (p) => const [1],
        write: (p) => const [],
      );
      TomDataScopeRegistry.registerAsync(
        'visible',
        (p) async => const [],
        write: (p) async => const [],
      );
      TomDataScopeRegistry.reset();
      expect(TomDataScopeRegistry.writeResolverFor('tenant'), isNull);
      expect(TomDataScopeRegistry.asyncWriteResolverFor('visible'), isNull);
    });
  });

  // RCC5: the `resource` kind is a *built-in* async scope, so `reset()` restores
  // it. Until a deployment installs its grant source it denies every row — an
  // unwired scope must not be an open door.
  group('the built-in resource scope kind (RCC5)', () {
    final col = _column('projects', 'resource_key', String);

    test('resource is a built-in async kind that survives reset', () {
      TomDataScopeRegistry.reset();
      expect(TomDataScopeRegistry.isAsync(TomDbScope.resourceScope), isTrue);
      expect(
        TomDataScopeRegistry.asyncResolverFor(TomDbScope.resourceScope),
        isNotNull,
      );
      expect(
        TomDataScopeRegistry.asyncWriteResolverFor(TomDbScope.resourceScope),
        isNotNull,
      );
    });

    test('denies every row while no grant source is installed', () async {
      TomDataScopeRegistry.reset();
      const scope = TomDbScope(
        field: 'resource_key',
        scope: TomDbScope.resourceScope,
      );
      final read = (await TomDataScope.buildAsync(
        b,
        scope,
        col,
        _principal(1),
      ))!;
      final write = (await TomDataScope.buildAsync(
        b,
        scope,
        col,
        _principal(1),
        forWrite: true,
      ))!;
      expect(
        read.predicate.generate(dialect),
        b.boolOp(false).generate(dialect),
      );
      expect(
        write.predicate.generate(dialect),
        b.boolOp(false).generate(dialect),
      );
    });
  });

  // RCC5: `@TomDbScope` is the *only* scope declaration — an entity that carries
  // a resource-key column is scoped automatically under the `resource` kind, and
  // an entity that must stay global says so with the same annotation.
  group('automatic resource scoping and opt-out (RCC5)', () {
    TomColumnInformation col(String table, String column) =>
        _column(table, column, String);

    test('a resource_key column implies the resource scope', () {
      final scope = TomAnnotationAnalyzer.autoScopeFor([
        col('projects', 'id'),
        col('projects', 'resource_key'),
        col('projects', 'title'),
      ]);
      expect(scope, isNotNull);
      expect(scope!.scope, TomDbScope.resourceScope);
      expect(scope.field, 'resource_key');
    });

    test('an entity without a resource-key column is not auto-scoped', () {
      expect(
        TomAnnotationAnalyzer.autoScopeFor([
          col('lookup', 'id'),
          col('lookup', 'label'),
        ]),
        isNull,
      );
    });

    test('an entity with no annotated columns is not auto-scoped', () {
      // `findDataScope` reaches here with `const []` for a type whose columns
      // the analyzer could not resolve, so the empty list is a real argument
      // and not a degenerate one. Nothing implies a scope, so there is none.
      expect(TomAnnotationAnalyzer.autoScopeFor(const []), isNull);
    });

    test('TomDbScope.unscoped is the explicit opt-out marker', () {
      const optOut = TomDbScope.unscoped();
      expect(optOut.scope, TomDbScope.noScope);
      expect(optOut.isOptOut, isTrue);
      expect(const TomDbScope(field: 'owner_id').isOptOut, isFalse);
    });
  });
}
