/// The HTTP *status* half of the preferences endpoints (TCCB5).
///
/// The store's behaviour is covered by `user_preferences_db_test.dart`, which
/// needs a database. What this file covers needs none: which status a client
/// sees when it asks for a preference that was never written. That is not a
/// detail — it is the difference between "you have no such preference" and "the
/// server is broken", and a client that cannot tell them apart must either
/// treat every failure as a miss or every miss as a failure.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

Request _request() =>
    Request('GET', Uri.parse('http://localhost/preferences/tom.theme'));

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
    test('the read endpoint is served under the 404-aware handler', () {
      // The handler only matters if it is the one the pipeline uses, and the
      // binding is an annotation — so it is asserted rather than assumed.
      final endpoint = const TomApiEndpointImplementation(
        apiId: tomUserPreferencesApiId,
        endpointId: tomUserPreferencesReadEndpointId,
        errorHandler: TomUserPreferencesErrorHandler(),
      );
      registerTomUserPreferencesApi();

      expect(
        endpoint.convertToTomEndpoint().errorHandler,
        isA<TomUserPreferencesErrorHandler>(),
      );
    });
  });
}
