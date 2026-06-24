# HTTP Connection Module

The HTTP Connection module provides a comprehensive infrastructure for making HTTP requests from client applications to remote servers. It offers type-safe API definitions, configurable HTTP clients, and automatic serialization/deserialization.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Architecture](#architecture)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

This module consists of several interconnected components:

| File | Description |
|------|-------------|
| `endpoints_apis.dart` | API and endpoint definitions with type-safe configuration |
| `headers.dart` | Common HTTP header name constants |
| `httpmethods.dart` | HTTP method definitions (GET, POST, PUT, etc.) |
| `mimetypes.dart` | MIME type definitions and file extension mapping |
| `remote_context.dart` | Server connection configuration |
| `server_connection.dart` | HTTP client infrastructure and request execution |

## Quick Start

### 1. Configure the Remote Context

First, set up where your application should send requests:

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Set the remote server context (do this once at app startup)
  TomClientRemoteContext.setCurrent(
    TomClientRemoteContext(
      Uri.parse('https://api.example.com'),
    ),
  );
}
```

### 2. Define Your API

Create type-safe API definitions:

```dart
final userApi = TomApi(
  id: 'users',
  name: 'User Management API',
  uri: '/api/v1/users',
  endpoints: [
    TomApiEndpoint<UserResponse, CreateUserRequest>(
      id: 'create',
      uri: '/create',
      method: TomHttpMethod.post,
      consumes: TomMimeType.json,
      produces: TomMimeType.json,
    ),
    TomApiEndpoint<UserResponse, void>(
      id: 'getById',
      uri: '/{id}',
      method: TomHttpMethod.get,
    ),
  ],
);

// Register the API globally
TomRemoteApis.registerApi(userApi);
```

### 3. Execute Requests

Use `TomServerEndpoint` for type-safe request execution:

```dart
// Create the endpoint executor
final endpoint = TomServerEndpoint.createApiServerEndpoint<
  CreateUserRequest,
  UserResponse
>(userApi['create']);

// Execute the request
final request = CreateUserRequest(name: 'John Doe', email: 'john@example.com');
final (response, error) = await endpoint.send(request);

if (error?.hasError ?? false) {
  print('Error: ${error!.statusCode} - ${error.reasonPhrase}');
} else {
  print('Created user: ${response.id}');
}
```

## Core Components

### TomRemoteApis

A singleton registry for managing all API definitions in your application.

```dart
// Register an API
TomRemoteApis.registerApi(myApi);

// Retrieve by ID
final api = TomRemoteApis.getApiById('myApi');

// Or use bracket notation with global accessor
final endpoint = tomRemoteApis['myApi']['endpoint'];
```

### TomApi

Represents a collection of related endpoints under a common base URI.

```dart
final api = TomApi(
  id: 'orders',
  name: 'Order API',
  uri: '/api/v1/orders',
  requestEncoding: utf8,
  responseEncoding: utf8,
  endpoints: [...],
);
```

### TomApiEndpoint

Defines a single API endpoint with full configuration:

```dart
TomApiEndpoint<OrderResponse, CreateOrderRequest>(
  id: 'createOrder',
  uri: '/create',
  method: TomHttpMethod.post,
  consumes: TomMimeType.json,
  produces: TomMimeType.json,
  includeBearerAuthentication: true,
  followRedirects: false,
  requestHeaders: {'X-Custom-Header': 'value'},
)
```

### TomHttpMethod

Predefined HTTP methods:

| Method | Description |
|--------|-------------|
| `TomHttpMethod.get` | Retrieve a resource |
| `TomHttpMethod.post` | Create a new resource |
| `TomHttpMethod.put` | Replace a resource |
| `TomHttpMethod.patch` | Partially update a resource |
| `TomHttpMethod.delete` | Delete a resource |
| `TomHttpMethod.head` | Retrieve headers only |

### TomMimeType

Common MIME types for request/response content:

```dart
TomMimeType.json        // application/json
TomMimeType.html        // text/html
TomMimeType.plainText   // text/plain
TomMimeType.xml         // application/xml
TomMimeType.pdf         // application/pdf
TomMimeType.urlEncoded  // application/x-www-form-urlencoded
TomMimeType.multipartFormData  // multipart/form-data
```

### TomServerChannel

Manages HTTP client connections with pooling:

```dart
final channel = TomServerChannel('api.example.com', 443);

// Prepare and execute a call
final call = channel.prepareCall(specs);
call.send(load);
final response = await call.readAsString(utf8);

// Close when done
channel.close();
```

### TomServerCall

Low-level HTTP request handling with abort support:

```dart
final call = TomServerCall(client, specs);

// Send the request
call.send(TomServerCallLoad(
  stringBody: jsonEncode(data),
  contentType: 'application/json',
));

// Read the response
final bytes = await call.read();
final text = await call.readAsString(utf8);

