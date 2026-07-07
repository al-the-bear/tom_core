/// Unit tests for [TodoItemForm]'s scope realignment (todo 4).
///
/// After the realignment the form runs under scope `'todo'` with `formId`
/// `'item'` and each field's `tomId` is the plain field name, so every gradable
/// field's `basePath` equals its wire resource key (`todo.item.<field>`). That
/// is the precondition for the detail screen to stamp each field with its
/// DB-resolved grade via a per-field fixed authorizer keyed by that `basePath`.
/// The estimate field is the special case: its `tomId` is `estimate` while its
/// reflected member stays `estimateHours` (D-A2), so its `basePath` is
/// `todo.item.estimate` but `bind`/`save` still round-trips into the entity by
/// member name.
library;

import 'package:advanced_app_client/forms/todo_item_form.dart';
import 'package:advanced_app_client/reflection_seed.dart'
    show initializeReflection;
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The gradable item keys in display order — the wire resource keys the form's
/// fields self-address as. Steps 21/24/26 derive this set from reflection/the
/// resource bundle; here it is the inline expectation.
const _gradableItemKeys = <String>[
  'todo.item.title',
  'todo.item.status',
  'todo.item.priority',
  'todo.item.assigneeId',
  'todo.item.dueDate',
  'todo.item.estimate',
  'todo.item.description',
];

void main() {
  setUpAll(initializeReflection);

  // Build the form the way the detail screen does: under the gradable scope.
  TodoItemForm buildForm() => TomScope.withScope('todo', TodoItemForm.new);

  group('TodoItemForm scope realignment (todo 4)', () {
    test('the form runs under todo.item', () {
      final form = buildForm();
      expect(form.basePath, 'todo.item');
    });

    test('each gradable field self-addresses as its todo.item.<field> key',
        () {
      final form = buildForm();
      expect(form.title.basePath, 'todo.item.title');
      expect(form.status.basePath, 'todo.item.status');
      expect(form.priority.basePath, 'todo.item.priority');
      expect(form.assigneeId.basePath, 'todo.item.assigneeId');
      expect(form.dueDate.basePath, 'todo.item.dueDate');
      expect(form.description.basePath, 'todo.item.description');
    });

    test(
        'the estimate field self-addresses as todo.item.estimate while its '
        'member stays estimateHours', () {
      final form = buildForm();
      // basePath uses the tomId (estimate), so it matches the graded key…
      expect(form.estimateHours.basePath, 'todo.item.estimate');
      expect(form.estimateHours.basePath, 'todo.item.estimate');
      // …but the reflected member name is unchanged, so bind/save round-trips
      // straight into the entity's `estimateHours`.
      expect(form.fields.containsKey('estimateHours'), isTrue);
      expect(form.fields.containsKey('estimate'), isFalse);
    });

    test('gradableFields basePaths equal the gradable item keys, in order',
        () {
      final form = buildForm();
      expect(
        form.gradableFields.map((field) => field.basePath).toList(),
        _gradableItemKeys,
      );
    });
  });
}
