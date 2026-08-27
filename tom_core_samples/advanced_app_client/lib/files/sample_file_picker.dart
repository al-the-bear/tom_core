/// The app's platform file picker, registered once at bootstrap.
///
/// [TomFormFileField] deliberately does not depend on a picker package —
/// `file_picker` and `image_picker` both pull in platform channels, they
/// conflict with each other, and an application that has already chosen one
/// should not be made to ship two. Instead the application registers **one**
/// adaptor with [TomFilePickerRegistry] and every file field in the app opens
/// it. That registration is the seam this file exists to demonstrate.
///
/// ## What a real application writes here
///
/// One registration naming its picker package. With `file_picker`:
///
/// ```dart
/// import 'package:file_picker/file_picker.dart' as fp;
///
/// TomFilePickerRegistry.register((request) async {
///   final result = await fp.FilePicker.platform.pickFiles(
///     allowedExtensions: request.allowedExtensions,
///     type: request.allowedExtensions == null
///         ? fp.FileType.any
///         : fp.FileType.custom,
///     withReadStream: true,
///   );
///   return result?.files
///           .map((f) => TomPickedFile(
///                 name: f.name,
///                 sizeBytes: f.size,
///                 path: f.path,
///                 bytes: f.bytes,
///                 open: f.readStream == null ? null : () => f.readStream!,
///               ))
///           .toList() ??
///       const [];
/// });
/// ```
///
/// ## Why this sample registers a synthetic one instead
///
/// The advanced sample's two Flutter clients ship no platform folders — they
/// are driven by their widget suites and by the cross-tier integration runner,
/// not launched on a device. A picker plugin would therefore add platform
/// channels that nothing in this repository can invoke, and a widget test would
/// have to stub them straight back out. So the sample registers
/// [registerSampleFilePicker]: a picker that *composes* a small file rather than
/// asking the platform for one.
///
/// Everything downstream of the picker is the real thing — the same
/// [TomPickedFile] shape a plugin returns, the same [FileRef] conversion, the
/// same streaming upload, the same progress, cancel and retry. Only the dialog
/// is missing, and swapping it in is the registration above.
library;

import 'dart:convert';

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Installs the sample's file picker as the application's picker.
///
/// Called once from `main`, before the first frame, exactly where a real
/// application would register its plugin adaptor. Calling it again replaces the
/// registration, which is what a test wants and what an application never needs.
void registerSampleFilePicker() =>
    TomFilePickerRegistry.register(sampleFilePicker);

/// Composes a small text file, in the shape a platform picker would return it.
///
/// The name carries a timestamp so two attachments picked in one session are
/// distinguishable on screen — a picker that returned the same file every time
/// would make "did the upload actually replace it?" unanswerable by looking.
///
/// The [request] is honoured the one way a synthetic picker can: its
/// `allowedExtensions`, when the field declares any, choose the suffix, so the
/// field's own validators pass rather than rejecting the sample's own file.
Future<List<TomPickedFile>> sampleFilePicker(
  TomFilePickRequest request,
) async {
  final extension = request.allowedExtensions?.firstOrNull ?? 'txt';
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[:.]'), '-');
  final name = 'note-$stamp.$extension';
  final bytes = utf8.encode(
    'Sample attachment composed by advanced_app_client at $stamp.\n',
  );
  return [
    TomPickedFile(
      name: name,
      sizeBytes: bytes.length,
      // A re-openable stream rather than the bytes, because that is the shape
      // a real picker offers for anything worth uploading — and the shape the
      // upload's retry depends on.
      open: () => Stream.value(bytes),
    ),
  ];
}
