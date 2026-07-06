/// Socket-free tests for [AdminApiClient] (step 25): the pure `parse*` functions
/// against captured server-shaped responses, and the typed methods over a
/// path-routing fake [JsonTransport].
///
/// The fixtures mirror the framework wire shape `advanced_auth_server` emits —
/// `tom_core_server`'s endpoint pipeline serializes a list result as a *bare*
/// JSON array of reflected DTO maps (no envelope) and a void result as an empty
/// body. The admin DTOs are reflection-first value records, so the parsers wrap
/// `dtoFromJson<T>` and need the combined domain+contracts seed installed once
/// (`initializeReflection`).
///
/// Stored bearers are synthetic unsigned JWTs (see [_makeJwt]) so
/// `setTokens(..., decrypt: false)` accepts them without RSA.
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(initializeReflection);

  group('AdminApiClient parsers', () {
    test('TC-25-01: parseUsers maps a bare array of user maps', () {
      final users = parseUsers([
        {
          'id': '1',
          'username': 'admin',
          'displayName': 'Administrator',
          'email': 'admin@example.com',
          'status': 'active',
        },
        {
          'id': '2',
          'username': 'alice',
          'displayName': 'Alice',
          'email': 'alice@example.com',
          'status': 'suspended',
        },
      ]);
      expect(users.map((u) => u.id), ['1', '2']);
      expect(users.first.username, 'admin');
      expect(users.first.email, 'admin@example.com');
      expect(users[1].status, 'suspended');
    });

    test('TC-25-02: parseUser tolerates a partial row, keeping DTO defaults',
        () {
      final user = parseUser({'id': '9', 'username': 'bob'});
      expect(user.id, '9');
      expect(user.username, 'bob');
      // Absent fields fall back to the DTO defaults (status → active token).
      expect(user.displayName, '');
      expect(user.email, '');
      expect(user.status, 'active');
    });

    test('TC-25-03: parseRoles maps key/name', () {
      final roles = parseRoles([
        {'key': 'admin', 'name': 'Administrator'},
        {'key': 'user', 'name': 'End User'},
      ]);
      expect(roles.map((r) => r.key), ['admin', 'user']);
      expect(roles.first.name, 'Administrator');
    });

    test('TC-25-04: parseGroups maps id/name/membership', () {
      final groups = parseGroups([
        {
          'id': '3',
          'name': 'Engineering',
          'memberUserIds': ['2', '4'],
        },
      ]);
      final group = groups.single;
      expect(group.id, '3');
      expect(group.name, 'Engineering');
      expect(group.memberUserIds, ['2', '4']);
    });

    test(
        'TC-25-05: parseGrantMatrix maps the role×field matrix (unknown → none)',
        () {
      final matrix = parseGrantMatrix({
        'matrix': {
          'owner': {'todo.item.title': 'full', 'todo.item.status': 'full'},
          'viewer': {
            'todo.item.title': 'read',
            // An unknown access token degrades closed-safe to none.
            'todo.item.status': 'bogus',
          },
        },
      });
      expect(matrix.roles, containsAll(['owner', 'viewer']));
      expect(matrix.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(matrix.accessFor('viewer', 'todo.item.title'), TomAuthState.read);
      expect(matrix.accessFor('viewer', 'todo.item.status'), TomAuthState.none);
      // An unset cell is closed-safe too.
      expect(matrix.accessFor('owner', 'todo.item.dueDate'), TomAuthState.none);
    });
  });

  group('AdminApiClient over a fake transport', () {
    final authBaseUri = Uri.parse('http://localhost:8081');

    setUp(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());
    tearDown(() => TomBearerAuthentication.bearerAuthentication =
        TomBearerAuthentication());

    AdminApiClient clientOver(_RoutingTransport transport) {
      final auth = AuthClient(authBaseUri, transport: transport);
      return AdminApiClient(authBaseUri, AuthorizedHttp(transport, auth));
    }

    void storeAdminBearer() {
      final jwt = _makeJwt({'username': 'admin', 'userId': 1});
      TomBearerAuthentication.setTokens(jwt, jwt, false);
    }

    test('TC-25-06: listUsers sends GET /admin/users with the bearer', () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/users': [
          HttpJsonResponse(200, jsonEncode([_userBody('1'), _userBody('2')])),
        ],
      });
      final client = clientOver(transport);

      final users = await client.listUsers();

      expect(users.map((u) => u.id), ['1', '2']);
      final call = transport.callsTo('/admin/users').single;
      expect(call.method, 'GET');
      expect(call.headers['Authorization'], startsWith('Bearer '));
    });

    test('TC-25-07: createUser POSTs the request JSON and parses the result',
        () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/users': [HttpJsonResponse(201, jsonEncode(_userBody('99')))],
      });
      final client = clientOver(transport);

      final created = await client.createUser(CreateUserRequest(
        username: 'dave',
        password: 'secret',
        displayName: 'Dave',
        email: 'dave@example.com',
      ));

      expect(created.id, '99');
      final call = transport.callsTo('/admin/users').single;
      expect(call.method, 'POST');
      final body = jsonDecode(call.body!) as Map;
      expect(body['username'], 'dave');
      expect(body['password'], 'secret');
    });

    test('TC-25-08: getGrants GETs /admin/grants and parses the matrix',
        () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/grants': [
          HttpJsonResponse(
              200,
              jsonEncode({
                'matrix': {
                  'owner': {'todo.item.title': 'full'},
                  'viewer': {'todo.item.title': 'read'},
                },
              })),
        ],
      });
      final client = clientOver(transport);

      final matrix = await client.getGrants();

      expect(matrix.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(matrix.accessFor('viewer', 'todo.item.title'), TomAuthState.read);
      expect(transport.callsTo('/admin/grants').single.method, 'GET');
    });

    test('TC-25-09: putGrants PUTs the matrix JSON', () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/grants': [HttpJsonResponse(200, '')],
      });
      final client = clientOver(transport);

      final matrix = GrantMatrixDto({
        'editor': {'todo.item.status': TomAuthState.full},
      });
      await client.putGrants(matrix);

      final call = transport.callsTo('/admin/grants').single;
      expect(call.method, 'PUT');
      // The body round-trips back to a matrix with the same cell (closed-safe
      // wire shape); GrantMatrixDto has no value equality, so assert on the cell.
      final sent = dtoFromJson<GrantMatrixDto>(
          jsonDecode(call.body!) as Map<String, Object?>);
      expect(sent.accessFor('editor', 'todo.item.status'), TomAuthState.full);
    });

    test('TC-25-10: assign POSTs the AssignmentRequest to /admin/assignments',
        () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/assignments': [HttpJsonResponse(200, '')],
      });
      final client = clientOver(transport);

      await client.assign(
          AssignmentRequest(userId: '2', roleKey: 'admin'));

      final call = transport.callsTo('/admin/assignments').single;
      expect(call.method, 'POST');
      final body = jsonDecode(call.body!) as Map;
      expect(body['userId'], '2');
      expect(body['roleKey'], 'admin');
    });

    test('TC-25-11: deleteUser DELETEs /admin/users/{id}', () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/users/55': [HttpJsonResponse(200, '')],
      });
      final client = clientOver(transport);

      await client.deleteUser('55');

      expect(transport.callsTo('/admin/users/55').single.method, 'DELETE');
    });

    test('TC-25-12: a 403 raises AdminApiException carrying the server key',
        () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/users': [
          HttpJsonResponse(
              403,
              jsonEncode({
                'error': 'endpoint_handler.handle_method_call.access_denied',
              })),
        ],
      });
      final client = clientOver(transport);

      await expectLater(
        client.listUsers(),
        throwsA(isA<AdminApiException>()
            .having((e) => e.key, 'key',
                'endpoint_handler.handle_method_call.access_denied')
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('TC-25-13: updateRole PUTs /admin/roles/{key} and parses the result',
        () async {
      storeAdminBearer();
      final transport = _RoutingTransport({
        '/admin/roles/editor': [
          HttpJsonResponse(
              200, jsonEncode({'key': 'editor', 'name': 'Editor (renamed)'})),
        ],
      });
      final client = clientOver(transport);

      final role = await client.updateRole(
          'editor', RoleDto(key: 'editor', name: 'Editor (renamed)'));

      expect(role.name, 'Editor (renamed)');
      expect(transport.callsTo('/admin/roles/editor').single.method, 'PUT');
    });
  });
}

/// A `UserDto` wire map (the framework list-serialization shape) carrying [id].
Map<String, Object?> _userBody(String id) => {
      'id': id,
      'username': 'user$id',
      'displayName': 'User $id',
      'email': 'user$id@example.com',
      'status': 'active',
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
