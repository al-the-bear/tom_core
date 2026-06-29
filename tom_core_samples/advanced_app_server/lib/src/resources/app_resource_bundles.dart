/// The app server's text resource bundle (step / todo 7).
///
/// The app client's post-login screens — the board and the item editor — render
/// their labels and hints through the Tom Flutter UI resource system rather than
/// from client-side strings. This is the server-owned source of those texts: a
/// flat `<basePath>.<suffix>` map the `appResources` endpoint serves and the
/// client installs via `TomTextResourceProvider.from(dto.texts)` (todo 9).
///
/// The item-form keys are **derived** from [TodoItemResourceKeys] (the todo-1
/// convention), not written as free strings, so a served label key can never
/// drift from the grade key the form field self-addresses as: the field at
/// `todo.item.title` is graded on `todo.item.title` and labelled from
/// `todo.item.title.label`. Board texts use the `board.*` namespace, which has
/// no grade counterpart (the board is not a gradable form).
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

/// Builds the app client's full text bundle (board + item-form texts).
///
/// Pure and database-free, so it is unit-tested directly and the
/// `AdvancedAppApiService.resources` endpoint simply returns [appBundle].
class AppResourceBundles {
  const AppResourceBundles._();

  /// Display label for each gradable item field, keyed by
  /// `${TodoItemResourceKeys.keyFor(field)}.label` so the label key tracks the
  /// grade key. The `estimate` token (not `estimateHours`) is used, matching the
  /// field's `tomId`.
  static const Map<String, String> _itemFieldLabels = {
    TodoItemResourceKeys.titleField: 'Title',
    TodoItemResourceKeys.statusField: 'Status',
    TodoItemResourceKeys.priorityField: 'Priority',
    TodoItemResourceKeys.assigneeIdField: 'Assignee id',
    TodoItemResourceKeys.dueDateField: 'Due date',
    TodoItemResourceKeys.estimateField: 'Estimate (h)',
    TodoItemResourceKeys.descriptionField: 'Description',
  };

  /// Board-screen texts (no grade counterpart).
  static const Map<String, String> _boardTexts = {
    'board.title': 'My Board',
    'board.empty': 'No items yet',
    'board.item.save': 'Save',
    'board.item.delete': 'Delete',
    'board.item.comment.add': 'Add comment',
    'board.share': 'Share',
  };

  /// The flat `<basePath>.<suffix>` text map the bundle carries.
  static Map<String, Object?> texts() => {
        for (final entry in _itemFieldLabels.entries)
          '${TodoItemResourceKeys.keyFor(entry.key)}.label': entry.value,
        ..._boardTexts,
      };

  /// The app client's full bundle (board + item-form texts).
  static ResourceBundleDto appBundle() => ResourceBundleDto(texts());
}
