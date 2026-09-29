/// Socket-free tests for [AuthorizedFileTransferClient], the byte half of the
/// authenticated client: all four transfer operations recover from an
/// expired token, and they do it through the *same* credential and the *same*
/// refresher the JSON half uses.
///
/// ## What is actually being proved
///
/// The failure this tier exists to avoid is not "a transfer 401s" — it is a
/// client that authenticates its **JSON** calls one way and its **byte** calls
/// another. That bug is invisible until a session ages: the board loads and its
/// attachments 401. So the stand-in server here does not simply fail the first
/// attempt and pass the second. It honours exactly one bearer, and the fake asks
/// for the presented credential through [AuthorizedHttp.authorizationHeader] —
/// the very function [ioFileTransferClient] hands the kernel transfer client as
/// its `headerProvider`. A second token path in the client would therefore show
/// up here as a refusal that no refresh can fix, not as a silent pass.
///
/// The refresher is not a stub either: the decorator is built over
/// [AuthorizedHttp.refresher], which is the production composition, so the
/// refresh under test is a real [AuthClient.refresh] round-trip that stores a
/// real token pair — and the replay only succeeds because it re-read it.
///
/// Stored tokens are synthetic unsigned JWTs (see [_makeJwt]) so
/// `setTokens(..., decrypt: false)` accepts them without RSA; the refresh
/// deserializes a [LoginResult] through reflection, hence `initializeReflection`.
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

/// The slot every test addresses — an item attachment, named through the shared
/// contract exactly as the app client names it.
final String _slot = AppFileSlots.itemAttachment('1');

/// The bytes uploaded, small enough that a whole-payload comparison is the
/// assertion.
final List<int> _payload = utf8.encode('advanced sample attachment');

