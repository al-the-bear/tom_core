import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// Tests for the server module: the per-request log state
/// ([TomRequestLogInfo]), the credential reader ([extractAuthentication]) and
/// the [TomCredentialOutcome] that tells its answers apart, the pipeline
/// middlewares ([contextSetupMiddleware], [tomLoggingMiddleware],
/// [tomDefaultAuthenticationMiddleware], [noopHandler]), the default
/// [TomServer.errorHandler] mapping closure, and [TomServer.start] itself.
///
/// `start()` is driven here against real sockets on the loopback interface —
/// it binds, hands back the [HttpServer], and the handle is what lets a test
/// close it again. The two properties worth naming:
///
///  * **the deployment is logged in before the socket accepts.** The stub auth
///    server in this file holds the login open, and the assertion is made while
///    it is held: a connection to the port `start()` is about to bind is
///    refused. A server that bound first would answer it, and would be serving
///    requests with user grants uncapped — the one direction in which getting
///    the order wrong grants access rather than denying it. The *source* is
///    also read for the same ordering, by `test/api_reference_coverage_test.dart`
///    in the group `start() logs the deployment in before it binds`, because a
///    rewrite that kept both calls and swapped them compiles and passes
///    everything else.
///  * **a configured deployment that cannot log in binds nothing.** The port is
///    still free afterwards, which is a stronger statement than "the future
///    rejected": it says `serve` was never reached.
///
/// What no suite in this package covers is a server against real databases and
/// a real auth server. That is the sample integration scripts in
/// `tom_core_samples` — `core_server_sample/tool/run_integration.sh` and
/// `advanced_client_core/tool/run_cross_tier_integration.sh` — and they are a
/// *sample's* scripts rather than an integration suite of this package's.
/// Saying so is the point: this package has no integration directory, so a
/// header implying one sends the reader looking for something that does not
/// exist.
///
/// Named by group and by script rather than by line number on purpose: these
/// pointers have to survive the files they point into being edited.

/// A JWT signed with the configuration this deployment has installed.
String _signed(Map<String, dynamic> claims) =>
    TomServerJwtToken(claims).getJWT(TomJwtSigning.current.issuer);

/// [token] with its public claims edited by [edit] and its original signature
/// left in place — what a client can produce with three lines and a base64
/// decoder, and what a decode-only server could not tell from the real thing.
String _withEditedPayload(
  String token,
  void Function(Map<String, dynamic> claims) edit,
) {
  String pad(String s) => s.padRight((s.length + 3) & ~3, '=');
  final parts = token.split('.');
  final claims =
      jsonDecode(utf8.decode(base64Url.decode(pad(parts[1]))))
          as Map<String, dynamic>;
  edit(claims);
  final edited = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  return '${parts[0]}.$edited.${parts[2]}';
}

/// Every [length]-character window of [value].
///
/// A leak does not have to be the whole credential to be a leak: a decoder
/// that quotes the first line of what it choked on writes a slice, and a slice
/// of a signature is still material nobody should be able to read out of an
/// access log.
Iterable<String> _slicesOf(String value, int length) sync* {
  for (var i = 0; i + length <= value.length; i++) {
    yield value.substring(i, i + length);
  }
}

Request _get([Map<String, String>? headers]) =>
    Request('GET', Uri.parse('http://localhost/resource'), headers: headers);

