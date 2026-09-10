/// HTTP Client Example
///
/// This example demonstrates basic HTTP client usage with TomServerCall
/// and TomServerChannel.
///
/// Key concepts:
/// - HTTP methods and their properties
/// - TomServerCallSpecs for request configuration
/// - TomServerCallLoad for request payloads
/// - TomServerChannel for connection management
/// - TomServerCallError for response/error handling
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/http_connection/01_http_client_example.dart
/// ```
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class HttpClientExample {
  // Captured results
  static late TomHttpMethod getMethod;
  static late TomHttpMethod postMethod;
  static late TomServerCallSpecs getSpecs;
  static late TomServerCallSpecs postSpecs;
  static late TomServerCallLoad jsonLoad;
  static late TomServerCallLoad formLoad;
  static late TomServerChannel channel;
  static late TomServerCallError successResponse;
  static late TomServerCallError errorResponse;

  // -------------------------------------------------------------------------
  // Example 1: Understanding TomHttpMethod
  // -------------------------------------------------------------------------
  static void example1HttpMethods() {
    print('1. HTTP Methods:');

    getMethod = TomHttpMethod.get;
    postMethod = TomHttpMethod.post;
    final deleteMethod = TomHttpMethod.delete;
    final traceMethod = TomHttpMethod.trace;

    print(
      '   - GET method: ${getMethod.name}, accepts body: ${getMethod.acceptsBody}',
    );
    print(
      '   - POST method: ${postMethod.name}, accepts body: ${postMethod.acceptsBody}',
    );
    print(
      '   - DELETE method: ${deleteMethod.name}, accepts body: ${deleteMethod.acceptsBody}',
    );
    print(
      '   - TRACE method: ${traceMethod.name}, accepts body: ${traceMethod.acceptsBody}',
    );

    // Lookup method by name
    final lookupMethod = TomHttpMethod.methods['PUT'];
    print('   - Lookup PUT: ${lookupMethod?.name}');

    // Assertions
    assert(getMethod.name == 'GET', 'GET name should match');
    assert(getMethod.acceptsBody == true, 'GET should accept body');
    assert(postMethod.name == 'POST', 'POST name should match');
    assert(traceMethod.acceptsBody == false, 'TRACE should not accept body');
    assert(lookupMethod?.name == 'PUT', 'Should find PUT method');
  }

  // -------------------------------------------------------------------------
  // Example 2: Creating TomServerCallSpecs
  // -------------------------------------------------------------------------
  static void example2ServerCallSpecs() {
    print('\n2. Creating server call specifications:');

    getSpecs = TomServerCallSpecs(
      'GET',
      Uri.parse('https://api.example.com/users'),
    );
    print('   - GET specs: ${getSpecs.method} ${getSpecs.url}');

    postSpecs = TomServerCallSpecs(
      'POST',
      Uri.parse('https://api.example.com/users'),
      headers: {'Content-Type': 'application/json', 'X-Custom': 'value'},
      followRedirects: true,
      maxRedirects: 5,
      includeBearerAuthentication: false,
    );
    print('   - POST specs: ${postSpecs.method} ${postSpecs.url}');
    print('   - Headers: ${postSpecs.headers}');
    print('   - Follow redirects: ${postSpecs.followRedirects}');
    print('   - Include bearer auth: ${postSpecs.includeBearerAuthentication}');

    // Assertions
    assert(getSpecs.method == 'GET', 'GET method should match');
    assert(getSpecs.url.host == 'api.example.com', 'Host should match');
    assert(postSpecs.followRedirects == true, 'Should follow redirects');
    assert(postSpecs.maxRedirects == 5, 'Max redirects should be 5');
    assert(
      postSpecs.includeBearerAuthentication == false,
      'Should not include bearer auth',
    );
  }

  // -------------------------------------------------------------------------
  // Example 3: Creating TomServerCallLoad payloads
  // -------------------------------------------------------------------------
  static void example3RequestPayloads() {
    print('\n3. Creating request payloads:');

    // JSON string body
    jsonLoad = TomServerCallLoad(
      stringBody: '{"name": "John", "email": "john@example.com"}',
      contentType: 'application/json',
    );
    print('   - JSON load content type: ${jsonLoad.contentType}');
    print('   - JSON load body: ${jsonLoad.stringBody}');

    // Form fields body
    formLoad = TomServerCallLoad(
      bodyFields: {'username': 'john_doe', 'password': 'secret123'},
    );
    print('   - Form load fields: ${formLoad.bodyFields}');

    // Binary body (e.g., file upload)
    final binaryData = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello" in bytes
    final binaryLoad = TomServerCallLoad(
      byteBody: Uint8List.fromList(binaryData),
      contentType: 'application/octet-stream',
    );
    print('   - Binary load size: ${binaryLoad.byteBody?.length} bytes');

    // Assertions
    assert(
      jsonLoad.contentType == 'application/json',
      'JSON content type should match',
    );
    assert(jsonLoad.stringBody != null, 'JSON body should not be null');
    assert(formLoad.bodyFields != null, 'Form fields should not be null');
    assert(
      formLoad.bodyFields!['username'] == 'john_doe',
      'Username should match',
    );
    assert(binaryLoad.byteBody != null, 'Binary body should not be null');
    assert(binaryLoad.byteBody!.length == 5, 'Binary body should be 5 bytes');
  }

  // -------------------------------------------------------------------------
  // Example 4: TomServerChannel configuration
  // -------------------------------------------------------------------------
  static void example4ServerChannel() {
    print('\n4. Server channel configuration:');

    channel = TomServerChannel('api.example.com', 443);
    print('   - Host: ${channel.host}');
    print('   - Port: ${channel.port}');

    // Creating a channel with custom client factory
    final customFactory = TomHttpClientFactory();
    final customChannel = TomServerChannel(
      'secure.api.com',
      8443,
      clientFactory: customFactory,
    );
    print('   - Custom channel host: ${customChannel.host}');
    print('   - Custom channel port: ${customChannel.port}');

    // Assertions
    assert(channel.host == 'api.example.com', 'Host should match');
    assert(channel.port == 443, 'Port should be 443');
    assert(customChannel.host == 'secure.api.com', 'Custom host should match');
    assert(customChannel.port == 8443, 'Custom port should be 8443');
  }

  // -------------------------------------------------------------------------
  // Example 5: TomServerCallError understanding
  // -------------------------------------------------------------------------
  static void example5ResponseErrorHandling() {
    print('\n5. Server call error/response structure:');

    successResponse = TomServerCallError(
      statusCode: 200,
      response: '{"id": 1, "name": "John"}',
      reasonPhrase: 'OK',
    );
    print('   - Success response status: ${successResponse.statusCode}');
    print('   - Has error: ${successResponse.hasError}');

    errorResponse = TomServerCallError(
      statusCode: 404,
      response: '{"error": "User not found"}',
      reasonPhrase: 'Not Found',
    );
    print('   - Not found status: ${errorResponse.statusCode}');
    print('   - Has error: ${errorResponse.hasError}');
    print('   - Reason phrase: ${errorResponse.reasonPhrase}');

    final internalError = TomServerCallError(
      statusCode: 200,
      internalError: TomServerCallError.jsonDecodingError,
    );
    print('   - Internal error code: ${internalError.internalError}');
    print('   - Has error (internal): ${internalError.hasError}');

    // Assertions
    assert(successResponse.hasError == false, 'Success should not have error');
    assert(errorResponse.hasError == true, 'Not found should have error');
    assert(errorResponse.statusCode == 404, 'Status code should be 404');
    assert(internalError.hasError == true, 'Internal error should have error');
    assert(
      internalError.internalError == TomServerCallError.jsonDecodingError,
      'Internal error should be JSON decoding error',
    );
  }

  // -------------------------------------------------------------------------
  // Example 6: Supplying your own HTTP client
  // -------------------------------------------------------------------------
  static void example6ClientFactory() {
    print('\n6. HTTP client factory:');

    // A custom factory is one method: implement
    // TomHttpClientAbstractFactory and return the client every call should
    // use — one carrying an interceptor, a proxy, or, here, a canned answer.
    final ambientClient = _StubClient();
    TomHttpClientFactory.setGlobalHttpClientFactory(
      _StubClientFactory(ambientClient),
    );

    // A channel that names no factory of its own resolves through the global.
    final ambient = TomServerChannel('api.example.com', 443);
    print('   - Ambient channel client: ${ambient.getClient().runtimeType}');

    // One channel can be given its own without disturbing that choice.
    final scopedClient = _StubClient();
    final scoped = TomServerChannel(
      'reporting.example.com',
      443,
      clientFactory: _StubClientFactory(scopedClient),
    );
    print('   - Scoped channel client:  ${scoped.getClient().runtimeType}');

    // Assertions
    assert(
      identical(ambient.getClient(), ambientClient),
      'The registered factory should answer for a channel with none of its own',
    );
    assert(
      identical(scoped.getClient(), scopedClient),
      'A per-channel factory should win over the registered one',
    );

    // The global factory is process-wide state: an application sets it once at
    // startup, and anything that borrows it puts it back.
    TomHttpClientFactory.resetGlobalHttpClientFactory();
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 01: HTTP Client Example ===\n');

    example1HttpMethods();
    example2ServerCallSpecs();
    example3RequestPayloads();
    example4ServerChannel();
    example5ResponseErrorHandling();
    example6ClientFactory();

    print('\n=== HTTP Client Example Complete ===\n');
  }
}

/// A client that answers every request from memory, so the example needs no
/// network.
class _StubClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
}

/// The whole of a custom client factory: one method, returning a client.
///
/// It implements the contract rather than extending [TomHttpClientFactory],
/// which is the *resolver* — a subclass of that which forgets to override
/// `getClient` forwards forever, and forwards to itself once registered as the
/// global.
class _StubClientFactory implements TomHttpClientAbstractFactory {
  _StubClientFactory(this._client);

  final _StubClient _client;

  @override
  _StubClient getClient() => _client;
}

void run() => HttpClientExample.run();

void main() {
  prepareSampleProcess();
  run();
}
