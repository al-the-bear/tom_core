/// The framework's HTTP file endpoint: the server half of the file-transfer
/// wire contract the kernel's `TomHttpFileTransferClient` speaks.
///
/// The two halves of file storage live in different packages. The server owns
/// the *store* — blob backends, `@TomFileReference` columns and the four
/// repository methods `saveFile` / `openFile` / `describeFile` / `clearFile`.
/// The kernel owns the *client* — `POST`/`GET`/`HEAD`/`DELETE` on
/// `<baseUri>/<slot>`, the JSON descriptor, the `x-tom-file` headers. This class
/// is the handler between them, and that handler is the same in every
/// application: map a slot to an entity and a file column, stream the request
/// body into `saveFile`, stream `openFile` back out, answer `HEAD` from
/// `describeFile`, `clearFile` on `DELETE`. Which is why it lives here, once,
/// rather than in every application that serves a file.
///
/// ## The slot is derived, not declared
///
/// A slot is `<table>/<id>/<column>`, and both names come from annotations the
/// entity already carries: `@TomDbTable.table` and the column's mapped name. No
/// application-supplied mapping table exists, so there is no second copy of the
/// entity name, the column name or the store name to go stale — renaming a
/// column moves the slot with it, and a column that no longer exists fails at
/// registration rather than at request time.
///
/// ## Exposure is default-closed
///
/// Reflection can *see* every file column; it publishes none of them. A column
/// is reachable over HTTP only when its `@TomFileReference` says
/// `exposed: true`. Whether a file may be fetched over HTTP is an authorization
/// decision, so it is declared next to the column it exposes.
///
/// What exposure decides is *which* column a slot names — never *whether* the
/// caller may have it. That stays where it already is: the row scope (C-3) and
/// column grade (C-4) the repository enforces on every one of these calls, and
/// the endpoint access check the surrounding pipeline runs before the handler is
/// entered. A file endpoint is not a hole in the C-grade model.
///
/// ## Wiring it up
///
/// One line per entity, naming the repository and nothing else — `T` and `K`
/// come from the repository's own type arguments:
///
/// ```dart
/// TomFileSlots.register(documentRepository); // TomFileRepository<Document, int>
/// TomBean.withType(TomFileServer, TomFileServer());
/// ```
///
/// The client then addresses it with no knowledge of any of the above:
///
/// ```dart
/// final client = TomHttpFileTransferClient(
///   baseUri: Uri.parse('http://localhost:8080/files'),
/// );
/// await client.upload(slot: 'document/42/attachment', source: source);
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../file_storage/blob_store.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/column_authorization.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/data_scope.dart';
import '../object_persistence/persistence_annotations.dart';
import 'endpoint_annotation.dart';
import 'endpoint_pipeline.dart';
import 'form_binding.dart';

/// Thrown while registering or resolving a file slot.
///
/// Registration failures ([TomFileSlots.register]) are *scan-time* errors —
/// they surface when the application wires itself up, not when a user uploads a
/// file, which is the whole point of deriving slots from reflection.
class TomFileSlotException extends TomServerException {
  /// Creates the exception; parameters mirror [TomServerException].
  TomFileSlotException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// One addressable file column: everything [TomFileEndpoint] needs to serve
/// `<table>/<id>/<column>`, with the entity and key types already bound.
///
/// The endpoint is not generic and cannot be — a URL carries strings, and the
/// entity type behind a slot is only known once the application registers its
/// repository. This interface is where the generics stop: [TomFileSlots] stores
/// slots as `TomFileSlot`, and each one closes over the `<T, K>` it was
/// registered with.
abstract class TomFileSlot {
  /// The table name the slot is addressed by (`@TomDbTable.table`).
  String get table;

  /// The column name the slot is addressed by (the mapped column name).
  String get column;

  /// Stores [bytes] against the row [rawId] and returns the descriptor of what
  /// was stored.
  ///
  /// The key is minted by the store, never named by the caller: a client that
  /// could choose a key could choose someone else's.
  Future<TomFileMetadata> upload(
    String rawId,
    Stream<List<int>> bytes, {
    String? mediaType,
    String? fileName,
  });