/// A concrete configuration that skips the generated reflection so a [TomServer]
/// can be constructed without codegen — its merged values are simply discarded.
/// Mirrors `configuration_test.dart`'s `_CapturingConfig`.
class _NoopConfig extends TomBaseServerConfiguration {
  _NoopConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

/// A [_NoopConfig] that names its application, so [tomAppId] has something to
/// report. Named in the constructor body, which is where a real server names
/// itself.
class _AppIdConfig extends TomBaseServerConfiguration {
  _AppIdConfig(String id) : super([]) {
    appId = id;
  }
  @override
  void setValues(Map<String, Object?> values) {}
}

/// A [TomLogOutput] that keeps every message instead of printing it, so a test
/// can assert on what the library actually wrote.
class _CapturingLogOutput extends TomLogOutput {
  final List<String> messages = [];
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => messages.add(convertToString(message));
}

void main() {
  group('TomRequestLogInfo', () {
    test('defaults to should-be-logged, not-yet-logged', () {
      final info = TomRequestLogInfo();
      expect(info.shouldBeLogged, isTrue);
      expect(info.hasBeenLogged, isFalse);
    });

    test('exposes the context key', () {
      expect(TomRequestLogInfo.contextName, 'loggingInfo');
    });

    test('toString reflects both flags and the route', () {
      final info = TomRequestLogInfo()..hasBeenLogged = true;
      expect(
        info.toString(),
        'TomRequestLogInfo should=true has=true route=null',
      );
      info.route = '/tasks/<id>';
      expect(
        info.toString(),
        'TomRequestLogInfo should=true has=true route=/tasks/<id>',
      );
    });
  });

  group('extractAuthentication', () {
    test('returns (null, null) when no Authorization header is present', () {
      final (principal, token, _) = extractAuthentication(_get());
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('returns (null, null) for a non-bearer scheme', () {
      final (principal, token, _) = extractAuthentication(
        _get({'authorization': 'Basic dXNlcjpwYXNz'}),
      );
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('returns (null, null) for a malformed bearer token', () {
      final (principal, token, _) = extractAuthentication(
        _get({'authorization': 'Bearer not-a-jwt'}),
      );
      expect(principal, isNull);
      expect(token, isNull);
    });

    test('accepts a token this deployment signed', () {
      final (principal, token, _) = extractAuthentication(
        _get({
          'authorization': 'Bearer ${_signed({'userId': 'u'})}',
        }),
      );
      expect(token, isNotNull);
      expect(token!.payload!['userId'], 'u');
      expect(principal, isNotNull);
    });

    test('refuses a token whose payload was edited after issue', () {
      // The whole point. The claims are re-encoded and the original signature
      // is carried over unchanged — which is exactly what a client can do,
      // because the public section is plain base64 and nothing about decoding
      // objects to it.
      final forged = _withEditedPayload(
        _signed({'userId': 'u', 'role': 'user'}),
        (claims) => claims['role'] = 'admin',
      );
      final (principal, token, _) = extractAuthentication(
        _get({'authorization': 'Bearer $forged'}),
      );
      expect(token, isNull, reason: 'an edited payload must not decode at all');
      expect(principal, isNull);
    });

    test('refuses a token signed with somebody else\'s key', () {
      // A well-formed, correctly-signed token from a server this one does not
      // share a `jwtSharedSecretKey` with. Before the signature was checked,
      // "well-formed" was the whole test.
      final foreign = jwt
          .JWT({'userId': 'u'}, issuer: 'other-server')
          .sign(jwt.SecretKey('a-different-secret'));
      final (principal, token, _) = extractAuthentication(
        _get({'authorization': 'Bearer $foreign'}),
      );
      expect(token, isNull);
      expect(principal, isNull);
    });

    test('accepts a token this deployment signed that has expired', () {
      // Deliberate, and the opposite of what a signature check might be
      // expected to do. An expired token is still *ours*, and it is the only
      // thing left identifying who is asking — a refresh or re-login endpoint
      // is reached with exactly it. Expiry is answered by the principal
      // reader, `TomBearerAuthentication.convertTokenPayloadToPrincipal`, which
      // builds no principal from a dead token; the token itself survives. See
      // the middleware groups below, which assert both halves with a warm
      // cache and a cold one.
      final expired = TomServerJwtToken(
        {'userId': 'u'},
        expiresIn: const Duration(hours: -1),
      ).getJWT(TomJwtSigning.current.issuer);
      final (_, token, _) = extractAuthentication(
        _get({'authorization': 'Bearer $expired'}),
      );
      expect(token, isNotNull);
    });
  });

  // Four requests arrive without credentials and answer `(null, null)` alike:
  // one that sent no header, one that sent a scheme this server does not
  // speak, one whose token would not verify, and one whose verified token
  // yielded no principal. Those are an anonymous caller, a misconfigured
  // client, a rotated signing key and a malformed claim set — four different
  // things to do about them, and until the outcome element existed the
  // module's own trace line read the same for all four.
  group('extractAuthentication says why a request is anonymous', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() => tomLog.logOutput = installed);

    TomCredentialOutcome outcomeOf(String? header) => extractAuthentication(
      _get(header == null ? null : {'authorization': header}),
    ).$3;

    String written() => captured.messages.join('\n');

    test(
      'the three reachable ways of arriving anonymous are three answers',
      () {
        expect(outcomeOf(null), TomCredentialOutcome.noCredentials);
        expect(
          outcomeOf('Basic dXNlcjpwYXNz'),
          TomCredentialOutcome.unsupportedScheme,
        );
        expect(
          outcomeOf('Bearer not-a-jwt'),
          TomCredentialOutcome.unreadableToken,
        );
      },
    );

    test('a token this deployment signed reports authenticated', () {
      expect(
        outcomeOf('Bearer ${_signed({'userId': 'u'})}'),
        TomCredentialOutcome.authenticated,
      );
    });

    test('the scheme is matched case-insensitively, as RFC 7235 requires', () {
      // The scheme is a case-insensitive token in the grammar, so a client
      // that sends `bearer` is conformant. Matching it case-sensitively made
      // every one of its requests anonymous, and wrote nothing anywhere.
      final token = _signed({'userId': 'u'});
      expect(outcomeOf('bearer $token'), TomCredentialOutcome.authenticated);
      expect(outcomeOf('BEARER $token'), TomCredentialOutcome.authenticated);
    });

    test('an ignored header is named by its scheme and by nothing else', () {
      outcomeOf('Basic dXNlcjpwYXNz');
      expect(written(), contains('scheme "Basic"'));
      expect(
        written(),
        isNot(contains('dXNlcjpwYXNz')),
        reason: 'what follows the scheme is the credential',
      );
    });

    test('a header with no scheme is reported without being quoted', () {
      // There is no scheme to name here, and the obvious fallback — print the
      // first word — would print the credential, because the whole header is
      // one.
      outcomeOf('dXNlcjpwYXNzd29yZA==');
      expect(written(), contains('names no scheme'));
      expect(written(), isNot(contains('dXNlcjpwYXNzd29yZA')));
    });

    test('a scheme long enough to flood the log is cut short', () {
      // Client-supplied, and a client can supply kilobytes of it.
      outcomeOf('${'S' * 4000} credentials');
      expect(captured.messages, hasLength(1));
      expect(captured.messages.single.length, lessThan(200));
    });

    test('an absent header is not worth a line', () {
      outcomeOf(null);
      expect(
        captured.messages,
        isEmpty,
        reason: 'anonymous traffic is ordinary; a warning per request is noise',
      );
    });
  });

  // A token this server cannot read is very often a live credential somewhere
  // else — the commonest reason it is unreadable is that it was minted for a
  // different deployment — and an access log is the least protected place it
  // could end up. The route by which one gets there is short:
  // `dart_jsonwebtoken` wraps anything it did not anticipate in an exception
  // whose message is the underlying one's `toString()`, and a base64
  // `FormatException` prints the input it choked on. Interpolating a decoder's
  // message whole therefore writes a slice of the presented credential, which
  // is why the reason is read a line at a time and why this battery exists
  // rather than a comment saying to be careful.
  group('a refused credential is never written to the log', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() => tomLog.logOutput = installed);

    test('for every shape of bearer token the module refuses', () {
      final signed = _signed({'userId': 'u'});
      final refused = <String, String>{
        'not a jwt at all': 'not-a-jwt',
        'a jwt whose payload is not base64': 'eyJhbGciOiJIUzI1NiJ9.!!!!.sig',
        'a signature truncated by one character': signed.substring(
          0,
          signed.length - 1,
        ),
        'a payload edited after issue': _withEditedPayload(
          signed,
          (claims) => claims['role'] = 'admin',
        ),
        'a token signed with another key': jwt
            .JWT({'userId': 'u'}, issuer: 'other')
            .sign(jwt.SecretKey('a-different-secret')),
        'a long string that is not a token': 'Z' * 400,
      };

      for (final entry in refused.entries) {
        captured.messages.clear();
        final (principal, token, outcome) = extractAuthentication(
          _get({'authorization': 'Bearer ${entry.value}'}),
        );
        expect(principal, isNull);
        expect(token, isNull);
        expect(outcome, TomCredentialOutcome.unreadableToken);

        final written = captured.messages.join('\n');
        expect(
          written,
          isNotEmpty,
          reason:
              'the refusal of ${entry.key} still has to be recorded — a '
              'credential refused in silence is the one nobody can investigate',
        );
        for (final slice in _slicesOf(entry.value, 8)) {
          expect(
            written,
            isNot(contains(slice)),
            reason:
                'the log line for ${entry.key} quotes the credential '
                '(found "$slice" in: $written)',
          );
        }
      }
    });
  });

  group('verifyBearerToken', () {
    test('returns the decoded token for a signature it can check', () {
      final verified = verifyBearerToken(_signed({'userId': 'u'}));
      expect(verified, isNotNull);
      expect(verified!.payload!['userId'], 'u');
    });

    test('returns null rather than throwing for every rejection', () {
      // The caller's contract is that an unusable token means *no
      // credentials*; throwing would turn a hostile request into a 500 and
      // hand the sender a way to tell a rejected signature from an accepted
      // one.
      expect(verifyBearerToken('not-a-jwt'), isNull);
      expect(verifyBearerToken(''), isNull);
      expect(
        verifyBearerToken(
          jwt.JWT({'userId': 'u'}).sign(jwt.SecretKey('wrong')),
        ),
        isNull,
      );
    });
  });

  group('noopHandler', () {
    test('ignores the request and returns the fixed status code', () async {
      final response = await noopHandler('t', 204)(_get());
      expect(response.statusCode, 204);
    });
  });

  group('contextSetupMiddleware', () {
    test('merges entries into the request context', () async {
      Object? seen;
      final handler = contextSetupMiddleware('seed', {'k': 'v'})((req) {
        seen = req.context['k'];
        return Response.ok('ok');
      });
      await handler(_get());
      expect(seen, 'v');
    });

    test(
      'passes the request through unchanged when no context is given',
      () async {
        final handler = contextSetupMiddleware('noop')(
          (req) => Response.ok('ok'),
        );
        expect((await handler(_get())).statusCode, 200);
      },
    );
  });

  group('tomRequestLogInfoMiddleware', () {
    test('seeds a separate TomRequestLogInfo into every request', () async {
      final seen = <TomRequestLogInfo>[];
      final handler = tomRequestLogInfoMiddleware()((req) {
        seen.add(
          req.context[TomRequestLogInfo.contextName] as TomRequestLogInfo,
        );
        return Response.ok('ok');
      });
      await handler(_get());
      await handler(_get());
      expect(seen, hasLength(2));
      expect(identical(seen[0], seen[1]), isFalse);
    });

    test('every request through one pipeline gets its access line', () async {
      // One instance shared by every request would be marked logged by the
      // first, and the access log would fall silent after one line.
      _AppIdConfig('');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final handler = const Pipeline()
          .addMiddleware(tomRequestLogInfoMiddleware())
          .addMiddleware(tomLoggingMiddleware())
          .addHandler((req) => Response.ok('ok'));
      await handler(_get());
      await handler(_get());

      expect(output.messages.where((m) => m.startsWith('HTTP/')), hasLength(2));
    });
  });

  group('tomLoggingMiddleware', () {
    test('emits at most once and marks the log info', () async {
      final info = TomRequestLogInfo();
      final request = _get().change(
        context: {TomRequestLogInfo.contextName: info},
      );
      final handler = tomLoggingMiddleware()((req) => Response.ok('ok'));
      await handler(request);
      expect(info.hasBeenLogged, isTrue);
    });

    test('does not re-log a request already marked as logged', () async {
      final info = TomRequestLogInfo()..hasBeenLogged = true;
      final request = _get().change(
        context: {TomRequestLogInfo.contextName: info},
      );
      final handler = tomLoggingMiddleware()((req) => Response.ok('ok'));
      // Should pass through without throwing and leave the flag set.
      expect((await handler(request)).statusCode, 200);
      expect(info.hasBeenLogged, isTrue);
    });

    test('emits nothing when shouldBeLogged is false', () async {
      // This is the opt-out an endpoint buys with `logRequests: false`: the
      // pipeline copies that flag onto TomRequestLogInfo.shouldBeLogged, and
      // TomHealthService uses it so an orchestrator probing /health every few
      // seconds does not bury the log. Asserted through hasBeenLogged rather
      // than by capturing output, because the middleware only sets that flag on
      // the branch that also emits -- so the flag staying false *is* the
      // suppression, and the two cannot drift apart.
      //
      // This is the property that shelf's own logRequests cannot honour: it
      // never sees the request context, so it would log all of these. It is
      // why the alternative documented on
      // TomBaseServerConfiguration.loggingMiddleware is not the default.
      final info = TomRequestLogInfo()..shouldBeLogged = false;
      final request = _get().change(
        context: {TomRequestLogInfo.contextName: info},
      );
      final handler = tomLoggingMiddleware()((req) => Response.ok('ok'));
      expect((await handler(request)).statusCode, 200);
      expect(info.hasBeenLogged, isFalse);
    });

    test('the access line names the application', () async {
      // This is the one line the library emits for every served request, and
      // until now it identified the request but not the process that served it.
      // That gap is why `tomAppId` exists, and this is the library reading it:
      // the advanced sample runs three servers side by side, two of them with
      // `isolateLogging = false`, so without the app id their access lines are
      // indistinguishable once collected anywhere in common.
      //
      // Captured rather than asserted through a flag -- unlike the suppression
      // tests above, the claim here *is* about the text.
      // Constructing it is what publishes it: the base constructor registers
      // the configuration, and `tomAppId` resolves `appId` through it.
      _AppIdConfig('billing');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final request = _get().change(
        context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
      );
      await tomLoggingMiddleware()((req) => Response.ok('ok'))(request);

      expect(output.messages.single, contains('[billing] '));
    });

    test('an unnamed application leaves no empty bracket on the line', () async {
      // The other half of the conditional prefix. A deployment that never sets
      // `appId` -- which is every one that has not needed the distinction --
      // must get the line it always got, not one opening `[] `. An empty
      // bracket reads as a *named* application whose name failed to render,
      // which is a worse report than no bracket at all.
      //
      // Found by mutation: making the prefix unconditional left the suite
      // green, the only assertion on the text being that it contains the name.
      _AppIdConfig('');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);
      tomLog.logOutput = output;

      final request = _get().change(
        context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
      );
      await tomLoggingMiddleware()((req) => Response.ok('ok'))(request);

      expect(output.messages.single, isNot(contains('[]')));
      expect(output.messages.single, startsWith('HTTP/'));
    });
  });

