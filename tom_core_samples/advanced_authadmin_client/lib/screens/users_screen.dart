/// The Users destination: list accounts and create/edit/delete them through a
/// bound [UserForm] (step 34).
///
/// A thin configuration of [AdminCrudScreen]: it names how a [UserDto] row reads
/// and folds the reflected [UserDraft] the form edits into the wire types the
/// seam takes — a [CreateUserRequest] on create (the one place a password
/// crosses), a [UserDto] on edit (username is the stable key, so it stays
/// read-only and only the profile + status change).
///
/// ## The avatar
///
/// The edit editor carries one more control that is **not** a form field: the
/// account's avatar, a [TomFormFileUpload] over the auth server's
/// `auth_users.avatar_ref` slot ([AppFileSlots.userAvatar]). It is the same
/// authenticated file client the app client attaches files with, pointed at the
/// other server — which is why it is here at all.
///
/// Three consequences follow from a file slot not being a bound member:
///
///  * It is **edit-only**. A slot is addressed by the row's id, and on create
///    there is no row yet. An admin sets the avatar on the account they just
///    made, by re-opening it.
///  * It **transfers on pick**, not on Save. The dialog's Save writes the JSON
///    profile; the bytes have already gone. The field's description says so.
///  * Its stored state is read with a single `HEAD` when the editor opens
///    ([TomFileTransferClient.describe]) rather than from [UserDto], which
///    carries no avatar column — the descriptor *is* what a `HEAD` returns, so
///    asking the slot is asking the authoritative source.
library;

import 'dart:typed_data';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/admin_actions.dart';
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
      createLabel: TomCtr.text('admin.users.create'),
      emptyText: TomCtr.text('admin.users.empty'),
      load: (backend) => backend.listUsers(),
      idOf: (user) => user.id,
      titleOf: (user) =>
          user.displayName.isEmpty ? user.username : user.displayName,
      subtitleOf: (user) => '${user.username} · ${user.status}',
      onCreate: _create,
      onEdit: _edit,
      onDelete: (user) =>
          runAdminAction(adminActions.deleteUser, DeleteUserContext(session, user.id)),
      createAuthorizer: adminActions.createUser.authorizer,
      deleteAuthorizer: adminActions.deleteUser.authorizer,
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
        title: TomCtr.text('admin.users.create'),
        children: [for (final field in form.editableFields) field.widget],
        submit: () async {
          if (!await form.save()) return '';
          final request = CreateUserRequest(
            username: draft.username.get(),
            password: draft.password.get(),
            displayName: draft.displayName.get(),
            email: draft.email.get(),
          );
          return runAdminAction(
              adminActions.createUser, CreateUserContext(session, request));
        },
      );
    } finally {
      form.dispose();
    }
  }

  /// Opens the edit editor for [user] and updates the profile + status on save.
  ///
  /// The account's avatar descriptor is read first, with one `HEAD` on the slot,
  /// because [TomFormFileUpload] takes its initial value synchronously: a field
  /// only describes a slot it *already* holds a stored value for, so a stored
  /// avatar it was never told about would stay invisible until the next upload.
  Future<bool> _edit(BuildContext context, UserDto user) async {
    final stored = await _describeAvatar(user.id);
    if (!context.mounted) return false;
    final form = UserForm(isCreate: false);
    final draft = UserDraft()
      ..username.set(user.username)
      ..displayName.set(user.displayName)
      ..email.set(user.email)
      ..status.set(user.status);
    form.bind(draft);
    final avatar = _buildAvatarField(context, user, stored);
    try {
      return await showAdminEditor(
        context,
        title: TomCtr.text('admin.users.edit'),
        children: [
          for (final field in form.editableFields) field.widget,
          avatar.widget,
        ],
        submit: () async {
          if (!await form.save()) return '';
          final updated = UserDto(
            id: user.id,
            username: user.username,
            displayName: draft.displayName.get(),
            email: draft.email.get(),
            status: draft.status.get(),
          );
          return runAdminAction(adminActions.updateUser,
              UpdateUserContext(session, user.id, updated));
        },
      );
    } finally {
      form.dispose();
      avatar.dispose();
    }
  }

  /// Reads what is stored in [userId]'s avatar slot — one `HEAD`, no bytes.
  ///
  /// A transfer failure is translated into the [AdminBackendException] the
  /// console already surfaces, rather than escaping as an unhandled async error
  /// from a button callback. It is *not* swallowed: an editor that cannot be
  /// told what the account's avatar is would otherwise open showing "no avatar"
  /// over a slot that has one, and the next upload would silently replace it.
  Future<FileDescriptorDto?> _describeAvatar(String userId) async {
    final slot = AppFileSlots.userAvatar(userId);
    try {
      final metadata = await session.backend.files.describe(slot);
      return metadata == null
          ? null
          : FileDescriptorDto.fromMetadata(slot, metadata);
    } on TomFileTransferException catch (e) {
      throw AdminBackendException(e.defaultUserMessage, key: e.key);
    }
  }

  /// Builds the account's avatar field over its slot on the auth server.
  ///
  /// Scoped to `admin` with the tomId `users.avatar`, so its wording resolves
  /// from `admin.users.avatar.*` — beside the rest of this screen's chrome, and
  /// clear of the `user.<member>.label` keys, which belong to the reflected
  /// editor's bound fields.
  TomFormFileUpload _buildAvatarField(
    BuildContext context,
    UserDto user,
    FileDescriptorDto? stored,
  ) {
    return TomScope.withScope(
      'admin',
      () => TomFormFileUpload(
        'users.avatar',
        stored == null ? null : FileRef.stored(stored.toMetadata()),
        storageSlot: AppFileSlots.userAvatar(user.id),
        transferClient: session.backend.files,
        // The one constraint an avatar has that an attachment does not. The
        // wording of a refusal is the bundle's `error.fileExtension`, which the
        // field raises as a validation key rather than a sentence.
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
        onDownload: (ref, bytes) => _onAvatarDownloaded(context, ref, bytes),
      ),
    );
  }

  /// Confirms a completed avatar download.
  ///
  /// What a downloaded file *is* — a preview, a save dialog — is the
  /// application's decision, which is why the field hands over the bytes and
  /// nothing more. This console has nowhere to put them (its clients ship no
  /// platform folders), so it reports what arrived.
  void _onAvatarDownloaded(BuildContext context, FileRef ref, Uint8List bytes) {
    if (!context.mounted) return;
    TomMessenger.showSnackBar(
      context,
      TomSnackBar(
        content: TomText(
          text: TomCtr.text('admin.users.avatar.downloaded')
              .replaceAll('{name}', ref.name)
              .replaceAll('{size}', tomHumanFileSize(bytes.length)),
        ),
      ),
    );
  }
}
