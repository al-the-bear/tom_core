/// The item-detail screen the board opens when a card is tapped — a bound
/// `TomForm<TodoItem>` whose per-field controls are graded through the framework
/// authorization registry.
///
/// This is where the authorization model becomes visible end-to-end. On open the
/// screen resolves the item's **resource-level** state through the framework —
/// `TomAuthorization.resolveAuth('item:<id>')`, which routes through the
/// [AppResourceRoleAdapter] the session installed at login → the principal's role
/// on the item → the [TomResourceRoleRegistry]. It then **narrows** that ceiling
/// by the field's per-role grade from the shared [projectRoleFieldGrades] matrix
/// and stamps the result on the field. The composition reproduces that matrix
/// exactly, so the *same* editor renders differently per role — `owner` edits
/// every field; `viewer` sees read-only fields with a disabled status control and
/// no estimate (an ungranted field resolves to [TomAuthState.none] and collapses)
/// — while the registry stays the load-bearing gate (no role → resource state
/// `none` → every field collapses).
///
/// Save writes the form back into the bound [TodoItem] through the reflection
/// round-trip and persists it via [AppSession.guard]. Because only `full` fields
/// render editable, the others keep their bound values, so a write-back persists
/// exactly the permitted fields — the server re-checks the same grade.
///
/// ## The two child sections
///
/// Below the graded fields the screen shows the item's two child collections,
/// loaded together on open ([_ItemDetailScreenState._loadChildren]) and each
/// authorized differently from the fields above them:
///
///  * The **checklist** ([_ItemDetailScreenState._buildSubtaskSection]) — the
///    item's subtasks in
///    `position` order. Adding a step and ticking one are `editor`-and-above
///    operations, one step stronger than commenting, because a subtask is *part
///    of* the item rather than a remark about it; the screen resolves that from
///    the same resource state the fields use
///    ([_ItemDetailScreenState._subtaskState]) so a viewer sees
///    the steps with disabled checkboxes and no composer.
///  * The **thread** ([_ItemDetailScreenState._buildCommentSection]) — the
///    comment history, read-gated
///    by the *item's* readability alone. Anyone who can open the screen can read
///    it, including a viewer who may not add to it; the composer below it stays
///    on its own `todo.item.comment` action.
///
/// Both sections re-read from the backend after a successful write rather than
/// patching their lists locally, so what the screen shows is what the server
/// stored — including the id and ordering it assigned.
///
/// ## The attachment
///
/// The item's file lives beside the graded fields but not among them (see
/// [_ItemDetailScreenState._attachment]): it is a *slot* on the server, moved
/// by [AppBackend.files] rather than by [AppBackend.saveItem], and authorized
/// by the row's resource state rather than by the per-field grade matrix.
library;

