/// API and Endpoint Definition Example
///
/// This example demonstrates the API definition and registration system:
/// - TomRemoteApis registry for managing APIs
/// - TomApi for grouping endpoints
/// - TomApiEndpoint for endpoint configuration
/// - TomClientRemoteContext for server configuration
/// - Bracket notation for accessing APIs and endpoints
/// - Resolving an endpoint's address from its own declaration
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Example Request/Response Types
// ============================================================================

/// Sample user response type.
class UserResponse {
  final int id;
  final String name;
  final String email;

  UserResponse({required this.id, required this.name, required this.email});
}

/// Sample user creation request type.
class CreateUserRequest {
  final String name;
  final String email;

  CreateUserRequest({required this.name, required this.email});
}

/// Sample order response type.
class OrderResponse {
  final String orderId;
  final double total;

  OrderResponse({required this.orderId, required this.total});
}

// ============================================================================
// Example Class
// ============================================================================

class ApiEndpointDefinitionExample {
  // Captured results
  static late TomApi userApi;
  static late TomApi orderApi;
  static late TomApiEndpoint createUserEndpoint;
  static late TomApiEndpoint getUserEndpoint;
  static late String apiId;
  static late String endpointId;
  static late String endpointMethod;
  static bool registryWorks = false;
  static bool bracketNotationWorks = false;
  static late TomClientRemoteContext remoteContext;
  static bool caughtEndpointException = false;
  static late String caughtExceptionKey;
  static late String fullEndpointUri;

  // --------------------------------------------------------------------------
  // Example 1: Creating a TomApi with endpoints
  // --------------------------------------------------------------------------
  static void example1CreateApi() {
    print('1. Creating TomApi with endpoints:');

    userApi = TomApi(
      id: 'users',
      name: 'User Management API',
      description: 'Handles user CRUD operations',
      uri: '/api/v1/users',
      requestEncoding: utf8,
      responseEncoding: utf8,
      endpoints: [
        TomApiEndpoint<UserResponse, CreateUserRequest>(
          id: 'create',
          uri: '/create',
          method: TomHttpMethod.post,
          consumes: TomMimeType.json,
          produces: TomMimeType.json,
          description: 'Create a new user',
          includeBearerAuthentication: true,
        ),
        TomApiEndpoint<UserResponse, void>(
          id: 'getById',
          uri: '/{id}',
          method: TomHttpMethod.get,
          produces: TomMimeType.json,
          description: 'Get user by ID',
        ),
        TomApiEndpoint<void, void>(
          id: 'delete',
          uri: '/{id}',
          method: TomHttpMethod.delete,
          description: 'Delete a user',
        ),
      ],
    );

    apiId = userApi.id;
    print('   - API ID: $apiId');
    print('   - API Name: ${userApi.name}');
    print('   - API URI: ${userApi.uri}');
    print('   - Endpoints count: ${userApi.endpoints.length}');

    // Assertions
    assert(apiId == 'users', 'API ID should be users');
    assert(userApi.endpoints.length == 3, 'Should have 3 endpoints');
  }

  // --------------------------------------------------------------------------
  // Example 2: Accessing endpoints with bracket notation
  // --------------------------------------------------------------------------
  static void example2BracketNotation() {
    print('\n2. Accessing endpoints with bracket notation:');

    // Access endpoint from API using []
    createUserEndpoint = userApi['create'];
    getUserEndpoint = userApi['getById'];

    endpointId = createUserEndpoint.id;
    endpointMethod = createUserEndpoint.method.name;

    print('   - Create endpoint ID: $endpointId');
    print('   - Create endpoint method: $endpointMethod');
    print('   - Create endpoint URI: ${createUserEndpoint.uri}');
    print('   - Create endpoint consumes: ${createUserEndpoint.consumes.toHeaderValue()}');
    print('   - Create endpoint produces: ${createUserEndpoint.produces.toHeaderValue()}');

    print('   - GetById endpoint ID: ${getUserEndpoint.id}');
    print('   - GetById endpoint method: ${getUserEndpoint.method.name}');

    bracketNotationWorks = true;

    // Assertions
    assert(endpointId == 'create', 'Endpoint ID should be create');
    assert(endpointMethod == 'POST', 'Method should be POST');
    assert(getUserEndpoint.method == TomHttpMethod.get, 'GetById should be GET');
  }