  /// The descriptor of the file on row [rawId], or `null` when the row holds
  /// none.
  Future<TomFileMetadata?> describe(String rawId);

  /// Streams the file on row [rawId], or [range] of it.
  Stream<List<int>> open(String rawId, {TomBlobRange? range});

  /// Removes the file on row [rawId]; `false` when there was none to remove.
  Future<bool> clear(String rawId);
}

/// A [TomFileSlot] bound to one entity type, key type and file column.
class _TypedFileSlot<T extends Object, K> extends TomFileSlot {
  _TypedFileSlot({
    required this.table,
    required this.columnInformation,
    required this.repository,
  });

  @override
  final String table;

  /// The reflected metadata of the `@TomFileReference` column this slot serves.
  final TomColumnInformation columnInformation;

  /// The repository that owns the row and moves the bytes.
  final TomFileRepository<T, K> repository;

  @override
  String get column => columnInformation.getQueryFieldName();

  /// The column's name as the repository knows it.
  String get _field => columnInformation.declaredName;

  /// Coerces the raw path segment into the entity's key type.
  ///
  /// Reuses the pipeline's own path-variable coercion so `/files/document/42/…`
  /// binds an `int` key the same way `/documents/{id}` does — one rule for what
  /// a URL segment means, not two.
  K _id(String raw) {
    final coerced = TomEndpointHandler.coercePrimitiveParameter(K, raw);
    if (coerced is! K) {
      throw TomFileSlotException(
        'file_endpoint.invalid_id',
        'The record id in the slot is not a $K.',
        parameters: {'table': table, 'column': column, 'id': raw},
      );
    }
    return coerced;
  }

  /// The row [id], or a `row_not_found` failure when it does not exist — or is
  /// not visible to the principal, which is deliberately the same answer.
  Future<T> _row(K id) async {
    final entity = await repository.findById(id);
    if (entity == null) {
      throw TomStorageException(
        'storage.file_reference.row_not_found',
        'No such record exists, or it is not visible to you.',
        parameters: {'entity': '$T', 'id': '$id'},
      );
    }
    return entity;
  }

  @override
  Future<TomFileMetadata> upload(
    String rawId,
    Stream<List<int>> bytes, {
    String? mediaType,
    String? fileName,
  }) async {
    final id = _id(rawId);
    final entity = await _row(id);
    await repository.saveFile(
      entity,
      _field,
      bytes,
      mediaType: mediaType,
      fileName: fileName,
    );
    final stored = await repository.describeFile(id, _field);
    if (stored == null) {
      // The row took the key and the store has the bytes, or `saveFile` would
      // have thrown. A descriptor that is absent anyway means the two disagree.
      throw TomFileSlotException(
        'file_endpoint.stored_file_not_readable',
        'The file was stored but cannot be described.',
        parameters: {'table': table, 'column': column, 'id': rawId},
      );
    }
    return _metadataOf(stored);
  }

  @override
  Future<TomFileMetadata?> describe(String rawId) async {
    final stored = await repository.describeFile(_id(rawId), _field);
    return stored == null ? null : _metadataOf(stored);
  }

  @override
  Stream<List<int>> open(String rawId, {TomBlobRange? range}) =>
      repository.openFile(_id(rawId), _field, range: range);

  @override
  Future<bool> clear(String rawId) async {
    final id = _id(rawId);
    final entity = await _row(id);
    // Asked through the repository rather than read off the entity: this is the
    // call that applies the column grade (C-4), and a masked column reads back
    // `null` — indistinguishable from "no file" if we looked at the field
    // ourselves, which would turn a refusal into a silent 404.
    if (await repository.describeFile(id, _field) == null) return false;
    await repository.clearFile(entity, _field);
    return true;
  }

