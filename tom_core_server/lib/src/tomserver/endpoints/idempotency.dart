/// Idempotency keys: a `POST` the client retries runs once, and the retry gets
/// the first response.
///
/// A client that sends a request and loses the answer — a timeout, a dropped
/// connection, a crashed load balancer — cannot know whether the server acted.
/// Retrying a `GET` is harmless; retrying a "create order" creates a second
/// order. With an `Idempotency-Key` header the retry is safe: the server stores
/// the first request's response under the key and answers the retry with it,
/// without running the handler again.
///
/// An endpoint opts in with [TomIdempotent]:
///
/// ```dart
/// @TomEndpoint(methods: [TomHttpMethod.post], uri: '/orders')
/// @TomIdempotent()
/// Future<OrderDto> placeOrder(PlaceOrderDto order);
/// ```
///
/// ## What a request with a key gets
///
/// | The key is … | Answer |
/// | ------------ | ------ |
/// | new | the handler runs; its response is stored and returned |
/// | stored, for the same request | the stored response, with `Idempotent-Replayed: true`; the handler does not run |
/// | stored, for a different request | `422`, `endpoint.idempotency.key_reused` |
/// | claimed by a request still running | `409`, `endpoint.idempotency.in_progress`, with `Retry-After: 1` |
///
/// A request is the same request when its method, path, query and body are —
/// compared as a SHA-256 of them. A key is the caller's: it is scoped to the
/// tenant, the authenticated principal and the operation (method and route
/// pattern), so two callers never meet on a key. A request without a key, and
/// an unauthenticated one, runs as it would without the annotation — a key
/// with no principal behind it would let anyone holding it read the response.
///
/// ## What is stored
///
/// A response with a status below 500 is stored, except `401`, `403`, `408`,
/// `409`, `425` and `429`: those say the request did not run (it was refused,
/// or should be tried later), so storing them would replay a refusal after the
/// cause is gone. A `5xx` or a thrown handler releases the key, and the retry
/// runs. Stored are the status, the body and the headers but the hop-by-hop
/// ones and `set-cookie` (a session cookie is the first caller's, not the
/// retry's to receive again).
///
/// Records expire after [TomIdempotent.retention] (the store's default, 24
/// hours, unless the annotation names one); a key used again after that runs
/// as new. A claim whose request has not finished after
/// [TomIdempotency.inProgressTimeout] — its process died — is taken over by the
/// next retry.
///
/// ## Where it is kept
///
/// [TomIdempotency.store] is in memory by default, which holds on one process.
/// A cluster installs a [TomSqlIdempotencyStore] — `TomServer.start` does when
/// the `idempotency` configuration names a data source. The SQL store resolves
/// its data source per request, so under tenancy a tenant's keys live in that
/// tenant's database or schema.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'idempotency_sql.dart';

/// Method-level annotation: requests to this endpoint may carry an
/// `Idempotency-Key` — see the library documentation.
class TomIdempotent {
  /// Opts the endpoint in; [retention] overrides the store's default record
  /// lifetime.
  const TomIdempotent({this.retention});

  /// How long a stored response is replayed, or `null` for
  /// [TomIdempotency.defaultRetention].
  final Duration? retention;
}

/// An idempotency key that cannot be used.
///
/// | Key | Status | Meaning |
/// | --- | ------ | ------- |
/// | `endpoint.idempotency.key_invalid` | 400 | The key is empty or longer than 191 characters. |
/// | `endpoint.idempotency.key_reused` | 422 | The key was used for a different request. |
/// | `endpoint.idempotency.in_progress` | 409 | The first request with the key is still running. |
/// | `endpoint.idempotency.no_datasource` | 500 | The SQL store's data source is not registered. |
/// | `endpoint.idempotency.config.invalid` | — | The `idempotency` configuration has a value of the wrong shape. |
class TomIdempotencyException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomIdempotencyException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
  }) : super(clientThrow: true);
}

/// Who a key belongs to and which operation it is for.
class TomIdempotencyScope {
  /// The scope of [key] for [principal] on [operation] in [tenant].
  const TomIdempotencyScope({
    required this.tenant,
    required this.principal,
    required this.operation,
    required this.key,
  });

  /// The tenant, `''` outside tenancy.
  final String tenant;

  /// The authenticated principal's id.
  final String principal;

  /// The operation: the method and the route pattern, `POST /orders`.
  final String operation;

  /// The client's key.
  final String key;

