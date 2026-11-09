/// `POST /sync/push` and `POST /sync/pull`: the sync protocol over HTTP, bound
/// to the kernel's [tomSyncApi].
///
/// The contract declares [TomAuthenticatedAccess] on both endpoints and the
/// pipeline applies it; what a caller may read and write beyond that is the
/// synced entities' row scope and column grades, applied by their
/// repositories — see `sync.dart`.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'sync.dart';

/// Answers a pull of a collection the server does not sync, and a pull with a
/// negative cursor or a limit below one, with a `400`; every other failure
/// stays opaque.
class TomSyncErrorHandler extends TomStatusMappingErrorHandler {
  /// Const constructor so the handler can be used as an annotation argument.
  const TomSyncErrorHandler();

  @override
  Map<String, int> get statusByErrorKey => const {
    tomSyncUnknownCollectionErrorKey: 400,
    'sync.pull.invalid': 400,
  };
}

/// The default [TomSyncApiService] implementation, over [TomSync].
///
/// Holds no state — the synced entities are [TomSync]'s and the caller is the
/// request zone — so the pipeline may construct it itself.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: tomSyncApiId)
class TomSyncServer implements TomSyncApiService {
  /// Creates the endpoint implementation.
  const TomSyncServer();

  @TomApiEndpointImplementation(
    apiId: tomSyncApiId,
    endpointId: tomSyncPushEndpointId,
    errorHandler: TomSyncErrorHandler(),
  )
  @override
  Future<TomSyncPushResponse> push(TomSyncPushRequest request) async =>
      TomSyncPushResponse(results: await TomSync.push(request.changes));

  @TomApiEndpointImplementation(
    apiId: tomSyncApiId,
    endpointId: tomSyncPullEndpointId,
    errorHandler: TomSyncErrorHandler(),
  )
  @override
  Future<TomSyncPullResponse> pull(TomSyncPullRequest request) async =>
      TomSyncPullResponse(
        await TomSync.pull(
          request.collection,
          request.since,
          limit: request.limit,
        ),
      );
}
