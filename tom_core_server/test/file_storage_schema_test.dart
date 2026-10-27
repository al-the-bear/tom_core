/// Connection-free tests for the database blob store's schema, and the guard on
/// the two functions that render it.
///
/// `framework_schema_test.dart` already proves the shipped chain *builds* the
/// blob descriptors, by replaying the migrations and comparing the resulting
/// schema column by column. That is the stronger check of the two and this file
/// does not repeat it. What it adds is the check `scheduling_schema_test.dart`
/// and `audit_sql_test.dart` have had all along and file storage did not: that
/// the `CREATE TABLE` text `blobManifestTableDdl` and `blobChunkTableDdl`
/// render is the text the migration files contain.
///
/// The distinction is worth stating, because the semantic check cannot stand in
/// for the textual one. Convergence is about the schema a chain arrives at, so
/// it is deliberately blind to how a statement is spelled — a file that reached
/// the same columns by a different route would still converge. The two
/// functions render a spelling, and a spelling is what a deployment copies into
/// its own migration. Nothing measured that spelling, which is why both
/// functions could sit in the public reference with no caller anywhere: they
/// were documented, exported, and unexercised.
///
/// Both are also the answer to a question the shipped files cannot answer. A
/// store constructed with `manifestTable:` set to something else has no
/// reference migration — its DDL exists only as what these functions return for
/// that name, so a deployment that cannot run DDL has nowhere else to get it.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/sql_text.dart';

void main() {
  group('file-storage migration files match the shipped DDL', () {
    test('the manifest migration is the DDL the store creates', () {
      expect(
        normaliseSql(readMigration('file_storage', '[1]-create_tom_blob.sql')),
        normaliseSql(blobManifestTableDdl(defaultBlobManifestTable)),
      );
    });

    test('the chunk migration is the DDL the store creates', () {
      expect(
        normaliseSql(
          readMigration('file_storage', '[2]-create_tom_blob_chunk.sql'),
        ),
        normaliseSql(blobChunkTableDdl(defaultBlobChunkTable)),
      );
    });

    test('the ledger migrations are the DDL the ledger creates', () {
      expect(
        normaliseSql(
          readMigration('file_storage', '[3]-create_tom_blob_ledger.sql'),
        ),
        normaliseSql(blobLedgerTableDdl(defaultBlobLedgerTable)),
      );
      expect(
        normaliseSql(
          readMigration('file_storage', '[4]-create_tom_blob_content.sql'),
        ),
        normaliseSql(blobContentTableDdl(defaultBlobContentTable)),
      );
    });

    test('the DDL follows the table names it is given', () {
      // The whole reason the functions take a name. `TomDatabaseBlobStore`
      // accepts `manifestTable:` and `chunkTable:`, and a store over renamed
      // tables ships no migration of its own — this is where its DDL comes
      // from, and it has to name the tables the store will actually address.
      expect(
        blobManifestTableDdl('archive_blob'),
        contains('CREATE TABLE IF NOT EXISTS archive_blob'),
      );
      expect(
        blobChunkTableDdl('archive_blob_chunk'),
        contains('CREATE TABLE IF NOT EXISTS archive_blob_chunk'),
      );
    });
  });

  group('the blob schema encodes what the store relies on', () {
    final manifest = blobManifestTableDdl(defaultBlobManifestTable);
    final chunks = blobChunkTableDdl(defaultBlobChunkTable);

    test('the key column is exactly as wide as a key may be', () {
      // A narrower column would truncate a key the validator accepted, and
      // truncation on the way in is indistinguishable from a different blob on
      // the way out. Written against the constant rather than against `512` so
      // that raising the limit fails here instead of silently going one way.
      expect(
        manifest,
        contains('storage_key VARCHAR(${TomBlobStore.maxKeyLength}) NOT NULL'),
      );
    });

    test('a blob is addressed by its key alone', () {
      expect(manifest, contains('PRIMARY KEY (storage_key)'));
    });

    test('the file name is the one nullable column', () {
      // A caller may store a blob without one; every other column is written by
      // the store on every commit, so a NULL there would mean a manifest row
      // that no successful write could have produced.
      expect(manifest, contains('file_name   VARCHAR(255) NULL'));
      final nullable = manifest
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.endsWith('NULL,') && !line.contains('NOT NULL'))
          .map((line) => line.split(RegExp(r'\s+')).first);
      expect(nullable, ['file_name']);
    });

    test('write time is DATETIME(6), the width the instant convention writes', () {
      // This test previously asserted the opposite, on the grounds that a
      // blob's write time is metadata for a human rather than an ordering the
      // code depends on, so the scheduler's sub-second precision would be noise
      // here. That reasoning was about whether the precision is *useful*, and
      // it asked the wrong question.
      //
      // The column does not get to choose its width independently of what is
      // written into it. Every `DateTime` bound by this data source is rendered
      // by `sqlInstant`, which always emits six fractional digits; MariaDB does
      // not reject the extra precision on a narrower column, it silently
      // *rounds* it. So a plain `DATETIME` here did not store a coarser version
      // of the right moment — it stored a different moment, up to half a second
      // away and in whichever direction the fraction fell, and made the value
      // `put` returned unequal to the one `describe` read back.
      //
      // `DATETIME(6)` is therefore not a precision preference; it is the column
      // agreeing with its writer. `sql_instant.dart` states this as the general
      // corollary for any column holding an instant.
      expect(manifest, contains('stored_at   DATETIME(6)  NOT NULL'));
    });

    test('chunks are keyed on the upload, not on the blob', () {
      // What makes the manifest REPLACE atomic: the chunks of an in-flight
      // write are addressable before anything commits to them, so an
      // interrupted upload leaves unreferenced chunk rows rather than a
      // half-written blob.
      expect(chunks, contains('PRIMARY KEY (upload_id, chunk_index)'));
      expect(chunks, isNot(contains('storage_key')));
    });

    test('chunk content is text, because the driver decodes every column', () {
      // The MariaDB driver decodes each value into a Dart String before the row
      // mapper sees it, so a BLOB would come back mangled by UTF-8 decoding.
      // Base64 in LONGTEXT is the only correct representation available, at a
      // cost of 33 % in storage.
      expect(chunks, contains('chunk_data  LONGTEXT    NOT NULL'));
    });
  });
}
