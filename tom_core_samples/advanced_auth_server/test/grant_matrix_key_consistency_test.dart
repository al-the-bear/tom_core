/// Drift guard: the seeded `tom_resource_grant` matrix must agree with the
/// shared domain grade maps — same `todo.item.*` keys, same grade in every cell.
///
/// The sample carries the four-state grade matrix twice on purpose. The domain's
/// [projectRoleFieldGrades] / [projectRoleAttachmentGrades] are the **client's**
/// copy, used to shape the item form; the rows this seed writes are the
/// **server's**, and are what the app server enforces on a write and the
/// authadmin console edits. The duality is the point — an administrator's edit
/// changes the server's answer and not the client's map, and the server's answer
/// is the binding one. But the two must *start* identical, or a first run tells
/// two different stories about the same role, and nothing at runtime compares
/// them. This test is that comparison.
///
/// Three artifacts have to agree on the scope/form/field keys — the graded item
/// key set (`todo.item.<name>`, the wire contract each side addresses), the app
/// server's `resources_app.json` text tree, and **this** server's grant-matrix
/// seed
/// (`database_migrations/auth_db/auth_schema/[003]-auth_demo_seed@dev,test.sql`).
/// This test pins the auth server's half: the distinct `resource_key`s the seed
/// grants are exactly the graded item key set, and the matrix is fully
/// populated — one row per ([ProjectRole], graded key) pair.
///
/// The graded set is **not** the gradable *field* set alone. It is the item's
/// gradable **form fields** *plus* the authorized **columns** the file endpoint
/// grades per row — currently [itemAttachmentGradeKey]. Both kinds are
/// graded from this one table by the same four roles; they differ only in where
/// the grade is enforced (the item write path's field overlay vs.
/// `saveFile`/`openFile`). Splitting them here keeps that distinction visible
/// instead of letting a column silently join the form-field set.
///
/// (G-RES-6: addressing is by scope + `tomId`, so there is no catalogue class —
/// the expected key set is the domain's own [gradableItemKeys] plus
/// [itemAttachmentGradeKey], not a list re-typed here.)
///
/// Reading the SQL directly (rather than booting MariaDB) keeps this a pure unit
/// test: a key typo, a forgotten field or a changed grade fails here without a
/// database and without the live two-server stack. The app server's text-tree
/// half of the same invariant is pinned by
/// `advanced_app_server/test/resource_key_consistency_test.dart`.
library;

import 'dart:io';

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';

/// The graded item **column** resource keys — values no client may write
/// directly, graded on the file endpoint instead of in the item payload.
const _gradedItemColumnKeys = <String>[itemAttachmentGradeKey];

/// Every `todo.item.*` resource the seed must grant, of either kind: the
/// gradable form fields plus the graded columns.
const _gradedItemKeys = <String>[...gradableItemKeys, ..._gradedItemColumnKeys];

/// The grant-matrix seed, resolved relative to the package root (the working
/// directory under `dart test`, the same convention the asset/migration loaders
/// use at boot).
const String _grantSeedPath =
    'database_migrations/auth_db/auth_schema/[003]-auth_demo_seed@dev,test.sql';

/// One seeded grant row: `(role_name, resource_key, access_level)`.
typedef _GrantRow = ({String role, String key, String access});

/// Parses every `('<role>', '<resource_key>', '<access>')` tuple in [sql] that
/// names a `todo.item.*` resource key (the gradable-field grant rows).
List<_GrantRow> _gradeGrantRows(String sql) {
  final tuple = RegExp(r"\(\s*'(\w+)'\s*,\s*'([\w.]+)'\s*,\s*'(\w+)'\s*\)");
  return [
    for (final m in tuple.allMatches(sql))
      if (m.group(2)!.startsWith('todo.item.'))
        (role: m.group(1)!, key: m.group(2)!, access: m.group(3)!),
  ];
}

void main() {
  group('grant-matrix key consistency', () {
    late final List<_GrantRow> rows;

    setUpAll(() {
      final file = File(_grantSeedPath);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'grant seed not found at $_grantSeedPath '
            '(cwd: ${Directory.current.path})',
      );
      rows = _gradeGrantRows(file.readAsStringSync());
    });

    test('seeded resource keys equal the graded item key set exactly', () {
      final keys = {for (final row in rows) row.key};
      expect(
        keys,
        equals(_gradedItemKeys.toSet()),
        reason:
            'The todo.item.* keys granted in the seed must match the '
            'graded item key set — the gradable fields plus the graded '
            'columns — exactly. A difference means the grant matrix drifted '
            'from the key set.',
      );
    });

    test('the matrix is full — one row per (ProjectRole, graded key)', () {
      final expectedCount = ProjectRole.values.length * _gradedItemKeys.length;
      expect(
        rows.length,
        expectedCount,
        reason:
            'expected ${ProjectRole.values.length} roles × '
            '${_gradedItemKeys.length} keys = $expectedCount grant '
            'rows',
      );

      // Every role grades every graded key — no gaps in the matrix.
      for (final role in ProjectRole.values) {
        final keysForRole = {
          for (final row in rows)
            if (row.role == role.name) row.key,
        };
        expect(
          keysForRole,
          equals(_gradedItemKeys.toSet()),
          reason: 'role "${role.name}" is missing or has stray grant keys',
        );
      }
    });

    test('every seeded field grade equals the shared domain map', () {
      final seeded = {
        for (final row in rows)
          if (row.key != itemAttachmentGradeKey)
            (row.role, row.key): row.access,
      };
      for (final role in ProjectRole.values) {
        for (final key in gradableItemKeys) {
          expect(
            seeded[(role.name, key)],
            projectRoleFieldGrades[role]![key]!.name,
            reason:
                'seeded grade for "${role.name}" × "$key" must match '
                'projectRoleFieldGrades — the client shapes its item form from '
                'the domain map and this table is what the app server enforces, '
                'so a first run would tell two different stories about the '
                'same role',
          );
        }
      }
    });

    test(
      'the attachment column is graded for every role, read at the weakest',
      () {
        final seeded = {
          for (final row in rows)
            if (row.key == itemAttachmentGradeKey) row.role: row.access,
        };
        expect(
          seeded.keys.toSet(),
          equals({for (final role in ProjectRole.values) role.name}),
          reason:
              'the file endpoint resolves its attachment grade from this '
              'table, so '
              'a role with no attachment row would resolve to `none` and be '
              'refused even the download',
        );
        // The seed is the *initial* state of the matrix — an administrator may
        // narrow any of these through the authadmin console at runtime, and the
        // server honours the edited row, not this file. What is pinned here is
        // that the initial state matches the client's default shaping map, so a
        // first run shows a consistent story on both tiers.
        for (final role in ProjectRole.values) {
          expect(
            seeded[role.name],
            projectRoleAttachmentGrades[role]!.name,
            reason:
                'seeded attachment grade for "${role.name}" must match '
                'projectRoleAttachmentGrades, the client-side default the item '
                'screen shapes the upload field with',
          );
        }
      },
    );
  });
}
