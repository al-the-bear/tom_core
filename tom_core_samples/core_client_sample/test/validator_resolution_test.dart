// Tests for the resource-declared validator path (G-UI-7) and resource-resolved
// validation messages (G-RES-1). The forms declare `required` in the appTexts
// bundle under `<basePath>.validators`; TomField resolves it by name through the
// TomValidatorRegistry and merges it with any code-supplied validator. A failed
// validator's `error.<name>` key resolves from the same bundle — no hardcoded
// message.

import 'package:core_client_sample/reflection_seed.dart';
import 'package:core_client_sample/resources/app_texts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Builds the todo form the way production does — inside the enclosing
/// [todoScopeId] scope, so its fields resolve their `<basePath>.validators`
/// declarations under `todo.item.<tomId>`.
TodoItemForm buildForm() =>
    TomScope.withScope(todoScopeId, () => TodoItemForm(const {}));

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(appTexts),
    );
  });

  testWidgets(
      'CCS-VAL-01: login fields resolve their validator purely from resources',
      (tester) async {
    final form = LoginForm();
    // No code validators are passed; each field's single validator is the
    // `required` declared under `login.<tomId>.validators`.
    expect(form.username.validators.length, 1);
    expect(form.password.validators.length, 1);
  });

  testWidgets('CCS-VAL-02: the title field merges a code + a resource validator',
      (tester) async {
    final form = buildForm();
    // One code-supplied validator (_noSurroundingSpace) + one resource-declared
    // (`required`) = two effective validators, proving TomField merges both.
    expect(form.title.validators.length, 2);
  });

  testWidgets(
      'CCS-VAL-03: a failed resource `required` renders the resolved message',
      (tester) async {
    final form = LoginForm();
    form.username.set('');
    await form.username.validate();
    expect(form.username.resolvedErrorMessage, 'This field is required.');
  });

  testWidgets(
      'CCS-VAL-04: the code-supplied validator message also resolves as a resource',
      (tester) async {
    final form = buildForm();
    form.title.set(' padded ');
    await form.title.validate();
    expect(form.title.resolvedErrorMessage,
        'Title cannot have leading or trailing spaces.');
  });

  testWidgets(
      'CCS-VAL-05: an empty title falls through the code rule to resource `required`',
      (tester) async {
    final form = buildForm();
    // The whitespace rule passes on '' (trim == value), so `required` is the
    // validator that reports — demonstrating the merge runs both in order.
    form.title.set('');
    await form.title.validate();
    expect(form.title.resolvedErrorMessage, 'This field is required.');
  });
}
