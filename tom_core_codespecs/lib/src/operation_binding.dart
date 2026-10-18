/// Where a [TomBindingParameter] finds the request member it supplies.
///
/// The four places an HTTP request carries a value. `body` names a member read
/// from the decoded request body as a whole field, so a binding can say that
/// `amount` comes from the body while `accountId` comes from the path.
enum TomBindingSource {
  /// A `{name}` capture in the binding's [TomOperationBinding.path].
  path,

  /// A query-string parameter.
  query,

  /// A field of the decoded request body.
  body,

  /// A request header.
  header,
}

/// The error shape a [TomOperationBinding] renders a failed operation in.
///
/// One operation has **one** error contract — its CE-ER error codes — and a
/// binding chooses only how that contract is written onto the wire. A second
/// binding of the same operation may therefore speak a standard error format
/// its clients expect without the operation knowing it is bound twice.
enum TomBindingErrorFormat {
  /// The CE-ER `Result` envelope of `codespecs_mapping.md` §7 — the shape the
  /// operation's primary binding speaks.
  resultEnvelope,

  /// RFC 9457 problem details (`application/problem+json`).
  problemJson,

  /// The SCIM error response of RFC 7644 §3.12.
  scim,

  /// The OAuth 2.0 error response of RFC 6749 §5.2.
  oauth,
}

/// One wire parameter of a [TomOperationBinding]: where it is read from, and
/// which request member of the operation it supplies.
///
/// The two names differ by design. [name] is what the *wire* calls the value —
/// fixed by whatever protocol the binding speaks (`startIndex`, `userName`,
/// `grant_type`) — while [member] is what the *operation* calls it, fixed by
/// the specification. Keeping both is what lets a second binding serve an
/// already-named operation under another protocol's vocabulary without
/// renaming the operation's request type.
class TomBindingParameter {
  /// The parameter's name on the wire.
  final String name;

  /// Where on the request the parameter is read from.
  final TomBindingSource source;

  /// The operation's request member this parameter supplies.
  final String member;

  /// Creates a binding parameter.
  const TomBindingParameter(
    this.name, {
    required this.source,
    required this.member,
  });
}

/// A second HTTP shape for an operation that already has a name.
///
/// **Why this is a gap (`codespecs_mapping.md` §5.30).** `tom_core_server` can
/// declare an arbitrary HTTP shape per endpoint — `@TomEndpoint` and
/// `TomApiEndpoint` (`tom_core_kernel`) carry a method, a path and the request
/// type — but an endpoint *is* its shape: there is no way to bind an
/// already-named operation a **second** time. Serving one operation under a
/// second shape (a SCIM `/Users` resource, an OAuth token endpoint, a
/// versioned REST path beside the CE-API one) therefore means a second
/// hand-written handler that re-implements the dispatch the first one already
/// does, and the two drift.
///
/// The proper home is a generic protocol capability in `tom_core` that binds
/// named operations — requested in the `tom_core` quest todo "Generic protocol
/// bindings over named operations". Until it ships, this class is the holder:
/// a CodeSpec's `@CsOperationBinding` (`tom_code_specs`, CE-API) marks a
/// top-level `const TomOperationBinding` in the **server** project, and Phase 6
/// registers it with whatever routing the project has
/// (`codespecs_derivation_contract.md` §3.4.5). When `tom_core` ships the
/// capability this class moves there — or is replaced by it — and the CodeSpecs
/// derivation follows.
///
/// **A const value class, and dependency-free.** A binding is authored
/// declaration, not runtime state, so every field is final and the constructor
/// is `const`: it is a compile-time constant the server project can name. The
/// method is a `String` rather than `tom_core_kernel`'s `TomHttpMethod`, which
/// is its runtime type, because this package takes no dependency
/// (`gap_class_inventory_test.dart` pins that); the CodeSpecs validator holds
/// the value to the closed set [methods].
class TomOperationBinding {
  /// The HTTP methods a binding may declare — the closed set the CodeSpecs
  /// validator holds [method] to.
  static const Set<String> methods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};

  /// The name of the operation this binding serves, verbatim.
  ///
  /// The operation's own name, as its CE-API declaration spells it — the
  /// binding adds a shape and never a second name.
  final String operation;

  /// The HTTP method, one of [methods].
  final String method;

  /// The path template after [versionPrefix], with `{name}` captures.
  ///
  /// Each capture is a [TomBindingSource.path] parameter; [pathCaptures] lists
  /// them in order.
  final String path;

  /// The prefix the path is served under, such as `/scim/v2`. Empty by default.
  final String versionPrefix;

  /// How each wire parameter maps onto the operation's request members.
  final List<TomBindingParameter> parameters;

  /// The status code a successful call answers with.
  final int successStatus;

  /// Response headers the binding sets on success, by name.
  final List<String> responseHeaders;

  /// The request media type the binding accepts, or `null` when the request
  /// carries no body.
  final String? consumes;

  /// The response media type.
  final String produces;

  /// The shape a failed call's CE-ER error is written in.
  final TomBindingErrorFormat errorFormat;

  /// Creates a binding of [operation].
  const TomOperationBinding(
    this.operation, {
    required this.method,
    required this.path,
    this.versionPrefix = '',
    this.parameters = const [],
    this.successStatus = 200,
    this.responseHeaders = const [],
    this.consumes,
    this.produces = 'application/json',
    this.errorFormat = TomBindingErrorFormat.resultEnvelope,
  });

  /// The full route the binding is served under: [versionPrefix] then [path].
  String get route => '$versionPrefix$path';

  /// The names inside the `{...}` captures of [path], in order.
  ///
  /// Empty when the path captures nothing.
  List<String> get pathCaptures => [
    for (final match in _capture.allMatches(path)) match.group(1)!,
  ];

  static final RegExp _capture = RegExp(r'\{([^{}]+)\}');
}
