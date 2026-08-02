// Generic MCP transport-auth contract.
//
// Promoted out of `tom_brain_memory`'s MCP server. The bearer-token
// gate that every MCP server in the framework needs is a transport
// concern with nothing domain-specific in it, so it lives here
// alongside the rest of the shared, `tom_basics`-only agentic
// infrastructure. Future thinking / planning / creation / procedure MCP
// servers reuse this one contract rather than each re-deriving a
// failure taxonomy and an error code.
//
// What stays domain-specific (and therefore does *not* live here): the
// concrete authenticators that turn a token into a framework principal
// (`TomPrincipal`). Those bind `tom_core_kernel` types and stay in their
// owning package. This contract keeps the principal type a parameter
// ([BearerTokenAuthenticator]'s `P`) so it can be reused without dragging
// the kernel into `tom_core_agentic` — which is `tom_basics`-only by
// design.

/// The JSON-RPC `_meta` key under which a client places the bearer
/// token at `initialize` time when the server is configured with a
/// [BearerTokenAuthenticator].
///
/// The MCP wire protocol does not carry an `Authorization` header on
/// stdio / UNIX-socket transports; the only request-level extensibility
/// point at the `initialize` boundary is the `_meta` map. This well-known
/// key is the agreed slot. It is namespaced so it does not collide with
/// the MCP standard `_meta.progressToken` reservation or with other
/// `_meta` consumers a host might layer on.
const bearerTokenMetaKey = 'tomBrainBearerToken';

/// JSON-RPC error code returned when a bearer authentication fails during
/// the MCP `initialize` handshake.
///
/// Sits in the JSON-RPC 2.0 server-defined implementation range
/// (-32099 … -32000); named so the value is never a bare literal at the
/// throw site, and shared so every MCP server in the framework refuses
/// with the same code.
const bearerAuthRpcErrorCode = -32001;

/// Validates a bearer token presented during the MCP `initialize`
/// handshake and resolves it to a principal of type [P].
///
/// Implementations are responsible for **authentication only** —
/// converting a token string into a principal or rejecting it.
/// Per-tool authorisation (role / entitlement checks against the
/// principal) is the consuming server's job.
///
/// The principal type is a parameter so this contract stays free of any
/// particular auth model: a server that authenticates to a
/// framework `TomPrincipal` binds `BearerTokenAuthenticator<TomPrincipal>`;
/// a test or a different host can bind any other identity type.
///
/// Implementations must be synchronous: the MCP `initialize` handshake
/// is on the hot path and must not make an LLM / network call at this
/// layer.
abstract interface class BearerTokenAuthenticator<P extends Object> {
  /// Validates [token] and returns the resulting principal.
  ///
  /// Throws [BearerAuthFailure] if [token] is missing, malformed, or
  /// otherwise rejected.
  P authenticate(String token);
}

/// Raised when a bearer token cannot be accepted.
///
/// Carries a stable [reason] tag — useful for telemetry and tests —
/// plus a human-readable [message]. A server translates this into a
/// JSON-RPC error ([bearerAuthRpcErrorCode]) during `initialize`; the
/// underlying [message] is **not** leaked to the client unmodified,
/// because token-introspection error details can be a side channel for
/// token-guessing attacks. Only the [reason] tag belongs on the wire.
class BearerAuthFailure implements Exception {
  /// Stable enum-like tag for the failure category.
  final BearerAuthFailureReason reason;

  /// Human-readable diagnostic, intended for server-side logs only.
  final String message;

  const BearerAuthFailure(this.reason, this.message);

  @override
  String toString() => 'BearerAuthFailure(${reason.name}): $message';
}

/// Categories of bearer-token authentication failure.
///
/// The set is closed by design — adding a new category is a version
/// bump, not a silent extension.
enum BearerAuthFailureReason {
  /// No `_meta` bearer-token field was present on the `initialize`
  /// request when the server requires one.
  missing,

  /// The token string was present but could not be parsed (malformed
  /// JWT, unknown format, …).
  malformed,

  /// The token parsed but failed authentication (guest principal,
  /// expired, unknown subject, …).
  rejected,
}
