import 'package:test/test.dart';
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

    test('enum labels render human-facing text', () {
      expect(TodoPriority.critical.label, 'Critical');
      expect(TodoLabel.docs.label, 'Docs');
    });
  });
}
