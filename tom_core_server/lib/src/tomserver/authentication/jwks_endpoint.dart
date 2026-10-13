/// Publishes this deployment's token verification keys as a JSON Web Key Set.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'jwt_keys.dart';

/// The `GET /.well-known/jwks.json` endpoint (RFC 7517, at the path OpenID
/// Connect discovery points to).
///
/// Publishes the public half of every key a token of this deployment may be
/// verified with — the signing key and the retired keys still verifying — so
/// any JWT library, API gateway or other service can verify this deployment's
/// tokens without being given a key. Each key carries the `kid` its tokens
/// name, which is how a verifier that caches the set picks the right key
/// through a rotation.
///
/// Public by design: the set holds public keys only. A deployment signing with
/// HS256 has no public key, and the endpoint answers `404`.
@tomReflector
@tomService
abstract class TomJwksService {
  /// The JSON Web Key Set, as `application/jwk-set+json`, cacheable for five
  /// minutes; `404` under HS256.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.get],
    uri: "/.well-known/jwks.json",
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Response> jwks();
}

/// The default [TomJwksService]: answers from [TomJwtSigning.current].
@tomReflector
@tomComponent
class TomJwksServer implements TomJwksService {
  /// How long a verifier may cache the set. Short enough that a key added for
  /// a rotation is seen well before the old key stops verifying.
  static const Duration cacheFor = Duration(minutes: 5);

  @override
  Future<Response> jwks() async => responseFor(TomJwtSigning.current);

  /// The response publishing [signing]'s keys.
  static Response responseFor(TomJwtSigning signing) {
    final set = signing.jwks;
    if (set == null) {
      return Response.notFound(
        'This deployment signs with ${signing.algorithm.jwtName} and '
        'publishes no keys.',
        headers: {TomHeader.contentType: TomMimeType.plainText.toHeaderValue()},
      );
    }
    return Response.ok(
      jsonEncode(set),
      headers: {
        TomHeader.contentType: 'application/jwk-set+json',
        'cache-control': 'public, max-age=${cacheFor.inSeconds}',
      },
    );
  }
}