  /// Translates the store's descriptor into the wire descriptor.
  ///
  /// The wire shape belongs to the kernel ([TomFileMetadata]) precisely so that
  /// this is the only place the two vocabularies meet.
  TomFileMetadata _metadataOf(TomStoredBlob stored) => TomFileMetadata(
    key: stored.key,
    mediaType: stored.mediaType,
    byteCount: stored.byteCount,
    fileName: stored.fileName,
    storedAt: stored.storedAt,
    // `unknownDigest` becomes `null` rather than an empty string: the wire
    // descriptor omits what it does not know, and an empty `digest` member
    // would read as a value.
    digest: stored.hasDigest ? stored.digest : null,
  );
}

/// The registry of HTTP-reachable file columns, keyed by table and column name.
///
/// Registration is per repository, not per column: the repository is the only
/// thing an application has to name, because it already carries the entity type,
/// the key type and — through the entity's annotations — the table name, the
/// column names and the blob store. Anything else would be a restatement, and a
/// restatement is what drifts.
///
/// ## Its lifetime is the isolate's, and that is a bootstrap requirement
///
/// The registry is a **process-wide static**, and Dart isolates do not share
/// statics — so it is really one registry *per isolate*. An application that
/// serves from several isolates must run its [register] calls in each of them,
/// which is what a server bootstrap already does: the registration sits in the
/// start-up path every isolate runs, beside the bean wiring and the data-source
/// configuration, not in a `main()` one isolate reaches and the others do not.
///
/// Static rather than owned state because the alternative buys nothing here.
/// The registry is written once at start-up and read on every file request; a
/// bean-scoped one would make the lifetime the server's rather than the
/// process's, which is the same lifetime in every deployment this framework
/// builds, at the cost of threading a dependency through [TomFileEndpoint],
/// `TomFormFileStorage` and every call site of [resolve].
///
/// What the static *does* cost is a silent failure mode: an isolate that never
/// ran the registration answers every file request with "no such slot", which is
/// indistinguishable from a column that is deliberately closed. [resolve]
/// removes it — see there.
class TomFileSlots {
  TomFileSlots._();

  static final Map<String, Map<String, TomFileSlot>> _slots = {};

  /// Registers every **exposed** `@TomFileReference` column of [T].
  ///
  /// Fails loudly and at wire-up time when the entity is not mapped, exposes no
  /// file column, or would produce an ambiguous slot. That is the trade the
  /// reflection-derived design buys: the failures a hand-written mapping table
  /// would have shown at request time show here instead.
  ///
  /// **Call this in the start-up path every isolate runs.** The registry it
  /// writes to is a static, and statics are per isolate, so a registration that
  /// happens in one isolate is invisible to every other one — see the class
  /// documentation. Registering twice in one isolate is refused
  /// (`file_endpoint.duplicate_slot`), so a bootstrap that runs once per
  /// isolate is both the requirement and the only thing that works.
  static void register<T extends Object, K>(
    TomFileRepository<T, K> repository,
  ) {
    final table = TomAnnotationAnalyzer.findTable(T);
    if (table == null) {
      throw TomFileSlotException(
        'file_endpoint.entity_not_mapped',
        'Cannot expose files of an entity that declares no @TomDbTable.',
        parameters: {'entity': '$T'},
      );
    }
    final fileColumns = TomAnnotationAnalyzer.findFileColumns(T);
    _assertUnambiguous(table.table, fileColumns);

    final exposed = [
      for (final column in fileColumns)
        if (column.fileReference!.exposed) column,
    ];
    if (exposed.isEmpty) {
      throw TomFileSlotException(
        'file_endpoint.no_exposed_column',
        'That entity has no @TomFileReference column marked exposed: true.',
        parameters: {'entity': '$T', 'table': table.table},
      );
    }

    final registered = _slots.putIfAbsent(table.table, () => {});
    for (final column in exposed) {
      final name = column.getQueryFieldName();
      if (registered.containsKey(name)) {
        throw TomFileSlotException(
          'file_endpoint.duplicate_slot',
          'Two entities expose the same table and column as a file slot.',
          parameters: {'entity': '$T', 'table': table.table, 'column': name},
        );
      }
      registered[name] = _TypedFileSlot<T, K>(
        table: table.table,
        columnInformation: column,
        repository: repository,
      );
    }
  }

