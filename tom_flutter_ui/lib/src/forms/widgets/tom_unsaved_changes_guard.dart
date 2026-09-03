import 'package:flutter/material.dart';

import '../tom_form.dart';
import '../tom_form_labels.dart';

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
/// Used by [TomMasterDetailListForm] for selection changes and by route
/// pop guards. Keeps the `tom_ui_widgets_forms.md` §15 master-detail
/// Save/Discard/Cancel pattern in one place instead of being duplicated
/// per demo.
///
/// The five captions default to `null` rather than to English: left unset they
/// resolve through [TomFormLabels] against the form's own resource scope, so a
/// localised application gets a localised prompt without passing anything.
/// Passing a string still wins outright, which is what a caller wanting one
/// specific wording here — and only here — is asking for.
Future<UnsavedChangesChoice> guardUnsavedChanges({
  required BuildContext context,
  required TomForm form,
  required Future<void> Function() action,
  String? title,
  String? message,
  String? saveLabel,
  String? discardLabel,
  String? cancelLabel,
}) async {
  if (!form.isDirty) {
    await action();
    return UnsavedChangesChoice.discard;
  }

  final path = form.basePath;
  final choice = await showDialog<UnsavedChangesChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? TomFormLabels.unsavedTitle(path)),
      content: Text(message ?? TomFormLabels.unsavedMessage(path)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(UnsavedChangesChoice.cancel),
          child: Text(cancelLabel ?? TomFormLabels.cancel(path)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(UnsavedChangesChoice.discard),
          child: Text(discardLabel ?? TomFormLabels.discard(path)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(UnsavedChangesChoice.save),
          child: Text(saveLabel ?? TomFormLabels.save(path)),
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
    this.title,
    this.message,
  });

  final TomForm form;
  final Widget child;

  /// Heading of the prompt; `null` resolves it through [TomFormLabels].
  final String? title;

  /// Body of the prompt; `null` resolves it through [TomFormLabels].
  final String? message;

  @override
  State<TomUnsavedChangesGuard> createState() => _TomUnsavedChangesGuardState();
}

class _TomUnsavedChangesGuardState extends State<TomUnsavedChangesGuard> {
  @override
  void initState() {
    super.initState();
    widget.form.changes.addListener(_onFormChanged);
  }

  @override
  void didUpdateWidget(covariant TomUnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.form != widget.form) {
      oldWidget.form.changes.removeListener(_onFormChanged);
      widget.form.changes.addListener(_onFormChanged);
    }
  }

  @override
  void dispose() {
    widget.form.changes.removeListener(_onFormChanged);
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

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
