/// The HTTP *status* half of the preferences endpoints (TCCB5).
///
/// The store's behaviour is covered by `user_preferences_db_test.dart`, which
/// needs a database. What this file covers needs none: which status a client
/// sees for the two failures that are not server faults.
///
///  * A preference that was never written is a **miss**, not a break. That is
///    the difference between "you have no such preference" and "the server is
///    broken", and a client that cannot tell them apart must either treat every
///    failure as a miss or every miss as a failure.
///  * A key that violates [TomUserPreferenceKeys] is the **caller's** mistake.
///    The key arrives in the request URL, so on this side it is untrusted
///    input; answering `500` would tell a client its own malformed request was
///    a server fault worth retrying.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// The reflection bootstrap, so the shipped endpoint class's own annotations can
// be read rather than restated here.
import 'fixtures/reflection_fixture.reflection.dart';

Request _request() =>
    Request('GET', Uri.parse('http://localhost/preferences/tom.theme'));

/// The refusal [TomUserPreferenceKeys.validate] actually raises for [key].
///
/// Caught from the validator rather than constructed here: the handler selects
/// a status by matching the error *key*, so an exception hand-written with the
/// expected string would let the two drift apart and the test would still pass.
TomException _keyRefusal(String key) {
  try {
    TomUserPreferenceKeys.validate(key);
  } on TomException catch (error) {
    return error;
  }
  throw StateError("'$key' was expected to be refused, and was not");
}

/// The error handler each [TomUserPreferencesServer] endpoint really declares,
/// keyed by endpoint id — absent where the method declares none.
Map<String, TomErrorHandler?> _declaredEndpointHandlers() {
  final mirror =
      tomReflector.reflectType(TomUserPreferencesServer) as ClassMirror;
  final handlers = <String, TomErrorHandler?>{};
  for (final declaration in mirror.declarations.values) {
    if (declaration is! MethodMirror) continue;
    for (final annotation in declaration.metadata) {
      if (annotation is TomApiEndpointImplementation) {
        handlers[annotation.endpointId] = annotation.errorHandler;
      }
    }
  }
  return handlers;
}

void main() {
  group('TomUserPreferencesErrorHandler', () {
    const handler = TomUserPreferencesErrorHandler();

    test('answers 404 for a preference that was never written', () async {
      final response = handler.handleInvocationError(
        TomEndpointHandlerException(
          'preferences.not_found',
          "No preference is stored under 'tom.theme'.",
        ),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 404);
      expect(response.headers['x-tom-error'], 'true');
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(
        body['errorKey'],
        'preferences.not_found',
        reason: 'a client branches on the key, not on the message',
      );
    });

    test('the miss declares the media type of the body it sends', () async {
      // The whole design argument for the 404 is that a client reads the body
      // rather than the status alone. A client stack that decides whether to
      // parse by media type has nothing to decide on if the response declares
      // none, and an intermediary that sniffs an undeclared body is free to
      // call it whatever it likes.
      final response = handler.handleInvocationError(
        TomEndpointHandlerException(
          'preferences.not_found',
          "No preference is stored under 'tom.theme'.",
        ),
        StackTrace.current,
        _request(),
      );

      // Compared as a parsed media type, not as a string: the charset is part
      // of what is sent, and pinning the literal would make this test a
      // spelling check on `toHeaderValue`.
      expect(
        TomMimeType.parse(response.headers[TomHeader.contentType]!),
        TomMimeType.json,
      );
    });

    test('the rejected key declares it too, from the same arm', () async {
      // The 400 and the 404 are one branch of `handleInvocationError`, so this
      // would only fail separately if that branch were ever split — which is
      // exactly when it would be worth knowing.
      final response = handler.handleInvocationError(
        _keyRefusal('a/b'),
        StackTrace.current,
        _request(),
      );

      expect(
        TomMimeType.parse(response.headers[TomHeader.contentType]!),
        TomMimeType.json,
      );
    });

    test('answers 400 for a key that is not a usable key at all', () async {
      // The key is a URL path segment the server reads back off the request,
      // so a bad one is a bad *request* — and the client is owed an answer
      // that says so rather than an opaque fault.
      final response = handler.handleInvocationError(
        _keyRefusal('a/b'),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 400);
      expect(response.headers['x-tom-error'], 'true');
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['errorKey'], 'preferences.key.invalid');
    });

    test('answers 400 for the empty key, which is the list endpoint', () {
      // The one an unset TomUserPreferenceKeyRequest produces by default, so it
      // is the bad key most likely to actually arrive.
      final response = handler.handleInvocationError(
        _keyRefusal(''),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 400);
    });

    test('leaves every other failure opaque', () async {
      // A missing store is a deployment fault, not a client's business: it must
      // not become a 404 that a client reads as "no such preference" and papers
      // over with a default.
      final response = handler.handleInvocationError(
        TomEndpointHandlerException(
          'preferences.not_configured',
          'No TomUserPreferences bean is installed.',
        ),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 500);
      // And it stays plain text: the opaque fallback has no envelope to parse,
      // so declaring JSON there would promise a body that is not one.
      expect(
        TomMimeType.parse(response.headers[TomHeader.contentType]!),
        TomMimeType.plainText,
      );
    });

    test('leaves a plain error opaque', () async {
      final response = handler.handleInvocationError(
        StateError('something else went wrong'),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 500);
    });
  });

  group('endpoint wiring', () {
    setUpAll(() {
      initializeReflection();
      registerTomUserPreferencesApi();
    });

    test('every key-taking endpoint is served under the aware handler', () {
      // Read from the shipped class's own annotations, not from a copy built
      // here: the handler only matters if it is the one the pipeline finds, and
      // an annotation restated in the test would pass while the source had
      // none. All three key-taking endpoints need it — the read and the delete
      // take their key from the path and the write takes its own from the
      // body, but all three take one from the caller, so a 400 only the read
      // could produce would leave two thirds of the surface answering 500.
      final declared = _declaredEndpointHandlers();

      for (final endpointId in <String>[
        tomUserPreferencesReadEndpointId,
        tomUserPreferencesWriteEndpointId,
        tomUserPreferencesDeleteEndpointId,
      ]) {
        expect(
          declared[endpointId],
          isA<TomUserPreferencesErrorHandler>(),
          reason: endpointId,
        );
      }
    });

    test('the list endpoint has no handler of its own, and needs none', () {
      // It takes no key and cannot miss — an empty list is an answer. A handler
      // there could only translate faults that are genuinely faults.
      expect(
        _declaredEndpointHandlers()[tomUserPreferencesListEndpointId],
        isNull,
      );
    });
  });
}
