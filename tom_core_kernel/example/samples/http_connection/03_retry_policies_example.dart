/// Retry Policies Example
///
/// This example demonstrates retry policies and request lifecycle
/// management for HTTP connections.
///
/// Key concepts:
/// - Request lifecycle states
/// - Error status codes and retry decisions
/// - Implementing retry logic patterns
/// - Retryable status code detection
/// - Internal error handling
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Class
// ============================================================================

class RetryPoliciesExample {
  // Captured results
  static late TomServerCallSpecs retrySpecs;
  static late List<int> calculatedDelays;
  static late Map<int, bool> retryableStatusCodes;
  static bool successHasError = true;
  static bool serverErrorHasError = false;

  // -------------------------------------------------------------------------
  // Example 1: Request lifecycle states
  // -------------------------------------------------------------------------
  static void example1RequestLifecycle() {
    print('1. Request lifecycle understanding:');

    print('   - A TomServerCall goes through these states:');
    print('     1. Created: Call is prepared with specs');
    print('     2. Sent: Request body is attached and sent');
    print('     3. Read: Response is consumed');
    print('     4. Reset: Call can be reused for retry');

    // Demonstrate specs for retry scenario
    retrySpecs = TomServerCallSpecs(
      'POST',
      Uri.parse('https://api.example.com/data'),
      followRedirects: true,
      maxRedirects: 3,
      persistentConnection: true,
    );

    print('   - Retry-friendly specs:');
    print('     • Follow redirects: ${retrySpecs.followRedirects}');
    print('     • Max redirects: ${retrySpecs.maxRedirects}');
    print('     • Persistent connection: ${retrySpecs.persistentConnection}');

    // Assertions
    assert(retrySpecs.followRedirects == true, 'Should follow redirects');
    assert(retrySpecs.maxRedirects == 3, 'Max redirects should be 3');
    assert(retrySpecs.persistentConnection == true, 'Should have persistent connection');
  }

  // -------------------------------------------------------------------------
  // Example 2: Configuring retry-capable channels
  // -------------------------------------------------------------------------
  static void example2RetryCapableChannels() {
    print('\n2. Retry-capable channel configuration:');

    // Create a channel with connection pooling for retries
    final channel = TomServerChannel('api.example.com', 443);

    print('   - Channel created for: ${channel.host}:${channel.port}');
    print('   - Client is lazily created on first use');
    print('   - Same client is reused for subsequent calls (connection pooling)');

    // Demonstrate that we can prepare multiple calls
    final specs1 = TomServerCallSpecs('GET', Uri.parse('https://api.example.com/users'));
    final specs2 = TomServerCallSpecs('GET', Uri.parse('https://api.example.com/orders'));

    print('   - Multiple call specs can be prepared from same channel');
    print('     • Specs 1: ${specs1.method} ${specs1.url.path}');
    print('     • Specs 2: ${specs2.method} ${specs2.url.path}');

    // Assertions
    assert(channel.host == 'api.example.com', 'Host should match');
    assert(channel.port == 443, 'Port should be 443');
  }

  // -------------------------------------------------------------------------
  // Example 3: Error status codes and retry decisions
  // -------------------------------------------------------------------------
  static void example3ErrorClassification() {
    print('\n3. Error classification for retry decisions:');

    // Successful response - no retry needed
    final successResponse = TomServerCallError(statusCode: 200);
    successHasError = successResponse.hasError;
    print('   - Status 200: hasError=$successHasError (no retry)');

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
    serverErrorHasError = serverError.hasError;
    final badGateway = TomServerCallError(statusCode: 502);
    final serviceUnavailable = TomServerCallError(statusCode: 503);
    final gatewayTimeout = TomServerCallError(statusCode: 504);

    print('   - Status 500 (Server Error): hasError=$serverErrorHasError (maybe retry)');
    print('   - Status 502 (Bad Gateway): hasError=${badGateway.hasError} (retry)');
    print('   - Status 503 (Unavailable): hasError=${serviceUnavailable.hasError} (retry with backoff)');
    print('   - Status 504 (Timeout): hasError=${gatewayTimeout.hasError} (retry)');

    // Assertions
    assert(successHasError == false, 'Success should not have error');
    assert(serverErrorHasError == true, 'Server error should have error');
    assert(notFound.hasError == true, 'Not found should have error');
  }

  // -------------------------------------------------------------------------
  // Example 4: Implementing retry logic pattern
  // -------------------------------------------------------------------------
  static void example4RetryLogicPattern() {
    print('\n4. Retry logic pattern:');

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
    calculatedDelays = [];
    var currentDelay = initialDelayMs;
    for (var i = 0; i < maxRetries; i++) {
      calculatedDelays.add(currentDelay);
      currentDelay = (currentDelay * backoffMultiplier).toInt();
      if (currentDelay > maxDelayMs) currentDelay = maxDelayMs;
    }
    print('   - Calculated delays: $calculatedDelays ms');

    // Assertions
    assert(calculatedDelays.length == 3, 'Should have 3 delays');
    assert(calculatedDelays[0] == 100, 'First delay should be 100');
    assert(calculatedDelays[1] == 200, 'Second delay should be 200');
    assert(calculatedDelays[2] == 400, 'Third delay should be 400');
  }

