/// The client core addresses every call through the contracts registry.
///
/// Each endpoint's route, method and URL parameters are declared once, in
/// `advanced_todo_contracts`' `authApi` / `adminApi` / `appApi`, and the servers
/// bind to that declaration by API id. A client that spelled its paths as
/// literals agreed with the servers only by inspection: rename a route in the
/// registry and both servers move while every client call keeps addressing the
/// old one — and a fake transport that asserts the same literals the client
/// sends would stay green.
///
/// So this suite does what that renaming does. For each endpoint it swaps the
/// registry's declaration for one at a *moved* route (same method, same
/// captures, same parameter mapping), calls the client method that uses it,
/// and requires the request to arrive at the moved route with the declared
/// method. A client that builds the URL from the declaration passes; one that
/// spells it fails, naming the endpoint.
///
/// The transport records the request and then throws, so no response has to be
/// canned: what is under test is the address, not the parsing.
library;

import 'dart:convert';

import 'package:advanced_client_core/advanced_client_core.dart';
import 'package:advanced_client_core/reflection_seed.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

final _base = Uri.parse('http://localhost:9999');

/// One request the transport saw.
class _Request {
  _Request(this.method, this.uri);
  final String method;
  final Uri uri;
}

/// Thrown by the transport once it has recorded the request.
class _Stop implements Exception {}

/// Records each request, then throws [_Stop].
class _RecordingTransport implements JsonTransport {
  final List<_Request> requests = [];

  @override
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    requests.add(_Request(method, uri));
    throw _Stop();
  }
}

/// The three clients over one recording transport.
class _Clients {
  _Clients() {
    auth = AuthClient(_base, transport: transport);
    final http = AuthorizedHttp(transport, auth);
    app = AppApiClient(_base, http);
    admin = AdminApiClient(_base, http);
  }

  final transport = _RecordingTransport();
  late final AuthClient auth;
  late final AppApiClient app;
  late final AdminApiClient admin;
}

/// A synthetic unsigned token, so calls that require a stored session run.
String _jwt() {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${seg({'exp': 4102444800, 'sub': '1'})}.sig';
}

TodoItem _item() => TodoItem()
  ..id.set('11')
  ..listId.set('3')
  ..title.set('t');

/// Every registry endpoint the client core calls, keyed by `api/endpoint`, with
/// the call and the parameters its URL is built from.
///
/// The parameters are what the client holds when it makes the call, keyed by
/// request-DTO field name — the same map `TomApiEndpoint.resolveUri` takes.
final Map<String, (Future<Object?> Function(_Clients), Map<String, Object?>)>
_calls = {
  'auth/authLogin': (
    (c) => c.auth.login(LoginRequest(username: 'u', password: 'p')),
    const {},
  ),
  'auth/authSecondFactor': ((c) => c.auth.submitSecondFactor('1'), const {}),
  'auth/authBeginEnrolment': ((c) => c.auth.beginEnrolment('totp'), const {}),
  'auth/authConfirmEnrolment': ((c) => c.auth.confirmEnrolment('1'), const {}),
  'auth/authSkipEnrolment': ((c) => c.auth.skipEnrolment(), const {}),
  'auth/authLoginResources': ((c) => c.auth.loginResources(), const {}),
  'auth/authRefresh': ((c) => c.auth.refresh(), const {}),
  'auth/authLogout': ((c) => c.auth.logout(), const {}),
  'admin/adminListUsers': ((c) => c.admin.listUsers(), const {}),
  'admin/adminCreateUser': (
    (c) => c.admin.createUser(
      CreateUserRequest(username: 'u', password: 'p', displayName: 'U'),
    ),
    const {},
  ),
  'admin/adminUpdateUser': (
    (c) => c.admin.updateUser(UserDto(id: '1', username: 'u')),
    const {},
  ),
  'admin/adminDeleteUser': (
    (c) => c.admin.deleteUser(EntityIdRequest(id: '5')),
    const {'id': '5'},
  ),
  'admin/adminListRoles': ((c) => c.admin.listRoles(), const {}),
  'admin/adminCreateRole': (
    (c) => c.admin.createRole(RoleDto(key: 'r')),
    const {},
  ),
  'admin/adminUpdateRole': (
    (c) => c.admin.updateRole(RoleDto(key: 'r')),
    const {},
  ),
  'admin/adminDeleteRole': (
    (c) => c.admin.deleteRole(EntityIdRequest(id: 'editor')),
    const {'id': 'editor'},
  ),
  'admin/adminListGroups': ((c) => c.admin.listGroups(), const {}),
  'admin/adminCreateGroup': (
    (c) => c.admin.createGroup(GroupDto(id: 'g')),
    const {},
  ),
  'admin/adminUpdateGroup': (
    (c) => c.admin.updateGroup(GroupDto(id: 'g')),
    const {},
  ),
  'admin/adminDeleteGroup': (
    (c) => c.admin.deleteGroup(EntityIdRequest(id: 'g')),
    const {'id': 'g'},
  ),
  'admin/adminGetGrants': ((c) => c.admin.getGrants(), const {}),
  'admin/adminPutGrants': (
    (c) => c.admin.putGrants(GrantMatrixDto()),
    const {},
  ),
  'admin/adminAssign': (
    (c) => c.admin.assign(AssignmentRequest(userId: '1')),
    const {},
  ),
  'admin/adminResources': ((c) => c.admin.resources(), const {}),
  'app/appHealth': ((c) => c.app.health(), const {}),
  'app/appListWorkspaces': ((c) => c.app.listWorkspaces(), const {}),
  'app/appCreateWorkspace': (
    (c) => c.app.createWorkspace(Workspace()..name.set('w')),
    const {},
  ),
  'app/appUpdateWorkspace': (
    (c) => c.app.updateWorkspace(Workspace()..id.set('1')),
    const {},
  ),
  'app/appDeleteWorkspace': (
    (c) => c.app.deleteWorkspace(EntityIdRequest(id: '1')),
    const {'id': '1'},
  ),
  'app/appListProjects': (
    (c) => c.app.listProjects('4'),
    const {'workspaceId': '4'},
  ),
  'app/appCreateProject': (
    (c) => c.app.createProject(Project()..name.set('p')),
    const {},
  ),
  'app/appListLists': ((c) => c.app.listLists('7'), const {'projectId': '7'}),
  'app/appListItems': ((c) => c.app.listItems('3'), const {'listId': '3'}),
  'app/appListAttachments': (
    (c) => c.app.listAttachments('3'),
    const {'listId': '3'},
  ),
  'app/appCreateItem': ((c) => c.app.createItem(_item()), const {}),
  'app/appUpdateItem': ((c) => c.app.updateItem(_item()), const {}),
  'app/appDeleteItem': (
    (c) => c.app.deleteItem(EntityIdRequest(id: '11')),
    const {'id': '11'},
  ),
  'app/appAddComment': (
    (c) => c.app.addComment(
      TodoComment()
        ..itemId.set('11')
        ..body.set('b'),
    ),
    const {'itemId': '11'},
  ),
  'app/appListComments': (
    (c) => c.app.listComments(EntityIdRequest(id: '11')),
    const {'id': '11'},
  ),
  'app/appListSubtasks': (
    (c) => c.app.listSubtasks(EntityIdRequest(id: '11')),
    const {'id': '11'},
  ),
  'app/appAddSubtask': (
    (c) => c.app.addSubtask(
      Subtask()
        ..itemId.set('11')
        ..title.set('s'),
    ),
    const {'itemId': '11'},
  ),
  'app/appUpdateSubtask': (
    (c) => c.app.updateSubtask(
      Subtask()
        ..id.set('2')
        ..itemId.set('11'),
    ),
    const {},
  ),
  'app/appShare': (
    (c) => c.app.share(
      ShareRequest(
        resourceType: 'project',
        resourceId: '7',
        granteeUserId: '3',
      ),
    ),
    const {},
  ),
  'app/appRevokeShare': ((c) => c.app.revokeShare('9'), const {'id': '9'}),
  'app/appResources': ((c) => c.app.resources(), const {}),
  'app/appResourceRoles': ((c) => c.app.resourceRoles(), const {}),
};