  @override
  bool operator ==(Object other) =>
      other is TomIdempotencyScope &&
      other.tenant == tenant &&
      other.principal == principal &&
      other.operation == operation &&
      other.key == key;

  @override
  int get hashCode => Object.hash(tenant, principal, operation, key);
}

/// A stored request: its fingerprint and, once it finished, its response.
class TomIdempotencyRecord {
  /// A record of the request [requestHash], claimed at [createdAt].
  const TomIdempotencyRecord({
    required this.requestHash,
    required this.createdAt,
    required this.expiresAt,
    this.status,
    this.headers = const {},
    this.body,
  });

  /// The SHA-256 of the first request's method, path, query and body.
  final String requestHash;

  /// When the first request claimed the key.
  final DateTime createdAt;

  /// When the record stops being replayed.
  final DateTime expiresAt;

  /// The stored response's status, or `null` while the request runs.
  final int? status;

  /// The stored response's headers.
  final Map<String, String> headers;

  /// The stored response's body.
  final List<int>? body;

  /// Whether the response has been stored.
  bool get isCompleted => status != null;
}

/// The result of [TomIdempotencyStore.claim]: the key is this request's, or
/// the record already holding it.
class TomIdempotencyClaim {
  /// A claim won by this request.
  const TomIdempotencyClaim.won() : existing = null;

  /// A claim lost to [existing].
  const TomIdempotencyClaim.lost(TomIdempotencyRecord this.existing);

  /// The record holding the key, or `null` when this request holds it.
  final TomIdempotencyRecord? existing;

  /// Whether this request holds the key.
  bool get won => existing == null;
}

/// Where idempotency records are kept.
abstract class TomIdempotencyStore {
  /// Claims [scope] for the request [requestHash] until [expiresAt], or
  /// answers the live record holding it. An expired record, and a claim still
  /// unfinished at [staleBefore], are replaced.
  Future<TomIdempotencyClaim> claim(
    TomIdempotencyScope scope,
    String requestHash, {
    required DateTime now,
    required DateTime expiresAt,
    required DateTime staleBefore,
  });

  /// Stores the response of the request holding [scope].
  Future<void> complete(
    TomIdempotencyScope scope, {
    required int status,
    required Map<String, String> headers,
    required List<int> body,
  });

  /// Gives [scope] up, so the next request with the key runs.
  Future<void> release(TomIdempotencyScope scope);

  /// Removes the records expired at [now]; answers how many.
  Future<int> purgeExpired(DateTime now);
}

/// The idempotency records of one process, in memory.
class TomMemoryIdempotencyStore implements TomIdempotencyStore {
  final Map<TomIdempotencyScope, TomIdempotencyRecord> _records = {};

  @override
  Future<TomIdempotencyClaim> claim(
    TomIdempotencyScope scope,
    String requestHash, {
    required DateTime now,
    required DateTime expiresAt,
    required DateTime staleBefore,
  }) async {
    final existing = _records[scope];
    if (existing != null &&
        existing.expiresAt.isAfter(now) &&
        (existing.isCompleted || existing.createdAt.isAfter(staleBefore))) {
      return TomIdempotencyClaim.lost(existing);
    }
    _records[scope] = TomIdempotencyRecord(
      requestHash: requestHash,
      createdAt: now,
      expiresAt: expiresAt,
    );
    return const TomIdempotencyClaim.won();
  }

  @override
  Future<void> complete(
    TomIdempotencyScope scope, {
    required int status,
    required Map<String, String> headers,
    required List<int> body,
  }) async {
    final claimed = _records[scope];
    if (claimed == null) return;
    _records[scope] = TomIdempotencyRecord(
      requestHash: claimed.requestHash,
      createdAt: claimed.createdAt,
      expiresAt: claimed.expiresAt,
      status: status,
      headers: Map.unmodifiable(headers),
      body: List.unmodifiable(body),
    );
  }

  @override
  Future<void> release(TomIdempotencyScope scope) async {
    _records.remove(scope);
  }

  @override
  Future<int> purgeExpired(DateTime now) async {
    final expired = [
      for (final e in _records.entries)
        if (!e.value.expiresAt.isAfter(now)) e.key,
    ];
    expired.forEach(_records.remove);
    return expired.length;
  }
}

