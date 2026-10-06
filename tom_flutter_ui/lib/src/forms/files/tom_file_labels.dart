/// The wording of the file widgets, as resource keys rather than literals.
///
/// The file field and the transfer indicator between them show a dozen short
/// strings — "Choose file…", "Uploading 42%", "The file is no longer
/// available." — and every one of them is user-visible. Written inline they are
/// English forever: an application that localises everything else still ships a
/// board whose paperclip row is in English, and a sample read as a template
/// propagates that shape into whatever is built from it.
///
/// So the strings live here, behind [TomFileLabels], resolved through [TomCtr]
/// with the built-in wording as the fallback, so a field with no resources
/// renders that wording — but every string *has* a key, which is the difference between "not translated yet"
/// and "not translatable".
///
/// ## Resolution order
///
/// Each label resolves scoped-then-global-then-literal, the same order
/// [TomField.resolvedErrorMessage] uses for validation messages:
///
///  1. `<basePath>.<key>` — this one field's override (the avatar field says
///     "Choose a picture…" while every other file field says "Choose file…").
///  2. `<key>` — the application-wide wording, set once.
///  3. The built-in English, so an unconfigured application is never blank.
///
/// ## Keys
///
/// | Key | Default | Parameters |
/// | --- | --- | --- |
/// | `file.choose` | `Choose file…` | — |
/// | `file.none` | `— no file selected` | — |
/// | `file.dropzoneHint` | `Tap to choose a file` | — |
/// | `file.selected` | `{name} ({size})` | `name`, `size` |
/// | `file.download` | `Download` | — |
/// | `file.clear` | `Clear` | — |
/// | `file.cancel` | `Cancel` | — |
/// | `file.retry` | `Retry` | — |
/// | `file.uploading` | `Uploading {percent}%` | `percent` |
/// | `file.uploadingBusy` | `Uploading…` | — |
/// | `file.downloading` | `Downloading {percent}%` | `percent` |
/// | `file.downloadingBusy` | `Downloading…` | — |
/// | `file.uploaded` | `Uploaded.` | — |
/// | `file.downloaded` | `Downloaded.` | — |
/// | `file.removed` | `Removed.` | — |
/// | `file.done` | `Done.` | — |
/// | `file.cancelled` | `Transfer cancelled.` | — |
/// | `file.rejectedTitle` | `File rejected` | — |
/// | `file.rejectedDismiss` | `OK` | — |
///
/// A file the picker *refuses* is reported under the validator key that refused
/// it (`error.fileExtension`, `error.fileTooLarge`) rather than under a
/// `file.*` key of its own — see [TomFileLabels.rejection].
///
/// Transfer *failures* are keyed by the transport's own stable error keys
/// (`file_transfer.not_found`, `file_transfer.rejected`, …) rather than by a
/// parallel vocabulary — see [tomTransferErrorMessage]. A server that already
/// publishes those keys therefore localises the failure line for free.
///
/// The percentage variants are split from the indeterminate ones instead of
/// interpolating `'…'` into one template, because a translation places the
/// number differently than it places an ellipsis, and a template that has to
/// accommodate both ends up correct in neither.
library;

import '../../widget_base/tom_construction_helpers.dart';

/// The user-visible strings of the file widgets.
///
/// Every method takes the field's `basePath` so a single field can override a
/// word without the application changing it everywhere; pass `null` when there
/// is no field in view (the indicator used stand-alone) and resolution starts at
/// the global key.
abstract final class TomFileLabels {
  /// The picker button on [TomFormFileUpload].
  static String choose(String? basePath) =>
      _text(basePath, 'file.choose', 'Choose file…');

  /// The caption shown when no file has been chosen.
  static String none(String? basePath) =>
      _text(basePath, 'file.none', '— no file selected');

  /// The invitation on an empty dropzone.
  static String dropzoneHint(String? basePath) =>
      _text(basePath, 'file.dropzoneHint', 'Tap to choose a file');