  group('tomDefaultAuthenticationMiddleware', () {
    test('publishes a TomRequestId into the request zone', () async {
      TomRequestId? zoneId;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneId = getFromCurrentZone<TomRequestId>();
        return Response.ok('ok');
      });
      final response = await handler(_get());
      expect(response.statusCode, 200);
      expect(zoneId, isNotNull);
      expect(zoneId!.uuid, isNotEmpty);
    });

    test('resolves no principal when there are no credentials', () async {
      TomPrincipal? zonePrincipal;
      var sawPrincipalKey = false;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zonePrincipal = getFromCurrentZone<TomPrincipal>();
        sawPrincipalKey = true;
        return Response.ok('ok');
      });
      await handler(_get());
      expect(sawPrincipalKey, isTrue);
      expect(zonePrincipal, isNull);
    });

    test(
      'merges the optional context into the request seen by the handler',
      () async {
        Object? seen;
        final handler = tomDefaultAuthenticationMiddleware('auth', {'k': 'v'})((
          req,
        ) {
          seen = req.context['k'];
          return Response.ok('ok');
        });
        await handler(_get());
        expect(seen, 'v');
      },
    );

    test('publishes the original request into the request zone', () async {
      final request = _get();
      Request? zoneRequest;
      // With no context override the inner handler receives the same request,
      // and the zone publishes that identical instance.
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneRequest = getFromCurrentZone<Request>();
        return Response.ok('ok');
      });
      await handler(request);
      expect(identical(zoneRequest, request), isTrue);
    });

    test('publishes the parsed bearer token into the request zone', () async {
      final jwt = TomServerJwtToken({
        'userId': 'u',
      }, expiresIn: const Duration(hours: 2)).getJWT('tom');
      TomClientJwtToken? zoneToken;
      final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
        zoneToken = getFromCurrentZone<TomClientJwtToken>();
        return Response.ok('ok');
      });
      await handler(_get({'authorization': 'Bearer $jwt'}));
      expect(zoneToken, isNotNull);
    });

    // An entry the cache has aged out. The two tests below drive the same
    // request; the first pins that the pipeline still answers it, the second
    // pins *what* the request is answered as.
    //
    // The token is minted already expired because the entry's lifetime *is* the
    // token's — `TomAuthorizationCache` reads its expiry from the token's
    // `validUntil` claim and refuses to invent one — so "the cached entry has
    // expired" and "this token has expired" are one fact, not two. A fixture
    // pairing a dead entry with a live token would be testing a state the cache
    // cannot reach.
    group('when the principal\'s grants were revoked', () {
      // A revocation raised on any node reaches this one through the
      // invalidation channel; from then on a token issued before it must not
      // produce the principal it was issued with — neither one cached for it,
      // nor the one its own claims still describe.
      test(
        'a live token issued before the revocation yields no principal',
        () async {
          final token = TomClientJwtToken(
            TomServerJwtToken({
              'userId': 'u',
              'username': 'alice',
            }, expiresIn: const Duration(hours: 1)).getJWT('tom'),
          );
          TomAuthorizationCache.revokeLocally(
            'alice',
            DateTime.now().add(const Duration(seconds: 1)),
          );
          addTearDown(TomAuthorizationCache.instance.dispose);

          TomPrincipal? zonePrincipal;
          var handlerRan = false;
          final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
            handlerRan = true;
            zonePrincipal = getFromCurrentZone<TomPrincipal>();
            return Response.ok('ok');
          });
          final response = await handler(
            _get({'authorization': 'Bearer ${token.tokenString}'}),
          );
          expect(handlerRan, isTrue, reason: 'served, unauthenticated');
          expect(response.statusCode, 200);
          expect(zonePrincipal, isNull);
        },
      );
    });

    group('when the cached principal has expired', () {
      /// The bearer header for a token that expired an hour ago, with a
      /// principal cached under it. `username` is set so that
      /// [extractAuthentication] derives an *authenticated* principal from the
      /// token itself — which is precisely the principal that must not be used.
      Future<Map<String, String>> expiredCredentials() async {
        final token = TomClientJwtToken(
          TomServerJwtToken({
            'userId': 'u',
            'username': 'alice',
          }, expiresIn: const Duration(hours: -1)).getJWT('tom'),
        );
        await TomAuthorizationCache.storePrincipal(
          token,
          TomPrincipal(user: TomUser(username: 'alice'), authenticated: true),
        );
        addTearDown(TomAuthorizationCache.instance.dispose);
        return {'authorization': 'Bearer ${token.tokenString}'};
      }

      test('the request is still served, not failed', () async {
        var handlerRan = false;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          handlerRan = true;
          return Response.ok('ok');
        });
        // The expiry must not escape as an exception: the outer error
        // middleware would turn it into a generic HTTP 500 — an answer no
        // client can act on, and one a cold cache would not produce for this
        // same request, so the cache's mere presence would decide it.
        final response = await handler(_get(await expiredCredentials()));
        expect(handlerRan, isTrue);
        expect(response.statusCode, 200);
      });

      test('the token-derived principal is not used in its place', () async {
        TomPrincipal? zonePrincipal;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          zonePrincipal = getFromCurrentZone<TomPrincipal>();
          return Response.ok('ok');
        });
        await handler(_get(await expiredCredentials()));
        // The expired session resolves to *no* principal — the same answer a
        // request bearing no credentials gets. A protected endpoint refuses
        // this request through the ordinary access-denied path.
        expect(zonePrincipal, isNull);
      });

      test('the token itself still reaches the request zone', () async {
        TomClientJwtToken? zoneToken;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          zoneToken = getFromCurrentZone<TomClientJwtToken>();
          return Response.ok('ok');
        });
        await handler(_get(await expiredCredentials()));
        // Dropping the principal does not drop the credentials: a refresh or
        // re-login endpoint is reached with exactly this token, and it is the
        // only thing left identifying who is asking.
        expect(zoneToken, isNotNull);
      });
    });

    // The same expired token with nothing cached under it. Which answer a dead
    // token gets must not depend on cache occupancy — an entry evicted by the
    // sweep, or a process that never cached the token, is the common case, and
    // here the token-derived principal is the only one on offer. The lifetime
    // is therefore enforced where every principal is built, not by the cache.
    group('when nothing is cached for an expired token', () {
      Map<String, String> expiredCredentials() => {
        'authorization':
            'Bearer ${TomServerJwtToken({'userId': 'u', 'username': 'alice'}, expiresIn: const Duration(hours: -1)).getJWT('tom')}',
      };

      test('the credential reader establishes no principal', () {
        final (principal, token, outcome) = extractAuthentication(
          _get(expiredCredentials()),
        );
        expect(principal, isNull);
        expect(token, isNotNull);
        expect(outcome, TomCredentialOutcome.noPrincipal);
      });

      test('the request is served with no principal and its token', () async {
        TomPrincipal? zonePrincipal;
        TomClientJwtToken? zoneToken;
        var handlerRan = false;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          handlerRan = true;
          zonePrincipal = getFromCurrentZone<TomPrincipal>();
          zoneToken = getFromCurrentZone<TomClientJwtToken>();
          return Response.ok('ok');
        });
        final response = await handler(_get(expiredCredentials()));
        expect(handlerRan, isTrue);
        expect(response.statusCode, 200);
        expect(zonePrincipal, isNull);
        expect(zoneToken, isNotNull);
      });

      test('a live token still establishes its principal', () async {
        TomPrincipal? zonePrincipal;
        final handler = tomDefaultAuthenticationMiddleware('auth')((req) {
          zonePrincipal = getFromCurrentZone<TomPrincipal>();
          return Response.ok('ok');
        });
        await handler(
          _get({
            'authorization':
                'Bearer ${TomServerJwtToken({'userId': 'u', 'username': 'alice'}).getJWT('tom')}',
          }),
        );
        expect(zonePrincipal?.username, 'alice');
        expect(zonePrincipal?.authenticated, isTrue);
      });
    });
  });

  // The TomServer constructor is the socket-free half of the class: it wires the
  // error, authentication-error, and logging handlers from the configuration,
  // falling back to the defaults. A no-op configuration subclass lets us build a
  // server without codegen reflection and inspect the wiring directly.
  group('TomServer constructor wiring', () {
    setUp(() {
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
    });

    test('honours a configuration-supplied errorHandler', () {
      Response? custom(Request r, Object e, StackTrace s) => null;
      final config = _NoopConfig()..errorHandler = custom;
      final server = TomServer(config);
      expect(identical(server.errorHandler, custom), isTrue);
    });

    test('honours a configuration-supplied authenticationErrorHandler', () {
      Response? custom(Request r, Object e, StackTrace s) => null;
      final config = _NoopConfig()..authenticationErrorHandler = custom;
      final server = TomServer(config);
      expect(identical(server.authenticationErrorHandler, custom), isTrue);
    });

    test('authenticationErrorHandler falls back to errorHandler when neither is'
        ' configured', () {
      final server = TomServer(_NoopConfig());
      // Neither handler configured -> the auth-error handler is the very same
      // closure as the (default) main error handler.
      expect(
        identical(server.authenticationErrorHandler, server.errorHandler),
        isTrue,
      );
    });

    test('honours a configuration-supplied loggingMiddleware', () {
      final custom = tomLoggingMiddleware();
      final config = _NoopConfig()..loggingMiddleware = custom;
      final server = TomServer(config);
      expect(identical(server.loggingMiddleware, custom), isTrue);
    });
  });

  // The TLS material a deployment gets when it configures none is a real
  // self-signed pair whose private key is committed to this repository. It
  // stays -- a development machine has to be able to speak HTTPS without a
  // certificate authority -- so the boot says so, every time, rather than
  // serving a published key in silence.
  group('the development TLS pair announces itself', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() => tomLog.logOutput = installed);

    String warning() =>
        captured.messages.where((m) => m.contains('TLS')).join('\n');

    test('a configuration that overrides neither half is warned about', () {
      TomServer(_NoopConfig()).warnOnDevelopmentTlsMaterial();
      // The three things an operator needs: that it is happening, that the key
      // is public, and which fields to set.
      expect(warning(), contains('development'));
      expect(warning(), contains('published'));
      expect(warning(), contains('certificateChain'));
      expect(warning(), contains('privateKey'));
    });

    // The half that matters most, told apart from the other: a deployment that
    // supplied its own chain and left the key is still serving a published key.
    test('overriding only the chain is still warned about', () {
      final config = _NoopConfig()..certificateChain = '-----BEGIN CERT-----';
      TomServer(config).warnOnDevelopmentTlsMaterial();
      expect(warning(), contains('private key'));
    });

    // And the reverse, which is a different fault with the same remedy: the
    // pair no longer matches, so the bind fails -- worth saying before it does.
    test('overriding only the key is still warned about', () {
      final config = _NoopConfig()..privateKey = '-----BEGIN KEY-----';
      TomServer(config).warnOnDevelopmentTlsMaterial();
      expect(warning(), contains('certificate chain'));
    });

    test('a configuration that overrides both is silent', () {
      final config = _NoopConfig()
        ..certificateChain = '-----BEGIN CERT-----'
        ..privateKey = '-----BEGIN KEY-----';
      TomServer(config).warnOnDevelopmentTlsMaterial();
      expect(captured.messages, isEmpty);
    });

    // Nothing is served over TLS, so there is nothing to warn about -- and a
    // warning here would be the kind that teaches an operator to ignore them.
    test('a plaintext server is silent, default pair or not', () {
      TomServer(_NoopConfig()..noSsl = true).warnOnDevelopmentTlsMaterial();
      expect(captured.messages, isEmpty);
    });

    test('the condition is readable on the configuration itself', () {
      expect(_NoopConfig().usesDevelopmentTlsMaterial(), isTrue);
      final overridden = _NoopConfig()
        ..certificateChain = 'x'
        ..privateKey = 'y';
      expect(overridden.usesDevelopmentTlsMaterial(), isFalse);
    });

    // `start()` is fire-and-forget and binds a socket, so nothing in this
    // package calls it (see the header). The warning is a public method for
    // that reason -- and the source is what says the boot still calls it,
    // which is the same technique the self-login ordering is pinned with.
    test('start() calls it, before it builds the context', () {
      final lines = File(
        'lib/src/tomserver/server/server.dart',
      ).readAsLinesSync();
      // The *call*, not the declaration: `…Material();` ends in a semicolon
      // where `void …Material() {` does not. Searching for the bare name would
      // match the method itself, and the guard would pass with nothing calling
      // it -- which is exactly what the first draft of this test did.
      final call = lines.indexWhere(
        (l) => l.contains('warnOnDevelopmentTlsMaterial();'),
      );
      final context = lines.indexWhere((l) => l.contains('SecurityContext()'));
      expect(
        call,
        greaterThanOrEqualTo(0),
        reason: 'start() no longer announces the development TLS pair',
      );
      expect(
        context,
        greaterThan(call),
        reason: 'the warning must precede the context it is about',
      );
    });
  });

  // Resource-key enforcement is off by default (see TomResourceKeyProtection),
  // and the cost of that default is a production server whose grants bind
  // nothing. The boot names it outside development and test, and only there.
  group('unenforced resource keys announce themselves', () {
    late _CapturingLogOutput captured;
    late TomLogOutput installed;

    setUp(() {
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
      TomResourceKeyProtection.restoreDefaults();
      TomRuntime.reset();
      installed = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
    });

    tearDown(() {
      tomLog.logOutput = installed;
      TomResourceKeyProtection.restoreDefaults();
      TomRuntime.reset();
    });

    void selectEnvironment({required bool development}) {
      TomRuntime.addEnvironment(
        TomEnvironment(
          development ? 'dev' : 'prod',
          isDevelopment: development,
          isTest: development,
        ),
      );
      TomRuntime.setCurrentEnvironment(development ? 'dev' : 'prod', '');
    }

    String warning() => captured.messages
        .where((m) => m.contains('tom.protection.resourceKeys'))
        .join('\n');

    test('a production server with the default is warned about', () {
      selectEnvironment(development: false);
      TomServer(_NoopConfig()).warnOnUnenforcedResourceKeys();
      // What is happening, and the setting that changes it.
      expect(warning(), contains('not enforced'));
      expect(warning(), contains('tom.protection.resourceKeys=true'));
    });

    test('a server that declared no environment is warned about', () {
      // Silence about the environment is read strictly, as the JWT signing
      // check reads it: not having said "development" is not development.
      TomServer(_NoopConfig()).warnOnUnenforcedResourceKeys();
      expect(warning(), isNotEmpty);
    });

    test('a development server is silent', () {
      selectEnvironment(development: true);
      TomServer(_NoopConfig()).warnOnUnenforcedResourceKeys();
      expect(captured.messages, isEmpty);
    });

    test('a server that enforces resource keys is silent', () {
      selectEnvironment(development: false);
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      TomServer(_NoopConfig()).warnOnUnenforcedResourceKeys();
      expect(captured.messages, isEmpty);
    });

    test('start() calls it before the socket is bound', () {
      final lines = File(
        'lib/src/tomserver/server/server.dart',
      ).readAsLinesSync();
      final call = lines.indexWhere(
        (l) => l.contains('warnOnUnenforcedResourceKeys();'),
      );
      final bind = lines.indexWhere((l) => l.contains('await serve('));
      expect(
        call,
        greaterThanOrEqualTo(0),
        reason: 'start() no longer announces unenforced resource keys',
      );
      expect(bind, greaterThan(call));
    });
  });

  // Pins the default error-mapping contract documented on TomServer.errorHandler
  // every thrown error becomes an HTTP-500 JSON response carrying
  // `x-tom-error: true` and an `errorType`; a TomException contributes
  // `errorKey`/`uuid`/`autoLog`/`requestUuid`; a TomServerException additionally
  // contributes `clientThrow`. No behaviour change — characterization only.
  group('TomServer.errorHandler', () {
    late TomServer server;

    setUp(() {
      // Isolate from any provider left installed by another suite.
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
      server = TomServer(_NoopConfig());
    });

    /// Drives the default handler and decodes its response.
    Future<
      ({int status, Map<String, String> headers, Map<String, dynamic> body})
    >
    map(Object error) async {
      final response = server.errorHandler(_get(), error, StackTrace.current);
      expect(
        response,
        isNotNull,
        reason: 'the default handler always responds',
      );
      final body =
          jsonDecode(await response!.readAsString()) as Map<String, dynamic>;
      return (
        status: response.statusCode,
        headers: response.headers,
        body: body,
      );
    }

    test('a plain error maps to HTTP 500 with only errorType', () async {
      final result = await map(const FormatException('boom'));
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorType'], 'FormatException');
      // A non-Tom error contributes none of the Tom-specific fields.
      expect(result.body.containsKey('errorKey'), isFalse);
      expect(result.body.containsKey('clientThrow'), isFalse);
    });

    test('a TomException adds errorKey/uuid/autoLog/requestUuid', () async {
      final error = TomException('user.fetch.not_found', 'no such user');
      final result = await map(error);
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorType'], 'TomException');
      expect(result.body['errorKey'], 'user.fetch.not_found');
      expect(result.body['uuid'], error.uuid);
      expect(result.body['autoLog'], isFalse);
      expect(result.body['requestUuid'], isNull);
      // Not a server exception -> no clientThrow.
      expect(result.body.containsKey('clientThrow'), isFalse);
    });

    test('a TomServerException additionally adds clientThrow', () async {
      final error = TomServerException(
        'db.fail',
        'query failed',
        clientThrow: false,
      );
      final result = await map(error);
      expect(result.status, 500);
      expect(result.headers['x-tom-error'], 'true');
      expect(result.body['errorKey'], 'db.fail');
      // The server-exception arm carries the masking flag through.
      expect(result.body['clientThrow'], isFalse);
    });

    test('clientThrow defaults to true and is reported as such', () async {
      final result = await map(TomServerException('db.fail', 'query failed'));
      expect(result.body['clientThrow'], isTrue);
    });

    test('the envelope declares the media type of the body it sends', () async {
      // This handler is the framework's error shape — the one every other
      // JSON-envelope handler in the package is written to match. A body a
      // client is expected to decode by `errorKey` has to say it is JSON, or
      // the client has only the `x-tom-error` header to guess from and an
      // intermediary has nothing at all.
      final result = await map(TomException('db.fail', 'query failed'));
      expect(
        TomMimeType.parse(result.headers[TomHeader.contentType]!),
        TomMimeType.json,
      );
    });
  });

  group('a request rejected during authentication is still logged', () {
    // The access log's whole point is the requests an operator did not expect:
    // an expired token, a token signed by the wrong key, an authorization cache
    // that cannot be reached. Those fail while the principal is being
    // established — and while the logging middleware sat *below* the error
    // layers, every one of them produced no line at all. An operator read a
    // quiet server for exactly the traffic worth reading about.
    //
    // Asserted through a real server rather than by composing the middlewares
    // here, because the claim is about the pipeline's *order*: a hand-built
    // stack in this file would only re-assert the order this file chose.
    setUpAll(() {
      initializeReflection();
      TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
    });

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      registerFixtureAccessApi();
    });

    /// Captures the log while [body] runs against a freshly started server.
    Future<List<String>> logOf(TomBaseServerConfiguration config) async {
      _AppIdConfig('');
      final output = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      addTearDown(() => tomLog.logOutput = previous);

      final server = await TomServer(config).start();
      addTearDown(() => server.close(force: true));

      // Installed after the bind so the boot's own lines are not captured.
      tomLog.logOutput = output;
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.get('127.0.0.1', server.port, '/anything');
      final response = await request.close();
      await response.drain<void>();
      return output.messages;
    }

    test('the rejection produces an access-log line', () async {
      final messages = await logOf(_RejectingAuthConfig());

      expect(
        messages.where((line) => line.startsWith('HTTP/')),
        hasLength(1),
        reason:
            'a request refused during authentication must appear in the access '
            'log exactly once — the line naming method, path and status is the '
            'one an operator can correlate and count',
      );
    });

    test('the line names the method, the path and the status', () async {
      // `_handleError` already logged the *error*, and that line names none of
      // these — which is why an error line is not a substitute for an access
      // line, and why this asserts the fields rather than that something was
      // written.
      final line = (await logOf(
        _RejectingAuthConfig(),
      )).firstWhere((message) => message.startsWith('HTTP/'));

      expect(line, contains('[GET]'));
      expect(line, contains('/anything'));
      expect(line, contains('500'));
    });

    test(
      'a request that is not rejected is still logged exactly once',
      () async {
        // The other direction. The endpoint pipeline writes its own, richer line
        // and marks the request logged, so moving the middleware outwards must
        // not add a second one for every served request.
        final messages = await logOf(_BindableConfig());

        expect(
          messages.where((line) => line.startsWith('HTTP/')),
          hasLength(lessThanOrEqualTo(1)),
        );
      },
    );
  });

  group('start binds, and hands back what it bound', () {
    // The header above says the bind is covered only by the samples' own
    // integration scripts. That was true while `start()` returned `void`:
    // nothing could tell *listening* from *called*, and nothing could close the
    // socket afterwards, so a suite that started a server could not end. Both
    // follow from the returned handle, which is why these run here now.
    setUpAll(() {
      initializeReflection();
      TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
    });

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      registerFixtureAccessApi();
    });

    test('the future completes with a listening socket', () async {
      final server = await TomServer(_BindableConfig()).start();
      addTearDown(() => server.close(force: true));

      // Port 0 asks the OS to choose, so a non-zero port is the proof that a
      // bind actually happened rather than that a future completed.
      expect(server.port, isNot(0));
      expect(server.address.address, '127.0.0.1');
    });

    test('a bind failure rejects the future', () async {
      // The failure the fire-and-forget shape turned into an unhandled
      // asynchronous error: a deployment meets it on its first port collision,
      // and used to meet it as a stack trace from nowhere rather than as a
      // rejected future at the call site.
      final first = await TomServer(_BindableConfig()).start();
      addTearDown(() => first.close(force: true));

      await expectLater(
        TomServer(_BindableConfig(port: first.port)).start(),
        throwsA(isA<SocketException>()),
      );
    });

    test('the handle closes the socket', () async {
      // The other half of "returns no handle to close": without this a test or
      // a supervisor can start a server and never stop it, which is what kept
      // the bind out of this suite.
      final server = await TomServer(_BindableConfig()).start();
      final port = server.port;

      await server.close(force: true);

      // Closed for real, not merely forgotten: the port binds again, which it
      // could not while the first socket held it.
      final second = await TomServer(_BindableConfig(port: port)).start();
      addTearDown(() => second.close(force: true));
      expect(second.port, port);
    });
  });

  // The module's central safety claim, asserted against a running server rather
  // than against the order of two statements. The server principal caps every
  // user's grants at `min(user, server)`, so a socket that accepted before the
  // principal was installed would serve those requests **uncapped** — the one
  // direction in which getting it wrong grants access rather than denying it.
  //
  // The login is held open by the stub auth server, and the assertion is made
  // while it is held: at that moment `start()` is inside the login, and a
  // connection to the port it will bind is refused. A `start()` that bound
  // first would answer it.
  group('start() installs the deployment principal before the socket accepts', () {
    setUpAll(() {
      initializeReflection();
      TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
    });

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      registerFixtureAccessApi();
    });

    tearDown(() {
      // The principal is process-global and the renewal is a live timer: a test
      // that left either behind would cap, or wake up inside, every test after
      // it.
      TomServerSelfLogin.stopRenewal();
      TomServerPrincipal.clear();
    });

    test('a held-open login means nothing is listening yet', () async {
      final stub = await _StubAuthServer.start();
      addTearDown(stub.close);

      final port = await _freePort();
      final started = TomServer(
        _SelfLoginConfig(loginUri: stub.loginUri, port: port),
      ).start();

      // Deterministic rather than timed: the stub has the request in hand, so
      // `start()` is demonstrably inside the login. Anything bound now was
      // bound before it.
      await stub.loginArrived;
      expect(
        TomServerPrincipal.isConfigured,
        isFalse,
        reason: 'the login has not answered yet',
      );
      await expectLater(
        Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(isA<SocketException>()),
        reason:
            'the socket accepted a connection while the deployment was still '
            'logging in, so a request arriving there would have been served '
            'with user grants uncapped',
      );

      stub.release();
      final server = await started;
      addTearDown(() => server.close(force: true));

      // And the other half: once the future completes, both are true.
      expect(server.port, port);
      expect(TomServerPrincipal.current?.user.username, 'svc-app');
    });

    test('a configured deployment that cannot log in binds nothing', () async {
      // Port 1 on the loopback interface refuses immediately — the shape of an
      // auth server that is down, without waiting for a timeout.
      final port = await _freePort();

      await expectLater(
        TomServer(
          _SelfLoginConfig(
            loginUri: 'http://127.0.0.1:1/auth/login',
            port: port,
          ),
        ).start(),
        throwsA(isA<TomServerSelfLoginException>()),
      );

      expect(TomServerPrincipal.isConfigured, isFalse);
      // Free, not merely unanswered: the port binds, which it could not if
      // `start()` had reached `serve` before giving up.
      final rebound = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      addTearDown(() => rebound.close(force: true));
      expect(rebound.port, port);
    });

    test(
      'a deployment that configured no credential binds with no principal',
      () async {
        // The guard the whole feature stands on: a server built before
        // server-as-principal existed configures no credential, must start, and
        // must cap nothing. `null` is not an empty principal — an empty one
        // would be entitled to nothing and deny every feature.
        final server = await TomServer(_BindableConfig()).start();
        addTearDown(() => server.close(force: true));

        expect(server.port, isNot(0));
        expect(TomServerPrincipal.current, isNull);
      },
    );
  });
}

