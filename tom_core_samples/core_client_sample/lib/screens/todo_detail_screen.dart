/// The todo detail screen: a [TodoItemForm] bound to one [TodoItem], with its
/// fields gated by the session's resolved [TomAuthState] matrix.
///
/// This is the screen where the four-state authorization model is visible
/// end-to-end: the form is constructed with [AppSession.fieldStates], so the
/// same editor renders differently per role — `owner` edits everything, while
/// `viewer` sees read-only fields and a disabled "done" toggle, and `member`
/// never sees `priority` at all. `save()` writes the form back into the bound
/// item through the reflection round-trip; the screen then persists it via the
/// session's backend.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:todo_domain/todo_domain.dart';

import '../app/app_session.dart';
import '../forms/todo_item_form.dart';

/// Create / edit screen for a single [TodoItem].
class TodoDetailScreen extends StatefulWidget {
  /// Creates the screen over [session]; a null [item] starts a new todo.
  const TodoDetailScreen({super.key, required this.session, this.item});

  /// The session supplying the backend and the field-state matrix.
  final AppSession session;

  /// The item to edit, or null to create a new one.
  final TodoItem? item;

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late final TodoItemForm _form;
  late final TodoItem _item;
  bool _busy = false;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    _item = widget.item ?? TodoItem();
    _form = TodoItemForm(widget.session.fieldStates);
    _form.bind(_item);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!await _form.save()) return; // validation failed
    setState(() => _busy = true);
    try {
      await widget.session.api.saveItem(_item);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await widget.session.api.deleteItem(_item.id.get());
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TomCtr.text(
            _isNew ? 'todoDetail.title.new' : 'todoDetail.title.edit')),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: TomCtr.text('todoDetail.action.delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _form.title.widget,
          const SizedBox(height: 12),
          _form.description.widget,
          const SizedBox(height: 12),
          _form.priority.widget,
          const SizedBox(height: 12),
          _form.assigneeId.widget,
          const SizedBox(height: 12),
          _form.done.widget,
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(TomCtr.text('todoDetail.action.save')),
          ),
        ],
      ),
    );
  }
}
