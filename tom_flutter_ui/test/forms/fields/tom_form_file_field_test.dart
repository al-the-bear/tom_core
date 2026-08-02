import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_file_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_file_field.dart';
import 'package:tom_flutter_ui/src/forms/files/tom_file_labels.dart';
import 'package:tom_flutter_ui/src/forms/files/tom_file_picker_registry.dart';
import 'package:tom_flutter_ui/src/forms/form_field_family.dart';
import 'package:tom_flutter_ui/src/forms/validation/validation_result.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Widget _wrapCupertino(Widget child) =>
    CupertinoApp(home: CupertinoPageScaffold(child: Center(child: child)));

/// Installs [tree] as the application's resources, replacing whatever was
/// there — the file widgets read their wording through this provider.
void _installResources(Map<String, dynamic> tree) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(tree),
  );
}

FileRef _localRef(String name, {int size = 4}) => FileRef(
  name: name,
  sizeBytes: size,
  bytes: Uint8List.fromList(List.filled(size, 1)),
);

/// A 1×1 transparent PNG.
///
/// A *decodable* image, not four filler bytes: the thumbnail hands these to
/// `Image.memory`, and a payload the codec rejects would exercise the error
/// path instead of the one under test.
final Uint8List _pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

FileRef _pngRef([String name = 'face.png']) => FileRef(
  name: name,
  sizeBytes: _pngBytes.length,
  mimeType: 'image/png',
  bytes: _pngBytes,
);

/// Stores [bytes] in [slot] and returns the stored-only reference a re-opened
/// form would hold — metadata and a key, no local content.
Future<FileRef> _seedStored(
  TomMemoryFileTransferClient client,
  String slot, {
  required String name,
  required Uint8List bytes,
  String? mediaType,
}) async {
  final metadata = await client.upload(
    slot: slot,
    source: TomFileSource.bytes(name, bytes, mediaType: mediaType),
  );
  return FileRef.stored(metadata);
}