/// A port the OS has just confirmed is free.
///
/// `start()` needs the port *in advance* here, because the assertion is about
/// what is listening on it before `start()` binds — so port 0, which the other
/// bind tests use, cannot be read off a handle that does not exist yet.
Future<int> _freePort() async {
  final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return port;
}

/// An auth server that answers one service login, when told to.
///
/// Answers the real wire shape over a real socket, so the login goes through
/// `TomHttpServiceLoginTransport` rather than around it — the transport seam
/// exists for unit tests of the login itself, and substituting it here would
/// leave the boot's own HTTP call unexercised.
class _StubAuthServer {
  _StubAuthServer._(this._server);

  final HttpServer _server;
  final Completer<void> _arrived = Completer<void>();
  final Completer<void> _release = Completer<void>();

  /// Completes when the login request has been received and is being held.
  Future<void> get loginArrived => _arrived.future;

  /// Where a configuration should point.
  String get loginUri => 'http://127.0.0.1:${_server.port}/auth/login';

  static Future<_StubAuthServer> start() async {
    final stub = _StubAuthServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    stub._serve();
    return stub;
  }

  void _serve() {
    _server.listen((request) async {
      await request.drain<void>();
      if (!_arrived.isCompleted) _arrived.complete();
      await _release.future;
      final token = TomServerJwtToken(
        {'username': 'svc-app', 'userId': 42},
        encryptedData: {'entitlements': <String>[]},
      ).getJWT('tom');
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'authenticationToken': token,
            'authorizationToken': token,
          }),
        );
      await request.response.close();
    });
  }

  /// Lets the held login answer.
  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  Future<void> close() async {
    release();
    await _server.close(force: true);
  }
}

