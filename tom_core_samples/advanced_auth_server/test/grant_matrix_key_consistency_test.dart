/// Drift guard: the seeded `tom_resource_grant` matrix and the domain's
/// gradable-field keys must name the same set of `todo.item.*` resources.
///
/// Three artifacts have to agree on the scope/form/field keys — the domain
/// [TodoItemResourceKeys] constants (the single source of truth), the app
/// server's `resources_app.json` text tree, and **this** server's grant-matrix
/// seed (`database_migrations/auth_db/auth_schema/[100]-auth_sample_data.sql`).
/// This test pins the auth server's half: the distinct `resource_key`s the seed
/// grants are exactly [TodoItemResourceKeys.all], and the matrix is fully
/// populated — one row per ([ProjectRole], gradable key) pair.
///
/// Reading the SQL directly (rather than booting MariaDB) keeps this a pure unit
/// test: a key typo or a forgotten field in the seed fails here without a
/// database. The app server's text-tree half of the same invariant is pinned by
/// `advanced_app_server/test/resource_key_consistency_test.dart`.
library;

import 'dart:io';

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

/// The grant-matrix seed, resolved relative to the package root (the working
/// directory under `dart test`, the same convention the asset/migration loaders
/// use at boot).
const String _grantSeedPath =
    'database_migrations/auth_db/auth_schema/[100]-auth_sample_data.sql';

/// One seeded grant row: `(role_name, resource_key, access_level)`.
typedef _GrantRow = ({String role, String key, String access});

/// Parses every `('<role>', '<resource_key>', '<access>')` tuple in [sql] that
/// names a `todo.item.*` resource key (the gradable-field grant rows).
List<_GrantRow> _gradeGrantRows(String sql) {
  final tuple = RegExp(
    r"\(\s*'(\w+)'\s*,\s*'([\w.]+)'\s*,\s*'(\w+)'\s*\)",
  );
  return [
    for (final m in tuple.allMatches(sql))
      if (m.group(2)!.startsWith(
        '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}.',
      ))
        (role: m.group(1)!, key: m.group(2)!, access: m.group(3)!),
  ];
}

void main() {
  group('grant-matrix key consistency (RC-26)', () {
    late final List<_GrantRow> rows;

    setUpAll(() {
      final file = File(_grantSeedPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'grant seed not found at $_grantSeedPath '
            '(cwd: ${Directory.current.path})',
      );
      rows = _gradeGrantRows(file.readAsStringSync());
    });

    test('seeded resource keys equal the domain gradable-key set exactly', () {
      final keys = {for (final row in rows) row.key};
      expect(
        keys,
        equals(TodoItemResourceKeys.all.toSet()),
        reason: 'The todo.item.* keys granted in the seed must match '
            'TodoItemResourceKeys.all exactly. A difference means the grant '
            'matrix drifted from the domain key set.',
      );
    });

    test('the matrix is full — one row per (ProjectRole, gradable key)', () {
      final expectedCount =
          ProjectRole.values.length * TodoItemResourceKeys.all.length;
      expect(rows.length, expectedCount,
          reason: 'expected ${ProjectRole.values.length} roles × '
              '${TodoItemResourceKeys.all.length} keys = $expectedCount grant '
              'rows');

      // Every role grades every gradable key — no gaps in the matrix.
      for (final role in ProjectRole.values) {
        final keysForRole = {
          for (final row in rows)
            if (row.role == role.name) row.key,
        };
        expect(
          keysForRole,
          equals(TodoItemResourceKeys.all.toSet()),
          reason: 'role "${role.name}" is missing or has stray grant keys',
        );
      }
    });
  });
}
