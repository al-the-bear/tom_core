/// The admin console shell: the signed-in frame that hosts the administrative
/// destinations behind a [NavigationRail].
///
/// Once an administrator is authenticated the [AdminConsoleApp] shows this
/// shell. It owns the app bar (with sign-out, which clears the session and
/// routes back to login) and a rail selecting between the Users, Roles, Groups,
/// Grants, and Assignments destinations, kept in an [IndexedStack] so each
/// screen's state survives a tab switch.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/admin_session.dart';
import 'assignments_screen.dart';
import 'grants_screen.dart';
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
    // The rail destinations and the matching bodies stay index-aligned.
    final destinations = <NavigationRailDestination>[
      _destination(
        Icons.people_outline,
        Icons.people,
        TomCtr.text('adminConsole.nav.users'),
      ),
      _destination(
        Icons.badge_outlined,
        Icons.badge,
        TomCtr.text('adminConsole.nav.roles'),
      ),
      _destination(
        Icons.groups_outlined,
        Icons.groups,
        TomCtr.text('adminConsole.nav.groups'),
      ),
      _destination(
        Icons.grid_on_outlined,
        Icons.grid_on,
        TomCtr.text('adminConsole.nav.grants'),
      ),
      _destination(
        Icons.assignment_ind_outlined,
        Icons.assignment_ind,
        TomCtr.text('adminConsole.nav.assignments'),
      ),
    ];
    final bodies = <Widget>[
      UsersScreen(session: _session),
      RolesScreen(session: _session),
      GroupsScreen(session: _session),
      GrantsScreen(session: _session),
      AssignmentsScreen(session: _session),
    ];

    // Shell chrome comes from the post-login console bundle (installed by
    // [AdminSession.login]); `adminConsole.title` has no grade counterpart and
    // no form override, so it renders the server text straight through [TomCtr].
    return TomScaffold(
      key: const Key('admin-shell-screen'),
      appBar: TomAppBar(
        title: TomText(text: TomCtr.text('adminConsole.title')),
        actions: [
          TomIconButton(
            key: const Key('admin-sign-out'),
            tooltip: TomCtr.text('adminConsole.signOut'),
            icon: const Icon(Icons.logout),
            onPressed: _session.logout,
          ),
        ],
      ),
      body: Row(
        children: [
          TomNavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: destinations,
          ),
          TomVerticalDivider(width: 1),
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
