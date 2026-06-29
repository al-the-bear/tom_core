/// The admin console shell: a [MaterialApp] that swaps between the login and the
/// console (shell) screen as a pure function of [AdminSession.isLoggedIn]
/// (step 33).
///
/// The session is a [ChangeNotifier]; a [ListenableBuilder] rebuilds the home on
/// every login/logout, so "signed out → signed in" (and a sign-out routing back
/// to login) is state-driven rather than imperative navigation. The Users/Roles/
/// Groups, grant-matrix, and assignments screens (steps 34–36) hang off the
/// console shell.
library;

import 'package:flutter/material.dart';

import '../screens/admin_login_screen.dart';
import '../screens/admin_shell_screen.dart';
import 'admin_session.dart';

/// Root widget: owns the [AdminSession] and renders login vs. the console shell.
class AdminConsoleApp extends StatelessWidget {
  /// Creates the console over [session] (bootstrap injects in-memory or live).
  const AdminConsoleApp({super.key, required this.session});

  /// The session driving the authenticated console.
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Todo — Admin',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => session.isLoggedIn
            ? AdminShellScreen(session: session)
            : AdminLoginScreen(session: session),
      ),
    );
  }
}
