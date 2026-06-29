/// The application shell: a [MaterialApp] that swaps between the login and board
/// screens as a pure function of [AppSession.isLoggedIn] (step 27).
///
/// The session is a [ChangeNotifier]; a [ListenableBuilder] rebuilds the home on
/// every login/logout, so "signed out → signed in" (and a dropped session
/// routing back to login) is state-driven rather than imperative navigation.
library;

import 'package:flutter/material.dart';

import '../screens/board_screen.dart';
import '../screens/login_screen.dart';
import 'app_session.dart';

/// Root widget: owns the [AppSession] and renders login vs. board.
class AdvancedTodoApp extends StatelessWidget {
  /// Creates the app over [session] (bootstrap injects in-memory or live).
  const AdvancedTodoApp({super.key, required this.session});

  /// The session driving the authenticated experience.
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Todo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => session.isLoggedIn
            ? BoardScreen(session: session)
            : LoginScreen(session: session),
      ),
    );
  }
}
