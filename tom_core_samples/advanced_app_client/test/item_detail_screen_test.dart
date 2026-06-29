/// Widget tests for the item-detail screen (step 30): the bound
/// `TomForm<TodoItem>` whose per-field controls are driven by the session's
/// four-state grade matrix.
///
/// This is the heart of what the sample teaches — the *same* [ItemDetailScreen]
/// (and the [TodoItemForm] it builds) renders differently per role because it is
/// constructed with the principal's resolved field matrix:
///
/// - `owner` (alice) edits every gradable field — a full editor with a Save.
/// - `viewer` (val, shared in for the test) sees read-only fields, a *disabled*
///   status control, and no `estimate` at all (ungranted → [TomAuthState.none],
///   the field collapses); with nothing editable there is no Save.
/// - `editor` (bob) can save, but `assigneeId` is read-only, so editing the
///   title and saving persists the title while the assignee stays put — the
///   write-back only carries the fields the grade renders editable.
///
/// Socket-free: the in-memory fake builds the reflected domain tree, so the
/// app's own `initializeReflection()` runs once in [setUpAll] and the resource
/// provider is installed per test. The detail screen is pushed from a host route
/// so its `Navigator.pop(true)` on save has a route to return to.
library;

import 'package:advanced_app_client/app/app_session.dart';
import 'package:advanced_app_client/backend/backend.dart';
import 'package:advanced_app_client/reflection_seed.dart';
import 'package:advanced_app_client/screens/item_detail_screen.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
// The app seed owns the authoritative `initializeReflection`; the domain library
// carries its own (for use on its own), hidden here to avoid the collision.
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show ProjectRole;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
  });

  // The role matrix is now driven *purely* through the implicit chain: each
  // test installs its session's adapter on the [TomAuthorization] singleton (the
  // same wiring `main` performs) and clears it afterwards, so the four-role
  // render matrix is reproduced without the form holding any authorization
  // state. This is the regression guard for the per-field-authorizer removal
  // (todo 5).
  tearDown(TomAuthorization.reset);

  /// A tall viewport so the detail form's fields and Save button all fit
  /// on-screen (the default 800×600 window scrolls controls out of reach).
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  LoginRequest login(String user) => LoginRequest(username: user, password: 'pw');

  /// Signs [user] in over a fresh backend and pushes the detail screen for item
  /// [itemId] from a host route. Returns the live backend so a test can re-read
  /// persisted state. [shareValAsViewer] grants `val` a viewer role first (val
  /// has no access in the seed), so the viewer case can open the item.
  Future<InMemoryAppBackend> openDetail(
    WidgetTester tester,
    String user, {
    String itemId = 'i-1',
    bool shareValAsViewer = false,
  }) async {
    useTallViewport(tester);

    final backend = InMemoryAppBackend();
    final session = AppSession(backend);
    // Install the session's adapter on the singleton, exactly as `main` does, so
    // each field resolves its grade implicitly through layer-1 once
    // `loadFieldStates` feeds the matrix in. Cleared in [tearDown].
    TomAuthorization.adapter = session.authorizationAdapter;

    if (shareValAsViewer) {
      await session.login(login('alice'));
      await backend.share(const ShareRequest(
        resourceType: 'project',
        resourceId: 'p-1',
        granteeUserId: 'u-val',
        projectRole: ProjectRole.viewer,
      ));
      await session.logout();
    }

    await session.login(login(user));
    final items = await backend.listItems('l-1');
    final item = items.firstWhere((i) => i.id.get() == itemId);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => ItemDetailScreen(session: session, item: item),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return backend;
  }

  testWidgets('TC-30-01: owner sees a full editor with every gradable field',
      (tester) async {
    await openDetail(tester, 'alice');

    // All seven gradable field labels are present (Material renders a field's
    // floating label more than once during its animation, so assert presence,
    // not an exact count).
    expect(find.text('Title'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Priority'), findsWidgets);
    expect(find.text('Assignee id'), findsWidgets);
    expect(find.text('Due date'), findsWidgets);
    expect(find.text('Estimate (h)'), findsWidgets);
    expect(find.text('Description'), findsWidgets);

    // …and because every field is `full`, the editor offers Save and the title
    // control is editable.
    expect(find.byKey(const Key('item-save-button')), findsOneWidget);
    final title = tester.widget<TextField>(find.byType(TextField).first);
    expect(title.enabled, isTrue);
  });

  testWidgets(
      'TC-30-02: viewer is read-only — status disabled, estimate hidden, no Save',
      (tester) async {
    await openDetail(tester, 'val', shareValAsViewer: true);

    // The ungranted field (estimate → none) collapses entirely…
    expect(find.text('Estimate (h)'), findsNothing);
    // …while the disabled status control is still visible.
    expect(find.text('Status'), findsOneWidget);

    // Nothing is editable: both dropdowns are disabled (onChanged == null) and
    // there is no Save button at all.
    final dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .toList();
    expect(dropdowns, isNotEmpty);
    for (final dropdown in dropdowns) {
      expect(dropdown.onChanged, isNull);
    }
    expect(find.byKey(const Key('item-save-button')), findsNothing);
  });

  testWidgets('TC-30-03: editor save persists only the permitted fields',
      (tester) async {
    final backend = await openDetail(tester, 'bob');

    // bob (editor) can edit the title (full) but not the assignee (read).
    await tester.enterText(find.byType(TextField).first, 'Reworked landing copy');
    await tester.tap(find.byKey(const Key('item-save-button')));
    await tester.pumpAndSettle();

    // The persisted item carries the new title; the read-only assignee is
    // untouched (the bound value flowed straight back through save).
    final after = await backend.listItems('l-1');
    final saved = after.firstWhere((i) => i.id.get() == 'i-1');
    expect(saved.title.get(), 'Reworked landing copy');
    expect(saved.assigneeId.get(), 'u-bob');
  });
}
