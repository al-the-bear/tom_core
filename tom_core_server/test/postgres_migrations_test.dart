/// The PostgreSQL reference migrations are exactly what the generator writes
/// from the canonical ones — so a canonical migration changed without
/// regenerating is caught here rather than by a PostgreSQL deployment.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/generate_postgres_migrations.dart';

void main() {
  final migrations = referenceMigrations(Directory.current).toList();

  test('every canonical reference migration has a PostgreSQL form', () {
    expect(migrations, isNotEmpty);
    for (final (_, postgres) in migrations) {
      expect(
        postgres.existsSync(),
        isTrue,
        reason:
            '${p.relative(postgres.path)} is missing — run '
            'dart run tool/generate_postgres_migrations.dart',
      );
    }
  });

  test('each PostgreSQL form is the generator\'s output for its source', () {
    for (final (canonical, postgres) in migrations) {
      if (!postgres.existsSync()) continue;
      expect(
        postgres.readAsStringSync(),
        postgresMigration(
          canonicalPathOf(canonical),
          canonical.readAsStringSync(),
        ),
        reason:
            '${p.relative(postgres.path)} differs from '
            '${p.relative(canonical.path)} — run '
            'dart run tool/generate_postgres_migrations.dart',
      );
    }
  });

  test('no PostgreSQL migration is left without a canonical source', () {
    final expected = {
      for (final (_, postgres) in migrations) p.relative(postgres.path),
    };
    final example = Directory('example');
    final present = [
      for (final entity in example.listSync(recursive: true))
        if (entity is File &&
            entity.path.contains(
              '${p.separator}migrations_postgresql${p.separator}',
            ) &&
            entity.path.endsWith('.sql'))
          p.relative(entity.path),
    ];
    expect(present.where((path) => !expected.contains(path)), isEmpty);
  });
}
