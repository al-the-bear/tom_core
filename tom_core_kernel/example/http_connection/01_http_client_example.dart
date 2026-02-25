/// Demonstrates basic HTTP client usage with TomServerCall and TomServerChannel.
///
/// This example shows how to create HTTP requests using the low-level
/// TomServerCall API and manage connections with TomServerChannel.
library;

import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 01: HTTP Client Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Understanding TomHttpMethod
  // -------------------------------------------------------------------------
  print('1. HTTP Methods:');

  final getMethod = TomHttpMethod.get;
  final postMethod = TomHttpMethod.post;
  final deleteMethod = TomHttpMethod.delete;
  final traceMethod = TomHttpMethod.trace;

  print('   - GET method: ${getMethod.name}, accepts body: ${getMethod.acceptsBody}');
  print('   - POST method: ${postMethod.name}, accepts body: ${postMethod.acceptsBody}');
  print('   - DELETE method: ${deleteMethod.name}, accepts body: ${deleteMethod.acceptsBody}');
  print('   - TRACE method: ${traceMethod.name}, accepts body: ${traceMethod.acceptsBody}');

  // Lookup method by name
  final lookupMethod = TomHttpMethod.methods['PUT'];
  print('   - Lookup PUT: ${lookupMethod?.name}\n');

  // -------------------------------------------------------------------------
  // Example 2: Creating TomServerCallSpecs
  // -------------------------------------------------------------------------
  print('2. Creating server call specifications:');

  final getSpecs = TomServerCallSpecs(
    'GET',
    Uri.parse('https://api.example.com/users'),
  );
  print('   - GET specs: ${getSpecs.method} ${getSpecs.url}');

  final postSpecs = TomServerCallSpecs(
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
  print('   - Include bearer auth: ${postSpecs.includeBearerAuthentication}\n');

  // -------------------------------------------------------------------------
  // Example 3: Creating TomServerCallLoad payloads
  // -------------------------------------------------------------------------
  print('3. Creating request payloads:');

  // JSON string body
  final jsonLoad = TomServerCallLoad(
    stringBody: '{"name": "John", "email": "john@example.com"}',
    contentType: 'application/json',
  );
  print('   - JSON load content type: ${jsonLoad.contentType}');
  print('   - JSON load body: ${jsonLoad.stringBody}');

  // Form fields body
  final formLoad = TomServerCallLoad(
    bodyFields: {'username': 'john_doe', 'password': 'secret123'},
  );
  print('   - Form load fields: ${formLoad.bodyFields}');

  // Binary body (e.g., file upload)
  final binaryData = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello" in bytes
  final binaryLoad = TomServerCallLoad(
    byteBody: Uint8List.fromList(binaryData),
    contentType: 'application/octet-stream',
  );
  print('   - Binary load size: ${binaryLoad.byteBody?.length} bytes\n');

  // -------------------------------------------------------------------------
  // Example 4: TomServerChannel configuration
  // -------------------------------------------------------------------------
  print('4. Server channel configuration:');

  final channel = TomServerChannel('api.example.com', 443);
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
  print('   - Custom channel port: ${customChannel.port}\n');

  // -------------------------------------------------------------------------
  // Example 5: TomServerCallError understanding
  // -------------------------------------------------------------------------
  print('5. Server call error/response structure:');

  final successError = TomServerCallError(
    statusCode: 200,
    response: '{"id": 1, "name": "John"}',
    reasonPhrase: 'OK',
  );
  print('   - Success response status: ${successError.statusCode}');
  print('   - Has error: ${successError.hasError}');

  final notFoundError = TomServerCallError(
    statusCode: 404,
    response: '{"error": "User not found"}',
    reasonPhrase: 'Not Found',
  );
  print('   - Not found status: ${notFoundError.statusCode}');
  print('   - Has error: ${notFoundError.hasError}');
  print('   - Reason phrase: ${notFoundError.reasonPhrase}');

  final internalError = TomServerCallError(
    statusCode: 200,
    internalError: TomServerCallError.jsonDecodingError,
  );
  print('   - Internal error code: ${internalError.internalError}');
  print('   - Has error (internal): ${internalError.hasError}\n');

  // -------------------------------------------------------------------------
  // Example 6: HTTP client factory initialization
  // -------------------------------------------------------------------------
  print('6. HTTP client factory:');

  // Initialize the default factory
  TomHttpClientFactory.initialize();
  print('   - Factory initialized with defaults');

  // Create a factory instance
  final factory = TomHttpClientFactory();
  print('   - Factory instance created: ${factory.runtimeType}');

  // Note: In real applications, you can set a custom global factory:
  // TomHttpClientFactory.setGlobalHttpClientFactory(myCustomFactory);
  print('   - Custom factories can be set globally\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: HTTP Methods
  assert(getMethod.name == 'GET');
  assert(getMethod.acceptsBody == true);
  assert(postMethod.name == 'POST');
  assert(traceMethod.acceptsBody == false);
  assert(lookupMethod?.name == 'PUT');

  // Example 2: Server call specs
  assert(getSpecs.method == 'GET');
  assert(getSpecs.url.host == 'api.example.com');
  assert(postSpecs.followRedirects == true);
  assert(postSpecs.maxRedirects == 5);
  assert(postSpecs.includeBearerAuthentication == false);

  // Example 3: Server call loads
  assert(jsonLoad.contentType == 'application/json');
  assert(jsonLoad.stringBody != null);
  assert(formLoad.bodyFields != null);
  assert(formLoad.bodyFields!['username'] == 'john_doe');
  assert(binaryLoad.byteBody != null);
  assert(binaryLoad.byteBody!.length == 5);

  // Example 4: Server channel
  assert(channel.host == 'api.example.com');
  assert(channel.port == 443);
  assert(customChannel.host == 'secure.api.com');
  assert(customChannel.port == 8443);

  // Example 5: Server call error
  assert(successError.hasError == false);
  assert(notFoundError.hasError == true);
  assert(notFoundError.statusCode == 404);
  assert(internalError.hasError == true);
  assert(internalError.internalError == TomServerCallError.jsonDecodingError);
}
