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
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../actions/app_actions.dart';
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
      // Load the item's DB-resolved grade matrix (keyed by wire resource key,
      // `todo.item.<field>`). The screen stamps it onto the form's fields; there
      // is no installed authorization adapter to route the grades implicitly.
      final states = await _session.loadFieldStates(_item.id.get());
      if (!mounted) return;
      // Run the form under the gradable scope so each field's basePath equals
      // its wire resource key (`todo.item.<field>`).
      final form = TomScope.withScope(
        'todo',
        TodoItemForm.new,
      );
      form.bind(_item);
      // Stamp each gradable field with its DB-resolved grade via a per-field
      // fixed authorizer (layer 4). An unsent gradable key is closed-safe
      // ([TomAuthState.none], D-A4): the field collapses rather than leaking an
      // editable control. Non-gradable chrome (login, board) keeps the
      // framework's permissive default — this screen installs no global adapter.
      for (final field in form.gradableFields) {
        field.authorizer =
            TomAuthorizer.fixed(states[field.basePath] ?? TomAuthState.none);
      }
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

  /// Validates the form and runs the [SaveItemAction], then pops with `true` so
  /// the board can refresh. Only `full` fields are editable, so the write-back
  /// carries exactly the permitted changes. The mutation runs through the action
  /// (`todo.item.save`); this method keeps the busy/error/navigation chrome.
  Future<void> _save() async {
    final form = _form;
    if (form == null) return;
    if (!await form.save()) return; // validation failed; messages are inline
    setState(() {
      _busy = true;
      _error = null;
    });
    final error =
        await runAppAction(itemActions.save, SaveItemContext(_session, _item));
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

  /// Posts the composer's text as a new comment via the [AddCommentAction]
  /// (`todo.item.comment`); the screen keeps the busy/error/snackbar chrome.
  Future<void> _addComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _postingComment = true;
      _commentError = null;
    });
    final error = await runAppAction(
      itemActions.comment,
      AddCommentContext(_session, _item.id.get(), body),
    );
    if (!mounted) return;
    if (error == null) {
      _commentController.clear();
      setState(() => _postingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        TomSnackBar(
            content: TomText(text: TomCtr.text('board.item.comment.added'))),
      );
      return;
    }
    setState(() {
      _commentError = error;
      _postingComment = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TomScaffold(
      key: const Key('item-detail-screen'),
      appBar: TomAppBar(title: TomText(text: _item.title.get())),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: TomCircularProgressIndicator());
    }
    final form = _form;
    if (form == null) {
      return Center(
        child: TomText(
            text: _error ?? TomCtr.text('board.item.loadError'),
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
          TomText(
              text: _error!,
              key: const Key('item-detail-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        if (canSave)
          TomFilledButton(
            key: const Key('item-save-button'),
            authorizer: itemActions.save.authorizer,
            onPressed: _busy ? null : _save,
            child: _busy
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: TomCircularProgressIndicator(strokeWidth: 2),
                  )
                : TomText(text: TomCtr.text('board.item.save')),
          ),
        TomDivider(height: 32),
        _buildCommentComposer(),
      ],
    );
  }

  Widget _buildCommentComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
            text: TomCtr.text('board.item.comment.title'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TomTextField(
          key: const Key('comment-input'),
          controller: _commentController,
          minLines: 1,
          maxLines: 3,
          label: '',
          hint: TomCtr.text('board.item.comment.hint'),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        if (_commentError != null) ...[
          const SizedBox(height: 8),
          TomText(
              text: _commentError!,
              key: const Key('comment-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TomOutlinedButton(
            key: const Key('comment-submit-button'),
            authorizer: itemActions.comment.authorizer,
            onPressed: _postingComment ? null : _addComment,
            child: _postingComment
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: TomCircularProgressIndicator(strokeWidth: 2),
                  )
                : TomText(text: TomCtr.text('board.item.comment.submit')),
          ),
        ),
      ],
    );
  }
}
