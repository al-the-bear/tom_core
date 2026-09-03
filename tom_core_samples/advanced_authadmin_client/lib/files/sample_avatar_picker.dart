/// The console's platform file picker, registered once at bootstrap.
///
/// [TomFormFileField] deliberately does not depend on a picker package —
/// `file_picker` and `image_picker` both pull in platform channels, they
/// conflict with each other, and an application that has already chosen one
/// should not be made to ship two. Instead the application registers **one**
/// adaptor with [TomFilePickerRegistry] and every file field in it opens that
/// one. The registration is the seam this file exists to demonstrate.
///
/// ## What a real console writes here
///
/// Six lines naming its picker package. With `image_picker`:
///
/// ```dart
/// import 'package:image_picker/image_picker.dart' as ip;
///
/// TomFilePickerRegistry.register((request) async {
///   final picked = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery);
///   if (picked == null) return const [];
///   return [
///     TomPickedFile(
///       name: picked.name,
///       sizeBytes: await picked.length(),
///       path: picked.path,
///       open: picked.openRead,
///     ),
///   ];
/// });
/// ```
///
/// ## Why this sample registers a synthetic one instead
///
/// The advanced sample's two Flutter clients ship no platform folders — they are
/// driven by their widget suites and by the cross-tier integration runner, not
/// launched on a device. A picker plugin would add platform channels nothing in
/// this repository can invoke, and a widget test would have to stub them
/// straight back out. So the console registers [registerSampleAvatarPicker]: a
/// picker that *composes* an image rather than asking the platform for one.
///
/// Everything downstream is the real thing — the same [TomPickedFile] shape a
/// plugin returns, the same [FileRef] conversion, the same streaming upload,
/// progress, cancel and retry. Only the gallery dialog is missing.
///
/// ## Why the app client has its own
///
/// `advanced_app_client` registers a different synthetic picker, and that is not
/// an oversight: the registration is **per application** by design, and each
/// client here shows its own so a reader of either one sees the whole seam
/// without cross-referencing the other. The two also differ in substance — an
/// attachment is any small file, an avatar is a PNG, and only a picker that
/// returns a real image satisfies the avatar field's extension validator.
library;

import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Installs the console's avatar picker as the application's picker.
///
/// Called once from `main`, before the first frame, exactly where a real console
/// would register its plugin adaptor. Calling it again replaces the
/// registration, which is what a test wants and what an application never needs.
void registerSampleAvatarPicker() =>
    TomFilePickerRegistry.register(sampleAvatarPicker);

/// A 1×1 opaque PNG, byte for byte.
///
/// A *real* PNG rather than arbitrary bytes labelled `.png`, so what travels
/// through the upload is a file the server could legitimately serve back as
/// `image/png` — the sample would otherwise be teaching that a media type is a
/// naming convention.
const List<int> _onePixelPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR length + type
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1 × 1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT length + type
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
  0x42, 0x60, 0x82, //
];

/// Composes a small image, in the shape a platform picker would return it.
///
/// The name carries a timestamp so two avatars picked in one session are
/// distinguishable on screen — a picker that returned the same file every time
/// would make "did the upload actually replace it?" unanswerable by looking.
///
/// The [request] is honoured the one way a synthetic picker can: its
/// `allowedExtensions`, when the field declares any, choose the suffix, so the
/// field's own validators pass rather than rejecting the sample's own image.
Future<List<TomPickedFile>> sampleAvatarPicker(
  TomFilePickRequest request,
) async {
  final extension = request.allowedExtensions?.firstOrNull ?? 'png';
  final stamp = DateTime.now().toIso8601String().replaceAll(
    RegExp(r'[:.]'),
    '-',
  );
  return [
    TomPickedFile(
      name: 'avatar-$stamp.$extension',
      sizeBytes: _onePixelPng.length,
      // A re-openable stream rather than the bytes, because that is the shape a
      // real picker offers for anything worth uploading — and the shape the
      // upload's retry depends on.
      open: () => Stream.value(_onePixelPng),
    ),
  ];
}
