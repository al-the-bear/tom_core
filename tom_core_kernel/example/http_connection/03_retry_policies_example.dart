/// Demonstrates retry policies and request lifecycle management
/// for HTTP connections.
///
/// This example shows how to configure request retries, handle
/// connection errors, abort requests, and manage server call lifecycle.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 03: Retry Policies Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Request lifecycle states
  // -------------------------------------------------------------------------
  print('1. Request lifecycle understanding:');

  print('   - A TomServerCall goes through these states:');
  print('     1. Created: Call is prepared with specs');
  print('     2. Sent: Request body is attached and sent');
  print('     3. Read: Response is consumed');
  print('     4. Reset: Call can be reused for retry');

  // Demonstrate specs for retry scenario
  final retrySpecs = TomServerCallSpecs(
    'POST',
    Uri.parse('https://api.example.com/data'),
    followRedirects: true,
    maxRedirects: 3,
    persistentConnection: true,
  );

  print('   - Retry-friendly specs:');
  print('     • Follow redirects: ${retrySpecs.followRedirects}');
  print('     • Max redirects: ${retrySpecs.maxRedirects}');
  print('     • Persistent connection: ${retrySpecs.persistentConnection}\n');

  // -------------------------------------------------------------------------
  // Example 2: Configuring retry-capable channels
  // -------------------------------------------------------------------------
  print('2. Retry-capable channel configuration:');

  // Create a channel with connection pooling for retries
  final channel = TomServerChannel('api.example.com', 443);

  print('   - Channel created for: ${channel.host}:${channel.port}');
  print('   - Client is lazily created on first use');
  print('   - Same client is reused for subsequent calls (connection pooling)');

  // Demonstrate that we can prepare multiple calls
  final specs1 = TomServerCallSpecs('GET', Uri.parse('https://api.example.com/users'));
  final specs2 = TomServerCallSpecs('GET', Uri.parse('https://api.example.com/orders'));

  // Note: In real code, you would use prepareCall, but we avoid it here
  // since it creates actual HTTP clients
  print('   - Multiple call specs can be prepared from same channel');
  print('     • Specs 1: ${specs1.method} ${specs1.url.path}');
  print('     • Specs 2: ${specs2.method} ${specs2.url.path}\n');

  // -------------------------------------------------------------------------
  // Example 3: Error status codes and retry decisions
  // -------------------------------------------------------------------------
  print('3. Error classification for retry decisions:');

  // Successful response - no retry needed
  final successResponse = TomServerCallError(statusCode: 200);
  print('   - Status 200: hasError=${successResponse.hasError} (no retry)');

  // Client errors - usually should NOT retry
  final badRequest = TomServerCallError(statusCode: 400);
  final unauthorized = TomServerCallError(statusCode: 401);
  final forbidden = TomServerCallError(statusCode: 403);
  final notFound = TomServerCallError(statusCode: 404);

  print('   - Status 400 (Bad Request): hasError=${badRequest.hasError} (no retry - fix request)');
  print('   - Status 401 (Unauthorized): hasError=${unauthorized.hasError} (retry after re-auth)');
  print('   - Status 403 (Forbidden): hasError=${forbidden.hasError} (no retry - permissions)');
  print('   - Status 404 (Not Found): hasError=${notFound.hasError} (no retry - wrong endpoint)');

  // Server errors - usually SHOULD retry
  final serverError = TomServerCallError(statusCode: 500);
  final badGateway = TomServerCallError(statusCode: 502);
  final serviceUnavailable = TomServerCallError(statusCode: 503);
  final gatewayTimeout = TomServerCallError(statusCode: 504);

  print('   - Status 500 (Server Error): hasError=${serverError.hasError} (maybe retry)');
  print('   - Status 502 (Bad Gateway): hasError=${badGateway.hasError} (retry)');
  print('   - Status 503 (Unavailable): hasError=${serviceUnavailable.hasError} (retry with backoff)');
  print('   - Status 504 (Timeout): hasError=${gatewayTimeout.hasError} (retry)\n');

  // -------------------------------------------------------------------------
  // Example 4: Implementing retry logic pattern
  // -------------------------------------------------------------------------
  print('4. Retry logic pattern:');

  // Example retry configuration
  const maxRetries = 3;
  const initialDelayMs = 100;
  const maxDelayMs = 5000;
  const backoffMultiplier = 2.0;

  print('   - Retry configuration:');
  print('     • Max retries: $maxRetries');
  print('     • Initial delay: ${initialDelayMs}ms');
  print('     • Max delay: ${maxDelayMs}ms');
  print('     • Backoff multiplier: $backoffMultiplier');

  // Calculate backoff delays
  final delays = <int>[];
  var currentDelay = initialDelayMs;
  for (var i = 0; i < maxRetries; i++) {
    delays.add(currentDelay);
    currentDelay = (currentDelay * backoffMultiplier).toInt();
    if (currentDelay > maxDelayMs) currentDelay = maxDelayMs;
  }
  print('   - Calculated delays: $delays ms\n');

  // -------------------------------------------------------------------------
  // Example 5: Retryable status code detection
  // -------------------------------------------------------------------------
  print('5. Retryable status code detection:');

  bool isRetryable(int statusCode) {
    // Network/server errors that may be transient
    return statusCode == 408 || // Request Timeout
        statusCode == 429 || // Too Many Requests
        statusCode == 500 || // Internal Server Error
        statusCode == 502 || // Bad Gateway
        statusCode == 503 || // Service Unavailable
        statusCode == 504; // Gateway Timeout
  }

  final testCodes = [200, 400, 401, 408, 429, 500, 502, 503, 504];
  for (final code in testCodes) {
    final error = TomServerCallError(statusCode: code);
    final retryable = isRetryable(code);
    print('   - Status $code: hasError=${error.hasError}, retryable=$retryable');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 6: Handling internal errors
  // -------------------------------------------------------------------------
  print('6. Internal error handling:');

  final jsonError = TomServerCallError(
    statusCode: 200,
    internalError: TomServerCallError.jsonDecodingError,
    response: 'invalid json {{{',
  );
  print('   - JSON decoding error:');
  print('     • Status code: ${jsonError.statusCode}');
  print('     • Internal error: ${jsonError.internalError}');
  print('     • Has error: ${jsonError.hasError}');
  print('     • Should retry: No (response is malformed)');

  final noResponseError = TomServerCallError(
    statusCode: 0,
    internalError: TomServerCallError.noResponseError,
  );
  print('   - No response error:');
  print('     • Internal error: ${noResponseError.internalError}');
  print('     • Has error: ${noResponseError.hasError}');
  print('     • Should retry: Yes (network issue)\n');

  // -------------------------------------------------------------------------
  // Example 7: Request abort handling
  // -------------------------------------------------------------------------
  print('7. Request abort handling:');

  print('   - Abort scenarios:');
  print('     • User cancellation');
  print('     • Timeout exceeded');
  print('     • Component disposal');
  print('     • Navigation away from page');

  // Simulate abort trigger
  final abortCompleter = Completer<void>();
  print('   - Abort trigger created: ${!abortCompleter.isCompleted}');

  // Show how abort would be triggered
  // abortCompleter.complete(); // This would abort the request
  print('   - Call abort() on TomServerCall to trigger abort');
  print('   - Aborted requests throw TomRequestAbortedException\n');

  // -------------------------------------------------------------------------
  // Example 8: Endpoint retry configuration
  // -------------------------------------------------------------------------
  print('8. Endpoint-level retry configuration:');

  // Some endpoints should have different retry behavior
  final idempotentEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
    id: 'getResource',
    uri: '/resource',
    method: TomHttpMethod.get,
    description: 'Safe to retry - GET is idempotent',
    followRedirects: true,
    maxRedirects: 5,
    persistentConnection: true,
  );

  final nonIdempotentEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
    id: 'createResource',
    uri: '/resource',
    method: TomHttpMethod.post,
    description: 'Careful with retries - POST may not be idempotent',
    followRedirects: false,
    persistentConnection: false,
  );

  final deleteEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
    id: 'deleteResource',
    uri: '/resource',
    method: TomHttpMethod.delete,
    description: 'Safe to retry - DELETE is idempotent',
    followRedirects: true,
  );

  print('   - ${idempotentEndpoint.id} (${idempotentEndpoint.method.name}):');
  print('     • Safe to retry: Yes (idempotent)');
  print('     • Persistent connection: ${idempotentEndpoint.persistentConnection}');

  print('   - ${nonIdempotentEndpoint.id} (${nonIdempotentEndpoint.method.name}):');
  print('     • Safe to retry: Caution (may duplicate)');
  print('     • Persistent connection: ${nonIdempotentEndpoint.persistentConnection}');

  print('   - ${deleteEndpoint.id} (${deleteEndpoint.method.name}):');
  print('     • Safe to retry: Yes (idempotent)');
  print('     • Follow redirects: ${deleteEndpoint.followRedirects}\n');

  // -------------------------------------------------------------------------
  // Example 9: Connection cleanup
  // -------------------------------------------------------------------------
  print('9. Connection cleanup:');

  print('   - Always close channels when done:');
  print('     channel.close();');
  print('   - This releases HTTP client resources');
  print('   - Important for long-running applications');

  // Cleanup
  channel.close();
  print('   - Channel closed successfully\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Request lifecycle
  assert(retrySpecs.followRedirects == true);
  assert(retrySpecs.maxRedirects == 3);
  assert(retrySpecs.persistentConnection == true);

  // Example 3: Error classification
  assert(successResponse.hasError == false);
  assert(badRequest.hasError == true);
  assert(serverError.hasError == true);

  // Example 4: Retry delays
  assert(delays.length == maxRetries);
  assert(delays[0] == initialDelayMs);
  assert(delays[1] == 200); // 100 * 2
  assert(delays[2] == 400); // 200 * 2

  // Example 5: Retryable detection
  assert(isRetryable(503) == true);
  assert(isRetryable(504) == true);
  assert(isRetryable(200) == false);
  assert(isRetryable(400) == false);

  // Example 6: Internal errors
  assert(jsonError.hasError == true);
  assert(jsonError.internalError == TomServerCallError.jsonDecodingError);
  assert(noResponseError.internalError == TomServerCallError.noResponseError);

  // Example 7: Abort handling
  assert(abortCompleter.isCompleted == false);

  // Example 8: Endpoint configuration
  assert(idempotentEndpoint.method == TomHttpMethod.get);
  assert(nonIdempotentEndpoint.method == TomHttpMethod.post);
  assert(deleteEndpoint.method == TomHttpMethod.delete);
}