/// Registry endpoints the client core deliberately does not call, and why.
const Map<String, String> _notCalled = {
  'auth/authMe':
      'the clients read the signed-in user from the login result and the '
      "token's claims; nothing in the client core asks the server who it is",
};

List<TomApi> get _apis => [authApi, adminApi, appApi];

void main() {
  setUpAll(() {
    initializeReflection();
    registerAdvancedTodoApis();
  });
  setUp(() {
    TomBearerAuthentication.clearTokens();
    TomBearerAuthentication.setTokens(_jwt(), _jwt(), false);
  });
  tearDown(TomBearerAuthentication.clearTokens);

  test('RR-1: every registry endpoint is either called or excused', () {
    final declared = {
      for (final api in _apis)
        for (final id in api.endpoints.keys) '${api.id}/$id',
    };
    final accounted = {..._calls.keys, ..._notCalled.keys};
    expect(
      declared.difference(accounted),
      isEmpty,
      reason:
          'registry endpoints this suite neither exercises nor excuses — add '
          'the client call to _calls, or the reason it has none to _notCalled',
    );
    expect(
      accounted.difference(declared),
      isEmpty,
      reason: 'entries naming an endpoint the registry no longer declares',
    );
  });

  group('RR-2: a moved route moves the client call', () {
    for (final entry in _calls.entries) {
      test(entry.key, () async {
        final [apiId, endpointId] = entry.key.split('/');
        final api = _apis.singleWhere((a) => a.id == apiId);
        final original = api[endpointId];
        // The same declaration at a different route: a prefix segment the real
        // registry never uses, so a literal in the client cannot match it.
        final moved = TomApiEndpoint<Object?, Object?>(
          id: original.id,
          uri: '/moved${original.uri ?? ''}',
          method: original.method,
          urlParameterMapping: original.urlParameterMapping,
          requestTypes: const [],
        );
        api[endpointId] = moved;
        addTearDown(() => api[endpointId] = original);

        final clients = _Clients();
        final (call, parameters) = entry.value;
        try {
          await call(clients);
        } on _Stop {
          // The expected end: the request was recorded.
        } on Object catch (e) {
          // A client may wrap the transport's exception; the recording is
          // what is checked, below.
          if (clients.transport.requests.isEmpty) rethrow;
          expect(e, isNot(isA<TomEndpointException>()));
        }

        final sent = clients.transport.requests;
        expect(sent, hasLength(1), reason: '${entry.key} sent no request');
        final expected = moved.resolveUri(_base, parameters: parameters);
        expect(
          sent.single.uri,
          expected,
          reason:
              '${entry.key} did not follow its declaration to '
              '${moved.uri}: the client spells the route itself',
        );
        expect(sent.single.method, original.method.name);
      });
    }
  });
}
