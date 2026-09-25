import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:todo_domain/todo_domain.dart';

void main() {
  setUpAll(initializeReflection);

  group('entities', () {
    test('TodoItem defaults are sensible', () {
      final item = TodoItem();
      expect(item.title.get(), '');
      expect(item.done.get(), isFalse);
      expect(item.dueDate.getOrNull(), isNull);
      expect(item.priorityValue, TodoPriority.medium);
      expect(item.labelValue, TodoLabel.feature);
    });

    test('priority/label store the enum name and round-trip back', () {
      final item = TodoItem()
        ..priorityValue = TodoPriority.high
        ..labelValue = TodoLabel.bug;
      // Stored as the enum name…
      expect(item.priority.get(), 'high');
      expect(item.label.get(), 'bug');
      // …and read back as the typed enum.
      expect(item.priorityValue, TodoPriority.high);
      expect(item.labelValue, TodoLabel.bug);
    });

    test('unknown stored value falls back to the default enum', () {
      final item = TodoItem()..priority.set('bogus');
      expect(item.priorityValue, TodoPriority.medium);
    });

    test('the hierarchy nests project → list → item', () {
      final project = Project()..name.set('Website relaunch');
      final list = TodoList()..name.set('Sprint backlog');
      final item = TodoItem()..title.set('Ship todo_domain');
      list.items.add(item);
      project.lists.add(list);

      expect(project.lists.length, 1);
      expect(project.lists[0].items.length, 1);
      expect(project.lists[0].items[0].title.get(), 'Ship todo_domain');
    });

    test('enum values resolve under a global.<enumtype>.<value> resource key', () {
      // G-RES-5: enums carry no hardcoded display text — the framework derives
      // the key and the installed bundle supplies the text at the point of
      // display. Asserted here because these are the keys the bundle must carry.
      String keyOf(Enum value) =>
          TomObservableEnum.resourceKeysFor(value).single;

      expect(keyOf(TodoPriority.critical), 'global.todopriority.critical');
      expect(keyOf(TodoLabel.docs), 'global.todolabel.docs');
    });
  });

  group('wire DTOs (reflection-first)', () {
    test('TDW-DTO-01: TodoItemDto round-trips through reflection', () {
      final dto = TodoItemDto(
        id: '7',
        title: 'Wire the endpoint',
        description: 'GET /todos',
        done: true,
        priority: TodoPriority.high.name,
        label: TodoLabel.feature.name,
        assigneeId: '2',
        dueDate: '2026-01-02T00:00:00.000',
        listId: '3',
      );
      final map = dtoToMap(dto);
      expect(map['title'], 'Wire the endpoint');
      expect(map['done'], isTrue);
      expect(map['priority'], 'high');

      final back = dtoFromJson<TodoItemDto>(map);
      expect(back.id, '7');
      expect(back.done, isTrue);
      expect(back.dueDate, '2026-01-02T00:00:00.000');
      expect(back.listId, '3');
    });

    test('TDW-DTO-02: TodoItemDto tolerates a partial map', () {
      final back = dtoFromJson<TodoItemDto>(const {'id': '1', 'title': 'Bare'});
      expect(back.id, '1');
      expect(back.priority, ''); // closed-safe default; caller applies fallback
      expect(back.dueDate, '');
    });

    test('TDW-DTO-03: TodoFieldMatrixDto encodes tokens and round-trips', () {
      final dto = TodoFieldMatrixDto({
        'owner': {
          'todo.item.title': TomAuthState.full,
          'todo.item.priority': TomAuthState.full,
        },
        'viewer': {
          'todo.item.title': TomAuthState.read,
          'todo.item.done': TomAuthState.disabled,
        },
      });
      // The nested map carries the stable enum-name tokens.
      final map = dtoToMap(dto);
      final states = map['states'] as Map;
      expect((states['owner'] as Map)['todo.item.title'], 'full');
      expect((states['viewer'] as Map)['todo.item.done'], 'disabled');

      final back = dtoFromJson<TodoFieldMatrixDto>(map);
      expect(back.accessFor('owner', 'todo.item.title'), TomAuthState.full);
      expect(back.accessFor('viewer', 'todo.item.done'), TomAuthState.disabled);
      // An unset cell is closed-safe.
      expect(back.accessFor('viewer', 'todo.item.priority'), TomAuthState.none);
      expect(back.statesFor('owner'), hasLength(2));
    });

    // `dtoToJsonString` goes through `convertToJsonString`, a different kernel
    // path from the `getValues` behind `dtoToMap`, so the string form is pinned
    // on its own: it must decode to the same map the map form produces, and
    // read back to the same DTO. The ISO-8601 `dueDate` and the nested `states`
    // map are the shapes most likely to serialize differently.
    test('TDW-DTO-04: TodoItemDto round-trips through its JSON string', () {
      final dto = TodoItemDto(
        id: '7',
        title: 'Wire the endpoint',
        description: 'GET /todos',
        done: true,
        priority: TodoPriority.high.name,
        label: TodoLabel.bug.name,
        assigneeId: '2',
        dueDate: '2026-01-02T00:00:00.000',
        listId: '3',
      );
      final decoded = jsonDecode(dtoToJsonString(dto)) as Map<String, Object?>;
      expect(decoded, equals(dtoToMap(dto)));
      expect(decoded['dueDate'], '2026-01-02T00:00:00.000');

      final back = dtoFromJson<TodoItemDto>(decoded);
      expect(dtoToMap(back), equals(dtoToMap(dto)));
    });

    test(
      'TDW-DTO-05: TodoFieldMatrixDto round-trips through its JSON string',
      () {
        final dto = TodoFieldMatrixDto({
          'owner': {'todo.item.title': TomAuthState.full},
          'viewer': {
            'todo.item.title': TomAuthState.read,
            'todo.item.done': TomAuthState.disabled,
            'todo.item.priority': TomAuthState.none,
          },
        });
        final decoded =
            jsonDecode(dtoToJsonString(dto)) as Map<String, Object?>;
        expect(decoded, equals(dtoToMap(dto)));
        expect(decoded['states'], {
          'owner': {'todo.item.title': 'full'},
          'viewer': {
            'todo.item.title': 'read',
            'todo.item.done': 'disabled',
            'todo.item.priority': 'none',
          },
        });

        final back = dtoFromJson<TodoFieldMatrixDto>(decoded);
        for (final role in ['owner', 'viewer']) {
          expect(back.statesFor(role), equals(dto.statesFor(role)));
        }
      },
    );
  });

  // The matrix is an authorization decision that arrives from the network, so
  // its degenerate inputs are the contract, not an afterthought: every one of
  // them must deny rather than throw. A reader that throws on a malformed
  // payload fails *open* in the sense that matters — the client's read path
  // breaks instead of rendering the most restrictive grade.
  group('TodoFieldMatrixDto closed-safe reads', () {
    /// A matrix whose `viewer` row mixes a well-formed token with cells that
    /// are not strings at all — the shape an untrusted or version-skewed
    /// payload can take, since `states` is typed `Map<String, Object?>`.
    TodoFieldMatrixDto malformed() =>
        TodoFieldMatrixDto()
          ..states = <String, Object?>{
            'viewer': <String, Object?>{
              'todo.item.title': 'read', // well-formed: must still parse
              'todo.item.priority': 42, // an int where a token belongs
              'todo.item.done': <String, Object?>{}, // a nested map
              'todo.item.label': true, // a bool
            },
            'ghost': 'not-a-row', // a row that is not a map at all
          };

    test('TDW-MTX-01: accessFor resolves a non-String cell to none', () {
      final dto = malformed();
      expect(dto.accessFor('viewer', 'todo.item.priority'), TomAuthState.none);
      expect(dto.accessFor('viewer', 'todo.item.done'), TomAuthState.none);
      expect(dto.accessFor('viewer', 'todo.item.label'), TomAuthState.none);
      // Anti-vacuity: the well-formed cell beside them still parses, so the
      // test would fail if accessFor simply returned none for everything.
      expect(dto.accessFor('viewer', 'todo.item.title'), TomAuthState.read);
    });

    test('TDW-MTX-02: statesFor resolves a non-String cell to none', () {
      final row = malformed().statesFor('viewer');
      expect(row['todo.item.priority'], TomAuthState.none);
      expect(row['todo.item.done'], TomAuthState.none);
      expect(row['todo.item.label'], TomAuthState.none);
      expect(row['todo.item.title'], TomAuthState.read); // anti-vacuity
      expect(row, hasLength(4)); // no cell is silently dropped
    });

    test('TDW-MTX-03: a malformed cell survives the wire path', () {
      // The threat model is a payload off the network, not a hand-built DTO,
      // so assert the same guarantee after reflection deserialization.
      final back = dtoFromJson<TodoFieldMatrixDto>(const {
        'states': {
          'viewer': {'todo.item.title': 'read', 'todo.item.priority': 42},
        },
      });
      expect(back.accessFor('viewer', 'todo.item.priority'), TomAuthState.none);
      expect(back.statesFor('viewer')['todo.item.priority'], TomAuthState.none);
      expect(back.accessFor('viewer', 'todo.item.title'), TomAuthState.read);
    });

    test('TDW-MTX-04: an absent role denies through both readers', () {
      final dto = malformed();
      expect(dto.accessFor('nobody', 'todo.item.title'), TomAuthState.none);
      expect(dto.statesFor('nobody'), isEmpty);
      // A role whose row is present but is not a map behaves the same way.
      expect(dto.accessFor('ghost', 'todo.item.title'), TomAuthState.none);
      expect(dto.statesFor('ghost'), isEmpty);
    });

    test('TDW-MTX-05: an unrecognised token resolves to none', () {
      expect(TodoFieldMatrixDto.parseState('bogus'), TomAuthState.none);
      expect(TodoFieldMatrixDto.parseState(null), TomAuthState.none);
      expect(TodoFieldMatrixDto.parseState(42), TomAuthState.none);
      expect(TodoFieldMatrixDto.parseState('full'), TomAuthState.full);
    });

    test('TDW-MTX-06: orElse chooses the fallback for every bad input', () {
      const fallback = TomAuthState.disabled;
      expect(
        TodoFieldMatrixDto.parseState('bogus', orElse: fallback),
        fallback,
      );
      expect(TodoFieldMatrixDto.parseState(null, orElse: fallback), fallback);
      expect(TodoFieldMatrixDto.parseState(42, orElse: fallback), fallback);
      // A recognised token still wins over orElse.
      expect(
        TodoFieldMatrixDto.parseState('read', orElse: fallback),
        TomAuthState.read,
      );
    });

    test('TDW-MTX-07: roles names every row the matrix carries', () {
      expect(malformed().roles, containsAll(<String>['viewer', 'ghost']));
      expect(TodoFieldMatrixDto().roles, isEmpty);
    });
  });
}
