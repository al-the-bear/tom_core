/// Step 20 done-bar guard (G-MIG-1/2/3): the `auth_db` migration filenames are
/// numbered consecutively and tagged so a **production** apply seeds the admin
/// account while omitting every demo user.
///
/// This is a pure, connection-free check: it parses the migration *filenames*
/// with the framework's own `TomDbMigrations.parseMigrationFileName` (the same
/// parser the boot-time runner uses) and asserts the environment tags, so a
/// mis-numbered or mis-tagged migration fails here without booting MariaDB.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// The auth schema migration directory, relative to the package root (the
/// working directory under `dart test`, matching the boot-time loader).
const String _authSchemaDir =
    'database_migrations/auth_db/auth_schema/';

/// Parses every `*.sql` migration basename in [dir] into `(version, parsed)`
/// records ordered by ascending numeric version.
List<({int version, TomMigrationFileName parsed})> _migrations(String dir) {
  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .map((f) {
        final name = f.uri.pathSegments.last;
        final basename = name.substring(0, name.length - '.sql'.length);
        final parsed = TomDbMigrations.parseMigrationFileName(basename);
        return (version: parsed.version, parsed: parsed);
      })
      .toList()
    ..sort((a, b) => a.version.compareTo(b.version));
  return files;
}

void main() {
  group('auth_db migration environment tagging (Step 20 / G-MIG-1/2/3)', () {
    late final List<({int version, TomMigrationFileName parsed})> migrations;

    setUpAll(() => migrations = _migrations(_authSchemaDir));

    test('versions are numbered consecutively from 0 with no gaps', () {
      expect(migrations.map((m) => m.version), [0, 1, 2, 3],
          reason: 'auth_db migrations must be [000],[001],[002],[003]');
    });

    test('schema + admin seed are untagged; the demo seed is @dev,test', () {
      final byDesc = {
        for (final m in migrations) m.parsed.description: m.parsed,
      };

      // Schema (DDL) and the admin bootstrap carry no environment tag — they
      // apply in *every* environment, production included.
      for (final desc in const [
        'auth_core_schema',
        'auth_authz_grants',
        'auth_admin_seed',
      ]) {
        expect(byDesc[desc]!.environments, isEmpty,
            reason: '$desc must be untagged (applies in every environment)');
      }

      // The demo seed is restricted to dev/test.
      expect(byDesc['auth_demo_seed']!.environments, ['dev', 'test']);
    });

    test('a production apply seeds admin without demo users (done-bar)', () {
      bool appliesIn(String env, String desc) =>
          migrations.firstWhere((m) => m.parsed.description == desc)
              .parsed
              .appliesInEnvironment(env);

      // Under production: schema + admin apply, the demo seed is skipped.
      expect(appliesIn('production', 'auth_core_schema'), isTrue);
      expect(appliesIn('production', 'auth_admin_seed'), isTrue);
      expect(appliesIn('production', 'auth_demo_seed'), isFalse);

      // Under dev/test: the demo seed applies too.
      expect(appliesIn('dev', 'auth_demo_seed'), isTrue);
      expect(appliesIn('test', 'auth_demo_seed'), isTrue);
    });
  });
}
