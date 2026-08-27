// Unit tests for the MCP-specific bearer-auth wire constants.
//
// Only the two constants live here. The failure taxonomy and the
// authenticator interface they are used with are transport-neutral and
// are covered by `bearer_auth_test.dart`, which imports them without
// this file's constants ever entering scope.

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:test/test.dart';

void main() {
  group('mcp_auth contract constants', () {
    test('bearerTokenMetaKey is the agreed namespaced _meta slot', () {
      expect(bearerTokenMetaKey, equals('tomBrainBearerToken'));
    });

    test('bearerAuthRpcErrorCode sits in the JSON-RPC server-defined range', () {
      expect(bearerAuthRpcErrorCode, equals(-32001));
      expect(bearerAuthRpcErrorCode, inInclusiveRange(-32099, -32000));
    });
  });
}
