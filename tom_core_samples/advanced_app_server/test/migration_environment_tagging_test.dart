/// Step 20 done-bar guard (G-MIG-1/2/3): the `app_db` migration filenames are
/// numbered consecutively and the demo seed is tagged so a **production** apply
/// creates the schema but skips the demo content (the app comes up empty).
///
/// A pure, connection-free check against the framework's own
/// `TomDbMigrations.parseMigrationFileName` — a mis-numbered or mis-tagged
/// migration fails here without booting MariaDB.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// The app schema migration directory, relative to the package root.
const String _appSchemaDir = 'database_migrations/app_db/app_schema/';

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
  group('app_db migration environment tagging (Step 20 / G-MIG-1/2/3)', () {
    late final List<({int version, TomMigrationFileName parsed})> migrations;

    setUpAll(() => migrations = _migrations(_appSchemaDir));

    test('versions are numbered consecutively from 0 with no gaps', () {
      expect(migrations.map((m) => m.version), [0, 1],
          reason: 'app_db migrations must be [000],[001]');
    });

    test('schema is untagged; the demo seed is @dev,test', () {
      final byDesc = {
        for (final m in migrations) m.parsed.description: m.parsed,
      };
      expect(byDesc['app_core_schema']!.environments, isEmpty,
          reason: 'the schema DDL applies in every environment');
      expect(byDesc['app_demo_seed']!.environments, ['dev', 'test']);
    });

    test('a production apply creates the schema but skips demo content', () {
      TomMigrationFileName forDesc(String desc) =>
          migrations.firstWhere((m) => m.parsed.description == desc).parsed;

      expect(forDesc('app_core_schema').appliesInEnvironment('production'),
          isTrue);
      expect(forDesc('app_demo_seed').appliesInEnvironment('production'),
          isFalse);
      expect(forDesc('app_demo_seed').appliesInEnvironment('dev'), isTrue);
    });
  });
}
