/// The live read path: a thin HTTP client over `core_server_sample`'s three
/// public `GET` endpoints.
///
/// `core_server_sample` exposes a read-only surface — `GET /health`,
/// `GET /todos`, and `GET /todos/field-states` — so this client demonstrates a
/// genuine wire round-trip against the running backend without pretending the
/// server has write/auth endpoints it does not. Staying read-only is a teaching
/// choice, not an unfinished one — it keeps this pair small enough to read in
/// one sitting. The live login/write loop is a separate series: the advanced
/// full-stack suite, mapped by `README_advanced_sample.md`, which adds bearer
/// tokens, write endpoints and per-principal field grading over the wire. The
/// app's CRUD and login run through [InMemoryTodoApi]; this client is offered as
/// a "refresh from the live server" action and is the honest live-tier seam.
///
/// The wire shapes are the **reflection-first DTOs** (G-DTO): `/todos` a JSON
/// array of [TodoItemDto], `/todos/field-states` a [TodoFieldMatrixDto]. The
/// JSON→entity mapping is split into the pure [parseTodos] / [parseFieldStates]
/// functions — each deserializes through the kernel reflection path
/// ([dtoFromJson]) and then maps into the observable form entities — so it is
/// unit-tested against captured server responses, with no socket in the test.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

import 'todo_api.dart';

/// Parses a [TomAuthState] from its stored [TomAuthState.name] token; an
/// unknown or absent token degrades to [TomAuthState.none] (the closed-safe
/// default), matching the server-side codec.
TomAuthState parseAuthState(String? token) =>
    TodoFieldMatrixDto.parseState(token);

/// Maps the `GET /todos` body (a JSON array of [TodoItemDto]) to [TodoItem]s.
///
/// Each element is deserialized into a [TodoItemDto] through reflection, then
/// projected into the observable form entity. Priority/label arrive as the
/// enum's name (the server stores them that way); an empty token falls back to
/// the domain default.
List<TodoItem> parseTodos(List<Object?> body) => [
      for (final element in body)
        _dtoToItem(dtoFromJson<TodoItemDto>(_asMap(element))),
    ];

/// Maps the `GET /todos/field-states` body (`{ states: { role: { key: token } } }`)
/// to a per-role, per-field [TomAuthState] matrix.
///
/// The body deserializes into a [TodoFieldMatrixDto]; each role is expanded to
/// the full gradable-field vocabulary, so a field absent from a role's block
/// degrades to [TomAuthState.none] (closed-safe).
Map<String, Map<String, TomAuthState>> parseFieldStates(
    Map<String, dynamic> body) {
  final matrix = dtoFromJson<TodoFieldMatrixDto>(body.cast<String, Object?>());
  return {
    for (final role in matrix.roles)
      role: {
        for (final key in gradableItemKeys) key: matrix.accessFor(role, key),
      },
  };
}

TodoItem _dtoToItem(TodoItemDto dto) => TodoItem()
  ..id.set(dto.id)
  ..title.set(dto.title)
  ..description.set(dto.description)
  ..done.set(dto.done)
  ..priority.set(dto.priority.isEmpty ? TodoPriority.medium.name : dto.priority)
  ..label.set(dto.label.isEmpty ? TodoLabel.feature.name : dto.label)
  ..assigneeId.set(dto.assigneeId)
  ..dueDate.set(dto.dueDate.isEmpty ? null : DateTime.tryParse(dto.dueDate));

Map<String, Object?> _asMap(Object? raw) =>
    (raw as Map).cast<String, Object?>();

/// A minimal HTTP client for `core_server_sample`'s read endpoints.
class LiveTodoReadClient {
  /// Creates a client against [baseUrl] (e.g. `http://localhost:8080`).
  LiveTodoReadClient(this.baseUrl, {HttpClient? httpClient})
      : _client = httpClient ?? HttpClient();

  /// The server's base URL, without a trailing slash.
  final String baseUrl;
  final HttpClient _client;

  /// `GET /health` — true when the server answers `{ "status": "ok" }`.
  Future<bool> isHealthy() async {
    final body = await _getJson('/health');
    return body['status'] == 'ok';
  }

  /// `GET /todos` — the persisted items (a JSON array of [TodoItemDto]), mapped
  /// through [parseTodos].
  Future<List<TodoItem>> fetchTodos() async =>
      parseTodos(await _getJsonArray('/todos'));

  /// `GET /todos/field-states` — the four-state matrix, via [parseFieldStates].
  Future<Map<String, Map<String, TomAuthState>>> fetchFieldStates() async =>
      parseFieldStates(await _getJson('/todos/field-states'));

  /// Releases the underlying HTTP client.
  void close() => _client.close(force: true);

  Future<Map<String, dynamic>> _getJson(String path) async =>
      await _getBody(path) as Map<String, dynamic>;

  Future<List<Object?>> _getJsonArray(String path) async =>
      (await _getBody(path) as List).cast<Object?>();

  Future<Object?> _getBody(String path) async {
    final request = await _client.getUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GET $path failed (${response.statusCode})');
    }
    return json.decode(text);
  }
}
