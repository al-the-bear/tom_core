/// Migration-naming guard (G-MIG-1/2/3): the `app_db` migration filenames are
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
  final files =
      Directory(dir)
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
  group('app_db migration environment tagging (G-MIG-1/2/3)', () {
    late final List<({int version, TomMigrationFileName parsed})> migrations;

    setUpAll(() => migrations = _migrations(_appSchemaDir));

    test('versions are numbered consecutively from 0 with no gaps', () {
      // Stated as the property rather than as a literal inventory (matching the
      // auth server's equivalent guard): adding a migration is routine, and a
      // list that has to be edited each time would fail for the wrong reason and
      // teach the reader to just bump it.
      expect(migrations, isNotEmpty);
      expect(
        migrations.map((m) => m.version),
        List.generate(migrations.length, (index) => index),
        reason:
            'app_db migrations must run [000], [001], … with no gaps and '
            'no duplicates',
      );
    });

    test('schema is untagged; the demo seed is @dev,test', () {
      final byDesc = {
        for (final m in migrations) m.parsed.description: m.parsed,
      };
      for (final desc in const [
        'app_core_schema',
        // The file-reference columns and the blob tables that hold their bytes
        // are schema, not content: a production deployment that skipped them
        // would accept an upload and then have nowhere to put it.
        'app_file_columns',
        'app_blob_tables',
      ]) {
        expect(
          byDesc[desc]!.environments,
          isEmpty,
          reason: '$desc must be untagged (applies in every environment)',
        );
      }
      expect(byDesc['app_demo_seed']!.environments, ['dev', 'test']);
    });

    test('a production apply creates the schema but skips demo content', () {
      bool appliesIn(String env, String desc) => migrations
          .firstWhere((m) => m.parsed.description == desc)
          .parsed
          .appliesInEnvironment(env);

      expect(appliesIn('production', 'app_core_schema'), isTrue);
      expect(appliesIn('production', 'app_file_columns'), isTrue);
      expect(appliesIn('production', 'app_blob_tables'), isTrue);
      expect(appliesIn('production', 'app_demo_seed'), isFalse);
      expect(appliesIn('dev', 'app_demo_seed'), isTrue);
    });
  });
}
