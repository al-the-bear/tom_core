/// The share dialog: grant another user a [ProjectRole] on the selected project
/// (step 31).
///
/// Sharing is the cross-user half of the four-state model — it is how `bob`
/// becomes an editor and `val` a viewer on a project they do not own. The dialog
/// collects a grantee and a role and calls [AppBackend.share] through
/// [AppSession.guard]; the in-memory fake records the share (so the grantee's
/// next read sees the project), and the live stack `POST`s `/share`.
///
/// **Grantee is entered as a user id, not picked from a list.** The frozen
/// step-26 [AppBackend] seam has no "list users" operation (and [share] speaks
/// `granteeUserId`, matching the live wire), so the dialog takes the id directly
/// — the demo ids are `u-alice` / `u-bob` / `u-val`. A denied share (only the
/// project owner may share) surfaces inline rather than closing the dialog.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';

import '../app/app_session.dart';
import '../backend/backend.dart';

/// Opens the share dialog for [projectId] over [session].
///
/// Resolves to `true` when a share was granted, and `null` when the user
/// dismissed the dialog without sharing.
Future<bool?> showShareDialog(
  BuildContext context,
  AppSession session,
  String projectId,
) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _ShareDialog(session: session, projectId: projectId),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.session, required this.projectId});

  final AppSession session;
  final String projectId;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final TextEditingController _granteeController = TextEditingController();
  ProjectRole _role = ProjectRole.viewer;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _granteeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final grantee = _granteeController.text.trim();
    if (grantee.isEmpty) {
      setState(() => _error = 'Enter a grantee user id (e.g. u-val).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.guard((b) => b.share(ShareRequest(
            resourceType: 'project',
            resourceId: widget.projectId,
            granteeUserId: grantee,
            projectRole: _role,
          )));
      if (mounted) Navigator.of(context).pop(true);
    } on AppBackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('share-dialog'),
      title: const Text('Share project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('share-grantee-input'),
            controller: _granteeController,
            decoration: const InputDecoration(
              labelText: 'Grantee user id',
              hintText: 'u-val',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProjectRole>(
            key: const Key('share-role-picker'),
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final role in ProjectRole.values)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
            onChanged: _busy
                ? null
                : (role) => setState(() => _role = role ?? ProjectRole.viewer),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                key: const Key('share-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('share-submit-button'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Share'),
        ),
      ],
    );
  }
}