  /// The caption naming the chosen file and its [size].
  static String selected(String? basePath, String name, String size) => _text(
    basePath,
    'file.selected',
    '{name} ({size})',
    params: {'name': name, 'size': size},
  );

  /// The download affordance.
  static String download(String? basePath) =>
      _text(basePath, 'file.download', 'Download');

  /// The clear-the-field affordance.
  static String clear(String? basePath) =>
      _text(basePath, 'file.clear', 'Clear');

  /// The cancel-this-transfer affordance.
  static String cancel(String? basePath) =>
      _text(basePath, 'file.cancel', 'Cancel');

  /// The retry-this-transfer affordance.
  static String retry(String? basePath) =>
      _text(basePath, 'file.retry', 'Retry');

  /// The progress line for a transfer of known size, at [percent] per cent.
  static String progress(String? basePath, bool isDownload, int percent) =>
      _text(
        basePath,
        isDownload ? 'file.downloading' : 'file.uploading',
        isDownload ? 'Downloading {percent}%' : 'Uploading {percent}%',
        params: {'percent': percent},
      );

  /// The progress line for a transfer whose size is not known in advance.
  static String progressBusy(String? basePath, bool isDownload) => _text(
    basePath,
    isDownload ? 'file.downloadingBusy' : 'file.uploadingBusy',
    isDownload ? 'Downloading…' : 'Uploading…',
  );

  /// The confirmation left behind by a completed upload.
  static String uploaded(String? basePath) =>
      _text(basePath, 'file.uploaded', 'Uploaded.');

  /// The confirmation left behind by a completed download.
  static String downloaded(String? basePath) =>
      _text(basePath, 'file.downloaded', 'Downloaded.');

  /// The confirmation left behind by a completed delete.
  static String removed(String? basePath) =>
      _text(basePath, 'file.removed', 'Removed.');

  /// The confirmation for a completed transfer of no particular kind.
  static String done(String? basePath) => _text(basePath, 'file.done', 'Done.');

  /// The line shown after the user cancelled a transfer.
  static String cancelled(String? basePath) =>
      _text(basePath, 'file.cancelled', 'Transfer cancelled.');

  /// The heading of the "this file was refused" report.
  static String rejectedTitle(String? basePath) =>
      _text(basePath, 'file.rejectedTitle', 'File rejected');

  /// The dismiss affordance on that report.
  static String rejectedDismiss(String? basePath) =>
      _text(basePath, 'file.rejectedDismiss', 'OK');

  /// The reason a picked file was refused, for the [errorKey]
  /// [TomFormFileField.checkFile] returned.
  ///
  /// Those keys (`error.fileExtension`, `error.fileTooLarge`) are the *same*
  /// ones the auto-prepended validators raise, so an application that words its
  /// validation messages has already worded this one — the picker's immediate
  /// report and the form's later validation error cannot drift apart.
  static String rejection(String? basePath, String errorKey) =>
      resolve(basePath, errorKey, switch (errorKey) {
        'error.fileExtension' => 'That file type is not allowed.',
        'error.fileTooLarge' => 'That file is too large.',
        // An unknown key is more useful on screen than an empty line: it names
        // the rule that fired and is greppable in a bug report.
        _ => errorKey,
      });

  /// Resolves [key] scoped to [basePath], then globally, then [fallback],
  /// interpolating `{name}` placeholders from [params] at whichever level won.
  ///
  /// Public because [tomTransferErrorMessage] resolves the transport's error
  /// keys through exactly this order and there is no reason for a second,
  /// subtly different copy of it.
  static String resolve(
    String? basePath,
    String key,
    String fallback, {
    Map<String, Object?>? params,
  }) => _text(basePath, key, fallback, params: params);

  static String _text(
    String? basePath,
    String key,
    String fallback, {
    Map<String, Object?>? params,
  }) {
    final resolved =
        TomCtr.textOrNull(basePath, key) ?? TomCtr.textOrNull(key) ?? fallback;
    if (params == null || params.isEmpty) return resolved;
    var out = resolved;
    params.forEach((name, value) => out = out.replaceAll('{$name}', '$value'));
    return out;
  }
}
