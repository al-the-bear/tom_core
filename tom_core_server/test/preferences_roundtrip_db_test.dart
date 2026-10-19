/// The whole trip a preference makes: written on one client, read on another
/// (C-13).
///
/// The two halves are already covered separately — `preferences_db_test`
/// exercises the store through the service, `preferences_endpoints_test`
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
    id: '$userId',
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

/// The smallest configuration a [TomServer] can be built from.
///
/// Only needed to reach `TomServer.errorHandler`, which is a field and so needs
/// an instance. `setValues` is overridden away because a real configuration is
/// generated, and none of its merged values matter here. Mirrors
/// `preferences_endpoints_test.dart`'s `_NoopConfig`.
class _NoopConfig extends TomBaseServerConfiguration {
  _NoopConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

/// Renders an escaping error the way a deployed server does.
///
/// Load-bearing rather than decorative. `TomServer.start` always installs this
/// layer — `_handleError(errorHandler, "InnerErrorHandler")`, between the
/// authentication middleware and the router — so a pipeline without it does not
/// serve what the framework serves, and a test built on one cannot assert what
/// a client receives.
///
/// It matters here because the error layers are two and not one. An endpoint's
/// own [TomEndpoint.errorHandler] only sees what the *invoked method* threw,
/// while the access check runs before the invocation and outside that
/// `try`/`catch`; a denial therefore escapes the endpoint handler entirely and
/// is rendered by this layer alone. Without it the denial reached shelf
/// uncaught, and the anonymous caller's answer was shelf's own
/// `500 Internal Server Error` — the shape an unhandled bug produces, carrying
/// no evidence of which failure it was.
///
/// The rendering is the shipped `TomServer.errorHandler` itself, not a copy, so
/// what the test below reads off the wire is the framework's error envelope
/// rather than this file's idea of one.
Middleware _rendersErrorsLikeTheServer() {
  final render = TomServer(_NoopConfig()).errorHandler;
  return (innerHandler) =>
      (request) => Future.sync(() => innerHandler(request)).onError<Object>((
        error,
        stack,
      ) {
        final rendered = render(request, error, stack);
        if (rendered == null) throw error;
        return rendered;
      });
}

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

  /// PUTs an already-encoded pair and hands back the answer unjudged — for the
  /// writes the server is expected to refuse.
  Future<_Answer> writeEncoded(
    String key,
    String valueType,
    String valueJson,
  ) => _send(
    tomUserPreferencesWriteEndpointId,
    body: tomReflectionInfo.convertToJsonString(
      TomUserPreferenceWriteRequest(
        key: key,
        valueType: valueType,
        value: valueJson,
      ),
    ),
  );

