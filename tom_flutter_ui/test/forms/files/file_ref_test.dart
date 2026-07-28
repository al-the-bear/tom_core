import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/files/file_ref.dart';

void main() {
  group('FileRef — content forms', () {
    test('a bytes reference carries local content and no storage key', () {
      final ref = FileRef(
        name: 'note.txt',
        sizeBytes: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(ref.hasLocalContent, isTrue);
      expect(ref.isStored, isFalse);
    });

    test('a source reference carries local content', () {
      final ref = FileRef(
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
      const ref = FileRef(name: 'ghost.pdf', sizeBytes: 0);
      expect(ref.hasLocalContent, isFalse);
      expect(ref.isStored, isFalse);
    });

    test('FileRef.stored describes a file that is only on the server', () {
      final ref = FileRef.stored(
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

    test('FileRef.stored falls back to the key\'s last segment for a name', () {
      final ref = FileRef.stored(
        const TomFileMetadata(
          key: 'scans/2026/07/9f2.png',
          mediaType: 'image/png',
          byteCount: 12,
        ),
      );
      expect(ref.name, '9f2.png');
    });
  });

  group('FileRef — toSource', () {
    test('prefers the streamed source over in-memory bytes', () {
      final source = TomFileSource.stream(
        fileName: 'streamed.bin',
        open: () => Stream<List<int>>.value(const [1]),
      );
      final ref = FileRef(
        name: 'streamed.bin',
        sizeBytes: 1,
        bytes: Uint8List.fromList([9, 9, 9]),
        source: source,
      );
      expect(identical(ref.toSource(), source), isTrue);
    });

    test('wraps bytes in a source that can be opened twice', () async {
      final ref = FileRef(
        name: 'note.txt',
        sizeBytes: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      final source = ref.toSource();
      expect(await source.open().expand((c) => c).toList(), [1, 2, 3]);
      expect(await source.open().expand((c) => c).toList(), [1, 2, 3]);
    });

    test('throws when there is nothing to send', () {
      const ref = FileRef(name: 'ghost.pdf', sizeBytes: 0);
      expect(ref.toSource, throwsStateError);
    });
  });

  group('FileRef — extension', () {
    test('is the lowercased text after the last dot', () {
      expect(const FileRef(name: 'Report.PDF', sizeBytes: 0).extension, 'pdf');
      expect(
        const FileRef(name: 'archive.tar.gz', sizeBytes: 0).extension,
        'gz',
      );
    });

    test('is empty when the name has no dot', () {
      expect(const FileRef(name: 'README', sizeBytes: 0).extension, '');
    });
  });

  group('FileRef — copyWith and equality', () {
    test('copyWith adds a storage key without losing the content', () {
      final ref = FileRef(
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
      const a = FileRef(name: 'n', sizeBytes: 1);
      const b = FileRef(name: 'n', sizeBytes: 1, storageKey: 'k');
      expect(a, isNot(equals(b)));
      expect(a, equals(const FileRef(name: 'n', sizeBytes: 1)));
      expect(b.hashCode, isNot(equals(a.hashCode)));
    });
  });
}
