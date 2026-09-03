/// The board screen the app shell shows while [AppSession.isLoggedIn] is true.
///
/// It is the signed-in home: a workspace/project picker over the principal's
/// visible tree and a status-column board of the selected project's items,
/// grouped into one column per [TodoStatus]. Every read flows through
/// [AppSession.guard], so a dropped session clears the principal and the shell
/// routes back to login without this screen handling it. Tapping a card opens
/// the [ItemDetailScreen], which is where the bound editor lives.
///
/// ## Attachments
///
/// Each load also fetches the visible items' file descriptors, one
/// [AppBackend.listAttachments] call per list. That answer is exactly what a
/// `HEAD` on each slot returns, so it costs no bytes — enough to paperclip the
/// cards that have a file, and enough to hand the detail screen its stored file
/// so the field renders it on the first frame instead of after a round-trip.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/app_session.dart';
import '../backend/backend.dart';
import 'item_detail_screen.dart';
import 'share_dialog.dart';

/// Shows the workspace/project picker and the status-column item board.
class BoardScreen extends StatefulWidget {
  /// Creates the board over [session] (the backend + principal seam).
  const BoardScreen({super.key, required this.session});

  /// The signed-in session every read is guarded through.
  final AppSession session;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<Workspace> _workspaces = const [];
  List<Project> _projects = const [];
  List<TodoItem> _items = const [];

  /// The visible items' file descriptors, keyed by item id.
  ///
  /// Keyed by [FileDescriptorDto.slotId] rather than by the slot address, because
  /// that is the key the card and the detail screen both already hold — an item
  /// id. An item with no file is simply absent (the server omits empty slots).
  Map<String, FileDescriptorDto> _attachments = const {};

  String? _workspaceId;
  String? _projectId;

  bool _loading = true;
  String? _error;

  AppSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  /// Loads the principal's workspaces and selects the first one, cascading into
  /// its projects and items.
  Future<void> _loadWorkspaces() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspaces = await _session.guard((b) => b.listWorkspaces());
      if (!mounted) return;
      _workspaces = workspaces;
      _workspaceId = workspaces.isEmpty ? null : workspaces.first.id.get();
      await _loadProjects();
    } on AppBackendException catch (e) {
      _failWith(e);
    }
  }

  /// Loads the selected workspace's projects and selects the first, cascading
  /// into its items.
  Future<void> _loadProjects() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) {
      setState(() {
        _projects = const [];
        _projectId = null;
        _items = const [];
        _loading = false;
      });
      return;
    }
    try {
      final projects = await _session.guard((b) => b.listProjects(workspaceId));
      if (!mounted) return;
      _projects = projects;
      _projectId = projects.isEmpty ? null : projects.first.id.get();
      await _loadItems();
    } on AppBackendException catch (e) {
      _failWith(e);
    }
  }

  /// Loads every item across the selected project's lists, together with the
  /// descriptors of the files those items carry.
  Future<void> _loadItems() async {
    final projectId = _projectId;
    if (projectId == null) {
      setState(() {
        _items = const [];
        _attachments = const {};
        _loading = false;
      });
      return;
    }
    try {
      final lists = await _session.guard((b) => b.listLists(projectId));
      final items = <TodoItem>[];
      final attachments = <String, FileDescriptorDto>{};
      for (final list in lists) {
        final listId = list.id.get();
        items.addAll(await _session.guard((b) => b.listItems(listId)));
        // One descriptor call per list, beside the item call. Not per card:
        // a paperclip is worth one round-trip for the board, never one each.
        for (final file in await _session.guard(
          (b) => b.listAttachments(listId),
        )) {
          final itemId = file.slotId;
          if (itemId != null && file.hasFile) attachments[itemId] = file;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _attachments = attachments;
        _loading = false;
      });
    } on AppBackendException catch (e) {
      _failWith(e);
    }
  }

  void _failWith(AppBackendException e) {
    if (!mounted) return;
    // A lost session has already cleared the principal in [AppSession.guard];
    // the shell rebuilds to login, so we only surface other failures inline.
    setState(() {
      _error = e.message;
      _loading = false;
    });
  }

  Future<void> _onWorkspaceChanged(String? id) async {
    if (id == null || id == _workspaceId) return;
    setState(() {
      _workspaceId = id;
      _loading = true;
    });
    await _loadProjects();
  }

  Future<void> _onProjectChanged(String? id) async {
    if (id == null || id == _projectId) return;
    setState(() {
      _projectId = id;
      _loading = true;
    });
    await _loadItems();
  }

  /// Opens [item]'s detail screen, handing it what the board already knows about
  /// the item's file, and reloads on the way back.
  ///
  /// The reload is unconditional rather than gated on the screen's `pop(true)`
  /// (which means "saved"), because the attachment moves *without* a save: the
  /// bytes go the moment they are picked. A gated reload would leave the board
  /// paperclip-free after an upload that plainly succeeded.
  Future<void> _openItem(TodoItem item) async {
    await Navigator.of(context).push<void>(
      TomPageRoute(
        builder: (_) => ItemDetailScreen(
          session: _session,
          item: item,
          attachment: _attachments[item.id.get()],
        ),
      ),
    );
    if (!mounted) return;
    await _loadItems();
  }

  /// Opens the share dialog for the selected project; on a granted share, a
  /// snackbar confirms it (the grantee's next read now sees the project).
  Future<void> _openShare() async {
    final projectId = _projectId;
    if (projectId == null) return;
    final shared = await showShareDialog(context, _session, projectId);
    if (shared == true && mounted) {
      TomMessenger.showSnackBar(
        context,
        TomSnackBar(content: TomText(text: TomCtr.text('board.shared'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _session.user?.displayName ?? _session.user?.username ?? '';
    // Board chrome comes from the post-login full bundle (installed by
    // [AppSession.login]); `board.*` has no grade counterpart and no form
    // override, so it renders the server text straight through [TomCtr].
    return TomScaffold(
      key: const Key('board-screen'),
      appBar: TomAppBar(
        title: TomText(text: TomCtr.text('board.title')),
        actions: [
          TomIconButton(
            key: const Key('share-button'),
            icon: const Icon(Icons.person_add_alt),
            tooltip: TomCtr.text('board.shareTooltip'),
            onPressed: _projectId == null ? null : _openShare,
          ),
          TomIconButton(
            key: const Key('logout-button'),
            icon: const Icon(Icons.logout),
            tooltip: TomCtr.text('board.signOut'),
            onPressed: _session.logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(name),
          TomDivider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(text: TomCtr.text('board.signedInAs').replaceAll('{name}', name)),
          const SizedBox(height: 8),
          AclBuilder()
              .setAclDefaultHideUnauthorized(true)
              .append(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TomText(text: TomCtr.text('board.workspace')),
                    TomDropdownButton<String>(
                      key: const Key('workspace-picker'),
                      value: _workspaceId,
                      isExpanded: true,
                      items: [
                        for (final w in _workspaces)
                          DropdownMenuItem(
                              value: w.id.get(),
                              child: Text(w.name.get())),
                      ],
                      onChanged: _onWorkspaceChanged,
                    ),
                  ],
                ),
                dist: 0,
              )
              .append(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TomText(text: TomCtr.text('board.project')),
                    TomDropdownButton<String>(
                      key: const Key('project-picker'),
                      value: _projectId,
                      isExpanded: true,
                      items: [
                        for (final p in _projects)
                          DropdownMenuItem(
                              value: p.id.get(),
                              child: Text(p.name.get())),
                      ],
                      onChanged: _onProjectChanged,
                    ),
                  ],
                ),
                dist: 12,
              )
              .addRowBreakpoint(atWidth: 480)
              .build(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: TomCircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: TomText(text: _error!, key: const Key('board-error')));
    }
    if (_items.isEmpty) {
      return Center(child: TomText(text: TomCtr.text('board.empty')));
    }
    return _buildBoard();
  }

  Widget _buildBoard() {
    final byStatus = <TodoStatus, List<TodoItem>>{
      for (final status in TodoStatus.values) status: <TodoItem>[],
    };
    for (final item in _items) {
      byStatus[item.statusValue]!.add(item);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in TodoStatus.values)
            _buildColumn(status, byStatus[status]!),
        ],
      ),
    );
  }

  Widget _buildColumn(TodoStatus status, List<TodoItem> items) {
    return Container(
      key: Key('status-column-${status.name}'),
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TomText(
              text: '${TomObservableEnum.resolveText(status)} '
                  '(${items.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final item in items) _buildCard(item),
        ],
      ),
    );
  }

  Widget _buildCard(TodoItem item) {
    final itemId = item.id.get();
    final file = _attachments[itemId];
    return TomCard(
      key: Key('item-$itemId'),
      child: TomListTile(
        titleText: item.title.get(),
        subtitle: TomText(
          text: '${TomObservableEnum.resolveText(item.priorityValue)} · '
              '${TomObservableEnum.resolveText(item.labelValue)}',
        ),
        // The paperclip is the whole point of fetching descriptors: presence,
        // type and size are on the card before anyone asks for a byte.
        trailing: file == null
            ? null
            : Tooltip(
                key: Key('item-$itemId-attachment'),
                message: TomCtr.text('board.item.attachment.present')
                    .replaceAll('{size}', tomHumanFileSize(file.byteCount)),
                child: const Icon(Icons.attach_file, size: 18),
              ),
        onTap: () => _openItem(item),
      ),
    );
  }
}
