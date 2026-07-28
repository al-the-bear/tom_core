/// The byte half of the client core's HTTP layer — uploads and downloads
/// against a server's framework file endpoint.
///
/// The JSON half ([JsonTransport] / `IoJsonTransport`) reduces a call to "a
/// method, a URI, some headers and a string", which is exactly wrong for a file:
/// a payload worth storing is a payload not worth holding in memory. So files
/// travel over the kernel's [TomFileTransferClient] instead, which streams in
/// both directions and reads the same [TomBearerAuthentication] token
/// `AuthorizedHttp` maintains — logging in through `AuthClient` is all a
/// transfer needs to be authenticated.
///
/// ## Why this file exists at all
///
/// [TomHttpFileTransferClient] would otherwise resolve its HTTP client through
/// the kernel's platform seam (`TomPlatformUtils.current.httpClient()`), which
/// throws until an application registers a platform at startup. This package is
/// deliberately Flutter-free and owns its own `dart:io` transport — that is
/// already true of `IoJsonTransport`, which builds an [HttpClient] directly —
/// so it supplies the byte transport the same way rather than making every
/// consumer remember a startup call. Both Flutter clients then get working file
/// transfer from the same wiring that gives them working JSON.
///
/// ## Example
///
/// ```dart
/// final files = ioFileTransferClient(Uri.parse('http://localhost:8080'));
/// try {
///   await files.upload(
///     slot: 'app_items/1/attachment',
///     source: TomFileSource.bytes('spec.pdf', bytes),
///   );
/// } finally {
///   files.close();
/// }
/// ```
library;

import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The path a Tom server mounts its file endpoint at.
///
/// Spelled here because it is the framework's `TomFileEndpoint.basePath`, which
/// lives in `tom_core_server` and is therefore out of a client's reach. Written
/// once, in the one place that builds file URIs, rather than at every call site.
const String fileEndpointBasePath = '/files';

/// A streaming file-transfer client for the server at [serverBaseUri].
///
/// [serverBaseUri] is the *server's* root (e.g. `http://localhost:8080`), not
/// its file endpoint: appending [fileEndpointBasePath] is this function's job,
/// so a caller names the same URI it uses for the JSON clients.
///
/// The returned client owns a connection pool; [TomFileTransferClient.close] it
/// when done.
TomFileTransferClient ioFileTransferClient(Uri serverBaseUri) {
  return TomHttpFileTransferClient(
    baseUri: serverBaseUri.replace(path: fileEndpointBasePath),
    channel: TomServerChannel(
      serverBaseUri.host,
      serverBaseUri.port,
      clientFactory: _IoHttpClientFactory(),
    ),
  );
}

/// Supplies a `dart:io`-backed client, bypassing the kernel's platform seam.
///
/// See the library doc for why this package answers the question itself instead
/// of requiring a `TomPlatformUtils.setCurrentPlatform` call at startup.
class _IoHttpClientFactory extends TomHttpClientFactory {
  @override
  Client getClient() => IOClient(HttpClient());
}
