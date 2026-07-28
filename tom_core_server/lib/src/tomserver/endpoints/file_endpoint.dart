/// The framework's HTTP file endpoint: the server half of the file-transfer
/// wire contract the kernel's `TomHttpFileTransferClient` speaks.
///
/// The two halves of file storage already existed and did not meet over HTTP.
/// The server owned the *store* — blob backends, `@TomFileReference` columns and
/// the four repository methods `saveFile` / `openFile` / `describeFile` /
/// `clearFile`. The kernel owned the *client* — `POST`/`GET`/`HEAD`/`DELETE` on
/// `<baseUri>/<slot>`, the JSON descriptor, the `x-tom-file` headers. What was
/// missing was the handler in between, and that handler is the same in every
/// application: map a slot to an entity and a file column, stream the request
/// body into `saveFile`, stream `openFile` back out, answer `HEAD` from
/// `describeFile`, `clearFile` on `DELETE`. Written once, here.
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
/// await client.upload('document/42/attachment', source);
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

  /// Streams the file on row [rawId].
  Stream<List<int>> open(String rawId);

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
  Stream<List<int>> open(String rawId) => repository.openFile(_id(rawId), _field);

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
  );
}

/// The registry of HTTP-reachable file columns, keyed by table and column name.
///
/// Registration is per repository, not per column: the repository is the only
/// thing an application has to name, because it already carries the entity type,
/// the key type and — through the entity's annotations — the table name, the
/// column names and the blob store. Anything else would be a restatement, and a
/// restatement is what drifts.
class TomFileSlots {
  TomFileSlots._();

  static final Map<String, Map<String, TomFileSlot>> _slots = {};

  /// Registers every **exposed** `@TomFileReference` column of [T].
  ///
  /// Fails loudly and at wire-up time when the entity is not mapped, exposes no
  /// file column, or would produce an ambiguous slot. That is the trade the
  /// reflection-derived design buys: the failures a hand-written mapping table
  /// would have shown at request time show here instead.
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
            parameters: {'table': table, 'name': name, 'columns': [owner, column.declaredName]},
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
  static TomFileSlot? resolve(String table, String column) =>
      _slots[table]?[column];

  /// Every registered slot, as `<table>/<column>` — for diagnostics and tests.
  static List<String> get slots => [
    for (final table in _slots.entries)
      for (final column in table.value.keys) '${table.key}/$column',
  ];

  /// Forgets every registration.
  ///
  /// Exists for tests, which build a fresh registry per case; an application
  /// registers once at startup.
  static void reset() => _slots.clear();
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
          return await _download(slot, id);
        case 'HEAD':
          return await _head(slot, id);
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

  static Future<Response> _download(TomFileSlot slot, String id) async {
    final metadata = await slot.describe(id);
    if (metadata == null) {
      return _error(404, 'file_endpoint.no_file', 'No file is stored there.');
    }
    return Response.ok(
      slot.open(id),
      headers: tomFileDescriptorHeaders(metadata),
    );
  }

  static Future<Response> _head(TomFileSlot slot, String id) async {
    final metadata = await slot.describe(id);
    if (metadata == null) {
      return _error(404, 'file_endpoint.no_file', 'No file is stored there.');
    }
    final headers = Map.of(tomFileDescriptorHeaders(metadata))
      // Content-length is owned by the response, not by us: a HEAD writes no
      // body, and declaring a length nothing then fills is an error at the
      // socket. The size still travels — `x-tom-file` carries the whole
      // descriptor, which is what the client reads first.
      ..remove('content-length');
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