  /// Rejects a set of file columns in which a slot name would be ambiguous.
  ///
  /// Checked across **all** file columns of the entity, not just the exposed
  /// ones, because the repository resolves a field by its declared name *or* its
  /// mapped column name. A column named `secret` with another column mapped to
  /// the column name `secret` would let the exposed one address the closed one —
  /// an exposure by accident, which is exactly what the default-closed rule
  /// exists to prevent.
  static void _assertUnambiguous(
    String table,
    List<TomColumnInformation> fileColumns,
  ) {
    final seen = <String, String>{};
    for (final column in fileColumns) {
      for (final name in {column.declaredName, column.getQueryFieldName()}) {
        final owner = seen[name];
        if (owner != null && owner != column.declaredName) {
          throw TomFileSlotException(
            'file_endpoint.ambiguous_slot',
            'Two file columns of the same entity answer to the name "$name".',
            parameters: {
              'table': table,
              'name': name,
              'columns': [owner, column.declaredName],
            },
          );
        }
        seen[name] = column.declaredName;
      }
    }
  }

  /// The slot serving `<table>/<column>`, or `null` when none is exposed.
  ///
  /// A non-exposed column is indistinguishable from a non-existent one here, and
  /// that is the intent: the endpoint answers both with a plain 404 rather than
  /// telling a caller which columns exist but are closed to them.
  ///
  /// An **empty registry** is the one case that does not get that answer. It
  /// means no slot was registered in this isolate at all, which a file request
  /// arriving here says somebody expected one — and the two readings of "no such
  /// slot" are then a closed column and a bootstrap that did not run, which no
  /// caller and no operator can tell apart from a 404. So it is refused by name
  /// and logged, and the request fails as the server fault it is.
  ///
  /// The trigger is deliberately "a file request arrived **and** the registry is
  /// empty", not "the registry is empty": a deployment that exposes no file
  /// columns is not misconfigured, it simply has no caller asking, and it never
  /// reaches this.
  static TomFileSlot? resolve(String table, String column) {
    if (_slots.isEmpty) {
      throw TomFileSlotException(
        'file_endpoint.no_slots_registered',
        'This server has no file slots registered.',
        parameters: {'table': table, 'column': column},
        autoLog: true,
      );
    }
    return _slots[table]?[column];
  }

  /// Every registered slot, as `<table>/<column>` — for diagnostics and tests.
  static List<String> get slots => [
    for (final table in _slots.entries)
      for (final column in table.value.keys) '${table.key}/$column',
  ];

  /// Forgets every registration.
  ///
  /// Exists for tests, which build a fresh registry per case; an application
  /// registers once per isolate at startup and never calls this. A test that
  /// resets while another test's slots are live deregisters them too — they
  /// share the isolate, and the registry is the isolate's.
  static void reset() => _slots.clear();
}

/// Stores a file that arrived as one part of a `multipart/form-data` request.
///
/// This is the join between the two upload shapes, and it is deliberately thin:
/// a form part reaches the blob store through the *same* [TomFileSlot] the
/// raw-body endpoint uses, so exposure ([TomFileReference.exposed]), the row
/// scope (C-3) and the column grade (C-4) all apply to it unchanged. There is
/// one route from bytes to storage; multipart only changes how the bytes get to
/// the handler.
///
/// The call is the handler's, not the pipeline's, and that ordering is
/// load-bearing: on a create the row does not exist while the request body is
/// being read, so the id the slot is addressed by is only known once the
/// handler has saved the entity.
///
/// ```dart
/// final saved = await documents.save(request.toDocument());
/// await attachment.storeIn('document', 'attachment', '${saved.id}');
/// ```
extension TomFormFileStorage on TomFormFile {
  /// Stores this part in the file slot `<table>/<column>` of row [rowId].
  ///
  /// Throws [TomFileSlotException] when no such slot is exposed — the same
  /// answer the HTTP endpoint gives, because it is the same registry and the
  /// same default-closed rule.
  Future<TomFileMetadata> storeIn(
    String table,
    String column,
    String rowId,
  ) async {
    final slot = TomFileSlots.resolve(table, column);
    if (slot == null) {
      throw TomFileSlotException(
        'file_endpoint.unknown_slot',
        'No such file slot.',
        parameters: {'table': table, 'column': column, 'field': field},
      );
    }
    return slot.upload(
      rowId,
      openRead(),
      mediaType: mediaType,
      fileName: fileName,
    );
  }
}

/// Serves the file-transfer wire contract over the registered [TomFileSlots].
///
/// Stateless: everything it needs is in the request and the registry, so the
/// component that mounts it ([TomFileServer]) holds nothing.
class TomFileEndpoint {
  TomFileEndpoint._();

