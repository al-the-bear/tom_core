// Unit tests for the single field identity (RCA1 / G-UI-6): a TodoItemForm
// field addresses itself ONE way. Its `basePath` — the scope its label key is
// composed from (`<basePath>.label`) — is byte-identical to the wire/authz key
// used to look the field's grade up in the session matrix. There is no second
// `todo.item.*` addressing scheme living beside the form's `todoItem.*` labels.

import 'package:core_client_sample/reflection_seed.dart';
import 'package:core_client_sample/resources/app_texts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(appTexts),
    );
  });

  testWidgets(
      'CCS-FORM-01: each gradable field basePath equals its wire/authz key',
      (tester) async {
    final form = TodoItemForm(const {});
    // The label key is `<basePath>.label`; the grant key is `<scope>.<tomId>`.
    // Deriving both from the single production scope constant proves the two
    // addressing schemes have collapsed into one identity.
    expect(form.title.basePath, '$todoItemScope.title');
    expect(form.done.basePath, '$todoItemScope.done');
    expect(form.priority.basePath, '$todoItemScope.priority');
    expect(form.assigneeId.basePath, '$todoItemScope.assigneeId');
    // And that scope resolves to the exact server-seeded wire prefix.
    expect(todoItemScope, 'todo.item');
  });

  testWidgets(
      'CCS-FORM-02: the grade stamped under the wire key drives the field',
      (tester) async {
    // A matrix keyed purely by the wire keys — the same identity as basePath.
    final form = TodoItemForm(const {
      'todo.item.title': TomAuthState.read,
      'todo.item.done': TomAuthState.disabled,
      'todo.item.priority': TomAuthState.none,
      'todo.item.assigneeId': TomAuthState.full,
    });
    expect(form.title.effectiveAuthState, TomAuthState.read);
    expect(form.done.effectiveAuthState, TomAuthState.disabled);
    expect(form.priority.effectiveAuthState, TomAuthState.none);
    expect(form.assigneeId.effectiveAuthState, TomAuthState.full);
  });

  testWidgets(
      'CCS-FORM-03: a field absent from the matrix is closed-safe (none)',
      (tester) async {
    final form = TodoItemForm(const {});
    expect(form.title.effectiveAuthState, TomAuthState.none);
    expect(form.assigneeId.effectiveAuthState, TomAuthState.none);
  });

  testWidgets('CCS-FORM-04: the label resolves from the same field identity',
      (tester) async {
    final form = TodoItemForm(const {});
    // `<basePath>.label` → `todo.item.title.label` in the installed bundle.
    expect(form.title.resolvedLabel, 'Title');
    expect(form.priority.resolvedLabel, 'Priority');
    expect(form.assigneeId.resolvedLabel, 'Assignee id');
  });
}