void main() {
  setUpAll(initializeReflection);

  group('AuthorizedFileTransferClient', () {
    // The bearer store is process-global; each test gets a fresh one.
    setUp(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );
    tearDown(
      () => TomBearerAuthentication.bearerAuthentication =
          TomBearerAuthentication(),
    );

    test(
      'TC-AFT-01: an expired token is refreshed once and the upload replayed '
      'with the fresh bearer',
      () async {
        final f = _expiredSession();

        final stored = await f.files.upload(
          slot: _slot,
          source: TomFileSource.bytes('notes.txt', _payload),
        );

        expect(stored.byteCount, equals(_payload.length));
        // Exactly one refresh, exactly two attempts — a recovery, not a loop.
        expect(f.refreshCalls, equals(1));
        expect(
          f.scripted.presented,
          equals(['Bearer ${f.staleAuthz}', 'Bearer ${f.freshAuthz}']),
        );
      },
    );

    test(
      'TC-AFT-02: download recovers the same way and serves the bytes intact',
      () async {
        final f = _expiredSession();
        f.scripted.content[_slot] = _payload;

        final received = <int>[];
        await for (final chunk in f.files.download(_slot)) {
          received.addAll(chunk);
        }

        expect(received, equals(_payload));
        expect(f.refreshCalls, equals(1));
        expect(f.scripted.presented, hasLength(2));
      },
    );

    test('TC-AFT-03: describe (HEAD) recovers', () async {
      final f = _expiredSession();
      f.scripted.content[_slot] = _payload;

      final described = await f.files.describe(_slot);

      expect(described, isNotNull);
      expect(described!.byteCount, equals(_payload.length));
      expect(f.refreshCalls, equals(1));
    });

    test('TC-AFT-04: remove (DELETE) recovers', () async {
      final f = _expiredSession();
      f.scripted.content[_slot] = _payload;

      expect(await f.files.remove(_slot), isTrue);
      expect(f.scripted.content, isNot(contains(_slot)));
      expect(f.refreshCalls, equals(1));
    });

    test('TC-AFT-05: the replayed upload re-reads the source, so the retry sends '
        'the whole file again', () async {
      // The property that makes an upload retryable at all: `TomFileSource.open`
      // is a factory, not a stream. If the decorator replayed a spent stream the
      // second attempt would store nothing — and a half-written attachment is
      // worse than a failed one.
      final f = _expiredSession();

      await f.files.upload(
        slot: _slot,
        source: TomFileSource.bytes('notes.txt', _payload),
      );

      expect(f.scripted.uploaded, equals([_payload, _payload]));
    });

    test('TC-AFT-06: the credential presented is the authorization token — the '
        'same one the JSON half sends', () async {
      // The whole point of the tier. The authentication token is stored too and
      // is a *different* string; a client that reached for it (as the kernel's
      // built-in bearer does by default) would present that instead.
      final f = _liveSession();

      await f.files.describe(_slot);

      expect(f.scripted.presented.single, equals('Bearer ${f.freshAuthz}'));
      expect(
        f.scripted.presented.single,
        isNot(equals('Bearer ${TomBearerAuthentication.token}')),
      );
      expect(f.refreshCalls, isZero, reason: 'nothing expired');
    });

    test(
      'TC-AFT-07: a non-expiry refusal is rethrown unchanged, with no refresh',
      () async {
        final f = _liveSession();
        f.scripted.refusal = TomFileTransferException(
          'file_transfer.rejected',
          'The server rejected the file transfer.',
          parameters: {'slot': _slot, 'statusCode': 403},
        );

        await expectLater(
          f.files.describe(_slot),
          throwsA(
            isA<TomFileTransferException>()
                .having((e) => e.key, 'key', 'file_transfer.rejected')
                .having((e) => e.parameters?['statusCode'], 'statusCode', 403),
          ),
        );
        // A 403 is an answer, not an expiry: refreshing would only re-ask a
        // question the server already settled.
        expect(f.refreshCalls, isZero);
        expect(f.scripted.presented, hasLength(1));
      },
    );

    test(
      'TC-AFT-08: a refusal that names no status is rethrown untouched',
      () async {
        // A cancellation carries no `statusCode`, so there is nothing for the
        // policy to rule on — it must surface exactly as the transfer client threw
        // it rather than being mistaken for a recoverable failure.
        final f = _liveSession();
        f.scripted.refusal = TomFileTransferException(
          'file_transfer.cancelled',
          'The file transfer was cancelled.',
          parameters: {'slot': _slot},
        );

        await expectLater(
          f.files.remove(_slot),
          throwsA(
            isA<TomFileTransferException>().having(
              (e) => e.key,
              'key',
              'file_transfer.cancelled',
            ),
          ),
        );
        expect(f.refreshCalls, isZero);
      },
    );

    test('TC-AFT-09: a 401 that persists after the refresh surfaces as '
        'TomAuthExpiredException', () async {
      // The server honours a token nobody will ever hold, so the refresh
      // succeeds and the replay is refused anyway — a genuinely dead session.
      final f = _expiredSession(honoured: _makeJwt({'sub': 'nobody'}));

      await expectLater(
        f.files.describe(_slot),
        throwsA(
          isA<TomAuthExpiredException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              // The server's own key, read from the refusal body exactly as the
              // JSON half reads it — one vocabulary across both halves.
              .having((e) => e.key, 'key', 'auth.token.expired'),
        ),
      );
      expect(f.refreshCalls, equals(1), reason: 'refreshed once, never looped');
      expect(f.scripted.presented, hasLength(2));
    });

    test(
      'TC-AFT-10: a refusal arriving after the first chunk is not retried',
      () async {
        // The retry window closes at the first chunk on purpose: the consumer has
        // already seen a prefix, and silently restarting the stream would hand it
        // those bytes twice. A 401 lands before any bytes anyway — the server
        // authorizes before it writes — so nothing recoverable is given up.
        final f = _expiredSession();
        f.scripted.refuseAfterFirstChunk = true;

        final received = <int>[];
        await expectLater(
          () async {
            await for (final chunk in f.files.download(_slot)) {
              received.addAll(chunk);
            }
          }(),
          throwsA(
            isA<TomFileTransferException>().having(
              (e) => e.parameters?['statusCode'],
              'statusCode',
              401,
            ),
          ),
        );
        expect(received, equals([1]), reason: 'the prefix is delivered once');
        expect(f.refreshCalls, isZero);
      },
    );

    test(
      'TC-AFT-11: an empty slot describes as null without a refresh',
      () async {
        // Absence is an answer, not a failure — the decorator must not turn "no
        // file here" into a session problem.
        final f = _liveSession();

        expect(await f.files.describe(_slot), isNull);
        expect(f.refreshCalls, isZero);
      },
    );

    test('TC-AFT-12: closing the decorator closes the delegate', () async {
      final f = _liveSession();
      f.files.close();
      expect(f.scripted.closes, equals(1));
    });
  });
}

