/// The whole trip a preference makes: written on one client, read on another
/// (C-13).
///
/// The two halves are already covered separately — `user_preferences_db_test`
/// exercises the store through the service, `user_preferences_endpoints_test`
/// the status a miss produces, and `tom_core_flutter`'s `preferences_test` the
/// shipped client against the same contract. What none of them asserts is the
/// claim the module exists to make: **a preference follows the user**. That is
/// a statement about two clients and one server, so it cannot be made by either
/// half agreeing with itself.
///
/// So this file joins them. A real loopback server carries the shipped
/// [TomUserPreferencesServer] over the real pipeline and a real
/// `tom_user_preference` table, and two *independent* callers — separate
/// connections, no shared state but the server — take the two ends. The
/// assertion is that the second caller reads what the first wrote and never
/// wrote itself, and that a caller signed in as somebody else does not.
///
/// The callers are written here rather than imported. `TomUserPreferencesClient`
/// lives in `tom_core_flutter`, which this package deliberately does not depend
/// on (a server must not pull in the Flutter SDK to test itself), and it is
/// covered against this very contract in that package's suite. What matters for
/// the trip is that *nothing here writes a URI*: every request is resolved from
/// [tomUserPreferencesApi] by [TomApiEndpoint.resolveUri], the same declaration
/// the router mounts the server end from, so the two ends cannot address
/// different things.
///
/// The group is `@Tags(['db'])` and skips itself when no MariaDB is reachable,
/// so the default `testkit :test` run stays green everywhere. Bring a server up
/// with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The header a caller names its signed-in user with.
///
/// Standing in for authentication, which has its own suite: what the endpoints
/// need is a [TomPrincipal] in the request zone, and minting a signed token here
/// would test the login path and leave this file unable to run without a key.
/// The header exists because the interesting cases are *two callers with the
/// same user* and *two callers with different ones* — a single fixed principal
/// could express neither.
const String _userHeader = 'x-test-user';

