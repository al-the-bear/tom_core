import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// RCC5 — the grant-driven `resource` row scope, verified connection-free.
///
/// The done-bar: an entity carrying a resource-key column is filtered, on read
/// *and* on write, by the resource keys the current principal holds a grant on
/// (C-5 direct grants ∪ C-6 active delegations) — with no application-side
/// resolver. What the repository composes is the predicate + its bound
/// parameters, so that is what is asserted here, exactly as the `owner`/`group`
/// scopes are asserted in `data_scope_test.dart`.
///
/// Two grades govern the two sides (RCC5 decisions 1 and 2): a role registered
/// at [TomAuthState.read] or wider admits the row to a *query*; only
/// [TomAuthState.full] admits it to a *write*.

/// A trivial host for the [TomQueryBuilder] DSL the scope builder needs.
class _Builder with TomQueryBuilder {}

TomColumnInformation _resourceKeyColumn(String table) {
  return TomColumnInformation(
    tableType: Object,
    table: TomDbTable(datasource: 'main', table: table, primaryKeyField: 'id'),
    declaredType: String,
    declaredName: 'resourceKey',
    field: 'resource_key',
    column: TomDbColumn(columnName: 'resource_key'),
  );
}

TomPrincipal _principal(int id) => TomPrincipal(
  user: TomUser(id: id, username: 'user$id'),
  aci: TomAccessControlInformation(),
  authenticated: true,
);

TomPrincipalResourceGrant _grant(int principal, String resource, String role) =>
    TomPrincipalResourceGrant(
      principalId: '$principal',
      resourceKey: resource,
      role: role,
    );

/// Installs the `resource` scope over the given grant and delegation rows,
/// resolving delegation validity at [now].
void _install(
  List<TomPrincipalResourceGrant> grants, {
  List<TomPrincipalDelegation> delegations = const [],
  DateTime? now,
}) {
  final direct = TomPrincipalResourceRoleResolver(
    InMemoryPrincipalResourceGrantStore(grants),
  );
  TomResourceDataScope.install(
    TomDelegationResolver(
      InMemoryPrincipalDelegationStore(delegations),
      direct,
    ),
    now: now == null ? null : () => now,
  );
}

