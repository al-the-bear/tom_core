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
/// The screen's two **child sections** — the comment thread and the checklist —
/// are covered from TC-30-06 on. They carry their own gates, distinct from the
/// field matrix above: the thread is readable by anyone who can open the item
/// (a viewer reads what they may not add to), while adding or ticking a
/// checklist step is `editor`-and-above, one step stronger than commenting.
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
  ///
  /// [height] exists because the screen's body is a `ListView`: a sliver only
  /// *builds* the children it can lay out, so a section scrolled past the
  /// bottom edge is absent from the element tree and `find.byKey` reports it
  /// missing. The child sections (checklist + thread) sit below the fields, so
  /// the tests that assert on them ask for a taller window rather than
  /// scrolling — scrolling would make every later `find` order-dependent.
  void useTallViewport(WidgetTester tester, {double height = 2400}) {
    tester.view.physicalSize = Size(1000, height);
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
    double viewportHeight = 2400,
  }) async {
    useTallViewport(tester, height: viewportHeight);

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

  // ---------------------------------------------------------------------------
  // The two child sections (tcca21): the comment thread and the checklist.
  //
  // These prove the half of the item screen that the step-30 seam could not
  // reach: reading a thread and a checklist back, and writing to them under a
  // gate one step *stronger* than the comment composer's. The seed puts one
  // comment and two subtasks (one already done) on `i-1`, so an assertion about
  // ordering and checked state has something to be about.
  // ---------------------------------------------------------------------------

  /// The checklist rows need room below the seven fields, so the child-section
  /// tests open on a taller window (see [useTallViewport]).
  const double childSectionViewport = 4200;

  testWidgets(
      'TC-30-06: the item renders its seeded thread and checklist in order',
      (tester) async {
    await openDetail(tester, 'alice', viewportHeight: childSectionViewport);

    // The thread: one seeded comment, rendered with its author byline and body.
    expect(find.byKey(const Key('comment-thread')), findsOneWidget);
    expect(find.byKey(const Key('comment-c-1')), findsOneWidget);
    expect(find.text('Started on the hero section — draft attached.'),
        findsOneWidget);
    // The byline is bundle-driven (`board.item.comment.byline`) with both
    // placeholders substituted — the seeded author and the seeded timestamp.
    expect(find.text('u-bob · 2026-07-01 09:30'), findsOneWidget);

    // The checklist: both steps, in `position` order, with the first ticked.
    expect(find.byKey(const Key('subtask-list')), findsOneWidget);
    expect(find.text('Collect the reference sites'), findsOneWidget);
    expect(find.text('Write the hero paragraph'), findsOneWidget);
    final boxes = tester
        .widgetList<Checkbox>(find.descendant(
            of: find.byKey(const Key('subtask-list')),
            matching: find.byType(Checkbox)))
        .toList();
    expect(boxes.map((b) => b.value), [true, false],
        reason: 'position order is preserved and s-1 is the done one');
  });

  testWidgets('TC-30-07: an owner adds a checklist step and it is persisted',
      (tester) async {
    final backend =
        await openDetail(tester, 'alice', viewportHeight: childSectionViewport);

    await tester.enterText(
        find.descendant(
            of: find.byKey(const Key('subtask-input')),
            matching: find.byType(TextField)),
        'Pick the hero image');
    await tester.tap(find.byKey(const Key('subtask-submit-button')));
    await tester.pumpAndSettle();

    // The screen re-read the list rather than patching it locally, so the row
    // it shows is the persisted one — and the backend agrees.
    expect(find.text('Pick the hero image'), findsOneWidget);
    final stored = await backend.listSubtasks('i-1');
    expect(stored.map((s) => s.title.get()),
        containsAllInOrder(<String>['Collect the reference sites',
          'Write the hero paragraph', 'Pick the hero image']));
    // The composer is cleared, so a second tap cannot re-post the same step.
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const Key('subtask-input')),
                matching: find.byType(TextField)))
            .controller
            ?.text,
        isEmpty);
  });

  testWidgets('TC-30-08: an owner ticks a step and the toggle is persisted',
      (tester) async {
    final backend =
        await openDetail(tester, 'alice', viewportHeight: childSectionViewport);

    // The second row (`s-2`) starts unticked; tap its checkbox.
    await tester.tap(find.descendant(
        of: find.byKey(const Key('subtask-s-2')),
        matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();

    final stored = await backend.listSubtasks('i-1');
    expect(stored.firstWhere((s) => s.id.get() == 's-2').done.get(), isTrue);
    // The title round-tripped: the toggle sends the whole row, so ticking a box
    // must not blank the step it belongs to.
    expect(stored.firstWhere((s) => s.id.get() == 's-2').title.get(),
        'Write the hero paragraph');
  });

  testWidgets(
      'TC-30-09: a viewer reads both sections but gets no checklist composer',
      (tester) async {
    final backend = await openDetail(tester, 'carol',
        shareCarolAs: ProjectRole.viewer,
        viewportHeight: childSectionViewport);

    // Both histories are readable — the thread is gated by the *item's*
    // readability alone, so a viewer sees the discussion they may not join…
    expect(find.byKey(const Key('comment-thread')), findsOneWidget);
    expect(find.text('Started on the hero section — draft attached.'),
        findsOneWidget);
    expect(find.byKey(const Key('subtask-list')), findsOneWidget);
    expect(find.text('Collect the reference sites'), findsOneWidget);

    // …but the checklist composer is absent entirely (a control that could only
    // ever be refused), as is the comment composer's editor-gated sibling.
    expect(find.byKey(const Key('subtask-input')), findsNothing);
    expect(find.byKey(const Key('subtask-submit-button')), findsNothing);

    // And the rows themselves are inert: the `read` grade wraps each checkbox in
    // the framework's readonly treatment, so a tap changes nothing.
    await tester.tap(
        find.descendant(
            of: find.byKey(const Key('subtask-s-2')),
            matching: find.byType(Checkbox)),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    final stored = await backend.listSubtasks('i-1');
    expect(stored.firstWhere((s) => s.id.get() == 's-2').done.get(), isFalse);
  });
}
