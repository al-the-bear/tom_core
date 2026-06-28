/// The typed client over `advanced_app_server`'s todo-board API (step 24).
///
/// Every call goes through [AuthorizedHttp] — so the bearer is attached and a
/// single token expiry self-heals (refresh-once-on-401) — and the JSON↔entity
/// mapping is split into the **pure** top-level `parse*` functions so it is
/// unit-tested against captured server responses with no socket (mirroring
/// `core_client_sample`'s `LiveTodoReadClient` discipline).
///
/// **Wire contract.** The app server returns the framework serialization of the
/// service method's result (`tom_core_server`'s endpoint pipeline): a single
/// entity as `entity.toJson()` (≡ `TomClass.getValues()`), a list as a *bare*
/// JSON array of those maps (no `{items:[…]}` envelope), `health()` as a plain
/// object, and the field-state matrix as a bare array of [GradedFieldDto] maps.
/// Date fields travel as the `@!@`-prefixed ISO string and the string-backed
/// enum fields as their `name` token.
///
/// The `parse*` functions map that JSON to entities **field-by-field** (rather
/// than the entity's own `setValues`) on purpose: the kernel's `TomList`
/// deserialization is not currently round-trip-safe — `setValues` on a typed
/// `TomList<TomString>` (e.g. `TodoItem.tags`) throws even for an empty array,
/// and `getValues` emits its elements unconverted so the server cannot
/// `jsonEncode` a non-empty one (both are pre-existing kernel gaps, out of this
/// step's scope — see `step24_app_api_client_decisions.md`). Hand-mapping keeps
/// the client correct regardless and matches `LiveTodoReadClient`'s explicit
/// pure-parser discipline.
///
/// A denial the server maps to `403`/`404` (an `{"error": key}` body, see plan
/// §A.6) surfaces as a typed [AppApiException] carrying that stable key; a
/// persistent `401` was already turned into an `AuthorizedHttpException` by the
/// wrapper before it reaches here.
///
/// Reflection must be initialized (`initializeReflection()` from
/// `advanced_todo_domain`) before any parser runs, since they construct
/// reflected entities — the app bootstrap does this once at startup, and the
/// unit tests do it in `setUpAll`.
library;

import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../http/authorized_http.dart';
import '../http/json_transport.dart';

/// Raised when an app-API call returns a non-success status the wrapper did not
/// already handle (a 401 becomes an `AuthorizedHttpException` upstream).
///
/// Carries the HTTP [statusCode] and the server's stable error [key] from the
/// `{"error": key}` body (e.g. `app.access.forbidden` → 403,
/// `app.item.not_found` → 404), so a UI can branch on the key without parsing a
/// message.
class AppApiException extends TomException {
  /// The HTTP status that triggered this.
  final int statusCode;

  /// Builds the exception from the server's stable [key], a human
  /// [defaultUserMessage] and the originating [statusCode].
  AppApiException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
  });
}

/// Parses one `Workspace` from its `toJson()`/`getValues()` wire map.
Workspace parseWorkspace(Map<String, dynamic> json) => Workspace()
  ..id.set(_str(json['id']))
  ..name.set(_str(json['name']))
  ..ownerId.set(_str(json['ownerId']))
  ..createdAt.set(_date(json['createdAt']));

/// Parses a bare array of workspace maps into [Workspace]s.
List<Workspace> parseWorkspaces(List<Object?> body) =>
    [for (final e in body) parseWorkspace(_asMap(e))];

/// Parses one `Project` from its wire map.
Project parseProject(Map<String, dynamic> json) => Project()
  ..id.set(_str(json['id']))
  ..workspaceId.set(_str(json['workspaceId']))
  ..name.set(_str(json['name']))
  ..description.set(_str(json['description']))
  ..colour.set(_str(json['colour']))
  ..archived.set(json['archived'] == true);