void main() {
  tearDown(TomFilePickerRegistry.clear);

  // -------------------------------------------------------------------------
  // Picking capability
  // -------------------------------------------------------------------------

  group('TomFormFileField — picking capability', () {
    test('cannot pick without an explicit or a registered picker', () {
      expect(TomFormFileUpload('doc', null).canPick, isFalse);
    });

    test('can pick once the application registers a picker', () {
      TomFilePickerRegistry.register((_) async => const []);
      expect(TomFormFileUpload('doc', null).canPick, isTrue);
    });

    test('can pick with an explicit picker even without a registered one', () {
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('a.txt')),
      );
      expect(field.canPick, isTrue);
    });

    testWidgets('an explicit picker wins over the registered one', (
      tester,
    ) async {
      TomFilePickerRegistry.register(
        (_) async => [const TomPickedFile(name: 'registered.txt')],
      );
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('explicit.txt')),
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

      final picked = await field.runPicker(captured);
      expect(picked!.name, 'explicit.txt');
    });

    testWidgets('the field\'s constraints reach the registered picker', (
      tester,
    ) async {
      late TomFilePickRequest seen;
      TomFilePickerRegistry.register((request) async {
        seen = request;
        return const [];
      });
      final field = TomFormFileUpload(
        'photo',
        null,
        pickKind: TomFilePickKind.image,
        allowedExtensions: const ['png'],
        maxSizeBytes: 2048,
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

      await field.runPicker(captured);
      expect(seen.kind, TomFilePickKind.image);
      expect(seen.allowedExtensions, ['png']);
      expect(seen.maxSizeBytes, 2048);
    });
  });

  // -------------------------------------------------------------------------
  // Constraints
  // -------------------------------------------------------------------------

  group('TomFormFileField — constraints', () {
    test('checkFile rejects a disallowed extension', () {
      final field = TomFormFileUpload(
        'doc',
        null,
        allowedExtensions: const ['pdf'],
      );
      expect(field.checkFile(_localRef('scan.png')), 'error.fileExtension');
      expect(field.checkFile(_localRef('scan.pdf')), isNull);
    });

    test('checkFile rejects a file over the size limit', () {
      final field = TomFormFileUpload('doc', null, maxSizeBytes: 10);
      expect(field.checkFile(_localRef('a.txt', size: 11)), 'error.fileTooLarge');
      expect(field.checkFile(_localRef('a.txt', size: 10)), isNull);
    });

    test('the same constraints are enforced on a programmatic setValue', () async {
      final field = TomFormFileUpload(
        'doc',
        null,
        allowedExtensions: const ['pdf'],
        maxSizeBytes: 10,
      );
      field.setValue(_localRef('scan.png'));
      expect(await field.validate(), isA<ValidationError>());

      field.setValue(_localRef('scan.pdf', size: 11));
      expect(await field.validate(), isA<ValidationError>());

      field.setValue(_localRef('scan.pdf', size: 4));
      expect(await field.validate(), isA<ValidationSuccess>());
    });

    test('a pristine null value passes every built-in validator', () async {
      final field = TomFormFileUpload(
        'doc',
        null,
        allowedExtensions: const ['pdf'],
        maxSizeBytes: 10,
      );
      expect(await field.validate(), isA<ValidationSuccess>());
    });
  });

  // -------------------------------------------------------------------------
  // Transfer wiring
  // -------------------------------------------------------------------------

  group('TomFormFileField — transfer wiring', () {
    test('is picker-only without both a client and a slot', () {
      expect(TomFormFileUpload('doc', null).canTransfer, isFalse);
      expect(
        TomFormFileUpload(
          'doc',
          null,
          transferClient: TomMemoryFileTransferClient(),
        ).canTransfer,
        isFalse,
      );
      expect(
        TomFormFileUpload('doc', null, storageSlot: 'docs/1').canTransfer,
        isFalse,
      );
    });

    test('creates a controller for its slot when fully wired', () {
      final field = TomFormFileUpload(
        'doc',
        null,
        transferClient: TomMemoryFileTransferClient(),
        storageSlot: 'docs/1',
      );
      final controller = field.createTransferController();
      addTearDown(() => controller!.dispose());
      expect(controller, isNotNull);
      expect(controller!.slot, 'docs/1');
    });

    test('a picker-only field creates no controller', () {
      expect(TomFormFileUpload('doc', null).createTransferController(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormFileUpload widget
  // -------------------------------------------------------------------------

  group('TomFormFileUpload widget', () {
    testWidgets('shows the empty caption and no transfer row when picker-only', (
      tester,
    ) async {
      final field = TomFormFileUpload('doc', null);
      await tester.pumpWidget(_wrap(field.widget));
      expect(find.text('— no file selected'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('disables the button when nothing can pick', (tester) async {
      final field = TomFormFileUpload('doc', null);
      await tester.pumpWidget(_wrap(field.widget));
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('picking stores the file and shows its name and size', (
      tester,
    ) async {
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf', size: 2048)),
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(field.get()!.name, 'report.pdf');
      expect(find.text('report.pdf (2.0 KB)'), findsOneWidget);
    });

    testWidgets('a rejected file is reported and never becomes the value', (
      tester,
    ) async {
      final field = TomFormFileUpload(
        'doc',
        null,
        allowedExtensions: const ['pdf'],
        picker: TomFilePickers.fixed(_localRef('scan.png')),
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(field.get(), isNull);
      // The refusal is reported as a sentence, not as the key that produced
      // it — `error.fileExtension` is a thing to look up, not to read.
      expect(find.text('That file type is not allowed.'), findsOneWidget);
    });

    testWidgets('picking uploads and the value gains the server\'s key', (
      tester,
    ) async {
      final client = TomMemoryFileTransferClient();
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
        transferClient: client,
        storageSlot: 'docs/1',
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(client.slots, contains('docs/1'));
      expect(field.get()!.isStored, isTrue);
      expect(field.get()!.storageKey, isNotNull);
      expect(find.text('Uploaded.'), findsOneWidget);
    });

    testWidgets('autoUpload: false picks without transferring', (tester) async {
      final client = TomMemoryFileTransferClient();
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
        transferClient: client,
        storageSlot: 'docs/1',
        autoUpload: false,
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(field.get(), isNotNull);
      expect(client.slots, isEmpty);
    });

    testWidgets('clearing also deletes the stored file', (tester) async {
      final client = TomMemoryFileTransferClient();
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
        transferClient: client,
        storageSlot: 'docs/1',
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(client.slots, contains('docs/1'));

      await tester.tap(find.byIcon(Icons.clear));
      // Long enough for the field's validation debounce, which setValue(null)
      // schedules and a settled tree would otherwise leave pending.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(field.get(), isNull);
      expect(client.slots, isEmpty);
    });

    testWidgets('a download hands the bytes to the application', (
      tester,
    ) async {
      final client = TomMemoryFileTransferClient();
      Uint8List? delivered;
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf', size: 6)),
        transferClient: client,
        storageSlot: 'docs/1',
        onDownload: (ref, bytes) => delivered = bytes,
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      expect(delivered, List.filled(6, 1));
    });

    testWidgets('no download affordance without a stored file', (tester) async {
      final field = TomFormFileUpload(
        'doc',
        null,
        transferClient: TomMemoryFileTransferClient(),
        storageSlot: 'docs/1',
        onDownload: (_, _) {},
      );
      await tester.pumpWidget(_wrap(field.widget));
      expect(find.byIcon(Icons.download), findsNothing);
    });

    testWidgets('a restored stored value renders its download affordance', (
      tester,
    ) async {
      final client = TomMemoryFileTransferClient();
      final field = TomFormFileUpload(
        'doc',
        FileRef.stored(
          const TomFileMetadata(
            key: 'docs/2026/07/a.pdf',
            mediaType: 'application/pdf',
            byteCount: 2048,
            fileName: 'report.pdf',
          ),
        ),
        transferClient: client,
        storageSlot: 'docs/1',
        onDownload: (_, _) {},
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('report.pdf (2.0 KB)'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TomFormFileDropzone widget
  // -------------------------------------------------------------------------

  group('TomFormFileDropzone widget', () {
    testWidgets('invites a tap while empty', (tester) async {
      final field = TomFormFileDropzone('doc', null);
      await tester.pumpWidget(_wrap(field.widget));
      expect(find.text('Tap to choose a file'), findsOneWidget);
    });

    testWidgets('tapping the surface picks and uploads', (tester) async {
      final client = TomMemoryFileTransferClient();
      final field = TomFormFileDropzone(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
        transferClient: client,
        storageSlot: 'docs/1',
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(field.get()!.isStored, isTrue);
      expect(client.slots, contains('docs/1'));
    });
  });

  // -------------------------------------------------------------------------
  // Thumbnail — what "renderable" means
  // -------------------------------------------------------------------------

  group('tomFileIsRenderableImage', () {
    test('a reported image media type decides it', () {
      final ref = FileRef(
        name: 'scan',
        sizeBytes: 1,
        mimeType: 'image/jpeg',
      );
      expect(tomFileIsRenderableImage(ref, TomFilePickKind.any), isTrue);
    });

    test('a reported non-image media type decides it too', () {
      // Even under `pickKind: image`: what the field *asked* for cannot
      // overrule what the value turned out to be, and handing a PDF to
      // `Image.memory` is exactly the mistake this ordering prevents.
      final ref = FileRef(
        name: 'invoice.png',
        sizeBytes: 1,
        mimeType: 'application/pdf',
      );
      expect(tomFileIsRenderableImage(ref, TomFilePickKind.image), isFalse);
    });

    test('without a media type the extension decides it', () {
      expect(
        tomFileIsRenderableImage(
          const FileRef(name: 'face.WebP', sizeBytes: 1),
          TomFilePickKind.any,
        ),
        isTrue,
      );
      expect(
        tomFileIsRenderableImage(
          const FileRef(name: 'report.pdf', sizeBytes: 1),
          TomFilePickKind.image,
        ),
        isFalse,
      );
    });

    test('a vector image is not renderable — Flutter has no codec for it', () {
      expect(
        tomFileIsRenderableImage(
          const FileRef(name: 'logo.svg', sizeBytes: 1),
          TomFilePickKind.image,
        ),
        isFalse,
      );
    });

    test('with neither, the field\'s pick kind is all that is left', () {
      expect(
        tomFileIsRenderableImage(
          const FileRef(name: 'scan', sizeBytes: 1),
          TomFilePickKind.image,
        ),
        isTrue,
      );
      expect(
        tomFileIsRenderableImage(
          const FileRef(name: 'scan', sizeBytes: 1),
          TomFilePickKind.any,
        ),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // TomFormFileThumbnail widget
  // -------------------------------------------------------------------------

  group('TomFormFileThumbnail widget', () {
    testWidgets('shows the empty caption and no image while empty', (
      tester,
    ) async {
      final field = TomFormFileThumbnail('doc', null);
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('— no file selected'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('paints the picked image inline', (tester) async {
      final field = TomFormFileThumbnail(
        'doc',
        _pngRef(),
        pickKind: TomFilePickKind.image,
      );
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsNothing);
    });

    testWidgets('falls back to the file-kind icon for a non-image file', (
      tester,
    ) async {
      final field = TomFormFileThumbnail('doc', _localRef('report.pdf'));
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('a re-opened form fetches the stored image to paint it', (
      tester,
    ) async {
      final client = TomMemoryFileTransferClient();
      final stored = await _seedStored(
        client,
        'photos/1',
        name: 'face.png',
        bytes: _pngBytes,
        mediaType: 'image/png',
      );
      expect(stored.hasLocalContent, isFalse);

      final field = TomFormFileThumbnail(
        'doc',
        stored,
        transferClient: client,
        storageSlot: 'photos/1',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the preview fetch is not announced as a download', (
      tester,
    ) async {
      // A preview is the widget's own read, not the user's transfer: routing
      // it through the controller would make the status row say "Downloaded."
      // for something nobody asked for.
      final client = TomMemoryFileTransferClient();
      final stored = await _seedStored(
        client,
        'photos/1',
        name: 'face.png',
        bytes: _pngBytes,
        mediaType: 'image/png',
      );
      final field = TomFormFileThumbnail(
        'doc',
        stored,
        transferClient: client,
        storageSlot: 'photos/1',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.text('Downloaded.'), findsNothing);
      expect(find.text('Downloading…'), findsNothing);
    });

    testWidgets('a stored file that cannot be fetched still shows its icon', (
      tester,
    ) async {
      // Nothing was ever stored in the slot, so the fetch throws
      // `file_transfer.not_found`. A failed preview must not take the field
      // down with it.
      final field = TomFormFileThumbnail(
        'doc',
        const FileRef(
          name: 'face.png',
          sizeBytes: 67,
          mimeType: 'image/png',
          storageKey: 'memory/0/face.png',
        ),
        transferClient: TomMemoryFileTransferClient(),
        storageSlot: 'photos/missing',
      );
      await tester.pumpWidget(_wrap(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('tapping the preview picks and uploads', (tester) async {
      final client = TomMemoryFileTransferClient();
      final field = TomFormFileThumbnail(
        'doc',
        null,
        picker: TomFilePickers.fixed(_pngRef()),
        pickKind: TomFilePickKind.image,
        transferClient: client,
        storageSlot: 'photos/1',
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pumpAndSettle();

      expect(field.get()!.isStored, isTrue);
      expect(client.slots, contains('photos/1'));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the download affordance stays derived, never authored', (
      tester,
    ) async {
      // §5.18: whether a download affordance appears is derived from the field
      // being wired for transfer *and* the file being stored — the same rule
      // the other two presentations obey.
      final client = TomMemoryFileTransferClient();
      final stored = await _seedStored(
        client,
        'photos/1',
        name: 'face.png',
        bytes: _pngBytes,
        mediaType: 'image/png',
      );

      final withoutCallback = TomFormFileThumbnail(
        'doc',
        stored,
        transferClient: client,
        storageSlot: 'photos/1',
      );
      await tester.pumpWidget(_wrap(withoutCallback.widget));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsNothing);

      final withCallback = TomFormFileThumbnail(
        'doc2',
        stored,
        transferClient: client,
        storageSlot: 'photos/1',
        onDownload: (_, _) {},
      );
      await tester.pumpWidget(_wrap(withCallback.widget));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('renders its label and description', (tester) async {
      _installResources({
        'doc': {'label': 'Portrait', 'description': 'One picture, please.'},
      });
      final field = TomFormFileThumbnail('doc', null);
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Portrait'), findsWidgets);
      expect(find.text('One picture, please.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // TomCupertinoFormFileThumbnail widget
  // -------------------------------------------------------------------------

  group('TomCupertinoFormFileThumbnail widget', () {
    testWidgets('paints the picked image inline', (tester) async {
      final field = TomCupertinoFormFileThumbnail(
        'doc',
        _pngRef(),
        pickKind: TomFilePickKind.image,
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.doc), findsNothing);
    });

    testWidgets('falls back to the file-kind icon for a non-image file', (
      tester,
    ) async {
      final field = TomCupertinoFormFileThumbnail(
        'doc',
        _localRef('report.pdf'),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(CupertinoIcons.doc), findsOneWidget);
    });

    testWidgets('a re-opened form fetches the stored image to paint it', (
      tester,
    ) async {
      final client = TomMemoryFileTransferClient();
      final stored = await _seedStored(
        client,
        'photos/1',
        name: 'face.png',
        bytes: _pngBytes,
        mediaType: 'image/png',
      );
      final field = TomCupertinoFormFileThumbnail(
        'doc',
        stored,
        transferClient: client,
        storageSlot: 'photos/1',
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Downloaded.'), findsNothing);
    });

    testWidgets('a rejected file surfaces in a Cupertino dialog', (
      tester,
    ) async {
      final field = TomCupertinoFormFileThumbnail(
        'doc',
        null,
        allowedExtensions: const ['png'],
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      await tester.tap(find.byIcon(CupertinoIcons.photo));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(field.get(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Family reachability
  // -------------------------------------------------------------------------

  group('FormFieldFamily.fileThumbnail', () {
    test('the Material family builds the Material concrete', () {
      final field = FormFieldFamily.material.fileThumbnail('doc', null);
      expect(field, isA<TomFormFileThumbnail>());
    });

    test('the Cupertino family builds the Cupertino concrete', () {
      final field = FormFieldFamily.cupertino.fileThumbnail('doc', null);
      expect(field, isA<TomCupertinoFormFileThumbnail>());
    });

    test('a thumbnail asks the picker for an image by default', () {
      // The presentation is the point of the field: a thumbnail that opened a
      // "choose any file" dialog would invite exactly the file it cannot show.
      expect(
        FormFieldFamily.material.fileThumbnail('doc', null).pickKind,
        TomFilePickKind.image,
      );
    });

    test('the transfer wiring reaches the concrete', () {
      // Without it the stored-preview path is unreachable through the family,
      // which is the path a generated form takes when it re-opens.
      final client = TomMemoryFileTransferClient();
      final field = FormFieldFamily.material.fileThumbnail(
        'doc',
        null,
        transferClient: client,
        storageSlot: 'photos/1',
      );
      expect(field.canTransfer, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Cupertino concrete
  // -------------------------------------------------------------------------

  group('TomCupertinoFormFileUpload widget', () {
    testWidgets('shows the empty caption', (tester) async {
      final field = TomCupertinoFormFileUpload('doc', null);
      await tester.pumpWidget(_wrapCupertino(field.widget));
      expect(find.text('— no file selected'), findsOneWidget);
    });

    testWidgets('picking stores and uploads the file', (tester) async {
      final client = TomMemoryFileTransferClient();
      final field = TomCupertinoFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf', size: 2048)),
        transferClient: client,
        storageSlot: 'docs/1',
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      await tester.tap(find.text('Choose file…'));
      await tester.pumpAndSettle();

      expect(field.get()!.isStored, isTrue);
      expect(find.text('report.pdf (2.0 KB)'), findsOneWidget);
    });

    testWidgets('a rejected file surfaces in a Cupertino dialog', (
      tester,
    ) async {
      final field = TomCupertinoFormFileUpload(
        'doc',
        null,
        allowedExtensions: const ['pdf'],
        picker: TomFilePickers.fixed(_localRef('scan.png')),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      await tester.tap(find.text('Choose file…'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('File rejected'), findsOneWidget);
      expect(find.text('That file type is not allowed.'), findsOneWidget);
      expect(field.get(), isNull);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('clearing also deletes the stored file', (tester) async {
      final client = TomMemoryFileTransferClient();
      final field = TomCupertinoFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
        transferClient: client,
        storageSlot: 'docs/1',
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      await tester.tap(find.text('Choose file…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(CupertinoIcons.clear_circled_solid));
      // See the Material counterpart: drains the validation debounce.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(field.get(), isNull);
      expect(client.slots, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Formatting
  // -------------------------------------------------------------------------

  group('tomHumanFileSize', () {
    test('renders bytes, kilobytes and megabytes', () {
      expect(tomHumanFileSize(512), '512 B');
      expect(tomHumanFileSize(2048), '2.0 KB');
      expect(tomHumanFileSize(3 * 1024 * 1024), '3.00 MB');
    });
  });

  // -------------------------------------------------------------------------
  // Wording
  // -------------------------------------------------------------------------
  //
  // The file widgets show a dozen user-visible strings. These tests pin that
  // every one of them *has a key* — that an application can translate the
  // paperclip row by declaring resources, without replacing the widgets.

  group('TomFileLabels', () {
    tearDown(() => _installResources({}));

    test('falls back to the built-in English when nothing is declared', () {
      _installResources({});
      expect(TomFileLabels.choose(null), 'Choose file…');
      expect(TomFileLabels.progress(null, false, 42), 'Uploading 42%');
      expect(TomFileLabels.progress(null, true, 42), 'Downloading 42%');
      expect(TomFileLabels.progressBusy(null, true), 'Downloading…');
    });

    test('a global key replaces the built-in wording everywhere', () {
      _installResources({
        'file': {'choose': 'Datei wählen…'},
      });
      expect(TomFileLabels.choose(null), 'Datei wählen…');
      expect(TomFileLabels.choose('doc'), 'Datei wählen…');
    });

    test('a field-scoped key beats the global one', () {
      _installResources({
        'file': {'choose': 'Choose a file'},
        'avatar': {
          'file': {'choose': 'Choose a picture'},
        },
      });
      expect(TomFileLabels.choose('doc'), 'Choose a file');
      expect(TomFileLabels.choose('avatar'), 'Choose a picture');
    });

    test('placeholders are interpolated at whichever level won', () {
      _installResources({
        'file': {'uploading': '{percent}% hochgeladen'},
      });
      expect(TomFileLabels.progress(null, false, 7), '7% hochgeladen');
    });

    test('a refusal resolves under the validator key that caused it', () {
      _installResources({
        'error': {'fileTooLarge': 'Zu groß.'},
      });
      expect(TomFileLabels.rejection(null, 'error.fileTooLarge'), 'Zu groß.');
      // Unknown keys stay visible rather than blanking the line.
      expect(TomFileLabels.rejection(null, 'error.mystery'), 'error.mystery');
    });
  });

  group('file field wording resolves from resources', () {
    tearDown(() => _installResources({}));

    testWidgets('the Material chrome reads the declared strings', (
      tester,
    ) async {
      _installResources({
        'file': {'choose': 'Pick one', 'none': 'nothing yet'},
      });
      final field = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
      );
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('nothing yet'), findsOneWidget);
    });

    testWidgets('the Cupertino chrome reads the same keys', (tester) async {
      _installResources({
        'file': {'choose': 'Pick one', 'none': 'nothing yet'},
      });
      final field = TomCupertinoFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
      );
      await tester.pumpWidget(_wrapCupertino(field.widget));

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('nothing yet'), findsOneWidget);
    });

    testWidgets('a field-scoped override applies to one field only', (
      tester,
    ) async {
      _installResources({
        'file': {'choose': 'Choose file'},
        'avatar': {
          'file': {'choose': 'Choose picture'},
        },
      });
      final doc = TomFormFileUpload(
        'doc',
        null,
        picker: TomFilePickers.fixed(_localRef('report.pdf')),
      );
      final avatar = TomFormFileUpload(
        'avatar',
        null,
        picker: TomFilePickers.fixed(_localRef('face.png')),
      );
      await tester.pumpWidget(
        _wrap(Column(children: [doc.widget, avatar.widget])),
      );

      expect(find.text('Choose file'), findsOneWidget);
      expect(find.text('Choose picture'), findsOneWidget);
    });

    testWidgets('the Material field renders its label and description', (
      tester,
    ) async {
      // The label is the field's *own* chrome, not the file plumbing's: it
      // resolves from `<basePath>.label` like every other field's. Asserted
      // because `TomGenericFieldDecorationMixin` declares its own `labelText`
      // after this class in the mixin linearization, so a label declared only
      // on the shared base would be shadowed and silently never render.
      _installResources({
        'doc': {'label': 'Attachment', 'description': 'One file, please.'},
      });
      final field = TomFormFileUpload('doc', null);
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Attachment'), findsWidgets);
      expect(find.text('One file, please.'), findsOneWidget);
    });

    testWidgets('the dropzone renders its label and description', (
      tester,
    ) async {
      _installResources({
        'doc': {'label': 'Attachment', 'description': 'One file, please.'},
      });
      final field = TomFormFileDropzone('doc', null);
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Attachment'), findsWidgets);
      expect(find.text('One file, please.'), findsOneWidget);
    });

    testWidgets('an explicit label override beats the resource', (
      tester,
    ) async {
      _installResources({
        'doc': {'label': 'Attachment'},
      });
      final field = TomFormFileUpload('doc', null, labelTextOverride: 'Scan');
      await tester.pumpWidget(_wrap(field.widget));

      expect(find.text('Scan'), findsWidgets);
      expect(find.text('Attachment'), findsNothing);
    });

    testWidgets('the rejection sentence is translatable', (tester) async {
      _installResources({
        'error': {'fileExtension': 'Nur PDF-Dateien.'},
      });
      final field = TomFormFileUpload(
        'doc',
        null,
        allowedExtensions: const ['pdf'],
        picker: TomFilePickers.fixed(_localRef('scan.png')),
      );
      await tester.pumpWidget(_wrap(field.widget));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.text('Nur PDF-Dateien.'), findsOneWidget);
    });
  });
}
