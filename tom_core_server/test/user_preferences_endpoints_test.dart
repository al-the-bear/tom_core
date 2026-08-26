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

// The reflection bootstrap. The router reads the shipped endpoint class through
// mirrors, so the wiring group cannot build its routing metadata — and so cannot
// ask which handler an endpoint is served under — until this has run.
import 'fixtures/reflection_fixture.reflection.dart';

Request _request() =>
    Request('GET', Uri.parse('http://localhost/preferences/tom.theme'));

/// The smallest configuration a [TomServer] can be built from.
///
/// Only needed to reach `TomServer.errorHandler`, which is a field and so needs
/// an instance. `setValues` is overridden away because a real configuration is
/// generated, and none of its merged values matter here. Mirrors
/// `server_test.dart`'s `_NoopConfig`.
class _NoopConfig extends TomBaseServerConfiguration {
  _NoopConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

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

/// The error handler the pipeline will use for each [TomUserPreferencesServer]
/// endpoint, keyed by endpoint id.
///
/// Read from the routing metadata the router builds — the same
/// [TomEndpointRouting.getClassMethodMetadata] call `initializeRouter` makes —
/// because that is where the binding is actually consumed:
/// `metadata.endpoint.errorHandler` is what `endpoint_pipeline.dart` reaches for
/// when a handler throws. Reading the *annotation* instead would answer a
/// narrower question. The annotation is only an input to
/// [TomApiEndpointImplementation.convertToTomEndpoint], which resolves the
/// registry entry and merges three sources — the endpoint's own handler, the
/// class-level `@TomApiImplementation`'s API-wide one, and the framework
/// default. A declared handler that the merge dropped, or a registry lookup that
/// resolved elsewhere, would leave the annotation intact and the served
/// behaviour wrong; taking the merged value closes that gap and subsumes the
/// narrower check, since the merge cannot produce the preferences handler unless
/// the annotation declared it.
///
/// Never null: the merge ends in the framework default, so an endpoint that
/// declares nothing still routes to a handler. That is why the list endpoint is
/// asserted below by *which* handler it gets rather than by absence.
Map<String, TomErrorHandler?> _routedEndpointHandlers() {
  final mirror =
      tomReflector.reflectType(TomUserPreferencesServer) as ClassMirror;
  final handlers = <String, TomErrorHandler?>{};
  for (final metadata in TomEndpointRouting().getClassMethodMetadata(mirror)) {
    final endpointId = metadata.apiEndpointImplementation?.endpointId;
    if (endpointId == null) continue;
    handlers[endpointId] = metadata.endpoint.errorHandler;
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

    test('the miss body is the framework envelope, field for field', () async {
      // The point of the translated 404 is that its body looks like every other
      // error body the framework produces, so a client decodes one shape rather
      // than one per endpoint. Comparing the two handlers is the only assertion
      // that notices when they stop agreeing — asserting a field list here
      // would just be a third copy of the same wire shape.
      final error = TomEndpointHandlerException(
        'preferences.not_found',
        "No preference is stored under 'tom.theme'.",
      );
      final stack = StackTrace.current;

      final translated =
          jsonDecode(
                await handler
                    .handleInvocationError(error, stack, _request())
                    .readAsString(),
              )
              as Map<String, dynamic>;

      final framework =
          jsonDecode(
                await TomServer(
                  _NoopConfig(),
                ).errorHandler(_request(), error, stack)!.readAsString(),
              )
              as Map<String, dynamic>;

      expect(translated, framework);
    });

    test('clientThrow is read from the error, not assumed', () async {
      // `clientThrow` is the field the hand-built copy dropped, and it is not a
      // constant: every error this handler translates is a
      // TomEndpointHandlerException and therefore a TomServerException, so the
      // flag was always part of what the framework reported and never part of
      // the 404.
      //
      // Raised as a bare TomServerException because that is the only way to set
      // the flag — TomEndpointHandlerException does not forward it, so a real
      // miss is always `true` and a test built on one could not tell a value
      // that is read from a value that is assumed.
      final response = handler.handleInvocationError(
        TomServerException(
          'preferences.not_found',
          "No preference is stored under 'tom.theme'.",
          clientThrow: false,
        ),
        StackTrace.current,
        _request(),
      );

      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['clientThrow'], isFalse);
    });

    test('a kernel exception contributes no clientThrow', () async {
      // The 400 arrives as TomUserPreferenceKeyException, raised in the kernel
      // and so not a TomServerException at all. The envelope reports what the
      // error actually carries rather than padding the shape with a default,
      // which is what makes the field's presence mean something.
      final response = handler.handleInvocationError(
        _keyRefusal('a/b'),
        StackTrace.current,
        _request(),
      );

      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body.containsKey('clientThrow'), isFalse);
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
      // Load-bearing, not decorative: `getClassMethodMetadata` resolves each
      // `@TomApiEndpointImplementation` against `tomRemoteApis[apiId]`, so
      // without the registration below the metadata build throws rather than
      // returning handlers to assert.
      registerTomUserPreferencesApi();
    });

    test('every key-taking endpoint is routed under the aware handler', () {
      // All three key-taking endpoints need it — the read and the delete take
      // their key from the path and the write takes its own from the body, but
      // all three take one from the caller, so a 400 only the read could
      // produce would leave two thirds of the surface answering 500.
      final routed = _routedEndpointHandlers();

      for (final endpointId in <String>[
        tomUserPreferencesReadEndpointId,
        tomUserPreferencesWriteEndpointId,
        tomUserPreferencesDeleteEndpointId,
      ]) {
        expect(
          routed[endpointId],
          isA<TomUserPreferencesErrorHandler>(),
          reason: endpointId,
        );
      }
    });

    test('the list endpoint routes to the framework default', () {
      // It takes no key and cannot miss — an empty list is an answer — so it
      // declares no handler of its own and needs none. What it gets instead is
      // the default the merge ends in, which is the accurate statement: the
      // absence of an override is not the absence of a handler, and asserting
      // "none" here would describe a pipeline that does not exist.
      expect(
        _routedEndpointHandlers()[tomUserPreferencesListEndpointId],
        isA<TomDefaultErrorHandler>(),
      );
    });
  });
}
