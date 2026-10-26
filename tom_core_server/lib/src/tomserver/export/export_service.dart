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
/// `tom_core_codespecs/doc/codespecs_mapping.md` §5.28 names three:
/// `apiResponse`, `fileExport` and `email`. The first two are [respondWith] and
/// [storeAs]. The third is `TomExportEmailDelivery` (`export_email.dart`),
/// which sends a stored export through the messaging outbox rather than
/// delivering anything itself, so retry and delivery stay the outbox's.
///
/// With a `TomExportRegister`, [storeAs] also records each stored export —
/// which a `TomExportQuota` counts per owner and `TomExportRetention` purges.
library;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../file_storage/blob_store.dart';
import 'export_register.dart';
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
  ///
  /// [register], when given, records every export [storeAs] stores — who it
  /// belongs to, how large, when — which is what [quota] counts against and
  /// what [TomExportRetention] purges from. A quota needs a register.
  TomExportService({
    TomExportFormats? formats,
    this.store,
    this.register,
    this.quota,
  }) : formats = formats ?? TomExportFormats.standard() {
    if (quota != null && register == null) {
      // throws-outside-family: programmer error — a quota counts what a
      // register records, and there is none.
      throw ArgumentError('An export quota needs an export register.');
    }
  }

  /// The formats this service can produce.
  final TomExportFormats formats;

  /// Where [storeAs] writes, when the application has somewhere to write.
  final TomExportStore? store;

  /// The record of stored exports, or `null` when nothing is recorded.
  final TomExportRegister? register;

  /// How much one owner may store, or `null` for no limit.
  final TomExportQuota? quota;

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
  ///
  /// With a [register], the export is recorded under [owner] (default `''`,
  /// no one) with [result]'s title. With a [quota] and an [owner], the owner's
  /// usage is checked before rendering and the stored size after it; a store
  /// that does not fit is deleted again and refused
  /// (`export.quota.count_exceeded`, `export.quota.bytes_exceeded`). A store
  /// over a key the owner already holds replaces that export, and a refused
  /// replacement leaves the key empty: the store had already written over it.
  Future<TomStoredExport> storeAs(
    TomTabularResult result,
    String format, {
    required String key,
    String owner = '',
  }) async {
    final target = store;
    if (target == null) {
      throw TomExportException(
        'export.service.no_store',
        'This server is not configured to store exports.',
        parameters: {'key': key},
      );
    }
    final records = register;
    final limit = owner.isEmpty ? null : quota;
    TomExportUsage? usage;
    if (records != null && limit != null) {
      final held = await records.usageOf(owner);
      final previous = await records.find(key);
      final replacing = previous != null && previous.owner == owner;
      usage = replacing
          ? TomExportUsage(
              count: held.count - 1,
              bytes: held.bytes - previous.byteCount,
            )
          : held;
      limit.check(owner, usage);
    }
    final stored = await target.store(
      key: key,
      bytes: render(result, format),
      mediaType: formats.rendererFor(format).mediaType,
    );
    if (records == null) return stored;
    if (limit != null) {
      try {
        limit.check(owner, usage!, addedBytes: stored.byteCount);
      } on TomExportException {
        await target.delete(stored.key);
        await records.remove(stored.key);
        rethrow;
      }
    }
    await records.record(
      TomExportRecord(
        key: stored.key,
        owner: owner,
        mediaType: stored.mediaType,
        byteCount: stored.byteCount,
        storedAt: stored.storedAt,
        title: result.title,
      ),
    );
    return stored;
  }

  /// Deletes the stored export under [key] and its record; answers whether
  /// the store held it.
  Future<bool> deleteStored(String key) async {
    final target = store;
    if (target == null) {
      throw TomExportException(
        'export.service.no_store',
        'This server is not configured to store exports.',
        parameters: {'key': key},
      );
    }
    final deleted = await target.delete(key);
    await register?.remove(key);
    return deleted;
  }

  String keyFor(String baseName, String format, {DateTime? partitionOn}) {
    final fileName = formats
        .rendererFor(format)
        .fileNameFor(
          TomBlobStore.sanitiseKeySegment(
            baseName,
            fallback: _unnamedExportBaseName,
          ),
        );
    if (partitionOn == null) return TomExportStore.validateKey(fileName);
    final month = partitionOn.month.toString().padLeft(2, '0');
    final day = partitionOn.day.toString().padLeft(2, '0');
    return TomExportStore.validateKey(
      '${partitionOn.year}/$month/$day/$fileName',
    );
  }

  /// What both channels name an export whose base name sanitises to nothing.
  ///
  /// One constant rather than two literals: an empty report name is an odd
  /// input, and the two channels disagreeing about what to call it would be
  /// discovered by whoever hit it, on whichever channel they hit second.
  static const String _unnamedExportBaseName = 'export';

  /// Makes [fileName] safe to place inside a quoted header parameter.
  ///
  /// A file name reaches this point from a report title, which reaches it from
  /// a user. A quote or a newline in it would end the parameter and start
  /// another header — the download equivalent of an injection — so the
  /// characters that can do that are replaced rather than escaped, and
  /// non-ASCII is transliterated away because `filename=` is a Latin-1 field.
  /// Callers needing the original name in full should add their own
  /// `filename*=UTF-8''…` parameter.
  ///
  /// This is the `apiResponse` channel's half of the naming rule;
  /// [TomBlobStore.sanitiseKeySegment], which [keyFor] applies, is the
  /// `fileExport` channel's. They keep different characters because a header
  /// parameter and a storage key allow different ones — a space survives here
  /// and becomes `_` there — but they accept the same names, so a report name
  /// works on both channels or on neither.
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
    return sanitised.isEmpty ? _unnamedExportBaseName : sanitised;
  }
}