/// Idempotency records in a SQL table — see the library documentation.
///
/// The data source is resolved by name on every call
/// ([TomDataSourceInfo.getDataSourceInfo]), so under tenancy the records of a
/// request in a tenant go to that tenant's data source.
class TomSqlIdempotencyStore implements TomIdempotencyStore {
  /// A store in [table] of the data source registered as [datasourceName].
  ///
  /// With [createSchema] (the default) the table is created on first use in
  /// each data source; a deployment whose user may not run DDL applies the
  /// shipped migration and passes `false`.
  TomSqlIdempotencyStore(
    String this.datasourceName, {
    this.table = defaultIdempotencyTable,
    this.createSchema = true,
  }) : _fixed = null;

  /// A store in [table] of [datasource] itself, resolved once — for a
  /// deployment without per-tenant data sources, and for tests.
  TomSqlIdempotencyStore.over(
    TomDataSource datasource, {
    this.table = defaultIdempotencyTable,
    this.createSchema = true,
  }) : datasourceName = null,
       _fixed = datasource;

  /// The registered name of the data source, or `null` for a store built
  /// [TomSqlIdempotencyStore.over] one.
  final String? datasourceName;

  final TomDataSource? _fixed;

  /// The table's name.
  final String table;

  /// Whether the table is created on first use.
  final bool createSchema;

  late final TomFrameworkTable _table = idempotencyTable(table);
  final Expando<TomSchemaProvisioning> _schemas = Expando();

  Future<TomDataSource> _datasource() async {
    final TomDataSource ds;
    final fixed = _fixed;
    if (fixed != null) {
      ds = _table.placed(fixed);
    } else {
      final info = TomDataSourceInfo.getBaseDataSourceInfo(datasourceName!);
      if (info == null) {
        throw TomIdempotencyException(
          'endpoint.idempotency.no_datasource',
          "The idempotency store's data source '$datasourceName' is not "
              'registered.',
          parameters: {'datasource': datasourceName},
        );
      }
      ds = _table.placedInfo(info).datasource;
    }
    if (createSchema) {
      await (_schemas[ds] ??= TomSchemaProvisioning()).ensure(
        () => _table.create(ds),
      );
    }
    return ds;
  }

  static Map<String, Object?> _keyOf(TomIdempotencyScope s) => {
    'tenant': s.tenant,
    'principal': s.principal,
    'operation': s.operation,
    'key': s.key,
  };

  static const String _where =
      'tenant = :tenant AND principal = :principal AND operation = :operation '
      'AND idem_key = :key';

  @override
  Future<TomIdempotencyClaim> claim(
    TomIdempotencyScope scope,
    String requestHash, {
    required DateTime now,
    required DateTime expiresAt,
    required DateTime staleBefore,
  }) async {
    final ds = await _datasource();
    final row = {
      ..._keyOf(scope),
      'hash': requestHash,
      'state': 'in_progress',
      'now': sqlInstant(now),
      'expires': sqlInstant(expiresAt),
    };
    for (var attempt = 0; attempt < 3; attempt++) {
      final inserted = await ds.executeCommand(
        _table.insertRow(ds.sqlDialect, const {
          'tenant': ':tenant',
          'principal': ':principal',
          'operation': ':operation',
          'idem_key': ':key',
          'request_hash': ':hash',
          'state': ':state',
          'created_at': ':now',
          'expires_at': ':expires',
        }, ignoreConflict: true),
        row,
      );
      if (inserted != BigInt.zero) return const TomIdempotencyClaim.won();

      // Taken: an expired record, or a claim whose request died, is replaced
      // by one conditional statement, so two retries cannot both win it.
      final replaced = await ds.executeCommand(
        'UPDATE $table SET request_hash = :hash, state = :state, '
        'status = NULL, headers = NULL, body = NULL, created_at = :now, '
        'expires_at = :expires WHERE $_where AND (expires_at <= :now OR '
        "(state = 'in_progress' AND created_at < :stale))",
        {...row, 'stale': sqlInstant(staleBefore)},
      );
      if (replaced != BigInt.zero) return const TomIdempotencyClaim.won();

      final existing = await _read(ds, scope);
      // Gone between the insert and the read: released by its request. Try
      // again.
      if (existing != null) return TomIdempotencyClaim.lost(existing);
    }
    throw TomIdempotencyException(
      'endpoint.idempotency.in_progress',
      'The idempotency key is being claimed and released repeatedly; try '
          'again.',
    );
  }

