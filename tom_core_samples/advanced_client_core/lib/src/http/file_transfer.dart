/// The byte half of the client core's HTTP layer — uploads and downloads
/// against a server's framework file endpoint.
///
/// The JSON half ([JsonTransport] / `IoJsonTransport`) reduces a call to "a
/// method, a URI, some headers and a string", which is exactly wrong for a file:
/// a payload worth storing is a payload not worth holding in memory. So files
/// travel over the kernel's [TomFileTransferClient] instead, which streams in
/// both directions.
///
/// ## Two pieces, one session
///
/// [ioFileTransferClient] is the transport: a `dart:io` client pointed at a
/// server's file endpoint, sending the credential [AuthorizedHttp] defines.
/// [AuthorizedFileTransferClient] is the policy: it wraps any transfer client
/// so an expired token is refreshed and the operation replayed, through the
/// same [TomAuthRefresher] the JSON half uses. Composed, they give a transfer
/// exactly the session the rest of the client has — logging in through
/// `AuthClient` is all it takes, and a token that expires mid-session is
/// recovered rather than surfaced.
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
/// final files = AuthorizedFileTransferClient(
///   ioFileTransferClient(Uri.parse('http://localhost:8080')),
///   authorizedHttp.refresher,
/// );
/// try {
///   await files.upload(
///     slot: AppFileSlots.itemAttachment('1'),
///     source: TomFileSource.bytes('spec.pdf', bytes),
///   );
/// } finally {
///   files.close();
/// }
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'authorized_http.dart';

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
    // The one place this client's credential is defined, shared verbatim with
    // the JSON half. Read per request, so a refresh that lands between attempts
    // is picked up — see [AuthorizedFileTransferClient].
    headerProvider: AuthorizedHttp.authorizationHeader,
  );
}

/// The file client an application installs: bytes over HTTP to [serverBaseUri],
/// under the session [http] already maintains.
///
/// The composition exists as a function so a call site cannot get it half right.
/// Building [ioFileTransferClient] alone gives a client that sends the current
/// token but cannot recover a stale one; wrapping it over a *fresh*
/// [AuthClientRefresher] would give it a second refresh path racing the JSON
/// half's. Passing `http.refresher` is the only correct wiring, so it is the
/// only one offered.
///
/// The returned client owns a connection pool; [TomFileTransferClient.close] it
/// when done.
TomFileTransferClient authenticatedFileTransferClient(
  Uri serverBaseUri,
  AuthorizedHttp http,
) => AuthorizedFileTransferClient(
  ioFileTransferClient(serverBaseUri),
  http.refresher,
);

/// The authenticated file client both Flutter clients transfer bytes through.
///
/// [delegate] carries the bytes (in production [ioFileTransferClient], in a test
/// the kernel's in-memory client); this decorator adds the one thing an
/// authenticated transfer needs and a raw transfer client cannot know about:
/// recovery from an expired token.
///
/// ## One token path, not two
///
/// The credential itself is *not* re-implemented here. [ioFileTransferClient]
/// reads it from [AuthorizedHttp.authorizationHeader] — the same function the
/// JSON clients send — and this decorator refreshes it through the same
/// [TomAuthRefresher] instance [AuthorizedHttp] holds. A second, subtly
/// different auth path in one client (a different stored token, a refresh that
/// only the JSON side performs) is the failure this tier exists to avoid: the
/// symptom is a board that loads while its attachments 401.
///
/// ## Why a decorator and not a policy inside the transfer client
///
/// The kernel's transfer client reports a refusal by *throwing*
/// [TomFileTransferException] (`file_transfer.rejected`, status in
/// `parameters['statusCode']`), while [tomRunWithAuthRetry] decides on a
/// returned response. Translating between the two is this class's whole job:
/// each operation runs as an attempt whose rejection becomes a status the
/// kernel policy can rule on, and a status it does not claim is rethrown
/// unchanged. The retry then replays the operation — which works for an upload
/// because [TomFileSource.open] is a factory, so the same bytes are available a
/// second time.
class AuthorizedFileTransferClient extends TomFileTransferClient {
  /// Wraps [delegate], recovering an expired session through [refresher].
  AuthorizedFileTransferClient(this.delegate, this.refresher);

  /// The client that actually moves the bytes.
  final TomFileTransferClient delegate;

