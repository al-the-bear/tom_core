/// The live read path: a thin HTTP client over `core_server_sample`'s three
/// public `GET` endpoints.
///
/// `core_server_sample` today exposes a read-only surface — `GET /health`,
/// `GET /todos`, and `GET /todos/field-states` — so this client demonstrates a
/// genuine wire round-trip against the running backend without pretending the
/// server has write/auth endpoints it does not (those are the cross-tier item
/// 28 work). The app's CRUD and login still run through [InMemoryTodoApi]; this
/// client is offered as a "refresh from the live server" action and is the
/// honest live-tier seam.
///
/// The JSON→entity mapping is split into the pure [parseTodos] /
/// [parseFieldStates] functions so it is unit-tested against captured server
/// responses, with no socket in the test.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

import 'field_keys.dart';

/// Parses a [TomAuthState] from its stored [TomAuthState.name] token; an
/// unknown or absent token degrades to [TomAuthState.none] (the closed-safe
/// default), matching the server-side codec.
TomAuthState parseAuthState(String? token) =>
    TomAuthState.values.asNameMap()[token] ?? TomAuthState.none;

/// Maps the `GET /todos` body (`{ "items": [ … ] }`) to [TodoItem]s.
///
/// The priority/label values arrive as the enum's name (the server stores them
/// that way), so they go straight into the string-backed fields.
List<TodoItem> parseTodos(Map<String, dynamic> body) {
  final items = (body['items'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  return [
    for (final json in items)
      TodoItem()
        ..id.set('${json['id'] ?? ''}')
        ..title.set('${json['title'] ?? ''}')
        ..description.set('${json['description'] ?? ''}')
        ..done.set(json['done'] == true)
        ..priority.set('${json['priority'] ?? TodoPriority.medium.name}')
        ..label.set('${json['label'] ?? TodoLabel.feature.name}')
        ..assigneeId.set('${json['assigneeId'] ?? ''}')
        ..dueDate.set(_parseDate(json['dueDate'])),
  ];
}

/// Maps the `GET /todos/field-states` body (`{ role: { key: state } }`) to a
/// per-role, per-field [TomAuthState] matrix.
Map<String, Map<String, TomAuthState>> parseFieldStates(
    Map<String, dynamic> body) {
  final result = <String, Map<String, TomAuthState>>{};
  for (final role in body.entries) {
    final perField = (role.value as Map<String, dynamic>? ?? const {});
    result[role.key] = {
      for (final key in TodoFieldKeys.all)
        key: parseAuthState(perField[key] as String?),
    };
  }
  return result;
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

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

  /// `GET /todos` — the persisted items, mapped through [parseTodos].
  Future<List<TodoItem>> fetchTodos() async => parseTodos(await _getJson('/todos'));

  /// `GET /todos/field-states` — the four-state matrix, via [parseFieldStates].
  Future<Map<String, Map<String, TomAuthState>>> fetchFieldStates() async =>
      parseFieldStates(await _getJson('/todos/field-states'));

  /// Releases the underlying HTTP client.
  void close() => _client.close(force: true);

  Future<Map<String, dynamic>> _getJson(String path) async {
    final request = await _client.getUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GET $path failed (${response.statusCode})');
    }
    return json.decode(text) as Map<String, dynamic>;
  }
}
