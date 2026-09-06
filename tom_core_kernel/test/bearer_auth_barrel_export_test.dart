/// The guard that keeps the bearer-authentication API's own types nameable
/// from the package barrel.
///
/// `TomBearerAuthentication` is a client-side API: an application logs in,
/// stores the token pair, and holds on to what it got back.
/// `clientJwtToken` and `clientAuthorizationJwtToken` are `TomClientJwtToken?`,
/// and `convertTokenPayloadToPrincipal` takes two of them — so a consumer that
/// cannot name `TomClientJwtToken` can call the getters but cannot declare a
/// field, a parameter or a local for the result. That is not a theoretical
/// loss: `tom_uam_client` declares exactly such a field.
///
/// The type is declared in `tom_crypto`, not here, and it reaches consumers
/// only because the barrel re-exports that package **in full**. That is the
/// fragility worth guarding. Nothing about the kernel's own source says the
/// type has to stay reachable, so narrowing the blanket re-export to a `show`
/// list — a reasonable cleanup, and one the package has already made elsewhere —
/// would drop `TomClientJwtToken` out of the public surface while every file
/// under `lib/` kept compiling, because they all import `tom_crypto` directly.
/// The break is only visible from outside.
///
/// So the check is compile-time rather than an assertion: this file imports
/// **nothing but the barrel** and names the type in each position the public
/// API uses it, so losing the re-export does not fail a test, it stops this
/// file compiling.
///
/// The first test exists to keep that property true. The guard's entire
/// strength is its import list, and an import list is exactly the kind of thing
/// a later edit widens without meaning anything by it: add one
/// `package:tom_crypto/...` import and this file still passes while proving
/// nothing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// This file's own path, read back to check how it imports.
const _ownPath = 'test/bearer_auth_barrel_export_test.dart';

/// The only import this file may have into the package under test.
const _barrelImport = "import 'package:tom_core_kernel/tom_core_kernel.dart';";

void main() {
  group('bearer-auth token types are part of the public surface', () {
    test('this file reaches the package only through the barrel', () {
      final source = File(_ownPath);
      expect(
        source.existsSync(),
        isTrue,
        reason:
            'the guard reads its own source; if this file moved, $_ownPath '
            'must move with it',
      );

      // Every import that could bring `TomClientJwtToken` into scope — the
      // barrel, or `tom_crypto` directly, which is the shortcut that would
      // hollow this guard out.
      final reachingImports = [
        for (final line in source.readAsLinesSync())
          if (RegExp(r"^\s*(import|export)\s+'").hasMatch(line) &&
              (line.contains('tom_core_kernel') || line.contains('tom_crypto')))
            line.trim(),
      ];

      // Non-vacuity: if this came back empty the check below would pass while
      // testing nothing at all.
      expect(reachingImports, isNotEmpty);
      expect(
        reachingImports,
        equals([_barrelImport]),
        reason:
            'the compile-time guard below only proves the barrel carries '
            'TomClientJwtToken while the barrel is the only way this file can '
            'see it',
      );
    });

    test('the two getters can be assigned to a named type', () {
      // Writing the type is the assertion. Both are null here because nothing
      // has logged in, which is the point: the declaration has to compile
      // whatever the value is.
      final TomClientJwtToken? authentication =
          TomBearerAuthentication.clientJwtToken;
      final TomClientJwtToken? authorization =
          TomBearerAuthentication.clientAuthorizationJwtToken;

      expect(authentication, isNull);
      expect(authorization, isNull);
    });

    test('a token round-trips through the API a consumer can write', () {
      // The end-to-end shape a client actually performs: hand the pair of
      // encoded tokens in, then hold the parsed ones in named variables and
      // pass them back to the public converter. Every type in that sequence
      // has to be nameable for the sequence to be writable at all.
      TomBearerAuthentication.setTokens(_token, _token, false);
      addTearDown(TomBearerAuthentication.clearTokens);

      final TomClientJwtToken? parsed = TomBearerAuthentication.clientJwtToken;
      expect(parsed, isNotNull);
      expect(parsed!.payload, isNotNull);

      final TomPrincipal principal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(parsed);
      final TomUser user = principal.user;
      expect(user.username, equals('Ada'));
      expect(user.id, equals(42));
    });
  });
}

/// An unsigned JWT carrying the smallest payload the converter accepts.
///
/// Built as a literal rather than signed here because the guard is about which
/// *types* cross the barrel, not about cryptography — `setTokens` is called
/// with `decrypt: false` so no key material is needed.
final String _token = _encode(
  '{"alg":"none","typ":"JWT"}',
  '{"userId":42,"username":"Ada"}',
);

String _encode(String header, String payload) {
  String seg(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  return '${seg(header)}.${seg(payload)}.';
}
