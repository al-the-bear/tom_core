/// The SCIM 2.0 HTTP endpoints under `/scim/v2/`, and the configuration that
/// enables them.
///
/// ## Enabling SCIM
///
/// Nothing is served until a deployment installs a [TomScimProvisioning] at
/// start-up — before that every SCIM path answers `404`:
///
/// ```dart
/// TomScimProvisioning.install(
///   TomScimProvisioning.fromConfiguration(
///     TomScimService(TomSqlScimStore.named('main')),
///   ),
/// );
/// ```
///
/// ```yaml
/// scim:
///   bearerTokens:
///     - ${SCIM_TOKEN_ENTRA}     # one per identity provider; several during a rotation
///   baseUrl: https://app.example.com/scim/v2   # behind a proxy; optional
/// ```
///
/// ## How the identity provider authenticates
///
/// With a bearer secret: the identity provider is configured with the tenant
/// URL (`https://<host>/scim/v2`) and a secret token, and sends
/// `Authorization: Bearer <secret>` on every request. The secret is compared
/// in constant time against the configured ones, which are held only as
/// SHA-256 digests. Installing claims the `/scim/v2/` paths in
/// `TomEndpointCredentials`, so the framework's bearer middleware leaves the
/// header to these endpoints instead of refusing it as a token of its own.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../endpoints/endpoint_annotation.dart';
import '../server/server.dart';
import 'scim_resource.dart';
import 'scim_service.dart';

/// The installed SCIM service and the secrets that may call it.
class TomScimProvisioning {
  /// Creates the configuration: [service] answers, and a caller presenting
  /// one of [bearerTokens] is admitted.
  ///
  /// [baseUrl] is the address resources are published under
  /// (`meta.location`); by default, the address the request arrived at.
  TomScimProvisioning({
    required this.service,
    required List<String> bearerTokens,
    this.baseUrl,
  }) : _digests = [
         for (final token in bearerTokens)
           if (token.isNotEmpty) _digest(token),
       ] {
    if (_digests.isEmpty) {
      throw TomScimException(
        'scim.not_enabled',
        'SCIM provisioning needs at least one bearer token.',
        status: 404,
      );
    }
  }

  /// The configuration path of the SCIM settings.
  static const String configurationKey = 'scim';

  /// The path every SCIM endpoint lives under.
  static const String pathPrefix = '/scim/v2/';

  /// The SCIM service.
  final TomScimService service;

  /// The published base address, or `null` for the request's own.
  final String? baseUrl;

  final List<List<int>> _digests;

  static TomScimProvisioning? _installed;

  /// The installed configuration, or `null` when SCIM is not enabled.
  static TomScimProvisioning? get current => _installed;

  /// Enables SCIM with [provisioning].
  static void install(TomScimProvisioning provisioning) {
    _installed = provisioning;
    TomEndpointCredentials.claim(pathPrefix);
  }

  /// Disables SCIM.
  static void reset() {
    _installed = null;
    TomEndpointCredentials.release(pathPrefix);
  }

  /// Reads `scim.bearerTokens` (a list, or one string) and `scim.baseUrl` from
  /// the configuration tree.
  ///
  /// Throws `scim.not_enabled` when no token is configured: an endpoint that
  /// admits nobody is a configuration mistake worth stopping the start for.
  factory TomScimProvisioning.fromConfiguration(
    TomScimService service, [
    TomServerConfigResourceProvider? config,
  ]) {
    final provider =
        config ?? TomServerConfigResourceProvider.getServerConfig();
    final raw = provider.exists('$configurationKey.bearerTokens')
        ? provider.get('$configurationKey.bearerTokens')
        : null;
    final tokens = raw is List
        ? [for (final token in raw) '$token']
        : raw == null
        ? const <String>[]
        : ['$raw'];
    final baseUrl = provider.exists('$configurationKey.baseUrl')
        ? '${provider.get('$configurationKey.baseUrl')}'
        : null;
    return TomScimProvisioning(
      service: service,
      bearerTokens: tokens,
      baseUrl: baseUrl,
    );
  }

  /// Throws `scim.unauthorized` unless the `Authorization` header [header]
  /// carries a configured secret.
  void requireAuthorized(String? header) {
    if (authorizes(header)) return;
    throw TomScimException(
      'scim.unauthorized',
      'The request does not carry a SCIM bearer token of this server.',
      status: 401,
    );
  }

  /// Whether the `Authorization` header [header] carries a configured secret.
  bool authorizes(String? header) {
    if (header == null) return false;
    final space = header.indexOf(' ');
    if (space < 0 || header.substring(0, space).toLowerCase() != 'bearer') {
      return false;
    }
    final presented = _digest(header.substring(space + 1).trim());
    var admitted = false;
    for (final digest in _digests) {
      var difference = 0;
      for (var i = 0; i < digest.length; i++) {
        difference |= digest[i] ^ presented[i];
      }
      admitted |= difference == 0;
    }
    return admitted;
  }

