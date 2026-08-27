// Unit tests for the transport-neutral bearer-token contract.
//
// These tests are kernel-free *and* transport-free — nothing here names
// MCP, HTTP, or any other edge, which is the point: the contract these
// cases pin is the one an HTTP edge reuses as-is. The contract is
// parameterised over the principal type, so a String stands in for the
// framework `TomPrincipal` the memory package binds. The kernel-coupled
// concrete authenticators (Jwt / Static) and their conformance tests
// stay in tom_brain_memory; the MCP wire constants are covered by
// `mcp_auth_test.dart`.
//
// The import below deliberately names the contract file rather than the
// package barrel. Going through the barrel would pull `bearerTokenMetaKey`
// and `bearerAuthRpcErrorCode` into scope too, and this file would keep
// compiling if the taxonomy were ever folded back in beside them — which
// is the state the split exists to prevent. Importing the leaf makes the
// separation a compile-time fact instead of a claim in a comment.

import 'package:tom_core_agentic/src/bearer_auth/bearer_auth_contract.dart';
import 'package:test/test.dart';

/// A trivial in-test authenticator binding a `String` principal, used to
/// exercise the generic [BearerTokenAuthenticator] contract without
/// pulling any auth model into the test.
final class _FakeStringAuthenticator
    implements BearerTokenAuthenticator<String> {
  final Map<String, String> _tokens;
  const _FakeStringAuthenticator(this._tokens);

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

void main() {
  group('BearerAuthFailureReason', () {
    test('is a closed set of exactly three categories', () {
      expect(BearerAuthFailureReason.values, hasLength(3));
      expect(
        BearerAuthFailureReason.values,
        containsAll(<BearerAuthFailureReason>[
          BearerAuthFailureReason.missing,
          BearerAuthFailureReason.malformed,
          BearerAuthFailureReason.rejected,
        ]),
      );
    });
  });

  group('BearerAuthFailure', () {
    test('toString carries the reason tag and the diagnostic message', () {
      const failure = BearerAuthFailure(
        BearerAuthFailureReason.rejected,
        'sample diagnostic',
      );
      expect(failure.toString(), contains('rejected'));
      expect(failure.toString(), contains('sample diagnostic'));
    });

    test('is an Exception with stable reason + message fields', () {
      const failure = BearerAuthFailure(
        BearerAuthFailureReason.malformed,
        'bad jwt',
      );
      expect(failure, isA<Exception>());
      expect(failure.reason, equals(BearerAuthFailureReason.malformed));
      expect(failure.message, equals('bad jwt'));
    });
  });

  group('BearerTokenAuthenticator<P> generic contract', () {
    test('resolves a known token to its principal of type P', () {
      const auth = _FakeStringAuthenticator({'tok': 'alice'});
      expect(auth.authenticate('tok'), equals('alice'));
    });

    test('throws missing for an empty token', () {
      const auth = _FakeStringAuthenticator({'tok': 'alice'});
      expect(
        () => auth.authenticate(''),
        throwsA(
          isA<BearerAuthFailure>().having(
            (f) => f.reason,
            'reason',
            BearerAuthFailureReason.missing,
          ),
        ),
      );
    });

    test('throws rejected for an unknown token', () {
      const auth = _FakeStringAuthenticator({'tok': 'alice'});
      expect(
        () => auth.authenticate('nope'),
        throwsA(
          isA<BearerAuthFailure>().having(
            (f) => f.reason,
            'reason',
            BearerAuthFailureReason.rejected,
          ),
        ),
      );
    });

    test('a BearerTokenAuthenticator<P> is a subtype of the raw interface', () {
      // Covariance: a <String> authenticator is usable where a
      // dynamic-principal authenticator is expected. This is what lets a
      // server hold BearerTokenAuthenticator<TomPrincipal> while generic
      // plumbing accepts the raw interface.
      const auth = _FakeStringAuthenticator({'tok': 'alice'});
      expect(auth, isA<BearerTokenAuthenticator<String>>());
      expect(auth, isA<BearerTokenAuthenticator<Object>>());
    });
  });
}