// =============================================================================
// FIXTURES
// =============================================================================

/// One assembled client under test, with the handles a test asserts on.
class _Fixture {
  _Fixture({
    required this.files,
    required this.scripted,
    required this.transport,
    required this.staleAuthz,
    required this.freshAuthz,
  });

  /// The decorator under test, composed exactly as production composes it.
  final AuthorizedFileTransferClient files;

  /// The stand-in server behind it.
  final _ScriptedFiles scripted;

  final _RefreshTransport transport;

  /// The authorization token stored before the first attempt.
  final String staleAuthz;

  /// The authorization token the refresh mints.
  final String freshAuthz;

  /// How many `/auth/refresh` round-trips happened.
  int get refreshCalls => transport.calls;
}

/// A client whose stored token is already stale: the server honours
/// [honoured] — by default the token the refresh will mint, so the replay
/// succeeds; pass a token nobody holds to model a dead session.
_Fixture _expiredSession({String? honoured}) {
  final stale = _makeJwt({'username': 'alice', 'userId': 2, 'v': 0});
  final fresh = _makeJwt({'username': 'alice', 'userId': 2, 'v': 1});
  TomBearerAuthentication.setTokens(
    _makeJwt({'username': 'alice', 'userId': 2, 'kind': 'auth'}),
    stale,
    false,
  );
  return _assemble(
    honoured: honoured ?? fresh,
    staleAuthz: stale,
    freshAuthz: fresh,
  );
}

/// A client whose stored token the server honours — nothing to recover from.
_Fixture _liveSession() {
  final current = _makeJwt({'username': 'alice', 'userId': 2, 'v': 1});
  TomBearerAuthentication.setTokens(
    _makeJwt({'username': 'alice', 'userId': 2, 'kind': 'auth'}),
    current,
    false,
  );
  return _assemble(honoured: current, staleAuthz: current, freshAuthz: current);
}

/// Composes the decorator the way the application does: one [AuthClient], one
/// [AuthorizedHttp] over it, and the file client running on **that wrapper's**
/// refresher rather than a second one of its own.
_Fixture _assemble({
  required String honoured,
  required String staleAuthz,
  required String freshAuthz,
}) {
  final transport = _RefreshTransport(_loginBody(freshAuthz));
  final authClient = AuthClient(
    Uri.parse('http://localhost:8081'),
    transport: transport,
  );
  final http = AuthorizedHttp(transport, authClient);
  final scripted = _ScriptedFiles(honoured: honoured);
  return _Fixture(
    files: AuthorizedFileTransferClient(scripted, http.refresher),
    scripted: scripted,
    transport: transport,
    staleAuthz: staleAuthz,
    freshAuthz: freshAuthz,
  );
}

/// A stand-in file server that honours exactly one bearer.
///
/// It reads the presented credential through [headerProvider] — bound to the
/// same [AuthorizedHttp.authorizationHeader] that [ioFileTransferClient] gives
/// the kernel transfer client, so "the file client uses exactly one token path"
/// is what these tests measure, not what they assume.
class _ScriptedFiles extends TomFileTransferClient {
  _ScriptedFiles({required this.honoured});

