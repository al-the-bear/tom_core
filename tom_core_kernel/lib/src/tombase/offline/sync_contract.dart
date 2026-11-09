/// The sync protocol as a remote API: the two endpoints a Tom server serves it
/// under and the bodies they take and answer.
///
/// `tom_core_server` implements the API (its `sync` module);
/// [TomHttpSyncTransport] calls it. Both read the addresses from
/// [tomSyncApi], so the route a server serves and the URI a device calls are
/// one declaration.
///
/// Both endpoints are `POST`s, the pull included. A pull is a read, but it is
/// a read a device makes right after its own push and has to see that push: a
/// `GET` is read-only work, which a server with read replicas answers from a
/// replica that may not have the push yet.
library;

import '../http_connection/endpoints_apis.dart';
import '../http_connection/httpmethods.dart';
import '../json/json_serializable.dart';
import '../reflection/reflection.dart';
import '../security/access_controls.dart';
import 'http_sync_transport.dart';
import 'sync_protocol.dart';

/// The id of the sync API in the remote-API registry.
const String tomSyncApiId = 'tomSync';

/// The id of the push endpoint.
const String tomSyncPushEndpointId = 'push';

/// The id of the pull endpoint.
const String tomSyncPullEndpointId = 'pull';

/// The error key of a pull of a collection the server does not sync.
const String tomSyncUnknownCollectionErrorKey = 'sync.collection.unknown';

/// The body of a push: the pending changes, in the order they are applied.
@tomReflector
class TomSyncPushRequest implements TomJsonSerializable {
  /// The changes.
  List<TomPendingChange> changes;

  /// A push of [changes].
  TomSyncPushRequest({List<TomPendingChange>? changes})
    : changes = changes ?? [];

  /// Reads [toJson]'s form.
  factory TomSyncPushRequest.fromJson(Map<String, Object?> json) =>
      TomSyncPushRequest(
        changes: [
          for (final change in json['changes'] as List? ?? const [])
            TomPendingChange.fromJson((change as Map).cast<String, Object?>()),
        ],
      );

  @override
  Map<String, Object?> toJson() => {
    'changes': [for (final change in changes) change.toJson()],
  };
}

/// The answer to a push: one result per change, in the order pushed.
@tomReflector
class TomSyncPushResponse implements TomJsonSerializable {
  /// The results.
  List<TomPushResult> results;

  /// An answer of [results].
  TomSyncPushResponse({List<TomPushResult>? results}) : results = results ?? [];

  /// Reads [toJson]'s form.
  factory TomSyncPushResponse.fromJson(Map<String, Object?> json) =>
      TomSyncPushResponse(
        results: [
          for (final result in json['results'] as List? ?? const [])
            TomPushResult.fromJson((result as Map).cast<String, Object?>()),
        ],
      );

  @override
  Map<String, Object?> toJson() => {
    'results': [for (final result in results) result.toJson()],
  };
}

/// The body of a pull: the changes of [collection] after sequence number
/// [since], at most [limit].
@tomReflector
class TomSyncPullRequest implements TomJsonSerializable {
  /// The collection.
  String collection;

  /// The last sequence number the device has.
  int since;

  /// The most changes to answer.
  int limit;

  /// A pull of [collection] after [since].
  TomSyncPullRequest({this.collection = '', this.since = 0, this.limit = 500});

  /// Reads [toJson]'s form.
  factory TomSyncPullRequest.fromJson(Map<String, Object?> json) =>
      TomSyncPullRequest(
        collection: json['collection'] as String? ?? '',
        since: json['since'] as int? ?? 0,
        limit: json['limit'] as int? ?? 500,
      );

  @override
  Map<String, Object?> toJson() => {
    'collection': collection,
    'since': since,
    'limit': limit,
  };
}

/// The answer to a pull: a [TomPullBatch].
@tomReflector
class TomSyncPullResponse implements TomJsonSerializable {
  /// The batch.
  TomPullBatch batch;

  /// An answer carrying [batch].
  TomSyncPullResponse(this.batch);

  /// Reads [toJson]'s form.
  factory TomSyncPullResponse.fromJson(Map<String, Object?> json) =>
      TomSyncPullResponse(TomPullBatch.fromJson(json));

  @override
  Map<String, Object?> toJson() => batch.toJson();
}

/// The sync API: `POST /sync/push` and `POST /sync/pull`, for an
/// authenticated caller.
///
/// ```json
/// POST /sync/push   {"changes": [<TomPendingChange.toJson>, ...]}
///   → {"results": [<TomPushResult.toJson>, ...]}
/// POST /sync/pull   {"collection": "notes", "since": 12, "limit": 500}
///   → {"changes": [<TomPulledChange.toJson>, ...], "cursor": 14,
///      "hasMore": false}
/// ```
///
/// A pull of a collection the server does not sync is refused (`400`,
/// [tomSyncUnknownCollectionErrorKey]); a pushed change of one is answered
/// `rejected` with that reason.
final TomApi tomSyncApi = TomApi(
  id: tomSyncApiId,
  name: 'Sync API',
  description:
      'The offline sync protocol: devices push their pending changes and pull '
      'the changes after a sequence number.',
  uri: '/sync',
  endpoints: [
    TomApiEndpoint<TomSyncPushResponse, TomSyncPushRequest>(
      id: tomSyncPushEndpointId,
      uri: '/push',
      method: TomHttpMethod.post,
      description:
          'Applies each change under optimistic locking on its base version '
          'and answers applied, conflict or rejected per change.',
      access: const TomAuthenticatedAccess(),
    ),
    TomApiEndpoint<TomSyncPullResponse, TomSyncPullRequest>(
      id: tomSyncPullEndpointId,
      uri: '/pull',
      method: TomHttpMethod.post,
      description:
          'The changes of a collection after a sequence number that the '
          'caller may read, in sequence order.',
      access: const TomAuthenticatedAccess(),
    ),
  ],
);

/// Registers [tomSyncApi] in the remote-API registry; idempotent.
void registerTomSyncApi() {
  tomRemoteApis.register(tomSyncApi);
}

/// The typed service interface behind [tomSyncApi]; the server implements it.
abstract class TomSyncApiService {
  /// [tomSyncPushEndpointId] — applies [request]'s changes in order.
  Future<TomSyncPushResponse> push(TomSyncPushRequest request);

  /// [tomSyncPullEndpointId] — the changes [request] asks for.
  Future<TomSyncPullResponse> pull(TomSyncPullRequest request);
}