  Future<TomIdempotencyRecord?> _read(
    TomDataSource ds,
    TomIdempotencyScope scope,
  ) async {
    final rows = await ds.executeQuery<TomIdempotencyRow>(
      'SELECT request_hash, state, status, headers, body, created_at, '
      'expires_at FROM $table WHERE $_where',
      _keyOf(scope),
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final headers = r.headers == null || r.headers!.isEmpty
        ? const <String, String>{}
        : (jsonDecode(r.headers!) as Map).cast<String, String>();
    return TomIdempotencyRecord(
      requestHash: r.requestHash,
      createdAt: parseSqlInstant(r.createdAt),
      expiresAt: parseSqlInstant(r.expiresAt),
      status: r.state == 'completed' ? r.status : null,
      headers: headers,
      body: r.body == null ? null : base64Decode(r.body!),
    );
  }

  @override
  Future<void> complete(
    TomIdempotencyScope scope, {
    required int status,
    required Map<String, String> headers,
    required List<int> body,
  }) async {
    final ds = await _datasource();
    await ds.executeCommand(
      "UPDATE $table SET state = 'completed', status = :status, "
      'headers = :headers, body = :body WHERE $_where',
      {
        ..._keyOf(scope),
        'status': status,
        'headers': jsonEncode(headers),
        'body': base64Encode(body),
      },
    );
  }

  @override
  Future<void> release(TomIdempotencyScope scope) async {
    final ds = await _datasource();
    await ds.executeCommand('DELETE FROM $table WHERE $_where', _keyOf(scope));
  }

  @override
  Future<int> purgeExpired(DateTime now) async {
    final ds = await _datasource();
    final removed = await ds.executeCommand(
      'DELETE FROM $table WHERE expires_at <= :now',
      {'now': sqlInstant(now)},
    );
    return removed.toInt();
  }

  /// Empties the table of the data source this zone resolves. For tests.
  Future<void> deleteAll() async {
    final ds = await _datasource();
    await ds.executeCommand('DELETE FROM $table');
  }
}

/// One row of the idempotency table, as [TomSqlIdempotencyStore] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["requestHash"],
)
class TomIdempotencyRow {
  /// The first request's fingerprint.
  @TomDbColumn(columnName: "request_hash")
  String requestHash = "";

  /// `in_progress` or `completed`.
  @TomDbColumn(columnName: "state")
  String state = "";

  /// The stored status.
  @TomDbColumn(columnName: "status")
  int? status;

  /// The stored headers, as JSON.
  @TomDbColumn(columnName: "headers")
  String? headers;

  /// The stored body, as base64.
  @TomDbColumn(columnName: "body")
  String? body;

  /// When the key was claimed, as stored UTC text.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// When the record expires, as stored UTC text.
  @TomDbColumn(columnName: "expires_at")
  String expiresAt = "";
}

/// The isolate's idempotency settings, and the handling of one request.
abstract final class TomIdempotency {
  /// The request header carrying the key.
  static const String header = 'Idempotency-Key';

  /// The response header marking a replayed response.
  static const String replayedHeader = 'Idempotent-Replayed';

  /// Where records are kept; in memory unless a deployment installs another.
  static TomIdempotencyStore store = TomMemoryIdempotencyStore();

  /// How long a stored response is replayed when the annotation names no
  /// retention.
  static Duration defaultRetention = const Duration(hours: 24);

  /// How long a claim may stay unfinished before a retry takes it over.
  static Duration inProgressTimeout = const Duration(minutes: 5);

  /// The clock. Replaceable for tests.
  static DateTime Function() clock = DateTime.now;

  /// Applies an `idempotency` configuration map:
  ///
  /// ```yaml
  /// idempotency:
  ///   datasource: app            # a TomSqlIdempotencyStore over it; absent: memory
  ///   table: tom_idempotency_key
  ///   createSchema: true
  ///   retentionMinutes: 1440
  ///   inProgressTimeoutSeconds: 300
  /// ```
  ///
  /// Throws `endpoint.idempotency.config.invalid` for a value of the wrong
  /// shape, before anything is applied.
  static void configure(Object? config) {
    if (config is! Map) {
      throw TomIdempotencyException(
        'endpoint.idempotency.config.invalid',
        'The idempotency settings must be a map, not a ${config.runtimeType}.',
      );
    }
    int? whole(String key) {
      if (!config.containsKey(key)) return null;
      final value = config[key];
      final parsed = value is int ? value : int.tryParse('$value');
      if (parsed == null || parsed <= 0) {
        throw TomIdempotencyException(
          'endpoint.idempotency.config.invalid',
          "The idempotency setting '$key' must be a positive whole number, "
              "not '$value'.",
          parameters: {'key': key},
        );
      }
      return parsed;
    }

    final retention = whole('retentionMinutes');
    final timeout = whole('inProgressTimeoutSeconds');
    final datasource = config['datasource'];
    final TomIdempotencyStore? sqlStore = datasource == null
        ? null
        : TomSqlIdempotencyStore(
            '$datasource',
            table: '${config['table'] ?? defaultIdempotencyTable}',
            createSchema: config['createSchema'] != false,
          );
    if (sqlStore != null) store = sqlStore;
    if (retention != null) defaultRetention = Duration(minutes: retention);
    if (timeout != null) inProgressTimeout = Duration(seconds: timeout);
  }

