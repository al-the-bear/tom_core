/// Render-level proof that the app's forms source their field labels/hints
/// from the installed resource bundle, not from hard-coded overrides.
///
/// [LoginForm] and [TodoItemForm] carry no `labelTextOverride`/`hintTextOverride`
/// and the screens build them without a screen-level scope wrapper, so each
/// field's `basePath` equals its wire resource key (`login.username`,
/// `todo.item.title`, …). A field with no override resolves its label through
/// `TomCtr.textOrNull(basePath, 'label')` — i.e. straight from the installed
/// [TomTextResourceProvider]. These tests install a **sentinel** bundle whose
/// values are deliberately distinct from the plain strings an override would
/// carry (the `[srv]` suffix), then assert the sentinels render. That proves two
/// things at once: the label came from the bundle (a leftover override would
/// short-circuit the lookup and render the bare string instead), and the field
/// addresses the right key (a scope/formId drift would miss the bundle entry).
library;

import 'package:advanced_app_client/forms/login_form.dart';
import 'package:advanced_app_client/forms/todo_item_form.dart';
import 'package:advanced_app_client/reflection_seed.dart'
    show initializeReflection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  setUpAll(initializeReflection);

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  void installBundle(Map<String, dynamic> texts) {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(texts),
    );
  }

  Future<void> pumpFields(
    WidgetTester tester,
    List<TomField<dynamic>> fields,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [for (final field in fields) field.widget]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TC-10-01: LoginForm labels/hints resolve from the login.* bundle, not '
    'overrides',
    (tester) async {
      installBundle(const {
        'login.username.label': 'Username [srv]',
        'login.username.hint': 'alice, bob or carol [srv]',
        'login.password.label': 'Password [srv]',
      });
      // Built unscoped: formId 'login' *is* the base path, so fields self-address
      // as login.username / login.password — the keys the bundle serves.
      final form = LoginForm();
      expect(form.basePath, 'login');
      expect(form.username.basePath, 'login.username');
      expect(form.password.basePath, 'login.password');

      await pumpFields(tester, [form.username, form.password]);

      expect(find.textContaining('Username [srv]'), findsWidgets);
      expect(find.textContaining('alice, bob or carol [srv]'), findsWidgets);
      expect(find.textContaining('Password [srv]'), findsWidgets);
      // A leftover override would have rendered the bare strings it carried.
      expect(find.text('Username'), findsNothing);
      expect(find.text('Password'), findsNothing);
      form.dispose();
    },
  );

  testWidgets(
    'TC-10-02: TodoItemForm labels resolve from the todo.item.* bundle',
    (tester) async {
      installBundle({
        'todo.item.title.label': 'Title [srv]',
        'todo.item.status.label': 'Status [srv]',
        'todo.item.priority.label': 'Priority [srv]',
        'todo.item.assigneeId.label': 'Assignee [srv]',
        'todo.item.dueDate.label': 'Due date [srv]',
        'todo.item.estimate.label': 'Estimate [srv]',
        'todo.item.description.label': 'Description [srv]',
      });
      // Built under the gradable scope, so basePath is todo.item and each
      // field self-addresses as its `todo.item.<field>` key.
      final form = TomScope.withScope('todo', TodoItemForm.new);
      expect(form.basePath, 'todo.item');

      await pumpFields(tester, form.gradableFields);

      expect(find.textContaining('Title [srv]'), findsWidgets);
      expect(find.textContaining('Status [srv]'), findsWidgets);
      expect(find.textContaining('Priority [srv]'), findsWidgets);
      expect(find.textContaining('Assignee [srv]'), findsWidgets);
      expect(find.textContaining('Due date [srv]'), findsWidgets);
      expect(find.textContaining('Estimate [srv]'), findsWidgets);
      expect(find.textContaining('Description [srv]'), findsWidgets);
      // No leftover override renders the bare label strings.
      expect(find.text('Title'), findsNothing);
      expect(find.text('Description'), findsNothing);
      form.dispose();
    },
  );
}
