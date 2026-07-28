/// Tests for the file-reference column's declarative half (CSFS1).
///
/// A `@TomFileReference` column holds a storage *key*; the bytes live in a blob
/// store. Two things can be checked without a database: the key scheme
/// ([TomFileReferenceKeys]), which is a pure function of the annotation, a name
/// and a clock; and the analyzer's resolution of the annotation onto reflected
/// columns, which is what the repository's upload/download/cascade paths read.
/// The round-trip through a live repository is in `file_storage_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureDocumentRecord, FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  group('TomFileReferenceKeys.extensionOf', () {
    test('carries a short alphanumeric extension, lower-cased', () {
      expect(TomFileReferenceKeys.extensionOf('Report.PDF'), '.pdf');
      expect(TomFileReferenceKeys.extensionOf('archive.tar.gz'), '.gz');
      expect(TomFileReferenceKeys.extensionOf('sheet.xlsx'), '.xlsx');
    });

    test('carries nothing when there is nothing worth carrying', () {
      expect(TomFileReferenceKeys.extensionOf(null), '');
      expect(TomFileReferenceKeys.extensionOf('no-extension'), '');
      expect(TomFileReferenceKeys.extensionOf('trailing.'), '');
    });

    test('refuses anything that is not a plain short suffix', () {
      // The extension is appended to a key whose grammar is narrow, and a
      // "file name" from a browser is caller-supplied text, not an identifier.
      expect(TomFileReferenceKeys.extensionOf('evil.p df'), '');
      expect(TomFileReferenceKeys.extensionOf('evil.../etc'), '');
      expect(TomFileReferenceKeys.extensionOf('x.${'a' * 13}'), '');
      expect(TomFileReferenceKeys.extensionOf('x.${'a' * 12}'), '.${'a' * 12}');
    });
  });

  group('TomFileReferenceKeys.generate', () {
    const reference = TomFileReference(keyPrefix: 'documents/attachment');

    test('partitions by prefix and year/month, and ends in a UUID', () {
      final key = TomFileReferenceKeys.generate(
        reference,
        fileName: 'Quarterly Report.pdf',
        now: DateTime(2026, 7, 28),
      );
      expect(key, startsWith('documents/attachment/2026/07/'));
      expect(key, endsWith('.pdf'));
      final uuid = key.split('/').last.split('.').first;
      expect(
        uuid,
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      );
    });

    test('pads a single-digit month so keys sort', () {
      final key = TomFileReferenceKeys.generate(
        reference,
        now: DateTime(2026, 3, 4),
      );
      expect(key, startsWith('documents/attachment/2026/03/'));
    });

    test('omits the prefix segment when the annotation declares none', () {
      final key = TomFileReferenceKeys.generate(
        const TomFileReference(),
        now: DateTime(2026, 7, 28),
      );
      expect(key, startsWith('2026/07/'));
    });

    test('never repeats a key', () {
      final keys = {
        for (var i = 0; i < 200; i++)
          TomFileReferenceKeys.generate(reference, now: DateTime(2026, 7, 28)),
      };
      expect(keys, hasLength(200));
    });

    test('always produces a key every backend will accept', () {
      for (final name in const [
        null,
        'plain.pdf',
        'has space.PDF',
        '../escape.txt',
        'no-extension',
      ]) {
        final key = TomFileReferenceKeys.generate(reference, fileName: name);
        expect(TomBlobStore.isValidKey(key), isTrue, reason: '$name -> $key');
      }
    });
  });

  group('TomFileReferenceKeys.storeFor', () {
    tearDown(TomBlobStoreInfo.closeAll);

    test('an annotation naming no store resolves to the default', () {
      final store = TomMemoryBlobStore();
      TomBlobStoreInfo.register('files', store, asDefault: true);
      expect(
        TomFileReferenceKeys.storeFor(const TomFileReference()),
        same(store),
      );
    });

    test('an annotation naming a store resolves that one', () {
      final archive = TomMemoryBlobStore();
      TomBlobStoreInfo.register('scratch', TomMemoryBlobStore(),
          asDefault: true);
      TomBlobStoreInfo.register('archive', archive);
      expect(
        TomFileReferenceKeys.storeFor(const TomFileReference(store: 'archive')),
        same(archive),
      );
    });

    test('a store that is not configured is a named error', () {
      // Resolved per call rather than captured, so a typo surfaces as this
      // rather than as a write to the wrong place.
      expect(
        () => TomFileReferenceKeys.storeFor(
          const TomFileReference(store: 'nosuchstore'),
        ),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.registry.unknown_store'),
        ),
      );
    });
  });

  group('TomAnnotationAnalyzer.findFileColumns', () {
    setUpAll(initializeReflection);

    test('resolves every file column of an entity, with its annotation', () {
      final columns =
          TomAnnotationAnalyzer.findFileColumns(FixtureDocumentRecord);
      expect(
        columns.map((c) => c.declaredName),
        unorderedEquals(['attachment', 'secretAttachment']),
      );

      final attachment =
          columns.firstWhere((c) => c.declaredName == 'attachment');
      expect(attachment.fileReference!.keyPrefix, 'fixture/attachment');
      expect(attachment.fileReference!.cascadeDelete, isTrue);
      expect(attachment.fileReference!.store, isNull);
      expect(attachment.getQueryFieldName(), 'attachment');

      final secret =
          columns.firstWhere((c) => c.declaredName == 'secretAttachment');
      expect(secret.fileReference!.keyPrefix, 'fixture/secret');
      expect(secret.fileReference!.cascadeDelete, isFalse);
      // The key column is an ordinary column, so C-4 governs it as it governs
      // any other — that is the whole authorization story for stored files.
      expect(secret.column!.authKey, 'fixture.document.secret_attachment');
      expect(secret.getQueryFieldName(), 'secret_attachment');
    });

    test('an entity with no stored files resolves to an empty list', () {
      // The short-circuit every repository path checks first, so an ordinary
      // entity pays nothing for the feature.
      expect(TomAnnotationAnalyzer.findFileColumns(FixtureTaskRecord), isEmpty);
    });
  });
}
