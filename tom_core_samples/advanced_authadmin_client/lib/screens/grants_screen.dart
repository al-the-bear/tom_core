/// The Grants destination: the `projectRole` × field-resource-key grant matrix
/// editor (step 35).
///
/// Unlike the Users/Roles/Groups destinations this is not a list of rows but a
/// single editing surface — a grid whose cells are the four-state
/// [TomAuthState] for each `(role, resourceKey)` pair. Tapping a cell cycles it
/// `none → disabled → read → full` (and wraps), building up an edited
/// [GrantMatrixDto] locally; **Save** writes the whole matrix back through
/// `putGrants` (`PUT /admin/grants`) and then re-reads it, so what the grid shows
/// after a save is exactly what the backend persisted.
///
/// The console stays domain-agnostic: it renders whatever role keys and resource
/// keys the matrix reports, never the application's enums. Every backend call is
/// guarded by [AdminSession.guard], so a lost session clears the principal and
/// the shell rebuilds onto login uniformly with the other destinations.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../app/admin_session.dart';
import '../backend/backend.dart';

/// The grant-matrix editor, bound to [session].
class GrantsScreen extends StatefulWidget {
  /// Creates the Grants destination over [session].
  const GrantsScreen({super.key, required this.session});

  /// The session every backend call is guarded through.
  final AdminSession session;

  @override
  State<GrantsScreen> createState() => _GrantsScreenState();
}

class _GrantsScreenState extends State<GrantsScreen> {
  // The last-persisted matrix and the working (possibly edited) copy. Save is
  // offered only when they differ; after a successful save the working copy is
  // replaced by a fresh read so the grid reflects exactly what was stored.
  GrantMatrixDto _loaded = GrantMatrixDto();
  GrantMatrixDto _working = GrantMatrixDto();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  AdminSession get _session => widget.session;

  bool get _dirty => _working != _loaded;

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
      final matrix = await _session.guard((b) => b.getGrants());
      if (!mounted) return;
      setState(() {
        _loaded = matrix;
        _working = matrix;
        _loading = false;
      });
    } on AdminBackendException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _cycle(String role, String resourceKey) {
    final current = _working.accessFor(role, resourceKey);
    final values = TomAuthState.values;
    final next = values[(current.index + 1) % values.length];
    setState(() => _working = _working.withAccess(role, resourceKey, next));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _session.guard((b) => b.putGrants(_working));
      // Re-read so the grid shows the persisted matrix, not just the local edit.
      final matrix = await _session.guard((b) => b.getGrants());
      if (!mounted) return;
      setState(() {
        _loaded = matrix;
        _working = matrix;
        _saving = false;
      });
    } on AdminBackendException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  /// The resource keys spanning every role, sorted for a stable column order.
  List<String> get _resourceKeys {
    final keys = <String>{};
    for (final role in _working.roles) {
      keys.addAll(_working.gradesFor(role).map((g) => g.resourceKey));
    }
    final sorted = keys.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('grants-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _dirty ? 'Unsaved changes' : 'Grant matrix',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                key: const Key('grants-save'),
                onPressed: (_dirty && !_saving) ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          key: const Key('grants-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    final roles = _working.roles.toList();
    final keys = _resourceKeys;
    if (roles.isEmpty || keys.isEmpty) {
      return const Center(
        child: Text('No grants to edit.', key: Key('grants-empty')),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 12,
          columns: [
            const DataColumn(label: Text('Role')),
            for (final key in keys) DataColumn(label: Text(_shortKey(key))),
          ],
          rows: [
            for (final role in roles)
              DataRow(
                key: ValueKey('grants-row-$role'),
                cells: [
                  DataCell(Text(role)),
                  for (final key in keys)
                    DataCell(_GrantCell(
                      role: role,
                      resourceKey: key,
                      access: _working.accessFor(role, key),
                      onTap: () => _cycle(role, key),
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// The trailing segment of a dotted resource key, for a compact column header
  /// (`todo.item.title` → `title`); the full key still keys each cell.
  static String _shortKey(String resourceKey) {
    final dot = resourceKey.lastIndexOf('.');
    return dot < 0 ? resourceKey : resourceKey.substring(dot + 1);
  }
}

/// One editable matrix cell: a button showing the current [access] for
/// `(role, resourceKey)`, cycling to the next state on tap.
class _GrantCell extends StatelessWidget {
  const _GrantCell({
    required this.role,
    required this.resourceKey,
    required this.access,
    required this.onTap,
  });

  final String role;
  final String resourceKey;
  final TomAuthState access;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
    return InkWell(
      key: Key('grant-cell-$role-$resourceKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: resourceKey,
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            _label(access),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Color _color(ColorScheme scheme) {
    switch (access) {
      case TomAuthState.none:
        return scheme.outline;
      case TomAuthState.disabled:
        return scheme.error;
      case TomAuthState.read:
        return scheme.tertiary;
      case TomAuthState.full:
        return scheme.primary;
    }
  }

  /// The human label shown in the cell — distinct per state so a reader (and a
  /// widget test) can tell the four states apart at a glance.
  static String _label(TomAuthState access) {
    switch (access) {
      case TomAuthState.none:
        return 'Hidden';
      case TomAuthState.disabled:
        return 'Disabled';
      case TomAuthState.read:
        return 'Read';
      case TomAuthState.full:
        return 'Full';
    }
  }
}
