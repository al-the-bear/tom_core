// MCP-specific wire constants for bearer-token authentication.
//
// Two values, and both of them are MCP facts: where a token sits on an
// MCP `initialize` request, and which JSON-RPC code an MCP server
// refuses with. Every MCP server in the framework shares them so that
// clients need one well-known slot and one well-known code rather than
// one pair per server.
//
// The failure taxonomy these constants are used *with* is not an MCP
// fact and does not live here — see `bearer_auth/bearer_auth_contract.dart`
// for [BearerTokenAuthenticator], [BearerAuthFailure] and
// [BearerAuthFailureReason], which an HTTP or WebSocket edge reuses
// without taking on anything below.

import '../bearer_auth/bearer_auth_contract.dart';

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

/// JSON-RPC error code an MCP server returns when a
/// [BearerAuthFailure] is raised during the `initialize` handshake.
///
/// Sits in the JSON-RPC 2.0 server-defined implementation range
/// (-32099 … -32000); named so the value is never a bare literal at the
/// throw site, and shared so every MCP server in the framework refuses
/// with the same code. It is the MCP half of the translation — an HTTP
/// edge maps the same [BearerAuthFailureReason] onto a 401 instead,
/// which is why the code is here and the taxonomy is not.
const bearerAuthRpcErrorCode = -32001;
