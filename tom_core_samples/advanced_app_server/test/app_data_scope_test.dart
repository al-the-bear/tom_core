/// Connection-free C-3 row-scope tests for the app records (RCC4).
///
/// The framework `@TomDbScope` filters a repository read to the current
/// principal's allowed values at the database. The advanced sample declares it
/// on exactly one entity — [WorkspaceRecord] — because a workspace's read
/// visibility is *owner-only*: a workspace is reachable iff the caller owns it,
/// and shares never target or flow up to one. The project/list/item records are
/// deliberately left unscoped: their visibility folds ownership *and*
/// `share`-mode delegations over the containment chain, which a single-column
/// `IN (…)` scope would AND-hide (dropping legitimately shared rows), so they
/// keep the [ResourceRoleResolver] filter instead.
///
/// The repository enforcement itself needs a live data source (exercised live in
/// the RCC5 integration script); here we verify the two facts that need no
/// connection: the annotation is present (and only where intended), and the
/// scope it resolves is the owner predicate riding the prepared-statement
/// protocol (the value is bound, never inlined — C-7).
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

    test('the project/list/item records are deliberately unscoped', () {
      // Their share + containment visibility cannot be a single-column scope,
      // so they must NOT declare one (else shared rows would be AND-hidden).
      expect(TomAnnotationAnalyzer.findDataScope(ProjectRecord), isNull);
      expect(TomAnnotationAnalyzer.findDataScope(ListRecord), isNull);
      expect(TomAnnotationAnalyzer.findDataScope(ItemRecord), isNull);
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
