/// The Users destination: list accounts and create/edit/delete them through a
/// bound [UserForm] (step 34).
///
/// A thin configuration of [AdminCrudScreen]: it names how a [UserDto] row reads
/// and folds the reflected [UserDraft] the form edits into the wire types the
/// seam takes — a [CreateUserRequest] on create (the one place a password
/// crosses), a [UserDto] on edit (username is the stable key, so it stays
/// read-only and only the profile + status change).
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';
import '../domain/admin_drafts.dart';
import '../forms/user_form.dart';
import 'admin_crud_screen.dart';
import 'admin_editor_dialog.dart';

/// Lists and edits accounts over [session].
class UsersScreen extends StatelessWidget {
  /// Creates the Users destination bound to [session].
  const UsersScreen({super.key, required this.session});

  /// The session every backend call is guarded through.
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return AdminCrudScreen<UserDto>(
      session: session,
      tilePrefix: 'users',
      createLabel: 'New user',
      emptyText: 'No users yet.',
      load: (backend) => backend.listUsers(),
      idOf: (user) => user.id,
      titleOf: (user) =>
          user.displayName.isEmpty ? user.username : user.displayName,
      subtitleOf: (user) => '${user.username} · ${user.status}',
      onCreate: _create,
      onEdit: _edit,
      onDelete: (backend, user) => backend.deleteUser(user.id),
    );
  }

  /// Opens the create editor and posts a [CreateUserRequest] on save.
  Future<bool> _create(BuildContext context) async {
    final form = UserForm();
    final draft = UserDraft();
    form.bind(draft);
    try {
      return await showAdminEditor(
        context,
        title: 'New user',
        children: [for (final field in form.editableFields) field.widget],
        submit: () async {
          if (!await form.save()) return '';
          final request = CreateUserRequest(
            username: draft.username.get(),
            password: draft.password.get(),
            displayName: draft.displayName.get(),
            email: draft.email.get(),
          );
          try {
            await session.guard((backend) => backend.createUser(request));
            return null;
          } on AdminBackendException catch (e) {
            return e.message;
          }
        },
      );
    } finally {
      form.dispose();
    }
  }

  /// Opens the edit editor for [user] and updates the profile + status on save.
  Future<bool> _edit(BuildContext context, UserDto user) async {
    final form = UserForm(isCreate: false);
    final draft = UserDraft()
      ..username.set(user.username)
      ..displayName.set(user.displayName)
      ..email.set(user.email)
      ..status.set(user.status);
    form.bind(draft);
    try {
      return await showAdminEditor(
        context,
        title: 'Edit user',
        children: [for (final field in form.editableFields) field.widget],
        submit: () async {
          if (!await form.save()) return '';
          final updated = UserDto(
            id: user.id,
            username: user.username,
            displayName: draft.displayName.get(),
            email: draft.email.get(),
            status: draft.status.get(),
          );
          try {
            await session.guard((backend) => backend.updateUser(user.id, updated));
            return null;
          } on AdminBackendException catch (e) {
            return e.message;
          }
        },
      );
    } finally {
      form.dispose();
    }
  }
}
