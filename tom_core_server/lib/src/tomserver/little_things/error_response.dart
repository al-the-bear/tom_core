/// The error responses the server sends: the framework's error envelope, or an
/// RFC 9457 problem document when the caller asks for one.
///
/// ## Which format a response takes
///
/// | Request | Body | `Content-Type` |
/// | ------- | ---- | -------------- |
/// | `Accept` lists `application/problem+json` (with a `q` above 0) | [tomProblemDetails] | `application/problem+json` |
/// | served by an endpoint of an API declared with `problemJson: true` | [tomProblemDetails] | `application/problem+json` |
/// | anything else | [tomErrorEnvelope] | `application/json` |
///
/// A wildcard (`*/*`, `application/*`) does not select problem+json: a client
/// that has not named the format is one written against the envelope. Both
/// bodies carry the same fields — a problem document is the envelope with
/// RFC 9457's `type`, `title`, `status` and `instance` added — and neither
/// carries a message, so switching format reveals nothing the other hides.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'server_exception.dart';

/// The media type of an RFC 9457 problem document.
const String tomProblemJsonMediaType = 'application/problem+json';

/// The request context key an endpoint sets to answer its errors as
/// problem+json whatever the request asked for — see [tomWantsProblemJson].
const String tomProblemJsonContextKey = 'tom.problemJson';

/// Whether [request] is answered with a problem document: its context carries
/// [tomProblemJsonContextKey] as `true`, or its `Accept` header lists
/// [tomProblemJsonMediaType] with a quality above zero.
bool tomWantsProblemJson(Request? request) {
  if (request == null) return false;
  if (request.context[tomProblemJsonContextKey] == true) return true;
  final accept = request.headers['accept'];
  if (accept == null) return false;
  for (final range in accept.split(',')) {
    final parts = range.split(';');
    if (parts.first.trim().toLowerCase() != tomProblemJsonMediaType) continue;
    var quality = 1.0;
    for (final parameter in parts.skip(1)) {
      final pair = parameter.split('=');
      if (pair.length == 2 && pair.first.trim().toLowerCase() == 'q') {
        quality = double.tryParse(pair.last.trim()) ?? 0;
      }
    }
    if (quality > 0) return true;
  }
  return false;
}

/// [error] as an RFC 9457 problem document answered with [status].
///
/// - `type`: `urn:tom:error:<errorKey>` for an error with a key — the key is
///   the problem type a client branches on — else `about:blank`;
/// - `title`: the reason phrase of [status];
/// - `status`: [status];
/// - `instance`: `urn:tom:request:<requestUuid>` when the error names the
///   request it was raised in;
///
/// and then every field of [tomErrorEnvelope] as an extension member, so a
/// client reads `errorKey`, `clientThrow` or `loginFailure` the same way in
/// both formats. There is no `detail`: the envelope carries no message, and a
/// problem document does not either.
Map<String, Object?> tomProblemDetails(Object error, int status) {
  final envelope = tomErrorEnvelope(error);
  final key = envelope['errorKey'];
  final requestUuid = envelope['requestUuid'];
  return {
    'type': key is String && key.isNotEmpty
        ? 'urn:tom:error:$key'
        : 'about:blank',
    'title': tomReasonPhrase(status),
    'status': status,
    if (requestUuid is String && requestUuid.isNotEmpty)
      'instance': 'urn:tom:request:$requestUuid',
    ...envelope,
  };
}

/// The error response for [error] with [status], in the format [request]
/// asks for ([tomWantsProblemJson]); [headers] are added to it.
///
/// Every framework error response comes from here, so the format rule has one
/// author. The response always carries `x-tom-error: true`.
Response tomErrorResponse(
  Object error, {
  required int status,
  Request? request,
  Map<String, String> headers = const {},
}) {
  final problem = tomWantsProblemJson(request);
  return Response(
    status,
    body: jsonEncode(
      problem ? tomProblemDetails(error, status) : tomErrorEnvelope(error),
    ),
    headers: {
      'x-tom-error': 'true',
      TomHeader.contentType: problem
          ? tomProblemJsonMediaType
          : TomMimeType.json.toHeaderValue(),
      ...headers,
    },
  );
}

/// The reason phrase of the HTTP [status], or `Error` for one without a
/// registered phrase.
String tomReasonPhrase(int status) => _reasonPhrases[status] ?? 'Error';

const Map<int, String> _reasonPhrases = {
  400: 'Bad Request',
  401: 'Unauthorized',
  402: 'Payment Required',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  406: 'Not Acceptable',
  408: 'Request Timeout',
  409: 'Conflict',
  410: 'Gone',
  411: 'Length Required',
  412: 'Precondition Failed',
  413: 'Content Too Large',
  415: 'Unsupported Media Type',
  416: 'Range Not Satisfiable',
  422: 'Unprocessable Content',
  423: 'Locked',
  425: 'Too Early',
  428: 'Precondition Required',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  501: 'Not Implemented',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
  504: 'Gateway Timeout',
};
