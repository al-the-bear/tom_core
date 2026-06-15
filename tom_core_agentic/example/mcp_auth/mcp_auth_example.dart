// Runnable demo of the generic MCP bearer-auth contract.
//
// It plays both sides of an MCP `initialize` handshake without any real
// transport: a client puts a token in the JSON-RPC `_meta` map under the
// well-known key, and a tiny server reads it back, authenticates it through a
// BearerTokenAuthenticator, and translates a rejection into the shared
// JSON-RPC error code. The principal type is a plain String, standing in for
// the framework TomPrincipal a real server would bind.
//
// Run with:
//   dart run --enable-asserts example/mcp_auth/mcp_auth_example.dart

import 'package:tom_core_agentic/tom_core_agentic.dart';

void main() {
  // A server binds one authenticator over its principal type. Here the
  // principal is a String username; a framework server would bind
  // BearerTokenAuthenticator<TomPrincipal>.
  const authenticator = _StaticAuthenticator({'tok-alice': 'alice'});
  final server = _MiniMcpServer(authenticator);

  // 1) A valid token in _meta resolves to a principal.
  final ok = server.initialize(_clientMeta('tok-alice'));
  print('valid token   -> $ok');
  assert(ok.principal == 'alice');
  assert(ok.rpcError == null);

  // 2) An unknown token is refused with the shared JSON-RPC error code; the
  //    diagnostic message never crosses the wire.
  final rejected = server.initialize(_clientMeta('tok-mallory'));
  print('unknown token -> $rejected');
  assert(rejected.principal == null);
  assert(rejected.rpcError == bearerAuthRpcErrorCode);

  // 3) A missing _meta token is also refused (reason: missing).
  final missing = server.initialize(const <String, Object?>{});
  print('missing token -> $missing');
  assert(missing.rpcError == bearerAuthRpcErrorCode);

  print('\nmcp_auth demo completed.');
}

/// Builds the JSON-RPC `_meta` map a client sends at `initialize`, carrying the
/// bearer token under the agreed namespaced key.
Map<String, Object?> _clientMeta(String token) => <String, Object?>{
      bearerTokenMetaKey: token,
    };

/// A trivial static-token authenticator binding a `String` principal.
final class _StaticAuthenticator implements BearerTokenAuthenticator<String> {
  final Map<String, String> _tokens;
  const _StaticAuthenticator(this._tokens);

  @override
  String authenticate(String token) {
    if (token.isEmpty) {
      throw const BearerAuthFailure(
        BearerAuthFailureReason.missing,
        'Empty bearer token.',
      );
    }
    final principal = _tokens[token];
    if (principal == null) {
      throw const BearerAuthFailure(
        BearerAuthFailureReason.rejected,
        'Unknown token.',
      );
    }
    return principal;
  }
}

/// The result a server returns from `initialize`: either an authenticated
/// principal or a JSON-RPC error code (the diagnostic stays server-side).
class _InitializeResult {
  final String? principal;
  final int? rpcError;
  const _InitializeResult.ok(this.principal) : rpcError = null;
  const _InitializeResult.refused(this.rpcError) : principal = null;

  @override
  String toString() => principal != null
      ? 'principal=$principal'
      : 'refused(rpcError=$rpcError)';
}

/// A minimal MCP server that gates `initialize` on the bearer-auth contract.
class _MiniMcpServer {
  final BearerTokenAuthenticator<String> _authenticator;
  const _MiniMcpServer(this._authenticator);

  _InitializeResult initialize(Map<String, Object?> meta) {
    final token = (meta[bearerTokenMetaKey] as String?) ?? '';
    try {
      return _InitializeResult.ok(_authenticator.authenticate(token));
    } on BearerAuthFailure catch (failure) {
      // Only the error code goes on the wire; the message is logged locally.
      print('  [server log] refused: $failure');
      return const _InitializeResult.refused(bearerAuthRpcErrorCode);
    }
  }
}
