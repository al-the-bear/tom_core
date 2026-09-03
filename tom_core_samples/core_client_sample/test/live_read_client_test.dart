// Unit tests for the live read path's pure JSON→entity mapping. The HTTP socket
// is deliberately not exercised here — the parsing is split into free functions
// precisely so it can be pinned against captured server responses.

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
}
