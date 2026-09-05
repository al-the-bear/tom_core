/// A small reusable editor dialog the Users/Roles/Groups screens host their
/// bound forms in.
///
/// It owns the busy/error chrome so each entity screen only supplies the field
/// widgets (and any extra controls, e.g. a group's membership checklist) and a
/// [AdminEditorDialog.submit] callback. It returns:
///
///  * `null` — saved; the dialog closes with `true`.
///  * `''` (empty) — stay open, show no banner (validation already rendered
///    inline on the form's fields).
///  * any other string — stay open and show it as an inline error banner (a
///    backend refusal such as a duplicate key).
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Shows [AdminEditorDialog] and resolves to `true` when a save succeeded.
Future<bool> showAdminEditor(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  required Future<String?> Function() submit,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        AdminEditorDialog(title: title, submit: submit, children: children),
  );
  return saved ?? false;
}

/// The editor dialog: a titled form body, a Cancel/Save pair, and inline error +
/// busy handling.
class AdminEditorDialog extends StatefulWidget {
  /// Creates the dialog over [children] (the form field widgets) and [submit].
  const AdminEditorDialog({
    super.key,
    required this.title,
    required this.submit,
    required this.children,
  });

  /// The dialog title (e.g. `New user`).
  final String title;

  /// Persists the edit; see the class doc for the return-value contract.
  final Future<String?> Function() submit;

  /// The body widgets (form fields + any extra controls).
  final List<Widget> children;

  @override
  State<AdminEditorDialog> createState() => _AdminEditorDialogState();
}

class _AdminEditorDialogState extends State<AdminEditorDialog> {
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = await widget.submit();
    if (!mounted) return;
    if (message == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = message.isEmpty ? null : message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TomAlertDialog(
      key: const Key('admin-editor-dialog'),
      title: TomText(text: widget.title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in widget.children) ...[
                child,
                const SizedBox(height: 12),
              ],
              if (_error != null)
                TomText(
                  text: _error!,
                  key: const Key('admin-editor-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TomTextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: TomText(text: TomCtr.text('admin.cancel')),
        ),
        TomFilledButton(
          key: const Key('admin-editor-save'),
          onPressed: _busy ? null : _save,
          child: _busy
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: TomCircularProgressIndicator(strokeWidth: 2),
                )
              : TomText(text: TomCtr.text('admin.save')),
        ),
      ],
    );
  }
}