  static List<int> _digest(String token) =>
      crypto.sha256.convert(utf8.encode(token)).bytes;
}

/// The SCIM 2.0 endpoints (RFC 7644).
///
/// Public to the framework — the identity provider holds no token of this
/// deployment — and authenticated by [TomScimServer] against the installed
/// [TomScimProvisioning].
@tomReflector
@tomService
abstract class TomScimApi {
  /// `GET /scim/v2/ServiceProviderConfig`.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/scim/v2/ServiceProviderConfig",
  )
  Future<Response> serviceProviderConfig(Request request);

  /// `GET /scim/v2/ResourceTypes`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/ResourceTypes")
  Future<Response> resourceTypes(Request request);

  /// `GET /scim/v2/ResourceTypes/<name>`.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/scim/v2/ResourceTypes/<name>",
  )
  Future<Response> resourceType(Request request, String name);

  /// `GET /scim/v2/Schemas`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/Schemas")
  Future<Response> schemas(Request request);

  /// `GET /scim/v2/Schemas/<schemaId>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/Schemas/<schemaId>")
  Future<Response> schema(Request request, String schemaId);

  /// `GET /scim/v2/Users` — query.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/Users")
  Future<Response> listUsers(Request request);

  /// `POST /scim/v2/Users` — create.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.post], uri: "/scim/v2/Users")
  Future<Response> createUser(Request request);

  /// `GET /scim/v2/Users/<id>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/Users/<id>")
  Future<Response> getUser(Request request, String id);

  /// `PUT /scim/v2/Users/<id>` — replace.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.put], uri: "/scim/v2/Users/<id>")
  Future<Response> replaceUser(Request request, String id);

  /// `PATCH /scim/v2/Users/<id>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.patch], uri: "/scim/v2/Users/<id>")
  Future<Response> patchUser(Request request, String id);

  /// `DELETE /scim/v2/Users/<id>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.delete], uri: "/scim/v2/Users/<id>")
  Future<Response> deleteUser(Request request, String id);

  /// `GET /scim/v2/Groups` — query.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/Groups")
  Future<Response> listGroups(Request request);

  /// `POST /scim/v2/Groups` — create.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.post], uri: "/scim/v2/Groups")
  Future<Response> createGroup(Request request);

  /// `GET /scim/v2/Groups/<id>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.get], uri: "/scim/v2/Groups/<id>")
  Future<Response> getGroup(Request request, String id);

  /// `PUT /scim/v2/Groups/<id>` — replace.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.put], uri: "/scim/v2/Groups/<id>")
  Future<Response> replaceGroup(Request request, String id);

  /// `PATCH /scim/v2/Groups/<id>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.patch], uri: "/scim/v2/Groups/<id>")
  Future<Response> patchGroup(Request request, String id);

  /// `DELETE /scim/v2/Groups/<id>`.
  @TomPublicAccess()
  @TomEndpoint(methods: [TomHttpMethod.delete], uri: "/scim/v2/Groups/<id>")
  Future<Response> deleteGroup(Request request, String id);
}

/// The default [TomScimApi]: authenticates the caller and answers from the
/// installed [TomScimService], in `application/scim+json`.
@tomReflector
@tomComponent
class TomScimServer implements TomScimApi {
  /// Creates the endpoint implementation.
  const TomScimServer();

  /// The SCIM media type.
  static const String mediaType = 'application/scim+json';

  @override
  Future<Response> serviceProviderConfig(Request request) =>
      _serve(request, (s, base) async => s.serviceProviderConfig(base));

  @override
  Future<Response> resourceTypes(Request request) =>
      _serve(request, (s, base) async => _listOf(s.resourceTypes(base)));

  @override
  Future<Response> resourceType(Request request, String name) =>
      _serve(request, (s, base) async {
        for (final type in TomScimResourceType.values) {
          if (type.resourceName == name) return s.resourceType(type, base);
        }
        throw _notFound('resource type', name);
      });

  @override
  Future<Response> schemas(Request request) =>
      _serve(request, (s, base) async => _listOf(s.schemas(base)));

  @override
  Future<Response> schema(Request request, String schemaId) =>
      _serve(request, (s, base) async {
        for (final schema in s.schemas(base)) {
          if (schema['id'] == schemaId) return schema;
        }
        throw _notFound('schema', schemaId);
      });

  @override
  Future<Response> listUsers(Request request) =>
      _list(request, TomScimResourceType.user);

  @override
  Future<Response> createUser(Request request) =>
      _create(request, TomScimResourceType.user);

  @override
  Future<Response> getUser(Request request, String id) =>
      _get(request, TomScimResourceType.user, id);

