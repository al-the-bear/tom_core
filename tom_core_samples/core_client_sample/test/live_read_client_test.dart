// Tests for the live read path, in two halves.
//
// The pure JSON→entity mapping is split into free functions precisely so it can
// be pinned against captured server responses, with no socket (CCS-LIVE-01..05).
//
// The transport - the four `LiveTodoReadClient` members and the non-200 path -
// runs against a real `HttpServer` bound to the loopback interface on a free
// port, through an injected `HttpClient` (CCS-LIVE-06..11). A loopback server
// rather than a fake client: `HttpClient` is a wide interface, and a fake would
// test the fake's idea of it; the loopback path needs no network and no
// `core_server_sample`.

import 'dart:convert';
import 'dart:io';

import 'package:core_client_sample/api/live_todo_read_client.dart';
import 'package:core_client_sample/reflection_seed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  group('parseAuthState', () {
    test('CCS-LIVE-01: maps a known token to its state', () {
      expect(parseAuthState('full'), TomAuthState.full);
      expect(parseAuthState('disabled'), TomAuthState.disabled);
    });

    test('CCS-LIVE-02: an unknown or absent token degrades to none', () {
      expect(parseAuthState('bogus'), TomAuthState.none);
      expect(parseAuthState(null), TomAuthState.none);
    });
  });

  group('parseTodos', () {
    test('CCS-LIVE-03: maps the JSON array of TodoItemDto to TodoItems', () {
      final todos = parseTodos(const [
        {
          'id': '7',
          'title': 'Wire the endpoint',
          'description': 'GET /todos',
          'done': true,
          'priority': 'high',
          'label': 'feature',
          'assigneeId': '2',
          'dueDate': '2026-01-02T00:00:00.000',
          'listId': '3',
        },
      ]);
      expect(todos, hasLength(1));
      final t = todos.single;
      expect(t.id.get(), '7');
      expect(t.title.get(), 'Wire the endpoint');
      expect(t.done.get(), isTrue);
      expect(t.priority.get(), 'high');
      expect(t.dueDate.get(), DateTime.parse('2026-01-02T00:00:00.000'));
    });

    test('CCS-LIVE-04: tolerates an empty array and partial rows', () {
      expect(parseTodos(const []), isEmpty);
      final todos = parseTodos(const [
        {'id': '1', 'title': 'Bare'},
      ]);
      expect(todos.single.priority.get(), 'medium');
      expect(todos.single.dueDate.get(), isNull);
    });
  });

  group('parseFieldStates', () {
    test('CCS-LIVE-05: maps the per-role/per-field matrix', () {
      final matrix = parseFieldStates(const {
        'states': {
          'owner': {'todo.item.title': 'full', 'todo.item.priority': 'full'},
          'viewer': {'todo.item.title': 'read', 'todo.item.done': 'disabled'},
        },
      });
      expect(matrix['owner']!['todo.item.title'], TomAuthState.full);
      expect(matrix['viewer']!['todo.item.done'], TomAuthState.disabled);
      // Fields absent from the role's block degrade to none.
      expect(matrix['viewer']!['todo.item.priority'], TomAuthState.none);
    });
  });

  group('LiveTodoReadClient over a loopback server', () {
    late HttpServer server;
    late HttpClient client;

    /// What the server answers per path: `(status, JSON body)`.
    late Map<String, (int, Object?)> routes;

    /// The paths the server was asked for, as received.
    late List<String> requested;

    setUp(() async {
      routes = {};
      requested = [];
      client = HttpClient();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        requested.add(request.uri.path);
        final (status, body) =
            routes[request.uri.path] ?? (404, {'error': 'nf'});
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body))
          ..close();
      });
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    String base() => 'http://${server.address.host}:${server.port}';
    LiveTodoReadClient live([String? url]) =>
        LiveTodoReadClient(url ?? base(), httpClient: client);

    test('CCS-LIVE-06: isHealthy is true only for {"status":"ok"}', () async {
      routes['/health'] = (200, {'status': 'ok'});
      expect(await live().isHealthy(), isTrue);
      routes['/health'] = (200, {'status': 'degraded'});
      expect(await live().isHealthy(), isFalse);
      routes['/health'] = (200, <String, Object?>{});
      expect(await live().isHealthy(), isFalse);
    });

    test('CCS-LIVE-07: fetchTodos GETs /todos and parses the array', () async {
      routes['/todos'] = (
        200,
        [
          {'id': '7', 'title': 'Wire the endpoint', 'done': true},
          {'id': '8', 'title': 'Ship it'},
        ],
      );
      final todos = await live().fetchTodos();
      expect(requested, ['/todos']);
      expect(todos.map((t) => t.id.get()), ['7', '8']);
      expect(todos.first.done.get(), isTrue);
    });

    test('CCS-LIVE-08: fetchFieldStates GETs /todos/field-states', () async {
      routes['/todos/field-states'] = (
        200,
        {
          'states': {
            'viewer': {'todo.item.done': 'disabled'},
          },
        },
      );
      final matrix = await live().fetchFieldStates();
      expect(requested, ['/todos/field-states']);
      expect(matrix['viewer']!['todo.item.done'], TomAuthState.disabled);
      expect(matrix['viewer']!['todo.item.title'], TomAuthState.none);
    });

    test(
      'CCS-LIVE-09: a non-200 raises HttpException naming path and status',
      () async {
        routes['/todos'] = (503, {'error': 'down'});
        await expectLater(
          live().fetchTodos(),
          throwsA(
            isA<HttpException>().having(
              (e) => e.message,
              'message',
              allOf(contains('GET /todos'), contains('503')),
            ),
          ),
        );
      },
    );

    test(
      'CCS-LIVE-10: a trailing slash on the base URL is normalised',
      () async {
        // The URL comes from a `--dart-define`, typed by a person; `…:8080/` and
        // `…:8080` must address the same routes, not `//todos`.
        routes['/todos'] = (200, <Object?>[]);
        final slashed = live('${base()}//');
        expect(slashed.baseUrl, base());
        await slashed.fetchTodos();
        expect(requested, ['/todos']);
      },
    );

    test('CCS-LIVE-11: close() closes the injected client', () async {
      routes['/health'] = (200, {'status': 'ok'});
      final c = live();
      expect(await c.isHealthy(), isTrue);
      c.close();
      await expectLater(c.isHealthy(), throwsA(isA<StateError>()));
    });
  });
}
