/// The Roles destination: list roles and create/edit/delete them through a bound
/// [RoleForm] (step 34).
///
/// A thin configuration of [AdminCrudScreen]. The role [RoleDto.key] is the
/// stable identifier the grant matrix and `@TomRoleAccess` key on, so it is
/// editable only on create; on edit it renders read-only and only the
/// human-facing name changes.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/admin_actions.dart';
import '../app/admin_session.dart';
import '../domain/admin_drafts.dart';
import '../forms/role_form.dart';
import 'admin_crud_screen.dart';
import 'admin_editor_dialog.dart';

/// Lists and edits roles over [session].
class RolesScreen extends StatelessWidget {
  /// Creates the Roles destination bound to [session].
  const RolesScreen({super.key, required this.session});

  /// The session every backend call is guarded through.
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return AdminCrudScreen<RoleDto>(
      session: session,
      tilePrefix: 'roles',
      createLabel: TomCtr.text('admin.roles.create'),
      emptyText: TomCtr.text('admin.roles.empty'),
      load: (backend) => backend.listRoles(),
      idOf: (role) => role.key,
      titleOf: (role) => role.name.isEmpty ? role.key : role.name,
      subtitleOf: (role) => role.key,
      onCreate: _create,
      onEdit: _edit,
      onDelete: (role) =>
          runAdminAction(adminActions.deleteRole, DeleteRoleContext(session, role.key)),
      createAuthorizer: adminActions.createRole.authorizer,
      deleteAuthorizer: adminActions.deleteRole.authorizer,
    );
  }

  /// Opens the create editor and posts a new [RoleDto] on save.
  Future<bool> _create(BuildContext context) async {
    final form = RoleForm();
    final draft = RoleDraft();
    form.bind(draft);
    try {
      return await showAdminEditor(
        context,
        title: TomCtr.text('admin.roles.create'),
        children: [for (final field in form.editableFields) field.widget],
        submit: () async {
          if (!await form.save()) return '';
          final role = RoleDto(key: draft.key.get(), name: draft.name.get());
          return runAdminAction(
              adminActions.createRole, CreateRoleContext(session, role));
        },
      );
    } finally {
      form.dispose();
    }
  }

  /// Opens the edit editor for [role] (key read-only) and renames it on save.
  Future<bool> _edit(BuildContext context, RoleDto role) async {
    final form = RoleForm(isCreate: false);
    final draft = RoleDraft()
      ..key.set(role.key)
      ..name.set(role.name);
    form.bind(draft);
    try {
      return await showAdminEditor(
        context,
        title: TomCtr.text('admin.roles.edit'),
        children: [for (final field in form.editableFields) field.widget],
        submit: () async {
          if (!await form.save()) return '';
          final updated = RoleDto(key: role.key, name: draft.name.get());
          return runAdminAction(adminActions.updateRole,
              UpdateRoleContext(session, role.key, updated));
        },
      );
    } finally {
      form.dispose();
    }
  }
}
