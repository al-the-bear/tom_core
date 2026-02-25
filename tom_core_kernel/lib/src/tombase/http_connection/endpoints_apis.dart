/// HTTP endpoint and API definition module.
///
/// This library provides classes for defining and managing remote API endpoints
/// in a structured, type-safe manner. It supports:
///
/// - API registration and lookup via [TomRemoteApis]
/// - API definition with endpoints via [TomApi]
/// - Endpoint configuration including HTTP methods, MIME types, and headers via [TomApiEndpoint]
///
/// ## Example
///
/// ```dart
/// final api = TomApi(
///   id: 'userApi',
///   name: 'User API',
///   uri: '/api/v1/users',
///   endpoints: [
///     TomApiEndpoint<UserResponse, UserRequest>(
///       id: 'createUser',
///       uri: '/create',
///       method: TomHttpMethod.post,
///     ),
///   ],
/// );
/// TomRemoteApis.registerApi(api);
/// ```
library;

import 'dart:convert';

import '../little_things/exception_base.dart';
import 'httpmethods.dart';
import 'mimetypes.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when an endpoint-related error occurs.
///
/// This includes errors such as:
/// - API not found
/// - Endpoint not found within an API
/// - API not set for an endpoint
class TomEndpointException extends TomException {
  TomEndpointException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

// =============================================================================
// CONTENT DISPOSITION
// =============================================================================

/// Constants for HTTP Content-Disposition header values.
///
/// Used to specify how content should be handled by the client,
/// particularly for file downloads.
class TomContentDisposition {
  /// Indicates that the content should be downloaded as an attachment.
  static String attachment = "attachment";
}

// =============================================================================
// REMOTE APIS REGISTRY
// =============================================================================

/// A singleton registry for managing remote API definitions.
///
/// Provides centralized storage and retrieval of [TomApi] instances
/// throughout the application.
///
/// ## Usage
///
/// ```dart
/// // Register an API
/// TomRemoteApis.registerApi(myApi);
///
/// // Retrieve by ID
/// final api = TomRemoteApis.getApiById('myApi');
///
/// // Or use the global accessor
/// final api = tomRemoteApis['myApi'];
/// ```
class TomRemoteApis {
  /// The singleton instance of the API registry.
  static final TomRemoteApis current = TomRemoteApis();

  /// Map of registered APIs, keyed by their unique ID.
  final Map<String, TomApi> apis = {};

  /// Creates a new empty API registry.
  TomRemoteApis();

  /// Registers an API with the global registry.
  ///
  /// The API will be stored using its [TomApi.id] as the key.
  static void registerApi(TomApi api) {
    current.apis[api.id] = api;
  }

  /// Retrieves an API by its unique identifier.
  ///
  /// Throws if the API is not found.
  static TomApi getApiById(String id) {
    return current.apis[id]!;
  }

  /// Gets an API by ID using bracket notation.
  ///
  /// Throws [TomEndpointException] if the API is not found.
  TomApi operator [](String apiId) {
    if (!apis.containsKey(apiId)) {
      throw TomEndpointException(
        "apis.api.not_found",
        "API with id '$apiId' not found.",
      );
    }
    return apis[apiId]!;
  }

  /// Registers an API using bracket notation.
  void operator []=(String apiId, TomApi api) {
    apis[apiId] = api;
  }

  /// Registers an API with this registry.
  void register(TomApi api) {
    apis[api.id] = api;
  }
}

/// Global accessor for the [TomRemoteApis] singleton.
TomRemoteApis get tomRemoteApis => TomRemoteApis.current;

// =============================================================================
// API DEFINITION
// =============================================================================

/// Represents a remote API with a collection of endpoints.
///
/// An API groups related endpoints under a common base URI and can define
/// shared settings like encoding and status code response types.
///
/// ## Example
///
/// ```dart
/// final userApi = TomApi(
///   id: 'users',
///   name: 'User Management API',
///   description: 'Handles user CRUD operations',
///   uri: '/api/v1/users',
///   endpoints: [
///     TomApiEndpoint<User, CreateUserRequest>(
///       id: 'create',
///       uri: '/create',
///       method: TomHttpMethod.post,
///     ),
///   ],
/// );
/// ```
class TomApi {
  /// Unique identifier for this API.
  final String id;

  /// Human-readable name for this API.
  final String? name;

  /// Description of what this API does.
  final String? description;

  /// Base URI path for all endpoints in this API.
  final String? uri;

  /// Default encoding for request bodies.
  final Encoding? requestEncoding;

  /// Default encoding for response bodies.
  final Encoding? responseEncoding;

  /// Maps HTTP status codes to response types for error handling.
  final Map<int, Type>? statusCodeResponseTypes;

  /// Map of endpoints, keyed by their unique ID.
  final Map<String, TomApiEndpoint> endpoints = {};

