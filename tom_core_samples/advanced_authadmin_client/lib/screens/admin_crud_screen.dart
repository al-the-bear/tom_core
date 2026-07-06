/// The generic list-with-CRUD body the Users, Roles, and Groups destinations
/// share (step 34).
///
/// All three screens are the same shape — load a list, show loading / error /
/// empty / rows, offer "New …", and let a row be edited or deleted — differing
/// only in the entity type and how each row reads. So that shape lives here once
/// and each entity screen supplies the small typed bits via callbacks: how to
/// [load] the rows, how to read a row's [idOf]/[titleOf]/[subtitleOf], and what
/// [onCreate]/[onEdit]/[onDelete] do. The create/edit callbacks open the shared
/// editor dialog (returning `true` when a save happened) and this scaffold
/// reloads on success, so list freshness is handled in one place.
///
/// Every backend read/delete routes through [AdminSession.guard], so a lost
/// session clears the principal and the shell rebuilds onto login uniformly.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';

/// A reusable list + create/edit/delete body for one admin entity type [T].
class AdminCrudScreen<T> extends StatefulWidget {
  /// Creates the scaffold for entity [T]; see the field docs for each callback.
  const AdminCrudScreen({
    super.key,
    required this.session,
    required this.tilePrefix,
    required this.createLabel,
    required this.emptyText,
    required this.load,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  /// The session every backend call is guarded through.
  final AdminSession session;

  /// The widget-key prefix for this entity (e.g. `users`), keying the create
  /// button, rows, delete buttons, and the error/empty placeholders.
  final String tilePrefix;

  /// The create-button label (e.g. `New user`).
  final String createLabel;

  /// What the body shows when the list is empty.
  final String emptyText;

  /// Loads the rows for this entity from the backend.
  final Future<List<T>> Function(AdminBackend backend) load;

  /// The stable id of [item] — keys its row and delete button.
  final String Function(T item) idOf;

  /// The row's primary line.
  final String Function(T item) titleOf;

  /// The row's secondary line.
  final String Function(T item) subtitleOf;

  /// Opens the create editor; returns `true` when a new row was saved.
  final Future<bool> Function(BuildContext context) onCreate;

  /// Opens the edit editor for [item]; returns `true` when the edit was saved.
  final Future<bool> Function(BuildContext context, T item) onEdit;

  /// Deletes [item] (already guarded by the caller's session).
  final Future<void> Function(AdminBackend backend, T item) onDelete;

  @override
  State<AdminCrudScreen<T>> createState() => _AdminCrudScreenState<T>();
}

class _AdminCrudScreenState<T> extends State<AdminCrudScreen<T>> {
  List<T> _items = const [];
  bool _loading = true;
  String? _error;

  AdminSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _session.guard(widget.load);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on AdminBackendException catch (e) {
      // A lost session is already cleared by guard (the shell rebuilds to
      // login); other failures surface inline here.
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final saved = await widget.onCreate(context);
    if (saved && mounted) await _load();
  }

  Future<void> _edit(T item) async {
    final saved = await widget.onEdit(context, item);
    if (saved && mounted) await _load();
  }

  Future<void> _delete(T item) async {
    final confirmed = await _confirmDelete(item);
    if (!confirmed || !mounted) return;
    try {
      await _session.guard((b) => widget.onDelete(b, item));
      if (mounted) await _load();
    } on AdminBackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        TomSnackBar(content: TomText(text: e.message)),
      );
    }
  }

  Future<bool> _confirmDelete(T item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TomAlertDialog(
        key: const Key('admin-delete-confirm'),
        title: TomText(text: TomCtr.text('admin.delete.label')),
        content: TomText(
            text: TomCtr.text('admin.delete.confirm')
                .replaceAll('{name}', widget.titleOf(item))),
        actions: [
          TomTextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: TomText(text: TomCtr.text('admin.cancel')),
          ),
          TomFilledButton(
            key: const Key('admin-delete-confirm-ok'),
            onPressed: () => Navigator.of(context).pop(true),
            child: TomText(text: TomCtr.text('admin.delete.label')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('${widget.tilePrefix}-screen'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: TomFilledButton(
              key: Key('${widget.tilePrefix}-create'),
              onPressed: _create,
              icon: const Icon(Icons.add),
              child: TomText(text: widget.createLabel),
            ),
          ),
        ),
        TomDivider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: TomCircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: TomText(
          text: _error!,
          key: Key('${widget.tilePrefix}-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: TomText(
            text: widget.emptyText, key: Key('${widget.tilePrefix}-empty')),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return TomListTile(
          key: Key('${widget.tilePrefix}-tile-${widget.idOf(item)}'),
          titleText: widget.titleOf(item),
          subtitle: TomText(text: widget.subtitleOf(item)),
          onTap: () => _edit(item),
          trailing: TomIconButton(
            key: Key('${widget.tilePrefix}-delete-${widget.idOf(item)}'),
            tooltip: TomCtr.text('admin.delete.label'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(item),
          ),
        );
      },
    );
  }
}
