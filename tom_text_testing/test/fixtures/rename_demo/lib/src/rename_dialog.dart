import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Asks for a file's new name.
class RenameDialog extends TomStatefulWidget {
  RenameDialog({super.key, required this.taken, required this.onRename});

  final Set<String> taken;
  final ValueChanged<String> onRename;

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends TomState<RenameDialog> {
  final _name = TextEditingController();
  String? _error;

  void _submit() {
    final name = _name.text.trim();
    final field = TomCtr.resolvePath(
      'rename.nameField',
      widget.constructionScope,
    );
    final error = name.isEmpty
        ? TomCtr.text(field, 'error.empty')
        : widget.taken.contains(name)
        ? TomCtr.text(field, 'error.taken').replaceAll('{name}', name)
        : null;
    setState(() => _error = error);
    if (error == null) widget.onRename(name);
  }

  @override
  Widget buildContent(BuildContext context) => TomAlertDialog(
    tomId: 'rename.renameDialog',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(tomId: 'rename.nameText'),
        TomTextField(
          tomId: 'rename.nameField',
          controller: _name,
          decoration: InputDecoration(errorText: _error),
        ),
      ],
    ),
    actions: [
      TomTextButton(
        tomId: 'rename.cancelButton',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      TomFilledButton(tomId: 'rename.renameButton', onPressed: _submit),
    ],
  );
}