// Or abort if needed
call.abort();
```

## Usage Examples

### Making a GET Request

```dart
final channel = TomServerChannel('api.example.com', 443);
final specs = TomServerCallSpecs(
  'GET',
  Uri.parse('https://api.example.com/users/123'),
  headers: {'Accept': 'application/json'},
);

final call = channel.prepareCall(specs);
call.send(TomServerCallLoad());
final response = await call.readAsString(utf8);
channel.close();
```

### Making a POST Request with JSON Body

```dart
final specs = TomServerCallSpecs(
  'POST',
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
);

final call = TomServerCall(client, specs);
call.send(TomServerCallLoad(
  stringBody: '{"name": "John", "email": "john@example.com"}',
  contentType: 'application/json',
  encoding: utf8,
));

final statusCode = await call.getResponseStatusCode();
final body = await call.readAsString(utf8);
```

### Using Form Data

```dart
final call = TomServerCall(client, specs);
call.send(TomServerCallLoad(
  bodyFields: {
    'username': 'john',
    'password': 'secret',
  },
));
```

### Handling Errors

```dart
final (response, error) = await endpoint.send(request);

if (error != null && error.hasError) {
  switch (error.statusCode) {
    case 400:
      print('Bad request: ${error.response}');
      break;
    case 401:
      print('Unauthorized - token expired?');
      break;
    case 404:
      print('Resource not found');
      break;
    case 500:
      print('Server error: ${error.reasonPhrase}');
      break;
    default:
      print('Error ${error.statusCode}: ${error.response}');
  }
}
```

### Custom HTTP Client Factory

```dart
class MyCustomClientFactory extends TomHttpClientFactory {
  @override
  Client getClient() {
    // Return your custom client (e.g., with interceptors)
    return MyCustomClient();
  }
}

// Set globally
TomHttpClientFactory.setGlobalHttpClientFactory(MyCustomClientFactory());
```

### Separate Authentication Server

```dart
TomClientRemoteContext.setCurrent(
  TomClientRemoteContext(
    Uri.parse('https://api.example.com'),      // Main API
    Uri.parse('https://auth.example.com'),     // Auth server
  ),
);
```

## Best Practices

### 1. Initialize Early

Set up `TomClientRemoteContext` as early as possible in your application lifecycle, typically in `main()`.

### 2. Register APIs Once

Register all your API definitions during app initialization:

```dart
void initializeApis() {
  TomRemoteApis.registerApi(userApi);
  TomRemoteApis.registerApi(orderApi);
  TomRemoteApis.registerApi(productApi);
}
```

### 3. Handle All Error Cases

Always check for errors after API calls:

```dart
final (response, error) = await endpoint.send(request);
if (error?.hasError ?? false) {
  // Handle error appropriately
  return;
}
// Process successful response
```

### 4. Close Channels When Done

If you create `TomServerChannel` instances manually, close them when finished:

```dart
final channel = TomServerChannel('api.example.com', 443);
try {
  // Use channel...
} finally {
  channel.close();
}
```

### 5. Use Type-Safe Endpoints

Prefer `TomServerEndpoint.createApiServerEndpoint` over manual HTTP calls for type safety and automatic serialization.

### 6. Configure Timeouts

Use appropriate timeouts for your use case to prevent hanging requests.

### 7. Secure Authentication

Bearer tokens are automatically included by default. Disable with `includeBearerAuthentication: false` for public endpoints:

```dart
TomApiEndpoint<PublicData, void>(
  id: 'publicEndpoint',
  method: TomHttpMethod.get,
  includeBearerAuthentication: false,  // No auth needed
)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                             │
├─────────────────────────────────────────────────────────────┤
│  TomRemoteApis                                               │
│  ├── TomApi (users)                                          │
│  │   ├── TomApiEndpoint (create)                            │
│  │   └── TomApiEndpoint (getById)                           │
│  └── TomApi (orders)                                         │
│      └── TomApiEndpoint (list)                              │
├─────────────────────────────────────────────────────────────┤
│  TomServerEndpoint<Request, Response>                        │
│  └── Type-safe request/response handling                     │
├─────────────────────────────────────────────────────────────┤
│  TomServerChannel                                            │
│  └── TomHttpClientFactory                                    │
├─────────────────────────────────────────────────────────────┤
│  TomServerCall                                               │
│  └── Low-level HTTP operations                               │
├─────────────────────────────────────────────────────────────┤
│  TomClientRemoteContext                                      │
│  └── Server URI configuration                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Dependencies

This module depends on:

- **Little Things Module**: `TomException` base class for error handling
- **Security Module**: `TomBearerAuthentication` for authentication
- **Reflection Module**: `TomReflectionInfo` for JSON serialization support
- **Runtime Module**: Platform utilities for HTTP client creation
