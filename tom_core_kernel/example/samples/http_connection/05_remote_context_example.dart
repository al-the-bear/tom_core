/// Remote Context Configuration Example
///
/// This example demonstrates TomClientRemoteContext for configuring
/// where client applications send server requests.
///
/// Key concepts:
/// - Setting up TomClientRemoteContext
/// - Configuring separate authentication server
/// - Accessing the current context
/// - Error handling for double initialization
/// - Which of the two URIs a built endpoint addresses
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Class
// ============================================================================

class RemoteContextExample {
  // Captured results
  static late Uri capturedBaseUri;
  static late Uri capturedAuthUri;
  static bool contextAccessWorks = false;
  static bool caughtDoubleInitError = false;
  static late String caughtExceptionKey;

  // --------------------------------------------------------------------------
  // Example 1: Understanding TomClientRemoteContext structure
  // --------------------------------------------------------------------------
  static void example1ContextStructure() {
    print('1. TomClientRemoteContext structure:');

    // Create a context (but don't set it as current yet)
    final context = TomClientRemoteContext(
      Uri.parse('https://api.example.com'),
    );

    capturedBaseUri = context.baseUri;
    capturedAuthUri = context.authenticationUri;

    print('   - Base URI: ${context.baseUri}');
    print('   - Authentication URI: ${context.authenticationUri}');
    print('   - Are they the same? ${context.baseUri == context.authenticationUri}');
    print('   - toString(): $context');

    // Assertions
    assert(capturedBaseUri.host == 'api.example.com', 'Base URI host should match');
    assert(capturedAuthUri.host == 'api.example.com', 'Auth URI should default to base URI');
  }

  // --------------------------------------------------------------------------
  // Example 2: Separate authentication server configuration
  // --------------------------------------------------------------------------
  static void example2SeparateAuthServer() {
    print('\n2. Separate authentication server:');

    final context = TomClientRemoteContext(
      Uri.parse('https://api.example.com'),
      Uri.parse('https://auth.example.com'),
    );

    print('   - Base URI: ${context.baseUri}');
    print('   - Auth URI: ${context.authenticationUri}');
    print('   - Different servers: ${context.baseUri.host != context.authenticationUri.host}');

    // Assertions
    assert(context.baseUri.host == 'api.example.com', 'Base should be api.example.com');
    assert(context.authenticationUri.host == 'auth.example.com', 'Auth should be auth.example.com');
  }

  // --------------------------------------------------------------------------
  // Example 3: URI configuration patterns
  // --------------------------------------------------------------------------
  static void example3UriPatterns() {
    print('\n3. URI configuration patterns:');

    // Local development
    final devContext = TomClientRemoteContext(
      Uri.parse('http://localhost:8080'),
    );
    print('   - Dev context: ${devContext.baseUri}');

    // With port and path
    final withPath = TomClientRemoteContext(
      Uri.parse('https://api.example.com:9443/v2'),
    );
    print('   - With path: ${withPath.baseUri}');
    print('   - Path component: ${withPath.baseUri.path}');
    print('   - Port: ${withPath.baseUri.port}');

    // HTTPS with different auth endpoint
    final prodContext = TomClientRemoteContext(
      Uri.parse('https://api.prod.example.com'),
      Uri.parse('https://sso.example.com/oauth'),
    );
    print('   - Prod API: ${prodContext.baseUri}');
    print('   - Prod SSO: ${prodContext.authenticationUri}');

    // Assertions
    assert(devContext.baseUri.scheme == 'http', 'Dev should be HTTP');
    assert(withPath.baseUri.port == 9443, 'Port should be 9443');
    assert(withPath.baseUri.path == '/v2', 'Path should be /v2');
  }

  // --------------------------------------------------------------------------
  // Example 4: Static current context access
  // --------------------------------------------------------------------------
  static void example4CurrentContext() {
    print('\n4. Static current context access:');

    // Check initial state (may be null or set from previous tests)
    final initialState = TomClientRemoteContext.current;
    print('   - Initial current state: ${initialState != null ? 'set' : 'null'}');

    // If not set, we'll demonstrate setting it
    if (initialState == null) {
      TomClientRemoteContext.setCurrent(
        TomClientRemoteContext(
          Uri.parse('https://sample.api.com'),
        ),
      );
      print('   - Set current context to: ${TomClientRemoteContext.current}');
    }

    // Access the current context
    final current = TomClientRemoteContext.current;
    if (current != null) {
      print('   - Current base URI: ${current.baseUri}');
      print('   - Current auth URI: ${current.authenticationUri}');
      contextAccessWorks = true;
    }

    // Assertions
    assert(TomClientRemoteContext.current != null, 'Current should be set');
  }

  // --------------------------------------------------------------------------
  // Example 5: Double initialization error handling
  // --------------------------------------------------------------------------
  static void example5DoubleInitError() {
    print('\n5. Double initialization error handling:');

    // Try to set the context again - should throw
    try {
      TomClientRemoteContext.setCurrent(
        TomClientRemoteContext(
          Uri.parse('https://another.api.com'),
        ),
      );
      print('   - ERROR: Should have thrown exception');
    } on TomClientRemoteContextException catch (e) {
      caughtDoubleInitError = true;
      caughtExceptionKey = e.key;
      print('   - Caught TomClientRemoteContextException');
      print('   - Exception key: ${e.key}');
      print('   - Message: ${e.defaultUserMessage}');
    }

    // Assertions
    assert(caughtDoubleInitError, 'Should catch double init exception');
    assert(
      caughtExceptionKey == 'tomclient.remote_context_state_error.already_initialized',
      'Exception key should match',
    );
  }

