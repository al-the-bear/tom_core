import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('TomFileRef — content forms', () {
    test('a bytes reference carries local content and no storage key', () {
      final ref = TomFileRef(
        name: 'note.txt',
        sizeBytes: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(ref.hasLocalContent, isTrue);
      expect(ref.isStored, isFalse);
    });

    test('a source reference carries local content', () {
      final ref = TomFileRef(
        name: 'big.bin',
        sizeBytes: 10,
        source: TomFileSource.stream(
          fileName: 'big.bin',
          byteCount: 10,
          open: () => Stream<List<int>>.value(List.filled(10, 7)),
        ),
      );
      expect(ref.hasLocalContent, isTrue);
    });

    test('a name-only reference has neither content nor a key', () {
      const ref = TomFileRef(name: 'ghost.pdf', sizeBytes: 0);
      expect(ref.hasLocalContent, isFalse);
      expect(ref.isStored, isFalse);
    });

    test('TomFileRef.stored describes a file that is only on the server', () {
      final ref = TomFileRef.stored(
        const TomFileMetadata(
          key: 'invoices/2026/07/abc.pdf',
          mediaType: 'application/pdf',
          byteCount: 4096,
          fileName: 'invoice.pdf',
        ),
      );
      expect(ref.name, 'invoice.pdf');
      expect(ref.sizeBytes, 4096);
      expect(ref.mimeType, 'application/pdf');
      expect(ref.storageKey, 'invoices/2026/07/abc.pdf');
      expect(ref.isStored, isTrue);
      expect(ref.hasLocalContent, isFalse);
    });

    test(
      'TomFileRef.stored falls back to the key\'s last segment for a name',
      () {
        final ref = TomFileRef.stored(
          const TomFileMetadata(
            key: 'scans/2026/07/9f2.png',
            mediaType: 'image/png',
            byteCount: 12,
          ),
        );
        expect(ref.name, '9f2.png');
      },
    );
  });

  group('TomFileRef — toSource', () {
    test('prefers the streamed source over in-memory bytes', () {
      final source = TomFileSource.stream(
        fileName: 'streamed.bin',
        open: () => Stream<List<int>>.value(const [1]),
      );
      final ref = TomFileRef(
        name: 'streamed.bin',
        sizeBytes: 1,
        bytes: Uint8List.fromList([9, 9, 9]),
        source: source,
      );
      expect(identical(ref.toSource(), source), isTrue);
    });

    test('wraps bytes in a source that can be opened twice', () async {
      final ref = TomFileRef(
        name: 'note.txt',
        sizeBytes: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final source = ref.toSource();
      expect(await source.open().expand((c) => c).toList(), [1, 2, 3]);
      expect(await source.open().expand((c) => c).toList(), [1, 2, 3]);
    });

    test('throws when there is nothing to send', () {
      const ref = TomFileRef(name: 'ghost.pdf', sizeBytes: 0);
      expect(ref.toSource, throwsStateError);
    });
  });

  group('TomFileRef — extension', () {
    test('is the lowercased text after the last dot', () {
      expect(
        const TomFileRef(name: 'Report.PDF', sizeBytes: 0).extension,
        'pdf',
      );
      expect(
        const TomFileRef(name: 'archive.tar.gz', sizeBytes: 0).extension,
        'gz',
      );
    });

    test('is empty when the name has no dot', () {
      expect(const TomFileRef(name: 'README', sizeBytes: 0).extension, '');
    });
  });

  group('TomFileRef — copyWith and equality', () {
    test('copyWith adds a storage key without losing the content', () {
      final ref = TomFileRef(
        name: 'note.txt',
        sizeBytes: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final stored = ref.copyWith(storageKey: 'notes/2026/07/x.txt');
      expect(stored.isStored, isTrue);
      expect(stored.hasLocalContent, isTrue);
      expect(stored.name, ref.name);
    });

    test('the storage key participates in equality', () {
      const a = TomFileRef(name: 'n', sizeBytes: 1);
      const b = TomFileRef(name: 'n', sizeBytes: 1, storageKey: 'k');
      expect(a, isNot(equals(b)));
      expect(a, equals(const TomFileRef(name: 'n', sizeBytes: 1)));
      expect(b.hashCode, isNot(equals(a.hashCode)));
    });
  });
}
