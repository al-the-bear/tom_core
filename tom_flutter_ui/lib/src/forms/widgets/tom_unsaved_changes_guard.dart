import 'package:flutter/material.dart';

import '../tom_form.dart';

/// Result of an unsaved-changes prompt. [save] runs the form's save and
/// only proceeds if it succeeds; [discard] resets the form; [cancel]
/// aborts the pending action.
enum UnsavedChangesChoice { save, discard, cancel }

/// Prompts the user to save / discard / cancel when [form] is dirty,
/// then performs [action] only if the choice doesn't abort.
///
/// Returns the chosen [UnsavedChangesChoice]. When the form isn't dirty
/// the dialog is skipped and [action] runs immediately, returning a
/// synthetic `discard` (nothing to save).
///
/// Used by [TomMasterDetailScaffold] for selection changes and by route
/// pop guards. Keeps the spec's §15 master-detail Save/Discard/Cancel
/// pattern in one place instead of being duplicated per demo.
Future<UnsavedChangesChoice> guardUnsavedChanges({
  required BuildContext context,
  required TomForm form,
  required Future<void> Function() action,
  String title = 'Unsaved changes',
  String message = 'You have unsaved edits. What would you like to do?',
  String saveLabel = 'Save',
  String discardLabel = 'Discard',
  String cancelLabel = 'Cancel',
}) async {
  if (!form.isDirty) {
    await action();
    return UnsavedChangesChoice.discard;
  }

  final choice = await showDialog<UnsavedChangesChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(ctx).pop(UnsavedChangesChoice.cancel),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(ctx).pop(UnsavedChangesChoice.discard),
          child: Text(discardLabel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(ctx).pop(UnsavedChangesChoice.save),
          child: Text(saveLabel),
        ),
      ],
    ),
  );

  switch (choice) {
    case UnsavedChangesChoice.save:
      final ok = await form.save();
      if (ok) {
        await action();
      }
      return UnsavedChangesChoice.save;
    case UnsavedChangesChoice.discard:
      form.discard();
      await action();
      return UnsavedChangesChoice.discard;
    case UnsavedChangesChoice.cancel:
    case null:
      return UnsavedChangesChoice.cancel;
  }
}

/// Wraps a subtree with a [PopScope] that defers route pops while [form]
/// is dirty. When the user tries to leave, [guardUnsavedChanges] runs;
/// if they choose Save (which succeeds) or Discard, the route pops
/// programmatically.
class TomUnsavedChangesGuard extends StatefulWidget {
  const TomUnsavedChangesGuard({
    super.key,
    required this.form,
    required this.child,
    this.title = 'Unsaved changes',
    this.message = 'You have unsaved edits. What would you like to do?',
  });

  final TomForm form;
  final Widget child;
  final String title;
  final String message;

  @override
  State<TomUnsavedChangesGuard> createState() =>
      _TomUnsavedChangesGuardState();
}

class _TomUnsavedChangesGuardState extends State<TomUnsavedChangesGuard> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.form.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await guardUnsavedChanges(
          context: context,
          form: widget.form,
          title: widget.title,
          message: widget.message,
          action: () async {
            if (navigator.canPop()) navigator.pop(result);
          },
        );
      },
      child: widget.child,
    );
  }
}
