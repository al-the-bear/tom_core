/// The board screen the app shell shows while [AppSession.isLoggedIn] is true
/// (step 27 scaffold).
///
/// Step 27 wires only the switch, so this is a minimal placeholder keyed
/// `board-screen`: it shows the signed-in principal and a logout action (the
/// other half of the login↔board switch). Step 29 fills the body with the
/// workspace/project picker and the status-column item board.
library;

import 'package:flutter/material.dart';

import '../app/app_session.dart';

/// Signed-in home: the (step 29) workspace picker + status-column board.
class BoardScreen extends StatelessWidget {
  /// Creates the board over [session] (its principal + backend drive the board).
  const BoardScreen({super.key, required this.session});

  /// The active session whose principal the board belongs to.
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final name = session.user?.displayName ?? session.user?.username ?? '';
    return Scaffold(
      key: const Key('board-screen'),
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          IconButton(
            key: const Key('logout-button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: session.logout,
          ),
        ],
      ),
      body: Center(child: Text('Signed in as $name')),
    );
  }
}
