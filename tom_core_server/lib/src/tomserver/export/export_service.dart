/// The two delivery channels, over one renderer and one store.
///
/// [TomExportService] is the seam an application actually calls: it knows the
/// registered formats and, optionally, where stored exports go, so an endpoint
/// asks for "this result, as `xlsx`" and gets back either a response or a
/// stored-file reference.
///
/// It is a thin object on purpose. Everything hard is in the renderers
/// (`tabular_renderer.dart`) or the store (`export_store.dart`); what is left
/// here is the part that would otherwise be copied into every endpoint that
/// exports something — picking the renderer, naming the file, and setting the
/// two headers a browser needs to download it rather than display it.
///
/// ## The channels
///
/// `codespecs_mapping.md` §5.28 names three: `apiResponse`, `fileExport` and
/// `email`. The first two are [respondWith] and [storeAs]. The third is not
/// here and should not be — an emailed export is a message with an attachment,
/// which is the `messaging` module's subject; it composes by rendering to the
/// store or to bytes and attaching the result, and inventing a third path here
/// would duplicate the outbox's retry and delivery semantics.
library;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'export_store.dart';
import 'tabular_renderer.dart';
import 'tabular_result.dart';

/// Renders tabular results and delivers them to a caller or to storage.
class TomExportService {
  /// Creates a service over [formats], defaulting to the three shipped ones.
  ///
  /// [store] is optional: an application that only streams exports back
  /// through its API never needs one, and requiring it would force a
  /// filesystem decision on a deployment that has no use for it. Calling
  /// [storeAs] without one is a configuration error and says so.
  TomExportService({TomExportFormats? formats, this.store})
    : formats = formats ?? TomExportFormats.standard();

  /// The formats this service can produce.
  final TomExportFormats formats;

  /// Where [storeAs] writes, when the application has somewhere to write.
  final TomExportStore? store;

  /// Renders [result] as [format], as a byte stream.
  ///
  /// The primitive both channels are built on, and the one to call directly
  /// when neither fits — attaching an export to a message, piping it into a
  /// hash, writing it to a socket.
  ///
  /// This is the **only** place in this class where a format id becomes bytes:
  /// [respondWith] and [storeAs] deliver whatever stream this returns. That is
  /// what makes it an extension point rather than a convenience — an override
  /// adding a metric, a trace or a row limit is on every channel's path, not
  /// only on the path of the callers who invoke it explicitly, which is the
  /// rarest case of the three.
  ///
  /// An override may wrap, meter or refuse the stream. It should not change
  /// which *format* is produced: the channels ask [formats] what a format id
  /// **is** — its media type, its file extension — and ask this method only
  /// what it **produces**, so a substituted format would be delivered under the
  /// original's labels.
  Stream<List<int>> render(TomTabularResult result, String format) =>
      formats.rendererFor(format).render(result);

  /// A shelf response that streams [result] as [format] — the `apiResponse`
  /// channel.
  ///
  /// [baseName] names the download without its extension; the renderer adds
  /// the one that matches the format, so a caller never has to keep the two in
  /// step. [inline] switches the disposition from `attachment` to `inline`,
  /// which is worth doing only for PDF: it is the one of the three formats a
  /// browser can display itself.
  ///
  /// The body is the renderer's stream, unbuffered — a CSV of a million rows
  /// starts arriving at the client while the query is still running, and the
  /// server's memory does not know the difference between that and ten rows.
  /// No `Content-Length` is set for the same reason: the length is not known
  /// until the last row, and the alternative to omitting it is buffering the
  /// document to measure it. Shelf falls back to chunked transfer encoding.
  Response respondWith(
    TomTabularResult result,
    String format, {
    required String baseName,
    bool inline = false,
  }) {
    // The registry is asked what the format *is*; [render] is asked what it
    // *produces*. Resolving here also means an unknown format fails before a
    // response object exists, rather than as an error on its body.
    final renderer = formats.rendererFor(format);
    final fileName = renderer.fileNameFor(baseName);
    return Response.ok(
      render(result, format),
      headers: {
        TomHeader.contentType: renderer.mediaType,
        TomHeader.contentDisposition:
            '${inline ? 'inline' : 'attachment'}; '
            'filename="${sanitiseFileName(fileName)}"',
      },
    );
  }

  /// Renders [result] as [format] and stores it — the `fileExport` channel.
  ///
  /// [key] is the storage key; its extension is not implied, so pass one the
  /// renderer produced (`renderer.fileNameFor(...)`) or a partitioned key like
  /// `2026/07/sales.xlsx`. Returns the descriptor the caller keeps: the key to
  /// read it back with, and the size it turned out to be.
  Future<TomStoredExport> storeAs(
    TomTabularResult result,
    String format, {
    required String key,
  }) {
    final target = store;
    if (target == null) {
      throw TomExportException(
        'export.service.no_store',
        'This server is not configured to store exports.',
        parameters: {'key': key},
      );
    }
    return target.store(
      key: key,
      bytes: render(result, format),
      mediaType: formats.rendererFor(format).mediaType,
    );
  }

  /// A storage key for [baseName] in [format], optionally date-partitioned.
  ///
  /// Exports accumulate, and a flat directory of them becomes unlistable long
  /// before it becomes large. Partitioning by day is the cheap fix that also
  /// makes expiry a matter of deleting a prefix.
  String keyFor(String baseName, String format, {DateTime? partitionOn}) {
    final fileName = formats.rendererFor(format).fileNameFor(baseName);
    if (partitionOn == null) return TomExportStore.validateKey(fileName);
    final month = partitionOn.month.toString().padLeft(2, '0');
    final day = partitionOn.day.toString().padLeft(2, '0');
    return TomExportStore.validateKey(
      '${partitionOn.year}/$month/$day/$fileName',
    );
  }

  /// Makes [fileName] safe to place inside a quoted header parameter.
  ///
  /// A file name reaches this point from a report title, which reaches it from
  /// a user. A quote or a newline in it would end the parameter and start
  /// another header — the download equivalent of an injection — so the
  /// characters that can do that are replaced rather than escaped, and
  /// non-ASCII is transliterated away because `filename=` is a Latin-1 field.
  /// Callers needing the original name in full should add their own
  /// `filename*=UTF-8''…` parameter.
  static String sanitiseFileName(String fileName) {
    final buffer = StringBuffer();
    for (final rune in fileName.runes) {
      final safe =
          rune >= 0x20 &&
          rune < 0x7F &&
          rune != 0x22 && // "
          rune != 0x5C && // \
          rune != 0x3B && // ;
          rune != 0x2F; // /
      buffer.writeCharCode(safe ? rune : 0x5F);
    }
    final sanitised = buffer.toString().trim();
    return sanitised.isEmpty ? 'export' : sanitised;
  }
}
