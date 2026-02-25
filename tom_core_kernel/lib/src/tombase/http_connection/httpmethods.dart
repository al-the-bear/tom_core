/// HTTP method definitions module.
///
/// This library provides the [TomHttpMethod] class representing
/// standard HTTP methods (GET, POST, PUT, DELETE, etc.) with
/// metadata about whether each method accepts a request body.
///
/// ## Example
///
/// ```dart
/// final method = TomHttpMethod.post;
/// print(method.name);        // "POST"
/// print(method.acceptsBody); // true
///
/// // Lookup method by name
/// final get = TomHttpMethod.methods['GET'];
/// ```
library;

// =============================================================================
// HTTP METHOD DEFINITION
// =============================================================================

/// Represents an HTTP method with its characteristics.
///
/// Each method has a name and an indication of whether it typically
/// accepts a request body.
///
/// ## Predefined Methods
///
/// - [TomHttpMethod.get] - Retrieve a resource
/// - [TomHttpMethod.post] - Create a new resource
/// - [TomHttpMethod.put] - Replace a resource
/// - [TomHttpMethod.patch] - Partially update a resource
/// - [TomHttpMethod.delete] - Delete a resource
/// - [TomHttpMethod.head] - Same as GET but without response body
/// - [TomHttpMethod.connect] - Establish a tunnel
/// - [TomHttpMethod.trace] - Debug/testing (no body)
/// - [TomHttpMethod.all] - Wildcard for all methods
///
/// ## Example
///
/// ```dart
/// final endpoint = TomApiEndpoint(
///   id: 'createUser',
///   method: TomHttpMethod.post,
///   // ...
/// );
/// ```
class TomHttpMethod {
  /// Map of all HTTP methods keyed by their uppercase name.
  static Map<String, TomHttpMethod> methods = {
    "HEAD": head,
    "GET": get,
    "POST": post,
    "PUT": put,
    "PATCH": patch,
    "DELETE": delete,
    "CONNECT": connect,
    "TRACE": trace,
    "OPTIONS": options,
    "ALL": all,
  };

  /// The uppercase name of the HTTP method (e.g., "GET", "POST").
  final String name;

  /// Whether this HTTP method typically accepts a request body.
  ///
  /// Most methods accept a body (`true`), but [trace] does not.
  final bool acceptsBody;

  /// Creates an HTTP method with the given name.
  ///
  /// - [name]: The HTTP method name (e.g., "GET", "POST")
  /// - [acceptsBody]: Whether the method accepts a body (default: `true`)
  const TomHttpMethod(this.name, [this.acceptsBody = true]);

  /// HTTP HEAD method - retrieves headers only.
  static const TomHttpMethod head = TomHttpMethod("HEAD");

  /// HTTP GET method - retrieves a resource.
  static const TomHttpMethod get = TomHttpMethod("GET");

  /// HTTP POST method - creates a new resource.
  static const TomHttpMethod post = TomHttpMethod("POST");

  /// HTTP PUT method - replaces a resource entirely.
  static const TomHttpMethod put = TomHttpMethod("PUT");

  /// HTTP PATCH method - partially updates a resource.
  static const TomHttpMethod patch = TomHttpMethod("PATCH");

  /// HTTP DELETE method - removes a resource.
  static const TomHttpMethod delete = TomHttpMethod("DELETE");

  /// HTTP CONNECT method - establishes a tunnel.
  static const TomHttpMethod connect = TomHttpMethod("CONNECT");

  /// HTTP TRACE method - echoes the request for debugging.
  ///
  /// Does not accept a request body.
  static const TomHttpMethod trace = TomHttpMethod("TRACE", false);

  /// HTTP OPTIONS method - describes communication options.
  static const TomHttpMethod options = TomHttpMethod("OPTIONS");
  
  /// Wildcard method matching all HTTP methods.
  ///
  /// Useful for routes that should respond to any method.
  static const TomHttpMethod all = TomHttpMethod("ALL", true);

  @override
  String toString() => "$name/$acceptsBody";
}