  // -------------------------------------------------------------------------
  // Example 5: Retryable status code detection
  // -------------------------------------------------------------------------
  static void example5RetryableDetection() {
    print('\n5. Retryable status code detection:');

    bool isRetryable(int statusCode) {
      // Network/server errors that may be transient
      return statusCode == 408 || // Request Timeout
          statusCode == 429 || // Too Many Requests
          statusCode == 500 || // Internal Server Error
          statusCode == 502 || // Bad Gateway
          statusCode == 503 || // Service Unavailable
          statusCode == 504; // Gateway Timeout
    }

    retryableStatusCodes = {};
    final testCodes = [200, 400, 401, 408, 429, 500, 502, 503, 504];
    for (final code in testCodes) {
      final error = TomServerCallError(statusCode: code);
      final retryable = isRetryable(code);
      retryableStatusCodes[code] = retryable;
      print('   - Status $code: hasError=${error.hasError}, retryable=$retryable');
    }

    // Assertions
    assert(retryableStatusCodes[200] == false, '200 should not be retryable');
    assert(retryableStatusCodes[400] == false, '400 should not be retryable');
    assert(retryableStatusCodes[503] == true, '503 should be retryable');
    assert(retryableStatusCodes[504] == true, '504 should be retryable');
  }

  // -------------------------------------------------------------------------
  // Example 6: Handling internal errors
  // -------------------------------------------------------------------------
  static void example6InternalErrors() {
    print('\n6. Internal error handling:');

    final jsonError = TomServerCallError(
      statusCode: 200,
      internalError: TomServerCallError.jsonDecodingError,
    );

    final networkError = TomServerCallError(
      statusCode: -1,
      internalError: TomServerCallError.noResponseError,
    );

    final timeoutError = TomServerCallError(
      statusCode: -1,
      internalError: TomServerCallError.serverError,
    );

    print('   - JSON decode error (status 200):');
    print('     • hasError: ${jsonError.hasError}');
    print('     • internalError: ${jsonError.internalError}');

    print('   - Network error:');
    print('     • hasError: ${networkError.hasError}');
    print('     • internalError: ${networkError.internalError}');

    print('   - Timeout error:');
    print('     • hasError: ${timeoutError.hasError}');
    print('     • internalError: ${timeoutError.internalError}');

    // Assertions
    assert(jsonError.hasError == true, 'JSON error should have error');
    assert(jsonError.internalError == TomServerCallError.jsonDecodingError, 'Should be JSON decoding error');
    assert(networkError.hasError == true, 'Network error should have error');
    assert(timeoutError.hasError == true, 'Timeout error should have error');
  }

  // -------------------------------------------------------------------------
  // Example 7: Retry decision matrix
  // -------------------------------------------------------------------------
  static void example7RetryDecisionMatrix() {
    print('\n7. Retry decision matrix:');

    print('   - Decision factors for retry:');
    print('     • Status code in retryable range (5xx, 408, 429)');
    print('     • Not exceeded max retry attempts');
    print('     • Request is idempotent (safe to retry)');
    print('     • Connection error (not application error)');
    print('');
    print('   - Idempotent methods (safe to retry):');
    print('     • GET, HEAD, OPTIONS, PUT, DELETE');
    print('   - Non-idempotent methods (caution when retrying):');
    print('     • POST, PATCH');

    final idempotentMethods = ['GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'];
    final nonIdempotentMethods = ['POST', 'PATCH'];

    for (final method in idempotentMethods) {
      final httpMethod = TomHttpMethod.methods[method];
      print('   - $method: idempotent=true, acceptsBody=${httpMethod?.acceptsBody}');
    }

    for (final method in nonIdempotentMethods) {
      final httpMethod = TomHttpMethod.methods[method];
      print('   - $method: idempotent=false, acceptsBody=${httpMethod?.acceptsBody}');
    }

    // Assertions
    assert(TomHttpMethod.methods['GET'] != null, 'GET should exist');
    assert(TomHttpMethod.methods['POST'] != null, 'POST should exist');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 03: Retry Policies Example ===\n');

    example1RequestLifecycle();
    example2RetryCapableChannels();
    example3ErrorClassification();
    example4RetryLogicPattern();
    example5RetryableDetection();
    example6InternalErrors();
    example7RetryDecisionMatrix();

    print('\n=== Retry Policies Example Complete ===\n');
  }
}

void run() => RetryPoliciesExample.run();

void main() => run();
