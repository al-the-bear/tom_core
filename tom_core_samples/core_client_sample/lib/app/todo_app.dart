/// The application shell: a [MaterialApp] that swaps between the login screen
/// and the todo list based on [AppSession.isLoggedIn].
///
/// The session is a [ChangeNotifier]; a [ListenableBuilder] rebuilds the home
/// on login/logout, so navigation between "signed out" and "signed in" is a
/// pure function of session state rather than imperative routing.
library;

import 'package:flutter/material.dart';

import '../api/live_todo_read_client.dart';
import '../screens/login_screen.dart';
import '../screens/todo_lists_screen.dart';
import 'app_session.dart';

/// Root widget: owns the [AppSession] and renders login vs. list.
class TodoApp extends StatelessWidget {
  /// Creates the app over [session]; [liveClient] enables the live read path.
  const TodoApp({super.key, required this.session, this.liveClient});

  /// The session driving the authenticated experience.
  final AppSession session;

  /// Optional client for the "refresh from live server" action.
  final LiveTodoReadClient? liveClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Todo',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => session.isLoggedIn
            ? TodoListsScreen(session: session, liveClient: liveClient)
            : LoginScreen(session: session),
      ),
    );
  }
}
