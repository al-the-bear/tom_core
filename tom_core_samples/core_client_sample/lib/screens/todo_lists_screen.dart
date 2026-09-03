/// The todo list screen: the signed-in user's items, a create action, the
/// role badge / logout, and an optional "refresh from the live server" action.
///
/// Items load from [AppSession.api] (the in-memory backend by default). When a
/// [LiveTodoReadClient] is configured, the app-bar refresh pulls the same list
/// from the running `core_server_sample` over HTTP — an honest live read that
/// swaps the view to server data and labels it as such, without pretending the
/// in-memory edits round-trip to the server. Writing over the wire is what the
/// advanced full-stack suite demonstrates — see `README_advanced_sample.md`.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
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
      _snack(
        TomCtr.text(
          'todos.live.loaded',
        ).replaceAll('{count}', '${items.length}'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(TomCtr.text('todos.live.unreachable').replaceAll('{error}', '$e'));
    }
  }

  void _snack(String message) {
    TomMessenger.showSnackBar(
      context,
      TomSnackBar(content: TomText(text: message)),
    );
  }

  Future<void> _openDetail(TodoItem? item) async {
    final saved = await Navigator.of(context).push<bool>(
      TomPageRoute(
        builder: (_) => TodoDetailScreen(session: _session, item: item),
      ),
    );
    if (saved == true) _loadLocal();
  }

  @override
  Widget build(BuildContext context) {
    return TomScaffold(
      appBar: TomAppBar(
        title: TomText(text: TomCtr.text('todos.appbar.title')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: TomText(
                text: TomCtr.text(
                  'todos.role',
                ).replaceAll('{role}', _session.role),
              ),
            ),
          ),
          if (widget.liveClient != null)
            TomIconButton(
              tooltip: TomCtr.text('todos.action.refreshLive'),
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: _loadLive,
            ),
          TomIconButton(
            tooltip: TomCtr.text('todos.action.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocal,
          ),
          TomIconButton(
            tooltip: TomCtr.text('todos.action.logout'),
            icon: const Icon(Icons.logout),
            onPressed: _session.logout,
          ),
        ],
      ),
      floatingActionButton: TomFloatingActionButton(
        onPressed: () => _openDetail(null),
        tooltip: TomCtr.text('todos.action.new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_showingLive)
            TomMaterialBanner(
              content: TomText(text: TomCtr.text('todos.live.banner')),
              leading: const Icon(Icons.cloud_done_outlined),
              actions: [
                TomTextButton(
                  onPressed: _loadLocal,
                  child: TomText(text: TomCtr.text('todos.live.back')),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? Center(child: TomCircularProgressIndicator())
                : _items.isEmpty
                ? Center(child: TomText(text: TomCtr.text('todos.empty')))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return TomListTile(
                        leading: Icon(
                          item.done.get()
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                        ),
                        titleText: item.title.get(),
                        subtitle: TomText(
                          text:
                              '${TomObservableEnum.resolveText(item.priorityValue)}'
                              ' · '
                              '${TomObservableEnum.resolveText(item.labelValue)}',
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
