/// Drift guard: the seeded `tom_resource_grant` matrix and the gradable item
/// field keys must name the same set of `todo.item.*` resources.
///
/// Three artifacts have to agree on the scope/form/field keys — the gradable
/// item key set (`todo.item.<field>`, the wire contract each side addresses),
/// the app server's `resources_app.json` text tree, and **this** server's
/// grant-matrix seed
/// (`database_migrations/auth_db/auth_schema/[100]-auth_sample_data.sql`).
/// This test pins the auth server's half: the distinct `resource_key`s the seed
/// grants are exactly the gradable item key set, and the matrix is fully
/// populated — one row per ([ProjectRole], gradable key) pair.
///
/// (G-RES-6: addressing is by scope + `tomId`, so there is no catalogue class;
/// steps 21/24/26 derive the gradable set from reflection/the resource bundle.
/// Until then the expected set is the inline literals below.)
///
/// Reading the SQL directly (rather than booting MariaDB) keeps this a pure unit
/// test: a key typo or a forgotten field in the seed fails here without a
/// database. The app server's text-tree half of the same invariant is pinned by
/// `advanced_app_server/test/resource_key_consistency_test.dart`.
library;

import 'dart:io';

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

/// The gradable item resource keys. Steps 21/24/26 derive this from
/// reflection/the resource bundle; here it is the inline expectation this drift
/// guard checks the seed against.
const _gradableItemKeys = <String>[
  'todo.item.title',
  'todo.item.status',
  'todo.item.priority',
  'todo.item.assigneeId',
  'todo.item.dueDate',
  'todo.item.estimate',
  'todo.item.description',
];

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
      if (m.group(2)!.startsWith('todo.item.'))
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

    test('seeded resource keys equal the gradable item key set exactly', () {
      final keys = {for (final row in rows) row.key};
      expect(
        keys,
        equals(_gradableItemKeys.toSet()),
        reason: 'The todo.item.* keys granted in the seed must match the '
            'gradable item key set exactly. A difference means the grant '
            'matrix drifted from the field key set.',
      );
    });

    test('the matrix is full — one row per (ProjectRole, gradable key)', () {
      final expectedCount =
          ProjectRole.values.length * _gradableItemKeys.length;
      expect(rows.length, expectedCount,
          reason: 'expected ${ProjectRole.values.length} roles × '
              '${_gradableItemKeys.length} keys = $expectedCount grant '
              'rows');

      // Every role grades every gradable key — no gaps in the matrix.
      for (final role in ProjectRole.values) {
        final keysForRole = {
          for (final row in rows)
            if (row.role == role.name) row.key,
        };
        expect(
          keysForRole,
          equals(_gradableItemKeys.toSet()),
          reason: 'role "${role.name}" is missing or has stray grant keys',
        );
      }
    });
  });
}
