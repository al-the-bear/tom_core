/// Executable example for the grant-driven row scope
/// ([TomResourceDataScope]) of `tom_core_server`.
///
/// An entity that carries a `resource_key` column is filtered — on reads *and*
/// on writes — by the resource keys the current principal holds a grant on. No
/// application-side resolver is involved: the grants (C-5) and the delegations
/// (C-6) already answer "which resources may this principal touch, and how
/// strongly", and the row scope simply asks them per query.
///
/// The demo runs connection-free: it resolves the scope and prints the
/// predicate the repository would AND into its `WHERE`, rather than opening a
/// data source. The same behaviour is covered end to end against MariaDB by
/// `test/resource_data_scope_db_test.dart`, and at predicate level by
/// `test/resource_data_scope_test.dart`.
///
/// Run with `dart run example/authorization/resource_data_scope_example.dart`.
/// Every step checks its own result and the run fails when one does not hold,
/// so a green run is a verification and not just a transcript.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// A trivial host for the [TomQueryBuilder] DSL (the repository is one too).
class _Builder with TomQueryBuilder {}

/// The `resource_key` column of a `document` table, as reflection would report
/// it for an entity with a `String resourceKey` field.
TomColumnInformation _resourceKeyColumn() => TomColumnInformation(
  tableType: Object,
  table: TomDbTable(
    datasource: 'main',
    table: 'document',
    primaryKeyFields: ['id'],
  ),
  declaredType: String,
  declaredName: 'resourceKey',
  field: 'resourceKey',
  column: TomDbColumn(columnName: 'resource_key'),
);

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

/// Renders a resolved scope predicate as SQL plus its bind values, so the
/// example can show that every key rides the prepared-statement protocol rather
/// than being concatenated into the statement (C-7).
String _render(TomDataScopePredicate? scope, TomStandardSqlDialect dialect) {
  if (scope == null) return '<no scoping>';
  return '${scope.predicate.generate(dialect)}  binds=${scope.parameters}';
}

