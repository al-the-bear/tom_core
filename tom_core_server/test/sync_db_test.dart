/// The sync protocol served by a Tom server: the kernel's sync contract run
/// over HTTP against the shipped [TomSyncServer], on a real database, and what
/// a server adds to it — the row scope, ids another principal holds, the
/// endpoints' refusals and the change log's numbering.
///
/// A loopback server carries the real pipeline; the device side is the
/// kernel's [TomHttpSyncTransport] and [TomSyncEngine], so nothing between the
/// device's queue and the `fixture_sync_note` table is a stand-in except the
/// credential, which a header names (as `preferences_roundtrip_db_test.dart`
/// explains).
///
/// The group is `@Tags(['db'])` and skips itself when no database is
/// reachable. `tool/run_db_tests.sh` runs it on MariaDB,
/// `tool/run_db_tests_postgres.sh` on PostgreSQL.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../../tom_core_kernel/test/contracts/sync_protocol_contract.dart';
import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The header a caller names its signed-in user with.
const String _userHeader = 'x-test-user';

TomPrincipal _principalWithId(int userId) => TomPrincipal(
  authenticated: true,
  context: {},
  clientId: 0,
  organization: 'acme',
  organizationId: 0,
  application: 'notes',
  applicationId: 0,
  process: 'sync',
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

/// Runs [body] as user [userId], as a request of that user would.
Future<R> _as<R>(int userId, Future<R> Function() body) =>
    runZoned(body, zoneValues: {TomPrincipal: _principalWithId(userId)});

Middleware _signedInByHeader() =>
    (innerHandler) => (request) {
      final id = int.tryParse(request.headers[_userHeader] ?? '');
      if (id == null) return innerHandler(request);
      return runZoned<FutureOr<Response>>(
        () => innerHandler(request),
        zoneValues: {TomPrincipal: _principalWithId(id)},
      );
    };

class _NoopConfig extends TomBaseServerConfiguration {
  _NoopConfig() : super([]);
  @override
  void setValues(Map<String, Object?> values) {}
}

/// Renders an escaping error the way a deployed server does — see
/// `preferences_roundtrip_db_test.dart`.
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

/// The note entity behind a repository whose key type is not one a device
/// can name.
class _ObjectKeyedNotes
    extends TomSqlDatasourceRepository<FixtureSyncNote, Object> {}

/// Stamps a new note with its creator, as an application stamps the scope
/// field a device never sends.
class _StampOwner extends TomEntityListener<FixtureSyncNote> {
  @override
  void beforeSave(FixtureSyncNote entity, {required bool insert}) {
    if (insert) {
      entity.ownerId = getFromCurrentZone<TomPrincipal>()!.qualifiedId;
    }
  }
}

/// The server as the sync contract drives it: the device is user 41 over
/// HTTP, and "another client" is a write of user 41 through the repository.
class _TomServerUnderTest implements TomSyncContractServer {
  _TomServerUnderTest(Uri baseUri, {int userId = 41})
    : transport = TomHttpSyncTransport(
        baseUri: baseUri,
        headers: () => {_userHeader: '$userId'},
      );

  final FixtureSyncNoteRepository notes = FixtureSyncNoteRepository();

  @override
  final TomSyncTransport transport;

  @override
  Future<int> put(String id, String text) => _as(41, () async {
    final held = await notes.findById(id);
    final stored = held == null
        ? await notes.insert(
            FixtureSyncNote()
              ..id = id
              ..text = text,
          )
        : await notes.save(held..text = text);
    return stored.version!;
  });

  @override
  Future<void> remove(String id) => _as(41, () async {
    final held = await notes.findById(id);
    if (held != null) await notes.delete(held);
  });

  @override
  Future<({String text, int version})?> note(String id) => _as(41, () async {
    final held = await notes.findById(id);
    return held == null ? null : (text: held.text!, version: held.version!);
  });
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('a Tom server', () {
    late TomDataSourceInfo dsi;
    late HttpServer server;
    late Uri baseUri;
    late void Function() removeStamp;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureSyncNoteTable(dsi);
      TomSync.reset();
      await TomSync.expose(
        'notes',
        FixtureSyncNoteRepository(),
        validate: (data) =>
            ((data['text'] as String?) ?? '').isEmpty ? 'text.required' : null,
      );
      removeStamp = TomEntityLifecycle.register<FixtureSyncNote>(_StampOwner());

      TomBean.resetBeanContext();
      registerFixtureAccessApi();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      final router = TomEndpointRouting().initializeRouter();
      final handler = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware('sync', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addMiddleware(_signedInByHeader())
          .addMiddleware(_rendersErrorsLikeTheServer())
          .addHandler(router.call);
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    });

    setUp(() => TestDatabase.truncateFixtureSyncNote(dsi));

    tearDownAll(() async {
      await server.close(force: true);
      removeStamp();
      TomSync.reset();
      TomBean.resetBeanContext();
      await TestDatabase.reset();
    });

    runTomSyncContract(
      'a Tom server over HTTP on ${TestDatabase.engine}',
      () async => _TomServerUnderTest(baseUri),
    );

    group('refusals', () {
      Future<String?> keyOf(Future<Object?> Function() action) async {
        try {
          await action();
        } on TomSyncException catch (refused) {
          return refused.key;
        }
        return null;
      }

      test('an entity without a version, a second exposure and a key that is '
          'neither String nor int are refused', () async {
        expect(
          await keyOf(() => TomSync.expose('tasks', FixtureTaskRepository())),
          'sync.expose.unversioned',
        );
        expect(
          await keyOf(
            () => TomSync.expose('notes', FixtureSyncNoteRepository()),
          ),
          'sync.expose.duplicate',
        );
        expect(
          await keyOf(() => TomSync.expose('other', _ObjectKeyedNotes())),
          'sync.expose.key',
        );
      });

      test(
        'a pull with a negative cursor or a limit below one is refused',
        () async {
          expect(
            await keyOf(() => TomSync.pull('notes', -1)),
            'sync.pull.invalid',
          );
          expect(
            await keyOf(() => TomSync.pull('notes', 0, limit: 0)),
            'sync.pull.invalid',
          );
        },
      );
    });

    group('beyond the contract', () {
      Future<TomSyncReport> syncAs(int userId, TomOfflineStore store) =>
          TomSyncEngine(
            store: store,
            transport: _TomServerUnderTest(baseUri, userId: userId).transport,
            collections: ['notes'],
          ).sync();

      TomOfflineStore device() => TomOfflineStore(TomMemoryLocalStoreEngine());

      test('a device pulls only the notes its principal may read, and a '
          'deletion reaches every device', () async {
        final server41 = _TomServerUnderTest(baseUri);
        await server41.put('mine', 'of user 41');
        final other = device();
        final report = await syncAs(42, other);
        expect(report.pulled['notes'], 0);
        expect(await other.meta('cursor:notes'), 1, reason: 'still advanced');

        await server41.remove('mine');
        final after = await syncAs(42, other);
        expect(after.pulled['notes'], 1);
      });

      test(
        'a creation under an id another principal holds is rejected',
        () async {
          await _TomServerUnderTest(baseUri).put('shared-id', 'of user 41');
          final results = await _TomServerUnderTest(baseUri, userId: 42)
              .transport
              .push([
                TomPendingChange(
                  changeId: 'c1',
                  collection: 'notes',
                  id: 'shared-id',
                  operation: TomChangeOperation.save,
                  data: {'id': 'shared-id', 'text': 'of user 42'},
                  queuedAt: DateTime.now(),
                ),
              ]);
          expect(results.single.outcome, TomPushOutcome.rejected);
          expect(results.single.reason, 'sync.id.taken');
          expect(results.single.serverData, isNull);
        },
      );

      test('a change of a collection the server does not sync is rejected, '
          'and a pull of one refused', () async {
        final transport = _TomServerUnderTest(baseUri).transport;
        final results = await transport.push([
          TomPendingChange(
            changeId: 'c1',
            collection: 'tasks',
            id: 't1',
            operation: TomChangeOperation.save,
            data: {'id': 't1'},
            queuedAt: DateTime.now(),
          ),
        ]);
        expect(results.single.reason, tomSyncUnknownCollectionErrorKey);
        await expectLater(
          transport.pull('tasks', 0),
          throwsA(
            isA<TomOfflineException>()
                .having((e) => e.parameters!['status'], 'status', 400)
                .having(
                  (e) => e.parameters!['errorKey'],
                  'errorKey',
                  tomSyncUnknownCollectionErrorKey,
                ),
          ),
        );
      });

      test('an anonymous caller is refused', () async {
        final client = HttpClient();
        addTearDown(client.close);
        final request = await client.postUrl(
          tomSyncApi[tomSyncPullEndpointId].resolveUri(baseUri),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'collection': 'notes'}));
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, isNot(200));
      });

      test('every write numbers its change in the collection, one after '
          'another', () async {
        final server41 = _TomServerUnderTest(baseUri);
        await Future.wait([
          for (var i = 0; i < 8; i++) server41.put('n$i', 'note $i'),
        ]);
        final batch = await server41.transport.pull('notes', 0);
        expect(
          [for (final c in batch.changes) c.sequence],
          [for (var i = 1; i <= 8; i++) i],
        );
      });
    });
  }, skip: skipReason);
}
