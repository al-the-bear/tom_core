import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  tearDown(TomFilePickerRegistry.clear);

  group('TomFilePickers.toFileRef', () {
    test('uses the streamed opener when the picker offered one', () async {
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'big.bin',
          sizeBytes: 4,
          open: () => Stream<List<int>>.value(const [1, 2, 3, 4]),
        ),
      );
      expect(ref.source, isNotNull);
      expect(ref.bytes, isNull);
      expect(ref.sizeBytes, 4);
      expect(await ref.toSource().open().expand((c) => c).toList(), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('prefers the streamed opener over eagerly read bytes', () {
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'both.bin',
          sizeBytes: 2,
          bytes: Uint8List.fromList([9, 9]),
          open: () => Stream<List<int>>.value(const [1, 2]),
        ),
      );
      expect(ref.source, isNotNull);
      expect(ref.bytes, isNull);
    });

    test('falls back to bytes when there is no opener', () {
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(name: 'small.txt', bytes: Uint8List.fromList([1, 2, 3])),
      );
      expect(ref.bytes, isNotNull);
      // The picker reported no size, so it comes from the bytes themselves.
      expect(ref.sizeBytes, 3);
    });

    test('guesses the media type from the file name', () {
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(name: 'photo.png', bytes: Uint8List(1)),
      );
      expect(ref.mimeType, 'image/png');
    });

    test('keeps the media type the picker reported', () {
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'photo.png',
          mimeType: 'image/heic',
          bytes: Uint8List(1),
        ),
      );
      expect(ref.mimeType, 'image/heic');
    });

    test('a content-less pick is still named and sized', () {
      final ref = TomFilePickers.toFileRef(const TomPickedFile(name: 'x.pdf'));
      expect(ref.hasLocalContent, isFalse);
      expect(ref.name, 'x.pdf');
      expect(ref.sizeBytes, 0);
    });

    test('an unknown size leaves the source indeterminate', () {
      final ref = TomFilePickers.toFileRef(
        TomPickedFile(
          name: 'unknown.bin',
          open: () => Stream<List<int>>.value(const [1]),
        ),
      );
      expect(ref.sizeBytes, 0);
      expect(ref.source!.hasKnownSize, isFalse);
      expect(ref.source!.byteCount, isNull);
    });
  });

  group('TomFilePickerRegistry', () {
    test('reports no picker until one is registered', () {
      expect(TomFilePickerRegistry.hasPicker, isFalse);
      TomFilePickerRegistry.register((_) async => const []);
      expect(TomFilePickerRegistry.hasPicker, isTrue);
      TomFilePickerRegistry.clear();
      expect(TomFilePickerRegistry.hasPicker, isFalse);
    });

    test('picking without a registered picker is a wiring error', () {
      expect(
        () => TomFilePickerRegistry.pick(const TomFilePickRequest()),
        throwsStateError,
      );
    });

    test('a cancelled pick — an empty list — becomes null', () async {
      TomFilePickerRegistry.register((_) async => const []);
      expect(
        await TomFilePickerRegistry.pick(const TomFilePickRequest()),
        isNull,
      );
    });

    test('the first picked file is converted to a FileRef', () async {
      TomFilePickerRegistry.register(
        (_) async => [
          TomPickedFile(name: 'first.txt', bytes: Uint8List.fromList([1])),
          TomPickedFile(name: 'second.txt', bytes: Uint8List.fromList([2])),
        ],
      );
      final ref = await TomFilePickerRegistry.pick(const TomFilePickRequest());
      expect(ref!.name, 'first.txt');
    });

    test('the field\'s constraints reach the adaptor', () async {
      late TomFilePickRequest seen;
      TomFilePickerRegistry.register((request) async {
        seen = request;
        return const [];
      });
      await TomFilePickerRegistry.pick(
        const TomFilePickRequest(
          allowedExtensions: ['png', 'jpg'],
          maxSizeBytes: 1024,
          kind: TomFilePickKind.image,
        ),
      );
      expect(seen.allowedExtensions, ['png', 'jpg']);
      expect(seen.maxSizeBytes, 1024);
      expect(seen.kind, TomFilePickKind.image);
    });

    test('registering again replaces the previous adaptor', () async {
      TomFilePickerRegistry.register(
        (_) async => [const TomPickedFile(name: 'old.txt')],
      );
      TomFilePickerRegistry.register(
        (_) async => [const TomPickedFile(name: 'new.txt')],
      );
      final ref = await TomFilePickerRegistry.pick(const TomFilePickRequest());
      expect(ref!.name, 'new.txt');
    });
  });

  group('TomFilePickers callbacks', () {
    testWidgets('registered() routes through the registry', (tester) async {
      TomFilePickerRegistry.register(
        (_) async => [const TomPickedFile(name: 'via-registry.txt')],
      );
      final picker = TomFilePickers.registered(
        allowedExtensions: const ['txt'],
      );

      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      );

      final ref = await picker(captured);
      expect(ref!.name, 'via-registry.txt');
    });

    testWidgets('fixed() always returns the same reference', (tester) async {
      const ref = FileRef(name: 'demo.pdf', sizeBytes: 12);
      final picker = TomFilePickers.fixed(ref);

      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(await picker(captured), same(ref));
    });
  });
}
