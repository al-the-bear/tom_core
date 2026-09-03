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
      expect(bearerTokenMetaKey, equals('tomBearerToken'));
    });

    test('bearerTokenMetaKey is scoped to the framework, not to a package', () {
      // The key is the only part of this module that a client and a
      // server must agree on out of band, so it is the only part whose
      // name cannot be corrected by the compiler later. It read
      // `tomBrainBearerToken` while the constant lived in `tom_brain`,
      // which would have had a planning or procedure server presenting
      // its token under a key named for a package it does not depend on.
      expect(bearerTokenMetaKey, startsWith('tom'));
      for (final package in const ['Brain', 'Memory', 'Access', 'Agentic']) {
        expect(
          bearerTokenMetaKey,
          isNot(contains(package)),
          reason: 'the shared wire key must not name one framework package',
        );
      }
    });

    test(
      'bearerAuthRpcErrorCode sits in the JSON-RPC server-defined range',
      () {
        expect(bearerAuthRpcErrorCode, equals(-32001));
        expect(bearerAuthRpcErrorCode, inInclusiveRange(-32099, -32000));
      },
    );
  });
}
