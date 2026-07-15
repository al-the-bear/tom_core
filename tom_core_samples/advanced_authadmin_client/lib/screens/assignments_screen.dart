/// The Assignments destination: assign a role and/or a group to a user
/// (step 36).
///
/// Unlike the Users/Roles/Groups destinations this destination does not edit an
/// entity in place — it issues an [AssignmentRequest] (`POST /admin/assignments`)
/// that adds a role and/or a group membership to an existing account. The screen
/// lists every account; an account's **group** memberships are shown in its
/// subtitle (the seam reads those back via `listGroups`), while its **roles**
/// are not (the seam has no read-back for a user's roles), so the assign editor
/// lets an admin pick a role and/or a group and the persisted effect is what the
/// next reload — and the seeded backend's introspection — reports.
///
/// Every backend call is guarded by [AdminSession.guard], so a lost session
/// clears the principal and the shell rebuilds onto login uniformly with the
/// other destinations.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/admin_actions.dart';
import '../app/admin_session.dart';
import '../backend/backend.dart';
import 'admin_editor_dialog.dart';

/// Lists accounts and assigns roles/groups to them over [session].
class AssignmentsScreen extends StatefulWidget {
  /// Creates the Assignments destination bound to [session].
  const AssignmentsScreen({super.key, required this.session});

  /// The session every backend call is guarded through.
  final AdminSession session;

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<UserDto> _users = const [];
  List<GroupDto> _groups = const [];
  bool _loading = true;
  String? _error;

  AdminSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _session.guard((b) => b.listUsers());
      final groups = await _session.guard((b) => b.listGroups());
      if (!mounted) return;
      setState(() {
        _users = users;
        _groups = groups;
        _loading = false;
      });
    } on AdminBackendException catch (e) {
      // A lost session is already cleared by guard (the shell rebuilds to
      // login); other failures surface inline here.
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// The names of the groups [user] currently belongs to (read back from the
  /// loaded group list — roles have no such read-back).
  List<String> _groupsOf(UserDto user) => [
        for (final group in _groups)
          if (group.memberUserIds.contains(user.id)) group.name,
      ];

  /// Opens the assign editor for [user]: pick a role and/or a group, then post
  /// the [AssignmentRequest]. Reloads on success so the subtitle reflects any
  /// new group membership.
  Future<void> _assign(UserDto user) async {
    final roles = await _guard(() => _session.guard((b) => b.listRoles()));
    if (roles == null || !mounted) return;
    final groups = await _guard(() => _session.guard((b) => b.listGroups()));
    if (groups == null || !mounted) return;

    final choice = _AssignmentChoice();
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    final saved = await showAdminEditor(
      context,
      title: TomCtr.text('admin.assignments.assignTo')
          .replaceAll('{name}', name),
      children: [
        _AssignmentPicker(roles: roles, groups: groups, choice: choice),
      ],
      submit: () async {
        if (choice.roleKey == null && choice.groupId == null) {
          return TomCtr.text('admin.assignments.chooseError');
        }
        return runAdminAction(
          adminActions.assign,
          AssignContext(
            _session,
            AssignmentRequest(
              userId: user.id,
              roleKey: choice.roleKey ?? '',
              groupId: choice.groupId ?? '',
            ),
          ),
        );
      },
    );
    if (saved && mounted) {
      TomMessenger.showSnackBar(
        context,
        TomSnackBar(
            content: TomText(
                text: TomCtr.text('admin.assignments.assigned')
                    .replaceAll('{name}', name))),
      );
      await _load();
    }
  }

  /// Runs a guarded backend read, surfacing a failure as a snackbar and
  /// returning null (so the editor does not open).
  Future<T?> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AdminBackendException catch (e) {
      if (mounted) {
        TomMessenger.showSnackBar(
          context,
          TomSnackBar(content: TomText(text: e.message)),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('assignments-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TomText(
            text: TomCtr.text('admin.assignments.title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TomDivider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: TomCircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: TomText(
          text: _error!,
          key: const Key('assignments-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: TomText(
            text: TomCtr.text('admin.users.empty'),
            key: Key('assignments-empty')),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final groups = _groupsOf(user);
        return TomListTile(
          key: Key('assignments-tile-${user.id}'),
          titleText:
              user.displayName.isEmpty ? user.username : user.displayName,
          subtitle: TomText(
            text: groups.isEmpty
                ? TomCtr.text('admin.assignments.noGroups')
                : TomCtr.text('admin.assignments.groups')
                    .replaceAll('{groups}', groups.join(', ')),
          ),
          trailing: TomOutlinedButton(
            key: Key('assignments-assign-${user.id}'),
            authorizer: adminActions.assign.authorizer,
            onPressed: () => _assign(user),
            icon: const Icon(Icons.person_add_alt_1),
            child: TomText(text: TomCtr.text('admin.assignments.assign')),
          ),
        );
      },
    );
  }
}

/// The mutable selection the assign editor builds up and reads back on save: an
/// optional role key and an optional group id (null = not chosen).
class _AssignmentChoice {
  String? roleKey;
  String? groupId;
}

/// The assign editor body: a role picker and a group picker, each optional,
/// writing the selection into the shared [choice] the submit callback reads.
class _AssignmentPicker extends StatefulWidget {
  const _AssignmentPicker({
    required this.roles,
    required this.groups,
    required this.choice,
  });

  /// Every assignable role.
  final List<RoleDto> roles;

  /// Every assignable group.
  final List<GroupDto> groups;

  /// The mutable selection mutated as the dropdowns change.
  final _AssignmentChoice choice;

  @override
  State<_AssignmentPicker> createState() => _AssignmentPickerState();
}

class _AssignmentPickerState extends State<_AssignmentPicker> {
  @override
  Widget build(BuildContext context) {
    final roleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
            text: TomCtr.text('admin.assignments.roleLabel'),
            style: Theme.of(context).textTheme.labelLarge),
        TomDropdownButton<String?>(
          key: const Key('assignment-role-dropdown'),
          value: widget.choice.roleKey,
          isExpanded: true,
          items: [
            DropdownMenuItem(
                value: null,
                child: TomText(text: TomCtr.text('admin.assignments.noRole'))),
            for (final role in widget.roles)
              DropdownMenuItem(value: role.key, child: TomText(text: role.name)),
          ],
          onChanged: (value) => setState(() => widget.choice.roleKey = value),
        ),
      ],
    );
    final groupColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
            text: TomCtr.text('admin.assignments.groupLabel'),
            style: Theme.of(context).textTheme.labelLarge),
        TomDropdownButton<String?>(
          key: const Key('assignment-group-dropdown'),
          value: widget.choice.groupId,
          isExpanded: true,
          items: [
            DropdownMenuItem(
                value: null,
                child: TomText(text: TomCtr.text('admin.assignments.noGroup'))),
            for (final group in widget.groups)
              DropdownMenuItem(value: group.id, child: TomText(text: group.name)),
          ],
          onChanged: (value) => setState(() => widget.choice.groupId = value),
        ),
      ],
    );
    return AclBuilder()
        .setAclDefaultHideUnauthorized(true)
        .append(roleColumn, dist: 0)
        .append(groupColumn, dist: 12)
        .addRowBreakpoint(atWidth: 480)
        .build();
  }
}