/// Parses a bare array of project maps into [Project]s.
List<Project> parseProjects(List<Object?> body) =>
    [for (final e in body) parseProject(_asMap(e))];

/// Parses one `TodoList` from its wire map.
TodoList parseList(Map<String, dynamic> json) => TodoList()
  ..id.set(_str(json['id']))
  ..projectId.set(_str(json['projectId']))
  ..name.set(_str(json['name']))
  ..position.set(_int(json['position']));

/// Parses a bare array of list maps into [TodoList]s.
List<TodoList> parseLists(List<Object?> body) =>
    [for (final e in body) parseList(_asMap(e))];

/// Parses one `TodoItem` from its wire map. The string-backed enum fields
/// (`status`/`priority`/`label`) arrive as their `name` token (kept verbatim in
/// the string-backed field), the date fields as the `@!@`-prefixed ISO string,
/// and `tags` as a JSON string array.
TodoItem parseItem(Map<String, dynamic> json) {
  final item = TodoItem()
    ..id.set(_str(json['id']))
    ..listId.set(_str(json['listId']))
    ..title.set(_str(json['title']))
    ..description.set(_str(json['description']))
    ..status.set(_str(json['status'], TodoStatus.backlog.name))
    ..priority.set(_str(json['priority'], TodoPriority.medium.name))
    ..label.set(_str(json['label'], TodoLabel.feature.name))
    ..assigneeId.set(_str(json['assigneeId']))
    ..reporterId.set(_str(json['reporterId']))
    ..dueDate.set(_date(json['dueDate']))
    ..createdAt.set(_date(json['createdAt']))
    ..updatedAt.set(_date(json['updatedAt']))
    ..estimateHours.set((json['estimateHours'] as num?)?.toDouble());
  // tags is a typed TomList<TomString>; append element-by-element (the kernel's
  // bulk TomList deserialization is not round-trip-safe — see the library doc).
  for (final tag in (json['tags'] as List<Object?>? ?? const [])) {
    item.tags.add(TomString('$tag'));
  }
  return item;
}

/// Parses a bare array of item maps into [TodoItem]s.
List<TodoItem> parseItems(List<Object?> body) =>
    [for (final e in body) parseItem(_asMap(e))];

/// Parses one `TodoComment` from its wire map.
TodoComment parseComment(Map<String, dynamic> json) => TodoComment()
  ..id.set(_str(json['id']))
  ..itemId.set(_str(json['itemId']))
  ..authorId.set(_str(json['authorId']))
  ..body.set(_str(json['body']))
  ..createdAt.set(_date(json['createdAt']));

/// Parses the `GET /items/{id}/field-states` body — a bare array of
/// [GradedFieldDto] maps (`{resourceKey, access}`) — into the per-field grade
/// list for the current principal. An unknown `access` token degrades to
/// [TomAuthState.none] (closed-safe) via [GradedFieldDto.fromJson].
List<GradedFieldDto> parseFieldStates(List<Object?> body) =>
    [for (final e in body) GradedFieldDto.fromJson(_asObjectMap(e))];

Map<String, dynamic> _asMap(Object? element) =>
    (element as Map).cast<String, dynamic>();

Map<String, Object?> _asObjectMap(Object? element) =>
    (element as Map).cast<String, Object?>();

/// Reads [raw] as a string, falling back to [fallback] (default empty) when it
/// is absent/null — matching the string-backed entity fields' own defaults.
String _str(Object? raw, [String fallback = '']) =>
    raw == null ? fallback : '$raw';

/// Reads [raw] as an int (the wire carries JSON numbers), defaulting to 0.
int _int(Object? raw) => raw is num ? raw.toInt() : 0;

/// Decodes a wire date: the `@!@<iso8601>` form `getValues` emits (the 3-char
/// prefix is trimmed) or a bare ISO string; absent/blank → null.
DateTime? _date(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final iso = raw.startsWith(TomDateTime.serializationPrefix)
      ? raw.substring(TomDateTime.serializationPrefix.length)
      : raw;
  return DateTime.tryParse(iso);
}

