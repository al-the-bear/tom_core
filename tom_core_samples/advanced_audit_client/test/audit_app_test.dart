// The audit application over InMemoryAuditBackend: signing in, asking the
// trail a question across its writers, saving it, and the saved questions'
// three actions.
import 'package:advanced_audit_client/app.dart';
import 'package:advanced_audit_client/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _signIn(
  WidgetTester tester, {
  String password = 'audrey-pass',
}) async {
  await tester.enterText(find.byKey(const Key('username')), 'audrey');
  await tester.enterText(find.byKey(const Key('password')), password);
  await tester.tap(find.byKey(const Key('signIn')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AAC-1: a wrong password is refused with a message', (
    tester,
  ) async {
    await tester.pumpWidget(AuditApp(backend: InMemoryAuditBackend()));
    await _signIn(tester, password: 'wrong');
    expect(find.byKey(const Key('signInError')), findsOneWidget);
    expect(find.text('Wrong user name or password.'), findsOneWidget);
  });

  testWidgets('AAC-2: audrey asks across both writers and narrows by actor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AuditApp(backend: InMemoryAuditBackend()));
    await _signIn(tester);
    expect(find.text('Audrey Auditor'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.text('6 record(s) from app, ops'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('actor')), 'alice');
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.text('1 record(s) from app, ops'), findsOneWidget);
    expect(find.text('denied'), findsOneWidget);
  });

  testWidgets('AAC-3: a question is saved, listed, delivered and deleted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = InMemoryAuditBackend();
    await tester.pumpWidget(AuditApp(backend: backend));
    await _signIn(tester);

    await tester.enterText(find.byKey(const Key('actor')), 'alice');
    await tester.tap(find.byKey(const Key('saveQuestion')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('questionName')), 'Alice');
    await tester.enterText(
      find.byKey(const Key('questionRecipients')),
      'audrey@example.com',
    );
    await tester.tap(find.byKey(const Key('confirmSave')));
    await tester.pumpAndSettle();
    expect(find.text('Saved "Alice".'), findsOneWidget);
    final saved = (await backend.questions()).single;
    expect(saved.filter['actor'], 'alice');
    expect(saved.recipients, ['audrey@example.com']);

    await tester.tap(find.text('Saved questions'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('question-${saved.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('deliver-${saved.id}')));
    await tester.pumpAndSettle();
    expect(
      // The snackbar waits behind the save's; the list shows the delivery.
      find.textContaining('next delivery 2026-10-27T11:00:00Z'),
      findsOneWidget,
    );
    expect((await backend.questions()).single.nextDeliveryAt, isNotEmpty);

    await tester.tap(find.byKey(Key('delete-${saved.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('question-${saved.id}')), findsNothing);
    expect(await backend.questions(), isEmpty);
  });

  testWidgets('AAC-4: signing out returns to the sign-in form', (tester) async {
    await tester.pumpWidget(AuditApp(backend: InMemoryAuditBackend()));
    await _signIn(tester);
    await tester.tap(find.byKey(const Key('signOut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signIn')), findsOneWidget);
  });
}