  // --------------------------------------------------------------------------
  // Example 6: URI manipulation for endpoint construction
  // --------------------------------------------------------------------------
  static void example6UriManipulation() {
    print('\n6. URI manipulation for endpoint construction:');

    final context = TomClientRemoteContext(
      Uri.parse('https://api.example.com'),
    );

    // Construct full endpoint URLs
    final usersEndpoint = context.baseUri.resolve('/api/v1/users');
    final userById = context.baseUri.resolve('/api/v1/users/123');

    print('   - Base URI: ${context.baseUri}');
    print('   - Users endpoint: $usersEndpoint');
    print('   - User by ID: $userById');

    // With query parameters
    final withQuery = context.baseUri.replace(
      path: '/api/v1/search',
      queryParameters: {'q': 'test', 'limit': '10'},
    );
    print('   - With query: $withQuery');

    // Assertions
    assert(usersEndpoint.path == '/api/v1/users', 'Users path should match');
    assert(userById.path == '/api/v1/users/123', 'User by ID path should match');
    assert(withQuery.queryParameters['q'] == 'test', 'Query param should match');
  }

  // --------------------------------------------------------------------------
  // Example 7: Environment-specific context patterns
  // --------------------------------------------------------------------------
  static void example7EnvironmentPatterns() {
    print('\n7. Environment-specific context patterns:');

    // Factory pattern for environment-specific contexts
    TomClientRemoteContext createContextForEnv(String env) {
      switch (env) {
        case 'dev':
          return TomClientRemoteContext(
            Uri.parse('http://localhost:8080'),
          );
        case 'int':
          return TomClientRemoteContext(
            Uri.parse('https://int-api.example.com'),
            Uri.parse('https://int-auth.example.com'),
          );
        case 'prod':
          return TomClientRemoteContext(
            Uri.parse('https://api.example.com'),
            Uri.parse('https://sso.example.com'),
          );
        default:
          return TomClientRemoteContext(
            Uri.parse('http://localhost:8080'),
          );
      }
    }

    final devCtx = createContextForEnv('dev');
    final intCtx = createContextForEnv('int');
    final prodCtx = createContextForEnv('prod');

    print('   - Dev base: ${devCtx.baseUri}');
    print('   - Int base: ${intCtx.baseUri}, auth: ${intCtx.authenticationUri}');
    print('   - Prod base: ${prodCtx.baseUri}, auth: ${prodCtx.authenticationUri}');

    // Assertions
    assert(devCtx.baseUri.host == 'localhost', 'Dev should be localhost');
    assert(intCtx.baseUri.host == 'int-api.example.com', 'Int should use int-api');
    assert(prodCtx.authenticationUri.host == 'sso.example.com', 'Prod auth should use SSO');
  }

  // --------------------------------------------------------------------------
  // Example 8: Which URI an endpoint actually addresses
  // --------------------------------------------------------------------------
  static void example8EndpointRouting() {
    print('\n8. Which server an endpoint addresses:');

    // The examples above compose URIs by hand. This one builds a real endpoint
    // and reads back where it points, under a context whose two URIs differ —
    // the only configuration in which the choice is observable.
    final api = TomApi(
      id: 'catalogApi',
      uri: '/api/v1',
      endpoints: [
        TomApiEndpoint<String, String>(
          id: 'items',
          uri: '/items',
          method: TomHttpMethod.get,
        ),
      ],
    );

    final context = TomClientRemoteContext(
      Uri.parse('https://api.example.com'),
      Uri.parse('https://auth.example.com'),
    );

    // An API endpoint with no explicit base goes to the API server.
    final apiEndpoint = TomClientRemoteContext.runWithContext(
      context,
      () => TomServerEndpoint.createApiServerEndpoint<String, String>(
        api['items'],
      ),
    );

    // An authentication endpoint names the authentication URI explicitly.
    final authEndpoint = TomClientRemoteContext.runWithContext(
      context,
      () => TomServerEndpoint.createApiServerEndpoint<String, String>(
        api['items'],
        baseUri: context.authenticationUri,
      ),
    );

    print('   - API endpoint:  ${apiEndpoint.specs.url}');
    print('   - Auth endpoint: ${authEndpoint.specs.url}');

    assert(apiEndpoint.specs.url.host == 'api.example.com',
        'An API endpoint must address the API server');
    assert(authEndpoint.specs.url.host == 'auth.example.com',
        'An authentication endpoint must address the authentication server');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('REMOTE CONTEXT CONFIGURATION EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  RemoteContextExample.example1ContextStructure();
  RemoteContextExample.example2SeparateAuthServer();
  RemoteContextExample.example3UriPatterns();
  RemoteContextExample.example4CurrentContext();
  RemoteContextExample.example5DoubleInitError();
  RemoteContextExample.example6UriManipulation();
  RemoteContextExample.example7EnvironmentPatterns();
  RemoteContextExample.example8EndpointRouting();

  print('\n✓ All remote context examples passed!\n');
}

void main() => run();