import 'dart:typed_data';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
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
  const ItemDetailScreen({
    super.key,
    required this.session,
    required this.item,
    this.attachment,
  });

  /// The signed-in session: backend seam + the field-grade matrix loader.
  final AppSession session;

  /// The item whose detail is shown and edited.
  final TodoItem item;

  /// What the board already learned about this item's file, when it has one.
  ///
  /// Passed in rather than re-fetched: the board loads every visible item's
  /// descriptor in one [AppBackend.listAttachments] call, and that answer is
  /// exactly what a `HEAD` on this slot would return. Opening a card therefore
  /// costs no extra round-trip and the field renders its stored file on the
  /// first frame instead of after one.
  final FileDescriptorDto? attachment;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  TodoItemForm? _form;
  TomFormFileUpload? _attachment;
  late final TodoItem _item = widget.item;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();

  /// The item's resource-level state and the subtask sections' state, both
  /// resolved once in [_resolveForm] (see [_buildSubtaskSection]).
  TomAuthState _subtaskState = TomAuthState.none;

  List<TodoComment> _thread = const [];
  List<Subtask> _checklist = const [];
  bool _loadingChildren = true;
  String? _childrenError;

  bool _busy = false;
  bool _postingComment = false;
  bool _addingSubtask = false;
  String? _error;
  String? _commentError;
  String? _subtaskError;

  AppSession get _session => widget.session;

  /// Whether the principal may add and tick checklist steps — the `editor`
  /// gate, read off the one resolved [_subtaskState] rather than re-derived
  /// from the role, so the composer and the checkboxes cannot disagree.
  bool get _canEditSubtasks => _subtaskState == TomAuthState.full;

  @override
  void initState() {
    super.initState();
    _resolveForm();
    _loadChildren();
  }

  @override
  void dispose() {
    _form?.dispose();
    _attachment?.dispose();
    _commentController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  /// Builds the bound form, grading each field through the framework registry.
  ///
  /// Resolution is now synchronous: the principal's per-resource role grants are
  /// already on the session (snapshotted + installed as the [TomAuthorization]
  /// adapter at login), so there is no backend round-trip to await — this
  /// runs once from [initState], before the first build.
  void _resolveForm() {
    final itemKey = ResourceRoleKeys.item(_item.id.get());
    // The item's resource-level state, resolved through the framework registry:
    // the installed AppResourceRoleAdapter maps the principal's role on this item
    // to a TomAuthState via the TomResourceRoleRegistry (no role → none).
    final resourceState = TomAuthorization.resolveAuth(itemKey);
    // The principal's role on the item picks the per-field grade row; the field
    // grades live in the shared domain (projectRoleFieldGrades), not here.
    final role = ProjectRole.values
        .asNameMap()[_session.resourceRoles[itemKey]];
    final grades = role == null
        ? const <String, TomAuthState>{}
        : (projectRoleFieldGrades[role] ?? const <String, TomAuthState>{});

    // Run the form under the gradable scope so each field's basePath equals its
    // wire resource key (`todo.item.<field>`).
    final form = TomScope.withScope('todo', TodoItemForm.new);
    form.bind(_item);
    // Each gradable field's state is the framework-resolved resource ceiling
    // narrowed by the field's per-role grade. Because every role's field grades
    // sit at or below its resource ceiling, the narrow reproduces
    // [projectRoleFieldGrades] exactly — while keeping the registry
    // load-bearing: no role → resource state none → the field collapses
    // (closed-safe).
    for (final field in form.gradableFields) {
      final fieldGrade = grades[field.basePath] ?? TomAuthState.none;
      field.authorizer = TomAuthorizer.fixed(resourceState.narrow(fieldGrade));
    }
    _form = form;
    _attachment = _buildAttachmentField(resourceState, role);
    // The checklist's own grade. Not a member of the field matrix — a subtask
    // is a row of its own, not a field of the item form — so it is narrowed
    // here by the server's rule instead: `editor` and above may write
    // (`full`), everyone who can open the screen may look (`read`). Narrowing
    // through `resourceState` keeps the registry load-bearing here too: no role
    // → `none` → the whole section collapses.
    _subtaskState = resourceState.narrow(
      role == ProjectRole.owner || role == ProjectRole.editor
          ? TomAuthState.full
          : TomAuthState.read,
    );
  }

  /// Loads the item's thread and checklist in one pass.
  ///
  /// The two are fetched together and rendered together: they are the same
  /// item's children, gated by the same read, and a screen that showed one
  /// while the other was still arriving would flicker for no gain. A failure
  /// is surfaced on the sections rather than on the form — the graded fields
  /// resolved synchronously and are already usable.
  Future<void> _loadChildren() async {
    final itemId = _item.id.get();
    try {
      final thread = await _session.guard((b) => b.listComments(itemId));
      final checklist = await _session.guard((b) => b.listSubtasks(itemId));
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _checklist = checklist;
        _childrenError = null;
        _loadingChildren = false;
      });
    } on AppBackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _childrenError = e.message;
        _loadingChildren = false;
      });
    }
  }

  /// Builds the item's attachment field: its file slot on the app server, wired
  /// to [AppBackend.files] so picking uploads and re-opening shows what is
  /// stored.
  ///
  /// **Not a member of [TodoItemForm], and deliberately not under
  /// `todo.item.*` in the form** — although it *is* graded by the same matrix:
  ///
  ///  * The value types differ. The field holds a [FileRef]; `TodoItem.attachment`
  ///    holds the *storage key* the server stamps. They cannot be the same bound
  ///    member.
  ///  * The write paths differ. Bytes travel over the file endpoint; the server
  ///    keeps the file column out of the item's writable bindings precisely so a
  ///    client cannot mint a storage key by editing an item. That is also why
  ///    [itemAttachmentGradeKey] is absent from [AppResourceBundles.gradableItemKeys]
  ///    and so from [TomForm.gradableFields] — the loop above cannot reach it.
  ///
  /// The **authorization**, however, is the same story as every other field, and
  /// this method applies it by hand because the form loop cannot: the item's
  /// resource state narrowed by the role's attachment grade
  /// ([projectRoleAttachmentGrades]). A commenter or viewer is graded `read`, so
  /// the field renders its download affordance and hides the picker — matching
  /// what the server will actually answer, because the app server resolves the
  /// very same grade per row at the file endpoint (`registerAppColumnGrades`)
  /// from the authoritative `tom_resource_grant` row.
  ///
  /// As everywhere else in this sample, the narrowing here is **cooperation, not
  /// enforcement**: it spares the user an affordance that would be refused. An
  /// administrator who edits the grant row changes the server's answer without
  /// changing this map, and the server's answer is the binding one.
  TomFormFileUpload _buildAttachmentField(
    TomAuthState resourceState,
    ProjectRole? role,
  ) {
    final stored = widget.attachment;
    // Closed-safe like the fields: no role → `none` → the field collapses.
    final grade = role == null
        ? TomAuthState.none
        : (projectRoleAttachmentGrades[role] ?? TomAuthState.none);
    return TomScope.withScope(
      'board',
      () => TomFormFileUpload(
        'item.attachment',
        stored == null ? null : FileRef.stored(stored.toMetadata()),
        storageSlot: AppFileSlots.itemAttachment(_item.id.get()),
        transferClient: _session.backend.files,
        onDownload: _onAttachmentDownloaded,
        authorizer: TomAuthorizer.fixed(resourceState.narrow(grade)),
      ),
    );
  }

  /// Confirms a completed download.
  ///
  /// What a downloaded file *is* — a preview, a share sheet, a save dialog — is
  /// the application's decision, which is why the field hands over the bytes and
  /// nothing more. This sample has nowhere to put them (its clients ship no
  /// platform folders), so it reports what arrived; a real app writes them.
  void _onAttachmentDownloaded(FileRef ref, Uint8List bytes) {
    if (!mounted) return;
    TomMessenger.showSnackBar(
      context,
      TomSnackBar(
        content: TomText(
          text: TomCtr.text('board.item.attachment.downloaded')
              .replaceAll('{name}', ref.name)
              .replaceAll('{size}', tomHumanFileSize(bytes.length)),
        ),
      ),
    );
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
    final error = await runAppAction(
      itemActions.save,
      SaveItemContext(_session, _item),
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
      TomMessenger.showSnackBar(
        context,
        TomSnackBar(
          content: TomText(text: TomCtr.text('board.item.comment.added')),
        ),
      );
      await _reloadThread();
      return;
    }
    setState(() {
      _commentError = error;
      _postingComment = false;
    });
  }

  /// Adds the composer's text as a checklist step via the [AddSubtaskAction]
  /// (`todo.item.addSubtask`), then re-reads the list.
  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _addingSubtask = true;
      _subtaskError = null;
    });
    final error = await runAppAction(
      itemActions.addSubtask,
      AddSubtaskContext(_session, _item.id.get(), title),
    );
    if (!mounted) return;
    if (error == null) {
      _subtaskController.clear();
      setState(() => _addingSubtask = false);
      await _reloadChecklist();
      return;
    }
    setState(() {
      _subtaskError = error;
      _addingSubtask = false;
    });
  }

  /// Flips [subtask]'s `done` via the [ToggleSubtaskAction]
  /// (`todo.item.toggleSubtask`), then re-reads the list.
  ///
  /// No optimistic flip: the checkbox keeps showing the stored value until the
  /// re-read lands, so a refused toggle leaves the row where the server has it
  /// rather than snapping back.
  Future<void> _toggleSubtask(Subtask subtask, bool done) async {
    setState(() => _subtaskError = null);
    final error = await runAppAction(
      itemActions.toggleSubtask,
      ToggleSubtaskContext(_session, subtask, done),
    );
    if (!mounted) return;
    if (error == null) {
      await _reloadChecklist();
      return;
    }
    setState(() => _subtaskError = error);
  }

  /// Re-reads the thread after a write, surfacing a failed refresh on the
  /// composer (the write itself already succeeded).
  Future<void> _reloadThread() async {
    try {
      final thread = await _session.guard(
        (b) => b.listComments(_item.id.get()),
      );
      if (!mounted) return;
      setState(() => _thread = thread);
    } on AppBackendException catch (e) {
      if (!mounted) return;
      setState(() => _commentError = e.message);
    }
  }

  /// Re-reads the checklist after a write; see [_reloadThread].
  Future<void> _reloadChecklist() async {
    try {
      final checklist = await _session.guard(
        (b) => b.listSubtasks(_item.id.get()),
      );
      if (!mounted) return;
      setState(() => _checklist = checklist);
    } on AppBackendException catch (e) {
      if (!mounted) return;
      setState(() => _subtaskError = e.message);
    }
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
    final form = _form;
    if (form == null) {
      return Center(
        child: TomText(
          text: _error ?? TomCtr.text('board.item.loadError'),
          key: const Key('item-detail-error'),
        ),
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
        // The attachment renders after the graded fields and outside the save
        // button's reach: its bytes move the moment they are picked, so it has
        // no pending state for `_save` to flush.
        if (_attachment != null) ...[
          _attachment!.widget,
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          TomText(
            text: _error!,
            key: const Key('item-detail-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
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
        _buildSubtaskSection(),
        TomDivider(height: 32),
        _buildCommentSection(),
      ],
    );
  }

  /// What both child sections show *instead of* their list while the shared
  /// [_loadChildren] is in flight or after it failed — or null once real data
  /// is available.
  ///
  /// Shared because the two lists arrive on one load: showing "no steps yet"
  /// and "no comments yet" for a read that never landed would report absence
  /// where the truth is ignorance, and the two sections must not disagree about
  /// which it is. The failure text is the backend's own message (already fit to
  /// show) rather than a generic key, so a denied read reads as a denial.
  Widget? _childrenNotice(Key key) {
    if (_loadingChildren) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TomCircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_childrenError case final message?) {
      return TomText(
        key: key,
        text: message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return null;
  }

  /// The checklist: the item's steps in `position` order, plus the
  /// `editor`-gated composer.
  ///
  /// The rows render for anyone who can open the screen — a viewer sees what
  /// the item requires — but their checkboxes carry [_subtaskState], so a
  /// `read` grade renders them ticked-but-inert. The composer is not merely
  /// disabled for a viewer, it is absent: a control that can never succeed is
  /// noise, and the section already shows the state it is in.
  Widget _buildSubtaskSection() {
    return Column(
      key: const Key('subtask-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          text: TomCtr.text('board.item.subtask.title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_childrenNotice(const Key('subtask-notice')) case final notice?)
          notice
        else if (_checklist.isEmpty)
          TomText(
            key: const Key('subtask-empty'),
            text: TomCtr.text('board.item.subtask.empty'),
          )
        else
          Column(
            key: const Key('subtask-list'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final subtask in _checklist)
                Row(
                  key: Key('subtask-${subtask.id.get()}'),
                  children: [
                    TomCheckbox(
                      value: subtask.done.get(),
                      authorizer: TomAuthorizer.fixed(_subtaskState),
                      onChanged: (value) =>
                          _toggleSubtask(subtask, value ?? false),
                    ),
                    Expanded(child: TomText(text: subtask.title.get())),
                  ],
                ),
            ],
          ),
        if (_subtaskError != null) ...[
          const SizedBox(height: 8),
          TomText(
            text: _subtaskError!,
            key: const Key('subtask-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_canEditSubtasks) ...[
          const SizedBox(height: 8),
          TomTextField(
            key: const Key('subtask-input'),
            controller: _subtaskController,
            label: '',
            hint: TomCtr.text('board.item.subtask.hint'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TomOutlinedButton(
              key: const Key('subtask-submit-button'),
              authorizer: itemActions.addSubtask.authorizer,
              onPressed: _addingSubtask ? null : _addSubtask,
              child: _addingSubtask
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: TomCircularProgressIndicator(strokeWidth: 2),
                    )
                  : TomText(text: TomCtr.text('board.item.subtask.submit')),
            ),
          ),
        ],
      ],
    );
  }

  /// The comment thread (oldest first) above the add-only composer.
  ///
  /// The history is ungated beyond the item's own readability, which is the
  /// whole point of showing it here: a viewer reads the discussion they cannot
  /// join, and the composer below carries its own action grant.
  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          text: TomCtr.text('board.item.comment.thread'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_childrenNotice(const Key('comment-notice')) case final notice?)
          notice
        else if (_thread.isEmpty)
          TomText(
            key: const Key('comment-empty'),
            text: TomCtr.text('board.item.comment.empty'),
          )
        else
          Column(
            key: const Key('comment-thread'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final comment in _thread) _buildComment(comment)],
          ),
        const SizedBox(height: 16),
        _buildCommentComposer(),
      ],
    );
  }

  /// One posted comment: its byline (author + timestamp) over its body.
  Widget _buildComment(TodoComment comment) {
    final when = comment.createdAt.get();
    return Padding(
      key: Key('comment-${comment.id.get()}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            text: TomCtr.text('board.item.comment.byline')
                .replaceAll('{author}', comment.authorId.get())
                .replaceAll('{when}', when == null ? '' : _formatWhen(when)),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          TomText(text: comment.body.get()),
        ],
      ),
    );
  }

  /// Formats a comment timestamp as `YYYY-MM-DD HH:MM`.
  ///
  /// Deliberately not locale-formatted: the sample ships no localisation
  /// package, and an ISO-ish stamp is unambiguous in every locale — which is
  /// the property that matters for a teaching sample and for the widget tests
  /// that assert on it.
  static String _formatWhen(DateTime when) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${when.year}-${two(when.month)}-${two(when.day)} '
        '${two(when.hour)}:${two(when.minute)}';
  }

  Widget _buildCommentComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          text: TomCtr.text('board.item.comment.title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TomTextField(
          key: const Key('comment-input'),
          controller: _commentController,
          minLines: 1,
          maxLines: 3,
          label: '',
          hint: TomCtr.text('board.item.comment.hint'),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_commentError != null) ...[
          const SizedBox(height: 8),
          TomText(
            text: _commentError!,
            key: const Key('comment-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
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
