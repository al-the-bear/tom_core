/// Render-level proof that the admin CRUD forms source their field labels from
/// the installed resource bundle, not from hard-coded overrides.
///
/// [UserForm], [RoleForm] and [GroupForm] carry no `labelTextOverride`, and the
/// CRUD screens build them without a `TomScope.withScope('userCreate'/…)`
/// wrapper, so each form's `formId` *is* its base path
/// (`user`, `role`, `group`) and each field self-addresses as its wire resource
/// key (`user.username`, `role.key`, `group.name`, …) — exactly the keys the
/// admin console bundle serves. A field with no override resolves its label
/// through `TomCtr.textOrNull(basePath, 'label')`, i.e. from the installed
/// [TomTextResourceProvider]. These tests install a **sentinel** bundle (the
/// `[srv]` suffix) and assert the sentinels render, which proves the label came
/// from the bundle and the form addresses the right key.
library;

import 'package:advanced_authadmin_client/forms/group_form.dart';
import 'package:advanced_authadmin_client/forms/role_form.dart';
import 'package:advanced_authadmin_client/forms/user_form.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
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
            child: Column(
              children: [for (final field in fields) field.widget],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TC-10-U: UserForm labels resolve from the user.* bundle, not overrides',
      (tester) async {
    installBundle(const {
      'user.username.label': 'Username [srv]',
      'user.password.label': 'Password [srv]',
      'user.displayName.label': 'Display name [srv]',
      'user.email.label': 'Email [srv]',
    });
    // Built unscoped: formId 'user' is the base path, fields self-address as
    // user.username / user.password / user.displayName / user.email.
    final form = UserForm();
    expect(form.basePath, 'user');
    expect(form.username.basePath, 'user.username');

    await pumpFields(tester, form.editableFields);

    expect(find.textContaining('Username [srv]'), findsWidgets);
    expect(find.textContaining('Password [srv]'), findsWidgets);
    expect(find.textContaining('Display name [srv]'), findsWidgets);
    expect(find.textContaining('Email [srv]'), findsWidgets);
    expect(find.text('Username'), findsNothing);
    form.dispose();
  });

  testWidgets(
      'TC-10-R: RoleForm labels resolve from the role.* bundle, not overrides',
      (tester) async {
    installBundle(const {
      'role.key.label': 'Key [srv]',
      'role.name.label': 'Name [srv]',
    });
    final form = RoleForm();
    expect(form.basePath, 'role');
    expect(form.key.basePath, 'role.key');
    expect(form.name.basePath, 'role.name');

    await pumpFields(tester, form.editableFields);

    expect(find.textContaining('Key [srv]'), findsWidgets);
    expect(find.textContaining('Name [srv]'), findsWidgets);
    expect(find.text('Key'), findsNothing);
    form.dispose();
  });

  testWidgets(
      'TC-10-G: GroupForm label resolves from the group.* bundle, not overrides',
      (tester) async {
    installBundle(const {'group.name.label': 'Name [srv]'});
    final form = GroupForm();
    expect(form.basePath, 'group');
    expect(form.name.basePath, 'group.name');

    await pumpFields(tester, form.editableFields);

    expect(find.textContaining('Name [srv]'), findsWidgets);
    form.dispose();
  });
}