/// A [_BindableConfig] that also carries a deployment identity to log in with.
class _SelfLoginConfig extends TomBaseServerConfiguration {
  _SelfLoginConfig({required String loginUri, required int port}) : super([]) {
    noSsl = true;
    host = '127.0.0.1';
    isolateCount = 1;
    this.port = port;
    authServerLoginUri = loginUri;
    serviceAccountName = 'svc-app';
    serviceAccountCredential = 's3cret';
    serviceAccountOrganization = 'org';
    serviceAccountApplication = 'app';
  }

  @override
  void setValues(Map<String, Object?> values) {}
}

/// A configuration that binds a real socket on the loopback interface.
///
/// Port `0` asks the OS for a free one, so the suite never collides with a
/// developer's running server — and the chosen port is readable off the handle,
/// which is what lets the collision test *aim* at it.
class _BindableConfig extends TomBaseServerConfiguration {
  _BindableConfig({int port = 0}) : super([]) {
    noSsl = true;
    host = '127.0.0.1';
    isolateCount = 1;
    this.port = port;
  }

  @override
  void setValues(Map<String, Object?> values) {}
}

/// A configuration whose authentication middleware refuses every request.
///
/// Stands in for the real refusals — an expired token, a wrong signing key, an
/// unreachable authorization cache — all of which fail at the same point in the
/// pipeline and are answered by the same error layer.
class _RejectingAuthConfig extends _BindableConfig {
  _RejectingAuthConfig() {
    authenticationMiddleware = (innerHandler) =>
        (request) => throw TomServerException('test.auth.rejected', 'refused');
  }
}