  /// Reads [key] as a [T], or `null` when this user has never written it.
  ///
  /// Absence is a `404` whose envelope names
  /// [tomUserPreferencesNotFoundErrorKey], and nothing else is — the same rule
  /// the shipped client applies, and the reason the read endpoint carries an
  /// error handler of its own. A bare `404` is a refusal and fails the
  /// expectation below like any other status.
  Future<T?> read<T extends Object>(String key) async {
    final answer = await _send(tomUserPreferencesReadEndpointId, key: key);
    if (answer.reportsAbsence) return null;
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

  /// The `errorKey` of the error envelope this answer carries, or `null` when
  /// the body is not one.
  String? get errorKey {
    try {
      final envelope = jsonDecode(body);
      return envelope is Map ? envelope['errorKey'] as String? : null;
    } on FormatException {
      return null;
    }
  }

  /// Whether this is the read endpoint saying "never written": a `404`
  /// carrying the error envelope keyed [tomUserPreferencesNotFoundErrorKey].
  bool get reportsAbsence =>
      statusCode == 404 && errorKey == tomUserPreferencesNotFoundErrorKey;
}

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('a preference between two clients', () {
    late TomDataSourceInfo dsi;
    late HttpServer server;
    late Uri baseUri;

    /// Whatever was registered as the [TomUserPreferencesServer] bean at the
    /// moment before the router was built — captured so a later assertion can
    /// say the pipeline *constructed* the handler rather than merely finding
    /// one. `null` is the answer the file is written to produce, and it is read
    /// rather than assumed because a registration added back in `setUp` would
    /// otherwise silently return this suite to asserting nothing.
    Object? handlerBeanBeforeRouting;

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
      TomBean.withType<TomUserPreferences>(
        TomUserPreferences(TomUserPreferenceRepository()),
      );
      // The *store* is installed and the *handler* is not, which is exactly the
      // split `doc/preferences.md` describes: a deployment registers
      // `TomUserPreferences` at bootstrap, and the handler "needs no bean:
      // like every component with a no-argument constructor, the pipeline
      // instantiates it". Registering one here too would make the claim
      // untestable in the one suite that mounts the real router — the
      // `??=` chain in `initializeRouter` reaches `instantiateComponent` only
      // when the bean lookup came back empty, so a pre-registration does not
      // merely duplicate the construction, it replaces it.
      handlerBeanBeforeRouting = TomBean.getBeanByType(
        TomUserPreferencesServer,
      );
      // The router mounts every endpoint reflection can see, not only the ones
      // a test is interested in, so the fixture surface has to be satisfied too
      // — an unregistered API is a routing failure, not a route that is left
      // out. These stand in for an *application's* own components, which
      // nothing claims are auto-built: the framework constructs what it ships,
      // and anything else stays the application's to register. Registering them
      // is therefore the accurate half of the picture, not the same omission as
      // the handler above.
      registerFixtureAccessApi();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());

      final router = TomEndpointRouting().initializeRouter();
      final handler = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware('preferences round trip', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addMiddleware(_signedInByHeader())
          // In the same position the shipped pipeline puts it: after the
          // authentication layer, so that what it renders is a failure of the
          // request rather than a failure to identify the caller.
          .addMiddleware(_rendersErrorsLikeTheServer())
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

    test('the pipeline built the handler every other test here used', () {
      // `doc/preferences.md` promises a deployment two things it need not do:
      // register the API ("the pipeline registers it itself, so a deployment
      // gets these endpoints without adding a line") and register the handler
      // ("needs no bean ... the pipeline instantiates it"). Both are real —
      // `initializeRouter` opens with `registerFrameworkApis()`, and its `??=`
      // chain ends in `instantiateComponent` — but this suite used to do both
      // by hand before building the router, so it exercised neither.
      //
      // Removing those two lines is most of the repair, and it is not this
      // test that collects the benefit: with nothing registered, a handler the
      // pipeline fails to build is a handler no route is mounted on, and the
      // *whole group* dies in `setUp`. Every test here now depends on the
      // construction happening.
      //
      // What this test adds is the half that failure cannot reach.
      // `instantiateComponent` both builds the instance and registers it, and
      // its dartdoc explains why the second part matters: "the router and any
      // later `TomBean.getBeanByType` see the same object". Drop only the
      // registration and the router still mounts the returned instance — every
      // other test in this file passes, and the promise is broken in a way
      // nothing observes. So the two assertions are one statement each: the
      // bean was absent going in (or this suite is back to never reaching
      // `instantiateComponent` at all), and present coming out.
      expect(
        handlerBeanBeforeRouting,
        isNull,
        reason:
            'something registered a TomUserPreferencesServer before the router '
            'was built, which puts this suite back to never reaching '
            'instantiateComponent',
      );
      expect(
        TomBean.getBeanByType(TomUserPreferencesServer),
        isA<TomUserPreferencesServer>(),
        reason:
            'the pipeline did not construct and register the shipped handler',
      );
    });

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

    test('a miss and a refusal share a status and differ in the body', () async {
      // The absence convention, asserted against the served pipeline rather
      // than against a handler in isolation. Both answers are a `404` — the
      // refusal so that it cannot be told from a route that does not exist —
      // so the body is the whole of the difference, and a client that read the
      // status alone would hand a signed-out caller the defaults.
      final (first, _, _) = callers();
      final endpoint = tomUserPreferencesApi[tomUserPreferencesReadEndpointId];
      final uri = endpoint.resolveUri(
        baseUri,
        parameters: {'key': TomUserPreferenceKeys.theme},
      );

      final http = HttpClient();
      addTearDown(http.close);

      Future<_Answer> get({required bool signedIn}) async {
        final request = await http.openUrl('GET', uri);
        if (signedIn) request.headers.set(_userHeader, '${first.userId}');
        final response = await request.close();
        return _Answer(
          response.statusCode,
          await response.transform(utf8.decoder).join(),
        );
      }

      final miss = await get(signedIn: true);
      expect(miss.statusCode, 404);
      expect(
        miss.reportsAbsence,
        isTrue,
        reason: 'a never-written preference must name the absence key',
      );

      final refusal = await get(signedIn: false);
      expect(refusal.statusCode, 404);
      expect(
        refusal.reportsAbsence,
        isFalse,
        reason: 'a refusal must not read as a preference that is not set',
      );
    });

    test('a write beyond the ceiling answers 409 naming the limit', () async {
      // The store's refusal, carried to the wire by the write endpoint's error
      // handler. Filled with raw rows so that what is under test is the
      // refusal, not 256 writes on the way to it.
      final (first, _, _) = callers();
      final rows = [
        for (var i = 0; i < tomUserPreferencesMaxPerPrincipal; i++)
          "(${first.userId}, 'k$i', 'String', '\"x\"', '2026-01-01 00:00:00')",
      ];
      await dsi.datasource.executeCommand(
        'INSERT INTO tom_user_preference '
        '(principal_id, preference_key, value_type, value_json, updated_at) '
        'VALUES ${rows.join(', ')}',
      );

      final refused = await first.writeEncoded('one.too.many', 'String', '"x"');
      expect(refused.statusCode, 409, reason: refused.body);
      expect(refused.errorKey, tomUserPreferencesLimitExceededErrorKey);

      // Replacing a held key is not a new preference, so it still succeeds.
      final replaced = await first.writeEncoded('k0', 'String', '"y"');
      expect(replaced.statusCode, 200, reason: replaced.body);
    });

    test('an oversized value answers 400, the caller\'s own mistake', () async {
      final (first, _, _) = callers();

      final answer = await first.writeEncoded(
        'ui.notes',
        TomUserPreferenceCodec.stringType,
        jsonEncode('a' * TomUserPreferenceCodec.maxValueBytes),
      );

      expect(answer.statusCode, 400, reason: answer.body);
      expect(answer.errorKey, 'preferences.encoded.too_large');
      expect(await first.keys(), isEmpty);
    });

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
      final body = await response.transform(utf8.decoder).join();

      // What is asserted is *which* refusal, because being refused at all is
      // the weaker claim and the one a broken gate also satisfies. Two things
      // can go wrong here and only one of them is this test's subject: the gate
      // can refuse the caller before the method runs, or the gate can be absent
      // and the handler refuse it afterwards — reaching
      // `TomUserPreferences.all()` and failing in `_requirePrincipal` with
      // `preferences.no_principal`. Both leave the caller with no data, so
      // `isNot(200)` is satisfied by the very state this test exists to
      // exclude.
      //
      // The status separates them. A pre-invocation denial answers a bare `404`
      // — the endpoint is rendered indistinguishable from one that does not
      // exist, so a caller cannot map the deployment's authorization by probing
      // it — while the service failure is caught below by
      // [TomDefaultErrorHandler] and answers `500`. Remove `access:` from the
      // contract and this test fails on the status, which is the point of
      // asserting it.
      //
      // The body carries nothing either way. `access_denied` names the event on
      // the server side, in the audit record and the log; a `404` that
      // explained itself would give back exactly what the `404` withholds.
      expect(response.statusCode, 404);
      expect(response.headers.value('x-tom-error'), isNull);
      expect(body, isNot(contains('access_denied')));
      expect(body, isNot(contains('no_principal')));
    });
  }, skip: skipReason);
}
