/// The login screen the app shell shows while [AppSession.isLoggedIn] is false
/// (step 27 scaffold).
///
/// Step 27 establishes only the bootstrap + session + the login↔board switch, so
/// this is a minimal placeholder keyed `login-screen` that the shell renders and
/// the widget test asserts on. Step 28 replaces the body with the bound
/// `TomForm` over credentials (inline error on a rejected login) that calls
/// [AppSession.login].
library;

import 'package:flutter/material.dart';

import '../app/app_session.dart';

/// Signed-out home: branding + the (step 28) credential form.
class LoginScreen extends StatelessWidget {
  /// Creates the login screen over [session] (the step-28 form drives
  /// [AppSession.login] through it).
  const LoginScreen({super.key, required this.session});

  /// The session the credential form authenticates against.
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login-screen'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.checklist_rounded, size: 48),
            SizedBox(height: 12),
            Text('Advanced Todo', style: TextStyle(fontSize: 22)),
            SizedBox(height: 4),
            Text('Please sign in.'),
          ],
        ),
      ),
    );
  }
}
