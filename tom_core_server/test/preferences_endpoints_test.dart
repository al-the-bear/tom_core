/// The preferences endpoints as seen from the outside — which status a
/// client gets, and what happens with nothing wired behind them.
///
/// The store's behaviour is covered by `preferences_db_test.dart`, which
/// needs a database. What this file covers needs none.
///
/// Two of the three failures a caller can meet are not server faults, and each
/// gets a status of its own:
///
///  * A preference that was never written is a **miss**, not a break. That is
///    the difference between "you have no such preference" and "the server is
///    broken", and a client that cannot tell them apart must either treat every
///    failure as a miss or every miss as a failure.
///  * A key that violates [TomUserPreferenceKeys] is the **caller's** mistake.
///    The key arrives in the request URL, so on this side it is untrusted
///    input; answering `500` would tell a client its own malformed request was
///    a server fault worth retrying.
///
/// The third is a **deployment** fault: [TomUserPreferencesServer] resolves its
/// store from the bean context on every call, and an application that shipped
/// the endpoints without installing one has nothing behind them. That is the
/// case with no client-visible distinction to make — it stays an opaque `500` —
/// but it does have to be *named* on the server side rather than surfacing as a
/// null dereference, and it is reachable here because the handler holds no
/// state: no database, no router, no request.
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
/// The refusal [TomUserPreferenceBulkWriteRequest.writes] raises for an entry
/// that is not `{valueType, value}`.
TomException _malformedBulk() {
  try {
    TomUserPreferenceBulkWriteRequest(
      preferences: {'tom.theme': 'dark'},
    ).writes;
  } on TomException catch (error) {
    return error;
  }
  throw StateError('a malformed bulk entry was accepted');
}

TomException _keyRefusal(String key) {
  try {
    TomUserPreferenceKeys.validate(key);
  } on TomException catch (error) {
    return error;
  }
  throw StateError("'$key' was expected to be refused, and was not");
}

/// The refusal the write boundary actually raises for an encoded pair — caught
/// from [TomUserPreferenceCodec.validateEncoded] for the same reason as
/// [_keyRefusal].
TomException _encodedRefusal(String valueType, String valueJson) {
  try {
    TomUserPreferenceCodec.validateEncoded(valueType, valueJson, key: 'k');
  } on TomException catch (error) {
    return error;
  }
  throw StateError("'$valueJson' as $valueType was expected to be refused");
}

