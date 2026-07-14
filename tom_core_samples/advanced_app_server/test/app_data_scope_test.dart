/// Connection-free C-3 row-scope tests for the app records (RCC4 + RCB8).
///
/// The framework `@TomDbScope` filters a repository read to the current
/// principal's allowed values at the database. The advanced sample declares two
/// kinds of scope:
///
///  - [WorkspaceRecord] carries the *synchronous* single-column owner scope on
///    `ownerId` — a workspace's read visibility is *owner-only* (a workspace is
///    reachable iff the caller owns it; shares never target or flow up to one),
///    so it is faithfully one `owner_id IN (…)` predicate (RCC4).
///  - [ProjectRecord] / [ListRecord] / [ItemRecord] carry the RCB8 *async union*
///    scope on their surrogate `id`. Their visibility folds ownership *and*
///    `share`-mode delegations over the containment chain, which a single-column
///    AND-scope would silently AND-hide (dropping shared rows), so they use the
///    async resolver that ORs the owned and shared id-sets
///    (`id IN (owned…) OR id IN (shared…)`) instead.
///
/// The repository enforcement itself needs a live data source (exercised live in
/// the RCC5 integration script); here we verify the facts that need no
/// connection: each record declares the intended scope, the workspace scope
/// resolves to the owner predicate riding the prepared-statement protocol (the
/// value is bound, never inlined — C-7), and the boot registration wires an
/// async resolver for each shared-entity scope kind.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The server's single reflection seed is its boot root; the analyzer reads the
// `@TomDbScope` off the generated ClassMirror, so the registry must be live.
import '../bin/app_server_start.reflection.dart' show initializeReflection;

/// A trivial host for the [TomQueryBuilder] DSL the scope builder needs.
class _Builder with TomQueryBuilder {}

TomPrincipal _principal(int id) => TomPrincipal(
      user: TomUser(id: id, username: 'user$id'),
      aci: TomAccessControlInformation(),
      authenticated: true,
    );

void main() {
  setUpAll(initializeReflection);

  group('the @TomDbScope declarations', () {
    test('WorkspaceRecord is owner-scoped on its owner column', () {
      final scope = TomAnnotationAnalyzer.findDataScope(WorkspaceRecord);
      expect(scope, isNotNull);
      expect(scope!.field, 'ownerId');
      // Default scope kind is the built-in 'owner' resolver.
      expect(scope.scope, 'owner');
    });

    test('project/list/item are async union-scoped on their surrogate id', () {
      // Their share + containment visibility folds ownership ∪ shared rows over
      // the containment chain — not a single-column AND-scope. RCB8 re-scopes
      // them on `id` bound to an async union resolver, so the CRUD repository
      // pushes the caller's owned ∪ shared id-set to the DB as an OR-union.
      final project = TomAnnotationAnalyzer.findDataScope(ProjectRecord);
      expect(project, isNotNull);
      expect(project!.field, 'id');
      expect(project.scope, projectVisibilityScope);

      final list = TomAnnotationAnalyzer.findDataScope(ListRecord);
      expect(list, isNotNull);
      expect(list!.field, 'id');
      expect(list.scope, listVisibilityScope);

      final item = TomAnnotationAnalyzer.findDataScope(ItemRecord);
      expect(item, isNotNull);
      expect(item!.field, 'id');
      expect(item.scope, itemVisibilityScope);
    });
  });

  group('registerAppDataScopes wires an async resolver per shared entity', () {
    // registerAppDataScopes eagerly builds the production repositories, which
    // resolve their datasource *metadata* (never a connection) at construction
    // time — so the two datasources they bind (`main` for the delegation tables,
    // `app_db` for the records) must be registered first. Bare, uninitialised
    // entries satisfy the lookup without opening a socket, keeping this test
    // connection-free.
    setUp(() {
      TomDataSourceInfo.datasources['main'] = TomDataSourceInfo('main', {});
      TomDataSourceInfo.datasources[appDatasource] =
          TomDataSourceInfo(appDatasource, {});
    });
    tearDown(() {
      // The boot registers these onto the process-global registry; reset so the
      // scope registration and datasource metadata never leak between tests.
      TomDataScopeRegistry.reset();
      TomDataSourceInfo.datasources.remove('main');
      TomDataSourceInfo.datasources.remove(appDatasource);
    });

    test('each visible:* scope resolves through an async union resolver', () {
      // Before boot registration none of the three kinds is known/async.
      expect(TomDataScopeRegistry.isAsync(projectVisibilityScope), isFalse);
      expect(TomDataScopeRegistry.isAsync(listVisibilityScope), isFalse);
      expect(TomDataScopeRegistry.isAsync(itemVisibilityScope), isFalse);

      registerAppDataScopes();

      expect(TomDataScopeRegistry.isAsync(projectVisibilityScope), isTrue);
      expect(TomDataScopeRegistry.isAsync(listVisibilityScope), isTrue);
      expect(TomDataScopeRegistry.isAsync(itemVisibilityScope), isTrue);
    });
  });

  group('the resolved workspace owner scope (C-3 done-bar)', () {
    final builder = _Builder();
    final dialect = MariadbSqlDialect();

    TomColumnInformation ownerColumn() {
      final info = TomAnnotationAnalyzer.analysePersistentType(WorkspaceRecord);
      return TomAnnotationAnalyzer.determineColumn('ownerId', [info]);
    }

    test('binds the principal id against owner_id, never inlining it (C-7)', () {
      final scope = TomAnnotationAnalyzer.findDataScope(WorkspaceRecord)!;
      final col = ownerColumn();

      final alice = TomDataScope.build(builder, scope, col, _principal(2))!;
      final bob = TomDataScope.build(builder, scope, col, _principal(3))!;

      // Same parameterised SQL for both principals — the value is a bound
      // placeholder, not concatenated into the text.
      expect(alice.predicate.generate(dialect),
          'app_workspaces.owner_id IN (:__tomscope_0)');
      expect(bob.predicate.generate(dialect),
          'app_workspaces.owner_id IN (:__tomscope_0)');
      expect(alice.parameters, {'__tomscope_0': 2});
      expect(bob.parameters, {'__tomscope_0': 3});
      // The numeric id never appears in the SQL text.
      expect(alice.predicate.generate(dialect), isNot(contains('2')));
    });

    test('an unauthenticated (null) principal is denied every row', () {
      final scope = TomAnnotationAnalyzer.findDataScope(WorkspaceRecord)!;
      final denied = TomDataScope.build(builder, scope, ownerColumn(), null)!;
      // No allowed values → a FALSE predicate (never the invalid `IN ()`).
      expect(denied.predicate.generate(dialect),
          builder.boolOp(false).generate(dialect));
      expect(denied.parameters, isEmpty);
    });
  });
}
