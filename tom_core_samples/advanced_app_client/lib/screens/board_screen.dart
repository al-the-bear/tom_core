/// The board screen the app shell shows while [AppSession.isLoggedIn] is true
/// (step 29).
///
/// It is the signed-in home: a workspace/project picker over the principal's
/// visible tree and a status-column board of the selected project's items,
/// grouped into one column per [TodoStatus]. Every read flows through
/// [AppSession.guard], so a dropped session clears the principal and the shell
/// routes back to login without this screen handling it. Tapping a card opens
/// the [ItemDetailScreen] (the bound editor lands in step 30).
library;

import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:flutter/material.dart';

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

  /// Loads every item across the selected project's lists.
  Future<void> _loadItems() async {
    final projectId = _projectId;
    if (projectId == null) {
      setState(() {
        _items = const [];
        _loading = false;
      });
      return;
    }
    try {
      final lists = await _session.guard((b) => b.listLists(projectId));
      final items = <TodoItem>[];
      for (final list in lists) {
        items.addAll(await _session.guard((b) => b.listItems(list.id.get())));
      }
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openItem(TodoItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(session: _session, item: item),
      ),
    );
  }

  /// Opens the share dialog for the selected project; on a granted share, a
  /// snackbar confirms it (the grantee's next read now sees the project).
  Future<void> _openShare() async {
    final projectId = _projectId;
    if (projectId == null) return;
    final shared = await showShareDialog(context, _session, projectId);
    if (shared == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project shared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _session.user?.displayName ?? _session.user?.username ?? '';
    return Scaffold(
      key: const Key('board-screen'),
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          IconButton(
            key: const Key('share-button'),
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Share project',
            onPressed: _projectId == null ? null : _openShare,
          ),
          IconButton(
            key: const Key('logout-button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _session.logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(name),
          const Divider(height: 1),
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
          Text('Signed in as $name'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('workspace-picker'),
                  initialValue: _workspaceId,
                  decoration: const InputDecoration(labelText: 'Workspace'),
                  items: [
                    for (final w in _workspaces)
                      DropdownMenuItem(
                          value: w.id.get(), child: Text(w.name.get())),
                  ],
                  onChanged: _onWorkspaceChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('project-picker'),
                  initialValue: _projectId,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    for (final p in _projects)
                      DropdownMenuItem(
                          value: p.id.get(), child: Text(p.name.get())),
                  ],
                  onChanged: _onProjectChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, key: const Key('board-error')));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No items in this project yet.'));
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
            child: Text(
              '${status.label} (${items.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final item in items) _buildCard(item),
        ],
      ),
    );
  }

  Widget _buildCard(TodoItem item) {
    return Card(
      key: Key('item-${item.id.get()}'),
      child: ListTile(
        title: Text(item.title.get()),
        subtitle: Text(
          '${item.priorityValue.label} · ${item.labelValue.label}',
        ),
        onTap: () => _openItem(item),
      ),
    );
  }
}
