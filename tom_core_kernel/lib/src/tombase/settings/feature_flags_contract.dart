/// The feature-flag API a Tom server serves and its clients read: one
/// `GET /feature-flags` answering the client-visible flags evaluated for the
/// caller.
///
/// A client fetches the snapshot once (at start, after a sign-in) and reads
/// flags locally through [TomFeatureFlags]:
///
/// ```dart
/// TomFeatureFlags.provider = await TomFeatureFlagsClient.fetch(
///   Uri.parse('https://api.example.com'),
///   bearerToken: accessToken,
/// );
/// if (await TomFeatureFlags.isEnabled('new-checkout')) { ... }
/// ```
///
/// Only flags the server marks `exposed` travel; the server evaluates them for
/// the caller's tenant, roles and id, so a client sees its own values and never
/// the rules.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../http_connection/endpoints_apis.dart';
import '../http_connection/httpmethods.dart';
import '../http_connection/server_connection.dart';
import '../little_things/exception_base.dart';
import '../security/access_controls.dart';
import 'feature_flags.dart';

/// The id of the feature-flag API in the remote-API registry.
const String tomFeatureFlagsApiId = 'tomFeatureFlags';

/// The id of its one endpoint.
const String tomFeatureFlagsEvaluateEndpointId = 'evaluateFlags';

/// The feature-flag API. Public: an anonymous caller is evaluated too, as no
/// one in particular.
final TomApi tomFeatureFlagsApi = TomApi(
  id: tomFeatureFlagsApiId,
  name: 'Feature Flags API',
  description: 'The client-visible feature flags, evaluated for the caller.',
  uri: '/feature-flags',
  endpoints: [
    TomApiEndpoint<Map<String, Object?>, Object?>(
      id: tomFeatureFlagsEvaluateEndpointId,
      uri: '',
      method: TomHttpMethod.get,
      description:
          'Every flag the server exposes to clients, evaluated for the caller: '
          '`{"flags": {"<key>": <value>, ...}}`.',
      requestTypes: const [],
      access: const TomPublicAccess(),
    ),
  ],
);

/// Registers [tomFeatureFlagsApi] in the remote-API registry; idempotent.
void registerTomFeatureFlagsApi() {
  tomRemoteApis.register(tomFeatureFlagsApi);
}

/// Thrown when a client cannot fetch its feature flags.
class TomFeatureFlagsException extends TomException {
  /// Creates the exception; parameters mirror [TomException].
  TomFeatureFlagsException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// Fetches a client's feature flags from a Tom server.
abstract final class TomFeatureFlagsClient {
  /// The flags the server at [baseUri] exposes, evaluated for the caller
  /// [bearerToken] authenticates (anonymous without one), as a provider to
  /// install in [TomFeatureFlags.provider].
  ///
  /// [client] defaults to the framework's outgoing client. Throws
  /// `feature_flags.fetch.failed` when the server does not answer with flags;
  /// a client that would rather run on defaults catches it and keeps the
  /// provider it has.
  static Future<TomStaticFlagProvider> fetch(
    Uri baseUri, {
    String? bearerToken,
    http.Client? client,
  }) async {
    final uri = tomFeatureFlagsApi[tomFeatureFlagsEvaluateEndpointId]
        .resolveUri(baseUri);
    final http_ = client ?? TomHttpClientFactory().getClient();
    try {
      final response = await http_.get(
        uri,
        headers: {
          'accept': 'application/json',
          if (bearerToken != null) 'authorization': 'Bearer $bearerToken',
        },
      );
      final Object? body = response.statusCode == 200
          ? jsonDecode(response.body)
          : null;
      final flags = body is Map ? body['flags'] : null;
      if (flags is! Map) {
        throw TomFeatureFlagsException(
          'feature_flags.fetch.failed',
          'The server did not answer with feature flags.',
          parameters: {'uri': '$uri', 'status': response.statusCode},
        );
      }
      return TomStaticFlagProvider(flags.cast<String, Object?>());
    } on TomFeatureFlagsException {
      rethrow;
    } on Object catch (error, stack) {
      throw TomFeatureFlagsException(
        'feature_flags.fetch.failed',
        'The feature flags could not be fetched.',
        parameters: {'uri': '$uri'},
        rootException: error,
        stack: stack,
      );
    } finally {
      if (client == null) http_.close();
    }
  }
}
