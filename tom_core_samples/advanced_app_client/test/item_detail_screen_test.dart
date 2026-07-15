/// Widget tests for the item-detail screen (step 30, RCC2): the bound
/// `TomForm<TodoItem>` whose per-field controls are graded through the framework
/// authorization registry.
///
/// This is the heart of what the sample teaches — the *same* [ItemDetailScreen]
/// (and the [TodoItemForm] it builds) renders differently per role because it
/// resolves each field's resource-level ceiling through the framework registry
/// (the login-installed [TomResourceRoleAdapter]) and narrows it by the shared
/// per-role field-grade matrix:
///
/// - `owner` (alice) edits every gradable field — a full editor with a Save.
/// - `viewer` (carol, shared in for the test) sees read-only fields, a *disabled*
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
// The app seed owns the authoritative `initializeReflection`; the domain is a
// library and ships no seed, so this import pulls only the enum and the shared
// role→state vocabulary registrar the tests need.
import 'package:advanced_todo_domain/advanced_todo_domain.dart'
    show ProjectRole, registerProjectRoleVocabulary;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const <String, dynamic>{}),
    );
    // The registry is the load-bearing gate: without the shared vocabulary,
    // every role resolves to `none` and all fields collapse. `main` registers it
    // at boot; each test installs the same mapping so `session.login` can resolve
    // the principal's resource-level ceiling through the framework adapter.
    registerProjectRoleVocabulary();
  });

  // Login installs an [AppResourceRoleAdapter] as the [TomAuthorization]
  // singleton and the vocabulary populates the [TomResourceRoleRegistry]; reset
  // both between tests so no adapter or role mapping leaks across cases.
  tearDown(() {
    TomAuthorization.reset();
    TomResourceRoleRegistry.reset();
  });

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
  /// persisted state.
  ///
  /// [shareCarolAs] grants `carol` that project role first (carol has no access in the
  /// seed), so the viewer/commenter cases — neither seeded with access — can open
  /// the item. [bundleOverride], if given, is installed over the
  /// session-installed full bundle *after* login and *before* the screen builds,
  /// so a test can prove the field labels come from the installed resource
  /// provider (not a hard-coded override or the bare tomId fallback).
  Future<InMemoryAppBackend> openDetail(
    WidgetTester tester,
    String user, {
    String itemId = 'i-1',
    ProjectRole? shareCarolAs,
    Map<String, dynamic>? bundleOverride,
  }) async {
    useTallViewport(tester);

    final backend = InMemoryAppBackend();
    final session = AppSession(backend);
    // `session.login` (below) snapshots the principal's per-resource role grants
    // and installs them as the framework [TomAuthorization] adapter, exactly as
    // `main` wires it. The detail screen then resolves each field's ceiling
    // through the registry and narrows by the shared field-grade matrix — the
    // four-role render matrix falls out of that composition.

    if (shareCarolAs != null) {
      await session.login(login('alice'));
      await backend.share(ShareRequest(
        resourceType: 'project',
        resourceId: 'p-1',
        granteeUserId: 'u-carol',
        projectRole: shareCarolAs,
      ));
      await session.logout();
    }

    await session.login(login(user));
    // Login installs the full server bundle (todo 9); a test may replace it with
    // a sentinel bundle to prove labels are provider-driven end-to-end.
    if (bundleOverride != null) {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(bundleOverride),
      );
    }
    final items = await backend.listItems('l-1');
    final item = items.firstWhere((i) => i.id.get() == itemId);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              TomPageRoute<bool>(
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
    // not an exact count). These strings are the *server bundle* values
    // (`InMemoryAppBackend.fullTexts`) the session installs on login — with the
    // form's `labelTextOverride`s gone (todo 10) they can only come from the
    // installed provider, and each differs from the bare tomId fallback
    // (`title`, `status`, …), so their presence is the bundle-sourced proof.
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
    await openDetail(tester, 'carol', shareCarolAs: ProjectRole.viewer);

    // The ungranted field (estimate → none) collapses entirely…
    expect(find.text('Estimate (h)'), findsNothing);
    // …while the disabled status control is still visible.
    expect(find.text('Status'), findsOneWidget);
    // Priority is `read` for a viewer (not `none`), so it stays visible — this is
    // what separates the viewer matrix from the commenter's (TC-30-04), where
    // priority is hidden.
    expect(find.text('Priority'), findsWidgets);

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

  testWidgets(
      'TC-30-04: commenter hides priority + estimate, reads the rest, no Save',
      (tester) async {
    await openDetail(tester, 'carol', shareCarolAs: ProjectRole.commenter);

    // The commenter matrix grades both priority and estimate `none`, so the
    // closed-safe render hides *both* fields (D-A4 made visible end-to-end) —
    // this is the only role that hides priority.
    expect(find.text('Priority'), findsNothing);
    expect(find.text('Estimate (h)'), findsNothing);

    // The remaining five fields are `read`: present but never editable.
    expect(find.text('Title'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Assignee id'), findsWidgets);
    expect(find.text('Due date'), findsWidgets);
    expect(find.text('Description'), findsWidgets);

    // No field is `full`, so the screen offers no Save, and the status dropdown
    // (graded `read`) is disabled like every other control.
    expect(find.byKey(const Key('item-save-button')), findsNothing);
    final dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .toList();
    expect(dropdowns, isNotEmpty);
    for (final dropdown in dropdowns) {
      expect(dropdown.onChanged, isNull);
    }
  });

  testWidgets(
      'TC-30-05: field labels are server-bundle-driven (sentinel proof)',
      (tester) async {
    // Sign in as the owner (every field `full`, so all seven render), but
    // replace the installed full bundle with sentinel label values distinct from
    // both the canned strings and the bare tomId fallback. With the form's
    // overrides removed (todo 10) the only source of a field's label is this
    // provider, so the sentinels rendering proves the labels are bundle-driven.
    await openDetail(tester, 'alice', bundleOverride: {
      'todo.item.title.label': 'Title [srv]',
      'todo.item.status.label': 'Status [srv]',
      'todo.item.priority.label': 'Priority [srv]',
      'todo.item.assigneeId.label': 'Assignee [srv]',
      'todo.item.dueDate.label': 'Due date [srv]',
      'todo.item.estimate.label': 'Estimate [srv]',
      'todo.item.description.label': 'Description [srv]',
    });

    expect(find.textContaining('Title [srv]'), findsWidgets);
    expect(find.textContaining('Status [srv]'), findsWidgets);
    expect(find.textContaining('Priority [srv]'), findsWidgets);
    expect(find.textContaining('Assignee [srv]'), findsWidgets);
    expect(find.textContaining('Due date [srv]'), findsWidgets);
    expect(find.textContaining('Estimate [srv]'), findsWidgets);
    expect(find.textContaining('Description [srv]'), findsWidgets);

    // Neither the canned bundle value nor the bare tomId fallback renders — the
    // label resolves through the installed provider, nothing else.
    expect(find.text('Title'), findsNothing);
    expect(find.text('title'), findsNothing);
  });
}