  @override
  Future<Response> replaceUser(Request request, String id) =>
      _replace(request, TomScimResourceType.user, id);

  @override
  Future<Response> patchUser(Request request, String id) =>
      _patch(request, TomScimResourceType.user, id);

  @override
  Future<Response> deleteUser(Request request, String id) =>
      _delete(request, TomScimResourceType.user, id);

  @override
  Future<Response> listGroups(Request request) =>
      _list(request, TomScimResourceType.group);

  @override
  Future<Response> createGroup(Request request) =>
      _create(request, TomScimResourceType.group);

  @override
  Future<Response> getGroup(Request request, String id) =>
      _get(request, TomScimResourceType.group, id);

  @override
  Future<Response> replaceGroup(Request request, String id) =>
      _replace(request, TomScimResourceType.group, id);

  @override
  Future<Response> patchGroup(Request request, String id) =>
      _patch(request, TomScimResourceType.group, id);

  @override
  Future<Response> deleteGroup(Request request, String id) =>
      _delete(request, TomScimResourceType.group, id);

  Future<Response> _list(Request request, TomScimResourceType type) =>
      _serve(request, (s, base) {
        final query = request.requestedUri.queryParameters;
        return s.list(
          type,
          base,
          filter: query['filter'],
          startIndex: int.tryParse(query['startIndex'] ?? ''),
          count: int.tryParse(query['count'] ?? ''),
          attributes: query['attributes'],
          excludedAttributes: query['excludedAttributes'],
        );
      });

  Future<Response> _get(Request request, TomScimResourceType type, String id) =>
      _serve(request, (s, base) {
        final query = request.requestedUri.queryParameters;
        return s.get(
          type,
          id,
          base,
          attributes: query['attributes'],
          excludedAttributes: query['excludedAttributes'],
        );
      });

  Future<Response> _create(Request request, TomScimResourceType type) => _serve(
    request,
    (s, base) async => s.create(type, await _body(request), base),
    status: 201,
  );

  Future<Response> _replace(
    Request request,
    TomScimResourceType type,
    String id,
  ) => _serve(
    request,
    (s, base) async => s.replace(type, id, await _body(request), base),
  );

  Future<Response> _patch(
    Request request,
    TomScimResourceType type,
    String id,
  ) => _serve(
    request,
    (s, base) async => s.patch(type, id, await _body(request), base),
  );

  Future<Response> _delete(
    Request request,
    TomScimResourceType type,
    String id,
  ) => _serve(request, (s, base) async {
    await s.delete(type, id);
    return null;
  }, status: 204);

  /// Authenticates [request], runs [action], and renders its result — or the
  /// SCIM error it raised.
  static Future<Response> _serve(
    Request request,
    Future<Object?> Function(TomScimService service, String base) action, {
    int status = 200,
  }) async {
    final provisioning = TomScimProvisioning.current;
    if (provisioning == null) {
      return _error(
        TomScimException(
          'scim.not_enabled',
          'SCIM provisioning is not enabled on this server.',
          status: 404,
        ),
      );
    }
    try {
      provisioning.requireAuthorized(request.headers['authorization']);
    } on TomScimException catch (refused) {
      return _error(
        refused,
        headers: const {'WWW-Authenticate': 'Bearer realm="scim"'},
      );
    }
    final base =
        provisioning.baseUrl ?? '${request.requestedUri.origin}/scim/v2';
    try {
      final result = await action(provisioning.service, base);
      if (result == null) return Response(status);
      final location = result is Map ? result['meta'] : null;
      return Response(
        status,
        body: jsonEncode(result),
        headers: {
          TomHeader.contentType: mediaType,
          if (status == 201 && location is Map && location['location'] != null)
            TomHeader.location: '${location['location']}',
        },
      );
    } on TomScimException catch (error) {
      return _error(error);
    }
  }

  static Future<Object?> _body(Request request) async {
    final text = await request.readAsString();
    try {
      return jsonDecode(text);
    } on FormatException {
      throw TomScimException(
        'scim.invalid_syntax',
        'The request body is not JSON.',
        status: 400,
        scimType: 'invalidSyntax',
      );
    }
  }

  static Map<String, Object?> _listOf(List<Map<String, Object?>> resources) => {
    'schemas': [TomScimSchemas.listResponse],
    'totalResults': resources.length,
    'startIndex': 1,
    'itemsPerPage': resources.length,
    'Resources': resources,
  };

  static TomScimException _notFound(String what, String name) =>
      TomScimException(
        'scim.not_found',
        'No $what is named "$name".',
        status: 404,
      );

  static Response _error(
    TomScimException error, {
    Map<String, String> headers = const {},
  }) => Response(
    error.status,
    body: jsonEncode(error.toJson()),
    headers: {TomHeader.contentType: mediaType, ...headers},
  );
}
