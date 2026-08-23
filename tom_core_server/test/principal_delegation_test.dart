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

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

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
