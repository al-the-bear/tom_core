/// A concrete file picker for the file fields — without depending on one.
///
/// ## The tension, and how it is resolved
///
/// `tom_flutter_ui` must not hard-depend on `file_picker` or `image_picker`:
/// they pull in platform channels, they conflict with each other, and an
/// application that has already chosen one should not be forced to ship two.
/// But "the app must supply a `picker` callback" meant the file fields did not
/// work out of the box at all.
///
/// The split is between the *plumbing* and the *plugin*:
///
///   * [TomPickedFile] is a structural description of a picked file — exactly
///     the fields every picker package already returns. Adapting one is a
///     handful of field copies, with no type from this package involved.
///   * [TomFilePickerRegistry] holds one adaptor for the whole application, so
///     a field constructed without a `picker` still opens a real picker.
///   * [TomFilePickers] turns a [TomPickedFile] into a [FileRef], choosing a
///     streamed source over in-memory bytes whenever it can.
///
/// So the app writes the six lines that name its picker package, once, and
/// every file field in the application works from then on.
///
/// ## Wiring `file_picker`
///
/// ```dart
/// import 'package:file_picker/file_picker.dart' as fp;
///
/// TomFilePickerRegistry.register((request) async {
///   final result = await fp.FilePicker.platform.pickFiles(
///     allowedExtensions: request.allowedExtensions,
///     type: request.allowedExtensions == null ? fp.FileType.any : fp.FileType.custom,
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
/// ## Wiring `image_picker`
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
///       mimeType: picked.mimeType,
///       open: picked.openRead,
///     ),
///   ];
/// });
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'file_opener.dart';
import 'file_ref.dart';

// ===========================================================================
// The structural picked-file description
// ===========================================================================

/// What a platform picker returned, in the shape every picker package uses.
///
/// Deliberately structural: nothing here refers to a picker package, so an
/// adaptor is a list of field copies and this package stays free of the
/// dependency.
@immutable
class TomPickedFile {
  /// Creates a description of a picked file.
  ///
  /// At least one of [bytes], [open] and [path] should be set, or the result
  /// describes a file whose contents cannot be read.
  const TomPickedFile({
    required this.name,
    this.sizeBytes,
    this.mimeType,
    this.bytes,
    this.path,
    this.open,
  });

  /// The file name as the user knows it, including its extension.
  final String name;

  /// The size in bytes, when the picker reported one.
  final int? sizeBytes;

  /// The media type, when the picker reported one.
  final String? mimeType;

  /// The bytes, when the picker read the file eagerly.
  final Uint8List? bytes;

  /// The filesystem path, when the platform has one.
  final String? path;

  /// A re-openable byte stream, when the picker offered streamed reads.
  final Stream<List<int>> Function()? open;

  @override
  String toString() => 'TomPickedFile($name, ${sizeBytes ?? '?'} B)';
}

/// What a field is asking the picker for.
///
/// Carries the field's own constraints so a picker can apply them in its
/// native dialog — a user who cannot select a `.exe` in the first place is
/// better served than one who is told afterwards that `.exe` is not allowed.
@immutable
class TomFilePickRequest {
  /// Creates a pick request.
  const TomFilePickRequest({
    this.allowedExtensions,
    this.maxSizeBytes,
    this.kind = TomFilePickKind.any,
  });

  /// Allowed extensions without a dot, lowercase, or `null` for no limit.
  final List<String>? allowedExtensions;

  /// The inclusive maximum size the field will accept, when it has one.
  final int? maxSizeBytes;

  /// What kind of file the field is after.
  final TomFilePickKind kind;
}

/// The kind of file a field wants, so an adaptor can pick the right dialog.
enum TomFilePickKind {
  /// Any file — a document picker.
  any,

  /// An image — a gallery or camera picker.
  image,

  /// A video.
  video,

  /// Audio.
  audio,
}

/// An adaptor over a platform picker, returning what the user chose.
///
/// Returns an empty list when the user cancels; the registry turns that into
/// the `null` a [FilePicker] contract expects.
typedef TomPlatformFilePicker =
    Future<List<TomPickedFile>> Function(TomFilePickRequest request);

// ===========================================================================
// The registry
// ===========================================================================