  // --------------------------------------------------------------------------
  // Example 3: Registering APIs with TomRemoteApis
  // --------------------------------------------------------------------------
  static void example3RegisterApis() {
    print('\n3. Registering APIs with TomRemoteApis:');

    // Create another API
    orderApi = TomApi(
      id: 'orders',
      name: 'Order Management API',
      uri: '/api/v1/orders',
      endpoints: [
        TomApiEndpoint<OrderResponse, Map<String, Object?>>(
          id: 'list',
          uri: '/list',
          method: TomHttpMethod.get,
        ),
      ],
    );

    // Register both APIs
    TomRemoteApis.registerApi(userApi);
    TomRemoteApis.registerApi(orderApi);

    // Retrieve by ID
    final retrievedUserApi = TomRemoteApis.getApiById('users');
    final retrievedOrderApi = TomRemoteApis.getApiById('orders');

    print('   - Registered user API: ${retrievedUserApi.id}');
    print('   - Registered order API: ${retrievedOrderApi.id}');
    print('   - Total APIs registered: ${TomRemoteApis.current.apis.length}');

    registryWorks = retrievedUserApi.id == 'users' && retrievedOrderApi.id == 'orders';

    // Assertions
    assert(registryWorks, 'Registry should work');
    assert(TomRemoteApis.current.apis.length >= 2, 'Should have at least 2 APIs');
  }

  // --------------------------------------------------------------------------
  // Example 4: Using global tomRemoteApis accessor
  // --------------------------------------------------------------------------
  static void example4GlobalAccessor() {
    print('\n4. Using global tomRemoteApis accessor:');

    // Access API using global accessor and bracket notation
    final api = tomRemoteApis['users'];
    final endpoint = tomRemoteApis['users']['create'];

    print('   - Accessed API: ${api.id}');
    print('   - Accessed endpoint: ${endpoint.id}');
    print('   - Endpoint description: ${endpoint.description}');

    // Chain bracket notation to get endpoint directly
    final ordersListEndpoint = tomRemoteApis['orders']['list'];
    print('   - Orders list endpoint method: ${ordersListEndpoint.method.name}');

    // Assertions
    assert(api.id == 'users', 'Should access users API');
    assert(endpoint.id == 'create', 'Should access create endpoint');
  }

  // --------------------------------------------------------------------------
  // Example 5: TomApiEndpoint configuration options
  // --------------------------------------------------------------------------
  static void example5EndpointConfiguration() {
    print('\n5. TomApiEndpoint configuration options:');

    // Create an endpoint with all configuration options
    final fullConfigEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
      id: 'upload',
      uri: '/files/upload',
      description: 'Upload a file with metadata',
      method: TomHttpMethod.post,
      consumes: TomMimeType.multipartFormData,
      produces: TomMimeType.json,
      contentDisposition: TomContentDisposition.attachment,
      formFields: ['file', 'description', 'tags'],
      requestHeaders: {'X-Upload-Source': 'mobile-app'},
      responseHeaders: {'X-File-Version': '1.0'},
      followRedirects: true,
      maxRedirects: 3,
      persistentConnection: true,
      includeBearerAuthentication: true,
    );

    print('   - Endpoint ID: ${fullConfigEndpoint.id}');
    print('   - Consumes: ${fullConfigEndpoint.consumes.toHeaderValue()}');
    print('   - Produces: ${fullConfigEndpoint.produces.toHeaderValue()}');
    print('   - Content-Disposition: ${fullConfigEndpoint.contentDisposition}');
    print('   - Form fields: ${fullConfigEndpoint.formFields}');
    print('   - Follow redirects: ${fullConfigEndpoint.followRedirects}');
    print('   - Max redirects: ${fullConfigEndpoint.maxRedirects}');
    print('   - Include bearer auth: ${fullConfigEndpoint.includeBearerAuthentication}');

