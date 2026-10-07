/// Pins the error key of every HTTP-connection refusal that was otherwise
/// asserted only by exception type, or not at all.
///
/// The module's exceptions carry a key so a client can branch on *which*
/// failure it got — a missing API registration, a call sent twice, a request
/// aborted mid-transfer — and so a log line can be looked up. A test that only
/// checks the exception type passes just as well when the key is misspelled or
/// raised from the wrong branch, so a key no test names is a failure mode
/// nobody checks. Each case drives the smallest real input that reaches one
/// raise and asserts the exact literal.
///
/// The surrounding behaviour is tested in `http_connection_test.dart`; this
/// file only pins the vocabulary. None of these refusals needs a reflected
/// DTO: each is raised before anything is serialized.
library;

import 'dart:typed_data';

import 'package:http/http.dart'
    show BaseClient, BaseRequest, RequestAbortedException, StreamedResponse;
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A client whose every request fails the way an aborted `AbortableRequest`
/// does, so a [TomServerCall] sees the abort without a real connection.
class _AbortingClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) =>
      Future.error(RequestAbortedException(request.url));
}

/// A client that answers every request with an empty 200.
class _EmptyClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async =>
      StreamedResponse(Stream.value(Uint8List(0)), 200);
}

/// Matches a [TomException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomException>().having((e) => e.key, 'key', key));

/// Specs with bearer authentication off, so building a call never consults the
/// process-wide token store.
TomServerCallSpecs _specs() => TomServerCallSpecs(
  'POST',
  Uri.parse('https://api.example.com/data'),
  includeBearerAuthentication: false,
);

void main() {
  group('API registry', () {
    test('an unregistered API id is refused under apis.api.not_found', () {
      expect(
        () => TomRemoteApis()['missing'],
        _throwsKey('apis.api.not_found'),
      );
    });

    test('an unknown endpoint id is refused under apis.endpoint.not_found', () {
      final api = TomApi(id: 'orders', endpoints: []);
      expect(() => api['missing'], _throwsKey('apis.endpoint.not_found'));
    });

    test(
      'an endpoint added to no API is refused under apis.endpoint.api_not_set',
      () {
        final endpoint = TomApiEndpoint<String, String>(
          id: 'orphan',
          method: TomHttpMethod.get,
        );
        expect(() => endpoint.api, _throwsKey('apis.endpoint.api_not_set'));
      },
    );

    test('an endpoint whose type arguments do not match is refused under '
        'apis.endpoint.invalid_type_parameters', () {
      final endpoint = TomApiEndpoint<String, String>(
        id: 'typed',
        method: TomHttpMethod.get,
      );
      expect(
        () => TomServerEndpoint.createApiServerEndpoint<int, int>(endpoint),
        _throwsKey('apis.endpoint.invalid_type_parameters'),
      );
    });
  });

  group('TomMimeType.parse', () {
    final cases = <String, String>{
      'mime_type.parse.invalid_number_of_parts': 'text',
      'mime_type.parse.invalid_mime_type.empty_parts': 'text/ ',
    };
    cases.forEach((key, type) {
      test('"$type" is refused under $key', () {
        expect(() => TomMimeType.parse(type), _throwsKey(key));
      });
    });
  });

  group('TomServerCall', () {
    test('a load with two bodies is refused under '
        'server.connect.only_one_type_of_body_possible', () {
      expect(
        () => TomServerCallLoad(
          stringBody: 'text',
          byteBody: Uint8List.fromList([1]),
        ),
        _throwsKey('server.connect.only_one_type_of_body_possible'),
      );
    });

    test(
      'a second send is refused under server.send.illegal_state_only_send_once',
      () {
        final call = TomServerCall(_EmptyClient(), _specs())
          ..send(TomServerCallLoad());
        expect(
          () => call.send(TomServerCallLoad()),
          _throwsKey('server.send.illegal_state_only_send_once'),
        );
      },
    );

    test('an abort before the response arrives is reported under '
        'server.send.request_aborted', () async {
      final call = TomServerCall(_AbortingClient(), _specs())
        ..send(TomServerCallLoad());
      await expectLater(
        call.read(),
        throwsA(
          isA<TomRequestAbortedException>().having(
            (e) => e.key,
            'key',
            'server.send.request_aborted',
          ),
        ),
      );
    });
  });

  group('TomClientRemoteContext', () {
    setUp(TomClientRemoteContext.resetCurrent);
    tearDown(TomClientRemoteContext.resetCurrent);

    test('a second setCurrent is refused under '
        'tomclient.remote_context_state_error.already_initialized', () {
      final uri = Uri.parse('https://api.example.com');
      TomClientRemoteContext.setCurrent(TomClientRemoteContext(uri));
      expect(
        () => TomClientRemoteContext.setCurrent(TomClientRemoteContext(uri)),
        _throwsKey('tomclient.remote_context_state_error.already_initialized'),
      );
    });
  });
}