  /// The path the endpoint is mounted at; a client's `baseUri` ends here.
  static const String basePath = '/files';

  /// The route pattern, with the three slot segments as path variables.
  static const String routeUri = '$basePath/{entity}/{id}/{column}';

  /// Serves one file request, dispatching on the HTTP method.
  ///
  /// Takes the shelf [Request] and returns a shelf [Response] rather than a
  /// reflected DTO because both directions must stream: a file large enough to
  /// be worth storing is large enough not to want in memory twice.
  static Future<Response> handle(Request request) async {
    final table = request.params['entity'];
    final id = request.params['id'];
    final column = request.params['column'];
    if (table == null || id == null || column == null) {
      return _error(404, 'file_endpoint.unknown_slot', 'No such file slot.');
    }
    final slot = TomFileSlots.resolve(table, column);
    if (slot == null) {
      return _error(404, 'file_endpoint.unknown_slot', 'No such file slot.');
    }
    try {
      switch (request.method.toUpperCase()) {
        case 'POST':
        case 'PUT':
          return await _upload(request, slot, id);
        case 'GET':
          return await _download(request, slot, id);
        case 'HEAD':
          return await _head(request, slot, id);
        case 'DELETE':
          return await _delete(slot, id);
        default:
          return _error(
            405,
            'file_endpoint.method_not_allowed',
            'That method is not supported for a file slot.',
          );
      }
    } on TomColumnAuthorizationException catch (error) {
      // C-4 refused the column. Reported as 403 and not as 404: the caller is
      // addressing a slot that exists and they may not have, and a repository
      // that says so explicitly should not be softened into "no such thing".
      return _error(403, error.key, error.defaultUserMessage);
    } on TomDataScopeAuthorizationException catch (error) {
      // C-3 refused the row — and unlike the column above this is a 404, not a
      // 403. The two gates answer different questions. A column refusal says
      // "this field of this row is closed to you", which presumes the row; a
      // row refusal must not presume anything, because a slot is addressed as
      // `<table>/<id>/<column>` with the id supplied by the caller. A 403 here
      // would confirm that the guessed id names a real row belonging to someone
      // else, which is the disclosure the scope exists to prevent. So an
      // out-of-scope row answers exactly as an absent one does.
      //
      // The read paths reach that answer on their own — a scoped read filters
      // the row away and reports `row_not_found`. This clause covers the write
      // side of the contract, where the repository *names* the refusal rather
      // than filtering it, and without it a `TomFileRepository` whose write gate
      // is stricter than its read gate would escape to the pipeline's generic
      // handler as a 500 — itself distinguishable from a 404, and so itself the
      // leak.
      return _error(404, error.key, error.defaultUserMessage);
    } on TomStorageException catch (error) {
      final status = switch (error.key) {
        'storage.file_reference.row_not_found' => 404,
        'storage.file_reference.no_file' => 404,
        'storage.blob.not_found' => 404,
        'storage.file_reference.unknown_column' => 404,
        _ => null,
      };
      if (status == null) rethrow;
      return _error(status, error.key, error.defaultUserMessage);
    } on TomFileSlotException catch (error) {
      if (error.key != 'file_endpoint.invalid_id') rethrow;
      return _error(400, error.key, error.defaultUserMessage);
    }
  }

