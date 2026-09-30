// Widget tests for the detail screen: CRUD through the bound form, plus the
// per-role four-state authorization rendering. These are the heart of what the
// sample teaches — the same TodoItemForm renders differently for owner, member
// and viewer because it is constructed with the session's resolved field matrix.

import 'dart:async';
import 'dart:io';

import 'package:core_client_sample/api/in_memory_todo_api.dart';
import 'package:core_client_sample/api/live_todo_read_client.dart';
import 'package:core_client_sample/app/app_session.dart';
import 'package:core_client_sample/app/todo_app.dart';
import 'package:core_client_sample/reflection_seed.dart';
import 'package:core_client_sample/resources/app_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_domain/todo_domain.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(appTexts),
    );
  });

  Future<AppSession> pumpSignedIn(
    WidgetTester tester,
    String user, {
    LiveTodoReadClient? liveClient,
    InMemoryTodoApi? api,
  }) async {
    // A tall viewport so the detail form's fields and Save button all fit
    // on-screen (the default 800×600 window scrolls the button out of reach).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = AppSession(api ?? InMemoryTodoApi());
    await tester.pumpWidget(TodoApp(session: session, liveClient: liveClient));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), user);
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> openFirstItem(WidgetTester tester) async {
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
  }

  testWidgets('CCS-CRUD-01: owner sees every gradable field on a todo', (
    tester,
  ) async {
    await pumpSignedIn(tester, 'alice');
    await openFirstItem(tester);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Assignee id'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('CCS-CRUD-02: member never sees priority (TomAuthState.none)', (
    tester,
  ) async {
    await pumpSignedIn(tester, 'bob');
    await openFirstItem(tester);
    expect(find.text('Title'), findsOneWidget);
    // priority is `none` for member → the field collapses to nothing.
    expect(find.text('Priority'), findsNothing);
  });

  /// The detail screen's three text inputs, in form order: title,
  /// description, assignee id. Priority is a dropdown and done a switch.
  List<TextField> textInputs(WidgetTester tester) {
    final inputs = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(inputs, hasLength(3), reason: 'title, description, assigneeId');
    return inputs;
  }

  testWidgets(
    'CCS-CRUD-05: viewer sees done disabled and title read - both refuse input',
    (tester) async {
      await pumpSignedIn(tester, 'val');
      await openFirstItem(tester);

      // `done` is TomAuthState.disabled: visible, and the switch takes no input.
      expect(find.text('Done'), findsOneWidget);
      final done = tester.widget<Switch>(find.byType(Switch));
      expect(done.onChanged, isNull, reason: 'disabled must not toggle');
      final before = done.value;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, before);

      // `title` and `assigneeId` are TomAuthState.read: shown, not editable, and
      // title's required marker - an instruction to fill it in - is not drawn.
      final [title, _, assignee] = textInputs(tester);
      expect(title.enabled, isFalse, reason: 'read must not be editable');
      expect(assignee.enabled, isFalse, reason: 'read must not be editable');
      expect(find.text('Title'), findsOneWidget);
      expect(find.text(' *'), findsNothing);
    },
  );

  testWidgets(
    'CCS-CRUD-06: owner gets the same fields editable - the contrast CRUD-05 '
    'is measured against',
    (tester) async {
      await pumpSignedIn(tester, 'alice');
      await openFirstItem(tester);

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      final [title, _, assignee] = textInputs(tester);
      expect(title.enabled, isNot(isFalse));
      expect(assignee.enabled, isNot(isFalse));
      expect(find.text(' *'), findsOneWidget, reason: 'title is required');
    },
  );

  testWidgets(
    'CCS-CRUD-07: description is ungraded - editable even for the viewer',
    (tester) async {
      // The one field declared without an authorizer: the matrix never reaches
      // it, so it renders at `full` for every role. That is the sample's
      // gradable / ungraded distinction, shown on the viewer - the role for
      // whom every graded field refuses input.
      await pumpSignedIn(tester, 'val');
      await openFirstItem(tester);
      final [_, description, _] = textInputs(tester);
      expect(description.enabled, isNot(isFalse));
    },
  );

  testWidgets('CCS-CRUD-03: owner creates a todo and it appears in the list', (
    tester,
  ) async {
    await pumpSignedIn(tester, 'alice');
    await tester.tap(find.byTooltip('New todo'));
    await tester.pumpAndSettle();

    // The Title field is the first TextField on the detail screen.
    await tester.enterText(find.byType(TextField).first, 'Fresh todo');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh todo'), findsOneWidget);
  });

  testWidgets('CCS-CRUD-04: saving a new todo with an empty title is blocked', (
    tester,
  ) async {
    await pumpSignedIn(tester, 'alice');
    await tester.tap(find.byTooltip('New todo'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Still on the detail screen — validation kept us here.
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });

  /// The list's row titles, in order.
  List<String> rowTitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      ((tile.title as Text?)?.data ?? ''),
  ];

  testWidgets(
    'CCS-CRUD-08: deleting an existing todo removes it from the list',
    (tester) async {
      await pumpSignedIn(tester, 'alice');
      final before = rowTitles(tester);
      await openFirstItem(tester);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      // Back on the list, one row fewer, and the opened row is the one gone.
      expect(find.byTooltip('New todo'), findsOneWidget);
      expect(rowTitles(tester), before.sublist(1));
    },
  );

  testWidgets('CCS-CRUD-09: delete is offered only for an existing todo', (
    tester,
  ) async {
    await pumpSignedIn(tester, 'alice');
    await tester.tap(find.byTooltip('New todo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets(
    'CCS-CRUD-10: while a delete is in flight, delete and save are disabled',
    (tester) async {
      final gate = Completer<void>();
      await pumpSignedIn(tester, 'alice', api: _GatedDeleteApi(gate.future));
      await openFirstItem(tester);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byTooltip('New todo'), findsOneWidget);
    },
  );

  testWidgets('CCS-CRUD-11: with no live client there is no live action', (
    tester,
  ) async {
    await pumpSignedIn(tester, 'alice');
    expect(find.byTooltip('Refresh from live server'), findsNothing);
  });

  testWidgets(
    'CCS-CRUD-12: live refresh shows the server rows read-only, then goes back',
    (tester) async {
      final live = _FakeLiveClient(
        todos: [
          TodoItem()
            ..id.set('90')
            ..title.set('From the server'),
          TodoItem()
            ..id.set('91')
            ..title.set('Also from the server'),
        ],
      );
      await pumpSignedIn(tester, 'alice', liveClient: live);
      final local = rowTitles(tester);

      await tester.tap(find.byTooltip('Refresh from live server'));
      await tester.pumpAndSettle();

      expect(live.fetches, 1);
      expect(rowTitles(tester), ['From the server', 'Also from the server']);
      expect(
        find.text('Showing live server data (read-only).'),
        findsOneWidget,
      );
      expect(
        find.text('Loaded 2 item(s) from the live server.'),
        findsOneWidget,
      );

      // Live rows are read-only: a tap opens nothing.
      await tester.tap(find.text('From the server'));
      await tester.pumpAndSettle();
      expect(find.text('Edit todo'), findsNothing);

      // "Back to my list" restores the local rows and drops the banner.
      await tester.tap(find.text('Back to my list'));
      await tester.pumpAndSettle();
      expect(rowTitles(tester), local);
      expect(find.text('Showing live server data (read-only).'), findsNothing);
    },
  );

  testWidgets(
    'CCS-CRUD-13: an unreachable live server reports it and keeps the local list',
    (tester) async {
      final live = _FakeLiveClient(
        error: const SocketException('Connection refused'),
      );
      await pumpSignedIn(tester, 'alice', liveClient: live);
      final local = rowTitles(tester);

      await tester.tap(find.byTooltip('Refresh from live server'));
      await tester.pumpAndSettle();

      expect(live.fetches, 1);
      expect(find.textContaining('Live server unreachable:'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(find.text('Showing live server data (read-only).'), findsNothing);
      expect(rowTitles(tester), local);
    },
  );
}

/// A live client that answers [fetchTodos] from memory - [todos], or [error]
/// thrown - and counts the calls. The rest of the client is never reached by
/// the list screen.
class _FakeLiveClient extends LiveTodoReadClient {
  _FakeLiveClient({this.todos = const [], this.error})
    : super('http://live.invalid');

  final List<TodoItem> todos;
  final Object? error;
  int fetches = 0;

  @override
  Future<List<TodoItem>> fetchTodos() async {
    fetches++;
    if (error case final e?) throw e;
    return todos;
  }
}

/// An in-memory backend whose delete waits for [gate], so a test can look at
/// the screen while the call is in flight.
class _GatedDeleteApi extends InMemoryTodoApi {
  _GatedDeleteApi(this.gate);

  final Future<void> gate;

  @override
  Future<void> deleteItem(String id) async {
    await gate;
    return super.deleteItem(id);
  }
}