  /// Restores the defaults: a fresh memory store, 24 hours, five minutes, the
  /// system clock. For tests.
  static void reset() {
    store = TomMemoryIdempotencyStore();
    defaultRetention = const Duration(hours: 24);
    inProgressTimeout = const Duration(minutes: 5);
    clock = DateTime.now;
  }

  /// The statuses that say the request did not run, and are never stored.
  static const Set<int> notStoredStatuses = {401, 403, 408, 409, 425, 429};

  static const Set<String> _notStoredHeaders = {
    'set-cookie',
    'date',
    'connection',
    'keep-alive',
    'transfer-encoding',
    'content-length',
    'trailer',
    'upgrade',
  };

  /// Answers [request] for [operation] through [next], applying the
  /// request's idempotency key — see the library documentation. A request
  /// without a key, or without an authenticated principal, goes straight to
  /// [next].
  static Future<Response> handle(
    Request request,
    String operation,
    TomIdempotent annotation,
    Future<Response> Function(Request request) next,
  ) async {
    final key = request.headers[header.toLowerCase()];
    if (key == null) return next(request);
    final principal = getFromCurrentZone<TomPrincipal>();
    if (principal == null || !principal.authenticated) return next(request);
    if (key.isEmpty || key.length > 191) {
      return _refusal(
        400,
        TomIdempotencyException(
          'endpoint.idempotency.key_invalid',
          'An Idempotency-Key is 1 to 191 characters long.',
          parameters: {'length': key.length},
        ),
      );
    }

    final body = await request.read().expand((chunk) => chunk).toList();
    final hash = sha256.convert([
      ...utf8.encode('${request.method}\n${request.requestedUri.path}\n'),
      ...utf8.encode('${request.requestedUri.query}\n'),
      ...body,
    ]).toString();
    final scope = TomIdempotencyScope(
      tenant: TomTenantContext.currentId ?? '',
      principal: principal.id,
      operation: operation,
      key: key,
    );
    final now = clock().toUtc();
    final claim = await store.claim(
      scope,
      hash,
      now: now,
      expiresAt: now.add(annotation.retention ?? defaultRetention),
      staleBefore: now.subtract(inProgressTimeout),
    );

    final existing = claim.existing;
    if (existing != null) {
      if (existing.requestHash != hash) {
        return _refusal(
          422,
          TomIdempotencyException(
            'endpoint.idempotency.key_reused',
            'This Idempotency-Key was used for a different request.',
          ),
        );
      }
      if (!existing.isCompleted) {
        return _refusal(
          409,
          TomIdempotencyException(
            'endpoint.idempotency.in_progress',
            'The request with this Idempotency-Key is still running.',
          ),
          headers: {'Retry-After': '1'},
        );
      }
      return Response(
        existing.status!,
        body: existing.body ?? const <int>[],
        headers: {...existing.headers, replayedHeader: 'true'},
      );
    }

    final Response response;
    try {
      response = await next(request.change(body: body));
    } catch (_) {
      await store.release(scope);
      rethrow;
    }
    final status = response.statusCode;
    if (status >= 500 || notStoredStatuses.contains(status)) {
      await store.release(scope);
      return response;
    }
    final responseBody = await response
        .read()
        .expand((chunk) => chunk)
        .toList();
    final headers = {
      for (final e in response.headers.entries)
        if (!_notStoredHeaders.contains(e.key.toLowerCase())) e.key: e.value,
    };
    await store.complete(
      scope,
      status: status,
      headers: headers,
      body: responseBody,
    );
    return response.change(body: responseBody);
  }

  static Response _refusal(
    int status,
    TomIdempotencyException error, {
    Map<String, String> headers = const {},
  }) => Response(
    status,
    body: jsonEncode({
      'error': error.key,
      'message': error.clientMessage('The request could not be completed.'),
    }),
    headers: {
      TomHeader.contentType: TomMimeType.json.toHeaderValue(),
      ...headers,
    },
  );
}