  /// How a stale token is re-minted — the [AuthorizedHttp.refresher] instance.
  final TomAuthRefresher refresher;

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) => _authorized(
    () => delegate.upload(
      slot: slot,
      source: source,
      onProgress: onProgress,
      cancellation: cancellation,
    ),
  );

  /// Streams [slot], refreshing and replaying once if the *request* is refused
  /// as expired.
  ///
  /// A rejection that arrives after bytes have already been yielded is not
  /// retried: the consumer has seen a prefix, and silently restarting the
  /// stream would hand it that prefix twice. So the retry window closes at the
  /// first chunk — which is also where a 401 actually lands, since the server
  /// authorizes before it writes.
  @override
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async* {
    Stream<List<int>> open() => delegate.download(
      slot,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    final started = await _authorized(() async {
      final iterator = StreamIterator(open());
      // Pulling the first chunk is what forces the request out and surfaces a
      // refusal here, inside the retry, rather than at the caller's `await for`.
      final hasFirst = await iterator.moveNext();
      return (iterator, hasFirst);
    });
    final (iterator, hasFirst) = started;
    if (!hasFirst) return;
    yield iterator.current;
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  @override
  Future<TomFileMetadata?> describe(String slot) =>
      _authorized(() => delegate.describe(slot));

  @override
  Future<bool> remove(String slot) => _authorized(() => delegate.remove(slot));

  @override
  void close() => delegate.close();

  /// Runs [operation] under the kernel's refresh-once-on-expiry policy.
  Future<R> _authorized<R>(Future<R> Function() operation) async {
    final attempt = await tomRunWithAuthRetry<_TransferAttempt<R>>(
      send: () async {
        try {
          return _TransferAttempt<R>.succeeded(await operation());
        } on TomFileTransferException catch (failure) {
          final status = failure.parameters?['statusCode'];
          // Only a refusal that names a status can be ruled on. A cancellation
          // or a missing file carries none and must surface untouched.
          if (status is! int) rethrow;
          return _TransferAttempt<R>.refused(status, failure);
        }
      },
      statusOf: (attempt) => attempt.statusCode,
      errorKeyOf: (attempt) => attempt.errorKey,
      refresher: refresher,
    );
    return attempt.resultOrThrow();
  }
}

/// One try at a transfer operation, as a *value* the kernel retry policy can
/// inspect — the kernel decides on a returned status, the transfer client
/// reports by throwing, and this is the translation between them.
class _TransferAttempt<R> {
  _TransferAttempt.succeeded(R value)
    : statusCode = 200,
      _value = value,
      failure = null;

  _TransferAttempt.refused(this.statusCode, this.failure) : _value = null;

  /// The status the policy rules on: the refusal's, or `200` when it worked.
  final int statusCode;

  /// The refusal, when there was one.
  final TomFileTransferException? failure;

  final R? _value;

  /// The server's stable error key from the refusal's body, when it carried one.
  ///
  /// The same `{"error": "..."}` shape [AuthorizedHttp] reads, deliberately: a
  /// session that is dead names itself identically whichever half of the client
  /// discovered it. Falling back to `null` lets the kernel supply its own
  /// `auth.session_expired`, which says more than the transport-level
  /// `file_transfer.rejected` would.
  String? get errorKey {
    final body = failure?.parameters?['response'];
    if (body is! String) return null;
    try {
      final decoded = jsonDecode(body);
      final key = decoded is Map ? decoded['error'] : null;
      return key is String ? key : null;
    } on FormatException {
      return null;
    }
  }

  /// The operation's result, or the original refusal if it never produced one.
  ///
  /// Rethrowing the *captured* exception (rather than a new one) keeps the
  /// caller's error contract exactly what the transfer client documents — a
  /// non-expiry refusal such as a 403 reaches them unchanged.
  R resultOrThrow() {
    final failed = failure;
    if (failed != null) throw failed;
    return _value as R;
  }
}

/// Supplies a `dart:io`-backed client, bypassing the kernel's platform seam.
///
/// See the library doc for why this package answers the question itself instead
/// of requiring a `TomPlatformUtils.setCurrentPlatform` call at startup.
class _IoHttpClientFactory implements TomHttpClientAbstractFactory {
  @override
  Client getClient() => IOClient(HttpClient());
}
