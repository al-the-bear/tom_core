/// The shared domain, used the way a runtime uses it: build the entity chain,
/// read the typed enums, and grade an item's fields for a role.
///
/// Four things every consumer of this package does, and none of which any
/// single consumer shows in one place:
///
/// 1. **The entity chain.** `Workspace -> Project -> TodoList -> TodoItem`,
///    linked by flat foreign keys (`workspaceId`, `projectId`, `listId`) —
///    each entity is one SQL table on the app server.
/// 2. **Typed enums over stored names.** Each enum is stored as its `name` in a
///    `TomString`, read through a typed accessor that falls back to a safe
///    default when the stored value is not a known name.
/// 3. **Resource keys.** The authorization layer addresses a resource as
///    `<type>:<id>` (`ResourceRoleKeys`).
/// 4. **The two-level grade.** The framework's resource-role registry gives a
///    role one *resource-level* state; `projectRoleFieldGrades` grades each
///    item field inside it; a field's effective state is the one narrowed by
///    the other — exactly what the app client's item screen computes. A
///    principal with no role on the item gets `none` everywhere, whatever the
///    matrix says.
///
/// ## Running it
///
/// No infrastructure:
///
/// ```sh
/// dart run example/advanced_todo_domain_example.dart
/// ```
///
/// This package ships no reflection seed of its own — each runtime installs a
/// combined one — so the example installs the seed the package generates for
/// its tests, `test/run_all_tests.reflection.dart`, before constructing any
/// entity.
library;

import 'dart:io';

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../test/run_all_tests.reflection.dart';

void main() {
  initializeReflection();
  registerProjectRoleVocabulary();

  // 1. The chain, by foreign key.
  final workspace = Workspace()
    ..id.set('w1')
    ..name.set('Acme Engineering')
    ..ownerId.set('u1');
  final project = Project()
    ..id.set('p1')
    ..workspaceId.set(workspace.id.get())
    ..name.set('Advanced sample');
  final list = TodoList()
    ..id.set('l1')
    ..projectId.set(project.id.get())
    ..name.set('This week');
  final item = TodoItem()
    ..id.set('i1')
    ..listId.set(list.id.get())
    ..title.set('Ship the advanced sample')
    ..statusValue = TodoStatus.inProgress
    ..priorityValue = TodoPriority.high;
  stdout
    ..writeln('== the chain')
    ..writeln(
      '${workspace.name.get()} > ${project.name.get()} > '
      '${list.name.get()} > ${item.title.get()}',
    )
    ..writeln(
      'item.listId=${item.listId.get()}  list.projectId=${list.projectId.get()}'
      '  project.workspaceId=${project.workspaceId.get()}',
    );

  // 2. Typed enums over the stored name.
  stdout
    ..writeln()
    ..writeln('== typed enums')
    ..writeln(
      'status stored "${item.status.get()}", read ${item.statusValue.name}',
    );
  item.status.set('shipped-yesterday'); // not a TodoStatus name
  stdout.writeln(
    'status stored "${item.status.get()}", read ${item.statusValue.name} '
    '(the closed-safe fallback)',
  );

  // 3. Resource keys.
  stdout
    ..writeln()
    ..writeln('== resource key')
    ..writeln(ResourceRoleKeys.item(item.id.get()));

  // 4. The two-level grade: resource ceiling narrowed by the field grade.
  const shown = ['todo.item.title', 'todo.item.status', 'todo.item.estimate'];
  stdout
    ..writeln()
    ..writeln('== effective field states (ceiling narrowed by grade)')
    ..writeln(
      [
        'role'.padRight(10),
        'ceiling'.padRight(8),
        ...shown.map((k) => k.split('.').last.padRight(9)),
      ].join(' ').trimRight(),
    );
  for (final role in ProjectRole.values) {
    final ceiling = TomResourceRoleRegistry.stateFor(role.name)!;
    stdout.writeln(
      _row(role.name, ceiling, projectRoleFieldGrades[role]!, shown),
    );
  }
  // A principal with no role on the item: the registry gives no resource state,
  // and the narrow collapses every field regardless of the matrix.
  stdout.writeln(
    _row(
      '(no role)',
      TomAuthState.none,
      projectRoleFieldGrades[ProjectRole.owner]!,
      shown,
    ),
  );
}

String _row(
  String role,
  TomAuthState ceiling,
  Map<String, TomAuthState> grades,
  List<String> keys,
) =>
    '${role.padRight(10)} ${ceiling.name.padRight(8)} '
            '${keys.map((k) => ceiling.narrow(grades[k]!).name.padRight(9)).join(' ')}'
        .trimRight();
