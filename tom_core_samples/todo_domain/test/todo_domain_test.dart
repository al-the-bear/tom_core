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

    test('enum values expose a global.<enumtype>.<value> resource key', () {
      // G-RES-5: enums carry no hardcoded display text — only a resource key
      // resolved through the installed bundle at the point of display.
      expect(TodoPriority.critical.resourceKey, 'global.todopriority.critical');
      expect(TodoLabel.docs.resourceKey, 'global.todolabel.docs');
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
  });
}