  /// The bearer this server accepts; anything else is a 401.
  final String honoured;

  /// How the client under test names its credential.
  final Map<String, String> Function() headerProvider =
      AuthorizedHttp.authorizationHeader;

  /// Thrown instead of the credential check when set — the refusals that are
  /// not about expiry at all.
  TomFileTransferException? refusal;

  /// When true, [download] yields a chunk *before* checking the credential.
  bool refuseAfterFirstChunk = false;

  /// Every `Authorization` header presented, in order.
  final List<String?> presented = [];

  /// The bytes read from the source on every upload attempt — a replay shows up
  /// as a second, identical entry.
  final List<List<int>> uploaded = [];

  /// What this server currently holds, by slot.
  final Map<String, List<int>> content = {};

  /// How many times [close] was called.
  int closes = 0;

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async {
    // Drained *before* the credential check so a refused attempt still records
    // its bytes — which is how TC-AFT-05 sees that the replay re-read the
    // source rather than sending a spent stream.
    final bytes = <int>[];
    await for (final chunk in source.open()) {
      bytes.addAll(chunk);
    }
    uploaded.add(bytes);
    _check();
    content[slot] = bytes;
    return TomFileMetadata(
      key: 'stored/$slot',
      mediaType: source.mediaType,
      byteCount: bytes.length,
      fileName: source.fileName,
    );
  }

  @override
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async* {
    if (refuseAfterFirstChunk) {
      yield const [1];
      _check();
      return;
    }
    _check();
    final bytes = content[slot];
    if (bytes == null) throw _notFound(slot);
    yield bytes;
  }

  @override
  Future<TomFileMetadata?> describe(String slot) async {
    _check();
    final bytes = content[slot];
    if (bytes == null) return null;
    return TomFileMetadata(
      key: 'stored/$slot',
      mediaType: 'text/plain',
      byteCount: bytes.length,
    );
  }

  @override
  Future<bool> remove(String slot) async {
    _check();
    return content.remove(slot) != null;
  }

  @override
  void close() => closes++;

  /// Records what was presented, then answers it.
  void _check() {
    final header = headerProvider()['Authorization'];
    presented.add(header);
    final forced = refusal;
    if (forced != null) throw forced;
    if (header == 'Bearer $honoured') return;
    throw TomFileTransferException(
      'file_transfer.rejected',
      'The server rejected the file transfer.',
      parameters: {
        'slot': _slot,
        'statusCode': 401,
        'response': '{"error":"auth.token.expired"}',
      },
    );
  }

  TomFileTransferException _notFound(String slot) => TomFileTransferException(
    'file_transfer.not_found',
    'No file is stored for the requested slot.',
    parameters: {'slot': slot},
  );
}

/// A [JsonTransport] that answers every call with one canned `/auth/refresh`
/// body and counts the round-trips, so "refreshed exactly once" is assertable.
class _RefreshTransport implements JsonTransport {
  _RefreshTransport(this._body);

  final Map<String, Object?> _body;

  /// How many calls were made — all of them refreshes, since the file client
  /// carries its own connection and nothing else uses this transport.
  int calls = 0;

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    calls++;
    return HttpJsonResponse(200, jsonEncode(_body));
  }
}

/// A success `/auth/refresh` body carrying [authzToken] as the new authorization
/// token, so a refresh stores a pair the replay can pick up.
Map<String, Object?> _loginBody(String authzToken) => {
  'user': {
    'id': '2',
    'username': 'alice',
    'displayName': 'alice',
    'email': 'alice@example.com',
    'status': 'active',
  },
  'authToken': _makeJwt({'username': 'alice', 'userId': 2, 'kind': 'auth'}),
  'authzToken': authzToken,
  'expiresAt': '2026-06-28T12:34:56.000Z',
};

/// Builds an unsigned, undecrypted JWT whose middle segment carries [payload].
/// Suitable for `setTokens(..., decrypt: false)`.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg({'exp': 4102444800, ...payload})}.sig';
}
