/// Tests for C-6 delegation (share / absence / intentional) resolution.
///
/// The C-6 done-bar: *B gains A's role on a shared resource within an absence
/// window and loses it after; verified by test at two timestamps.* Delegations
/// are grant-table rows resolved alongside a delegate's own direct C-5 grants, so
/// this suite pins:
///   * [TomPrincipalDelegation] — the row, its parsed mode, and the uniform
///     [TomPrincipalDelegation.isActiveAt] window/revoke gate.
///   * [TomDelegationResolver] — the three modes, the two-timestamp absence
///     window, non-transitivity, and the strength-fold merge with direct grants.
///   * [InMemoryPrincipalDelegationStore] — the seeded, connection-free store.
///
/// That the shipped reference migration still reproduces
/// [TomPrincipalDelegation.createTableSql] is asserted in
/// `reference_migrations_test.dart`, which holds that guard for every migration
/// under `example/` rather than a copy of it per entity.
///
/// Everything here is connection-free: no live MariaDB is touched, matching the
/// conventions of `principal_resource_grant_test.dart`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// A direct-grant store seeded so Alice owns `project.X` and views `project.Y`.
TomPrincipalResourceRoleResolver _directResolver(
  List<TomPrincipalResourceGrant> grants,
) => TomPrincipalResourceRoleResolver(
  InMemoryPrincipalResourceGrantStore(grants),
);

TomPrincipalResourceGrant _grant(
  String principal,
  String resource,
  String role,
) => TomPrincipalResourceGrant(
  principalId: principal,
  resourceKey: resource,
  role: role,
);

/// An [InMemoryPrincipalResourceGrantStore] that counts its reads, so a test can
/// assert how many times resolution went to the store rather than only what it
/// resolved. Modelled on the `_CountingGrantStore` the `per-request caching`
/// group in `resource_data_scope_test.dart` counts [TomResourceDataScope]
/// resolutions with.
class _CountingGrantStore implements PrincipalResourceGrantStore {
  final List<TomPrincipalResourceGrant> grants;

  /// The principal ids passed to [grantsForPrincipal], in call order. The length
  /// is the read count; the set is which delegators were read at all.
  final List<String> reads = [];

  _CountingGrantStore(this.grants);

  @override
  Future<List<TomPrincipalResourceGrant>> grantsForPrincipal(
    String principalId,
  ) async {
    reads.add(principalId);
    return [
      for (final g in grants)
        if (g.principalId == principalId) g,
    ];
  }
}