  static Future<Response> _upload(
    Request request,
    TomFileSlot slot,
    String id,
  ) async {
    final metadata = await slot.upload(
      id,
      // Handed on un-read. The endpoint declares a non-JSON `consumes`, so the
      // pipeline never materialises the body, and this stream is the socket.
      request.read(),
      mediaType: request.headers[TomHeader.contentType],
      fileName: tomFileNameFromDisposition(
        request.headers[TomHeader.contentDisposition],
      ),
    );
    return Response(
      201,
      body: jsonEncode(metadata.toJson()),
      headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
    );
  }

  static Future<Response> _download(
    Request request,
    TomFileSlot slot,
    String id,
  ) async {
    final metadata = await slot.describe(id);
    if (metadata == null) {
      return _error(404, 'file_endpoint.no_file', 'No file is stored there.');
    }
    final headers = {
      ...tomFileDescriptorHeaders(metadata),
      // Advertised on every download, because a client that means to resume
      // asks this first. Without it a browser will not attempt a range at all,
      // and the backends' seeking would never be reached from the wire.
      'accept-ranges': 'bytes',
    };

    // Answered before the range, and before anything is read: a conditional
    // request the caller already satisfies costs one `describe`, whatever it
    // asked for. RFC 9110 puts `If-None-Match` ahead of `Range` for exactly
    // this reason — a client resuming a download it turns out already has in
    // full should not be handed a `206`.
    if (_matches(request.headers['if-none-match'], metadata.digest)) {
      // A 304 carries the validators and no body. `Content-Length` is dropped
      // rather than set to 0: it describes the representation, and a zero here
      // tells a cache the resource is empty.
      final unchanged = Map.of(headers)..remove('content-length');
      return Response.notModified(headers: unchanged);
    }

    final asked = _rangeOf(request.headers['range'], metadata.byteCount);
    if (asked == null) {
      return Response.ok(_inCurrentZone(() => slot.open(id)), headers: headers);
    }

    final range = asked.clampedTo(metadata.byteCount);
    if (range == null) {
      // 416, and it carries `Content-Range: bytes */size` — the one response
      // that tells a client resuming from a stale size what the size now is,
      // which is what lets it retry correctly instead of looping.
      return Response(
        416,
        body: jsonEncode({
          'key': 'file_endpoint.range_not_satisfiable',
          'message': 'That byte range lies beyond the end of the file.',
        }),
        headers: {
          TomHeader.contentType: TomMimeType.json.toHeaderValue(),
          'accept-ranges': 'bytes',
          'content-range': 'bytes */${metadata.byteCount}',
        },
      );
    }

    final end = range.endExclusive! - 1;
    return Response(
      206,
      body: _inCurrentZone(() => slot.open(id, range: range)),
      headers: {
        ...headers,
        // Both rewritten for the partial: the length is the slice's, and
        // `Content-Range` is inclusive at both ends where this module's range
        // is not. Leaving the whole file's length here is how a client waits
        // forever for bytes that are not coming.
        'content-length': '${range.length}',
        'content-range': 'bytes ${range.start}-$end/${metadata.byteCount}',
      },
    );
  }

  /// Whether [header] lists an entity tag matching [digest].
  ///
  /// `*` matches anything that exists, which is what it means in
  /// `If-None-Match`. Otherwise each comma-separated tag is compared to the
  /// strong tag this endpoint writes; a `W/` prefix is accepted because the
  /// *weak* comparison is the one `If-None-Match` specifies, and a cache is
  /// entitled to send back a tag it weakened.
  ///
  /// A file with no digest matches nothing: it has no validator, so a
  /// conditional request against it cannot be satisfied and the bytes are
  /// served.
  static bool _matches(String? header, String? digest) {
    if (header == null) return false;
    if (digest == null || digest.isEmpty) return false;
    final tag = '"$digest"';
    for (final candidate in header.split(',')) {
      final trimmed = candidate.trim();
      if (trimmed == '*') return true;
      final strong = trimmed.startsWith('W/') ? trimmed.substring(2) : trimmed;
      if (strong == tag) return true;
    }
    return false;
  }