/// The typed client over the app server's endpoints (the `appApi` registry).
///
/// Implements [AppApiService] so it is the live seam the app client's backend
/// plugs in (step 26); the in-memory fake implements the same interface for
/// widget tests. All authenticated transport flows through the supplied
/// [AuthorizedHttp].
class AppApiClient implements AppApiService {
  /// Base URL of the app server, e.g. `http://localhost:8080` (no path suffix —
  /// each endpoint adds its own absolute path).
  final Uri baseUri;

  final AuthorizedHttp _http;

  /// Builds the client against [baseUri], sending every call through [http].
  AppApiClient(this.baseUri, AuthorizedHttp http) : _http = http;

  @override
  Future<Map<String, Object>> health() async {
    final response = await _get('/health');
    return {
      for (final entry in response.jsonObject.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  @override
  Future<List<Workspace>> listWorkspaces() async =>
      parseWorkspaces((await _get('/workspaces')).jsonArray);

  @override
  Future<List<Project>> listProjects(String workspaceId) async =>
      parseProjects(
          (await _get('/projects', {'workspaceId': workspaceId})).jsonArray);

  @override
  Future<Project> createProject(Project project) async => parseProject(
        (await _send('POST', '/projects', body: jsonEncode(project.toJson())))
            .jsonObject,
      );

  @override
  Future<List<TodoList>> listLists(String projectId) async =>
      parseLists((await _get('/lists', {'projectId': projectId})).jsonArray);

  @override
  Future<List<TodoItem>> listItems(String listId) async =>
      parseItems((await _get('/items', {'listId': listId})).jsonArray);

  @override
  Future<TodoItem> createItem(TodoItem item) async => parseItem(
        (await _send('POST', '/items', body: jsonEncode(item.toJson())))
            .jsonObject,
      );

  @override
  Future<TodoItem> updateItem(String id, TodoItem item) async => parseItem(
        (await _send('PUT', '/items/$id', body: jsonEncode(item.toJson())))
            .jsonObject,
      );

  @override
  Future<void> deleteItem(String id) async => _send('DELETE', '/items/$id');

  @override
  Future<TodoComment> addComment(String itemId, TodoComment comment) async =>
      parseComment(
        (await _send('POST', '/items/$itemId/comments',
                body: jsonEncode(comment.toJson())))
            .jsonObject,
      );

  @override
  Future<List<GradedFieldDto>> itemFieldStates(String itemId) async =>
      parseFieldStates((await _get('/items/$itemId/field-states')).jsonArray);

  @override
  Future<void> share(ShareRequest request) async =>
      _send('POST', '/share', body: jsonEncode(request.toJson()));

  @override
  Future<void> revokeShare(String id) async => _send('DELETE', '/share/$id');

  Future<HttpJsonResponse> _get(String path,
          [Map<String, String> query = const {}]) =>
      _send('GET', path, query: query);

  /// Sends [method] to [path] (with optional [query]/[body]) through the
  /// authorized transport and returns the response, throwing [AppApiException]
  /// on any non-success status (reading the server's stable error key).
  Future<HttpJsonResponse> _send(
    String method,
    String path, {
    Map<String, String> query = const {},
    String? body,
  }) async {
    final response =
        await _http.send(method: method, uri: _uri(path, query), body: body);
    if (!response.isSuccess) {
      throw AppApiException(
        _errorKey(response) ?? 'app.request.failed',
        'App API $method $path failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  /// Resolves the absolute [path] (and optional [query]) against [baseUri].
  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final base = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(
      path: '$base$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// The server's stable error key from a `{"error": "..."}` body, or null.
  String? _errorKey(HttpJsonResponse response) {
    try {
      final key = response.jsonObject['error'];
      return key is String ? key : null;
    } on FormatException {
      return null;
    }
  }
}
