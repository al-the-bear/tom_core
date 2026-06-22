/// The todo list screen: the signed-in user's items, a create action, the
/// role badge / logout, and an optional "refresh from the live server" action.
///
/// Items load from [AppSession.api] (the in-memory backend by default). When a
/// [LiveTodoReadClient] is configured, the app-bar refresh pulls the same list
/// from the running `core_server_sample` over HTTP — an honest live read that
/// swaps the view to server data and labels it as such, without pretending the
/// in-memory edits round-trip to the server (that is the cross-tier item-28
/// work).
library;

import 'package:flutter/material.dart';
import 'package:todo_domain/todo_domain.dart';

import '../api/live_todo_read_client.dart';
import '../app/app_session.dart';
import 'todo_detail_screen.dart';

/// Lists the session's todo items with create / open / refresh actions.
class TodoListsScreen extends StatefulWidget {
  /// Creates the screen over [session]; [liveClient] enables the live refresh.
  const TodoListsScreen({super.key, required this.session, this.liveClient});

  /// The signed-in session (backend + role + field states).
  final AppSession session;

  /// Optional client for the "refresh from live server" action.
  final LiveTodoReadClient? liveClient;

  @override
  State<TodoListsScreen> createState() => _TodoListsScreenState();
}

class _TodoListsScreenState extends State<TodoListsScreen> {
  List<TodoItem> _items = const [];
  bool _loading = true;
  bool _showingLive = false;

  AppSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    setState(() => _loading = true);
    final items = await _session.api.listItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _showingLive = false;
    });
  }

  Future<void> _loadLive() async {
    final client = widget.liveClient;
    if (client == null) return;
    setState(() => _loading = true);
    try {
      final items = await client.fetchTodos();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _showingLive = true;
      });
      _snack('Loaded ${items.length} item(s) from the live server.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Live server unreachable: $e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDetail(TodoItem? item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TodoDetailScreen(session: _session, item: item),
      ),
    );
    if (saved == true) _loadLocal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('role: ${_session.role}')),
          ),
          if (widget.liveClient != null)
            IconButton(
              tooltip: 'Refresh from live server',
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: _loadLive,
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocal,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _session.logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDetail(null),
        tooltip: 'New todo',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_showingLive)
            MaterialBanner(
              content: const Text('Showing live server data (read-only).'),
              leading: const Icon(Icons.cloud_done_outlined),
              actions: [
                TextButton(
                  onPressed: _loadLocal,
                  child: const Text('Back to my list'),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No todos yet.'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            leading: Icon(
                              item.done.get()
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(item.title.get()),
                            subtitle: Text(
                              '${item.priorityValue.label} · '
                              '${item.labelValue.label}',
                            ),
                            onTap: _showingLive ? null : () => _openDetail(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