/// The failure [call] actually raises against a [TomUserPreferencesServer] with
/// no store installed.
///
/// The handler needs nothing else to be reachable: it holds no state, the store
/// is the bean and the caller is the zone, so the absent-bean path is the first
/// thing every endpoint hits and no database, router or request is involved.
///
/// Caught rather than constructed, for the same reason as [_keyRefusal]: an
/// exception hand-written with the expected key proves only that the test can
/// spell it.
Future<TomException> _missingStoreFailure(
  Future<void> Function(TomUserPreferencesServer server) call,
) async {
  try {
    await call(const TomUserPreferencesServer());
  } on TomException catch (error) {
    return error;
  }
  throw StateError('the call was expected to be refused, and was not');
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

    test('answers 409 for a write that would exceed the ceiling', () async {
      // Built from the contract's constant rather than caught from a store:
      // reaching the ceiling needs a database, and the key the handler matches
      // is the constant itself, so there is no second spelling to drift. The
      // DB suite asserts that the store raises it.
      final response = handler.handleInvocationError(
        TomUserPreferenceException(
          tomUserPreferencesLimitExceededErrorKey,
          'The caller already holds the most preferences allowed.',
        ),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 409);
      expect(response.headers['x-tom-error'], 'true');
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['errorKey'], tomUserPreferencesLimitExceededErrorKey);
    });

    test('answers 400 for a malformed bulk entry', () async {
      final response = handler.handleInvocationError(
        _malformedBulk(),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['errorKey'], tomUserPreferencesBulkMalformedErrorKey);
    });

    test('answers 400 for every refusal of the write boundary', () async {
      // The encoded pair arrives in the request body, so it is the caller's
      // input exactly as the key is: an oversized value, text that is not
      // JSON, a value that is not the type it names, or an instant that names
      // no zone is a bad request, and a 500 would tell the client to retry it.
      final refusals = {
        'preferences.encoded.too_large': _encodedRefusal(
          TomUserPreferenceCodec.stringType,
          jsonEncode('a' * TomUserPreferenceCodec.maxValueBytes),
        ),
        'preferences.encoded.invalid_json': _encodedRefusal(
          TomUserPreferenceCodec.stringType,
          '{oops',
        ),
        'preferences.encoded.type_mismatch': _encodedRefusal(
          TomUserPreferenceCodec.intType,
          '"three"',
        ),
        'preferences.encoded.not_an_instant': _encodedRefusal(
          TomUserPreferenceCodec.dateTimeType,
          '"2026-01-01T00:00:00"',
        ),
      };

      for (final MapEntry(key: errorKey, value: error) in refusals.entries) {
        expect(error.key, errorKey, reason: 'the fixture raised another key');
        final response = handler.handleInvocationError(
          error,
          StackTrace.current,
          _request(),
        );
        expect(response.statusCode, 400, reason: errorKey);
        final body = jsonDecode(await response.readAsString()) as Map;
        expect(body['errorKey'], errorKey);
      }
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
      //
      // The error is taken from an endpoint that really is missing its store,
      // not written out here, so the handler's silence about it stays tied to
      // the key the endpoints actually raise. A hand-built copy would keep
      // answering 500 after a rename that made the real key one of the two the
      // handler translates.
      final response = handler.handleInvocationError(
        await _missingStoreFailure((server) => server.listPreferences()),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 500);
      // Opaque is about the *status* and the message, not about the shape. The
      // body is the framework envelope like every other error this package
      // answers with, so a client decodes one shape whichever endpoint replied
      // — and an operator gets the `uuid` to quote, which is the whole value of
      // a 500 that is otherwise unexplainable. What must not appear is the
      // message, and that is what is asserted here rather than the media type:
      // a plain-text body proves nothing about leaking, since the leak this
      // guards against is `defaultUserMessage` reaching the wire.
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['errorKey'], 'preferences.not_configured');
      expect(body['uuid'], isNotEmpty);
      expect(body.containsKey('defaultUserMessage'), isFalse);
      expect(body.values.join(' '), isNot(contains('store')));
    });

    test('leaves a plain error opaque', () async {
      final response = handler.handleInvocationError(
        StateError('something else went wrong'),
        StackTrace.current,
        _request(),
      );

      expect(response.statusCode, 500);
      // A non-framework error has no key, no uuid and no message to carry, so
      // its envelope names the type and nothing else. Asserted because that is
      // the one case where the envelope really is nearly empty — and it still
      // must not carry the `StateError`'s own text.
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body, {'errorType': 'StateError'});
    });
  });

  group('with no store installed, every endpoint names the missing wiring', () {
    // The bean context is process-global, so the absence these tests are about
    // is established rather than assumed — a test of "nothing is installed"
    // that inherited a registration from elsewhere would pass for the wrong
    // reason, or fail for one.
    setUp(TomBean.resetBeanContext);

    // All five endpoints, not a representative one. `_store()` is a private
    // helper each of them calls separately, so any single endpoint can stop
    // going through it — by holding the store in a field, by resolving the bean
    // inline — without the others noticing. An unwired deployment would then
    // answer four named faults and one `NoSuchMethodError` on null.

    test('list', () async {
      final error = await _missingStoreFailure(
        (server) => server.listPreferences(),
      );

      expect(error.key, 'preferences.not_configured');
    });

    test('read', () async {
      final error = await _missingStoreFailure(
        (server) => server.readPreference(
          TomUserPreferenceKeyRequest(key: 'tom.theme'),
        ),
      );

      expect(error.key, 'preferences.not_configured');
    });

    test('write', () async {
      final error = await _missingStoreFailure(
        (server) => server.writePreference(
          TomUserPreferenceWriteRequest(
            key: 'tom.theme',
            valueType: 'String',
            value: '"dark"',
          ),
        ),
      );

      expect(error.key, 'preferences.not_configured');
    });

    test('bulk write', () async {
      final error = await _missingStoreFailure(
        (server) => server.writePreferences(
          TomUserPreferenceBulkWriteRequest.of([
            TomUserPreferenceWriteRequest(
              key: 'tom.theme',
              valueType: 'String',
              value: '"dark"',
            ),
          ]),
        ),
      );

      expect(error.key, 'preferences.not_configured');
    });

    test('delete', () async {
      final error = await _missingStoreFailure(
        (server) => server.deletePreference(
          TomUserPreferenceKeyRequest(key: 'tom.theme'),
        ),
      );

      expect(error.key, 'preferences.not_configured');
    });

    test('clear', () async {
      final error = await _missingStoreFailure(
        (server) => server.clearPreferences(),
      );

      expect(error.key, 'preferences.not_configured');
    });

    test('and does so as a handler failure, so the pipeline reports it', () {
      // The type is what decides how the failure leaves the server: the
      // pipeline routes a TomEndpointHandlerException through the endpoint's
      // error handler, which is what turns this one into the opaque 500 the
      // group above asserts. Raised as some other exception it would still be a
      // failure, but no longer one whose status this module has decided.
      expect(
        _missingStoreFailure((server) => server.listPreferences()),
        completion(isA<TomEndpointHandlerException>()),
      );
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
        tomUserPreferencesBulkWriteEndpointId,
        tomUserPreferencesDeleteEndpointId,
      ]) {
        expect(
          routed[endpointId],
          isA<TomUserPreferencesErrorHandler>(),
          reason: endpointId,
        );
      }
    });

    test('the clear endpoint routes to the framework default', () {
      // It takes nothing from the caller — no key in a path, no body — so
      // there is no malformed input for a `400` to describe, and it cannot
      // miss: a principal holding nothing is cleared. Every failure left is a
      // fault, which is exactly what the default handler is for.
      expect(
        _routedEndpointHandlers()[tomUserPreferencesClearEndpointId],
        isA<TomDefaultErrorHandler>(),
      );
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
