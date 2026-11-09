/// The sync protocol over HTTP to a Tom server.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../http_connection/resilience.dart';
import '../security/bearer_authentication.dart';
import 'local_store.dart';
import 'sync_contract.dart';
import 'sync_protocol.dart';

/// A [TomSyncTransport] calling a Tom server's sync API ([tomSyncApi]) at
/// [baseUri].
///
/// [baseUri] is the server root; the API's own path is appended from the
/// contract. Every request carries the headers [headers] answers, computed per
/// request so a rotating credential is current; without an `Authorization`
/// among them the bearer token of [TomBearerAuthentication] is sent. Requests
/// go through [client], by default a [TomResilientClient] — a push is not
/// idempotent at the HTTP level, so the client does not retry it, and a failed
/// push leaves the changes queued for the next sync, which the server answers
/// by their base versions.
///
/// A status other than `200` throws a [TomOfflineException] keyed
/// `offline.http.failed`, carrying the status and the error key of the
/// server's error envelope when it has one; the sync engine reports it as a
/// failed transport and keeps every change.
class TomHttpSyncTransport extends TomSyncTransport {
  /// A transport to the server at [baseUri].
  TomHttpSyncTransport({
    required this.baseUri,
    http.Client? client,
    Map<String, String> Function()? headers,
  }) : _client = client ?? TomResilientClient(http.Client()),
       _headers = headers {
    registerTomSyncApi();
  }

  /// The server root.
  final Uri baseUri;

  final http.Client _client;
  final Map<String, String> Function()? _headers;

  @override
  Future<List<TomPushResult>> push(List<TomPendingChange> changes) async {
    final body = await _post(
      tomSyncPushEndpointId,
      TomSyncPushRequest(changes: changes).toJson(),
    );
    return TomSyncPushResponse.fromJson(body).results;
  }

  @override
  Future<TomPullBatch> pull(
    String collection,
    int since, {
    int limit = 500,
  }) async {
    final body = await _post(
      tomSyncPullEndpointId,
      TomSyncPullRequest(
        collection: collection,
        since: since,
        limit: limit,
      ).toJson(),
    );
    return TomPullBatch.fromJson(body);
  }

  Future<Map<String, Object?>> _post(
    String endpointId,
    Map<String, Object?> request,
  ) async {
    final endpoint = tomSyncApi[endpointId];
    final headers = {
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      ...?_headers?.call(),
    };
    if (!headers.keys.any((name) => name.toLowerCase() == 'authorization')) {
      final token = TomBearerAuthentication.token;
      if (token != null) headers['authorization'] = 'Bearer $token';
    }
    final uri = endpoint.resolveUri(baseUri);
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(request),
    );
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      String? errorKey;
      try {
        final envelope = jsonDecode(text);
        if (envelope is Map && envelope['errorKey'] is String) {
          errorKey = envelope['errorKey'] as String;
        }
      } on FormatException {
        // A body that is not the error envelope names no key.
      }
      throw TomOfflineException(
        'offline.http.failed',
        'The sync server at $uri answered ${response.statusCode}'
            '${errorKey == null ? '' : ' ($errorKey)'}.',
        parameters: {
          'endpoint': endpointId,
          'status': response.statusCode,
          'errorKey': ?errorKey,
        },
      );
    }
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  /// Closes the HTTP client.
  void close() => _client.close();
}