/// Holds the application's platform picker.
///
/// One adaptor for the whole application, because there is one file picker per
/// application; a field that wants something else still passes its own
/// `picker` callback and bypasses this entirely.
class TomFilePickerRegistry {
  TomFilePickerRegistry._();

  static TomPlatformFilePicker? _picker;

  /// Installs [picker] as the application's file picker.
  ///
  /// Call once during start-up. Registering again replaces the previous
  /// adaptor, which is what a test wants and what an application should never
  /// need.
  static void register(TomPlatformFilePicker picker) => _picker = picker;

  /// Removes the registered picker.
  static void clear() => _picker = null;

  /// Whether a picker has been registered.
  ///
  /// A field checks this to decide whether to enable its "Choose file…"
  /// affordance at all — a button that cannot do anything is worse than an
  /// absent one.
  static bool get hasPicker => _picker != null;

  /// Runs the registered picker for [request], returning the first file chosen
  /// or `null` when the user cancelled.
  ///
  /// Throws [StateError] when no picker is registered; reaching here without
  /// one is a wiring mistake, not a runtime condition to paper over.
  static Future<FileRef?> pick(TomFilePickRequest request) async {
    final picker = _picker;
    if (picker == null) {
      throw StateError(
        'No file picker is registered. Call TomFilePickerRegistry.register() '
        'during start-up, or pass a picker callback to the field.',
      );
    }
    final picked = await picker(request);
    if (picked.isEmpty) return null;
    return TomFilePickers.toFileRef(picked.first);
  }
}

// ===========================================================================
// Conversions
// ===========================================================================

/// Ready-made [FilePicker] callbacks and the [TomPickedFile] → [FileRef]
/// conversion they share.
class TomFilePickers {
  TomFilePickers._();

  /// The picker every file field falls back to: the registered adaptor.
  ///
  /// A field's `picker` parameter is optional precisely so this can be the
  /// default, which is what "works out of the box" means here.
  static FilePicker registered({
    List<String>? allowedExtensions,
    int? maxSizeBytes,
    TomFilePickKind kind = TomFilePickKind.any,
  }) =>
      (BuildContext context) => TomFilePickerRegistry.pick(
        TomFilePickRequest(
          allowedExtensions: allowedExtensions,
          maxSizeBytes: maxSizeBytes,
          kind: kind,
        ),
      );

  /// A picker that always returns [ref] — for demos, tests and previews.
  static FilePicker fixed(FileRef? ref) =>
      (BuildContext context) async => ref;

  /// Converts a picked file into the value a field holds.
  ///
  /// Prefers a streamed source over in-memory bytes: the picker may hand over
  /// both, and keeping the bytes would defeat the streaming upload the source
  /// exists to enable. A path is opened lazily, so a large file is never read
  /// here.
  static FileRef toFileRef(TomPickedFile picked) {
    final mimeType =
        picked.mimeType ?? TomFileSource.guessMediaType(picked.name);

    final open = picked.open ?? _openerForPath(picked.path);
    if (open != null) {
      final size =
          picked.sizeBytes ??
          (picked.path == null ? null : fileLengthAt(picked.path!));
      return FileRef(
        name: picked.name,
        // A size the picker did not report and the filesystem cannot supply is
        // recorded as 0 rather than guessed: the upload still streams, and the
        // progress bar honestly shows itself as indeterminate.
        sizeBytes: size ?? 0,
        mimeType: mimeType,
        source: TomFileSource.stream(
          fileName: picked.name,
          byteCount: size,
          mediaType: mimeType,
          open: open,
        ),
      );
    }

    final bytes = picked.bytes;
    if (bytes != null) {
      return FileRef(
        name: picked.name,
        sizeBytes: picked.sizeBytes ?? bytes.length,
        mimeType: mimeType,
        bytes: bytes,
      );
    }

    // Neither content form: the file can still be named and validated, and the
    // upload path will say clearly that there is nothing to send.
    return FileRef(
      name: picked.name,
      sizeBytes: picked.sizeBytes ?? 0,
      mimeType: mimeType,
    );
  }

  static Stream<List<int>> Function()? _openerForPath(String? path) =>
      path == null ? null : openFilePath(path);
}
