/// The renderer abstraction: one tabular result, many byte formats.
///
/// A [TomTabularRenderer] turns a [TomTabularResult] into a `Stream<List<int>>`.
/// That signature is the whole design, and both halves of it are deliberate.
///
/// ## Why a byte *stream* out
///
/// The alternative — `Future<Uint8List>` — forces the entire rendered document
/// into memory before anything can be done with it, which for the exports large
/// enough to be worth exporting is exactly the failure mode to avoid. A stream
/// lets the same renderer feed a `shelf` response body, a file sink, or a blob
/// upload without any of them waiting for the last row.
///
/// It also makes the two delivery channels
/// `tom_core_codespecs/doc/codespecs_mapping.md` §5.28 names the *same* code
/// path: `apiResponse` pipes the stream to the client, `fileExport` pipes it to
/// storage. Neither needs a variant renderer.
///
/// ## Why bytes and not text
///
/// CSV is text, XLSX is a ZIP archive and PDF is a binary document. Typing the
/// abstraction as text would make two of three formats encode-then-decode
/// through a `String`, corrupting them. Bytes is the only common denominator,
/// and the text formats simply encode as they go.
///
/// ## What a renderer may assume
///
/// - Each section's row stream is pulled **once**, in order, to completion.
/// - Cell values match their column's [TomColumnType], or are `null`.
/// - The returned stream is not listened to more than once.
///
/// A renderer that meets those may hold no more than one row at a time. Whether
/// it *does* is a per-format property that the format itself decides; see
/// [TomTabularRenderer.streamsRows].
library;

import 'dart:async';

import 'csv_renderer.dart';
import 'pdf_renderer.dart';
import 'tabular_result.dart';
import 'xlsx_renderer.dart';

/// Renders a [TomTabularResult] to a byte stream in one concrete format.
abstract class TomTabularRenderer {
  /// Creates a renderer.
  const TomTabularRenderer();

  /// The short, lowercase format key: `csv`, `xlsx`, `pdf`.
  ///
  /// This is what a report definition's delivery channel names, what a query
  /// parameter carries, and what [TomExportFormats] registers under.
  String get formatId;

  /// The IANA media type to serve or store the output as.
  String get mediaType;

  /// The filename extension, without the dot.
  String get fileExtension;

  /// Whether the format renders in memory bounded by one row rather than all.
  ///
  /// `true` for the formats whose output is written strictly front-to-back —
  /// CSV and XLSX. `false` for PDF, whose file structure ends with a
  /// cross-reference table of byte offsets into everything before it, so no
  /// conforming writer can emit the first page before knowing the last. The
  /// flag is exposed rather than hidden because it is the one property a caller
  /// deciding *whether to allow* an export of a given size needs to know.
  ///
  /// Declaring it `true` promises two things, which are the two ways the
  /// property is lost: a row is not read once the next has been pulled — rows
  /// are handed over uncopied, so by then it may hold something else — and
  /// output is not held back, so the last row is followed by a constant tail
  /// rather than by the whole document.
  bool get streamsRows => true;

  /// Renders [result], emitting the encoded document as it is produced.
  ///
  /// The stream is single-subscription. Errors surface on the stream rather
  /// than being thrown from this call — by the time the first row fails to
  /// render, this method has long returned.
  Stream<List<int>> render(TomTabularResult result);

  /// A filename for [baseName] in this format, with the extension applied.
  String fileNameFor(String baseName) => '$baseName.$fileExtension';

  @override
  String toString() => '$runtimeType($formatId)';
}

/// The set of formats an application offers, keyed by [TomTabularRenderer.formatId].
///
/// A registry rather than a switch so that an application can add a format —
/// a fixed-width extract a partner insists on, an internal JSON-lines dump —
/// without the export service knowing about it.
class TomExportFormats {
  /// Creates an empty registry.
  TomExportFormats();

  /// Creates a registry holding the three formats this package ships.
  ///
  /// Constructed on demand rather than exposed as a shared instance: a registry
  /// is mutable, and a process-wide mutable default is a race between whichever
  /// modules register first.
  factory TomExportFormats.standard() => TomExportFormats()
    ..register(const TomCsvRenderer())
    ..register(const TomXlsxRenderer())
    ..register(const TomPdfRenderer());

  final Map<String, TomTabularRenderer> _renderers = {};

  /// Registers [renderer], replacing any renderer with the same format id.
  ///
  /// Replacement is allowed on purpose: overriding the stock CSV renderer with
  /// one that emits semicolons for a European locale should not require a new
  /// format id, because it is still the format the caller asked for.
  void register(TomTabularRenderer renderer) {
    _renderers[renderer.formatId] = renderer;
  }

  /// The registered format ids, in registration order.
  Iterable<String> get formatIds => _renderers.keys;

  /// The registered renderers, in registration order.
  Iterable<TomTabularRenderer> get renderers => _renderers.values;

  /// Whether [formatId] is registered.
  bool supports(String formatId) => _renderers.containsKey(formatId);

  /// The renderer for [formatId].
  ///
  /// Throws [TomExportException] when the format is unknown — a caller naming a
  /// format that is not there has asked for a document that cannot exist, and
  /// returning `null` would only move that failure somewhere less informative.
  TomTabularRenderer rendererFor(String formatId) {
    final renderer = _renderers[formatId];
    if (renderer == null) {
      throw TomExportException(
        'export.format.unknown',
        'No renderer is registered for the requested export format.',
        parameters: {
          'format': formatId,
          'available': _renderers.keys.join(', '),
        },
      );
    }
    return renderer;
  }
}

/// Formats a cell for the text-oriented renderers.
///
/// Shared rather than duplicated per renderer because "how does a `DateTime`
/// appear in an export" is one decision, not three — and the day it becomes
/// configurable it must become configurable everywhere at once.
///
/// The rules: `null` is empty, `DateTime` is ISO-8601, `double` drops a
/// trailing `.0` so whole numbers do not read as approximations, and everything
/// else is `toString()`.
String tomFormatCellAsText(Object? value) => switch (value) {
  null => '',
  DateTime() => value.toIso8601String(),
  double() =>
    value == value.roundToDouble() && value.abs() < 1e15
        ? value.toInt().toString()
        : value.toString(),
  _ => value.toString(),
};
