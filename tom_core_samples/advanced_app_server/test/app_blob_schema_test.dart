/// The convergence guard on this server's copy of the framework blob tables.
///
/// `tom_blob` / `tom_blob_chunk` are the framework's tables, but the DDL that
/// creates them here is *ours*: `[003]-app_blob_tables.sql` is a file in this
/// repository, and the store that reads and writes those tables builds its
/// statements from `blobManifestTable()` / `blobChunkTable()` in
/// `tom_core_server`. Two spellings of the same schema, in two repositories, and
/// nothing but this test relating them.
///
/// The failure it exists to catch is quiet. A column the framework renames, or
/// widens, or adds is a change to the descriptor; the migration file here does
/// not move with it, and nothing fails to compile. The first symptom would be an
/// upload that half-succeeds against a real database — and the sample would
/// teach a broken schema to everyone who copied it.
///
/// The whole applied chain is passed, not just the blob migration: what is worth
/// asserting is that `app_db` *as this server migrates it* ends up with the right
/// blob tables, so a later migration that alters them is caught too. The check
/// narrows the comparison to the tables it was given, so the application's own
/// tables in the same chain are neither compared nor reported.
///
/// Connection-free — the chain is replayed through the framework's own DDL
/// reader, so this runs in the ordinary suite rather than behind a `db` tag.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// The app schema migration directory, relative to the package root (the working
/// directory under `dart test`, matching the boot-time loader).
const String _appSchemaDir = 'database_migrations/system/app_db/app_schema/';

/// The shipped migration chain under [directory], in file order.
///
/// Read from disk rather than re-typed, so what is replayed is the SQL the
/// server actually applies at boot and not a parallel copy of it.
List<TomMigrationArtifact> _chain(String directory) {
  final files = Directory(directory).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      TomMigrationArtifact(file.uri.pathSegments.last, file.readAsStringSync()),
  ];
}

void main() {
  group('the app_db chain builds the framework blob tables', () {
    final check = TomFrameworkSchemaCheck();

    test('tom_blob and tom_blob_chunk match the framework descriptors', () {
      final report = check.verifyChain(
        datasource: 'app_db',
        schema: 'app_schema',
        tables: [
          blobManifestTable(defaultBlobManifestTable),
          blobChunkTable(defaultBlobChunkTable),
        ],
        chain: _chain(_appSchemaDir),
      );
      expect(report.converged, isTrue, reason: report.describe());
    });

    test('the blob store is configured to leave that schema alone', () {
      // The migration above is only the single source of the blob schema while
      // the store is told not to provision one of its own. With `createSchema`
      // left at its default the store would issue its own CREATE TABLE at boot —
      // harmless while the two agree, and a silent divergence the moment they do
      // not, at which point the test above would still pass against a schema
      // nobody applied. So the setting is asserted rather than assumed.
      final settings = TomYaml.loadYamlFile('assets/blobstores_default.yaml');
      final files = settings['files'] as Map;
      expect(files['createSchema'], isFalse);
      // And the store must name this server's *own* database. The `main`
      // datasource deliberately points at the auth server's DB to read the
      // shared grant matrix, so a store that fell back to the default would put
      // item attachments in auth_db and quietly dissolve the sample's
      // two-database boundary.
      expect(files['datasource'], 'app_db');
    });
  });
}
