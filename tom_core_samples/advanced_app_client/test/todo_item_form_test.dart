/// Unit tests for [TodoItemForm]'s scope realignment (todo 4).
///
/// After the realignment the form runs under [TodoItemResourceKeys.scope]
/// (`'todo'`) with `formId` [TodoItemResourceKeys.formId] (`'item'`) and each
/// field's `tomId` comes from the matching `*Field` token, so every gradable
/// field's `basePath` equals its wire resource key (`todo.item.<field>`). That
/// is the precondition for the installed [FieldStateAuthorizationAdapter] (todo
/// 3) to grade each field implicitly through layer-1
/// `TomAuthorization.resolveAuth(basePath)`. The estimate field is the special
/// case: its `tomId` is `estimate` while its reflected member stays
/// `estimateHours` (D-A2), so its `basePath` is `todo.item.estimate` but
/// `bind`/`save` still round-trips into the entity by member name.
library;

import 'package:advanced_app_client/forms/todo_item_form.dart';
import 'package:advanced_app_client/reflection_seed.dart'
    show initializeReflection;
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show TodoItemResourceKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  // Build the form the way the detail screen does: under the gradable scope.
  TodoItemForm buildForm() => TomScope.withScope(
        TodoItemResourceKeys.scope,
        TodoItemForm.new,
      );

  group('TodoItemForm scope realignment (todo 4)', () {
    test('the form runs under todo.item', () {
      final form = buildForm();
      expect(form.basePath,
          '${TodoItemResourceKeys.scope}.${TodoItemResourceKeys.formId}');
      expect(form.basePath, 'todo.item');
    });

    test('each gradable field self-addresses as its TodoItemResourceKeys value',
        () {
      final form = buildForm();
      expect(form.title.basePath, TodoItemResourceKeys.title);
      expect(form.status.basePath, TodoItemResourceKeys.status);
      expect(form.priority.basePath, TodoItemResourceKeys.priority);
      expect(form.assigneeId.basePath, TodoItemResourceKeys.assigneeId);
      expect(form.dueDate.basePath, TodoItemResourceKeys.dueDate);
      expect(form.description.basePath, TodoItemResourceKeys.description);
    });

    test(
        'the estimate field self-addresses as todo.item.estimate while its '
        'member stays estimateHours', () {
      final form = buildForm();
      // basePath uses the tomId (estimate), so it matches the graded key…
      expect(form.estimateHours.basePath, TodoItemResourceKeys.estimate);
      expect(form.estimateHours.basePath, 'todo.item.estimate');
      // …but the reflected member name is unchanged, so bind/save round-trips
      // straight into the entity's `estimateHours`.
      expect(form.fields.containsKey('estimateHours'), isTrue);
      expect(form.fields.containsKey('estimate'), isFalse);
    });

    test('gradableFields basePaths equal TodoItemResourceKeys.all, in order',
        () {
      final form = buildForm();
      expect(
        form.gradableFields.map((field) => field.basePath).toList(),
        TodoItemResourceKeys.all,
      );
    });
  });
}
