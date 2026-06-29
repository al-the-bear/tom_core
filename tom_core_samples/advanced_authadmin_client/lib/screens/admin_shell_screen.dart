/// The admin console shell: the signed-in landing the [AdminConsoleApp] shows
/// once an administrator is authenticated (step 33).
///
/// For now a placeholder destination that proves "admin proceeds past login" —
/// it names the signed-in administrator and offers sign-out (which clears the
/// session and routes back to login). The Users/Roles/Groups, grant-matrix, and
/// assignments destinations (steps 34–36) are added into this shell.
library;

import 'package:flutter/material.dart';

import '../app/admin_session.dart';

/// The authenticated console landing, wired to [session].
class AdminShellScreen extends StatelessWidget {
  /// Creates the shell over [session] (the signed-in administrator).
  const AdminShellScreen({super.key, required this.session});

  /// The active admin session driving sign-out.
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    final admin = session.user;
    return Scaffold(
      key: const Key('admin-shell-screen'),
      appBar: AppBar(
        title: const Text('Advanced Todo — Admin console'),
        actions: [
          IconButton(
            key: const Key('admin-sign-out'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: session.logout,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, size: 48),
            const SizedBox(height: 12),
            Text(
              'Signed in as ${admin?.displayName ?? admin?.username ?? 'admin'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Users, Roles, Groups, grants and assignments arrive in '
              'steps 34–36.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
