/// The item-detail screen the board opens when a card is tapped — a bound
/// `TomForm<TodoItem>` whose per-field controls are driven live by the session's
/// four-state grade matrix (step 30).
///
/// This is where the authorization model becomes visible end-to-end: on open the
/// screen loads the item's `resourceKey → TomAuthState` matrix
/// ([AppSession.loadFieldStates]) and constructs a [TodoItemForm] with it, so the
/// *same* editor renders differently per role — `owner` edits every field;
/// `viewer` sees read-only fields with a disabled status control and no estimate
/// at all (an ungranted field resolves to [TomAuthState.none] and collapses).
///
/// Save writes the form back into the bound [TodoItem] through the reflection
/// round-trip and persists it via [AppSession.guard]. Because only `full` fields
/// render editable, the others keep their bound values, so a write-back persists
/// exactly the permitted fields — the server re-checks the same grade.
///
/// A minimal add-only comment composer posts through the existing
/// [AppBackend.addComment] seam. The comment thread (history) and subtasks are
/// deferred — the step-26 backend seam exposes neither a comment-list read nor
/// subtask operations, so they cannot be driven against the in-memory fake
/// without extending the frozen seam (see `step30_item_detail_decisions.md`).
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../app/app_session.dart';
import '../backend/backend.dart';
import '../forms/todo_item_form.dart';

/// Bound, authorization-aware editor for a single [TodoItem].
class ItemDetailScreen extends StatefulWidget {
  /// Creates the detail screen for [item] over [session].
  const ItemDetailScreen({super.key, required this.session, required this.item});

  /// The signed-in session: backend seam + the field-grade matrix loader.
  final AppSession session;

  /// The item whose detail is shown and edited.
  final TodoItem item;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  TodoItemForm? _form;
  late final TodoItem _item = widget.item;
  final TextEditingController _commentController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _postingComment = false;
  String? _error;
  String? _commentError;

  AppSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _form?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Loads the item's four-state matrix and builds the bound form against it.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load the item's grade matrix; this pushes it into the session's
      // installed [FieldStateAuthorizationAdapter], so the form's fields resolve
      // their grades implicitly (the form itself holds no authorization state).
      await _session.loadFieldStates(_item.id.get());
      if (!mounted) return;
      // Run the form under the gradable scope so each field's basePath equals
      // its wire resource key (`todo.item.<field>`) and the installed adapter
      // (todo 3) resolves its grade implicitly via layer-1.
      final form = TomScope.withScope(
        'todo',
        TodoItemForm.new,
      );
      form.bind(_item);
      setState(() {
        _form = form;
        _loading = false;
      });
    } on AppBackendException catch (e) {
      // A lost session is already handled by [AppSession.guard] (the principal
      // is cleared and the shell rebuilds to login); we only surface other
      // failures inline here.
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Validates and persists the form, then pops with `true` so the board can
  /// refresh. Only `full` fields are editable, so the write-back carries exactly
  /// the permitted changes.
  Future<void> _save() async {
    final form = _form;
    if (form == null) return;
    if (!await form.save()) return; // validation failed; messages are inline
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.guard((b) => b.saveItem(_item));
      if (mounted) Navigator.of(context).pop(true);
    } on AppBackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  /// Posts the composer's text as a new comment on the item.
  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _postingComment = true;
      _commentError = null;
    });
    try {
      final comment = TodoComment()
        ..itemId.set(_item.id.get())
        ..authorId.set(_session.user?.id ?? '')
        ..body.set(body);
      await _session.guard((b) => b.addComment(_item.id.get(), comment));
      if (!mounted) return;
      _commentController.clear();
      setState(() => _postingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment added')),
      );
    } on AppBackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _commentError = e.message;
        _postingComment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('item-detail-screen'),
      appBar: AppBar(title: Text(_item.title.get())),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final form = _form;
    if (form == null) {
      return Center(
        child: Text(_error ?? 'Could not load item.',
            key: const Key('item-detail-error')),
      );
    }
    final canSave = form.gradableFields.any((f) => f.isEditable);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final field in form.gradableFields) ...[
          field.widget,
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(_error!,
              key: const Key('item-detail-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        if (canSave)
          FilledButton(
            key: const Key('item-save-button'),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        const Divider(height: 32),
        _buildCommentComposer(),
      ],
    );
  }

  Widget _buildCommentComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a comment',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('comment-input'),
          controller: _commentController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write a comment…',
            border: OutlineInputBorder(),
          ),
        ),
        if (_commentError != null) ...[
          const SizedBox(height: 8),
          Text(_commentError!,
              key: const Key('comment-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            key: const Key('comment-submit-button'),
            onPressed: _postingComment ? null : _addComment,
            child: _postingComment
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post comment'),
          ),
        ),
      ],
    );
  }
}
