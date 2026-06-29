/// The user editor — a `TomForm` bound to a [UserDraft], rendering the right
/// field set for create vs. edit (step 34).
///
/// On **create** the admin enters username + password + profile (the fields
/// `CreateUserRequest` carries). On **edit** the username is a stable key
/// (rendered read-only) and there is no password (the seam exposes no
/// password-change), so the form shows username (read-only) + profile + status.
/// [editableFields] returns the ordered subset the screen lays out, so a single
/// bound form drives both flows.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/admin_drafts.dart';

/// A bound editor for a [UserDraft], in create or edit mode.
@tomReflector
class UserForm extends TomForm<UserDraft> {
  /// Creates the form. When [isCreate] is false the username is read-only and
  /// the password field is dropped from [editableFields].
  UserForm({this.isCreate = true}) : super(formId: 'user');

  /// Whether the form is creating a new account (vs. editing an existing one).
  final bool isCreate;

  /// Login name — editable on create, read-only (stable key) on edit.
  late final username = TomFormStringInput(
    'username',
    '',
    form: this,
    labelTextOverride: 'Username',
    authorizer: TomAuthorizer.fixed(
      isCreate ? TomAuthState.full : TomAuthState.read,
    ),
    validators: [Validators.required()],
  );

  /// Initial password — shown on create only. The form reflects over *all*
  /// declared fields when it validates, so the required rule is applied only in
  /// create mode; on edit the field is unrendered and must not block the save.
  late final password = TomFormStringInput(
    'password',
    '',
    form: this,
    labelTextOverride: 'Password',
    obscureText: true,
    validators: isCreate ? [Validators.required()] : const [],
  );

  /// Human-facing name.
  late final displayName = TomFormStringInput(
    'displayName',
    '',
    form: this,
    labelTextOverride: 'Display name',
    validators: [Validators.required()],
  );

  /// Contact email.
  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    labelTextOverride: 'Email',
    keyboardType: TextInputType.emailAddress,
  );

  /// Account status — a dropdown over the wire tokens; edit only.
  late final status = TomFormStringDropdown(
    'status',
    'active',
    form: this,
    source: _statusSource,
    labelTextOverride: 'Status',
  );

  /// The fields the screen renders, in order, for the current mode.
  List<TomField<dynamic>> get editableFields => [
        username,
        if (isCreate) password,
        displayName,
        email,
        if (!isCreate) status,
      ];

  @override
  void createFormElements() {}
}

/// The two account-status options, valued by the wire token the DTO stores.
final TomSelectableSource<String> _statusSource = StaticSelectableSource([
  const SelectableItem<String>(value: 'active', label: 'Active'),
  const SelectableItem<String>(value: 'suspended', label: 'Suspended'),
]);