  /// The single byte range [header] asks for, or `null` for no usable one.
  ///
  /// Deliberately **lenient**: an unparsable header, a unit other than `bytes`,
  /// or more than one range answers `null`, and the caller then serves the whole
  /// file with a 200. RFC 9110 permits exactly that, and it is the right trade
  /// here — a multipart/byteranges body is a second wire format for a case no
  /// browser needs, and refusing a header we merely do not understand would
  /// break a download that would otherwise have worked.
  ///
  /// The three forms: `bytes=500-999` is `[500, 1000)`, `bytes=500-` runs to
  /// the end, and the suffix form `bytes=-500` means *the last 500 bytes*.
  /// [byteCount] is taken because the suffix form cannot be resolved without
  /// it — it counts backwards from an end this header never names.
  ///
  /// `bytes=-0` asks for the last nothing, which the RFC calls unsatisfiable;
  /// it comes back as a range starting at [byteCount], which
  /// [TomBlobRange.clampedTo] then reports as such. That keeps "the caller
  /// asked for something impossible" (416) apart from "this header says nothing
  /// I understand" (200 and the whole file), which are different answers.
  static TomBlobRange? _rangeOf(String? header, int byteCount) {
    if (header == null) return null;
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null) return null;
    final from = match.group(1)!;
    final to = match.group(2)!;
    if (from.isEmpty && to.isEmpty) return null;
    if (from.isEmpty) {
      final wanted = int.parse(to);
      if (wanted == 0) return TomBlobRange(byteCount);
      return TomBlobRange((byteCount - wanted).clamp(0, byteCount), byteCount);
    }
    final start = int.parse(from);
    if (to.isEmpty) return TomBlobRange(start);
    final endInclusive = int.parse(to);
    // A backwards range is nonsense rather than unsatisfiable, so it is ignored
    // like any other header this does not understand.
    if (endInclusive < start) return null;
    return TomBlobRange(start, endInclusive + 1);
  }