Future<void> run() async {
  final builder = _Builder();
  final dialect = MariadbSqlDialect();
  final column = _resourceKeyColumn();
  final scope = TomDbScope(
    field: 'resourceKey',
    scope: TomDbScope.resourceScope,
  );

  final alice = _principal(1);
  final bob = _principal(2);

  // 0. Roles are graded once, at start-up. An unregistered role grades as
  //    nothing and so grants nothing — a typo in a grant row closes a door
  //    rather than opening one.
  TomResourceRoleRegistry.registerAll({
    'owner': TomAuthState.full,
    'viewer': TomAuthState.read,
    'blocked': TomAuthState.disabled,
  });

  // 1. While no source is installed the scope denies every row: an unwired
  //    scope must be a closed door.
  TomResourceDataScope.uninstall();
  print(
    '1. uninstalled -> ${_render(await TomDataScope.buildAsync(builder, scope, column, alice), dialect)}',
  );

  // 2. Install the scope over the delegation resolver the rest of the
  //    authorization layer already uses. Alice owns `proj-a` and merely views
  //    `proj-b`; Bob owns `proj-c` and is `blocked` on `proj-d`.
  final grants = [
    _grant(1, 'proj-a', 'owner'),
    _grant(1, 'proj-b', 'viewer'),
    _grant(2, 'proj-c', 'owner'),
    _grant(2, 'proj-d', 'blocked'),
  ];
  final delegations = <TomPrincipalDelegation>[];
  TomResourceDataScope.install(
    TomDelegationResolver(
      InMemoryPrincipalDelegationStore(delegations),
      TomPrincipalResourceRoleResolver(
        InMemoryPrincipalResourceGrantStore(grants),
      ),
    ),
  );
  print(
    '2. installed    : ${grants.length} grants, '
    '${delegations.length} delegations',
  );

  // 3. On a read, a grade of `read` or wider admits the row — so Alice sees
  //    both the project she owns and the one she only views.
  final aliceRead = await TomDataScope.buildAsync(
    builder,
    scope,
    column,
    alice,
  );
  print('3. alice read  : ${_render(aliceRead, dialect)}');
  check(
    aliceRead!.parameters.values.contains('proj-a'),
    'a listing shows the project its owner owns',
  );
  check(
    aliceRead.parameters.values.contains('proj-b'),
    'a listing also shows a project shared read-only, so "shared with me" is '
    'visible rather than merely not writable',
  );

  // 4. On a write, only `full` admits it. The viewer grant on `proj-b` shows a
  //    row in every listing and rejects every attempt to change it — which is
  //    exactly the difference between "shared with me" and "mine".
  final aliceWrite = await TomDataScope.buildAsync(
    builder,
    scope,
    column,
    alice,
    forWrite: true,
  );
  print('4. alice write : ${_render(aliceWrite, dialect)}');
  check(
    aliceWrite!.parameters.values.contains('proj-a'),
    'an owner may change the rows of the project they own',
  );
  check(
    !aliceWrite.parameters.values.contains('proj-b'),
    'a viewer grant stops at the write path, which is the whole difference '
    'between "shared with me" and "mine"',
  );

  // 5. The two principals resolve to disjoint sets, and a `disabled` grade
  //    grants nothing at all — Bob never sees `proj-d`.
  final bobRead = await TomDataScope.buildAsync(builder, scope, column, bob);
  print('5. bob read    : ${_render(bobRead, dialect)}');
  check(
    bobRead!.parameters.values.contains('proj-c'),
    'each principal is scoped by their own grants',
  );
  check(
    !bobRead.parameters.values.contains('proj-d'),
    'a role graded disabled admits nothing, so holding a grant row is not by '
    'itself access',
  );
  check(
    !bobRead.parameters.values.contains('proj-a'),
    "one principal's resources stay out of another's queries",
  );

  // 6. Deny by default: an unauthenticated request (no principal in the zone)
  //    resolves to no keys, and the scope renders a FALSE filter rather than an
  //    unfiltered query.
  print(
    '6. no principal: ${_render(await TomDataScope.buildAsync(builder, scope, column, null), dialect)}',
  );

  // 7. Delegations are folded in *through* TomDelegationResolver, so every rule
  //    it enforces — validity window, revocation, mode, non-transitivity —
  //    governs the row scope for free. Alice shares `proj-a` with Bob as a
  //    viewer for the next hour.
  final now = DateTime.now();
  delegations.add(
    TomPrincipalDelegation(
      delegatorId: '1',
      delegateId: '2',
      resourceKey: 'proj-a',
      role: 'viewer',
      mode: TomDelegationMode.share.name,
      validFrom: now.subtract(const Duration(minutes: 1)),
      validTo: now.add(const Duration(hours: 1)),
    ),
  );
  final bobShared = await TomDataScope.buildAsync(builder, scope, column, bob);
  print('7. bob + share : ${_render(bobShared, dialect)}');
  check(
    bobShared!.parameters.values.contains('proj-a'),
    "a live delegation widens the delegate's reads without anyone touching a "
    'grant row',
  );

  // 8. …but the share is a *viewer* share, so it does not widen Bob's write
  //    set. Revoking it (or letting it expire) removes the row from his reads
  //    on the very next request — resolution is live, never read from the token.
  final bobSharedWrite = await TomDataScope.buildAsync(
    builder,
    scope,
    column,
    bob,
    forWrite: true,
  );
  print('8. bob + share (write): ${_render(bobSharedWrite, dialect)}');
  check(
    !bobSharedWrite!.parameters.values.contains('proj-a'),
    'a share carries its own role, so sharing something to read never hands '
    'over the right to change it',
  );

  // 9. Entities opt *in* by simply having the column: the analyzer synthesises
  //    the `resource` scope for any reflected entity exposing `resource_key`,
  //    so no annotation is needed on the ordinary case. An entity that must
  //    stay global opts out with `@TomDbScope.unscoped()`.
  final auto = TomAnnotationAnalyzer.autoScopeFor([column]);
  print('9. auto scope  : field=${auto?.field} kind=${auto?.scope}');
  check(
    auto != null && auto.scope == TomDbScope.resourceScope,
    'an entity carrying a resource_key column is scoped without anyone having '
    'to remember an annotation',
  );

  // 10. A request typically resolves the scope several times (one read per
  //     repository call, plus the write check). Wrapping the request body in
  //     runCached collapses them into one grant read per principal, while
  //     keeping resolution live *across* requests.
  await TomResourceDataScope.runCached(() async {
    await TomDataScope.buildAsync(builder, scope, column, alice);
    await TomDataScope.buildAsync(builder, scope, column, alice);
    print('10. two resolutions inside runCached shared one grant read');
  });

  TomResourceDataScope.uninstall();
  TomResourceRoleRegistry.reset();
  print('\nResource data-scope example completed.');
}

Future<void> main() async {
  await run();
}