/// A principal whose [TomPrincipal.id] is [userId] — the value the `'owner'`
/// scope resolver binds into `principal_id`.
TomPrincipal _principalWithId(int userId) => TomPrincipal(
  authenticated: true,
  context: {},
  clientId: 0,
  organization: 'acme',
  organizationId: 0,
  application: 'console',
  applicationId: 0,
  process: 'preferences',
  processId: 0,
  language: 'en',
  country: 'US',
  clientCountry: 'US',
  clientLanguage: 'en',
  clientTimezone: 'UTC',
  user: TomUser(
    id: userId,
    username: 'user$userId',
    firstname: 'Test',
    lastname: 'User',
    attributes: {},
    timezone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// Installs the principal named by [_userHeader] into the request zone, exactly
/// where `tomDefaultAuthenticationMiddleware` installs the one it derived from a
/// bearer token.
Middleware _signedInByHeader() =>
    (innerHandler) => (request) {
      final id = int.tryParse(request.headers[_userHeader] ?? '');
      if (id == null) return innerHandler(request);
      return runZoned<FutureOr<Response>>(
        () => innerHandler(request),
        zoneValues: {TomPrincipal: _principalWithId(id)},
      );
    };

/// One client of the preferences API: its own connection, its own signed-in
/// user, and not one URI of its own.
///
/// Deliberately minimal — it carries only what the trip needs — but every
/// address it calls comes from the contract, so "the client asked for what the
/// server serves" is a property of the declaration rather than of this file.
class _PreferencesCaller {
  _PreferencesCaller(this.baseUri, this.userId);

  /// The server root; the API's own `/preferences` path is appended from the
  /// contract, never written here.
  final Uri baseUri;

  /// The user this caller is signed in as.
  final int userId;

  final HttpClient _http = HttpClient();

  void close() => _http.close();

  /// Writes [value] under [key], as the shipped client does: encode through the
  /// codec, then PUT the write request.
  ///
  /// No `key` is handed to [_send]: the write endpoint's URI is the bare
  /// collection, so the key reaches the server in the body alone.
  Future<void> write(String key, Object value) async {
    final encoded = TomUserPreferenceCodec.encode(key, value);
    final answer = await _send(
      tomUserPreferencesWriteEndpointId,
      body: tomReflectionInfo.convertToJsonString(
        TomUserPreferenceWriteRequest(
          key: encoded.key,
          valueType: encoded.valueType,
          value: encoded.value,
        ),
      ),
    );
    expect(
      answer.statusCode,
      200,
      reason: 'a write by user $userId was rejected: ${answer.body}',
    );
  }

  /// Reads [key] as a [T], or `null` when this user has never written it.
  ///
  /// `404` is absence and nothing else is — the same rule the shipped client
  /// applies, and the reason the read endpoint carries an error handler of its
  /// own.
  Future<T?> read<T extends Object>(String key) async {
    final answer = await _send(tomUserPreferencesReadEndpointId, key: key);
    if (answer.statusCode == 404) return null;
    expect(
      answer.statusCode,
      200,
      reason: 'a read by user $userId failed: ${answer.body}',
    );
    return TomUserPreferenceCodec.decode<T>(
      tomReflectionInfo.convertFromJsonString(
        TomUserPreferenceDto(),
        answer.body,
      ),
    );
  }

  /// Every key this user holds, in the order the server lists them.
  Future<List<String>> keys() async {
    final answer = await _send(tomUserPreferencesListEndpointId);
    expect(answer.statusCode, 200, reason: answer.body);
    return [
      for (final element in jsonDecode(answer.body) as List)
        (element as Map)['key'] as String,
    ];
  }

  /// Deletes [key].
  Future<void> remove(String key) async {
    final answer = await _send(tomUserPreferencesDeleteEndpointId, key: key);
    expect(answer.statusCode, anyOf(200, 204), reason: answer.body);
  }

  /// Issues the endpoint registered under [endpointId] and reads the answer.
  Future<_Answer> _send(String endpointId, {String? key, String? body}) async {
    final endpoint = tomUserPreferencesApi[endpointId];
    final request = await _http.openUrl(
      endpoint.method.name.toUpperCase(),
      endpoint.resolveUri(
        baseUri,
        parameters: key == null ? const {} : {'key': key},
      ),
    );
    request.headers.set(_userHeader, '$userId');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    return _Answer(
      response.statusCode,
      await response.transform(utf8.decoder).join(),
    );
  }
}

/// One server answer: the status and the text, read together.
class _Answer {
  const _Answer(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('a preference between two clients', () {
    late TomDataSourceInfo dsi;
    late HttpServer server;
    late Uri baseUri;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // TomUserPreference declares `datasource: 'main'`, the name a deployment
      // configures. Aliasing rather than renaming keeps the entity under test
      // identical to the one that ships.
      await TestDatabase.registerMainAlias();
      await TestDatabase.ensureUserPreferenceTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateUserPreference(dsi);
      TomBean.resetBeanContext();
      // The shipped handler over the shipped service over a real table: the
      // point of the file is that nothing in the chain is a stand-in except the
      // credential.
      TomBean.withType(
        TomUserPreferences,
        TomUserPreferences(TomUserPreferenceRepository()),
      );
      TomBean.withType(
        TomUserPreferencesServer,
        const TomUserPreferencesServer(),
      );
      registerTomUserPreferencesApi();
      // The router mounts every endpoint reflection can see, not only the ones
      // a test is interested in, so the fixture surface has to be satisfied too
      // — an unregistered API is a routing failure, not a route that is left
      // out.
      registerFixtureAccessApi();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomBean.withType(TomHealthServer, TomHealthServer());

      final router = TomEndpointRouting().initializeRouter();
      final handler = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware('preferences round trip', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addMiddleware(_signedInByHeader())
          .addHandler(router.call);
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    });

    tearDown(() async {
      await server.close(force: true);
      TomBean.resetBeanContext();
    });

    tearDownAll(TestDatabase.reset);

    /// Two clients of user 41 and one of user 42, closed when the test ends.
    ///
    /// Separate [HttpClient]s rather than one shared: two devices are two
    /// connections, and a single client could satisfy the assertion from a
    /// connection-level cache without the value ever having reached the table.
    (_PreferencesCaller, _PreferencesCaller, _PreferencesCaller) callers() {
      final first = _PreferencesCaller(baseUri, 41);
      final second = _PreferencesCaller(baseUri, 41);
      final other = _PreferencesCaller(baseUri, 42);
      addTearDown(first.close);
      addTearDown(second.close);
      addTearDown(other.close);
      return (first, second, other);
    }

    test('the second client reads what the first wrote', () async {
      final (first, second, _) = callers();

      await first.write(TomUserPreferenceKeys.theme, 'dark');

      // The second caller has written nothing, so a value here can only have
      // come from the server — which is the whole claim of a user preference.
      expect(await second.read<String>(TomUserPreferenceKeys.theme), 'dark');
    });

    test('every preference type survives the trip', () async {
      final (first, second, _) = callers();
      final instant = DateTime.utc(2026, 3, 4, 5, 6, 7);

      await first.write('account.language', 'de');
      await first.write('account.pageSize', 25);
      await first.write('account.zoom', 1.25);
      await first.write('account.compact', true);
      await first.write('account.lastSeen', instant);

      expect(await second.read<String>('account.language'), 'de');
      expect(await second.read<int>('account.pageSize'), 25);
      expect(await second.read<double>('account.zoom'), 1.25);
      expect(await second.read<bool>('account.compact'), true);
      expect(await second.read<DateTime>('account.lastSeen'), instant);
    });

    test('a reflected value arrives as an object, not as text', () async {
      final (first, second, _) = callers();

      await first.write(
        'account.display',
        FixtureDisplayPreference()
          ..theme = 'solarized'
          ..fontSize = 13
          ..compact = true,
      );

      // Reconstructed on the far end from the type name the value carries —
      // which is what separates a typed preference from a stringly-typed blob,
      // and it has to survive HTTP in both directions to mean anything.
      final read = await second.read<FixtureDisplayPreference>(
        'account.display',
      );
      expect(read, isNotNull);
      expect(read!.theme, 'solarized');
      expect(read.fontSize, 13);
      expect(read.compact, isTrue);
    });

    test('the second client sees the later write, not the first', () async {
      final (first, second, _) = callers();

      await first.write(TomUserPreferenceKeys.theme, 'dark');
      expect(await second.read<String>(TomUserPreferenceKeys.theme), 'dark');

      // A value the second client had already read once: if anything but the
      // table were answering, this is where it would show.
      await first.write(TomUserPreferenceKeys.theme, 'light');
      expect(await second.read<String>(TomUserPreferenceKeys.theme), 'light');
    });

    test('either client can write and the other reads it', () async {
      final (first, second, _) = callers();

      await first.write('account.language', 'de');
      await second.write('account.pageSize', 50);

      // Neither end is the writer by construction — the store is the server, so
      // the trip runs in both directions.
      expect(await second.read<String>('account.language'), 'de');
      expect(await first.read<int>('account.pageSize'), 50);
    });

    test('a delete on one client clears it on the other', () async {
      final (first, second, _) = callers();

      await first.write(TomUserPreferenceKeys.theme, 'dark');
      expect(await second.read<String>(TomUserPreferenceKeys.theme), 'dark');

      await second.remove(TomUserPreferenceKeys.theme);
      expect(await first.read<String>(TomUserPreferenceKeys.theme), isNull);
    });

    test('both clients list the same keys in the same order', () async {
      final (first, second, _) = callers();

      // Written across both clients and in neither alphabetical order nor its
      // reverse, so a list that echoed the write sequence would differ from the
      // one asserted rather than coincide with it.
      await first.write('theme', 'dark');
      await second.write('account.pageSize', 50);
      await first.write('account.language', 'de');

      // The same *list*, not the same set. The server orders by key, so two
      // clients of one user see the same sequence — which is what makes a list
      // safe to render side by side or diff between devices. An unordered
      // matcher here would pass just as well against a server that answered in
      // a different order each time.
      const expected = <String>[
        'account.language',
        'account.pageSize',
        'theme',
      ];
      expect(await first.keys(), expected);
      expect(await second.keys(), expected);
    });

    test('a client of another user sees none of it', () async {
      final (first, _, other) = callers();

      await first.write(TomUserPreferenceKeys.theme, 'dark');

      // Not a denial but an absence: the row scope means the query never
      // selects it, so the answer is the same one an unwritten key gives — and
      // it leaks nothing about whether somebody else holds the key.
      expect(await other.read<String>(TomUserPreferenceKeys.theme), isNull);
      expect(await other.keys(), isEmpty);
    });

    test(
      "one user's write does not disturb another's same-named preference",
      () async {
        final (first, second, other) = callers();

        await first.write(TomUserPreferenceKeys.theme, 'dark');
        await other.write(TomUserPreferenceKeys.theme, 'light');

        expect(await second.read<String>(TomUserPreferenceKeys.theme), 'dark');
        expect(await other.read<String>(TomUserPreferenceKeys.theme), 'light');
      },
    );

    test('a caller with no principal is refused, not served unscoped', () async {
      final (first, _, _) = callers();
      await first.write(TomUserPreferenceKeys.theme, 'dark');

      final anonymous = HttpClient();
      addTearDown(anonymous.close);
      final request = await anonymous.openUrl(
        'GET',
        tomUserPreferencesApi[tomUserPreferencesListEndpointId].resolveUri(
          baseUri,
        ),
      );
      final response = await request.close();
      await response.drain<void>();

      // The contract declares TomAuthenticatedAccess on every endpoint, and
      // there is no anonymous preference: a caller who is nobody has nothing to
      // ask for.
      expect(response.statusCode, isNot(200));
    });
  }, skip: skipReason);
}