  /// [open]'s stream, opened and consumed in the zone this is called from.
  ///
  /// A response body is *lazy*: the handler returns a stream and shelf hands it
  /// to the socket, so nothing is read until the request has already returned
  /// and the zone the authentication middleware established — the one holding
  /// the [TomPrincipal] — is no longer current. For a file that is not an
  /// implementation detail. `openFile` is a scoped read, and a `@TomDbScope`
  /// predicate resolves its principal from the zone; subscribed outside the
  /// request it finds none, filters the row away, and raises `row_not_found`
  /// *after* the 200 and its headers are on the wire. The caller is left with a
  /// truncated body and a status code that says the opposite of what happened.
  ///
  /// So the subscription is made where the request still is. The controller
  /// defers [open] until something listens, then runs both the call and the
  /// `listen` inside the captured zone, which is what the async generator
  /// behind `openFile` captures in turn. Pause, resume and cancel are forwarded
  /// so backpressure still reaches the store — buffering the file to sidestep
  /// the zone would trade this bug for a worse one.
  static Stream<List<int>> _inCurrentZone(Stream<List<int>> Function() open) {
    final zone = Zone.current;
    late final StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    controller = StreamController<List<int>>(
      onListen: () => zone.run(() {
        try {
          subscription = open().listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
        } catch (error, stackTrace) {
          // [open] is declared to return a stream, so a synchronous throw has
          // no route to the caller — it would surface as an unhandled error in
          // the socket's zone, killing the connection with nothing logged
          // against the request. Turned into a stream error it travels the same
          // path a failure inside the stream does.
          controller.addError(error, stackTrace);
          // Not awaited, and cannot be: `close` completes when the consumer has
          // drained the stream, which is the socket, which is waiting on this
          // callback to return.
          unawaited(controller.close());
        }
      }),
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      // The controller takes a `Future` from `onCancel` and from no other
      // callback, so the cancel is handed over rather than merely started: a
      // client that hangs up mid-file must not leave a read running behind it.
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  static Future<Response> _head(
    Request request,
    TomFileSlot slot,
    String id,
  ) async {
    final metadata = await slot.describe(id);
    if (metadata == null) {
      return _error(404, 'file_endpoint.no_file', 'No file is stored there.');
    }
    final headers = Map.of(tomFileDescriptorHeaders(metadata))
      // Content-length is owned by the response, not by us: a HEAD writes no
      // body, and declaring a length nothing then fills is an error at the
      // socket. The size still travels — `x-tom-file` carries the whole
      // descriptor, which is what the client reads first.
      ..remove('content-length')
      // The same advertisement the GET makes, and this is where a client that
      // plans a resumable download actually reads it: it asks HEAD for the
      // size, and learns here that it may ask for part of it.
      ..['accept-ranges'] = 'bytes';
    // The same condition the `GET` answers. A client that probes with `HEAD`
    // before deciding whether to download is precisely the one this saves a
    // transfer, and answering it differently from `GET` would make the probe
    // and the request disagree about the same resource.
    if (_matches(request.headers['if-none-match'], metadata.digest)) {
      return Response.notModified(headers: headers);
    }
    return Response.ok(null, headers: headers);
  }

  static Future<Response> _delete(TomFileSlot slot, String id) async {
    final removed = await slot.clear(id);
    if (!removed) {
      return _error(404, 'file_endpoint.no_file', 'No file is stored there.');
    }
    return Response(204);
  }

  /// A JSON error body carrying the error [key], so a client sees the same
  /// stable code the server logged.
  static Response _error(int status, String key, String message) => Response(
    status,
    body: jsonEncode({'key': key, 'message': message}),
    headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
  );
}

/// The file-transfer service interface, mounted by the endpoints pipeline.
///
/// One method for all four verbs: the wire contract addresses a single resource
/// and varies only the method, and splitting it into four handlers would mean
/// four copies of the slot resolution that has to be identical across them.
@tomReflector
@tomService
abstract class TomFileService {
  /// `POST`/`GET`/`HEAD`/`DELETE` on `/files/{entity}/{id}/{column}`.
  ///
  /// `consumes` is deliberately **not** JSON: the pipeline reads a request body
  /// into a string only for a JSON endpoint, so declaring octet-stream is what
  /// leaves the upload stream intact all the way to the blob store.
  ///
  /// [TomAuthenticatedAccess] because the endpoint's other protections cannot
  /// stand in for it. The row scope (C-3) and the column grade (C-4) are both
  /// principal-*relative*: they answer "which rows, which columns", never
  /// "whether there is a caller at all". An entity that declares no
  /// `@TomDbScope` filters nothing and an ungraded column refuses nothing, so
  /// without this an exposed file column on an ordinary entity would be
  /// world-readable and world-writable. An application that genuinely wants
  /// anonymous file access declares its own [TomFileService] component with a
  /// different [TomAccessControl] — a handler-side annotation is a local
  /// override (G-API-3) — rather than every application inheriting the open
  /// case by default.
  @TomAuthenticatedAccess()
  @TomEndpoint(
    methods: [
      TomHttpMethod.post,
      TomHttpMethod.put,
      TomHttpMethod.get,
      TomHttpMethod.head,
      TomHttpMethod.delete,
    ],
    uri: TomFileEndpoint.routeUri,
    consumes: TomMimeType.octetStream,
    produces: TomMimeType.json,
  )
  Future<Response> file(Request request);
}

/// The default [TomFileService] implementation.
///
/// Holds no state — the registry is [TomFileSlots] and the request is the
/// argument — so the pipeline may construct it itself when an application has
/// registered no bean of its own.
@tomReflector
@tomComponent
class TomFileServer implements TomFileService {
  @override
  Future<Response> file(Request request) => TomFileEndpoint.handle(request);
}
