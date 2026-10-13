/// Serves the server's generated OpenAPI document at `GET /openapi.json`.
///
/// The document is **generated at build time, not here**: `tom_core_openapi`
/// writes it from the endpoint annotations and the reflected DTOs, and the
/// server serves the file it is pointed at. Serving is optional — a server not
/// pointed at a document answers `404` with the error envelope, and says why.
///
/// Generating at request time was the alternative, and the worse one: the
/// document would be an artefact nobody reviewed and nothing pinned, its
/// content could differ between two running nodes of one build, and every
/// server would carry the generator. A file written by the build is diffable,
/// is the same on every node, and is what a client generator reads anyway.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'endpoint_annotation.dart';

/// The route contract for the OpenAPI document.
///
/// Public, because the document describes how to call the server and is read
/// before a caller holds any credential — the same reason a well-known JWKS is
/// public. It describes routes, never data.
@tomReflector
@tomService
abstract class TomOpenApiService {
  /// `GET /openapi.json` — the generated document, as written by the build.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: TomOpenApiServer.documentUri,
    logRequests: false,
  )
  Future<Response> openApiDocument();
}

/// Serves the file [globalSettingDocumentPath] names.
///
/// Read on every request rather than cached: the file is small, it is replaced
/// by a deployment rather than at run time, and a cached copy would go on
/// serving a document the deployment had already replaced.
@tomReflector
@tomComponent
class TomOpenApiServer implements TomOpenApiService {
  /// The route the document is served at.
  static const String documentUri = '/openapi.json';

  /// The generated document to serve, or `null` to serve none.
  ///
  /// `TomServer.start` sets it from `TomBaseServerConfiguration.openApiDocument`,
  /// so a deployment turns serving on with one configuration key. A relative
  /// path resolves against the working directory, as the migrations directory
  /// does.
  static String? globalSettingDocumentPath;

  /// Creates the component the router mounts.
  TomOpenApiServer();

  @override
  Future<Response> openApiDocument() async {
    final path = globalSettingDocumentPath;
    if (path == null || path.isEmpty) {
      return _notFound(
        'openapi.document.not_served',
        'This server does not publish an OpenAPI document.',
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      tomLog.warn(
        'The OpenAPI document is configured as "$path", which does not exist; '
        'generate it with tom_core_openapi before starting the server.',
      );
      return _notFound(
        'openapi.document.missing',
        'The OpenAPI document of this server is not available.',
      );
    }
    return Response.ok(
      await file.readAsString(),
      headers: {'content-type': TomMimeType.json.toHeaderValue()},
    );
  }

  static Response _notFound(String key, String message) => Response.notFound(
    jsonEncode(
      tomErrorEnvelope(TomServerException(key, message, clientThrow: true)),
    ),
    headers: {'content-type': TomMimeType.json.toHeaderValue()},
  );
}
