/// Socket-free tests for [AppApiClient] (step 24): the pure `parse*` functions
/// against captured server-shaped responses, and the typed methods over a
/// path-routing fake [JsonTransport].
///
/// The fixtures mirror the framework wire shape `advanced_app_server` emits —
/// `tom_core_server`'s endpoint pipeline serializes a single entity as
/// `entity.toJson()`/`getValues()` and a list as a *bare* JSON array of those
/// maps, with date fields carrying the `@!@` prefix and the string-backed enum
/// fields as their `name` token. The parsers are the symmetric inverse
/// (`entity.setValues`), so a captured row round-trips field-for-field.
///
/// Reflection is initialized once in [setUpAll] — via the client core's combined
/// domain+contracts seed — because every parser constructs either a reflected
/// entity or a reflection-first DTO. Stored bearers are synthetic unsigned JWTs
/// (see [_makeJwt]) so `setTokens(..., decrypt: false)` accepts them without RSA.
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(initializeReflection);

  group('AppApiClient parsers', () {
    test('TC-24-01: parseWorkspaces maps a bare array of workspace maps', () {
      final workspaces = parseWorkspaces([
        {'id': '1', 'name': 'Acme Engineering', 'ownerId': '2'},
        {'id': '2', 'name': 'Personal', 'ownerId': '2'},
      ]);
      expect(workspaces.map((w) => w.id.get()), ['1', '2']);
      expect(workspaces.first.name.get(), 'Acme Engineering');
      expect(workspaces.first.ownerId.get(), '2');
    });

    test('TC-24-02: parseProjects maps id/workspaceId/archived', () {
      final projects = parseProjects([
        {
          'id': '7',
          'workspaceId': '1',
          'name': 'Website relaunch',
          'description': 'Q3 push',
          'colour': '#3366FF',
          'archived': true,
        },
      ]);
      final p = projects.single;
      expect(p.id.get(), '7');
      expect(p.workspaceId.get(), '1');
      expect(p.colour.get(), '#3366FF');
      expect(p.archived.get(), isTrue);
    });

    test('TC-24-03: parseLists maps the position ordering field', () {
      final lists = parseLists([
        {'id': '3', 'projectId': '7', 'name': 'Sprint backlog', 'position': 2},
      ]);
      expect(lists.single.position.get(), 2);
      expect(lists.single.name.get(), 'Sprint backlog');
    });

    test(
        'TC-24-04: parseItems decodes enum tokens, the @!@ date prefix and tags',
        () {
      final items = parseItems([
        {
          'id': '11',
          'listId': '3',
          'title': 'Wire the endpoint',
          'description': 'GET /items',
          'status': TodoStatus.inProgress.name,
          'priority': TodoPriority.high.name,
          'label': TodoLabel.bug.name,
          'assigneeId': '2',
          'reporterId': '5',
          'dueDate': '${TomDateTime.serializationPrefix}2026-07-01T09:00:00.000',
          'estimateHours': 4.5,
          'tags': ['backend', 'urgent'],
        },
      ]);
      final item = items.single;
      expect(item.id.get(), '11');
      expect(item.statusValue, TodoStatus.inProgress);
      expect(item.priorityValue, TodoPriority.high);
      expect(item.labelValue, TodoLabel.bug);
      expect(item.dueDate.get(), DateTime.parse('2026-07-01T09:00:00.000'));
      expect(item.estimateHours.get(), 4.5);
      expect([for (final t in item.tags.get()) t.get()], ['backend', 'urgent']);
    });

    test('TC-24-05: parseItems tolerates a partial row, keeping field defaults',
        () {
      expect(parseItems(const []), isEmpty);
      final item = parseItems([
        {'id': '1', 'title': 'Bare'},
      ]).single;
      // Untouched fields keep the entity's constructor defaults.
      expect(item.statusValue, TodoStatus.backlog);
      expect(item.priorityValue, TodoPriority.medium);
      expect(item.dueDate.get(), isNull);
    });

    test('TC-24-06: parseComment maps the thread entry', () {
      final comment = parseComment({
        'id': '90',
        'itemId': '11',
        'authorId': '2',
        'body': 'Looks good to me',
      });
      expect(comment.itemId.get(), '11');
      expect(comment.authorId.get(), '2');
      expect(comment.body.get(), 'Looks good to me');
    });

    test('TC-24-07: parseFieldStates maps the per-field grade array', () {
      final states = parseFieldStates([
        {'resourceKey': 'todo.item.title', 'access': TomAuthState.full.name},
        {'resourceKey': 'todo.item.priority', 'access': TomAuthState.read.name},
        // An unknown access token degrades to none (closed-safe).
        {'resourceKey': 'todo.item.assigneeId', 'access': 'bogus'},
      ]);
      expect(states, hasLength(3));
      expect(states[0].resourceKey, 'todo.item.title');
      expect(states[0].accessState, TomAuthState.full);
      expect(states[1].accessState, TomAuthState.read);
      expect(states[2].accessState, TomAuthState.none);
    });
  });

  group('AppApiClient over a fake transport', () {
    final appBaseUri = Uri.parse('http://localhost:8080');
    final authBaseUri = Uri.parse('http://localhost:8081');

    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    AppApiClient clientOver(_RoutingTransport transport) {
      final auth = AuthClient(authBaseUri, transport: transport);
      return AppApiClient(appBaseUri, AuthorizedHttp(transport, auth));
    }

    void storeBearer() {
      final jwt = _makeJwt({'username': 'alice', 'userId': 2});
      TomBearerAuthentication.setTokens(jwt, jwt, false);
    }

    test('TC-24-08: listItems sends GET /items?listId= with the bearer', () async {
      storeBearer();
      final transport = _RoutingTransport({
        '/items': [
          HttpJsonResponse(200, jsonEncode([_itemBody('11'), _itemBody('12')])),
        ],
      });
      final client = clientOver(transport);

      final items = await client.listItems('3');

      expect(items.map((i) => i.id.get()), ['11', '12']);
      final call = transport.callsTo('/items').single;
      expect(call.method, 'GET');
      expect(call.uri.queryParameters['listId'], '3');
      expect(call.headers['Authorization'], startsWith('Bearer '));
    });

    test('TC-24-09: createItem POSTs the entity JSON and parses the result',
        () async {
      storeBearer();
      final transport = _RoutingTransport({
        '/items': [HttpJsonResponse(201, jsonEncode(_itemBody('99')))],
      });
      final client = clientOver(transport);

      final created =
          await client.createItem(TodoItem()..title.set('New task'));

      expect(created.id.get(), '99');
      final call = transport.callsTo('/items').single;
      expect(call.method, 'POST');
      expect((jsonDecode(call.body!) as Map)['title'], 'New task');
    });

    test('TC-24-10: health() reads the public status object', () async {
      final transport = _RoutingTransport({
        // `/status`, not `/health`: the app's typed status endpoint avoids the
        // framework's plain-text `/health` liveness probe.
        '/status': [
          HttpJsonResponse(
              200, jsonEncode({'status': 'ok', 'service': 'advanced_app_server'})),
        ],
      });
      final client = clientOver(transport);

      final health = await client.health();

      expect(health['status'], 'ok');
      expect(health['service'], 'advanced_app_server');
    });

    test('TC-24-11: a 403 raises AppApiException carrying the server key',
        () async {
      storeBearer();
      final transport = _RoutingTransport({
        '/items': [
          HttpJsonResponse(403, jsonEncode({'error': 'app.access.forbidden'})),
        ],
      });
      final client = clientOver(transport);

      await expectLater(
        client.listItems('3'),
        throwsA(isA<AppApiException>()
            .having((e) => e.key, 'key', 'app.access.forbidden')
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('TC-24-12: a 404 on delete raises AppApiException (not_found)',
        () async {
      storeBearer();
      final transport = _RoutingTransport({
        '/items/55': [
          HttpJsonResponse(404, jsonEncode({'error': 'app.item.not_found'})),
        ],
      });
      final client = clientOver(transport);

      await expectLater(
        client.deleteItem('55'),
        throwsA(isA<AppApiException>()
            .having((e) => e.key, 'key', 'app.item.not_found')
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('TC-24-13: itemFieldStates GETs the per-item field-state array',
        () async {
      storeBearer();
      final transport = _RoutingTransport({
        '/items/11/field-states': [
          HttpJsonResponse(
              200,
              jsonEncode([
                {'resourceKey': 'todo.item.title', 'access': 'full'},
                {'resourceKey': 'todo.item.priority', 'access': 'read'},
              ])),
        ],
      });
      final client = clientOver(transport);

      final states = await client.itemFieldStates('11');

      expect(states.map((s) => s.resourceKey),
          ['todo.item.title', 'todo.item.priority']);
      expect(transport.callsTo('/items/11/field-states').single.method, 'GET');
    });
  });
}

/// A `TodoItem` wire map (the framework `getValues()` shape) carrying [id].
Map<String, Object?> _itemBody(String id) => {
      'id': id,
      'listId': '3',
      'title': 'Item $id',
      'status': TodoStatus.backlog.name,
      'priority': TodoPriority.medium.name,
      'label': TodoLabel.feature.name,
    };

/// Builds an unsigned, undecrypted JWT whose middle segment carries [payload].
/// Suitable for `setTokens(..., decrypt: false)`.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = {'alg': 'HS256', 'typ': 'JWT'};
  return '${seg(header)}.${seg(payload)}.sig';
}

/// One captured transport call, so a test can assert what the client sent.
class _Call {
  _Call(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

/// A [JsonTransport] that records every call and replays canned responses from a
/// per-`uri.path` queue.
class _RoutingTransport implements JsonTransport {
  _RoutingTransport(this._queues);
  final Map<String, List<HttpJsonResponse>> _queues;
  final List<_Call> calls = [];
  final Map<String, int> _idx = {};

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    calls.add(_Call(method, uri, headers, body));
    final queue = _queues[uri.path];
    if (queue == null) {
      throw StateError('no canned response queued for ${uri.path}');
    }
    final i = _idx[uri.path] ?? 0;
    _idx[uri.path] = i + 1;
    return queue[i];
  }

  /// The recorded calls whose path equals [path], in order.
  List<_Call> callsTo(String path) =>
      calls.where((c) => c.uri.path == path).toList();
}
