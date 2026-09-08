/// Tests for per-principal-per-resource role persistence and resolution (C-5).
///
/// The server half of the C-5 done-bar: a `(principal_id, resource_key, role)`
/// grant table folds into the `resourceKey → roleName` map the kernel carries on
/// the principal (and thus in the authorization token). This suite pins:
///   * [TomPrincipalResourceGrant] — the grant row.
///   * [TomPrincipalResourceRoleResolver] — folding grants into a per-resource
///     role map, including the strongest-role tie-break for duplicate resources.
///   * [InMemoryPrincipalResourceGrantStore] — the seeded, connection-free store.
///
/// That the shipped reference migration still reproduces
/// [TomPrincipalResourceGrant.createTableSql] is asserted in
/// `reference_migrations_test.dart`, which holds that guard for every migration
/// under `example/` rather than a copy of it per entity.
///
/// Everything here is connection-free: no live MariaDB is touched, matching the
/// conventions of `graded_authorization_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('TomPrincipalResourceGrant', () {
    test('constructs no-arg (reflection-loadable) with safe defaults', () {
      final grant = TomPrincipalResourceGrant();
      expect(grant.id, -1);
      expect(grant.principalId, '');
      expect(grant.resourceKey, '');
      expect(grant.role, '');
    });

    test('createTableSql keys on (principal_id, resource_key)', () {
      final sql = TomPrincipalResourceGrant.createTableSql;
      expect(sql, contains('tom_principal_resource_grant'));
      expect(sql, contains('principal_id'));
      expect(sql, contains('resource_key'));
      expect(sql, contains('role'));
      expect(sql, contains('UNIQUE KEY uq_tom_principal_resource_grant'));
    });
  });

  group('TomPrincipalResourceRoleResolver — C-5 done-bar', () {
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

    test('registryStrength keeps the first of two equally strong roles', () {
      // `owner` and `editor` are both `full` here, and the resolver folds
      // several grants for one resource through this comparator -- so on a tie
      // the answer decides which role name a caller sees, and it has to be the
      // same answer every time or an effective-role map changes between runs
      // on grants that did not.
      //
      // Keeping the first is what makes the fold left-associative: the
      // accumulator wins unless the newcomer is genuinely stronger. Found by
      // mutation -- narrowing `>=` to `>`, which reverses exactly this case,
      // left the suite green.
      expect(
        TomPrincipalResourceRoleResolver.registryStrength('owner', 'editor'),
        'owner',
      );
      expect(
        TomPrincipalResourceRoleResolver.registryStrength('editor', 'owner'),
        'editor',
      );
      // And a genuine difference is still decided by strength, either way round.
      expect(
        TomPrincipalResourceRoleResolver.registryStrength('viewer', 'owner'),
        'owner',
      );
      expect(
        TomPrincipalResourceRoleResolver.registryStrength('owner', 'viewer'),
        'owner',
      );
    });

    test(
      'Alice\'s role differs per resource → per-resource role map',
      () async {
        final store = InMemoryPrincipalResourceGrantStore([
          TomPrincipalResourceGrant(
            principalId: 'alice',
            resourceKey: 'project.X',
            role: 'owner',
          ),
          TomPrincipalResourceGrant(
            principalId: 'alice',
            resourceKey: 'project.Y',
            role: 'viewer',
          ),
          // Bob's grant must not leak into Alice's resolution.
          TomPrincipalResourceGrant(
            principalId: 'bob',
            resourceKey: 'project.X',
            role: 'viewer',
          ),
        ]);
        final resolver = TomPrincipalResourceRoleResolver(store);

        final roles = await resolver.resolveResourceRoles('alice');
        expect(roles, {'project.X': 'owner', 'project.Y': 'viewer'});
      },
    );

    test('no grants → empty map (every resource resolves to none)', () async {
      final resolver = TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore([]),
      );
      expect(await resolver.resolveResourceRoles('nobody'), isEmpty);
    });

    test('duplicate resource collapses to the strongest role', () async {
      // A direct viewer grant plus a delegated owner grant (C-6 shape) on the
      // same resource: the stronger (owner → full) must win.
      final store = InMemoryPrincipalResourceGrantStore([
        TomPrincipalResourceGrant(
          principalId: 'alice',
          resourceKey: 'project.X',
          role: 'viewer',
        ),
        TomPrincipalResourceGrant(
          principalId: 'alice',
          resourceKey: 'project.X',
          role: 'owner',
        ),
      ]);
      final resolver = TomPrincipalResourceRoleResolver(store);

      final roles = await resolver.resolveResourceRoles('alice');
      expect(roles, {'project.X': 'owner'});
    });

    test(
      'resolveAdapter produces an adapter driving server + client states',
      () async {
        final store = InMemoryPrincipalResourceGrantStore([
          TomPrincipalResourceGrant(
            principalId: 'alice',
            resourceKey: 'project.X',
            role: 'owner',
          ),
          TomPrincipalResourceGrant(
            principalId: 'alice',
            resourceKey: 'project.Y',
            role: 'viewer',
          ),
        ]);
        final resolver = TomPrincipalResourceRoleResolver(store);

        final adapter = await resolver.resolveAdapter('alice');

        // Server enforcement.
        expect(adapter.stateOf('project.X').isInteractive, isTrue);
        expect(adapter.stateOf('project.Y').isInteractive, isFalse);
        // Client presentation.
        expect(adapter.resolveAuth('project.X'), TomAuthState.full);
        expect(adapter.resolveAuth('project.Y'), TomAuthState.read);
        expect(adapter.resolveAuth('project.Z'), TomAuthState.none);
      },
    );

    test(
      'a custom strongerRole ordering overrides the registry default',
      () async {
        // With registry strength, editor (full) would beat commenter (read); a
        // caller-supplied ordering that always prefers the alphabetically-first
        // token flips that.
        final store = InMemoryPrincipalResourceGrantStore([
          TomPrincipalResourceGrant(
            principalId: 'alice',
            resourceKey: 'r',
            role: 'editor',
          ),
          TomPrincipalResourceGrant(
            principalId: 'alice',
            resourceKey: 'r',
            role: 'commenter',
          ),
        ]);
        final resolver = TomPrincipalResourceRoleResolver(
          store,
          strongerRole: (a, b) => a.compareTo(b) <= 0 ? a : b,
        );

        final roles = await resolver.resolveResourceRoles('alice');
        expect(roles, {'r': 'commenter'});
      },
    );
  });
}
