/// The share dialog: grant another user a [ProjectRole] on the selected project.
///
/// Sharing is the cross-user half of the four-state model — it is how `bob`
/// becomes an editor and `carol` a viewer on a project they do not own. The dialog
/// collects a grantee and a role and calls [AppBackend.share] through
/// [AppSession.guard]; the in-memory fake records the share (so the grantee's
/// next read sees the project), and the live stack `POST`s `/share`.
///
/// **Grantee is entered as a user id, not picked from a list.** The
/// [AppBackend] seam has no "list users" operation (and [share] speaks
/// `granteeUserId`, matching the live wire), so the dialog takes the id
/// directly. Offline the five seeded ids are `u-alice`, `u-bob`, `u-carol`,
/// `u-dave` and `u-erin`; on the live stack the grantee is the numeric
/// `auth_db` user id the server parses (alice `2` … erin `6`), so the id to
/// type depends on the run mode. A denied share (only the project owner may
/// share) surfaces inline rather than closing the dialog.
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart' show TomObservableEnum;
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/app_actions.dart';
import '../app/app_session.dart';

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
      setState(() => _error = TomCtr.text('share.granteeRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // The grant runs through the [ShareProjectAction] (`board.share`); this
    // method keeps the busy/error/navigation chrome around it.
    final error = await runAppAction(
      boardActions.share,
      ShareProjectContext(widget.session, widget.projectId, grantee, _role),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = error;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TomAlertDialog(
      key: const Key('share-dialog'),
      title: TomText(text: TomCtr.text('share.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomTextField(
            key: const Key('share-grantee-input'),
            controller: _granteeController,
            label: TomCtr.text('share.grantee.label'),
            hint: TomCtr.text('share.grantee.hint'),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(text: TomCtr.text('share.role')),
              TomDropdownButton<ProjectRole>(
                key: const Key('share-role-picker'),
                value: _role,
                isExpanded: true,
                items: [
                  for (final role in ProjectRole.values)
                    DropdownMenuItem(
                      value: role,
                      child: Text(TomObservableEnum.resolveText(role)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (role) =>
                        setState(() => _role = role ?? ProjectRole.viewer),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            TomText(
                text: _error!,
                key: const Key('share-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TomTextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: TomText(text: TomCtr.text('share.cancel')),
        ),
        TomFilledButton(
          key: const Key('share-submit-button'),
          authorizer: boardActions.share.authorizer,
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: TomCircularProgressIndicator(strokeWidth: 2),
                )
              : TomText(text: TomCtr.text('board.share')),
        ),
      ],
    );
  }
}
