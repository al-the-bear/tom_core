/// The admin console shell: the signed-in frame that hosts the administrative
/// destinations behind a [NavigationRail] (steps 33–34).
///
/// Once an administrator is authenticated the [AdminConsoleApp] shows this
/// shell. It owns the app bar (with sign-out, which clears the session and
/// routes back to login) and a rail selecting between the Users, Roles, and
/// Groups destinations, kept in an [IndexedStack] so each screen's list state
/// survives a tab switch. The grant-matrix (step 35) and assignments (step 36)
/// destinations are added to this same rail later.
library;

import 'package:flutter/material.dart';

import '../app/admin_session.dart';
import 'groups_screen.dart';
import 'roles_screen.dart';
import 'users_screen.dart';

/// The authenticated console frame, wired to [session].
class AdminShellScreen extends StatefulWidget {
  /// Creates the shell over [session] (the signed-in administrator).
  const AdminShellScreen({super.key, required this.session});

  /// The active admin session driving the destinations and sign-out.
  final AdminSession session;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  AdminSession get _session => widget.session;

  @override
  Widget build(BuildContext context) {
    // The rail destinations and the matching bodies stay index-aligned. Grants
    // (step 35) and assignments (step 36) append to both lists here later.
    final destinations = <NavigationRailDestination>[
      _destination(Icons.people_outline, Icons.people, 'Users'),
      _destination(Icons.badge_outlined, Icons.badge, 'Roles'),
      _destination(Icons.groups_outlined, Icons.groups, 'Groups'),
    ];
    final bodies = <Widget>[
      UsersScreen(session: _session),
      RolesScreen(session: _session),
      GroupsScreen(session: _session),
    ];

    return Scaffold(
      key: const Key('admin-shell-screen'),
      appBar: AppBar(
        title: const Text('Advanced Todo — Admin console'),
        actions: [
          IconButton(
            key: const Key('admin-sign-out'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _session.logout,
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: bodies),
          ),
        ],
      ),
    );
  }

  NavigationRailDestination _destination(
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    return NavigationRailDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: Text(label),
    );
  }
}