void main() {
  setUp(() {
    TomResourceRoleRegistry.reset();
    TomResourceRoleRegistry.registerAll({
      'owner': TomAuthState.full,
      'editor': TomAuthState.full,
      'commenter': TomAuthState.read,
      'viewer': TomAuthState.read,
    });
  });
  tearDown(TomResourceRoleRegistry.reset);

  group('TomPrincipalDelegation', () {
    test('constructs no-arg (reflection-loadable) with safe defaults', () {
      final d = TomPrincipalDelegation();
      expect(d.id, -1);
      expect(d.delegatorId, '');
      expect(d.delegateId, '');
      expect(d.mode, '');
      expect(d.resourceKey, isNull);
      expect(d.role, isNull);
      expect(d.validFrom, isNull);
      expect(d.validTo, isNull);
      expect(d.revoked, isFalse);
      // A blank mode parses to null → delegates nothing (closed/safe).
      expect(d.delegationMode, isNull);
    });

    test('delegationMode parses the stored name, null when unknown', () {
      expect(
        TomPrincipalDelegation(mode: 'share').delegationMode,
        TomDelegationMode.share,
      );
      expect(
        TomPrincipalDelegation(mode: 'absence').delegationMode,
        TomDelegationMode.absence,
      );
      expect(
        TomPrincipalDelegation(mode: 'intentional').delegationMode,
        TomDelegationMode.intentional,
      );
      expect(TomPrincipalDelegation(mode: 'bogus').delegationMode, isNull);
    });

    test('createTableSql names the table, columns and delegate index', () {
      final sql = TomPrincipalDelegation.createTableSql;
      expect(sql, contains('tom_principal_delegation'));
      expect(sql, contains('delegator_id'));
      expect(sql, contains('delegate_id'));
      expect(sql, contains('mode'));
      expect(sql, contains('valid_from'));
      expect(sql, contains('valid_to'));
      expect(sql, contains('revoked'));
      expect(sql, contains('idx_tom_principal_delegation_delegate'));
    });

    group('isActiveAt', () {
      final from = DateTime.utc(2026, 1, 10);
      final to = DateTime.utc(2026, 1, 20);

      test('within an inclusive window → active; outside → inactive', () {
        final d = TomPrincipalDelegation(
          mode: 'absence',
          validFrom: from,
          validTo: to,
        );
        expect(d.isActiveAt(DateTime.utc(2026, 1, 9)), isFalse); // before
        expect(d.isActiveAt(from), isTrue); // inclusive start
        expect(d.isActiveAt(DateTime.utc(2026, 1, 15)), isTrue); // inside
        expect(d.isActiveAt(to), isTrue); // inclusive end
        expect(d.isActiveAt(DateTime.utc(2026, 1, 21)), isFalse); // after
      });

      test('null bounds are unbounded on that side', () {
        final openEnd = TomPrincipalDelegation(
          mode: 'intentional',
          validFrom: from,
        );
        expect(openEnd.isActiveAt(DateTime.utc(2030)), isTrue);
        final openStart = TomPrincipalDelegation(
          mode: 'intentional',
          validTo: to,
        );
        expect(openStart.isActiveAt(DateTime.utc(2000)), isTrue);
        final unbounded = TomPrincipalDelegation(mode: 'intentional');
        expect(unbounded.isActiveAt(DateTime.utc(2026, 6)), isTrue);
      });

      test('revoked is inactive at every timestamp', () {
        final d = TomPrincipalDelegation(
          mode: 'intentional',
          validFrom: from,
          validTo: to,
          revoked: true,
        );
        expect(d.isActiveAt(from), isFalse);
        expect(d.isActiveAt(DateTime.utc(2026, 1, 15)), isFalse);
      });
    });
  });

  group('TomDelegationResolver — absence window (C-6 done-bar)', () {
    // Alice (delegator) owns project.X and views project.Y.
    final direct = _directResolver([
      _grant('alice', 'project.X', 'owner'),
      _grant('alice', 'project.Y', 'viewer'),
    ]);
    final from = DateTime.utc(2026, 1, 10);
    final to = DateTime.utc(2026, 1, 20);
    // Bob is out-of-office cover for Alice for the window.
    final store = InMemoryPrincipalDelegationStore([
      TomPrincipalDelegation(
        delegatorId: 'alice',
        delegateId: 'bob',
        mode: 'absence',
        validFrom: from,
        validTo: to,
      ),
    ]);
    final resolver = TomDelegationResolver(store, direct);

    final inside = DateTime.utc(2026, 1, 15);
    final after = DateTime.utc(2026, 2, 1);

    test('within the window Bob inherits ALL of Alice\'s roles', () async {
      expect(await resolver.resolveDelegatedRoles('bob', inside), {
        'project.X': 'owner',
        'project.Y': 'viewer',
      });
    });

    test('after the window Bob inherits nothing', () async {
      expect(await resolver.resolveDelegatedRoles('bob', after), isEmpty);
    });

    test('effective roles: Bob gains then loses owner on project.X', () async {
      final adapterInside = await resolver.resolveAdapter('bob', inside);
      expect(adapterInside.stateOf('project.X').isInteractive, isTrue);

      final adapterAfter = await resolver.resolveAdapter('bob', after);
      expect(adapterAfter.stateOf('project.X'), TomAuthState.none);
    });
  });

  group('TomDelegationResolver — share and intentional modes', () {
    final direct = _directResolver([
      _grant('alice', 'project.X', 'owner'),
      _grant('alice', 'project.Y', 'viewer'),
    ]);
    final now = DateTime.utc(2026, 3, 1);

    test('share lends exactly the named (resource, role), no delegator grant '
        'needed', () async {
      // Carol shares only project.Q at viewer with Bob — Carol holds no direct
      // grant here, proving share carries its own explicit role.
      final store = InMemoryPrincipalDelegationStore([
        TomPrincipalDelegation(
          delegatorId: 'carol',
          delegateId: 'bob',
          mode: 'share',
          resourceKey: 'project.Q',
          role: 'viewer',
        ),
      ]);
      final resolver = TomDelegationResolver(store, direct);
      expect(await resolver.resolveDelegatedRoles('bob', now), {
        'project.Q': 'viewer',
      });
    });

    test('a malformed share (missing role) contributes nothing', () async {
      final store = InMemoryPrincipalDelegationStore([
        TomPrincipalDelegation(
          delegatorId: 'carol',
          delegateId: 'bob',
          mode: 'share',
          resourceKey: 'project.Q',
        ),
      ]);
      final resolver = TomDelegationResolver(store, direct);
      expect(await resolver.resolveDelegatedRoles('bob', now), isEmpty);
    });

    test(
      'intentional narrows to one resource and overrides the role',
      () async {
        // Alice intentionally lends only project.X, downgraded to viewer.
        final store = InMemoryPrincipalDelegationStore([
          TomPrincipalDelegation(
            delegatorId: 'alice',
            delegateId: 'bob',
            mode: 'intentional',
            resourceKey: 'project.X',
            role: 'viewer',
          ),
        ]);
        final resolver = TomDelegationResolver(store, direct);
        expect(await resolver.resolveDelegatedRoles('bob', now), {
          'project.X': 'viewer',
        });
      },
    );

    test('a revoked intentional delegation lends nothing', () async {
      final store = InMemoryPrincipalDelegationStore([
        TomPrincipalDelegation(
          delegatorId: 'alice',
          delegateId: 'bob',
          mode: 'intentional',
          revoked: true,
        ),
      ]);
      final resolver = TomDelegationResolver(store, direct);
      expect(await resolver.resolveDelegatedRoles('bob', now), isEmpty);
    });
  });

  group('TomDelegationResolver — merge, strength, and non-transitivity', () {
    final now = DateTime.utc(2026, 3, 1);

    test(
      'effective roles fold direct + delegated to the stronger per resource',
      () async {
        // Bob directly views project.X; Alice delegates owner of project.X to him.
        // The stronger (owner → full) must win, exactly like duplicate direct
        // grants collapse.
        final direct = _directResolver([
          _grant('alice', 'project.X', 'owner'),
          _grant('bob', 'project.X', 'viewer'),
        ]);
        final store = InMemoryPrincipalDelegationStore([
          TomPrincipalDelegation(
            delegatorId: 'alice',
            delegateId: 'bob',
            mode: 'intentional',
          ),
        ]);
        final resolver = TomDelegationResolver(store, direct);
        expect(await resolver.resolveEffectiveRoles('bob', now), {
          'project.X': 'owner',
        });
      },
    );

    test(
      'delegation is not transitive: B does not inherit A\'s delegated roles',
      () async {
        // Carol delegates her roles to Alice; Alice delegates hers to Bob. Bob must
        // see only Alice's DIRECT roles (project.X), never Carol's (project.Z).
        final direct = _directResolver([
          _grant('alice', 'project.X', 'owner'),
          _grant('carol', 'project.Z', 'owner'),
        ]);
        final store = InMemoryPrincipalDelegationStore([
          TomPrincipalDelegation(
            delegatorId: 'carol',
            delegateId: 'alice',
            mode: 'intentional',
          ),
          TomPrincipalDelegation(
            delegatorId: 'alice',
            delegateId: 'bob',
            mode: 'intentional',
          ),
        ]);
        final resolver = TomDelegationResolver(store, direct);
        expect(await resolver.resolveDelegatedRoles('bob', now), {
          'project.X': 'owner',
        });
      },
    );

    test('another delegate\'s delegations do not leak', () async {
      final direct = _directResolver([_grant('alice', 'project.X', 'owner')]);
      final store = InMemoryPrincipalDelegationStore([
        TomPrincipalDelegation(
          delegatorId: 'alice',
          delegateId: 'bob',
          mode: 'intentional',
        ),
      ]);
      final resolver = TomDelegationResolver(store, direct);
      expect(
        await resolver.resolveDelegatedRoles('someone_else', now),
        isEmpty,
      );
    });
  });

  group('PrincipalDelegationStore — only live rows cross the seam', () {
    final from = DateTime.utc(2026, 1, 10);
    final to = DateTime.utc(2026, 1, 20);

    /// One row of every liveness shape, all targeting Bob, all distinguishable
    /// by `delegatorId` so a test can name which survived.
    InMemoryPrincipalDelegationStore mixedStore() =>
        InMemoryPrincipalDelegationStore([
          TomPrincipalDelegation(
            delegatorId: 'live_unbounded',
            delegateId: 'bob',
            mode: 'intentional',
          ),
          TomPrincipalDelegation(
            delegatorId: 'live_in_window',
            delegateId: 'bob',
            mode: 'absence',
            validFrom: from,
            validTo: to,
          ),
          TomPrincipalDelegation(
            delegatorId: 'revoked',
            delegateId: 'bob',
            mode: 'intentional',
            revoked: true,
          ),
          TomPrincipalDelegation(
            delegatorId: 'not_yet',
            delegateId: 'bob',
            mode: 'absence',
            validFrom: DateTime.utc(2027),
          ),
          TomPrincipalDelegation(
            delegatorId: 'expired',
            delegateId: 'bob',
            mode: 'absence',
            validTo: DateTime.utc(2025),
          ),
          TomPrincipalDelegation(
            delegatorId: 'live_but_not_bobs',
            delegateId: 'someone_else',
            mode: 'intentional',
          ),
        ]);

    test('the in-memory store answers only the rows live at the '
        'instant', () async {
      final rows = await mixedStore().activeDelegationsForDelegate(
        'bob',
        DateTime.utc(2026, 1, 15),
      );
      expect(rows.map((d) => d.delegatorId), [
        'live_unbounded',
        'live_in_window',
      ]);
    });

    test('the instant decides: the same store answers differently '
        'later', () async {
      final rows = await mixedStore().activeDelegationsForDelegate(
        'bob',
        DateTime.utc(2026, 6, 1),
      );
      // The window row has expired by June; the unbounded one has not.
      expect(rows.map((d) => d.delegatorId), ['live_unbounded']);
    });

    group('the repository store asks the database', () {
      late TomQuerySentenceCompiler compiler;
      final dialect = MariadbSqlDialect();

      setUpAll(() {
        initializeReflection();
        compiler = TomQuerySentenceCompiler([TomPrincipalDelegation]);
      });

      /// The SQL the store's *own* sentence compiles to — the constant is read
      /// from the store rather than restated here, so the assertions below
      /// cannot drift from the query that actually runs.
      String sql() =>
          (compiler.compileQuerySentence(
                    RepositoryPrincipalDelegationStore.activeDelegationsQuery,
                  )
                  as TomSelect)
              .generateQuery(dialect);

      test('the delegate predicate is still there', () {
        expect(
          sql(),
          contains('tom_principal_delegation.delegate_id = :delegateId'),
        );
      });

      test('revoked rows are excluded in SQL', () {
        expect(sql(), contains('tom_principal_delegation.revoked = :revoked'));
      });

      test('the window bounds are tested in SQL, each admitting null', () {
        // `null` is unbounded on that side, so neither bound can be a bare
        // comparison: SQL's three-valued logic makes `NULL <= :at` unknown,
        // which would silently drop every open-ended delegation.
        expect(
          sql(),
          contains(
            '( tom_principal_delegation.valid_from IS NULL '
            'OR tom_principal_delegation.valid_from <= :at )',
          ),
        );
        expect(
          sql(),
          contains(
            '( tom_principal_delegation.valid_to IS NULL '
            'OR tom_principal_delegation.valid_to >= :at )',
          ),
        );
      });
    });

    test('the index covers the columns the query now filters on', () {
      // An index on the delegate alone leaves the database reading every
      // historical row for that delegate before discarding the revoked ones.
      expect(
        TomPrincipalDelegation.createTableSql,
        contains(
          'KEY idx_tom_principal_delegation_delegate (delegate_id, revoked)',
        ),
      );
    });
  });

  group('the validity window is an instant, not a wall clock', () {
    // `[validFrom, validTo]` decides whether a delegate holds a role. Stored as
    // the writing node's local wall clock it means a different moment on every
    // node that reads it, so two servers of one cluster disagree about when a
    // delegation begins and ends — and the one that is wrong is wrong in the
    // direction of granting access outside the window its owner set.

    /// Runs the probe with `TZ` forced to [zone] and returns its four fields.
    Future<List<String>> probe(String zone) async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', p.join('test', 'fixtures', 'delegation_window_tz_probe.dart')],
        environment: {'TZ': zone},
      );
      expect(
        result.exitCode,
        0,
        reason: 'probe failed under $zone: ${result.stdout}${result.stderr}',
      );
      return (result.stdout as String).trim().split('|');
    }

    test(
      'two nodes in different zones store the same characters',
      () async {
        // Fourteen hours east and twelve west: 26 hours apart, so the two
        // hosts are not merely at different clock readings but on different
        // calendar days for the probe's instant.
        final east = await probe('Pacific/Kiritimati');
        final west = await probe('Etc/GMT+12');

        // Believe the columns only once the forced zones are known to have
        // taken effect — two processes that both silently stayed at UTC would
        // agree trivially and the assertion below would prove nothing.
        expect(int.parse(east.first), 14, reason: 'TZ did not take effect');
        expect(int.parse(west.first), -12, reason: 'TZ did not take effect');

        // The property: the column is the instant, so the characters do not
        // depend on who wrote them.
        expect(east[1], west[1]);
        expect(east[1], '2026-08-11 23:30:00.000000');
      },
      skip: Platform.isWindows
          ? 'the Windows C runtime does not honour TZ'
          : null,
    );

    test(
      'a stored window bound reads back as the instant it names, in any zone',
      () async {
        final east = await probe('Pacific/Kiritimati');
        final west = await probe('Etc/GMT+12');

        expect(int.parse(east.first), 14, reason: 'TZ did not take effect');
        expect(int.parse(west.first), -12, reason: 'TZ did not take effect');

        // Both read the *same* stored text; a reader that parses it as its own
        // local time lands 14 hours early on one host and 12 hours late on the
        // other, which is 26 hours of window either side of the truth.
        expect(east[2], '2026-08-11T23:30:00.000Z');
        expect(west[2], '2026-08-11T23:30:00.000Z');
        // Flagged UTC, not merely equal to it: `DateTime.==` compares `isUtc`,
        // so a local-flagged value of the same moment fails every equality the
        // window comparisons and the tests are written with.
        expect(east[3], 'utc');
        expect(west[3], 'utc');
      },
      skip: Platform.isWindows
          ? 'the Windows C runtime does not honour TZ'
          : null,
    );

    test('the window columns carry the sub-second precision the '
        'convention specifies', () {
      // `DATETIME` is whole seconds; the instant convention is `DATETIME(6)`.
      // A window bound rounded to the second is a window whose edge moves by up
      // to half a second relative to the one that was set.
      expect(
        TomPrincipalDelegation.createTableSql,
        contains('valid_from DATETIME(6) NULL'),
      );
      expect(
        TomPrincipalDelegation.createTableSql,
        contains('valid_to DATETIME(6) NULL'),
      );
    });
  });

  group('TomDelegationResolver — grant reads per resolution', () {
    final now = DateTime.utc(2026, 3, 1);

    /// Three active delegations to Bob naming two distinct delegators: Alice
    /// twice (narrowed to a different resource each time, so both rows matter)
    /// and Carol once.
    List<TomPrincipalDelegation> threeDelegationsTwoDelegators() => [
      TomPrincipalDelegation(
        delegatorId: 'alice',
        delegateId: 'bob',
        mode: 'intentional',
        resourceKey: 'project.X',
      ),
      TomPrincipalDelegation(
        delegatorId: 'alice',
        delegateId: 'bob',
        mode: 'intentional',
        resourceKey: 'project.Y',
      ),
      TomPrincipalDelegation(
        delegatorId: 'carol',
        delegateId: 'bob',
        mode: 'absence',
      ),
    ];

    _CountingGrantStore countingStore() => _CountingGrantStore([
      _grant('alice', 'project.X', 'owner'),
      _grant('alice', 'project.Y', 'viewer'),
      _grant('carol', 'project.Z', 'editor'),
    ]);

    test('n delegations naming k delegators cost k grant reads', () async {
      final grants = countingStore();
      final resolver = TomDelegationResolver(
        InMemoryPrincipalDelegationStore(threeDelegationsTwoDelegators()),
        TomPrincipalResourceRoleResolver(grants),
      );

      final roles = await resolver.resolveDelegatedRoles('bob', now);

      // Three delegation rows, two delegators → two reads, not three.
      expect(grants.reads.length, 2);
      expect(grants.reads.toSet(), {'alice', 'carol'});
      // And the reuse lends the right roles: a memo keyed on the wrong thing
      // would hand Alice's grants to Carol's row (or the reverse) and this map
      // would be wrong while the count above stayed right.
      expect(roles, {
        'project.X': 'owner',
        'project.Y': 'viewer',
        'project.Z': 'editor',
      });
    });

    test('only the delegators that are actually resolved are read', () async {
      final grants = countingStore();
      final resolver = TomDelegationResolver(
        InMemoryPrincipalDelegationStore([
          // A share carries its own explicit role, so it never reads the
          // delegator's grants...
          TomPrincipalDelegation(
            delegatorId: 'dave',
            delegateId: 'bob',
            mode: 'share',
            resourceKey: 'project.Q',
            role: 'viewer',
          ),
          // ...and an inactive row is skipped before any read.
          TomPrincipalDelegation(
            delegatorId: 'erin',
            delegateId: 'bob',
            mode: 'intentional',
            revoked: true,
          ),
          TomPrincipalDelegation(
            delegatorId: 'alice',
            delegateId: 'bob',
            mode: 'intentional',
          ),
        ]),
        TomPrincipalResourceRoleResolver(grants),
      );

      await resolver.resolveDelegatedRoles('bob', now);

      expect(grants.reads, ['alice']);
    });

    test('the reuse is scoped to one resolution, not remembered across '
        'calls', () async {
      // Request-scoped caching is TomResourceDataScope.runCached's job; the
      // resolver holding grants beyond a single resolution would serve a
      // revoked grant to the next request.
      final grants = countingStore();
      final resolver = TomDelegationResolver(
        InMemoryPrincipalDelegationStore(threeDelegationsTwoDelegators()),
        TomPrincipalResourceRoleResolver(grants),
      );

      await resolver.resolveDelegatedRoles('bob', now);
      await resolver.resolveDelegatedRoles('bob', now);

      expect(grants.reads.length, 4);
    });

    test('effective roles read the delegate once alongside the '
        'delegators', () async {
      final grants = countingStore();
      final resolver = TomDelegationResolver(
        InMemoryPrincipalDelegationStore(threeDelegationsTwoDelegators()),
        TomPrincipalResourceRoleResolver(grants),
      );

      await resolver.resolveEffectiveRoles('bob', now);

      expect(grants.reads, ['bob', 'alice', 'carol']);
    });
  });
}