    // Assertions
    assert(fullConfigEndpoint.followRedirects == true, 'Should follow redirects');
    assert(fullConfigEndpoint.maxRedirects == 3, 'Max redirects should be 3');
    assert(fullConfigEndpoint.formFields.length == 3, 'Should have 3 form fields');
  }

  // --------------------------------------------------------------------------
  // Example 6: Endpoint parent API access
  // --------------------------------------------------------------------------
  static void example6EndpointParentApi() {
    print('\n6. Endpoint parent API access:');

    // Get the parent API from an endpoint
    final endpoint = userApi['create'];
    final parentApi = endpoint.api;

    fullEndpointUri = '${parentApi.uri}${endpoint.uri}';

    print('   - Endpoint ID: ${endpoint.id}');
    print('   - Parent API ID: ${parentApi.id}');
    print('   - Parent API URI: ${parentApi.uri}');
    print('   - Endpoint URI: ${endpoint.uri}');
    print('   - Full path: $fullEndpointUri');

    // Assertions
    assert(parentApi.id == 'users', 'Parent API should be users');
    assert(fullEndpointUri == '/api/v1/users/create', 'Full URI should match');
  }

  // --------------------------------------------------------------------------
  // Example 7: Error handling - API not found
  // --------------------------------------------------------------------------
  static void example7ApiNotFound() {
    print('\n7. Error handling - API not found:');

    try {
      final _ = tomRemoteApis['nonexistent'];
      print('   - ERROR: Should have thrown exception');
    } on TomEndpointException catch (e) {
      caughtEndpointException = true;
      caughtExceptionKey = e.key;
      print('   - Caught TomEndpointException');
      print('   - Exception key: ${e.key}');
      print('   - Message: ${e.defaultUserMessage}');
    }

    // Assertions
    assert(caughtEndpointException, 'Should catch exception');
    assert(caughtExceptionKey == 'apis.api.not_found', 'Exception key should match');
  }

  // --------------------------------------------------------------------------
  // Example 8: Error handling - Endpoint not found
  // --------------------------------------------------------------------------
  static void example8EndpointNotFound() {
    print('\n8. Error handling - Endpoint not found:');

    try {
      final _ = tomRemoteApis['users']['nonexistent'];
      print('   - ERROR: Should have thrown exception');
    } on TomEndpointException catch (e) {
      print('   - Caught TomEndpointException');
      print('   - Exception key: ${e.key}');
      print('   - Message: ${e.defaultUserMessage}');
      assert(e.key == 'apis.endpoint.not_found', 'Exception key should match');
    }
  }

  // --------------------------------------------------------------------------
  // Example 9: Adding endpoints dynamically
  // --------------------------------------------------------------------------
  static void example9DynamicEndpoints() {
    print('\n9. Adding endpoints dynamically:');

    // Create a new endpoint
    final patchEndpoint = TomApiEndpoint<UserResponse, Map<String, Object?>>(
      id: 'patch',
      uri: '/{id}',
      method: TomHttpMethod.patch,
      description: 'Partially update a user',
    );

    // Add to existing API using bracket notation
    userApi['patch'] = patchEndpoint;

    print('   - Added patch endpoint to users API');
    print('   - Total endpoints now: ${userApi.endpoints.length}');
    print('   - Patch endpoint method: ${userApi['patch'].method.name}');

    // Verify the endpoint is linked to the API
    final parentApi = patchEndpoint.api;
    print('   - Patch endpoint parent API: ${parentApi.id}');

    // Assertions
    assert(userApi.endpoints.length == 4, 'Should have 4 endpoints now');
    assert(patchEndpoint.api.id == 'users', 'Parent should be set');
  }

  // --------------------------------------------------------------------------
  // Example 10: Status code response types
  // --------------------------------------------------------------------------
  static void example10StatusCodeTypes() {
    print('\n10. Status code response types:');

    // Define an API with status code mappings
    final apiWithStatusCodes = TomApi(
      id: 'withStatusCodes',
      name: 'API with Status Code Types',
      uri: '/api/v1/status',
      statusCodeResponseTypes: {
        400: Map<String, Object?>,  // Bad request returns error map
        401: Map<String, Object?>,  // Unauthorized
        404: Map<String, Object?>,  // Not found
        500: Map<String, Object?>,  // Server error
      },
      endpoints: [
        TomApiEndpoint<UserResponse, CreateUserRequest>(
          id: 'create',
          uri: '/create',
          method: TomHttpMethod.post,
          statusCodeResponseTypes: {
            409: Map<String, Object?>,  // Conflict - endpoint specific
          },
        ),
      ],
    );

    print('   - API-level status code types: ${apiWithStatusCodes.statusCodeResponseTypes}');
    print('   - Endpoint-level status code types: ${apiWithStatusCodes['create'].statusCodeResponseTypes}');

    // Assertions
    assert(
      apiWithStatusCodes.statusCodeResponseTypes?.containsKey(400) ?? false,
      'Should have 400 mapping',
    );
    assert(
      apiWithStatusCodes['create'].statusCodeResponseTypes?.containsKey(409) ?? false,
      'Should have endpoint 409 mapping',
    );
  }

  // --------------------------------------------------------------------------
  // Example 11: From a declaration to an addressed endpoint
  // --------------------------------------------------------------------------
  static void example11UrlParameterResolution() {
    print('\n11. URL parameters — from declaration to address:');

    // The declaration is the only place the address is written down. Path
    // captures and query parameters are named once, here, and both the client
    // and the server read the route from this same statement.
    final catalogApi = TomApi(
      id: 'catalogApi',
      name: 'Catalog API',
      uri: '/api/v1/items',
      endpoints: [
        TomApiEndpoint<OrderResponse, CreateUserRequest>(
          id: 'getById',
          uri: '/{id}',
          method: TomHttpMethod.get,
          urlParameterMapping: {
            'id': 'itemId', //         {id} in the path
            'lang': 'language', //     ?lang=…
          },
        ),
      ],
    );

    // resolveUri builds the address on its own; parameters are keyed by
    // request-DTO field name, because a client holds a DTO, not a URL.
    final resolved = catalogApi['getById'].resolveUri(
      Uri.parse('https://api.example.com'),
      parameters: {'itemId': 42, 'language': 'de'},
    );
    print('   - resolveUri:                 $resolved');

    // createApiServerEndpoint resolves the same way, so going straight from a
    // declaration to a callable endpoint needs no hand-written URI either.
    final endpoint = TomServerEndpoint.createApiServerEndpoint<OrderResponse,
        CreateUserRequest>(
      catalogApi['getById'],
      baseUri: Uri.parse('https://api.example.com'),
      parameters: {'itemId': 42, 'language': 'de'},
    );
    print('   - createApiServerEndpoint:    ${endpoint.specs.url}');

    // An optional query parameter is simply omitted when it has no value...
    final withoutLanguage = catalogApi['getById'].resolveUri(
      Uri.parse('https://api.example.com'),
      parameters: {'itemId': 42},
    );
    print('   - without the query parameter: $withoutLanguage');

    // ...whereas a path capture with no value is a broken address, not an
    // empty segment, so it is refused rather than sent.
    var refusedMissingCapture = false;
    try {
      catalogApi['getById'].resolveUri(Uri.parse('https://api.example.com'));
    } on TomEndpointException catch (e) {
      refusedMissingCapture = true;
      print('   - missing capture refused:     ${e.key}');
    }

    // Assertions
    assert(
      resolved.toString() == 'https://api.example.com/api/v1/items/42?lang=de',
      'resolveUri must substitute the capture and append the query parameter',
    );
    assert(
      endpoint.specs.url == resolved,
      'The endpoint factory must address exactly what resolveUri builds',
    );
    assert(!withoutLanguage.hasQuery, 'An unset query parameter is omitted');
    assert(refusedMissingCapture, 'A capture without a value must be refused');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('API AND ENDPOINT DEFINITION EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  ApiEndpointDefinitionExample.example1CreateApi();
  ApiEndpointDefinitionExample.example2BracketNotation();
  ApiEndpointDefinitionExample.example3RegisterApis();
  ApiEndpointDefinitionExample.example4GlobalAccessor();
  ApiEndpointDefinitionExample.example5EndpointConfiguration();
  ApiEndpointDefinitionExample.example6EndpointParentApi();
  ApiEndpointDefinitionExample.example7ApiNotFound();
  ApiEndpointDefinitionExample.example8EndpointNotFound();
  ApiEndpointDefinitionExample.example9DynamicEndpoints();
  ApiEndpointDefinitionExample.example10StatusCodeTypes();
  ApiEndpointDefinitionExample.example11UrlParameterResolution();

  print('\n✓ All API and endpoint definition examples passed!\n');
}

void main() => run();
