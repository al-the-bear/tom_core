import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_file_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_file_field.dart';
import 'package:tom_flutter_ui/src/forms/files/tom_file_labels.dart';
import 'package:tom_flutter_ui/src/forms/files/tom_file_picker_registry.dart';
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