void main() {
  final b = _Builder();
  final dialect = MariadbSqlDialect();
  const scope = TomDbScope(
    field: 'resource_key',
    scope: TomDbScope.resourceScope,
  );
  final col = _resourceKeyColumn('projects');

  setUp(() {
    TomResourceRoleRegistry.reset();
    // The vocabulary the grades are read through: an `owner` may write, a
    // `viewer` may only read, a `blocked` role sees nothing (C-5 grading).
    TomResourceRoleRegistry.registerAll({
      'owner': TomAuthState.full,
      'editor': TomAuthState.full,
      'viewer': TomAuthState.read,
      'blocked': TomAuthState.disabled,
    });
  });

  tearDown(() {
    TomResourceDataScope.uninstall();
    TomDataScopeRegistry.reset();
    TomResourceRoleRegistry.reset();
  });

  Future<TomDataScopePredicate> read(TomPrincipal? principal) async =>
      (await TomDataScope.buildAsync(b, scope, col, principal))!;

  Future<TomDataScopePredicate> write(TomPrincipal? principal) async =>
      (await TomDataScope.buildAsync(
        b,
        scope,
        col,
        principal,
        forWrite: true,
      ))!;

  group('grant-driven read scope (RCC5 done-bar)', () {
    test(
      'two principals see disjoint row sets from their own grants',
      () async {
        _install([
          _grant(1, 'project:alpha', 'owner'),
          _grant(2, 'project:beta', 'owner'),
        ]);
        expect((await read(_principal(1))).parameters.values, [
          'project:alpha',
        ]);
        expect((await read(_principal(2))).parameters.values, ['project:beta']);
      },
    );

    test(
      'a read grant admits the row, a full grant admits it too (decision 1)',
      () async {
        _install([
          _grant(1, 'project:alpha', 'owner'),
          _grant(1, 'project:beta', 'viewer'),
        ]);
        expect(
          (await read(_principal(1))).parameters.values,
          containsAll(<Object?>['project:alpha', 'project:beta']),
        );
      },
    );

    test(
      'a disabled-graded role does not admit the row (decision 1)',
      () async {
        _install([
          _grant(1, 'project:alpha', 'owner'),
          _grant(1, 'project:greyed', 'blocked'),
        ]);
        expect((await read(_principal(1))).parameters.values, [
          'project:alpha',
        ]);
      },
    );

    test('an unregistered role grants nothing (closed by default)', () async {
      _install([_grant(1, 'project:alpha', 'inventor')]);
      expect(
        (await read(_principal(1))).predicate.generate(dialect),
        b.boolOp(false).generate(dialect),
      );
    });

    test('no grants deny every row (deny-by-default)', () async {
      _install(const []);
      final p = await read(_principal(1));
      expect(p.predicate.generate(dialect), b.boolOp(false).generate(dialect));
      expect(p.parameters, isEmpty);
    });

    test('a null (unauthenticated) principal sees nothing', () async {
      _install([_grant(1, 'project:alpha', 'owner')]);
      final p = await read(null);
      expect(p.predicate.generate(dialect), b.boolOp(false).generate(dialect));
      expect(p.parameters, isEmpty);
    });

    test(
      'the resource keys are bound, never written into the SQL (C-7)',
      () async {
        _install([
          _grant(1, 'project:alpha', 'owner'),
          _grant(1, 'project:beta', 'viewer'),
        ]);
        final p = await read(_principal(1));
        final sql = p.predicate.generate(dialect);
        expect(sql, isNot(contains('project:alpha')));
        expect(sql, isNot(contains('project:beta')));
        expect(sql, contains('projects.resource_key IN ('));
        expect(p.parameters.keys, everyElement(startsWith('__tomscope_')));
      },
    );
  });

  group('grant-driven write scope (RCC5 decision 2)', () {
    test('only a full-graded grant admits the row to a write', () async {
      _install([
        _grant(1, 'project:alpha', 'owner'),
        _grant(1, 'project:beta', 'viewer'),
      ]);
      expect((await write(_principal(1))).parameters.values, ['project:alpha']);
    });

    test('a read-only principal may query but may write nothing', () async {
      _install([_grant(1, 'project:beta', 'viewer')]);
      expect((await read(_principal(1))).parameters.values, ['project:beta']);
      final w = await write(_principal(1));
      expect(w.predicate.generate(dialect), b.boolOp(false).generate(dialect));
      expect(w.parameters, isEmpty);
    });

    test('a null principal may write nothing', () async {
      _install([_grant(1, 'project:alpha', 'owner')]);
      expect(
        (await write(null)).predicate.generate(dialect),
        b.boolOp(false).generate(dialect),
      );
    });

    test(
      'the writable key set is a membership check the repository can apply',
      () async {
        _install([
          _grant(1, 'project:alpha', 'owner'),
          _grant(1, 'project:beta', 'viewer'),
        ]);
        final writable = await TomDataScope.allowedValuesAsync(
          scope,
          _principal(1),
          forWrite: true,
        );
        expect(TomDataScope.permits(writable, 'project:alpha'), isTrue);
        expect(TomDataScope.permits(writable, 'project:beta'), isFalse);
        expect(TomDataScope.permits(writable, 'project:unknown'), isFalse);
      },
    );
  });

  group('delegated grants widen the scope (C-6 through the resolver)', () {
    final at = DateTime.utc(2026, 8, 4, 12);

    test(
      'a share delegation makes the delegate see the delegator\'s resource',
      () async {
        _install(
          [_grant(1, 'project:alpha', 'owner')],
          delegations: [
            TomPrincipalDelegation(
              delegatorId: '1',
              delegateId: '2',
              mode: TomDelegationMode.share.name,
              resourceKey: 'project:alpha',
              role: 'viewer',
            ),
          ],
          now: at,
        );
        expect((await read(_principal(2))).parameters.values, [
          'project:alpha',
        ]);
        // Shared as a viewer, so the delegate may read it but not write it.
        expect(
          (await write(_principal(2))).predicate.generate(dialect),
          b.boolOp(false).generate(dialect),
        );
      },
    );

    test('a share at a full-graded role also admits the write', () async {
      _install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: TomDelegationMode.share.name,
            resourceKey: 'project:alpha',
            role: 'editor',
          ),
        ],
        now: at,
      );
      expect((await write(_principal(2))).parameters.values, ['project:alpha']);
    });

    test('a revoked delegation stops granting access', () async {
      _install(
        [_grant(1, 'project:alpha', 'owner')],
        delegations: [
          TomPrincipalDelegation(
            delegatorId: '1',
            delegateId: '2',
            mode: TomDelegationMode.share.name,
            resourceKey: 'project:alpha',
            role: 'viewer',
            revoked: true,
          ),
        ],
        now: at,
      );
      expect(
        (await read(_principal(2))).predicate.generate(dialect),
        b.boolOp(false).generate(dialect),
      );
    });

    test(
      'an absence delegation grants inside its window and not outside',
      () async {
        TomPrincipalDelegation absence() => TomPrincipalDelegation(
          delegatorId: '1',
          delegateId: '2',
          mode: TomDelegationMode.absence.name,
          validFrom: DateTime.utc(2026, 8, 1),
          validTo: DateTime.utc(2026, 8, 10),
        );

        _install(
          [_grant(1, 'project:alpha', 'owner')],
          delegations: [absence()],
          now: DateTime.utc(2026, 8, 4),
        );
        expect((await read(_principal(2))).parameters.values, [
          'project:alpha',
        ]);

        _install(
          [_grant(1, 'project:alpha', 'owner')],
          delegations: [absence()],
          now: DateTime.utc(2026, 8, 20),
        );
        expect(
          (await read(_principal(2))).predicate.generate(dialect),
          b.boolOp(false).generate(dialect),
        );
      },
    );

    test(
      'the delegate keeps their own direct grants alongside the shared one',
      () async {
        _install(
          [
            _grant(1, 'project:alpha', 'owner'),
            _grant(2, 'project:beta', 'owner'),
          ],
          delegations: [
            TomPrincipalDelegation(
              delegatorId: '1',
              delegateId: '2',
              mode: TomDelegationMode.share.name,
              resourceKey: 'project:alpha',
              role: 'viewer',
            ),
          ],
          now: at,
        );
        expect(
          (await read(_principal(2))).parameters.values,
          containsAll(<Object?>['project:alpha', 'project:beta']),
        );
        // Only the own resource is writable — the share is a viewer share.
        expect((await write(_principal(2))).parameters.values, [
          'project:beta',
        ]);
      },
    );
  });

  group('installation lifecycle', () {
    test('uninstall returns the scope to deny-all', () async {
      _install([_grant(1, 'project:alpha', 'owner')]);
      expect(TomResourceDataScope.isInstalled, isTrue);
      TomResourceDataScope.uninstall();
      expect(TomResourceDataScope.isInstalled, isFalse);
      expect(
        (await read(_principal(1))).predicate.generate(dialect),
        b.boolOp(false).generate(dialect),
      );
    });

    test('the principal-id mapping is overridable', () async {
      final direct = TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore([
          _grant(0, 'user1', 'owner')..principalId = 'user1',
        ]),
      );
      TomResourceDataScope.install(
        TomDelegationResolver(
          InMemoryPrincipalDelegationStore(const []),
          direct,
        ),
        principalId: (p) => p.username,
      );
      expect((await read(_principal(1))).parameters.values, ['user1']);
    });

    test(
      'resolution runs unscoped so the grant reads cannot recurse',
      () async {
        var sawBypass = false;
        final direct = TomPrincipalResourceRoleResolver(
          _BypassProbeGrantStore(() => sawBypass = TomDataScope.isBypassed),
        );
        TomResourceDataScope.install(
          TomDelegationResolver(
            InMemoryPrincipalDelegationStore(const []),
            direct,
          ),
        );
        await read(_principal(1));
        expect(sawBypass, isTrue);
      },
    );
  });

  group('per-request caching', () {
    test(
      'runCached resolves the grants once for every query in the request',
      () async {
        final store = _CountingGrantStore([
          _grant(1, 'project:alpha', 'owner'),
        ]);
        TomResourceDataScope.install(
          TomDelegationResolver(
            InMemoryPrincipalDelegationStore(const []),
            TomPrincipalResourceRoleResolver(store),
          ),
        );
        await TomResourceDataScope.runCached(() async {
          await read(_principal(1));
          await read(_principal(1));
          await write(_principal(1));
        });
        expect(store.calls, 1);
      },
    );

    test('without runCached every resolution reads the grants', () async {
      final store = _CountingGrantStore([_grant(1, 'project:alpha', 'owner')]);
      TomResourceDataScope.install(
        TomDelegationResolver(
          InMemoryPrincipalDelegationStore(const []),
          TomPrincipalResourceRoleResolver(store),
        ),
      );
      await read(_principal(1));
      await read(_principal(1));
      expect(store.calls, 2);
    });

    test('the cache is keyed per principal', () async {
      final store = _CountingGrantStore([
        _grant(1, 'project:alpha', 'owner'),
        _grant(2, 'project:beta', 'owner'),
      ]);
      TomResourceDataScope.install(
        TomDelegationResolver(
          InMemoryPrincipalDelegationStore(const []),
          TomPrincipalResourceRoleResolver(store),
        ),
      );
      await TomResourceDataScope.runCached(() async {
        expect((await read(_principal(1))).parameters.values, [
          'project:alpha',
        ]);
        expect((await read(_principal(2))).parameters.values, ['project:beta']);
      });
      expect(store.calls, 2);
    });
  });

  group("the scope's own input tables are never auto-scoped", () {
    // The framework's authorization tables all carry a `resource_key` column,
    // so they match the auto-scope rule by shape. Scoping them would close the
    // authorization layer against itself: a principal reaches its own grant
    // rows only by already holding a grant on them, which no row can satisfy.
    //
    // They carry `@TomDbScope.unscoped()` too, but that lives in generated
    // reflection, which a deployment may not have regenerated after upgrading.
    // The name set is the guard that does not depend on code generation — so
    // these tests assert the *set*, and that it still names the real tables.

    setUpAll(initializeReflection);

    test('the named tables match the entities that declare them', () {
      // Keeps the duplicated names honest: `object_persistence` cannot import
      // `authorization`, so renaming a table there must fail here rather than
      // silently disarm the guard.
      final declared = {
        for (final type in [
          TomPrincipalResourceGrant,
          TomPrincipalDelegation,
          TomResourceGrant,
        ])
          TomAnnotationAnalyzer.findTable(type)!.table,
      };
      expect(
        TomAnnotationAnalyzer.resourceScopeInputTables,
        equals(declared),
        reason:
            'resourceScopeInputTables must name exactly the tables the '
            'resource scope reads to compute itself',
      );
    });

    test('a resource-key column on an input table synthesises no scope', () {
      for (final table in TomAnnotationAnalyzer.resourceScopeInputTables) {
        expect(
          TomAnnotationAnalyzer.autoScopeFor([_resourceKeyColumn(table)]),
          isNull,
          reason: '$table is the scope\'s input and must stay unscoped',
        );
      }
    });

    test('the same column on any other table does synthesise one', () {
      final scope = TomAnnotationAnalyzer.autoScopeFor([
        _resourceKeyColumn('app_document'),
      ]);
      expect(scope, isNotNull);
      expect(scope!.scope, TomDbScope.resourceScope);
    });
  });
}

/// A grant store that reports whether the scope bypass was in force when the
/// resolver read through it (the recursion guard).
class _BypassProbeGrantStore implements PrincipalResourceGrantStore {
  final void Function() probe;

  _BypassProbeGrantStore(this.probe);

  @override
  Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(
    String principalId,
  ) async {
    probe();
    return const [];
  }
}

/// A grant store that counts how often the resolver read through it.
class _CountingGrantStore implements PrincipalResourceGrantStore {
  final List<TomPrincipalResourceGrant> grants;
  int calls = 0;

  _CountingGrantStore(this.grants);

  @override
  Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(
    String principalId,
  ) async {
    calls++;
    return [
      for (final g in grants)
        if (g.principalId == principalId) g,
    ];
  }
}
