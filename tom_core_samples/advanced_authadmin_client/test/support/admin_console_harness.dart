/// Shared widget-test harness for the admin console's Users/Roles/Groups
/// screens.
///
/// The three CRUD test suites drive the *whole* console — pump it, sign in as the
/// seeded administrator, switch destinations on the rail — so that boilerplate
/// lives here once. Every helper runs over a caller-supplied
/// [InMemoryAdminBackend] so a test can introspect persisted state after a flow.
library;

import 'package:advanced_authadmin_client/app/admin_app.dart';
import 'package:advanced_authadmin_client/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Installs the canned public login bundle so the sign-in screen renders its
/// server-delivered chrome — without it the submit button shows the raw
/// `adminLogin.submit` key and the sign-in helper's `'Sign in'` finder misses.
void installLoginBundle() {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(
      Map<String, dynamic>.from(InMemoryAdminBackend.loginTexts),
    ),
  );
}

/// A viewport tall enough that an editor dialog's fields and the Save action all
/// fit (the default 800×600 window scrolls controls out of reach).
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps the console over [backend] and signs in as the seeded `admin`, landing
/// on the shell with the Users destination selected.
Future<void> pumpSignedInConsole(
  WidgetTester tester,
  InMemoryAdminBackend backend,
) async {
  useTallViewport(tester);
  installLoginBundle();
  await tester.pumpWidget(AdminConsoleApp(session: AdminSession(backend)));
  await tester.pumpAndSettle();

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'admin');
  await tester.enterText(fields.at(1), InMemoryAdminBackend.demoPassword);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

/// Selects the rail destination labelled [label] (e.g. `Roles`) and settles.
Future<void> openDestination(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Saves the open editor dialog and settles.
Future<void> saveEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('admin-editor-save')));
  await tester.pumpAndSettle();
}

/// Confirms the delete confirmation dialog and settles.
Future<void> confirmDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('admin-delete-confirm-ok')));
  await tester.pumpAndSettle();
}