  /// Creates a new API with the given endpoints.
  ///
  /// All endpoints are automatically linked to this API.
  TomApi({
    required this.id,
    this.name,
    this.description,
    this.uri,
    required List<TomApiEndpoint> endpoints,
    this.requestEncoding,
    this.responseEncoding,
    this.statusCodeResponseTypes,
  }) {
    for (var endpoint in endpoints) {
      this.endpoints[endpoint.id] = endpoint;
      endpoint._api = this;
    }
  }

  /// Gets an endpoint by ID using bracket notation.
  ///
  /// Throws [TomEndpointException] if the endpoint is not found.
  TomApiEndpoint operator [](String endpointId) {
    TomApiEndpoint? endpoint = endpoints[endpointId];
    if (endpoint == null) {
      throw TomEndpointException(
        "apis.endpoint.not_found",
        "Endpoint with id '$endpointId' not found in API '$id'.",
      );
    }
    return endpoints[endpointId]!;
  }

  /// Registers an endpoint using bracket notation.
  void operator []=(String endpointId, TomApiEndpoint endpoint) {
    endpoints[endpointId] = endpoint;
    endpoint._api = this;
  }
}

// =============================================================================
// ENDPOINT DEFINITION
// =============================================================================

/// Represents a single API endpoint with type-safe request/response handling.
///
/// Generic parameters:
/// - [returnType]: The expected response type from the server
/// - [requestType]: The request body type to send to the server
///
/// ## Example
///
/// ```dart
/// final createUserEndpoint = TomApiEndpoint<UserResponse, CreateUserRequest>(
///   id: 'createUser',
///   uri: '/create',
///   method: TomHttpMethod.post,
///   consumes: TomMimeType.json,
///   produces: TomMimeType.json,
///   description: 'Creates a new user account',
/// );
/// ```
class TomApiEndpoint<returnType, requestType> {
  /// Reference to the parent API (set when endpoint is added to an API).
  TomApi? _api;

  /// Unique identifier for this endpoint within its parent API.
  final String id;

  /// Relative URI path for this endpoint (appended to API's base URI).
  final String? uri;

  /// Human-readable description of what this endpoint does.
  final String? description;

  /// List of allowed HTTP methods (for multi-method endpoints).
  final List<TomHttpMethod>? methods;

  /// Primary HTTP method for this endpoint.
  final TomHttpMethod method;

  /// MIME type that this endpoint accepts for request bodies.
  final TomMimeType consumes;

  /// MIME type that this endpoint produces in responses.
  final TomMimeType produces;

  /// Content-Disposition header value (e.g., for file downloads).
  final String? contentDisposition;

  /// Types that can be used as request bodies.
  late final List<Type> requestTypes;

  /// The response type for successful requests.
  late Type responseType = returnType;

  /// Field names for form-encoded requests.
  final List<String> formFields;

  /// Headers to include in responses (server-side).
  final Map<String, String> responseHeaders;

  /// Headers to include in requests (client-side).
  final Map<String, String> requestHeaders;

  /// Whether to automatically follow HTTP redirects.
  final bool followRedirects;

  /// Maximum number of redirects to follow.
  final int? maxRedirects;

  /// Whether to use persistent HTTP connections.
  final bool? persistentConnection;

  /// Whether to include Bearer token in Authorization header.
  final bool includeBearerAuthentication;

  /// Encoding for request bodies (overrides API-level setting).
  final Encoding? requestEncoding;

  /// Encoding for response bodies (overrides API-level setting).
  final Encoding? responseEncoding;

  /// Maps HTTP status codes to response types for error handling.
  final Map<int, Type>? statusCodeResponseTypes;

  /// Creates a new API endpoint with the specified configuration.
  TomApiEndpoint({
    required this.id,
    this.uri,
    this.description,
    this.methods,
    required this.method,
    this.consumes = TomMimeType.json,
    this.produces = TomMimeType.json,
    this.contentDisposition,
    this.formFields = const [],
    this.responseHeaders = const {},
    this.requestHeaders = const {},
    List<Type>? requestTypes,
    this.followRedirects = false,
    this.persistentConnection,
    this.includeBearerAuthentication = true,
    this.maxRedirects,
    this.requestEncoding,
    this.responseEncoding,
    this.statusCodeResponseTypes,
  }) {
    this.requestTypes = requestTypes ?? [requestType];
    if (returnType == dynamic) {
      responseType = Map<String, Object?>;
    }
  }

  /// Gets the parent API for this endpoint.
  ///
  /// Throws [TomEndpointException] if the endpoint hasn't been added to an API.
  TomApi get api {
    if (_api == null) {
      throw TomEndpointException(
        "apis.endpoint.api_not_set",
        "API not set for endpoint $id",
      );
    }
    return _api!;
  }
}
