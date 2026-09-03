/// The Groups destination: list groups and create/edit/delete them, editing
/// membership as a checklist alongside the bound [GroupForm].
///
/// A configuration of [AdminCrudScreen] with one extra: a group's membership is
/// a list of user ids, not a scalar field, so the editor pairs the form (which
/// owns only the name) with a [_MembershipChecklist] over every account. The
/// editor loads the user list first so the checklist can render names; the
/// checked set folds straight into the [GroupDto.memberUserIds] on save.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/admin_actions.dart';
import '../app/admin_session.dart';
import '../backend/backend.dart';
import '../domain/admin_drafts.dart';
import '../forms/group_form.dart';
import 'admin_crud_screen.dart';
import 'admin_editor_dialog.dart';

/// Lists and edits groups (name + membership) over [session].
class GroupsScreen extends StatelessWidget {
  /// Creates the Groups destination bound to [session].
  const GroupsScreen({super.key, required this.session});

  /// The session every backend call is guarded through.
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return AdminCrudScreen<GroupDto>(
      session: session,
      tilePrefix: 'groups',
      createLabel: TomCtr.text('admin.groups.create'),
      emptyText: TomCtr.text('admin.groups.empty'),
      load: (backend) => backend.listGroups(),
      idOf: (group) => group.id,
      titleOf: (group) => group.name,
      subtitleOf: (group) {
        final count = group.memberUserIds.length;
        final template = count == 1
            ? TomCtr.text('admin.groups.memberCount')
            : TomCtr.text('admin.groups.memberCountPlural');
        return template.replaceAll('{count}', '$count');
      },
      onCreate: _create,
      onEdit: _edit,
      onDelete: (group) => runAdminAction(
        adminActions.deleteGroup,
        DeleteGroupContext(session, group.id),
      ),
      createAuthorizer: adminActions.createGroup.authorizer,
      deleteAuthorizer: adminActions.deleteGroup.authorizer,
    );
  }

  /// Opens the create editor (name + membership) and posts a [GroupDto] on save.
  Future<bool> _create(BuildContext context) async {
    final users = await _loadUsers(context);
    if (users == null || !context.mounted) return false;
    final form = GroupForm();
    final draft = GroupDraft();
    form.bind(draft);
    final selected = <String>{};
    try {
      return await showAdminEditor(
        context,
        title: TomCtr.text('admin.groups.create'),
        children: [
          for (final field in form.editableFields) field.widget,
          _MembershipChecklist(users: users, selected: selected),
        ],
        submit: () async {
          if (!await form.save()) return '';
          final group = GroupDto(
            name: draft.name.get(),
            memberUserIds: selected.toList(),
          );
          return runAdminAction(
            adminActions.createGroup,
            CreateGroupContext(session, group),
          );
        },
      );
    } finally {
      form.dispose();
    }
  }

  /// Opens the edit editor for [group], pre-checking its current members.
  Future<bool> _edit(BuildContext context, GroupDto group) async {
    final users = await _loadUsers(context);
    if (users == null || !context.mounted) return false;
    final form = GroupForm();
    final draft = GroupDraft()..name.set(group.name);
    form.bind(draft);
    final selected = {...group.memberUserIds};
    try {
      return await showAdminEditor(
        context,
        title: TomCtr.text('admin.groups.edit'),
        children: [
          for (final field in form.editableFields) field.widget,
          _MembershipChecklist(users: users, selected: selected),
        ],
        submit: () async {
          if (!await form.save()) return '';
          final updated = GroupDto(
            id: group.id,
            name: draft.name.get(),
            memberUserIds: selected.toList(),
          );
          return runAdminAction(
            adminActions.updateGroup,
            UpdateGroupContext(session, group.id, updated),
          );
        },
      );
    } finally {
      form.dispose();
    }
  }

  /// Loads the accounts the membership checklist offers; surfaces a failure as a
  /// snackbar and returns null (the editor does not open).
  Future<List<UserDto>?> _loadUsers(BuildContext context) async {
    try {
      return await session.guard((backend) => backend.listUsers());
    } on AdminBackendException catch (e) {
      if (context.mounted) {
        TomMessenger.showSnackBar(
          context,
          TomSnackBar(content: TomText(text: e.message)),
        );
      }
      return null;
    }
  }
}

/// A checklist of every account, toggling membership in the shared [selected]
/// set the editor reads back on save.
class _MembershipChecklist extends StatefulWidget {
  const _MembershipChecklist({required this.users, required this.selected});

  /// Every account the group may include.
  final List<UserDto> users;

  /// The mutable set of selected member ids — mutated in place as boxes toggle
  /// and read by the editor's submit callback.
  final Set<String> selected;

  @override
  State<_MembershipChecklist> createState() => _MembershipChecklistState();
}

class _MembershipChecklistState extends State<_MembershipChecklist> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TomText(
            text: TomCtr.text('admin.groups.members'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final user in widget.users)
          TomCheckboxListTile(
            key: Key('group-member-${user.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: widget.selected.contains(user.id),
            titleText: user.displayName.isEmpty
                ? user.username
                : user.displayName,
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                widget.selected.add(user.id);
              } else {
                widget.selected.remove(user.id);
              }
            }),
          ),
      ],
    );
  }
}
