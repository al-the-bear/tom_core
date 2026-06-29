/// Unit tests for [AdminLoginForm] — the reflected admin login form added in
/// todo 12.
///
/// Three things the form has to get right:
///
/// 1. **Self-addressing.** Built unscoped with `formId: 'adminLogin'`, the form's
///    `basePath` is `adminLogin` and each field's `basePath` is its served bundle
///    key (`adminLogin.username` / `adminLogin.password`). That equality is the
///    precondition for labels to resolve from the public `/resources/login`
///    bundle the admin client installs before sign-in (todo 8) — a double-scope
///    (`adminLogin.adminLogin.*`) would silently miss every key.
/// 2. **Required validation.** Both fields are `Validators.required()`, so a
///    `save()` with either empty fails (returns false) and a `save()` with both
///    present succeeds.
/// 3. **`bind`/`save` round-trip.** Saving writes the typed field values straight
///    back into the bound [AdminLoginCredentials] through the reflection
///    round-trip, exactly as the screen (todo 13) will consume them.
///
/// A fourth widget test proves labels are bundle-driven (no overrides): a
/// sentinel `adminLogin.*` bundle renders through the field, mirroring the
/// `form_label_resolution_test` pattern used for the CRUD forms.
library;

import 'package:advanced_authadmin_client/domain/admin_login_credentials.dart';
import 'package:advanced_authadmin_client/forms/admin_login_form.dart';
import 'package:advanced_authadmin_client/reflection_seed.dart'
    show initializeReflection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  group('AdminLoginForm self-addressing (todo 12)', () {
    test('the form runs unscoped under adminLogin', () {
      final form = AdminLoginForm();
      expect(form.basePath, 'adminLogin');
      form.dispose();
    });

    test('each field self-addresses as its served bundle key', () {
      final form = AdminLoginForm();
      expect(form.username.basePath, 'adminLogin.username');
      expect(form.password.basePath, 'adminLogin.password');
      form.dispose();
    });
  });

  group('AdminLoginForm required validation (todo 12)', () {
    test('save fails when either field is empty', () async {
      final form = AdminLoginForm()..bind(AdminLoginCredentials());

      // Both empty.
      expect(await form.save(), isFalse);

      // Only username present.
      form.username.setValue('admin');
      expect(await form.save(), isFalse);

      // Only password present.
      form.username.setValue('');
      form.password.setValue('pw');
      expect(await form.save(), isFalse);

      form.dispose();
    });

    test('save succeeds when both fields are present', () async {
      final form = AdminLoginForm()..bind(AdminLoginCredentials());
      form.username.setValue('admin');
      form.password.setValue('pw');
      expect(await form.save(), isTrue);
      form.dispose();
    });
  });

  test('bind/save round-trips into the bound AdminLoginCredentials (todo 12)',
      () async {
    final credentials = AdminLoginCredentials();
    final form = AdminLoginForm()..bind(credentials);

    form.username.setValue('admin');
    form.password.setValue('s3cret');
    expect(await form.save(), isTrue);

    // The save wrote the typed field values straight back into the bound entity
    // — exactly what the screen folds into a LoginRequest in todo 13.
    expect(credentials.username.get(), 'admin');
    expect(credentials.password.get(), 's3cret');

    form.dispose();
  });

  testWidgets(
      'labels resolve from the adminLogin.* login bundle, not overrides (todo 12)',
      (tester) async {
    // Install a sentinel login bundle (the `[srv]` suffix is distinct from both
    // the canned strings and the bare tomId fallback). The form carries no
    // labelTextOverride, so the only source of a field's label is this provider
    // — the sentinels rendering proves the labels are bundle-driven and the
    // fields address the right keys.
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {
        'adminLogin.username.label': 'Username [srv]',
        'adminLogin.password.label': 'Password [srv]',
      }),
    );

    final form = AdminLoginForm();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [form.username.widget, form.password.widget],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Username [srv]'), findsWidgets);
    expect(find.textContaining('Password [srv]'), findsWidgets);
    // Neither the bare tomId fallback renders — the label resolves through the
    // installed provider, nothing else.
    expect(find.text('username'), findsNothing);
    expect(find.text('password'), findsNothing);

    form.dispose();
  });
}
