/// Executable example for the file components of the `forms/` module.
///
/// A file field is the one field whose value does not live in the form: the
/// user picks a file, the bytes go to a store, and what the form saves is a
/// reference. This example walks that whole path without a server and without
/// a picker package:
///
/// 1. registering an application file picker (the adaptor an app writes once),
/// 2. what a picked file becomes — streamed source vs in-memory bytes,
/// 3. uploading through [TomFileTransferController] with progress,
/// 4. cancelling, failing and retrying,
/// 5. downloading a stored file,
/// 6. describing a slot when a form is re-opened, and removing the blob,
/// 7. wiring a real field: `TomFormFileUpload` with a slot and a client.
///
/// It uses [TomMemoryFileTransferClient], the in-memory implementation of the
/// same contract `TomHttpFileTransferClient` speaks — so everything here is
/// exactly what happens against a server, minus the sockets.
///
/// Because it imports `flutter/material` through the package barrel, bare
/// `dart run` cannot execute it. Run
/// `flutter test test/forms/file_fields_example_test.dart`, which calls this
/// example and reports its result in the exit code.
library;

// Demonstration example: console output is intentional.
// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

Future<void> run() async {
  // ---------------------------------------------------------------------------
  // 1. Registering the application's picker
  // ---------------------------------------------------------------------------
  // In a real app this closure calls `file_picker` or `image_picker` and copies
  // a handful of fields into TomPickedFile. Nothing in tom_flutter_ui names
  // either package, which is why it does not depend on them.
  TomFilePickerRegistry.register((request) async {
    print(
      'picker asked for kind=${request.kind.name} '
      'extensions=${request.allowedExtensions} '
      'maxSize=${request.maxSizeBytes}',
    );
    return [
      TomPickedFile(
        name: 'quarterly-report.pdf',
        sizeBytes: 40,
        // A re-openable stream, not a Stream: the upload must be able to read
        // the file again when a retry needs it.
        open: () =>
            Stream.fromIterable(List.generate(4, (_) => List.filled(10, 7))),
      ),
    ];
  });
  print('picker registered: ${TomFilePickerRegistry.hasPicker}');

  // ---------------------------------------------------------------------------
  // 2. What a picked file becomes
  // ---------------------------------------------------------------------------
  final picked = await TomFilePickerRegistry.pick(
    const TomFilePickRequest(
      allowedExtensions: ['pdf'],
      maxSizeBytes: 1024 * 1024,
    ),
  );
  print(
    'picked: ${picked!.name} ${picked.sizeBytes} B '
    'mime=${picked.mimeType} streamed=${picked.source != null}',
  );

  // A picker that read the file eagerly gives bytes instead; both are a
  // TomFileRef, and both can produce the TomFileSource an upload needs.
  final small = TomFilePickers.toFileRef(
    TomPickedFile(name: 'note.txt', bytes: Uint8List.fromList([1, 2, 3])),
  );
  print(
    'small: ${small.name} bytes=${small.bytes?.length} '
    'streamed=${small.source != null}',
  );

  // ---------------------------------------------------------------------------
  // 3. Uploading, with progress
  // ---------------------------------------------------------------------------
  final client = TomMemoryFileTransferClient(chunkSize: 10);
  final controller = TomFileTransferController(
    client: client,
    // The application owns the slot; the *key* is the server's to generate.
    slot: 'reports/2026/q2',
  );

  final progress = <String>[];
  void record() {
    final state = controller.value;
    final fraction = state.fraction;
    progress.add(
      '${state.phase.name}${fraction == null ? '' : ' ${(fraction * 100).round()}%'}',
    );
  }

  controller.addListener(record);

  final stored = await controller.upload(picked);
  // Watched only for the upload — the download below drives the same
  // controller and would otherwise append to the same list.
  controller.removeListener(record);
  print('upload states: ${progress.join(' → ')}');
  print('stored key: ${stored!.key} (${stored.byteCount} B)');

  // The value the form saves is the reference plus the server's key.
  final savedValue = picked.copyWith(storageKey: stored.key);
  print('form value: name=${savedValue.name} stored=${savedValue.isStored}');

  // ---------------------------------------------------------------------------
  // 4. Failure and retry
  // ---------------------------------------------------------------------------
  // A missing slot is the simplest real failure: it lands in `failed`, keeps
  // its error key, and leaves the controller ready to repeat the attempt.
  final missing = TomFileTransferController(client: client, slot: 'nope');
  await missing.download();
  print(
    'failed with: ${missing.value.errorKey} '
    '→ "${tomTransferErrorMessage(missing.value)}" retryable=${missing.canRetry}',
  );
  missing.dispose();

  // ---------------------------------------------------------------------------
  // 5. Downloading
  // ---------------------------------------------------------------------------
  final bytes = await controller.download();
  print(
    'downloaded ${bytes!.length} B in phase ${controller.value.phase.name}',
  );

  // The streaming form never holds the whole file: a preview accumulates, a
  // file writer does not.
  var streamed = 0;
  await controller.downloadTo((chunk) => streamed += chunk.length);
  print('streamed $streamed B without buffering');

  // ---------------------------------------------------------------------------
  // 6. Re-opening a form, and removing the blob
  // ---------------------------------------------------------------------------
  // A re-opened form knows only the key it saved. One describe is enough to
  // show the attachment without downloading it.
  final described = await controller.describe();
  print('described: ${described!.fileName} (${described.byteCount} B)');
  final restored = TomFileRef.stored(described);
  print(
    'restored value: ${restored.name} localContent=${restored.hasLocalContent}',
  );

  final removed = await controller.remove();
  print('removed=$removed slots left=${client.slots.length}');

  // ---------------------------------------------------------------------------
  // 7. A field wired for the whole thing
  // ---------------------------------------------------------------------------
  final field = TomFormFileUpload(
    'report',
    null,
    transferClient: client,
    storageSlot: 'reports/2026/q3',
    allowedExtensions: const ['pdf'],
    maxSizeBytes: 8 * 1024 * 1024,
    labelTextOverride: 'Quarterly report',
  );
  print('field canPick=${field.canPick} canTransfer=${field.canTransfer}');
  print(
    'field rejects a .png: ${field.checkFile(const TomFileRef(name: 'photo.png', sizeBytes: 10))}',
  );

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------
  assert(TomFilePickerRegistry.hasPicker);

  // A picker that offers a stream is taken up on it — a 4 GB file must not be
  // read into memory to be uploaded.
  assert(picked.source != null);
  assert(picked.bytes == null);
  assert(picked.mimeType == 'application/pdf');
  assert(picked.sizeBytes == 40);

  assert(small.bytes != null);
  assert(small.source == null);

  assert(progress.first == 'running');
  assert(progress.last == 'succeeded 100%');
  assert(progress.any((p) => p.startsWith('running 25%')));
  assert(stored.byteCount == 40);
  assert(savedValue.isStored);
  assert(savedValue.hasLocalContent); // the picked source is still there

  assert(missing.value.phase == TomTransferPhase.failed);
  assert(missing.value.errorKey == 'file_transfer.not_found');
  assert(missing.canRetry);

  assert(bytes.length == 40);
  assert(streamed == 40);

  assert(described.fileName == 'quarterly-report.pdf');
  assert(!restored.hasLocalContent);
  assert(restored.isStored);

  assert(removed);
  assert(client.slots.isEmpty);

  assert(field.canPick); // via the registered picker, with no picker argument
  assert(field.canTransfer);
  assert(
    field.checkFile(const TomFileRef(name: 'photo.png', sizeBytes: 10)) ==
        'error.fileExtension',
  );

  controller.dispose();
  TomFilePickerRegistry.clear();
}

void main() => run();
